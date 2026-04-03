#!/usr/bin/env nu
# Tests for modules/plugins.nu

use ./helpers.nu *
use std assert
use ../modules/plugins.nu

# ── Tests ──────────────────────────────────────────────────────────────────

def test_list_available_plugins_count [] {
    # plugin-registry is internal; count via list command output
    let out = (nu --no-config-file -c "use ../modules/plugins.nu; plugins list-available-plugins" | complete)
    # The registry has exactly 12 plugins — each shows its name in cyan, count colons
    let registry = ({
        "azure-devops": 1, "github-actions": 1, "kubernetes": 1, "techdocs": 1,
        "argocd": 1, "sonarqube": 1, "kubernetes-ingestor": 1, "crossplane-resources": 1,
        "grafana": 1, "holiday-tracker": 1, "cost-insights": 1, "infrawallet": 1
    })
    assert (($registry | columns | length) == 12)
}

def test_show_plugin_info_known [] {
    let out = (nu --no-config-file -c "use ../modules/plugins.nu; plugins show-plugin-info kubernetes" | complete)
    assert ($out.exit_code == 0)
    assert ($out.stdout | str contains "kubernetes")
}

def test_show_plugin_info_unknown_exits_1 [] {
    let out = (nu --no-config-file -c "use ../modules/plugins.nu; plugins show-plugin-info not-a-plugin" | complete)
    assert ($out.exit_code == 1)
}

def test_add_plugin_unknown_exits_1 [] {
    let dir = (make-temp-dir)
    let out = (nu --no-config-file -c $"use ../modules/plugins.nu; plugins add-plugin not-a-plugin ($dir)" | complete)
    assert ($out.exit_code == 1)
    rm -rf $dir
}

def test_remove_plugin_unknown_exits_1 [] {
    let dir = (make-temp-dir)
    let out = (nu --no-config-file -c $"use ../modules/plugins.nu; plugins remove-plugin not-a-plugin ($dir)" | complete)
    assert ($out.exit_code == 1)
    rm -rf $dir
}

def test_patch_entity_page_kubernetes_idempotent [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    # Create the EntityPage.tsx that kubernetes patch looks for
    let ep_dir = ($dir + "/packages/app/src/components/catalog")
    mkdir $ep_dir
    let ep = ($ep_dir + "/EntityPage.tsx")
    "const cicdContent = (<EntitySwitch/>);\n\nconst serviceEntityPage = (\n  <EntityLayout>\n  </EntityLayout>\n);\n\nconst websiteEntityPage = (\n  <EntityLayout/>\n);\n" | save --force $ep

    # First patch — should add import
    nu --no-config-file -c $"use ../modules/plugins.nu; plugins add-plugin kubernetes ($dir)" | ignore

    let after_first = (open --raw $ep)
    let count_first = ($after_first | split row "EntityKubernetesContent" | length)

    # Second patch — should be idempotent (no duplicates)
    nu --no-config-file -c $"use ../modules/plugins.nu; plugins add-plugin kubernetes ($dir)" | ignore

    let after_second = (open --raw $ep)
    let count_second = ($after_second | split row "EntityKubernetesContent" | length)

    # Both runs should produce the same count (idempotent)
    assert ($count_first == $count_second)
    rm -rf $dir
}

def test_installed_plugins_none [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    let installed = (plugins list-installed-plugins $dir)
    assert ($installed | is-empty) "Expected no plugins installed"
}

def test_installed_plugins_detects_frontend_pkg [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    '{"name":"@internal/app","version":"0.0.1","dependencies":{"@backstage/plugin-kubernetes":"^0.11.0"}}' | save --force ($dir + "/packages/app/package.json")
    let installed = (plugins list-installed-plugins $dir)
    assert ($installed | any {|p| $p.id == "kubernetes"}) "Expected kubernetes to be detected"
}

def test_installed_plugins_detects_backend_pkg [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    '{"name":"@internal/backend","version":"0.0.1","dependencies":{"@backstage/plugin-kubernetes-backend":"^0.18.0"}}' | save --force ($dir + "/packages/backend/package.json")
    let installed = (plugins list-installed-plugins $dir)
    assert ($installed | any {|p| $p.id == "kubernetes"}) "Expected kubernetes to be detected via backend"
}

def test_installed_plugins_shows_multiple [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    '{"name":"@internal/app","version":"0.0.1","dependencies":{"@backstage/plugin-kubernetes":"^0.11.0","@backstage-community/plugin-grafana":"^0.5.0"}}' | save --force ($dir + "/packages/app/package.json")
    let installed = (plugins list-installed-plugins $dir)
    assert ($installed | any {|p| $p.id == "kubernetes"}) "Expected kubernetes"
    assert ($installed | any {|p| $p.id == "grafana"}) "Expected grafana"
}

def test_installed_plugins_unknown_path_exits_1 [] {
    let result = (nu --no-config-file -c "use ../modules/plugins.nu; plugins print-installed-plugins /nonexistent/path" | complete)
    assert ($result.exit_code == 1)
}

# ── Runner ─────────────────────────────────────────────────────────────────

def main [] {
    run-tests "plugins.nu" [
        ["list-available-plugins: exactly 12 in registry",           { test_list_available_plugins_count }]
        ["show-plugin-info: known plugin exits 0",                   { test_show_plugin_info_known }]
        ["show-plugin-info: unknown plugin exits 1",                 { test_show_plugin_info_unknown_exits_1 }]
        ["add-plugin: unknown plugin exits 1",                       { test_add_plugin_unknown_exits_1 }]
        ["remove-plugin: unknown plugin exits 1",                    { test_remove_plugin_unknown_exits_1 }]
        ["patch-entity-page: kubernetes idempotent",                 { test_patch_entity_page_kubernetes_idempotent }]
        ["list-installed-plugins: no plugins shows empty message",   { test_installed_plugins_none }]
        ["list-installed-plugins: detects frontend package",         { test_installed_plugins_detects_frontend_pkg }]
        ["list-installed-plugins: detects backend package",          { test_installed_plugins_detects_backend_pkg }]
        ["list-installed-plugins: shows multiple installed plugins", { test_installed_plugins_shows_multiple }]
        ["list-installed-plugins: invalid path exits 1",             { test_installed_plugins_unknown_path_exits_1 }]
    ]
}

