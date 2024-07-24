# Helm chart for Strimzi Kafka
resource "helm_release" "strimzi-cluster-operator" {
  name = "strimzi-cluster-operator"  
  repository = "https://strimzi.io/charts/"
  chart = "strimzi-kafka-operator"
  version = "0.42.0"
  namespace = kubernetes_namespace.kafka-namespace.metadata[0].name
#   values = [file("${path.module}/values/kafka.yaml")]
  depends_on = [kubernetes_namespace.kafka-namespace]
}