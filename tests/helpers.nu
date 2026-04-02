# Shared test helpers for Platform CLI tests
# Usage: use ./helpers.nu *

use std assert

# Create a temporary directory for a test, return its path
export def make-temp-dir [] {
    let ts = (date now | format date "%Y%m%d%H%M%S%f")
    let dir = ("/tmp/platform-cli-test-" + $ts)
    mkdir $dir
    $dir
}

# Create a minimal fake Backstage instance directory structure
export def make-fake-backstage [base: string] {
    let dirs = [
        ($base + "/packages/app/src")
        ($base + "/packages/backend/src")
        ($base + "/catalog-entities")
    ]
    for d in $dirs { mkdir $d }

    # Minimal app-config.yaml
    "app:\n  title: Test App\n  baseUrl: http://localhost:3000\nbackend:\n  baseUrl: http://localhost:7007\nauth:\n  providers:\n    guest: {}\ncatalog:\n  rules:\n    - allow: [Component]\n" | save --force ($base + "/app-config.yaml")

    # New-system App.tsx (frontend-defaults)
    "import { createApp } from '@backstage/frontend-defaults';\nimport catalogPlugin from '@backstage/plugin-catalog/alpha';\n\nexport default createApp({\n  features: [catalogPlugin],\n});\n" | save --force ($base + "/packages/app/src/App.tsx")

    # Backend index.ts
    "import { createBackend } from '@backstage/backend-defaults';\nconst backend = createBackend();\nbackend.add(import('@backstage/plugin-app-backend'));\nbackend.start();\n" | save --force ($base + "/packages/backend/src/index.ts")

    # package.json files
    '{"name": "backstage-test", "version": "0.0.1"}' | save --force ($base + "/package.json")
    '{"name": "@internal/app", "version": "0.0.1"}' | save --force ($base + "/packages/app/package.json")
    '{"name": "@internal/backend", "version": "0.0.1"}' | save --force ($base + "/packages/backend/package.json")
}

# Assert a file exists
export def assert-file-exists [path: string] {
    assert ($path | path exists) $"Expected file to exist: ($path)"
}

# Assert a file contains a string
export def assert-file-contains [path: string, needle: string] {
    assert-file-exists $path
    let content = (open --raw $path)
    assert ($content | str contains $needle) $"Expected ($path) to contain: ($needle)"
}

# Assert a file does NOT contain a string
export def assert-file-not-contains [path: string, needle: string] {
    if ($path | path exists) {
        let content = (open --raw $path)
        assert not ($content | str contains $needle) $"Expected ($path) NOT to contain: ($needle)"
    }
}

# Run a list of [name, closure] test pairs and print results
# Returns exit 1 if any fail
# Create a mock bin dir with a no-op `yarn` script; returns the dir path.
# Use with: with-env {PATH: [(make-mock-bin) ...$env.PATH]} { ... }
export def make-mock-bin [] {
    let bin_dir = (make-temp-dir)
    "#!/bin/sh\nexit 0\n" | save --force ($bin_dir + "/yarn")
    ^chmod +x ($bin_dir + "/yarn")
    $bin_dir
}

export def run-tests [section: string, tests: list] {
    print $"── ($section) ────────────────────────────────"
    mut results = []
    for t in $tests {
        let name = ($t | get 0)
        let body = ($t | get 1)
        let outcome = (try { do $body; "pass" } catch {|e| ("fail: " + $e.msg) })
        if $outcome == "pass" {
            print $"  ✅ ($name)"
            $results = ($results | append "pass")
        } else {
            print $"  ❌ ($name): ($outcome | str replace 'fail: ' '')"
            $results = ($results | append "fail")
        }
    }
    let passed = ($results | where {|r| $r == "pass"} | length)
    let failed = ($results | where {|r| $r != "pass"} | length)
    print $"  → ($passed) passed, ($failed) failed\n"
    if $failed > 0 { exit 1 }
}
