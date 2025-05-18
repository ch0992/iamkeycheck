variable "namespace" {
  type    = string
  default = "default"
}

variable "envoy_node_port" {
  type = number
}

variable "stage" {
  type = string
}

variable "image_tag" {
  type = string
}

