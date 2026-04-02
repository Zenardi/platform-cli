# Copilot Instructions

## Project Overview

**Platform CLI** is a Nushell tool for automating [Backstage](https://backstage.io/) scaffolding.
**Goal:** Zero-manual-config IDP instances.
**Tech Stack:** Nushell (Logic), TypeScript (Target), `nust` (Nushell Testing).

## Architecture

```
main.nu          # CLI entry point: parses args and dispatches to modules
setup.nu         # One-time installer (copies CLI to ~/.config/nushell/platform/)
config.nu        # Global constants: versions, defaults, ANSI color codes
modules/
  scaffolding.nu # Runs npx @backstage/create-app@latest to bootstrap instances
  plugins.nu     # Plugin registry (12 plugins) + yarn install + TS file patching
  auth.nu        # Auth provider registry (3 providers) + yarn install + TS patching
  entities.nu    # Generates Backstage catalog YAML entities
  app-config.nu  # Manages app-config.yaml (database, auth, storage settings)
  utils.nu       # Shared helpers: print-*, check-command, prompt-*, run-command
templates/
  package.json.template  # Backstage monorepo workspace template
docs/
  README.md      # Full command reference
  USAGE.md       # Step-by-step workflows
  EXAMPLES.md    # 10 complete real-world scenarios
```

**Dispatch pattern in `main.nu`:** Raw CLI args are matched with `if`/`else if` blocks. Named flags are extracted with the `get-flag` helper.

**Registries as data:** Both plugins and auth providers are defined as Nushell records (not classes or switch tables). Each entry holds package names, config snippets, and install notes. Adding a new plugin or auth provider means adding a new key to the registry record.

**Auto-patching:** After `yarn add`, the CLI surgically injects imports, routes, and API registrations into the generated TypeScript files (`index.ts`, `App.tsx`, `EntityPage.tsx`, `apis.ts`) using `str replace` on raw file content.

## Key Conventions

### Nushell style
- Functions are defined with `export def` for cross-module use; module-private helpers omit `export`.
- Flags use `--kebab-case`; required positional params are undecorated.
- Always use `^bash -c "..."` (or `do { cd $dir; ^yarn ... }`) when shell builtins or `cd` are needed — Nushell does not source `.bashrc`.
- File reads: `open --raw $path`. File writes: `$content | save --force $path`.
- Iterate records with `$record | items {|key, val| ... }`; iterate lists with `| each {|item| ... }`.
- String interpolation: `$"text ($var) more text"` — parentheses are required around expressions.
- Error exit pattern: `utils print-error "message"; exit 1`.

### Module imports
```nushell
use ../config.nu         # sibling/parent file
use ./utils.nu           # same-directory file
use modules/plugins.nu * # wildcard brings all exported defs into scope
```

### Output helpers (from `utils.nu`)
| Function | Prefix |
|---|---|
| `utils print-success` | ✅ green |
| `utils print-error` | ❌ red |
| `utils print-warning` | ⚠️  yellow |
| `utils print-info` | ℹ️  blue |
| `utils print-header` | cyan divider |

### Adding a new plugin
1. Add a record key to the registry in `modules/plugins.nu` with `name`, `frontend_pkg`, `backend_pkg`, `app_config`, `notes`.
2. Add a `patch-*` function if TypeScript files need modification.
3. Call the patch function from inside `add-plugin`.
4. No changes needed in `main.nu`.

### Adding a new auth provider
Same pattern as plugins, but inside `modules/auth.nu`. Include `backend_code`, `app_config`, `env_vars`, and `notes` fields.

### Entity YAML output
Entities are written to `./catalog-entities/<name>.yaml` by default. All entity generators follow the Backstage catalog schema (`apiVersion: backstage.io/v1alpha1`, `kind`, `metadata`, `spec`).

## Running the CLI

```sh
# One-time install
nu setup.nu

# After install (alias is set in env.nu)
platform init my-backstage
platform plugin add kubernetes ./my-backstage
platform auth add github ./my-backstage
platform entity create my-service --type component --owner team-a
platform validate ./my-backstage

# Run directly without installing
nu main.nu init my-backstage
```

## Versions & Defaults

Defined in `config.nu → get-config`:
- Backstage: `1.26.0`
- Node.js: `18.17.0`
- Package manager: `yarn`
- Default database: `postgresql`
- Default auth: `github`
- Default plugins: catalog, scaffolder, techdocs, kubernetes, github


## Strict TDD Workflow
Before writing any implementation logic, Copilot **must** generate tests.
1.  **Red:** Create a test file in `tests/<module>_test.nu`. Define the expected behavior.
2.  **Green:** Write the minimal Nushell code in the corresponding module to pass the test.
3.  **Refactor:** Clean up the logic, ensuring it follows the "Registries as Data" pattern.

### Testing Patterns
- Use `use std assert` for assertions.
- Use `before-each` blocks to create temporary directories for file-system manipulation tests.
- **Example Test Structure:**
```nushell
use std assert
use ../modules/utils.nu

#[test]
def test_check_command_exists() {
    assert (utils check-command "ls")
    assert (utils check-command "non-existent-cmd" == false)
}
```

## Advanced Nushell Architecture

### 1. Functional Purity & Data Pipelines
- **Avoid Global State:** Functions should take a path/record and return a value. 
- **Validation First:** Every command must validate its environment (check for `node`, `yarn`, `npx`) before execution using `utils.nu`.
- **Structured Data:** Use Nushell tables for any list processing to allow easy filtering/sorting.

### 2. Robust File Patching (The "Surgical" Rule)
Since the CLI patches TypeScript files, avoid simple string replacement if possible.
- **Verification:** Always check if a snippet already exists before injecting (`str contains`).
- **Idempotency:** Running a command twice should not result in duplicate imports or double-registrations.
- **Safety:** Always create a `.bak` of a file before a `str replace` operation.

### 3. Error Handling (The "Graceful Exit" Rule)
- Use `try { ... } catch { ... }` blocks for external commands (`yarn`, `npx`).
- Do not let the CLI crash with a Nushell stack trace. Catch the error, print it using `utils print-error`, and exit with code `1`.

## Key Conventions (Updated)

### Nushell Style & Safety
- **Strict Typing:** Use type signatures in function definitions (e.g., `def install-plugin [name: string, target_path: path]`).
- **Path Handling:** Always use `$path | path expand` to avoid relative path breakage.
- **External Commands:** Use `^` prefix for all external binaries to avoid naming collisions with Nushell internal commands.
- **Help Documentation:** Every `export def` must have a docstring for `help <command>` support.

### Output Standards
| Function | Purpose |
|---|---|
| `utils print-success` | Operation completed successfully. |
| `utils print-error` | Critical failure, stop execution. |
| `utils print-warning` | Non-blocking issue (e.g., optional env var missing). |
| `utils print-step` | Visual indicator of current progress in a multi-step task. |

## Feature Expansion: Resilience & Maintenance
- **Dry Run:** Implement a `--dry-run` flag for all commands that shows what *would* be written to files without actually writing.
- **Doctor Command:** `platform doctor` to check system dependencies (Node version, Yarn, Git).
- **Cleanup:** A `platform undo` mechanism or logging changes to a `platform.log` for auditability.

## Adding New Features
When asked to add a plugin or auth provider:
1.  Define the **Schema** in the registry first.
2.  Write a **Test** that mocks a Backstage directory and asserts the file content after the "patch."
3.  Implement the **Patch Logic**.

---

### Key Additions to your workflow:
* **The `std assert` library:** This is the standard way to test in Nushell.
* **Expansion of `utils.nu`:** It should now include a `verify-environment` function that is called at the start of `main.nu`.
* **Dry Run capability:** Crucial for robust CLIs. It allows Copilot to simulate the "patching" to see if the regex/replacement logic is correct before touching the disk.
