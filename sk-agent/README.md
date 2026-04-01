# SK Agent Microservices Helm Chart

微服务架构产品的Helm部署方案，支持父子Chart结构、多环境配置、多架构部署。

## 架构概览

```
sk-agent/                          # 父Chart (L1)
├── Chart.yaml                     # 依赖所有子Foundation
├── values.yaml                    # 默认配置
├── values-dev.yaml               # 开发环境
├── values-pre.yaml               # 预生产环境
├── values-prod.yaml              # 生产环境
├── templates/
│   └── _helpers.tpl              # 全局辅助函数
└── charts/
    ├── middleware/               # L2: 中间件层
    │   └── charts/
    │       ├── database/          # 数据库 (MySQL/PostgreSQL/Kingbase)
    │       ├── redis/             # Redis缓存
    │       ├── rabbitmq/         # RabbitMQ消息队列
    │       └── minio/            # MinIO对象存储
    │
    ├── data-foundation/          # L2: 数据基座层
    │   └── charts/
    │       ├── memory/           # Memory服务
    │       ├── milvus/           # Milvus向量数据库
    │       └── rag-services/      # RAG服务
    │
    ├── model-foundation/          # L2: 模型基座层
    │   └── charts/
    │       ├── asr/              # ASR语音识别服务
    │       ├── vllm-30b/         # VLLM 30B模型
    │       ├── vllm-30b-lora/   # VLLM 30B LoRA模型
    │       ├── vllm-bge/        # BGE向量模型
    │       ├── vllm-reranker/   # Reranker模型
    │       └── vllm-vl-32b/     # VLLM VL 32B模型
    │
    ├── common-foundation/         # L2: 公共服务基座层
    │   └── charts/
    │       ├── user/             # 用户服务
    │       ├── domain/           # 领域服务
    │       ├── etl/             # ETL服务
    │       ├── storage/          # 存储服务
    │       ├── notification/     # 通知服务
    │       └── operation/        # 运营服务
    │
    ├── medical-brain/            # L2: 智能体层
    │   └── charts/
    │       ├── agent/            # Agent服务
    │       ├── agent-task/       # Agent任务服务
    │       └── scheduler/        # 调度服务
    │
    ├── biz-foundation/           # L2: 业务服务层
    │   └── charts/
    │       ├── assessment/       # 评估服务
    │       ├── customer/         # 客服服务
    │       ├── dashboard/        # 仪表盘服务
    │       ├── hospital/         # 医院服务
    │       └── tcm/             # 中医服务
    │
    └── gateway/                  # L2: 网关层
        └── charts/
            ├── manager/         # 管理服务
            ├── nginx/           # Nginx网关
            ├── app-web/         # App前端
            └── hospital-web/    # 医院前端
```

## 层级依赖关系

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Gateway Layer (网关层)                        │
│              Nginx → Manager → App-Web / Hospital-Web                   │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
┌─────────────────────────────────┴───────────────────────────────────────┐
│                      Business Service Layer (业务服务层)                  │
│         Assessment | Customer | Dashboard | Hospital | TCM              │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
┌─────────────────────────────────┴───────────────────────────────────────┐
│                     Medical Brain Layer (智能体层)                       │
│                    Agent ←→ Agent-Task ←→ Scheduler                    │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
┌─────────────────────────────────┴───────────────────────────────────────┐
│                    Common Foundation Layer (公共服务层)                   │
│              User | Domain | ETL | Storage | Notification               │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
┌─────────────────────────────────┴───────────────────────────────────────┐
│                      Model Foundation Layer (模型基座层)                   │
│        ASR | VLLM-30B | VLLM-30B-LoRA | VLLM-BGE | VLLM-Reranker       │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
┌─────────────────────────────────┴───────────────────────────────────────┐
│                      Data Foundation Layer (数据基座层)                   │
│                      Memory ← Milvus ← RAG-Services                     │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
┌─────────────────────────────────┴───────────────────────────────────────┐
│                       Middleware Layer (中间件层)                        │
│                      MySQL | Redis | RabbitMQ | MinIO                   │
└─────────────────────────────────────────────────────────────────────────┘
```

## 快速开始

### 1. 安装依赖

```bash
helm dependency build
```

### 2. 开发环境部署

```bash
# 创建命名空间
kubectl create namespace sk-agent-dev

# 创建镜像拉取密钥
kubectl create secret docker-registry registry-secret \
  --docker-server=saascr.shukun.net \
  --docker-username=your-username \
  --docker-password=your-password \
  -n sk-agent-dev

# 安装开发环境
helm install sk-agent-dev sk-agent \
  -f sk-agent/values-dev.yaml \
  -n sk-agent-dev \
  --create-namespace

# 查看部署状态
kubectl get pods -n sk-agent-dev

# 查看日志
kubectl logs -n sk-agent-dev -l app=user

# 卸载
helm uninstall sk-agent-dev -n sk-agent-dev
```

### 3. 预生产环境部署

```bash
kubectl create namespace sk-agent-pre
kubectl create secret docker-registry registry-secret \
  --docker-server=saascr.shukun.net \
  --docker-username=xxx \
  --docker-password=xxx \
  -n sk-agent-pre

helm install sk-agent-pre sk-agent \
  -f sk-agent/values-pre.yaml \
  -n sk-agent-pre \
  --create-namespace
```

### 4. 生产环境部署

```bash
kubectl create namespace sk-agent-prod
kubectl create secret docker-registry registry-secret \
  --docker-server=saascr.shukun.net \
  --docker-username=xxx \
  --docker-password=xxx \
  -n sk-agent-prod

helm install sk-agent-prod sk-agent \
  -f sk-agent/values-prod.yaml \
  -n sk-agent-prod \
  --create-namespace
```

## 配置说明

### 全局配置

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `global.environment` | 环境 | `dev` |
| `global.architecture` | 架构 | `amd64` |
| `global.storageClass` | 存储类 | `manual-sc` |
| `global.imagePullSecrets` | 镜像密钥 | `[]` |

### Middleware层配置

| 服务 | 端口 | 说明 |
|------|------|------|
| database | 3306/5432/5236 | MySQL/PostgreSQL/Kingbase |
| redis | 6379 | Redis缓存 |
| rabbitmq | 5672/15672 | AMQP/Mgmt |
| minio | 9000/9001 | S3兼容存储 |

### Data Foundation层配置

| 服务 | 端口 | 说明 |
|------|------|------|
| memory | 8080 | Memory服务 |
| milvus | 19530 | Milvus向量数据库 |
| rag-services | 8080 | RAG服务 |

### Model Foundation层配置

| 服务 | 端口 | 说明 |
|------|------|------|
| asr | 8080 | ASR语音识别 |
| vllm-30b | 8080 | VLLM 30B模型服务 |
| vllm-30b-lora | 8080 | VLLM 30B LoRA服务 |
| vllm-bge | 8080 | BGE向量模型 |
| vllm-reranker | 8080 | Reranker模型 |
| vllm-vl-32b | 8080 | VL 32B多模态模型 |

### Common Foundation层配置

| 服务 | 端口 | 说明 |
|------|------|------|
| user | 8080 | 用户服务 |
| domain | 8080 | 领域服务 |
| etl | 8080 | ETL服务 |
| storage | 8080 | 存储服务 |
| notification | 8080 | 通知服务 |
| operation | 8080 | 运营服务 |

### Medical Brain层配置

| 服务 | 端口 | 说明 |
|------|------|------|
| agent | 8080 | Agent服务 |
| agent-task | 8080 | Agent任务服务 |
| scheduler | 8080 | 调度服务 |

### Business Foundation层配置

| 服务 | 端口 | 说明 |
|------|------|------|
| assessment | 8080 | 评估服务 |
| customer | 8080 | 客服服务 |
| dashboard | 8080 | 仪表盘服务 |
| hospital | 8080 | 医院服务 |
| tcm | 8080 | 中医服务 |

### Gateway层配置

| 服务 | 端口 | 说明 |
|------|------|------|
| manager | 8080 | 管理服务 |
| nginx | 80 | Nginx网关 |
| app-web | 80 | App前端 |
| hospital-web | 80 | 医院前端 |

### 层级启用/禁用

每个层级可通过以下参数启用/禁用：

```yaml
middleware:
  enabled: true
  redis:
    enabled: true
    replicas: 1

data-foundation:
  enabled: true
  milvus:
    enabled: true

model-foundation:
  enabled: true
  vllm-30b:
    enabled: true
```

## 多架构支持

### x86_64 (amd64)

```yaml
global:
  architecture: amd64
```

### ARM64

```yaml
global:
  architecture: arm64
```

## 持久化存储

### 本地存储 (k3s开发环境)

```yaml
global:
  hostPath: "/tmp/volumes/mysql-dev"
  storageClass: "manual-sc"
```

## 健康检查

### Java服务

- Liveness: `/actuator/health/liveness`
- Readiness: `/actuator/health/readiness`

### Python服务

- Liveness: `/health`
- Readiness: `/health`

### Node服务

- Liveness: `/health`
- Readiness: `/health`

## 升级

```bash
# 升级到新版本
helm upgrade sk-agent-dev sk-agent \
  -f sk-agent/values-dev.yaml \
  -n sk-agent-dev

# 回滚
helm rollback sk-agent-dev -n sk-agent-dev
```

## 调试

```bash
# 查看所有资源
kubectl get all -n sk-agent-dev

# 查看ConfigMap
kubectl get cm -n sk-agent-dev

# 查看Secret
kubectl get secret -n sk-agent-dev

# 查看PVC
kubectl get pvc -n sk-agent-dev

# 端口转发进行测试
kubectl port-forward svc/user 8080:8080 -n sk-agent-dev

# 进入容器调试
kubectl exec -it <pod-name> -n sk-agent-dev -- /bin/bash
```

## License

MIT
