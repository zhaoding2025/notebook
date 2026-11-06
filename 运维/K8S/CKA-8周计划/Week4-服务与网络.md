# Week 4｜Services & Networking（20%，高频）

> **本周时长**：10~12 小时
> **本周定位**：网络是考纲第三大模块。Service 与 NetworkPolicy 几乎必考。
> **上一周**：[Week3-调度与亲和性.md](Week3-调度与亲和性.md) ｜ **下一周**：[Week5-存储与RBAC.md](Week5-存储与RBAC.md)

---

## 一、本周目标

- [ ] 讲清 K8s 网络模型：为什么 Pod 之间不用 NAT
- [ ] 四种 Service 类型都会创建，能说出各自适用场景
- [ ] 会排查 **Endpoints 为空** 的问题（高频排障点）
- [ ] CoreDNS 域名格式背下来，能用 `nslookup` 验证
- [ ] **能独立写出 NetworkPolicy**：默认拒绝 + 白名单（高频）
- [ ] 会用 Ingress 暴露 HTTP 服务（path/host 路由）
- [ ] 3 分钟内完成：暴露 Deployment → 验证 → 排查不可访问

---

## 二、知识主线

```
       外部用户
          │
    ┌─────▼──────┐
    │  Ingress   │  七层 HTTP 路由（需要 Ingress Controller）
    └─────┬──────┘
          │
    ┌─────▼──────┐
    │  Service   │  四层（TCP/UDP）负载均衡 + 固定虚拟 IP
    └─────┬──────┘
          │  通过 selector 选中
    ┌─────▼──────┐
    │ Endpoints  │  实际 Pod IP 列表
    └─────┬──────┘
          │
    ┌─────▼──────┐
    │    Pod     │
    └────────────┘
```

---

## 三、逐日安排

### D1｜Service 四种类型

| 类型 | 作用 | 访问方式 |
|------|------|---------|
| `ClusterIP`（默认） | 集群内虚拟 IP | 仅集群内访问 |
| `NodePort` | 在每个节点开一个端口（30000-32767） | `<节点IP>:<NodePort>` |
| `LoadBalancer` | 云厂商 LB（裸机需 MetalLB） | 外部 IP |
| `ExternalName` | 把 Service 映射成外部 CNAME | 无 ClusterIP，只做 DNS 转发 |

**任务**

```bash
# 准备后端
k create deploy nginx --image=nginx --replicas=3
k expose deploy nginx --port=80 --target-port=80

# 四种类型
k expose deploy nginx --name=nginx-np --port=80 --target-port=80 --type=NodePort
k create service nodeport np-manual --tcp=8080:80 --node-port=30080   # 指定端口

# ExternalName（考试可能考）
k create service externalname ext-svc --external-name=example.com

# 查看
k get svc
k get endpoints nginx
k get endpointslices
k describe svc nginx
```

**yaml 模板**

```yaml
apiVersion: v1
kind: Service
metadata: {name: nginx-svc}
spec:
  type: NodePort
  selector: {app: nginx}
  ports:
  - name: http
    port: 80            # Service 自己的端口（集群内访问用）
    targetPort: 8080    # 容器端口
    nodePort: 30080     # 节点端口（30000-32767，可选）
    protocol: TCP
```

> ⚠️ **三个 port 别混**：
> - `port`：Service 的端口，集群内通过 `<svc>:<port>` 访问
> - `targetPort`：**Pod 容器监听的端口**
> - `nodePort`：宿主机暴露的端口

**无 selector 的 Service + 手动 Endpoints（考点）**

用于把集群外的服务"伪装"成集群内服务（如外部数据库）：

```yaml
apiVersion: v1
kind: Service
metadata: {name: external-db}
spec:
  ports: [{port: 3306, targetPort: 3306}]
  # 注意：没有 selector！
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-db        # 名字必须与 Service 同名
subsets:
- addresses:
  - ip: 10.0.0.50          # 外部数据库 IP
  ports: [{port: 3306}]
```

---

### D2｜Endpoints 与排查（高频排障点）

**核心机制**

Service 并不是"转发到自己身上"，而是：
1. Service 通过 `selector` 找到匹配的 Pod
2. 把 Pod IP + 容器端口写进 **Endpoints** 对象
3. kube-proxy 监听 Endpoints 变化，更新节点上的 iptables/IPVS 规则

**所以 Endpoints 为空 = Service 一定不通。**

**排查 5 步法**

```bash
# 1. 看 Endpoints 是否有值
k get endpoints <svc>
# NAME    ENDPOINTS                     AGE
# nginx   10.244.1.5:80,10.244.2.6:80   5m     ← 正常
# nginx   <none>                        5m     ← 有问题！

# 2. 如果为空，比对 selector 与 Pod 标签
k get svc <svc> -o yaml | grep -A3 selector
k get pods --show-labels

# 3. 如果标签匹配了但还没 Endpoints，检查 Pod 是否 Ready
k get pods -o wide
k describe pod <p> | grep -A10 'Conditions'
# ⚠️ 关键：Pod 不 Ready 不会被加入 Endpoints！

# 4. 检查 targetPort 是否与容器实际监听端口一致
k exec -it <pod> -- netstat -tlnp    # 或 ss -tlnp

# 5. 集群 DNS 是否正常
k run test --image=busybox --rm -it --restart=Never -- nslookup nginx
```

**三个最常见的 Endpoints 为空原因**

| 原因 | 检查方法 |
|------|---------|
| selector 与 Pod label 不匹配 | `k get svc -o yaml \| grep selector` vs `k get po --show-labels` |
| Pod 未 Ready（readinessProbe 失败） | `k get po` 看 READY 列（`0/1` 就是没 Ready） |
| Pod 在另一个 namespace | Service 只能选同 namespace 的 Pod |

---

### D3｜CoreDNS 与 DNS 解析

**域名格式（背下来）**

```
<service>.<namespace>.svc.cluster.local
```

简化规则（同一 namespace 内可省）：

```
# 同一 namespace
nginx
# 跨 namespace
nginx.default
# 完整 FQDN
nginx.default.svc.cluster.local
```

**Pod 的 DNS 配置**

```bash
k exec -it <pod> -- cat /etc/resolv.conf
# nameserver 10.96.0.10
# search <ns>.svc.cluster.local svc.cluster.local cluster.local
# options ndots:5
```

`search` 域 + `ndots:5` 是 `nginx` 能被解析成 `nginx.<ns>.svc.cluster.local` 的原因。

**任务**

```bash
# 1. 用临时 Pod 测试 DNS
k run dns-test --image=busybox:1.36 --rm -it --restart=Never -- sh
# 容器内：
# nslookup kubernetes.default
# nslookup nginx.default
# nslookup nginx.default.svc.cluster.local
# cat /etc/resolv.conf

# 2. 查看 CoreDNS
k get pods -n kube-system -l k8s-app=kube-dns
k logs -n kube-system -l k8s-app=kube-dns
k get cm coredns -n kube-system -o yaml

# 3. 服务发现验证
k run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://nginx.default.svc.cluster.local
```

> 💡 **考试提示**：DNS 排障题常给一个"解析失败"的 Pod。先看 `/etc/resolv.conf` 的 nameserver 是否为 CoreDNS Service IP（`k get svc -n kube-system kube-dns`），再看 CoreDNS Pod 是否在跑。

---

### D4｜NetworkPolicy（⭐⭐高频）

**核心概念**

- K8s 默认**所有 Pod 之间可以自由通信**（无限制）
- NetworkPolicy 是**白名单**机制：一旦某个 Pod 被任何 NetworkPolicy 选中，它就对**被限制的方向**变成"默认拒绝"

> ⚠️⚠️ **最重要的一句话**：
> **NetworkPolicy 只是声明，必须 CNI 支持才生效。**
> Calico / Cilium 支持；**Flannel 不支持**（写了也没用）。
> 考试环境一般是 Calico，能用。

**关键语义（易错）**

| 情况 | 结果 |
|------|------|
| Pod 无任何 NetworkPolicy 选中 | 全部允许 |
| Pod 被 policy 选中，policy 有 `Ingress` 规则 | 只有规则允许的入站，其他**全部拒绝** |
| Pod 被 policy 选中，policy **只有** `Ingress` 段 | **出站仍然全部允许**（各方向独立） |
| Pod 被 policy 选中，policy 的 `podSelector: {}` + `policyTypes: [Ingress, Egress]` + 无规则 | 完全隔离（默认拒绝） |

**模板 1：默认拒绝所有入站**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: prod
spec:
  podSelector: {}          # 空 = 选中本 ns 所有 Pod
  policyTypes:
  - Ingress
  # 没有 ingress 规则 = 全部拒绝
```

**模板 2：只允许特定来源访问**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-web-to-db, namespace: prod}
spec:
  podSelector:
    matchLabels: {app: db}            # 作用于 db Pod
  policyTypes: [Ingress]
  ingress:
  - from:
    # ① 同 ns 内 app=web 的 Pod
    - podSelector:
        matchLabels: {app: web}
    # ② 其他 ns 中 env=prod 的 Pod
    - namespaceSelector:
        matchLabels: {env: prod}
      podSelector:
        matchLabels: {app: web}
    # ③ 某个 CIDR
    - ipBlock:
        cidr: 172.17.0.0/16
        except: [172.17.1.0/24]
    ports:
    - protocol: TCP
      port: 3306
```

**⚠️ 最容易错的点：`namespaceSelector` 和 `podSelector` 在同一个 list item 里是 AND，分开写是 OR**

```yaml
    from:
    # 这个 = 「prod namespace 里 且 app=web」→ AND
    - namespaceSelector: {matchLabels: {env: prod}}
      podSelector: {matchLabels: {app: web}}

    # 这个 = 「prod namespace 里的任意 Pod」 或者 「本 ns 的 app=web」→ OR
    - namespaceSelector: {matchLabels: {env: prod}}
    - podSelector: {matchLabels: {app: web}}
```

**模板 3：出站限制**

```yaml
spec:
  podSelector: {matchLabels: {app: web}}
  policyTypes: [Egress]
  egress:
  - to:
    - podSelector: {matchLabels: {app: db}}
    ports: [{protocol: TCP, port: 3306}]
  - to:                                  # 必须放行 DNS，否则解析全挂
    - namespaceSelector:
        matchLabels: {kubernetes.io/metadata.name: kube-system}
    ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
```

> 🔑 **一旦配了 Egress 限制，必须显式放行 DNS（53 端口），否则 Pod 内所有域名解析都会失败。** 这是考试和生产的经典坑。

**任务**

```bash
# 1. 建两个 ns + 三组 Pod
k create ns prod; k create ns dev

# 2. 在 prod 里建 db（label app=db）和 web（label app=web）
k run db --image=nginx --labels=app=db -n prod
k expose pod db --port=80 -n prod
k run web --image=busybox --labels=app=web -n prod -- sleep 3600
k run other --image=busybox --labels=app=other -n prod -- sleep 3600

# 3. 应用 policy 前：都能访问
k exec web -n prod -- wget -qO- --timeout=2 db
k exec other -n prod -- wget -qO- --timeout=2 db   # 也能通

# 4. 应用 allow-web-to-db
k apply -f policy.yaml
sleep 5
k exec web -n prod -- wget -qO- --timeout=2 db     # 通
k exec other -n prod -- wget -qO- --timeout=2 db   # 超时（被拒）

# 5. 应用 default-deny-ingress 后再测
```

---

### D5｜Ingress

**前提**：必须有 Ingress Controller（如 ingress-nginx），否则 Ingress 资源只是"一堆配置"，没人执行。

```bash
# kind 安装 ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 等就绪
k wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=120s
```

**Ingress 模板（path 路由 + host 路由）**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: nginx-svc
            port: {number: 80}
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port: {number: 8080}
```

**带 TLS 的 Ingress**

```yaml
spec:
  tls:
  - hosts: [app.example.com]
    secretName: my-tls          # 用 k create secret tls 创建
  rules:
  - host: app.example.com
    ...
```

**任务**

```bash
# 命令生成
k create ingress demo --rule="/web=nginx-svc:80" \
  --class=nginx --dry-run=client -o yaml

# 验证
k get ingress
k describe ingress demo
k get ingress demo -o yaml | grep -A2 'status:'

# 实际访问（kind 里用端口映射或 curl 到 controller）
k get pods -n ingress-nginx
k port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 &
curl -H "Host: app.example.com" http://localhost:8080/web
```

**`pathType` 三种**

| 值 | 含义 |
|----|------|
| `Prefix` | 路径前缀匹配 `/web` 匹配 `/web`、`/web/x`（**最常用**） |
| `Exact` | 完全相等 |
| `ImplementationSpecific` | 由 Controller 决定 |

---

### D6-D7｜动手实验（周末）

#### 实验 1：Service 全类型（30 分钟）

1. 建 Deployment `app`（nginx，3 副本）
2. 建 ClusterIP Service，从集群内 curl 验证
3. 建 NodePort Service（指定 nodePort 30080），验证
4. 建无 selector 的 Service + 手动 Endpoints，指向 `10.0.0.1:80`，验证 Endpoints 有值
5. 建 ExternalName Service 指向 `example.com`，用 `k exec` 内 `nslookup` 验证能解析

#### 实验 2：Endpoints 排障（15 分钟）

人为制造三种"Endpoints 为空"：

```bash
# ① selector 不匹配
k create deploy x1 --image=nginx
k expose deploy x1 --port=80 --name=bad-svc --dry-run=client -o yaml > /tmp/bad.yaml
# 改 selector 为 app=nonexist
k get endpoints bad-svc        # <none>

# ② Pod 未 Ready（把 readinessProbe 写成永远失败的路径）
# ③ Service 与 Pod 不在同一 namespace
```

每种都写出"你如何发现、如何修"。

#### 实验 3：NetworkPolicy 白名单（⭐核心实验，30 分钟）

**需求**：

> ns `prod` 中有 3 个 Pod：`frontend`(app=frontend)、`backend`(app=backend)、`other`(app=other)。
> 要求：
> 1. `backend` 只接受 `frontend` 的 80 端口访问
> 2. 其他所有 Pod 之间默认放通（先不设 default-deny）
> 3. 完成后补充：再给 `prod` 加 default-deny-ingress，验证只有 frontend→backend 还能通

**验证命令**（用 wget 或 nc）：

```bash
k exec frontend -n prod -- wget -qO- --timeout=2 http://backend-svc  # 通
k exec other    -n prod -- wget -qO- --timeout=2 http://backend-svc  # 超时
```

#### 实验 4：Ingress 分流（30 分钟）

1. 装 ingress-nginx
2. 建两个 Deployment：`web`（nginx）、`api`（用 `hashicorp/http-echo` 或 nginx 都行）
3. 建一个 Ingress，`/web` → web svc，`/api` → api svc
4. 用 `curl -H "Host: ..."` 验证两条路径都通
5. 加 TLS（自签证书），验证 https 可访问

---

## 四、本周必练命令

```bash
# Service
kubectl expose deploy <n> --port=<p> --target-port=<tp> --type=<t>
kubectl create service clusterip|nodeport|loadbalancer <name> --tcp=80:80
kubectl create service externalname <name> --external-name=<fqdn>
kubectl get svc,endpoints,endpointslices
kubectl describe svc <n>

# 网络测试
kubectl run tmp --image=busybox:1.36 --rm -it --restart=Never -- sh
kubectl exec -it <pod> -- nslookup <svc>.<ns>.svc.cluster.local
kubectl exec -it <pod> -- wget -qO- --timeout=2 http://<svc>
kubectl exec -it <pod> -- cat /etc/resolv.conf

# NetworkPolicy
kubectl get networkpolicy -A
kubectl describe networkpolicy <n>

# Ingress
kubectl create ingress <n> --rule="/path=svc:port" --class=nginx [--dry-run=client -o yaml]
kubectl get ingress
kubectl describe ingress <n>

# 端口转发（本地调试神器）
kubectl port-forward svc/<n> 8080:80
```

---

## 五、验收标准

- [ ] 能在 3 分钟内创建 NodePort Service 并说明 `port`/`targetPort`/`nodePort` 的区别
- [ ] 给出一个"Endpoints 为空"的场景，能在 5 分钟内定位到原因
- [ ] 能默写 CoreDNS 域名格式 `svc.ns.svc.cluster.local`
- [ ] 能不看文档写出「默认拒绝 + 只允许 frontend 访问 backend 的 80 端口」
- [ ] 能说清 `namespaceSelector` 与 `podSelector` 同 list item / 分 list item 的 AND/OR 差异
- [ ] 知道为什么 Egress 策略必须放通 DNS
- [ ] 能创建 Ingress 并说出为什么"创建了 Ingress 但访问不通"（没装 Controller）
- [ ] 知道 Flannel 不支持 NetworkPolicy 这个事实

---

## 六、自测题

1. `port`、`targetPort`、`nodePort` 分别指什么？不写 `targetPort` 会怎样？
2. Service 的 Endpoints 为空，列出至少 4 种可能原因。
3. 一个 Pod 被只有 `Ingress` 规则的 NetworkPolicy 选中，它的**出站**流量会被限制吗？
4. 写了 NetworkPolicy 但没生效，最可能的原因是什么？
5. `nslookup backend` 在一个 Pod 里能通，`nslookup backend.prod` 不能通，说明什么？
6. `pathType: Prefix` 的 `/api` 能匹配 `/apixyz` 吗？（提示：按路径段匹配）
7. Ingress 和 Service 的根本区别是什么？为什么需要 Ingress Controller？
8. `port-forward` 能用于生产暴露服务吗？为什么？

---

## 七、踩坑记录

| 现象 | 原因 | 解决 |
|------|------|------|
| | | |

---

## 八、复盘区

**Endpoints 排查 5 步法（自己重写一遍）**

1.
2.
3.
4.
5.

**实验 3 NetworkPolicy 实验，我踩的坑**

>

**本周用时统计**

| 天 | 计划 | 实际 |
|----|------|------|
| D1 | 1.5h | |
| D2 | 1.5h | |
| D3 | 1.5h | |
| D4 | 2h | |
| D5 | 1.5h | |
| D6 | 3h | |
| D7 | 3h | |

**一句话总结本周**

>

---

*[← 上一周：Week3-调度与亲和性](Week3-调度与亲和性.md) ｜ [返回索引](README.md) ｜ [下一周：Week5-存储与RBAC →](Week5-存储与RBAC.md)*