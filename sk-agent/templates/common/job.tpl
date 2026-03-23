{{/*
Init Job Template - One-time Job for data initialization
Usage: include "init.job" (dict "root" . "jobName" "image" "command" "resources" ...)
*/}}
{{- define "init.job" -}}
{{- $root := .root -}}
{{- $jobName := .jobName -}}
{{- $image := .image | default (dict "repository" "openjdk" "tag" "17-slim") -}}
{{- $resources := .resources | default $root.Values.services.initData.resources -}}
{{- $env := .env | default list -}}
{{- $command := .command | default nil -}}
{{- $args := .args | default nil -}}
{{- $restartPolicy := .restartPolicy | default "OnFailure" -}}
{{- $backoffLimit := .backoffLimit | default 4 -}}
{{- $ttlSecondsAfterFinished := .ttlSecondsAfterFinished | default 300 -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $jobName }}
  labels:
    {{- include "sk-agent.labels" $root | nindent 4 }}
    layer: platform-services
    type: init-job
spec:
  backoffLimit: {{ $backoffLimit }}
  ttlSecondsAfterFinished: {{ $ttlSecondsAfterFinished }}
  template:
    metadata:
      labels:
        {{- include "sk-agent.selectorLabels" $root | nindent 8 }}
        app: {{ $jobName }}
        layer: platform-services
        type: init-job
    spec:
      {{- include "sk-agent.imagePullSecret" $root | nindent 6 }}
      serviceAccountName: {{ include "sk-agent.serviceAccountName" $root }}
      restartPolicy: {{ $restartPolicy }}
      securityContext:
        {{- toYaml $root.Values.securityContext | nindent 8 }}
      containers:
        - name: {{ $jobName }}
          image: {{ printf "%s:%s" $image.repository $image.tag | quote }}
          imagePullPolicy: {{ $image.pullPolicy | default "IfNotPresent" }}
          {{- if $command }}
          command:
            {{- range $command }}
            - {{ . }}
            {{- end }}
          {{- end }}
          {{- if $args }}
          args:
            {{- range $args }}
            - {{ . }}
            {{- end }}
          {{- end }}
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: {{ $root.Values.global.environment }}
            {{- range $env }}
            - {{ . | toYaml | nindent 14 }}
            {{- end }}
          resources:
            {{- toYaml $resources | nindent 12 }}
      {{- with $root.Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
