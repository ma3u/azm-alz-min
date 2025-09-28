# Variables for Azure Landing Zone Sandbox
variable "location" {
  description = "The Azure region for sandbox deployment"
  type        = string
  default     = "West Europe"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "sandbox"
}

variable "workload_name" {
  description = "Workload identifier"
  type        = string
  default     = "alz-sandbox"
}

variable "enable_private_endpoint" {
  description = "Enable private endpoints (typically false for sandbox)"
  type        = bool
  default     = false
}
