resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

module "app" {
  source    = "../../modules/app"
  image_tag = var.image_tag
  n_hours   = var.n_hours
  namespace = "prod"
}

module "envoy" {
  source = "../../modules/envoy"
  namespace = "prod"
}
