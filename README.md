# Platform CLI — Backstage Bootstrap Tool

A Nushell CLI for scaffolding and configuring production-ready [Backstage](https://backstage.io) instances.
Automates directory scaffolding, plugin installation, auth provider setup, and catalog entity creation.

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| [Nushell](https://www.nushell.sh/book/installation.html) | v0.100.0+ | Required |
| Node.js | v18.17.0+ | Required for Backstage |
| Yarn | any | Required for Backstage |
| Git | any | Optional |

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/Zenardi/platform-cli.git
cd platform-cli
```

### 2. Run the setup script

```nushell
nu setup.nu
```

This will:
- Copy the CLI files to `~/.config/nushell/platform/`
- Add `alias platform = nu ~/.config/nushell/platform/main.nu` to your Nushell env file

### 3. Reload your shell

In your **Nushell** session:

```nushell
source ~/.config/nushell/env.nu
```

Or simply restart your terminal.

### 4. Verify the installation

```nushell
platform --help
```

### Run without installing

You can also run the CLI directly without setup:

```nushell
nu main.nu --help
nu main.nu init my-backstage
```

---

## Setting Environment Variables (Nushell)

Auth providers require credentials. In Nushell, set environment variables for your current session:

```nushell
$env.AZURE_CLIENT_ID     = "your-client-id"
$env.AZURE_CLIENT_SECRET = "your-client-secret"
$env.AZURE_TENANT_ID     = "your-tenant-id"
```

To persist them across sessions, add them to `~/.config/nushell/env.nu`:

```nushell
# ~/.config/nushell/env.nu
$env.AZURE_CLIENT_ID     = "your-client-id"
$env.AZURE_CLIENT_SECRET = "your-client-secret"
$env.AZURE_TENANT_ID     = "your-tenant-id"
```

---

## Quick Start

```nushell
# 1. Scaffold a new Backstage instance
platform init my-backstage

# 2. Add plugins
platform plugin add kubernetes    ./my-backstage
platform plugin add techdocs      ./my-backstage
platform plugin add grafana       ./my-backstage

# 3. Add Microsoft Azure AD auth (no guest sign-in)
$env.AZURE_CLIENT_ID     = "your-client-id"
$env.AZURE_CLIENT_SECRET = "your-client-secret"
$env.AZURE_TENANT_ID     = "your-tenant-id"
platform auth add microsoft ./my-backstage --no-guest

# 4. Create catalog entities
platform entity create my-service --type component --owner platform-team

# 5. Validate
platform validate ./my-backstage
```

---

## Commands Reference

### `platform init`

Scaffold a new Backstage instance using the official Backstage scaffolder.
Runs `npx @backstage/create-app@latest` — produces a complete Backstage project.

```
platform init <name> [--path <parent-dir>] [--skip-install]
```

```nushell
# Create my-backstage/ in the current directory
platform init my-backstage

# Create in a specific parent directory
platform init my-backstage --path ~/projects

# Skip yarn install (useful in CI)
platform init my-backstage --skip-install
```

Generated project structure:

```
my-backstage/
├── packages/
│   ├── app/               # React frontend
│   └── backend/           # Node.js backend
├── app-config.yaml        # Main Backstage config
├── app-config.local.yaml  # Local overrides (gitignored)
├── package.json
├── tsconfig.json
├── .gitignore
└── README.md
```

---

### `platform plugin`

```
platform plugin list
platform plugin info   <plugin-id>
platform plugin add    <plugin-id> <instance-path> [--frontend-only] [--backend-only] [--skip-config]
platform plugin remove <plugin-id> <instance-path>
```

**Available plugins:**

| ID | Name | Packages | Auto-patches |
|----|------|---------|--------------|
| `azure-devops` | Azure DevOps | frontend + backend | `index.ts`, `EntityPage.tsx` |
| `github-actions` | GitHub Actions | frontend only | `EntityPage.tsx` |
| `kubernetes` | Kubernetes | frontend + backend | `index.ts`, `EntityPage.tsx` |
| `techdocs` | TechDocs | frontend + backend | `index.ts`, `EntityPage.tsx` |
| `argocd` | Argo CD | frontend + backend | `index.ts` |
| `sonarqube` | SonarQube | frontend + backend | `index.ts` |
| `kubernetes-ingestor` | Kubernetes Ingestor | backend only | `index.ts` |
| `crossplane-resources` | Crossplane Resources | frontend + backend | `index.ts`, `apis.ts`, `EntityPage.tsx` |
| `grafana` | Grafana | frontend only | `EntityPage.tsx` |
| `holiday-tracker` | Holiday Tracker | frontend only | `App.tsx` |
| `cost-insights` | Cost Insights | frontend only | `apis.ts`, `App.tsx` |
| `infrawallet` | InfraWallet | frontend + backend | `index.ts`, `App.tsx` |

```nushell
platform plugin list
platform plugin info kubernetes
platform plugin add kubernetes           ./my-backstage
platform plugin add kubernetes-ingestor  ./my-backstage
platform plugin add crossplane-resources ./my-backstage
platform plugin add grafana              ./my-backstage
platform plugin add cost-insights        ./my-backstage
platform plugin add argocd               ./my-backstage --skip-config
```

---

### `platform auth`

Install and configure an OAuth / identity provider.
Patches `packages/backend/src/index.ts` and `packages/app/src/App.tsx` automatically.

```
platform auth list
platform auth info  <provider> [--no-guest]
platform auth add   <provider> <instance-path>
  [--client-id     <id>]
  [--client-secret <secret>]
  [--tenant-id     <id>]       # Microsoft only
  [--no-guest]                 # Disable guest sign-in (force IdP login)
  [--skip-config]
  [--skip-install]
```

**Available providers:**

| ID | Name | Required env vars |
|----|------|------------------|
| `microsoft` | Microsoft Azure AD | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` |
| `github` | GitHub OAuth | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` |
| `google` | Google OAuth | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |

```nushell
# Microsoft Azure AD — require login, no guest option
$env.AZURE_CLIENT_ID = "..."; $env.AZURE_CLIENT_SECRET = "..."; $env.AZURE_TENANT_ID = "..."
platform auth add microsoft ./my-backstage --no-guest

# Microsoft — with credentials baked in (written to app-config.local.yaml)
platform auth add microsoft ./my-backstage \
  --client-id abc123 --client-secret xyz --tenant-id tid --no-guest

# GitHub OAuth
$env.GITHUB_CLIENT_ID = "..."; $env.GITHUB_CLIENT_SECRET = "..."
platform auth add github ./my-backstage

# Preview what config + code changes look like before applying
platform auth info microsoft --no-guest
```

**`--no-guest` behaviour:**

| | Default (guest allowed) | `--no-guest` |
|-|------------------------|--------------|
| `SignInPage` prop | `providers={['guest', {...}]}` | `auto` + `provider={{...}}` |
| Effect | "Sign in as Guest" button visible | Auto-redirects to IdP, no guest button |

---

### `platform config`

```
platform config init     <instance-path> [--name <title>]
platform config validate <instance-path>

platform config set-database <instance-path>
  --db-type    postgresql|mysql|mariadb
  --host       <host>
  --port       <port>
  --user       <user>
  --password   <password>
  --database   <db-name>

platform config set-storage <instance-path>
  --provider   aws|azure|gcp|local
  --bucket     <bucket>
  --region     <region>
```

---

### `platform entity`

```
platform entity create      <name> [--type TYPE] [--owner OWNER] [--system SYS] [--description DESC] [--output PATH]
platform entity create-bulk <instance-path> [--template basic|microservices|team-structure]
platform entity list        <instance-path>
platform entity validate    <entity-path>
```

**Entity types:** `component`, `api`, `resource`, `system`, `group`, `user`

```nushell
platform entity create "my-system"   --type system    --owner platform-team
platform entity create "api-service" --type component --system my-system --owner platform-team
platform entity create-bulk ./my-backstage --template team-structure
platform entity validate ./my-backstage/catalog-entities/api-service.yaml
```

---

### `platform validate`

Run a sanity-check on a Backstage instance (files, config, entities).

```nushell
platform validate ./my-backstage
```

---

### `platform deploy`

Prepare an instance for production deployment.

```nushell
platform deploy ./my-backstage
platform deploy ./my-backstage --environment staging
```

---

## Catalog Entity Format

```yaml
# catalog-entities/my-service.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-service
  description: Main API service
spec:
  type: service
  lifecycle: production
  owner: platform-team
  system: my-system
```

Supported kinds: `Component`, `API`, `Resource`, `System`, `Group`, `User`, `Location`

---

## Project Structure

```
platform-cli/
├── main.nu          # CLI entry point
├── setup.nu         # One-time installer
├── config.nu        # Global constants (versions, colors)
├── version.txt      # Current version
├── modules/
│   ├── scaffolding.nu
│   ├── plugins.nu
│   ├── auth.nu
│   ├── entities.nu
│   ├── app-config.nu
│   └── utils.nu
├── templates/
├── tests/
└── docs/
    ├── USAGE.md
    └── EXAMPLES.md
```

---

## See Also

- [USAGE.md](./docs/USAGE.md) — step-by-step workflows
- [EXAMPLES.md](./docs/EXAMPLES.md) — complete scenario scripts
- [Backstage docs](https://backstage.io/docs)
