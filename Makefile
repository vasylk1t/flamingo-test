CLUSTER_NAME    := fleetdm-flamingo-local
NAMESPACE       := fleet
RELEASE_NAME    := fleet
CHART_PATH      := ./fleet
CHART_REGISTRY  := oci://ghcr.io/vasylk1t/flamingo-test/fleet
CHART_VERSION   := 1.0.0
VALUES_FILE     := values-local.yaml
KIND_CONFIG     := kind-config.yaml

.PHONY: cluster install install-remote uninstall port-forward status help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

cluster: ## Create local Kind cluster
	@if kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "Cluster '$(CLUSTER_NAME)' already exists"; \
	else \
		echo "Creating Kind cluster '$(CLUSTER_NAME)'..."; \
		kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG) --wait 60s; \
	fi
	@kubectl cluster-info --context kind-$(CLUSTER_NAME)

install: cluster ## Install from local chart (default)
	@helm repo add valkey https://valkey.io/valkey-helm/ 2>/dev/null || true
	@helm dependency build $(CHART_PATH)
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		--values $(VALUES_FILE) \
		--wait \
		--timeout 10m
	@echo ""
	@echo "FleetDM deployed. Run 'make port-forward' to access UI at http://localhost:8080"

install-remote: cluster ## Install from GHCR (use CHART_VERSION=<tag>)
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install $(RELEASE_NAME) $(CHART_REGISTRY) \
		--version $(CHART_VERSION) \
		--namespace $(NAMESPACE) \
		--values $(VALUES_FILE) \
		--wait \
		--timeout 10m
	@echo ""
	@echo "FleetDM deployed ($(CHART_VERSION)). Run 'make port-forward' to access UI at http://localhost:8080"

uninstall: ## Remove all deployed resources
	@if helm status $(RELEASE_NAME) -n $(NAMESPACE) >/dev/null 2>&1; then \
		helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE); \
	fi
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found 2>/dev/null || true
	@if kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		kind delete cluster --name $(CLUSTER_NAME); \
	fi
	@echo "All resources removed."

port-forward: ## Forward FleetDM to http://localhost:8080
	kubectl port-forward svc/fleet-service 8080:8080 -n $(NAMESPACE)

status: ## Show pod status
	@kubectl get pods,svc,jobs -n $(NAMESPACE)
