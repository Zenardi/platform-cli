#!/usr/bin/env nu
# Tests for modules/auth.nu

use ./helpers.nu *
use std assert
use ../modules/auth.nu

# ── Tests ──────────────────────────────────────────────────────────────────

def test_list_auth_providers_runs [] {
    # list-auth-providers prints and returns nothing — just verify no crash
    let out = (nu --no-config-file -c "use ../modules/auth.nu; auth list-auth-providers" | complete)
    assert ($out.exit_code == 0)
}

def test_list_auth_providers_shows_all_three [] {
    let out = (nu --no-config-file -c "use ../modules/auth.nu; auth list-auth-providers" | complete)
    assert ($out.stdout | str contains "github")
    assert ($out.stdout | str contains "microsoft")
    assert ($out.stdout | str contains "google")
}

def test_show_auth_info_known [] {
    let out = (nu --no-config-file -c "use ../modules/auth.nu; auth show-auth-info github" | complete)
    assert ($out.exit_code == 0)
    assert ($out.stdout | str contains "github")
}

def test_show_auth_info_unknown_exits_1 [] {
    let out = (nu --no-config-file -c "use ../modules/auth.nu; auth show-auth-info not-a-provider" | complete)
    assert ($out.exit_code == 1)
}

def test_patch_backend_index_injects_provider [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    let index_path = ($dir + "/packages/backend/src/index.ts")
    let mock_bin = (make-mock-bin)

    with-env {PATH: [$mock_bin ...$env.PATH]} {
        nu --no-config-file -c $"use ../modules/auth.nu; \$env.GITHUB_CLIENT_ID = 'x'; \$env.GITHUB_CLIENT_SECRET = 'x'; auth add-auth-provider github ($dir)" | ignore
    }

    let content = (open --raw $index_path)
    assert ($content | str contains "plugin-auth-backend-module-github-provider")
    rm -rf $dir
    rm -rf $mock_bin
}

def test_patch_backend_index_idempotent [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    let index_path = ($dir + "/packages/backend/src/index.ts")
    let mock_bin = (make-mock-bin)

    with-env {PATH: [$mock_bin ...$env.PATH]} {
        # First patch
        nu --no-config-file -c $"use ../modules/auth.nu; \$env.GITHUB_CLIENT_ID = 'x'; \$env.GITHUB_CLIENT_SECRET = 'x'; auth add-auth-provider github ($dir)" | ignore
        let after_first = (open --raw $index_path)

        # Second patch — should be idempotent
        nu --no-config-file -c $"use ../modules/auth.nu; \$env.GITHUB_CLIENT_ID = 'x'; \$env.GITHUB_CLIENT_SECRET = 'x'; auth add-auth-provider github ($dir)" | ignore
        let after_second = (open --raw $index_path)

        let count_first  = ($after_first  | split row "plugin-auth-backend-module-github-provider" | length)
        let count_second = ($after_second | split row "plugin-auth-backend-module-github-provider" | length)
        assert ($count_first == $count_second)
    }
    rm -rf $dir
    rm -rf $mock_bin
}

def test_patch_frontend_app_new_system_injects_module [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    let app_path = ($dir + "/packages/app/src/App.tsx")
    let mock_bin = (make-mock-bin)

    with-env {PATH: [$mock_bin ...$env.PATH]} {
        nu --no-config-file -c $"use ../modules/auth.nu; \$env.GITHUB_CLIENT_ID = 'x'; \$env.GITHUB_CLIENT_SECRET = 'x'; auth add-auth-provider github ($dir)" | ignore
    }

    let content = (open --raw $app_path)
    assert ($content | str contains "SignInPageBlueprint")
    rm -rf $dir
    rm -rf $mock_bin
}

def test_add_auth_provider_writes_local_config [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    let local_cfg = ($dir + "/app-config.local.yaml")
    if ($local_cfg | path exists) { rm $local_cfg }
    let mock_bin = (make-mock-bin)

    with-env {PATH: [$mock_bin ...$env.PATH]} {
        nu --no-config-file -c $"use ../modules/auth.nu; \$env.GITHUB_CLIENT_ID = 'x'; \$env.GITHUB_CLIENT_SECRET = 'x'; auth add-auth-provider github ($dir)" | ignore
    }

    assert-file-exists $local_cfg
    assert-file-contains $local_cfg "github"
    rm -rf $dir
    rm -rf $mock_bin
}

def test_add_auth_provider_microsoft_writes_azure_config [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    let local_cfg = ($dir + "/app-config.local.yaml")
    if ($local_cfg | path exists) { rm $local_cfg }
    let mock_bin = (make-mock-bin)

    with-env {PATH: [$mock_bin ...$env.PATH]} {
        nu --no-config-file -c $"use ../modules/auth.nu; \$env.AZURE_CLIENT_ID = 'x'; \$env.AZURE_CLIENT_SECRET = 'x'; \$env.AZURE_TENANT_ID = 'x'; auth add-auth-provider microsoft ($dir)" | ignore
    }

    assert-file-exists $local_cfg
    assert-file-contains $local_cfg "microsoft"
    rm -rf $dir
    rm -rf $mock_bin
}

def test_add_auth_provider_unknown_exits_1 [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    let out = (nu --no-config-file -c $"use ../modules/auth.nu; auth add-auth-provider not-a-provider ($dir)" | complete)
    assert ($out.exit_code == 1)
    rm -rf $dir
}

def test_add_auth_provider_no_guest_flag [] {
    let dir = (make-temp-dir)
    make-fake-backstage $dir
    let mock_bin = (make-mock-bin)

    with-env {PATH: [$mock_bin ...$env.PATH]} {
        nu --no-config-file -c $"use ../modules/auth.nu; \$env.GITHUB_CLIENT_ID = 'x'; \$env.GITHUB_CLIENT_SECRET = 'x'; auth add-auth-provider github ($dir) --no-guest" | ignore
    }

    let local_cfg = ($dir + "/app-config.local.yaml")
    assert-file-contains $local_cfg "dangerouslyDisableDefaultAuthPolicy: true"
    rm -rf $dir
    rm -rf $mock_bin
}

# ── Runner ─────────────────────────────────────────────────────────────────

def main [] {
    run-tests "auth.nu" [
        ["list-auth-providers: runs without error",          { test_list_auth_providers_runs }]
        ["list-auth-providers: shows github/gitlab/ms",      { test_list_auth_providers_shows_all_three }]
        ["show-auth-info: known provider exits 0",           { test_show_auth_info_known }]
        ["show-auth-info: unknown provider exits 1",         { test_show_auth_info_unknown_exits_1 }]
        ["patch-backend-index: injects provider import",     { test_patch_backend_index_injects_provider }]
        ["patch-backend-index: idempotent",                  { test_patch_backend_index_idempotent }]
        ["patch-frontend-app: new system injects module",    { test_patch_frontend_app_new_system_injects_module }]
        ["add-auth-provider: writes app-config.local.yaml",  { test_add_auth_provider_writes_local_config }]
        ["add-auth-provider: microsoft writes azure config", { test_add_auth_provider_microsoft_writes_azure_config }]
        ["add-auth-provider: unknown provider exits 1",      { test_add_auth_provider_unknown_exits_1 }]
        ["add-auth-provider: --no-guest sets disable policy",{ test_add_auth_provider_no_guest_flag }]
    ]
}

main
