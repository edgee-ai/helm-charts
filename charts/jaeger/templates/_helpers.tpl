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
*/}}
{{- define "jaeger.clickhouseAddress" -}}
{{- printf "%s:%v" (required "clickhouse.host must be set" .Values.clickhouse.host) .Values.clickhouse.port }}
{{- end }}

{{/*
Build the full Jaeger / OTel Collector config dict, then deep-merge
.Values.extraConfig on top so users can override or extend anything.
*/}}
{{- define "jaeger.config" -}}
{{- $clickhouseBackend := dict
  "protocol" .Values.clickhouse.protocol
  "addresses" (list (include "jaeger.clickhouseAddress" .))
  "database" .Values.clickhouse.database
  "auth" (dict
    "basic" (dict
      "username" "${env:CLICKHOUSE_USERNAME}"
      "password" "${env:CLICKHOUSE_PASSWORD}"
    )
  )
-}}
{{- if .Values.clickhouse.tls }}
{{- $clickhouseBackend = merge $clickhouseBackend (dict "tls" (dict "insecure_skip_verify" .Values.clickhouse.tlsInsecureSkipVerify)) }}
{{- end }}
{{- $config := dict
  "extensions" (dict
    "healthcheckv2" (dict
      "use_v2" true
      "http" (dict "endpoint" "0.0.0.0:13133")
    )
    "jaeger_storage" (dict
      "backends" (dict
        "clickhouse" (dict
          "clickhouse" $clickhouseBackend
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
