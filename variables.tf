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

#Member must satisfy regular expression pattern: ^([\p{L}\p{Z}\p{N}_.:/=+\-@]*)$.(UAT) giving error 
variable "tag_environment" {
  description = "Deployment environment (e.g., Development/Test/Staging(UAT)/Production)."
  type        = string
  default     = "Staging"
}

variable service {
  description = "Service name for tagging."
  type        = string
  default     = "StaticFiles"
}

variable serviceDescription {
  description = "Service Description name for tagging."
  type        = string
  default     = "StaticFiles"
}

variable costCentre {
  description = "Cost Centre for tagging."
  type        = string
  default     = "StaticFiles"
}

variable serviceOwner {
  description = "Service Owner for tagging."
  type        = string
  default     = "StaticFiles"
}

variable serviceOwnerGroup {
  description = "Service Owner Group for tagging."
  type        = string
  default     = "StaticFiles"
}

variable technicalContact {
  description = "Technical Contact for tagging."
  type        = string
  default     = "StaticFiles"
}

variable technicalContactGroup {
  description = "Technical Contact Group Name for tagging."
  type        = string
  default     = "StaticFiles"
}

variable dataClassification {
  description = "Data Classification for tagging."
  type        = string
  default     = "StaticFiles"
}

variable deploymentType {
  description = "Deployment Type for tagging."
  type        = string
  default     = "TFC"
}

variable deployer {
  description = "Deployer for tagging."
  type        = string
  default     = "Neelima Nair"
}

# NEW: user-supplied tags that can override defaults
variable "tags" {
  description = "Additional/override tags. Later keys override defaults in locals.tags."
  type        = map(string)
  default     = {}  
}

#Environment for resource naming
variable "env" {
  description = "Deployment environment (e.g., 	prd, stg(UAT), tst (SIT), dev)."
  type        = string
  default     = "stg"
}

#Project for resource naming
variable "project" {
  description = "Project Name"
  type        = string
  default     = "static"
}

variable "subnet1_suffix" {
  description = "Suffix for Subnet 1"
  type        = string
  default     = "private-a"
}

variable "subnet2_suffix" {
  description = "Suffix for Subnet 2"
  type        = string
  default     = "private-b"
}

variable "sg1_suffix" {
  description = "Suffix for Security Group 1"
  type        = string
  default     = "alb"
}

variable "sg2_suffix" {
  description = "Suffix for Security Group  2"
  type        = string
  default     = "vpce"
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
  type        = string
  default     = "internal.de"
}
