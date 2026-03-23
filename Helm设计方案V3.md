# SK-Agent 微服务架构 Helm 部署方案 (第三版)

## 一、设计背景

基于需求文档，本方案为包含Infra层、RAG层、Platform Services层和Platform Web层的微服务产品设计Helm Chart部署方案。

### 需求要点
- 使用 Helm Chart 进行应用部署和管理
- 采用父子 Chart 结构，父 Chart 管理整体部署，子 Chart 管理具体服务
- 根据服务特性选择合适的 K8s 资源类型（Deployment、StatefulSet、Job 等）
- 所有服务采用 StorageClass 进行数据持久化
- 私有镜像 + ServiceAccount 账号管理
- 配置化管理：Secret、ConfigMap 管理账号密码
- 前后端服务使用可复用模板
- 支持单机 k3s 部署，分为 dev/pre/prod 三种环境
- 支持 x86_64、arm64 多架构部署

---

## 二、设计原则

### 折中方案：保留子Chart结构 + 复用公共模板

| 特点 | 第一版 | 第二版 | 第三版(本) |
|------|--------|--------|------------|
| 结构 | 真正子Chart | 扁平化(无子Chart) | 折中方案 |
| 模板 | 子Chart内模板 | 全局公共模板 | 全局公共模板 |
| 复用 | 子Chart可互相引用 | 所有服务用同一模板 | 子Chart使用公共模板 |
| 维护 | 各服务独立维护 | 统一维护 | 统一模板+独立Chart |

### 第三版优势
1. **保持子Chart独立性** - 每个服务有自己的Chart，可单独部署/调试
2. **模板统一复用** - 公共模板在父Chart中定义，子Chart通过include调用
3. **简化依赖管理** - 父Chart声明所有子Chart依赖，避免循环引用
4. **灵活组合** - 可选择性部署某些子Chart，不影响整体

---

## 三、架构设计

### 3.1 整体架构

```
sk-agent (父Chart)
│
├── charts/                          # 子Chart目录
│   ├── infra/                       # 基础设施层
│   │   ├── mysql/                   # MySQL 8.0 数据库
│   │   ├── redis/                   # Redis 7.4 缓存
│   │   ├── rabbitmq/                # RabbitMQ 3.13 消息队列
│   │   └── minio/                   # MinIO 对象存储
│   │
│   ├── rag/                         # RAG层
│   │   ├── memory/                  # Memory服务
│   │   ├── milvus/                  # Milvus 向量数据库
│   │   └── rag-services/           # RAG服务
│   │
│   ├── services/                    # 平台服务层
│   │   ├── user/                    # 用户服务 (Java)
│   │   ├── domain/                  # 领域服务 (Java)
│   │   ├── scheduler/              # 调度服务 (Java)
│   │   ├── agent/                   # Agent服务 (Python)
│   │   ├── operation/              # 运营服务 (Java)
│   │   ├── storage/                # 存储服务 (Java)
│   │   ├── etl/                     # ETL服务 (Python)
│   │   ├── assessment/             # 评估服务 (Java)
│   │   ├── hospital/               # 医院服务 (Java)
│   │   ├── tcm/                     # 中医服务 (Java)
│   │   ├── notification/           # 通知服务 (Java)
│   │   ├── customer/               # 客户服务 (Java)
│   │   ├── dashboard/              # 仪表盘服务 (Java)
│   │   └── manager/                # 管理服务 (Java)
│   │
│   └── web/                         # 前端层
│       ├── app-web/                 # App前端 (Node)
│       ├── hospital-web/           # 医院前端 (Node)
│       └── nginx/                  # Nginx网关
│
├── templates/                        # 公共模板(父Chart级别)
│   ├── _helpers.tpl                 # 全局辅助函数
│   ├── common/                      # 公共模板定义
│   │   ├── java-deployment.tpl     # Java服务部署模板
│   │   ├── python-deployment.tpl   # Python服务部署模板
│   │   ├── node-deployment.tpl     # Node.js服务部署模板
│   │   ├── job.tpl                  # Job模板
│   │   └── statefulset.tpl         # StatefulSet模板
│   └── global/                      # 全局资源
│       ├── storage.yaml            # StorageClass
│       └── serviceaccount.yaml     # ServiceAccount
│
├── values.yaml                      # 默认配置
├── values-dev.yaml                  # 开发环境
├── values-pre.yaml                  # 预生产环境
└── values-prod.yaml                 # 生产环境
```

### 3.2 服务依赖关系

```
┌─────────────────────────────────────────────────────────────────┐
│                        Infra Layer                               │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌────────┐           │
│  │  MySQL  │  │  Redis  │  │ RabbitMQ │  │ MinIO  │           │
│  └────┬────┘  └────┬────┘  └────┬─────┘  └───┬────┘           │
└───────┼────────────┼────────────┼─────────────┼─────────────────┘
        │            │            │             │
        ▼            ▼            ▼             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      RAG Layer                                  │
│  ┌─────────┐      ┌─────────┐      ┌─────────────┐            │
│  │ Memory  │──────│ Milvus  │──────│ rag-services│            │
│  └─────────┘      └─────────┘      └─────────────┘            │
└─────────────────────────────────────────────────────────────────┘
        │                                  │
        ▼                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Platform Services Layer                        │
│  ┌──────┐ ┌───────┐ ┌──────────┐ ┌───────┐ ┌──────────┐       │
│  │ User │ │ Domain│ │ Scheduler│ │ Agent │ │Operation │  ...   │
│  └──────┘ └───────┘ └──────────┘ └───────┘ └──────────┘       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Platform Web Layer                         │
│  ┌──────────┐    ┌─────────────┐    ┌────────┐                │
│  │ app-web  │    │hospital-web │    │  Nginx │                │
│  └──────────┘    └─────────────┘    └────────┘                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 四、模板复用设计

### 4.1 公共模板架构

```
父Chart templates/common/           子Chart调用方式
        │                                    │
        ├── java-deployment.tpl  ───────────▶ {{ include "java.deployment" (dict ...) }}
        │                                    │
        ├── python-deployment.tpl ──────────▶ {{ include "python.deployment" (dict ...) }}
        │                                    │
        ├── node-deployment.tpl  ───────────▶ {{ include "node.deployment" (dict ...) }}
        │                                    │
        ├── job.tpl               ───────────▶ {{ include "job.tpl" (dict ...) }}
        │                                    │
        └── statefulset.tpl       ───────────▶ {{ include "statefulset.tpl" (dict ...) }}
```

### 4.2 Java服务部署模板

**模板文件**: `templates/common/java-deployment.tpl`

```yaml
{{- define "java.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .serviceName }}
  labels:
    app: {{ .serviceName }}
    {{- include "sk-agent.labels" .root | nindent 4 }}
spec:
  replicas: {{ default 1 .replicas }}
  selector:
    matchLabels:
      app: {{ .serviceName }}
  template:
    metadata:
      labels:
        app: {{ .serviceName }}
    spec:
      serviceAccountName: {{ default "sk-agent-account" .serviceAccount }}
      containers:
      - name: {{ .serviceName }}
        image: {{ .image }}
        ports:
        - containerPort: {{ default 8080 .port }}
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: {{ .root.Values.profile | default "dev" }}
        - name: JAVA_OPTS
          value: {{ default "-Xmx512m -Xms256m" .javaOpts }}
        resources:
          {{- toYaml .resources | nindent 10 }}
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: {{ default 8080 .port }}
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: {{ default 8080 .port }}
          initialDelaySeconds: 30
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .serviceName }}
spec:
  selector:
    app: {{ .serviceName }}
  ports:
  - port: {{ default 8080 .port }}
    targetPort: {{ default 8080 .port }}
  type: ClusterIP
{{- end }}
```

**子Chart调用示例** (`charts/services/user/templates/deployment.yaml`):

```yaml
{{- include "java.deployment" (dict 
  "root" .
  "serviceName" "user" 
  "image" .Values.image 
  "port" .Values.service.port
  "replicas" .Values.replicas
  "resources" .Values.resources
  "javaOpts" .Values.javaOpts
) -}}
```

### 4.3 Python服务部署模板

**模板文件**: `templates/common/python-deployment.tpl`

```yaml
{{- define "python.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .serviceName }}
  labels:
    app: {{ .serviceName }}
spec:
  replicas: {{ default 1 .replicas }}
  selector:
    matchLabels:
      app: {{ .serviceName }}
  template:
    metadata:
      labels:
        app: {{ .serviceName }}
    spec:
      containers:
      - name: {{ .serviceName }}
        image: {{ .image }}
        {{- if .command }}
        command: {{ .command }}
        {{- end }}
        ports:
        - containerPort: {{ default 8080 .port }}
        env:
        - name: PYTHON_ENV
          value: {{ .root.Values.profile | default "dev" }}
        resources:
          {{- toYaml .resources | nindent 10 }}
        livenessProbe:
          httpGet:
            path: /health
            port: {{ default 8080 .port }}
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: {{ default 8080 .port }}
          initialDelaySeconds: 20
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .serviceName }}
spec:
  selector:
    app: {{ .serviceName }}
  ports:
  - port: {{ default 8080 .port }}
    targetPort: {{ default 8080 .port }}
  type: ClusterIP
{{- end }}
```

### 4.4 StatefulSet模板

**模板文件**: `templates/common/statefulset.tpl`

```yaml
{{- define "statefulset" -}}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ .serviceName }}
  labels:
    app: {{ .serviceName }}
spec:
  serviceName: {{ .serviceName }}
  replicas: {{ default 1 .replicas }}
  selector:
    matchLabels:
      app: {{ .serviceName }}
  template:
    metadata:
      labels:
        app: {{ .serviceName }}
    spec:
      containers:
      - name: {{ .serviceName }}
        image: {{ .image }}
        ports:
        {{- range .ports }}
        - name: {{ .name }}
          containerPort: {{ .port }}
        {{- end }}
        volumeMounts:
        - name: data
          mountPath: {{ default "/data" .mountPath }}
        env:
        {{- range .envVars }}
        - name: {{ .name }}
          value: {{ .value }}
        {{- end }}
        resources:
          {{- toYaml .resources | nindent 10 }}
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [{{ default "ReadWriteOnce" .accessMode }}]
      storageClassName: {{ .storageClass }}
      resources:
        requests:
          storage: {{ .storageSize }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .serviceName }}
spec:
  clusterIP: None
  selector:
    app: {{ .serviceName }}
  ports:
  {{- range .ports }}
  - name: {{ .name }}
    port: {{ .port }}
    targetPort: {{ .port }}
  {{- end }}
{{- end }}
```

---

## 五、子Chart结构

### 5.1 Java子Chart示例 (user服务)

```
charts/services/user/
├── Chart.yaml
├── values.yaml
└── templates/
    └── deployment.yaml
```

**Chart.yaml**:
```yaml
apiVersion: v2
name: user
description: User Service
type: application
version: 0.1.0
```

**values.yaml**:
```yaml
image: registry.example.com/user-service:1.0.0
service:
  port: 8080
replicas: 1
resources:
  limits:
    cpu: "1"
    memory: 1Gi
  requests:
    cpu: 250m
    memory: 512Mi
javaOpts: "-Xmx1g -Xms512m"
```

**templates/deployment.yaml**:
```yaml
{{- include "java.deployment" (dict 
  "root" .
  "serviceName" "user" 
  "image" .Values.image 
  "port" .Values.service.port
  "replicas" .Values.replicas
  "resources" .Values.resources
  "javaOpts" .Values.javaOpts
) -}}
```

### 5.2 基础设施子Chart示例 (MySQL)

```
charts/infra/mysql/
├── Chart.yaml
├── values.yaml
└── templates/
    └── statefulset.yaml
```

**templates/statefulset.yaml**:
```yaml
{{- include "statefulset" (dict 
  "root" .
  "serviceName" "mysql"
  "image" .Values.image
  "ports" (list (dict "name" "mysql" "port" 3306))
  "replicas" .Values.replicas
  "storageClass" .Values.persistence.storageClass
  "storageSize" .Values.persistence.size
  "mountPath" "/var/lib/mysql"
  "envVars" (list 
    (dict "name" "MYSQL_ROOT_PASSWORD" "value" .Values.mysqlRootPassword)
    (dict "name" "MYSQL_DATABASE" "value" .Values.mysqlDatabase)
  )
  "resources" .Values.resources
) -}}
```

---

## 六、父Chart配置

### 6.1 父Chart Chart.yaml

```yaml
apiVersion: v2
name: sk-agent
description: SK Agent Microservices Architecture
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  # Infrastructure
  - name: infra-mysql
    condition: infra-mysql.enabled
  - name: infra-redis
    condition: infra-redis.enabled
  - name: infra-rabbitmq
    condition: infra-rabbitmq.enabled
  - name: infra-minio
    condition: infra-minio.enabled

  # RAG
  - name: rag-memory
    condition: rag-memory.enabled
  - name: rag-milvus
    condition: rag-milvus.enabled
  - name: rag-services
    condition: rag-services.enabled

  # Services
  - name: svc-user
    condition: svc-user.enabled
  - name: svc-domain
    condition: svc-domain.enabled
  - name: svc-scheduler
    condition: svc-scheduler.enabled
  - name: svc-agent
    condition: svc-agent.enabled
  - name: svc-operation
    condition: svc-operation.enabled
  - name: svc-storage
    condition: svc-storage.enabled
  - name: svc-etl
    condition: svc-etl.enabled
  - name: svc-assessment
    condition: svc-assessment.enabled
  - name: svc-hospital
    condition: svc-hospital.enabled
  - name: svc-tcm
    condition: svc-tcm.enabled
  - name: svc-notification
    condition: svc-notification.enabled
  - name: svc-customer
    condition: svc-customer.enabled
  - name: svc-dashboard
    condition: svc-dashboard.enabled
  - name: svc-manager
    condition: svc-manager.enabled

  # Web
  - name: web-app
    condition: web-app.enabled
  - name: web-hospital
    condition: web-hospital.enabled
  - name: web-nginx
    condition: web-nginx.enabled
```

### 6.2 父Chart values.yaml

```yaml
global:
  imagePullSecrets:
    - name: registry-secret
  serviceAccount: sk-agent-account
  arch: amd64

profile: dev

# Infrastructure
infra-mysql:
  enabled: true
infra-redis:
  enabled: true
infra-rabbitmq:
  enabled: true
infra-minio:
  enabled: true

# RAG
rag-memory:
  enabled: true
rag-milvus:
  enabled: true
rag-services:
  enabled: true

# Services
svc-user:
  enabled: true
svc-domain:
  enabled: true
svc-scheduler:
  enabled: true
svc-agent:
  enabled: true
svc-operation:
  enabled: true
svc-storage:
  enabled: true
svc-etl:
  enabled: true
svc-assessment:
  enabled: true
svc-hospital:
  enabled: true
svc-tcm:
  enabled: true
svc-notification:
  enabled: true
svc-customer:
  enabled: true
svc-dashboard:
  enabled: true
svc-manager:
  enabled: true

# Web
web-app:
  enabled: true
web-hospital:
  enabled: true
web-nginx:
  enabled: true
```

---

## 七、K8s 资源类型选择

| 服务类型 | K8s 资源 | 说明 |
|---------|----------|------|
| MySQL | StatefulSet | 有状态数据库，需要持久化存储 |
| Redis | StatefulSet | 有状态缓存，需要持久化 |
| RabbitMQ | StatefulSet | 有状态消息队列，需要持久化 |
| MinIO | StatefulSet | 有状态对象存储，需要持久化 |
| Milvus | StatefulSet | 有状态向量数据库，需要持久化 |
| Memory | StatefulSet | 有状态服务，需要持久化 |
| Java微服务 | Deployment | 无状态应用，可水平扩展 |
| Python微服务 | Deployment | 无状态应用，可水平扩展 |
| Web前端 | Deployment | 无状态应用，可水平扩展 |
| init-data | Job | 一次性任务，执行后退出 |

---

## 八、多环境配置

### 8.1 环境差异对比

| 配置项 | dev | pre | prod |
|-------|-----|-----|------|
| StorageClass | manual-sc | standard | standard |
| MySQL存储 | 5Gi | 20Gi | 100Gi |
| Redis存储 | 1Gi | 5Gi | 20Gi |
| 服务副本数 | 1 | 2 | 2-3 |
| 资源配置 | 最低 | 中等 | 高 |
| Ingress | NodePort | LoadBalancer | LoadBalancer+TLS |

### 8.2 values文件

- **values.yaml**: 默认配置，所有环境的公共配置
- **values-dev.yaml**: 开发环境，低资源，hostPath存储
- **values-pre.yaml**: 预生产环境，中等资源
- **values-prod.yaml**: 生产环境，高可用，高资源

---

## 九、私有镜像配置

### 9.1 ServiceAccount 配置

```yaml
# templates/global/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sk-agent-account
```

### 9.2 镜像拉取密钥

```yaml
# templates/registry-secret.yaml
{{- if and .Values.global.imagePullSecrets (ne (len .Values.global.imagePullSecrets) 0) }}
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: {{ printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\"}}}" .Values.registry.server .Values.registry.username .Values.registry.password | b64enc }}
{{- end }}
```

### 9.3 values.yaml 配置

```yaml
registry:
  server: "registry.example.com"
  username: ""
  password: ""
  email: ""
```

---

## 十、存储配置

### 10.1 StorageClass

```yaml
# templates/global/storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: manual-sc
provisioner: kubernetes.io/no-provisioner
```

### 10.2 环境特定存储

**values-dev.yaml**:
```yaml
persistence:
  hostPath: "/tmp/volumes"
  storageClass: "manual-sc"
```

**values-prod.yaml**:
```yaml
persistence:
  storageClass: "standard"
```

---

## 十一、部署示例

### 11.1 开发环境部署

```bash
# 1. 创建命名空间
kubectl create namespace sk-agent-dev

# 2. 部署
helm install sk-agent-dev sk-agent \
  --set registry.username=your-user \
  --set registry.password=your-pass \
  -f sk-agent/values-dev.yaml \
  -n sk-agent-dev \
  --create-namespace

# 3. 查看状态
kubectl get pods -n sk-agent-dev

# 4. 端口转发测试
kubectl port-forward svc/user 8080:8080 -n sk-agent-dev
```

### 11.2 生产环境部署

```bash
kubectl create namespace sk-agent-prod

helm install sk-agent-prod sk-agent \
  --set registry.username=your-user \
  --set registry.password=your-pass \
  -f sk-agent/values-prod.yaml \
  -n sk-agent-prod \
  --create-namespace
```

### 11.3 单独部署子Chart

```bash
# 仅部署MySQL
helm install sk-agent-mysql sk-agent/charts/infra/mysql \
  -f sk-agent/values-dev.yaml \
  -n sk-agent-dev

# 仅部署user服务
helm install sk-agent-user sk-agent/charts/services/user \
  -f sk-agent/values-dev.yaml \
  -n sk-agent-dev
```

---

## 十二、渲染资源统计

| 资源类型 | 数量 | 说明 |
|---------|------|------|
| StatefulSet | 6 | MySQL, Redis, RabbitMQ, MinIO, Memory, Milvus |
| Deployment | 21 | 12个Java + 5个Python + 3个Web + 1个RAG |
| Service | 27 | 基础设施 + 微服务端口 |
| ConfigMap | 5 | Redis, RabbitMQ, MinIO, Memory, Milvus |
| Secret | 5 | Redis, RabbitMQ, MinIO, Memory, Milvus |
| Job | 1 | init-data 数据初始化 |

### 服务清单

**Infra层 (4个)**:
- MySQL (3306)
- Redis (6379)
- RabbitMQ (5672/15672)
- MinIO (9000/9001)

**RAG层 (3个)**:
- Memory (3306)
- Milvus (19530)
- rag-services (8080)

**Platform Services层 (17个)**:
- Java: user, domain, scheduler, operation, storage, assessment, hospital, tcm, notification, customer, dashboard, manager
- Python: agent, etl
- Job: init-data

**Web层 (3个)**:
- app-web (3000)
- hospital-web (3000)
- nginx (80)

---

## 十三、第三版设计优势总结

| 优势 | 说明 |
|------|------|
| **子Chart独立** | 每个服务有自己的Chart，可单独部署和调试 |
| **模板复用** | 公共模板在父Chart中定义，避免代码重复 |
| **灵活部署** | 可通过values选择性地启用/禁用子Chart |
| **依赖清晰** | 父Chart统一管理所有子Chart依赖关系 |
| **便于维护** | 模板修改一次即可影响所有服务 |
| **版本管理** | 各子Chart可独立版本控制 |
| **调试友好** | 可单独渲染某个子Chart进行调试 |