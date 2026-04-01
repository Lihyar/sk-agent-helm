{{/*
Java Service Deployment Template with ConfigMap Support
Usage: include "service.deployment" (dict "root" . "serviceName" "image" "port" "resources" "configMap" ...)
*/}}
{{- define "service.deployment" -}}
{{- $root := .root -}}
{{- $serviceName := .serviceName -}}
{{- $image := .image | default (dict "repository" "nginx" "tag" "latest") -}}
{{- $imagePullPolicy := .imagePullPolicy | default "IfNotPresent" -}}
{{- $port := .port | default 8080 -}}
{{- $resources := .resources | default (dict "requests" (dict "cpu" "500m" "memory" "1Gi") "limits" (dict "cpu" "2000m" "memory" "2Gi")) -}}
{{- $env := .env | default list -}}
{{- $command := .command -}}
{{- $args := .args -}}
{{- $replicas := .replicas | default 1 -}}
{{- $serviceType := .serviceType | default "ClusterIP" -}}
{{- $configMap := .configMap -}}
{{- $configMapVolume := .configMapVolume -}}
{{- $secretName := .secretName -}}
{{- $volumes := .volumes -}}
{{- $javaOpts := .javaOpts | default "-Xms512m -Xmx1g" -}}
{{- $profile := $root.Values.global.environment | default "dev" -}}
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
          imagePullPolicy: {{ $imagePullPolicy }}
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
              value: {{ $profile }}
            - name: JAVA_OPTS
              value: {{ $javaOpts }}
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            {{- range $env }}
            - {{ . | toYaml | nindent 14 }}
            {{- end }}
          {{- if or $configMap $secretName }}
          envFrom:
            {{- if $configMap }}
            - configMapRef:
                name: {{ $serviceName }}-config
            {{- end }}
            {{- if $secretName }}
            - secretRef:
                name: {{ $secretName }}
            {{- end }}
          {{- end }}
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: http
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: http
            initialDelaySeconds: 30
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          resources:
            {{- toYaml $resources | nindent 12 }}
          volumeMounts:
          {{- if $configMap }}
            - name: config
              mountPath: /config
          {{- end }}
          {{- if $configMapVolume }}
            {{- range $configMapVolume }}
            - name: {{ .name }}
              mountPath: {{ .mountPath }}
              readOnly: {{ .readOnly | default false }}
            {{- end }}
          {{- end }}
          {{- if $volumes }}
            {{- range $volumes }}
            - name: {{ .name }}
              mountPath: {{ .mountPath }}
            {{- end }}
          {{- end }}
      {{- if or $configMap $volumes }}
      volumes:
      {{- if $configMap }}
        - name: config
          configMap:
            name: {{ $serviceName }}-config
      {{- end }}
      {{- if $configMapVolume }}
        {{- range $configMapVolume }}
        - name: {{ .name }}
          configMap:
            name: {{ .configMapName }}
        {{- end }}
      {{- end }}
      {{- if $volumes }}
        {{- range $volumes }}
        - name: {{ .name }}
          persistentVolumeClaim:
            claimName: {{ .claimName }}
        {{- end }}
      {{- end }}
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