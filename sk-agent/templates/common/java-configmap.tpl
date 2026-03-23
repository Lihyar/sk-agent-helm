{{/*
Generate ConfigMap for Java Service application.yaml
Usage: include "java.configmap" (dict "root" . "serviceName" "applicationYaml" ...)
*/}}
{{- define "java.configmap" -}}
{{- $root := .root -}}
{{- $serviceName := .serviceName -}}
{{- $appConfig := .applicationYaml | default (dict "spring" (dict "application" "yaml")) -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $serviceName }}-config
  labels:
    {{- include "sk-agent.labels" $root | nindent 4 }}
data:
  application.yaml: |
    {{- toYaml $appConfig | nindent 4 }}
{{- end }}