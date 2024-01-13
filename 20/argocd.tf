# Helm chart resource for ArgoCD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.52.0"
  timeout          = 600

  values = [
    file("${path.module}/values/argocd.yaml"),
  ]
}

# Helm chart to deploy argo root application
resource "helm_release" "argocd-app" {
  name             = "argocd-app"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "argocd"
  version          = "1.4.1"
  timeout          = 600

  values = [
    file("${path.module}/values/argocd-app.yaml"),
  ]

  depends_on = [ helm_release.argocd ]
}