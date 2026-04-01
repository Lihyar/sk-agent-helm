{{/*
Ingress Template
Usage: include "ingress" (dict "root" . "serviceName" "port" "ingress" ...)
*/}}
{{- define "ingress" -}}
{{- $root := .root -}}
{{- $serviceName := .serviceName -}}
{{- $port := .port | default 80 -}}
{{- $ingress := .ingress -}}
{{- if $ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $serviceName }}
  labels:
    {{- include "sk-agent.labels" $root | nindent 4 }}
  {{- with $ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if $ingress.className }}
  ingressClassName: {{ $ingress.className }}
  {{- end }}
  {{- if $ingress.tls }}
  tls:
    {{- range $ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range $ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $serviceName }}
                port:
                  number: {{ $port }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end }}
