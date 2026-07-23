# kms_cmk

Single customer-managed KMS key (CMK) + alias, for encrypting EBS volumes, RDS storage, and SSM
SecureString parameters at rest under one key with a controlled policy and annual rotation.

## Design

- **Anti-lockout + IAM delegation:** the key policy grants the account root `kms:*`, so IAM policies
  govern real usage. A consumer (e.g. an EC2 instance role) that needs to decrypt just grants itself
  `kms:Decrypt` on this key ARN in **its own** IAM policy — it does **not** need to be listed in
  `key_user_arns`. This deliberately avoids a key-policy ↔ role circular dependency.
- `key_user_arns` is an optional explicit allow-list (adds a usage statement + a CreateGrant
  statement scoped by `kms:GrantIsForAWSResource`) for principals you want named in the key policy.

## Usage

```hcl
module "kms" {
  source   = "../../modules/kms_cmk"
  app_name = "myapp-prod"
  tags     = local.tags
}

# consumer grants itself decrypt in its own IAM policy:
#   actions   = ["kms:Decrypt"]
#   resources = [module.kms.key_arn]
```

## Inputs (required)

| Name | Description |
|------|-------------|
| `app_name` | Naming prefix; alias becomes `alias/<app_name>`. |

Optional: `description`, `enable_key_rotation` (true), `deletion_window_in_days` (30),
`multi_region` (false), `key_administrator_arns` ([]), `key_user_arns` ([]), `tags`.

## Outputs

`key_arn`, `key_id`, `alias_name`, `alias_arn`.
