variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "gsg-devops-cluster"
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.33"
}
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}