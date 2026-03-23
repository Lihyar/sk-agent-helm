{{- define "hospital.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "hospital.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "hospital.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}