#!/usr/bin/env nu
# Platform CLI Test Runner
# Usage: nu tests/run.nu [--filter <pattern>]

def main [
    --filter: string = ""   # Only run test files matching this pattern
    --verbose               # Show output of passing tests too
] {
    let repo_root = ($env.FILE_PWD | path dirname)
    let test_files = (
        glob ($repo_root + "/tests/*_test.nu")
        | where {|f| if ($filter | is-empty) { true } else { $f | str contains $filter }}
        | sort
    )

    if ($test_files | is-empty) {
        print "⚠ No test files found"
        return
    }

    let file_count = ($test_files | length)
    print $"\n🧪 Platform CLI Test Suite"
    print $"   Running ($file_count) test files\n"

    mut total_passed = 0
    mut total_failed = 0
    mut file_results = []

    let tests_dir = ($repo_root + "/tests")

    for test_file in $test_files {
        let name = ($test_file | path basename)
        let raw = (do { cd $tests_dir; nu --no-config-file $test_file } | complete)
        let result = ($raw.stdout + $raw.stderr)
        let exit_ok = ($raw.exit_code == 0)

        # Count pass/fail lines
        let passed = ($result | lines | where {|l| $l | str contains "✅"} | length)
        let failed = ($result | lines | where {|l| $l | str contains "❌"} | length)

        $total_passed += $passed
        $total_failed += $failed

        if $exit_ok and $failed == 0 {
            print $"  ✅ ($name)  ($passed) passed"
            if $verbose { print $result }
        } else {
            print $"  ❌ ($name)  ($passed) passed, ($failed) failed"
            let fail_lines = ($result | lines | where {|l| ($l | str contains "❌") or ($l | str contains "Error")} | str join "\n")
            print $fail_lines
        }
    }

    print $"\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print $"  Total: ($total_passed) passed, ($total_failed) failed"
    print $"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

    if $total_failed > 0 {
        exit 1
    }
}
