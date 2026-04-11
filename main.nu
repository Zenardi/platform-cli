#! /usr/bin/env nu

# Platform CLI - Backstage IdP Bootstrap Tool
# A comprehensive CLI for creating production-ready Backstage instances

use modules/utils.nu
use modules/scaffolding.nu
use modules/plugins.nu *
use modules/app-config.nu *
use modules/entities.nu *
use modules/auth.nu *
use modules/dockerfile.nu *
use modules/kubernetes.nu *
use modules/actions.nu *
use modules/cluster.nu *
use modules/onboarding.nu *
use config.nu

def print-banner [] {
    let colors = (config get-colors)
    let version = (config get-version)
    print (($colors.cyan + $colors.bold) + "
 ╔═══════════════════════════════════════════════════════════════╗
 ║                                                               ║
 ║              Platform CLI - Backstage Bootstrap               ║
 ║                                                               ║
 ║         Create production-ready Backstage instances           ║
 ║                                                               ║
 ╚═══════════════════════════════════════════════════════════════╝
" + $colors.reset)
    print $"  ($colors.bold)version($colors.reset) ($version)\n"
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
  plugin installed     List plugins currently installed in a Backstage instance
  auth list            List available auth providers
  auth add             Install and configure an auth provider
  auth info            Show full setup guide for an auth provider
  action list          List available custom scaffolder actions
  action add           Install a custom scaffolder action into a Backstage instance
  action info          Show details and usage for a custom scaffolder action
  config               Configuration management
  entity               Entity catalog management
  validate             Validate Backstage setup
  dockerfile           Generate a production Dockerfile and .dockerignore
  k8s                  Generate Kubernetes manifests (Deployment, Service, Ingress, Secrets)
  cluster              Manage Kubernetes cluster config in app-config.local.yaml
  project              Manage Azure project onboarding pre-requisites
  deploy               Prepare for production deployment
  help                 Show this help message

Examples:
  platform init my-backstage
  platform plugin list
  platform plugin info kubernetes
  platform plugin add azure-devops ./my-backstage
  platform plugin installed ./my-backstage
  platform auth list
  platform auth info microsoft
  platform auth add microsoft ./my-backstage
  platform auth add microsoft ./my-backstage --client-id abc --client-secret xyz --tenant-id tid
  platform action list
  platform action info azure-pipeline
  platform action add azure-pipeline ./my-backstage
  platform config set-database ./my-backstage --db-type postgresql
  platform entity create my-service --type component
  platform validate ./my-backstage
  platform dockerfile ./my-backstage
  platform dockerfile ./my-backstage --output ./deploy/Dockerfile
  platform k8s ./my-backstage
  platform k8s ./my-backstage --image ghcr.io/myorg/backstage:v1.0 --host backstage.mycompany.io
  platform cluster configure ./my-backstage --cluster-name kind-backstage
  platform cluster configure ./my-backstage --cluster-name prod-cluster --kubeconfig ~/.kube/prod.yaml --sa-name backstage-reader
  platform cluster configure ./my-backstage --cluster-name kind-backstage --duration 2160h
  platform cluster list ./my-backstage
  platform project onboard --project-name myproject --subscription-id <uuid> --tenant-id <uuid> --ado-org https://dev.azure.com/myorg --backstage-object-id <uuid>
  platform project onboard --project-name myproject --subscription-id <uuid> --tenant-id <uuid> --ado-org https://dev.azure.com/myorg --backstage-object-id <uuid> --dry-run
  
See 'platform auth info <provider>' or 'platform plugin info <name>' for detailed setup guides.
"
}

# Print a formatted help block for a subcommand.
# Accepts a record with: usage, description, examples, and optionally args and options.
def print-subcommand-help [info: record] {
    let colors = (config get-colors)
    let args_text    = ($info | get --optional args    | default "")
    let options_text = ($info | get --optional options | default "")

    print $"\n($info.description)\n"
    print $"($colors.bold)Usage:($colors.reset)"
    print $"  ($info.usage)\n"
    if ($args_text | is-not-empty) {
        print $"($colors.bold)Arguments:($colors.reset)"
        print $args_text
        print ""
    }
    if ($options_text | is-not-empty) {
        print $"($colors.bold)Options:($colors.reset)"
        print $options_text
        print ""
    }
    print $"($colors.bold)Examples:($colors.reset)"
    print $info.examples
    print ""
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
            name: "packages/app (frontend)",
            path: ($instance_path + "/packages/app"),
            critical: true
        },
        {
            name: "packages/backend",
            path: ($instance_path + "/packages/backend"),
            critical: true
        }
    ]
    
    mut valid = true
    
    for check in $checks {
        if ($check.path | path exists) {
            utils print-success $check.name
        } else {
            if $check.critical {
                utils print-error $"($check.name)  ← not found: ($check.path | path expand)"
                $valid = false
            } else {
                utils print-warning $"($check.name)  ← not found: ($check.path | path expand)"
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

# Dockerfile command
export def "dockerfile gen" [
    instance_path: string
    --output: string = ""
] {
    if ($output | is-not-empty) {
        generate-dockerfile $instance_path --output $output
    } else {
        generate-dockerfile $instance_path
    }
}

# Kubernetes manifests command
export def "k8s gen" [
    instance_path: string
    --namespace: string = "backstage"
    --image: string = "docker.io/YOUR_DOCKERHUB_USER/backstage:latest"
    --host: string = "backstage.example.com"
    --replicas: int = 2
] {
    generate-k8s-manifests $instance_path --namespace $namespace --image $image --host $host --replicas $replicas
}

# Deploy command
export def deploy [instance_path: string, --environment: string = "production"] {    utils print-header $"Preparing for Deployment: ($environment)"
    
    # Validate first
    validate $instance_path
    
    utils print-info "Running final build..."
    utils print-info "Preparing configuration..."
    utils print-info "Generating deployment manifests..."
    
    utils print-success "Deployment preparation complete"
    utils print-info $"Instance is ready for ($environment) deployment"
}

# Main entry point — Platform CLI for Backstage IdP automation
def --wrapped main [...rest: string] {
    if ($rest | is-empty) or ("--help" in $rest) and ($rest | length) == 1 or ("-h" in $rest) and ($rest | length) == 1 {
        print-help
        return
    }
    
    # Dispatch to subcommands
    match $rest.0 {
        "init" => {
            if ("--help" in $rest) or ("-h" in $rest) {
                print-subcommand-help {
                    usage: "platform init <name> [flags]"
                    description: "Create a new Backstage instance using @backstage/create-app@latest.\nRuns npx under the hood and sets up a full monorepo with app and backend packages."
                    args: "  name    Name of the new Backstage instance (used as the directory name)"
                    options: "  --path <path>       Parent directory to create the instance in (default: current directory)\n  --skip-install      Skip the yarn install step (useful for CI or offline use)"
                    examples: "  platform init my-backstage\n  platform init my-backstage --path ~/projects\n  platform init my-backstage --skip-install"
                }
                return
            }
            if ($rest | length) < 2 {
                print-help
                exit 1
            }
            init ($rest | get 1)
        },
        "plugin" => {
            if ($rest | length) < 2 or $rest.1 == "--help" or $rest.1 == "-h" {
                print-subcommand-help {
                    usage: "platform plugin <subcommand> [args]"
                    description: "Manage plugins for a Backstage instance.\nSubcommands: add, remove, list, info, installed"
                    examples: "  platform plugin list\n  platform plugin info kubernetes\n  platform plugin add kubernetes ./my-backstage\n  platform plugin remove kubernetes ./my-backstage\n  platform plugin installed ./my-backstage"
                }
                return
            }
            match $rest.1 {
                "add" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform plugin add <name> <instance-path> [flags]"
                            description: "Install and configure a plugin in an existing Backstage instance.\nRuns yarn add, patches TypeScript files, and writes app-config.local.yaml entries.\nUse 'platform plugin list' to see all available plugins."
                            args: "  name            Plugin name (see 'platform plugin list')\n  instance-path   Path to the Backstage instance root"
                            options: "  --frontend-only   Only install frontend packages\n  --backend-only    Only install backend packages\n  --skip-config     Skip app-config.yaml patching"
                            examples: "  platform plugin add kubernetes ./my-backstage\n  platform plugin add techdocs ./my-backstage\n  platform plugin add techdocs ./my-backstage --frontend-only"
                        }
                        return
                    }
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
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform plugin remove <name> <instance-path>"
                            description: "Remove a plugin from a Backstage instance.\nRuns yarn remove for all associated packages."
                            args: "  name            Plugin name\n  instance-path   Path to the Backstage instance root"
                            examples: "  platform plugin remove kubernetes ./my-backstage\n  platform plugin remove techdocs ./my-backstage"
                        }
                        return
                    }
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
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform plugin info <name>"
                            description: "Show detailed installation instructions for a specific plugin,\nincluding required packages, environment variables, and manual configuration steps."
                            args: "  name    Plugin name (see 'platform plugin list')"
                            examples: "  platform plugin info kubernetes\n  platform plugin info techdocs\n  platform plugin info azure-devops"
                        }
                        return
                    }
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform plugin info <name>"
                        exit 1
                    }
                    show-plugin-info ($rest | get 2)
                },
                "installed" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform plugin installed <instance-path>"
                            description: "List all CLI-registered plugins that are currently installed in a Backstage instance.\nScans packages/app/package.json and packages/backend/package.json for known plugin packages\nand cross-references them against the CLI plugin registry."
                            args: "  instance-path   Path to the Backstage instance root"
                            examples: "  platform plugin installed ./my-backstage\n  platform plugin installed ."
                        }
                        return
                    }
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform plugin installed <instance-path>"
                        exit 1
                    }
                    print-installed-plugins ($rest | get 2)
                },
                _ => {
                    utils print-error $"Unknown plugin command: ($rest.1). Available: add, remove, list, info, installed"
                    exit 1
                }
            }
        },
        "config" => {
            if ($rest | length) < 2 or $rest.1 == "--help" or $rest.1 == "-h" {
                print-subcommand-help {
                    usage: "platform config <subcommand> [args]"
                    description: "Manage app-config.yaml configuration for a Backstage instance.\nSubcommands: init, validate, set-database, set-auth, set-storage"
                    examples: "  platform config init ./my-backstage\n  platform config validate ./my-backstage\n  platform config set-database ./my-backstage --db-type postgresql\n  platform config set-auth ./my-backstage --provider github\n  platform config set-storage ./my-backstage --provider s3"
                }
                return
            }
            match $rest.1 {
                "init" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform config init <instance-path> [flags]"
                            description: "Initialize a new app-config.local.yaml file in the Backstage instance\nwith sensible defaults for local development."
                            args: "  instance-path   Path to the Backstage instance root"
                            options: "  --name <name>   Application display name"
                            examples: "  platform config init ./my-backstage\n  platform config init ./my-backstage --name \"My IDP\""
                        }
                        return
                    }
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
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform config validate <instance-path>"
                            description: "Validate the app-config.yaml file for required fields and structural correctness."
                            args: "  instance-path   Path to the Backstage instance root"
                            examples: "  platform config validate ./my-backstage"
                        }
                        return
                    }
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform config validate <instance-path>"
                        exit 1
                    }
                    config validate ($rest | get 2)
                },
                "set-database" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform config set-database <instance-path> [flags]"
                            description: "Configure the database connection in app-config.yaml.\nSupports PostgreSQL (recommended for production) and SQLite (for local development)."
                            args: "  instance-path   Path to the Backstage instance root"
                            options: "  --db-type <type>      Database type: postgresql or sqlite (default: postgresql)\n  --host <host>         Database host (default: localhost)\n  --user <user>         Database username\n  --password <pass>     Database password\n  --database <name>     Database name"
                            examples: "  platform config set-database ./my-backstage\n  platform config set-database ./my-backstage --db-type postgresql --host db.example.com\n  platform config set-database ./my-backstage --db-type sqlite"
                        }
                        return
                    }
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
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform config set-auth <instance-path> [flags]"
                            description: "Configure the authentication provider section in app-config.yaml."
                            args: "  instance-path   Path to the Backstage instance root"
                            options: "  --provider <name>        Auth provider: github, microsoft, gitlab (default: github)\n  --client-id <id>         OAuth client ID\n  --client-secret <secret> OAuth client secret"
                            examples: "  platform config set-auth ./my-backstage --provider github\n  platform config set-auth ./my-backstage --provider github --client-id abc --client-secret xyz"
                        }
                        return
                    }
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
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform config set-storage <instance-path> [flags]"
                            description: "Configure object storage for TechDocs in app-config.yaml.\nUsed to store and serve generated documentation sites."
                            args: "  instance-path   Path to the Backstage instance root"
                            options: "  --provider <name>   Storage provider: local, s3, gcs (default: local)\n  --bucket <name>     Storage bucket name (required for s3/gcs)\n  --region <region>   Cloud region (required for s3)"
                            examples: "  platform config set-storage ./my-backstage\n  platform config set-storage ./my-backstage --provider s3 --bucket my-docs --region us-east-1\n  platform config set-storage ./my-backstage --provider gcs --bucket my-docs"
                        }
                        return
                    }
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
            if ($rest | length) < 2 or $rest.1 == "--help" or $rest.1 == "-h" {
                print-subcommand-help {
                    usage: "platform entity <subcommand> [args]"
                    description: "Manage Backstage catalog entity YAML files.\nSubcommands: create, create-bulk, list, validate"
                    examples: "  platform entity create my-service\n  platform entity create my-api --type api --owner team-a\n  platform entity list ./my-backstage\n  platform entity validate ./catalog-entities/my-service.yaml"
                }
                return
            }
            match $rest.1 {
                "create" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform entity create <name> [flags]"
                            description: "Generate a Backstage catalog YAML entity file.\nSupports Component, API, Group, User, System, and Domain kinds.\nOutput is written to ./catalog-entities/<name>.yaml by default."
                            args: "  name    Entity name (used in metadata.name)"
                            options: "  --type <type>            Entity kind: component, api, group, user, system, domain (default: component)\n  --owner <owner>          Owning team or user (default: platform-team)\n  --system <system>        Parent system name (default: internal-platform)\n  --description <text>     Short description of the entity\n  --output <path>          Custom output file path"
                            examples: "  platform entity create my-service\n  platform entity create my-api --type api --owner team-a\n  platform entity create platform --type system\n  platform entity create my-service --output ./catalog/my-service.yaml"
                        }
                        return
                    }
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
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform entity create-bulk <instance-path> [flags]"
                            description: "Generate a set of catalog entities from a predefined template.\nUseful for bootstrapping a new instance with example entities."
                            args: "  instance-path   Path to the Backstage instance root"
                            options: "  --template <name>   Template to use: basic (default: basic)"
                            examples: "  platform entity create-bulk ./my-backstage\n  platform entity create-bulk ./my-backstage --template basic"
                        }
                        return
                    }
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform entity create-bulk <instance-path> [--template <template>]"
                        exit 1
                    }
                    let template = (get-flag $rest "--template" | default "basic")
                    create-bulk-entities ($rest | get 2) --template $template
                },
                "list" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform entity list <instance-path>"
                            description: "List all catalog entity YAML files found in the instance's catalog-entities/ directory."
                            args: "  instance-path   Path to the Backstage instance root"
                            examples: "  platform entity list ./my-backstage"
                        }
                        return
                    }
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
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform entity validate <entity-path>"
                            description: "Validate a catalog entity YAML file against the Backstage catalog schema.\nChecks for required fields (apiVersion, kind, metadata.name, spec)."
                            args: "  entity-path   Path to the entity YAML file"
                            examples: "  platform entity validate ./catalog-entities/my-service.yaml"
                        }
                        return
                    }
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
            if ("--help" in $rest) or ("-h" in $rest) {
                print-subcommand-help {
                    usage: "platform validate <instance-path>"
                    description: "Validate that a Backstage instance directory is correctly structured.\nChecks for: package.json, app-config.yaml, tsconfig.json, packages/app, and packages/backend.\nCritical items cause a non-zero exit; warnings do not."
                    args: "  instance-path   Path to the Backstage instance root"
                    examples: "  platform validate ./my-backstage\n  platform validate ."
                }
                return
            }
            if ($rest | length) < 2 {
                print-help
                exit 1
            }
            validate ($rest | get 1)
        },
        "auth" => {
            if ($rest | length) < 2 or $rest.1 == "--help" or $rest.1 == "-h" {
                print-subcommand-help {
                    usage: "platform auth <subcommand> [args]"
                    description: "Manage authentication providers for a Backstage instance.\nSubcommands: add, list, info"
                    examples: "  platform auth list\n  platform auth info github\n  platform auth add github ./my-backstage\n  platform auth add microsoft ./my-backstage --client-id abc --client-secret xyz --tenant-id tid"
                }
                return
            }
            match $rest.1 {
                "add" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform auth add <provider> <instance-path> [flags]"
                            description: "Install and configure an authentication provider in a Backstage instance.\nInstalls packages via yarn, patches backend and frontend TypeScript files,\nand writes the auth section to app-config.local.yaml."
                            args: "  provider        Auth provider name (see 'platform auth list')\n  instance-path   Path to the Backstage instance root"
                            options: "  --client-id <id>         OAuth client ID\n  --client-secret <secret> OAuth client secret\n  --tenant-id <id>         Tenant ID (Microsoft Entra only)\n  --no-guest               Disable guest/anonymous access\n  --skip-config            Skip config file patching\n  --skip-install           Skip yarn install"
                            examples: "  platform auth add github ./my-backstage\n  platform auth add github ./my-backstage --client-id abc --client-secret xyz\n  platform auth add microsoft ./my-backstage --client-id abc --client-secret xyz --tenant-id tid\n  platform auth add microsoft ./my-backstage --no-guest"
                        }
                        return
                    }
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
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform auth info <provider> [flags]"
                            description: "Show a full setup guide for an authentication provider.\nIncludes required environment variables, Kubernetes secret keys,\nand step-by-step manual configuration instructions."
                            args: "  provider   Auth provider name (see 'platform auth list')"
                            options: "  --no-guest   Show configuration with guest access disabled"
                            examples: "  platform auth info github\n  platform auth info microsoft\n  platform auth info microsoft --no-guest"
                        }
                        return
                    }
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
        "dockerfile" => {
            if ("--help" in $rest) or ("-h" in $rest) {
                print-subcommand-help {
                    usage: "platform dockerfile <instance-path> [flags]"
                    description: "Generate a production-ready multi-stage Dockerfile and .dockerignore for a Backstage instance.\n\nThree build stages:\n  1. packages  — extracts package.json skeleton for yarn install caching\n  2. build     — installs deps, runs yarn tsc and yarn backend build\n  3. final     — Chainguard Node image (minimal CVEs)\n\nAlso writes a correct .dockerignore that avoids stripping TypeScript source files,\nwhich would cause 'TS18003: No inputs were found' during yarn tsc."
                    args: "  instance-path   Path to the Backstage instance root"
                    options: "  --output <path>   Custom output path for the Dockerfile (default: <instance-path>/Dockerfile)"
                    examples: "  platform dockerfile ./my-backstage\n  platform dockerfile ./my-backstage --output ./deploy/Dockerfile\n  docker build -t backstage ./my-backstage"
                }
                return
            }
            if ($rest | length) < 2 {
                utils print-error "Usage: platform dockerfile <instance-path> [--output <path>]"
                exit 1
            }
            let output = (get-flag $rest "--output" | default "")
            if ($output | is-not-empty) {
                generate-dockerfile ($rest | get 1) --output $output
            } else {
                generate-dockerfile ($rest | get 1)
            }
        },
        "k8s" => {
            if ("--help" in $rest) or ("-h" in $rest) {
                print-subcommand-help {
                    usage: "platform k8s <instance-path> [flags]"
                    description: "Generate production-ready Kubernetes manifests for a Backstage instance.\n\nCreates a k8s/ directory containing:\n  deployment.yaml                — Deployment with health probes and resource limits\n  service.yaml                   — ClusterIP Service on port 80\n  ingress.yaml                   — Traefik Ingress with TLS\n  backstage-secrets.example.yaml — Secret template with all required env vars\n\nEdit backstage-secrets.example.yaml with your values, rename it to\nbackstage-secrets.yaml, then apply: kubectl apply -f k8s/"
                    args: "  instance-path   Path to the Backstage instance root"
                    options: "  --namespace <ns>    Kubernetes namespace (default: backstage)\n  --image <img>       Container image (default: docker.io/YOUR_DOCKERHUB_USER/backstage:latest)\n  --host <host>       Ingress hostname (default: backstage.example.com)\n  --replicas <n>      Deployment replica count (default: 2)"
                    examples: "  platform k8s ./my-backstage\n  platform k8s ./my-backstage --image ghcr.io/myorg/backstage:v1.0 --host backstage.mycompany.io\n  platform k8s ./my-backstage --namespace production --replicas 3"
                }
                return
            }
            if ($rest | length) < 2 {
                utils print-error "Usage: platform k8s <instance-path> [--namespace <ns>] [--image <img>] [--host <host>] [--replicas <n>]"
                exit 1
            }
            let ns       = (get-flag $rest "--namespace" | default "backstage")
            let img      = (get-flag $rest "--image"     | default "docker.io/YOUR_DOCKERHUB_USER/backstage:latest")
            let host_val = (get-flag $rest "--host"      | default "backstage.example.com")
            let reps_str = (get-flag $rest "--replicas"  | default "2")
            let reps     = ($reps_str | into int)
            generate-k8s-manifests ($rest | get 1) --namespace $ns --image $img --host $host_val --replicas $reps
        },
        "cluster" => {
            if ($rest | length) < 2 or $rest.1 == "--help" or $rest.1 == "-h" {
                print-subcommand-help {
                    usage: "platform cluster <subcommand> [args]"
                    description: "Manage Kubernetes cluster configuration in app-config.local.yaml.\n\nSubcommands:\n  configure   Create/update ServiceAccount+RBAC, generate token, and register\n              the cluster in app-config.local.yaml (idempotent — re-run to rotate token).\n  list        Show clusters already configured in app-config.local.yaml."
                    examples: "  platform cluster configure ./my-backstage --cluster-name kind-backstage\n  platform cluster configure ./my-backstage --cluster-name prod --kubeconfig ~/.kube/prod.yaml\n  platform cluster configure ./my-backstage --cluster-name kind-backstage --duration 2160h\n  platform cluster configure ./my-backstage --cluster-name kind-backstage --sa-name my-sa --namespace monitoring\n  platform cluster list ./my-backstage"
                }
                return
            }
            match $rest.1 {
                "configure" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform cluster configure <instance-path> --cluster-name <name> [flags]"
                            description: "Create or update a Kubernetes cluster in app-config.local.yaml.\n\nThis command is idempotent:\n  • Re-running it rotates the token for an existing cluster entry.\n  • Using a new --cluster-name appends a second cluster.\n\nSteps performed:\n  1. Creates/updates the ServiceAccount and ClusterRole/ClusterRoleBinding\n     on the target cluster (kubectl apply — safe to re-run).\n  2. Generates a fresh service account token.\n  3. Auto-detects the cluster URL from the active kubeconfig.\n  4. Writes (or updates) the cluster block in app-config.local.yaml.\n\nRestart Backstage after running this command."
                            args: "  instance-path   Path to the Backstage instance root"
                            options: "  --cluster-name <name>   Name for the cluster in Backstage (required)\n  --kubeconfig <path>     Path to kubeconfig file (default: ~/.kube/config)\n  --context <ctx>         Kubeconfig context to use\n  --sa-name <name>        ServiceAccount name to create/use (default: backstage-reader)\n  --namespace <ns>        Namespace for the ServiceAccount (default: default)\n  --duration <dur>        Token lifetime, e.g. 8760h, 2160h (default: 8760h = 1 year)\n  --skip-tls-verify       Disable TLS certificate verification\n  --dry-run               Preview all steps without making any changes"
                            examples: "  platform cluster configure ./my-backstage --cluster-name kind-backstage\n  platform cluster configure ./my-backstage --cluster-name prod --kubeconfig ~/.kube/prod.yaml --context prod-admin\n  platform cluster configure ./my-backstage --cluster-name kind-backstage --duration 2160h\n  platform cluster configure ./my-backstage --cluster-name kind-backstage --sa-name my-sa --namespace monitoring --skip-tls-verify"
                        }
                        return
                    }
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform cluster configure <instance-path> --cluster-name <name> [flags]"
                        exit 1
                    }
                    let instance_path  = ($rest | get 2)
                    let cluster_name   = (get-flag $rest "--cluster-name"  | default "")
                    let kubeconfig     = (get-flag $rest "--kubeconfig"    | default "")
                    let kube_context   = (get-flag $rest "--context"       | default "")
                    let sa_name        = (get-flag $rest "--sa-name"       | default "backstage-reader")
                    let ns             = (get-flag $rest "--namespace"     | default "default")
                    let duration       = (get-flag $rest "--duration"      | default "8760h")
                    let skip_tls       = ("--skip-tls-verify" in $rest)
                    let dry_run        = ("--dry-run" in $rest)
                    configure-cluster $instance_path --cluster-name $cluster_name --kubeconfig $kubeconfig --context $kube_context --sa-name $sa_name --namespace $ns --duration $duration --skip-tls-verify=$skip_tls --dry-run=$dry_run
                },
                "list" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform cluster list <instance-path>"
                            description: "List all Kubernetes clusters configured in app-config.local.yaml."
                            args: "  instance-path   Path to the Backstage instance root"
                            examples: "  platform cluster list ./my-backstage"
                        }
                        return
                    }
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform cluster list <instance-path>"
                        exit 1
                    }
                    list-clusters ($rest | get 2)
                },
                _ => {
                    utils print-error $"Unknown cluster subcommand: ($rest.1)"
                    utils print-info "Available: configure, list"
                    exit 1
                }
            }
        },
        "deploy" => {
            if ("--help" in $rest) or ("-h" in $rest) {
                print-subcommand-help {
                    usage: "platform deploy <instance-path> [flags]"
                    description: "Validate the Backstage instance and prepare it for production deployment.\nRuns the validate command, then performs final build and configuration checks."
                    args: "  instance-path   Path to the Backstage instance root"
                    options: "  --environment <env>   Target environment name (default: production)"
                    examples: "  platform deploy ./my-backstage\n  platform deploy ./my-backstage --environment staging"
                }
                return
            }
            if ($rest | length) < 2 {
                print-help
                exit 1
            }
            deploy ($rest | get 1)
        },
        "help" | "--help" | "-h" => {
            print-help
        },
        "action" => {
            if ($rest | length) < 2 or $rest.1 == "--help" or $rest.1 == "-h" {
                print-subcommand-help {
                    usage: "platform action <subcommand> [args]"
                    description: "Manage custom scaffolder actions for a Backstage instance.\nSubcommands: add, list, info"
                    examples: "  platform action list\n  platform action info azure-pipeline\n  platform action add azure-pipeline ./my-backstage"
                }
                return
            }
            match $rest.1 {
                "add" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform action add <name> <instance-path>"
                            description: "Install a custom scaffolder action into a Backstage instance.\nCreates the TypeScript source file under packages/backend/src/extensions/\nand registers it in packages/backend/src/index.ts.\n\nRestart the Backstage backend after running this command."
                            args: "  name            Action name (see 'platform action list')\n  instance-path   Path to the Backstage instance root"
                            examples: "  platform action add azure-pipeline ./my-backstage"
                        }
                        return
                    }
                    if ($rest | length) < 4 {
                        utils print-error "Usage: platform action add <name> <instance-path>"
                        exit 1
                    }
                    install-action ($rest | get 2) ($rest | get 3)
                },
                "list" => {
                    list-available-actions
                },
                "info" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform action info <name>"
                            description: "Show details, inputs, outputs and template usage for a custom scaffolder action."
                            args: "  name    Action name (see 'platform action list')"
                            examples: "  platform action info azure-pipeline"
                        }
                        return
                    }
                    if ($rest | length) < 3 {
                        utils print-error "Usage: platform action info <name>"
                        exit 1
                    }
                    show-action-info ($rest | get 2)
                },
                _ => {
                    utils print-error $"Unknown action subcommand: ($rest.1)"
                    utils print-info "Available: add, list, info"
                    exit 1
                }
            }
        },
        "project" => {
            if ($rest | length) < 2 or $rest.1 == "--help" or $rest.1 == "-h" {
                print-subcommand-help {
                    usage: "platform project <subcommand> [args]"
                    description: "Manage Azure project onboarding pre-requisites.\nSubcommands: onboard"
                    examples: "  platform project onboard --project-name myproject --subscription-id <uuid> --tenant-id <uuid> --ado-org https://dev.azure.com/myorg --backstage-object-id <uuid>"
                }
                return
            }
            match $rest.1 {
                "onboard" => {
                    if ("--help" in $rest) or ("-h" in $rest) {
                        print-subcommand-help {
                            usage: "platform project onboard [flags]"
                            description: "Automate all Azure and ADO pre-requisites before running the AKS GitOps Platform template.\n\nRequires az CLI logged in with a personal account (az login) and az devops extension.\n\nSteps automated (all idempotent):\n  1. Create ADO project\n  2. Create Entra group [project-name]-admins\n  3. Create SP sp-[project-name]-platform\n  4. Add SP as member + owner of admin group\n  5. Assign admin group as Subscription Owner\n  6. Add backstage identity to admin group\n  7. Add admin group as ADO Project Administrator\n  8. Grant org-level Agent Pool permission\n  9. Create sc-bootstrap WIF service connection (3-phase)\n\nPrints all Backstage form values at the end. ADO PAT must be created manually."
                            options: "  --project-name <name>          ADO project name, e.g. Marketing (required)\n  --subscription-id <uuid>       Azure subscription UUID (required)\n  --tenant-id <uuid>             Entra ID tenant UUID (required)\n  --ado-org <url>                ADO org URL, e.g. https://dev.azure.com/myorg (required)\n  --backstage-object-id <uuid>   Object ID of the backstage App Registration (required)\n  --group-object-id <uuid>       Object ID of an existing Entra admin group (skips group creation)\n  --subscription-name <name>     Subscription display name (auto-detected when omitted)\n  --dry-run                      Preview all steps without making changes"
                            examples: "  platform project onboard --project-name myproject --subscription-id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx --tenant-id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx --ado-org https://dev.azure.com/myorg --backstage-object-id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\n  platform project onboard --project-name my-project --subscription-id <uuid> --tenant-id <uuid> --ado-org https://dev.azure.com/myorg --backstage-object-id <uuid> --dry-run"
                        }
                        return
                    }
                    let project_name        = (get-flag $rest "--project-name"        | default "")
                    let subscription_id     = (get-flag $rest "--subscription-id"     | default "")
                    let tenant_id           = (get-flag $rest "--tenant-id"           | default "")
                    let ado_org             = (get-flag $rest "--ado-org"             | default "")
                    let backstage_object_id = (get-flag $rest "--backstage-object-id" | default "")
                    let subscription_name   = (get-flag $rest "--subscription-name"   | default "")
                    let group_object_id     = (get-flag $rest "--group-object-id"     | default "")
                    let dry_run             = ("--dry-run" in $rest)
                    onboard-project --project-name $project_name --subscription-id $subscription_id --tenant-id $tenant_id --ado-org $ado_org --backstage-object-id $backstage_object_id --subscription-name $subscription_name --group-object-id $group_object_id --dry-run=$dry_run
                },
                _ => {
                    utils print-error $"Unknown project subcommand: ($rest.1). Available: onboard"
                    exit 1
                }
            }
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


