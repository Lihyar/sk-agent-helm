{{- define "dashboard.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "dashboard.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "dashboard.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}