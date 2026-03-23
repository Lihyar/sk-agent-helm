{{- define "storage.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "storage.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "storage.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}