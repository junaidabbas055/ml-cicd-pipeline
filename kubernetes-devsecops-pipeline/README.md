# Kubernetes DevSecOps Pipeline

End-to-end DevSecOps platform featuring Jenkins CI/CD, Ansible server hardening (CIS Level 2), ELK centralised logging, Docker multi-stage builds, Trivy security scanning, and Kubernetes deployment manifests.

## Architecture

```
Developer Push
      |
      v
Jenkins Pipeline (Kubernetes agent pods)
  |-- Build:         Docker multi-stage image
  |-- SAST:          Trivy filesystem scan
  |-- Container Scan: Trivy image scan (blocks on CRITICAL/HIGH)
  |-- Push:          ACR registry (main/release branches)
  |-- Deploy Dev:    kubectl rollout (automatic)
  |-- Smoke Test:    in-cluster curl health check
  |-- Deploy Prod:   manual approval gate
      |
      v
AKS Cluster
  |-- jenkins/       Jenkins StatefulSet + RBAC
  |-- logging/       Elasticsearch + Logstash + Kibana + Filebeat
  |-- myapp-dev/     Application workloads
  |-- myapp-prod/    Application workloads (prod)

Ansible (runs from Jenkins infra pipeline)
  |-- common-hardening/   CIS L2: SSH, kernel, auditd, UFW, fail2ban, AIDE
  |-- elk-stack/          ELK via Docker Compose on VMs
  |-- docker-setup/       Docker CE installation
```

## Repository Structure

```
.
├── jenkins/
│   ├── pipelines/
│   │   ├── Jenkinsfile          # App CI/CD pipeline
│   │   └── Jenkinsfile.infra    # Ansible/infra pipeline
│   └── shared-libs/vars/        # Shared Groovy library steps
├── ansible/
│   ├── roles/
│   │   ├── common-hardening/    # CIS L2: SSH, kernel, auditd, UFW, fail2ban
│   │   ├── elk-stack/           # ELK via Docker Compose
│   │   └── docker-setup/        # Docker CE install (RHEL + Ubuntu)
│   ├── inventory/               # Dev and prod inventories
│   ├── group_vars/              # Shared variables
│   └── playbook-*.yml           # Top-level playbooks
├── docker/
│   └── app/
│       └── Dockerfile           # Multi-stage, non-root, OCI-labelled
├── kubernetes/
│   ├── jenkins/                 # Jenkins StatefulSet, RBAC, Ingress
│   └── elk/                     # Elasticsearch, Logstash, Kibana manifests
└── scripts/
    ├── setup-jenkins.sh
    ├── deploy-elk.sh
    └── run-hardening.sh
```

## Prerequisites

| Tool | Version |
|------|---------|
| kubectl | >= 1.29 |
| Ansible | >= 2.15 |
| Docker | >= 24.0 |
| Python | >= 3.10 |

## Quick Start

### 1. Deploy Jenkins to AKS

```bash
az aks get-credentials --resource-group <rg> --name <cluster>
./scripts/setup-jenkins.sh ~/.kube/config
```

### 2. Deploy ELK Stack

```bash
./scripts/deploy-elk.sh ~/.kube/config <your-elastic-password>
```

### 3. Harden Servers with Ansible

```bash
# Dry run first
./scripts/run-hardening.sh dev --check

# Apply
./scripts/run-hardening.sh dev
```

### 4. Configure Jenkins Pipeline

In Jenkins → New Item → Pipeline → point to this repo's `jenkins/pipelines/Jenkinsfile`.

Required Jenkins credentials:

| Credential ID | Type | Description |
|---|---|---|
| `acr-credentials` | Username/Password | Azure Container Registry |
| `kubeconfig-dev` | Secret file | Dev cluster kubeconfig |
| `kubeconfig-prod` | Secret file | Prod cluster kubeconfig |
| `ssh-key-dev` | SSH private key | Dev server access |
| `ssh-key-prod` | SSH private key | Prod server access |

## Security Controls

- **CIS Level 2** — SSH hardening, kernel params, auditd rules, UFW firewall, fail2ban, AIDE
- **Trivy** — Blocks pipeline on CRITICAL/HIGH CVEs in both source code and container image
- **Non-root containers** — All Docker images run as UID 1000, read-only root filesystem
- **Kubernetes Pod Security** — `restricted` PSS enforced on all namespaces
- **Docker daemon hardening** — `no-new-privileges`, limited log retention, live-restore

## ELK Logging

- Filebeat ships container logs from all nodes to Logstash
- Logstash parses JSON app logs, enriches with GeoIP, drops health-check noise
- Kibana index patterns: `app-logs-*`, `system-logs-*`, `jenkins-*`
- Access Kibana at: `http://kibana.example.com`

## Jenkins Pipeline Stages

```
Checkout → Build Image → SAST Scan → Container Scan → Push → Deploy Dev → Smoke Test → [Deploy Prod*]
                                           |
                              Blocks on CRITICAL/HIGH CVEs
                                        * = manual approval
```

## License

MIT
