variable "project_name" {
  description = "Short name used as a prefix for all resource names."
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod)."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "key_deletion_window_days" {
  description = "Waiting period (in days) before a disabled/scheduled-for-deletion key is actually deleted."
  type        = number
  default     = 30
}

variable "enable_key_rotation" {
  description = "Whether automatic annual key rotation is enabled on all CMKs."
  type        = bool
  default     = true
}
