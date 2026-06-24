{{/*
Expand the name of the chart.
*/}}
{{- define "gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "gateway.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gateway.labels" -}}
helm.sh/chart: {{ include "gateway.chart" . }}
{{ include "gateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "gateway.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "gateway.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the image URI
*/}}
{{- define "gateway.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
Return the name of the config Secret (gateway.toml).
Uses existingConfigSecret if set, otherwise generates from fullname.
*/}}
{{- define "gateway.configSecretName" -}}
{{- if .Values.gateway.existingConfigSecret -}}
{{- .Values.gateway.existingConfigSecret -}}
{{- else -}}
{{- include "gateway.fullname" . }}-config
{{- end -}}
{{- end }}

{{/*
Return the name of the credentials Secret (LICENSE_KEY, EDGEE_SIGNATURE_KEY, provider_keys.toml).
Uses existingSecret if set, otherwise generates from fullname.
*/}}
{{- define "gateway.secretName" -}}
{{- if .Values.gateway.existingSecret -}}
{{- .Values.gateway.existingSecret -}}
{{- else -}}
{{- include "gateway.fullname" . }}-secret
{{- end -}}
{{- end }}

{{/*
Return the name of the docker-registry pull Secret.
Uses imageCredentials.existingSecret if set, otherwise generates from fullname.
*/}}
{{- define "gateway.registrySecretName" -}}
{{- if .Values.imageCredentials.existingSecret -}}
{{- .Values.imageCredentials.existingSecret -}}
{{- else -}}
{{- include "gateway.fullname" . }}-registry
{{- end -}}
{{- end }}

{{/*
Return the effective imagePullSecrets list, merging imageCredentials-managed secrets
with any explicitly provided imagePullSecrets entries.
*/}}
{{- define "gateway.imagePullSecrets" -}}
{{- $secrets := list -}}
{{- if or .Values.imageCredentials.create .Values.imageCredentials.existingSecret -}}
{{- $secrets = append $secrets (dict "name" (include "gateway.registrySecretName" .)) -}}
{{- end -}}
{{- range .Values.imagePullSecrets -}}
{{- $secrets = append $secrets . -}}
{{- end -}}
{{- if $secrets -}}
{{- toYaml $secrets -}}
{{- end -}}
{{- end }}

{{/*
Return true if provider keys should be mounted as a file.
True when inline providerKeysContent is set, or when providerKeysEnabled signals
that the existingSecret contains a provider_keys.toml key.
*/}}
{{- define "gateway.providerKeysMounted" -}}
{{- if or .Values.gateway.providerKeysContent .Values.gateway.providerKeysEnabled -}}
true
{{- end -}}
{{- end }}

{{/*
Return true if the gateway.toml config file should be mounted.
True when configContent is set inline or existingConfigSecret is provided.
*/}}
{{- define "gateway.configMounted" -}}
{{- if or .Values.gateway.configContent .Values.gateway.existingConfigSecret -}}
true
{{- end -}}
{{- end }}
