resource "kubernetes_deployment" "envoy" {
  metadata {
    name = "envoy-deployment"
    namespace = var.namespace
    labels = { app = "envoy" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "envoy" }
    }
    template {
      metadata {
        labels = { app = "envoy" }
      }
      spec {
        container {
          name  = "envoy"
          image = "envoyproxy/envoy:v1.25-latest"
          port {
            container_port = 8080
          }
          volume_mount {
            name       = "envoy-config-volume"
            mount_path = "/etc/envoy"
          }
        }
        volume {
          name = "envoy-config-volume"
          config_map {
            name = kubernetes_config_map.envoy_config.metadata[0].name
            items {
              key  = "envoy.yaml"
              path = "envoy.yaml"
            }
          }
        }
      }
    }
  }
}
