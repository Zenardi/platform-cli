# auth provider management module

use ../config.nu
use ./utils.nu

# ---------------------------------------------------------------------------
# Auth provider registry
# frontend_code is generated dynamically via build-frontend-code based on
# whether guest sign-in is enabled or not.
# ---------------------------------------------------------------------------
def auth-registry [] {
    {
        "microsoft": {
            name: "Microsoft (Azure AD)"
            description: "Sign-in via Azure Active Directory OAuth — supports AAD users and groups"
            backend_pkg: "@backstage/plugin-auth-backend-module-microsoft-provider"
            api_ref:        "microsoftAuthApiRef"
            provider_id:    "microsoft-auth-provider"
            provider_title: "Microsoft"
            provider_msg:   "Sign in using Microsoft Azure AD"
            app_config: "
auth:
  environment: development
  providers:
    microsoft:
      development:
        clientId: ${AZURE_CLIENT_ID}
        clientSecret: ${AZURE_CLIENT_SECRET}
        tenantId: ${AZURE_TENANT_ID}
        domainHint: ${AZURE_TENANT_ID}
        signIn:
          resolvers:
            - resolver: userIdMatchingUserEntityAnnotation
"
            backend_code: "
// Add to packages/backend/src/index.ts
backend.add(import('@backstage/plugin-auth-backend'));
backend.add(import('@backstage/plugin-auth-backend-module-microsoft-provider'));
"
            env_vars: ["AZURE_CLIENT_ID", "AZURE_CLIENT_SECRET", "AZURE_TENANT_ID"]
            notes: "
Azure Portal setup steps:
  1. Go to https://portal.azure.com > App registrations
     Create a new registration (or reuse an existing Backstage one)

  2. Under Authentication > Add a platform > Web, set Redirect URI:
       http://localhost:7007/api/auth/microsoft/handler/frame   (dev)
       https://<your-backstage>/api/auth/microsoft/handler/frame  (prod)
     Leave Front-channel logout URL blank.
     Uncheck all Implicit grant / hybrid flow boxes.

  3. Under API permissions > Add permission > Microsoft Graph > Delegated:
       email, offline_access, openid, profile, User.Read
     (Optional) Grant admin consent so users aren't prompted individually.

  4. Under Certificates & secrets > New client secret — copy the value.

  5. From App registration Overview, copy:
       Application (client) ID  →  AZURE_CLIENT_ID
       Directory (tenant) ID    →  AZURE_TENANT_ID

  Docs: https://backstage.io/docs/auth/microsoft/provider
"
        }
        "github": {
            name: "GitHub"
            description: "Sign-in via GitHub OAuth"
            backend_pkg: "@backstage/plugin-auth-backend-module-github-provider"
            api_ref:        "githubAuthApiRef"
            provider_id:    "github-auth-provider"
            provider_title: "GitHub"
            provider_msg:   "Sign in using GitHub"
            app_config: "
auth:
  environment: development
  providers:
    github:
      development:
        clientId: ${GITHUB_CLIENT_ID}
        clientSecret: ${GITHUB_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: usernameMatchingUserEntityName
"
            backend_code: "
// Add to packages/backend/src/index.ts
backend.add(import('@backstage/plugin-auth-backend'));
backend.add(import('@backstage/plugin-auth-backend-module-github-provider'));
"
            env_vars: ["GITHUB_CLIENT_ID", "GITHUB_CLIENT_SECRET"]
            notes: "
GitHub OAuth App setup:
  1. Go to https://github.com/settings/developers > OAuth Apps > New OAuth App
  2. Set Homepage URL: http://localhost:3000 (or your Backstage URL)
  3. Set Authorization callback URL:
       http://localhost:7007/api/auth/github/handler/frame
  4. Copy Client ID and generate a Client Secret.

  Docs: https://backstage.io/docs/auth/github/provider
"
        }
        "google": {
            name: "Google"
            description: "Sign-in via Google OAuth"
            backend_pkg: "@backstage/plugin-auth-backend-module-google-provider"
            api_ref:        "googleAuthApiRef"
            provider_id:    "google-auth-provider"
            provider_title: "Google"
            provider_msg:   "Sign in using Google"
            app_config: "
auth:
  environment: development
  providers:
    google:
      development:
        clientId: ${GOOGLE_CLIENT_ID}
        clientSecret: ${GOOGLE_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: emailMatchingUserEntityProfileEmail
"
            backend_code: "
// Add to packages/backend/src/index.ts
backend.add(import('@backstage/plugin-auth-backend'));
backend.add(import('@backstage/plugin-auth-backend-module-google-provider'));
"
            env_vars: ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET"]
            notes: "
Google Cloud Console setup:
  1. Go to https://console.cloud.google.com > APIs & Services > Credentials
  2. Create OAuth 2.0 Client ID (type: Web application)
  3. Add Authorized redirect URI:
       http://localhost:7007/api/auth/google/handler/frame
  4. Copy the Client ID and Client Secret.

  Docs: https://backstage.io/docs/auth/google/provider
"
        }
    }
}

# ---------------------------------------------------------------------------
# Generate the App.tsx SignInPage snippet.
# --no-guest  → single `provider` prop + `auto` (forces IdP login, no guest option)
# default     → `providers` array including 'guest' (user can choose guest or IdP)
# ---------------------------------------------------------------------------
def build-frontend-code [auth: record, no_guest: bool] {
    let provider_block = $"        \{
          id: '($auth.provider_id)',
          title: '($auth.provider_title)',
          message: '($auth.provider_msg)',
          apiRef: ($auth.api_ref),
        \}"

    let sign_in_page = if $no_guest {
        $"    <SignInPage
      \{...props\}
      auto
      provider=\{
($provider_block)
      \}
    />"
    } else {
        $"    <SignInPage
      \{...props\}
      providers=\{[
        'guest',
($provider_block),
      ]\}
    />"
    }

    let guest_note = if $no_guest {
        "  // Guest sign-in is DISABLED — users must authenticate via the provider."
    } else {
        "  // Guest sign-in is enabled. Pass --no-guest to require authentication."
    }

    $"
// In packages/app/src/App.tsx — add to createApp\(\{ components: \{ ... \} \}\)
import \{ ($auth.api_ref) \} from '@backstage/core-plugin-api';
import \{ SignInPage \} from '@backstage/core-components';
($guest_note)

components: \{
  SignInPage: props => \(
($sign_in_page)
  \),
\},
"
}


# Generate the components block ready to be inserted inside createApp({}) in App.tsx
def build-components-insert [auth: record, no_guest: bool] {
    let provider_block = $"          \{
            id: '($auth.provider_id)',
            title: '($auth.provider_title)',
            message: '($auth.provider_msg)',
            apiRef: ($auth.api_ref),
          \}"

    let sign_in_page = if $no_guest {
        $"      <SignInPage
        \{...props\}
        auto
        provider=\{
($provider_block)
        \}
      />"
    } else {
        $"      <SignInPage
        \{...props\}
        providers=\{[
          'guest',
($provider_block),
        ]\}
      />"
    }

    $"  components: \{
    SignInPage: props => \(
($sign_in_page)
    \),
  \},"
}

# Patch packages/backend/src/index.ts to register the auth provider module
def patch-backend-index [instance_path: string, auth: record] {
    let index_path = ($instance_path + "/packages/backend/src/index.ts")
    if not ($index_path | path exists) {
        utils print-warning "packages/backend/src/index.ts not found — skipping backend patch"
        return
    }

    let content = (open --raw $index_path)
    let pkg = $auth.backend_pkg

    if ($content | str contains $pkg) {
        utils print-info "index.ts already registers this auth provider"
        return
    }

    let auth_line = "backend.add(import('@backstage/plugin-auth-backend'));"
    let provider_line = $"backend.add\(import\('($pkg)'\)\);"

    let new_content = if ($content | str contains $auth_line) {
        $content | str replace $auth_line ($auth_line + "\n" + $provider_line)
    } else {
        $content | str replace "backend.start();" ($"// auth plugin\n($auth_line)\n($provider_line)\n\nbackend.start\(\);")
    }

    $new_content | save --force $index_path
    utils print-success "packages/backend/src/index.ts updated"
}

# Patch packages/app/src/App.tsx to add the import and SignInPage components block
def patch-frontend-app [instance_path: string, auth: record, no_guest: bool] {
    let app_path = ($instance_path + "/packages/app/src/App.tsx")
    if not ($app_path | path exists) {
        utils print-warning "packages/app/src/App.tsx not found — skipping frontend patch"
        return
    }

    let content = (open --raw $app_path)
    mut new_content = $content

    # 1. Add the provider apiRef import before createApp if not already present
    if not ($new_content | str contains $auth.api_ref) {
        let import_line = $"import \{ ($auth.api_ref) \} from '@backstage/core-plugin-api';"
        if ($new_content | str contains "const app = createApp({") {
            $new_content = ($new_content | str replace "const app = createApp({" ($import_line + "\n\nconst app = createApp({"))
        } else {
            utils print-warning "Could not locate createApp in App.tsx — add the import manually:"
            utils print-info    $"  ($import_line)"
        }
    }

    # 2. Inject the SignInPage components block inside createApp if not already present
    if not ($new_content | str contains "SignInPage: props =>") {
        let components_block = (build-components-insert $auth $no_guest)
        # The createApp block ends with the bindRoutes close (2-space indent) then });
        let close_marker = "  },\n});"
        if ($new_content | str contains $close_marker) {
            $new_content = ($new_content | str replace $close_marker ("  },\n" + $components_block + "\n});"))
        } else {
            utils print-warning "Could not locate createApp closing in App.tsx — add the components block manually"
            utils print-info    "Inside createApp({ ... }), add:"
            print $components_block
        }
    } else {
        utils print-info "App.tsx already has a SignInPage component — skipping"
    }

    $new_content | save --force $app_path
    utils print-success "packages/app/src/App.tsx updated"
}

# Install and configure an authentication provider in a Backstage instance
export def add-auth-provider [
    provider: string          # Provider ID: microsoft, github, google. Use 'auth list' to see all.
    instance_path: string     # Path to the Backstage instance root
    --client-id: string       # Set clientId directly in app-config.local.yaml (otherwise uses env var placeholder)
    --client-secret: string   # Set clientSecret directly (not recommended for production)
    --tenant-id: string       # (Microsoft only) Set tenantId directly
    --no-guest                # Disable guest sign-in — users must authenticate via the provider
    --skip-config             # Skip patching app-config.local.yaml
    --skip-install            # Skip running yarn install
] {
    let registry = (auth-registry)

    if not ($provider in $registry) {
        utils print-error $"Unknown auth provider: ($provider)"
        utils print-info "Run 'platform auth list' to see available providers"
        exit 1
    }

    let auth = ($registry | get $provider)
    let instance_path = ($instance_path | path expand)

    if not ($instance_path | path exists) {
        utils print-error $"Instance path not found: ($instance_path)"
        exit 1
    }

    utils print-header $"Setting Up Auth: ($auth.name)"
    utils print-info $"($auth.description)"
    if $no_guest {
        utils print-info "Guest sign-in: DISABLED"
    } else {
        utils print-info "Guest sign-in: enabled  (use --no-guest to disable)"
    }
    print ""

    # ── Backend package ───────────────────────────────────────────────────────
    if not $skip_install {
        let backend_dir = ($instance_path + "/packages/backend")
        if ($backend_dir | path exists) {
            utils print-info $"Installing: ($auth.backend_pkg)"
            let result = (do { cd $backend_dir; ^yarn add $auth.backend_pkg } | complete)
            if $result.exit_code == 0 {
                utils print-success "Backend auth package installed"
            } else {
                utils print-error "Install failed — run manually:"
                utils print-info  $"  yarn --cwd ($backend_dir) add ($auth.backend_pkg)"
            }
        } else {
            utils print-warning "packages/backend not found — skipping install"
            utils print-info    $"  Run manually: yarn --cwd ($instance_path)/packages/backend add ($auth.backend_pkg)"
        }
    }

    # ── app-config.local.yaml ─────────────────────────────────────────────────
    if not $skip_config {
        let local_config = ($instance_path + "/app-config.local.yaml")
        mut config_snippet = $auth.app_config

        # Substitute literal values if provided via flags
        if ($client_id | is-not-empty) {
            $config_snippet = ($config_snippet | str replace "${AZURE_CLIENT_ID}"   $client_id)
            $config_snippet = ($config_snippet | str replace "${GITHUB_CLIENT_ID}"  $client_id)
            $config_snippet = ($config_snippet | str replace "${GOOGLE_CLIENT_ID}"  $client_id)
        }
        if ($client_secret | is-not-empty) {
            $config_snippet = ($config_snippet | str replace "${AZURE_CLIENT_SECRET}"  $client_secret)
            $config_snippet = ($config_snippet | str replace "${GITHUB_CLIENT_SECRET}" $client_secret)
            $config_snippet = ($config_snippet | str replace "${GOOGLE_CLIENT_SECRET}" $client_secret)
        }
        if ($tenant_id | is-not-empty) {
            $config_snippet = ($config_snippet | str replace --all "${AZURE_TENANT_ID}" $tenant_id)
        }

        # Disable guest/unauthenticated access
        if $no_guest {
            $config_snippet = ($config_snippet | str replace "auth:" "auth:\n  dangerouslyDisableDefaultAuthPolicy: false")
        }

        # Read existing app-config.local.yaml or initialise a fresh one
        mut existing_local = ""
        if ($local_config | path exists) {
            $existing_local = (open --raw $local_config)
        } else {
            $existing_local = "# Backstage local development overrides — keep out of version control\n"
        }

        if ($existing_local | str contains "auth:") {
            utils print-warning "app-config.local.yaml already has an 'auth:' section"
            utils print-info    "Merge the following snippet manually:"
            print $config_snippet
        } else {
            ($existing_local + $"\n# --- ($auth.name) auth provider ---\n" + $config_snippet) | save --force $local_config
            utils print-success "app-config.local.yaml updated with auth configuration"
        }
    }

    # ── Environment variable checklist ────────────────────────────────────────
    print ""
    utils print-header "Required Environment Variables"
    $auth.env_vars | each {|var|
        print $"  export ($var)=<your-value>"
    } | ignore

    # ── Code changes needed ───────────────────────────────────────────────────
    print ""
    utils print-header "Backend Code  (packages/backend/src/index.ts)"
    print $auth.backend_code

    utils print-header "Frontend Code  (packages/app/src/App.tsx)"
    print (build-frontend-code $auth $no_guest)

    # ── Portal / IdP setup notes ──────────────────────────────────────────────
    utils print-header "Identity Provider Setup"
    print $auth.notes

    # ── Auto-patch source files ───────────────────────────────────────────────
    utils print-header "Patching Source Files"
    patch-backend-index $instance_path $auth
    patch-frontend-app $instance_path $auth $no_guest

    utils print-success $"Auth provider ($auth.name) setup complete"
}

# List all available authentication providers
export def list-auth-providers [] {
    let registry = (auth-registry)
    let colors = (config get-colors)

    utils print-header "Available Auth Providers"
    print ""

    $registry | items {|id, auth|
        print $"  ($colors.cyan)($colors.bold)($id)($colors.reset)"
        print $"    ($auth.description)"
        print $"    backend pkg: ($auth.backend_pkg)"
        let vars = ($auth.env_vars | str join ", ")
        print $"    env vars:    ($vars)"
        print ""
    } | ignore
}

# Show full setup guide for an auth provider
export def show-auth-info [
    provider: string
    --no-guest  # Show the no-guest-sign-in version of the frontend code
] {
    let registry = (auth-registry)

    if not ($provider in $registry) {
        utils print-error $"Unknown provider: ($provider)"
        utils print-info "Run 'platform auth list' to see available providers"
        exit 1
    }

    let auth = ($registry | get $provider)

    utils print-header $"Auth Provider: ($auth.name)"
    print ""
    print $"  ($auth.description)"
    print $"  Backend package: ($auth.backend_pkg)"
    let vars = ($auth.env_vars | str join ", ")
    print $"  Environment vars: ($vars)"

    utils print-header "app-config.yaml snippet"
    print $auth.app_config

    utils print-header "Backend Code  (packages/backend/src/index.ts)"
    print $auth.backend_code

    utils print-header "Frontend Code  (packages/app/src/App.tsx)"
    print (build-frontend-code $auth $no_guest)

    utils print-header "Identity Provider Setup"
    print $auth.notes
}
