# Create static ip.
resource "google_compute_global_address" "ip_address" {
  name = "web-static-ip"
}

# Create ssl policy.
resource "google_compute_ssl_policy" "ssl-policy" {
  name            = "gke-ingress-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}
