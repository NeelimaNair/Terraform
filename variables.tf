variable "certificate_arn" {
  description = "ARN of the private certificate."
  type        = string
}


variable "ssl_policy" {
  description = "ALB SSL policy (e.g., ELBSecurityPolicy-TLS13-1-2-2021-06)"
  type        = string
  # Good secure default (TLS 1.3 + 1.2). Adjust to your org standard.
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "tag_environment" {
  description = "Deployment environment (e.g., Development/Test/Staging(UAT)/Production)."
  type        = string
  default     = "Staging(UAT)"
}

variable service {
  description = "Service name for tagging."
  type        = string
  default     = ""
}


variable costCentre {
  description = "Cost Centre for tagging."
  type        = string
  default     = ""
}

variable serviceOwner {
  description = "Service Owner for tagging."
  type        = string
  default     = ""
}

variable serviceOwnerGroup {
  description = "Service Owner Group for tagging."
  type        = string
  default     = ""
}

variable technicalContact {
  description = "Technical Contact for tagging."
  type        = string
  default     = ""
}

variable technicalContactGroup {
  description = "Technical Contact Group Name for tagging."
  type        = string
  default     = ""
}

variable dataClassification {
  description = "Data Classification for tagging."
  type        = string
  default     = ""
}

variable deploymentType {
  description = "Deployment Type for tagging."
  type        = string
  default     = ""
}

variable deployer {
  description = "Deployer for tagging."
  type        = string
  default     = ""
}

# NEW: user-supplied tags that can override defaults
variable "tags" {
  description = "Additional/override tags. Later keys override defaults in locals.tags."
  type        = map(string)
  default     = {}  
}
