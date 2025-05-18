resource "kubernetes_deployment" "app" {
  metadata {
    name = "iamkeycheck-deployment-${var.stage}-${var.image_tag}"
    namespace = var.namespace
    labels = { app = "iamkeycheck-${var.stage}-${var.image_tag}" }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "iamkeycheck-${var.stage}-${var.image_tag}" }
    }

    template {
      metadata {
        name = "iamkeycheck-${var.stage}-${var.image_tag}"
        labels = { app = "iamkeycheck-${var.stage}-${var.image_tag}" }
      }

      spec {
        container {
          name  = "iamkeycheck"
          image = "iamkeycheck:${var.stage}-${var.image_tag}"
          image_pull_policy = "Never"

          port {
            container_port = 8000
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 2
            period_seconds        = 5
            failure_threshold     = 3
            success_threshold     = 1
            timeout_seconds       = 2
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            failure_threshold     = 5
            success_threshold     = 1
            timeout_seconds       = 2
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
