# AWS S3 Backend Storage Terraform Module

Terraform module which creates an S3 bucket for backend storage with pre-signed URL support.

## Features

This module supports creating:

- **S3 Bucket** - Private bucket for application storage
- **Bucket Policy** - Secure access configuration
- **CORS Configuration** - Pre-signed URL upload/download support
- **IAM Policy** - Attachable policy for ECS/Lambda roles
- **Server-Side Encryption** - AES256 encryption
- **Versioning** - Optional object versioning

## Usage

### Example 1: Basic Backend Storage

```terraform
module "s3_backend_storage" {
  source = "../../modules/s3_backend_storage"

  app_name = "${var.environment}-${var.app_name}"

  # CORS - domains allowed to upload/download via pre-signed URLs
  allowed_origins = [
    "https://${var.frontend_domain}",
    "https://${var.api_domain}"
  ]

  versioning_enabled = true

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

### Example 2: Attach to ECS Task Role

```terraform
module "s3_backend_storage" {
  source = "../../modules/s3_backend_storage"

  app_name = "${var.environment}-${var.app_name}"

  allowed_origins = [
    "https://www.example.com",
    "https://api.example.com"
  ]

  versioning_enabled = true
}

# Attach policy to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_s3_access" {
  role       = module.ecs_api.task_role_name
  policy_arn = module.s3_backend_storage.s3_access_policy_arn
}
```

### Example 3: Using with Lambda

```terraform
module "s3_backend_storage" {
  source = "../../modules/s3_backend_storage"

  app_name = "${var.environment}-${var.app_name}"

  allowed_origins = [
    "https://www.example.com"
  ]
}

# Attach policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = module.lambda_function.role_name
  policy_arn = module.s3_backend_storage.s3_access_policy_arn
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

## Backend Code Example (Node.js)

```javascript
const {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
} = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const s3Client = new S3Client({ region: 'ap-northeast-1' });

// Generate upload URL
async function getUploadUrl(key) {
  const command = new PutObjectCommand({
    Bucket: process.env.S3_BUCKET_NAME,
    Key: key,
  });
  return await getSignedUrl(s3Client, command, { expiresIn: 3600 });
}

// Generate download URL
async function getDownloadUrl(key) {
  const command = new GetObjectCommand({
    Bucket: process.env.S3_BUCKET_NAME,
    Key: key,
  });
  return await getSignedUrl(s3Client, command, { expiresIn: 3600 });
}
```

## Inputs

| Name               | Description                        | Type           | Default | Required |
| ------------------ | ---------------------------------- | -------------- | ------- | :------: |
| app_name           | Application name for bucket naming | `string`       | n/a     |   yes    |
| allowed_origins    | Allowed origins for CORS           | `list(string)` | `["*"]` |    no    |
| versioning_enabled | Enable bucket versioning           | `bool`         | `true`  |    no    |

## Outputs

| Name                        | Description                    |
| --------------------------- | ------------------------------ |
| bucket_id                   | S3 bucket name                 |
| bucket_arn                  | S3 bucket ARN                  |
| bucket_domain_name          | S3 bucket domain name          |
| bucket_regional_domain_name | S3 bucket regional domain name |
| s3_access_policy_arn        | IAM policy ARN for S3 access   |
| s3_access_policy_json       | IAM policy JSON document       |

## IAM Policy Permissions

The generated IAM policy includes:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ListBucket"
  ],
  "Resource": ["arn:aws:s3:::bucket-name", "arn:aws:s3:::bucket-name/*"]
}
```

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.4.0 |
| aws       | >= 5.0.0 |

## License

Apache 2 Licensed. See LICENSE for full details.
