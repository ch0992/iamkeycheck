resource "kubernetes_config_map" "app_config" {
  metadata {
    name = "iamkeycheck-config"
    namespace = var.namespace
  }
  data = {
    N_HOURS   = tostring(var.n_hours)
    LOG_LEVEL = var.log_level
    CSV_PATH  = var.csv_path
    IMAGE_TAG = var.image_tag
  }
}
