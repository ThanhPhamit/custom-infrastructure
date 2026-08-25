# RDS Module Upgrade Plan — Best-in-class Security & Performance

> **Status:** 📋 Draft — chờ review, chưa triển khai
> **Ngày tạo:** 2026-06-10
> **Phạm vi:** `modules/rds`, `modules/rds_secret_rotation` (xóa), `modules/rds_rotation_rollout` (harden)

---

## 0. Bối cảnh & Quyết định kiến trúc

### Hiện trạng (3 module)

```
rds                      → DIY random_password + Secrets Manager secret + 2× ignore_changes
                           ⚠️ password ban đầu nằm plaintext trong TF state
rds_secret_rotation      → SAR Lambda (SecretsManagerRDSPostgreSQLRotationSingleUser)
                           + aws_secretsmanager_secret_rotation (cron/interval)
                           ⚠️ SAR stack không pin semantic_version
                           ⚠️ Lambda SG egress-all, phụ thuộc NAT/VPC endpoint
rds_rotation_rollout     → EventBridge (CloudTrail: UpdateSecretVersionStage)
                           → Lambda sync consolidated secret → CodeDeploy/ECS rollout
                           ⚠️ Không DLQ, không alarm — rollout fail là SILENT
                           ⚠️ Fallback appspec.yaml có thể deploy task definition CŨ
```

### Kiến trúc đề xuất (2 module)

```
rds                      → manage_master_user_password = true (RDS-managed secret)
                           ✅ password KHÔNG BAO GIỜ vào TF state
                           ✅ Secrets Manager managed rotation — không Lambda,
                              không VPC wiring, không NAT dependency
                           ✅ rotation schedule config ngay trong module
rds_secret_rotation      → ❌ XÓA TOÀN BỘ
rds_rotation_rollout     → GIỮ + harden (DLQ, alarms, fail-fast)
                           Handler đã validate sẵn event RotationSucceeded
                           (handler.py:229) — chỉ cần đổi EventBridge rule
```

### Lý do chọn managed master password

| Tiêu chí | DIY hiện tại | `manage_master_user_password` |
|---|---|---|
| Password trong TF state | ❌ Có (plaintext, vô hiệu sau lần rotate đầu) | ✅ Không bao giờ |
| Rotation Lambda phải maintain | SAR stack + SG + VPC wiring | ✅ Không có — service-managed |
| NAT GW / VPC endpoint dependency | Bắt buộc | ✅ Không cần |
| Schedule | cron qua module phụ | cron qua `aws_secretsmanager_secret_rotation` (không lambda) |
| Secret format | `{engine,host,username,password,dbname,port}` | `{username,password}` — `_extract_password` của rollout vẫn chạy nguyên |
| Code TF phải maintain | ~150 dòng + 1 module | ~5 dòng |

### Trade-off chấp nhận

- Managed rotation = **single-user** (giống hiện tại — không tệ hơn): có risk window vài phút
  cho connection MỚI dùng password cũ trong lúc rollout chưa cutover xong.
  → Bù bằng Phase 3 (fail-fast + alarm) + lịch rotate lúc traffic thấp (00:00 JST mùng 1).
- Secret managed không chứa `host/dbname/port` → app/output lấy endpoint từ module output
  (consolidated runtime secret vẫn là nguồn chính cho app, không đổi).

---

## ⚠️ Bước 0 — Verify TRƯỚC khi code (gate quyết định)

- [ ] **0.1** Xác nhận provider AWS `>= 5.40` (hỗ trợ `aws_secretsmanager_secret_rotation`
      không cần `rotation_lambda_arn` cho managed rotation).
- [ ] **0.2** Test trên 1 secret managed thật: chạy `aws secretsmanager rotate-secret` thủ công,
      xác nhận CloudTrail emit event `RotationSucceeded` (hoặc `UpdateSecretVersionStage`)
      với shape mà EventBridge rule mới match được.
      **Nếu event không như kỳ vọng → fallback Option B:** giữ DIY + SAR, chỉ làm Phase 3.
      (Phase 3 dùng chung cho cả 2 hướng nên không mất công.)
- [ ] **0.3** `grep -r "rds_secret_rotation\|rds_rotation_rollout\|module.rds"` toàn bộ
      `environments/` và các repo terraform khác → lập danh sách consumer thật
      (kết quả grep sơ bộ trong repo này: **chưa có environment nào reference** —
      cần xác nhận thêm tokyo-dev nằm ở repo/thư mục nào).

---

## Phase 1 — `modules/rds`: Core upgrade

### 1.1 Managed master password (thay toàn bộ DIY credential path)

```hcl
# main.tf — aws_db_instance.primary
manage_master_user_password   = true
master_user_secret_kms_key_id = var.kms_key_arn
# XÓA: password = local.db_password
# XÓA: lifecycle { ignore_changes = [password] }
```

**Xóa:** `random_password.rds`, `aws_secretsmanager_secret.rds_credentials`,
`aws_secretsmanager_secret_version.rds_credentials`, local `use_generated_password`,
local `db_password`, var `db_password`.

### 1.2 KMS xuyên suốt (CMK)

```hcl
variable "kms_key_arn" {
  type        = string
  description = "Customer-managed KMS key ARN for storage, PI, master secret, and log encryption. Null = AWS-managed keys."
  default     = null   # default null = không breaking change
}
```

Áp vào 4 chỗ:
- [ ] `kms_key_id` (storage) — ⚠️ đổi trên instance hiện hữu = **recreate**, xem Phase 4.4
- [ ] `performance_insights_kms_key_id`
- [ ] `master_user_secret_kms_key_id`
- [ ] `aws_cloudwatch_log_group.rds_exports` → `kms_key_id`

> Lý do CMK: cross-account snapshot share BẮT BUỘC CMK; key policy giới hạn ai decrypt
> được secret chứa master password; audit CloudTrail theo key riêng.

### 1.3 Rotation schedule nội bộ module (module tự chứa vòng đời password)

```hcl
variable "rotation_schedule_expression" {
  type        = string
  description = "Secrets Manager schedule for managed master password rotation (cron/rate). Null = giữ default của RDS (7 ngày)."
  default     = null
}

resource "aws_secretsmanager_secret_rotation" "master" {
  count     = var.rotation_schedule_expression != null ? 1 : 0
  secret_id = aws_db_instance.primary.master_user_secret[0].secret_arn
  # KHÔNG có rotation_lambda_arn — managed rotation
  rotation_rules {
    schedule_expression = var.rotation_schedule_expression
  }
}
```

### 1.4 Security hardening

- [ ] `ca_cert_identifier` — var mới, default `"rds-ca-rsa2048-g1"` (tránh surprise khi AWS deprecate CA cũ)
- [ ] `iam_database_authentication_enabled` — var mới, default `false` (bật cho app role giảm phụ thuộc password)

### 1.5 Performance knobs (gp3 ≥ 400GB)

- [ ] var `iops` (default `null`), var `storage_throughput` (default `null`)
      → truyền vào `aws_db_instance.primary` (và replica)

### 1.6 Replica parity với primary

Replica hiện thiếu toàn bộ observability ([main.tf:335](main.tf#L335)):
- [ ] `monitoring_interval` + `monitoring_role_arn`
- [ ] `performance_insights_enabled` + retention + KMS
- [ ] `kms_key_id`
- [ ] `ca_cert_identifier`

### 1.7 SG rules: `count` → `for_each`

[main.tf:124](main.tf#L124) — `count` theo index: đổi SG ở giữa list → shift index → recreate rules.

```hcl
resource "aws_security_group_rule" "db_from_sg" {
  for_each                 = toset(var.restricted_security_group_ids)
  source_security_group_id = each.value
  # ...
}
```

⚠️ Cần `terraform state mv` hoặc `moved {}` block cho consumer hiện hữu.

### 1.8 Outputs

- [ ] Thêm `master_user_secret_arn` = `aws_db_instance.primary.master_user_secret[0].secret_arn`
- [ ] Xóa `password_secret_arn`, `password_secret_name` (hoặc giữ 1 release với deprecation note)

---

## Phase 2 — Xóa `modules/rds_secret_rotation`

- [ ] 2.1 Xác nhận Bước 0.3 — không còn consumer nào
- [ ] 2.2 `git rm -r modules/rds_secret_rotation/`
- [ ] 2.3 Pin `aws >= 5.40` trong `modules/rds/versions.tf`
- [ ] 2.4 Gỡ section `rds_secret_rotation` khỏi README

---

## Phase 3 — Harden `modules/rds_rotation_rollout` (GIỮ lại)

> Phase này dùng chung cho cả Option A (managed) lẫn Option B (DIY) — làm trước an toàn.

### 3.1 EventBridge pattern mới

Đổi rule từ `UpdateSecretVersionStage` ([main.tf:196](../rds_rotation_rollout/main.tf#L196))
sang `RotationSucceeded` (shape xác nhận ở Bước 0.2). Handler đã hỗ trợ sẵn cả 2
(`is_cloudtrail_rotation_succeeded`, handler.py:229) — chỉ đổi TF, không đổi Python.

### 3.2 DLQ + on-failure destination ⭐ (gap nghiêm trọng nhất)

Failure mode hiện tại: rotation XONG nhưng rollout FAIL → password DB đã đổi, app chưa biết
→ outage trễ ở lần reconnect/scale-out tiếp theo, không ai được báo.

- [ ] SQS DLQ cho EventBridge target (`dead_letter_config`)
- [ ] Lambda async on-failure destination → cùng SQS (hoặc SNS)
- [ ] Output DLQ ARN để environment wire vào alerting

### 3.3 CloudWatch Alarms

- [ ] Lambda `Errors > 0` (period 5m)
- [ ] EventBridge rule `FailedInvocations > 0`
- [ ] DLQ `ApproximateNumberOfMessagesVisible > 0`
- [ ] var `alarm_sns_topic_arns` → wire vào module `alert_email` / `chatbot_slack` có sẵn

### 3.4 Fail-fast thay silent fallback appspec ⭐

[handler.py:140-164](../rds_rotation_rollout/lambda/handler.py#L140-L164): fallback
`appspec.yaml` có thể trỏ task definition revision CŨ → rotation day deploy nhầm app cũ.

- [ ] var `allow_appspec_fallback` (default **`false`** = fail-fast)
- [ ] Khi fail → exception → DLQ → alarm (3.2/3.3) → xử lý tay an toàn hơn deploy nhầm

### 3.5 Idempotency cho duplicate delivery

EventBridge = at-least-once. Catch `DeploymentLimitExceeded` / "deployment already in progress"
trong `_rollout_codedeploy` → log + return ok thay vì raise.

### 3.6 KMS cho Lambda log group

`cloudwatch_logs_kms_key_id = var.kms_key_arn` (đồng bộ Phase 1.2).

---

## Phase 4 — Migration environment đang chạy + Docs

> ⚠️ THỨ TỰ QUAN TRỌNG — bật `manage_master_user_password` trên instance đang chạy là
> **in-place** (không recreate) nhưng AWS đổi password NGAY tại thời điểm apply.

### Trình tự apply

1. **Apply Phase 3 trước** — rollout lambda sẵn sàng bắt event mới
2. **Flip `manage_master_user_password = true`** → RDS tạo managed secret, rotation event fire
   → rollout lambda TỰ ĐỘNG sync consolidated secret + redeploy ECS
   (pipeline tự xử lý migration — không cần thao tác tay)
3. **Verify**: app connect OK, consolidated secret có password mới, CodeDeploy deployment success
4. **KMS storage cho instance HIỆN HỮU**: đổi `kms_key_id` = recreate
   → env đang chạy: GIỮ default key, document đường snapshot → copy-with-CMK → restore
   → env mới: dùng CMK từ đầu
5. **Decommission**: xóa secret DIY cũ (recovery window 7 ngày), destroy SAR stack,
   `terraform state rm` các resource đã xóa khỏi code
6. CloudTrail trail (Step 0 trong README) **VẪN CẦN GIỮ** — EventBridge vẫn ăn event qua CloudTrail

### Rollback

- Secret DIY cũ còn trong recovery window 7 ngày → restore được
- Reset password thủ công: `aws rds modify-db-instance --master-user-password <old>` 
  (lấy old password từ secret cũ) + tắt `manage_master_user_password`
- ECS task cũ (blue) giữ connection cũ sống → có thời gian xử lý

### Docs

- [ ] Viết lại `README.md`: kiến trúc 2-module, diagram mới, Example 3 mới,
      migration runbook, rollback steps
- [ ] Note rõ risk window single-user rotation (thay claim "zero-downtime")

---

## Validation chain (chạy sau MỖI phase)

```
terraform fmt → terraform validate → tflint → checkov → terraform plan -out=tfplan
```

- Phase 1/2: `terraform plan` trên env thật → xác nhận **KHÔNG có destroy/recreate ngoài ý muốn**
  (đặc biệt: SG rules for_each cần `moved`/`state mv`, instance không được recreate)
- Phase 3: test bằng `rotate-secret` thủ công 1 lần → theo dõi full chain
  rotation → EventBridge → lambda → sync → CodeDeploy

---

## Câu hỏi mở (cần chốt khi review)

1. ✅/❌ Đồng ý hướng **Option A** (managed password, xóa `rds_secret_rotation`)?
   Hay giữ DIY (Option B) và chỉ làm Phase 3?
2. Environment nào đang chạy module này thật (tokyo-dev ở repo nào)? → quyết định scope Phase 4
3. Có yêu cầu zero-downtime TUYỆT ĐỐI không? Nếu có → cần multi-user rotation strategy
   (chỉ làm được với DIY/Option B + SAR MultiUser lambda + app đọc cả username từ secret)
4. `iam_database_authentication_enabled` có bật cho app không (cần app đổi cách auth)?
