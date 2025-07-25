output "prometheus_release" {
  value       = helm_release.prometheus.name
  description = "Helm release name for Prometheus stack"
}

output "blackbox_exporter_release" {
  value       = helm_release.blackbox_exporter.name
  description = "Helm release name for Blackbox Exporter"
}

output "s3www_release" {
  value       = helm_release.s3www.name
  description = "Helm release name for the s3www app"
}

output "prometheus_namespace" {
  value       = helm_release.prometheus.namespace
  description = "Namespace where Prometheus stack is deployed"
}

output "blackbox_exporter_namespace" {
  value       = helm_release.blackbox_exporter.namespace
  description = "Namespace where Blackbox Exporter is deployed"
}

output "s3www_namespace" {
  value       = helm_release.s3www.namespace
  description = "Namespace where s3www is deployed"
}

output "s3www_service_url" {
  value       = "http://s3www.local"
  description = "Expected URL for accessing the s3www app via Ingress (update /etc/hosts)"
}

output "prometheus_ui" {
  value       = "http://localhost:9090"
  description = "Port-forward Prometheus with: kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090"
}

output "grafana_ui" {
  value       = "http://localhost:3000"
  description = "Port-forward Grafana with: kubectl port-forward svc/prometheus-grafana -n monitoring 3000"
}
