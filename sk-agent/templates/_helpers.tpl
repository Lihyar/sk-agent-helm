{{/*
Expand the name of the chart.
*/}}
{{- define "sk-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "sk-agent.fullname" -}}
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
Create chart name and version
*/}}
{{- define "sk-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sk-agent.labels" -}}
helm.sh/chart: {{ include "sk-agent.chart" . }}
{{ include "sk-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sk-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sk-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "sk-agent.serviceAccountName" -}}
{{- if .Values.global.serviceAccount.create }}
{{- default (include "sk-agent.fullname" .) .Values.global.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.global.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get the architecture
*/}}
{{- define "sk-agent.architecture" -}}
{{- .Values.global.architecture | default "amd64" }}
{{- end }}

{{/*
Get the storage class
*/}}
{{- define "sk-agent.storageClass" -}}
{{- .Values.global.storageClass | default "manual-sc" }}
{{- end }}

{{/*
Common image pull secret
*/}}
{{- define "sk-agent.imagePullSecret" -}}
{{- if .Values.global.imagePullSecrets }}
imagePullSecrets:
  {{- range .Values.global.imagePullSecrets }}
  - name: {{ .name }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Common image pull secrets (alias)
*/}}
{{- define "sk-agent.imagePullSecrets" -}}
{{- include "sk-agent.imagePullSecret" . -}}
{{- end }}
