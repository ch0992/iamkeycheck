resource "kubernetes_service" "app" {
  metadata {
    name      = "iamkeycheck-service-${var.stage}"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "iamkeycheck-${var.stage}-${var.image_tag}"
    }
    port {
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}
