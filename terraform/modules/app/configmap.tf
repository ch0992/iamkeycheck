resource "kubernetes_config_map" "app_config" {
  metadata {
    name = "iamkeycheck-config"
    namespace = var.namespace
  }
  data = {
    N_HOURS = tostring(var.n_hours)
  }
}
