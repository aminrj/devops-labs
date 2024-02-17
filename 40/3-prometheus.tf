# Helm chart for Prometheus
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "25.8.2"
  namespace  = "observability"

  values     = [file("${path.module}/values/prometheus.yaml")]
  depends_on = [kubernetes_namespace.observability-namespace]
}