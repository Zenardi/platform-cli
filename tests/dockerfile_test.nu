use std assert
use ./helpers.nu *
use ../modules/dockerfile.nu *

def main [] {
    let tests = [
        ["generate-dockerfile: creates Dockerfile at instance root", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-dockerfile $base
            assert-file-exists ($base + "/Dockerfile")
        }],
        ["generate-dockerfile: Dockerfile contains FROM node:24-trixie-slim AS packages", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-dockerfile $base
            assert-file-contains ($base + "/Dockerfile") "FROM node:24-trixie-slim AS packages"
        }],
        ["generate-dockerfile: Dockerfile contains FROM node:24-trixie-slim AS build", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-dockerfile $base
            assert-file-contains ($base + "/Dockerfile") "FROM node:24-trixie-slim AS build"
        }],
        ["generate-dockerfile: Dockerfile contains chainguard final stage", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-dockerfile $base
            assert-file-contains ($base + "/Dockerfile") "FROM cgr.dev/chainguard/node:latest"
        }],
        ["generate-dockerfile: Dockerfile contains yarn tsc and backend build", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-dockerfile $base
            assert-file-contains ($base + "/Dockerfile") "RUN yarn tsc"
            assert-file-contains ($base + "/Dockerfile") "RUN yarn --cwd packages/backend build"
        }],
        ["generate-dockerfile: Dockerfile exposes port 7007", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-dockerfile $base
            assert-file-contains ($base + "/Dockerfile") "EXPOSE 7007"
        }],
        ["generate-dockerfile: Dockerfile contains CMD with node packages/backend", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-dockerfile $base
            assert-file-contains ($base + "/Dockerfile") "CMD [\"node\", \"packages/backend\""
        }],
        ["generate-dockerfile: Dockerfile is idempotent (running twice does not duplicate)", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-dockerfile $base
            generate-dockerfile $base
            let content = (open --raw ($base + "/Dockerfile"))
            let count = ($content | split row "FROM node:24-trixie-slim AS packages" | length)
            assert ($count == 2) "Expected exactly one FROM node:24-trixie-slim AS packages block"
        }],
        ["generate-dockerfile: --output places Dockerfile at custom path", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            let custom = ($base + "/custom/Dockerfile")
            mkdir ($base + "/custom")
            generate-dockerfile $base --output $custom
            assert-file-exists $custom
        }],
        ["generate-dockerfile: also creates .dockerignore at instance root", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-dockerfile $base
            assert-file-exists ($base + "/.dockerignore")
        }],
        ["generate-dockerfile: .dockerignore excludes node_modules and local configs", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-dockerfile $base
            assert-file-contains ($base + "/.dockerignore") "node_modules"
            assert-file-contains ($base + "/.dockerignore") "*.local.yaml"
        }],
        ["generate-dockerfile: .dockerignore does NOT exclude packages/*/src", {
            let base = (make-temp-dir)
            make-fake-backstage $base
            generate-dockerfile $base
            assert-file-not-contains ($base + "/.dockerignore") "packages/*/src"
        }],
    ]

    run-tests "dockerfile" $tests
}

main
