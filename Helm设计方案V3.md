# SK-Agent 微服务架构 Helm 部署方案 (第三版 - 最终)

## 一、设计背景

基于需求文档，本方案为包含Infra层、RAG层、Platform Services层和Platform Web层的微服务产品设计Helm Chart部署方案。

### 需求要点
- 使用 Helm Chart 进行应用部署和管理
- 采用父子 Chart 结构，父 Chart 管理整体部署，24个子Chart管理具体服务
- 根据服务特性选择合适的 K8s 资源类型（Deployment、StatefulSet）
- **多路径持久化存储** - 支持单个服务挂载多个PVC
- **ConfigMap配置管理** - Java服务通过ConfigMap管理application.yaml
- 私有镜像 + ServiceAccount 账号管理
- Ingress域名访问配置
- 前后端服务使用可复用模板
- 支持单机 k3s 部署，分为 dev/pre/prod 三种环境
- 支持 x86_64、arm64 多架构部署

---

## 二、设计原则

### 折中方案：子Chart结构 + 复用公共模板 + 多路径存储 + ConfigMap配置

| 特点 | 第一版 | 第二版 | 第三版(本) |
|------|--------|--------|------------|
| 结构 | 真正子Chart | 扁平化(无子Chart) | 24个独立子Chart |
| 模板 | 子Chart内模板 | 全局公共模板 | 全局公共模板 |
| 存储 | 单路径持久化 | 无 | **多路径持久化** |
| 配置 | 硬编码 | 硬编码 | **ConfigMap管理** |
| Ingress | 无 | 无 | **支持** |

### 第三版新特性
1. **多路径持久化** - StatefulSet支持挂载多个PVC，不同路径可配置不同存储大小
2. **ConfigMap配置管理** - Java服务自动生成ConfigMap，挂载到/config目录管理application.yaml
3. **Ingress域名访问** - nginx支持Ingress配置，可配置域名和TLS证书
4. **保持子Chart独立性** - 每个服务有自己的Chart，可单独部署/调试
5. **模板统一复用** - 公共模板在父Chart中定义，子Chart通过include调用

---

## 三、架构设计

### 3.1 目录结构

```
sk-agent/
├── charts/                          # 24个独立子Chart
│   ├── infra-mysql/                # MySQL 8.0 (多路径: data+conf)
│   ├── infra-redis/                # Redis 7.4 (多路径: data+conf)
│   ├── infra-rabbitmq/             # RabbitMQ 3.13
│   ├── infra-minio/                # MinIO 对象存储
│   ├── rag-memory/                 # Memory服务
│   ├── rag-milvus/                 # Milvus 向量数据库
│   ├── rag-services/               # RAG服务
│   ├── svc-user/                   # 用户服务 (Java+ConfigMap)
│   ├── svc-domain/                 # 领域服务 (Java+ConfigMap)
│   ├── svc-scheduler/             # 调度服务 (Java+ConfigMap)
│   ├── svc-agent/                  # Agent服务 (Python)
│   ├── svc-operation/             # 运营服务 (Java+ConfigMap)
│   ├── svc-storage/                # 存储服务 (Java+ConfigMap)
│   ├── svc-etl/                    # ETL服务 (Python)
│   ├── svc-assessment/            # 评估服务 (Java+ConfigMap)
│   ├── svc-hospital/              # 医院服务 (Java+ConfigMap)
│   ├── svc-tcm/                    # 中医服务 (Java+ConfigMap)
│   ├── svc-notification/          # 通知服务 (Java+ConfigMap)
│   ├── svc-customer/              # 客户服务 (Java+ConfigMap)
│   ├── svc-dashboard/              # 仪表盘服务 (Java+ConfigMap)
│   ├── svc-manager/                # 管理服务 (Java+ConfigMap)
│   ├── web-app/                    # App前端 (Node)
│   ├── web-hospital/               # 医院前端 (Node)
│   └── web-nginx/                  # Nginx网关 (+Ingress)
│
├── templates/                       # 公共模板
│   ├── _helpers.tpl                # 全局辅助函数
│   └── common/                     # 公共模板
│       ├── java-deployment.tpl    # Java服务模板 (+ConfigMap挂载)
│       ├── java-configmap.tpl     # ConfigMap生成模板
│       ├── python-deployment.tpl # Python服务模板
│       ├── node-deployment.tpl    # Node.js服务模板
│       ├── statefulset.tpl        # StatefulSet模板 (多路径)
│       └── job.tpl                # Job模板
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
│  │(多路径)  │  │(多路径)  │  │         │  │        │           │
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
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Platform Services Layer                        │
│  ┌──────┐ ┌───────┐ ┌──────────┐ ┌───────┐ ┌──────────┐       │
│  │ User │ │ Domain│ │ Scheduler│ │ Agent │ │Operation │       │
│  │+CMAP │ │+CMAP  │ │  +CMAP   │ │       │ │  +CMAP   │       │
│  └──────┘ └───────┘ └──────────┘ └───────┘ └──────────┘       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Platform Web Layer                         │
│  ┌──────────┐    ┌─────────────┐    ┌────────┐                │
│  │ app-web  │    │hospital-web │    │  Nginx│                │
│  │          │    │             │    │+Ingress│                │
│  └──────────┘    └─────────────┘    └────────┘                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 四、核心特性配置

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
### 4.2 多路径持久化存储

**实现原理**：StatefulSet模板支持volumes数组，每个元素定义独立的PVC

**模板参数**：
```yaml
volumes:
  - name: data                              # volume名称
    mountPath: /var/lib/mysql              # 容器内挂载路径
    size: 10Gi                              # 存储大小
    storageClass: manual-sc                # 存储类
    accessMode: ReadWriteOnce               # 访问模式
```

**Infra服务配置**：

| 服务 | volume数量 | 路径 | 存储大小 |
|------|-----------|------|----------|
| mysql | 2 | /var/lib/mysql, /etc/mysql/conf.d | 10Gi + 1Gi |
| redis | 2 | /data, /usr/local/etc/redis | 2Gi + 100Mi |
| rabbitmq | 1 | /var/lib/rabbitmq | 8Gi |
| minio | 1 | /data | 20Gi |

**RAG服务配置**：

| 服务 | volume数量 | 路径 | 存储大小 |
|------|-----------|------|----------|
| memory | 1 | /data | 5Gi |
| milvus | 1 | /var/lib/milvus | 10Gi |
| rag-services | 0 | - | - |

### 4.3 ConfigMap配置管理

**实现原理**：Java服务模板自动调用ConfigMap模板生成application.yaml，并挂载到容器/config目录

**模板文件**：`templates/common/java-configmap.tpl`
```yaml
{{- define "java.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .serviceName }}-config
data:
  application.yaml: |
    {{- toYaml .applicationYaml | nindent 4 }}
{{- end }}
```

**values.yaml配置示例**：
```yaml
config:
  spring:
    application:
      name: user-service
    datasource:
      url: jdbc:mysql://mysql:3306/skagent?useUnicode=true&characterEncoding=utf8&useSSL=false
      username: skuser
      password: mysql123
      driver-class-name: com.mysql.cj.jdbc.Driver
    redis:
      host: redis
      port: 6379
    rabbitmq:
      host: rabbitmq
      port: 5672
  server:
    port: 8080
```

**自动挂载**：
- ConfigMap名称：`<serviceName>-config`
- 挂载路径：`/config`
- 环境变量：`SPRING_PROFILES_ACTIVE`、环境变量引用ConfigMap

**子Chart调用**：
```yaml
# charts/svc-user/templates/deployment.yaml
{{ include "java.configmap" (dict "root" . "serviceName" .Values.name "applicationYaml" .Values.config) }}
{{ include "java.deployment" (dict "root" . "serviceName" .Values.name "image" .Values.image "port" .Values.service.port "resources" .Values.resources "configMap" true) }}
```

### 4.4 Ingress域名访问

**实现原理**：nginx子Chart模板支持条件渲染Ingress资源

**配置示例**：
```yaml
# web-nginx/values.yaml
ingress:
  enabled: false                  # 开发环境默认关闭
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: "api.sk-agent.com"
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: sk-agent-tls
      hosts:
        - "api.sk-agent.com"
```

**环境差异**：

| 配置项 | dev | pre | prod |
|-------|-----|-----|------|
| Ingress | enabled: true | enabled: false | enabled: true |
| Service | NodePort | ClusterIP | LoadBalancer |
| 域名 | sk-agent-dev.local | - | api.sk-agent.com |
| TLS | 无 | 无 | letsencrypt |

---

## 五、模板设计

### 5.1 公共模板列表

```
templates/common/
├── java-deployment.tpl      # Java服务部署（自动挂载ConfigMap到/config）
├── java-configmap.tpl       # ConfigMap生成（spring.datasource/redis/rabbitmq）
├── python-deployment.tpl    # Python服务部署
├── node-deployment.tpl      # Node.js服务部署
├── statefulset.tpl          # StatefulSet（支持多volumeClaimTemplates）
└── job.tpl                  # Job模板
```

### 5.2 子Chart模板调用示例

**Java服务（ConfigMap）**：
```yaml
{{ include "java.configmap" (dict "root" . "serviceName" .Values.name "applicationYaml" .Values.config) }}
{{ include "java.deployment" (dict "root" . "serviceName" .Values.name "image" .Values.image "port" .Values.service.port "resources" .Values.resources "configMap" true "javaOpts" .Values.javaOpts) }}
```

**有状态服务（多路径）**：
```yaml
{{ include "statefulset" (dict "root" . "name" .Values.name "image" .Values.image "port" .Values.service.port "volumes" .Values.volumes "env" .Values.env "resources" .Values.resources) }}
```

**Python服务**：
```yaml
{{ include "python.deployment" (dict "root" . "serviceName" .Values.name "image" .Values.image "port" .Values.service.port "resources" .Values.resources "command" .Values.command) }}
```

---

## 六、父Chart配置

### 6.1 父Chart Chart.yaml

```yaml
apiVersion: v2
name: sk-agent
description: SK Agent Microservices Architecture - Parent Chart
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  # Infrastructure (4个)
  - name: infra-mysql
    version: "0.1.0"
    condition: infra-mysql.enabled
  - name: infra-redis
    version: "0.1.0"
    condition: infra-redis.enabled
  - name: infra-rabbitmq
    version: "0.1.0"
    condition: infra-rabbitmq.enabled
  - name: infra-minio
    version: "0.1.0"
    condition: infra-minio.enabled

  # RAG (3个)
  - name: rag-memory
    version: "0.1.0"
    condition: rag-memory.enabled
  - name: rag-milvus
    version: "0.1.0"
    condition: rag-milvus.enabled
  - name: rag-services
    version: "0.1.0"
    condition: rag-services.enabled

  # Services (13个)
  - name: svc-user
    version: "0.1.0"
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

  # Web (3个)
  - name: web-app
    version: "0.1.0"
    condition: web-app.enabled
  - name: web-hospital
    version: "0.1.0"
    condition: web-hospital.enabled
  - name: web-nginx
    version: "0.1.0"
    condition: web-nginx.enabled
```

### 6.2 父Chart values.yaml（全局配置）

```yaml
global:
  environment: dev
  architecture: amd64
  imagePullSecrets:
    - name: registry-secret
  storageClass: "manual-sc"
  serviceAccount:
    create: true
    name: "sk-agent-account"

# Infrastructure - 使用volumes格式
infra-mysql:
  enabled: true
  volumes:
    - name: data
      mountPath: /var/lib/mysql
      size: 10Gi
    - name: conf
      mountPath: /etc/mysql/conf.d
      size: 1Gi

# Services - 使用config格式
svc-user:
  enabled: true
  config:
    spring:
      datasource:
        url: jdbc:mysql://mysql:3306/skagent

# Web - 使用ingress配置
web-nginx:
  enabled: true
  ingress:
    enabled: false
    hosts:
      - host: api.sk-agent.com
```

---

## 七、K8s 资源类型选择

| 服务类型 | K8s 资源 | 特性 |
|---------|----------|------|
| MySQL | StatefulSet | 有状态服务，支持多路径持久化 |
| Redis | StatefulSet | 有状态缓存，支持多路径持久化 |
| RabbitMQ | StatefulSet | 有状态消息队列，支持多路径持久化 |
| MinIO | StatefulSet | 有状态对象存储，支持多路径持久化 |
| Milvus | StatefulSet | 有状态向量数据库，支持多路径持久化 |
| Memory | StatefulSet | 无状态服务，支持多路径持久化 |
| init-data | Job | 一次性任务，执行后退出 |
| Java微服务 | Deployment | 无状态应用，可水平扩展, ConfigMap配置 |
| Python微服务 | Deployment | 无状态应用，可水平扩展, ConfigMap配置 |
| Web前端 | Deployment | 无状态应用，可水平扩展,ConfigMap配置 |
| nginx | Deployment | Ingress配置 |

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

## 十一、验证结果

### 11.1 Helm Lint验证
```bash
cd sk-agent && helm lint .
# 结果：1 chart(s) lint, 0 chart(s) failed
```

### 11.2 渲染资源统计

| 资源类型 | 数量 | 说明 |
|---------|------|------|
| StatefulSet | 6 | MySQL, Redis, RabbitMQ, MinIO, Memory, Milvus |
| Deployment | 18 | 12个Java + rag-services + agent + etl + 3个Web |
| Service | 24 | 每个服务一个 |
| ConfigMap | 14 | 13个Java服务 + nginx |

### 11.3 多路径验证

**MySQL渲染结果**：
```yaml
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: manual-sc
      resources:
        requests:
          storage: 10Gi
  - metadata:
      name: conf
    spec:
      storageClassName: manual-sc
      resources:
        requests:
          storage: 1Gi
```

---

## 十二、部署示例

### 12.1 开发环境部署
```bash
helm install sk-agent-dev sk-agent \
  -f sk-agent/values-dev.yaml \
  -n sk-agent-dev \
  --create-namespace
```

### 12.2 生产环境部署（启用Ingress）
```bash
helm install sk-agent-prod sk-agent \
  -f sk-agent/values-prod.yaml \
  --set web-nginx.ingress.enabled=true \
  --set web-nginx.ingress.hosts[0].host=api.sk-agent.com \
  -n sk-agent-prod \
  --create-namespace
```

### 12.3 单独部署子Chart
```bash
# 仅部署MySQL（多路径）
helm install sk-agent-mysql sk-agent/charts/infra-mysql

# 仅部署user服务（ConfigMap）
helm install sk-agent-user sk-agent/charts/svc-user
```

---

## 十三、设计优势总结

| 优势 | 说明 |
|------|------|
| **多路径持久化** | 单服务支持多个PVC挂载，不同路径不同存储大小 |
| **ConfigMap管理** | Java服务自动生成ConfigMap，热更新配置 |
| **Ingress支持** | nginx支持域名访问和TLS配置 |
| **子Chart独立** | 每个服务可单独部署/调试 |
| **模板复用** | 公共模板减少代码重复 |
| **环境适配** | dev/pre/prod三种环境配置 |

---

## 十四、文件清单

| 文件 | 说明 |
|------|------|
| `sk-agent/Chart.yaml` | 父Chart定义，24个子Chart依赖 |
| `sk-agent/values.yaml` | 默认配置 |
| `sk-agent/values-dev.yaml` | 开发环境配置 |
| `sk-agent/values-pre.yaml` | 预生产环境配置 |
| `sk-agent/values-prod.yaml` | 生产环境配置 |
| `sk-agent/templates/common/*.tpl` | 公共模板（6个） |
| `sk-agent/charts/*/Chart.yaml` | 24个子Chart定义 |
| `sk-agent/charts/*/values.yaml` | 子Chart配置 |
| `sk-agent/charts/*/templates/deployment.yaml` | 子Chart资源渲染 |