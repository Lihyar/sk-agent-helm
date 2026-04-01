{{/*
Expand the name of the chart
*/}}
{{- define "database.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name
*/}}
{{- define "database.fullname" -}}
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
{{- define "database.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "database.labels" -}}
helm.sh/chart: {{ include "database.chart" . }}
{{ include "database.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "database.selectorLabels" -}}
app.kubernetes.io/name: {{ include "database.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Database type labels
*/}}
{{- define "database.typeLabel" -}}
{{- .Values.database.type }}
{{- end }}

{{/*
Get the database type specific image
*/}}
{{- define "database.image" -}}
{{- $type := .Values.database.type | lower }}
{{- if eq $type "mysql" }}
image:
  repository: {{ .Values.mysql.image.repository }}
  tag: {{ .Values.mysql.image.tag }}
  pullPolicy: {{ .Values.mysql.image.pullPolicy }}
{{- else if eq $type "postgresql" }}
image:
  repository: {{ .Values.postgresql.image.repository }}
  tag: {{ .Values.postgresql.image.tag }}
  pullPolicy: {{ .Values.postgresql.image.pullPolicy }}
{{- else if eq $type "kingbase" }}
image:
  repository: {{ .Values.kingbase.image.repository }}
  tag: {{ .Values.kingbase.image.tag }}
  pullPolicy: {{ .Values.kingbase.image.pullPolicy }}
{{- else }}
{{- fail "Unsupported database type. Must be one of: mysql, postgresql, kingbase" }}
{{- end }}
{{- end }}

{{/*
Get the database port based on type
*/}}
{{- define "database.port" -}}
{{- $type := .Values.database.type | lower }}
{{- if eq $type "mysql" }}
{{ .Values.mysql.service.port }}
{{- else if eq $type "postgresql" }}
{{ .Values.postgresql.service.port }}
{{- else if eq $type "kingbase" }}
{{ .Values.kingbase.service.port }}
{{- else }}
{{- fail "Unsupported database type" }}
{{- end }}
{{- end }}

{{/*
Get environment variables based on database type
*/}}
{{- define "database.env" -}}
{{- $type := .Values.database.type | lower }}
{{- if eq $type "mysql" }}
{{ .Values.mysql.env }}
{{- else if eq $type "postgresql" }}
{{ .Values.postgresql.env }}
{{- else if eq $type "kingbase" }}
{{ .Values.kingbase.env }}
{{- else }}
{{- list }}
{{- end }}
{{- end }}

{{/*
Get volumes based on database type
*/}}
{{- define "database.volumes" -}}
{{- $type := .Values.database.type | lower }}
{{- if eq $type "mysql" }}
{{ .Values.mysql.volumes }}
{{- else if eq $type "postgresql" }}
{{ .Values.postgresql.volumes }}
{{- else if eq $type "kingbase" }}
{{ .Values.kingbase.volumes }}
{{- else }}
{{- list }}
{{- end }}
{{- end }}

{{/*
Get resources based on database type
*/}}
{{- define "database.resources" -}}
{{- $type := .Values.database.type | lower }}
{{- if eq $type "mysql" }}
{{ .Values.mysql.resources }}
{{- else if eq $type "postgresql" }}
{{ .Values.postgresql.resources }}
{{- else if eq $type "kingbase" }}
{{ .Values.kingbase.resources }}
{{- else }}
{{- dict "requests" (dict "cpu" "100m" "memory" "256Mi") "limits" (dict "cpu" "500m" "memory" "1Gi") }}
{{- end }}
{{- end }}

{{/*
Get database name based on type
*/}}
{{- define "database.dbName" -}}
{{- $type := .Values.database.type | lower }}
{{- if eq $type "mysql" }}
{{ .Values.mysql.env | dict | get "MYSQL_DATABASE" "skagent" }}
{{- else if eq $type "postgresql" }}
{{ .Values.postgresql.env | dict | get "POSTGRES_DB" "skagent" }}
{{- else if eq $type "kingbase" }}
{{ .Values.kingbase.env | dict | get "KINGBASE_DATABASE" "skagent" }}
{{- else }}
skagent
{{- end }}
{{- end }}
