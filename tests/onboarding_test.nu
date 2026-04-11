use std assert
use ./helpers.nu *
use ../modules/onboarding.nu *

def main [] {
    let tests = [

        # ── detect-os ─────────────────────────────────────────────────────────
        ["detect-os: returns a known OS string", {
            let os = (detect-os)
            assert (($os == "windows") or ($os == "macos") or ($os == "linux"))
        }],
        ["detect-os: returns a non-empty string", {
            assert ((detect-os | str length) > 0)
        }],

        # ── format-az-install-instructions ────────────────────────────────────
        ["format-az-install-instructions: windows contains winget", {
            let s = (format-az-install-instructions "windows")
            assert ($s | str contains "winget")
        }],
        ["format-az-install-instructions: windows contains Chocolatey", {
            let s = (format-az-install-instructions "windows")
            assert ($s | str contains "choco")
        }],
        ["format-az-install-instructions: windows contains MSI link", {
            let s = (format-az-install-instructions "windows")
            assert ($s | str contains "installazurecliwindows")
        }],
        ["format-az-install-instructions: macos contains brew", {
            let s = (format-az-install-instructions "macos")
            assert ($s | str contains "brew")
        }],
        ["format-az-install-instructions: macos contains InstallAzureCli", {
            let s = (format-az-install-instructions "macos")
            assert ($s | str contains "InstallAzureCli")
        }],
        ["format-az-install-instructions: linux contains apt/bash script", {
            let s = (format-az-install-instructions "linux")
            assert ($s | str contains "InstallAzureCLIDeb")
        }],
        ["format-az-install-instructions: linux contains dnf", {
            let s = (format-az-install-instructions "linux")
            assert ($s | str contains "dnf")
        }],
        ["format-az-install-instructions: linux contains full guide URL", {
            let s = (format-az-install-instructions "linux")
            assert ($s | str contains "install-azure-cli-linux")
        }],
        ["format-az-install-instructions: unknown OS falls back to linux", {
            let s = (format-az-install-instructions "freebsd")
            assert ($s | str contains "InstallAzureCLIDeb")
        }],
        ["format-az-install-instructions: returns non-empty string for each OS", {
            for os in ["windows" "macos" "linux"] {
                assert ((format-az-install-instructions $os | str length) > 0)
            }
        }],

        # ── validate-project-name ─────────────────────────────────────────────
        ["validate-project-name: single word", {
            assert (validate-project-name "myproject")
        }],
        ["validate-project-name: hyphenated", {
            assert (validate-project-name "my-project")
        }],
        ["validate-project-name: with digits", {
            assert (validate-project-name "project2")
        }],
        ["validate-project-name: multiple segments", {
            assert (validate-project-name "my-cool-project")
        }],
        ["validate-project-name: digit in segment", {
            assert (validate-project-name "space-tech2")
        }],
        ["validate-project-name: rejects empty string", {
            assert not (validate-project-name "")
        }],
        ["validate-project-name: accepts uppercase", {
            assert (validate-project-name "MyProject")
        }],
        ["validate-project-name: accepts spaces", {
            assert (validate-project-name "my project")
        }],
        ["validate-project-name: accepts leading hyphen", {
            assert (validate-project-name "-myproject")
        }],
        ["validate-project-name: rejects leading period", {
            assert not (validate-project-name ".myproject")
        }],
        ["validate-project-name: rejects trailing period", {
            assert not (validate-project-name "myproject.")
        }],
        ["validate-project-name: rejects backslash", {
            assert not (validate-project-name "my\\project")
        }],
        ["validate-project-name: rejects colon", {
            assert not (validate-project-name "my:project")
        }],
        ["validate-project-name: accepts Marketing", {
            assert (validate-project-name "Marketing")
        }],
        ["validate-project-name: accepts Finance GitOps Platform", {
            assert (validate-project-name "Finance GitOps Platform")
        }],

        # ── build-wif-endpoint-body ───────────────────────────────────────────
        ["build-wif-endpoint-body: returns valid JSON", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "sub-id" "My Sub" "tenant-id" "proj-id" "myproject")
            let parsed = ($body | from json)
            assert ($parsed != null)
        }],
        ["build-wif-endpoint-body: name is set", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "sub-id" "My Sub" "tenant-id" "proj-id" "myproject")
            let parsed = ($body | from json)
            assert ($parsed.name == "sc-bootstrap")
        }],
        ["build-wif-endpoint-body: type is AzureRM", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "sub-id" "My Sub" "tenant-id" "proj-id" "myproject")
            let parsed = ($body | from json)
            assert ($parsed.type == "AzureRM")
        }],
        ["build-wif-endpoint-body: scheme is WorkloadIdentityFederation", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "sub-id" "My Sub" "tenant-id" "proj-id" "myproject")
            let parsed = ($body | from json)
            assert ($parsed.authorization.scheme == "WorkloadIdentityFederation")
        }],
        ["build-wif-endpoint-body: serviceprincipalid is set", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "my-app-id" "sub-id" "My Sub" "tenant-id" "proj-id" "myproject")
            let parsed = ($body | from json)
            assert ($parsed.authorization.parameters.serviceprincipalid == "my-app-id")
        }],
        ["build-wif-endpoint-body: tenantid is set", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "sub-id" "My Sub" "my-tenant" "proj-id" "myproject")
            let parsed = ($body | from json)
            assert ($parsed.authorization.parameters.tenantid == "my-tenant")
        }],
        ["build-wif-endpoint-body: subscriptionId in data", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "my-sub-id" "My Sub" "tenant-id" "proj-id" "myproject")
            let parsed = ($body | from json)
            assert ($parsed.data.subscriptionId == "my-sub-id")
        }],
        ["build-wif-endpoint-body: subscriptionName in data", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "sub-id" "My Subscription" "tenant-id" "proj-id" "myproject")
            let parsed = ($body | from json)
            assert ($parsed.data.subscriptionName == "My Subscription")
        }],
        ["build-wif-endpoint-body: creationMode is Manual", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "sub-id" "My Sub" "tenant-id" "proj-id" "myproject")
            let parsed = ($body | from json)
            assert ($parsed.data.creationMode == "Manual")
        }],
        ["build-wif-endpoint-body: environment is AzureCloud", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "sub-id" "My Sub" "tenant-id" "proj-id" "myproject")
            let parsed = ($body | from json)
            assert ($parsed.data.environment == "AzureCloud")
        }],
        ["build-wif-endpoint-body: project reference has correct id", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "sub-id" "My Sub" "tenant-id" "my-proj-uuid" "myproject")
            let parsed = ($body | from json)
            let ref = ($parsed.serviceEndpointProjectReferences | get 0)
            assert ($ref.projectReference.id == "my-proj-uuid")
        }],
        ["build-wif-endpoint-body: project reference has correct name", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "sub-id" "My Sub" "tenant-id" "proj-id" "myproject")
            let parsed = ($body | from json)
            let ref = ($parsed.serviceEndpointProjectReferences | get 0)
            assert ($ref.projectReference.name == "myproject")
        }],
        ["build-wif-endpoint-body: service endpoint project references entry name matches sc_name", {
            let body = (build-wif-endpoint-body "sc-bootstrap" "app-id" "sub-id" "My Sub" "tenant-id" "proj-id" "myproject")
            let parsed = ($body | from json)
            let ref = ($parsed.serviceEndpointProjectReferences | get 0)
            assert ($ref.name == "sc-bootstrap")
        }],

        # ── build-federated-credential-body ───────────────────────────────────
        ["build-federated-credential-body: returns valid JSON", {
            let body = (build-federated-credential-body "https://issuer.example.com" "repo:myorg/myrepo:ref:main")
            let parsed = ($body | from json)
            assert ($parsed != null)
        }],
        ["build-federated-credential-body: name is ado-sc-bootstrap", {
            let body = (build-federated-credential-body "https://issuer" "subject")
            let parsed = ($body | from json)
            assert ($parsed.name == "ado-sc-bootstrap")
        }],
        ["build-federated-credential-body: issuer is preserved", {
            let body = (build-federated-credential-body "https://my-issuer.example.com" "subject")
            let parsed = ($body | from json)
            assert ($parsed.issuer == "https://my-issuer.example.com")
        }],
        ["build-federated-credential-body: subject is preserved", {
            let body = (build-federated-credential-body "https://issuer" "sc://org/proj/endpoint")
            let parsed = ($body | from json)
            assert ($parsed.subject == "sc://org/proj/endpoint")
        }],
        ["build-federated-credential-body: audiences contains AzureADTokenExchange", {
            let body = (build-federated-credential-body "https://issuer" "subject")
            let parsed = ($body | from json)
            assert ("api://AzureADTokenExchange" in $parsed.audiences)
        }],

        # ── format-onboarding-summary ─────────────────────────────────────────
        ["format-onboarding-summary: contains project name", {
            let s = (format-onboarding-summary "myproject" "group-uuid" "sub-uuid" "tenant-uuid")
            assert ($s | str contains "myproject")
        }],
        ["format-onboarding-summary: contains group object id", {
            let s = (format-onboarding-summary "myproject" "group-uuid-123" "sub-uuid" "tenant-uuid")
            assert ($s | str contains "group-uuid-123")
        }],
        ["format-onboarding-summary: contains subscription id", {
            let s = (format-onboarding-summary "myproject" "group-uuid" "sub-uuid-456" "tenant-uuid")
            assert ($s | str contains "sub-uuid-456")
        }],
        ["format-onboarding-summary: contains tenant id", {
            let s = (format-onboarding-summary "myproject" "group-uuid" "sub-uuid" "tenant-uuid-789")
            assert ($s | str contains "tenant-uuid-789")
        }],
        ["format-onboarding-summary: contains sc-bootstrap", {
            let s = (format-onboarding-summary "myproject" "group-uuid" "sub-uuid" "tenant-uuid")
            assert ($s | str contains "sc-bootstrap")
        }],
        ["format-onboarding-summary: contains PAT reminder", {
            let s = (format-onboarding-summary "myproject" "group-uuid" "sub-uuid" "tenant-uuid")
            assert ($s | str contains "Personal Access Token")
        }],
        ["format-onboarding-summary: contains PAT scope Code", {
            let s = (format-onboarding-summary "myproject" "group-uuid" "sub-uuid" "tenant-uuid")
            assert ($s | str contains "Code: Read")
        }],
        ["format-onboarding-summary: contains PAT scope Agent Pools", {
            let s = (format-onboarding-summary "myproject" "group-uuid" "sub-uuid" "tenant-uuid")
            assert ($s | str contains "Agent Pools")
        }],
        ["format-onboarding-summary: contains ADO Project Name label", {
            let s = (format-onboarding-summary "myproject" "group-uuid" "sub-uuid" "tenant-uuid")
            assert ($s | str contains "ADO Project Name")
        }],
        ["format-onboarding-summary: contains Admin Group Object ID label", {
            let s = (format-onboarding-summary "myproject" "group-uuid" "sub-uuid" "tenant-uuid")
            assert ($s | str contains "Admin Group Object ID")
        }],
    ]

    run-tests "onboarding" $tests
}

main
