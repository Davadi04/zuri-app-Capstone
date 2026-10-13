# Zuri Market — Frontend

React (Vite) storefront consuming the backend API. Forked from [Test-class2026/zuriapp-frontend](https://github.com/Test-class2026/zuriapp-frontend); accessibility and reliability fixes added on top.

## Running locally

```bash
cp .env.example .env
npm install
npm run dev
```

Dev server runs on `http://localhost:3000`.

## Environment variables

| Variable | Purpose |
|---|---|
| `VITE_API_URL` | Backend base URL. **Baked in at build time**, not read at runtime. Left empty in Docker/Kubernetes builds so the app calls relative `/api/...` paths, which the Ingress/nginx then routes to the backend. |
| `VITE_STORE_NAME` | Fallback store name if the API call fails |

**Note:** the code uses `??` (nullish coalescing), not `||`, when reading `VITE_API_URL`. An empty string is falsy in JavaScript, so `||` would silently fall back to `http://localhost:5000` even when `VITE_API_URL=""` was deliberately set — a real bug this project hit and fixed.

## Scripts

```bash
npm run lint     # ESLint (with eslint-plugin-react)
npm run build    # Production build — treated as the test gate, since there's no test suite
npm run preview  # Preview the production build locally
```

## Docker

Multi-stage build: Node compiles the app with Vite, then a second stage serves the static output with `nginx-unprivileged` (non-root). Node, npm and all source code are discarded after the build stage — the final image is roughly a third the size of the backend's.

```bash
docker build -t zuri-frontend:local --build-arg VITE_API_URL= .
docker run -p 8080:8080 zuri-frontend:local
```

## Kubernetes

nginx's routing config is injected via a ConfigMap at deploy time (`k8s/frontend/configmap.yaml`), rather than baked into the image, so routing can change without a rebuild.

## Fixes applied (SonarQube findings)

- Floating promises in `useEffect` calls marked explicitly with `void`, rather than left unhandled
- The cart-close backdrop (a clickable `<div>`) made keyboard-accessible: `role="button"`, `tabIndex`, `onKeyDown`, and an `aria-label`, since it previously could only be dismissed with a mouse