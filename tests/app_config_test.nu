#!/usr/bin/env nu
# Tests for modules/app-config.nu

use ./helpers.nu *
use std assert
use ../modules/app-config.nu

# ── Tests ──────────────────────────────────────────────────────────────────

def test_init_app_config_creates_file [] {
    let dir = (make-temp-dir)
    app-config init-app-config $dir --name "test-app"
    assert-file-exists ($dir + "/app-config.yaml")
    rm -rf $dir
}

def test_init_app_config_contains_app_name [] {
    let dir = (make-temp-dir)
    app-config init-app-config $dir --name "my-platform"
    assert-file-contains ($dir + "/app-config.yaml") "my-platform"
    rm -rf $dir
}

def test_init_app_config_contains_required_sections [] {
    let dir = (make-temp-dir)
    app-config init-app-config $dir --name "test-app"
    assert-file-contains ($dir + "/app-config.yaml") "backend:"
    assert-file-contains ($dir + "/app-config.yaml") "auth:"
    assert-file-contains ($dir + "/app-config.yaml") "catalog:"
    rm -rf $dir
}

def test_validate_app_config_valid [] {
    let dir = (make-temp-dir)
    app-config init-app-config $dir --name "test-app"
    let result = (app-config validate-app-config ($dir + "/app-config.yaml"))
    assert ($result == true)
    rm -rf $dir
}

def test_validate_app_config_missing_file [] {
    let result = (app-config validate-app-config "/tmp/nonexistent-config.yaml")
    assert ($result == false)
}

def test_configure_database_postgresql_default_port [] {
    let dir = (make-temp-dir)
    # configure-database just prints info and returns — verify it runs without error
    app-config configure-database $dir --db-type "postgresql"
    rm -rf $dir
}

def test_configure_database_mysql_default_port [] {
    let dir = (make-temp-dir)
    app-config configure-database $dir --db-type "mysql"
    rm -rf $dir
}

def test_configure_database_mariadb_default_port [] {
    let dir = (make-temp-dir)
    app-config configure-database $dir --db-type "mariadb"
    rm -rf $dir
}

def test_configure_database_custom_port [] {
    let dir = (make-temp-dir)
    app-config configure-database $dir --db-type "postgresql" --port 5433 --host "db.example.com"
    rm -rf $dir
}

def test_configure_storage_aws_requires_bucket_and_region [] {
    let dir = (make-temp-dir)
    # Missing bucket and region should exit 1 — run in subprocess
    let result = (nu --no-config-file -c $"use ../modules/app-config.nu; app-config configure-storage ($dir) --provider aws" | complete)
    assert ($result.exit_code == 1)
    rm -rf $dir
}

def test_configure_storage_aws_valid [] {
    let dir = (make-temp-dir)
    app-config configure-storage $dir --provider "aws" --bucket "my-bucket" --region "us-east-1"
    rm -rf $dir
}

def test_configure_storage_azure_requires_container [] {
    let dir = (make-temp-dir)
    let result = (nu --no-config-file -c $"use ../modules/app-config.nu; app-config configure-storage ($dir) --provider azure" | complete)
    assert ($result.exit_code == 1)
    rm -rf $dir
}

def test_configure_storage_azure_valid [] {
    let dir = (make-temp-dir)
    app-config configure-storage $dir --provider "azure" --bucket "my-container"
    rm -rf $dir
}

# ── Runner ─────────────────────────────────────────────────────────────────

def main [] {
    run-tests "app-config.nu" [
        ["init-app-config: creates file",               { test_init_app_config_creates_file }]
        ["init-app-config: contains app name",          { test_init_app_config_contains_app_name }]
        ["init-app-config: required sections present",  { test_init_app_config_contains_required_sections }]
        ["validate-app-config: valid file",             { test_validate_app_config_valid }]
        ["validate-app-config: missing file → false",   { test_validate_app_config_missing_file }]
        ["configure-database: postgresql default port", { test_configure_database_postgresql_default_port }]
        ["configure-database: mysql default port",      { test_configure_database_mysql_default_port }]
        ["configure-database: mariadb default port",    { test_configure_database_mariadb_default_port }]
        ["configure-database: custom port",             { test_configure_database_custom_port }]
        ["configure-storage: aws missing args → exit1", { test_configure_storage_aws_requires_bucket_and_region }]
        ["configure-storage: aws valid",                { test_configure_storage_aws_valid }]
        ["configure-storage: azure missing container",  { test_configure_storage_azure_requires_container }]
        ["configure-storage: azure valid",              { test_configure_storage_azure_valid }]
    ]
}

main
