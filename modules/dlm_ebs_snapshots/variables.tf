variable "app_name" {
  description = "Naming prefix (e.g. myapp-prod)."
  type        = string
}

variable "target_tags" {
  description = "Tag key/value map that selects the resources to snapshot. For INSTANCE policies, tag the INSTANCE with these (e.g. { Backup = \"myapp-daily\" })."
  type        = map(string)
}

variable "resource_type" {
  description = "What DLM targets: INSTANCE (snapshots all attached volumes as a set; supports exclude_boot_volume) or VOLUME."
  type        = string
  default     = "INSTANCE"

  validation {
    condition     = contains(["INSTANCE", "VOLUME"], var.resource_type)
    error_message = "resource_type must be INSTANCE or VOLUME."
  }
}

variable "exclude_boot_volume" {
  description = "INSTANCE policies only: skip the root/boot volume (snapshot only data volumes). Ignored for VOLUME policies."
  type        = bool
  default     = true
}

variable "schedule_interval_hours" {
  description = "Snapshot interval in hours (24 = daily). Must be one of DLM's allowed values."
  type        = number
  default     = 24

  validation {
    condition     = contains([1, 2, 3, 4, 6, 8, 12, 24], var.schedule_interval_hours)
    error_message = "schedule_interval_hours must be one of 1,2,3,4,6,8,12,24."
  }
}

variable "schedule_times" {
  description = "List of UTC times (HH:MM) at which the create rule runs. Single element for a daily snapshot."
  type        = list(string)
  default     = ["17:00"]
}

variable "retain_count" {
  description = "Number of snapshots to retain (oldest deleted beyond this)."
  type        = number
  default     = 14

  validation {
    condition     = var.retain_count >= 1 && var.retain_count <= 1000
    error_message = "retain_count must be between 1 and 1000."
  }
}

variable "copy_tags" {
  description = "Copy the source resource's tags onto the snapshots."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the DLM policy + role (merged with Name + ManagedBy)."
  type        = map(string)
  default     = {}
}
