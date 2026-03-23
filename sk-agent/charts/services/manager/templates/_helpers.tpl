{{- define "manager.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "manager.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "manager.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}