{{- define "domain.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "domain.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "domain.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}