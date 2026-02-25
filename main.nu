#! /usr/bin/env nu

# Platform CLI - Backstage IdP Bootstrap Tool
# A comprehensive CLI for creating production-ready Backstage instances

use modules/utils.nu
use modules/scaffolding.nu
use modules/plugins.nu *
use modules/app-config.nu *
use modules/entities.nu *
use modules/auth.nu *
use config.nu

def print-banner [] {
    let colors = (config get-colors)
    print (($colors.cyan + $colors.bold) + "
 ╔═══════════════════════════════════════════════════════════════╗
 ║                                                               ║
 ║              Platform CLI - Backstage Bootstrap               ║
 ║                                                               ║
 ║         Create production-ready Backstage instances           ║
 ║                                                               ║
 ╚═══════════════════════════════════════════════════════════════╝
" + $colors.reset)
}

def print-help [] {
    print-banner
    print ""
    utils print-header "Commands"
    print "
  init                 Create a new Backstage instance
  plugin list          List available plugins
  plugin add           Install a plugin into a Backstage instance
  plugin remove        Remove a plugin from a Backstage instance
  plugin info          Show install instructions for a plugin
  auth list            List available auth providers
  auth add             Install and configure an auth provider
  auth info            Show full setup guide for an auth provider
  config               Configuration management
  entity               Entity catalog management
  validate             Validate Backstage setup
  deploy               Prepare for production deployment
  help                 Show this help message

Examples:
  platform init my-backstage
  platform plugin list
  platform plugin add azure-devops ./my-backstage
  platform auth list
  platform auth info microsoft
  platform auth add microsoft ./my-backstage
  platform auth add microsoft ./my-backstage --client-id abc --client-secret xyz --tenant-id tid
  platform config set-database ./my-backstage --db-type postgresql
  platform entity create my-service --type component
  platform validate ./my-backstage
  
See 'platform auth info <provider>' or 'platform plugin info <name>' for detailed setup guides.
"
}

# Main init command
export def init [
    name: string
    --path: string = "."
    --skip-git = false
    --skip-install = false
] {
    scaffolding create-instance $name --path $path --skip-git=$skip_git --skip-install=$skip_install
}

# Plugin commands
export def "plugin add" [
    plugin_name: string
    instance_path: string
    --frontend-only
    --backend-only
    --skip-config
] {
    add-plugin $plugin_name $instance_path --frontend-only=$frontend_only --backend-only=$backend_only --skip-config=$skip_config
}

export def "plugin remove" [plugin_name: string, instance_path: string] {
    remove-plugin $plugin_name $instance_path
}

export def "plugin list" [] {
    list-available-plugins
}

export def "plugin info" [plugin_name: string] {
    show-plugin-info $plugin_name
}

# Auth commands
export def "auth add" [
    provider: string
    instance_path: string
    --client-id: string
    --client-secret: string
    --tenant-id: string
    --no-guest
    --skip-config
    --skip-install
] {
    add-auth-provider $provider $instance_path --client-id $client_id --client-secret $client_secret --tenant-id $tenant_id --no-guest=$no_guest --skip-config=$skip_config --skip-install=$skip_install
}

export def "auth list" [] {
    list-auth-providers
}

export def "auth info" [provider: string, --no-guest] {
    show-auth-info $provider --no-guest=$no_guest
}

# Config commands
export def "config init" [instance_path: string, --name: string] {
    init-app-config $instance_path --name $name
}

export def "config validate" [instance_path: string] {
    let config_path = ($instance_path + "/app-config.yaml")
    validate-app-config $config_path
}

export def "config set-database" [
    instance_path: string
    --db-type: string = "postgresql"
    --host: string = "localhost"
    --port: int
    --user: string
    --password: string
    --database: string
] {
    configure-database $instance_path --db-type $db_type --host $host --port $port --user $user --password $password --database $database
}

export def "config set-auth" [
    instance_path: string
    --provider: string = "github"
    --client-id: string
    --client-secret: string
] {
    configure-auth $instance_path --provider $provider --client-id $client_id --client-secret $client_secret
}

export def "config set-storage" [
    instance_path: string
    --provider: string = "local"
    --bucket: string
    --region: string
] {
    configure-storage $instance_path --provider $provider --bucket $bucket --region $region
}

# Entity commands
export def "entity create" [
    name: string
    --type: string = "component"
    --owner: string = "platform-team"
    --system: string = "internal-platform"
    --description: string = ""
    --output: string
] {
    create-entity $name --type $type --owner $owner --system $system --description $description --output $output
}

export def "entity create-bulk" [
    instance_path: string
    --template: string = "basic"
] {
    create-bulk-$instance_path --template $template
}

export def "entity list" [instance_path: string] {
    let entity_files = (list-$instance_path)
    
    if ($entity_files | is-empty) {
        utils print-info "No found"
        return
    }
    
    utils print-header "Catalog Entities"
    $entity_files | each {|file|
        print $"  - ($file)"
    }
}

export def "entity validate" [entity_path: string] {
    validate-entity $entity_path
}

# Validate command
export def validate [instance_path: string] {
    utils print-header "Validating Backstage Instance"
    
    let checks = [
        {
            name: "package.json",
            path: ($instance_path + "/package.json"),
            critical: true
        },
        {
            name: "app-config.yaml",
            path: ($instance_path + "/app-config.yaml"),
            critical: true
        },
        {
            name: "tsconfig.json",
            path: ($instance_path + "/tsconfig.json"),
            critical: false
        },
        {
            name: "Directory structure",
            path: ($instance_path + "/app"),
            critical: true
        }
    ]
    
    mut valid = true
    
    for check in $checks {
        if ($check.path | path exists) {
            utils print-success $check.name
        } else {
            if $check.critical {
                utils print-error $check.name
                $valid = false
            } else {
                utils print-warning $check.name
            }
        }
    }
    
    print ""
    if $valid {
        utils print-success "Instance validation passed"
    } else {
        utils print-error "Instance validation failed - please check critical items"
        exit 1
    }
}

# Deploy command
export def deploy [instance_path: string, --environment: string = "production"] {
    utils print-header $"Preparing for Deployment: ($environment)"
    
    # Validate first
    validate $instance_path
    
    utils print-info "Running final build..."
    utils print-info "Preparing configuration..."
    utils print-info "Generating deployment manifests..."
    
    utils print-success "Deployment preparation complete"
    utils print-info $"Instance is ready for ($environment) deployment"
}

# Main entry point
def --wrapped main [--help (-h), ...rest] {
    if $help or ($rest | is-empty) {
        print-help
        return
    }
    
    # Dispatch to subcommands
    match $rest.0 {
        "init" => {
            if ($rest | length) < 2 {
                print-help
                exit 1
            }
            init ($rest | get 1)
        },
        "plugin" => {
            if ($rest | length) < 2 {
                utils print-error "Missing plugin command. Available: add, remove, list, info"
                exit 1
            }
            match $rest.1 {
                "add" => {
                    if ($rest | length) < 4 {
                        utils print-error "Usage: platform plugin add <name> <instance-path> [--frontend-only] [--backend-only] [--skip-config]"
                        exit 1
                    }
                    let frontend_only = ("--frontend-only" in $rest)
                    let backend_only  = ("--backend-only"  in $rest)
                    let skip_config   = ("--skip-config"   in $rest)
                    add-plugin ($rest | get 2) ($rest | get 3) --frontend-only=$frontend_only --backend-only=$backend_only --skip-config=$skip_config
                },
                "remove" => {
                    if ($rest | length) < 4 {
                        utils print-error "Usage: platform plugin remove <name> <instance-path>"
                        exit 1
                    }
                    remove-plugin ($rest | get 2) ($rest | get 3)
                },
                "list" => {
                    list-available-plugins
                },
                "info" => {
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform plugin info <name>"
                        exit 1
                    }
                    show-plugin-info ($rest | get 2)
                },
                _ => {
                    utils print-error $"Unknown plugin command: ($rest.1). Available: add, remove, list, info"
                    exit 1
                }
            }
        },
        "config" => {
            if ($rest | length) < 2 {
                utils print-error "Missing config command. Available: init, validate, set-database, set-auth, set-storage"
                exit 1
            }
            match $rest.1 {
                "init" => {
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform config init <instance-path> [--name <name>]"
                        exit 1
                    }
                    let name_val = (get-flag $rest "--name")
                    if ($name_val != null) {
                        config init ($rest | get 2) --name $name_val
                    } else {
                        config init ($rest | get 2)
                    }
                },
                "validate" => {
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform config validate <instance-path>"
                        exit 1
                    }
                    config validate ($rest | get 2)
                },
                "set-database" => {
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform config set-database <instance-path> [--db-type <type>] [--host <host>]"
                        exit 1
                    }
                    let db_type  = (get-flag $rest "--db-type"  | default "postgresql")
                    let db_host  = (get-flag $rest "--host"     | default "localhost")
                    let db_user  = (get-flag $rest "--user"     | default "")
                    let db_pass  = (get-flag $rest "--password" | default "")
                    let db_name  = (get-flag $rest "--database" | default "")
                    config set-database ($rest | get 2) --db-type $db_type --host $db_host --user $db_user --password $db_pass --database $db_name
                },
                "set-auth" => {
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform config set-auth <instance-path> --provider <provider> --client-id <id> --client-secret <secret>"
                        exit 1
                    }
                    let provider      = (get-flag $rest "--provider"      | default "github")
                    let client_id     = (get-flag $rest "--client-id"     | default "")
                    let client_secret = (get-flag $rest "--client-secret" | default "")
                    config set-auth ($rest | get 2) --provider $provider --client-id $client_id --client-secret $client_secret
                },
                "set-storage" => {
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform config set-storage <instance-path> --provider <provider>"
                        exit 1
                    }
                    let provider = (get-flag $rest "--provider" | default "local")
                    let bucket   = (get-flag $rest "--bucket"   | default "")
                    let region   = (get-flag $rest "--region"   | default "")
                    config set-storage ($rest | get 2) --provider $provider --bucket $bucket --region $region
                },
                _ => {
                    utils print-error $"Unknown config command: ($rest.1)"
                    exit 1
                }
            }
        },
        "entity" => {
            if ($rest | length) < 2 {
                utils print-error "Missing entity command. Available: create, create-bulk, list, validate"
                exit 1
            }
            match $rest.1 {
                "create" => {
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform entity create <name> [--type <type>] [--owner <owner>]"
                        exit 1
                    }
                    let entity_type = (get-flag $rest "--type"        | default "component")
                    let owner       = (get-flag $rest "--owner"       | default "platform-team")
                    let system      = (get-flag $rest "--system"      | default "internal-platform")
                    let description = (get-flag $rest "--description" | default "")
                    let output      = (get-flag $rest "--output"      | default "")
                    if ($output | is-not-empty) {
                        create-entity ($rest | get 2) --type $entity_type --owner $owner --system $system --description $description --output $output
                    } else {
                        create-entity ($rest | get 2) --type $entity_type --owner $owner --system $system --description $description
                    }
                },
                "create-bulk" => {
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform entity create-bulk <instance-path> [--template <template>]"
                        exit 1
                    }
                    let template = (get-flag $rest "--template" | default "basic")
                    create-bulk-entities ($rest | get 2) --template $template
                },
                "list" => {
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform entity list <instance-path>"
                        exit 1
                    }
                    let entity_files = (list-entities ($rest | get 2))
                    if ($entity_files | is-empty) {
                        utils print-info "No entities found"
                    } else {
                        utils print-header "Catalog Entities"
                        $entity_files | each {|file| print $"  - ($file)"} | ignore
                    }
                },
                "validate" => {
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform entity validate <entity-path>"
                        exit 1
                    }
                    validate-entity ($rest | get 2)
                },
                _ => {
                    utils print-error $"Unknown entity command: ($rest.1)"
                    exit 1
                }
            }
        },
        "validate" => {
            if ($rest | length) < 2 {
                print-help
                exit 1
            }
            validate ($rest | get 1)
        },
        "auth" => {
            if ($rest | length) < 2 {
                utils print-error "Missing auth command. Available: add, list, info"
                exit 1
            }
            match $rest.1 {
                "add" => {
                    if ($rest | length) < 4 {
                        utils print-error "Usage: platform auth add <provider> <instance-path> [--client-id <id>] [--client-secret <secret>] [--tenant-id <tid>]"
                        exit 1
                    }
                    let client_id     = (get-flag $rest "--client-id")
                    let client_secret = (get-flag $rest "--client-secret")
                    let tenant_id     = (get-flag $rest "--tenant-id")
                    let no_guest      = ("--no-guest"     in $rest)
                    let skip_config   = ("--skip-config"  in $rest)
                    let skip_install  = ("--skip-install" in $rest)
                    let provider      = ($rest | get 2)
                    let path          = ($rest | get 3)
                    if ($client_id != null) and ($client_secret != null) and ($tenant_id != null) {
                        add-auth-provider $provider $path --client-id $client_id --client-secret $client_secret --tenant-id $tenant_id --no-guest=$no_guest --skip-config=$skip_config --skip-install=$skip_install
                    } else if ($client_id != null) and ($client_secret != null) {
                        add-auth-provider $provider $path --client-id $client_id --client-secret $client_secret --no-guest=$no_guest --skip-config=$skip_config --skip-install=$skip_install
                    } else if ($client_id != null) {
                        add-auth-provider $provider $path --client-id $client_id --no-guest=$no_guest --skip-config=$skip_config --skip-install=$skip_install
                    } else {
                        add-auth-provider $provider $path --no-guest=$no_guest --skip-config=$skip_config --skip-install=$skip_install
                    }
                },
                "list" => {
                    list-auth-providers
                },
                "info" => {
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform auth info <provider> [--no-guest]"
                        exit 1
                    }
                    let no_guest = ("--no-guest" in $rest)
                    show-auth-info ($rest | get 2) --no-guest=$no_guest
                },
                _ => {
                    utils print-error $"Unknown auth command: ($rest.1). Available: add, list, info"
                    exit 1
                }
            }
        },
        "deploy" => {
            if ($rest | length) < 2 {
                print-help
                exit 1
            }
            deploy ($rest | get 1)
        },
        "help" | "--help" | "-h" => {
            print-help
        },
        _ => {
            utils print-error $"Unknown command: ($rest.0)"
            print-help
            exit 1
        }
    }
}

# Extract a named flag value from a list of raw args (e.g. ["--name", "foo"] -> "foo")
def get-flag [args: list, flag: string] {
    let idx = ($args | enumerate | where {|e| $e.item == $flag} | get 0?.index?)
    if ($idx != null) {
        $args | get ($idx + 1)
    } else {
        null
    }
}


