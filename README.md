# FleetDM Local Kubernetes Deployment

Deploy FleetDM with MySQL and Redis on a local Kind cluster using Helm.

## Prerequisites

```bash
brew install kind kubectl helm
```

Docker Desktop must be running.

## Usage

```bash
make cluster     # Create local Kind cluster
make install     # Install FleetDM Helm chart
make uninstall   # Remove all resources and delete cluster
```

After install, access FleetDM UI:

```bash
make port-forward
# Open http://localhost:8080
```

## Verification

Check all components are running:

```bash
kubectl get pods -n fleet
```

All pods should be in `Running` state:

```
fleet-<id>           1/1     Running   0     3m
fleet-mysql-0        1/1     Running   0     3m
fleet-valkey-<id>    1/1     Running   0     3m
```

Verify FleetDM:

```bash
kubectl port-forward svc/fleet-service 8080:8080 -n fleet &
curl -s http://localhost:8080/healthz
```

Verify MySQL:

```bash
kubectl exec -it fleet-mysql-0 -n fleet -- mysqladmin ping -u fleet -pfleetdm-pass
```

Verify Redis (Valkey):

```bash
kubectl exec -it deploy/fleet-valkey -n fleet -- valkey-cli ping
```

## Architecture

- **FleetDM Server** — device management platform (port 8080, TLS disabled for local dev)
- **MySQL 8.4** — primary database (subchart)
- **Valkey (Redis-compatible)** — cache layer (subchart)

### Database Migrations

`fleet prepare db --no-prompt` runs automatically as an initContainer before the Fleet server starts. The pod startup sequence:

1. `wait-for-mysql` — waits for MySQL to accept connections
2. `wait-for-redis` — waits for Valkey to accept connections
3. `run-migrations` — executes `fleet prepare db --no-prompt`
4. `fleet serve` — starts only after all above succeed

## Agent Connectivity

FleetDM is exposed via `kubectl port-forward` on `http://localhost:8080`.
Osquery agents on the host can enroll using this URL as the Fleet server address.

## Helm Chart Registry (CI)

On every push to `main` that changes the chart, CI automatically lints and publishes a new version to GHCR:

```bash
helm install fleet oci://ghcr.io/vasylk1t/flamingo-test/fleet \
  --namespace fleet --values values-local.yaml
```

## Teardown

```bash
make uninstall
```
