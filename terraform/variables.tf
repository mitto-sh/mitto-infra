variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (prod, staging)"
  type        = string
  default     = "prod"
}

variable "domain" {
  description = "Root domain for the platform"
  type        = string
  default     = "dhinrichs.dev"
}

variable "platform_name" {
  description = "Platform name used for resource naming"
  type        = string
  default     = "mitto"
}

# ── VPC ────────────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the Control Plane VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to use (3 recommended)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# ── ECS ────────────────────────────────────────────────────────────────────────
variable "api_cpu" {
  description = "Fargate vCPU units for the API task"
  type        = number
  default     = 256
}

variable "api_memory" {
  description = "MB of memory for the API task"
  type        = number
  default     = 512
}

variable "api_desired_count" {
  description = "Desired number of API tasks"
  type        = number
  default     = 1
}

# ── RDS ────────────────────────────────────────────────────────────────────────
variable "db_name" {
  description = "Control Plane database name"
  type        = string
  default     = "mitto"
}

variable "db_username" {
  description = "Master DB username"
  type        = string
  default     = "mitto"
  sensitive   = true
}

variable "db_min_acu" {
  description = "Aurora Serverless v2 minimum ACU"
  type        = number
  default     = 0.5
}

variable "db_max_acu" {
  description = "Aurora Serverless v2 maximum ACU"
  type        = number
  default     = 4
}

# ── ECR ────────────────────────────────────────────────────────────────────────
variable "ecr_image_retention" {
  description = "Number of images to keep per ECR repo"
  type        = number
  default     = 10
}
