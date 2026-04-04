# cluster.nu — Kubernetes cluster configuration management for Backstage
#
# Provides commands to:
#   - Create/update a ServiceAccount and ClusterRole/ClusterRoleBinding on a cluster
#   - Generate (or rotate) a service account token
#   - Add or update the cluster entry in app-config.local.yaml

use ./utils.nu

# ── RBAC manifest builder ─────────────────────────────────────────────────────

# Build a combined multi-document YAML manifest for the ServiceAccount,
# ClusterRole, and ClusterRoleBinding that Backstage needs to read
# Kubernetes resources. Covers all resource types queried by the plugin.
export def build-sa-rbac-manifest [
    sa_name: string   # ServiceAccount name
    namespace: string # Namespace for the ServiceAccount
] {
$"apiVersion: v1
kind: ServiceAccount
metadata:
  name: ($sa_name)
  namespace: ($namespace)
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ($sa_name)
rules:
- apiGroups: [\"\"]
  resources: [pods, services, configmaps, events, namespaces, limitranges, resourcequotas]
  verbs: [get, list, watch]
- apiGroups: [apps]
  resources: [deployments, replicasets, statefulsets, daemonsets]
  verbs: [get, list, watch]
- apiGroups: [autoscaling]
  resources: [horizontalpodautoscalers]
  verbs: [get, list, watch]
- apiGroups: [networking.k8s.io]
  resources: [ingresses]
  verbs: [get, list, watch]
- apiGroups: [batch]
  resources: [jobs, cronjobs]
  verbs: [get, list, watch]
- apiGroups: [metrics.k8s.io]
  resources: [pods, nodes]
  verbs: [get, list]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ($sa_name)
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ($sa_name)
subjects:
- kind: ServiceAccount
  name: ($sa_name)
  namespace: ($namespace)
"
}

# ── Pure config manipulation ──────────────────────────────────────────────────

# Insert or update a cluster entry in a parsed app-config record.
#
# Behaviour:
#   - If the kubernetes section is missing, creates it.
#   - If no config-type clusterLocatorMethod exists, adds one.
#   - If a cluster with the same name exists, replaces it (token rotation).
#   - Otherwise appends the new cluster (multi-cluster support).
#
# Does NOT add serviceLocatorMethod — that lives in app-config.yaml (base).
export def upsert-cluster-in-config [
    config: record        # Parsed app-config record (`open app-config.local.yaml` or `{}`)
    cluster_entry: record # Cluster record to insert/update
] {
    let existing_k8s     = ($config | get -o kubernetes | default {})
    let existing_methods = ($existing_k8s | get -o clusterLocatorMethods | default [])

    # Find the index of the config-type locator (if any)
    let config_locator_idx = (
        $existing_methods
        | enumerate
        | where { |e| ($e.item | get -o type | default "") == "config" }
        | get 0?.index?
    )

    let updated_methods = if ($config_locator_idx != null) {
        # Config-type locator exists — upsert cluster inside it
        let existing_clusters = (
            $existing_methods | get $config_locator_idx | get -o clusters | default []
        )
        let existing_cluster_idx = (
            $existing_clusters
            | enumerate
            | where { |e| ($e.item | get -o name | default "") == $cluster_entry.name }
            | get 0?.index?
        )
        let updated_clusters = if ($existing_cluster_idx != null) {
            # Replace existing entry (token rotation)
            $existing_clusters | enumerate | each { |e|
                if $e.index == $existing_cluster_idx { $cluster_entry } else { $e.item }
            }
        } else {
            # Append new cluster
            $existing_clusters | append $cluster_entry
        }
        $existing_methods | enumerate | each { |e|
            if $e.index == $config_locator_idx {
                $e.item | upsert clusters $updated_clusters
            } else {
                $e.item
            }
        }
    } else {
        # No config-type locator found — create one with this cluster
        $existing_methods | append { type: "config", clusters: [$cluster_entry] }
    }

    let updated_k8s = ($existing_k8s | upsert clusterLocatorMethods $updated_methods)
    $config | upsert kubernetes $updated_k8s
}

# ── kubectl helpers ───────────────────────────────────────────────────────────

# Build optional --kubeconfig / --context flags string for kubectl calls
def kube-flags [kubeconfig: string, context: string] {
    mut flags = ""
    if ($kubeconfig | is-not-empty) { $flags = $flags + $" --kubeconfig ($kubeconfig)" }
    if ($context    | is-not-empty) { $flags = $flags + $" --context ($context)" }
    $flags
}

# ── Main command ──────────────────────────────────────────────────────────────

# Create or update a Kubernetes cluster configuration in app-config.local.yaml.
#
# This command is idempotent:
#   - Re-running it rotates the token for an existing cluster entry.
#   - Running it with a new --cluster-name appends a second cluster.
#
# What it does:
#   1. Creates/updates the ServiceAccount, ClusterRole, ClusterRoleBinding
#      on the target cluster (kubectl apply, safe to re-run).
#   2. Generates a fresh service account token (default: 1 year).
#   3. Auto-detects the cluster URL from the active kubeconfig.
#   4. Writes (or updates) the cluster block in app-config.local.yaml.
#
# Use --dry-run to preview all steps without making any changes.
export def configure-cluster [
    backstage_path: string                  # Path to the Backstage instance root
    --cluster-name: string                  # Name for this cluster in Backstage (required)
    --kubeconfig: string = ""               # Path to kubeconfig file (default: ~/.kube/config)
    --context: string = ""                  # Kubeconfig context to use
    --sa-name: string = "backstage-reader"  # ServiceAccount name to create/use
    --namespace: string = "default"         # Namespace for the ServiceAccount
    --duration: string = "8760h"            # Token lifetime (default: 8760h = 1 year)
    --skip-tls-verify = false               # Disable TLS certificate verification
    --dry-run = false                       # Preview what would happen without making changes
] {
    utils require-command "kubectl" "kubectl (https://kubernetes.io/docs/tasks/tools/)"

    if ($cluster_name | is-empty) {
        utils print-error "--cluster-name is required"
        exit 1
    }

    let expanded = ($backstage_path | path expand)
    if not ($expanded | path exists) {
        utils print-error $"Backstage instance path not found: ($expanded)"
        exit 1
    }

    let flags = (kube-flags $kubeconfig $context)

    if $dry_run {
        utils print-warning "DRY-RUN mode — no changes will be made"
    }

    # ── 1. Create/update ServiceAccount + RBAC ──────────────────────────────
    utils print-header "ServiceAccount and RBAC"
    utils print-info $"ServiceAccount: ($sa_name) in namespace ($namespace)"

    let manifest = (build-sa-rbac-manifest $sa_name $namespace)

    if $dry_run {
        utils print-info "Would apply the following manifest:"
        print $manifest
    } else {
        let tmp = $"/tmp/backstage-sa-rbac-(date now | format date '%Y%m%d%H%M%S%f').yaml"
        $manifest | save --force $tmp
        try {
            ^bash -c $"kubectl apply -f ($tmp)($flags)"
        } catch {
            rm $tmp
            utils print-error "Failed to create ServiceAccount/RBAC"
            exit 1
        }
        rm $tmp
        utils print-success $"ServiceAccount '($sa_name)' and RBAC ready"
    }

    # ── 2. Detect cluster URL (safe to read in dry-run) ───────────────────────
    utils print-header "Cluster URL"
    let cluster_url = try {
        ^bash -c $"kubectl config view --minify -o jsonpath='\{.clusters[0].cluster.server\}'($flags)" | str trim
    } catch {
        utils print-error "Failed to get cluster URL from kubeconfig. Is kubectl configured?"
        exit 1
    }
    if ($cluster_url | is-empty) {
        utils print-error "Cluster URL is empty — check your kubeconfig context"
        exit 1
    }
    utils print-info $"Cluster URL: ($cluster_url)"

    # ── 3. Generate service account token ────────────────────────────────────
    utils print-header "Service Account Token"
    if $dry_run {
        utils print-info $"Would generate token for ($sa_name) in namespace ($namespace), duration: ($duration)"
    } else {
        let token = try {
            ^bash -c $"kubectl create token ($sa_name) -n ($namespace) --duration ($duration)($flags)" | str trim
        } catch {
            utils print-error "Failed to generate service account token"
            exit 1
        }
        utils print-success $"Token generated — expires in ($duration)"

        # ── 4. Upsert cluster in app-config.local.yaml ───────────────────────
        utils print-header "Backstage Config"
        let config_path = ($expanded + "/app-config.local.yaml")
        let existing_config = if ($config_path | path exists) { open $config_path } else { {} }

        let cluster_entry = {
            url: $cluster_url
            name: $cluster_name
            authProvider: "serviceAccount"
            serviceAccountToken: $token
            skipTLSVerify: $skip_tls_verify
        }

        let updated_config = (upsert-cluster-in-config $existing_config $cluster_entry)
        $updated_config | to yaml | save --force $config_path

        utils print-success $"Cluster '($cluster_name)' written to app-config.local.yaml"
        utils print-warning "Restart Backstage (yarn start) to apply the new cluster configuration"
    }

    if $dry_run {
        utils print-header "Dry-run Summary"
        utils print-info $"cluster-name:    ($cluster_name)"
        utils print-info $"cluster-url:     ($cluster_url)"
        utils print-info $"sa-name:         ($sa_name)"
        utils print-info $"namespace:       ($namespace)"
        utils print-info $"duration:        ($duration)"
        utils print-info $"skip-tls-verify: ($skip_tls_verify)"
        utils print-info $"config-target:   (($expanded) + '/app-config.local.yaml')"
        utils print-warning "Re-run without --dry-run to apply these changes"
    }
}

# List all Kubernetes clusters configured in app-config.local.yaml.
export def list-clusters [
    backstage_path: string  # Path to the Backstage instance root
] {
    let config_path = (($backstage_path | path expand) + "/app-config.local.yaml")

    if not ($config_path | path exists) {
        utils print-warning "app-config.local.yaml not found — no clusters configured"
        return
    }

    let config  = (open $config_path)
    let methods = ($config | get -o kubernetes.clusterLocatorMethods | default [])
    let clusters = (
        $methods
        | where { |m| ($m | get -o type | default "") == "config" }
        | each { |m| $m | get -o clusters | default [] }
        | flatten
    )

    if ($clusters | is-empty) {
        utils print-warning "No clusters configured in the kubernetes block"
        return
    }

    utils print-header "Configured Kubernetes Clusters"
    for c in $clusters {
        let name     = ($c | get -o name     | default "(unnamed)")
        let url      = ($c | get -o url      | default "(no url)")
        let auth     = ($c | get -o authProvider | default "(unknown)")
        let tls_skip = ($c | get -o skipTLSVerify | default false)
        let has_token = ($c | get -o serviceAccountToken | default "" | is-not-empty)
        print $"  • ($name)"
        print $"      url:           ($url)"
        print $"      authProvider:  ($auth)"
        print $"      skipTLSVerify: ($tls_skip)"
        print $"      token:         (if $has_token { '✓ present' } else { '✗ missing' })"
        print ""
    }
}
