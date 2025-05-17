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
  log_level = var.LOG_LEVEL
  csv_path  = var.CSV_PATH
  aws_access_key_id     = var.AWS_ACCESS_KEY_ID
  aws_secret_access_key = var.AWS_SECRET_ACCESS_KEY
}

module "envoy" {
  source = "../../modules/envoy"
  namespace = var.namespace
}
