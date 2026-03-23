{{- define "tcm.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "tcm.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "tcm.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}