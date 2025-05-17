resource "kubernetes_service" "app" {
  metadata {
    name      = "iamkeycheck-service"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "iamkeycheck"
    }
    port {
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}
