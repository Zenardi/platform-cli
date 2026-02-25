# configuration and defaults for platform CLI

export def get-config [] {
    {
        backstage_version: "1.26.0",
        node_version: "18.17.0",
        package_manager: "yarn",
        default_database: "postgresql",
        default_auth: "github",
        default_plugins: [
            "catalog",
            "scaffolder",
            "techdocs",
            "kubernetes",
            "github"
        ],
        directories: {
            app: "app",
            packages: "packages",
            config: "app-config",
            entities: "catalog-entities"
        },
        git: {
            author_name: $env.USER,
            author_email: ($env.USER + "@backstage.local"),
            initial_branch: "main"
        }
    }
}

export def get-colors [] {
    {
        reset: "\u{1b}[0m",
        green: "\u{1b}[32m",
        red: "\u{1b}[31m",
        yellow: "\u{1b}[33m",
        blue: "\u{1b}[34m",
        cyan: "\u{1b}[36m",
        bold: "\u{1b}[1m"
    }
}

export def get-template-dir [] {
    (($env.SCRIPT_DIR? | default $nu.default-config-dir) + "/platform/templates")
}
