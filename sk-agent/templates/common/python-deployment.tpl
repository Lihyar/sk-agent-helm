{{/*
Python Service Deployment Template
Usage: include "python.deployment" (dict "root" . "serviceName" "image" "port" "command" "resources" ...)
*/}}
{{- define "python.deployment" -}}
{{- $root := .root -}}
{{- $serviceName := .serviceName -}}
{{- $image := .image | default (dict "repository" "python" "tag" "3.11") -}}
{{- $port := .port | default 8080 -}}
{{- $resources := .resources | default $root.Values.services.agent.resources -}}
{{- $env := .env | default list -}}
{{- $command := .command | default (list "python" "-m" "uvicorn" "app.main:app" "--host" "0.0.0.0" "--port" (quote $port)) -}}
{{- $replicas := .replicas | default 1 -}}
{{- $serviceType := .serviceType | default "ClusterIP" -}}
{{- $configmap := .configmap | default nil -}}
{{- $secretName := .secretName | default nil -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $serviceName }}
  labels:
    {{- include "sk-agent.labels" $root | nindent 4 }}
    layer: platform-services
    language: python
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
          command:
            {{- range $command }}
            - {{ . }}
            {{- end }}
          env:
            - name: ENVIRONMENT
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
          {{- if $configmap }}
          volumeMounts:
            - name: config
              mountPath: /app/config
              readOnly: true
      volumes:
        - name: config
          configMap:
            name: {{ $configmap }}
          {{- end }}
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
