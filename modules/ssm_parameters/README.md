# ssm_parameters

Creates a set of **SSM Parameter Store SecureString** parameters under a common path prefix,
encrypted with a CMK. Values are **placeholders** — the real secret is set out-of-band and preserved
across applies via `ignore_changes = [value]`.

## Usage

```hcl
module "ssm" {
  source      = "../../modules/ssm_parameters"
  path_prefix = "/myapp/prod"
  kms_key_id  = module.kms.key_arn
  parameters = {
    "database-url" = { description = "DB connection string (set out-of-band)" }
    "api-token"    = { description = "third-party API token (set out-of-band)" }
  }
  tags = local.tags
}
```

Set values out-of-band:

```bash
aws ssm put-parameter --name /myapp/prod/api-token \
  --type SecureString --key-id <cmk> --value "<secret>" --overwrite --profile <aws-profile>
```

## Inputs (required)

| Name | Description |
|------|-------------|
| `path_prefix` | Common prefix, no trailing slash (e.g. `/myapp/prod`). |
| `kms_key_id` | CMK id/ARN for SecureString encryption. |
| `parameters` | Map of short-name => `{ description }`. |

Optional: `tier` (Standard), `placeholder_value`, `tags`.

## Outputs

`parameter_arns` (map), `parameter_names` (list), `path_prefix`.
