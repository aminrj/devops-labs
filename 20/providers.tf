# Define the helm provider with minikube setup
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
