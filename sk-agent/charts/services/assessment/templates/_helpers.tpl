{{- define "assessment.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "assessment.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "assessment.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}