# Platform CLI — Backstage Bootstrap Tool

A Nushell CLI for scaffolding and configuring production-ready [Backstage](https://backstage.io) instances.
Automates scaffolding, plugin installation, auth provider setup, catalog entity creation, Dockerfile generation, and Kubernetes manifest generation.

> [!NOTE]
> **Tested with Backstage v1.49.3**

- [Platform CLI — Backstage Bootstrap Tool](#platform-cli--backstage-bootstrap-tool)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [1. Clone the repository](#1-clone-the-repository)
    - [2. Run the setup script](#2-run-the-setup-script)
    - [3. Reload your shell](#3-reload-your-shell)
    - [4. Verify](#4-verify)
    - [Run without installing](#run-without-installing)
  - [Setting Environment Variables (Nushell)](#setting-environment-variables-nushell)
  - [Quick Start](#quick-start)
  - [Commands Reference](#commands-reference)
    - [`platform init`](#platform-init)
    - [`platform plugin list`](#platform-plugin-list)
    - [`platform plugin info`](#platform-plugin-info)
    - [`platform plugin add`](#platform-plugin-add)
    - [`platform plugin remove`](#platform-plugin-remove)
    - [`platform auth list`](#platform-auth-list)
    - [`platform auth info`](#platform-auth-info)
    - [`platform auth add`](#platform-auth-add)
    - [`platform config init`](#platform-config-init)
    - [`platform config validate`](#platform-config-validate)
    - [`platform config set-database`](#platform-config-set-database)
    - [`platform config set-auth`](#platform-config-set-auth)
    - [`platform config set-storage`](#platform-config-set-storage)
    - [`platform entity create`](#platform-entity-create)
    - [`platform entity create-bulk`](#platform-entity-create-bulk)
    - [`platform entity list`](#platform-entity-list)
    - [`platform entity validate`](#platform-entity-validate)
    - [`platform validate`](#platform-validate)
    - [`platform dockerfile`](#platform-dockerfile)
    - [`platform k8s`](#platform-k8s)
    - [`platform cluster configure`](#platform-cluster-configure)
    - [`platform cluster list`](#platform-cluster-list)
    - [`platform deploy`](#platform-deploy)
  - [Catalog Entity Format](#catalog-entity-format)
  - [Project Structure](#project-structure)
  - [See Also](#see-also)


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

This copies the CLI to `~/.config/nushell/platform/` and adds the following alias to your Nushell env file:

```nushell
alias platform = nu ~/.config/nushell/platform/main.nu
```

### 3. Reload your shell

```nushell
source ~/.config/nushell/env.nu
```

Or restart your terminal.

### 4. Verify

```nushell
platform --help
```

### Run without installing

```nushell
nu main.nu --help
nu main.nu init my-backstage
```

---

## Setting Environment Variables (Nushell)

Auth providers require credentials. In Nushell, set them for the current session:

```nushell
$env.AZURE_CLIENT_ID     = "your-client-id"
$env.AZURE_CLIENT_SECRET = "your-client-secret"
$env.AZURE_TENANT_ID     = "your-tenant-id"
```

To persist across sessions, add them to `~/.config/nushell/env.nu`.

---

## Quick Start

```nushell
# 1. Scaffold a new Backstage instance
platform init my-backstage

# 2. Add plugins
platform plugin add kubernetes ./my-backstage
platform plugin add techdocs   ./my-backstage

# 3. Add auth provider
platform auth add microsoft ./my-backstage --no-guest \
  --client-id abc --client-secret xyz --tenant-id tid

# 4. Create catalog entities
platform entity create my-service --type component --owner platform-team

# 5. Validate the instance
platform validate ./my-backstage

# 6. Generate Docker and Kubernetes deployment files
platform dockerfile ./my-backstage
platform k8s ./my-backstage --image ghcr.io/myorg/backstage:latest --host backstage.example.com

# 7. Register a Kubernetes cluster (creates SA + RBAC, generates token, updates app-config.local.yaml)
platform cluster configure ./my-backstage --cluster-name kind-backstage --skip-tls-verify
platform cluster list ./my-backstage
```

---

## Commands Reference

### `platform init`

Scaffold a new Backstage instance using the official `@backstage/create-app@latest` scaffolder.

```
platform init <name> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `name` *(required)* | — | Name of the new instance. Used as the directory name. |
| `--path <path>` | `.` (current dir) | Parent directory to create the instance in. |
| `--skip-install` | false | Skip the `yarn install` step. Useful for CI or offline use. |

```nushell
platform init my-backstage
platform init my-backstage --path ~/projects
platform init my-backstage --skip-install
```

Generated project structure:

```
my-backstage/
├── packages/
│   ├── app/               # React frontend
│   └── backend/           # Node.js backend
├── app-config.yaml        # Main Backstage configuration
├── app-config.local.yaml  # Local overrides (gitignored)
├── package.json
├── tsconfig.json
└── README.md
```

---

### `platform plugin list`

List all available plugins that can be installed.

```nushell
platform plugin list
```

**Available plugins:**

| ID | Name | Packages | Auto-patches | Scaffolder Actions |
|----|------|----------|--------------|--------------------|
| `azure-devops` | Azure DevOps | frontend + backend + scaffolder module | `index.ts`, `EntityPage.tsx` | `publish:azure` |
| `github-actions` | GitHub Actions | frontend only | `EntityPage.tsx` | — |
| `kubernetes` | Kubernetes | frontend + backend | `index.ts`, `EntityPage.tsx` | — |
| `techdocs` | TechDocs | frontend + backend | `index.ts`, `EntityPage.tsx` | — |
| `argocd` | Argo CD | frontend + backend | `index.ts` | — |
| `sonarqube` | SonarQube | frontend + backend | `index.ts` | — |
| `kubernetes-ingestor` | Kubernetes Ingestor | backend only | `index.ts` | — |
| `crossplane-resources` | Crossplane Resources | frontend + backend | `index.ts`, `apis.ts`, `EntityPage.tsx` | — |
| `grafana` | Grafana | frontend only | `EntityPage.tsx` | — |
| `holiday-tracker` | Holiday Tracker | frontend only | `App.tsx` | — |
| `cost-insights` | Cost Insights | frontend only | `apis.ts`, `App.tsx` | — |
| `infrawallet` | InfraWallet | frontend + backend | `index.ts`, `App.tsx` | — |

> **Azure DevOps — `publish:azure` scaffolder action:** Installing the `azure-devops` plugin also installs `@backstage/plugin-scaffolder-backend-module-azure` and registers it in `packages/backend/src/index.ts`. This makes the `publish:azure` built-in action available in your software templates. No manual steps required.

> **⚠ Azure DevOps — Local vs Production credentials:**
> - **Local development:** Managed Identity does **not** work on a local machine — it requires Azure-hosted infrastructure (AKS, App Service, VM). Use `clientId + clientSecret` in `app-config.local.yaml`. Generate a client secret in: Azure Portal → App Registrations → your app → Certificates & Secrets.
> - **Production (AKS/Azure-hosted):** Use `managedIdentityClientId` in `app-config.yaml`.
>
> If you see `ManagedIdentityCredential: Network unreachable` locally, your `app-config.local.yaml` is using `managedIdentityClientId` instead of `clientSecret`.
>
> **Also required:** The app registration must be added as a member of your Azure DevOps organization at `https://dev.azure.com/{YOUR_ORG}/_settings/users` (License: Basic, Group: Project Contributors). Without this you will get `TF401444: Please sign-in at least once...`.

---

### `platform plugin info`

Show detailed installation instructions for a plugin, including required packages, environment variables, and manual steps.

```
platform plugin info <name>
```

| Argument | Description |
|---|---|
| `name` *(required)* | Plugin ID (see `platform plugin list`). |

```nushell
platform plugin info kubernetes
platform plugin info techdocs
platform plugin info azure-devops
```

---

### `platform plugin add`

Install and configure a plugin in an existing Backstage instance. Runs `yarn add`, patches TypeScript files, and writes entries to `app-config.local.yaml`.

```
platform plugin add <name> <instance-path> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `name` *(required)* | — | Plugin ID (see `platform plugin list`). |
| `instance-path` *(required)* | — | Path to the Backstage instance root. |
| `--frontend-only` | false | Only install and patch frontend packages. |
| `--backend-only` | false | Only install and patch backend packages. |
| `--skip-config` | false | Skip writing to `app-config.local.yaml`. |

```nushell
platform plugin add kubernetes           ./my-backstage
platform plugin add techdocs             ./my-backstage
platform plugin add azure-devops         ./my-backstage
platform plugin add grafana              ./my-backstage --frontend-only
platform plugin add kubernetes-ingestor  ./my-backstage --backend-only
platform plugin add crossplane-resources ./my-backstage --skip-config
```

> **Note for Backstage v1.49.3+ (new declarative frontend system):** `EntityPage.tsx` no longer exists. The CLI will warn you and print the manual steps needed to register the plugin's entity cards via the `/alpha` extension package in `App.tsx`.

---

### `platform plugin remove`

Remove a plugin from a Backstage instance by running `yarn remove`.

```
platform plugin remove <name> <instance-path>
```

| Argument | Description |
|---|---|
| `name` *(required)* | Plugin ID. |
| `instance-path` *(required)* | Path to the Backstage instance root. |

```nushell
platform plugin remove kubernetes ./my-backstage
```

---

### `platform auth list`

List all available authentication providers.

```nushell
platform auth list
```

**Available providers:**

| ID | Name | Required credentials |
|----|------|---------------------|
| `microsoft` | Microsoft Azure AD / Entra ID | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` |
| `github` | GitHub OAuth | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` |
| `google` | Google OAuth | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |

---

### `platform auth info`

Show a full setup guide for an auth provider, including required env vars, Kubernetes secret keys, and step-by-step configuration instructions.

```
platform auth info <provider> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `provider` *(required)* | — | Provider ID (see `platform auth list`). |
| `--no-guest` | false | Show the configuration variant that disables guest/anonymous access. |

```nushell
platform auth info github
platform auth info microsoft --no-guest
```

---

### `platform auth add`

Install and configure an authentication provider. Runs `yarn add`, patches `packages/backend/src/index.ts` and `packages/app/src/App.tsx`, and writes the auth block to `app-config.local.yaml`.

```
platform auth add <provider> <instance-path> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `provider` *(required)* | — | Provider ID (see `platform auth list`). |
| `instance-path` *(required)* | — | Path to the Backstage instance root. |
| `--client-id <id>` | — | OAuth client ID. Written to `app-config.local.yaml`. |
| `--client-secret <secret>` | — | OAuth client secret. Written to `app-config.local.yaml`. |
| `--tenant-id <id>` | — | Tenant ID. **Microsoft only.** Written to `app-config.local.yaml`. |
| `--no-guest` | false | Disable guest / anonymous access. Forces IdP login. |
| `--skip-config` | false | Skip patching config files. Only runs `yarn add` and TypeScript patches. |
| `--skip-install` | false | Skip `yarn add`. Only patches config and TypeScript files. |

```nushell
# GitHub — reads credentials from environment variables
$env.GITHUB_CLIENT_ID = "..."; $env.GITHUB_CLIENT_SECRET = "..."
platform auth add github ./my-backstage

# GitHub — with credentials passed directly
platform auth add github ./my-backstage --client-id abc --client-secret xyz

# Microsoft — no guest access, credentials inline
platform auth add microsoft ./my-backstage \
  --client-id abc --client-secret xyz --tenant-id tid --no-guest

# Microsoft — skip yarn install (packages already installed)
platform auth add microsoft ./my-backstage --skip-install
```

**`--no-guest` effect:**

| | Default | `--no-guest` |
|-|---------|--------------|
| Sign-in page | Shows "Sign in as Guest" button | Auto-redirects to the IdP, no guest option |
| `SignInPage` prop | `providers: ['guest', {...}]` | `auto` + `provider: {...}` |

---

### `platform config init`

Initialize a new `app-config.local.yaml` in the Backstage instance with sensible defaults for local development.

```
platform config init <instance-path> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `instance-path` *(required)* | — | Path to the Backstage instance root. |
| `--name <title>` | `"Backstage"` | Application display name shown in the browser tab and header. |

```nushell
platform config init ./my-backstage
platform config init ./my-backstage --name "My IDP"
```

---

### `platform config validate`

Validate `app-config.yaml` for required fields and structural correctness.

```
platform config validate <instance-path>
```

| Argument | Description |
|---|---|
| `instance-path` *(required)* | Path to the Backstage instance root. |

```nushell
platform config validate ./my-backstage
```

---

### `platform config set-database`

Configure the database connection in `app-config.yaml`. Supports PostgreSQL (recommended for production) and SQLite (for local development).

```
platform config set-database <instance-path> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `instance-path` *(required)* | — | Path to the Backstage instance root. |
| `--db-type <type>` | `postgresql` | Database engine: `postgresql` or `sqlite`. |
| `--host <host>` | `localhost` | Database server hostname or IP. |
| `--port <port>` | — | Database port (default depends on engine). |
| `--user <user>` | — | Database username. |
| `--password <pass>` | — | Database password. |
| `--database <name>` | — | Database name. |

```nushell
platform config set-database ./my-backstage
platform config set-database ./my-backstage --db-type postgresql --host db.example.com --user backstage --password secret
platform config set-database ./my-backstage --db-type sqlite
```

---

### `platform config set-auth`

Configure the authentication provider block in `app-config.yaml`.

```
platform config set-auth <instance-path> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `instance-path` *(required)* | — | Path to the Backstage instance root. |
| `--provider <name>` | `github` | Auth provider: `github`, `microsoft`, or `gitlab`. |
| `--client-id <id>` | — | OAuth client ID. |
| `--client-secret <secret>` | — | OAuth client secret. |

```nushell
platform config set-auth ./my-backstage --provider github
platform config set-auth ./my-backstage --provider github --client-id abc --client-secret xyz
```

---

### `platform config set-storage`

Configure object storage for TechDocs in `app-config.yaml`.

```
platform config set-storage <instance-path> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `instance-path` *(required)* | — | Path to the Backstage instance root. |
| `--provider <name>` | `local` | Storage backend: `local`, `s3`, or `gcs`. |
| `--bucket <name>` | — | Storage bucket name. Required for `s3` and `gcs`. |
| `--region <region>` | — | Cloud region. Required for `s3`. |

```nushell
platform config set-storage ./my-backstage
platform config set-storage ./my-backstage --provider s3 --bucket my-docs-bucket --region us-east-1
platform config set-storage ./my-backstage --provider gcs --bucket my-docs-bucket
```

---

### `platform entity create`

Generate a Backstage catalog YAML entity file. Output is written to `./catalog-entities/<name>.yaml` by default.

```
platform entity create <name> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `name` *(required)* | — | Entity name (used in `metadata.name`). |
| `--type <type>` | `component` | Entity kind: `component`, `api`, `group`, `user`, `system`, or `domain`. |
| `--owner <owner>` | `platform-team` | Owning team or user reference. |
| `--system <system>` | `internal-platform` | Parent system name. |
| `--description <text>` | `""` | Short human-readable description of the entity. |
| `--output <path>` | `./catalog-entities/<name>.yaml` | Custom output file path. |

```nushell
platform entity create my-service
platform entity create my-api --type api --owner team-a
platform entity create platform --type system --owner platform-team
platform entity create my-service --description "Main backend API" --output ./catalog/my-service.yaml
```

---

### `platform entity create-bulk`

Generate a set of catalog entities from a predefined template. Useful for bootstrapping a new instance with example entities.

```
platform entity create-bulk <instance-path> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `instance-path` *(required)* | — | Path to the Backstage instance root. |
| `--template <name>` | `basic` | Template to use: `basic`, `microservices`, or `team-structure`. |

```nushell
platform entity create-bulk ./my-backstage
platform entity create-bulk ./my-backstage --template team-structure
```

---

### `platform entity list`

List all catalog entity YAML files in the instance's `catalog-entities/` directory.

```
platform entity list <instance-path>
```

| Argument | Description |
|---|---|
| `instance-path` *(required)* | Path to the Backstage instance root. |

```nushell
platform entity list ./my-backstage
```

---

### `platform entity validate`

Validate a catalog entity YAML file against the Backstage catalog schema. Checks for required fields: `apiVersion`, `kind`, `metadata.name`, and `spec`.

```
platform entity validate <entity-path>
```

| Argument | Description |
|---|---|
| `entity-path` *(required)* | Path to the entity YAML file. |

```nushell
platform entity validate ./catalog-entities/my-service.yaml
```

---

### `platform validate`

Validate that a Backstage instance directory has the required structure and configuration files. Critical failures cause a non-zero exit code.

```
platform validate <instance-path>
```

| Argument | Description |
|---|---|
| `instance-path` *(required)* | Path to the Backstage instance root. |

**Checks performed:**

| File / Directory | Critical | Notes |
|---|---|---|
| `package.json` | ✅ Yes | Must exist at instance root |
| `app-config.yaml` | ✅ Yes | Main Backstage configuration file |
| `tsconfig.json` | ⚠️ Warning | Expected but not strictly required |
| `packages/app` | ✅ Yes | Frontend package directory |
| `packages/backend` | ✅ Yes | Backend package directory |

```nushell
platform validate ./my-backstage
platform validate .
```

---

### `platform dockerfile`

Generate a production-ready multi-stage `Dockerfile` and `.dockerignore` for a Backstage instance.

```
platform dockerfile <instance-path> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `instance-path` *(required)* | — | Path to the Backstage instance root. |
| `--output <path>` | `<instance-path>/Dockerfile` | Custom output path for the Dockerfile. |

**Build stages generated:**

| Stage | Base image | Purpose |
|---|---|---|
| `packages` | `node:24-trixie-slim` | Extracts `package.json` skeleton for layer-cached `yarn install` |
| `build` | `node:24-trixie-slim` | Installs all deps, runs `yarn tsc` + `yarn --cwd packages/backend build` |
| `final` | `cgr.dev/chainguard/node:latest` | Minimal production image (Chainguard — fewer CVEs) |

The generated `.dockerignore` intentionally **does not** exclude `packages/*/src`, which would otherwise cause `TS18003: No inputs were found` during `yarn tsc`.

```nushell
platform dockerfile ./my-backstage
platform dockerfile ./my-backstage --output ./deploy/Dockerfile

# Build the image
docker build -t backstage ./my-backstage
docker run -p 7007:7007 backstage
```

---

### `platform k8s`

Generate production-ready Kubernetes manifests for a Backstage instance. Creates a `k8s/` directory with four files.

```
platform k8s <instance-path> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `instance-path` *(required)* | — | Path to the Backstage instance root. |
| `--namespace <ns>` | `backstage` | Kubernetes namespace for all resources. |
| `--image <img>` | `docker.io/YOUR_DOCKERHUB_USER/backstage:latest` | Container image reference for the Deployment. |
| `--host <host>` | `backstage.example.com` | Ingress hostname (used in rules and TLS). |
| `--replicas <n>` | `2` | Number of Deployment replicas. |

**Files generated:**

| File | Kind | Description |
|---|---|---|
| `k8s/deployment.yaml` | `Deployment` | 2 replicas, health probes, resource limits, secrets reference |
| `k8s/service.yaml` | `Service` | `ClusterIP` on port 80 → container port 7007 |
| `k8s/ingress.yaml` | `Ingress` | Traefik with TLS, configurable hostname |
| `k8s/backstage-secrets.example.yaml` | `Secret` | Template with all required env var placeholders |

```nushell
# Generate with defaults
platform k8s ./my-backstage

# Customise image, host and namespace
platform k8s ./my-backstage \
  --image ghcr.io/myorg/backstage:v1.0 \
  --host backstage.mycompany.io \
  --namespace production \
  --replicas 3

# Apply to the cluster
cp k8s/backstage-secrets.example.yaml k8s/backstage-secrets.yaml
# Edit k8s/backstage-secrets.yaml with real values, then:
kubectl apply -f ./my-backstage/k8s/
```

---

### `platform cluster configure`

Create or update a Kubernetes cluster in `app-config.local.yaml`. This command:

1. Creates/updates the `ServiceAccount`, `ClusterRole`, and `ClusterRoleBinding` on the target cluster (`kubectl apply` — idempotent, safe to re-run).
2. Generates a fresh service account token.
3. Auto-detects the cluster URL from the active kubeconfig.
4. Writes (or updates) the cluster block in `app-config.local.yaml`.

**Re-running the command rotates the token** for an existing cluster entry. Providing a different `--cluster-name` appends a second cluster without affecting the first.

```
platform cluster configure <instance-path> --cluster-name <name> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `instance-path` *(required)* | — | Path to the Backstage instance root. |
| `--cluster-name <name>` *(required)* | — | Name for this cluster in Backstage (used as the display name). |
| `--kubeconfig <path>` | `~/.kube/config` | Path to a kubeconfig file. Useful for managing multiple clusters. |
| `--context <ctx>` | *(active context)* | Kubeconfig context to use. |
| `--sa-name <name>` | `backstage-reader` | Name of the `ServiceAccount` to create or reuse. |
| `--namespace <ns>` | `default` | Namespace where the `ServiceAccount` is created. |
| `--duration <dur>` | `8760h` (1 year) | Token lifetime. Examples: `8760h` (1y), `2160h` (90d), `720h` (30d). |
| `--skip-tls-verify` | `false` | Disable TLS certificate verification (useful for KIND/local clusters). |
| `--dry-run` | `false` | Preview all steps (RBAC manifest, cluster URL, config diff) without making any changes. |

The `ClusterRole` grants `get`, `list`, `watch` on all resource types the Backstage Kubernetes plugin queries:

| API Group | Resources |
|---|---|
| `""` (core) | pods, services, configmaps, events, namespaces, limitranges, resourcequotas |
| `apps` | deployments, replicasets, statefulsets, daemonsets |
| `autoscaling` | horizontalpodautoscalers |
| `networking.k8s.io` | ingresses |
| `batch` | jobs, cronjobs |
| `metrics.k8s.io` | pods, nodes |

```nushell
# Preview what would happen — no changes made
platform cluster configure ./my-backstage \
  --cluster-name kind-backstage \
  --skip-tls-verify \
  --dry-run

# Register the KIND cluster (first time or token rotation)
platform cluster configure ./my-backstage \
  --cluster-name kind-backstage \
  --skip-tls-verify

# Use a custom SA name, non-default namespace, and shorter token lifetime
platform cluster configure ./my-backstage \
  --cluster-name kind-backstage \
  --sa-name my-backstage-reader \
  --namespace monitoring \
  --duration 720h \
  --skip-tls-verify

# Register a second cluster (appends — does not replace the first)
platform cluster configure ./my-backstage \
  --cluster-name prod-eks \
  --kubeconfig ~/.kube/prod.yaml \
  --context prod-admin

# Rotate the token for an existing cluster (re-run same command)
platform cluster configure ./my-backstage --cluster-name kind-backstage --skip-tls-verify
```

> [!IMPORTANT]
> `app-config.local.yaml` is gitignored. The service account token is a secret — never commit it.
> Restart Backstage (`yarn start`) after running this command for the change to take effect.

---

### `platform cluster list`

Show all Kubernetes clusters currently configured in `app-config.local.yaml`.

```
platform cluster list <instance-path>
```

| Argument | Default | Description |
|---|---|---|
| `instance-path` *(required)* | — | Path to the Backstage instance root. |

```nushell
platform cluster list ./my-backstage
```

---

### `platform deploy`

Validate the instance and prepare it for production deployment.

```
platform deploy <instance-path> [options]
```

| Argument / Option | Default | Description |
|---|---|---|
| `instance-path` *(required)* | — | Path to the Backstage instance root. |
| `--environment <env>` | `production` | Target environment name (used in log output). |

```nushell
platform deploy ./my-backstage
platform deploy ./my-backstage --environment staging
```

---

## Catalog Entity Format

```yaml
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
├── main.nu           # CLI entry point and dispatcher
├── setup.nu          # One-time installer
├── config.nu         # Global constants (versions, colors)
├── version.txt       # Current version
├── modules/
│   ├── scaffolding.nu  # platform init
│   ├── plugins.nu      # platform plugin *
│   ├── auth.nu         # platform auth *
│   ├── entities.nu     # platform entity *
│   ├── app-config.nu   # platform config *
│   ├── dockerfile.nu   # platform dockerfile
│   ├── kubernetes.nu   # platform k8s
│   ├── cluster.nu      # platform cluster
│   └── utils.nu        # Shared helpers
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

