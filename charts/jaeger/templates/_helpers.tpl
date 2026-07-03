{{/*
Expand the name of the chart.
*/}}
{{- define "jaeger.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "jaeger.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart label value (name-version).
*/}}
{{- define "jaeger.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "jaeger.labels" -}}
helm.sh/chart: {{ include "jaeger.chart" . }}
{{ include "jaeger.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — used in matchLabels and pod template labels.
*/}}
{{- define "jaeger.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jaeger.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name to use.
*/}}
{{- define "jaeger.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "jaeger.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image reference (repository:tag).
*/}}
{{- define "jaeger.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
socat sidecar image reference.
*/}}
{{- define "jaeger.socat.image" -}}
{{- printf "%s:%s" .Values.clickhouse.socat.image.repository .Values.clickhouse.socat.image.tag }}
{{- end }}

{{/*
Name of the Secret holding ClickHouse credentials.
Uses existingSecret when set; otherwise falls back to the chart-managed Secret.
*/}}
{{- define "jaeger.clickhouseSecretName" -}}
{{- if .Values.clickhouse.existingSecret -}}
{{- .Values.clickhouse.existingSecret -}}
{{- else -}}
{{- include "jaeger.fullname" . }}-clickhouse
{{- end -}}
{{- end }}

{{/*
ClickHouse address Jaeger should connect to.
When TLS is enabled the socat sidecar listens on localhost:8123 and forwards
to the real endpoint, so Jaeger always uses plain HTTP on localhost:8123.
When TLS is disabled Jaeger connects directly.
*/}}
{{- define "jaeger.clickhouseAddress" -}}
{{- if .Values.clickhouse.tls -}}
localhost:8123
{{- else -}}
{{- printf "%s:%v" (required "clickhouse.host must be set" .Values.clickhouse.host) .Values.clickhouse.port }}
{{- end -}}
{{- end }}

{{/*
Build the full Jaeger / OTel Collector config dict, then deep-merge
.Values.extraConfig on top so users can override or extend anything.
*/}}
{{- define "jaeger.config" -}}
{{- $config := dict
  "extensions" (dict
    "healthcheckv2" (dict
      "use_v2" true
      "http" (dict "endpoint" "0.0.0.0:13133")
    )
    "jaeger_storage" (dict
      "backends" (dict
        "clickhouse" (dict
          "clickhouse" (dict
            "protocol" "http"
            "addresses" (list (include "jaeger.clickhouseAddress" .))
            "database" .Values.clickhouse.database
            "auth" (dict
              "basic" (dict
                "username" "${env:CLICKHOUSE_USERNAME}"
                "password" "${env:CLICKHOUSE_PASSWORD}"
              )
            )
          )
        )
      )
    )
    "jaeger_query" (dict
      "storage" (dict "traces" "clickhouse")
      "http" (dict "endpoint" "0.0.0.0:16686")
      "grpc" (dict "endpoint" "0.0.0.0:16685")
    )
  )
  "receivers" (dict "nop" nil)
  "exporters" (dict "nop" nil)
  "service" (dict
    "extensions" (list "healthcheckv2" "jaeger_storage" "jaeger_query")
    "telemetry" (dict "logs" (dict "level" "info"))
    "pipelines" (dict
      "traces" (dict
        "receivers" (list "nop")
        "processors" (list)
        "exporters" (list "nop")
      )
    )
  )
-}}
{{- mergeOverwrite $config .Values.extraConfig | toYaml }}
{{- end }}
