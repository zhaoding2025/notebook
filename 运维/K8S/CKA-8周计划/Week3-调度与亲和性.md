# Week 3｜调度 + Taint/亲和性（⭐高频考点周）

> **本周时长**：10~12 小时
> **本周定位**：本周是**考试高频区**。Taint/Toleration 和亲和性几乎每场必考，必须练到肌肉记忆。
> **上一周**：[Week2-工作负载.md](Week2-工作负载.md) ｜ **下一周**：[Week4-服务与网络.md](Week4-服务与网络.md)

---

## 一、本周目标

- [ ] 讲清调度器两阶段（Filter → Score）各在过滤什么
- [ ] 掌握 5 种把 Pod 放到指定节点的方法，并知道何时用哪个
- [ ] **Taint / Toleration 熟练到闭眼写**：三种 effect、增删查、与 NoExecute 的区别
- [ ] NodeAffinity（required/preferred）与 PodAffinity/PodAntiAffinity 都会写
- [ ] 会创建 DaemonSet 和 Static Pod
- [ ] **8 分钟内**完成组合题：打污点 + 部署只在污点节点运行的 Pod + 反亲和打散

---

## 二、知识主线：5 种调度手段

| 手段 | 写法 | 强制/偏好 | 用途 |
|------|------|-----------|------|
| `spec.nodeName` | 直接写节点名 | 强制，**绕过调度器** | 手动指定、Static Pod 也用 |
| `nodeSelector` | `nodeSelector: {disk: ssd}` | 强制 | 最简单的标签匹配 |
| **NodeAffinity** | `requiredDuringSchedulingIgnoredDuringExecution` | 强制/偏好 | 复杂标签表达式 |
| **Taint/Toleration** | 节点打 `taint`，Pod 加 `toleration` | 节点侧排斥 | **专用节点**、控制平面保护 |
| **Pod(Anti)Affinity** | `podAffinity` / `podAntiAffinity` | 强制/偏好 | Pod 之间靠拢或分散 |

> 💡 **方向相反的一对**：`nodeSelector`/`nodeAffinity` 是 **Pod 挑节点**；`taint` 是 **节点拒绝 Pod**。两者结合才能实现"专用节点"（节点打污点排斥所有，目标 Pod 加容忍才能进去）。

---

## 三、逐日安排

### D1｜调度器原理 + nodeName + nodeSelector

**调度器两阶段**

```
新 Pod (nodeName 为空)
    │
    ├─ Filter（过滤）：排除不满足硬性条件的节点
    │    · 资源是否足够（requests）
    │    · 节点污点 Pod 是否容忍
    │    · nodeSelector / nodeAffinity(required) 是否匹配
    │    · Pod 反亲和要求是否满足
    │    · PV 所在可用区
    │    · 节点是否 cordon（unschedulable）
    │
    ├─ Score（打分）：对剩余节点排序
    │    · 资源均衡度（LeastAllocated 优先空节点）
    │    · 亲和性偏好分
    │    · 镜像是否已在节点上
    │
    └─ Bind：写入 Pod 的 spec.nodeName
```

**任务**

```bash
# 1. 强制指定节点（绕过调度器）
k run pinned --image=nginx --overrides='
{"spec":{"nodeName":"cka-worker"}}'

# 2. nodeSelector
k label node cka-worker disk=ssd
k run ssd-pod --image=nginx --dry-run=client -o yaml > /tmp/p.yaml
# 编辑加入 nodeSelector: {disk: ssd}
k apply -f /tmp/p.yaml

# 3. 观察调度失败事件
k describe pod ssd-pod | grep -A5 Events
```

**nodeSelector yaml**

```yaml
spec:
  nodeSelector:
    disk: ssd
    zone: east
```

> ⚠️ `nodeSelector` 只能用**精确等值**匹配，不支持 `in` / `NotIn` / `Gt` / `Lt`。复杂表达式用 NodeAffinity。

---

### D2｜NodeAffinity 节点亲和性

**两种模式**

| 字段 | 含义 |
|------|------|
| `requiredDuringSchedulingIgnoredDuringExecution` | **硬性**，必须满足，否则 Pod 一直 Pending |
| `preferredDuringSchedulingIgnoredDuringExecution` | **软性**，尽量满足，有权重 `weight: 1-100` |

> "IgnoredDuringExecution" 的意思是：**已经跑起来的 Pod，如果节点标签后来变了，不会被驱逐**。

**yaml 模板**

```yaml
spec:
  affinity:
    nodeAffinity:
      # ---- 硬性 ----
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:              # 多个 term 之间是 OR
        - matchExpressions:             # 同一个 term 内多个表达式是 AND
          - key: disk
            operator: In                # In / NotIn / Exists / DoesNotExist / Gt / Lt
            values: [ssd, nvme]
          - key: kubernetes.io/hostname
            operator: NotIn
            values: [cka-control-plane]
      # ---- 软性 ----
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
          - key: zone
            operator: In
            values: [east]
```

**任务**

```bash
# 给节点打多个标签
k label node cka-worker-2 zone=east gpu=true

# 部署后验证落在哪个节点
k get po -o wide
k describe po <name> | grep -i node
```

**⚠️ 易混：`In` vs `Exists`**

- `In [ssd]`：节点必须有 `disk` 标签**且值为 ssd**
- `Exists`：节点只要有这个 `disk` 标签就行，值不管

---

### D3｜Taint & Toleration（⭐⭐⭐ 最高频）

**核心概念**

- **Taint（污点）** 打在**节点**上：`key=value:Effect`，意思是"别把普通 Pod 放我这"
- **Toleration（容忍）** 写在**Pod** 上：意思是"我能接受这个污点"

**三种 Effect**

| Effect | 含义 |
|--------|------|
| `NoSchedule` | 新 Pod 不能调度上来；**已运行的 Pod 不受影响** |
| `PreferNoSchedule` | 调度器**尽量**不安排，但资源不够时可以安排（软性） |
| `NoExecute` | 新 Pod 不能调度上来，**且已运行的、不容忍的 Pod 会被立即驱逐** |

**命令**

```bash
# 查看节点污点
k describe node cka-worker | grep -i taint
k get node cka-worker -o jsonpath='{.spec.taints}'

# 加污点
k taint node cka-worker gpu=true:NoSchedule
k taint node cka-worker dedicated=db:NoExecute

# 覆盖已有污点（必须加 --overwrite）
k taint node cka-worker gpu=false:NoSchedule --overwrite

# 删除污点（末尾加 -）
k taint node cka-worker gpu=true:NoSchedule-
k taint node cka-worker dedicated-                  # 删除该 key 的所有污点

# 加多个
k taint node n1 a=1:NoSchedule b=2:NoExecute
```

**Toleration 写法（考试重点，4 种组合）**

```yaml
spec:
  tolerations:
  # 1. 精确匹配：key + value + effect 全等
  - key: "gpu"
    operator: "Equal"      # 默认就是 Equal
    value: "true"
    effect: "NoSchedule"

  # 2. Exists：只要节点有这个 key 就能忍（不管 value）
  - key: "gpu"
    operator: "Exists"
    effect: "NoSchedule"

  # 3. tolerationSeconds：NoExecute 时延迟驱逐时间
  - key: "dedicated"
    operator: "Equal"
    value: "db"
    effect: "NoExecute"
    tolerationSeconds: 3600     # 容忍 1 小时后再被驱逐

  # 4. 容忍一切（万能写法，考试救急用）
  - operator: "Exists"          # 不写 key = 匹配所有 key
```

> 🔑 **万能容忍**：`- operator: Exists`（无 key、无 value、无 effect）= 容忍**所有**污点。考试时间紧时直接上这个。

**控制平面节点的内置污点**

```bash
k describe node cka-control-plane | grep -i taint
# node-role.kubernetes.io/control-plane:NoSchedule
```

---

### D4｜PodAffinity / PodAntiAffinity

**含义**

- `podAffinity`：**我想和某类 Pod 待在同一拓扑域**（同一节点 / 同一可用区）
- `podAntiAffinity`：**我不想和某类 Pod 待在一起**（打散副本）

`topologyKey` 定义"同一域"的边界，常用：
- `kubernetes.io/hostname` → 同一节点
- `topology.kubernetes.io/zone` → 同一可用区

**yaml 模板**

```yaml
spec:
  affinity:
    podAntiAffinity:
      # 硬性打散：绝不同节点
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels: {app: web}
        topologyKey: kubernetes.io/hostname
      # 软性打散：尽量不同节点（副本多时用这个，否则放不下）
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values: [web]
          topologyKey: kubernetes.io/hostname
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels: {app: cache}
        topologyKey: kubernetes.io/hostname
```

> ⚠️ **考试坑**：3 节点集群里用 `required` 反亲和 + 3 副本，如果一节点已满会 Pending。**副本数 ≥ 节点数时用 `preferred`**。

---

### D5｜DaemonSet 与 Static Pod

**DaemonSet：每个节点跑一个**

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata: {name: node-agent}
spec:
  selector:
    matchLabels: {app: node-agent}
  template:
    metadata:
      labels: {app: node-agent}
    spec:
      tolerations:                       # 要覆盖控制平面节点就得加这个
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: agent
        image: busybox
        command: ["sh","-c","while true; do date; sleep 60; done"]
```

```bash
k create deploy x --image=nginx --dry-run=client -o yaml   # 没有 daemonset 的 create 子命令
# DaemonSet 只能手写或用 kubectl create 的扩展语法
k get ds -A
k get pod -l app=node-agent -o wide   # 观察每个节点都有一个
```

**Static Pod（静态 Pod）**

- 由 **kubelet 直接管理**，不经过 apiserver 调度
- 存放目录：`/etc/kubernetes/manifests/`（`--pod-manifest-path` 配置）
- 命名带节点名后缀：`etcd-cka-control-plane`
- **控制平面组件本身就是 Static Pod**
- 删除方法：**删除清单文件**，`kubectl delete pod` 无效（kubelet 会重建）

```bash
# kind/minikube 进节点看
docker exec -it cka-control-plane ls /etc/kubernetes/manifests/
docker exec -it cka-control-plane cat /etc/kubernetes/manifests/kube-apiserver.yaml

# 创建一个 static pod（在节点上写文件）
docker exec -it cka-control-plane bash -c 'cat > /etc/kubernetes/manifests/static.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: static-web
spec:
  containers:
  - name: web
    image: nginx
EOF'
k get po -A | grep static-web
```

> 🔑 **考点**：题目说"创建一个静态 Pod"，就是让你把 yaml 放到 `/etc/kubernetes/manifests/`。文件名随意，记得用 `kubectl get pods -A` 验证（名字会带 `-<节点名>`）。

---

### D6-D7｜动手实验（周末）

#### 实验 1：专用节点（⭐典型考题）

目标：让 `cka-worker-2` 只跑 `app=infra` 的 Pod，其他 Pod 一律进不来。

```bash
# 1. 给节点打污点
k taint node cka-worker-2 dedicated=infra:NoSchedule

# 2. 部署普通应用（3 副本，无反亲和）→ 应该只落在 worker-1 和控制平面拒绝后 → worker-1
k create deploy normal --image=nginx --replicas=3
k get po -o wide

# 3. 部署 infra 应用（带容忍）→ 应该落在 worker-2
# yaml 里加 tolerations: [{key: dedicated, operator: Equal, value: infra, effect: NoSchedule}]
# 以及 nodeSelector: {dedicated: infra}（节点要有这个标签）
k get po -o wide
```

#### 实验 2：副本打散（反亲和）

```bash
# 3 副本，要求每个节点一个
# 用 podAntiAffinity preferred + topologyKey: kubernetes.io/hostname
k create deploy spread --image=nginx --replicas=3
k get po -l app=spread -o wide    # 核对是否分散在 3 个节点

# 改成 required 再试，如果节点不够会 Pending —— 观察 Events
```

#### 实验 3：组合题（对标考试，计时 8 分钟）

**题目**：

> 1. 给节点 `cka-worker` 添加污点 `env=prod:NoExecute`
> 2. 创建一个 DaemonSet `agent`，镜像 `busybox`，命令 `sleep infinity`，**必须能跑在所有节点上（含此污点节点）**
> 3. 创建一个 Deployment `web`，3 副本，镜像 `nginx`，要求：
>    - 不能部署到 `cka-worker` 节点（因为污点，天然满足）
>    - 3 个副本分散在可用节点上（反亲和）

**自己计时做完，再对答案。**

```bash
# 参考解法骨架
k taint node cka-worker env=prod:NoExecute
# DaemonSet 加：tolerations: [{operator: Exists}]  ← 万能容忍
# Deployment 加：podAntiAffinity preferred + hostname
```

#### 实验 4：Static Pod

```bash
# 在控制平面节点上创建一个 static pod，名为 static-web，镜像 nginx
docker exec -it cka-control-plane bash -c 'cat > /etc/kubernetes/manifests/static-web.yaml <<EOF
apiVersion: v1
kind: Pod
metadata: {name: static-web}
spec:
  containers: [{name: web, image: nginx}]
EOF'
sleep 20 && k get po -A | grep static-web
# 删除
docker exec -it cka-control-plane rm /etc/kubernetes/manifests/static-web.yaml
```

---

## 四、本周必练命令

```bash
# 节点标签
kubectl label node <n> key=value [--overwrite]
kubectl label node <n> key-

# 污点（考试最高频）
kubectl taint node <n> key=value:NoSchedule [--overwrite]
kubectl taint node <n> key=value:NoExecute-
kubectl taint node <n> key-
kubectl describe node <n> | grep -i taint
kubectl get node <n> -o jsonpath='{.spec.taints}'

# 节点维护
kubectl cordon <n>        # 标记不可调度
kubectl uncordon <n>      # 恢复可调度
kubectl drain <n> --ignore-daemonsets --delete-emptydir-data   # 驱逐业务 Pod

# 调度验证
kubectl get po -o wide
kubectl describe po <p> | grep -E 'Node:|Tolerations|Affinity'
```

---

## 五、验收标准

- [ ] 能在 **30 秒内**：给节点打 NoSchedule 污点 → 验证新 Pod 不会调度上去 → 删除污点
- [ ] 能默写 4 种 toleration 写法（Equal/Exists/tolerationSeconds/万能）
- [ ] 能解释 `NoSchedule` 与 `NoExecute` 的**关键区别**（会不会驱逐已运行的 Pod）
- [ ] 能写出带 `nodeSelectorTerms` 和 `matchExpressions` 的 NodeAffinity 硬性+软性
- [ ] 能写出 `podAntiAffinity` 让 3 副本分散到 3 节点
- [ ] 能在 8 分钟内独立完成「实验 3 组合题」
- [ ] 能创建 Static Pod 并说明为什么 `kubectl delete pod` 删不掉它
- [ ] 知道 `drain` / `cordon` / `uncordon` 三者的区别

---

## 六、自测题

1. `NoSchedule` 和 `NoExecute` 最本质的区别是什么？
2. 节点有污点 `a=1:NoSchedule`，Pod 的 toleration 是 `{key: a, operator: Exists}`（无 value），能调度上去吗？
3. 节点有污点 `a=1:NoSchedule`，Pod 的 toleration 是 `{key: a, operator: Equal, value: 2, effect: NoSchedule}`，能上去吗？
4. NodeAffinity 里的 `IgnoredDuringExecution` 是什么意思？什么时候会出问题？
5. `podAntiAffinity` 用 `required` + `topologyKey: kubernetes.io/hostname`，5 副本但只有 3 节点，会怎样？
6. DaemonSet 为什么默认不会跑在控制平面节点上？怎么让它跑上去？
7. Static Pod 的名字为什么后面带节点名？删掉它的正确方法是什么？
8. `kubectl drain` 和 `kubectl cordon` 的区别？

---

## 七、踩坑记录

| 现象 | 原因 | 解决 |
|------|------|------|
| | | |

---

## 八、复盘区

**Taint 三种 effect 我的记忆法**

>

**实验 3 计时结果**

- 用时：____ 分钟
- 卡住的地方：

**本周用时统计**

| 天 | 计划 | 实际 |
|----|------|------|
| D1 | 1.5h | |
| D2 | 1.5h | |
| D3 | 2h | |
| D4 | 1.5h | |
| D5 | 1h | |
| D6 | 3h | |
| D7 | 3h | |

**一句话总结本周**

>

---

*[← 上一周：Week2-工作负载](Week2-工作负载.md) ｜ [返回索引](README.md) ｜ [下一周：Week4-服务与网络 →](Week4-服务与网络.md)*