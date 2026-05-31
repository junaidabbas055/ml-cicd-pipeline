# OpenStack Infrastructure Automation

OpenStack private cloud automation platform featuring Terraform modules (Nova, Neutron, Keystone), Pulumi Python IaC, Ansible configuration management, VM rightsizing & auto-scaling, FluxCD GitOps, and Azure Sentinel SIEM integration via PowerShell.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GitHub Actions                              │
│  terraform-plan (PR) · ansible-lint (PR) · sentinel-sync (cron)   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
┌─────────────────────────┐   ┌─────────────────────────────────────┐
│   Terraform / Pulumi    │   │   Azure Sentinel (SIEM)             │
│                         │   │   ← PowerShell sentinel-sync.ps1   │
│   OpenStack Private     │   │   ← Nova/Keystone audit events     │
│   Cloud (Lufthansa-     │   │   ← 15-min scheduled ingestion     │
│   style)                │   └─────────────────────────────────────┘
│                         │
│  ┌─────────┐ ┌────────┐ │
│  │Keystone │ │Neutron │ │
│  │Identity │ │Network │ │
│  └─────────┘ └────────┘ │
│  ┌─────────────────────┐ │
│  │  Nova Compute       │ │
│  │  m1.medium × 2 app  │ │
│  │  m1.large  × 1 db   │ │
│  │  Anti-affinity SG   │ │
│  └─────────────────────┘ │
└────────────┬────────────┘
             │ Ansible post-provisioning
             ▼
┌────────────────────────────────────────────┐
│  VM Configuration (Ansible)                │
│  ├── openstack-vm: NTP, rsyslog→ELK, mount│
│  ├── vm-rightsizing: collect-metrics.sh   │
│  │                   auto-scale-check.sh  │
│  └── vm-cost-report.py: savings report    │
└────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────┐
│  FluxCD GitOps (Kubernetes on OpenStack)   │
│  ├── clusters/dev  → apps/dev              │
│  ├── clusters/prod → apps/prod             │
│  └── Image Automation: auto-update tags    │
└────────────────────────────────────────────┘
```

## Repository Structure

```
.
├── terraform/
│   ├── modules/
│   │   ├── compute/       # Nova instances, anti-affinity, block volumes
│   │   ├── network/       # Neutron networks, subnets, routers, security groups
│   │   └── identity/      # Keystone projects, users, roles, assignments
│   └── environments/
│       ├── dev/           # Dev environment root module
│       └── prod/          # Prod environment root module
├── pulumi/
│   └── __main__.py        # Same infra as Terraform — Pulumi Python SDK
├── ansible/
│   ├── roles/
│   │   ├── openstack-vm/        # Base config: NTP, rsyslog→ELK, volume mount
│   │   ├── vm-rightsizing/      # collect-metrics.sh + auto-scale-check.sh
│   │   └── docker-setup/        # Docker CE (reusable)
│   ├── inventory/               # dev.ini / prod.ini
│   └── group_vars/all.yml
├── fluxcd/
│   ├── clusters/
│   │   ├── dev/flux-system.yaml
│   │   └── prod/flux-system.yaml
│   └── apps/
│       └── dev/                 # Kustomization, Deployment, Image Automation
├── scripts/
│   ├── sentinel-sync.ps1        # OpenStack → Azure Sentinel log ingestion
│   └── vm-cost-report.py        # Cost & rightsizing savings report
└── .github/workflows/
    ├── terraform-plan.yml       # Validate on PR
    ├── ansible-lint.yml         # Lint + Trivy + PSScriptAnalyzer
    └── sentinel-sync.yml        # Sentinel sync every 15 minutes
```

## Quick Start

### 1. Configure OpenStack credentials

```bash
# ~/.config/openstack/clouds.yaml
clouds:
  devcloud:
    auth:
      auth_url: http://controller:5000/v3
      username: admin
      password: your-password
      project_name: admin
      user_domain_name: Default
      project_domain_name: Default
    region_name: RegionOne
```

### 2. Provision with Terraform

```bash
cd terraform/environments/dev
terraform init
terraform plan -var="key_pair=my-keypair" -var="cicd_bot_password=secret"
terraform apply
```

### 3. Provision with Pulumi (alternative)

```bash
cd pulumi
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
pulumi stack init dev
pulumi config set keyPair my-keypair
pulumi up
```

### 4. Configure VMs with Ansible

```bash
cd ansible
ansible-playbook -i inventory/dev.ini playbook-configure.yml
```

### 5. Bootstrap FluxCD

```bash
flux bootstrap github \
  --owner=junaidabbas055 \
  --repository=openstack-infra-automation \
  --branch=main \
  --path=fluxcd/clusters/dev \
  --personal
```

### 6. VM Cost Report

```bash
export OS_AUTH_URL OS_USERNAME OS_PASSWORD OS_PROJECT_NAME
python3 scripts/vm-cost-report.py --output table
```

### 7. Azure Sentinel Sync

```powershell
./scripts/sentinel-sync.ps1 `
    -OpenStackAuthUrl        "http://controller:5000/v3" `
    -LogAnalyticsWorkspaceId "your-workspace-id" `
    -LogAnalyticsKey         "your-key"
```

## GitHub Actions Secrets

| Secret | Description |
|---|---|
| `OS_AUTH_URL` | OpenStack Keystone endpoint |
| `OS_USERNAME` | OpenStack admin username |
| `OS_PASSWORD` | OpenStack admin password |
| `OS_PROJECT_NAME` | OpenStack project |
| `LOG_ANALYTICS_WORKSPACE_ID` | Azure Log Analytics workspace ID |
| `LOG_ANALYTICS_KEY` | Azure Log Analytics shared key |

## CV Mapping

| CV Experience | What's in this project |
|---|---|
| OpenStack (Keystone, Nova, Neutron) | Terraform modules + Pulumi stack |
| VM rightsizing → −30% compute costs | Ansible role + Python cost report |
| Azure Sentinel SIEM | PowerShell sentinel-sync.ps1 |
| FluxCD GitOps | clusters/ + apps/ with Image Automation |
| Pulumi (basic) | Complete Python Pulumi stack |
| PowerShell | Full PS script with HMAC auth |
| GitHub Actions | 3 workflows: plan, lint, sentinel-sync |

## License

MIT
