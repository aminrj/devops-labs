# Install the Kubescape Helm chart
resource "helm_release" "kubescape" {
  name       = "kubescape"
  repository = "https://kubescape.github.io/helm-charts"
  chart      = "kubescape-operator"
  version    = "1.18.3"
  namespace  = "kubescape"
  create_namespace = true

  values     = [file("${path.module}/values/kubescape.yaml")]
  depends_on = [kubernetes_namespace.observability-namespace]

}