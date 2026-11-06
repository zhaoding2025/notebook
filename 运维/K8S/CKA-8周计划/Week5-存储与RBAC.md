# Week 5｜存储 + RBAC（两座必须攻克的山）

> **本周时长**：10~12 小时
> **本周定位**：Storage 权重 10% 但**必考且送分**；RBAC 权重高且几乎必考。两者都是纯 yaml 硬功夫，练透就稳。
> **上一周**：[Week4-服务与网络.md](Week4-服务与网络.md) ｜ **下一周**：[Week6-集群运维.md](Week6-集群运维.md)

---

## 一、本周目标

- [ ] 会写 PV / PVC 并让它们 **Bound**（容量、accessModes、storageClassName 三要素匹配）
- [ ] 能解释 PV 的 4 种状态：Available / Bound / Released / Failed
- [ ] 会用 StorageClass 做动态供给，知道默认 SC 的 annotation
- [ ] 会在 Pod / Deployment 里挂载 PVC
- [ ] RBAC 四件套（Role / RoleBinding / ClusterRole / ClusterRoleBinding）闭眼写
- [ ] 会用 `kubectl auth can-i` 验证权限
- [ ] 能给 ServiceAccount 授权并在 Pod 里使用

---

## 二、知识主线

### 存储层次

```
容器内路径  ──volumeMounts──▶  Volume
                                 │
                    ┌────────────┴────────────┐
                    │                         │
              hostPath/emptyDir           PVC（持久化）
              （节点本地、临时）              │
                                      ┌─────┴──────┐
                                      │            │
                                 静态绑定       动态供给
                              （手写 PV）    （StorageClass）
```

### RBAC 四件套

```
谁能做什么（权限定义）        绑定到谁（主体）
─────────────────────       ─────────────────
Role          ──────────▶   RoleBinding
（namespace 级）              （namespace 级）
                                 │
                                 └─▶ User / Group / ServiceAccount

ClusterRole   ──────────▶   ClusterRoleBinding  （全集群生效）
（集群级）          │
                    └────▶   RoleBinding        （仅在该 ns 生效，权限降级使用）
```

> 🔑 **关键理解**：ClusterRole 可以被 RoleBinding 引用——这样在单个 namespace 里授予"集群级定义的权限"。这是常考点。

---

## 三、逐日安排

### D1｜Volume 基础类型

| 类型 | 生命周期 | 用途 |
|------|---------|------|
| `emptyDir` | 与 Pod 同生共死，Pod 删除即丢 | 容器间共享临时数据、缓存 |
| `hostPath` | 存在宿主机上，Pod 删了还在 | 访问节点文件（日志、docker sock）、**生产慎用** |
| `configMap` / `secret` | 由对象管理 | 注入配置文件 |
| `nfs` | 网络存储 | 多节点共享 |
| PVC | 持久化 | 生产标准做法 |

**任务**

```bash
# emptyDir 多容器共享
cat > /tmp/emptydir.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: share}
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh','-c','while true; do date >> /data/log; sleep 5; done']
    volumeMounts: [{name: d, mountPath: /data}]
  - name: reader
    image: busybox
    command: ['sh','-c','while true; do tail -3 /data/log; sleep 5; done']
    volumeMounts: [{name: d, mountPath: /data}]
  volumes:
  - name: d
    emptyDir: {}
EOF
k apply -f /tmp/emptydir.yaml
k logs share -c reader -f
```

```yaml
# hostPath 示例
  volumes:
  - name: host
    hostPath:
      path: /var/log
      type: Directory        # Directory / File / DirectoryOrCreate / FileOrCreate
```

> ⚠️ `hostPath` 的 `type` 字段是考点：
> - `DirectoryOrCreate`：不存在就自动创建目录
> - `FileOrCreate`：不存在就自动创建空文件

---

### D2｜PV / PVC 静态绑定（⭐⭐必考）

**PV（管理员视角：我有什么存储）**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-demo
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce              # RWO
  persistentVolumeReclaimPolicy: Retain    # Retain / Delete / Recycle
  storageClassName: manual                  # ⚠️ 必须与 PVC 一致（或不写两边）
  hostPath:
    path: /mnt/data
```

**PVC（用户视角：我要多大存储）**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-demo
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi          # 可以小于 PV 容量（PV 必须 ≥ PVC 需求）
  storageClassName: manual    # 与 PV 一致
```

**Pod 挂载 PVC**

```yaml
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /usr/share/nginx/html
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: pvc-demo
```

**绑定三要素（必须全匹配）**

1. `spec.storageClassName` 相同（**都为空也算相同**）
2. `accessModes` 包含 PVC 要求的模式
3. PV `capacity` ≥ PVC `requests.storage`

**AccessModes 四种**

| 模式 | 缩写 | 含义 |
|------|------|------|
| ReadWriteOnce | RWO | 单节点读写（**最常用**，一个 PVC 只能被一个节点挂载） |
| ReadOnlyMany | ROX | 多节点只读 |
| ReadWriteMany | RWX | 多节点读写（需 NFS/CephFS 等） |
| ReadWriteOncePod | RWOP | 单 Pod 读写（1.22+） |

**回收策略**

| 策略 | 行为 |
|------|------|
| `Retain` | PV 保留数据，状态变 `Released`，**需手动处理**才能再绑定 |
| `Delete` | 自动删除底层存储（动态供给默认） |
| `Recycle` | 已废弃，别用 |

**PV 四种状态**

```
Available  ──绑定成功──▶  Bound  ──PVC 被删──▶  Released  ──(Retain 策略)
                              │
                              └─ 绑定/回收失败 ──▶  Failed
```

> 🔑 **考试变体**：PV 是 `Released` 状态，想重新使用怎么办？
> 删掉 PV 的 `spec.claimRef` 字段（`kubectl edit pv xxx`），状态会重新变 `Available`。
> 这是常见考点，一定要记住。

**任务**

```bash
# 1. 建 PV
# 2. 建 PVC（注意 storageClassName 一致）
k get pv,pvc
# 3. 验证 Bound
k get pvc pvc-demo    # STATUS 应为 Bound

# 4. 故意不匹配（改 storageClassName 或 requests 过大）
k get pvc             # STATUS 应为 Pending
k describe pvc xxx    # Events 里会写原因

# 5. 演练 Released → Available
k delete pvc pvc-demo
k get pv              # Released
k edit pv pv-demo     # 删除 spec.claimRef 整段
k get pv              # Available
```

---

### D3｜StorageClass 动态供给

**StorageClass**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"   # 设为默认
provisioner: kubernetes.io/no-provisioner    # 或云厂商/本地 provisioner
volumeBindingMode: WaitForFirstConsumer      # Immediate / WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

**测试用：local-path（kind 自带）**

```bash
# kind 集群自带 standard StorageClass，可直接用
k get sc
k get sc standard -o yaml

# 动态创建 PVC：不写 PV
cat > /tmp/pvc-dyn.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: pvc-dyn}
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests: {storage: 100Mi}
EOF
k apply -f /tmp/pvc-dyn.yaml
k get pvc pvc-dyn      # Bound（自动生成了 PV）
k get pv               # 看到 pvc-<uid> 的 PV
```

**`volumeBindingMode` 两种**

| 值 | 行为 |
|----|------|
| `Immediate` | PVC 一创建就绑定 PV（可能绑到 Pod 跑不到的节点） |
| `WaitForFirstConsumer` | **等有 Pod 使用它时**再绑定（配合 local PV / 节点亲和必用） |

**扩展 PVC**

```bash
# SC 需 allowVolumeExpansion: true
k patch pvc pvc-dyn -p '{"spec":{"resources":{"requests":{"storage":"200Mi"}}}}'
k get pvc pvc-dyn      # CAPACITY 应变大
```

---

### D4｜RBAC 上：Role / RoleBinding / ServiceAccount

**ServiceAccount 是什么**

Pod 访问 apiserver 时用的身份（自动挂载 token 到 `/var/run/secrets/kubernetes.io/serviceaccount/`）。

```bash
k create sa my-sa
k get sa
k get sa my-sa -o yaml    # 会看到自动创建的 token secret（1.24+ 用 TokenRequest API）
```

**Role（namespace 级权限）**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: dev
rules:
- apiGroups: [""]              # 核心组用空字符串
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]
```

**RoleBinding**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: dev
subjects:
- kind: ServiceAccount
  name: my-sa
  namespace: dev
- kind: User
  name: alice                 # 任意字符串用户名
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: dev-team
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role                  # 或 ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**命令行创建（考试提速）**

```bash
# Role
k create role pod-reader --verb=get,list,watch --resource=pods -n dev

# RoleBinding 到 SA
k create rolebinding rb1 --role=pod-reader \
  --serviceaccount=dev:my-sa -n dev

# RoleBinding 到 user
k create rolebinding rb2 --role=pod-reader --user=alice -n dev

# RoleBinding 到 group
k create rolebinding rb3 --role=pod-reader --group=dev-team -n dev
```

**Pod 使用 SA**

```yaml
spec:
  serviceAccountName: my-sa
  automountServiceAccountToken: true
```

---

### D5｜RBAC 下：ClusterRole / ClusterRoleBinding / 验证

**ClusterRole**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader              # 无 namespace 字段
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/status"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list"]
```

**ClusterRoleBinding**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: node-reader-binding}
subjects:
- kind: ServiceAccount
  name: my-sa
  namespace: dev
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

**考点：用 RoleBinding 引用 ClusterRole（降级到单 namespace）**

```yaml
kind: RoleBinding
metadata: {name: deploy-admin-dev, namespace: dev}
subjects:
- {kind: ServiceAccount, name: my-sa, namespace: dev}
roleRef:
  kind: ClusterRole
  name: admin           # 引用集群级 ClusterRole
```
→ 效果：`my-sa` 只在 `dev` namespace 里拥有 `admin` 权限。

**verbs 完整清单（记住常见的）**

```
get  list  watch  create  update  patch  delete  deletecollection
```

**验证权限（⭐必考手法）**

```bash
# 当前身份
k auth can-i get pods

# 模拟其他身份
k auth can-i get pods --as=system:serviceaccount:dev:my-sa -n dev
k auth can-i delete pods --as=system:serviceaccount:dev:my-sa -n dev   # no

# 列出某身份所有权限
k auth can-i --list --as=system:serviceaccount:dev:my-sa -n dev

# 模拟 user
k auth can-i get nodes --as=alice
```

**快速排错：RBAC 不生效的 5 个检查点**

1. `namespace` 对不对（Role/RoleBinding 是 ns 级的）
2. `subjects.namespace` 是否与 SA 所在 ns 一致
3. `roleRef` 里的 `name` / `kind` 拼写
4. `apiGroups` 写的对不对（Pod 是 `""`，Deployment 是 `"apps"`）
5. `verbs` 是否包含了实际动作（`list` 不等于 `get`）

---

### D6-D7｜动手实验（周末）

#### 实验 1：PV/PVC 全链路（20 分钟）

1. 手工创建 3 个 PV（1Gi/2Gi/5Gi，各不同 accessModes）
2. 创建 PVC 请求 2Gi RWO → 观察绑定到哪个 PV
3. 创建另一个 PVC 请求 3Gi RWO → 观察绑定到 5Gi 的 PV
4. 创建 Pod 挂载 PVC，进入容器写入文件
5. 删除 Pod，重建 Pod，验证数据还在
6. 删除 PVC，观察 PV 状态变 Released
7. 手动修复 PV（删 claimRef）让它回到 Available

#### 实验 2：StorageClass 动态供给（15 分钟）

1. 查看默认 SC
2. 创建 PVC（不指定 SC），验证动态绑定
3. 创建自定义 SC（`no-provisioner` + `WaitForFirstConsumer`），观察 PVC 状态变 `Pending`，直到有 Pod 使用才 Bound

#### 实验 3：RBAC 完整授权（⭐核心实验，30 分钟）

**需求**：

> 1. 创建 namespace `dev`
> 2. 创建 ServiceAccount `deployer`
> 3. 创建 Role `deploy-manager`，允许对 Deployment / ReplicaSet / Pod 做所有操作
> 4. 绑定给 `deployer`
> 5. 创建 ServiceAccount `auditor`，只允许 get/list Pod（整个集群）
> 6. 验证：`deployer` 能删 Pod，`auditor` 不能删 Pod，但能 list 全集群的 Pod

**验证脚本**

```bash
k auth can-i delete pods --as=system:serviceaccount:dev:deployer -n dev   # yes
k auth can-i delete pods --as=system:serviceaccount:dev:auditor  -n dev   # no
k auth can-i list pods --as=system:serviceaccount:dev:auditor -A          # 需 ClusterRole
k auth can-i --list --as=system:serviceaccount:dev:auditor -n dev
```

#### 实验 4（进阶，选做）：在 Pod 内使用 SA 调用 API

```bash
# 用 deployer SA 起一个 Pod，在容器内 curl apiserver
k run api-test --image=curlimages/curl -n dev \
  --overrides='{"spec":{"serviceAccountName":"deployer"}}' \
  --rm -it --restart=Never -- sh

# 容器内：
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
curl -s --cacert $CACERT -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/dev/pods
```

这能让你真正理解"Pod 里的权限从哪来"。

---

## 四、本周必练命令

```bash
# 存储
kubectl get pv,pvc -A
kubectl describe pv <n>
kubectl describe pvc <n>
kubectl get sc
kubectl edit pv <n>          # 用于删 claimRef 解绑

# RBAC
kubectl create sa <n> [-n ns]
kubectl create role <n> --verb=... --resource=... [-n ns]
kubectl create clusterrole <n> --verb=... --resource=...
kubectl create rolebinding <n> --role=... --serviceaccount=ns:sa|--user=u|--group=g [-n ns]
kubectl create clusterrolebinding <n> --clusterrole=... --serviceaccount=ns:sa
kubectl get role,rolebinding -n <ns>
kubectl get clusterrole,clusterrolebinding
kubectl auth can-i <verb> <resource> [--as=...] [-n ns]
kubectl auth can-i --list --as=...
```

---

## 五、验收标准

- [ ] 能不看文档手写 PV + PVC + Pod 挂载，一次 Bound
- [ ] 能说出 PV 与 PVC 绑定的**三个匹配条件**
- [ ] 能解释 `Released` 状态的 PV 如何变回 `Available`
- [ ] 能说出 `RWO` 与 `RWX` 的实际差异（RWO 是"单节点"，不是"单 Pod"）
- [ ] 能在 5 分钟内完成 Sa + Role + RoleBinding + `auth can-i` 验证全流程
- [ ] 能解释 RoleBinding 引用 ClusterRole 的效果
- [ ] 知道 `apiGroups: [""]` 对应哪些资源（core 组：pod/svc/cm/secret/pv/pvc/node）
- [ ] RBAC 不生效时能列出 5 个检查点

---

## 六、自测题

1. PVC 请求 2Gi，只有 1Gi 和 5Gi 两个可用 PV，会不会绑定到 5Gi？为什么？
2. PV 是 `Retain` 策略，PVC 删了以后 PV 是什么状态？怎么复用？
3. `ReadWriteOnce` 到底是"一个 Pod 独占"还是"一个节点独占"？
4. 动态供给的时候，PV 是谁创建的？StorageClass 里哪个字段决定绑定时机？
5. `Role` 和 `ClusterRole` 能不能互换使用？`RoleBinding` 引用 `ClusterRole` 有什么用？
6. 给 SA 授权后，`kubectl auth can-i` 返回 `no`，可能是哪些地方写错了？
7. Pod 里的 ServiceAccount token 存在什么路径？它代表什么身份？
8. 一个 PVC 用 `ReadWriteOnce`，两个 Pod 在不同节点上都挂它，会发生什么？

---

## 七、踩坑记录

| 现象 | 原因 | 解决 |
|------|------|------|
| | | |

---

## 八、复盘区

**PV/PVC 绑定三要素（自己默写）**

1.
2.
3.

**RBAC 不生效检查清单（自己总结）**

1.
2.
3.
4.
5.

**本周用时统计**

| 天 | 计划 | 实际 |
|----|------|------|
| D1 | 1.5h | |
| D2 | 2h | |
| D3 | 1.5h | |
| D4 | 1.5h | |
| D5 | 1.5h | |
| D6 | 3h | |
| D7 | 3h | |

**一句话总结本周**

>

---

*[← 上一周：Week4-服务与网络](Week4-服务与网络.md) ｜ [返回索引](README.md) ｜ [下一周：Week6-集群运维 →](Week6-集群运维.md)*