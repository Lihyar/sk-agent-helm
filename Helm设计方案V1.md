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
{{- include "java.deployment" (dict "root" . "serviceName" "user" "image" .Values.services.user.image) -}}
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
**应用场景**: 基础设施服务 (MySQL, Redis, RabbitMQ, MinIO, Milvus)
**功能**:
- 生成 StatefulSet 资源
- 自动创建 PVC (PersistentVolumeClaim)
- 支持 headless Service
- 数据持久化配置
- Init Container 初始化权限
---
### 3.2 服务模板 (charts/services/)
#### 3.2.1 java-service/ - Java服务通用模板
```
charts/services/java-service/
├── Chart.yaml              # apiVersion: v2, name: java-service
├── values.yaml             # 默认配置
└── templates/
    ├── _helpers.tpl       # Helm 辅助函数
    ├── deployment.yaml     # Java Deployment
    └── service.yaml        # ClusterIP Service
```
**作用**: 作为Java服务的通用模板，提供:
- 标准Java微服务部署配置
- 默认端口 8080
- Spring Boot 健康检查配置
- 资源限制默认值
**使用方式**: 其他Java服务可引用此模板或直接复制修改。
#### 3.2.2 python-service/ - Python服务通用模板
```
charts/services/python-service/
├── Chart.yaml              # apiVersion: v2, name: python-service
├── values.yaml             # 默认配置
└── templates/
    ├── _helpers.tpl       # Helm 辅助函数
    ├── deployment.yaml     # Python Deployment
    └── service.yaml        # ClusterIP Service
```
**作用**: 作为Python服务的通用模板，提供:
- 标准Python微服务部署配置
- 默认端口 8080
- uvicorn 默认启动命令
- `/health` 健康检查端点
**使用方式**: agent, etl, etl-listener 等Python服务可引用此模板。
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
### 7.2 ImagePullSecrets
```yaml
# values.yaml
global:
  imagePullSecrets:
    - name: registry-secret  # 需提前创建
```
### 7.3 Secret 创建
```bash
kubectl create secret docker-registry registry-secret \
  --docker-server=registry.example.com \
  --docker-username=xxx \
  --docker-password=xxx \
  -n sk-agent
```
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
# 2. 创建镜像拉取密钥
kubectl create secret docker-registry registry-secret \
  --docker-server=registry.example.com \
  --docker-username=xxx \
  --docker-password=xxx \
  -n sk-agent-dev
# 3. 部署
helm install sk-agent-dev sk-agent \
  -f sk-agent/values-dev.yaml \
  -n sk-agent-dev \
  --create-namespace
# 4. 查看状态
kubectl get pods -n sk-agent-dev
# 5. 端口转发测试
kubectl port-forward svc/user 8080:8080 -n sk-agent-dev
```
### 9.2 生产环境部署
```bash
kubectl create namespace sk-agent-prod
kubectl create secret docker-registry registry-secret \
  --docker-server=registry.example.com \
  --docker-username=xxx \
  --docker-password=xxx \
  -n sk-agent-prod
helm install sk-agent-prod sk-agent \
  -f sk-agent/values-prod.yaml \
  -n sk-agent-prod \
  --create-namespace
```
---
## 十、文件清单
```
sk-agent/
├── Chart.yaml                      # 父Chart定义
├── values.yaml                     # 默认配置
├── values-dev.yaml                 # 开发环境
├── values-pre.yaml                 # 预生产环境
├── values-prod.yaml                # 生产环境
├── README.md                       # 文档
│
├── templates/
│   ├── _helpers.tpl               # 全局辅助函数
│   └── common/
│       ├── java-deployment.tpl     # Java服务模板
│       ├── python-deployment.tpl   # Python服务模板
│       ├── node-deployment.tpl     # Node.js服务模板
│       ├── job.tpl                 # Job模板
│       └── statefulset.tpl         # StatefulSet模板
│
└── charts/
    ├── infra/
    │   ├── Chart.yaml
    │   ├── mysql/
    │   ├── redis/
    │   ├── rabbitmq/
    │   └── minio/
    │
    ├── rag/
    │   ├── Chart.yaml
    │   ├── memory/
    │   ├── milvus/
    │   └── rag-services/
    │
    ├── services/
    │   ├── Chart.yaml
    │   ├── java-service/           # Java服务模板
    │   ├── python-service/          # Python服务模板
    │   ├── init-data/
    │   ├── user/
    │   ├── domain/
    │   ├── scheduler/
    │   ├── agent/
    │   ├── agent-task/
    │   ├── operation/
    │   ├── storage/
    │   ├── etl/
    │   ├── etl-listener/
    │   ├── etl-beat/
    │   ├── assessment/
    │   ├── hospital/
    │   ├── tcm/
    │   ├── notification/
    │   ├── customer/
    │   ├── dashboard/
    │   └── manager/
    │
    └── web/
        ├── Chart.yaml
        ├── web-service/             # Web服务模板
        ├── nginx/
        ├── app-web/
        └── hospital-web/
```
---
## 十一、模板复用关系图
```
templates/common/ (公共模板)
       │
       ├── java-deployment.tpl  ────────────▶ 各个Java微服务
       │                                    (user, domain, scheduler等)
       │
       ├── python-deployment.tpl  ──────────▶ 各个Python服务
       │                                    (agent, etl, etl-listener等)
       │
       ├── node-deployment.tpl  ───────────▶ 前端服务
       │                                    (app-web, hospital-web)
       │
       ├── job.tpl  ───────────────────────▶ init-data
       │
       └── statefulset.tpl  ───────────────▶ 基础设施服务
                                               (mysql, redis, rabbitmq, minio)
charts/services/ (服务模板)
       │
       ├── java-service/  ─────────────────▶ 作为参考模板
       │     └── 提供标准Java服务部署配置      其他Java服务可复制或引用
       │
       └── python-service/  ────────────────▶ 作为参考模板
```