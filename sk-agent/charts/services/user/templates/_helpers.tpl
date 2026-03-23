{{- define "user.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "user.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "user.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}