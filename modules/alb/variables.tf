variable "allow_cloudfront_prefix_list" {
  description = "Enable ingress from AWS managed CloudFront global origin-facing prefix list."
  type        = bool
  default     = false
}
variable "app_name" {
  type        = string
  description = "Name of the application"
}
variable "create_route53_record" {
  type        = bool
  description = "Whether to create Route 53 DNS record for the ALB. Set to false when using CloudFront."
  default     = true
}
variable "alb_domain" {
  type        = string
  description = "Domain name for the ALB. Required when create_route53_record is true, can be null when create_route53_record is false."
  default     = null
}
variable "acm_certificate_arn" {
  type        = string
  description = "ARN of the ACM certificate to use for HTTPS listeners"
}
variable "route_53_zone_id" {
  type        = string
  description = "Route 53 hosted zone ID for creating DNS records"
}
variable "vpc_id" {
  type        = string
  description = "ID of the VPC where the ALB will be created"
}
variable "restricted_source_ips" {
  type        = list(string)
  description = "List of CIDR blocks to allow for the security group ingress rules"
}
variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs where the ALB will be deployed"
}
variable "alb_internal" {
  type        = bool
  description = "Whether the ALB is internal or not"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
