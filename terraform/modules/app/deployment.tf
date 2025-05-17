resource "kubernetes_deployment" "app" {
  metadata {
    name = "iamkeycheck-deployment"
    namespace = var.namespace
    labels = { app = "iamkeycheck" }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "iamkeycheck" }
    }

    template {
      metadata {
        labels = { app = "iamkeycheck" }
      }

      spec {
        container {
          name  = "iamkeycheck"
          image = "nginx:alpine"
          image_pull_policy = "Always"

          port {
            container_port = 8000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.app_config.metadata[0].name
            }
          }
        }
      }
    }
  }
}
