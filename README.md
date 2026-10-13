# Zuri Market — DevOps Capstone

A secure, automated, observable delivery platform for Zuri Market's e-commerce storefront, replacing manual SSH deployments with a Git-driven CI/CD pipeline.

## The problem

Zuri Market's engineering team deployed by SSHing into a server, running `git pull`, and restarting the app by hand. No automated testing, no security scanning, secrets committed to Git, and no monitoring beyond manually checking logs during an incident.

This project replaces that with: automated testing and security gates on every change, infrastructure defined as code, containerized services running on Kubernetes, secrets stored in AWS Secrets Manager (never in Git), and a daily automated health check.

## Architecture

Developer → Pull Request → GitHub Actions (lint, test, quality gate, Trivy scan)
↓
main branch (protected)
↓
Build, scan, push image → GHCR
↓
Terraform validates / applies infrastructure
↓
Deploy to Kubernetes (k3s on EC2) via AWS SSM
↓
Ingress → frontend (React/nginx) + backend (Node/Express)
↓
Prometheus + Grafana | daily health-check (cron)


See [`docs/architecture.md`](docs/architecture.md) for the full diagram.

## Repository structure

backend/ Node.js/Express API (forked from zuriapp-backend)
frontend/ React/Vite storefront (forked from zuriapp-frontend)
terraform/ Infrastructure as code (VPC, EC2, IAM, Secrets Manager)
k8s/ Kubernetes manifests (Deployments, Services, Ingress, RBAC)
scripts/ health-check.sh, sync-secrets.sh
.github/workflows/ ci-cd.yml — the full CI/CD pipeline
docs/ Architecture diagram, Jenkins comparison


Starter application code credit: [Test-class2026/zuriapp-backend](https://github.com/Test-class2026/zuriapp-backend) and [Test-class2026/zuriapp-frontend](https://github.com/Test-class2026/zuriapp-frontend).

## Running locally

```bash
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
docker compose up --build
```

Frontend: http://localhost:8080 · Backend: http://localhost:5000

## Running in the cloud

```bash
cd terraform/bootstrap && terraform init && terraform apply -var="region=us-east-1" -var="bucket_name=<your-bucket>"
cd ../environments/dev && terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

This provisions a VPC, security group (HTTP only, no SSH — access via AWS SSM Session Manager), IAM role, Secrets Manager container, and an EC2 instance running k3s (lightweight Kubernetes).

## CI/CD pipeline

One combined workflow (`.github/workflows/ci-cd.yml`), eight jobs:

| Job | Trigger | What it does |
|---|---|---|
| `backend-quality` / `frontend-quality` | PR & push | install, lint, test/build, SonarQube Cloud quality gate |
| `backend-image` / `frontend-image` | PR & push | Docker build, Trivy security scan, push to GHCR (push only) |
| `backend-deploy` / `frontend-deploy` | push to `main` | Deploy new image to Kubernetes via AWS SSM |
| `terraform-validate` | PR | `fmt`, `validate` |
| `terraform-apply` | push to `main` / manual | Apply infrastructure changes |

A pull request runs every check; only a merge to `main` publishes images and deploys.

## Security

- No root AWS credentials used anywhere; a least-privilege IAM user (`David`) with MFA, built from scratch after an early credential exposure was rotated immediately
- No SSH on the server; access only via AWS SSM Session Manager, every session logged
- Secrets live in AWS Secrets Manager, synced into a Kubernetes Secret at deploy time — never committed to Git
- SonarQube quality gate: found and fixed real issues (unrestricted CORS, unhandled promises, an accessibility gap) in both apps
- Trivy scan: found 10 HIGH vulnerabilities bundled inside npm's own tooling in the base image; removed npm entirely from the final backend image via a second Docker stage — re-scan confirmed zero vulnerabilities
- Third-party GitHub Actions (Trivy, SonarQube scanner) pinned to exact commit SHAs, not mutable version tags, after real supply-chain compromises were disclosed for both tools in 2026

## Monitoring

Prometheus + Grafana (`kube-prometheus-stack` via Helm), scraping backend metrics via a `ServiceMonitor`. Dashboard: request rate, error rate, latency — see `monitoring/dashboards/`.

## Daily health check

`scripts/health-check.sh` runs via cron at 06:00 UTC daily, appending one line per day to `/var/log/zuri/health-report.txt` on the server. See evidence in `docs/evidence/`.

## Jenkins vs GitHub Actions

See [`docs/jenkins-vs-github-actions.md`](docs/jenkins-vs-github-actions.md).

## One thing I'd do differently

The EC2 instance's public IP changes whenever Terraform replaces it (e.g. an AMI update). A production setup would sit this behind a stable DNS name or load balancer rather than relying on a raw IP for CORS/Ingress configuration.