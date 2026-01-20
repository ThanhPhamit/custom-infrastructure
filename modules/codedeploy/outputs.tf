output "s3_bucket_name" {
  description = "The name of the S3 bucket for CodeDeploy revisions"
  value       = aws_s3_bucket.codedeploy_revisions.bucket
}

output "create_deployment_script" {
  description = "The script to create a deployment"
  value = templatefile("${path.module}/create-deployment.sh.tpl", {
    application_name       = aws_codedeploy_app.this.name
    deployment_group_name  = "${var.app_name}-dg"
    s3_bucket              = aws_s3_bucket.codedeploy_revisions.bucket
    deployment_config_name = var.deployment_config_name
    key                    = var.revision_appspec_key
    bundle_type            = var.revision_bundle_type
  })
}
