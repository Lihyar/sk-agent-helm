# Redis Helm Chart

支持 x86 和 ARM 架构的 Redis Kubernetes Helm 部署方案。

## 功能特性

- ✅ 支持 x86 和 ARM 架构
- ✅ 配置通过 ConfigMap 管理
- ✅ 密码通过 Secret 加密存储
- ✅ 使用 StorageClass 持久化
- ✅ 外部访问服务配置
- ✅ 资源大小可调整
- ✅ 健康检查配置

## 前置要求

- Kubernetes 1.20+
- Helm 3.0+

## 安装部署

### 1. 
```bash
helm install myredis ./redis-helm \
  --set persistence.storageClass=manual-sc
```

### 3. ARM 架构部署

```bash
helm install myredis ./redis-helm \
  --set nodeSelector.kubernetes.io/arch=arm64
```

## 配置参数

### Redis 配置

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `redis.mode` | `standalone` | 部署模式: `standalone` 或 `cluster` |
| `redis.database` | `0` | 数据库编号 |
| `redis.image.repository` | `redis` | Redis 镜像仓库 |
| `redis.image.tag` | `7.4` | Redis 镜像版本 |

### ARM 配置

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `redis_arm.image.repository` | `arm64v8/redis` | ARM Redis 镜像仓库 |
| `redis_arm.image.tag` | `7.4` | ARM Redis 镜像版本 |

### 持久化存储

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `persistence.enabled` | `true` | 是否启用持久化 |
| `persistence.storageClass` | `""` | Cluster 模式下的存储类 |
| `persistence.size` | `10Gi` | 存储大小 |
| `persistence.hostPath` | `/tmp/sk-redis-data` | Standalone 模式下的主机路径 |
| `persistence.accessMode` | `ReadWriteOnce` | 访问模式 |

### 服务配置

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `service.type` | `ClusterIP` | 服务类型 |
| `service.port` | `6379` | 服务端口 |
| `service.targetPort` | `6379` | 容器端口 |

### 资源配置

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `resources.requests.cpu` | `100m` | CPU 请求 |
| `resources.requests.memory` | `256Mi` | 内存请求 |
| `resources.limits.cpu` | `500m` | CPU 限制 |
| `resources.limits.memory` | `1Gi` | 内存限制 |

### Redis 配置

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `redisConfig.maxmemory` | `256mb` | 最大内存 |
| `redisConfig.maxmemoryPolicy` | `allkeys-lru` | 内存淘汰策略 |
| `redisConfig.appendonly` | `yes` | AOF 持久化 |

## 连接 Redis

```bash
# 获取服务 IP
kubectl get svc myredis-redis

# 连接 Redis
redis-cli -h <SERVICE_IP> -p 6379 -a <PASSWORD>
```

## 升级

```bash
helm upgrade myredis ./redis-helm \
  --set persistence.size=20Gi
```

## 卸载

```bash
helm uninstall myredis
```

## 故障排除

### Pod 无法启动

1. 检查存储路径是否存在
2. 确认路径权限正确：`chmod 777 /tmp/sk-redis-data`
3. 查看 Pod 事件：`kubectl describe pod <pod-name>`

### 连接问题

1. 检查 Service 配置
2. 确认密码正确
3. 查看 Pod 日志：`kubectl logs <pod-name>`
