# Helm chart for promtail
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.15.3"
  namespace  = "observability"

  values     = [file("${path.module}/values/promtail.yaml")]
  depends_on = [kubernetes_namespace.observability-namespace]
}