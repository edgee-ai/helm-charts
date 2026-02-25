# jaeger

Helm chart for [Jaeger v2](https://www.jaegertracing.io/) — deployed in **query-only mode** as a trace UI. Traces are written directly to ClickHouse by external systems; this chart only runs the Jaeger query service on top of a remote ClickHouse database over HTTPS, bridged by a `socat` sidecar since the Jaeger ClickHouse storage backend does not yet support TLS natively.

## Architecture

```
[user / grafana]
  HTTP :16686 / gRPC :16685
        ↓
[jaeger container]  ←→  localhost:8123 (plain HTTP)
                                ↓
                        [socat sidecar]
                    TCP-LISTEN:8123 → OPENSSL:<host>:<port>
                                ↓
                   [remote ClickHouse HTTPS]
```

Jaeger runs in query-only mode — it does **not** receive or ingest traces. The `socat` sidecar runs inside the same pod and acts as a transparent HTTP→HTTPS proxy on `localhost:8123`. Jaeger's ClickHouse backend is pointed at that local address using the `http` protocol. TLS termination and certificate verification happen inside socat.

## Prerequisites

- Kubernetes 1.21+
- Helm 3.2+
- A reachable ClickHouse instance with HTTPS enabled
- ClickHouse credentials (see [Credentials](#credentials))

## Installing

```sh
helm install jaeger . \
  --set clickhouse.host=clickhouse.example.com \
  --set clickhouse.username=<user> \
  --set clickhouse.password=<pass>
```

## Credentials

Two options are available:

### Option A — inline values (recommended for Qovery)

Pass credentials directly as values. The chart creates a `Secret` from them:

```sh
helm install jaeger . \
  --set clickhouse.host=clickhouse.example.com \
  --set clickhouse.username=<user> \
  --set clickhouse.password=<pass>
```

### Option B — existing Secret

Pre-create a Secret, then reference it by name. No Secret is created by the chart:

```sh
kubectl create secret generic clickhouse-creds \
  --from-literal=username=<user> \
  --from-literal=password=<pass>

helm install jaeger . \
  --set clickhouse.host=clickhouse.example.com \
  --set clickhouse.existingSecret=clickhouse-creds
```

The Secret must contain exactly two keys: `username` and `password`. When `existingSecret` is set it takes precedence over `username`/`password`.

## Deploying on Qovery

Qovery's [Helm service](https://hub.qovery.com/docs/using-qovery/configuration/helm/) deploys this chart directly from the git repository. Credentials are injected at deploy time using Qovery's `qovery.env.*` macro, which substitutes environment variable or secret values into your values override before running `helm install/upgrade`.

### 1. Add environment variables / secrets on Qovery

In your Qovery environment, create the following secrets:

| Name | Value |
|------|-------|
| `CLICKHOUSE_HOST` | your ClickHouse hostname (no scheme) |
| `CLICKHOUSE_USERNAME` | ClickHouse username |
| `CLICKHOUSE_PASSWORD` | ClickHouse password |

### 2. Configure the Helm service

When creating the Helm service in Qovery:

- **Helm chart source**: Git Repository — point to this repository, branch `main`, root path `charts/jaeger`
- **Values override (Raw YAML)**:

```yaml
clickhouse:
  host: "qovery.env.CLICKHOUSE_HOST"
  username: "qovery.env.CLICKHOUSE_USERNAME"
  password: "qovery.env.CLICKHOUSE_PASSWORD"
```

Qovery replaces the `qovery.env.*` macros with the actual secret values before the chart is rendered, so credentials are never stored in plain text in the chart or Helm release history.

### 3. Expose ports via the Network tab

In the Qovery Helm service **Network** settings, add the ports you want to expose publicly:

| Service name | Service port | Protocol | Notes |
|---|---|---|---|
| `<release>-jaeger` | `16686` | HTTPS | Jaeger UI and HTTP query API |
| `<release>-jaeger` | `16685` | gRPC | Jaeger gRPC query API (optional) |

Qovery will provision an ingress, domain, and TLS certificate automatically.

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of Jaeger replicas | `1` |
| `strategy.type` | Deployment strategy type (`RollingUpdate` or `Recreate`) | `RollingUpdate` |
| `strategy.rollingUpdate.maxSurge` | Maximum number of pods that can be scheduled above the desired count during a rolling update | `1` |
| `strategy.rollingUpdate.maxUnavailable` | Maximum number of pods that can be unavailable during a rolling update | `0` |
| `image.repository` | Jaeger image repository | `docker.io/jaegertracing/jaeger` |
| `image.tag` | Jaeger image tag. Defaults to the chart `appVersion` when empty | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Image pull secrets | `[]` |
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the fully qualified resource name | `""` |
| `serviceAccount.create` | Create a ServiceAccount | `true` |
| `serviceAccount.name` | ServiceAccount name. Generated from fullname when empty | `""` |
| `serviceAccount.annotations` | Annotations on the ServiceAccount | `{}` |
| `podAnnotations` | Annotations on the pod | `{}` |
| `podSecurityContext` | Pod-level security context | `runAsNonRoot: true, runAsUser/Group: 10001` |
| `containerSecurityContext` | Container-level security context for the Jaeger container | `readOnlyRootFilesystem: true, no privilege escalation` |
| `resources` | CPU/memory requests and limits for the Jaeger container | see `values.yaml` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |
| `service.type` | Kubernetes Service type | `ClusterIP` |
| `service.annotations` | Annotations on the Service | `{}` |
| `clickhouse.host` | **Required.** Remote ClickHouse hostname (no scheme) | `""` |
| `clickhouse.port` | Remote ClickHouse HTTPS port | `8443` |
| `clickhouse.database` | ClickHouse database name | `jaeger` |
| `clickhouse.username` | ClickHouse username. Chart creates a Secret when set (use `qovery.env.*` on Qovery) | `""` |
| `clickhouse.password` | ClickHouse password. Chart creates a Secret when set (use `qovery.env.*` on Qovery) | `""` |
| `clickhouse.existingSecret` | Name of a pre-existing Secret with keys `username` and `password`. Takes precedence over `username`/`password` | `""` |
| `clickhouse.socat.image.repository` | socat sidecar image repository | `docker.io/alpine/socat` |
| `clickhouse.socat.image.tag` | socat sidecar image tag | `latest` |
| `clickhouse.socat.image.pullPolicy` | socat sidecar image pull policy | `IfNotPresent` |
| `clickhouse.socat.resources` | CPU/memory requests and limits for the socat sidecar | see `values.yaml` |
| `config` | Full Jaeger/OTel Collector configuration. Overriding this replaces the entire config | see `values.yaml` |

## Ports

| Port | Name | Description |
|------|------|-------------|
| 16686 | `jaeger-http` | Jaeger UI and HTTP query API |
| 16685 | `jaeger-grpc` | Jaeger gRPC query API |
| 13133 | `healthcheck` | Health check endpoint (`/status`) |

## Accessing the UI

With the default `ClusterIP` service type, use port-forward:

```sh
kubectl port-forward svc/jaeger 16686:16686
```

Then open `http://localhost:16686`.

## Upgrading

```sh
helm upgrade jaeger . \
  --set clickhouse.host=clickhouse.example.com \
  --set clickhouse.existingSecret=clickhouse-creds
```

The deployment uses a `RollingUpdate` strategy with `maxSurge: 1` and `maxUnavailable: 0` by default, ensuring zero-downtime rollouts. To switch back to terminating the old pod before starting the new one, set `strategy.type: Recreate`.
