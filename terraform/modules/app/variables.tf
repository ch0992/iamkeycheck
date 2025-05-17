variable "namespace" {
  type    = string
  default = "default"
}

variable "image_tag" { type = string }
variable "n_hours" { type = number }

# ConfigMap용 환경 변수
variable "log_level" { type = string }
variable "csv_path" { type = string }

# Secret용 환경 변수
variable "aws_access_key_id" { type = string }
variable "aws_secret_access_key" { type = string }
