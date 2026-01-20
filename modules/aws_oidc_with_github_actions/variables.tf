variable "app_name" {
  description = "The name of the application"
}

variable "oidc_url" {
  description = "The URL of the identity provider. Corresponds to the iss claim."
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "create_oidc_provider" {
  description = "Whether to create the OIDC provider (set to false if it already exists)"
  type        = bool
  default     = true
}

variable "client_id_list" {
  description = "A list of client IDs (also known as audiences)."
  type        = list(string)
  default     = ["sts.amazonaws.com"]
}

variable "thumbprint_list" {
  description = "A list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)."
  type        = list(string)
  default     = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

variable "github_org" {
  description = "GitHub organisation name."
  type        = string
}

variable "github_repositories" {
  description = "List of GitHub repository names."
  type        = list(string)
}

variable "iam_role_name" {
  description = "Friendly name of the role. If omitted, Terraform will assign a random, unique name."
  type        = string
  default     = "github-oidc-role"
}

variable "iam_role_description" {
  description = "Description of the role"
  type        = string
  default     = "IAM role to enable GitHub OIDC access"
}

variable "max_session_duration" {
  default     = 3600
  description = "Maximum session duration in seconds."
  type        = number
}

variable "iam_role_path" {
  default     = "/"
  description = "Path to the IAM role."
  type        = string
}

variable "passrole_target_role_arns" {
  description = "ARNs of the IAM roles that can pass a role to the service."
  type        = list(string)
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
