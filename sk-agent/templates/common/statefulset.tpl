{{/*
StatefulSet Template with PVC
Usage: include "statefulset" (dict "root" . "name" "serviceName" "image" "port" "resources" "persistence" ...)
*/}}
{{- define "statefulset" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $serviceName := .serviceName | default $name -}}
{{- $image := .image | default (dict "repository" "nginx" "tag" "latest") -}}
{{- $port := .port | default 8080 -}}
{{- $resources := .resources | default (dict "requests" (dict "cpu" "250m" "memory" "512Mi") "limits" (dict "cpu" "1000m" "memory" "2Gi")) -}}
{{- $persistence := .persistence | default (dict "enabled" true "size" "2Gi" "storageClass" "manual-sc") -}}
{{- $serviceType := .serviceType | default "ClusterIP" -}}
{{- $headless := .headless | default false -}}
{{- $env := .env | default list -}}
{{- $command := .command | default nil -}}
{{- $args := .args | default nil -}}
{{- $configmapName := .configmapName | default nil -}}
{{- $secretName := .secretName | default nil -}}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ $name }}
  labels:
    {{- include "sk-agent.labels" $root | nindent 4 }}
spec:
  serviceName: {{ $serviceName }}
  replicas: 1
  selector:
    matchLabels:
      {{- include "sk-agent.selectorLabels" $root | nindent 6 }}
      app: {{ $name }}
  template:
    metadata:
      labels:
        {{- include "sk-agent.selectorLabels" $root | nindent 8 }}
        app: {{ $name }}
    spec:
      {{- include "sk-agent.imagePullSecret" $root | nindent 6 }}
      serviceAccountName: {{ include "sk-agent.serviceAccountName" $root }}
      securityContext:
        {{- toYaml $root.Values.securityContext | nindent 8 }}
      initContainers:
        - name: init-permissions
          image: "busybox:1.36"
          command:
            - sh
            - -c
            - |
              mkdir -p /data && chown -R 1000:1000 /data
          volumeMounts:
            - name: data
              mountPath: /data
      containers:
        - name: {{ $name }}
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
            {{- range $env }}
            - {{ . | toYaml | nindent 14 }}
            {{- end }}
          livenessProbe:
            tcpSocket:
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            tcpSocket:
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          resources:
            {{- toYaml $resources | nindent 12 }}
          volumeMounts:
            - name: data
              mountPath: /data
      {{- with $root.Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $root.Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  {{- if and $persistence.enabled $persistence.size }}
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: {{ $persistence.storageClass | default "manual-sc" }}
        resources:
          requests:
            storage: {{ $persistence.size }}
  {{- end }}
---
{{- if $headless }}
apiVersion: v1
kind: Service
metadata:
  name: {{ $serviceName }}-headless
  labels:
    {{- include "sk-agent.labels" $root | nindent 4 }}
spec:
  clusterIP: None
  ports:
    - port: {{ $port }}
      targetPort: http
      name: http
  selector:
    app: {{ $name }}
{{- else }}
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
    app: {{ $name }}
{{- end }}
{{- end }}
