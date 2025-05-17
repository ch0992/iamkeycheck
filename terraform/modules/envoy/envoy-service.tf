resource "kubernetes_service" "envoy" {
  metadata {
    name = "envoy-service"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "envoy"
    }
    port {
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}
