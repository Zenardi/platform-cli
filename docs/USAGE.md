# Platform CLI — Usage Guide

## Complete Setup Workflow

### 1. Scaffold the instance

```bash
platform init my-idp
cd my-idp
```

Runs `npx @backstage/create-app@latest` — creates a complete, real Backstage project including
`packages/app` (React frontend), `packages/backend` (Node.js), `app-config.yaml`, and a git repo.

### 2. Start the dev server (optional — verify it works)

```bash
yarn dev
```

### 3. Configure the database

```bash
platform config set-database . \
  --db-type postgresql \
  --host localhost \
  --port 5432 \
  --user backstage \
  --password secret \
  --database backstage_db
```

### 4. Add plugins

```bash
platform plugin add kubernetes           .
platform plugin add techdocs             .
platform plugin add argocd               .
platform plugin add azure-devops         .
platform plugin add kubernetes-ingestor  .
platform plugin add crossplane-resources .
platform plugin add grafana              .
platform plugin add cost-insights        .
platform plugin add infrawallet          .
platform plugin add holiday-tracker      .
```

Each command:
- Runs `yarn add <package>` in `packages/app` and/or `packages/backend`
- Appends the plugin's config snippet to `app-config.yaml`
- **Auto-patches** TypeScript source files where applicable:
  - `packages/backend/src/index.ts` — registers backend modules
  - `packages/app/src/components/catalog/EntityPage.tsx` — injects entity page cards/routes
  - `packages/app/src/App.tsx` — adds page imports and `<Route>` entries
  - `packages/app/src/apis.ts` — registers API factories
- Prints a "Next Steps" summary listing only the remaining manual steps

### 5. Configure authentication

```bash
# Microsoft Azure AD — force IdP login, disable guest access
platform auth add microsoft . --no-guest

# With credentials embedded directly in app-config.yaml
platform auth add microsoft . \
  --client-id $AZURE_CLIENT_ID \
  --client-secret $AZURE_CLIENT_SECRET \
  --tenant-id $AZURE_TENANT_ID \
  --no-guest

# GitHub OAuth — allow guest sign-in
platform auth add github .

# Google OAuth
platform auth add google .
```

After running `auth add`, the CLI automatically patches:
- `packages/backend/src/index.ts` — registers the auth backend module
- `packages/app/src/App.tsx` — injects the `SignInPage` component and auth API ref

Set up the IdP app registration (Azure Portal / GitHub / Google Cloud) and configure
the credentials in `app-config.local.yaml` (written by the CLI).

### 6. Configure cloud storage (optional)

```bash
# AWS S3
platform config set-storage . --provider aws --bucket my-docs-bucket --region us-east-1

# Azure Blob Storage
platform config set-storage . --provider azure --bucket backstage-container

# GCP
platform config set-storage . --provider gcp --bucket my-backstage-bucket
```

### 7. Create catalog entities

```bash
platform entity create "platform-team"  --type group
platform entity create "my-system"      --type system --owner platform-team
platform entity create "api-service"    --type component --system my-system --owner platform-team
platform entity create "my-api"         --type api       --system my-system --owner platform-team

# Or use a bulk template
platform entity create-bulk . --template team-structure
```

### 8. Validate

```bash
platform validate .
```

### 9. Deploy

```bash
platform deploy . --environment production
```

---

## Working with Auth Providers

### See all available providers

```bash
platform auth list
```

### Preview config + code without installing

```bash
platform auth info microsoft
platform auth info microsoft --no-guest   # see guest-disabled version
```

### Guest sign-in

By default, `platform auth add` generates a `SignInPage` that includes a **Guest** option.
Pass `--no-guest` to require users to authenticate via the IdP:

```bash
# Without --no-guest → providers={['guest', { id: 'microsoft-auth-provider', ... }]}
platform auth add microsoft ./my-backstage

# With --no-guest → auto + provider={{ id: 'microsoft-auth-provider', ... }}
platform auth add microsoft ./my-backstage --no-guest
```

---

## Working with Plugins

### List available plugins

```bash
platform plugin list
```

### Inspect a plugin before installing

```bash
platform plugin info kubernetes-ingestor
platform plugin info crossplane-resources
```

### Install backend or frontend only

```bash
platform plugin add kubernetes-ingestor  ./my-backstage --backend-only
platform plugin add crossplane-resources ./my-backstage --frontend-only
```

### Skip config patching

```bash
platform plugin add argocd ./my-backstage --skip-config
```

### Remove a plugin

```bash
platform plugin remove argocd ./my-backstage
```

---

## Cloud Costs & FinOps Setup

For cloud spend visibility integrated directly into Backstage:

```bash
platform init finops-backstage
platform config init ./finops-backstage --name "FinOps IDP"

# Multi-cloud cost aggregation dashboard (AWS, Azure, GCP)
platform plugin add infrawallet ./finops-backstage

# Per-team / per-entity cost breakdown (requires a CostInsightsApi implementation)
platform plugin add cost-insights ./finops-backstage
```

**InfraWallet** — uncomment your cloud provider block in `app-config.yaml`:
```yaml
backend:
  infraWallet:
    integrations:
      aws:
        - name: my-aws-account
          accountId: '123456789012'
          assumedRoleName: InfraWalletRole
```

**Cost Insights** — replace `ExampleCostInsightsClient` in `packages/app/src/apis.ts`
with a real implementation once ready. The mock client is wired in automatically so
the page renders immediately.

Both plugins add a `/infrawallet` and `/cost-insights` route respectively. Add sidebar entries manually in `packages/app/src/components/Root/Root.tsx`.

---

## Kubernetes-Native Setup

For a cluster-connected Backstage with auto-ingestion:

```bash
platform init k8s-backstage
platform config init ./k8s-backstage --name "K8s Backstage"

# Core k8s plugin (shows workloads on entity pages)
platform plugin add kubernetes ./k8s-backstage

# Auto-ingest workloads, Crossplane claims, XRDs into catalog
platform plugin add kubernetes-ingestor ./k8s-backstage

# Crossplane resource viewer (YAML, events, dependency graph)
platform plugin add crossplane-resources ./k8s-backstage

# Apply RBAC shown in: platform plugin info kubernetes-ingestor
```

---

## Multi-Environment Setup

```bash
# Create per-environment configs
cp app-config.yaml app-config.development.yaml
cp app-config.yaml app-config.production.yaml
```

Point Backstage to the right file:
```bash
NODE_ENV=production yarn start --config app-config.production.yaml
```

---

## CI/CD Integration

### GitHub Actions — validate on PR

```yaml
# .github/workflows/validate.yml
name: Validate Backstage
on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Nushell
        run: |
          curl -Lo nu.tar.gz https://github.com/nushell/nushell/releases/latest/download/nu-*-x86_64-unknown-linux-gnu.tar.gz
          tar -xzf nu.tar.gz --wildcards '*/nu' --strip-components=1 -C /usr/local/bin
      - name: Validate
        run: nu platform/main.nu validate .
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `File not found: …/platform/main.nu` | Re-run `nu platform/setup.nu` to reinstall |
| `Duplicate command definition` | Re-run `nu platform/setup.nu` to fix stale install |
| `open` returns record instead of string | Update to latest platform version (uses `open --raw`) |
| Yarn install fails | Run `yarn --cwd packages/backend add <pkg>` manually |
| Azure AD redirect error | Check Redirect URI in App registration matches `http://localhost:7007/api/auth/microsoft/handler/frame` |
