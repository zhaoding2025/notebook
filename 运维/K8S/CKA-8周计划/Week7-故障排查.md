# Week 7｜Troubleshooting 故障排查（30%，最拉开差距）

> **本周时长**：12~14 小时（本周最重要，可以多投入）
> **本周定位**：考纲最大模块（30%）。这一周不做新知识，只做**方法论 + 大量演练**。
> **上一周**：[Week6-集群运维.md](Week6-集群运维.md) ｜ **下一周**：[Week8-模拟冲刺.md](Week8-模拟冲刺.md)

---

## 一、本周目标

- [ ] 建立自己的**固定排障流程**（不靠灵感，靠 checklist）
- [ ] 能快速识别并修复 7 种 Pod 异常状态
- [ ] 能排查 Node NotReady（kubelet / 运行时 / 资源 / 网络）
- [ ] 能排查控制平面组件故障（apiserver / etcd / scheduler）
- [ ] 能排查网络问题（DNS / Endpoints / NetworkPolicy）
- [ ] **给定一个坏掉的集群或资源，15 分钟内定位并修复**

---

## 二、排障方法论（先建立流程，再练手）

### 万能四步法

```
① 划定范围：是单个 Pod？一个 Deployment？一个节点？还是整个集群？
     ↓
② 看状态：kubectl get 看 STATUS / READY / RESTARTS / AGE
     ↓
③ 看事件：kubectl describe → 翻到最下面的 Events（90% 的答案在这）
     ↓
④ 看日志：kubectl logs（应用层）/ journalctl（系统层）/ crictl（运行时层）
```

### 分层次排查（自下而上）

| 层 | 工具 | 查什么 |
|----|------|--------|
| 集群层 | `kubectl get componentstatuses` / `kubectl get --raw /healthz` | 控制平面是否健康 |
| 节点层 | `kubectl get nodes` / `describe node` / `journalctl -u kubelet` | 节点是否 Ready、有无资源压力 |
| 调度层 | `describe pod` 的 Events / 被 taint 掉的节点 | 为什么没被调度 |
| Pod 层 | `get pod` / `describe pod` / `logs` | 容器为什么不跑 |
| 网络层 | `get endpoints` / `nslookup` / CNI Pod 状态 | 为什么访问不通 |
| 存储层 | `get pv,pvc` / `describe pvc` | 为什么挂不上盘 |

### 三个「第一站」工具

```bash
kubectl get pods -A -o wide | grep -v Running       # 一眼找出异常
kubectl get events -A --sort-by=.lastTimestamp       # 全局最近发生了什么
kubectl describe <res> <name>                        # 单个资源的完整现场
```

---

## 三、逐日安排

### D1｜Pod 异常状态全解（⭐核心）

**七种状态对照表**

| 状态 | 直接原因 | 排查命令 | 典型修复 |
|------|---------|---------|---------|
| `Pending` | 没找到可调度节点 / 镜像在拉 | `describe pod` → Events | 查资源、污点、亲和性、PVC、配额 |
| `ContainerCreating` | 卡在挂卷 / 拉镜像 / CNI | `describe pod` → Events | 查 PVC、Secret、CNI |
| `ImagePullBackOff` / `ErrImagePull` | 镜像名错 / 私有仓库无凭据 / 网络不通 | `describe pod` → Events | 改镜像名、加 `imagePullSecrets` |
| `CrashLoopBackOff` | 容器启动后立即退出 | `logs --previous` | 修启动命令、配置、依赖 |
| `RunContainerError` | 容器无法创建 | `describe pod` | 命令不存在、权限、挂载问题 |
| `OOMKilled` | 超过 memory limit 被内核杀 | `describe pod` → Last State | 调大 limits 或修内存泄漏 |
| `CreateContainerConfigError` | 引用不存在的 CM/Secret | `describe pod` | 创建缺失的 CM/Secret，改 key 名 |
| `Error` / `Completed` | 正常结束（Job）或异常退出 | `get pod` | Job 场景 Completed 是正常的 |
| `Terminating` 卡住 | finalizer / 节点失联 / 卷卸载 | `describe pod` | 加 `--force --grace-period=0`，查明 finalizer |

**逐条演练脚本（自己动手造，再修）**

```bash
# ① Pending：资源请求过大
k run p1 --image=nginx --overrides='{"spec":{"containers":[{"name":"c","image":"nginx","resources":{"requests":{"memory":"100Gi"}}}]}}'
k describe pod p1 | tail -20

# ② ImagePullBackOff：镜像名错
k run p2 --image=nginx:doesnotexist
k describe pod p2 | tail -20

# ③ CrashLoopBackOff：命令立即退出
k run p3 --image=busybox -- sh -c 'echo fail; exit 1'
k logs p3 --previous
k describe pod p3 | grep -A8 'Last State'

# ④ CreateContainerConfigError：CM 不存在
k run p4 --image=nginx --overrides='{"spec":{"containers":[{"name":"c","image":"nginx","env":[{"name":"X","valueFrom":{"configMapKeyRef":{"name":"no-such-cm","key":"k"}}}]}]}}'
k describe pod p4 | tail -10

# ⑤ OOMKilled：内存限制过小
k run p5 --image=polinux/stress --overrides='{"spec":{"containers":[{"name":"c","image":"polinux/stress","command":["stress","--vm","1","--vm-bytes","200M","--vm-hang","1"],"resources":{"limits":{"memory":"50Mi"}}}]}}'
k get pod p5    # 观察 OOMKilled / CrashLoopBackOff
k describe pod p5 | grep -A6 'Last State'

# ⑥ Pending：PVC 未绑定
cat > /tmp/p6.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: p6}
spec:
  containers: [{name: c, image: nginx}]
  volumes: [{name: v, persistentVolumeClaim: {claimName: no-such-pvc}}]
EOF
k apply -f /tmp/p6.yaml
k describe pod p6 | tail -10
```

> 🔑 **每个 Pending 的 Pod，`describe` 最后的 Events 一定会写原因**（`FailedScheduling ... 0/3 nodes are available: 3 Insufficient memory`）。**学会读这句话**，考试就赢一半。

**FailedScheduling 常见事件文本对照**

| 事件文本 | 含义 |
|---------|------|
| `Insufficient cpu/memory` | 资源不够 |
| `node(s) had untolerated taint` | 有污点没容忍 |
| `node(s) didn't match Pod's node affinity/selector` | 亲和性/选择器不匹配 |
| `node(s) were unschedulable` | 节点被 cordon |
| `pod has unbound immediate PersistentVolumeClaims` | PVC 未绑定 |
| `node(s) didn't match pod anti-affinity rules` | 反亲和冲突 |

---

### D2｜容器日志与 exec 调试

**日志三件套**

```bash
kubectl logs <pod>                      # 单容器
kubectl logs <pod> -c <container>       # 多容器指定
kubectl logs <pod> --previous           # 上一次崩溃的容器（CrashLoop 必用）
kubectl logs <pod> -f                   # 实时跟随
kubectl logs <pod> --tail=50
kubectl logs <pod> --since=1h
kubectl logs -l app=web --all-containers=true   # 按标签批量
```

**exec 走不进去怎么办**

| 现象 | 解决 |
|------|------|
| `executable file not found` | 镜像里没有 `bash`/`sh`，换 `sh` 或 `busybox` |
| 容器是 `distroless` | 无法 exec，改用 `kubectl debug` |
| 容器已退出 | 无法 exec，改为看 logs 或 `kubectl debug --copy-to` |

**kubectl debug（现代排障利器）**

```bash
# 给运行中的 Pod 加临时调试容器（共享网络命名空间）
kubectl debug -it <pod> --image=busybox:1.36 --target=<原容器名>

# 复制 Pod 并改造（可以改命令、加容器）
kubectl debug <pod> --copy-to=<pod>-debug --container=<c> --image=busybox -- sh

# 在节点上起一个特权 Pod 排查节点问题（节点排障神器）
kubectl debug node/<node-name> -it --image=busybox
# 会挂载宿主机根文件系统到 /host
```

---

### D3｜节点 NotReady 排查（⭐）

**排查顺序（自下而上）**

```
1. 宿主机：磁盘满？内存耗尽？CPU 打满？时间不同步？
2. 容器运行时：containerd 在跑吗？
3. kubelet：在跑吗？报什么错？
4. 网络：kubelet 能连上 apiserver 吗？CNI Pod 正常吗？
5. 证书：kubelet 客户端证书过期了吗？
```

**命令清单**

```bash
# ① 节点状态与原因
kubectl get nodes
kubectl describe node <node> | grep -A15 Conditions
# 关注：Ready / MemoryPressure / DiskPressure / PIDPressure / NetworkUnavailable

# ② 登录节点后
systemctl status kubelet
systemctl status containerd
journalctl -u kubelet -n 100 --no-pager
journalctl -u kubelet -f --no-pager        # 实时看

df -h                     # 磁盘
free -m                   # 内存
top                       # CPU
systemctl status chronyd  # 时间同步（证书校验依赖）

# ③ 网络与 apiserver 连通性
curl -k https://<apiserver>:6443/healthz
ss -tlnp | grep 10250      # kubelet 端口
ls /etc/cni/net.d/         # CNI 配置
crictl ps | grep -E 'calico|cilium|flannel'

# ④ 证书
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates
```

**常见 NotReady 原因与修复**

| journalctl 里的关键错误 | 原因 | 修复 |
|-------------------------|------|------|
| `failed to run Kubelet: misconfiguration: kubelet cgroup driver: "cgroupfs" is different from docker cgroup driver: "systemd"` | cgroup driver 不一致 | 改 containerd 配置 `SystemdCgroup = true`，重启 |
| `Unable to register node ... x509: certificate has expired` | kubelet 客户端证书过期 | `kubeadm certs renew` 或删除 `/var/lib/kubelet/pki/*` 后重启 |
| `failed to get node info ... connection refused` | apiserver 不可达 | 查 apiserver / kube-proxy / 网络 |
| `The node was low on resource: nodefs` | 磁盘压力 | 清理镜像 `crictl rmi --prune`，删日志 |
| `Failed to create pod sandbox ... network plugin is not ready` | CNI 未就绪 | 检查 CNI Pod 与 `/etc/cni/net.d` |
| `PLEG is not healthy` | 运行时卡住 | 重启 containerd → kubelet |
| `failed to load kubelet config` | kubelet 配置写错 | 查 `/var/lib/kubelet/config.yaml` |

**磁盘满的急救**

```bash
crictl rmi --prune                        # 清未使用镜像
journalctl --vacuum-size=200M             # 清 journal
du -sh /var/lib/containerd/*              # 找占用
find /var/log -name "*.log" -size +100M   # 找大日志
```

---

### D4｜控制平面故障

**症状与定位**

| 症状 | 可能原因 | 检查 |
|------|---------|------|
| `kubectl` 连接超时 / refused | apiserver 挂了 | `crictl ps -a \| grep apiserver`，`crictl logs` |
| apiserver 起来又立刻退出 | manifest 参数错误 / 证书路径错 / etcd 不可达 | `crictl logs <apiserver>` |
| `kubectl get` 卡住不动 | etcd 慢/不健康 | `etcdctl endpoint health` |
| Pod 一直 Pending 但节点正常 | scheduler 挂了 | `crictl ps \| grep scheduler` |
| Deployment 创建了但没有 RS/Pod | controller-manager 挂了 | `crictl ps \| grep controller-manager` |
| `kube-proxy` 相关 Service 不通 | kube-proxy Pod 异常 | `get pod -n kube-system` |

**核心认知**

> 控制平面组件是**静态 Pod**，kubelet 读 `/etc/kubernetes/manifests/` 自动拉起。
> 所以修复方式通常是：**改那个 yaml** → kubelet 自动重建。
> 如果 kubelet 本身挂了，那就什么都起不来 → 先修 kubelet。

**演练：制造各组件故障**

```bash
# ---- ① apiserver 故障 ----
cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
# 故意改错 --etcd-servers 端口
sed -i 's/2379/9999/' /etc/kubernetes/manifests/kube-apiserver.yaml
sleep 30
crictl ps -a | grep apiserver         # 容器在重启循环
crictl logs <id>                      # 看到连接 etcd 失败
# 修复
cp /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

# ---- ② scheduler 故障 ----
# 把 kube-scheduler.yaml 里的 --kubeconfig 路径改错
# 现象：新建 Pod 一直 Pending，Events 里没有 FailedScheduling（因为根本没调度器接管）

# ---- ③ controller-manager 故障 ----
# 现象：kubectl create deploy 后，deployment 存在但没有 replicaset

# ---- ④ etcd 故障 ----
cd /etc/kubernetes/manifests
mv etcd.yaml /tmp/          # etcd Pod 消失
sleep 20
kubectl get nodes            # 应该报错或超时
mv /tmp/etcd.yaml .
```

> 💡 **观察技巧**：`kubectl get pods -n kube-system -o wide` 里，静态 Pod 的名字是 `组件名-节点名`。它们状态变化很快，用 `-w` 观察。

---

### D5｜网络故障

**症状树**

```
访问不通
  ├─ Service ClusterIP 访问不通
  │    ├─ Endpoints 为空  → 查 selector / Pod Ready / namespace
  │    ├─ targetPort 错    → 查容器实际监听端口
  │    └─ kube-proxy 异常 → 查 kube-system 里 kube-proxy Pod
  ├─ 域名解析失败
  │    ├─ CoreDNS Pod 挂了
  │    ├─ /etc/resolv.conf 的 nameserver 不对
  │    └─ NetworkPolicy 拦了 53 端口（Egress 场景）
  ├─ 跨节点 Pod 不通
  │    ├─ CNI Pod 异常
  │    └─ 节点间路由/防火墙
  └─ 被 NetworkPolicy 拦了
       └─ kubectl get netpol -n <ns> 看有没有 policy 选中目标 Pod
```

**排查命令流**

```bash
# 1. Service 层面
k get svc <svc> -o wide
k get endpoints <svc>
k get endpointslices -l kubernetes.io/service-name=<svc>

# 2. Pod 端口
k exec -it <pod> -- ss -tlnp          # 或 netstat
k get pod <pod> -o yaml | grep -A5 'containerPort'

# 3. DNS
k exec -it <pod> -- cat /etc/resolv.conf
k exec -it <pod> -- nslookup <svc>.<ns>.svc.cluster.local
k get svc -n kube-system kube-dns
k logs -n kube-system -l k8s-app=kube-dns --tail=50

# 4. kube-proxy
k get pod -n kube-system -l k8s-app=kube-proxy
k logs -n kube-system -l k8s-app=kube-proxy --tail=50

# 5. NetworkPolicy
k get networkpolicy -A
k describe networkpolicy <n> -n <ns>
# 临时删掉验证是不是 policy 问题：
k delete netpol <n> -n <ns> && k exec ... && k apply -f back

# 6. CNI
k get pod -n kube-system | grep -E 'calico|cilium|flannel'
```

---

### D6-D7｜综合演练（周末，重点是模拟考试节奏）

#### 演练 1：修复 10 个坏掉的对象（自建题库）

自己制造，自己修，**每个计时**：

```bash
# ---- 故障 1：Deployment 镜像写错 ----
k create deploy f1 --image=nginx --replicas=2
k set image deploy/f1 nginx=nginx:1.99-nonexist
# 修：改成正确镜像，观察 rollout

# ---- 故障 2：Service selector 写错 ----
k create deploy f2 --image=nginx
k expose deploy f2 --port=80 --name=f2-svc
k patch svc f2-svc -p '{"spec":{"selector":{"app":"wrong"}}}'
# 修：改回正确 selector，验证 endpoints 有值

# ---- 故障 3：节点打了不该打的污点 ----
k taint node <node> broken=true:NoSchedule
# 修：删掉污点，观察 Pending Pod 起飞

# ---- 故障 4：PVC 与 PV 的 storageClassName 不一致 ----
# 修：改动其中一个，验证 Bound

# ---- 故障 5：RBAC 授权给了错误的 namespace ----
# 修：在正确的 ns 建 RoleBinding

# ---- 故障 6：Static Pod manifest 写坏了 ----
# 修：改回

# ---- 故障 7：NetworkPolicy 拦了 DNS ----
# 修：加 53 端口放行

# ---- 故障 8：kubelet 配置文件被改坏（cgroupDriver）----
# 修：改回 systemd，重启 kubelet

# ---- 故障 9：Deployment 的 maxUnavailable 写成 100%，导致全删 ----
# 修：改回合理值

# ---- 故障 10：Secret key 名与引用不一致 ----
# 修：改 key 名或改引用
```

#### 演练 2：完整事故复盘（30 分钟）

**场景**：早上发现 `prod` namespace 全部业务不可用。要求：
1. 找出所有异常资源
2. 定位根因（可能只有一个，如节点 NotReady 导致的连锁反应）
3. 修复并验证
4. 写出时间线

**自己先造一个这样的场景**（比如 cordon 一个跑着所有副本的节点 + 删掉对应 PVC），然后走一遍。

#### 演练 3：盲修训练（重要）

让同学/同事随机改坏你的集群一处，你在**不看文档**的情况下 15 分钟修好。这个训练比刷 10 遍模拟题都有用。

---

## 四、本周必练命令（排障专用）

```bash
# 全局扫描
kubectl get pods -A -o wide | grep -vE 'Running|Completed'
kubectl get events -A --sort-by=.lastTimestamp --field-selector type=Warning
kubectl get pod -o wide --sort-by=.status.startTime

# 单个资源现场
kubectl describe pod/node/svc/pvc <n>
kubectl get pod <n> -o yaml
kubectl get pod <n> -o jsonpath='{.status.conditions[*].message}'

# 日志
kubectl logs <p> [-c c] [--previous] [-f] [--tail=100] [--since=10m]
kubectl logs -l app=x --all-containers=true --prefix

# 调试容器
kubectl debug -it <p> --image=busybox --target=<c>
kubectl debug node/<n> -it --image=busybox

# 节点侧
journalctl -u kubelet -n 100 --no-pager
journalctl -u kubelet -f | grep -iE 'error|fail'
systemctl status kubelet containerd
crictl ps -a
crictl logs <id>
crictl rmi --prune
df -h; free -m; top -bn1 | head -20

# 运行时/集群状态
kubectl get --raw='/healthz'
kubectl get --raw='/readyz'
kubectl get componentstatuses
kubectl get pods -n kube-system -o wide

# 强制删除
kubectl delete pod <n> --force --grace-period=0
kubectl patch pod <n> -p '{"metadata":{"finalizers":null}}' --type=merge
```

---

## 五、验收标准

- [ ] 看到任意 Pod 异常状态，能在 3 分钟内说出「下一步做什么」
- [ ] 能默写出 `FailedScheduling` 5 种常见原因
- [ ] 能解释 `CrashLoopBackOff` 为什么要用 `logs --previous`
- [ ] 节点 NotReady 时，能按固定顺序排查（宿主机 → 运行时 → kubelet → 网络 → 证书）
- [ ] apiserver 挂掉时知道用 `crictl` 而不是 `kubectl`
- [ ] 能在 10 分钟内排查「Service 访问不通」
- [ ] 每周演练的 10 个故障，全部能独立修复
- [ ] 关键：**15 分钟内修好一个陌生故障**

---

## 六、自测题

1. `Pending` 和 `ContainerCreating` 的区别是什么？各查什么？
2. `CrashLoopBackOff` 的 `RESTARTS` 从 1 涨到 5，中间等待时间怎么变化的？（提示：指数退避，最长 5 分钟）
3. 一个 Pod `CreateContainerConfigError`，如何最快找到缺少的 key 名？
4. `describe node` 里 `Ready` 条件是 `False`，`Reason` 是 `KubeletNotReady`，下一步查什么？
5. apiserver 挂掉，`kubectl get nodes` 报 `connection refused`，第一步做什么？
6. 集群里所有新 Pod 都 Pending 且没有任何 Events 里的 `FailedScheduling`，最可能是什么组件挂了？
7. `Service` 的 `Endpoints` 有值但访问还是不通，可能是什么原因？（至少 3 个）
8. 一个 Pod `Terminating` 了 10 分钟还在，如何处理？处理后有什么风险？
9. `crictl` 与 `nerdctl` 与 `kubectl` 分别在哪一层？什么场景用哪个？

---

## 七、踩坑记录

| 现象 | 原因 | 解决 |
|------|------|------|
| | | |

---

## 八、复盘区

### 我的排障 Checklist（自己写，考前只看这个）

**Pod 不 Running**

1.
2.
3.
4.

**节点 NotReady**

1.
2.
3.
4.
5.

**Service 不通**

1.
2.
3.
4.

**控制平面异常**

1.
2.
3.

### 10 个故障演练记录

| # | 故障 | 找到原因用时 | 修复用时 | 卡在哪 |
|---|------|-------------|---------|--------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |
| 7 | | | | |
| 8 | | | | |
| 9 | | | | |
| 10 | | | | |

**本周用时统计**

| 天 | 计划 | 实际 |
|----|------|------|
| D1 | 2h | |
| D2 | 1.5h | |
| D3 | 2h | |
| D4 | 2h | |
| D5 | 1.5h | |
| D6 | 3h | |
| D7 | 3h | |

**一句话总结本周**

>

---

*[← 上一周：Week6-集群运维](Week6-集群运维.md) ｜ [返回索引](README.md) ｜ [下一周：Week8-模拟冲刺 →](Week8-模拟冲刺.md)*