# Kubernetes StatefulSet 从入门到精通

> 本指南只讲 StatefulSet 一件事，从"它到底是什么"一路讲到"如何运维一套有状态集群"。
> 所有 YAML 都在本目录下，可以直接 `kubectl apply -f` 运行。

---

## 目录

- [第 0 章：先建立直觉](#第-0-章先建立直觉)
- [第 1 章：StatefulSet 到底解决什么问题](#第-1-章statefulset-到底解决什么问题)
- [第 2 章：三大核心机制](#第-2-章三大核心机制)
- [第 3 章：完整字段解剖](#第-3-章完整字段解剖)
- [第 4 章：生命周期与有序性](#第-4-章生命周期与有序性)
- [第 5 章：存储深入](#第-5-章存储深入)
- [第 6 章：更新与回滚](#第-6-章更新与回滚)
- [第 7 章：网络与集群发现](#第-7-章网络与集群发现)
- [第 8 章：调度、高可用与中断](#第-8-章调度高可用与中断)
- [第 9 章：与 Deployment 的彻底对比](#第-9-章与-deployment-的彻底对比)
- [第 10 章：生产实战模式](#第-10-章生产实战模式)
- [第 11 章：精通级陷阱清单](#第-11-章精通级陷阱清单)
- [附录：命令速查与文件索引](#附录命令速查与文件索引)

---

## 第 0 章：先建立直觉

### 0.1 一句话定义

> **StatefulSet 是给"有身份的应用"用的控制器：它为每个副本分配一个永久不变的编号（0,1,2…），并把这个编号同时绑定到网络名和存储卷上。**

三个关键词：**编号（ordinal）**、**绑定（binding）**、**不变（stability）**。

### 0.2 什么样的应用需要它

判断标准只有一条：**这个应用的重启/重建，是否需要"复原本人"而不是"随便一个新实例"？**

| 类型 | 例子 | 用 StatefulSet？ | 原因 |
|---|---|---|---|
| 无状态 Web API | nginx、Spring Boot、Node 服务 | ❌ 用 Deployment | 任意副本等价，随机名字没区别 |
| 数据库主从 | MySQL、PostgreSQL、Redis 主从 | ✅ | 主库从库身份不同，数据不能串 |
| 分布式共识 | etcd、ZooKeeper、Consul | ✅ | 成员有固定 ID，需按名单组建集群 |
| 消息队列 | Kafka、RabbitMQ 镜像队列 | ✅ | 分区/队列与 broker 绑定 |
| 搜索引擎 | Elasticsearch、SolrCloud | ✅ | 分片分配依赖节点稳定身份 |
| 对象存储 | MinIO 分布式 | ✅ | 纠删码分片与磁盘序号绑定 |
| 定时任务 | CronJob | ❌ | 用 CronJob |
| 一次性批处理 | Job | ❌ | 用 Job |

反过来也有反例：**有些应用"看起来有状态"但不需要 StatefulSet** —— 比如把 session 存到 Redis 的无状态服务，仍应使用 Deployment。

### 0.3 最小可运行例子

```bash
# 详见 01-basic/statefulset-simple.yaml
kubectl apply -f 01-basic/statefulset-simple.yaml
kubectl get pods -l app=nginx-sts -w
```

你会看到：

```
NAME          READY   STATUS              AGE
nginx-sts-0   0/1     ContainerCreating   0s
nginx-sts-0   1/1     Running             3s
nginx-sts-1   0/1     ContainerCreating   3s     ← 0 号 Ready 后才创建
nginx-sts-1   1/1     Running             6s
nginx-sts-2   0/1     ContainerCreating   6s
nginx-sts-2   1/1     Running             9s
```

这就是 StatefulSet 的第一课：**串行、有序、带编号**。

---

## 第 1 章：StatefulSet 到底解决什么问题

### 1.1 从 Deployment 的"缺陷"说起

Deployment 创建的 Pod 名字是 `myapp-7d9f8b6c4-x2k9p` —— 一段随机 hash。这带来三个"不可追溯"：

1. **身份不可追溯**：Pod 重建后，你无法知道"这到底是原来那个，还是新的"
2. **网络不可追溯**：Pod IP 每次重建都变，Service 只提供负载均衡，不提供"固定地址"
3. **存储不可追溯**：多个副本共享一个 PVC 会打架（尤其是 RWO 卷或需要独占的数据库）

对无状态服务这三个都不是问题。但对数据库：

```
主库挂了要重启 → 新 Pod 变成 myapp-7d9f8b6c4-p8k2j
              → IP 从 10.1.2.3 变成 10.1.2.9
              → 它该挂哪块盘？谁是新的主？
              → 从库怎么找到它？
```

**StatefulSet 的答案是把这三样都用"序号"锚定：**

| 维度 | Deployment | StatefulSet |
|---|---|---|
| Pod 名 | `app-<hash>-<rand>` | `app-0`、`app-1`、`app-2` |
| 重建后名字 | 变 | **不变** |
| 网络标识 | 只有 Service VIP | `<pod>.<svc>.<ns>.svc.cluster.local` **永久** |
| 存储 | 共享 PVC（或不用） | 每副本独占 PVC `data-app-0`，**永久绑定** |
| 启动顺序 | 并行 | 默认串行（0→1→2） |
| 删除顺序 | 并行 | 默认逆序（2→1→0） |
| 滚动更新 | 从新到旧，批量 | 从最大序号开始，一次一个 |
| 扩缩容 | 任意 | 只能从尾部增减（改的是 `replicas`，不是删指定 Pod） |

### 1.2 它不是什么

- **不是"带持久化存储的 Deployment"** —— 这个理解非常危险。StatefulSet 的核心是**身份**，存储只是身份的一个载体。
- **不是万能的** —— 它不提供数据复制、不提供选主、不提供故障自动转移。这些是**应用自己的责任**（或用 Operator）。
- **不保证"主节点"在哪** —— 序号 0 不是主节点，只是编号最小。谁是主由应用决定（etcd 由 raft 选举，MySQL 靠 group replication）。

### 1.3 一张架构图

```
                        ┌──────────────────────────────────┐
                        │  StatefulSet (name: db, rep: 3)  │
                        └───────────────┬──────────────────┘
                                        │ 按序号模板化生成
        ┌───────────────────────────────┼───────────────────────────────┐
        ▼                               ▼                               ▼
  ┌──────────┐                    ┌──────────┐                    ┌──────────┐
  │  db-0    │                    │  db-1    │                    │  db-2    │
  │ name 固定│                    │ name 固定│                    │ name 固定│
  └────┬─────┘                    └────┬─────┘                    └────┬─────┘
       │                               │                               │
       │ DNS                           │ DNS                           │ DNS
       ▼                               ▼                               ▼
 db-0.db.svc                     db-1.db.svc                     db-2.db.svc
 (Headless Service: clusterIP=None) ─── 每个 Pod 一条独立 A 记录

       │                               │                               │
       │ PVC                           │ PVC                           │ PVC
       ▼                               ▼                               ▼
  data-db-0                       data-db-1                       data-db-2
  (PV-A, 1Gi)                     (PV-B, 1Gi)                     (PV-C, 1Gi)
       │                               │                               │
       └────────── 序号把「名字 / DNS / 磁盘」三者焊死 ─────────────────┘
```

---

## 第 2 章：三大核心机制

### 2.1 机制一：ordinal（编号）

StatefulSet 控制器从 `0` 到 `replicas-1` 生成 Pod 名：`<sts-name>-<ordinal>`。

编号的来源与影响：

- **副本数调整只能从尾部**：`replicas: 3 → 5` 会创建 `-3`、`-4`；`5 → 3` 会删除 `-4`、`-3`。你**不能**指定"删除 1 号"。
- **编号是身份的一部分**：应用可以通过 downward API 读到自己的序号，从而决定角色（如 `hostname` 解析、`metadata.name` 的后缀）。
- **序号影响一切**：PVC 名、DNS 名、启动顺序、更新顺序。

```yaml
# 让应用知道自己的序号
env:
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name          # db-2
  - name: POD_IP
    valueFrom:
      fieldRef:
        fieldPath: status.podIP
  - name: POD_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
```

> **进阶技巧**：从 `POD_NAME` 提取序号在 bash 里：
> ```bash
> ORDINAL="${POD_NAME##*-}"    # db-2 → 2
> ```

### 2.2 机制二：稳定网络标识

StatefulSet 通过 `spec.serviceName` 指向一个 **Headless Service**（`clusterIP: None`），从而为每个 Pod 生成**独立的、永久的 A 记录**：

```
<pod-name>.<service-name>.<namespace>.svc.<cluster-domain>
db-0.db.default.svc.cluster.local
```

注意区分两种 DNS 查询：

| 查询 | 返回 | 用途 |
|---|---|---|
| `db-0.db` | 单个 IP（Pod 自己的） | 直连特定成员（主库、特定分片） |
| `db` （Headless Service 本身） | **所有 Ready Pod 的 IP 列表** | 客户端轮询 / 服务发现 |

对比普通 ClusterIP Service：它只返回一个 VIP，由 kube-proxy 做 L4 负载均衡，你**永远无法指定访问哪个 Pod**。

这就是"有状态"的网络基础：Kafka 的 broker 之间、etcd 的 peer 之间，都必须能精确指向"那个特定成员"，而不是"随便一个"。

`publishNotReadyAddresses` 的取舍见 [7.2](#72-publishnotreadyaddresses要不要开)。

### 2.3 机制三：稳定存储（volumeClaimTemplates）

```yaml
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

控制器为每个副本生成一个 PVC，命名规则：

```
<volumeClaimTemplate.metadata.name>-<statefulset.metadata.name>-<ordinal>
data-db-0
data-db-1
data-db-2
```

**三条铁律**（每一条都值得背下来）：

1. **PVC 与序号绑定，不随 Pod 重建而改变** —— `db-1` 删了重建，仍然挂 `data-db-1`
2. **PVC 的生命周期独立于 Pod** —— 删 Pod、缩容、甚至删 StatefulSet，PVC 默认都保留
3. **改名即重建** —— 如果你试图修改 `volumeClaimTemplates`（哪怕只是改容量），已存在的 PVC **不会**跟着变（详见 5.4）

---

## 第 3 章：完整字段解剖

一个"字段注释版"的完整模板：

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: default
spec:
  # ═══════════════ 必填项 ═══════════════
  replicas: 3
  serviceName: db                  # 必填！指向 Headless Service，决定 DNS
  selector:                        # 必填！且创建后不可改
    matchLabels:
      app: db
  template:                        # 必填！Pod 模板
    metadata:
      labels:
        app: db                    # 必须匹配 selector
    spec:
      containers:
        - name: mysql
          image: mysql:8.0

  # ═══════════════ 序号管理 ═══════════════
  podManagementPolicy: OrderedReady
  # OrderedReady（默认）：串行创建 0→1→2，逆序删除 2→1→0
  # Parallel：并行创建/删除，仍有稳定身份，但无顺序保证
  # 选型：有启动依赖（MySQL 主从）用 OrderedReady
  #       无依赖（Cassandra 分片）用 Parallel

  # ═══════════════ 更新策略 ═══════════════
  updateStrategy:
    type: RollingUpdate             # 或 OnDelete
    rollingUpdate:
      partition: 0
      # partition: N 表示只更新 ordinal >= N 的 Pod
      #   = 0  → 全部更新（默认）
      #   = 2  → 只更新 2 号（金丝雀）
      #   = 99 → 全部冻结（等效手动模式）

  # ═══════════════ 就绪判定 ═══════════════
  minReadySeconds: 10
  # Pod Ready 后要持续这么久才被认为"更新完成"/"可用"
  # 用于防止"假就绪"导致顺序推进过快

  # ═══════════════ 缩容/删除时 PVC 回收 ═══════════════
  persistentVolumeClaimRetentionPolicy:   # K8s 1.27 GA
    whenScaled: Retain                    # 缩容时保留 PVC（默认）
    whenDeleted: Retain                   # 删 STS 时保留 PVC（默认）
    # 改为 Delete 则自动清理 —— 仅适用于"缓存类可丢数据"场景

  # ═══════════════ 历史版本保留 ═══════════════
  revisionHistoryLimit: 10
  # 保留多少个 ControllerRevision（供 rollout undo）
  # 设为 0 则无法回滚

  # ═══════════════ 存储模板 ═══════════════
  volumeClaimTemplates:
    - metadata:
        name: data
        labels: {}                 # 可加标签，便于批量管理 PVC
        annotations: {}            # 部分 CSI 驱动用注解传参
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: standard  # 不写则用默认 SC
        volumeMode: Filesystem      # 或 Block（需应用直接操作块设备）
        resources:
          requests:
            storage: 10Gi
        selector: {}                # 可选：预绑定特定 PV
```

### 3.1 不可变字段（改了会报错）

```
spec.selector              创建后不可修改
spec.serviceName           创建后可改，但改会导致 DNS 变化（重建才生效）
spec.podManagementPolicy   创建后不可修改
spec.volumeClaimTemplates  创建后不可修改
  └ metadata.name          不可改
  └ 已生成 PVC 的 spec     只能扩容，不能缩容/改 accessModes
```

试图修改时报错：

```
The StatefulSet "db" is invalid: spec: Forbidden: updates to statefulset spec
for fields other than 'replicas', 'ordinals', 'template', 'updateStrategy',
'revisionHistoryLimit', 'persistentVolumeClaimRetentionPolicy' and 'minReadySeconds'
are forbidden
```

**许可证清单（可改字段）**：`replicas`、`template`、`updateStrategy`、`minReadySeconds`、`revisionHistoryLimit`、`persistentVolumeClaimRetentionPolicy`、`ordinals`(1.31+ beta)。

---

## 第 4 章：生命周期与有序性

### 4.1 创建流程（OrderedReady）

```
replicas: 3

① 创建 db-0        → 等 db-0 phase=Running 且 Ready
② 创建 db-1        → 等 db-1 phase=Running 且 Ready
③ 创建 db-2        → 等 db-2 phase=Running 且 Ready
④ 完成，currentReplicas=3, readyReplicas=3
```

"Ready" 的定义：**所有容器的 readinessProbe 通过**（没配探针则视为容器启动即 Ready）。

> ⚠️ 高发卡点：`db-0` 的 readinessProbe 依赖 `db-1`（比如集群 quorum），而 `db-1` 还没被创建 → **死锁**。
> 解法：改 `podManagementPolicy: Parallel`，并考虑开 `publishNotReadyAddresses`。

### 4.2 删除流程（OrderedReady）

- **缩容**（`replicas` 变小）：从最大序号开始删，删一个等它彻底消失再删下一个
- **删除 StatefulSet**（默认 `--cascade=foreground`）：同样从最大序号开始，逆序
- **单独删 Pod**（**不缩容**）：控制器会**立刻重建同一个序号**，不涉及顺序

> 记住这条区别：**删 Pod ≠ 缩容**。删 Pod 是"重启某人"，缩容是"请某人离开"。

### 4.3 Readiness 与"有序"的关系

这是新手最容易误解的地方：

```
顺序推进的唯一条件是「前一个 Pod Ready」
────────────────────────────────────────
Ready 不是 Running！ContainerCreating/Running 但不 Ready 都不会推进。
```

所以对慢启动的数据库，**必须配 `startupProbe`**，否则：

```
liveness 探测失败 → 容器被 SIGKILL → 重启 → 又探测失败 → 无限重启
→ db-0 永远不 Ready → db-1/db-2 永远不创建 → 整个集群卡在 0 号
```

正确做法（见 `03-storage/statefulset-pvc.yaml`）：

```yaml
startupProbe:                # 只在启动阶段生效，成功后不再探测
  exec:
    command: ["mysqladmin", "ping", "-uroot", "-p$(MYSQL_ROOT_PASSWORD)"]
  failureThreshold: 30       # 30 × 10s = 5 分钟容忍启动
  periodSeconds: 10
readinessProbe:              # 启动成功后接管 "是否可服务"
  exec:
    command: ["mysqladmin", "ping", "-uroot", "-p$(MYSQL_ROOT_PASSWORD)"]
  periodSeconds: 10
livenessProbe:               # 运行期检测死锁（注意别和 readiness 打架）
  exec:
    command: ["mysqladmin", "ping", "-uroot", "-p$(MYSQL_ROOT_PASSWORD)"]
  periodSeconds: 20
  failureThreshold: 3
```

**探针设计原则（有状态服务版）**：

| 探针 | 语义 | 有状态服务的注意点 |
|---|---|---|
| `startupProbe` | 启动是否完成 | 必须给足（数据库首次初始化可能几分钟） |
| `readinessProbe` | 能否接流量 | 不要依赖"集群整体健康"，否则一个成员抖动会连锁卡死 |
| `livenessProbe` | 进程是否僵死 | **不要**检查外部依赖（DB 连不上不该重启自身）；否则故障扩散 |

> 经典事故：`livenessProbe` 里检查"能否连上主库"，主库一抖动 → 从库全部被重启 → 集群崩塌。

### 4.4 Parallel 模式

```yaml
podManagementPolicy: Parallel
```

- 一次性把 `db-0/1/2` 都创建出来，不等 Ready
- 删除时也并行
- **仍保留**稳定名字 / DNS / PVC 绑定
- 适用：成员间无启动依赖，或依赖"全体同时在"才能组建集群（etcd、ZK 配合 `publishNotReadyAddresses`）

---

## 第 5 章：存储深入

### 5.1 完整存储链路

```
volumeClaimTemplates (模板)
        │  为每个 ordinal 实例化
        ▼
PVC: data-db-0  ──── 绑定 ────▶  PV: pvc-xxxx (由 StorageClass 动态制备)
        │                              │
        │  被 Pod 挂载                  │  实际后端
        ▼                              ▼
   Pod db-0                       EBS / Ceph / NFS / Local SSD
       mountPath: /var/lib/mysql
```

### 5.2 accessModes 与 StatefulSet 的匹配

| 模式 | 含义 | 能否用于 StatefulSet 多副本 |
|---|---|---|
| `ReadWriteOnce` (RWO) | 单**节点**读写 | ✅ **最常用**，每副本一块盘 |
| `ReadOnlyMany` (ROX) | 多节点只读 | 少见，如共享配置 |
| `ReadWriteMany` (RWX) | 多节点读写 | ⚠️ 只有 NFS/CephFS/EFS 支持；多副本写同一目录通常**是错的** |
| `ReadWriteOncePod` (RWOP，1.29 GA) | 单 **Pod** 读写 | ✅ 最严格，防止同节点两个 Pod 抢卷 |

> **反模式**：给 StatefulSet 的 3 个副本挂同一个 RWX PVC。看起来"数据共享很方便"，实际上多个数据库进程写同一个数据目录 = **数据损坏**。StatefulSet 的正确姿势永远是"每副本独占"。

### 5.3 StorageClass 的选择

```yaml
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: fast-ssd   # 显式指定，不要依赖默认 SC
```

| 场景 | 推荐 SC 特性 |
|---|---|
| 数据库 | `volumeBindingMode: WaitForFirstConsumer` + 本地 SSD/云盘 |
| 需要扩容 | `allowVolumeExpansion: true` |
| 数据要跨集群迁移 | 支持快照/克隆的 CSI |
| 成本敏感 | HDD 类 SC + `reclaimPolicy: Retain` |

**为什么 `WaitForFirstConsumer` 对有状态服务很重要？**

本地盘 PV 绑定到特定节点。如果先创建 PVC 再调度 Pod，可能导致"Pod 被调度到节点 A，但 PV 在节点 B"→ 永远 Pending。延迟绑定让 Pod 先确定节点，再在该节点上制备卷。

### 5.4 PVC 扩容（高频痛点）

**事实**：修改 `volumeClaimTemplates` 里的 `storage` 大小，**不会**影响已存在的 PVC。

```bash
# ① 确认 SC 支持扩容
kubectl get sc <sc-name> -o jsonpath='{.allowVolumeExpansion}'   # 需为 true

# ② 逐个扩容已存在的 PVC
for i in 0 1 2; do
  kubectl patch pvc data-db-$i -p \
    '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
done

# ③ 观察状态（短暂 Resizing，之后变 20Gi）
kubectl get pvc data-db-0 -w

# ④ 部分 CSI 需要重启 Pod 才能让文件系统看到新容量
kubectl delete pod db-0    # 会重建，PVC 不变
```

**缩容是不可能的** —— K8s 不支持缩小 PVC。只能：

```
备份数据 → 创建小 PVC → 恢复数据 → 切换
```

### 5.5 PVC 回收策略矩阵

| 动作 | `whenScaled`/`whenDeleted` = `Retain`（默认） | `= Delete` |
|---|---|---|
| 缩容 `3→1` | PVC 保留 | `-2`、`-1` 的 PVC **被删除** |
| 删 Pod | PVC 保留 | PVC 保留 |
| 删 StatefulSet | 全部 PVC 保留 | 全部 PVC **被删除** |
| 恢复副本数 | 重新挂回原 PVC，数据还在 | 数据**永久丢失** |

```yaml
persistentVolumeClaimRetentionPolicy:
  whenScaled: Retain
  whenDeleted: Retain
```

> 默认值 `Retain` 是**安全**的选择。如果你在做"临时测试集群"，可以设 `Delete` 图方便，但**生产环境永远不要**。

### 5.6 完整实验：验证"数据跟着身份走"

```bash
kubectl apply -f 03-storage/pvc-lab.yaml
kubectl rollout status sts/store --timeout=180s

# 写入身份标记
for i in 0 1 2; do kubectl exec store-$i -- sh -c "echo pod-$i > /data/id"; done

# 实验 A：删 Pod → 数据仍在
kubectl delete pod store-1
kubectl wait --for=condition=Ready pod/store-1 --timeout=120s
kubectl exec store-1 -- cat /data/id     # pod-1 ✅

# 实验 B：缩容再扩容 → 数据仍在
kubectl scale sts store --replicas=1
kubectl get pvc -l app=store             # 3 个 PVC 都还在
kubectl scale sts store --replicas=3
kubectl exec store-2 -- cat /data/id     # pod-2 ✅

# 实验 C：删 StatefulSet → PVC 仍在
kubectl delete sts store
kubectl get pvc -l app=store             # 仍然存在
kubectl delete pvc -l app=store          # 手动清理
```

---

## 第 6 章：更新与回滚

### 6.1 更新方向：与 Deployment 相反

```
Deployment  RollingUpdate：
  旧 [A][A][A]  → 新 Pod 起 1 个，杀掉 1 个旧的，再起再杀...
  过程是"新旧混跑"，容量不降（maxSurge）

StatefulSet RollingUpdate：
  旧 [0][1][2]  → 停 [2] → 起新 [2] → Ready → 停 [1] → 起新 [1] → ...
  过程是"每次少 1 个副本"，从最大序号倒着来
```

为什么反向？因为 **0 号通常是最重要的**（初始成员、leader 候选、单点初始化节点）。最后更新它，能把风险降到最低。

### 6.2 partition：金丝雀更新的官方机制

```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    partition: 2
```

语义：**只更新 `ordinal >= partition` 的 Pod**。当 `replicas: 3`：

| partition | 被更新的 Pod | 场景 |
|---|---|---|
| 3 | 无 | 完全冻结 |
| 2 | `-2` | 金丝雀：先看 2 号表现 |
| 1 | `-2`, `-1` | 扩大范围 |
| 0 | `-2`, `-1`, `-0` | 全量（默认） |

**三阶段灰度实操**：

```bash
# 阶段 1：只更新 2 号
kubectl patch sts db -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'
kubectl set image sts/db mysql=mysql:8.1
kubectl rollout status sts/db
# 观察 2 号一段时间：日志、监控、慢查询

# 阶段 2：扩到 2 号和 1 号
kubectl patch sts db -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":1}}}}'

# 阶段 3：全量（0 号最后更新）
kubectl patch sts db -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
```

### 6.3 OnDelete：完全手动

```yaml
updateStrategy:
  type: OnDelete
```

- 改镜像后**不会**自动更新任何 Pod
- 你手动 `kubectl delete pod db-2`，它才会用新模板重建
- 适用：需要精确控制更新窗口的敏感集群（如金融、核心 DB）

### 6.4 更新卡住怎么办

```bash
kubectl rollout status sts/db          # 看卡在哪个序号
kubectl get pods -l app=db -o wide
kubectl describe pod db-2 | tail -20
kubectl logs db-2 --previous           # 崩溃前的日志
```

| 卡点 | 原因 | 处理 |
|---|---|---|
| `db-2` 一直 ContainerCreating | 镜像拉取失败 / PVC 绑定失败 | 检查 `describe` 事件 |
| `db-2` CrashLoopBackOff | 新版本不兼容旧数据 | 回滚！ |
| 更新到 `db-1` 就停了 | `db-2` 没 Ready | 修 `db-2` |
| 完全没动静 | `partition` 太大 或 `type: OnDelete` | 检查 `updateStrategy` |

### 6.5 回滚

```bash
kubectl rollout history sts/db
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>

kubectl rollout undo sts/db              # 回到上一版
kubectl rollout undo sts/db --to-revision=1   # 回到指定版本

kubectl rollout status sts/db
```

**重要限制**：`rollout undo` 只回滚 **Pod 模板**（镜像、命令、环境变量等）。**不回滚 PVC 中的数据**。

> 如果新版本已经把数据目录迁移/升级了（如 MySQL 8.0 → 8.4 的数据格式变更），回滚镜像会启动失败。所以**数据库升级前必须备份**，这是 StatefulSet 无法帮你解决的问题。

### 6.6 revisionHistoryLimit

```yaml
revisionHistoryLimit: 10      # 默认 10
```

每个 ControllerRevision 是一个压缩过的 Pod 模板快照，很占 etcd 空间。生产上 10 够用；设成 `0` 就无法回滚了。

---

## 第 7 章：网络与集群发现

### 7.1 DNS 详解

假设 `namespace: prod`、`sts: kafka`、`svc: kafka`、`replicas: 3`：

| 域名 | 类型 | 返回 |
|---|---|---|
| `kafka-0.kafka.prod.svc.cluster.local` | A | `10.1.1.5`（Pod 0 的 IP） |
| `kafka-1.kafka.prod.svc.cluster.local` | A | `10.1.2.7` |
| `kafka.prod.svc.cluster.local` | A | `[10.1.1.5, 10.1.2.7, 10.1.3.9]`（所有 Ready Pod） |
| `kafka-0.kafka` | SRV | `_<port-name>._tcp...` （含端口） |

**在 Pod 内部可以用短名**（同 namespace）：

```bash
kubectl exec kafka-0 -- nslookup kafka-1.kafka
kubectl exec kafka-0 -- nslookup kafka            # Service 级，返回所有
```

**为什么 SRV 记录有用**？因为它带端口信息。有些服务发现客户端（如 gRPC 的 `dns:///`、Kafka 的某些实现）需要同时知道 host 和 port。

### 7.2 publishNotReadyAddresses：要不要开？

```yaml
apiVersion: v1
kind: Service
metadata:
  name: kafka
spec:
  clusterIP: None
  publishNotReadyAddresses: true    # ← 关键
  selector:
    app: kafka
```

| 设置 | Pod 未 Ready 时 | 适用 |
|---|---|---|
| `false`（默认） | **不**出现在 DNS/Endpoints | 客户端只应连到能服务的实例 |
| `true` | 出现在 DNS/Endpoints | 成员需要"看到彼此"才能一起就绪 |

**必须开 `true` 的场景（集群启动死锁）**：

```
Kafka/etcd/ZooKeeper 的第一次启动：
  每个成员需要连上 peers 才能完成选主 → 才能 Ready
  但 peers 还没 Ready → 默认不在 DNS 里 → 找不到 → 永远不 Ready
```

**开着有风险**：客户端可能被路由到还没准备好的实例。所以**只在 Headless Service 上开**，并且应用层要能容忍连接失败并重试。

### 7.3 两种客户端模式

**模式 A：直连特定成员**（需要身份语义）

```bash
# 主库写入
mysql -h db-0.db -u root -p

# 特定分片
curl http://shard-3.shard:8080/api
```

**模式 B：Service 级轮询**（需要负载均衡）

```yaml
# Headless + 客户端侧 LB
# 客户端解析 db.default.svc.cluster.local → 得到所有 IP → 自行轮询/哈希
```

> 注意：Headless Service **不做**负载均衡，`kube-proxy` 不会介入。要么客户端自己轮询，要么再加一个普通 ClusterIP Service 做 L4 代理（Kafka 常见做法：Headless 用于 broker 间通信，ClusterIP 用于 bootstrap）。

### 7.4 双 Service 模式（生产常见）

```yaml
# ① Headless：给成员间通信用，提供 per-Pod DNS
apiVersion: v1
kind: Service
metadata:
  name: kafka-headless
spec:
  clusterIP: None
  publishNotReadyAddresses: true
  selector:
    app: kafka
  ports:
    - name: broker
      port: 9092
---
# ② ClusterIP：给客户端做 bootstrap，负载均衡到任意 broker
apiVersion: v1
kind: Service
metadata:
  name: kafka-bootstrap
spec:
  selector:
    app: kafka
  ports:
    - name: broker
      port: 9092
      targetPort: 9092
```

StatefulSet 的 `spec.serviceName` 指向 ①。

### 7.5 hostNetwork 的坑

```yaml
spec:
  template:
    spec:
      hostNetwork: true     # ⚠️ 谨慎
```

开了 `hostNetwork` 后：

- Pod 不再有独立 IP，DNS 解析走节点网络
- **Headless Service 的 per-Pod DNS 会失效**（Pod 用的是节点 IP）
- 端口冲突（同一节点上 `db-0` 和 `db-1` 都想用 3306 → 冲突）

只有极少数场景需要（如网络插件自身、需要固定端口暴露）。**StatefulSet 通常不该用**。

---

## 第 8 章：调度、高可用与中断

### 8.1 反亲和：别把鸡蛋放一个篮子

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:   # 软约束
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              app: etcd
```

- `preferred`（软）：尽量分散，节点不够时也能调度 → **推荐用于有状态服务**（否则副本数 > 节点数时会一直 Pending）
- `required`（硬）：必须分散，节点不够就 Pending → 只有副本数 ≤ 节点数且不容忍同机时用

### 8.2 拓扑分布约束（更现代的方式）

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone       # 按可用区均摊
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: etcd
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname            # 再按节点均摊
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: etcd
```

与 `podAntiAffinity` 的区别：

| | podAntiAffinity | topologySpreadConstraints |
|---|---|---|
| 语义 | "不要和 X 在同一拓扑域" | "在整个拓扑域里尽可能均匀" |
| 粒度 | 二元（同/不同） | 数量级（maxSkew 容忍差） |
| 推荐 | 特殊需求 | **通用场景优先用这个** |

### 8.3 PodDisruptionBudget（PDB）

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: etcd-pdb
spec:
  maxUnavailable: 1          # 或 minAvailable: 2
  selector:
    matchLabels:
      app: etcd
```

**PDB 保护的是"主动驱逐"**（`kubectl drain`、节点升级、集群缩容），**不保护**：

- 节点宕机（硬件故障）
- Pod 自己崩溃
- `kubectl delete pod`（不是驱逐）

对 etcd/ZK 这类需要 quorum 的集群：

```yaml
maxUnavailable: 1     # 3 副本时，允许一次驱逐 1 个 → 保留 2 个 → 仍有 quorum
```

> ⚠️ `minAvailable` 写死后扩缩容不会跟着变。用 `maxUnavailable` 更灵活，或用 `minAvailable: 50%`。

### 8.4 节点亲和与本地盘

用本地盘时，**必须**让 Pod 调度到有盘的节点：

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values: ["node-1"]
```

但更优雅的做法：**让 `volumeBindingMode: WaitForFirstConsumer` 配合 PV 的 `nodeAffinity` 自动完成**，不需要在 StatefulSet 里硬编码节点（见 `05-advanced/advanced-features.yaml`）。

### 8.5 优雅终止（有状态服务必配）

```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 60     # 给足时间
      containers:
        - name: db
          lifecycle:
            preStop:
              exec:
                command:
                  - sh
                  - -c
                  - |
                    # 1. 主动交出 leader（避免其他成员等着超时）
                    # 2. 刷盘
                    # 3. 摘除自己
                    sleep 10
```

终止时序：

```
kubectl delete pod db-0
  ↓
① Pod 从 Service Endpoints 移除（异步，需要时间传播）
② preStop 钩子执行
③ SIGTERM 发给容器主进程
④ 等待 terminationGracePeriodSeconds
⑤ 超时则 SIGKILL
```

**为什么要 `preStop` + `sleep`？** 因为步骤 ① 是异步的：Pod 已经从 Endpoints 删除，但 kube-proxy/ingress 的规则更新有延迟，此时如果立刻 SIGTERM，会有少量流量打到正在退出的 Pod。对有状态服务，这可能导致连接中断或数据不一致。

---

## 第 9 章：与 Deployment 的彻底对比

| 维度 | Deployment | StatefulSet |
|---|---|---|
| **定位** | 无状态服务 | 有状态服务 |
| **Pod 名** | `app-<rs-hash>-<rand>` | `app-0` / `app-1` / … |
| **名字稳定性** | 每次重建都变 | **永久不变** |
| **网络标识** | 仅 Service VIP，无法定位单个 Pod | per-Pod DNS `<pod>.<svc>` |
| **Headless Service** | 可选 | **必需**（`serviceName` 必填） |
| **存储** | 共享 PVC / emptyDir / 无 | 每副本独占 PVC（`volumeClaimTemplates`） |
| **PVC 命名** | 手动创建 | `<vct>-<sts>-<ordinal>` 自动 |
| **创建顺序** | 并行 | 默认串行 0→1→2 |
| **删除顺序** | 并行 | 默认逆序 2→1→0 |
| **扩容** | 任意增加 | 从尾部增加（`-n`） |
| **缩容** | 任意减少（可能删任意 Pod） | 从尾部减少（`-max` 先走） |
| **滚动更新方向** | 乱序/批量，先起后杀 | 从最大序号起，一次一个 |
| **分批更新** | `maxSurge`/`maxUnavailable` | `partition`（按序号切） |
| **回滚** | `rollout undo` | `rollout undo`（同样支持） |
| **HPA** | ✅ 自然搭配 | ⚠️ 慎用（副本数变化=成员变化） |
| **ReplicaSet 中间层** | 有 | 无（直接管 Pod） |
| **适用** | Web/API/网关 | DB/MQ/共识/搜索 |

### 什么时候可以"用 Deployment 冒充有状态"

有些团队会给 Deployment 挂 PVC 当"有状态"用。这在以下条件**全部满足**时勉强可行：

1. 副本数恒为 1（无多副本协调问题）
2. 能接受 Pod 重建后**换一块盘**（或挂同一块盘的 RWX）
3. 不需要稳定网络标识

只要有一条不满足，就该上 StatefulSet。**单副本 + PVC 是最常见的"不该用 Deployment"的坑**。

---

## 第 10 章：生产实战模式

### 10.1 模式一：主从（0 号为主）

```yaml
# 用序号决定角色
command:
  - bash
  - -c
  - |
    ORDINAL="${HOSTNAME##*-}"
    if [ "$ORDINAL" = "0" ]; then
      exec mysqld --server-id=1 --log-bin --gtid-mode=ON
    else
      exec mysqld --server-id=$((ORDINAL+1)) \
        --replicate-do-db=app \
        --master-host=db-0.db
    fi
```

**要点**：主库是 0 号（`db-0.db` 域名），从库靠 `db-0.db` 找主。故障切换需要外部组件（Orchestrator / MHA / Operator）。

### 10.2 模式二：共识集群（etcd / ZK）

见 `04-update/etcd-cluster.yaml`。核心三点：

```yaml
podManagementPolicy: Parallel              # ① 全体同时启动
# ② Service 开 publishNotReadyAddresses
# ③ initial-cluster 里硬编码全部成员域名（不用 IP）
env:
  - name: INITIAL_CLUSTER
    value: "etcd-0=http://etcd-0.etcd:2380,etcd-1=http://etcd-1.etcd:2380,etcd-2=http://etcd-2.etcd:2380"
```

验证：

```bash
kubectl apply -f 04-update/etcd-cluster.yaml
kubectl exec etcd-0 -- etcdctl member list
kubectl exec etcd-0 -- etcdctl endpoint health --cluster
kubectl exec etcd-0 -- etcdctl put foo bar
kubectl exec etcd-1 -- etcdctl get foo          # 从另一个成员读到
```

### 10.3 模式三：分片（Sharding）

```yaml
# 每个副本负责一部分数据，序号即分片 ID
env:
  - name: SHARD_ID
    valueFrom:
      fieldRef:
        fieldPath: metadata.name      # shard-0..N
  - name: TOTAL_SHARDS
    value: "4"
```

应用按 `hash(key) % TOTAL_SHARDS == SHARD_ID` 决定数据归属。**扩容时不会自动 rebalance** —— 这必须由应用实现。

### 10.4 模式四：Operator（生产级答案）

自己写 StatefulSet 管数据库，很快会撞墙：

- 主从切换怎么做？
- 备份/恢复怎么做？
- 版本升级的顺序和兼容性谁保证？
- 加成员要 `member add`，缩成员要 `member remove`，谁执行？

**这就是 Operator 存在的意义**。Operator = CRD + 自定义控制器，内部仍然用 StatefulSet，但补齐了领域知识。

| 数据库 | Operator |
|---|---|
| PostgreSQL | CloudNativePG、Zalando postgres-operator |
| MySQL | MySQL Operator、Vitess |
| etcd | etcd-operator |
| Kafka | Strimzi |
| Elasticsearch | ECK |
| MongoDB | MongoDB Community Operator |
| Redis | Redis Operator / Sentinel |

**学习建议**：先用裸 StatefulSet 跑一遍（理解原理），再上 Operator（理解工程化）。

### 10.5 生产 Checklist

```yaml
# ① 存储
volumeClaimTemplates:
  spec:
    storageClassName: <显式指定，不用默认>
    accessModes: ["ReadWriteOnce"]
    resources: {requests: {storage: <留 2x 余量>}}

# ② 回收策略（保持安全默认）
persistentVolumeClaimRetentionPolicy:
  whenScaled: Retain
  whenDeleted: Retain

# ③ 探针三件套
startupProbe:   {failureThreshold: 30, periodSeconds: 10}
readinessProbe: {periodSeconds: 10}      # 不依赖外部服务
livenessProbe:  {periodSeconds: 20}      # 只检查自身进程

# ④ 优雅终止
terminationGracePeriodSeconds: 60
lifecycle: {preStop: {...}}

# ⑤ 资源
resources:
  requests: {cpu: ..., memory: ...}      # 必须设！否则 QoS = BestEffort，最先被驱逐
  limits: {memory: ...}                  # 内存必须限，防止 OOM 拖垮节点

# ⑥ 可用性
affinity: {podAntiAffinity: {preferred...}}
topologySpreadConstraints: [{...}]
PodDisruptionBudget: {maxUnavailable: 1}

# ⑦ 更新
updateStrategy: {type: RollingUpdate, rollingUpdate: {partition: 0}}
minReadySeconds: 10
revisionHistoryLimit: 10

# ⑧ 可观测
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "<metrics-port>"
```

---

## 第 11 章：精通级陷阱清单

### 陷阱 1：改了 volumeClaimTemplates 却没生效

```yaml
# 你把它从 1Gi 改成 10Gi
volumeClaimTemplates:
  spec: {resources: {requests: {storage: 10Gi}}}
```

**结果**：新 PVC 才是 10Gi，**旧的仍是 1Gi**。而且这条修改本身可能被 API Server 拒绝（`volumeClaimTemplates` 是不可变字段，某些版本允许改但被忽略）。

**正解**：逐个 `kubectl patch pvc`（见 5.4）。

### 陷阱 2：删 StatefulSet 时忘了 PVC

```bash
kubectl delete sts db
kubectl get pvc          # data-db-0/1/2 还在！
kubectl apply -f db.yaml # 新 STS 又挂回这些 PVC → 带着旧数据启动
```

有时这是你要的（接管现有数据），有时不是（你以为重装了）。**删之前想清楚**。

### 陷阱 3：OrderedReady + 慢启动 = 全集群卡死

`db-0` 因为初始化（导入大 SQL、建索引）要 20 分钟，`livenessProbe` 30 秒就判死 → 无限重启 → `db-1/2` 永不创建。

**正解**：`startupProbe.failureThreshold` 给到足够大（如 180 = 30 分钟）。

### 陷阱 4：livenessProbe 检查外部依赖

```yaml
# ❌ 错误示范
livenessProbe:
  exec:
    command: ["sh", "-c", "mysql -h db-0.db -e 'select 1'"]
```

主库挂了 → 所有从库 liveness 失败 → **全部重启** → 集群彻底崩。

**正解**：liveness 只检查**本进程**（`pg_isready -U postgres` 本地，或 `/healthz` 只返回进程状态）。

### 陷阱 5：`serviceName` 写错或漏写

```yaml
spec:
  serviceName: db-svc      # 但 Service 名叫 db
```

**结果**：Pod 没有 `<pod>.<svc>` 域名（`hostname -f` 只有短名），集群成员互相找不到。

**检查**：`kubectl get sts db -o jsonpath='{.spec.serviceName}'` 必须与 Service 名**完全一致**，且该 Service 必须 `clusterIP: None`。

### 陷阱 6：用 RWX 让多副本共享一块盘

3 个 MySQL 挂同一个 NFS PV → 两个进程同时写 `ibdata1` → **数据损坏，不可恢复**。

**正解**：`volumeClaimTemplates` 永远让每个副本独占（RWO）。

### 陷阱 7：partition 忘了改回去

```bash
kubectl patch sts db -p '{"partition":2}'    # 灰度时改的
# ... 后来忘了
kubectl set image sts/db mysql=8.4           # 只有 2 号更新，0/1 还是旧版
```

**检查**：`kubectl get sts db -o jsonpath='{.spec.updateStrategy.rollingUpdate.partition}'` 应为 `0`。

**建议**：灰度脚本里把"恢复 partition=0"写成固定步骤，别靠人记。

### 陷阱 8：缩容时应用没做数据迁移

```bash
kubectl scale sts shard --replicas=2    # 删掉 shard-2
# shard-2 上有 1/4 的数据 → 谁负责迁移到 shard-0/1？
```

StatefulSet **不会**帮你 rebalance。数据丢失是必然的，除非应用有"下线前主动迁移"的 preStop 逻辑。

### 陷阱 9：用 kubectl delete pod 代替缩容

```bash
kubectl delete pod db-2      # 控制器立刻重建 db-2！
```

想永久减少副本，只能改 `replicas`。`delete pod` 语义是"重启这个人"。

### 陷阱 10：没设 resources.requests

QoS 变成 `BestEffort`，节点内存紧张时**第一个被驱逐**。对有状态服务是灾难（可能引发连锁重启）。

**正解**：至少设 `requests`。`requests == limits` 可得 `Guaranteed` QoS。

### 陷阱 11：迁移集群时的身份衔接

```bash
# 老集群
kubectl get pvc -o yaml > pvc-backup.yaml
# 新集群 apply → PVC 会重新绑定，但数据在新集群的 PV 里不存在！
```

PVC 只是"声明"，**数据在 PV 后端**。跨集群迁移必须迁移**数据**（快照 / rsync / 备份恢复），不是 YAML。

### 陷阱 12：minReadySeconds 与滚动速度

```yaml
minReadySeconds: 300    # 每个 Pod 都要等 5 分钟
# replicas=10 → 最坏 50 分钟更新完
```

知道这个成本，别在紧急修复时设太大。

---

## 附录：命令速查与文件索引

### A. 常用命令

```bash
# ─── 查看 ───
kubectl get sts                                    # 概览
kubectl get sts db -o yaml                         # 完整定义
kubectl get pods -l app=db -o wide                 # Pod 与节点/IP
kubectl get pvc -l app=db                          # 所有 PVC
kubectl get pvc data-db-0 -o jsonpath='{.spec.volumeName}'   # PVC → PV
kubectl get endpoints db                           # Headless 的后端
kubectl get sts db -o jsonpath='{.spec.updateStrategy}'      # 当前更新策略
kubectl get sts db -o jsonpath='{.spec.serviceName}'         # 关联的 svc

# ─── 伸缩 ───
kubectl scale sts db --replicas=5
kubectl patch sts db -p '{"spec":{"replicas":3}}'

# ─── 更新 ───
kubectl set image sts/db mysql=mysql:8.4
kubectl rollout status sts/db
kubectl rollout history sts/db
kubectl rollout undo sts/db --to-revision=1
kubectl rollout restart sts/db                     # 触发一次滚动重启

# ─── partition 灰度 ───
kubectl patch sts db --type=merge \
  -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'

# ─── 身份验证 ───
for i in 0 1 2; do
  echo -n "db-$i: "
  kubectl exec db-$i -- hostname
done
kubectl exec db-0 -- nslookup db-1.db.default.svc.cluster.local
kubectl exec db-0 -- nslookup db

# ─── 存储验证 ───
kubectl exec db-0 -- sh -c 'echo hello > /var/lib/mysql/test.txt'
kubectl delete pod db-0
kubectl wait --for=condition=Ready pod/db-0 --timeout=180s
kubectl exec db-0 -- cat /var/lib/mysql/test.txt   # 应仍为 hello

# ─── 清理（注意顺序）───
kubectl delete sts db                 # Pod 删了，PVC 留着
kubectl delete pvc -l app=db          # 手动清数据
kubectl delete svc db
```

### B. 快速诊断脚本

```bash
#!/usr/bin/env bash
# 用法：./diag.sh db default
STS=${1:?sts name}; NS=${2:-default}
echo "===== StatefulSet ====="
kubectl -n $NS get sts $STS -o custom-columns=\
NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,\
CURRENT:.status.currentReplicas,UPDATED:.status.updatedReplicas,\
PARTITION:.spec.updateStrategy.rollingUpdate.partition
echo "===== Pods ====="
kubectl -n $NS get pods -l "app=$STS" -o wide
echo "===== PVC ====="
kubectl -n $NS get pvc | grep "^data-$STS-" || kubectl -n $NS get pvc
echo "===== Service ====="
kubectl -n $NS get svc $STS -o wide
echo "===== Endpoints ====="
kubectl -n $NS get endpoints $STS
echo "===== 最近事件 ====="
kubectl -n $NS get events --sort-by=.lastTimestamp | tail -20
```

### C. 文件索引

```
statefulset/
├── README.md                          # 本文件（学习指南）
├── run-lab.sh                         # 一键体验全部实验
├── 01-basic/
│   └── statefulset-simple.yaml        # 最小可用例子：观察有序创建
├── 02-headless/
│   └── dns-lab.yaml                   # Headless Service + DNS 验证
├── 03-storage/
│   ├── statefulset-pvc.yaml           # MySQL 三副本 + VCT（含 secret）
│   └── pvc-lab.yaml                   # PVC 绑定实验（缩容/删 Pod）
├── 04-update/
│   ├── rolling-update.yaml            # partition 灰度更新演示
│   └── etcd-cluster.yaml              # 生产级 3 节点 etcd
├── 05-advanced/
│   ├── advanced-features.yaml         # 拓扑分布/多端口/preStop/本地 SC
│   ├── hpa-pdb.yaml                   # HPA + PDB + Redis
│   └── pvc-resize-note.yaml           # PVC 扩容说明
└── 06-troubleshoot/
    └── troubleshooting.md             # 故障排查速查表
```

### D. 学习路径建议

| 阶段 | 目标 | 对应文件 |
|---|---|---|
| **入门（1 天）** | 理解有序创建、稳定名字、PVC 绑定 | `01-basic`、`02-headless`、`03-storage/pvc-lab.yaml` |
| **进阶（2 天）** | 掌握滚动更新、partition 灰度、DNS 机制 | `04-update`、`02-headless` |
| **实操（3 天）** | 跑通 etcd 集群，理解 `Parallel` + `publishNotReadyAddresses` | `04-update/etcd-cluster.yaml` |
| **精通（1 周）** | 调度/PDB/优雅终止/PVC 扩容/故障排查 | `05-advanced`、`06-troubleshoot` |
| **工程化（2 周）** | 用 Operator 管一套真实的 PostgreSQL/MySQL | 生产 Checklist |

### E. 自测题（答对即"精通"）

1. `kubectl delete pod db-1` 和 `kubectl scale sts db --replicas=2` 有什么区别？
2. 为什么 etcd 集群要 `podManagementPolicy: Parallel` + `publishNotReadyAddresses: true`？
3. 把 `volumeClaimTemplates` 里 `storage` 从 1Gi 改成 5Gi，`data-db-0` 会变成 5Gi 吗？
4. `partition: 1` 且 `replicas: 3` 时，哪些 Pod 会被更新？顺序如何？
5. 为什么 `livenessProbe` 里不能检查"能否连上主库"？
6. StatefulSet 的 3 个副本能否共用一个 `ReadWriteMany` 的 PVC？会有什么后果？
7. `serviceName: db-headless`，但 Service 是普通 ClusterIP（不是 None），会怎样？
8. 缩容 `5 → 2` 之后再扩回 `5`，`db-4` 的数据还在吗？取决于什么？
9. 滚动更新时 `db-2` 一直 CrashLoopBackOff，后续的 `db-1`、`db-0` 会更新吗？
10. 想彻底删除一套 StatefulSet 并清空数据，正确的命令顺序是什么？

> 答案都在正文里；答不上来就翻回对应章节，并**实际敲一遍**。