# SK-Agent 微服务架构 Helm 部署方案

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

## 二、架构设计

### 2.1 整体架构

```
sk-agent (父Chart)
│
├── charts/infra/           # 基础设施层
│   ├── mysql/              # MySQL 8.0 数据库
│   ├── redis/              # Redis 7.4 缓存
│   ├── rabbitmq/           # RabbitMQ 3.13 消息队列
│   └── minio/              # MinIO 对象存储
│
├── charts/rag/             # RAG层
│   ├── memory/             # Memory服务 (依赖MySQL)
│   ├── milvus/             # Milvus 向量数据库 (依赖MinIO)
│   └── rag-services/       # RAG服务 (依赖MySQL/Redis/Milvus)
│
├── charts/services/         # 平台服务层
│   ├── init-data/          # 数据初始化 (Job)
│   ├── user/               # 用户服务 (Java)
│   ├── domain/             # 领域服务 (Java)
│   ├── scheduler/          # 调度服务 (Java)
│   ├── agent/              # Agent服务 (Python)
│   ├── agent-task/         # Agent任务 (Python, 同agent镜像)
│   ├── operation/          # 运营服务 (Java)
│   ├── storage/            # 存储服务 (Java)
│   ├── etl/                # ETL服务 (Python)
│   ├── etl-listener/       # ETL监听 (Python, 同etl镜像)
│   ├── etl-beat/           # ETL调度 (Python, 同etl镜像)
│   ├── assessment/          # 评估服务 (Java)
│   ├── hospital/           # 医院服务 (Java)
│   ├── tcm/                # 中医服务 (Java)
│   ├── notification/       # 通知服务 (Java)
│   ├── customer/           # 客户服务 (Java)
│   ├── dashboard/          # 仪表盘服务 (Java)
│   ├── manager/            # 管理服务 (Java)
│   ├── java-service/       # Java服务模板
│   └── python-service/     # Python服务模板
│
└── charts/web/             # 前端层
    ├── app-web/            # App前端 (Node)
    ├── hospital-web/       # 医院前端 (Node)
    ├── nginx/              # Nginx网关
    └── web-service/        # Web服务模板
```

### 2.2 服务依赖关系

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
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ init-data (Job)                                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────┐ ┌───────┐ ┌──────────┐ ┌───────┐ ┌──────────┐       │
│  │ User │ │ Domain│ │ Scheduler│ │ Agent │ │Operation │  ...   │
│  └──────┘ └───────┘ └──────────┘ └───────┘ └──────────┘       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                      Manager                               │   │
│  │    (依赖: user, domain, storage, tcm, etl, customer,     │   │
│  │           notification, hospital, agent, assessment)       │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Platform Web Layer                         │
│  ┌──────────┐    ┌─────────────┐    ┌────────┐                │
│  │ app-web  │    │hospital-web │    │  Nginx │                │
│  └────┬─────┘    └──────┬──────┘    └───┬────┘                │
│       │                 │                │                      │
│       └─────────────────┼────────────────┘                      │
│                         ▼                                       │
│                   外部访问                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 三、模板复用设计

### 3.1 公共模板 (templates/common/)

公共模板用于定义可复用的 Kubernetes 资源模板，通过 Helm `include` 函数调用。

#### 3.1.1 java-deployment.tpl - Java服务部署模板

```yaml
{{- define "java.deployment" -}}
# 输出 Java 服务的 Deployment + Service
{{- end }}
```

**应用场景**: 所有Java微服务 (user, domain, scheduler等)

**功能**:
- 生成 Deployment 资源
- 自动配置 Spring Boot Actuator 健康检查端点
- 支持环境变量注入 (SPRING_PROFILES_ACTIVE)
- 支持自定义 command/args
- 资源限制配置

**调用示例**:
```yaml
{{- include "java.deployment" (dict "root" . "serviceName" "user" "image" .Values.services.user.image "port" 8080 "resources" .Values.services.user.resources) -}}
```

#### 3.1.2 python-deployment.tpl - Python服务部署模板

```yaml
{{- define "python.deployment" -}}
# 输出 Python 服务的 Deployment + Service
{{- end }}
```

**应用场景**: Python服务 (agent, etl, etl-listener, etl-beat等)

**功能**:
- 生成 Deployment 资源
- 健康检查端点 `/health`
- 默认使用 uvicorn 运行 FastAPI 应用
- 支持自定义启动命令
- 环境变量配置

**调用示例**:
```yaml
{{- include "python.deployment" (dict "root" . "serviceName" "agent" "image" .Values.services.agent.image "command" (list "python" "-m" "agent.task") "resources" .Values.services.agentTask.resources) -}}
```

#### 3.1.3 node-deployment.tpl - Node.js服务部署模板

```yaml
{{- define "node.deployment" -}}
# 输出 Node.js 服务的 Deployment + Service
{{- end }}
```

**应用场景**: 前端服务 (app-web, hospital-web)

**功能**:
- Node.js 应用部署
- 健康检查配置
- 环境变量支持

#### 3.1.4 job.tpl - 一次性任务模板

```yaml
{{- define "init.job" -}}
# 输出 Job 资源
{{- end }}
```

**应用场景**: init-data 数据初始化任务

**功能**:
- 生成 Job 资源
- 支持 `restartPolicy: OnFailure`
- 自动清理: `ttlSecondsAfterFinished: 300`
- 任务完成后自动删除 Pod

#### 3.1.5 statefulset.tpl - 有状态服务模板

```yaml
{{- define "statefulset" -}}
# 输出 StatefulSet + Service
{{- end }}
```

**应用场景**: 基础设施服务 (MySQL, Redis, RabbitMQ, MinIO)

**功能**:
- 生成 StatefulSet 资源
- 自动创建 PVC (PersistentVolumeClaim)
- 支持 headless Service
- 数据持久化配置
- Init Container 初始化权限

---

### 3.2 服务定义 (templates/services/, templates/infra/, templates/web/)

扁平化设计，所有服务定义在父Chart中，通过include调用公共模板。

#### 3.2.1 java-services.yaml - Java服务集合

包含12个Java微服务的Deployment和Service定义，每个服务通过include调用公共模板：

```yaml
{{- if .Values.services.enabled -}}
{{- if .Values.services.user.enabled }}
{{- $svc := .Values.services.user }}
{{- include "java.deployment" (dict "root" . "serviceName" "user" "image" $svc.image "port" $svc.service.port "resources" $svc.resources) -}}
{{- end }}
...
{{- end }}
```

#### 3.2.2 python-services.yaml - Python服务集合

包含5个Python微服务的Deployment和Service定义，支持同镜像不同启动命令：

- agent: 主服务
- agent-task: 同镜像，命令 `python -m agent.task`
- etl: ETL服务
- etl-listener: 同镜像，命令 `python -m etl.listener`
- etl-beat: 同镜像，命令 `python -m etl.beat`

#### 3.2.3 job.yaml - 一次性任务

包含 init-data 数据初始化Job。

#### 3.2.4 infra/*.yaml - 基础设施服务

- mysql.yaml: MySQL StatefulSet
- redis.yaml: Redis StatefulSet
- rabbitmq.yaml: RabbitMQ StatefulSet
- minio.yaml: MinIO StatefulSet

#### 3.2.5 web.yaml - 前端服务

- app-web: Node.js前端
- hospital-web: Node.js前端
- nginx: 网关代理

---

## 四、K8s 资源类型选择

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

## 五、多环境配置

### 5.1 环境差异对比

| 配置项 | dev | pre | prod |
|-------|-----|-----|------|
| StorageClass | manual-sc | standard | standard |
| MySQL存储 | 5Gi | 20Gi | 100Gi |
| Redis存储 | 1Gi | 5Gi | 20Gi |
| 服务副本数 | 1 | 2 | 2-3 |
| 资源配置 | 最低 | 中等 | 高 |
| Ingress | NodePort | LoadBalancer | LoadBalancer+TLS |

### 5.2 values文件

- **values.yaml**: 默认配置，所有环境的公共配置
- **values-dev.yaml**: 开发环境，低资源，hostPath存储
- **values-pre.yaml**: 预生产环境，中等资源
- **values-prod.yaml**: 生产环境，高可用，高资源

---

## 六、多架构支持

### 6.1 架构检测逻辑

```yaml
{{- $arch := default "amd64" (index .Values.nodeSelector "kubernetes.io/arch") }}
image: {{ if eq $arch "arm64" }}arm64v8/xxx{{ else }}xxx{{ end }}
```

### 6.2 支持的架构

| 架构 | 镜像示例 |
|------|---------|
| amd64 (x86_64) | mysql:8.0, redis:7.4 |
| arm64 | arm64v8/mysql:8.0, arm64v8/redis:7.4 |

---

## 七、私有镜像配置

### 7.1 ServiceAccount 配置

```yaml
# global/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sk-agent-account
```

### 7.2 镜像拉取密钥 (通过Helm自动创建)

```yaml
# sk-agent/templates/registry-secret.yaml
{{- if and .Values.registry.enabled .Values.registry.username .Values.registry.password }}
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: {{ printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\"}}}" .Values.registry.server .Values.registry.username .Values.registry.password | b64enc }}
{{- end }}
```

### 7.3 values.yaml 配置

```yaml
registry:
  enabled: true
  server: "registry.example.com"
  username: ""      # 填写私有仓库用户名
  password: ""      # 填写私有仓库密码
  email: ""
```

Secret会在部署时自动创建，无需手动执行kubectl命令。

---

## 八、存储配置

### 8.1 StorageClass

```yaml
# global/storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: manual-sc
provisioner: kubernetes.io/no-provisioner
```

### 8.2 开发环境 (hostPath)

```yaml
persistence:
  hostPath: "/tmp/volumes/mysql-dev"
  storageClass: "manual-sc"
```

### 8.3 生产环境 (云存储)

```yaml
persistence:
  storageClass: "standard"  # AWS EBS, GCE PD, Azure Disk
```

---

## 九、部署示例

### 9.1 开发环境部署

```bash
# 1. 创建命名空间
kubectl create namespace sk-agent-dev

# 2. 部署 (registry-secret会自动创建)
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

### 9.2 生产环境部署

```bash
kubectl create namespace sk-agent-prod

helm install sk-agent-prod sk-agent \
  --set registry.username=your-user \
  --set registry.password=your-pass \
  -f sk-agent/values-prod.yaml \
  -n sk-agent-prod \
  --create-namespace
```

---

## 十、文件清单

```
sk-agent/
├── Chart.yaml                      # 父Chart定义（无子Chart依赖）
├── values.yaml                     # 默认配置
├── values-dev.yaml                 # 开发环境
├── values-pre.yaml                 # 预生产环境
├── values-prod.yaml                # 生产环境
│
├── templates/
│   ├── _helpers.tpl               # 全局辅助函数
│   ├── registry-secret.yaml        # 镜像拉取密钥
│   ├── common/                    # 公共模板（被include调用）
│   │   ├── java-deployment.tpl     # Java服务模板
│   │   ├── python-deployment.tpl   # Python服务模板
│   │   ├── node-deployment.tpl     # Node.js服务模板
│   │   ├── job.tpl                # Job模板
│   │   └── statefulset.tpl        # StatefulSet模板
│   ├── infra/                     # 基础设施服务定义
│   │   ├── mysql.yaml             # MySQL
│   │   ├── redis.yaml             # Redis
│   │   ├── rabbitmq.yaml          # RabbitMQ
│   │   └── minio.yaml             # MinIO
│   ├── services/                  # 微服务定义
│   │   ├── java-services.yaml     # 12个Java服务
│   │   └── job.yaml               # init-data
│   └── web/                       # 前端服务定义
│       └── web.yaml               # app-web, hospital-web, nginx
```

---

## 十一、模板复用关系图

```
templates/common/ (公共模板定义)
       │
       ├── java-deployment.tpl  ────────────▶ templates/services/java-services.yaml
       │                                    └── user, domain, scheduler等Java服务
       │
       ├── python-deployment.tpl  ──────────▶ templates/services/python-services.yaml
       │                                    └── agent, etl, etl-listener等Python服务
       │
       ├── node-deployment.tpl  ───────────▶ templates/web/web.yaml
       │                                    └── app-web, hospital-web
       │
       ├── job.tpl  ───────────────────────▶ templates/services/job.yaml
       │                                    └── init-data
       │
       └── statefulset.tpl  ──────────────▶ templates/infra/*.yaml
                                                └── mysql, redis, rabbitmq, minio
```

---

## 十二、渲染资源统计

使用 `helm template test sk-agent` 渲染结果：

| 资源类型 | 数量 | 说明 |
|---------|------|------|
| StatefulSet | 6 | MySQL, Redis, RabbitMQ, MinIO, Memory, Milvus |
| Deployment | 21 | 12个Java + 5个Python + 3个Web + 1个RAG |
| Service | 27 | 基础设施 + 微服务端口 |
| ConfigMap | 5 | Redis, RabbitMQ, MinIO, Memory, Milvus |
| Secret | 5 | Redis, RabbitMQ, MinIO, Memory, Milvus |
| Job | 1 | init-data 数据初始化 |

### 服务清单

**Infra层 (4个StatefulSet)**:
- MySQL (3306)
- Redis (6379)
- RabbitMQ (5672/15672)
- MinIO (9000/9001)

**RAG层 (2个StatefulSet + 1个Deployment)**:
- Memory (3306) - 依赖MySQL
- Milvus (19530) - 依赖MinIO
- rag-services (8080) - 依赖MySQL, Redis, Milvus

**Platform Services层 (12个Java + 5个Python + 1个Job)**:
- Java: user, domain, scheduler, operation, storage, assessment, hospital, tcm, notification, customer, dashboard, manager
- Python: agent, agent-task, etl, etl-listener, etl-beat
- Job: init-data

**Web层 (3个Deployment)**:
- app-web (3000)
- hospital-web (3000)
- nginx (80)


### 设计优势
方案：扁平化设计 - 父Chart直接渲染所有服务
1. 无重复代码 - 所有服务复用公共模板
2. 配置集中 - values.yaml 包含所有服务配置
3. 部署简单 - 单一 Chart 部署全部服务
4. 易于维护 - 修改模板一处即可影响所有服务