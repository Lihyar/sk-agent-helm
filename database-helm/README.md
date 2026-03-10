# Database Helm Chart

支持 x86 MySQL 和 ARM 人大金仓数据库的 Kubernetes Helm 部署方案。

## 功能特性

- ✅ 支持 MySQL (x86架构) 和 人大金仓 (ARM架构)
- ✅ 配置通过 ConfigMap 管理
- ✅ 密码通过 Secret 加密存储
- ✅ 持久化存储支持
- ✅ 外部访问服务配置
- ✅ 资源大小可调整
- ✅ 健康检查配置
- ✅ SSL 加密支持

## 前置要求

- Kubernetes 1.20+
- Helm 3.0+
- 支持StorageClass存储

## 安装部署

### 1. 单机环境 Local 模式（推荐）

```bash
helm install mydb ./database-helm \
  --set database.type=mysql \
  --set database.password=your-secure-password \
  --set persistence.hostPath=/data/database
```

### 2. 部署人大金仓数据库

```bash
helm install mykingbase ./database-helm \
  --set database.type=kingbase \
  --set database.password=your-secure-password \
  --set persistence.hostPath=/data/kingbase \
  --set nodeSelector."kubernetes\.io/arch"=arm64
```

### 3. StorageClass 模式（多节点环境）

```bash
helm install mydb ./database-helm \
  --set database.type=mysql \
  --set database.password=MySecurePassword123 \
  --set persistence.storageClass=local-path \
  --set persistence.size=50Gi \
  --set service.type=LoadBalancer \
  --set resources.requests.cpu=1000m \
  --set resources.requests.memory=2Gi \
  --set nodeSelector."kubernetes\.io/arch"=amd64
```

## 配置参数

### 数据库配置

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `database.type` | `mysql` | 数据库类型: `mysql` 或 `kingbase` |
| `database.name` | `mydatabase` | 数据库名称 |
| `database.user` | `dbuser` | 数据库用户 |
| `database.password` | - | 数据库密码 (必须设置) |
| `database.sslEnabled` | `false` | 是否启用SSL |

### MySQL 配置

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `mysql.image.repository` | `mysql` | MySQL镜像仓库 |
| `mysql.image.tag` | `8.0` | MySQL镜像版本 |
| `mysql.charset` | `utf8mb4` | 字符集 |
| `mysql.collation` | `utf8mb4_unicode_ci` | 排序规则 |
| `mysql.rootPassword` | `rootpassword` | root密码 |

### 人大金仓配置

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `kingbase.image.repository` | `kingbase/kingbase` | 人大金仓镜像仓库 |
| `kingbase.image.tag` | `v8.6` | 人大金仓镜像版本 |
| `kingbase.encoding` | `UTF8` | 编码 |
| `kingbase.locale` | `C` | 本地化 |

### 持久化存储

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `persistence.enabled` | `true` | 是否启用持久化 |
| `persistence.storageClass` | `""` | StorageClass 模式下的存储类 |
| `persistence.size` | `20Gi` | 存储大小 |
| `persistence.hostPath` | `/data/database` | Local 模式下的主机路径 |
| `persistence.accessMode` | `ReadWriteOnce` | 访问模式 |

### 服务配置

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `service.type` | `LoadBalancer` | 服务类型 |
| `service.port` | `3306` | 服务端口 |
| `service.targetPort` | `3306` | 容器端口 |
| `service.loadBalancerIP` | - | 负载均衡器IP |

### 资源配置

| 参数 | 默认值 | 描述 |
|------|--------|------|
| `resources.requests.cpu` | `500m` | CPU请求 |
| `resources.requests.memory` | `1Gi` | 内存请求 |
| `resources.limits.cpu` | `2000m` | CPU限制 |
| `resources.limits.memory` | `4Gi` | 内存限制 |

### 自定义资源配置

可以为不同数据库类型设置不同的资源配置:

```yaml
customResources:
  mysql:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 4Gi
  kingbase:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 4000m
      memory: 8Gi
```

## 部署模式

### 1. 单机环境 Local 模式（推荐）

```bash
# 部署MySQL
helm install mysql-db ./database-helm \
  --set database.type=mysql \
  --set database.password=MySecurePassword123 \
  --set persistence.hostPath=/data/mysql-data \
  --set nodeSelector."kubernetes\.io/arch"=amd64

# 部署人大金仓
helm install kingbase-db ./database-helm \
  --set database.type=kingbase \
  --set database.password=MySecurePassword123 \
  --set persistence.hostPath=/data/kingbase-data \
  --set nodeSelector."kubernetes\.io/arch"=arm64
```

### 2. 多节点环境 StorageClass 模式

```bash
# 部署MySQL
helm install mysql-db ./database-helm \
  --set database.type=mysql \
  --set database.password=MySecurePassword123 \
  --set persistence.storageClass=local-path \
  --set nodeSelector."kubernetes\.io/arch"=amd64

# 部署人大金仓
helm install kingbase-db ./database-helm \
  --set database.type=kingbase \
  --set database.password=MySecurePassword123 \
  --set persistence.storageClass=local-path \
  --set nodeSelector."kubernetes\.io/arch"=arm64
```

## SSL 配置

启用SSL加密:

```bash
helm install secure-db ./database-helm \
  --set database.sslEnabled=true \
  --set database.ssl.caCert=<base64-encoded-ca-cert> \
  --set database.ssl.serverCert=<base64-encoded-server-cert> \
  --set database.ssl.serverKey=<base64-encoded-server-key>
```

## 连接数据库

### MySQL 连接示例

```bash
# 获取服务IP
kubectl get svc mydb-database

# 连接MySQL
mysql -h <SERVICE_IP> -P 3306 -u dbuser -p mydatabase
```

### 人大金仓连接示例

```bash
# 获取服务IP  
kubectl get svc mykingbase-database

# 连接人大金仓
ksql -h <SERVICE_IP> -p 54321 -U dbuser -d mydatabase
```

## 监控和日志

查看Pod状态:
```bash
kubectl get pods -l app.kubernetes.io/name=database
kubectl logs -f statefulset/<release-name>-database
```

健康检查状态:
```bash
kubectl describe pod <pod-name>
```

## 升级

```bash
helm upgrade mydb ./database-helm \
  --set database.password=new-password \
  --set persistence.size=50Gi
```

## 卸载

```bash
helm uninstall mydb
# 如需删除PV和PVC
kubectl delete pvc data-mydb-database-0
kubectl delete pv <pv-name>
```

## 故障排除

### Local 模式常见问题

1. **Pod无法启动**: 
   - 检查存储路径是否存在：`ls -la /data/database`
   - 确认路径权限正确：`chmod 777 /data/database`
   - 查看Pod事件：`kubectl describe pod <pod-name>`

2. **存储权限问题**: 
   - 确保Kubernetes节点有权限访问存储路径
   - 检查SELinux设置（如启用）

### StorageClass 模式问题

1. **StorageClass不存在**: 确认Local Path Provisioner正常运行
2. **PVC一直处于Pending状态**: 检查存储类配置和资源配额

### 通用问题

1. **连接问题**: 检查Service配置和网络安全策略
2. **密码错误**: 查看Secret配置：`kubectl get secret <secret-name> -o yaml`

## 开发说明

如需修改模板，请更新以下文件：
- `templates/configmap.yaml` - 数据库配置
- `templates/secret.yaml` - 密码管理
- `templates/statefulset.yaml` - 部署配置
- `templates/service.yaml` - 服务配置
- `templates/pvc.yaml` - 存储声明配置
- `templates/pv.yaml` - 手动存储卷配置
- `values.yaml` - 默认值配置

## 单机环境部署步骤

单机环境没有StorageClass，需要按以下步骤部署：

### 方式一：Helm自动创建PV（推荐）

1. **准备存储目录**（在目标节点上执行）：
   ```bash
   sudo mkdir -p /data/database
   sudo chmod 777 /data/database
   ```

2. **部署数据库**：
   ```bash
   helm install mydb ./database-helm \
     --set database.type=mysql \
     --set database.password=YourPassword123 \
     --set persistence.hostPath=/data/database
   ```

3. **验证部署**：
   ```bash
   kubectl get statefulset
   kubectl get pv
   kubectl get pvc
   kubectl get pods
   ```

### 方式二：手动创建PV后部署

1. **手动创建PV**：
   ```bash
   # 创建存储目录
   sudo mkdir -p /data/database
   sudo chmod 777 /data/database
   
   # 应用PV配置
   kubectl apply -f - <<EOF
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: database-pv
     labels:
       database-pv: database-pv
   spec:
     capacity:
       storage: 20Gi
     accessModes:
       - ReadWriteOnce
     persistentVolumeReclaimPolicy: Retain
     storageClassName: ""
     local:
       path: /data/database
     nodeAffinity:
       required:
         nodeSelectorTerms:
           - matchExpressions:
               - key: kubernetes.io/hostname
                 operator: In
                 values:
                   - <您的节点名称>
   EOF
   ```

2. **部署数据库**：
   ```bash
   helm install mydb ./database-helm \
     --set database.type=mysql \
     --set database.password=YourPassword123 \
     --set persistence.hostPath=/data/database
   ```

3. **验证部署**：
   ```bash
   kubectl get statefulset
   kubectl get pv
   kubectl get pvc
   kubectl get pods
   kubectl logs -f statefulset/mydb-database
   ```