# Platform CLI — Examples

## Example 1: Minimal Local Dev Instance

```bash
platform init my-dev-idp
platform config init ./my-dev-idp --name "Dev IDP"
platform plugin add techdocs     ./my-dev-idp
platform plugin add github-actions ./my-dev-idp
platform auth add github ./my-dev-idp
platform validate ./my-dev-idp

cd my-dev-idp && yarn install && yarn dev
```

## Example 2: Azure-First Production Instance

Full setup using Azure AD auth, Azure DevOps pipelines, and Kubernetes ingestion.

```bash
platform init prod-idp
platform config init ./prod-idp --name "Production IDP"

# Database
platform config set-database ./prod-idp \
  --db-type postgresql \
  --host prod-db.example.com \
  --port 5432 \
  --user backstage \
  --password "$DB_PASSWORD" \
  --database backstage_prod

# Cloud storage for TechDocs
platform config set-storage ./prod-idp \
  --provider azure \
  --bucket backstage-docs

# Plugins
platform plugin add azure-devops         ./prod-idp
platform plugin add techdocs             ./prod-idp
platform plugin add kubernetes           ./prod-idp
platform plugin add kubernetes-ingestor  ./prod-idp
platform plugin add crossplane-resources ./prod-idp
platform plugin add argocd               ./prod-idp

# Auth — Microsoft Azure AD, no guest access
platform auth add microsoft ./prod-idp \
  --client-id     "$AZURE_CLIENT_ID" \
  --client-secret "$AZURE_CLIENT_SECRET" \
  --tenant-id     "$AZURE_TENANT_ID" \
  --no-guest

platform validate ./prod-idp
```

Then follow the printed code-change checklists for each plugin and auth provider.

## Example 3: Crossplane-Focused Platform Engineering Instance

Backstage as a Crossplane control plane portal — auto-ingest XRDs, show claims/managed resources.

```bash
platform init xplane-idp
platform config init ./xplane-idp --name "Crossplane IDP"

# Core
platform plugin add kubernetes           ./xplane-idp
platform plugin add kubernetes-ingestor  ./xplane-idp   # ingests XRDs, claims, workloads
platform plugin add crossplane-resources ./xplane-idp   # YAML viewer, event log, dep graph
platform plugin add techdocs             ./xplane-idp

# Auth
platform auth add microsoft ./xplane-idp --no-guest

platform validate ./xplane-idp
```

**Enable Crossplane ingestion** — edit `app-config.yaml`:
```yaml
kubernetesIngestor:
  crossplane:
    enabled: true
    claims:
      ingestAllClaims: true
    xrds:
      enabled: true
      publishPhase:
        target: github
        git:
          repoUrl: github.com?owner=myorg&repo=backstage-templates
          targetBranch: main
```

**Apply cluster RBAC** (see `platform plugin info kubernetes-ingestor` for the full YAML):
```bash
kubectl apply -f rbac/backstage-kubernetes-ingestor.yaml
```

## Example 4: Multi-Auth Preview

Check how the `SignInPage` component differs before committing:

```bash
# See GitHub with guest allowed
platform auth info github

# See Microsoft with guest disabled
platform auth info microsoft --no-guest

# Then install the one you want
platform auth add microsoft ./my-idp --no-guest
```

## Example 5: Adding Plugins One at a Time (dry-run style)

Use `--skip-install` and `--skip-config` to preview what would be done:

```bash
# Preview notes only (no install, no config patch)
platform plugin add kubernetes-ingestor ./my-idp --skip-install --skip-config

# Install package but don't touch app-config.yaml
platform plugin add argocd ./my-idp --skip-config

# Patch config only (package already installed)
platform plugin add sonarqube ./my-idp --skip-install
```

## Example 6: Batch Entity Creation

```bash
platform init entity-demo
platform config init ./entity-demo --name "Entity Demo"

# Org structure
platform entity create "platform-team"   --type group  --output ./entity-demo/catalog-entities/team-platform.yaml
platform entity create "delivery-team"   --type group  --output ./entity-demo/catalog-entities/team-delivery.yaml

# Systems
platform entity create "infrastructure"  --type system --owner platform-team
platform entity create "ecommerce"       --type system --owner delivery-team

# Components
platform entity create "api-gateway"     --type component --system infrastructure --owner platform-team --description "Central API gateway"
platform entity create "checkout-svc"    --type component --system ecommerce      --owner delivery-team  --description "Checkout microservice"
platform entity create "payments-svc"    --type component --system ecommerce      --owner delivery-team  --description "Payment processing"

# APIs
platform entity create "checkout-api"    --type api --system ecommerce --owner delivery-team
platform entity create "internal-api"    --type api --system infrastructure --owner platform-team

# Resources
platform entity create "postgres-primary" --type resource --system infrastructure --owner platform-team

# Validate all
platform entity list ./entity-demo
for entity in (ls ./entity-demo/catalog-entities/*.yaml | get name) {
  platform entity validate $entity
}
```

## Example 7: GitHub Actions — Validate on Every PR

Add this to `.github/workflows/validate.yml` in your Backstage instance repo:

```yaml
name: Validate Backstage Config
on:
  pull_request:
    paths:
      - 'app-config.yaml'
      - 'catalog-entities/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Nushell
        run: |
          curl -Lo nu.tar.gz \
            https://github.com/nushell/nushell/releases/latest/download/nu-0.110.0-x86_64-unknown-linux-gnu.tar.gz
          tar -xzf nu.tar.gz --strip-components=1 -C /usr/local/bin nu-0.110.0-x86_64-unknown-linux-gnu/nu
          chmod +x /usr/local/bin/nu

      - name: Validate instance
        run: nu platform/main.nu validate .

      - name: Validate all entities
        run: |
          for f in catalog-entities/**/*.yaml; do
            nu platform/main.nu entity validate "$f"
          done
```
