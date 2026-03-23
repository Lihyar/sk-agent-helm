{{- define "customer.fullname" -}}
{{- include "java-service.fullname" . }}
{{- end }}

{{- define "customer.labels" -}}
{{- include "java-service.labels" . }}
{{- end }}

{{- define "customer.selectorLabels" -}}
{{- include "java-service.selectorLabels" . }}
{{- end }}