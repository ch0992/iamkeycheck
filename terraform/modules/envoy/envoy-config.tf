resource "kubernetes_config_map" "envoy_config" {
  metadata {
    name = "envoy-config"
    namespace = var.namespace
  }
  data = {
    "envoy.yaml" = <<EOF
static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address: { address: 0.0.0.0, port_value: 8080 }
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          route_config:
            name: local_route
            virtual_hosts:
            - name: backend
              domains: ["*"]
              routes:
              - match: { prefix: "/" }
                route: { cluster: app_service }
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
  clusters:
  - name: app_service
    connect_timeout: 0.25s
    type: logical_dns
    lb_policy: round_robin
    load_assignment:
      cluster_name: app_service
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: iamkeycheck-service
                port_value: 8000
EOF
  }
}
