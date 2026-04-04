use std assert
use ./helpers.nu *
use ../modules/cluster.nu *

def main [] {
    let tests = [

        # ── build-sa-rbac-manifest ────────────────────────────────────────────
        ["build-sa-rbac-manifest: contains ServiceAccount kind", {
            let m = (build-sa-rbac-manifest "backstage-reader" "default")
            assert ($m | str contains "kind: ServiceAccount")
        }],
        ["build-sa-rbac-manifest: ServiceAccount uses given name", {
            let m = (build-sa-rbac-manifest "my-sa" "default")
            assert ($m | str contains "name: my-sa")
        }],
        ["build-sa-rbac-manifest: ServiceAccount uses given namespace", {
            let m = (build-sa-rbac-manifest "backstage-reader" "my-ns")
            assert ($m | str contains "namespace: my-ns")
        }],
        ["build-sa-rbac-manifest: contains ClusterRole kind", {
            let m = (build-sa-rbac-manifest "backstage-reader" "default")
            assert ($m | str contains "kind: ClusterRole")
        }],
        ["build-sa-rbac-manifest: contains ClusterRoleBinding kind", {
            let m = (build-sa-rbac-manifest "backstage-reader" "default")
            assert ($m | str contains "kind: ClusterRoleBinding")
        }],
        ["build-sa-rbac-manifest: ClusterRole covers core resources", {
            let m = (build-sa-rbac-manifest "backstage-reader" "default")
            assert ($m | str contains "pods")
            assert ($m | str contains "services")
            assert ($m | str contains "configmaps")
            assert ($m | str contains "limitranges")
            assert ($m | str contains "resourcequotas")
        }],
        ["build-sa-rbac-manifest: ClusterRole covers apps resources", {
            let m = (build-sa-rbac-manifest "backstage-reader" "default")
            assert ($m | str contains "deployments")
            assert ($m | str contains "replicasets")
            assert ($m | str contains "statefulsets")
            assert ($m | str contains "daemonsets")
        }],
        ["build-sa-rbac-manifest: ClusterRole covers batch resources", {
            let m = (build-sa-rbac-manifest "backstage-reader" "default")
            assert ($m | str contains "jobs")
            assert ($m | str contains "cronjobs")
        }],
        ["build-sa-rbac-manifest: ClusterRole covers metrics resources", {
            let m = (build-sa-rbac-manifest "backstage-reader" "default")
            assert ($m | str contains "metrics.k8s.io")
        }],
        ["build-sa-rbac-manifest: ClusterRole covers ingresses", {
            let m = (build-sa-rbac-manifest "backstage-reader" "default")
            assert ($m | str contains "ingresses")
        }],
        ["build-sa-rbac-manifest: ClusterRole covers HPAs", {
            let m = (build-sa-rbac-manifest "backstage-reader" "default")
            assert ($m | str contains "horizontalpodautoscalers")
        }],
        ["build-sa-rbac-manifest: is multi-document YAML (has --- separator)", {
            let m = (build-sa-rbac-manifest "backstage-reader" "default")
            assert ($m | str contains "---")
        }],
        ["build-sa-rbac-manifest: ClusterRoleBinding references same SA name", {
            let m = (build-sa-rbac-manifest "my-reader" "custom-ns")
            let binding_section = ($m | split row "---" | get 2)
            assert ($binding_section | str contains "name: my-reader")
            assert ($binding_section | str contains "namespace: custom-ns")
        }],

        # ── upsert-cluster-in-config: empty config ────────────────────────────
        ["upsert-cluster-in-config: creates kubernetes section in empty config", {
            let entry = {url: "https://127.0.0.1:6443", name: "my-cluster", authProvider: "serviceAccount", serviceAccountToken: "tok", skipTLSVerify: true}
            let result = (upsert-cluster-in-config {} $entry)
            assert (($result | get -i kubernetes) != null)
        }],
        ["upsert-cluster-in-config: creates clusterLocatorMethods in empty config", {
            let entry = {url: "https://127.0.0.1:6443", name: "my-cluster", authProvider: "serviceAccount", serviceAccountToken: "tok", skipTLSVerify: true}
            let result = (upsert-cluster-in-config {} $entry)
            assert (($result | get -i kubernetes.clusterLocatorMethods | default [] | is-not-empty))
        }],
        ["upsert-cluster-in-config: cluster is added in empty config", {
            let entry = {url: "https://127.0.0.1:6443", name: "my-cluster", authProvider: "serviceAccount", serviceAccountToken: "tok", skipTLSVerify: true}
            let result = (upsert-cluster-in-config {} $entry)
            let clusters = ($result | get -i kubernetes.clusterLocatorMethods | default [] | where {|m| ($m | get -i type | default "") == "config"} | get 0?.clusters? | default [])
            assert (($clusters | length) == 1)
        }],
        ["upsert-cluster-in-config: cluster name is preserved", {
            let entry = {url: "https://127.0.0.1:6443", name: "kind-backstage", authProvider: "serviceAccount", serviceAccountToken: "tok", skipTLSVerify: false}
            let result = (upsert-cluster-in-config {} $entry)
            let clusters = ($result | get -i kubernetes.clusterLocatorMethods | default [] | where {|m| ($m | get -i type | default "") == "config"} | get 0?.clusters? | default [])
            assert (($clusters | get 0.name) == "kind-backstage")
        }],
        ["upsert-cluster-in-config: cluster url is preserved", {
            let entry = {url: "https://127.0.0.1:6443", name: "kind-backstage", authProvider: "serviceAccount", serviceAccountToken: "tok", skipTLSVerify: false}
            let result = (upsert-cluster-in-config {} $entry)
            let clusters = ($result | get -i kubernetes.clusterLocatorMethods | default [] | where {|m| ($m | get -i type | default "") == "config"} | get 0?.clusters? | default [])
            assert (($clusters | get 0.url) == "https://127.0.0.1:6443")
        }],

        # ── upsert-cluster-in-config: append second cluster ───────────────────
        ["upsert-cluster-in-config: appends second cluster without removing first", {
            let entry1 = {url: "https://a:6443", name: "cluster-a", authProvider: "serviceAccount", serviceAccountToken: "tok1", skipTLSVerify: false}
            let entry2 = {url: "https://b:6443", name: "cluster-b", authProvider: "serviceAccount", serviceAccountToken: "tok2", skipTLSVerify: false}
            let after_first  = (upsert-cluster-in-config {} $entry1)
            let after_second = (upsert-cluster-in-config $after_first $entry2)
            let clusters = ($after_second | get -i kubernetes.clusterLocatorMethods | default [] | where {|m| ($m | get -i type | default "") == "config"} | get 0?.clusters? | default [])
            assert (($clusters | length) == 2)
        }],
        ["upsert-cluster-in-config: second cluster has correct name", {
            let entry1 = {url: "https://a:6443", name: "cluster-a", authProvider: "serviceAccount", serviceAccountToken: "tok1", skipTLSVerify: false}
            let entry2 = {url: "https://b:6443", name: "cluster-b", authProvider: "serviceAccount", serviceAccountToken: "tok2", skipTLSVerify: false}
            let after_first  = (upsert-cluster-in-config {} $entry1)
            let after_second = (upsert-cluster-in-config $after_first $entry2)
            let clusters = ($after_second | get -i kubernetes.clusterLocatorMethods | default [] | where {|m| ($m | get -i type | default "") == "config"} | get 0?.clusters? | default [])
            let names = ($clusters | get name)
            assert ("cluster-a" in $names)
            assert ("cluster-b" in $names)
        }],

        # ── upsert-cluster-in-config: token rotation ──────────────────────────
        ["upsert-cluster-in-config: rotating token updates existing cluster", {
            let entry1 = {url: "https://127.0.0.1:6443", name: "kind-backstage", authProvider: "serviceAccount", serviceAccountToken: "old-token", skipTLSVerify: true}
            let entry2 = {url: "https://127.0.0.1:6443", name: "kind-backstage", authProvider: "serviceAccount", serviceAccountToken: "new-token", skipTLSVerify: true}
            let after_first  = (upsert-cluster-in-config {} $entry1)
            let after_rotate = (upsert-cluster-in-config $after_first $entry2)
            let clusters = ($after_rotate | get -i kubernetes.clusterLocatorMethods | default [] | where {|m| ($m | get -i type | default "") == "config"} | get 0?.clusters? | default [])
            assert (($clusters | length) == 1) "Should not add a duplicate entry"
            assert (($clusters | get 0.serviceAccountToken) == "new-token")
        }],
        ["upsert-cluster-in-config: rotation preserves other clusters", {
            let entry1 = {url: "https://a:6443", name: "cluster-a", authProvider: "serviceAccount", serviceAccountToken: "tok1", skipTLSVerify: false}
            let entry2 = {url: "https://b:6443", name: "cluster-b", authProvider: "serviceAccount", serviceAccountToken: "tok2", skipTLSVerify: false}
            let rotated_a = {url: "https://a:6443", name: "cluster-a", authProvider: "serviceAccount", serviceAccountToken: "new-tok1", skipTLSVerify: false}
            let config = (upsert-cluster-in-config (upsert-cluster-in-config {} $entry1) $entry2)
            let after_rotate = (upsert-cluster-in-config $config $rotated_a)
            let clusters = ($after_rotate | get -i kubernetes.clusterLocatorMethods | default [] | where {|m| ($m | get -i type | default "") == "config"} | get 0?.clusters? | default [])
            assert (($clusters | length) == 2)
            let cluster_b = ($clusters | where {|c| $c.name == "cluster-b"} | get 0)
            assert ($cluster_b.serviceAccountToken == "tok2") "cluster-b token should be untouched"
        }],

        # ── upsert-cluster-in-config: preserves other config sections ─────────
        ["upsert-cluster-in-config: preserves non-kubernetes top-level keys", {
            let entry = {url: "https://127.0.0.1:6443", name: "c", authProvider: "serviceAccount", serviceAccountToken: "t", skipTLSVerify: false}
            let config = {auth: {providers: {guest: {}}}, integrations: {github: [{host: "github.com"}]}}
            let result = (upsert-cluster-in-config $config $entry)
            assert (($result | get -i auth) != null)
            assert (($result | get -i integrations) != null)
        }],
        ["upsert-cluster-in-config: preserves other kubernetes keys", {
            let entry = {url: "https://127.0.0.1:6443", name: "c", authProvider: "serviceAccount", serviceAccountToken: "t", skipTLSVerify: false}
            let config = {kubernetes: {serviceLocatorMethod: {type: "multiTenant"}, clusterLocatorMethods: []}}
            let result = (upsert-cluster-in-config $config $entry)
            let svc = ($result | get -i kubernetes.serviceLocatorMethod.type | default "")
            assert ($svc == "multiTenant") "serviceLocatorMethod should be preserved"
        }],

        # ── upsert-cluster-in-config: non-config locators are preserved ────────
        ["upsert-cluster-in-config: preserves non-config type locators", {
            let entry = {url: "https://127.0.0.1:6443", name: "c", authProvider: "serviceAccount", serviceAccountToken: "t", skipTLSVerify: false}
            let config = {kubernetes: {clusterLocatorMethods: [{type: "catalog"}]}}
            let result = (upsert-cluster-in-config $config $entry)
            let methods = ($result | get -i kubernetes.clusterLocatorMethods | default [])
            assert (($methods | length) == 2) "Both catalog and config locators should exist"
            assert (($methods | where {|m| ($m | get -i type | default "") == "catalog"} | is-not-empty))
        }],

        # ── list-clusters ──────────────────────────────────────────────────────
        ["list-clusters: handles missing app-config.local.yaml gracefully", {
            let base = (make-temp-dir)
            # No app-config.local.yaml created — should not error
            list-clusters $base
        }],
        ["list-clusters: handles empty kubernetes block gracefully", {
            let base = (make-temp-dir)
            "kubernetes:\n  clusterLocatorMethods: []\n" | save --force ($base + "/app-config.local.yaml")
            list-clusters $base
        }],
        ["list-clusters: shows configured clusters without error", {
            let base = (make-temp-dir)
            let config = {kubernetes: {clusterLocatorMethods: [{type: "config", clusters: [{url: "https://127.0.0.1:6443", name: "kind-test", authProvider: "serviceAccount", serviceAccountToken: "tok", skipTLSVerify: true}]}]}}
            $config | to yaml | save --force ($base + "/app-config.local.yaml")
            list-clusters $base
        }],
    ]

    run-tests "cluster" $tests
}

main
