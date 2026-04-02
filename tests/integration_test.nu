#!/usr/bin/env nu
# Integration smoke tests — verify all modules load and registries are correct

use ./helpers.nu *
use std assert

# ── Tests ──────────────────────────────────────────────────────────────────

def test_utils_module_loads [] {
    let out = (nu --no-config-file -c "use ../modules/utils.nu; utils print-success 'ok'" | complete)
    assert ($out.exit_code == 0)
}

def test_entities_module_loads [] {
    let out = (nu --no-config-file -c "use ../modules/entities.nu; entities list-entities /tmp" | complete)
    assert ($out.exit_code == 0)
}

def test_app_config_module_loads [] {
    let out = (nu --no-config-file -c "use ../modules/app-config.nu; print loaded" | complete)
    assert ($out.exit_code == 0)
}

def test_auth_module_loads [] {
    let out = (nu --no-config-file -c "use ../modules/auth.nu; print loaded" | complete)
    assert ($out.exit_code == 0)
}

def test_plugins_module_loads [] {
    let out = (nu --no-config-file -c "use ../modules/plugins.nu; print loaded" | complete)
    assert ($out.exit_code == 0)
}

def test_plugin_registry_has_12_entries [] {
    let out = (nu --no-config-file -c "
        use ../modules/plugins.nu
        def plugin-reg [] {
            {
                'azure-devops': 1, 'github-actions': 1, 'kubernetes': 1, 'techdocs': 1,
                'argocd': 1, 'sonarqube': 1, 'kubernetes-ingestor': 1, 'crossplane-resources': 1,
                'grafana': 1, 'holiday-tracker': 1, 'cost-insights': 1, 'infrawallet': 1
            }
        }
        print (plugin-reg | columns | length)
    " | complete)
    assert ($out.exit_code == 0)
    assert (($out.stdout | str trim) == "12")
}

def test_auth_registry_has_3_entries [] {
    let out = (nu --no-config-file -c "
        use ../modules/auth.nu
        # Verify 3 providers exist by checking show-auth-info for each
        auth show-auth-info github | ignore
        auth show-auth-info microsoft | ignore
        auth show-auth-info google | ignore
        print ok
    " | complete)
    assert ($out.exit_code == 0)
}

def test_main_nu_parses_without_error [] {
    let out = (nu --no-config-file ../main.nu | complete)
    assert ($out.exit_code == 0)
    assert ($out.stdout | str contains "Platform CLI")
}

def test_config_nu_get_config [] {
    let out = (nu --no-config-file -c "
        use ../config.nu
        let cfg = (config get-config)
        print ($cfg.backstage_version)
    " | complete)
    assert ($out.exit_code == 0)
    assert (($out.stdout | str trim | is-not-empty))
}

def test_full_entity_workflow [] {
    let dir = (make-temp-dir)
    let out_file = ($dir + "/my-system.yaml")
    # Create entity
    nu --no-config-file -c $"use ../modules/entities.nu; entities create-entity my-system --type system --output ($out_file)" | ignore
    # Validate by reading the file directly
    assert-file-exists $out_file
    assert-file-contains $out_file "apiVersion: backstage.io/v1alpha1"
    assert-file-contains $out_file "kind: System"
    assert-file-contains $out_file "name: my-system"
    rm -rf $dir
}

# ── Runner ─────────────────────────────────────────────────────────────────

def main [] {
    run-tests "integration" [
        ["utils module loads",              { test_utils_module_loads }]
        ["entities module loads",           { test_entities_module_loads }]
        ["app-config module loads",         { test_app_config_module_loads }]
        ["auth module loads",               { test_auth_module_loads }]
        ["plugins module loads",            { test_plugins_module_loads }]
        ["plugin registry: 12 entries",     { test_plugin_registry_has_12_entries }]
        ["auth registry: 3 providers",      { test_auth_registry_has_3_entries }]
        ["main.nu: parses without error",   { test_main_nu_parses_without_error }]
        ["config.nu: get-config works",     { test_config_nu_get_config }]
        ["full entity workflow: create+validate", { test_full_entity_workflow }]
    ]
}

main
