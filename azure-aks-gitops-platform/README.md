# Azure AKS GitOps Platform

Production-ready AKS platform with Terraform IaC, ArgoCD GitOps, Prometheus/Grafana monitoring, CIS benchmark security hardening, and GitHub Actions CI/CD pipelines.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Actions                           │
│  terraform-plan (PR) → terraform-apply (merge) → security-scan │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Terraform OIDC
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Azure                                    │
│  Resource Group → VNet/NSG → AKS Cluster → Log Analytics       │
│                              ├── System Node Pool (3–6 nodes)  │
│                              └── Workload Node Pool (3–30)      │
└───────────────────────────┬─────────────────────────────────────┘
                            │ kubectl / Helm
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     AKS Cluster                                 │
│                                                                 │
│  ┌──────────────┐  ┌────────────────┐  ┌──────────────────┐   │
│  │    ArgoCD    │  │  kube-prom-    │  │   OPA Gatekeeper │   │
│  │  app-of-apps │  │  stack         │  │   CIS L2 Policies│   │
│  │  GitOps sync │  │  Prometheus +  │  │   Network Policies│  │
│  └──────┬───────┘  │  Grafana +     │  └──────────────────┘   │
│         │          │  Alertmanager  │                          │
│         ▼          └────────────────┘                          │
│  ┌──────────────────────────────────┐                          │
│  │   Application Namespaces         │                          │
│  │   myapp-dev / myapp-prod         │                          │
│  │   Helm golden-path chart         │                          │
│  │   HPA + PDB + Affinity rules     │                          │
│  └──────────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
.
├── terraform/
│   ├── modules/
│   │   ├── aks-cluster/     # AKS cluster, node pools, AAD RBAC
│   │   ├── networking/      # VNet, subnets, NSG, Log Analytics
│   │   └── monitoring/      # Azure Monitor alerts & action groups
│   └── environments/
│       ├── dev/             # Dev environment root module
│       └── prod/            # Prod environment root module
├── helm/
│   └── app-template/        # Golden-path Helm chart for microservices
├── argocd/
│   ├── install/             # ArgoCD config (OIDC, RBAC)
│   ├── apps/                # App-of-apps + per-environment apps
│   └── projects/            # ArgoCD AppProject with RBAC
├── monitoring/
│   ├── prometheus/
│   │   ├── values.yaml      # kube-prometheus-stack Helm values
│   │   └── alerts/          # PrometheusRule alert definitions
│   └── grafana/
│       └── dashboards/      # Grafana dashboard JSON
├── security/
│   ├── policies/            # Network policies + CIS/OPA constraints
│   └── rbac/                # Kubernetes RBAC roles & bindings
├── .github/workflows/
│   ├── terraform-plan.yml   # PR plan with comment posting
│   ├── terraform-apply.yml  # Auto-apply on merge (dev → prod gate)
│   └── security-scan.yml    # Trivy + tfsec + Checkov
└── scripts/
    ├── bootstrap.sh         # Fresh cluster bootstrap
    └── health-check.sh      # Platform health validation
```

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | >= 1.6 |
| kubectl | >= 1.29 |
| Helm | >= 3.14 |
| Azure CLI | >= 2.57 |

## Quick Start

### 1. Provision Infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform plan -var="alert_email=you@example.com"
terraform apply
```

### 2. Bootstrap the Cluster

```bash
az aks get-credentials --resource-group aks-platform-dev-rg --name aksdev-cluster
./scripts/bootstrap.sh ~/.kube/config dev
```

### 3. Deploy an Application

Create an ArgoCD Application pointing at the `helm/app-template` chart:

```bash
kubectl apply -f argocd/apps/dev-app.yaml
```

Or use the Helm chart directly:

```bash
helm upgrade --install myapp ./helm/app-template \
  --namespace myapp-dev --create-namespace \
  --set image.repository=myacr.azurecr.io/myapp \
  --set image.tag=1.0.0
```

### 4. Validate Platform Health

```bash
./scripts/health-check.sh myapp-dev
```

## GitHub Actions Setup

Required repository secrets:

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Service principal / managed identity client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID |

OIDC federated credentials must be configured on the app registration for the `main` branch and PR refs.

## Security Controls

- **CIS Level 2** — Enforced via Kubernetes Pod Security Standards (`restricted` profile) on all workload namespaces
- **OPA Gatekeeper** — Prevents missing resource limits, `latest` image tags, and missing probes
- **Network Policies** — Default deny-all with explicit allowlist per namespace
- **Azure Defender for Containers** — Enabled via `azure_policy_enabled = true` on AKS
- **Trivy + tfsec + Checkov** — IaC and manifest scanning on every PR and weekly schedule
- **Least-privilege RBAC** — Separate `developer-readonly` and `cicd-deployer` roles; `platform-admin` ClusterRole for break-glass only

## Monitoring

- Prometheus retention: 15 days / 40 GB
- Alert channels: Slack (`#platform-alerts`) + PagerDuty for critical
- Key alert rules: node CPU/memory/disk, pod crash-looping, OOMKilled, HPA maxed out, HTTP error rate > 5%, P99 latency > 2s
- Grafana SSO via Azure AD

## License

MIT
