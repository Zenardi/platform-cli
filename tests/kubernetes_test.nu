use std assert
use ./helpers.nu *
use ../modules/kubernetes.nu *

def main [] {
    let tests = [
        # ── File creation ────────────────────────────────────────────────────
        ["generate-k8s-manifests: creates k8s/ directory at instance root", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert (($base + "/k8s") | path exists) "k8s/ directory should exist"
        }],
        ["generate-k8s-manifests: creates deployment.yaml", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-exists ($base + "/k8s/deployment.yaml")
        }],
        ["generate-k8s-manifests: creates service.yaml", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-exists ($base + "/k8s/service.yaml")
        }],
        ["generate-k8s-manifests: creates ingress.yaml", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-exists ($base + "/k8s/ingress.yaml")
        }],
        ["generate-k8s-manifests: creates backstage-secrets.example.yaml", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-exists ($base + "/k8s/backstage-secrets.example.yaml")
        }],

        # ── deployment.yaml content ──────────────────────────────────────────
        ["generate-k8s-manifests: deployment uses correct apiVersion and kind", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/deployment.yaml") "apiVersion: apps/v1"
            assert-file-contains ($base + "/k8s/deployment.yaml") "kind: Deployment"
        }],
        ["generate-k8s-manifests: deployment targets port 7007", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/deployment.yaml") "containerPort: 7007"
        }],
        ["generate-k8s-manifests: deployment uses default image", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/deployment.yaml") "image: docker.io/YOUR_DOCKERHUB_USER/backstage:latest"
        }],
        ["generate-k8s-manifests: deployment uses custom --image", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base --image "ghcr.io/myorg/backstage:v1.0"
            assert-file-contains ($base + "/k8s/deployment.yaml") "image: ghcr.io/myorg/backstage:v1.0"
        }],
        ["generate-k8s-manifests: deployment uses default namespace backstage", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/deployment.yaml") "namespace: backstage"
        }],
        ["generate-k8s-manifests: deployment uses custom --namespace", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base --namespace "my-ns"
            assert-file-contains ($base + "/k8s/deployment.yaml") "namespace: my-ns"
        }],
        ["generate-k8s-manifests: deployment uses default replicas 2", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/deployment.yaml") "replicas: 2"
        }],
        ["generate-k8s-manifests: deployment uses custom --replicas", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base --replicas 3
            assert-file-contains ($base + "/k8s/deployment.yaml") "replicas: 3"
        }],
        ["generate-k8s-manifests: deployment has readiness, liveness and startup probes", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/deployment.yaml") "readinessProbe:"
            assert-file-contains ($base + "/k8s/deployment.yaml") "livenessProbe:"
            assert-file-contains ($base + "/k8s/deployment.yaml") "startupProbe:"
        }],
        ["generate-k8s-manifests: deployment has resource requests and limits", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/deployment.yaml") "resources:"
            assert-file-contains ($base + "/k8s/deployment.yaml") "requests:"
            assert-file-contains ($base + "/k8s/deployment.yaml") "limits:"
        }],
        ["generate-k8s-manifests: deployment references backstage-secrets", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/deployment.yaml") "backstage-secrets"
        }],

        # ── service.yaml content ─────────────────────────────────────────────
        ["generate-k8s-manifests: service is ClusterIP on port 80 -> 7007", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/service.yaml") "type: ClusterIP"
            assert-file-contains ($base + "/k8s/service.yaml") "port: 80"
            assert-file-contains ($base + "/k8s/service.yaml") "targetPort: http"
        }],

        # ── ingress.yaml content ─────────────────────────────────────────────
        ["generate-k8s-manifests: ingress uses default host", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/ingress.yaml") "host: backstage.example.com"
        }],
        ["generate-k8s-manifests: ingress uses custom --host", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base --host "backstage.mycompany.io"
            assert-file-contains ($base + "/k8s/ingress.yaml") "host: backstage.mycompany.io"
        }],
        ["generate-k8s-manifests: ingress uses traefik and TLS", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/ingress.yaml") "traefik"
            assert-file-contains ($base + "/k8s/ingress.yaml") "tls:"
        }],

        # ── secrets example ──────────────────────────────────────────────────
        ["generate-k8s-manifests: secrets example contains POSTGRES_HOST placeholder", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/backstage-secrets.example.yaml") "POSTGRES_HOST:"
        }],
        ["generate-k8s-manifests: secrets example contains AUTH_GITHUB placeholders", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            assert-file-contains ($base + "/k8s/backstage-secrets.example.yaml") "AUTH_GITHUB_CLIENT_ID:"
        }],

        # ── idempotency ──────────────────────────────────────────────────────
        ["generate-k8s-manifests: is idempotent (second run overwrites cleanly)", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-k8s-manifests $base
            generate-k8s-manifests $base --image "img:v2"
            assert-file-contains ($base + "/k8s/deployment.yaml") "image: img:v2"
        }],
    ]

    run-tests "kubernetes" $tests
}

main
