use std assert
use ./helpers.nu *
use ../modules/plugins.nu *

# ── Helpers ────────────────────────────────────────────────────────────────

def make-backstage-with-plugins [base: string, app_pkgs: list, backend_pkgs: list] {
    make-fake-backstage $base

    let app_deps = ($app_pkgs | reduce --fold {} {|pkg, acc| $acc | insert $pkg "1.0.0"})
    let app_pkg_json = ({name: "@internal/app", version: "0.0.1", dependencies: $app_deps} | to json)
    $app_pkg_json | save --force ($base + "/packages/app/package.json")

    let backend_deps = ($backend_pkgs | reduce --fold {} {|pkg, acc| $acc | insert $pkg "1.0.0"})
    let backend_pkg_json = ({name: "@internal/backend", version: "0.0.1", dependencies: $backend_deps} | to json)
    $backend_pkg_json | save --force ($base + "/packages/backend/package.json")
}

def main [] {
    let tests = [
        ["list-installed-plugins: empty when no plugins installed", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            let result = (list-installed-plugins $base)
            assert ($result | is-empty) "Expected no installed plugins"
        }],
        ["list-installed-plugins: detects kubernetes frontend+backend", {
            let base = (make-temp-dir)
            make-backstage-with-plugins $base ["@backstage/plugin-kubernetes"] ["@backstage/plugin-kubernetes-backend"]
            let result = (list-installed-plugins $base)
            assert ($result | any {|p| $p.id == "kubernetes"}) "Expected kubernetes to be detected"
        }],
        ["list-installed-plugins: detects techdocs frontend+backend", {
            let base = (make-temp-dir)
            make-backstage-with-plugins $base ["@backstage/plugin-techdocs"] ["@backstage/plugin-techdocs-backend"]
            let result = (list-installed-plugins $base)
            assert ($result | any {|p| $p.id == "techdocs"}) "Expected techdocs to be detected"
        }],
        ["list-installed-plugins: detects grafana frontend-only", {
            let base = (make-temp-dir)
            make-backstage-with-plugins $base ["@backstage-community/plugin-grafana"] []
            let result = (list-installed-plugins $base)
            assert ($result | any {|p| $p.id == "grafana"}) "Expected grafana to be detected"
        }],
        ["list-installed-plugins: detects kubernetes-ingestor backend-only", {
            let base = (make-temp-dir)
            make-backstage-with-plugins $base [] ["@terasky/backstage-plugin-kubernetes-ingestor"]
            let result = (list-installed-plugins $base)
            assert ($result | any {|p| $p.id == "kubernetes-ingestor"}) "Expected kubernetes-ingestor to be detected"
        }],
        ["list-installed-plugins: detects multiple plugins", {
            let base = (make-temp-dir)
            make-backstage-with-plugins $base ["@backstage/plugin-kubernetes", "@backstage-community/plugin-grafana"] ["@backstage/plugin-kubernetes-backend"]
            let result = (list-installed-plugins $base)
            assert (($result | length) >= 2) "Expected at least 2 plugins"
        }],
        ["list-installed-plugins: does not detect uninstalled plugins", {
            let base = (make-temp-dir)
            make-backstage-with-plugins $base ["@backstage/plugin-kubernetes"] ["@backstage/plugin-kubernetes-backend"]
            let result = (list-installed-plugins $base)
            assert not ($result | any {|p| $p.id == "techdocs"}) "techdocs should not be detected"
            assert not ($result | any {|p| $p.id == "grafana"}) "grafana should not be detected"
        }],
        ["list-installed-plugins: result has id, name, frontend, backend fields", {
            let base = (make-temp-dir)
            make-backstage-with-plugins $base ["@backstage/plugin-kubernetes"] ["@backstage/plugin-kubernetes-backend"]
            let result = (list-installed-plugins $base)
            let entry = ($result | where {|p| $p.id == "kubernetes"} | first)
            assert ($entry.id | is-not-empty)
            assert ($entry.name | is-not-empty)
            assert ($entry.frontend == true)
            assert ($entry.backend == true)
        }],
        ["list-installed-plugins: frontend-only plugin has backend=false", {
            let base = (make-temp-dir)
            make-backstage-with-plugins $base ["@backstage-community/plugin-grafana"] []
            let result = (list-installed-plugins $base)
            let entry = ($result | where {|p| $p.id == "grafana"} | first)
            assert ($entry.frontend == true)
            assert ($entry.backend == false)
        }],
        ["list-installed-plugins: backend-only plugin has frontend=false", {
            let base = (make-temp-dir)
            make-backstage-with-plugins $base [] ["@terasky/backstage-plugin-kubernetes-ingestor"]
            let result = (list-installed-plugins $base)
            let entry = ($result | where {|p| $p.id == "kubernetes-ingestor"} | first)
            assert ($entry.frontend == false)
            assert ($entry.backend == true)
        }],
        ["print-installed-plugins: succeeds when plugins installed", {
            let base = (make-temp-dir)
            make-backstage-with-plugins $base ["@backstage/plugin-kubernetes"] ["@backstage/plugin-kubernetes-backend"]
            print-installed-plugins $base
        }],
        ["print-installed-plugins: succeeds when no plugins installed", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            print-installed-plugins $base
        }],
    ]

    run-tests "plugin-installed" $tests
}

main
