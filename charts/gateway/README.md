# gateway

A Helm chart for deploying the [Edgee OnPrem AI Gateway](https://github.com/edgee-ai/gateway).

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- A read access token for the private `ghcr.io/edgee-ai/gateway` image (or your own mirror)
- A license key and signature key (`gateway.licenseKey` / `gateway.signatureKey`), available from the Edgee Console under **Org settings → On-Premise**

## Installing the chart

```sh
helm repo add edgee-ai https://edgee-ai.github.io/helm-charts
helm repo update
helm install my-gateway edgee-ai/gateway -f my-values.yaml
```

## Uninstalling the chart

```sh
helm uninstall my-gateway
```

## Deployment modes

The gateway runs in one of two modes, controlled by `gateway.apiSync.enabled`:

- **Air-gapped** (default) — all config is loaded from local files. `gateway.configContent` (or `gateway.existingConfigSecret`) is required. Only LLM provider endpoints are contacted, never the Edgee API.
- **Connected** — set `gateway.apiSync.enabled: true` to have the gateway pull its full config (models, API keys, provider credentials) from the Edgee API on boot and every `gateway.apiSync.intervalSecs` seconds. `gateway.configContent` becomes an optional bootstrap only. Requires `gateway.licenseKey`.

### Air-gapped example

```yaml
gateway:
  licenseKey: "<jwt-issued-by-edgee>"
  signatureKey: "<org-specific-signing-key>"
  providerKeysContent: |
    openai    = "sk-proj-..."
    anthropic = "sk-ant-..."
  configContent: |
    [api_keys."sk-your-gateway-key-here"]
    id              = "key-001"
    organization_id = "org-001"
    models          = []
    max_usage       = -1
    active          = true
    expires_at      = 9999999999
```

### Connected mode example

```yaml
gateway:
  licenseKey: "<jwt-issued-by-edgee>"
  signatureKey: "<org-specific-signing-key>"
  apiSync:
    enabled: true
```

## Image pull credentials

`ghcr.io/edgee-ai/gateway` is a private registry. Pick one:

- **Inline credentials** — the chart creates the pull secret for you:
  ```yaml
  imageCredentials:
    create: true
    username: <github-username>
    password: <ghcr-pat-with-read:packages-scope>
  ```
- **Pre-existing docker-registry Secret**:
  ```yaml
  imageCredentials:
    existingSecret: my-ghcr-pull-secret
  ```
- **Standard Helm `imagePullSecrets`**:
  ```yaml
  imagePullSecrets:
    - name: my-ghcr-pull-secret
  ```

## Bringing your own Secret

Instead of letting the chart generate the credentials Secret from `gateway.licenseKey` / `gateway.signatureKey` / `gateway.providerKeysContent`, you can reference one you manage yourself:

```yaml
gateway:
  existingSecret: my-gateway-secret   # keys: LICENSE_KEY, EDGEE_SIGNATURE_KEY
  providerKeysEnabled: true           # set if the Secret also has a provider_keys.toml key
```

The same applies to the `gateway.toml` config file via `gateway.existingConfigSecret` (must contain a `gateway.toml` key).

## Values

| Key | Default | Description |
|---|---|---|
| `replicaCount` | `1` | Number of gateway pods |
| `strategy.type` | `RollingUpdate` | Deployment update strategy |
| `strategy.rollingUpdate.maxSurge` | `1` | Max surge during rollout |
| `strategy.rollingUpdate.maxUnavailable` | `0` | Max unavailable during rollout |
| `nameOverride` | `""` | Override the chart name used in generated resource names |
| `fullnameOverride` | `""` | Override the fully qualified app name |
| `image.repository` | `ghcr.io/edgee-ai/gateway` | Image repository |
| `image.tag` | `""` | Image tag; defaults to the chart's `appVersion` |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `imageCredentials.create` | `false` | Create a docker-registry Secret from inline credentials |
| `imageCredentials.registry` | `ghcr.io` | Registry host for the generated pull secret |
| `imageCredentials.username` | `""` | Registry username (with `create: true`) |
| `imageCredentials.password` | `""` | Registry password/PAT (with `create: true`) |
| `imageCredentials.existingSecret` | `""` | Use a pre-existing docker-registry Secret instead of creating one |
| `imagePullSecrets` | `[]` | Additional pull secrets, standard Helm format |
| `serviceAccount.create` | `true` | Create a ServiceAccount |
| `serviceAccount.annotations` | `{}` | ServiceAccount annotations |
| `serviceAccount.name` | `""` | ServiceAccount name; generated from the fullname if unset |
| `podAnnotations` | `{}` | Extra pod annotations |
| `podSecurityContext` | `runAsNonRoot: true, runAsUser: 65534, runAsGroup: 65534` | Pod-level security context |
| `containerSecurityContext` | `allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, drop: [ALL]` | Container-level security context |
| `resources.requests.cpu` | `250m` | CPU request |
| `resources.requests.memory` | `256Mi` | Memory request |
| `resources.limits.memory` | `1Gi` | Memory limit |
| `nodeSelector` | `{}` | Node selector |
| `tolerations` | `[]` | Tolerations |
| `affinity` | `{}` | Affinity rules |
| `terminationGracePeriodSeconds` | `30` | Termination grace period |
| `service.type` | `ClusterIP` | Kubernetes Service type |
| `service.annotations` | `{}` | Service annotations |
| `ingress.enabled` | `false` | Create an Ingress resource |
| `ingress.className` | `""` | Ingress class name |
| `ingress.annotations` | `{}` | Ingress annotations |
| `ingress.hosts` | see `values.yaml` | Ingress host/path rules |
| `ingress.tls` | `[]` | Ingress TLS configuration |
| `gateway.env` | `prod` | Deployment environment identifier (`prod`, `staging`, `dev`); sets `ENV` |
| `gateway.configContent` | `""` | Inline `gateway.toml` content; chart creates a Secret for it. Required in air-gapped mode |
| `gateway.existingConfigSecret` | `""` | Reference a pre-existing Secret (key `gateway.toml`) instead of `configContent` |
| `gateway.licenseKey` | `""` | `LICENSE_KEY` env var. Required in all non-dev builds. Get it from the Edgee Console (Org settings → On-Premise) |
| `gateway.signatureKey` | `""` | `EDGEE_SIGNATURE_KEY` env var. Required in production. Get it from the Edgee Console (Org settings → On-Premise) |
| `gateway.providerKeysContent` | `""` | Contents of `provider_keys.toml` (flat TOML, no section header) |
| `gateway.existingSecret` | `""` | Reference a pre-existing Secret (keys `LICENSE_KEY`, `EDGEE_SIGNATURE_KEY`) instead of the above |
| `gateway.providerKeysEnabled` | `false` | Set when `existingSecret` also carries a `provider_keys.toml` key to mount |
| `gateway.apiSync.enabled` | `false` | Enable connected mode (periodic config sync from the Edgee API) |
| `gateway.apiSync.intervalSecs` | `15` | Sync poll interval in seconds (connected mode only) |
| `gateway.telemetry.enabled` | `false` | Enable OTLP trace export |
| `gateway.telemetry.otlpEndpoint` | `http://localhost:4318` | OTLP collector endpoint for traces |
| `gateway.usage.otlpEndpoint` | `""` | OTLP endpoint for usage logs. If unset and `apiSync.enabled` + `licenseKey` are both set, defaults to `https://onprem-log.edgee.ai/v1/logs` with an `Authorization: Bearer <licenseKey>` header. Set to override with a self-hosted collector |
| `gateway.usage.otlpHeaders` | `""` | Extra headers for the usage OTLP endpoint, format `k1=v1,k2=v2` |
| `gateway.extraEnv` | `{}` | Arbitrary extra environment variables (e.g. `RUST_LOG: info`) |

## Health checks

The gateway exposes a single `GET /status` endpoint used for the startup, liveness, and readiness probes, returning version and build metadata.

## OpenAI-compatible API

Once deployed, the gateway is reachable in-cluster at `<release-name>-gateway.<namespace>.svc.cluster.local:8080` and speaks the OpenAI-compatible chat completions API.
