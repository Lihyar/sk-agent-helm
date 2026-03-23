{{/*
Java Service Deployment Template
Usage: include "java.deployment" (dict "root" . "serviceName" "user" "image" "port" "resources" ...)
*/}}
{{- define "java.deployment" -}}
{{- $root := .root -}}
{{- $serviceName := .serviceName -}}
{{- $image := .image | default (dict "repository" "nginx" "tag" "latest") -}}
{{- $port := .port | default 8080 -}}
{{- $resources := .resources | default (dict "requests" (dict "cpu" "500m" "memory" "1Gi") "limits" (dict "cpu" "2000m" "memory" "2Gi")) -}}
{{- $env := .env | default list -}}
{{- $command := .command | default nil -}}
{{- $args := .args | default nil -}}
{{- $replicas := .replicas | default 1 -}}
{{- $serviceType := .serviceType | default "ClusterIP" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $serviceName }}
  labels:
    {{- include "sk-agent.labels" $root | nindent 4 }}
    layer: platform-services
    language: java
spec:
  replicas: {{ $replicas }}
  selector:
    matchLabels:
      {{- include "sk-agent.selectorLabels" $root | nindent 6 }}
      app: {{ $serviceName }}
  template:
    metadata:
      labels:
        {{- include "sk-agent.selectorLabels" $root | nindent 8 }}
        app: {{ $serviceName }}
        layer: platform-services
    spec:
      {{- include "sk-agent.imagePullSecret" $root | nindent 6 }}
      serviceAccountName: {{ include "sk-agent.serviceAccountName" $root }}
      securityContext:
        {{- toYaml $root.Values.securityContext | nindent 8 }}
      containers:
        - name: {{ $serviceName }}
          image: {{ printf "%s:%s" $image.repository $image.tag | quote }}
          imagePullPolicy: {{ $image.pullPolicy | default "IfNotPresent" }}
          ports:
            - name: http
              containerPort: {{ $port }}
              protocol: TCP
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
          livenessProbe:
            httpGet:
              path: /actuator/health
              port: http
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          resources:
            {{- toYaml $resources | nindent 12 }}
      {{- with $root.Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $root.Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $serviceName }}
  labels:
    {{- include "sk-agent.labels" $root | nindent 4 }}
spec:
  type: {{ $serviceType }}
  ports:
    - port: {{ $port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app: {{ $serviceName }}
{{- end }}
