# scaffolding module — creates Backstage instances via @backstage/create-app

use ./utils.nu

# Create a new Backstage instance using the official @backstage/create-app scaffolder.
# Runs: npx @backstage/create-app@latest --path <name>
export def create-instance [
    name: string              # Name / directory for the new Backstage instance
    --path: string = "."      # Parent directory to create the instance in
    --skip-install = false    # Pass --skip-install to create-app (skip yarn install)
    --skip-git = false        # Ignored — create-app always initialises a git repo
] {
    utils print-header $"Creating Backstage Instance: ($name)"

    # ── Pre-flight checks ────────────────────────────────────────────────────
    if (which npx | is-empty) {
        utils print-error "npx not found. Install Node.js v18+ first."
        exit 1
    }

    let parent_path   = ($path | path expand)
    let instance_path = ($parent_path | path join $name)

    if ($instance_path | path exists) {
        utils print-error $"Directory already exists: ($instance_path)"
        exit 1
    }

    if not ($parent_path | path exists) {
        utils print-error $"Parent directory not found: ($parent_path)"
        exit 1
    }

    # ── Run create-app ────────────────────────────────────────────────────────
    utils print-info "Running: npx @backstage/create-app@latest"
    utils print-info $"Target:  ($instance_path)"
    utils print-info "This may take a few minutes — downloading packages...\n"

    let skip_flag = if $skip_install { "--skip-install" } else { "" }
    let cmd = $"cd '($parent_path)' && npx @backstage/create-app@latest --path '($name)' ($skip_flag)"

    try {
        ^bash -c $cmd
    } catch {|err|
        utils print-error $"create-app failed: ($err.msg)"
        exit 1
    }

    # ── Done ─────────────────────────────────────────────────────────────────
    print ""
    utils print-success $"Backstage instance ready at: ($instance_path)"
    print ""
    utils print-header "Next Steps"
    print $"  1. cd ($instance_path)"
    print  "  2. yarn dev                           # start the dev server"
    print  ""
    print  "  Then use platform to add plugins and auth:"
    print $"    platform plugin add kubernetes           ($instance_path)"
    print $"    platform plugin add kubernetes-ingestor  ($instance_path)"
    print $"    platform auth add microsoft              ($instance_path) --no-guest"
}
