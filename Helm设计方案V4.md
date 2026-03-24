# SK-Agent 微服务架构 Helm 部署方案 (第四版 - 业务层分组)

## 一、设计背景

基于需求文档，本方案为包含Infra层、RAG层、Platform Services层和Platform Web层的微服务产品设计Helm Chart部署方案。

### 需求要点
- 使用 Helm Chart 进行应用部署和管理
- 采用父子 Chart 结构，父 Chart 管理整体部署，**3个业务层子Chart**管理具体服务
- 根据服务特性选择合适的 K8s 资源类型（Deployment、StatefulSet、Job）
- **多路径持久化存储** - 支持单个服务挂载多个PVC
- **ConfigMap配置管理** - Java服务通过ConfigMap管理application.yaml
- 私有镜像 + ServiceAccount 账号管理
- Ingress域名访问配置
- 前后端服务使用可复用模板
- 支持单机 k3s 部署，分为 dev/pre/prod 三种环境
- 支持 x86_64、arm64 多架构部署
- **x86架构下使用MySQL，arm64架构下使用Kingbase**

---

## 二、设计原则

### 折中方案：业务层分组子Chart + 公共模板 + 多路径存储 + ConfigMap配置

| 特点 | 第一版 | 第二版 | 第三版 | 第四版(本) |
|------|--------|--------|--------|------------|
| 结构 | 真正子Chart | 扁平化(无子Chart) | 24个独立子Chart | **3个业务层子Chart** |
| 模板 | 子Chart内模板 | 全局公共模板 | 全局公共模板 | 全局公共模板 |
| 存储 | 单路径持久化 | 无 | 多路径持久化 | 多路径持久化 |
| 配置 | 硬编码 | 硬编码 | ConfigMap管理 | ConfigMap管理 |
| Ingress | 无 | 无 | 支持 | 支持 |
| 多架构 | 无 | 无 | 无 | **支持(x86/arm64)** |

### 第四版新特性
1. **业务层分组** - 3个子Chart（infra、rag、platform）按业务领域划分
2. **多架构支持** - x86使用MySQL，arm64使用Kingbase
3. **多路径持久化** - StatefulSet支持挂载多个PVC
4. **ConfigMap配置管理** - Java服务自动生成ConfigMap
5. **Ingress域名访问** - nginx支持Ingress配置
6. **模板统一复用** - 公共模板在父Chart中定义，子Chart通过include调用

---

## 三、架构设计

### 3.1 目录结构

```
sk-agent/
├── charts/                          # 3个业务层子Chart
│   ├── infra/                       # 基础设施层
│   │   ├── charts/
│   │   │   ├── mysql/               # MySQL 8.0 (x86) / Kingbase (arm64)
│   │   │   ├── redis/               # Redis 7.4 (多路径: data+conf)
│   │   │   ├── rabbitmq/            # RabbitMQ 3.13
│   │   │   └── minio/               # MinIO 对象存储
│   │   ├── values.yaml
│   │   └── Chart.yaml
│   │
│   ├── rag/                         # RAG层
│   │   ├── charts/
│   │   │   ├── memory/              # Memory服务 (依赖mysql)
│   │   │   ├── milvus/              # Milvus 向量数据库 (依赖minio+etcd)
│   │   │   └── rag-services/        # RAG服务 (依赖mysql+redis+milvus)
│   │   ├── values.yaml
│   │   └── Chart.yaml
│   │
│   └── platform/                    # 平台服务层 (Services + Web)
│       ├── charts/
│       │   ├── init-data/           # 数据初始化 (Job, 一次性)
│       │   ├── user/                # 用户服务 (Java+ConfigMap, 依赖init-data)
│       │   ├── domain/              # 领域服务 (Java+ConfigMap)
│       │   ├── scheduler/           # 调度服务 (Java+ConfigMap)
│       │   ├── agent/               # Agent服务 (Python)
│       │   ├── agent-task/          # Agent任务 (Python, 依赖scheduler)
│       │   ├── operation/           # 运营服务 (Java+ConfigMap)
│       │   ├── storage/             # 存储服务 (Java+ConfigMap)
│       │   ├── etl/                 # ETL服务 (Python)
│       │   ├── etl-listener/        # ETL监听 (Python, 与etl镜像同)
│       │   ├── etl-beat/            # ETL调度 (Python, 依赖user/domain/operation)
│       │   ├── assessment/          # 评估服务 (Java+ConfigMap)
│       │   ├── hospital/            # 医院服务 (Java+ConfigMap)
│       │   ├── tcm/                 # 中医服务 (Java+ConfigMap)
│       │   ├── notification/        # 通知服务 (Java+ConfigMap)
│       │   ├── customer/            # 客户服务 (Java+ConfigMap)
│       │   ├── dashboard/           # 仪表盘服务 (Java+ConfigMap, 依赖operation)
│       │   ├── manager/             # 管理服务 (Java+ConfigMap, 依赖多服务)
│       │   ├── app-web/             # App前端 (Node, 依赖domain)
│       │   ├── hospital-web/        # 医院前端 (Node, 依赖hospital)
│       │   └── nginx/               # Nginx网关 (+Ingress, 依赖app-web+hospital-web)
│       ├── values.yaml
│       └── Chart.yaml
│
├── templates/                       # 公共模板
│   ├── _helpers.tpl                # 全局辅助函数
│   └── common/                     # 公共模板
│       ├── java-deployment.tpl    # Java服务模板 (+ConfigMap挂载)
│       ├── java-configmap.tpl     # ConfigMap生成模板
│       ├── python-deployment.tpl  # Python服务模板
│       ├── node-deployment.tpl    # Node.js服务模板
│       ├── statefulset.tpl         # StatefulSet模板 (多路径)
│       ├── job.tpl                 # Job模板
│       └── ingress.tpl             # Ingress模板
│
├── values.yaml                      # 默认配置
├── values-dev.yaml                  # 开发环境
├── values-pre.yaml                  # 预生产环境
└── values-prod.yaml                 # 生产环境
```

### 3.2 服务依赖关系

```
┌─────────────────────────────────────────────────────────────────┐
│                      INFRA LAYER                                 │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌────────┐           │
│  │  MySQL  │  │  Redis  │  │ RabbitMQ │  │ MinIO  │           │
│  │(x86/arm)│  │(多路径)  │  │         │  │        │           │
│  └────┬────┘  └────┬────┘  └────┬─────┘  └───┬────┘           │
└───────┼────────────┼────────────┼─────────────┼───────────────┘
        │            │            │             │
        ▼            ▼            ▼             ▼
┌─────────────────────────────────────────────────────────────────┐
│                       RAG LAYER                                  │
│  ┌─────────┐      ┌─────────┐      ┌─────────────┐            │
│  │ Memory  │──────│ Milvus  │──────│ rag-services│            │
│  │ (mysql) │      │(minio)  │      │(mysql+redis)│            │
│  └─────────┘      └─────────┘      └─────────────┘            │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PLATFORM SERVICES LAYER                       │
│  ┌──────┐ ┌───────┐ ┌──────────┐ ┌───────┐ ┌──────────┐       │
│  │ User │ │ Domain│ │ Scheduler│ │ Agent │ │Operation │       │
│  │+CMAP │ │+CMAP  │ │  +CMAP   │ │       │ │  +CMAP   │       │
│  └──────┘ └───────┘ └──────────┘ └───────┘ └──────────┘       │
│  ┌───────┐ ┌──────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐     │
│  │Storage│ │  ETL │ │Hospital │ │ Manager  │ │  Tcm     │     │
│  │+CMAP  │ │      │ │  +CMAP  │ │  +CMAP    │ │  +CMAP   │     │
│  └───────┘ └──────┘ └─────────┘ └──────────┘ └──────────┘     │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                      PLATFORM WEB LAYER                          │
│  ┌──────────┐    ┌─────────────┐    ┌────────┐                │
│  │ app-web  │    │hospital-web │    │  Nginx│                │
│  │          │    │             │    │+Ingress│                │
│  └──────────┘    └─────────────┘    └────────┘                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 四、核心特性配置

### 4.1 三层子Chart结构

```
父Chart sk-agent/
    │
    ├── charts/infra/         # 基础设施层 (4个服务)
    │   ├── charts/mysql/     # 根据架构切换MySQL/Kingbase
    │   ├── charts/redis/
    │   ├── charts/rabbitmq/
    │   └── charts/minio/
    │
    ├── charts/rag/          # RAG层 (3个服务)
    │   ├── charts/memory/
    │   ├── charts/milvus/
    │   └── charts/rag-services/
    │
    └── charts/platform/     # 平台服务层 (21个服务)
        ├── charts/init-data/ # Job类型
        ├── charts/user/     # Java+ConfigMap
        ├── charts/domain/   # Java+ConfigMap
        ├── ... (其他Java服务)
        ├── charts/agent/   # Python
        ├── charts/etl/     # Python
        ├── charts/app-web/ # Node
        └── charts/nginx/   # Node+Ingress
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
| mysql/kingbase | 2 | /var/lib/mysql, /etc/mysql/conf.d | 10Gi + 1Gi |
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

### 4.4 多架构支持 (x86/arm64)

**实现原理**：根据全局架构配置动态切换数据库类型

**配置示例**：
```yaml
# values.yaml
global:
  architecture: amd64  # amd64 (x86) 或 arm64

# MySQL子Chart values.yaml
database:
  type: mysql          # 根据架构自动切换
  
# 模板中判断
{{- if eq .Values.global.architecture "arm64" }}
image: kingbase-image
{{- else }}
image: mysql-image
{{- end }}
```

**架构差异**：

| 配置项 | x86_64 (amd64) | arm64 |
|-------|---------------|-------|
| 数据库 | MySQL 8.0 | Kingbase |
| 镜像 | mysql:8.0 | kingbase:v8r6 |
| JDBC驱动 | com.mysql.cj.jdbc.Driver | com.kingbase8.Driver |
| 数据源URL | jdbc:mysql:// | jdbc:kingbase8:// |

### 4.5 Ingress域名访问

**实现原理**：nginx子Chart模板支持条件渲染Ingress资源

**配置示例**：
```yaml
# nginx/values.yaml
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
├── job.tpl                  # Job模板
└── ingress.tpl              # Ingress模板
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
  # Infrastructure Layer (4个服务)
  - name: infra
    version: "0.1.0"
    condition: infra.enabled
    repository: "file://charts/infra"

  # RAG Layer (3个服务)
  - name: rag
    version: "0.1.0"
    condition: rag.enabled
    repository: "file://charts/rag"

  # Platform Layer (21个服务)
  - name: platform
    version: "0.1.0"
    condition: platform.enabled
    repository: "file://charts/platform"
```

### 6.2 父Chart values.yaml（全局配置）

```yaml
global:
  environment: dev
  architecture: amd64           # amd64 (x86) 或 arm64
  imagePullSecrets:
    - name: registry-secret
  storageClass: "manual-sc"
  serviceAccount:
    create: true
    name: "sk-agent-account"

# Infrastructure Layer
infra:
  enabled: true
  mysql:
    enabled: true
    volumes:
      - name: data
        mountPath: /var/lib/mysql
        size: 10Gi
      - name: conf
        mountPath: /etc/mysql/conf.d
        size: 1Gi
  redis:
    enabled: true
  rabbitmq:
    enabled: true
  minio:
    enabled: true

# RAG Layer
rag:
  enabled: true

# Platform Layer
platform:
  enabled: true
```

### 6.3 Infra子Chart Chart.yaml

```yaml
apiVersion: v2
name: infra
description: Infrastructure Layer - MySQL, Redis, RabbitMQ, MinIO
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  - name: mysql
    version: "0.1.0"
    condition: mysql.enabled
  - name: redis
    version: "0.1.0"
    condition: redis.enabled
  - name: rabbitmq
    version: "0.1.0"
    condition: rabbitmq.enabled
  - name: minio
    version: "0.1.0"
    condition: minio.enabled
```

### 6.4 Platform子Chart Chart.yaml

```yaml
apiVersion: v2
name: platform
description: Platform Services + Web Layer
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  # Services (13个)
  - name: init-data
    version: "0.1.0"
    condition: init-data.enabled
  - name: user
    version: "0.1.0"
    condition: user.enabled
  - name: domain
    condition: domain.enabled
  - name: scheduler
    condition: scheduler.enabled
  - name: agent
    condition: agent.enabled
  - name: agent-task
    condition: agent-task.enabled
  - name: operation
    condition: operation.enabled
  - name: storage
    condition: storage.enabled
  - name: etl
    condition: etl.enabled
  - name: etl-listener
    condition: etl-listener.enabled
  - name: etl-beat
    condition: etl-beat.enabled
  - name: assessment
    condition: assessment.enabled
  - name: hospital
    condition: hospital.enabled
  - name: tcm
    condition: tcm.enabled
  - name: notification
    condition: notification.enabled
  - name: customer
    condition: customer.enabled
  - name: dashboard
    condition: dashboard.enabled
  - name: manager
    condition: manager.enabled

  # Web (3个)
  - name: app-web
    version: "0.1.0"
    condition: app-web.enabled
  - name: hospital-web
    version: "0.1.0"
    condition: hospital-web.enabled
  - name: nginx
    version: "0.1.0"
    condition: nginx.enabled
```

---

## 七、K8s 资源类型选择

| 服务类型 | K8s 资源 | 特性 |
|---------|----------|------|
| MySQL/Kingbase | StatefulSet | 有状态服务，支持多路径持久化，多架构 |
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
| 架构 | amd64 | amd64 | amd64/arm64 |

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

## 十一、服务依赖配置

### 11.1 Platform服务依赖矩阵

| 服务 | 依赖服务 | 依赖类型 |
|------|---------|---------|
| init-data | - | 初始数据，一次性Job |
| user | init-data | 数据依赖 |
| domain | - | 基础服务 |
| scheduler | - | 调度服务 |
| agent | - | Agent服务 |
| agent-task | scheduler | 任务依赖调度 |
| operation | - | 运营服务 |
| storage | - | 存储服务 |
| etl | scheduler | ETL依赖调度 |
| etl-listener | etl | 与etl同镜像 |
| etl-beat | user, domain, operation | 依赖多个服务 |
| assessment | - | 评估服务 |
| hospital | - | 医院服务 |
| tcm | - | 中医服务 |
| notification | - | 通知服务 |
| customer | - | 客户服务 |
| dashboard | operation | 依赖运营服务 |
| manager | user, domain, storage, tcm, etl, customer, notification, hospital, agent, assessment | 依赖多个服务 |
| app-web | domain | 依赖领域服务 |
| hospital-web | hospital | 依赖医院服务 |
| nginx | app-web, hospital-web | 网关依赖前端 |

### 11.2 依赖实现方式

通过设置initContainers或sidecar确保依赖服务先启动：
```yaml
initContainers:
  - name: wait-for-dependency
    image: busybox:1.36
    command:
      - sh
      - -c
      - |
        echo "Waiting for dependency service..."
        # 通过DNS名称等待依赖服务
        nslookup {{ .Values.dependency.serviceName }} || exit 1
```

---

## 十二、部署示例

### 12.1 开发环境部署 (x86)
```bash
helm install sk-agent-dev sk-agent \
  -f sk-agent/values-dev.yaml \
  -n sk-agent-dev \
  --create-namespace
```

### 12.2 ARM64环境部署 (使用Kingbase)
```bash
helm install sk-agent-arm64 sk-agent \
  -f sk-agent/values-prod.yaml \
  --set global.architecture=arm64 \
  -n sk-agent-prod \
  --create-namespace
```

### 12.3 生产环境部署（启用Ingress）
```bash
helm install sk-agent-prod sk-agent \
  -f sk-agent/values-prod.yaml \
  --set platform.nginx.ingress.enabled=true \
  --set platform.nginx.ingress.hosts[0].host=api.sk-agent.com \
  -n sk-agent-prod \
  --create-namespace
```

### 12.4 单独部署子Chart
```bash
# 仅部署Infra层
helm install sk-agent-infra sk-agent/charts/infra

# 仅部署RAG层
helm install sk-agent-rag sk-agent/charts/rag

# 仅部署Platform层
helm install sk-agent-platform sk-agent/charts/platform

# 单独部署某个服务
helm install sk-agent-mysql sk-agent/charts/infra/charts/mysql
```

---

## 十三、方案对比

| 特性 | 方案1 | 方案2 | 方案3 | 方案4(本) |
|------|-------|-------|-------|----------|
| 子Chart数量 | 24 | 0 | 24 | **3** |
| 业务分组 | 无 | 无 | 无 | **Infra/RAG/Platform** |
| 多路径存储 | 单路径 | 无 | 多路径 | 多路径 |
| ConfigMap | 无 | 无 | 有 | 有 |
| Ingress | 无 | 无 | 有 | 有 |
| 多架构支持 | 无 | 无 | 无 | **x86/arm64** |
| 部署粒度 | 服务级 | 整体 | 服务级 | **层/服务级** |

---

## 十四、设计优势总结

| 优势 | 说明 |
|------|------|
| **业务层分组** | 3个子Chart按业务领域划分，便于管理和理解 |
| **多架构支持** | x86使用MySQL，arm64使用Kingbase，动态切换 |
| **多路径持久化** | 单服务支持多个PVC挂载，不同路径不同存储大小 |
| **ConfigMap管理** | Java服务自动生成ConfigMap，热更新配置 |
| **Ingress支持** | nginx支持域名访问和TLS配置 |
| **层/服务级部署** | 可部署整个层，也可单独部署某个服务 |
| **模板复用** | 公共模板减少代码重复 |
| **环境适配** | dev/pre/prod三种环境配置 |

---

## 十五、文件清单

| 文件 | 说明 |
|------|------|
| `sk-agent/Chart.yaml` | 父Chart定义，3个子Chart依赖 |
| `sk-agent/values.yaml` | 默认配置 |
| `sk-agent/values-dev.yaml` | 开发环境配置 |
| `sk-agent/values-pre.yaml` | 预生产环境配置 |
| `sk-agent/values-prod.yaml` | 生产环境配置 |
| `sk-agent/templates/common/*.tpl` | 公共模板（7个） |
| `sk-agent/charts/infra/Chart.yaml` | Infra子Chart定义 |
| `sk-agent/charts/infra/charts/*/` | 4个Infra服务 |
| `sk-agent/charts/rag/Chart.yaml` | RAG子Chart定义 |
| `sk-agent/charts/rag/charts/*/` | 3个RAG服务 |
| `sk-agent/charts/platform/Chart.yaml` | Platform子Chart定义 |
| `sk-agent/charts/platform/charts/*/` | 21个Platform服务 |