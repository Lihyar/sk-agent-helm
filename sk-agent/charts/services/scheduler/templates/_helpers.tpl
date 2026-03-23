{{- define "scheduler.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "scheduler.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "scheduler.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}