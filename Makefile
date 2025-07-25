# ==== Configuration ====
MINIKUBE_PROFILE ?= up42-cluster
K8S_VERSION      ?= v1.32.0
CPUS            ?= 4
MEMORY          ?= 4096
DISK_SIZE       ?= 20g
DRIVER          ?= docker
TERRAFORM_DIR   ?= terraform
HELM_CHARTS_DIR ?= helm

# ==== CLI Tools ====
KUBECTL  = kubectl
MINIKUBE = minikube
TERRAFORM = terraform
HELM = helm

# ==== Targets ====
explain:
	@echo ""
	@echo "🎯 Makefile Targets Overview"
	@echo "============================"
	@echo "make up             # Launch full stack (Minikube, Helm validation, Terraform apply)"
	@echo "make down           # Tear down all components and clean environment"
	@echo "make start          # Start Minikube cluster"
	@echo "make addons         # Enable core Minikube addons"
	@echo "make ingress        # Enable and wait for Ingress Controller"
	@echo "make tunnel         # Start Minikube tunnel (requires sudo)"
	@echo "make tunnel-stop    # Stop Minikube tunnel"
	@echo "make status         # Show status of Minikube"
	@echo "make stop           # Stop the cluster"
	@echo "make delete         # Delete the cluster"
	@echo "make context        # Set kubectl context to Minikube"
	@echo "make helm-validate  # Validate Helm charts (deps, lint, template)"
	@echo "make tf-init        # Initialize Terraform"
	@echo "make tf-plan        # Show Terraform execution plan"
	@echo "make tf-apply       # Apply Terraform configuration"
	@echo "make tf-destroy     # Destroy Terraform-managed resources"
	@echo "make tf-refresh     # Refresh Terraform state"
	@echo "make logs           # Tail logs from s3www"
	@echo "make verify         # Check application availability via curl"
	@echo ""

.PHONY: all up down start addons ingress tunnel dashboard status \
        stop delete context tf-init tf-plan tf-apply tf-destroy tf-refresh \
        helm-validate helm-lint helm-template helm-deps \
        logs verify

# 🎯 Launch everything
up: start addons ingress tunnel helm-validate tf-init tf-apply verify
	@echo "✅ Cluster and application deployed successfully."

# 🔻 Destroy everything
down: tunnel-stop tf-destroy stop delete
	@echo "🧹 Full environment cleaned up."

# ==== Minikube Setup ====
start: ensure-profile
	@echo "🚀 Starting Minikube cluster: $(MINIKUBE_PROFILE)"
	$(MINIKUBE) start \
		--profile=$(MINIKUBE_PROFILE) \
		--kubernetes-version=$(K8S_VERSION) \
		--cpus=$(CPUS) \
		--memory=$(MEMORY) \
		--disk-size=$(DISK_SIZE) \
		--driver=$(DRIVER)

ensure-profile:
	@if ! $(MINIKUBE) profile list | grep -q "$(MINIKUBE_PROFILE)"; then \
		echo "🆕 Creating Minikube profile $(MINIKUBE_PROFILE)..."; \
	else \
		echo "🔁 Minikube profile $(MINIKUBE_PROFILE) already exists."; \
	fi


addons:
	@echo "🛠 Enabling core Minikube addons"
	$(MINIKUBE) addons enable metrics-server --profile=$(MINIKUBE_PROFILE)
	$(MINIKUBE) addons enable dashboard --profile=$(MINIKUBE_PROFILE)
	$(MINIKUBE) addons enable storage-provisioner --profile=$(MINIKUBE_PROFILE)
	$(MINIKUBE) addons enable registry --profile=$(MINIKUBE_PROFILE)

ingress:
	@echo "🌐 Enabling NGINX Ingress Controller"
	$(MINIKUBE) addons enable ingress --profile=$(MINIKUBE_PROFILE)
	@echo "⏳ Waiting for ingress controller to be ready..."
	$(KUBECTL) wait --namespace ingress-nginx \
		--for=condition=Ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=120s
tunnel:
	@echo "🔌 Starting minikube tunnel (requires sudo)"
	@echo "Note: Keep this terminal open as it runs in foreground."
	@sudo -v && sudo minikube tunnel --profile=$(MINIKUBE_PROFILE) &


# Stop minikube tunnel
tunnel-stop:
	@echo "🛑 Stopping minikube tunnel"
	@TUNNEL_PID=$$(pgrep -f "minikube tunnel.*--profile=$(MINIKUBE_PROFILE)"); \
	if [ -n "$$TUNNEL_PID" ]; then \
		echo "Found tunnel PID: $$TUNNEL_PID"; \
		sudo kill -9 $$TUNNEL_PID && echo "✅ Tunnel stopped (PID: $$TUNNEL_PID)"; \
	else \
		echo "⚠️  No active tunnel found for profile $(MINIKUBE_PROFILE)"; \
	fi


dashboard:
	$(MINIKUBE) dashboard --profile=$(MINIKUBE_PROFILE)

stop:
	$(MINIKUBE) stop --profile=$(MINIKUBE_PROFILE)

delete:
	$(MINIKUBE) delete --profile=$(MINIKUBE_PROFILE)

status:
	$(MINIKUBE) status --profile=$(MINIKUBE_PROFILE)

context:
	$(KUBECTL) config use-context $(MINIKUBE_PROFILE)

# ==== Helm Validations ====
helm-validate: helm-deps helm-lint helm-template
	@echo "✅ Helm charts validated."

helm-deps:
	@echo "🔧 Updating Helm dependencies"
	$(HELM) dependency update $(HELM_CHARTS_DIR)/s3www || true

helm-lint:
	@echo "🔍 Linting Helm charts"
	$(HELM) lint $(HELM_CHARTS_DIR)/s3www

helm-template:
	@echo "🔧 Rendering Helm templates"
	$(HELM) template test-render $(HELM_CHARTS_DIR)/s3www --debug

# ==== Terraform ====
tf-validate:
	cd $(TERRAFORM_DIR) && $(TERRAFORM) validate

tf-init:
	cd $(TERRAFORM_DIR) && $(TERRAFORM) init && $(TERRAFORM) validate

tf-plan:
	cd $(TERRAFORM_DIR) && $(TERRAFORM) plan

tf-apply:
	cd $(TERRAFORM_DIR) && $(TERRAFORM) apply -auto-approve

tf-destroy:
	cd $(TERRAFORM_DIR) && $(TERRAFORM) destroy -auto-approve

tf-refresh:
	cd $(TERRAFORM_DIR) && $(TERRAFORM) refresh
tf-output:
	cd $(TERRAFORM_DIR) && $(TERRAFORM) output
# ==== Utilities ====

verify:
	@echo "🔍 Verifying application availability..."
	curl -s -o /dev/null -w "%{http_code}\n" http://s3www.local | grep 200 > /dev/null \
	&& echo "✅ Application reachable at http://s3www.local" \
	|| echo "❌ Application not reachable at http://s3www.local"

logs:
	$(KUBECTL) logs -l app.kubernetes.io/name=s3www -n s3www -f

prometheus-url:
	@echo "🔎 Prometheus UI:"
	@echo "http://$$(minikube service -n monitoring prometheus-kube-prometheus-prometheus --url)"

prometheus-access:
	@echo "🌐 Starting port-forward to Prometheus UI (http://localhost:9090)"
	@kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090
# ==== Hosts ====
hosts:
	@echo "📝 Adding /etc/hosts entry for s3www.local"
	@grep -q "127.0.0.1 s3www.local" /etc/hosts || echo "127.0.0.1 s3www.local" | sudo tee -a /etc/hosts\
