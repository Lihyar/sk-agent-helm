{{/*
Node.js Service Deployment Template
Usage: include "node.deployment" (dict "root" . "serviceName" "image" "port" "resources" ...)
*/}}
{{- define "node.deployment" -}}
{{- $root := .root -}}
{{- $serviceName := .serviceName -}}
{{- $image := .image | default (dict "repository" "node" "tag" "18-alpine") -}}
{{- $port := .port | default 3000 -}}
{{- $resources := .resources | default (dict "requests" (dict "cpu" "100m" "memory" "128Mi") "limits" (dict "cpu" "500m" "memory" "512Mi")) -}}
{{- $env := .env | default list -}}
{{- $replicas := .replicas | default 1 -}}
{{- $serviceType := .serviceType | default "ClusterIP" -}}
{{- $command := .command | default nil -}}
{{- $args := .args | default nil -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $serviceName }}
  labels:
    {{- include "sk-agent.labels" $root | nindent 4 }}
    layer: platform-web
    language: node
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
        layer: platform-web
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
            - name: NODE_ENV
              value: {{ $root.Values.global.environment }}
            {{- range $env }}
            - {{ . | toYaml | nindent 14 }}
            {{- end }}
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
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
