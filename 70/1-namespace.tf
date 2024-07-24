# Create a namespace for observability
resource "kubernetes_namespace" "kafka-namespace" {
  metadata {
    name = "kafka"
  }
}