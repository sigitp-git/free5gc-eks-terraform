output "monitoring_namespace" {
  description = "Monitoring namespace"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "network_attachment_definitions" {
  description = "Network Attachment Definitions"
  value = {
    n3_1001 = kubernetes_manifest.nad_n3_1001.manifest.metadata.name
    n3_1002 = kubernetes_manifest.nad_n3_1002.manifest.metadata.name
  }
}
