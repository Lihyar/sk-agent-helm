# SK-Agent 微服务架构 Helm 部署方案 (第四版 - 业务层分组)

## 一、设计背景

基于需求文档，本方案为包含中间件层(middleware)、数据基座层(data)、模型基座层(model)、公共服务基座层（common）、智能体(agent)层、业务服务层(biz) 和 网关层（gateway）产品设计Helm Chart部署方案。

---

## 二、设计原则

### 特性
1. **业务层分组** - 子Chart按业务领域划分
2. **多架构支持** - x86｜arm64
3. **多路径持久化** - 支持挂载多个PVC
4. **ConfigMap配置管理** -服务自动生成ConfigMap
5. **Ingress域名访问** - nginx支持Ingress配置
6. **模板统一复用** - 公共模板在父Chart中定义，子Chart通过include调用
7. **中间件尽量使用开源chart** - 尽量使用开源chart，个性化需求可提供设计方案
8. **数据库** - 按需选择不同数据库。如mysql、Postgres、kingbase。优先保障mysql，其他数据库之后再实现。
9. **持久化** -  StorageClass + HostPath + PV
10. **全局配置初始化** - 例如私有镜像仓库授权配置、用户配置


---

## 三、架构设计
### 3.1分层架构
1. 中间件层(middleware)：包括数据库、缓存、消息队列等基础服务
2. 数据基座层(data)：包括知识库服务
3. 模型基座层(model)：AI模型服务
4. 公共服务基座层(common)：通用服务
5. 智能体(agent)：智能体服务
6. 业务服务层(biz)：GHC业务服务

### 3.2 技术方案
#### 3.2.1 helm结构
```text
sk-agent/                        # L1: 产品架构编排，支持整体部署  
├── templates/
│   ├── _helpers.tpl
│   ├── NOTES.txt
│   └── common/   # 公共模板
│       ├── configmap.tpl          # ConfigMap生成模板                  
│       ├── deployment.tpl         # 后端服务模板
│       ├── node-deployment.tpl    # Node.js服务模板
│       ├── statefulset.tpl        # StatefulSet模板 (多路径)
│       ├── job.tpl                # Job模板
│       └── global.yaml            # 全局配置
├── charts/   
│   ├── middleware            # L2: 定义中间建层服务编排，支持按层部署。尽量使用开源配置
│       ├── Chart.yaml    
│       ├── values.yaml
│       └── charts
│           ├── mysql/        # L3：定义服务逻辑，支持按服务部署
│               ├── Chart.yaml    
│               └── values.yaml
│           ├── redis/
│           ├── rabbitmq/
│           ├── minio/
│           └── milvus/
│   ├── data-foundation/charts    # 定义数据基座层逻辑
│           ├── domain?
│           ├── memory-server
│           └── rag-server
│   ├── model-foundation/charts  # 定义模型基座层逻辑
│           ├── asr
│           ├── vllm-bge
│           ├── vllm-reranker
│           ├── vllm-30b
│           ├── vllm-30b-lora
│           └── vllm-vl-32b
│   ├── common-foundation/charts  # 定义公共服务层逻辑
│           ├── user         # 用户管理
│           ├── etl          # 信息提取
│           ├── storage      # 存储服务
│           ├── notification # 消息通知 
│           ├── operation    # 运营平台 
│           ├── edge-mgmt    # 边端管理
│           └──  asr-api     # 语音服务
│   ├── medical-brain/charts  # 定义智能体层逻辑
│           ├── agent
│           ├── agent-task
│           └── scheduler
│   └── biz-foundation/charts # 定义业务层逻辑
│           ├── healthcare    # 健康管理（包含前后端）
│           ├── assement      # 健康评估
│           ├── dashborad     # 数据统计
│           ├── hospital      # 医院服务（包含前后端）
│           └── tcm           # 中医服务
│   └── gateway/charts # 定义网关逻辑
│           ├── manager       # 网关管理
│           └── nginx         # 代理服务
├── Chart.yaml   
├── values.yaml                      # 默认配置
├── values-dev.yaml                  # 开发环境
├── values-pre.yaml                  # 预生产环境
├── values-prod.yaml                 # 生产环境
└── README.md
```
#### 3.2.2 配置说明
-  L1级配置
```yaml
# Chart.yaml：定义产品部署架构
apiVersion: v2
name: sk-agent
description: SK Agent Microservices Architecture - Parent Chart
type: application
version: 0.1.0
appVersion: "1.0.0"

keywords:
  - microservices
  - sk-agent
  - kubernetes
  - k3s

maintainers:
  - name: SK Agent Team
    email: team@example.com

dependencies:
  - name: middleware
    version: "0.1.0"
  - name: data-service
    version: "0.1.0"
  - name: model-service
    version: "0.1.0"
  - name: common-service
    version: "0.1.0" 
  - name: biz-service
    version: "0.1.0" 
  - name: medical-brain
    version: "0.1.0" 
  - name: gateway
    version: "0.1.0"  
```
- value.yaml：定义全局配置。部署环境、系统架构、命令空间、存储类等信息
```yaml
# Global settings
global:
  environment: dev
  architecture: amd64
  imagePullSecrets:
    - name: registry-secret
  storageClass: "manual-sc"
  serviceAccount:
    create: true
    name: "sk-agent-account"
  domain: "cluster.local"
```

- L2级配置
```yaml
# Chart.yaml： 定义层级服务及启动顺序
apiVersion: v2
name: sk-agent-service
description: SK Agent Microservices Architecture - Parent Chart
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  - name: svc-user
    version: "0.1.0"
    condition: svc-user.enabled
  - name: svc-domain
    version: "0.1.0"
    condition: svc-domain.enabled

keywords:
  - microservices
  - sk-agent
  - kubernetes
  - k3s
home: https://github.com/your-org/sk-agent
sources:
  - https://github.com/your-org/sk-agent
maintainers:
  - name: SK Agent Team
    email: team@example.com
```
- value.yaml
```yaml
# ==============================================================================
# Platform Services Layer - 子Chart配置 (svc-*)
# ==============================================================================
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

### 4.3 ConfigMap配置管理

**实现原理**：服务模板自动调用ConfigMap模板生成application.yaml，并挂载到容器/config目录

**模板文件**：`templates/common/java-configmap.tpl`
```yaml
{{- define "service.configmap" -}}
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

**实现原理**：根据全局配置动态切换数据库类型

**配置示例**：
```yaml
# values.yaml
global:
  architecture: amd64  # amd64 (x86) 或 arm64
# MySQL子Chart values.yaml
database:
  type: mysql 
  
# 模板中判断
{{- if eq .Values.global.database "mysql" }}
mysql.enabeled: true
{{- elif eq .Values.global.database "postgres" }}
postgres.enabeled: true
{{- elif eq .Values.global.database "kingbase" }}
kingbase.enabeled: true
{{- end }}
```

**架构差异**：

| 数据库 | MySQL 8.0 | Kingbase | postgres |
|-------|---------------|-------|-------|
| 镜像 | mysql:8.0 | kingbase:v8r6 | postgres:15-alpine
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

**后端服务（ConfigMap）**：
```yaml
{{ include "service.configmap" (dict "root" . "serviceName" .Values.name "applicationYaml" .Values.config) }}
{{ include "service.deployment" (dict "root" . "serviceName" .Values.name "image" .Values.image "port" .Values.service.port "resources" .Values.resources "configMap" true "javaOpts" .Values.javaOpts) }}
```

**有状态服务（多路径）**：
```yaml
{{ include "statefulset" (dict "root" . "name" .Values.name "image" .Values.image "port" .Values.service.port "volumes" .Values.volumes "env" .Values.env "resources" .Values.resources) }}
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
  # 中间件Layer (4个服务)
  - name: middleware
    version: "0.1.0"
    condition: infra.enabled
    repository: "file://charts/infra"

  # 数据基座 Layer (3个服务)
  - name: data-foundation
    version: "0.1.0"
    condition: rag.enabled
    repository: "file://charts/rag"
...
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

# Middleware Layer
middleware:
  enabled: true
  database:
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
...
```

### 6.3 Infra子Chart Chart.yaml

```yaml
apiVersion: v2
name: infra
description: Infrastructure Layer - Database, Redis, RabbitMQ, MinIO
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  - name: database
    version: "0.1.0"
    condition: database.enabled
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
| Database| StatefulSet | 有状态服务，支持多路径持久化，多类型（MySQL/Kingbase/Postgres ） |
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
| 数据库存储 | 5Gi | 20Gi | 100Gi |
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
  server: "saascr.shukun.net"
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