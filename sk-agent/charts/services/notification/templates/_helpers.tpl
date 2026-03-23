{{- define "notification.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "notification.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "notification.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}