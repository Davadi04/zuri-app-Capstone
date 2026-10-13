# Zuri Market — Backend

Node.js/Express REST API serving the Zuri Market product catalogue and cart validation. Forked from [Test-class2026/zuriapp-backend](https://github.com/Test-class2026/zuriapp-backend); platform hooks (health check, metrics) and security fixes added on top.

## Running locally

```bash
cp .env.example .env
npm install
npm start
```

Server runs on `http://localhost:5000` (set via `PORT`).

## Environment variables

| Variable | Purpose |
|---|---|
| `PORT` | Port to listen on (default `5000`) |
| `API_SECRET_KEY` | Required header value (`x-api-key`) for `/api/cart/validate` |
| `STORE_NAME` | Display name returned by `/api/store` |
| `ALLOWED_ORIGIN` | CORS-allowed origin (default `http://localhost:3000`) |

In production these are injected via a Kubernetes ConfigMap (`PORT`, `NODE_ENV`) and Secret (`API_SECRET_KEY`, `STORE_NAME`), synced from AWS Secrets Manager.

## Routes

| Route | Method | Notes |
|---|---|---|
| `/api/store` | GET | Store info |
| `/api/products` | GET | Product list |
| `/api/products/:id` | GET | Single product |
| `/api/cart/validate` | POST | Requires `x-api-key` header, returns `401` otherwise |
| `/api/health` | GET | Used by Kubernetes probes and the daily health check |
| `/metrics` | GET | Prometheus scrape target (not exposed publicly) |

## Scripts

```bash
npm run lint    # ESLint
npm test        # Node's built-in test runner — one smoke test on /api/health
npm run build   # n/a — plain Node, no build step
```

## Docker

Two-stage build: dependencies installed with `npm ci --ignore-scripts`, then a second stage strips npm itself out of the final image (see "Security notes" below).

```bash
docker build -t zuri-backend:local .
docker run -p 5000:5000 --env-file .env zuri-backend:local
```

## Security notes

- Runs as the non-root `node` user
- CORS restricted to a configured origin, not open by default (fixed after a SonarQube finding)
- `npm ci --ignore-scripts` during build, blocking arbitrary install-time scripts
- The final image has npm removed entirely — a Trivy scan found 10 HIGH-severity CVEs in npm's own bundled dependencies (not the app's own dependencies); since the container only ever runs `node server.js`, npm serves no purpose at runtime and was stripped from the final stage. Re-scan: 0 vulnerabilities.