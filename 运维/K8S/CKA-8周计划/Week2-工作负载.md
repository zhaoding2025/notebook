# Week 2｜工作负载（Deployment / Job / ConfigMap / Secret / HPA）

> **本周时长**：10~12 小时
> **本周定位**：应用怎么"跑起来、更新、回滚、注入配置"。这是日常运维 80% 的工作内容。
> **上一周**：[Week1-环境与基础.md](Week1-环境与基础.md) ｜ **下一周**：[Week3-调度与亲和性.md](Week3-调度与亲和性.md)

---

## 一、本周目标

- [ ] 讲清 **Deployment → ReplicaSet → Pod** 三层关系，以及谁管理谁
- [ ] 熟练滚动更新：`set image` → `rollout status` → `rollout history` → `rollout undo`
- [ ] 会写 Job 和 CronJob，理解 `completions` / `parallelism` / `backoffLimit`
- [ ] ConfigMap / Secret 的**两种注入方式**都做过：env 注入、volume 挂载
- [ ] 会用 HPA 做水平扩缩容，知道它依赖 metrics-server
- [ ] **5 分钟内**从零搭出「Deployment + CM + Secret + 滚动更新 + 回滚」全链路

---

## 二、逐日安排

### D1｜ReplicaSet 与 Deployment

**核心关系**

```
Deployment  （管理版本、滚动更新策略）
    └── ReplicaSet v1  （管理副本数，保留旧版本用于回滚）
            └── Pod × 3
```

- Deployment **不直接管 Pod**，它管 ReplicaSet
- 滚动更新时：新建一个 ReplicaSet（v2），逐步扩它、缩 v1，**v1 保留下来**（`revisionHistoryLimit`，默认 10）
- 所以 `rollout undo` 才能"回到上一个版本"

**任务**

```bash
# 创建（考试必用，比手写快）
k create deploy web --image=nginx:1.24 --replicas=3
k get deploy,rs,po -l app=web

# 观察三层关系
k get deploy web -o yaml | grep -A5 'selector:'

# 扩容
k scale deploy web --replicas=5
k get rs   # 注意 rs 名字 = deploy名-<podtemplate-hash>
```

**yaml 模板**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels: {app: web}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1             # 最多超出期望副本数 1 个
      maxUnavailable: 0       # 最多少 0 个（保证不中断）
  template:
    metadata:
      labels: {app: web}
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports: [{containerPort: 80}]
```

---

### D2｜滚动更新与回滚（⭐高频）

**任务**

```bash
# 更新镜像（触发滚动更新）
k set image deploy/web nginx=nginx:1.25

# 观察进度
k rollout status deploy/web

# 历史版本
k rollout history deploy/web
k rollout history deploy/web --revision=2

# 回滚
k rollout undo deploy/web                      # 回上一版
k rollout undo deploy/web --to-revision=1      # 回指定版

# 暂停/恢复滚动（改了多次配置想一次性发布）
k rollout pause deploy/web
k rollout resume deploy/web

# 重启（等价于滚动更新，不改镜像）——考试常考"重启 deployment"
k rollout restart deploy/web
```

**验证滚动更新的效果**

```bash
# 一个终端持续观察
k get po -l app=web -w
# 另一个终端触发更新
k set image deploy/web nginx=nginx:1.25
```

观察：是否有 Pod 短暂变成 2 个（maxSurge=1 的效果）。然后把 `maxUnavailable` 改成 `1` 再试一次，对比差异。

> 💡 **考点**：题目可能说"保证零中断升级"，那就必须 `maxUnavailable: 0`。

---

### D3｜Job 与 CronJob

**Job：跑完就结束**

```yaml
apiVersion: batch/v1
kind: Job
metadata: {name: pi}
spec:
  completions: 1        # 需要成功完成的次数
  parallelism: 1        # 同时跑几个
  backoffLimit: 4       # 失败重试上限
  ttlSecondsAfterFinished: 100   # 完成后多久自动删除
  template:
    spec:
      restartPolicy: Never        # Job 必须是 Never 或 OnFailure
      containers:
      - name: pi
        image: perl
        command: ["perl","-Mbignum=bpi","-wle","print bpi(2000)"]
```

```bash
k create job pi --image=perl -- perl -Mbignum=bpi -wle 'print bpi(2000)'
k get jobs
k logs job/pi
```

**CronJob**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata: {name: hello}
spec:
  schedule: "*/1 * * * *"        # 分 时 日 月 周
  concurrencyPolicy: Forbid      # Allow / Forbid / Replace
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: hello
            image: busybox
            command: ["sh","-c","date; echo hello"]
```

> ⚠️ 两个 `restartPolicy` 坑：
> - Job/CronJob 的 Pod 只能是 `Never` 或 `OnFailure`，写 `Always` 直接报错
> - CronJob 的 yaml 结构是 `spec.jobTemplate.spec.template.spec` —— **三层嵌套**，手写极易缩进错。建议 `k create cronjob --dry-run=client -o yaml` 生成。

---

### D4｜ConfigMap 与 Secret（⭐⭐高频）

**ConfigMap 三种创建方式**

```bash
# 1. 字面量
k create cm app-cfg --from-literal=APP_ENV=prod --from-literal=LOG_LEVEL=info

# 2. 从文件（key = 文件名，value = 文件内容）
k create cm nginx-cfg --from-file=nginx.conf

# 3. 从 env 文件（key=value 逐行）
k create cm app-env --from-env-file=app.env

# 查看
k get cm app-cfg -o yaml
```

**Secret**

```bash
# 通用
k create secret generic db-secret \
  --from-literal=username=admin --from-literal=password='S3cr3t'

# TLS（需要 cert + key）
k create secret tls my-tls --cert=tls.crt --key=tls.key

# 私有镜像仓库（考试可能考）
k create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user --docker-password=pass

# 查看（值是被 base64 编码的）
k get secret db-secret -o jsonpath='{.data.password}' | base64 -d
```

**两种注入方式（必须都会）**

```yaml
apiVersion: v1
kind: Pod
metadata: {name: cfg-demo}
spec:
  containers:
  - name: app
    image: nginx
    # ---- 方式一：env 注入（单个 key）----
    env:
    - name: APP_ENV
      valueFrom:
        configMapKeyRef: {name: app-cfg, key: APP_ENV}
    - name: DB_PASS
      valueFrom:
        secretKeyRef: {name: db-secret, key: password}
    # ---- 方式二：envFrom 注入（整个 CM/Secret 所有 key）----
    envFrom:
    - configMapRef: {name: app-cfg}
    # ---- 方式三：volume 挂载（每个 key 变成一个文件）----
    volumeMounts:
    - name: cfg-vol
      mountPath: /etc/app
      readOnly: true
  volumes:
  - name: cfg-vol
    configMap:
      name: nginx-cfg
      items:                      # 可选：只挂载部分 key + 重命名
      - key: nginx.conf
        path: nginx.conf
```

**四种方式对比（考试可能问区别）**

| 方式 | 语法 | 特点 |
|------|------|------|
| 单个 env | `env.valueFrom.configMapKeyRef` | 只注入指定 key |
| 全部 env | `envFrom.configMapRef` | 所有 key 变成环境变量 |
| volume | `volumes.configMap` | key 变成**文件**，支持热更新（约 1 分钟） |
| `subPath` | `volumeMounts.subPath` | 挂单个文件，**不支持热更新**（考点！） |

> 💡 **常见考点**：「挂载 ConfigMap 后修改它，容器里的文件会变吗？」
> 用 volume 挂载 → 会（延迟约 60s）；用 `subPath` 挂载 → **不会**；用 env 注入 → **不会**。

---

### D5｜HPA 水平自动扩缩容

**前提**：集群必须装 `metrics-server`，否则 HPA 一直显示 `<unknown>`。

```bash
# kind 集群安装 metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# kind 需要加 --kubelet-insecure-tls
kubectl patch deploy metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# 验证
k top node
k top pod
```

**创建 HPA**

```bash
# 命令行
k autoscale deploy web --min=2 --max=10 --cpu-percent=50

# yaml
```

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target: {type: Utilization, averageUtilization: 50}
```

```bash
k get hpa
k describe hpa web      # 看 Current/Target 和缩放事件
```

> ⚠️ HPA 计算依赖 Pod 的 `resources.requests.cpu`。**没写 requests 的 Pod 无法被 HPA 计算利用率**，会一直 `<unknown>`。

---

### D6-D7｜动手实验（周末）

#### 实验 1：完整发布流程（⭐核心实验）

要求一条龙走完，全程用命令：

```bash
# 1. 建 CM + Secret
k create cm web-cfg --from-literal=APP_ENV=prod
k create secret generic web-secret --from-literal=API_KEY=abc123

# 2. 写 Deployment，注入上述 CM/Secret（env + volume 两种方式都用上）
# 3. 扩容到 5
# 4. 更新镜像 nginx:1.24 → 1.25 → 1.26（连续两次）
# 5. 查看 revision 历史
# 6. 回滚到 revision=1
# 7. 验证镜像确实是 nginx:1.24
# 8. 用 rollout restart 重启
# 9. 配置 HPA min=2 max=6 cpu=50%
# 10. 用 stress 或 busybox 压测，观察 HPA 扩容
```

**每一步都要验证结果**，别只看命令回显。

#### 实验 2：ConfigMap 热更新验证（易考点）

```bash
k create cm hot --from-literal=version=v1
# 起一个 Pod 挂载这个 CM
# 修改 CM
k create cm hot --from-literal=version=v2 --dry-run=client -o yaml | k apply -f -
# 等 60s，进容器 cat 文件 → 是 v2
# 再用 subPath 挂载同样的 CM，重复实验 → 不变
```

把两个结论写进复盘区。

#### 实验 3：Job / CronJob 故障演练

```bash
# 1. 建一个会失败的 Job，观察 backoffLimit 重试，最后状态 Failed
k create job fail --image=busybox -- sh -c 'exit 1'
k get pod -w          # 会看到 Pod 反复重建
k describe job fail

# 2. 建 CronJob，schedule 设为每分钟，观察 Job 生成
# 3. 把 concurrencyPolicy 改成 Forbid，让 Job 跑久一点，观察并发被禁止
```

---

## 三、本周必练命令

```bash
# Deployment
kubectl create deploy <n> --image=<i> --replicas=<n> [--dry-run=client -o yaml]
kubectl set image deploy/<n> <ctr>=<new-image>
kubectl scale deploy/<n> --replicas=<n>
kubectl rollout status|history|undo|pause|resume|restart deploy/<n>
kubectl rollout undo deploy/<n> --to-revision=<n>

# 查看管理链
kubectl get deploy,rs,po -l app=<x>
kubectl describe deploy <n>

# ConfigMap / Secret
kubectl create cm <n> --from-literal=k=v --from-file=f --from-env-file=e
kubectl create secret generic <n> --from-literal=k=v
kubectl create secret tls <n> --cert= --key=
kubectl create secret docker-registry <n> --docker-server= --docker-username= --docker-password=

# Job / CronJob
kubectl create job <n> --image=<i> -- <cmd>
kubectl create cronjob <n> --image=<i> --schedule="*/1 * * * *" -- <cmd>

# HPA
kubectl autoscale deploy/<n> --min= --max= --cpu-percent=
kubectl get hpa
kubectl top pod|node
```

---

## 四、验收标准

- [ ] `k create deploy --dry-run=client -o yaml` 不查文档一次成功
- [ ] 能说出为什么 `rollout undo` 可以回到上一版（ReplicaSet 保留机制）
- [ ] 在 3 分钟内完成：更新镜像 → 观察 status → 回滚 → 验证镜像版本
- [ ] 能写出 ConfigMap 的 **4 种**注入方式，并说出哪种支持热更新
- [ ] 能独立给一个 Deployment 加 HPA 并解释为什么它可能显示 `<unknown>`
- [ ] Job 的 yaml 里 `restartPolicy` 写 `Always` 会被拒绝——知道原因
- [ ] 能不看文档写出 CronJob 的**三层嵌套** yaml

---

## 五、自测题

1. `maxSurge: 0, maxUnavailable: 0` 能不能用？会怎样？
2. Deployment 的 `rollout restart` 到底做了什么（本质是什么操作）？
3. `kubectl set image` 之后立刻 `kubectl rollout undo`，会发生什么？
4. 一个 Pod 引用了不存在的 ConfigMap（用 `configMapKeyRef`），Pod 状态是什么？用 volume 方式引用不存在的 CM 呢？
5. HPA 显示 `TARGETS: <unknown>/50%`，可能的原因有哪些？（至少 3 个）
6. Job 的 `completions: 3, parallelism: 2` 是什么意思？总共会跑几个 Pod？
7. CronJob 的 `concurrencyPolicy: Forbid` 在什么场景下必要？

---

## 六、踩坑记录

| 现象 | 原因 | 解决 |
|------|------|------|
| | | |

---

## 七、复盘区

**ConfigMap 热更新实验结论**

- volume 挂载：
- subPath 挂载：
- env 注入：

**Deployment 三层关系的理解**

>

**本周用时统计**

| 天 | 计划 | 实际 |
|----|------|------|
| D1 | 1.5h | |
| D2 | 1.5h | |
| D3 | 1.5h | |
| D4 | 1.5h | |
| D5 | 1h | |
| D6 | 3h | |
| D7 | 3h | |

**一句话总结本周**

>

---

*[← 上一周：Week1-环境与基础](Week1-环境与基础.md) ｜ [返回索引](README.md) ｜ [下一周：Week3-调度与亲和性 →](Week3-调度与亲和性.md)*