# Week 1｜环境搭建 + 基础概念 + kubectl 手感

> **本周时长**：10~12 小时（工作日 1~1.5h + 周末各 3h）
> **本周定位**：把地基打牢。这一周不追求做难题，追求两件事——**集群能跑起来**、**kubectl 敲得顺手**。
> **上一周**：无 ｜ **下一周**：[Week2-工作负载.md](Week2-工作负载.md)

---

## 一、本周目标

学完本周你应该能做到：

- [ ] 在本机跑起一个 **3 节点** Kubernetes 集群，能自由删除重建
- [ ] 画出并口头讲出 K8s 架构：4 个控制平面组件 + 3 个节点组件各干什么
- [ ] 不看文档写出一个带 **initContainer + 探针 + 资源限制** 的 Pod yaml
- [ ] `kubectl` 常用子命令不查 `-h` 也能敲出来
- [ ] 熟练使用 `-l` 标签筛选、`-o wide/yaml/jsonpath`、`kubectl explain`

---

## 二、逐日安排

### D1｜安装集群，先跑起来

**任务**

1. 安装 `kubectl`、`kind`（Mac 推荐）或 `minikube`
2. 创建一个 **3 节点**集群（1 control-plane + 2 worker）
3. 配置 shell 提效

```bash
# ---- Mac 安装 ----
brew install kubectl kind

# ---- 创建 3 节点集群 ----
cat > /tmp/kind-3node.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cka
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
kind create cluster --config /tmp/kind-3node.yaml

# ---- 验证 ----
kubectl get nodes -o wide
kubectl get pods -n kube-system
kubectl cluster-info
```

**shell 提效（写进 `~/.zshrc`）**

```bash
alias k=kubectl
alias kk='kubectl'
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
source <(kubectl completion zsh)
complete -F __start_kubectl k   # 让 alias k 也有补全
```

> 💡 补全生效后，`k get po -n kube-<TAB>` 会直接补出 namespace，效率提升巨大。

---

### D2｜K8s 架构：把每个组件的职责说清楚

**任务**：读官方文档 **Kubernetes Components** 一节，然后回答下面的问题（写在本文件「复盘区」）。

**控制平面（Control Plane）**

| 组件 | 职责 | 关键记忆点 |
|------|------|-----------|
| kube-apiserver | 集群唯一入口，REST API，认证/授权/准入 | **只有它直连 etcd**；无状态可多副本 |
| etcd | 键值存储，保存集群唯一真实状态 | Raft，奇数节点（3/5）；**备份它 = 备份整个集群** |
| kube-scheduler | 为新 Pod 选节点 | 过滤（Filter）→ 打分（Score）两阶段 |
| kube-controller-manager | 一堆控制器的合体 | 每个控制器是「期望状态 vs 实际状态」调谐循环 |
| cloud-controller-manager | 对接云厂商 API（可选） | 负载均衡、云盘、节点生命周期 |

**节点（Node）**

| 组件 | 职责 | 关键记忆点 |
|------|------|-----------|
| kubelet | 节点上的工头，管 Pod 生命周期 | 执行探针；上报状态；**不通过 CRI 以外的运行时** |
| kube-proxy | 维护网络规则实现 Service 转发 | iptables / IPVS 模式 |
| Container Runtime | 真正跑容器 | containerd / CRI-O，通过 **CRI** 接口 |
| Pod | 最小调度单元 | 共享网络命名空间（同一 Pod 内容器走 localhost） |

**三个必答问题**（自测）

1. `kubectl apply` 之后，一个 Pod 从"提交"到"容器跑起来"，中间经过了哪几个组件？按顺序说出来。
2. 为什么说"备份 etcd 就等于备份了整个集群"？
3. kubelet 和 apiserver 是谁主动连谁？（提示：kubelet 主动 watch）

---

### D3｜Pod 基础：创建、调试、多容器

**任务**

```bash
# 最快速的 Pod 创建（考试常用）
k run nginx --image=nginx
k get po -o wide

# 生成 yaml 模板再改（考试核心手法）
k run nginx --image=nginx --dry-run=client -o yaml > /tmp/pod.yaml

# 端口、标签、命令
k run busy --image=busybox --labels="app=tools,tier=debug" \
  --command -- sleep 3600
```

**进容器调试**

```bash
k exec -it nginx -- sh
k exec -it nginx -- ls /etc/nginx
k logs nginx
k logs nginx --previous        # 看上一次崩溃的容器日志（排障神器）
k describe pod nginx           # 重点看 Events
```

**多容器 Pod + initContainer**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi
spec:
  initContainers:                 # 按顺序执行，全部成功主容器才启动
  - name: init-svc
    image: busybox
    command: ['sh','-c','until nslookup mysvc; do echo waiting; sleep 2; done']
  containers:
  - name: app
    image: nginx
  - name: sidecar
    image: busybox
    command: ['sh','-c','while true; do echo hi; sleep 5; done']
```

> 💡 **initContainer 的典型考点**：等待依赖服务就绪、下载配置、初始化数据卷。

---

### D4｜Label / Selector / Annotation

**任务**

```bash
# 打标签
k label pod nginx env=prod tier=web
k label pod nginx env=dev --overwrite

# 按标签筛选（考试高频）
k get pods -l env=prod
k get pods -l 'env in (prod,dev)'
k get pods -l '!env'                 # 没有 env 标签的
k get pods --show-labels

# 在节点上打标签（下周调度要用）
k label node cka-worker disk=ssd

# 删除标签
k label pod nginx env-
```

**Annotation vs Label 的区别**

| | Label | Annotation |
|---|---|---|
| 用途 | **被 selector 选中**，参与调度/服务发现 | 存元信息，**不能被筛选** |
| 长度 | 短，受字符限制 | 可存长文本、JSON、配置 |
| 例子 | `app=nginx`, `env=prod` | `kubectl.kubernetes.io/last-applied-configuration` |

---

### D5｜Namespace + 查看资源的各种姿势

**任务**

```bash
# Namespace
k create ns dev
k get ns
k get pods -n dev
k config set-context --current --namespace=dev   # 切换默认 ns（考试提效）

# 查看
k get all -n dev
k get po,svc,deploy
k get po -o wide
k get po -o yaml
k get po -o jsonpath='{.items[*].metadata.name}'
k get po -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'
k get po --sort-by=.metadata.creationTimestamp

# 字段解释（不用查文档）
k explain pod.spec.containers
k explain pod.spec.containers.resources --recursive

# 事件（排障必看）
k get events --sort-by=.lastTimestamp
k get events -A --field-selector type=Warning
```

**考试提速：`--sort-by` 和 `jsonpath` 值不值得练？**
值得。有些题目要求"找出创建时间最早/最晚的 Pod"，`--sort-by` 一行搞定。

---

### D6-D7｜动手实验（周末）

#### 实验 1：手写 5 个 Pod（不看文档）

要求每个都 **手写 yaml**（写错就 `k apply` 试，靠报错学）：

1. 最简 Pod：nginx，1 个容器
2. 带资源限制：requests 100m/128Mi，limits 200m/256Mi
3. 带三种探针：liveness（httpGet）、readiness（exec）、startup
4. 带 initContainer：init 容器写一个文件到 emptyDir，主容器读它
5. 双容器 sidecar：一个 nginx + 一个 busybox 每 5 秒 curl localhost

**探针参考写法**

```yaml
    resources:
      requests: {cpu: 100m, memory: 128Mi}
      limits:   {cpu: 200m, memory: 256Mi}
    startupProbe:
      httpGet: {path: /, port: 80}
      failureThreshold: 30
      periodSeconds: 2
    livenessProbe:
      httpGet: {path: /, port: 80}
      initialDelaySeconds: 10
      periodSeconds: 10
    readinessProbe:
      exec:
        command: ['sh','-c','test -f /tmp/ready']
      periodSeconds: 5
```

#### 实验 2：制造并观察 Pod 异常（预习下周排障）

```bash
# 1. 镜像不存在 → ImagePullBackOff
k run bad --image=nginx:notexist

# 2. 命令立即退出 → CrashLoopBackOff
k run crash --image=busybox -- sh -c 'echo boom; exit 1'

# 3. 资源要得太大 → Pending
k run big --image=nginx --overrides='
{"spec":{"containers":[{"name":"c","image":"nginx",
"resources":{"requests":{"memory":"200Gi"}}}]}}'
```

对每个 Pod 执行 `k describe pod xxx`，**把 Events 抄到复盘区**。这是排障的原始素材。

#### 实验 3：整理自己的 kubectl 速查表

在 `../CKA速查表.md` 里补充你这一周常用但容易忘的命令。别人的速查表不如自己写的。

---

## 三、本周必练命令

```bash
# 集群
kubectl cluster-info
kubectl get nodes -o wide
kubectl get componentstatuses        # 老版本；新版本看 kube-system 里的静态 Pod

# 创建/生成
kubectl run <name> --image=<img> [--dry-run=client -o yaml]
kubectl create ns <ns>
kubectl apply -f file.yaml

# 查看
kubectl get <res> [-n ns] [-o wide|yaml|jsonpath] [-l selector] [--show-labels]
kubectl describe <res> <name>
kubectl explain <path> [--recursive]

# 调试
kubectl logs <pod> [-c <ctr>] [--previous] [-f]
kubectl exec -it <pod> -- sh
kubectl get events --sort-by=.lastTimestamp

# 标签
kubectl label <res> <name> key=value [--overwrite]
kubectl label <res> <name> key-
```

---

## 四、验收标准

本周结束前，逐条自测，**全部打勾才算过关**：

- [ ] 能在 **5 分钟内**从零创建 3 节点 kind 集群并 `kubectl get nodes` 全 Ready
- [ ] 能口头按顺序讲出「kubectl apply → Pod 运行」的完整链路（含至少 5 个组件）
- [ ] 不看文档写出带 initContainer + 探针 + resources 的 Pod yaml，一次 `apply` 成功
- [ ] 能从现有 Pod **反向生成** yaml 并保存文件
- [ ] 能用 `-l` 做 3 种筛选：等值、集合 `in`、否定
- [ ] 能解释 Label 与 Annotation 的区别，并各举一例
- [ ] 见到 `CrashLoopBackOff` 知道第一步该执行 `describe` + `logs --previous`

---

## 五、自测题（答案写在自己的笔记里，不要抄）

1. `kubectl run` 和 `kubectl create deployment` 的区别是什么？`kubectl run` 在 1.18 之后行为有什么变化？
2. 一个 Pod 里两个容器能通过 `localhost` 通信吗？为什么？
3. `kubectl logs --previous` 什么时候用？
4. `kubectl explain pod.spec.containers.resources` 输出里，`limits` 和 `requests` 分别有什么后果（超出会怎样）？
5. 集群里 `kube-system` 命名空间下的 `kube-apiserver-xxx` 这类 Pod，为什么不能用 `kubectl delete pod` 删掉？

---

## 六、踩坑记录

> 记录本周遇到的报错、原因、解决方式。这是最值钱的部分，别嫌麻烦。

| 现象 | 原因 | 解决 |
|------|------|------|
| | | |

---

## 七、复盘区

**D2 三个必答问题的答案**

1.
2.
3.

**本周用时统计**

| 天 | 计划 | 实际 |
|----|------|------|
| D1 | 1.5h | |
| D2 | 1.5h | |
| D3 | 1.5h | |
| D4 | 1h | |
| D5 | 1h | |
| D6 | 3h | |
| D7 | 3h | |

**一句话总结本周**

>

**下周需要补的坑**

>

---

*[← 返回索引](README.md) ｜ [下一周：Week2-工作负载 →](Week2-工作负载.md)*