{{- define "operation.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "operation.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "operation.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}