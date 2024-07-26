# Create a namespace for observability
resource "kubernetes_namespace" "kafka-namespace" {
  metadata {
    name = "kafka"
  }
}

# Create a namespace for observability
resource "kubernetes_namespace" "observability-namespace" {
  metadata {
    name = "observability"
  }
}