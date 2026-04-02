#!/usr/bin/env nu
# Tests for modules/utils.nu

use ./helpers.nu *
use std assert
use ../modules/utils.nu

# ── Tests ──────────────────────────────────────────────────────────────────

def test_check_command_exists [] {
    assert (utils check-command "nu")
}

def test_check_command_missing [] {
    assert not (utils check-command "this-cmd-does-not-exist-xyz-123")
}

def test_create_directory_new [] {
    let dir = (make-temp-dir)
    let new_dir = ($dir + "/sub/nested")
    utils create-directory $new_dir
    assert ($new_dir | path exists)
    rm -rf $dir
}

def test_create_directory_already_exists [] {
    let dir = (make-temp-dir)
    utils create-directory $dir
    assert ($dir | path exists)
    rm -rf $dir
}

def test_validate_path_passes_when_absent [] {
    utils validate-path "/tmp/platform-cli-surely-absent-xyzabc987" "test"
}

def test_validate_path_errors_when_exists [] {
    let dir = (make-temp-dir)
    # validate-path calls `exit 1` — must run in subprocess to capture exit code
    let result = (nu --no-config-file -c $"use ../modules/utils.nu; utils validate-path ($dir) test" | complete)
    assert ($result.exit_code == 1)
    rm -rf $dir
}

def test_validate_yaml_valid_file [] {
    let dir = (make-temp-dir)
    let f = ($dir + "/valid.yaml")
    "key: value\nlist:\n  - a\n  - b\n" | save --force $f
    utils validate-yaml $f
    rm -rf $dir
}

def test_validate_yaml_missing_file [] {
    let result = (utils validate-yaml "/tmp/does-not-exist-xyz.yaml")
    assert ($result == false)
}

def test_validate_json_valid [] {
    utils validate-json '{"key": "value", "num": 42}'
}

def test_validate_json_invalid [] {
    # Use clearly malformed JSON (unclosed bracket)
    let result = (utils validate-json "[unclosed")
    assert ($result == false)
}

def test_backup_file_creates_bak [] {
    let dir = (make-temp-dir)
    let f = ($dir + "/myfile.txt")
    "original content" | save --force $f
    utils backup-file $f
    let backups = (ls $dir | where name =~ "myfile.txt.backup." | get name)
    assert (($backups | length) > 0)
    rm -rf $dir
}

def test_get_timestamp_format [] {
    let ts = (utils get-timestamp)
    assert not ($ts | is-empty)
    assert (($ts | str length) == 15)
    assert ($ts | str contains "_")
}

def test_print_functions_do_not_crash [] {
    utils print-success "ok"
    utils print-error "err"
    utils print-warning "warn"
    utils print-info "info"
    utils print-header "Title"
}

# ── Runner ─────────────────────────────────────────────────────────────────

def main [] {
    run-tests "utils.nu" [
        ["check-command: exists",                  { test_check_command_exists }]
        ["check-command: missing",                 { test_check_command_missing }]
        ["create-directory: new dir",              { test_create_directory_new }]
        ["create-directory: already exists",       { test_create_directory_already_exists }]
        ["validate-path: passes when absent",      { test_validate_path_passes_when_absent }]
        ["validate-path: errors when exists",      { test_validate_path_errors_when_exists }]
        ["validate-yaml: valid file",              { test_validate_yaml_valid_file }]
        ["validate-yaml: missing file errors",     { test_validate_yaml_missing_file }]
        ["validate-json: valid JSON",              { test_validate_json_valid }]
        ["validate-json: invalid JSON errors",     { test_validate_json_invalid }]
        ["backup-file: creates .bak file",         { test_backup_file_creates_bak }]
        ["get-timestamp: correct format",          { test_get_timestamp_format }]
        ["print-*: no crash",                      { test_print_functions_do_not_crash }]
    ]
}

main
