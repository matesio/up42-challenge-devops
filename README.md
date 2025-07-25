# 📦 UP42 Cloud Challenge — `s3www` Deployment

This repository contains a production-grade deployment setup for the `s3www` application and its dependencies, using **Kubernetes**, **Helm**, and **Terraform**. The solution simulates a real-world infrastructure with observability, automation, and modular configurations.

---

## 🛡️ Architecture Overview

```
🌀 Minikube Cluster
|
|-- MinIO
|   |-- InitContainer (uploads .webp file)
|
|-- s3www (serves the file from MinIO)
|   |-- Ingress: s3www.local
|
|-- Prometheus Operator
|   |-- Blackbox Exporter (probes HTTP endpoints)
|   |-- ServiceMonitor & PrometheusRule
```

---

## 🚀 Getting Started

### 🔧 Prerequisites

- [Minikube](https://minikube.sigs.k8s.io/)
- [Terraform](https://www.terraform.io/)
- [Helm](https://helm.sh/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

### 🔨 Setup Instructions

```bash
# Clone the repo
$ git clone https://github.com/your-org/up42-cloud-challenge.git
$ cd up42-cloud-challenge

# Launch the system
$ make up
```

This will:

- Start a Minikube cluster
- Enable required addons
- Validate Helm charts
- Apply Terraform modules
- Setup Prometheus, MinIO, Blackbox Exporter, and s3www
- Expose s3www over Ingress on [http://s3www.local](http://s3www.local)

---

## 📂 Project Structure

```
.
├── helm/
│   └── s3www/          # Helm chart for s3www
├── terraform/          # Terraform configs
│   └── monitoring-manifests/
├── Makefile            # Orchestrates full lifecycle
├── README.md
└── CHALLENGE.md        # Solution write-up
```

---

## ⚙️ Configuration

### values.yaml for `s3www`

```yaml
s3www:
  image:
    repository: y4m4/s3www
    tag: latest  # <- Use your local image instead of pulling remotely
  port: 8080
  ingressPort: 80
  ingress:
    enabled: true
    hostname: s3www.local
  args:
    - "-endpoint=http://s3www-minio.s3www.svc.cluster.local:9000"
    - "-accessKey=minioadmin"
    - "-secretKey=minioadmin"
    - "-bucket=my-bucket"
    - "-address=0.0.0.0:8080"

fileToServe:
  name: VdiQKDAguhDSi37gn1.webp
  url: https://media.giphy.com/media/VdiQKDAguhDSi37gn1/giphy.gif
  bucket: my-bucket

minio:
  auth:
    rootUser: minioadmin
    rootPassword: minioadmin
  defaultBuckets: "my-bucket"
  persistence:
    enabled: false
monitoring:
  serviceMonitor:
    enabled: true
```

---

## 🧩 Verification

```bash
# Validate s3www response
make verify
# Access logs
make logs

# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090
```

---

## 🔄 Cleanup

```bash
make down         # Destroy infrastructure
make tunnel-stop  # Stop minikube tunnel
```

---

## 🧰 Operational Overview

| Component         | Description                                                   |
| ----------------- | ------------------------------------------------------------- |
| Ingress           | NGINX-based Ingress on `s3www.local`                          |
| File Upload       | Handled in `initContainer` via `curl` and `mc` CLI            |
| Prometheus        | Deployed via Terraform Helm Provider                          |
| Blackbox Exporter | Probes HTTP endpoint `/` of s3www for availability monitoring |
| Metrics           | Scraped via ServiceMonitor, displayed in Prometheus UI        |
| Alerts            | Triggered via PrometheusRule on `probe_success == 0`          |

---

