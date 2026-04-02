{{/*
StatefulSet Template with Multiple PVC Support
Usage: include "statefulset" (dict "root" . "name" "image" "volumes" "resources" ...)
Example volumes:
  - name: data
    mountPath: /var/lib/mysql
    size: 10Gi
    storageClass: standard
  - name: config
    mountPath: /etc/mysql/conf.d
    size: 1Gi
    storageClass: standard
*/}}
{{- define "statefulset" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $serviceName := .serviceName | default $name -}}
{{- $image := .image | default (dict "repository" "nginx" "tag" "latest") -}}
{{- $imagePullPolicy := .imagePullPolicy | default "IfNotPresent" -}}
{{- $port := .port | default 8080 -}}
{{- $resources := .resources | default (dict "requests" (dict "cpu" "250m" "memory" "512Mi") "limits" (dict "cpu" "1000m" "memory" "2Gi")) -}}
{{- $volumes := .volumes | default (list (dict "name" "data" "mountPath" "/data" "size" "2Gi" "storageClass" "manual-sc")) -}}
{{- $serviceType := .serviceType | default "ClusterIP" -}}
{{- $nodePort := .nodePort | default 0 -}}
{{- $headless := .headless | default false -}}
{{- $env := .env | default list -}}
{{- $command := .command -}}
{{- $args := .args -}}
{{- $initCommand := .initCommand -}}
{{- $configmapName := .configmapName -}}
{{- $secretName := .secretName -}}
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
      {{- if $initCommand }}
      initContainers:
        - name: init-permissions
          image: "busybox:1.36"
          command:
            - sh
            - -c
            - |
              {{ $initCommand }}
          volumeMounts:
          {{- range $volumes }}
            - name: {{ .name }}
              mountPath: {{ .mountPath }}
          {{- end }}
      {{- end }}
      containers:
        - name: {{ $name }}
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
          {{- if or $configmapName $secretName }}
          envFrom:
            {{- if $configmapName }}
            - configMapRef:
                name: {{ $configmapName }}
            {{- end }}
            {{- if $secretName }}
            - secretRef:
                name: {{ $secretName }}
            {{- end }}
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
          {{- range $volumes }}
            - name: {{ .name }}
              mountPath: {{ .mountPath }}
          {{- end }}
      {{- with $root.Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $root.Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  {{- if $volumes }}
  volumeClaimTemplates:
  {{- range $volumes }}
    - metadata:
        name: {{ .name }}
      spec:
        accessModes:
          - {{ .accessMode | default "ReadWriteOnce" }}
        storageClassName: {{ .storageClass | default "manual-sc" }}
        resources:
          requests:
            storage: {{ .size }}
  {{- end }}
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
  {{- if and (eq $serviceType "NodePort") $nodePort }}
  externalTrafficPolicy: Local
  ports:
    - port: {{ $port }}
      targetPort: http
      nodePort: {{ $nodePort }}
      protocol: TCP
      name: http
  {{- else }}
  ports:
    - port: {{ $port }}
      targetPort: http
      protocol: TCP
      name: http
  {{- end }}
  selector:
    app: {{ $name }}
{{- end }}
{{- end }}