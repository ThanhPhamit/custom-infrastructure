variable "dns_zone" {
  description = "Route 53 hosted zone name (e.g., care-hub.lion-garden.com). Zone must already exist."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", var.dns_zone))
    error_message = "dns_zone must be a valid domain name (e.g., care-hub.lion-garden.com)."
  }
}

variable "private_zone" {
  description = "Whether the hosted zone is private. Default false (public zone)."
  type        = bool
  default     = false
}

# ===== Generic records input =====
# Each record = one Route 53 resource record set. This shape lets the caller
# drive any record type (A/AAAA/CNAME/TXT/...), choose per-record TTL, and
# point different subdomains at different targets.
variable "records" {
  description = <<-EOT
    Map of DNS records to create. Key is an arbitrary identifier (typically the FQDN).
    Each record:
      - name    : FQDN for the record (e.g., "api.example.com")
      - type    : DNS record type (A, AAAA, CNAME, TXT, MX, ...)
      - ttl     : TTL in seconds (60–86400)
      - values  : list of record values (IPv4 for A, FQDN for CNAME, etc.)
    Example:
      {
        api = { name = "api.example.com", type = "A", ttl = 300, values = ["203.0.113.25"] }
      }
  EOT
  type = map(object({
    name   = string
    type   = string
    ttl    = number
    values = list(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for r in values(var.records) : contains(
        ["A", "AAAA", "CNAME", "TXT", "MX", "NS", "SRV", "PTR", "CAA"], r.type
      )
    ])
    error_message = "Each record.type must be one of A, AAAA, CNAME, TXT, MX, NS, SRV, PTR, CAA."
  }

  validation {
    condition = alltrue([
      for r in values(var.records) : r.ttl >= 60 && r.ttl <= 86400
    ])
    error_message = "Each record.ttl must be between 60 and 86400 seconds."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : length(r.values) > 0])
    error_message = "Each record must have at least one value in 'values'."
  }
}

# ===== Backwards-compatible convenience inputs =====
# When 'records' is empty, the module falls back to these inputs and builds
# one A record per subdomain → target_ip. This preserves the original
# "point many subdomains at one IP" use case without forcing callers to
# construct the full records map.

variable "subdomains" {
  description = "(Convenience) List of FQDNs to point to target_ip as A records. Ignored when var.records is non-empty."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for s in var.subdomains : can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", s))
    ])
    error_message = "Each subdomain must be a valid FQDN (e.g., api.example.com)."
  }
}

variable "target_ip" {
  description = "(Convenience) IPv4 target for subdomains shortcut. Required when using 'subdomains'."
  type        = string
  default     = null

  validation {
    condition     = var.target_ip == null || can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.target_ip))
    error_message = "target_ip must be a valid IPv4 address or null."
  }
}

variable "ttl" {
  description = "(Convenience) TTL used when building records from subdomains/target_ip."
  type        = number
  default     = 300

  validation {
    condition     = var.ttl >= 60 && var.ttl <= 86400
    error_message = "ttl must be between 60 and 86400 seconds."
  }
}
