#!/usr/bin/env nu
# Tests for modules/entities.nu

use ./helpers.nu *
use std assert
use ../modules/entities.nu

# ── Tests ──────────────────────────────────────────────────────────────────

def test_create_entity_component [] {
    let dir = (make-temp-dir)
    entities create-entity "my-service" --type "component" --owner "team-a" --system "my-system" --output ($dir + "/my-service.yaml")
    assert-file-exists ($dir + "/my-service.yaml")
    assert-file-contains ($dir + "/my-service.yaml") "kind: Component"
    assert-file-contains ($dir + "/my-service.yaml") "name: my-service"
    assert-file-contains ($dir + "/my-service.yaml") "owner: team-a"
    assert-file-contains ($dir + "/my-service.yaml") "apiVersion: backstage.io/v1alpha1"
    rm -rf $dir
}

def test_create_entity_api [] {
    let dir = (make-temp-dir)
    entities create-entity "my-api" --type "api" --system "my-system" --output ($dir + "/my-api.yaml")
    assert-file-contains ($dir + "/my-api.yaml") "kind: API"
    assert-file-contains ($dir + "/my-api.yaml") "name: my-api"
    rm -rf $dir
}

def test_create_entity_resource [] {
    let dir = (make-temp-dir)
    entities create-entity "my-db" --type "resource" --system "my-system" --output ($dir + "/my-db.yaml")
    assert-file-contains ($dir + "/my-db.yaml") "kind: Resource"
    assert-file-contains ($dir + "/my-db.yaml") "name: my-db"
    rm -rf $dir
}

def test_create_entity_system [] {
    let dir = (make-temp-dir)
    entities create-entity "my-system" --type "system" --output ($dir + "/my-system.yaml")
    assert-file-contains ($dir + "/my-system.yaml") "kind: System"
    assert-file-contains ($dir + "/my-system.yaml") "name: my-system"
    rm -rf $dir
}

def test_create_entity_group [] {
    let dir = (make-temp-dir)
    entities create-entity "my-team" --type "group" --output ($dir + "/my-team.yaml")
    assert-file-contains ($dir + "/my-team.yaml") "kind: Group"
    assert-file-contains ($dir + "/my-team.yaml") "name: my-team"
    rm -rf $dir
}

def test_create_entity_user [] {
    let dir = (make-temp-dir)
    entities create-entity "john-doe" --type "user" --output ($dir + "/john-doe.yaml")
    assert-file-contains ($dir + "/john-doe.yaml") "kind: User"
    assert-file-contains ($dir + "/john-doe.yaml") "name: john-doe"
    rm -rf $dir
}

def test_create_entity_default_output_path [] {
    let dir = (make-temp-dir)
    let orig = $env.PWD
    cd $dir
    entities create-entity "svc" --type "system"
    let exists = (($dir + "/catalog-entities/svc.yaml") | path exists)
    cd $orig
    rm -rf $dir
    assert $exists
}

def test_create_entity_with_description [] {
    let dir = (make-temp-dir)
    entities create-entity "svc" --type "system" --description "My cool service" --output ($dir + "/svc.yaml")
    assert-file-contains ($dir + "/svc.yaml") "My cool service"
    rm -rf $dir
}

def test_validate_entity_valid [] {
    let dir = (make-temp-dir)
    let f = ($dir + "/valid.yaml")
    "apiVersion: backstage.io/v1alpha1\nkind: Component\nmetadata:\n  name: test\nspec:\n  type: service\n  lifecycle: production\n  owner: team-a\n" | save --force $f
    let result = (entities validate-entity $f)
    assert ($result == true)
    rm -rf $dir
}

def test_validate_entity_missing_apiversion [] {
    let dir = (make-temp-dir)
    let f = ($dir + "/invalid.yaml")
    "kind: Component\nmetadata:\n  name: test\n" | save --force $f
    let result = (entities validate-entity $f)
    assert ($result == false)
    rm -rf $dir
}

def test_validate_entity_missing_kind [] {
    let dir = (make-temp-dir)
    let f = ($dir + "/invalid.yaml")
    "apiVersion: backstage.io/v1alpha1\nmetadata:\n  name: test\n" | save --force $f
    let result = (entities validate-entity $f)
    assert ($result == false)
    rm -rf $dir
}

def test_validate_entity_missing_metadata [] {
    let dir = (make-temp-dir)
    let f = ($dir + "/invalid.yaml")
    "apiVersion: backstage.io/v1alpha1\nkind: Component\n" | save --force $f
    let result = (entities validate-entity $f)
    assert ($result == false)
    rm -rf $dir
}

def test_list_entities [] {
    let dir = (make-temp-dir)
    mkdir ($dir + "/catalog-entities")
    "apiVersion: backstage.io/v1alpha1\nkind: Component\nmetadata:\n  name: a\n" | save --force ($dir + "/catalog-entities/a.yaml")
    "apiVersion: backstage.io/v1alpha1\nkind: System\nmetadata:\n  name: b\n"    | save --force ($dir + "/catalog-entities/b.yaml")
    let files = (entities list-entities $dir)
    assert (($files | length) == 2)
    rm -rf $dir
}

def test_create_bulk_entities_basic [] {
    let dir = (make-temp-dir)
    entities create-bulk-entities $dir --template "basic"
    let files = (ls ($dir + "/catalog-entities") | get name)
    assert (($files | length) > 0)
    rm -rf $dir
}

def test_create_bulk_entities_microservices [] {
    let dir = (make-temp-dir)
    entities create-bulk-entities $dir --template "microservices"
    let files = (ls ($dir + "/catalog-entities") | get name)
    assert (($files | length) > 0)
    rm -rf $dir
}

def test_create_bulk_entities_team_structure [] {
    let dir = (make-temp-dir)
    entities create-bulk-entities $dir --template "team-structure"
    let files = (ls ($dir + "/catalog-entities") | get name)
    assert (($files | length) > 0)
    rm -rf $dir
}

# ── Runner ─────────────────────────────────────────────────────────────────

def main [] {
    run-tests "entities.nu" [
        ["create-entity: component",              { test_create_entity_component }]
        ["create-entity: api",                    { test_create_entity_api }]
        ["create-entity: resource",               { test_create_entity_resource }]
        ["create-entity: system",                 { test_create_entity_system }]
        ["create-entity: group",                  { test_create_entity_group }]
        ["create-entity: user",                   { test_create_entity_user }]
        ["create-entity: default output path",    { test_create_entity_default_output_path }]
        ["create-entity: with description",       { test_create_entity_with_description }]
        ["validate-entity: valid entity",         { test_validate_entity_valid }]
        ["validate-entity: missing apiVersion",   { test_validate_entity_missing_apiversion }]
        ["validate-entity: missing kind",         { test_validate_entity_missing_kind }]
        ["validate-entity: missing metadata",     { test_validate_entity_missing_metadata }]
        ["list-entities: returns all yaml files", { test_list_entities }]
        ["create-bulk: basic template",           { test_create_bulk_entities_basic }]
        ["create-bulk: microservices template",   { test_create_bulk_entities_microservices }]
        ["create-bulk: team-structure template",  { test_create_bulk_entities_team_structure }]
    ]
}

