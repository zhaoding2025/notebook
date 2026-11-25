# Kubernetes 调度核心知识点速查手册

> 覆盖:污点(Taint)/容忍(Toleration)、节点亲和(nodeAffinity)、Pod 亲和/反亲和(podAffinity / podAntiAffinity)、拓扑分布约束(topologySpreadConstraints)。
> 一句话定位:调度器想「把 Pod 放到哪」= 亲和性(Pod 主动挑)+ 污点(节点拒绝)+ 资源约束。

---

## 0. 四类调度手段全景图

| 手段 | 判断对象 | 方向 | 表达能力 |
|------|---------|------|----------|
| `nodeName` | Node | Pod 主动 | 最弱:硬绑机器,跳过调度器 |
| `nodeSelector` | Node label | Pod 主动 | 弱:只能等值匹配 |
| **`nodeAffinity`** | Node label | Pod 主动 | 强:In/NotIn/Exists/Gt/Lt + 软硬 |
| **`podAffinity`/`podAntiAffinity`** | **节点上的 Pod** | Pod 主动 | 最强:看"别的 Pod 在哪" |
| **Taint/Toleration** | Node → Pod | **节点拒绝** | 反向约束(与上面方向相反) |

> 两者配合实现「双向锁定」:亲和性让 Pod「想去」,污点阻止别的 Pod「进来」。

---

## 1. 污点 Taint(打在节点) · 容忍 Toleration(打在 Pod)

### 1.1 三要素:`key=value:effect`

| 要素 | 说明 |
|------|------|
| key | 标识,如 `dedicated`、`disktype` |
| value | 可省略(如 master 默认污点无 value) |
| effect | `NoSchedule` / `PreferNoSchedule` / `NoExecute` |

### 1.2 三种 effect(背下来)

| effect | 拒绝新 Pod | 驱逐已有 Pod |
|--------|-----------|--------------|
| `NoSchedule` | ✅ | ❌(不驱逐) |
| `PreferNoSchedule` | ⚠️ 尽量不(软) | ❌ |
| `NoExecute` | ✅ | ✅(且可配宽限期) |

**NoExecute 宽限期** `tolerationSeconds`:
```yaml
- key: key1
  operator: Equal
  value: value1
  effect: NoExecute
  tolerationSeconds: 3600   # 容忍 1 小时后才被驱逐;不写=永久容忍
```

### 1.3 容忍的 operator 与省略写法

| 写法 | 匹配逻辑 |
|------|---------|
| `Equal`(默认) | key+value+effect 三样必须全等 |
| `Exists` | 只看 key(+effect),忽略 value(value 留空) |
| 缺省组合 | 万能通行证:`operator: Exists` 无 key/effect |

```yaml
tolerations:
- key: key1
  operator: Equal
  value: value1
  effect: NoSchedule
```

### 1.4 节点默认/内置污点(自
动出现也能自动驱逐)

| 内置 key | 触发条件 |
|----------|---------|
| `node-role.kubernetes.io/master` | 旧版 master(1.24 前) |
| `node-role.kubernetes.io/control-plane` | 新版 master |
| `node.kubernetes.io/not-ready` | 心跳丢失 |
| `node.kubernetes.io/unreachable` | 不可达 |
| `node.kubernetes.io/memory-pressure` | 内存压力 |
| `node.kubernetes.io/disk-pressure` | 磁盘压力 |
| `node.kubernetes.io/pid-pressure` | PID 不足 |
| `node.cloudprovider.../uninitialized` | 云厂商未初始化 |

> 内置逻辑:k8s 默认给所有 Pod 配 `not-ready` 和 `unreachable` 的 NoExecute 容忍,**宽限 5 分钟(300s)**。所以节点宕机,Pod 不立即驱逐。

### 1.5 命令

```bash
# 查看
kubectl describe node <node> | grep -i taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 添加
kubectl taint nodes node1 key=value:NoSchedule
# 删除(末尾加 -)
kubectl taint nodes node1 key=value:NoSchedule-
# 修改:先删再加;kubectl 不支持原地改
```

**易错**:`NoSchedule` 不驱逐已有 Pod,只有 `NoExecute` 驱逐;删污点必须带 effect 和 `-`。

---

## 2. nodeAffinity 节点亲和

### 2.1 软硬两种 + 字段含义(拆段记)

```
requiredDuringSchedulingIgnoredDuringExecution
preferredDuringSchedulingIgnoredDuringExecution
    ↑ required  硬约束,不满足就 Pending
    ↑ preferred 软约束,打分; 权重 weight 1~100
所有人都是 IgnoredDuringExecution:运行时节点 label 变了也不驱逐 Pod
```

### 2.2 逻辑与 API 校验(重点)

- 多个 `nodeSelectorTerms` → **OR(或)**
- 多个 `matchExpressions` → **AND(与)**
- `Exists`/`DoesNotExist` **不能带 values**,否则 PVC 校验失败
- `Gt`/`Lt` **只能带 1 个值**(且字符串比较后转数值)

```yaml
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
  - matchExpressions:                    # OR: (ssd 且 zone-a) 或 gpu存在
    - key: disktype
      operator: In
      values: ["ssd"]
    - key: zone
      operator: In
      values: ["zone-a"]
  - matchExpressions:
    - key: gpu
      operator: Exists
```

operator 全表:

| operator | 需要 values | 语义 |
|----------|------------|------|
| `In` | ✅ | 值在列 |
| `NotIn` | ✅ | 值不在列 |
| `Exists` | ❌ | key 存在 |
| `DoesNotExist` | ❌ | key 不存在 |
| `Gt` | 1 个 | 值 > n |
| `Lt` | 1 个 | 值 < n |

---

## 3. podAffinity / podAntiAffinity(Pod 间)

### 3.1 核心区别

- **判断对象是"节点上已经运行的 Pod 的 label"**,不是节点 label。
- **关键字段 `topologyKey`**:决定「同一拓扑域」的范围。
- **必须先有目标 Pod** → 否则亲和落空 Pending(实验2 演示过)。

### 3.2 topologyKey(决定"一起"的范围)

| topologyKey | 一个域 = | 用途 |
|-------------|---------|------|
| `kubernetes.io/hostname` | 一台机器 | 同机/互斥(打散) |
| `topology.kubernetes.io/zone` | 一个可用区 | 跨 AZ 高可用 |
| `topology.kubernetes.io/region` | 一个地域 | 跨地域 |

⚠️ topologyKey 指定的 label 节点必须真实存在,否则该节点被判不满足。

### 3.3 四种组合语义(背下来)

| 组合 | 语义 | 推荐 |
|------|------|------|
| podAffinity + required | 必须与目标同域 | 强绑定(同机缓存) |
| podAffinity + preferred | 尽量与目标同域 | 弱绑定 |
| podAntiAffinity + required | 必须不与目标同域 | 硬分散(**易 Pending**) |
| podAntiAffinity + preferred | 尽量不与目标同域 | **生产首选** |

```yaml
# 反亲和硬约束(打散,避免同机全挂)
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:   # 软约束改这里
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app: web
        topologyKey: kubernetes.io/hostname
```

### 3.4 字段差异(易错,背下来)

| 层级字段 | nodeAffinity | podAffinity |
|---------|-------------|-------------|
| 软约束 | preferred → `preference` | preferred → **`podAffinityTerm`** |
| 判断依据 | `matchExpressions` | `labelSelector` + `topologyKey` |

> 抄 YAML 常见的报错:同层 key 写错(如把 `podAffinityTerm` 写成 `preference`)。

### 3.5 namespaces(默认只看自己 ns)

- 默认:只匹配**本 namespace** 的 Pod。
- 跨 ns:显式给 `namespaces` 或 `namespaceSelector`(两者并集)。

```yaml
namespaces: ["cache-ns","default"]
# 或
namespaceSelector: { matchLabels: { team: infra } }
```

### 3.6 性能与坑
- PodAffinity 要遍历节点上的 Pod,大集群开销显著。
- required 反亲和 + 副本数 > 拓扑域数 → **永久 Pending**,事件 `/N nodes ... didn't match pod anti-affinity rules`。
- `IgnoredDuringExecution`:label 改了不迁移。
- 只能用 In/NotIn/Exists/DoesNotExist,**无 Gt/Lt**。

---

## 4. topologySpreadConstraints(进阶,更均衡)

> 副本数在拓扑域间**均匀分布** 的正规做法(优于反亲和,1.19+ GA)。

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  whenUnsatisfiable: DoNotSchedule   # 或 ScheduleAnyway(不阻塞)
  labelSelector:   { matchLabels: { app: web } }
```
`maxSkew`=域之间最多相差副本数。优先于反亲和用于均衡场景。

---

## 5. 常用命令集

```bash
# 污点
kubectl describe node <n> | grep -i taints
kubectl taint nodes <n> k=v:NoSchedule
kubectl taint nodes <n> k=v:NoSchedule-
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 标签(亲和/topologyKey 依赖它)
kubectl label node <n> disktype=ssd zone=zone-a --overwrite
kubectl get nodes --show-labels

# 诊断调度失败
kubectl describe pod <p> | sed -n '/Events:$/,$p'
kubectl get pods -A -l <label> -o wide
kubectl get pod <p> -o jsonpath='{.spec.nodeName}'
```

---

## 6. 故障排查一句话(对应报错)

| 报错关键句 | 含义 | 修法 |
|-----------|------|------|
| `had taint {..: NoSchedule}` 且 didn't tolerate | 节点有污点,Pod 没容忍 | 加对应 toleration,或删污点(`-`) |
| `didn't match pod/node affinity rules` | 边没匹配上 | 节点亲和查 label;Pod 亲和**先建目标 Pod** |
| `N node(s) didn't match pod anti-affinity` | 反亲和硬约束冲突,`副本>域数` | 降为 preferred 或减少副本 |
| `<none>` 显示 | 字段不存在(无污点) | — |

---

## 7. 记忆口诀

```
亲和挑节点,污点拒掉它; 拓扑定域,配额控动力。

nodeAffinity 看机器, podAffinity 瞅邻居;
preferred 软、required 硬, 反亲和要散在域间;
containers 又对 prefix_error 报错 —— 看 operator 与 topologyKey。
```

---

## 8. 实验环境(E 文本)

本目录配套 `affinity-lab`:
- `bash 实验.sh 1/2/3/4/all/clean`
- 含脚本断言(实验2 自动判断 redis 与 web 是否同机)

---

*整理时间:随集群实验同步维护。*