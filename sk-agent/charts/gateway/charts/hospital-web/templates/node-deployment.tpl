{{/*
Node.js Service Deployment Template
Usage: include "node.deployment" (dict "root" . "serviceName" "image" "port" "resources" ...)
*/}}
{{- define "node.deployment" -}}
{{- $root := .root -}}
{{- $serviceName := .serviceName -}}
{{- $image := .image | default (dict "repository" "node" "tag" "18-alpine") -}}
{{- $port := .port | default 3000 -}}
{{- $resources := .resources | default (dict) -}}
{{- $replicas := .replicas | default 1 -}}
{{- $serviceType := .serviceType | default "ClusterIP" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $serviceName }}
  labels:
    app: {{ $serviceName }}
    layer: platform-web
    language: node
spec:
  replicas: {{ $replicas }}
  selector:
    matchLabels:
      app: {{ $serviceName }}
  template:
    metadata:
      labels:
        app: {{ $serviceName }}
        layer: platform-web
    spec:
      containers:
        - name: {{ $serviceName }}
          image: {{ printf "%s:%s" $image.repository $image.tag | quote }}
          imagePullPolicy: {{ $image.pullPolicy | default "IfNotPresent" }}
          ports:
            - name: http
              containerPort: {{ $port }}
              protocol: TCP
          {{- if $resources }}
          resources:
            {{- toYaml $resources | nindent 10 }}
          {{- end }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $serviceName }}
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
