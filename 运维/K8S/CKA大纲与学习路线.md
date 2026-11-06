# CKA 认证备考：考纲 · 学习路线 · 每周计划

> 目标：通过 Linux Foundation / CNCF 的 **CKA（Certified Kubernetes Administrator）**
> 形式：全实操，无选择题，**2 小时**，远程监考
> 通过线：**66 分**（历史标准，以官方页面为准）
> 允许查阅：kubernetes.io 官方文档（**这是最重要的信息，不要死记 yaml**）

---

## 📁 配套文件导航

本文是**总纲**。逐周执行请看拆分版：

| 文件 | 用途 |
|------|------|
| **[CKA-8周计划/README.md](CKA-8周计划/README.md)** | **入口索引**：进度追踪表 + 使用方法 |
| [Week1-环境与基础.md](CKA-8周计划/Week1-环境与基础.md) | 集群搭建、架构、Pod 基础、kubectl 手感 |
| [Week2-工作负载.md](CKA-8周计划/Week2-工作负载.md) | Deployment、滚动更新、Job、CM/Secret、HPA |
| [Week3-调度与亲和性.md](CKA-8周计划/Week3-调度与亲和性.md) | Taint/Toleration、亲和性、DaemonSet、Static Pod |
| [Week4-服务与网络.md](CKA-8周计划/Week4-服务与网络.md) | Service、Endpoints、CoreDNS、NetworkPolicy、Ingress |
| [Week5-存储与RBAC.md](CKA-8周计划/Week5-存储与RBAC.md) | PV/PVC、StorageClass、RBAC 四件套 |
| [Week6-集群运维.md](CKA-8周计划/Week6-集群运维.md) | kubeadm、etcd 备份恢复、升级、证书 |
| [Week7-故障排查.md](CKA-8周计划/Week7-故障排查.md) | Pod/节点/控制平面/网络排障、故障演练 |
| [Week8-模拟冲刺.md](CKA-8周计划/Week8-模拟冲刺.md) | killer.sh ×2、错题复盘、考前准备 |
| **[CKA速查表.md](CKA-8周计划/CKA速查表.md)** | **考前只看这一份**：命令 + yaml 模板 + 排障流程 + 易错点 |

---

## 一、考试概览

| 项目 | 说明 |
|------|------|
| 考试代号 | CKA |
| 时长 | 120 分钟 |
| 题量 | 15~20 道实操题 |
| 形式 | 浏览器内远程桌面（PSI 监考），可开 1 个浏览器标签访问 k8s.io/docs |
| 通过分 | 66 / 100 |
| 有效期 | 3 年（2025 起部分考试有重认证要求，报名时确认） |
| 前置要求 | 无硬性要求，但需 Linux + 容器基础 |
| 常用集群 | 每题独立集群/上下文，**务必先切 context** |

---

## 二、官方考纲（Domains & Competencies）

### 权重总览

| 模块 | 权重 | 优先级 |
|------|------|--------|
| Troubleshooting 故障排查 | **30%** | ⭐⭐⭐⭐⭐ 重中之重 |
| Cluster Architecture, Installation & Configuration | **25%** | ⭐⭐⭐⭐⭐ 核心 |
| Services & Networking 服务与网络 | **20%** | ⭐⭐⭐⭐ 高频 |
| Workloads & Scheduling 工作负载与调度 | **15%** | ⭐⭐⭐ 常用 |
| Storage 存储 | **10%** | ⭐⭐⭐ 必掌握 |

> ⚠️ 注意：不同版本考纲权重略有调整（部分版本 Services & Networking 为 20%、Workloads 为 15%）。报名后以官方考试页面 PDF 为准。
> *（本地 `CKA大纲.sh` 中记录 Services 为 20%，本文与之一致。）*

---

### 模块 1：Troubleshooting — 故障排查（30%）

考试大量题目是「给你一个坏掉的集群 / 资源，定位并修复」，最贴近真实运维。

**细分知识点**

- **节点故障排查**
  - Node `NotReady`，定位 kubelet / 容器运行时 / 网络
  - `journalctl -u kubelet`、`systemctl status`、磁盘与内存压力
  - `df -h`、`free -m`、`top`、节点 conditions
- **控制平面组件故障**
  - apiserver / etcd / scheduler / controller-manager 静态 Pod 异常
  - `/etc/kubernetes/manifests/` 下的静态 Pod 清单错误
  - 证书过期（`kubeadm certs check-expiration`）
- **Pod 状态异常**
  - `Pending`（资源不足 / 污点 / 亲和性 / PVC 未绑定）
  - `CrashLoopBackOff`（应用启动失败、探针失败、命令错误）
  - `ImagePullBackOff` / `ErrImagePull`（镜像名、私有仓库 secret）
  - `RunContainerError`、`OOMKilled`（limits 太小）
  - `CreateContainerConfigError`（ConfigMap/Secret 缺失）
- **容器与应用排障**
  - `kubectl logs [-c container] [-f] [--previous]`
  - `kubectl describe pod` → **看 Events，排障第一站**
  - `kubectl exec -it -- sh`
  - 多容器 Pod（sidecar）日志区分
- **网络与 Service 排障**
  - Pod 间不通、Pod 访问 Service 异常
  - `Endpoints` 为空 → 查 selector / label 是否匹配
  - CoreDNS 解析失败（`nslookup`、`dig`、`/etc/resolv.conf`）
  - kube-proxy 的 iptables / IPVS 规则
- **资源监控**
  - metrics-server、`kubectl top node/pod`
  - 节点资源耗尽导致的驱逐（Eviction）

**必练命令**

```bash
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> [-c <container>] [-f] [--previous]
kubectl get events --sort-by=.lastTimestamp
kubectl top node
kubectl top pod -A
journalctl -u kubelet -f
kubectl get pods -o wide
kubectl get endpoints <svc>
```

---

### 模块 2：Cluster Architecture, Installation & Configuration（25%）

**细分知识点**

- **架构理解**
  - 控制平面：kube-apiserver、etcd、kube-scheduler、kube-controller-manager、cloud-controller-manager
  - 节点：kubelet、kube-proxy、CRI 运行时（containerd / CRI-O）
  - 声明式 API、控制器模式、etcd 为唯一真相源
- **kubeadm 集群管理**
  - `kubeadm init` / `kubeadm join` / `kubeadm token create --print-join-command`
  - HA 控制平面部署（多 master + LB + etcd 奇数节点）
  - 集群升级：`kubeadm upgrade plan` / `apply` + `kubelet` 升级 + drain/uncordon
- **底层接口**
  - CNI（网络）、CSI（存储）、CRI（运行时）
- **RBAC（高频必考）**
  - Role / ClusterRole / RoleBinding / ClusterRoleBinding
  - 动词 verbs、资源 resources、apiGroups
  - 用 `kubectl auth can-i` 验证
  - 为 ServiceAccount 授权、user 授权
- **扩展与部署工具**
  - CRD 概念、Operator 基础
  - Helm 基础（install/upgrade/rollback）、Kustomize 基础
- **kubeconfig 与上下文**
  - `kubectl config view/use-context/set-context/set-credentials`
- **集群生命周期**
  - **etcd 备份与恢复**（`etcdctl snapshot save/restore`）——常考
  - 证书管理、节点维护（`drain` / `cordon` / `uncordon`）

**必练**

```bash
kubeadm token create --print-join-command
kubectl create role ... --verb=... --resource=...
kubectl create rolebinding ... --role=... --serviceaccount=...
kubectl auth can-i get pods --as=system:serviceaccount:ns:sa
ETCDCTL_API=3 etcdctl snapshot save /tmp/backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data
```

---

### 模块 3：Services & Networking（20%）

**细分知识点**

- **网络模型**：每个 Pod 独立 IP，Pod 间无需 NAT 直接通信
- **Service**
  - 类型：ClusterIP / NodePort / LoadBalancer / ExternalName
  - Endpoints / EndpointSlice、selector 匹配
  - 无 selector 的 Service + 手动 Endpoints
- **CoreDNS**
  - 服务发现：`<svc>.<ns>.svc.cluster.local`
  - 故障排查：`nslookup`、`dig`、coredns ConfigMap
- **NetworkPolicy**
  - ingress / egress 规则、podSelector / namespaceSelector / ipBlock
  - 默认拒绝策略
  - ⚠️ 注意：NetworkPolicy 只是声明，需 CNI 支持（Calico/Cilium 支持，Flannel 不支持）
- **Ingress / Gateway API**
  - Ingress 资源 + Ingress Controller（nginx）
  - TLS、path / host 路由
- **kube-proxy 原理**：iptables / IPVS 模式

**必练**

```bash
kubectl expose deployment nginx --port=80 --target-port=80 --type=NodePort
kubectl create ingress demo --rule="/path=svc:80" --dry-run=client -o yaml
kubectl get endpointslices -n <ns>
```

---

### 模块 4：Workloads & Scheduling（15%）

**细分知识点**

- **Deployment**
  - 创建、`rollout status/history/undo`、`set image`、`scale`
  - 滚动更新策略 maxSurge / maxUnavailable
  - Deployment → ReplicaSet → Pod 关系
- **Pod 基础**
  - 多容器、initContainer、sidecar
  - `requests` / `limits`、QoS 等级（Guaranteed / Burstable / BestEffort）
  - 探针：liveness / readiness / startup
- **调度**
  - Label / Selector / Annotation（**考试常考 label 打标与筛选**）
  - nodeName、nodeSelector
  - NodeAffinity（required / preferred）
  - PodAffinity / PodAntiAffinity + topologyKey
  - **Taint & Toleration（⭐高频）**：`NoSchedule` / `PreferNoSchedule` / `NoExecute`
  - DaemonSet、Static Pod（`/etc/kubernetes/manifests`）
  - 手动调度：`spec.nodeName` 直接指定
- **配置管理**
  - ConfigMap / Secret（env 注入、volume 挂载、`immutable`）
  - Secret 类型：Opaque / tls / dockerconfigjson
- **HPA**
  - `kubectl autoscale`、metrics-server 依赖
- **Job / CronJob**

**必练**

```bash
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
kubectl create deployment web --image=nginx --replicas=3 --dry-run=client -o yaml
kubectl set image deploy/web nginx=nginx:1.25
kubectl rollout undo deploy/web
kubectl taint node node1 key=value:NoSchedule
kubectl label node node1 disk=ssd
kubectl create configmap app --from-literal=k=v --dry-run=client -o yaml
```

---

### 模块 5：Storage（10%）

**细分知识点**

- **Volume 类型**：emptyDir、hostPath、configMap/secret、nfs
- **PV / PVC**
  - PersistentVolume（容量、accessModes、storageClassName、hostPath/nfs/local）
  - PersistentVolumeClaim 绑定规则（容量 ≥、accessModes 匹配、SC 匹配）
  - 访问模式：RWO / ROX / RWX / RWOP
  - 回收策略：Retain / Delete / Recycle
  - PV 状态：Available / Bound / Released / Failed
- **StorageClass**
  - 动态供给（provisioner）、`volumeBindingMode`
  - 默认 StorageClass（annotation `storageclass.kubernetes.io/is-default-class`）
- **使用**
  - Pod 挂载 PVC、Deployment 挂载
  - 扩容：`allowVolumeExpansion`

**必练**：手写 PV + PVC 并绑定；创建 StorageClass 后动态申请 PVC。

---

## 三、前置基础清单

| 领域 | 需要掌握 |
|------|---------|
| Linux | shell、systemd、`journalctl`、文件权限、vim/nano、`ip`/`ss`/`curl`/`nslookup`、`tar`、`df`/`free` |
| 容器 | 镜像/容器/仓库、Dockerfile、namespace/cgroup 概念、containerd |
| YAML | 缩进（**空格，禁止 Tab**）、列表 `-`、多文档 `---` |
| Kubectl | 熟练 + `alias k=kubectl` + bash/zsh 补全 + `--dry-run=client -o yaml` |
| 网络 | TCP/IP、DNS、iptables 基础、NAT |

**环境准备（第一周完成）**

```bash
# 方案 A：kind（最快，Mac 推荐）
brew install kind kubectl
kind create cluster --name cka --config kind-ha.yaml

# 方案 B：kubeadm（最贴近考试，需要 Linux VM × 3）
# 1 master + 2 worker，Ubuntu 22.04，安装 containerd + kubeadm

# 方案 C：minikube（单节点，够用但不够像考试）
brew install minikube && minikube start --nodes=3

# 通用提效
alias k=kubectl
source <(kubectl completion zsh)
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
```

---

## 四、学习路线（总体策略）

```
第0步 环境搭建 + kubectl 肌肉记忆
   ↓
第1步 概念打底（架构 + 五大对象：Pod/Deploy/Svc/CM/PV）
   ↓
第2步 分模块动手（每个知识点都要亲手敲出来，不抄不算学）
   ↓
第3步 高频硬骨头专项（RBAC / etcd 备份恢复 / NetworkPolicy / Taint / 排障）
   ↓
第4步 模拟考试 + 计时（killer.sh 至少 2 轮）
   ↓
第5步 错题复盘 + 速查表固化
```

**六条铁律**

1. **先切 context，再动手。** 每题开头 `kubectl config use-context xxx`，做错集群直接 0 分。
2. **能生成就不手写。** `--dry-run=client -o yaml` 生成模板再改。
3. **documentation 是你的朋友。** 打开 k8s.io/docs 的搜索页预先固定，考试靠复制改。
4. **describe → events → logs**：排障固定三步。
5. **每道题做完立即验证。** `kubectl get/describe` 确认是否符合要求。
6. **卡住就标记跳过。** 15 题 120 分钟，平均 8 分钟/题。

---

## 五、8 周计划（每周 10~12 小时，适合在职）

> 节奏：工作日 1~1.5h/天 + 周末各 3h。可按自己时间等比缩放。

### Week 1｜环境 + 基础概念 + kubectl 手感

| 天 | 内容 |
|----|------|
| D1 | 装 kind/minikube，跑起 3 节点集群；装 kubectl 补全、设 `alias k` |
| D2 | K8s 架构逐个组件读官方文档；画出控制平面与节点组件图 |
| D3 | Pod 基础：创建、`exec`、`logs`、`describe`、多容器、initContainer |
| D4 | Label / Selector / Annotation；`kubectl get -l` 筛选 |
| D5 | Namespace、Node 查看、`kubectl get all`、`explain` 用法 |
| D6-D7 | **动手**：手写 5 个 Pod yaml（含 initContainer、resources、探针）；整理「kubectl 速查表」 |

✅ 验收：能不看文档写出带探针和资源限制的 Pod；`kubectl -h` 常见子命令都摸过一遍。

---

### Week 2｜Workloads 工作负载（Deployment / Job / HPA）

| 天 | 内容 |
|----|------|
| D1 | ReplicaSet / Deployment 关系，创建与扩容 |
| D2 | 滚动更新策略、`rollout status/history/undo`、`set image` |
| D3 | Job / CronJob；`completions` / `parallelism` |
| D4 | ConfigMap：`--from-literal` / `--from-file`，env 注入 vs volume 挂载 |
| D5 | Secret：Opaque / tls / dockerconfigjson；base64 编解码 |
| D6-D7 | **动手**：完整做一个「Deployment + CM + Secret + 滚动更新 + 回滚」实验；HPA + metrics-server 实验 |

✅ 验收：能 5 分钟内从零搭出一个带配置注入的 Deployment 并成功回滚。

---

### Week 3｜Scheduling 调度 + Taint/亲和性（高频）

| 天 | 内容 |
|----|------|
| D1 | 调度器原理：过滤 → 打分；`nodeName` 手动调度 |
| D2 | nodeSelector / NodeAffinity（required vs preferred） |
| D3 | **Taint & Toleration 专项**：三种 effect，`kubectl taint` 增删 |
| D4 | PodAffinity / PodAntiAffinity + topologyKey |
| D5 | DaemonSet、Static Pod（`/etc/kubernetes/manifests`） |
| D6-D7 | **动手**：三节点集群上做「A 副本分散、B 只跑带污点节点、C 作为 DaemonSet」的组合题 |

✅ 验收：能在 8 分钟内完成"给节点打污点 + 部署只在污点节点运行的 Pod + 反亲和打散"。

---

### Week 4｜Services & Networking（20%）

| 天 | 内容 |
|----|------|
| D1 | Service 四种类型；ClusterIP / NodePort 实验 |
| D2 | Endpoints / EndpointSlice；selector 不匹配的排查 |
| D3 | CoreDNS：域名格式、`nslookup`/`dig` 实验、定制 ConfigMap |
| D4 | **NetworkPolicy 专项**：ingress/egress、namespaceSelector、默认拒绝 |
| D5 | Ingress + nginx-ingress-controller；TLS；path/host 路由 |
| D6-D7 | **动手**：搭 ingress-nginx，做「域名分流 + 只允许某 namespace 访问」的组合实验 |

✅ 验收：能写默认拒绝 + 白名单的 NetworkPolicy，并用 Ingress 暴露服务。

---

### Week 5｜Storage 存储 + RBAC（两座必须攻克的山）

| 天 | 内容 |
|----|------|
| D1 | Volume 类型：emptyDir / hostPath / configMap |
| D2 | PV / PVC 手工绑定：容量、accessModes、回收策略 |
| D3 | StorageClass 动态供给；默认 SC |
| D4 | **RBAC 专项上**：Role / RoleBinding / ServiceAccount |
| D5 | **RBAC 专项下**：ClusterRole / ClusterRoleBinding / `auth can-i` |
| D6-D7 | **动手**：① 手写 PV+PVC+Pod 挂载全链路；② 给 SA 只读某 namespace 的 pods 权限并验证 |

✅ 验收：`kubectl auth can-i` 能证明权限正确；PVC 能 Bound 并被 Pod 使用。

---

### Week 6｜集群运维：kubeadm / etcd / 升级 / 证书

| 天 | 内容 |
|----|------|
| D1 | kubeadm init 流程拆解；control-plane 静态 Pod 清单目录 |
| D2 | `kubeadm join`、`token create --print-join-command`、节点加入与移除 |
| D3 | **etcd 备份与恢复专项**（常考原题）：`snapshot save` / `restore` |
| D4 | 集群升级：`kubeadm upgrade plan/apply` + kubelet + drain/uncordon |
| D5 | 证书：`kubeadm certs check-expiration` / `renew` |
| D6-D7 | **动手**：在 kubeadm 集群上完整演练「备份 → 破坏 → 恢复」+ 一次小版本升级 |

✅ 验收：不看文档完成 etcd 备份 + 从备份恢复集群；能解释 drain/cordon/uncordon 区别。

---

### Week 7｜Troubleshooting 专项（30%，最拉开差距）

| 天 | 内容 |
|----|------|
| D1 | 排障方法论：describe → events → logs → 组件状态；建自己的 checklist |
| D2 | Pod 异常状态全量：Pending / CrashLoop / ImagePull / CreateContainerConfigError / OOMKilled |
| D3 | 节点 NotReady：kubelet、containerd、证书、磁盘压力、swap |
| D4 | 控制平面故障：静态 Pod 挂掉、apiserver 起不来、scheduler 不调度 |
| D5 | 网络排障：DNS、Endpoints 空、NetworkPolicy 误伤、iptables |
| D6-D7 | **动手**：人为制造 10 个故障（改错 yaml、停服务、删证书、占满磁盘）逐个修 |

✅ 验收：给定一个「坏掉的集群/资源」，15 分钟内在不查文档情况下定位并修复。

---

### Week 8｜模拟考试 + 冲刺

| 天 | 内容 |
|----|------|
| D1-D2 | **killer.sh 第一轮**（计时 2 小时），严格按考试节奏 |
| D3 | 复盘：逐题记「错在哪、正确路径、耗时」，重做错的题 |
| D4 | 弱项专项补漏（按前两周错题统计） |
| D5 | **killer.sh 第二轮**（或另一套模拟），目标 ≥ 75 分 |
| D6 | 只看自己的速查表 + 官方文档检索路径演练；不做新题 |
| D7 | 考试环境准备（网络、摄像头、桌面清理），早睡；考前只过一遍「六条铁律」 |

✅ 验收：两轮模拟均 ≥ 66 分，且第二轮错题 ≤ 3 道。

---

## 五-附：每周文件对应关系

| 8 周计划章节 | 对应文件 |
|-------------|---------|
| Week 1 | [Week1-环境与基础.md](CKA-8周计划/Week1-环境与基础.md) |
| Week 2 | [Week2-工作负载.md](CKA-8周计划/Week2-工作负载.md) |
| Week 3 | [Week3-调度与亲和性.md](CKA-8周计划/Week3-调度与亲和性.md) |
| Week 4 | [Week4-服务与网络.md](CKA-8周计划/Week4-服务与网络.md) |
| Week 5 | [Week5-存储与RBAC.md](CKA-8周计划/Week5-存储与RBAC.md) |
| Week 6 | [Week6-集群运维.md](CKA-8周计划/Week6-集群运维.md) |
| Week 7 | [Week7-故障排查.md](CKA-8周计划/Week7-故障排查.md) |
| Week 8 | [Week8-模拟冲刺.md](CKA-8周计划/Week8-模拟冲刺.md) |

---

## 六、时间紧张版（4 周冲刺，每周 20h）

| 周 | 重点 |
|----|------|
| Week 1 | 环境 + Workloads + Scheduling（含 Taint） |
| Week 2 | Services & Networking + Storage + RBAC |
| Week 3 | kubeadm / etcd 备份恢复 + Troubleshooting 专项 |
| Week 4 | killer.sh ×2 + 错题复盘 + 冲刺 |

> 前提：已有 Linux 与容器基础。若没有，先补 1 周基础再进这个节奏。

---

## 七、高频考点 Top 15（复习优先级）

1. **Taint / Toleration** 与污点节点上部署 Pod
2. **RBAC**：创建 Role/ClusterRole + Binding，为 SA/user 授权
3. **etcd 备份与恢复**
4. **Deployment 滚动更新 / 回滚 / 扩容**
5. **NetworkPolicy** 编写与验证
6. **Pod 排障**（CrashLoopBackOff / Pending / ImagePull）
7. **节点排障**（NotReady、kubelet 起不来）
8. **Service 暴露 + Endpoints 为空排查**
9. **PV / PVC 手工绑定 + Pod 挂载**
10. **Static Pod** 创建/修复（/etc/kubernetes/manifests）
11. **nodeSelector / NodeAffinity / PodAntiAffinity**
12. **ConfigMap / Secret 注入**
13. **Ingress 配置**
14. **节点维护 drain / cordon / uncordon**
15. **集群升级 kubeadm upgrade**

---

## 八、考试通用技巧

1. **每题先切 context**：`kubectl config use-context xxx`。做错集群直接 0 分。
2. **优先级排序**：先扫一遍所有题，把简单题（写 yaml、打 label）先做完，再去啃排障。
3. **用 `--dry-run=client -o yaml`** 生成模板，保存到 `/tmp/xxx.yaml` 再编辑 apply。
4. **vim 配置**：考前设 `:set paste` 或准备 `.vimrc`（`set tabstop=2 shiftwidth=2 expandtab`）。
5. **验证意识**：每道题做完 `kubectl get -o yaml` 检查实际结果，别只看 apply 成功。
6. **时间管理**：单题超过 10 分钟先标记跳过，留 15 分钟回查。
7. **文档检索**：只开官方文档，提前练好「搜关键词 → 找到 yaml 块 → 复制改」的路径。
8. **注意 namespace**：命令默认 default，题目要求的 namespace 必须显式加 `-n`。

---

## 九、资料清单

| 类型 | 资源 |
|------|------|
| 官方文档 | https://kubernetes.io/docs/ （考试内唯一可用） |
| 官方任务页 | https://kubernetes.io/docs/tasks/ （yaml 复制最佳来源） |
| 模拟考试 | https://killer.sh/ （买 CKA 通常含 2 次，**强烈推荐**） |
| 本地实验 | kind / minikube / kubeadm / Vagrant |
| 交互学习 | killercoda.com（有免费 K8s 场景） |
| 练习题库 | github 搜索 "cka-exercises"、"kubernetes-the-hard-way" |
| 视频 | 官方 CKA 课程（LF 出品）、Mumshad KodeKloud CKA 课 |

---

## 十、自查进度表

| 周 | 主题 | 完成 |
|----|------|------|
| W1 | 环境 + 基础概念 + kubectl | ☐ |
| W2 | Workloads 工作负载 | ☐ |
| W3 | Scheduling + Taint/亲和性 | ☐ |
| W4 | Services & Networking | ☐ |
| W5 | Storage + RBAC | ☐ |
| W6 | kubeadm / etcd / 升级 / 证书 | ☐ |
| W7 | Troubleshooting 专项 | ☐ |
| W8 | 模拟考试 + 冲刺 | ☐ |

**每周固定动作**
- 手敲实验 → 写 3 行总结（学到什么 / 卡在哪 / 下次怎么更快）
- 更新自己的速查表（`常用命令` 文件）
- 周日回顾：本周内容能否在 10 分钟内从零重做一遍？

---

*最后更新：见 git 记录*