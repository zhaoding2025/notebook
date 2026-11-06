# Week 6｜集群运维：kubeadm / etcd 备份恢复 / 升级 / 证书

> **本周时长**：10~12 小时
> **本周定位**：考纲 25% 的模块。**etcd 备份恢复几乎必考**，是"不看文档 5 分钟做完"的送分题。
> **上一周**：[Week5-存储与RBAC.md](Week5-存储与RBAC.md) ｜ **下一周**：[Week7-故障排查.md](Week7-故障排查.md)

> ⚠️ 本周需要一台 **Linux 虚拟机**（kind 只有单个容器节点，不适合练 kubeadm）。
> 建议：本地 VirtualBox / Multipass / 或云上一台 2C4G 的 VM。也可以用 `vagrant up` 起 3 台。

---

## 一、本周目标

- [ ] 能手写/读取 kubeadm 初始化配置，理解 `kubeadm init` 每一步在干什么
- [ ] 会用 `kubeadm join` 加节点，会用 `token create --print-join-command`
- [ ] **能从零完成 etcd 备份 + 从备份恢复一个坏掉的集群**（⭐核心）
- [ ] 能执行一次集群升级：`kubeadm upgrade plan/apply` + kubelet + drain
- [ ] 会查看和续期证书
- [ ] 会用 `drain / cordon / uncordon` 做节点维护

---

## 二、知识主线：kubeadm 集群的骨架

### 控制平面节点的目录结构（必记）

| 路径 | 内容 |
|------|------|
| `/etc/kubernetes/manifests/` | **静态 Pod 清单**：kube-apiserver、kube-controller-manager、kube-scheduler、etcd |
| `/etc/kubernetes/pki/` | 所有证书和密钥 |
| `/etc/kubernetes/pki/etcd/` | etcd 专用证书（`ca.crt`、`server.crt`、`server.key`） |
| `/etc/kubernetes/admin.conf` | admin kubeconfig |
| `/etc/kubernetes/kubelet.conf` | kubelet 用的 kubeconfig |
| `/var/lib/kubelet/` | kubelet 数据、静态 Pod 的实际 manifest |
| `/var/lib/etcd/` | etcd 数据目录 |
| `~/.kube/config` | 用户 kubeconfig（由 kubeadm 从 admin.conf 复制） |

### 组件通信

```
kubelet ──(读 /etc/kubernetes/manifests)──▶ 直接启动静态 Pod
                                              │
                                        kube-apiserver（容器）
                                              │
                                        etcd（容器，数据在 /var/lib/etcd）
```

> 🔑 **重要认知**：控制平面组件**本身是静态 Pod**。所以"apiserver 挂了"往往意味着"`/etc/kubernetes/manifests/kube-apiserver.yaml` 被改坏了"，而不是"Pod 被删了"。修复方式就是改那个 yaml 文件。

---

## 三、逐日安排

### D1｜kubeadm init 流程拆解

**初始化配置（推荐先写文件，而不是一堆 flag）**

```yaml
# /tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.1.10
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  name: master1
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.29.0
controlPlaneEndpoint: "192.168.1.10:6443"     # HA 时填 LB 地址
networking:
  podSubnet: "10.244.0.0/16"                   # 与 CNI 匹配
  serviceSubnet: "10.96.0.0/12"
apiServer:
  certSANs:
  - "192.168.1.10"
  - "k8s.example.com"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
```

**执行**

```bash
kubeadm init --config /tmp/kubeadm-config.yaml --upload-certs
```

**kubeadm init 到底做了哪些事（考试可能问）**

1. 前置检查（`preflight`）：端口、内核参数、swap、容器运行时
2. 生成 CA 和各类证书（写到 `/etc/kubernetes/pki/`）
3. 生成 kubeconfig 文件（admin / kubelet / controller-manager / scheduler）
4. 生成静态 Pod 清单（`/etc/kubernetes/manifests/`）
5. 等待 apiserver 起来 → 创建必要 RBAC、namespace
6. 生成 bootstrap token（用于 join）
7. 安装 CoreDNS、kube-proxy（DaemonSet）
8. 输出 join 命令

**初始化后必做**

```bash
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 装 CNI（不装的话节点 NotReady）
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# 单节点集群：去掉控制平面污点
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

**前置检查项速查**

```bash
swapoff -a && sed -i '/swap/d' /etc/fstab
modprobe br_netfilter
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system
```

---

### D2｜节点加入与移除

**获取 join 命令**

```bash
# 在 master 上
kubeadm token create --print-join-command
# 输出形如：
# kubeadm join 192.168.1.10:6443 --token abcdef.0123456789abcdef \
#   --discovery-token-ca-cert-hash sha256:xxxx

# token 有效期 24h，过期就重新生成
kubeadm token list
kubeadm token create
```

**worker 加入**

```bash
# 在 worker 上执行上面拿到的 join 命令
kubeadm join 192.168.1.10:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx

# master 验证
kubectl get nodes
```

**控制平面节点加入（HA）**

```bash
# 在 master1 上生成带证书的 join 命令
kubeadm init phase upload-certs --upload-certs
kubeadm token create --print-join-command --certificate-key <上面输出的key>

# 在 master2 上执行 join 命令 + --control-plane
kubeadm join 192.168.1.10:6443 --token xxx \
  --discovery-token-ca-cert-hash sha256:xxx \
  --control-plane --certificate-key yyy
```

**移除节点**

```bash
# 1. master 上驱逐并删除
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force
kubectl delete node <node>

# 2. 在节点上清理（如果要重新加入）
kubeadm reset -f
rm -rf /etc/cni/net.d $HOME/.kube
ipvsadm --clear
```

**查看 token 与证书哈希**

```bash
kubeadm token list
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -hex | sed 's/^.* //'
```

---

### D3｜etcd 备份与恢复（⭐⭐⭐ 必考）

**etcd 证书路径（考试必用，背下来）**

```
--cacert=/etc/kubernetes/pki/etcd/ca.crt
--cert=/etc/kubernetes/pki/etcd/server.crt
--key=/etc/kubernetes/pki/etcd/server.key
--endpoints=https://127.0.0.1:2379
```

> 💡 如果 cert/key 文件名不同，先 `ls /etc/kubernetes/pki/etcd/` 看一眼。

**备份**

```bash
export ETCDCTL_API=3    # 3.5+ 已经是默认 v3，可省略

etcdctl snapshot save /opt/backup/etcd-$(date +%F).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 验证备份
etcdctl snapshot status /opt/backup/etcd-xxx.db --write-out=table

# 备份文件位置建议：/opt/backup 或 /tmp（考试题会给目录，看清要求）
```

**恢复（⚠️ 考试标准流程）**

恢复的核心是两件事：
1. 把 etcd 数据目录指向新恢复的目录
2. 重启 etcd 静态 Pod（改 manifest 或移动文件）

```bash
# 步骤 1：恢复到一个新目录
etcdctl snapshot restore /opt/backup/etcd-xxx.db \
  --data-dir=/var/lib/etcd-restore

# 步骤 2：把 etcd 的数据目录指向新目录
# 方法 A：改静态 Pod manifest
vi /etc/kubernetes/manifests/etcd.yaml
# 找到：
#   - --data-dir=/var/lib/etcd
# 改成：
#   - --data-dir=/var/lib/etcd-restore
# volumeMounts 和 volumes 里的 hostPath 也要同步改

# 方法 B（更彻底）：停 kubelet 后替换目录
systemctl stop kubelet
mv /var/lib/etcd /var/lib/etcd.bak
mv /var/lib/etcd-restore /var/lib/etcd
# 需要改回 hostPath 权限/属主
chown -R etcd:etcd /var/lib/etcd     # 视版本而定
systemctl start kubelet

# 步骤 3：等待 etcd 和 apiserver 重启
crictl ps | grep etcd
kubectl get nodes
```

**⚠️ 常见坑**

| 坑 | 说明 |
|----|------|
| `--data-dir` 目录必须**不存在或为空** | 否则 restore 报错 |
| restore 时不需要 `--endpoints` | 它只是写文件，不连集群 |
| 改 manifest 后 kubelet 会自动重建 etcd Pod，**不用手动重启 kubelet**（改 manifest 的方式） |
| 恢复后 Pod 会回到备份时刻的状态——**这是预期行为** |
| 如果集群完全挂了，`crictl` 是唯一能看到 Pod 状态的工具 |

**用 crictl 排查（apiserver 挂掉时 kubectl 不可用）**

```bash
crictl ps -a | grep -E 'etcd|apiserver'
crictl logs <container-id>
```

---

### D4｜集群升级

**升级顺序（必须按这个顺序）**

```
① 升级 kubeadm
② kubeadm upgrade plan / apply    （升级控制平面组件）
③ drain 节点
④ 升级 kubelet + kubectl
⑤ uncordon 节点
⑥ 对每个 worker 重复 ③④⑤
```

**控制平面节点升级（master）**

```bash
# 1. 升级 kubeadm 到目标版本
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.29.x-1.1
apt-mark hold kubeadm
kubeadm version

# 2. 查看升级计划
kubeadm upgrade plan

# 3. 执行控制平面升级
kubeadm upgrade apply v1.29.x

# 4. 驱逐本节点
kubectl drain master1 --ignore-daemonsets   # 控制平面节点可能需要 --force

# 5. 升级 kubelet 和 kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.29.x-1.1 kubectl=1.29.x-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

# 6. 恢复调度
kubectl uncordon master1
```

**worker 节点升级**

```bash
# 在 master 上
kubectl drain worker1 --ignore-daemonsets --delete-emptydir-data

# 在 worker1 上
apt-mark unhold kubeadm && apt-get install -y kubeadm=1.29.x-1.1 && apt-mark hold kubeadm
kubeadm upgrade node                 # 注意是 upgrade node，不是 apply
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.29.x-1.1 kubectl=1.29.x-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

# 在 master 上
kubectl uncordon worker1
```

> 🔑 **区别记忆**：`kubeadm upgrade apply` 用于**第一个控制平面节点**；`kubeadm upgrade node` 用于**其他所有节点**（含其他 master 和 worker）。

---

### D5｜证书管理 + 节点维护

**查看证书过期**

```bash
kubeadm certs check-expiration

# 输出示例
# CERTIFICATE                EXPIRES                  RESIDUAL TIME
# admin.conf                 Aug 15, 2025 10:00 UTC   364d
# apiserver                  Aug 15, 2025 10:00 UTC   364d
# etcd-server                Aug 15, 2025 10:00 UTC   364d
```

**续期**

```bash
# 续期全部
kubeadm certs renew all

# 续期单个
kubeadm certs renew apiserver
kubeadm certs renew etcd-server

# ⚠️ 续期后必须重启控制平面静态 Pod（移动 manifest 文件即可触发重建）
cd /etc/kubernetes/manifests
mv kube-apiserver.yaml /tmp/ && sleep 20 && mv /tmp/kube-apiserver.yaml .
# 或者直接重启 kubelet（会重建所有静态 Pod）
systemctl restart kubelet

# 如果是 kubeconfig（admin.conf 等）续期，还要更新 ~/.kube/config
cp /etc/kubernetes/admin.conf $HOME/.kube/config
```

**kubeconfig 管理**

```bash
k config view                                  # 查看所有 context
k config get-contexts                          # 列出
k config current-context                       # 当前
k config use-context <name>                    # 切换（考试第一步！）
k config set-context --current --namespace=dev # 改默认 ns
k config rename-context <old> <new>
k config delete-context <name>

# 用 admin.conf 直接操作
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes
export KUBECONFIG=/etc/kubernetes/admin.conf:other-conf   # 多文件合并
```

**节点维护**

```bash
kubectl cordon <node>          # 标记 Unschedulable，禁止新 Pod 调度
kubectl uncordon <node>        # 恢复

kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
# --ignore-daemonsets        忽略 DaemonSet 管理的 Pod（必须加）
# --delete-emptydir-data     删除使用 emptyDir 的 Pod（必须加，否则报错拒绝）
# --force                    删除非控制器管理的 Pod（裸 Pod）
# --timeout=60s              超时
# --dry-run=server           先演练
```

> 🔑 `drain` = `cordon` + **驱逐现有 Pod**。`cordon` 只禁止新调度。

---

### D6-D7｜动手实验（周末）

**前置**：准备一台 Linux VM（Ubuntu 22.04，2C4G）。用 `multipass launch -n k8s -m 4G -c 2 22.04` 或 Vagrant。

#### 实验 1：从零搭一个 kubeadm 单节点集群（45 分钟）

要求全程不复制文档，凭记忆写出：

1. 关闭 swap、加载内核模块、设 sysctl
2. 安装 containerd + 配置 `SystemdCgroup = true`
3. 安装 kubeadm/kubelet/kubectl 并 `apt-mark hold`
4. `kubeadm init`
5. 配置 kubeconfig
6. 装 Calico
7. 去掉控制平面污点
8. `kubectl get nodes` 显示 Ready

#### 实验 2：etcd 备份 + 恢复（⭐核心，40 分钟）

**这个实验必须做到闭眼完成，考试几乎必考。**

```bash
# ---- 阶段 1：备份 ----
mkdir -p /opt/backup
etcdctl snapshot save /opt/backup/etcd.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
etcdctl snapshot status /opt/backup/etcd.db -w table

# ---- 阶段 2：制造"事故" ----
kubectl create deploy disaster --image=nginx --replicas=3
kubectl get deploy    # 记住现在有 disaster

# ---- 阶段 3：恢复 ----
etcdctl snapshot restore /opt/backup/etcd.db --data-dir=/var/lib/etcd-restore

# 停 kubelet（避免它重建 etcd）
systemctl stop kubelet
# 替换数据目录
mv /var/lib/etcd /var/lib/etcd.bak
mv /var/lib/etcd-restore /var/lib/etcd
systemctl start kubelet

# ---- 阶段 4：验证 ----
sleep 30
kubectl get deploy    # disaster 应该消失了（回到备份时刻的状态）
kubectl get nodes
```

> ⚠️ **关键点**：恢复后 `disaster` deployment **不存在了**，因为备份是在它创建之前。这就是"恢复到备份时刻"的含义——也是验证恢复成功的标志。

#### 实验 3：制造并修复 apiserver 故障（20 分钟）

```bash
# 1. 改坏 /etc/kubernetes/manifests/kube-apiserver.yaml 的某个参数
#    比如把 --etcd-servers 的端口改错
cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/apiserver.bak
sed -i 's|--etcd-servers=https://127.0.0.1:2379|--etcd-servers=https://127.0.0.1:9999|' \
  /etc/kubernetes/manifests/kube-apiserver.yaml

# 2. 等 30s，kubectl 应该连不上了
kubectl get nodes    # 报 connection refused

# 3. 用 crictl 看容器状态（kubectl 不可用时唯一工具）
crictl ps -a | grep apiserver
crictl logs <apiserver-container-id>

# 4. 修复
cp /tmp/apiserver.bak /etc/kubernetes/manifests/kube-apiserver.yaml
sleep 30
kubectl get nodes
```

#### 实验 4：节点维护（15 分钟）

```bash
# 场景：worker1 需要换内存，要安全下线
kubectl drain worker1 --ignore-daemonsets --delete-emptydir-data
kubectl get pods -A -o wide | grep worker1   # 应该只剩 DaemonSet
kubectl get nodes                            # worker1 是 SchedulingDisabled

# 维护完成后
kubectl uncordon worker1
```

#### 实验 5（可选）：升级演练

在快照/备份 VM 上做一次小版本升级（如 1.28.x → 1.29.x），完整走一遍流程。这对理解命令顺序很有帮助，但不是必须。

---

## 四、本周必练命令

```bash
# kubeadm
kubeadm init --config=...
kubeadm token create --print-join-command
kubeadm token list
kubeadm join <endpoint> --token <t> --discovery-token-ca-cert-hash sha256:<h>
kubeadm upgrade plan
kubeadm upgrade apply v1.xx.x
kubeadm upgrade node
kubeadm reset -f
kubeadm certs check-expiration
kubeadm certs renew all

# etcd
export ETCDCTL_API=3
etcdctl snapshot save <path> --endpoints= --cacert= --cert= --key=
etcdctl snapshot status <path> --write-out=table
etcdctl snapshot restore <path> --data-dir=<newdir>
etcdctl member list --endpoints= --cacert= --cert= --key=
etcdctl endpoint health --endpoints= --cacert= --cert= --key=

# 节点
kubectl drain <n> --ignore-daemonsets --delete-emptydir-data
kubectl cordon <n>
kubectl uncordon <n>
kubectl delete node <n>

# kubeconfig
kubectl config get-contexts
kubectl config use-context <c>
kubectl config set-context --current --namespace=<ns>
kubectl config view

# 容器运行时（apiserver 挂时唯一工具）
crictl ps -a
crictl logs <id>
crictl pods
crictl images

# systemd
systemctl status kubelet
journalctl -u kubelet -f --no-pager
journalctl -u containerd -n 100
```

---

## 五、验收标准

- [ ] 能在 **5 分钟内**不看文档完成 etcd 备份（含证书路径）
- [ ] 能从备份恢复集群并**验证恢复成功**（说明为什么某个对象消失了）
- [ ] 能说出 etcd 证书的 4 个路径
- [ ] 能解释为什么"改静态 Pod manifest 会自动生效"（kubelet 监听文件变化）
- [ ] 能说出升级的正确顺序，知道 `upgrade apply` 与 `upgrade node` 的区别
- [ ] 能解释 `drain` / `cordon` / `uncordon` 三者关系
- [ ] 知道 apiserver 挂掉时用什么命令查问题（crictl）
- [ ] 能手写 `kubeadm token create --print-join-command` 并说明 token 有效期

---

## 六、自测题

1. `kubeadm init` 生成的东西分别在哪些目录？静态 Pod 清单在哪个目录？
2. apiserver 起不来，`kubectl` 完全不可用，你怎么排查？用什么命令？
3. etcd 恢复时 `--data-dir` 能不能指向已存在的非空目录？为什么？
4. 为什么恢复 etcd 后，最近创建的 Deployment 会消失？
5. `kubeadm upgrade apply` 和 `kubeadm upgrade node` 分别在哪个节点上用？
6. `kubectl drain` 时容器使用 `emptyDir` 会报错，怎么解决？这个参数意味着什么风险？
7. 证书续期后为什么必须重启 apiserver？怎么让它重启？
8. `--ignore-daemonsets` 如果加在 `drain` 里，DaemonSet 的 Pod 会被删吗？
9. 一个节点 `NotReady`，你会按什么顺序排查？（kubelet → containerd → 网络 → 资源）

---

## 七、踩坑记录

| 现象 | 原因 | 解决 |
|------|------|------|
| | | |

---

## 八、复盘区

**etcd 备份命令（默写，含 4 个证书参数）**

```bash
# 写在这里，直到能盲写

```

**etcd 恢复完整步骤（默写）**

1.
2.
3.
4.

**升级顺序（默写）**

1.
2.
3.
4.
5.
6.

**本周用时统计**

| 天 | 计划 | 实际 |
|----|------|------|
| D1 | 2h | |
| D2 | 1.5h | |
| D3 | 2h | |
| D4 | 1.5h | |
| D5 | 1.5h | |
| D6 | 3h | |
| D7 | 2h | |

**一句话总结本周**

>

---

*[← 上一周：Week5-存储与RBAC](Week5-存储与RBAC.md) ｜ [返回索引](README.md) ｜ [下一周：Week7-故障排查 →](Week7-故障排查.md)*