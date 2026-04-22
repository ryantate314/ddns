variable "region" {
  description = "AWS region for the Lambda, API Gateway, and SNS topic."
  type        = string
  default     = "us-east-1"
}

variable "zone_name" {
  description = "Existing Route 53 public hosted zone name (e.g. example.com). No trailing dot."
  type        = string
}

variable "record_name" {
  description = "FQDN of the DNS record to manage (e.g. home.example.com). Must be within zone_name."
  type        = string

  validation {
    condition     = endswith(trimsuffix(var.record_name, "."), trimsuffix(var.zone_name, "."))
    error_message = "record_name must be within zone_name."
  }
}

variable "notify_email" {
  description = "Email address subscribed to the SNS topic. AWS will send a confirmation link — you must click it."
  type        = string
}

variable "ttl" {
  description = "TTL in seconds for the A/AAAA records."
  type        = number
  default     = 60
}
