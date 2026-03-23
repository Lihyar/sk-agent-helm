# SK Agent Microservices Helm Chart

微服务架构产品的Helm部署方案，支持父子Chart结构、多环境配置、多架构部署。

## 架构概览

```
sk-agent/                          # 父Chart
├── Chart.yaml                     # 依赖所有子Chart
├── values.yaml                    # 默认配置
├── values-dev.yaml               # 开发环境
├── values-pre.yaml               # 预生产环境
├── values-prod.yaml              # 生产环境
├── templates/
│   ├── _helpers.tpl              # 全局辅助函数
│   └── common/                   # 公共模板
│       ├── java-deployment.tpl   # Java服务模板
│       ├── python-deployment.tpl  # Python服务模板
│       ├── node-deployment.tpl    # Node.js服务模板
│       ├── job.tpl               # Job模板
│       └── statefulset.tpl       # StatefulSet模板
└── charts/
    ├── infra/                    # 基础设施层
    │   ├── mysql/                # MySQL数据库
    │   ├── redis/                # Redis缓存
    │   ├── rabbitmq/             # RabbitMQ消息队列
    │   └── minio/                # MinIO对象存储
    ├── rag/                      # RAG层
    │   ├── memory/               # Memory服务
    │   ├── milvus/               # Milvus向量数据库
    │   └── rag-services/         # RAG服务
    ├── services/                 # 平台服务层
    │   ├── init-data/            # 数据初始化Job
    │   ├── java-service/         # Java服务模板
    │   ├── python-service/       # Python服务模板
    │   ├── user/                 # 用户服务
    │   ├── domain/               # 领域服务
    │   ├── scheduler/            # 调度服务
    │   ├── agent/                # Agent服务
    │   ├── operation/            # 运营服务
    │   ├── storage/              # 存储服务
    │   ├── etl/                  # ETL服务
    │   ├── assessment/           # 评估服务
    │   ├── hospital/             # 医院服务
    │   ├── tcm/                  # 中医服务
    │   ├── notification/         # 通知服务
    │   ├── customer/             # 客户服努
    │   ├── dashboard/             # 仪表盘服务
    │   └── manager/              # 管理服务
    └── web/                      # 前端层
        ├── app-web/              # App前端
        ├── hospital-web/         # 医院前端
        ├── nginx/                # Nginx网关
        └── web-service/          # Web服务模板
```

## 服务依赖关系

```
Infra Layer (基础设施层)
├── MySQL ──────────┬─→ Platform Services
├── Redis ──────────┤
├── RabbitMQ ───────┤
└── MinIO ──────────┘

RAG Layer (RAG层)
├── Memory ──────────→ (依赖MySQL)
├── Milvus ──────────→ (依赖MinIO, etcd)
└── rag-services ─────→ (依赖MySQL, Redis, Milvus)

Platform Services (平台服务层)
├── init-data (Job) ──→ 初始化数据
├── user ─────────────→ [依赖]
├── domain ────────────→ [依赖]
├── scheduler ─────────→ [依赖]
├── agent ─────────────→ [依赖]
├── agent-task ────────→ (依赖scheduler)
├── operation ─────────→ [依赖]
├── storage ───────────→ [依赖]
├── etl ───────────────→ (依赖scheduler)
├── etl-listener ──────→ (同etl镜像)
├── etl-beat ──────────→ (同etl镜像, 依赖user,domain,operation)
├── assessment ────────→ [依赖]
├── hospital ──────────→ [依赖]
├── tcm ───────────────→ [依赖]
├── notification ──────→ [依赖]
├── customer ──────────→ [依赖]
├── dashboard ──────────→ (依赖operation)
└── manager ────────────→ (依赖所有服务)

Platform Web (前端层)
├── app-web ───────────→ (依赖domain)
├── hospital-web ──────→ (依赖hospital)
└── nginx ─────────────→ (代理app-web, hospital-web)
```

## 快速开始

### 1. 安装依赖

```bash
# 添加私有仓库
helm repo add sk-agent https://charts.example.com
helm repo update
```

### 2. 开发环境部署

```bash
# 创建命名空间
kubectl create namespace sk-agent-dev

# 创建镜像拉取密钥
kubectl create secret docker-registry registry-secret \
  --docker-server=registry.example.com \
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
  --docker-server=registry.example.com \
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
  --docker-server=registry.example.com \
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

### Infra层配置

| 服务 | 端口 | 说明 |
|------|------|------|
| mysql | 3306 | MySQL数据库 |
| redis | 6379 | Redis缓存 |
| rabbitmq | 5672/15672 | AMQP/Mgmt |
| minio | 9000/9001 | S3兼容存储 |

### Services层配置

每个服务可通过以下参数启用/禁用：

```yaml
services:
  user:
    enabled: true
    replicas: 1
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 2Gi
```

### Web层配置

```yaml
web:
  nginx:
    enabled: true
    service:
      type: LoadBalancer  # dev: NodePort, prod: LoadBalancer
```

## 多架构支持

### x86_64 (amd64)

```yaml
nodeSelector:
  kubernetes.io/arch: "amd64"
```

### ARM64

```yaml
nodeSelector:
  kubernetes.io/arch: "arm64"
```

## 持久化存储

### 本地存储 (k3s开发环境)

```yaml
persistence:
  hostPath: "/tmp/volumes/mysql-dev"
  storageClass: "manual-sc"
```

### 云存储 (生产环境)

```yaml
persistence:
  storageClass: "standard"  # AWS EBS, GCE PD, Azure Disk
```

## 服务端口映射

| 服务 | 端口 | 协议 |
|------|------|------|
| MySQL | 3306 | TCP |
| Redis | 6379 | TCP |
| RabbitMQ | 5672 | AMQP |
| RabbitMQ MGMT | 15672 | HTTP |
| MinIO API | 9000 | HTTP |
| MinIO Console | 9001 | HTTP |
| Milvus | 19530 | gRPC |
| Java Services | 8080 | HTTP |
| Python Services | 8080 | HTTP |
| Node Services | 3000 | HTTP |
| Nginx | 80 | HTTP |

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
kubectl exec -it user-0 -n sk-agent-dev -- /bin/bash
```

## License

MIT
