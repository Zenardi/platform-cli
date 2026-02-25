# entity catalog management module

use ../config.nu
use ./utils.nu

export def create-entity [
    name: string
    --type: string
    --owner: string = "platform-team"
    --system: string
    --description: string = ""
    --output: string
] {
    utils print-header $"Creating Entity: ($name)"
    
    let entity_type = ($type | default "component")
    
    let entity = match $entity_type {
        "component" => (create-component-entity $name $owner $system $description),
        "api" => (create-api-entity $name $owner $system $description),
        "resource" => (create-resource-entity $name $owner $system $description),
        "system" => (create-system-entity $name $owner $description),
        "group" => (create-group-entity $name),
        "user" => (create-user-entity $name),
        _ => {
            utils print-error $"Unknown entity type: ($entity_type)"
            exit 1
        }
    }
    
    let output_path = (
        if ($output | is-empty) {
            $"./catalog-entities/($name).yaml"
        } else {
            $output
        }
    )
    
    # Ensure parent directory exists
    let parent_dir = ($output_path | path dirname)
    utils create-directory $parent_dir
    
    $entity | save --force $output_path
    utils print-success $"Entity created at: ($output_path)"
}

def create-component-entity [
    name: string
    owner: string
    system: string
    description: string
] {
    $"
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ($name)
  description: ($description)
  annotations:
    github.com/project-slug: org/($name)
spec:
  type: service
  owner: ($owner)
  system: ($system)
  providesApis: []
  consumesApis: []
  dependsOn:
    - resource:default/($name)-database
"
}

def create-api-entity [
    name: string
    owner: string
    system: string
    description: string
] {
    $"
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: ($name)
  description: ($description)
spec:
  type: openapi
  owner: ($owner)
  lifecycle: production
  system: ($system)
  definition:
    $text: >
      openapi: 3.0.0
      info:
        title: ($name)
        version: 1.0.0
      paths: {}
"
}

def create-resource-entity [
    name: string
    owner: string
    system: string
    description: string
] {
    $"
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: ($name)
  description: ($description)
spec:
  type: database
  owner: ($owner)
  system: ($system)
"
}

def create-system-entity [
    name: string
    owner: string
    description: string
] {
    $"
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: ($name)
  description: ($description)
spec:
  owner: ($owner)
"
}

def create-group-entity [name: string] {
    $"
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: ($name)
spec:
  type: team
  profile:
    displayName: ($name)
  children: []
"
}

def create-user-entity [name: string] {
    $"
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: ($name)
spec:
  profile:
    displayName: ($name)
    email: ($name + "example.com")
  memberOf: 
    - default/($name)-group
"@
}

export def create-bulk-entities [instance_path: string, --template: string = "basic"] {
    utils print-header "Creating Bulk Entities from Template"
    
    let entities_dir = ($instance_path + "/catalog-entities")
    utils create-directory $entities_dir
    
    match $template {
        "basic" => {
            create-basic-entity-set $entities_dir
        },
        "microservices" => {
            create-microservices-entity-set $entities_dir
        },
        "team-structure" => {
            create-team-structure-entity-set $entities_dir
        },
        _ => {
            utils print-error $"Unknown template: ($template)"
            exit 1
        }
    }
}

def create-basic-entity-set [entities_dir: string] {
    # Platform team
    let team_entity = "
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: platform-team
spec:
  type: team
  profile:
    displayName: Platform Team
"
    $team_entity | save --force ($entities_dir + "/team-platform.yaml")
    
    # Infrastructure system
    let system_entity = "
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: internal-platform
  description: Internal Developer Platform
spec:
  owner: platform-team
  domain: infrastructure
"
    $system_entity | save --force ($entities_dir + "/system-platform.yaml")
    
    utils print-success "Basic entity set created"
}

def create-microservices-entity-set [entities_dir: string] {
    # Create user service
    let user_service = "
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: user-service
  description: User management service
spec:
  type: service
  owner: platform-team
  system: internal-platform
"
    $user_service | save --force ($entities_dir + "/component-user-service.yaml")
    
    # Create API service
    let api_service = "
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: api-gateway
  description: API Gateway service
spec:
  type: service
  owner: platform-team
  system: internal-platform
"
    $api_service | save --force ($entities_dir + "/component-api-gateway.yaml")
    
    utils print-success "Microservices entity set created"
}

def create-team-structure-entity-set [entities_dir: string] {
    # Platform team
    let platform_team = "
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: platform-team
spec:
  type: team
  profile:
    displayName: Platform Team
"
    $platform_team | save --force ($entities_dir + "/group-platform.yaml")
    
    # Engineering team
    let engineering_team = "
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: engineering-team
spec:
  type: team
  profile:
    displayName: Engineering Team
"
    $engineering_team | save --force ($entities_dir + "/group-engineering.yaml")
    
    # Operations team
    let ops_team = "
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: operations-team
spec:
  type: team
  profile:
    displayName: Operations Team
"
    $ops_team | save --force ($entities_dir + "/group-operations.yaml")
    
    utils print-success "Team structure entity set created"
}

export def validate-entity [entity_path: string] {
    if not ($entity_path | path exists) {
        utils print-error "Entity file not found: ($entity_path)"
        return false
    }
    
    try {
        let content = (open $entity_path)
        
        # Check required fields
        if not ("apiVersion" in $content and "kind" in $content and "metadata" in $content) {
            utils print-error "Entity missing required fields (apiVersion, kind, metadata)"
            return false
        }
        
        utils print-success "Entity is valid"
        true
    } catch {
        utils print-error "Entity validation failed"
        false
    }
}

export def list-entities [instance_path: string] {
    let entities_dir = ($instance_path + "/catalog-entities")
    
    if not ($entities_dir | path exists) {
        utils print-warning "No entities directory found"
        return []
    }
    
    glob ($entities_dir + "/*.yaml")
}
