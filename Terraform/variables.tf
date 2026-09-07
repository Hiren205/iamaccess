variable vpc_cidr_block {
    default = "10.0.0.0/16"
}
variable private_subnet_cidr_blocks {
    default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable public_subnet_cidr_blocks {
    default = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable k8s_version {
    default = "1.35"
}

variable k8s_cluster_name {
    default = "aws-eks-cluster"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  default = "#!AMGErobf"
  sensitive   = true
}

variable "EnvironmentRegion" {
  description = "AWS Region to deploy resources"
  default = "eu-north-1"
  type        = string
}

variable "AwsProfile" {
  description = "AWS CLI profile name already configured locally"
  type        = string
}

variable "policy_name" {
  description = "value"
  type = string
  default = "neof-aws-secrets-policy"
}

variable "k8s_namespace" {
  default = "neof-aws"
}
