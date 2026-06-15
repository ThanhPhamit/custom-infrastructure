# Hướng dẫn kết nối AWS Client VPN để truy cập tài nguyên WMS

> Áp dụng cho dev/QA cần truy cập tài nguyên nội bộ VPC (site `*.welfan.internal`) và DB on-premise qua AWS Client VPN.
> Endpoint UDP: `cvpn-endpoint-02ac7085243748633` — region `ap-northeast-3` (Osaka).

---

## Vì sao cần cấu hình DNS thêm (đọc 1 lần để hiểu, đỡ vướng về sau)

VPN cho bạn vào được **mạng nội bộ** (VPC + on-prem). Nhưng "vào được mạng" và "phân giải được tên miền" là hai chuyện khác nhau:

- **Truy cập bằng IP** (ví dụ DB on-prem `192.168.0.61:1433`) → chỉ cần routing, **không cần DNS**. Đây là lý do connect DB chạy ngay sau khi bật VPN.
- **Truy cập bằng tên** (ví dụ `https://staging.welfan.internal`) → cần DNS. Các domain `*.welfan.internal` là **Route 53 private hosted zone**, trỏ tới **internal ALB** (IP private trong VPC). Chỉ **DNS resolver của VPC là `169.254.169.253`** mới phân giải được — DNS công cộng/DNS nhà hoàn toàn không biết các tên này.

Khi chạy `sudo openvpn` trực tiếp, server VPN **có đẩy** thông tin DNS (`dhcp-option DNS 169.254.169.253`) về client, nhưng OpenVPN **không tự áp** nó vào hệ thống (Linux dùng `systemd-resolved`, macOS cần client GUI xử lý). Vì vậy phải cấu hình thêm bước DNS — đó là toàn bộ nội dung "rắc rối" của tài liệu này.

---

## Bước 1 — Chuẩn bị file `client.ovpn`

1. **Lấy file mới nhất.** Certificate client có hạn **1 năm**, hết hạn sẽ thấy log `WARNING: Your certificate has expired!` và không kết nối được. File chuẩn được Terraform sinh ra tại `osaka-stg/client.ovpn` (admin cấp cho bạn). Khi cert hết hạn, admin chạy lại `terraform apply` và phát lại file mới.

2. **Sửa dòng `remote`.** Mở file, tìm dòng:
   ```
   remote *.cvpn-endpoint-02ac7085243748633.prod.clientvpn.ap-northeast-3.amazonaws.com 443
   ```
   Thay `*` (hoặc tên người trước đó) bằng **tên tuỳ ý** của bạn — AWS chấp nhận bất kỳ prefix nào:
   ```
   remote dangtrung.cvpn-endpoint-02ac7085243748633.prod.clientvpn.ap-northeast-3.amazonaws.com 443
   ```
   Lưu lại.

---

## Bước 2 — Kết nối + cấu hình DNS

> Cấu hình DNS **khác nhau giữa Linux và macOS** vì cách áp DNS khác nhau: Linux chạy `openvpn` tay nên cần script `resolvectl`; macOS dùng client GUI nên khai báo `dhcp-option DNS` trong file là đủ. Dùng đúng phần cho HĐH của bạn.

### 🐧 Linux

Thêm khối sau vào **cuối file `client.ovpn`**:

```conf
# DNS configuration for VPN tunnel
script-security 2
up "/bin/bash -c 'sudo resolvectl dns tun0 169.254.169.253; sudo resolvectl domain tun0 \"~welfan.internal\"'"
down "/bin/bash -c 'sudo resolvectl revert tun0'"
```

Rồi kết nối:
```bash
sudo openvpn --config client.ovpn
```

- Khối `up`/`down` tự áp DNS mỗi lần connect và tự `revert` khi ngắt. Dùng **split-DNS** `~welfan.internal`: chỉ `*.welfan.internal` đi qua resolver VPC, còn lại dùng DNS thường của máy.
- ⚠️ Tên interface mặc định là `tun0`. Nếu đã có VPN khác đang chạy, OpenVPN có thể tạo `tun1`... → `ip a | grep tun` để kiểm tra và sửa tên trong script cho khớp.
- ⚠️ **ElastiCache nối bằng hostname** (`*.cache.amazonaws.com`) sẽ KHÔNG resolve với `~welfan.internal`. Nếu cần nối ElastiCache bằng tên: đổi `~welfan.internal` thành `~.` (đẩy mọi truy vấn DNS qua resolver VPC), hoặc nối bằng IP. (DB nối bằng IP nên không ảnh hưởng.)

### 🍎 macOS

Dùng client GUI **Tunnelblick** hoặc **OpenVPN Connect** (lệnh `resolvectl` ở phần Linux không có trên macOS).

1. Thêm 3 dòng sau vào **cuối file `client.ovpn`**:

   ```conf
   verify-x509-name server.vpn.welfan.internal name
   reneg-sec 0
   dhcp-option DNS 192.168.25.2
   ```

   - `verify-x509-name server.vpn.welfan.internal name` — xác thực đúng server cert (CN khớp).
   - `reneg-sec 0` — tắt renegotiation định kỳ.
   - `dhcp-option DNS 192.168.25.2` — resolver của VPC (primary CIDR `192.168.25.0/24` → resolver `.2`). Áp DNS này thì resolve được cả `*.welfan.internal` lẫn ElastiCache (`*.cache.amazonaws.com`).

2. Cài Tunnelblick/OpenVPN Connect → **import** file `.ovpn` (kéo vào app hoặc double-click).
3. Bấm **Connect**, đợi trạng thái **Connected**. DNS nội bộ resolve ngay, không cần thao tác tay.

### ⚠️ Nếu WiFi/router của bạn dùng dải `192.168.0.x` (trùng với DB)

DB on-prem nằm trong `192.168.0.0/24`. Nếu WiFi/router nhà bạn cũng cấp IP dạng `192.168.0.x` (ví dụ máy bạn là `192.168.0.236`), máy sẽ coi IP của DB là "cùng mạng LAN" và **đẩy ra WiFi thay vì vào VPN** → nối DB báo lỗi **`No route to host`**. (ElastiCache `192.168.25/26` không trùng nên vẫn chạy bình thường — đó là dấu hiệu nhận biết.)

**Kiểm tra** (khi VPN đang bật):
```bash
ip route get 192.168.0.61        # Linux
route -n get 192.168.0.61        # macOS
```
Nếu kết quả đi ra card WiFi (`wlo1` / `en0`) thay vì VPN (`tun0` / `utunX`) → đúng là trùng dải.

**Cách sửa (khuyến nghị)** — thêm route `/32` cho **từng DB** vào file `.ovpn`. Dùng được cho **cả Linux lẫn macOS**, tự áp khi connect, không cần `sudo`:
```conf
route 192.168.0.61  255.255.255.255
route 192.168.0.220 255.255.255.255
```
`/32` cụ thể hơn `/24` của WiFi nên "thắng" → traffic tới DB đi đúng vào VPN. Có thêm DB/host nào trong `192.168.0.x` thì thêm 1 dòng nữa.

**Nếu cần CẢ dải `192.168.0.0/24`** (nhiều host), thay vì liệt kê từng IP thì push 2 route `/25`:
```conf
route 192.168.0.0   255.255.255.128
route 192.168.0.128 255.255.255.128
```
> ⚠️ Cách `/25` khiến bạn **mất truy cập thiết bị LAN nhà** trong dải đó khi VPN bật (router `192.168.0.1`, máy in...). Chỉ cần vài DB thì dùng `/32` an toàn hơn.

**Bền vững nhất**: đổi dải LAN của router sang dải không trùng (`192.168.50.0/24`, `10.0.0.0/24`...) hoặc dùng hotspot điện thoại — khi đó không cần route `/32` nào.

---

## Bước 3 — Kiểm tra kết nối

```bash
# 1) Tunnel đã lên?
ip a | grep tun                  # Linux — thấy tun0 là OK
# log openvpn có dòng: Initialization Sequence Completed

# 2) DNS nội bộ resolve được? (hỏi thẳng resolver VPC)
nslookup staging.welfan.internal 169.254.169.253
# -> ra IP private (192.168.x). Nếu lệnh này ra IP nhưng `nslookup staging.welfan.internal`
#    (không chỉ định server) lại fail => DNS chưa được áp vào hệ thống, xem lại Bước 2.

# 3) Truy cập thực tế
curl -I https://staging.welfan.internal/
```

---

## Bước 4 — Tài nguyên nội bộ truy cập được

| Domain | Môi trường | Loại |
|---|---|---|
| `https://staging.welfan.internal` | osaka-stg | Giao diện (Nuxt) |
| `https://api.staging.welfan.internal` | osaka-stg | API (Nest) |
| `https://dev.welfan.internal` | osaka-dev | Giao diện (Nuxt) |
| `https://api.dev.welfan.internal` | osaka-dev | API (Nest) |
| `https://welfan.internal` | osaka-prod | Giao diện (Nuxt) |
| `https://api.welfan.internal` | osaka-prod | API (Nest) |
| DB on-premise `192.168.0.61:1433` (SQL Server) | — | Kết nối **bằng IP**, qua Site-to-Site VPN; không cần DNS |

---

## Xử lý sự cố thường gặp

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `WARNING: Your certificate has expired!` rồi không kết nối | Cert client hết hạn (hạn 1 năm) | Xin admin file `client.ovpn` mới (admin chạy lại `terraform apply` để tạo lại cert) |
| `Options error: ... block-outside-dns` | Option dành cho Windows, Linux bỏ qua | **Vô hại** — bỏ qua. Có "Initialization Sequence Completed" là đã kết nối |
| Connect DB (bằng IP) OK nhưng mở `*.welfan.internal` không được | DNS chưa được áp vào hệ thống | Làm đúng phần DNS ở Bước 2; verify bằng `nslookup ... 169.254.169.253` |
| Nối DB báo `No route to host` (nhưng ElastiCache/site vẫn được) | WiFi/router trùng dải `192.168.0.x` với DB → traffic bị đẩy ra WiFi | Thêm route `/32` vào `.ovpn` (xem mục ⚠️ ở Bước 2), hoặc đổi dải router / dùng hotspot |
| VPN connect xong nhưng không tới được gì | Admin đang tắt VPN ngoài giờ (subnet association bị gỡ theo lịch) | VPN tự bật **07:50–19:00 VN, thứ 2–6**. Ngoài giờ nhờ admin bật tay (xem `vpn-schedule-automation.md`) |
| VPN tự tắt giữa chừng khi đóng terminal | `sudo openvpn` chạy foreground | Chạy nền: thêm `--daemon`, hoặc dùng NetworkManager/Tunnelblick |

---

## Liên quan

- `docs/vpn-schedule-automation.md` — lịch tự bật/tắt VPN (07:50 & 19:00 VN, thứ 2–6) và lý do dùng private IP cho bastion.
