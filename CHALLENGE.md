# CHALLENGE.md

## 🧠 Design Decisions & Reasoning

### 🧱 Tooling & Stack

- **Terraform**: Manages all infrastructure resources, ensuring reproducibility and state tracking.
- **Helm**: Used for deploying Kubernetes manifests via reusable, layered `values.yaml` configs.
- **Minikube**: Provides a production-like local Kubernetes cluster with `Ingress` and `LoadBalancer` simulation.

### ⚙️ Modular Setup

- Terraform deploys Prometheus Operator, Blackbox Exporter, and `s3www` in a dependency-respecting order.
- Helm charts are isolated per component and configured cleanly for overrides and customization.

### 🧾 File Upload Logic

- A Helm-based `initContainer` uploads the static `.webp` file to MinIO at startup using `mc`.
- The upload logic uses a retry loop to ensure MinIO is reachable before continuing.

### 📈 Monitoring

- Deployed **Prometheus Operator** via Terraform-managed Helm release.
- Used **Blackbox Exporter** to probe `s3www`'s HTTP endpoint, since the app lacks native `/metrics`.
- Alerts via `PrometheusRule` are triggered if probes fail (`probe_success == 0`).

### 🌐 Ingress

- Enabled `nginx` Ingress via Minikube addons.
- Exposed the application via `http://s3www.local` and handled traffic using `minikube tunnel`.

---

## ⚖️ Trade-offs

| Area            | Decision                     | Trade-off                                                |
|-----------------|------------------------------|-----------------------------------------------------------|
| Metrics         | Blackbox Exporter            | No internal app metrics — only HTTP availability          |
| File Upload     | InitContainer using `mc`     | Simpler than a custom uploader, but retry logic is basic  |
| Observability   | Alert on HTTP failure only   | No detailed telemetry due to lack of native metrics       |
| Infra Provision | Terraform + `local-exec` wait | Adds complexity to ensure CRDs are available in time     |

---

## ⚠️ Known Limitations

- `s3www` lacks native Prometheus metrics support.
- Naive retry logic for MinIO availability.
- No HTTPS; Ingress is HTTP-only.
- Secrets like MinIO credentials are hardcoded.
- RBAC and Pod Security Policies (PSP) are not enforced.

---

## 🚀 Improvements

- Replace the retry loop with readiness/liveness probe-driven logic.
- Use a `Job` instead of an `initContainer` for file uploads.
- Add HTTPS support using cert-manager and Let's Encrypt.
- Externalize secrets using Kubernetes Secret or external secret managers.
- Add monitoring probes for MinIO health and bucket status.

---

## 🔐 Security, ⚖️ Scalability, 📈 Observability

### Security

- Secrets like `minioadmin` are embedded and not rotated.
- No access control or TLS configuration.
- Anonymous access to the bucket is enabled (insecure for production).

### Scalability

- Single replica only — can scale horizontally with probes.
- MinIO is ephemeral (no persistence); not production-grade.
- Horizontal scaling possible with minimal chart changes.

### Observability

| Metric Source         | Integration                                                             |
|-----------------------|--------------------------------------------------------------------------|
| `HTTP Availability`   | Blackbox Exporter + `ServiceMonitor`                                     |
| `Custom App Metrics`  | ❌ Not available (`s3www` lacks `/metrics`)                              |
| `Alerts`              | `PrometheusRule` triggers on `probe_success == 0` for 1 min             |
| `Blackbox Exporter`   | Configured via Helm, targets `s3www` ingress endpoint                   |

---

## 🧠 Final Thoughts

The current implementation simulates a production-grade environment using standard tooling (Terraform, Helm, Minikube). Blackbox monitoring acts as a viable fallback given the application’s limitations. For a real-world setup, further enhancements in secrets handling, TLS, and metrics exposure would be essential.
