# onboarding.nu — AKS GitOps Platform project onboarding automation
#
# Automates all Azure and ADO pre-requisite steps a developer must complete
# before running the AKS GitOps Platform template in Backstage.
#
# Prerequisites (checked at runtime):
#   - az CLI installed and logged in with a personal account (az login)
#   - az devops extension  (az extension add --name azure-devops)
#
# The developer's own credentials are used — no service principal required.

use ./utils.nu

# ADO resource ID used for az rest authentication against dev.azure.com / vssps.dev.azure.com
const ADO_RESOURCE_ID = "499b84ac-1321-427f-aa17-267ca6975798"

# ── Pure functions (unit-testable, no I/O) ────────────────────────────────────

# Detect the current operating system.
# Returns "windows", "macos", or "linux".
export def detect-os []: nothing -> string {
    let os = ($env | get -o OS | default "" | str downcase)
    let uname_s = (try { ^uname -s | str trim | str downcase } catch { "" })
    if ($os | str contains "windows") or ($os | str contains "windows_nt") {
        "windows"
    } else if $uname_s == "darwin" {
        "macos"
    } else {
        "linux"
    }
}

# Return OS-specific installation instructions for the Azure CLI.
# Pure function — no side effects.
export def format-az-install-instructions [os: string]: nothing -> string {
    match $os {
        "windows" => {
            "  Windows — choose one:\n    • winget:      winget install -e --id Microsoft.AzureCLI\n    • Chocolatey:  choco install azure-cli\n    • MSI:         https://aka.ms/installazurecliwindows"
        }
        "macos" => {
            "  macOS — choose one:\n    • Homebrew:    brew update && brew install azure-cli\n    • Script:      curl -L https://aka.ms/InstallAzureCli | bash"
        }
        _ => {
            "  Linux — choose one:\n    • Script:      curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash   (Debian/Ubuntu)\n    • dnf:         sudo dnf install azure-cli                              (RHEL/Fedora)\n    • zypper:      sudo zypper install azure-cli                           (SLES)\n    • Full guide:  https://docs.microsoft.com/cli/azure/install-azure-cli-linux"
        }
    }
}

# Validate that a project name is kebab-case.
# Rules: lowercase letters and digits only; hyphens allowed between segments;
# must start with a letter; no consecutive or trailing hyphens.
# Returns true when valid, false otherwise.
export def validate-project-name [name: string]: nothing -> bool {
    # ADO project names: letters, digits, spaces, hyphens, periods, underscores.
    # Must not be empty, start/end with a period, or contain reserved chars.
    let trimmed = ($name | str trim)
    (($trimmed | str length) > 0) and (not ($trimmed | str starts-with ".")) and (not ($trimmed | str ends-with ".")) and (not ($trimmed =~ '[\\/:*?"<>|]'))
}

# Build the JSON body for an ADO Workload Identity Federation service endpoint.
# Used in both Phase 1 (create) and Phase 3 (verify) of the sc-bootstrap setup.
export def build-wif-endpoint-body [
    sc_name: string       # Service connection name (e.g. "sc-bootstrap")
    sp_app_id: string     # SP App (client) ID
    sub_id: string        # Azure subscription ID
    sub_name: string      # Azure subscription display name
    tenant_id: string     # Entra ID tenant ID
    project_id: string    # ADO project ID (UUID)
    project_name: string  # ADO project name
]: nothing -> string {
    {
        name: $sc_name
        type: "AzureRM"
        url: "https://management.azure.com/"
        authorization: {
            scheme: "WorkloadIdentityFederation"
            parameters: {
                serviceprincipalid: $sp_app_id
                tenantid: $tenant_id
            }
        }
        data: {
            subscriptionId: $sub_id
            subscriptionName: $sub_name
            environment: "AzureCloud"
            creationMode: "Manual"
        }
        serviceEndpointProjectReferences: [
            {
                description: ""
                name: $sc_name
                projectReference: {
                    id: $project_id
                    name: $project_name
                }
            }
        ]
    } | to json --raw
}

# Build the JSON body for an Entra ID federated credential.
# Used in Phase 2 of the sc-bootstrap setup to link ADO WIF to the SP.
export def build-federated-credential-body [
    issuer: string   # WIF issuer URL returned by ADO after Phase 1
    subject: string  # WIF subject returned by ADO after Phase 1
]: nothing -> string {
    {
        name: "ado-sc-bootstrap"
        issuer: $issuer
        subject: $subject
        audiences: ["api://AzureADTokenExchange"]
    } | to json --raw
}

# Format the final summary block printed after all steps complete.
# Returns a multi-line string ready to print to the terminal.
export def format-onboarding-summary [
    project_name: string    # ADO project / kebab-case project name
    group_object_id: string # Entra admin group Object ID
    sub_id: string          # Azure subscription ID
    tenant_id: string       # Entra tenant ID
]: nothing -> string {
    [
        ""
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "  Onboarding Complete — Backstage Form Values"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        $"  ADO Project Name        : ($project_name)"
        $"  Admin Group Object ID   : ($group_object_id)"
        "  Service Connection Name : sc-bootstrap"
        $"  Subscription ID         : ($sub_id)"
        $"  Tenant ID               : ($tenant_id)"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ""
        "⚠  Manual step required — create an ADO Personal Access Token:"
        "   Go to ADO → User Settings → Personal Access Tokens → New Token"
        "   Required scopes:"
        "     • Code: Read"
        "     • Agent Pools: Read & Manage"
        "     • Service Connections: Read, query & manage"
        "     • Variable Groups: Read, create & manage"
        "   Enter this token as 'ArgoCD ADO PAT' in the Backstage form."
        ""
    ] | str join "\n"
}

# ── Orchestration (calls Azure / ADO CLIs — not unit-testable) ────────────────

# Ensure Azure CLI is installed. If not: show OS-specific install instructions,
# ask user whether to install automatically or cancel, then install or exit.
def ensure-az-installed [] {
    if (which az | is-not-empty) { return }

    let os = (detect-os)
    utils print-error "Azure CLI (az) is not installed — it is required for this command."
    print ""
    print "Installation instructions:"
    print (format-az-install-instructions $os)
    print ""

    if $os == "windows" {
        # On Windows, automated install requires winget or an elevated shell — guide only
        utils print-info "Please install Azure CLI using one of the methods above, then re-run this command."
        exit 1
    }

    let answer = (utils prompt-confirm "Would you like platform-cli to install Azure CLI automatically?")
    if not $answer {
        utils print-info "Please install Azure CLI manually, then re-run this command."
        exit 1
    }

    utils print-info $"Installing Azure CLI for ($os)..."
    if $os == "macos" {
        if (which brew | is-not-empty) {
            ^brew update
            ^brew install azure-cli
        } else {
            utils print-info "Homebrew not found — using install script..."
            ^bash -c "curl -L https://aka.ms/InstallAzureCli | bash"
        }
    } else {
        # Linux: try apt-based script first, fall back to guide
        let apt_available = (which apt-get | is-not-empty)
        if $apt_available {
            ^bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
        } else {
            utils print-error "Automatic install is only supported on Debian/Ubuntu. Please install manually:"
            print (format-az-install-instructions "linux")
            exit 1
        }
    }

    if (which az | is-not-empty) {
        utils print-success "Azure CLI installed successfully."
    } else {
        utils print-error "Azure CLI installation failed. Please install it manually and re-run this command."
        exit 1
    }
}

# Ensure az devops extension is installed.
# If not: prompt user to install automatically or cancel.
def ensure-az-devops-installed [] {
    let installed = try {
        ^az extension show --name azure-devops --output json | from json | get -o name | default "" | is-not-empty
    } catch { false }

    if $installed { return }

    utils print-warning "The 'azure-devops' az extension is not installed."
    let answer = (utils prompt-confirm "Would you like platform-cli to install it automatically? (az extension add --name azure-devops)")
    if not $answer {
        utils print-info "Please run: az extension add --name azure-devops"
        utils print-info "Then re-run this command."
        exit 1
    }

    utils print-info "Installing azure-devops extension..."
    ^az extension add --name azure-devops
    utils print-success "azure-devops extension installed."
}

# Ensure the developer is logged in to Azure CLI with a personal \(interactive\) account.
# If not logged in, or logged in as a service principal, prompt for interactive login.
def ensure-az-logged-in [] {
    let account = try {
        ^az account show --output json | from json
    } catch { null }

    # Not logged in at all
    if ($account == null) {
        utils print-warning "You are not logged in to Azure CLI."
        do-interactive-az-login
        return
    }

    # Detect SP / managed identity sessions — user.type is "servicePrincipal" or "ManagedIdentity"
    let user_type = ($account | get -o user.type | default "user")
    let user_name = ($account | get -o user.name | default "unknown")

    if ($user_type != "user") {
        utils print-warning $"Azure CLI is currently logged in as a service principal / managed identity: ($user_name)"
        utils print-warning "platform project onboard requires your personal Azure account."
        print ""
        let answer = (utils prompt-confirm "Re-login with your personal account now?")
        if not $answer {
            utils print-info "Please run 'az login' manually with your personal account, then re-run this command."
            exit 1
        }
        do-interactive-az-login
        return
    }

    utils print-success $"Logged in as: ($user_name)"
}

# Run az login interactively and verify success.
def do-interactive-az-login [] {
    utils print-info "Running 'az login' to authenticate..."
    print ""
    try {
        ^az login
    } catch {
        utils print-error "Login failed. Please run 'az login' manually and re-run this command."
        exit 1
    }

    let ok = try {
        let acc = (^az account show --output json | from json)
        let t = ($acc | get -o user.type | default "user")
        ($t == "user")
    } catch { false }

    if not $ok {
        utils print-error "Login did not complete with a personal account. Please run 'az login' manually."
        exit 1
    }
    utils print-success "Logged in to Azure CLI."
}

# Ensure the active subscription matches the requested one.
# Shows the current subscription and prompts to switch if different,
# or confirms if it's already correct.
def ensure-correct-subscription [subscription_id: string] {
    let current = try {
        ^az account show --output json | from json
    } catch {
        utils print-error "Cannot read current subscription — are you logged in?"
        exit 1
    }

    let current_id   = ($current | get -o id   | default "")
    let current_name = ($current | get -o name | default "(unknown)")

    if ($current_id | str downcase) == ($subscription_id | str downcase) {
        utils print-success $"Active subscription: ($current_name) [($current_id)]"
        return
    }

    utils print-warning $"Current active subscription: ($current_name) [($current_id)]"
    utils print-warning $"Required subscription ID:    ($subscription_id)"
    print ""
    let answer = (utils prompt-confirm $"Switch active subscription to ($subscription_id)?")
    if not $answer {
        utils print-info "Please run: az account set --subscription <subscription-id>"
        utils print-info "Then re-run this command."
        exit 1
    }

    try {
        ^az account set --subscription $subscription_id
        let new_name = try {
            ^az account show --output json | from json | get name
        } catch { $subscription_id }
        utils print-success $"Switched to subscription: ($new_name) [($subscription_id)]"
    } catch {
        utils print-error $"Failed to switch subscription. Please run: az account set --subscription ($subscription_id)"
        exit 1
    }
}

# Onboard a new project: automate all Azure and ADO pre-requisites required
# before running the AKS GitOps Platform template in Backstage.
#
# The developer's own az CLI credentials are used throughout. Ensure you are
# logged in with 'az login' using a personal account that has:
#   - Azure subscription Owner/Contributor rights
#   - ADO Organization Administrator access
#
# Steps automated:
#   1. Create ADO project (idempotent — skips if already exists)
#   2. Create Entra group [project-name]-admins
#   3. Create SP sp-[project-name]-platform
#   4. Add SP as member + owner of the admin group
#   5. Assign admin group as Subscription Owner
#   6. Add the backstage identity to the admin group
#   7. Add admin group as ADO Project Administrator (Graph API)
#   8. Grant org-level Agent Pool permission to admin group
#   9. Create sc-bootstrap WIF service connection (3-phase: create → fedcred → verify)
#
# Step not automated (PAT): printed as a clear manual reminder at the end.
export def onboard-project [
    --project-name: string              # ADO project name (letters, digits, spaces, hyphens allowed)
    --subscription-id: string           # Azure subscription UUID
    --tenant-id: string                 # Entra ID tenant UUID
    --ado-org: string                   # ADO org URL (e.g. https://dev.azure.com/myorg)
    --backstage-object-id: string       # Object ID of the 'backstage' App Registration
    --subscription-name: string = ""    # Subscription display name (auto-detected when empty)
    --group-object-id: string = ""      # Object ID of an existing Entra admin group (skips group creation)
    --ado-pat: string = ""              # ADO Personal Access Token (required for personal Microsoft accounts)
    --dry-run = false                   # Preview all steps without making any changes
] {
    # ── Pre-flight: ensure required tools are installed and credentials valid ──
    if $dry_run {
        utils print-warning "DRY-RUN mode — no changes will be made"
        utils print-info "Skipping tool installation and login checks in dry-run mode"
    } else {
        ensure-az-installed
        ensure-az-logged-in
        ensure-correct-subscription $subscription_id
        ensure-az-devops-installed
    }

    # ── Configure ADO PAT if provided ─────────────────────────────────────────
    # az devops respects AZURE_DEVOPS_EXT_PAT for authentication.
    # Required for personal Microsoft accounts \(live.com\) where the Bearer token
    # obtained by az login is not accepted by ADO's authorization layer.
    if ($ado_pat | is-not-empty) {
        $env.AZURE_DEVOPS_EXT_PAT = $ado_pat
        utils print-success "ADO PAT configured for authentication"
    }

    # ── Validate inputs ────────────────────────────────────────────────────────
    utils print-header "Input Validation"

    if ($project_name | is-empty) {
        utils print-error "--project-name is required"
        exit 1
    }
    if not (validate-project-name $project_name) {
        utils print-error $"Invalid project name '($project_name)'. Must not be empty, start/end with a period, or contain \\ / : * ? \" < > |"
        exit 1
    }
    for param in [
        ["--subscription-id" $subscription_id]
        ["--tenant-id"       $tenant_id]
        ["--ado-org"         $ado_org]
        ["--backstage-object-id" $backstage_object_id]
    ] {
        if ($param.1 | is-empty) {
            utils print-error $"($param.0) is required"
            exit 1
        }
    }

    let group_name = $"($project_name | str downcase | str replace --all ' ' '-')-admins"
    let sp_name    = $"sp-($project_name | str downcase | str replace --all ' ' '-')-platform"
    let org_name   = ($ado_org | str replace "https://dev.azure.com/" "" | str trim --char "/")

    utils print-info $"Project       : ($project_name)"
    utils print-info $"Admin group   : ($group_name)"
    utils print-info $"SP name       : ($sp_name)"
    utils print-info $"ADO org       : ($org_name)"
    utils print-success "Inputs valid"

    # ── Resolve subscription name ──────────────────────────────────────────────
    let resolved_sub_name = if ($subscription_name | is-not-empty) {
        $subscription_name
    } else if $dry_run {
        "dry-run-subscription-name"
    } else {
        try {
            ^az account show --subscription $subscription_id --output json | from json | get name
        } catch {
            utils print-error $"Cannot resolve subscription name for ($subscription_id). Pass --subscription-name to skip auto-detection."
            exit 1
        }
    }
    utils print-info $"Subscription  : ($resolved_sub_name)"

    # ── Step 1: Create ADO project ─────────────────────────────────────────────
    utils print-header $"Step 1 — ADO Project: ($project_name)"

    let existing_project = try {
        ^az devops project show --project $project_name --org $ado_org --output json | from json
    } catch { null }

    let project_id = if ($existing_project != null) {
        utils print-info $"Project '($project_name)' already exists — skipping creation"
        $existing_project.id
    } else if $dry_run {
        utils print-info $"Would create ADO project: ($project_name)"
        "dry-run-project-id"
    } else {
        let created = try {
            ^az devops project create --name $project_name --org $ado_org --output json | from json
        } catch {
            utils print-error $"Failed to create ADO project '($project_name)'"
            exit 1
        }
        utils print-success $"ADO project '($project_name)' created"
        $created.id
    }

    # ── Step 2: Create Entra admin group ───────────────────────────────────────
    utils print-header $"Step 2 — Entra Group: ($group_name)"

    # Only look up the group if the caller didn't supply the object ID directly.
    let existing_group_lookup = if ($group_object_id | is-empty) {
        try { ^az ad group show --group $group_name --output json | from json } catch { null }
    } else { null }

    let group_object_id = if ($group_object_id | is-not-empty) {
        utils print-info $"--group-object-id provided — skipping group creation, using ($group_object_id)"
        $group_object_id
    } else if ($existing_group_lookup != null) {
        utils print-info $"Group '($group_name)' already exists — skipping creation"
        $existing_group_lookup.id
    } else if $dry_run {
        utils print-info $"Would create Entra group: ($group_name)"
        "dry-run-group-id"
    } else {
        let created = try {
            ^az ad group create --display-name $group_name --mail-nickname $group_name --output json | from json
        } catch {
            utils print-error $"Failed to create group '($group_name)'"
            exit 1
        }
        utils print-success $"Group '($group_name)' created \(Object ID: ($created.id)\)"
        $created.id
    }

    # ── Step 3: Create Service Principal ──────────────────────────────────────
    utils print-header $"Step 3 — Service Principal: ($sp_name)"

    let existing_sp_list = try {
        ^az ad sp list --display-name $sp_name --output json | from json
    } catch { [] }
    let existing_sp = ($existing_sp_list | get 0?)

    let sp_app_id = if ($existing_sp != null) {
        utils print-info $"SP '($sp_name)' already exists — skipping creation"
        $existing_sp.appId
    } else if $dry_run {
        utils print-info $"Would create SP: ($sp_name)"
        "dry-run-sp-app-id"
    } else {
        let created = try {
            ^az ad sp create-for-rbac --name $sp_name --skip-assignment --output json | from json
        } catch {
            utils print-error $"Failed to create SP '($sp_name)'"
            exit 1
        }
        utils print-success $"SP '($sp_name)' created \(appId: ($created.appId)\)"
        $created.appId
    }

    # SP object ID (used for group membership — differs from appId)
    let sp_object_id = if $dry_run {
        "dry-run-sp-object-id"
    } else {
        try {
            ^az ad sp show --id $sp_app_id --output json | from json | get id
        } catch {
            utils print-error "Failed to resolve SP object ID"
            exit 1
        }
    }

    # ── Step 4: Add SP as group member + owner ─────────────────────────────────
    utils print-header "Step 4 — SP Membership in Admin Group"

    if $dry_run {
        utils print-info $"Would add ($sp_name) as member of ($group_name)"
        utils print-info $"Would add ($sp_name) as owner of ($group_name)"
    } else {
        let is_member = try {
            ^az ad group member check --group $group_object_id --member-id $sp_object_id --output json | from json | get value
        } catch { false }

        if not $is_member {
            ^az ad group member add --group $group_object_id --member-id $sp_object_id
            utils print-success $"($sp_name) added as member"
        } else {
            utils print-info $"($sp_name) already a member"
        }

        try {
            ^az ad group owner add --group $group_object_id --owner-object-id $sp_object_id
            utils print-success $"($sp_name) added as owner"
        } catch {
            utils print-info $"($sp_name) may already be an owner"
        }
    }

    # ── Step 5: Assign admin group as Subscription Owner ──────────────────────
    utils print-header "Step 5 — Subscription Owner Role"
    let sub_scope = $"/subscriptions/($subscription_id)"

    if $dry_run {
        utils print-info $"Would assign ($group_name) as Owner on ($sub_scope)"
    } else {
        let existing_assignments = try {
            ^az role assignment list --assignee $group_object_id --role Owner --scope $sub_scope --output json | from json | length
        } catch { 0 }

        if $existing_assignments > 0 {
            utils print-info $"($group_name) already has Owner on subscription — skipping"
        } else {
            # AAD group replication can take 10-60 s after creation.
            # Retry up to 6 times with 15 s backoff before giving up.
            mut assigned = false
            mut attempt  = 0
            while (not $assigned) and ($attempt < 6) {
                $attempt = $attempt + 1
                let result = try {
                    ^az role assignment create --assignee $group_object_id --assignee-principal-type Group --role Owner --scope $sub_scope --output none
                    true
                } catch { false }

                if $result {
                    $assigned = true
                    utils print-success $"($group_name) assigned as Subscription Owner"
                } else if $attempt < 6 {
                    utils print-info $"Role assignment attempt ($attempt)/6 failed \(AAD replication delay\) — retrying in 15 s..."
                    sleep 15sec
                }
            }

            if not $assigned {
                utils print-error $"Failed to assign Subscription Owner role after 6 attempts. Check that ($group_object_id) exists in the directory."
                exit 1
            }
        }
    }

    # ── Step 6: Add backstage to admin group ───────────────────────────────────
    utils print-header "Step 6 — backstage in Admin Group"

    if $dry_run {
        utils print-info $"Would add backstage \(($backstage_object_id)\) as member of ($group_name)"
    } else {
        # Entra groups only accept Service Principal object IDs as members.
        # The --backstage-object-id flag holds the App Registration object ID,
        # which is a different object from the associated Service Principal.
        # Resolve the SP object ID via the app's appId (client ID).
        let backstage_sp_id = try {
            let app_id = (^az ad app show --id $backstage_object_id --query appId --output tsv | str trim)
            ^az ad sp show --id $app_id --query id --output tsv | str trim
        } catch {
            # If lookup fails, the caller may have already passed a SP object ID directly
            $backstage_object_id
        }

        if ($backstage_sp_id | is-empty) or ($backstage_sp_id == $backstage_object_id) {
            utils print-warning $"Could not resolve SP object ID for backstage app \(($backstage_object_id)\) — using value as-is"
        } else {
            utils print-info $"Resolved backstage SP object ID: ($backstage_sp_id)"
        }

        let is_member = try {
            ^az ad group member check --group $group_object_id --member-id $backstage_sp_id --output json | from json | get value
        } catch { false }

        if not $is_member {
            try {
                ^az ad group member add --group $group_object_id --member-id $backstage_sp_id
                utils print-success "backstage added to admin group"
            } catch {
                utils print-error $"Failed to add backstage to admin group. Verify that ($backstage_object_id) is a valid App Registration or Service Principal Object ID."
                exit 1
            }
        } else {
            utils print-info "backstage already in admin group"
        }
    }

    # ── Step 7: Add group as ADO Project Administrator (Graph API) ────────────
    utils print-header "Step 7 — ADO Project Administrator"

    # Holds the ADO subject descriptor for the admin group; populated in step 7,
    # consumed in step 8 for pool role assignment.
    mut group_ado_descriptor = ""

    if $dry_run {
        utils print-info $"Would add ($group_name) as ADO Project Administrator in ($project_name)"
    } else {
        # Get the ADO graph descriptor for the project (needed to scope group lookup)
        let desc_url = ($"https://vssps.dev.azure.com/($org_name)/_apis/graph/descriptors/($project_id)" + "?api-version=7.1-preview.1")
        let project_descriptor = try {
            ^az rest --method GET --url $desc_url --resource $ADO_RESOURCE_ID --output json | from json | get value
        } catch { "" }

        if ($project_descriptor | is-empty) {
            utils print-warning "Could not resolve ADO project descriptor — skipping Step 7"
            utils print-warning "Add manually: ADO → Project Settings → Permissions → Project Administrators → Members → Add group"
        } else {
            # Find Project Administrators group in this project scope
            let groups_url = ($"https://vssps.dev.azure.com/($org_name)/_apis/graph/groups" + $"?scopeDescriptor=($project_descriptor)" + "&api-version=7.1-preview.1")
            let groups_response = try {
                ^az rest --method GET --url $groups_url --resource $ADO_RESOURCE_ID --output json | from json
            } catch { {value: []} }

            let proj_admin_group = (
                $groups_response.value
                | where { |g| ($g.principalName | default "" | str ends-with "\\Project Administrators") }
                | get 0?
            )

            if ($proj_admin_group == null) {
                utils print-warning "Could not find Project Administrators group — add group manually in ADO"
            } else {
                # Materialize the Entra group in ADO to get its descriptor,
                # and simultaneously add it as a member of Project Administrators.
                let materialize_url = ($"https://vssps.dev.azure.com/($org_name)/_apis/graph/groups" + $"?groupDescriptors=($proj_admin_group.descriptor)" + "&api-version=7.1-preview.1")
                let entra_group_in_ado = try {
                    ^az rest --method POST --url $materialize_url --resource $ADO_RESOURCE_ID --headers "Content-Type=application/json" --body $"{\"originId\": \"($group_object_id)\"}" --output json | from json
                } catch { null }

                if ($entra_group_in_ado == null) {
                    utils print-warning "Could not materialize Entra group in ADO (may already exist)"
                    utils print-warning "Add manually: ADO → Project Settings → Permissions → Project Administrators → Members"
                    # Fallback: look up existing ADO group by originId
                    let all_aad_groups = try {
                        ^az rest --method GET --url $"https://vssps.dev.azure.com/($org_name)/_apis/graph/groups?subjectTypes=aadgp&api-version=7.1-preview.1" --resource $ADO_RESOURCE_ID --output json | from json | get value
                    } catch { [] }
                    let found_group = ($all_aad_groups | where { |g| ($g | get -o originId | default "") == $group_object_id } | get 0?)
                    if ($found_group != null) {
                        $group_ado_descriptor = $found_group.descriptor
                        utils print-info $"Resolved existing ADO descriptor for ($group_name)"
                    }
                } else {
                    let member_descriptor = $entra_group_in_ado.descriptor
                    $group_ado_descriptor = $member_descriptor
                    # Add membership explicitly (materialization may or may not add it)
                    let membership_url = ($"https://vssps.dev.azure.com/($org_name)/_apis/graph/memberships/($member_descriptor)/($proj_admin_group.descriptor)" + "?api-version=7.1-preview.1")
                    try {
                        ^az rest --method PUT --url $membership_url --resource $ADO_RESOURCE_ID --output none
                        utils print-success $"($group_name) added as ADO Project Administrator"
                    } catch {
                        utils print-info $"($group_name) may already be a Project Administrator"
                    }
                }
            }
        }
    }

    # ── Step 8: Org-level Agent Pool permission ────────────────────────────────
    utils print-header "Step 8 — Org-Level Agent Pool Permission"

    if $dry_run {
        utils print-info $"Would grant ($group_name) Agent Pool User permission at org level"
    } else {
        # Resolve descriptor if step 7 didn't populate it (e.g. dry_run path above skipped step 7)
        mut pool_descriptor = $group_ado_descriptor
        if ($pool_descriptor | is-empty) {
            let all_aad_groups = try {
                ^az rest --method GET --url $"https://vssps.dev.azure.com/($org_name)/_apis/graph/groups?subjectTypes=aadgp&api-version=7.1-preview.1" --resource $ADO_RESOURCE_ID --output json | from json | get value
            } catch { [] }
            let found_group = ($all_aad_groups | where { |g| ($g | get -o originId | default "") == $group_object_id } | get 0?)
            if ($found_group != null) {
                $pool_descriptor = $found_group.descriptor
            }
        }

        if ($pool_descriptor | is-empty) {
            utils print-warning "Could not resolve ADO descriptor for admin group — grant pool permission manually"
            utils print-warning "ADO → Organisation Settings → Agent Pools → <pool> → Security → Add group as User"
        } else {
            let pools_url = $"https://dev.azure.com/($org_name)/_apis/distributedtask/pools?api-version=7.1"
            let pools = try {
                ^az rest --method GET --url $pools_url --resource $ADO_RESOURCE_ID --output json | from json | get value
            } catch { [] }

            if ($pools | is-empty) {
                utils print-warning "Could not retrieve agent pools — grant permission manually"
                utils print-warning "ADO → Organisation Settings → Agent Pools → <pool> → Security → Add group as User"
            } else {
                let role_name = "User"

                # Convert Graph subject descriptor → Identity storage key (GUID).
                # The Security Roles API expects an identity storage key, not a Graph descriptor.
                # Copy mut to let so it can be captured in the catch closure.
                let resolved_descriptor = $pool_descriptor
                let identity_url = $"https://vssps.dev.azure.com/($org_name)/_apis/identities?subjectDescriptors=($resolved_descriptor)&api-version=7.1-preview.1"
                let identity_id = try {
                    let ident = (^az rest --method GET --url $identity_url --resource $ADO_RESOURCE_ID --output json | from json | get value | first)
                    $ident.id
                } catch { $resolved_descriptor }

                utils print-info $"Using role '($role_name)' for agent pool assignment"

                mut granted = 0
                for pool in $pools {
                    let role_url = $"https://dev.azure.com/($org_name)/_apis/securityroles/scopes/distributedtask.agentpoolrole/roleassignments/resources/($pool.id)?api-version=7.1-preview.1"
                    try {
                        ^az rest --method PUT --url $role_url --resource $ADO_RESOURCE_ID --headers "Content-Type=application/json" --body $"[{\"roleName\": \"($role_name)\", \"userId\": \"($identity_id)\"}]" --output none
                        $granted = ($granted + 1)
                    } catch { }
                }
                if $granted > 0 {
                    utils print-success $"Agent Pool ($role_name) role granted on ($granted) org pool\(s\)"
                } else {
                    utils print-warning "Could not grant pool permissions automatically"
                    utils print-warning "ADO → Organisation Settings → Agent Pools → <pool> → Security → Add group as User"
                }
            }
        }
    }

    # ── Step 9: Create sc-bootstrap WIF service connection (3-phase) ──────────
    utils print-header "Step 9 — WIF Service Connection (sc-bootstrap)"

    if $dry_run {
        utils print-info "Would create WIF service connection sc-bootstrap:"
        utils print-info "  Phase 1 — POST /serviceendpoint/endpoints"
        utils print-info "  Phase 2 — az ad app federated-credential create"
        utils print-info "  Phase 3 — PUT /serviceendpoint/endpoints/{id} (verify)"
    } else {
        # Check if service connection already exists
        let existing_sc_list = try {
            ^az devops service-endpoint list --project $project_name --org $ado_org --output json | from json
        } catch { [] }
        let existing_sc = ($existing_sc_list | where { |e| ($e | get -o name | default "") == "sc-bootstrap" } | get 0?)

        if ($existing_sc != null) {
            utils print-info "Service connection sc-bootstrap already exists — skipping"
        } else {
            # Phase 1: Create endpoint
            let endpoint_body = (build-wif-endpoint-body "sc-bootstrap" $sp_app_id $subscription_id $resolved_sub_name $tenant_id $project_id $project_name)
            let endpoints_url = ($"https://dev.azure.com/($org_name)/($project_name)/_apis/serviceendpoint/endpoints" + "?api-version=7.1")

            let endpoint = try {
                ^az rest --method POST --url $endpoints_url --resource $ADO_RESOURCE_ID --headers "Content-Type=application/json" --body $endpoint_body --output json | from json
            } catch {
                utils print-error "Failed to create service endpoint (Phase 1)"
                exit 1
            }

            let endpoint_id = $endpoint.id
            let issuer      = ($endpoint | get -o authorization.parameters.workloadIdentityFederationIssuer | default "")
            let subject     = ($endpoint | get -o authorization.parameters.workloadIdentityFederationSubject | default "")

            if ($issuer | is-empty) or ($subject | is-empty) {
                utils print-error "ADO did not return WIF issuer/subject — cannot create federated credential"
                exit 1
            }

            utils print-success $"Phase 1 done \(endpoint id: ($endpoint_id)\)"
            utils print-info $"Issuer:  ($issuer)"
            utils print-info $"Subject: ($subject)"

            # Phase 2: Create federated credential in Entra on the SP's Application registration
            let app_object_id = try {
                ^az ad app show --id $sp_app_id --output json | from json | get id
            } catch {
                utils print-error "Failed to get Application object ID for federated credential"
                exit 1
            }

            let fed_cred_body = (build-federated-credential-body $issuer $subject)
            try {
                ^az ad app federated-credential create --id $app_object_id --parameters $fed_cred_body --output none
                utils print-success "Phase 2 done (federated credential created)"
            } catch {
                utils print-error "Failed to create federated credential (Phase 2)"
                exit 1
            }

            # Phase 3: Verify the endpoint
            let verify_body = ($endpoint | upsert isReady true | to json --raw)
            let verify_url = ($"https://dev.azure.com/($org_name)/($project_name)/_apis/serviceendpoint/endpoints/($endpoint_id)" + "?api-version=7.1")
            try {
                ^az rest --method PUT --url $verify_url --resource $ADO_RESOURCE_ID --headers "Content-Type=application/json" --body $verify_body --output none
                utils print-success "Phase 3 done (sc-bootstrap verified and ready)"
            } catch {
                utils print-warning "Endpoint verify call failed — sc-bootstrap may still work, check in ADO"
            }
        }
    }

    # ── Final summary ──────────────────────────────────────────────────────────
    print (format-onboarding-summary $project_name $group_object_id $subscription_id $tenant_id)
}
