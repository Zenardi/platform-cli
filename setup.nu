# Setup and installation script for Platform CLI

def print-setup-header [title: string] {
    print ""
    print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print $title
    print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

def main [] {
    print-setup-header "Platform CLI Setup"
    
    # Source directory where setup.nu lives
    let source_path = ($env.CURRENT_FILE | path dirname)
    
    # Target installation directory
    let install_path = ($nu.default-config-dir + "/platform")
    
    print $"Source path:       ($source_path)"
    print $"Installation path: ($install_path)"
    print ""
    
    # Check prerequisites
    print-setup-header "Checking Prerequisites"
    
    # Check Nushell
    let nu_ok = (which nu | is-not-empty)
    if $nu_ok {
        let version = (nu --version)
        print $"✓ Nushell: ($version)"
    } else {
        print "✗ Nushell: NOT FOUND"
        print "  Install from: https://www.nushell.sh/book/installation.html"
    }
    
    # Check Git
    let git_ok = (which git | is-not-empty)
    if $git_ok {
        let version = (git --version)
        print $"✓ Git: ($version)"
    } else {
        print "✗ Git: NOT FOUND"
        print "  Install from: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git"
    }
    
    # Check Node.js
    let node_ok = (which node | is-not-empty)
    if $node_ok {
        let version = (node --version)
        print $"✓ Node.js: ($version)"
    } else {
        print "✗ Node.js: NOT FOUND"
        print "  Install from: https://nodejs.org/"
    }
    
    print ""
    
    if (not $nu_ok) or (not $git_ok) or (not $node_ok) {
        print "Please install missing prerequisites and run setup again."
        exit 1
    }
    
    # Copy files to install location
    print-setup-header "Installing Files"
    
    if ($install_path | path exists) {
        rm --recursive --force $install_path
    }
    mkdir $install_path
    bash -c $"cp -r '($source_path)/.' '($install_path)/'"
    print $"✓ Installed platform CLI to ($install_path)"
    
    # Setup alias
    print-setup-header "Setting Up Alias"
    
    let config_file = ($env.NU_CONFIG_PATH? | default ($nu.default-config-dir + "/env.nu"))
    
    print $"Config file: ($config_file)"
    
    let alias_line = $"alias platform = nu ($install_path)/main.nu"
    
    if ($config_file | path exists) {
        let current_content = (open $config_file)
        
        if ($current_content | str contains "alias platform") {
            print "✓ Platform alias already configured"
        } else {
            ($current_content + "\n\n# Platform CLI alias\n" + $alias_line + "\n") | save --force $config_file
            print "✓ Added platform alias to configuration"
        }
    } else {
        mkdir ($config_file | path dirname)
        $alias_line | save $config_file
        print "✓ Created configuration file with platform alias"
    }
    
    print ""
    print "Setup Instructions:"
    print ""
    print "1. Reload your shell configuration:"
    print $"   source ($config_file)"
    print ""
    print "2. Or restart your terminal"
    print ""
    print "3. Test the installation:"
    print "   platform --help"
    print ""
    
    print-setup-header "Setup Complete!"
    print ""
    print "You can now use the platform CLI from anywhere in your system."
    print ""
    print "Get started with:"
    print "  platform init my-backstage"
    print ""
}

def shell-exec [cmd: string] {
    bash -c $cmd
}
