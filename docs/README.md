# Platform CLI — Backstage Bootstrap Tool

A Nushell CLI for scaffolding and configuring production-ready [Backstage](https://backstage.io) instances.
Automates directory scaffolding, plugin installation, auth provider setup, and catalog entity creation.

## Prerequisites

| Tool | Version |
|------|---------|
| [Nushell](https://www.nushell.sh/book/installation.html) | v0.84.0+ |
| Node.js | v18.17.0+ |
| Yarn | any |
| Git | optional |

## Installation

```bash
cd platform/
nu setup.nu
```

This copies the CLI to `~/.config/nushell/platform/` and adds `alias platform = nu …/main.nu` to your Nushell env.

Reload your shell or run:
```nushell
source ~/.config/nushell/env.nu
```

---

## Quick Start

```bash
# 1. Scaffold a new Backstage instance (runs npx @backstage/create-app@latest)
platform init my-backstage

# 2. Add plugins
platform plugin add kubernetes ./my-backstage
platform plugin add techdocs   ./my-backstage

# 3. Add Microsoft Azure AD auth (no guest sign-in)
platform auth add microsoft ./my-backstage --no-guest

# 4. Validate
platform validate ./my-backstage
```

---

## Commands Reference

### `platform init`

Scaffold a new Backstage instance using the official Backstage scaffolder.
Runs `npx @backstage/create-app@latest` under the hood — produces a real, complete Backstage project.

```
platform init <name> [--path <parent-dir>] [--skip-install]
```

```bash
# Create my-backstage/ in the current directory
platform init my-backstage

# Create in a specific parent directory
platform init my-backstage --path ~/projects

# Skip yarn install (useful in CI — run yarn install manually after)
platform init my-backstage --skip-install
```

What `@backstage/create-app` generates:
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
  --region     <region>          # cloud providers only
```

---

### `platform plugin`

```
platform plugin list
platform plugin info <plugin-id>
platform plugin add  <plugin-id> <instance-path> [--frontend-only] [--backend-only] [--skip-config]
platform plugin remove <plugin-id> <instance-path>
```

**Available plugins:**

| ID | Name | Packages |
|----|------|---------|
| `azure-devops` | Azure DevOps | frontend + backend |
| `github-actions` | GitHub Actions | frontend only |
| `kubernetes` | Kubernetes | frontend + backend |
| `techdocs` | TechDocs | frontend + backend |
| `argocd` | Argo CD | frontend + backend |
| `sonarqube` | SonarQube | frontend + backend |
| `kubernetes-ingestor` | Kubernetes Ingestor | backend only |
| `crossplane-resources` | Crossplane Resources | frontend + backend |

```bash
# Examples
platform plugin add kubernetes          ./my-backstage
platform plugin add kubernetes-ingestor ./my-backstage
platform plugin add crossplane-resources ./my-backstage
platform plugin add argocd              ./my-backstage --skip-config
```

---

### `platform auth`

Install and configure an OAuth / identity provider.

```
platform auth list
platform auth info  <provider> [--no-guest]
platform auth add   <provider> <instance-path>
  [--client-id     <id>]
  [--client-secret <secret>]
  [--tenant-id     <id>]       # Microsoft only
  [--no-guest]                 # Disable guest sign-in
  [--skip-config]
  [--skip-install]
```

**Available providers:**

| ID | Name | Required env vars |
|----|------|------------------|
| `microsoft` | Microsoft Azure AD | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` |
| `github` | GitHub OAuth | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` |
| `google` | Google OAuth | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |

```bash
# Microsoft Azure AD — require login, no guest option
platform auth add microsoft ./my-backstage --no-guest

# With credentials baked into app-config.yaml
platform auth add microsoft ./my-backstage \
  --client-id abc123 --client-secret xyz --tenant-id tid --no-guest

# GitHub — allow guest sign-in
platform auth add github ./my-backstage

# Preview what the config + code looks like
platform auth info microsoft --no-guest
```

**`--no-guest` behaviour:**

| | Default (guest allowed) | `--no-guest` |
|-|------------------------|--------------|
| `SignInPage` prop | `providers={['guest', {...}]}` | `auto` + `provider={{...}}` |
| Effect | "Sign in as Guest" button visible | Auto-redirects to IdP, no guest |

---

### `platform entity`

```
platform entity create      <name> [--type TYPE] [--owner OWNER] [--system SYS] [--description DESC] [--output PATH]
platform entity create-bulk <instance-path> [--template basic|microservices|team-structure]
platform entity list        <instance-path>
platform entity validate    <entity-path>
```

**Entity types:** `component`, `api`, `resource`, `system`, `group`, `user`

```bash
platform entity create "my-system" --type system --owner platform-team
platform entity create "api-service" --type component --system my-system --owner platform-team
platform entity create-bulk ./my-backstage --template team-structure
platform entity validate ./my-backstage/catalog-entities/api-service.yaml
```

---

### `platform validate`

Run a full sanity-check on a Backstage instance (files, config, entities).

```bash
platform validate ./my-backstage
```

---

### `platform deploy`

Prepare an instance for production deployment.

```bash
platform deploy ./my-backstage
platform deploy ./my-backstage --environment staging
```

---

## Project Structure

```
my-backstage/
├── app/src/
│   ├── components/
│   ├── pages/
│   └── api/
├── packages/
│   ├── backend/        # yarn --cwd packages/backend add <pkg>
│   ├── frontend/
│   └── cli/
├── plugins/            # custom plugins
├── catalog-entities/   # Backstage YAML entities
├── docs/
├── .github/workflows/
├── app-config.yaml     # patched by platform commands
├── package.json
├── tsconfig.json
└── .gitignore
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

## See Also

- [USAGE.md](./USAGE.md) — step-by-step workflows
- [EXAMPLES.md](./EXAMPLES.md) — complete scenario scripts
- [Backstage docs](https://backstage.io/docs)
