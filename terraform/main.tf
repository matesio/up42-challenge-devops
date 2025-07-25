provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "up42-cluster"
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "up42-cluster"
  }
}

resource "helm_release" "prometheus" {
  name             = "prometheus"
  namespace        = "monitoring"
  create_namespace = true

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "75.13.0"
}

resource "null_resource" "wait_for_prometheus_crds" {
  provisioner "local-exec" {
    command = <<EOT
      echo "⏳ Waiting for Prometheus CRDs..."

      for i in {1..30}; do
        kubectl get crd servicemonitors.monitoring.coreos.com prometheusrules.monitoring.coreos.com >/dev/null 2>&1 && break
        echo "Waiting..."
        sleep 5
      done
    EOT
  }

  depends_on = [helm_release.prometheus]
}

resource "helm_release" "blackbox_exporter" {
  name       = "blackbox-exporter"
  namespace  = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-blackbox-exporter"
  version    = "11.1.1"

  values = [file("${path.module}/../values/blackbox-exporter.yaml")]

  depends_on = [null_resource.wait_for_prometheus_crds]
}

resource "helm_release" "s3www" {
  name             = "s3www"
  namespace        = "s3www"
  create_namespace = true
  chart            = "${path.module}/../helm/s3www"

  # Optionally enable monitoring via values.yaml:
  # values = [file("${path.module}/values/s3www.yaml")]

  depends_on = [null_resource.wait_for_prometheus_crds]
}
