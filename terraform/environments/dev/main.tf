resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

module "app" {
  source    = "../../modules/app"
  image_tag = var.image_tag
  n_hours   = var.n_hours
  namespace = var.namespace
  stage     = var.stage
  log_level = var.log_level
  csv_path  = var.csv_path
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
}

module "envoy" {
  source = "../../modules/envoy"
  namespace = var.namespace
  envoy_node_port = 30500
  stage = var.stage
  image_tag = var.image_tag
}
