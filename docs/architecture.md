# Architecture

## The problem, in four parts

Zuri Market deployed by SSHing into a server, running `git pull`, and restarting the app by hand — no automated testing, no security scanning, secrets committed to Git and pasted into Slack, and no monitoring beyond manually checking logs during an incident. This platform replaces all four failures with one connected, automated system.

## End-to-end flow

  Developer
      |
      v  git push (feature branch)
  Pull Request into main
      |
      v  GitHub Actions: lint, test, SonarQube gate, Trivy scan
  Review comment + merge
      |
      v
  main branch (protected, no direct pushes)
      |
      +----------------------------+
      |                            |
      v                            v
  Build Docker image       terraform/ changed?
      |                       /         \
      v                     yes          no
  Trivy security scan        |         (skipped)
      |                      v
      v                 Terraform apply
  Push to GHCR          (infrastructure)
  (tagged by SHA)             |
      |                       |
      v                       v
  Deploy via AWS SSM --> EC2 instance (k3s / Kubernetes)
      |                       |
      v                       v
  ===================================================
                AWS  —  eu-west-2 / VPC
  ===================================================
  EC2 instance:
    Traefik Ingress
      |-- "/"     --> Frontend Deployment (React + nginx)
      |-- "/api"  --> Backend Deployment  (Node + Express)
    Frontend --> relative /api/* calls --> Ingress --> Backend

    Prometheus --> scrapes /metrics --> Backend
    Grafana    --> queries --> Prometheus
    cron (health-check.sh, daily 06:00 UTC) --> checks / and /api/health

  AWS Secrets Manager --> synced at deploy time --> Backend
  IAM role (SSM + read one secret only) --> assumed by --> EC2

  Customer --> HTTP port 80 (no SSH anywhere) --> Ingress
  You --> AWS SSM Session Manager (no SSH key, every session logged) --> EC2
flowchart TD
    Dev[Developer] -->|git push, feature branch| PR[Pull Request into main]
    PR --> CI[GitHub Actions: lint, test,<br/>SonarQube quality gate, Trivy scan]
    CI -->|checks pass| Review[Review comment + merge]
    Review --> Main[main branch<br/>protected, no direct pushes]

    Main --> Build[Build Docker image]
    Build --> Scan[Trivy security scan]
    Scan --> GHCR[(Push to GHCR<br/>tagged by commit SHA)]

    Main --> TFCheck{terraform/ changed?}
    TFCheck -->|yes| TFApply[Terraform apply<br/>infrastructure]
    TFCheck -->|no| Skip[Skipped]

    GHCR --> Deploy[Deploy via AWS SSM<br/>kubectl set image]
    TFApply -.provisions.-> EC2

    subgraph AWS["AWS — eu-west-2"]
        subgraph VPC["VPC"]
            subgraph EC2["EC2 instance — k3s (Kubernetes)"]
                Ingress[Traefik Ingress]
                Frontend[Frontend Deployment<br/>React + nginx]
                Backend[Backend Deployment<br/>Node + Express]
                Prom[Prometheus]
                Graf[Grafana]
                Cron[cron: health-check.sh<br/>daily, 06:00 UTC]
            end
        end
        SM[(AWS Secrets Manager)]
        IAM[IAM role<br/>SSM + read one secret only]
    end

    Deploy --> Ingress
    Ingress -->|/| Frontend
    Ingress -->|/api| Backend
    Frontend -->|/api/*, relative path| Ingress
    SM -.synced via sync-secrets.sh.-> Backend
    IAM -.assumed by.-> EC2
    Prom -->|scrapes /metrics| Backend
    Graf -->|queries| Prom
    Cron -->|curl /api/health, /| Ingress

    User[Customer] -->|HTTP 80, no SSH anywhere| Ingress
    Admin[You] -.AWS SSM Session Manager,<br/>no SSH key, every session logged.-> EC2
```

## Repository layout

zuri-app-Capstone/
├── backend/ Node.js/Express API
├── frontend/ React/Vite storefront
├── terraform/
│ ├── bootstrap/ S3 state bucket (run once)
│ ├── modules/ network, security, compute, secrets
│ └── environments/dev/ wires modules together, dev.tfvars
├── k8s/
│ ├── namespace.yaml
│ ├── ingress.yaml
│ ├── backend/ deployment, service, configmap, servicemonitor
│ └── frontend/ deployment, service, configmap
├── scripts/
│ ├── health-check.sh daily cron job, appends to health-report.txt
│ └── sync-secrets.sh AWS Secrets Manager → Kubernetes Secret
├── monitoring/dashboards/ exported Grafana dashboard JSON
├── docs/ this file, Jenkins comparison, evidence
└── .github/workflows/ci-cd.yml the pipeline above, as code


## Design decisions worth explaining

| Decision | Reason |
|---|---|
| One repo, two app folders | A 3-developer team doesn't need the coordination overhead of separate repos |
| No SSH anywhere, SSM only | Zuri's brief specifically names "nobody can confirm who holds SSH access" as a problem; this makes it structurally impossible to recur |
| Secrets in AWS Secrets Manager, synced at deploy time | Never written to Git, never pasted anywhere; matches Zuri's exact `.env`-in-Git failure |
| Image tagged by commit SHA, not just `latest` | Makes rollback and "what's actually running" answerable |
| `terraform-apply` auto-runs only when `terraform/` changes | A code-only merge should never risk rebuilding live infrastructure |
| AMI pinned to a specific ID, not "always latest" | AWS publishing a routine AMI update previously triggered a silent, unplanned instance replacement — pinning stopped it |
| npm stripped from the final backend image | Trivy found 10 HIGH CVEs living in npm's own bundled tooling, not the app's dependencies; since the container never calls npm at runtime, it was removed entirely |

## What I'd do differently with more time

The EC2 instance's public IP changes whenever Terraform replaces it. A production setup would sit this behind a stable DNS name or an Application Load Balancer, rather than relying on a raw IP for CORS, Ingress, and SSM targeting.