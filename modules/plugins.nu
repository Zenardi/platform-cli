# plugin management module

use ../config.nu
use ./utils.nu

# ---------------------------------------------------------------------------
# Plugin registry
# Each entry describes a Backstage community / core plugin with:
#   frontend_pkg  – npm package installed into packages/app (empty = none)
#   backend_pkg   – npm package installed into packages/backend (empty = none)
#   description   – one-line summary
#   app_config    – YAML snippet to append to app-config.yaml
#   notes         – post-install manual steps shown to the user
# ---------------------------------------------------------------------------
def plugin-registry [] {
    {
        "azure-devops": {
            name: "Azure DevOps"
            description: "Azure Pipelines, Repos, Git Tags and README for entity pages"
            frontend_pkg: "@backstage-community/plugin-azure-devops"
            backend_pkg:  "@backstage-community/plugin-azure-devops-backend"
            app_config: "
integrations:
  azure:
    - host: dev.azure.com
      credentials:
        - organizations:
            - <your-org>
          clientId: ${AZURE_CLIENT_ID}
          clientSecret: ${AZURE_CLIENT_SECRET}
          tenantId: ${AZURE_TENANT_ID}
"
            notes: "
Automated by CLI:
  ✓ Backend package installed
  ✓ Frontend package installed
  ✓ app-config.yaml updated
  ✓ packages/backend/src/index.ts patched
  ✓ EntityPage.tsx patched (import + EntitySwitch.Case in cicdContent)

Manual steps remaining:
  1. Add entity annotation to catalog-info.yaml:
       dev.azure.com/project-repo: <project>/<repo>

  2. Set environment variables: AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID
     (or use a Personal Access Token: personalAccessToken: \${AZURE_TOKEN})

  Docs: https://github.com/backstage/community-plugins/tree/main/workspaces/azure-devops
"
        }
        "github-actions": {
            name: "GitHub Actions"
            description: "View GitHub Actions workflow runs on entity pages"
            frontend_pkg: "@backstage-community/plugin-github-actions"
            backend_pkg:  ""
            app_config: "
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}
"
            notes: "
Automated by CLI:
  ✓ Frontend package installed
  ✓ app-config.yaml updated
  ✓ EntityPage.tsx patched (import + EntitySwitch.Case in cicdContent)

Manual steps remaining:
  1. Add entity annotation to catalog-info.yaml:
       github.com/project-slug: <org>/<repo>

  2. Set GITHUB_TOKEN environment variable.
"
        }
        "kubernetes": {
            name: "Kubernetes"
            description: "Kubernetes cluster resources and workloads on entity pages"
            frontend_pkg: "@backstage/plugin-kubernetes"
            backend_pkg:  "@backstage/plugin-kubernetes-backend"
            app_config: "
kubernetes:
  serviceLocatorMethod:
    type: multiTenant
  clusterLocatorMethods:
    - type: config
      clusters:
        - url: https://your-cluster-api-url
          name: my-cluster
          authProvider: serviceAccount
          serviceAccountToken: ${K8S_SERVICE_ACCOUNT_TOKEN}
          skipTLSVerify: false
"
            notes: "
Automated by CLI:
  ✓ Backend package installed
  ✓ Frontend package installed
  ✓ app-config.yaml updated
  ✓ packages/backend/src/index.ts patched
  ✓ EntityPage.tsx patched (import + route in serviceEntityPage)

Manual steps remaining:
  1. Add entity annotation to catalog-info.yaml:
       backstage.io/kubernetes-id: <service-name>

  2. Update app-config.yaml cluster URL and set K8S_SERVICE_ACCOUNT_TOKEN
     (or configure OIDC/other auth).
"
        }
        "techdocs": {
            name: "TechDocs"
            description: "Serve Markdown docs directly from source repositories"
            frontend_pkg: "@backstage/plugin-techdocs"
            backend_pkg:  "@backstage/plugin-techdocs-backend"
            app_config: "
techdocs:
  builder: local
  publisher:
    type: local
"
            notes: "
Automated by CLI:
  ✓ Backend package installed
  ✓ Frontend package installed
  ✓ app-config.yaml updated
  ✓ packages/backend/src/index.ts patched
  ✓ EntityPage.tsx patched (imports + techdocsContent + /docs route)

Manual steps remaining:
  1. Add entity annotation to catalog-info.yaml:
       backstage.io/techdocs-ref: dir:.
"
        }
        "argocd": {
            name: "Argo CD"
            description: "Argo CD deployment status and sync state on entity pages"
            frontend_pkg: "@roadiehq/backstage-plugin-argo-cd"
            backend_pkg:  "@roadiehq/backstage-plugin-argo-cd-backend"
            app_config: "
argocd:
  baseUrl: https://your-argocd-instance.example.com
  token: ${ARGOCD_AUTH_TOKEN}
"
            notes: "
Automated by CLI:
  ✓ Backend package installed
  ✓ Frontend package installed
  ✓ app-config.yaml updated
  ✓ packages/backend/src/index.ts patched

Manual steps remaining:
  1. Add entity annotation to catalog-info.yaml:
       argocd/app-name: <argocd-app-name>

  2. Add to EntityPage.tsx (inside overviewContent or serviceEntityPage):
       import { EntityArgoCDOverviewCard, isArgocdAvailable }
         from '@roadiehq/backstage-plugin-argo-cd';

       <EntitySwitch.Case if={isArgocdAvailable}>
         <Grid item sm={12}>
           <EntityArgoCDOverviewCard />
         </Grid>
       </EntitySwitch.Case>

  3. Set ARGOCD_AUTH_TOKEN environment variable.
"
        }
        "sonarqube": {
            name: "SonarQube"
            description: "Code quality and security analysis results on entity pages"
            frontend_pkg: "@backstage/plugin-sonarqube"
            backend_pkg:  "@backstage/plugin-sonarqube-backend"
            app_config: "
sonarqube:
  baseUrl: https://your-sonarqube-instance.example.com
  apiKey: ${SONARQUBE_TOKEN}
"
            notes: "
Automated by CLI:
  ✓ Backend package installed
  ✓ Frontend package installed
  ✓ app-config.yaml updated
  ✓ packages/backend/src/index.ts patched

Manual steps remaining:
  1. Add entity annotation to catalog-info.yaml:
       sonarqube.org/project-key: <project-key>

  2. Add to EntityPage.tsx (inside overviewContent or serviceEntityPage):
       import { EntitySonarQubeCard, isSonarQubeAvailable }
         from '@backstage/plugin-sonarqube';

       <EntitySwitch.Case if={isSonarQubeAvailable}>
         <Grid item sm={6}>
           <EntitySonarQubeCard variant='gridItem' />
         </Grid>
       </EntitySwitch.Case>

  3. Set SONARQUBE_TOKEN environment variable.
"
        }
        "kubernetes-ingestor": {
            name: "Kubernetes Ingestor"
            description: "Auto-ingest Kubernetes workloads, Crossplane claims, and XRDs as Backstage catalog entities"
            frontend_pkg: ""
            backend_pkg:  "@terasky/backstage-plugin-kubernetes-ingestor"
            app_config: "
kubernetesIngestor:
  mappings:
    namespaceModel: 'cluster'
    nameModel: 'name-cluster'
    titleModel: 'name'
    systemModel: 'namespace'
    referencesNamespaceModel: 'default'
  components:
    enabled: true
    ingestAsResources: false
    taskRunner:
      frequency: 10
      timeout: 600
    excludedNamespaces:
      - kube-public
      - kube-system
  crossplane:
    enabled: false
  kro:
    enabled: false
"
            notes: "
Automated by CLI:
  ✓ Backend package installed
  ✓ app-config.yaml updated
  ✓ packages/backend/src/index.ts patched

Manual steps remaining:
  1. (Optional) For Crossplane XRD / KRO template generation, install the utils module:
       cd <instance-path>/packages/backend && yarn add @terasky/backstage-plugin-scaffolder-backend-module-terasky-utils

     Then add to packages/backend/src/index.ts:
       backend.add(import('@backstage/plugin-scaffolder-backend-module-github'));
       backend.add(import('@terasky/backstage-plugin-scaffolder-backend-module-terasky-utils'));

  2. Apply RBAC to each Kubernetes cluster Backstage should read:
       kubectl apply -f - <<'EOF'
       apiVersion: rbac.authorization.k8s.io/v1
       kind: ClusterRole
       metadata:
         name: backstage-kubernetes-ingestor
       rules:
         - apiGroups: [\"*\"]
           resources: [\"*\"]
           verbs: [\"get\", \"list\", \"watch\"]
       ---
       apiVersion: rbac.authorization.k8s.io/v1
       kind: ClusterRoleBinding
       metadata:
         name: backstage-kubernetes-ingestor
       subjects:
         - kind: ServiceAccount
           name: backstage-kubernetes-ingestor
           namespace: backstage
       roleRef:
         kind: ClusterRole
         name: backstage-kubernetes-ingestor
         apiGroup: rbac.authorization.k8s.io
       EOF

  3. Ensure the Kubernetes plugin is also configured:
       platform plugin add kubernetes ./your-instance

  4. To enable Crossplane or KRO ingestion, set in app-config.yaml:
       kubernetesIngestor.crossplane.enabled: true
       kubernetesIngestor.kro.enabled: true

  Docs: https://terasky-oss.github.io/backstage-plugins/plugins/kubernetes-ingestor/overview
"
        }
        "crossplane-resources": {
            name: "Crossplane Resources"
            description: "View Crossplane claims, composite resources, managed resources, events, YAML, and dependency graph on entity pages"
            frontend_pkg: "@terasky/backstage-plugin-crossplane-resources-frontend"
            backend_pkg:  "@terasky/backstage-plugin-crossplane-resources-backend"
            app_config: "
permission:
  enabled: true

crossplane:
  enablePermissions: true
"
            notes: "
Automated by CLI:
  ✓ Backend package installed
  ✓ Frontend package installed
  ✓ app-config.yaml updated
  ✓ packages/backend/src/index.ts patched
  ✓ packages/app/src/apis.ts patched (CrossplaneApiClient factory)
  ✓ EntityPage.tsx patched (imports + CrossplaneEntityPage + componentPage cases)

Manual steps remaining:
  1. Works best with the kubernetes-ingestor plugin which auto-populates annotations:
       platform plugin add kubernetes-ingestor ./your-instance

  Docs: https://terasky-oss.github.io/backstage-plugins/plugins/crossplane/overview
"
        }

        "grafana": {
            name: "Grafana"
            description: "Grafana alerts and dashboards cards on entity overview pages"
            frontend_pkg: "@backstage-community/plugin-grafana"
            backend_pkg:  ""
            app_config: "
proxy:
  '/grafana/api':
    target: https://your-grafana.example.com/
    headers:
      Authorization: Bearer \${GRAFANA_TOKEN}

grafana:
  domain: https://your-grafana.example.com
  unifiedAlerting: false
"
            notes: "
Automated by CLI:
  ✓ Frontend package installed
  ✓ app-config.yaml updated
  ✓ EntityPage.tsx patched (alerts + dashboards cards in overviewContent)

Manual steps remaining:
  1. Update app-config.yaml grafana.domain and proxy target to your Grafana URL.
  2. Set GRAFANA_TOKEN environment variable.
  3. Add entity annotation for alerts (unified alerting):
       grafana/alert-label-selector: 'label=label-value'
     Or for legacy alerting:
       grafana/tag-selector: my-tag
  4. Add entity annotation for dashboards:
       grafana/dashboard-selector: my-service

  Docs: https://github.com/backstage/community-plugins/tree/main/workspaces/grafana
"
        }

        "holiday-tracker": {
            name: "Holiday Tracker"
            description: "Display holidays for any country/region using the Calendarific API"
            frontend_pkg: "@infosys_ltd/holiday-tracker-plugin"
            backend_pkg:  ""
            app_config: "
proxy:
  endpoints:
    '/holidays':
      target: 'https://calendarific.com/api/v2/holidays?api_key=\${HOLIDAY_TRACKER_ACCESS_KEY}&country=\${HOLIDAY_TRACKER_LOCATION}&year=\${HOLIDAY_TRACKER_YEAR}'
      changeOrigin: true
"
            notes: "
Automated by CLI:
  ✓ Frontend package installed
  ✓ app-config.yaml updated
  ✓ packages/app/src/App.tsx patched (import + /holidays route)

Manual steps remaining:
  1. Create a Calendarific account and generate an API key:
       https://calendarific.com/
  2. Set environment variables:
       export HOLIDAY_TRACKER_ACCESS_KEY=your_api_key
       export HOLIDAY_TRACKER_LOCATION=IN    # country code e.g. IN, US, GB
       export HOLIDAY_TRACKER_YEAR=2025
  3. Optionally add a sidebar entry pointing to /holidays.

  Docs: https://github.com/Infosys/holiday-tracker-plugin/blob/main/plugins/holiday-tracker/README.md
"
        }

        "cost-insights": {
            name: "Cost Insights"
            description: "Visualize, understand and optimize cloud costs per team and catalog entity"
            frontend_pkg: "@backstage-community/plugin-cost-insights"
            backend_pkg:  ""
            app_config: "
costInsights:
  engineerCost: 200000
  ## Optional: define cloud products for cost breakdown
  # products:
  #   cloudStorage:
  #     name: Cloud Storage
  #     icon: storage
  ## Optional: define business metrics for comparison
  # metrics:
  #   dailyActiveUsers:
  #     name: Daily Active Users
  #     default: true
"
            notes: "
Automated by CLI:
  ✓ Frontend package installed
  ✓ app-config.yaml updated
  ✓ packages/app/src/apis.ts patched (ExampleCostInsightsClient factory)
  ✓ packages/app/src/App.tsx patched (import + /cost-insights route)

Manual steps remaining:
  1. Replace ExampleCostInsightsClient in apis.ts with your real CostInsightsApi implementation.
     Use the template as a starting point:
       https://github.com/backstage/community-plugins/blob/main/workspaces/cost-insights/plugins/cost-insights/src/example/templates/CostInsightsClient.ts
  2. Update costInsights.engineerCost in app-config.yaml with your org's average engineer cost.
  3. Optionally add a sidebar entry in packages/app/src/components/Root/Root.tsx:
       import MoneyIcon from '@material-ui/icons/MonetizationOn';
       <SidebarItem icon={MoneyIcon} to=\"cost-insights\" text=\"Cost Insights\" />

  Docs: https://github.com/backstage/community-plugins/tree/main/workspaces/cost-insights/plugins/cost-insights
"
        }

        "infrawallet": {
            name: "InfraWallet"
            description: "Multi-cloud cost aggregation and visualization across AWS, Azure, GCP and more"
            frontend_pkg: "@electrolux-oss/plugin-infrawallet"
            backend_pkg:  "@electrolux-oss/plugin-infrawallet-backend"
            app_config: "
## InfraWallet frontend settings
infraWallet:
  settings:
    defaultGroupBy: none        # none, account, provider, category, service, or tag:<tag_key>
    defaultShowLastXMonths: 3   # recommended: less than 12

## InfraWallet backend integrations (add your cloud account credentials)
backend:
  infraWallet:
    integrations:
      ## AWS example
      # aws:
      #   - name: my-aws-account
      #     accountId: '123456789012'
      #     assumedRoleName: InfraWalletRole
      #     accessKeyId: \${AWS_ACCESS_KEY_ID}       # optional: only if using IAM user
      #     secretAccessKey: \${AWS_SECRET_ACCESS_KEY} # optional: only if using IAM user
      ## Azure example
      # azure:
      #   - name: my-azure-subscription
      #     subscriptionId: \${AZURE_SUBSCRIPTION_ID}
      #     tenantId: \${AZURE_TENANT_ID}
      #     clientId: \${AZURE_CLIENT_ID}
      #     clientSecret: \${AZURE_CLIENT_SECRET}
      ## GCP example
      # gcp:
      #   - name: my-gcp-project
      #     keyFilePath: /path/to/service-account.json
      #     projectId: my-gcp-project
      #     datasetId: billing_dataset
      #     tableId: gcp_billing_export_v1_XXXXXX
"
            notes: "
Automated by CLI:
  ✓ Frontend package installed
  ✓ Backend package installed
  ✓ app-config.yaml updated
  ✓ packages/backend/src/index.ts patched
  ✓ packages/app/src/App.tsx patched (import + /infrawallet route)

Manual steps remaining:
  1. Uncomment and fill in your cloud provider credentials in app-config.yaml
     under backend.infraWallet.integrations (AWS, Azure, GCP, etc.)
  2. For AWS: create an IAM role with ce:GetCostAndUsage and ce:GetTags permissions.
  3. For Azure: register an app and assign 'Cost Management Reader' on the subscription.
  4. For GCP: export billing to BigQuery and create a service account with BigQuery roles.
  5. Optionally add a sidebar entry in packages/app/src/components/Root/Root.tsx:
       import { InfraWalletIcon } from '@electrolux-oss/plugin-infrawallet';
       <SidebarItem icon={InfraWalletIcon} to=\"infrawallet\" text=\"InfraWallet\" />

  Docs: https://opensource.electrolux.one/infrawallet/
"
        }
    }
}

# Patch packages/backend/src/index.ts to register a plugin's backend module
def patch-backend-plugin-index [instance_path: string, plugin: record] {
    if ($plugin.backend_pkg | is-empty) { return }

    let index_path = ($instance_path + "/packages/backend/src/index.ts")
    if not ($index_path | path exists) {
        utils print-warning "packages/backend/src/index.ts not found — skipping backend patch"
        return
    }

    let content = (open --raw $index_path)
    let pkg = $plugin.backend_pkg

    if ($content | str contains $pkg) {
        utils print-info "index.ts already has this plugin registered"
        return
    }

    let new_line = $"backend.add\(import\('($pkg)'\)\);"
    let new_content = $content | str replace "backend.start();" ($new_line + "\n\nbackend.start();")

    $new_content | save --force $index_path
    utils print-success "packages/backend/src/index.ts updated"
}

# Patch EntityPage.tsx with TechDocs import, content variable, and docs route
def patch-entity-page-techdocs [instance_path: string] {
    let ep_path = ($instance_path + "/packages/app/src/components/catalog/EntityPage.tsx")
    if not ($ep_path | path exists) {
        utils print-warning "EntityPage.tsx not found — skipping"
        return
    }

    mut content = (open --raw $ep_path)
    mut patched = false

    # 1. Imports
    if not ($content | str contains "from '@backstage/plugin-techdocs'") {
        let imports = "import { EntityTechdocsContent } from '@backstage/plugin-techdocs';\nimport { TechDocsAddons } from '@backstage/plugin-techdocs-react';\nimport { ReportIssue } from '@backstage/plugin-techdocs-module-addons-contrib';\n"
        if ($content | str contains "\nconst cicdContent") {
            $content = ($content | str replace "\nconst cicdContent" ($imports + "\nconst cicdContent"))
            $patched = true
        }
    }

    # 2. Content variable
    if not ($content | str contains "const techdocsContent") {
        let content_var = "const techdocsContent = (\n  <EntityTechdocsContent>\n    <TechDocsAddons>\n      <ReportIssue />\n    </TechDocsAddons>\n  </EntityTechdocsContent>\n);\n\n"
        if ($content | str contains "\nconst cicdContent") {
            $content = ($content | str replace "\nconst cicdContent" ($content_var + "\nconst cicdContent"))
            $patched = true
        }
    }

    # 3. Docs route in serviceEntityPage (before websiteEntityPage)
    let service_close = "  </EntityLayout>\n);\n\nconst websiteEntityPage = ("
    if not ($content | str contains "path=\"/docs\"") {
        if ($content | str contains $service_close) {
            let route = "\n    <EntityLayout.Route path=\"/docs\" title=\"Docs\">\n      {techdocsContent}\n    </EntityLayout.Route>"
            $content = ($content | str replace $service_close ($route + "\n" + $service_close))
            $patched = true
        }
    }

    if $patched {
        $content | save --force $ep_path
        utils print-success "EntityPage.tsx updated"
    } else {
        utils print-info "EntityPage.tsx already has TechDocs configured"
    }
}

# Patch EntityPage.tsx with Kubernetes import and route
def patch-entity-page-kubernetes [instance_path: string] {
    let ep_path = ($instance_path + "/packages/app/src/components/catalog/EntityPage.tsx")
    if not ($ep_path | path exists) {
        utils print-warning "EntityPage.tsx not found — skipping"
        return
    }

    mut content = (open --raw $ep_path)
    mut patched = false

    # 1. Imports
    if not ($content | str contains "from '@backstage/plugin-kubernetes'") {
        let imports = "import {\n  EntityKubernetesContent,\n  isKubernetesAvailable,\n} from '@backstage/plugin-kubernetes';\n"
        if ($content | str contains "\nconst cicdContent") {
            $content = ($content | str replace "\nconst cicdContent" ($imports + "\nconst cicdContent"))
            $patched = true
        }
    }

    # 2. Route in serviceEntityPage (before websiteEntityPage)
    let service_close = "  </EntityLayout>\n);\n\nconst websiteEntityPage = ("
    if not ($content | str contains "path=\"/kubernetes\"") {
        if ($content | str contains $service_close) {
            let route = "\n    <EntityLayout.Route\n      path=\"/kubernetes\"\n      title=\"Kubernetes\"\n      if={isKubernetesAvailable}\n    >\n      <EntityKubernetesContent />\n    </EntityLayout.Route>"
            $content = ($content | str replace $service_close ($route + "\n" + $service_close))
            $patched = true
        }
    }

    if $patched {
        $content | save --force $ep_path
        utils print-success "EntityPage.tsx updated"
    } else {
        utils print-info "EntityPage.tsx already has Kubernetes configured"
    }
}

# Patch packages/app/src/apis.ts to register the Crossplane API factory
def patch-apis-crossplane-resources [instance_path: string] {
    let apis_path = ($instance_path + "/packages/app/src/apis.ts")
    if not ($apis_path | path exists) {
        utils print-warning "packages/app/src/apis.ts not found — skipping"
        return
    }

    mut content = (open --raw $apis_path)
    mut patched = false

    # 1. Crossplane frontend import
    if not ($content | str contains "crossplaneApiRef") {
        let crossplane_import = "import {
  CrossplaneApiClient,
  crossplaneApiRef,
} from '@terasky/backstage-plugin-crossplane-resources-frontend';
"
        $content = ($content | str replace "\nexport const apis" ($crossplane_import + "\nexport const apis"))
        $patched = true
    }

    # 2. discoveryApiRef / fetchApiRef (separate line if not already imported)
    if not ($content | str contains "discoveryApiRef") {
        let extra_import = "import { discoveryApiRef, fetchApiRef } from '@backstage/core-plugin-api';\n"
        $content = ($content | str replace "\nexport const apis" ($extra_import + "\nexport const apis"))
        $patched = true
    }

    # 3. Factory entry in the apis array (before closing ];)
    if not ($content | str contains "crossplaneApiRef,") {
        let factory = "  createApiFactory({
    api: crossplaneApiRef,
    deps: { discoveryApi: discoveryApiRef, fetchApi: fetchApiRef },
    factory: ({ discoveryApi, fetchApi }) =>
      new CrossplaneApiClient(discoveryApi, fetchApi),
  }),
"
        $content = ($content | str replace "\n];\n" ($factory + "\n];\n"))
        $patched = true
    }

    if $patched {
        $content | save --force $apis_path
        utils print-success "packages/app/src/apis.ts updated"
    } else {
        utils print-info "apis.ts already has Crossplane API factory"
    }
}

# Patch EntityPage.tsx with Crossplane imports, component, and switch cases
def patch-entity-page-crossplane-resources [instance_path: string] {
    let ep_path = ($instance_path + "/packages/app/src/components/catalog/EntityPage.tsx")
    if not ($ep_path | path exists) {
        utils print-warning "EntityPage.tsx not found — skipping"
        return
    }

    mut content = (open --raw $ep_path)
    mut patched = false

    # 1. Imports
    if not ($content | str contains "from '@terasky/backstage-plugin-crossplane-resources-frontend'") {
        let imports = "import {
  CrossplaneResourcesTableSelector,
  CrossplaneOverviewCardSelector,
  CrossplaneResourceGraphSelector,
  useResourceGraphAvailable,
  useResourcesListAvailable,
  IfCrossplaneOverviewAvailable,
  IfCrossplaneResourceGraphAvailable,
  IfCrossplaneResourcesListAvailable,
} from '@terasky/backstage-plugin-crossplane-resources-frontend';
"
        if ($content | str contains "\nconst cicdContent") {
            $content = ($content | str replace "\nconst cicdContent" ($imports + "\nconst cicdContent"))
            $patched = true
        }
    }

    # 2. CrossplaneEntityPage component definition (before componentPage)
    if not ($content | str contains "CrossplaneEntityPage") {
        let component_def = "const CrossplaneEntityPage = () => {
  const isResourcesListAvailable = useResourcesListAvailable();
  const isResourceGraphAvailable = useResourceGraphAvailable();
  return (
    <EntityLayout>
      <EntityLayout.Route path=\"/\" title=\"Overview\">
        <Grid container spacing={3}>
          <Grid item md={6}><EntityAboutCard variant=\"gridItem\" /></Grid>
          <IfCrossplaneOverviewAvailable>
            <Grid item md={6}><CrossplaneOverviewCardSelector /></Grid>
          </IfCrossplaneOverviewAvailable>
        </Grid>
      </EntityLayout.Route>
      <EntityLayout.Route if={isResourcesListAvailable} path=\"/crossplane-resources\" title=\"Crossplane Resources\">
        <IfCrossplaneResourcesListAvailable>
          <CrossplaneResourcesTableSelector />
        </IfCrossplaneResourcesListAvailable>
      </EntityLayout.Route>
      <EntityLayout.Route if={isResourceGraphAvailable} path=\"/crossplane-graph\" title=\"Crossplane Graph\">
        <IfCrossplaneResourceGraphAvailable>
          <CrossplaneResourceGraphSelector />
        </IfCrossplaneResourceGraphAvailable>
      </EntityLayout.Route>
    </EntityLayout>
  );
};

"
        if ($content | str contains "\nconst componentPage = (") {
            $content = ($content | str replace "\nconst componentPage = (" ($component_def + "\nconst componentPage = ("))
            $patched = true
        }
    }

    # 3. EntitySwitch.Case entries in componentPage (before its fallback case)
    # Include 'const apiPage' in the marker to distinguish from entityPage's identical fallback
    let component_fallback = "\n\n    <EntitySwitch.Case>{defaultEntityPage}</EntitySwitch.Case>\n  </EntitySwitch>\n);\n\nconst apiPage"
    if not ($content | str contains "crossplane-claim") {
        if ($content | str contains $component_fallback) {
            let cases = "\n\n    <EntitySwitch.Case if={isComponentType('crossplane-claim')}>\n      <CrossplaneEntityPage />\n    </EntitySwitch.Case>\n\n    <EntitySwitch.Case if={isComponentType('crossplane-xr')}>\n      <CrossplaneEntityPage />\n    </EntitySwitch.Case>"
            $content = ($content | str replace $component_fallback ($cases + $component_fallback))
            $patched = true
        }
    }

    if $patched {
        $content | save --force $ep_path
        utils print-success "EntityPage.tsx updated"
    } else {
        utils print-info "EntityPage.tsx already has Crossplane configured"
    }
}

# Dispatch apis.ts patching to the appropriate plugin handler
def patch-apis-cost-insights [instance_path: string] {
    let apis_path = ($instance_path + "/packages/app/src/apis.ts")
    if not ($apis_path | path exists) {
        utils print-warning "packages/app/src/apis.ts not found — skipping"
        return
    }

    mut content = (open --raw $apis_path)
    mut patched = false

    # 1. Import costInsightsApiRef + ExampleCostInsightsClient
    if not ($content | str contains "costInsightsApiRef") {
        let cost_import = "import { costInsightsApiRef, ExampleCostInsightsClient } from '@backstage-community/plugin-cost-insights';\n"
        $content = ($content | str replace "\nexport const apis" ($cost_import + "\nexport const apis"))
        $patched = true
    }

    # 2. Factory entry in the apis array (before closing ];)
    if not ($content | str contains "costInsightsApiRef,") {
        let factory = "  createApiFactory({
    api: costInsightsApiRef,
    deps: {},
    factory: () => new ExampleCostInsightsClient(),
  }),
"
        $content = ($content | str replace "\n];\n" ($factory + "\n];\n"))
        $patched = true
    }

    if $patched {
        $content | save --force $apis_path
        utils print-success "packages/app/src/apis.ts updated (CostInsights API factory)"
    } else {
        utils print-info "apis.ts already has CostInsights API factory"
    }
}

def patch-apis-ts [instance_path: string, plugin_name: string] {
    match $plugin_name {
        "crossplane-resources" => { patch-apis-crossplane-resources $instance_path }
        "cost-insights"        => { patch-apis-cost-insights        $instance_path }
        _ => {}
    }
}

# Patch EntityPage.tsx with Azure DevOps import and cicd switch case
def patch-entity-page-azure-devops [instance_path: string] {
    let ep_path = ($instance_path + "/packages/app/src/components/catalog/EntityPage.tsx")
    if not ($ep_path | path exists) {
        utils print-warning "EntityPage.tsx not found — skipping"
        return
    }

    mut content = (open --raw $ep_path)
    mut patched = false

    # 1. Import
    if not ($content | str contains "from '@backstage-community/plugin-azure-devops'") {
        let imports = "import {\n  EntityAzurePipelinesContent,\n  isAzureDevOpsAvailable,\n} from '@backstage-community/plugin-azure-devops';\n"
        if ($content | str contains "\nconst cicdContent") {
            $content = ($content | str replace "\nconst cicdContent" ($imports + "\nconst cicdContent"))
            $patched = true
        }
    }

    # 2. EntitySwitch.Case inside cicdContent (before the fallback EmptyState case)
    # The fallback case marker is unique to cicdContent
    let cicd_fallback = "\n    <EntitySwitch.Case>\n      <EmptyState"
    if not ($content | str contains "isAzureDevOpsAvailable") {
        if ($content | str contains $cicd_fallback) {
            let case_block = "\n    <EntitySwitch.Case if={isAzureDevOpsAvailable}>\n      <EntityAzurePipelinesContent defaultLimit={25} />\n    </EntitySwitch.Case>"
            $content = ($content | str replace $cicd_fallback ($case_block + $cicd_fallback))
            $patched = true
        }
    }

    if $patched {
        $content | save --force $ep_path
        utils print-success "EntityPage.tsx updated"
    } else {
        utils print-info "EntityPage.tsx already has Azure DevOps configured"
    }
}

# Patch EntityPage.tsx with GitHub Actions import and cicd switch case
def patch-entity-page-github-actions [instance_path: string] {
    let ep_path = ($instance_path + "/packages/app/src/components/catalog/EntityPage.tsx")
    if not ($ep_path | path exists) {
        utils print-warning "EntityPage.tsx not found — skipping"
        return
    }

    mut content = (open --raw $ep_path)
    mut patched = false

    # 1. Import
    if not ($content | str contains "from '@backstage-community/plugin-github-actions'") {
        let imports = "import {\n  EntityGithubActionsContent,\n  isGithubActionsAvailable,\n} from '@backstage-community/plugin-github-actions';\n"
        if ($content | str contains "\nconst cicdContent") {
            $content = ($content | str replace "\nconst cicdContent" ($imports + "\nconst cicdContent"))
            $patched = true
        }
    }

    # 2. EntitySwitch.Case inside cicdContent (before the fallback EmptyState case)
    let cicd_fallback = "\n    <EntitySwitch.Case>\n      <EmptyState"
    if not ($content | str contains "from '@backstage-community/plugin-github-actions'") {
        if ($content | str contains $cicd_fallback) {
            let case_block = "\n    <EntitySwitch.Case if={isGithubActionsAvailable}>\n      <EntityGithubActionsContent />\n    </EntitySwitch.Case>"
            $content = ($content | str replace $cicd_fallback ($case_block + $cicd_fallback))
            $patched = true
        }
    }

    if $patched {
        $content | save --force $ep_path
        utils print-success "EntityPage.tsx updated"
    } else {
        utils print-info "EntityPage.tsx already has GitHub Actions configured"
    }
}

# Dispatch EntityPage.tsx patching to the appropriate plugin handler
# Patch EntityPage.tsx with Grafana alerts and dashboards cards in overviewContent
def patch-entity-page-grafana [instance_path: string] {
    let ep_path = ($instance_path + "/packages/app/src/components/catalog/EntityPage.tsx")
    if not ($ep_path | path exists) {
        utils print-warning "EntityPage.tsx not found — skipping"
        return
    }

    mut content = (open --raw $ep_path)
    mut patched = false

    # 1. Import
    if not ($content | str contains "from '@backstage-community/plugin-grafana'") {
        let imports = "import { EntityGrafanaAlertsCard, EntityGrafanaDashboardsCard } from '@backstage-community/plugin-grafana';\n"
        if ($content | str contains "\nconst cicdContent") {
            $content = ($content | str replace "\nconst cicdContent" ($imports + "\nconst cicdContent"))
            $patched = true
        }
    }

    # 2. Cards in overviewContent (before its closing </Grid>)
    let overview_close = "\n  </Grid>\n);\n\nconst serviceEntityPage = ("
    if not ($content | str contains "<EntityGrafanaAlertsCard") {
        if ($content | str contains $overview_close) {
            let cards = "\n    <Grid item md={6} xs={12}>\n      <EntityGrafanaAlertsCard />\n    </Grid>\n    <Grid item md={6} xs={12}>\n      <EntityGrafanaDashboardsCard />\n    </Grid>"
            $content = ($content | str replace $overview_close ($cards + $overview_close))
            $patched = true
        }
    }

    if $patched {
        $content | save --force $ep_path
        utils print-success "EntityPage.tsx patched (Grafana alerts + dashboards cards)"
    } else {
        utils print-info "EntityPage.tsx already up to date for Grafana"
    }
}

def patch-entity-page [instance_path: string, plugin_name: string] {
    match $plugin_name {
        "techdocs"             => { patch-entity-page-techdocs             $instance_path }
        "kubernetes"           => { patch-entity-page-kubernetes            $instance_path }
        "azure-devops"         => { patch-entity-page-azure-devops          $instance_path }
        "github-actions"       => { patch-entity-page-github-actions        $instance_path }
        "crossplane-resources" => { patch-entity-page-crossplane-resources  $instance_path }
        "grafana"              => { patch-entity-page-grafana               $instance_path }
        _ => {
            utils print-info $"EntityPage.tsx patching for ($plugin_name) requires manual steps — see 'Next Steps' above"
        }
    }
}

# Patch packages/app/src/App.tsx to add the HolidayTrackerPage import and route
def patch-app-tsx-holiday-tracker [instance_path: string] {
    let app_path = ($instance_path + "/packages/app/src/App.tsx")
    if not ($app_path | path exists) {
        utils print-warning "packages/app/src/App.tsx not found — skipping"
        return
    }

    mut content = (open --raw $app_path)
    mut patched = false

    # 1. Import (inject before `const app = createApp`)
    if not ($content | str contains "from '@infosys_ltd/holiday-tracker-plugin'") {
        let import_line = "import { HolidayTrackerPage } from '@infosys_ltd/holiday-tracker-plugin';\n"
        if ($content | str contains "\nconst app = createApp") {
            $content = ($content | str replace "\nconst app = createApp" ($import_line + "\nconst app = createApp"))
            $patched = true
        }
    }

    # 2. Route (inject before `</FlatRoutes>`)
    let flat_routes_close = "\n  </FlatRoutes>\n);"
    if not ($content | str contains "<HolidayTrackerPage") {
        if ($content | str contains $flat_routes_close) {
            let route = "\n    <Route path=\"/holidays\" element={<HolidayTrackerPage />} />"
            $content = ($content | str replace $flat_routes_close ($route + $flat_routes_close))
            $patched = true
        }
    }

    if $patched {
        $content | save --force $app_path
        utils print-success "packages/app/src/App.tsx patched (HolidayTrackerPage import + route)"
    } else {
        utils print-info "App.tsx already up to date for Holiday Tracker"
    }
}

# Patch packages/app/src/App.tsx to add the CostInsightsPage import and route
def patch-app-tsx-cost-insights [instance_path: string] {
    let app_path = ($instance_path + "/packages/app/src/App.tsx")
    if not ($app_path | path exists) {
        utils print-warning "packages/app/src/App.tsx not found — skipping"
        return
    }

    mut content = (open --raw $app_path)
    mut patched = false

    # 1. Import (inject before `const app = createApp`)
    if not ($content | str contains "from '@backstage-community/plugin-cost-insights'") {
        let import_line = "import { CostInsightsPage } from '@backstage-community/plugin-cost-insights';\n"
        if ($content | str contains "\nconst app = createApp") {
            $content = ($content | str replace "\nconst app = createApp" ($import_line + "\nconst app = createApp"))
            $patched = true
        }
    }

    # 2. Route (inject before `</FlatRoutes>`)
    let flat_routes_close = "\n  </FlatRoutes>\n);"
    if not ($content | str contains "<CostInsightsPage") {
        if ($content | str contains $flat_routes_close) {
            let route = "\n    <Route path=\"/cost-insights\" element={<CostInsightsPage />} />"
            $content = ($content | str replace $flat_routes_close ($route + $flat_routes_close))
            $patched = true
        }
    }

    if $patched {
        $content | save --force $app_path
        utils print-success "packages/app/src/App.tsx patched (CostInsightsPage import + route)"
    } else {
        utils print-info "App.tsx already up to date for Cost Insights"
    }
}

# Patch packages/app/src/App.tsx to add the InfraWalletPage import and route
def patch-app-tsx-infrawallet [instance_path: string] {
    let app_path = ($instance_path + "/packages/app/src/App.tsx")
    if not ($app_path | path exists) {
        utils print-warning "packages/app/src/App.tsx not found — skipping"
        return
    }

    mut content = (open --raw $app_path)
    mut patched = false

    # 1. Import (inject before `const app = createApp`)
    if not ($content | str contains "from '@electrolux-oss/plugin-infrawallet'") {
        let import_line = "import { InfraWalletPage } from '@electrolux-oss/plugin-infrawallet';\n"
        if ($content | str contains "\nconst app = createApp") {
            $content = ($content | str replace "\nconst app = createApp" ($import_line + "\nconst app = createApp"))
            $patched = true
        }
    }

    # 2. Route (inject before `</FlatRoutes>`)
    let flat_routes_close = "\n  </FlatRoutes>\n);"
    if not ($content | str contains "<InfraWalletPage") {
        if ($content | str contains $flat_routes_close) {
            let route = "\n    <Route path=\"/infrawallet\" element={<InfraWalletPage />} />"
            $content = ($content | str replace $flat_routes_close ($route + $flat_routes_close))
            $patched = true
        }
    }

    if $patched {
        $content | save --force $app_path
        utils print-success "packages/app/src/App.tsx patched (InfraWalletPage import + route)"
    } else {
        utils print-info "App.tsx already up to date for InfraWallet"
    }
}

def patch-app-tsx [instance_path: string, plugin_name: string] {
    match $plugin_name {
        "holiday-tracker" => { patch-app-tsx-holiday-tracker $instance_path }
        "cost-insights"   => { patch-app-tsx-cost-insights   $instance_path }
        "infrawallet"     => { patch-app-tsx-infrawallet      $instance_path }
        _ => {}
    }
}

# Install a plugin into a Backstage instance
export def add-plugin [
    plugin_name: string       # Plugin ID (e.g. azure-devops). Use 'plugin list' to see all.
    instance_path: string     # Path to the Backstage instance root
    --frontend-only           # Only install the frontend package
    --backend-only            # Only install the backend package
    --skip-config             # Skip appending the app-config.yaml snippet
] {
    let registry = (plugin-registry)

    if not ($plugin_name in $registry) {
        utils print-error $"Unknown plugin: ($plugin_name)"
        utils print-info $"Run 'platform plugin list' to see available plugins"
        exit 1
    }

    let plugin = ($registry | get $plugin_name)
    let instance_path = ($instance_path | path expand)

    if not ($instance_path | path exists) {
        utils print-error $"Instance path not found: ($instance_path)"
        exit 1
    }

    utils print-header $"Installing Plugin: ($plugin.name)"
    utils print-info $"($plugin.description)"
    print ""

    # ── Frontend ─────────────────────────────────────────────────────────────
    if (not $backend_only) and ($plugin.frontend_pkg | is-not-empty) {
        let app_dir = ($instance_path + "/packages/app")
        if ($app_dir | path exists) {
            utils print-info $"Installing frontend: ($plugin.frontend_pkg)"
            let result = (do { cd $app_dir; ^yarn add $plugin.frontend_pkg } | complete)
            if $result.exit_code == 0 {
                utils print-success $"Frontend package installed"
            } else {
                utils print-error $"Frontend install failed — run manually:"
                utils print-info  $"  yarn --cwd ($app_dir) add ($plugin.frontend_pkg)"
            }
        } else {
            utils print-warning $"packages/app not found — skipping frontend install"
            utils print-info    $"  Run manually: yarn --cwd ($app_dir) add ($plugin.frontend_pkg)"
        }
    }

    # ── Backend ──────────────────────────────────────────────────────────────
    if (not $frontend_only) and ($plugin.backend_pkg | is-not-empty) {
        let backend_dir = ($instance_path + "/packages/backend")
        if ($backend_dir | path exists) {
            utils print-info $"Installing backend:  ($plugin.backend_pkg)"
            let result = (do { cd $backend_dir; ^yarn add $plugin.backend_pkg } | complete)
            if $result.exit_code == 0 {
                utils print-success $"Backend package installed"
            } else {
                utils print-error $"Backend install failed — run manually:"
                utils print-info  $"  yarn --cwd ($backend_dir) add ($plugin.backend_pkg)"
            }
        } else {
            utils print-warning $"packages/backend not found — skipping backend install"
            utils print-info    $"  Run manually: yarn --cwd ($backend_dir) add ($plugin.backend_pkg)"
        }
    }

    # ── app-config.yaml ──────────────────────────────────────────────────────
    if not $skip_config {
        let config_path = ($instance_path + "/app-config.yaml")
        if ($config_path | path exists) {
            let existing = (open --raw $config_path)
            # Only append if snippet not already present
            let marker = ($plugin.app_config | str trim | lines | get 0)
            if not ($existing | str contains $marker) {
                ($existing + $"\n# --- ($plugin.name) plugin ---\n" + $plugin.app_config) | save --force $config_path
                utils print-success "app-config.yaml updated with plugin configuration"
            } else {
                utils print-info "app-config.yaml already contains this plugin's config"
            }
        } else {
            utils print-warning "app-config.yaml not found — skipping config update"
        }
    }

    # ── Post-install notes ────────────────────────────────────────────────────
    print ""
    utils print-header "Next Steps"
    print $plugin.notes

    # ── Auto-patch source files ───────────────────────────────────────────────
    utils print-header "Patching Source Files"
    if not $frontend_only {
        patch-backend-plugin-index $instance_path $plugin
    }
    if not $backend_only {
        patch-apis-ts $instance_path $plugin_name
        patch-entity-page $instance_path $plugin_name
        patch-app-tsx $instance_path $plugin_name
    }

    utils print-success $"Plugin ($plugin.name) installation complete"
}

# Remove a plugin from a Backstage instance
export def remove-plugin [
    plugin_name: string
    instance_path: string
] {
    let registry = (plugin-registry)

    if not ($plugin_name in $registry) {
        utils print-error $"Unknown plugin: ($plugin_name)"
        exit 1
    }

    let plugin = ($registry | get $plugin_name)
    let instance_path = ($instance_path | path expand)

    utils print-header $"Removing Plugin: ($plugin.name)"

    if ($plugin.frontend_pkg | is-not-empty) {
        let app_dir = ($instance_path + "/packages/app")
        if ($app_dir | path exists) {
            utils print-info $"Removing frontend: ($plugin.frontend_pkg)"
            do { ^yarn --cwd $app_dir remove $plugin.frontend_pkg } | ignore
            utils print-success "Frontend package removed"
        }
    }

    if ($plugin.backend_pkg | is-not-empty) {
        let backend_dir = ($instance_path + "/packages/backend")
        if ($backend_dir | path exists) {
            utils print-info $"Removing backend: ($plugin.backend_pkg)"
            do { ^yarn --cwd $backend_dir remove $plugin.backend_pkg } | ignore
            utils print-success "Backend package removed"
        }
    }

    utils print-success $"Plugin ($plugin.name) removed"
    utils print-warning "Remember to also remove any manual code changes in EntityPage.tsx and app-config.yaml"
}

# List all available plugins
export def list-available-plugins [] {
    let registry = (plugin-registry)

    utils print-header "Available Plugins"
    print ""

    let colors = (config get-colors)
    $registry | items {|id, plugin|
        print $"  ($colors.cyan)($colors.bold)($id)($colors.reset)"
        print $"    ($plugin.description)"
        if ($plugin.frontend_pkg | is-not-empty) {
            print $"    frontend:  ($plugin.frontend_pkg)"
        }
        if ($plugin.backend_pkg | is-not-empty) {
            print $"    backend:   ($plugin.backend_pkg)"
        }
        print ""
    } | ignore
}

# Show detailed info and install instructions for a plugin
export def show-plugin-info [plugin_name: string] {
    let registry = (plugin-registry)

    if not ($plugin_name in $registry) {
        utils print-error $"Unknown plugin: ($plugin_name)"
        utils print-info "Run 'platform plugin list' to see available plugins"
        exit 1
    }

    let plugin = ($registry | get $plugin_name)

    utils print-header $"Plugin: ($plugin.name)"
    print ""
    print $"  Description: ($plugin.description)"
    if ($plugin.frontend_pkg | is-not-empty) {
        print $"  Frontend package:  ($plugin.frontend_pkg)"
    }
    if ($plugin.backend_pkg | is-not-empty) {
        print $"  Backend package:   ($plugin.backend_pkg)"
    }
    print ""
    utils print-header "app-config.yaml snippet"
    print $plugin.app_config
    utils print-header "Post-install Notes"
    print $plugin.notes
}
