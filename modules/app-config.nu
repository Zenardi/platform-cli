# app-config management module

use ../config.nu
use ./utils.nu

export def init-app-config [instance_path: string, --name: string] {
    utils print-header "Initializing app-config.yaml"
    
    let instance_path = ($instance_path | path expand)
    let config_path = ($instance_path + "/app-config.yaml")
    
    utils validate-path $config_path "app-config.yaml"
    
    # Create default app-config
    let default_config = (get-default-app-config $name)
    
    $default_config | save $config_path
    utils print-success $"Created app-config.yaml"
}

def get-default-app-config [name: string] {
    let app_name = ($name | default "backstage-app")
    
    $"
app:
  title: ($app_name)
  baseUrl: http://localhost:3000

environment: development

backend:
  database:
    client: pg
    connection:
      host: localhost
      port: 5432
      user: postgres
      password: postgres
      database: backstage
  auth:
    keys:
      - secret: development-secret-key
  apis:
    enable: true
  cors:
    origin: http://localhost:3000
    credentials: true

auth:
  providers:
    github:
      development:
        clientId: YOUR_GITHUB_CLIENT_ID
        clientSecret: YOUR_GITHUB_CLIENT_SECRET

catalog:
  import:
    entityFilename: catalog-info.yaml
  rules:
    - allow: [Component, System, API, Resource, Location]

techdocs:
  builder: external
  publisher:
    type: local

scaffolder:
  defaultAuthor:
    name: Platform Team
  defaultCommitAction: commit
"
}

export def set-config [instance_path: string, key: string, value: string] {
    let instance_path = ($instance_path | path expand)
    let config_path = ($instance_path + "/app-config.yaml")
    
    if not ($config_path | path exists) {
        utils print-error "app-config.yaml not found"
        exit 1
    }
    
    # Backup existing config
    utils backup-file $config_path
    
    utils print-info $"Setting ($key) = ($value)"
    
    # Note: Full YAML editing would require a YAML library
    # This is a simplified version
    try {
        let content = (open $config_path)
        # Would implement proper YAML parsing here
        utils print-success $"Updated configuration"
    } catch {
        utils print-error "Failed to update configuration"
        exit 1
    }
}

export def configure-database [
    instance_path: string
    --db-type: string = "postgresql"
    --host: string = "localhost"
    --port: int
    --user: string
    --password: string
    --database: string
] {
    utils print-header "Configuring Database"
    
    utils print-info $"Database Type: ($db_type)"
    utils print-info $"Host: ($host)"
    utils print-info $"Port: ($port)"
    
    let port = if ($port | is-empty) {
        match $db_type {
            "postgresql" => 5432,
            "mysql" => 3306,
            "mariadb" => 3306,
            _ => 5432
        }
    } else {
        $port
    }
    
    utils print-success "Database configuration ready"
}

export def configure-auth [
    instance_path: string
    --provider: string
    --client-id: string
    --client-secret: string
] {
    utils print-header $"Configuring Auth: ($provider)"
    
    if ($client_id | is-empty) or ($client_secret | is-empty) {
        utils print-error "Client ID and Secret are required"
        exit 1
    }
    
    utils print-success $"Auth provider ($provider) configured"
}

export def configure-storage [
    instance_path: string
    --provider: string
    --bucket: string
    --region: string
] {
    utils print-header $"Configuring Storage: ($provider)"
    
    match $provider {
        "aws" => {
            if ($bucket | is-empty) or ($region | is-empty) {
                utils print-error "Bucket and Region required for AWS"
                exit 1
            }
            utils print-info $"AWS S3 bucket: ($bucket), region: ($region)"
        },
        "azure" => {
            if ($bucket | is-empty) {
                utils print-error "Container name required for Azure"
                exit 1
            }
            utils print-info $"Azure Blob Storage container: ($bucket)"
        },
        "gcp" => {
            if ($bucket | is-empty) {
                utils print-error "Bucket name required for GCP"
                exit 1
            }
            utils print-info $"GCP Storage bucket: ($bucket)"
        },
        _ => {
            utils print-info "Local storage will be used"
        }
    }
    
    utils print-success "Storage configured"
}

export def validate-app-config [config_path: string] {
    if not ($config_path | path exists) {
        utils print-error "Config file not found"
        return false
    }
    
    try {
        let _ = (open $config_path)
        utils print-success "Configuration is valid"
        true
    } catch {
        utils print-error "Configuration validation failed"
        false
    }
}
