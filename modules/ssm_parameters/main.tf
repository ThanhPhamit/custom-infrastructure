# SecureString placeholders. Values are set OUT-OF-BAND (spec: secret values never live in TF code
# or tfvars). `ignore_changes = [value]` keeps Terraform from reverting the operator-set value on
# subsequent applies. NOTE: a later `terraform refresh` reads the live value back into state, so the
# state bucket MUST be encrypted (this is why the backend uses SSE-KMS / --enforce-kms).
resource "aws_ssm_parameter" "this" {
  for_each = var.parameters

  name        = "${var.path_prefix}/${each.key}"
  description = each.value.description
  type        = "SecureString"
  key_id      = var.kms_key_id
  tier        = var.tier
  value       = var.placeholder_value

  tags = merge(var.tags, {
    Name      = "${var.path_prefix}/${each.key}"
    ManagedBy = "Terraform"
  })

  lifecycle {
    ignore_changes = [value]
  }
}
