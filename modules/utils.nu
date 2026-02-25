# utility functions for platform CLI

use ../config.nu

export def print-success [message: string] {
    let colors = (config get-colors)
    print (($colors.green + $colors.bold) + "✓ " + $colors.reset + $message)
}

export def print-error [message: string] {
    let colors = (config get-colors)
    print (($colors.red + $colors.bold) + "✗ " + $colors.reset + $message)
}

export def print-warning [message: string] {
    let colors = (config get-colors)
    print (($colors.yellow + $colors.bold) + "⚠ " + $colors.reset + $message)
}

export def print-info [message: string] {
    let colors = (config get-colors)
    print (($colors.blue + $colors.bold) + "ℹ " + $colors.reset + $message)
}

export def print-header [title: string] {
    let colors = (config get-colors)
    print ""
    print (($colors.cyan + $colors.bold) + "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" + $colors.reset)
    print (($colors.cyan + $colors.bold) + $title + $colors.reset)
    print (($colors.cyan + $colors.bold) + "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" + $colors.reset)
}

export def check-command [cmd: string] {
    (which $cmd | is-not-empty)
}

export def require-command [cmd: string, description: string] {
    if not (check-command $cmd) {
        print-error $"Required command not found: ($cmd)"
        print-info $"Please install: ($description)"
        exit 1
    }
}

export def create-directory [path: string] {
    if not ($path | path exists) {
        mkdir $path
        print-success $"Created directory: ($path)"
    }
}

export def validate-path [path: string, name: string] {
    if ($path | path exists) {
        print-error $"($name) already exists at ($path)"
        exit 1
    }
}

export def prompt-confirm [message: string] {
    let response = (input $"($message) (y/n): ")
    ($response | str downcase) == "y"
}

export def prompt-input [message: string, --default: string] {
    let response = (input $"($message) [($default)]: ")
    if ($response | is-empty) { $default } else { $response }
}

export def validate-yaml [path: string] {
    try {
        open $path | ignore
        true
    } catch {
        false
    }
}

export def validate-json [content: string] {
    try {
        $content | from json | ignore
        true
    } catch {
        false
    }
}

export def run-command [cmd: string, --description: string] {
    let desc = ($description | default $cmd)
    print-info $"Running: ($desc)"
    try {
        (bash -c $cmd)
        print-success $"Completed: ($desc)"
    } catch {
        print-error $"Failed: ($desc)"
        exit 1
    }
}

export def copy-template [source: string, dest: string] {
    try {
        if ($source | path exists) {
            cp -r $source $dest
            print-success $"Copied template from ($source)"
        } else {
            print-error $"Template not found: ($source)"
            exit 1
        }
    } catch {
        print-error $"Failed to copy template"
        exit 1
    }
}

export def get-timestamp [] {
    (date now | format date "%Y%m%d_%H%M%S")
}

export def backup-file [path: string] {
    if ($path | path exists) {
        let timestamp = (get-timestamp)
        let backup_path = $"($path).backup.($timestamp)"
        cp $path $backup_path
        print-info $"Backed up to: ($backup_path)"
    }
}
