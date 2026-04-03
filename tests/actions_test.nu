#!/usr/bin/env nu
# Tests for modules/actions.nu

use ./helpers.nu *
use std assert
use ../modules/actions.nu

# ── Registry tests ────────────────────────────────────────────────────────

def test_list_available_actions_has_azure_pipeline [] {
    let out = (nu --no-config-file -c "use ../modules/actions.nu; actions list-available-actions" | complete)
    assert ($out.exit_code == 0)
    assert ($out.stdout | str contains "azure-pipeline")
}


def test_show_action_info_known [] {
    let out = (nu --no-config-file -c "use ../modules/actions.nu; actions show-action-info azure-pipeline" | complete)
    assert ($out.exit_code == 0)
    assert ($out.stdout | str contains "azure:pipeline:create-and-run")
}


def test_show_action_info_unknown_exits_1 [] {
    let out = (nu --no-config-file -c "use ../modules/actions.nu; actions show-action-info not-an-action" | complete)
    assert ($out.exit_code == 1)
}


def test_install_action_unknown_exits_1 [] {
    let dir = (make-temp-dir)
    let out = (nu --no-config-file -c $"use ../modules/actions.nu; actions install-action not-an-action ($dir)" | complete)
    assert ($out.exit_code == 1)
    rm -rf $dir
}

# ── File creation tests ────────────────────────────────────────────────────


def test_install_azure_pipeline_creates_ts_file [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    nu --no-config-file -c $"use ../modules/actions.nu; actions install-action azure-pipeline ($dir)" | ignore
    let ts_path = ($dir + "/packages/backend/src/extensions/azurePipelineAction.ts")
    assert-file-exists $ts_path
    rm -rf $dir
}


def test_install_azure_pipeline_creates_extensions_dir [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    let ext_dir = ($dir + "/packages/backend/src/extensions")
    assert not ($ext_dir | path exists) "extensions/ should not exist before install"
    nu --no-config-file -c $"use ../modules/actions.nu; actions install-action azure-pipeline ($dir)" | ignore
    assert ($ext_dir | path exists) "extensions/ should exist after install"
    rm -rf $dir
}


def test_install_azure_pipeline_file_contains_action_id [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    nu --no-config-file -c $"use ../modules/actions.nu; actions install-action azure-pipeline ($dir)" | ignore
    let ts_path = ($dir + "/packages/backend/src/extensions/azurePipelineAction.ts")
    assert-file-contains $ts_path "azure:pipeline:create-and-run"
    rm -rf $dir
}


def test_install_azure_pipeline_file_contains_variables_input [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    nu --no-config-file -c $"use ../modules/actions.nu; actions install-action azure-pipeline ($dir)" | ignore
    let ts_path = ($dir + "/packages/backend/src/extensions/azurePipelineAction.ts")
    assert-file-contains $ts_path "variables"
    assert-file-contains $ts_path "isSecret"
    rm -rf $dir
}

# ── index.ts patching tests ────────────────────────────────────────────────


def test_install_azure_pipeline_patches_index_ts [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    nu --no-config-file -c $"use ../modules/actions.nu; actions install-action azure-pipeline ($dir)" | ignore
    let index_path = ($dir + "/packages/backend/src/index.ts")
    assert-file-contains $index_path "azurePipelineAction"
    rm -rf $dir
}


def test_install_azure_pipeline_idempotent [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir

    nu --no-config-file -c $"use ../modules/actions.nu; actions install-action azure-pipeline ($dir)" | ignore
    nu --no-config-file -c $"use ../modules/actions.nu; actions install-action azure-pipeline ($dir)" | ignore

    let index_content = (open --raw ($dir + "/packages/backend/src/index.ts"))
    let count = ($index_content | split row "azurePipelineAction" | length)
    assert ($count == 2) "azurePipelineAction should appear exactly once in index.ts"

    let ts_path = ($dir + "/packages/backend/src/extensions/azurePipelineAction.ts")
    assert-file-exists $ts_path
    rm -rf $dir
}


def test_install_azure_pipeline_missing_instance_exits_1 [] {
    let out = (nu --no-config-file -c "use ../modules/actions.nu; actions install-action azure-pipeline /nonexistent/path" | complete)
    assert ($out.exit_code == 1)
}

# ── Runner ─────────────────────────────────────────────────────────────────

def main [] {
    run-tests "actions.nu" [
        ["list-available-actions: has azure-pipeline",               { test_list_available_actions_has_azure_pipeline }]
        ["show-action-info: known action exits 0",                   { test_show_action_info_known }]
        ["show-action-info: unknown action exits 1",                 { test_show_action_info_unknown_exits_1 }]
        ["install-action: unknown action exits 1",                   { test_install_action_unknown_exits_1 }]
        ["install-action: creates azurePipelineAction.ts",           { test_install_azure_pipeline_creates_ts_file }]
        ["install-action: creates extensions/ directory",            { test_install_azure_pipeline_creates_extensions_dir }]
        ["install-action: file contains action id",                  { test_install_azure_pipeline_file_contains_action_id }]
        ["install-action: file contains variables+isSecret inputs",  { test_install_azure_pipeline_file_contains_variables_input }]
        ["install-action: patches index.ts",                         { test_install_azure_pipeline_patches_index_ts }]
        ["install-action: idempotent (no duplicates in index.ts)",   { test_install_azure_pipeline_idempotent }]
        ["install-action: missing instance path exits 1",            { test_install_azure_pipeline_missing_instance_exits_1 }]
    ]
}
