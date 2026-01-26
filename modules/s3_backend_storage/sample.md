# S3 Backend Storage Module

Module này tạo S3 bucket cho backend sử dụng với pre-signed URLs (get, put, delete objects).

## Features

- ✅ Block all public access - chỉ truy cập qua pre-signed URLs
- ✅ Server-side encryption (AES256)
- ✅ CORS configuration cho frontend upload/download qua pre-signed URLs
- ✅ IAM policy để attach vào ECS task role / Lambda role

## main.tf

```terraform
module "s3_backend_storage" {
  source = "../../modules/s3_backend_storage"

  app_name = var.app_name

  # CORS - domains được phép upload/download qua pre-signed URLs
  allowed_origins = [
    "https://${var.frontend_domain}",
    "https://${var.api_domain}"
  ]

  versioning_enabled = true
}

# Attach policy to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_s3_access" {
  role       = module.ecs.task_role_name
  policy_arn = module.s3_backend_storage.s3_access_policy_arn
}
```

## variables.tf

```terraform
variable "frontend_domain" {
  type    = string
  default = "frontend.staging.example.com"
}

variable "api_domain" {
  type    = string
  default = "api.staging.example.com"
}
```

## Outputs

```terraform
output "s3_bucket_name" {
  value = module.s3_backend_storage.bucket_id
}

output "s3_bucket_arn" {
  value = module.s3_backend_storage.bucket_arn
}

output "s3_access_policy_arn" {
  value = module.s3_backend_storage.s3_access_policy_arn
}
```

## Pre-signed URL Flow

```
Frontend                    Backend                     S3
   |                           |                         |
   |-- Request upload URL ---->|                         |
   |                           |-- Generate PUT URL ---->|
   |<-- Return PUT URL --------|                         |
   |                           |                         |
   |-- PUT object directly ---------------------------->|
   |<-- 200 OK ------------------------------------------|
```
