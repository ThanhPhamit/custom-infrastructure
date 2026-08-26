# =============================================================================
# cloudwatch_alb_availability -- "can a user actually be served right now?"
#
# The question no host-level alarm answers. An EC2 status check passes while the container on it is
# dead; a host-absent alarm sees metrics flowing and stays OK. Both are green while the ALB returns
# 503 to every request. This watches the only thing that tracks user-visible availability: whether
# the target group has a healthy target.
# =============================================================================

variable "app_name" {
  description = "Naming prefix for the alarm (e.g. prod-tyo-lg-autoflow)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "app_name must be lowercase alphanumeric with hyphens."
  }
}

variable "load_balancer_arn_suffix" {
  description = "arn_suffix of the load balancer (aws_lb.x.arn_suffix), e.g. app/my-alb/50dc6c495c0c9188 -- the CloudWatch dimension value, NOT the full ARN."
  type        = string

  validation {
    condition     = can(regex("^(app|net)/", var.load_balancer_arn_suffix))
    error_message = "load_balancer_arn_suffix must look like app/<name>/<id> -- you have probably passed the full ARN."
  }
}

variable "target_group_arn_suffix" {
  description = "arn_suffix of the target group (aws_lb_target_group.x.arn_suffix), e.g. targetgroup/my-tg/73e2d6bc24d8a067."
  type        = string

  validation {
    condition     = can(regex("^targetgroup/", var.target_group_arn_suffix))
    error_message = "target_group_arn_suffix must look like targetgroup/<name>/<id> -- you have probably passed the full ARN."
  }
}

variable "sns_topic_arn" {
  description = "SNS topic the alarm publishes to."
  type        = string
}

variable "period" {
  description = "Seconds per evaluation period."
  type        = number
  default     = 60
}

variable "evaluation_periods" {
  description = "Periods that must breach before the alarm fires. 2 x 60 s keeps detection near two minutes without firing on a single scrape gap."
  type        = number
  default     = 2
}

variable "treat_missing_data" {
  description = <<-EOT
    "breaching" (default) is correct in both common cases and they are worth separating:

      HealthyHostCount = 0   the target is registered and failing its health check -- the container
                             is down, the port is closed, the app is wedged.
      metric ABSENT          no target is registered at all: the instance is stopped, was never
                             attached, or the target group is empty. ALB publishes nothing here --
                             it does not publish a zero -- so only "breaching" sees it.

    On a resource with a start/stop schedule this must be paired with an office-hours gate, or every
    scheduled stop pages. Set "notBreaching" only if you accept losing the second case entirely.
  EOT
  type        = string
  default     = "breaching"

  validation {
    condition     = contains(["breaching", "notBreaching", "ignore", "missing"], var.treat_missing_data)
    error_message = "treat_missing_data must be one of breaching, notBreaching, ignore, missing."
  }
}

variable "enable_ok_actions" {
  description = "Send a notification when the alarm returns to OK. Leave false when an office-hours gate manages this alarm -- the gate's morning reset is an ALARM -> OK transition and would post every working day."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the alarm (merged with Name + ManagedBy)."
  type        = map(string)
  default     = {}
}

variable "create_target_5xx_alarm" {
  description = <<-EOT
    Alarm when the TARGET returns 5xx -- the app is up, registered and passing its health check, but
    failing real requests. The classic cause is a dependency it cannot reach (database, cache,
    upstream API) while the health check is shallow enough not to notice.

    This is the only infrastructure-level signal for that failure. A metric on the dependency itself
    usually is not: RDS DatabaseConnections, for example, oscillates to zero on a perfectly healthy
    app whose pool closes idle connections, so no threshold separates healthy from broken (measured
    2026-08-26). The 5xx count does separate them.

    Caveat worth stating out loud: it needs traffic. With nobody using the service there are no
    requests, no 5xx, and no alarm -- so this complements the availability alarm rather than
    replacing it.
  EOT
  type        = bool
  default     = false
}

variable "target_5xx_threshold" {
  description = "Target 5xx responses per period above which the alarm fires. Keep it above zero: a single 5xx is noise on any real service, a sustained handful is not."
  type        = number
  default     = 5
}

variable "target_5xx_period" {
  description = "Seconds per evaluation period for the 5xx alarm. 300 smooths a one-off blip while still catching a broken dependency within five minutes."
  type        = number
  default     = 300
}
