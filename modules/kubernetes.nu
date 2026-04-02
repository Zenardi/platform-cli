# kubernetes module — generates production-ready Kubernetes manifests for Backstage

use ./utils.nu

# ── Manifest content builders ────────────────────────────────────────────────

def k8s-deployment [namespace: string, image: string, replicas: int] {
    $"apiVersion: apps/v1
kind: Deployment
metadata:
  name: backstage
  namespace: ($namespace)
  labels:
    app.kubernetes.io/name: backstage
spec:
  replicas: ($replicas)
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app.kubernetes.io/name: backstage
  template:
    metadata:
      labels:
        app.kubernetes.io/name: backstage
    spec:
      containers:
        - name: backstage
          image: ($image)
          imagePullPolicy: Always
          ports:
            - containerPort: 7007
              name: http
          envFrom:
            - secretRef:
                name: backstage-secrets
          readinessProbe:
            tcpSocket:
              port: http
            initialDelaySeconds: 20
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 6
          livenessProbe:
            tcpSocket:
              port: http
            initialDelaySeconds: 60
            periodSeconds: 20
            timeoutSeconds: 3
            failureThreshold: 3
          startupProbe:
            tcpSocket:
              port: http
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 30
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: \"1\"
              memory: 1Gi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
      securityContext:
        runAsNonRoot: true
      terminationGracePeriodSeconds: 30
"
}

def k8s-service [namespace: string] {
    $"apiVersion: v1
kind: Service
metadata:
  name: backstage
  namespace: ($namespace)
  labels:
    app.kubernetes.io/name: backstage
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: backstage
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
"
}

def k8s-ingress [namespace: string, host: string] {
    $"apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backstage
  namespace: ($namespace)
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: \"true\"
spec:
  ingressClassName: traefik
  rules:
    - host: ($host)
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backstage
                port:
                  name: http
  tls:
    - hosts:
        - ($host)
      secretName: backstage-tls
"
}

def k8s-secrets-example [namespace: string] {
    "apiVersion: v1
kind: Secret
metadata:
  name: backstage-secrets
  namespace: " + $namespace + "
type: Opaque
stringData:
  # Public URLs — can be moved to ConfigMap if preferred
  APP_BASE_URL: https://backstage.example.com
  BACKEND_BASE_URL: https://backstage-api.example.com
  PORT: \"7007\"

  # Backstage backend service-to-service secret
  BACKEND_SECRET: replace-with-a-long-random-secret

  # PostgreSQL
  POSTGRES_HOST: postgres-rw.database.svc.cluster.local
  POSTGRES_PORT: \"5432\"
  POSTGRES_USER: backstage
  POSTGRES_PASSWORD: replace-with-postgres-password

  # GitHub integration and auth provider
  GITHUB_TOKEN: replace-with-github-token
  AUTH_GITHUB_CLIENT_ID: replace-with-github-oauth-client-id
  AUTH_GITHUB_CLIENT_SECRET: replace-with-github-oauth-client-secret

  # Microsoft auth provider
  AUTH_MICROSOFT_CLIENT_ID: replace-with-microsoft-client-id
  AUTH_MICROSOFT_CLIENT_SECRET: replace-with-microsoft-client-secret
  AUTH_MICROSOFT_TENANT_ID: replace-with-microsoft-tenant-id

  # Azure DevOps integration — service principal + user-assigned managed identity
  AZURE_APP_REGISTRATION_CLIENT_ID: replace-with-app-registration-client-id
  AZURE_MANAGED_IDENTITY_CLIENT_ID: replace-with-user-assigned-managed-identity-client-id
  AZURE_TENANT_ID: replace-with-entra-tenant-id
"
}

# Generate Kubernetes manifests (Deployment, Service, Ingress, Secrets example) for a Backstage instance.
#
# Creates a k8s/ directory at <instance_path> containing:
#   deployment.yaml              — backend Deployment (2 replicas, health probes, resource limits)
#   service.yaml                 — ClusterIP Service on port 80
#   ingress.yaml                 — Traefik Ingress with TLS
#   backstage-secrets.example.yaml — Secret template with all required env vars
export def generate-k8s-manifests [
    instance_path: string                           # Path to the Backstage instance root
    --namespace: string = "backstage"               # Kubernetes namespace
    --image: string = "docker.io/YOUR_DOCKERHUB_USER/backstage:latest"  # Container image
    --host: string = "backstage.example.com"        # Ingress hostname
    --replicas: int = 2                             # Number of Deployment replicas
] {
    let expanded = ($instance_path | path expand)

    if not ($expanded | path exists) {
        utils print-error $"Instance path not found: ($expanded)"
        exit 1
    }

    let k8s_dir = $expanded + "/k8s"
    mkdir $k8s_dir

    # Write manifests
    (k8s-deployment $namespace $image $replicas) | save --force ($k8s_dir + "/deployment.yaml")
    utils print-success "k8s/deployment.yaml"

    (k8s-service $namespace) | save --force ($k8s_dir + "/service.yaml")
    utils print-success "k8s/service.yaml"

    (k8s-ingress $namespace $host) | save --force ($k8s_dir + "/ingress.yaml")
    utils print-success "k8s/ingress.yaml"

    (k8s-secrets-example $namespace) | save --force ($k8s_dir + "/backstage-secrets.example.yaml")
    utils print-success "k8s/backstage-secrets.example.yaml"

    print ""
    utils print-info $"Manifests written to ($k8s_dir)"
    utils print-warning "Edit backstage-secrets.example.yaml, rename it to backstage-secrets.yaml, and apply with:"
    utils print-info "  kubectl apply -f k8s/"
}
