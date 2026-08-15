variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name — fixed for this stack"
  type        = string
  default     = "dev"
}

variable "domain" {
  description = "Root domain for the platform (same as prod — this stack owns the hosted zone until the prod stack is applied)"
  type        = string
  default     = "dhinrichs.dev"
}

variable "platform_name" {
  description = "Platform name used for resource naming"
  type        = string
  default     = "mitto"
}

# ── NETWORK ──────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the dev VPC (different range from prod's 10.0.0.0/16 to avoid overlap if ever peered)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "AZs to use — ALB requires at least 2"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ── EC2 ──────────────────────────────────────────────────────────────────────
variable "instance_type" {
  description = "EC2 instance type running Docker Compose"
  type        = string
  default     = "t3.small"
}

variable "ebs_size_gb" {
  description = "Root volume size (gp3)"
  type        = number
  default     = 20
}

variable "ssh_public_key" {
  description = "Public key (contents of your .pub file) for SSH access to the instance"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH into the instance — restrict this to your own IP/32, do not leave open to 0.0.0.0/0"
  type        = string
}

# ── ECR ──────────────────────────────────────────────────────────────────────
variable "ecr_image_retention" {
  description = "Number of images to keep per ECR repo"
  type        = number
  default     = 10
}

# ── AUTO SHUTDOWN ──────────────────────────────────────────────────────────────
variable "schedule_timezone" {
  description = "IANA timezone for the shutdown/startup schedule"
  type        = string
  default     = "America/Santiago"
}

variable "shutdown_hour" {
  description = "Hour (0-23, local schedule_timezone) the instance stops every day"
  type        = number
  default     = 23
}

variable "startup_hour" {
  description = "Hour (0-23, local schedule_timezone) the instance starts Mon-Fri (stays off Sat/Sun)"
  type        = number
  default     = 9
}
