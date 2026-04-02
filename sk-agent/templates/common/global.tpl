{{/*
Global Configuration Template
Creates ServiceAccount, Registry Secret, and StorageClass
*/}}
{{- define "global.config" -}}
{{- $root := . }}
{{- if .Values.global.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.global.serviceAccount.name }}
  labels:
    {{- include "sk-agent.labels" . | nindent 4 }}
{{- end }}
---
{{- if and .Values.registry.enabled .Values.registry.server }}
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
  labels:
    {{- include "sk-agent.labels" . | nindent 4 }}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: {{ printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\"}}}" .Values.registry.server .Values.registry.username .Values.registry.password .Values.registry.email | b64enc | quote }}
{{- end }}
---
{{- if eq .Values.global.storageClass "local-path" }}
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
{{- end }}
{{- end }}
