# CKA 速查表 · 考前只看这一份

> **用法**：考前 48 小时只看这页。按「场景」查，不按字母查。
> **考试铁律**：① 先切 context ② 卡住就跳过 ③ 能 dry-run 就不手写

---

## 目录

- [0. 开考准备（设一次就够）](#0-开考准备设一次就够)
- [1. 万能快捷命令](#1-万能快捷命令)
- [2. YAML 模板速查](#2-yaml-模板速查)
- [3. 场景速查（按题目要求找答案）](#3-场景速查按题目要求找答案)
- [4. 排障速查](#4-排障速查)
- [5. 官方文档检索路径](#5-官方文档检索路径)
- [6. 易错点清单](#6-易错点清单)

---

## 0. 开考准备（设一次就够）

```bash
# ---- 必设 ----
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"

# ---- 补全（考试环境用 bash）----
source <(kubectl completion bash)
complete -o default -F __start_kubectl k

# ---- vim 设置（考试环境可写 ~/.vimrc）----
cat > ~/.vimrc <<'EOF'
set tabstop=2 shiftwidth=2 expandtab
set number autoindent
EOF
# 临时粘贴：编辑时先 :set paste
```

---

## 1. 万能快捷命令

### Context / Namespace（每题必做）

```bash
kubectl config get-contexts
kubectl config use-context <ctx>                              # ⭐每题第一句
kubectl config set-context --current --namespace=<ns>
kubectl config view --minify | grep namespace:
```

### 查看资源

```bash
kubectl get all -n <ns>
kubectl get pods -A -o wide
kubectl get pods --show-labels
kubectl get pods -l app=web,tier=fe
kubectl get pods -l 'env in (prod,dev)'
kubectl get pods -l '!env'
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get pods -o wide --sort-by=.status.startTime
kubectl get pod <p> -o yaml
kubectl get pod <p> -o jsonpath='{.status.podIP}'
kubectl get pod <p> -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
kubectl get pod <p> -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
kubectl explain pod.spec.containers --recursive
kubectl api-resources | grep -i <keyword>
kubectl api-versions
```

### 创建（省时间的关键）

```bash
k run <n> --image=<i> $do > /tmp/p.yaml
k run <n> --image=<i> --port=80 --labels=app=x --env=K=V --command -- sleep 3600
k create deploy <n> --image=<i> --replicas=3 $do > /tmp/d.yaml
k create job <n> --image=busybox -- <cmd>
k create cronjob <n> --image=busybox --schedule="*/1 * * * *" -- <cmd>
k create ns <ns>
k create cm <n> --from-literal=k=v --from-file=f.conf --from-env-file=e.env
k create secret generic <n> --from-literal=k=v
k create secret tls <n> --cert=tls.crt --key=tls.key
k create secret docker-registry <n> --docker-server=reg --docker-username=u --docker-password=p
k create sa <n> -n <ns>
k create role <n> --verb=get,list,watch --resource=pods -n <ns>
k create rolebinding <n> --role=<r> --serviceaccount=<ns>:<sa> -n <ns>
k create rolebinding <n> --role=<r> --user=<u> -n <ns>
k create clusterrole <n> --verb=get,list --resource=nodes
k create clusterrolebinding <n> --clusterrole=<cr> --serviceaccount=<ns>:<sa>
k create ingress <n> --rule="/path=svc:80" --class=nginx $do > /tmp/i.yaml
kubectl autoscale deploy <n> --min=2 --max=10 --cpu-percent=50
```

### 修改（避免手改 yaml）

```bash
kubectl scale deploy <n> --replicas=5
kubectl set image deploy/<n> <ctr>=<img>:<tag>
kubectl set env deploy/<n> K=V
kubectl set resources deploy/<n> -c=<ctr> --limits=cpu=200m,memory=256Mi
kubectl label node <n> key=value [--overwrite]
kubectl label node <n> key-
kubectl label pod <p> key=value
kubectl annotate <res> <n> key=value
kubectl patch <res> <n> -p '{"spec":{...}}' --type=merge
kubectl edit <res> <n>
```

### 调试

```bash
kubectl logs <p> [-c <c>] [-f] [--previous] [--tail=100] [--since=10m]
kubectl logs -l app=x --all-containers=true --prefix
kubectl exec -it <p> -- sh
kubectl exec -it <p> -c <c> -- sh
kubectl debug -it <p> --image=busybox:1.36 --target=<c>
kubectl debug node/<node> -it --image=busybox     # 挂宿主机到 /host
kubectl port-forward svc/<s> 8080:80
kubectl port-forward pod/<p> 8080:80
kubectl get events -A --sort-by=.lastTimestamp
kubectl get events --field-selector type=Warning -A
kubectl top node
kubectl top pod
```

### 删除 / 强制

```bash
kubectl delete <res> <n> [-n ns]
kubectl delete -f file.yaml
kubectl delete pod <p> --force --grace-period=0
kubectl patch pod <p> -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl delete ns <ns> --force --grace-period=0
```

---

## 2. YAML 模板速查

### Pod（含探针 + 资源 + 多容器）

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
  labels: {app: mypod}
spec:
  serviceAccountName: default
  nodeSelector: {disk: ssd}
  tolerations:
  - {key: dedicated, operator: Equal, value: infra, effect: NoSchedule}
  initContainers:
  - name: init
    image: busybox
    command: ['sh','-c','echo init > /work/x']
    volumeMounts: [{name: work, mountPath: /work}]
  containers:
  - name: app
    image: nginx:1.25
    ports: [{containerPort: 80}]
    resources:
      requests: {cpu: 100m, memory: 128Mi}
      limits:   {cpu: 200m, memory: 256Mi}
    env:
    - {name: ENV, value: prod}
    - name: FROM_CM
      valueFrom: {configMapKeyRef: {name: cfg, key: k}}
    - name: FROM_SEC
      valueFrom: {secretKeyRef: {name: sec, key: k}}
    envFrom:
    - configMapRef: {name: cfg}
    startupProbe:
      httpGet: {path: /, port: 80}
      failureThreshold: 30
      periodSeconds: 2
    livenessProbe:
      httpGet: {path: /, port: 80}
      initialDelaySeconds: 10
      periodSeconds: 10
    readinessProbe:
      exec: {command: ['sh','-c','test -f /tmp/ready']}
      periodSeconds: 5
    volumeMounts:
    - {name: work, mountPath: /work}
    - {name: cfgv, mountPath: /etc/cfg, readOnly: true}
  volumes:
  - name: work
    emptyDir: {}
  - name: cfgv
    configMap: {name: cfg}
  restartPolicy: Always
```

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: web}
spec:
  replicas: 3
  selector:
    matchLabels: {app: web}
  strategy:
    type: RollingUpdate
    rollingUpdate: {maxSurge: 1, maxUnavailable: 0}
  template:
    metadata:
      labels: {app: web}
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports: [{containerPort: 80}]
```

### Service（四种）

```yaml
# ClusterIP（默认）
apiVersion: v1
kind: Service
metadata: {name: svc}
spec:
  type: ClusterIP
  selector: {app: web}
  ports:
  - {name: http, port: 80, targetPort: 80, protocol: TCP}
---
# NodePort
spec:
  type: NodePort
  selector: {app: web}
  ports:
  - {port: 80, targetPort: 80, nodePort: 30080}
---
# LoadBalancer
spec:
  type: LoadBalancer
  selector: {app: web}
  ports: [{port: 80, targetPort: 80}]
---
# ExternalName（无 selector，无 ports 也可）
spec:
  type: ExternalName
  externalName: example.com
```

**无 selector + 手动 Endpoints**

```yaml
apiVersion: v1
kind: Service
metadata: {name: ext-db}
spec:
  ports: [{port: 3306, targetPort: 3306}]
---
apiVersion: v1
kind: Endpoints
metadata: {name: ext-db}       # 必须与 Service 同名
subsets:
- addresses: [{ip: 10.0.0.50}]
  ports: [{port: 3306}]
```

### Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  tls:
  - hosts: [app.example.com]
    secretName: my-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service: {name: web-svc, port: {number: 80}}
```

### ConfigMap / Secret

```yaml
apiVersion: v1
kind: ConfigMap
metadata: {name: cfg}
data:
  APP_ENV: prod
  nginx.conf: |
    server { listen 80; }
---
apiVersion: v1
kind: Secret
metadata: {name: sec}
type: Opaque
data:
  password: UzNjcjN0          # echo -n 'S3cr3t' | base64
stringData:                    # 明文写法（apply 时自动编码）
  username: admin
```

### PV / PVC

```yaml
apiVersion: v1
kind: PersistentVolume
metadata: {name: pv1}
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain     # Retain / Delete
  storageClassName: manual
  hostPath: {path: /mnt/data}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: pvc1}
spec:
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual
---
# Pod 挂载
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts: [{name: d, mountPath: /data}]
  volumes:
  - name: d
    persistentVolumeClaim: {claimName: pvc1}
```

### StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer   # Immediate / WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### RBAC（四件套）

```yaml
# Role（namespace 级）
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: pod-reader, namespace: dev}
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get","list","watch"]
---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: rb, namespace: dev}
subjects:
- {kind: ServiceAccount, name: my-sa, namespace: dev}
- {kind: User,  name: alice, apiGroup: rbac.authorization.k8s.io}
- {kind: Group, name: devs,  apiGroup: rbac.authorization.k8s.io}
roleRef:
  {kind: Role, name: pod-reader, apiGroup: rbac.authorization.k8s.io}
---
# ClusterRole（集群级，无 namespace）
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: node-reader}
rules:
- apiGroups: [""]
  resources: ["nodes","nodes/status"]
  verbs: ["get","list","watch"]
---
# ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: crb}
subjects:
- {kind: ServiceAccount, name: my-sa, namespace: dev}
roleRef:
  {kind: ClusterRole, name: node-reader, apiGroup: rbac.authorization.k8s.io}
```

**apiGroups 对照（常考）**

| 资源 | apiGroups |
|------|-----------|
| pods, services, configmaps, secrets, pv, pvc, nodes, namespaces, sa | `""` |
| deployments, replicasets, daemonsets, statefulsets | `"apps"` |
| jobs, cronjobs | `"batch"` |
| ingresses, networkpolicies | `"networking.k8s.io"` |
| storageclasses | `"storage.k8s.io"` |

**verbs**：`get list watch create update patch delete deletecollection`

### NetworkPolicy

```yaml
# 默认拒绝全部入站
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: deny-all-ingress, namespace: prod}
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
# 允许指定来源
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-web-to-db, namespace: prod}
spec:
  podSelector: {matchLabels: {app: db}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: {matchLabels: {app: web}}        # 同 ns
    - namespaceSelector: {matchLabels: {env: prod}} # 其他 ns 全部
      podSelector: {matchLabels: {app: web}}        # ↑ 同 item = AND
    - ipBlock: {cidr: 172.17.0.0/16, except: [172.17.1.0/24]}
    ports:
    - {protocol: TCP, port: 3306}
---
# Egress（务必放行 DNS！）
spec:
  podSelector: {matchLabels: {app: web}}
  policyTypes: [Egress]
  egress:
  - to: [{podSelector: {matchLabels: {app: db}}}]
    ports: [{protocol: TCP, port: 3306}]
  - to:
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}
    ports:
    - {protocol: UDP, port: 53}
    - {protocol: TCP, port: 53}
```

### DaemonSet

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata: {name: agent}
spec:
  selector: {matchLabels: {app: agent}}
  template:
    metadata: {labels: {app: agent}}
    spec:
      tolerations:
      - {key: node-role.kubernetes.io/control-plane, operator: Exists, effect: NoSchedule}
      - {operator: Exists}          # 万能容忍（覆盖所有污点）
      containers:
      - name: agent
        image: busybox
        command: ['sh','-c','sleep infinity']
```

### Job / CronJob

```yaml
apiVersion: batch/v1
kind: Job
metadata: {name: j1}
spec:
  completions: 3
  parallelism: 2
  backoffLimit: 4
  ttlSecondsAfterFinished: 100
  template:
    spec:
      restartPolicy: Never       # ⚠️ Never / OnFailure，不能 Always
      containers:
      - {name: c, image: busybox, command: ['sh','-c','echo hi']}
---
apiVersion: batch/v1
kind: CronJob
metadata: {name: cj}
spec:
  schedule: "*/1 * * * *"
  concurrencyPolicy: Forbid     # Allow / Forbid / Replace
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:                  # ⚠️ 三层嵌套
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - {name: c, image: busybox, command: ['sh','-c','date']}
```

### 调度：亲和性 + 污点容忍

```yaml
spec:
  nodeSelector: {disk: ssd}
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - {key: disk, operator: In, values: [ssd, nvme]}
          - {key: zone, operator: NotIn, values: [west]}
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
          - {key: gpu, operator: Exists}
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector: {matchLabels: {app: web}}
          topologyKey: kubernetes.io/hostname
  tolerations:
  - {key: gpu, operator: Equal, value: "true", effect: NoSchedule}
  - {key: dedicated, operator: Exists, effect: NoExecute, tolerationSeconds: 3600}
  - {operator: Exists}          # 万能：容忍所有
```

### HPA

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

### Static Pod（放到 /etc/kubernetes/manifests/）

```yaml
apiVersion: v1
kind: Pod
metadata: {name: static-web}
spec:
  containers: [{name: web, image: nginx}]
```

```bash
# 创建
cat > /etc/kubernetes/manifests/static-web.yaml <<'EOF'
...上面的 yaml...
EOF
# 验证（名字带节点名后缀）
kubectl get pods -A | grep static-web
# 删除：删文件，不是 kubectl delete
rm /etc/kubernetes/manifests/static-web.yaml
```

---

## 3. 场景速查（按题目要求找答案）

### 「给某个 Pod 打上标签 / 修改标签」
```bash
kubectl label pod <p> env=prod --overwrite
```

### 「把 Deployment 扩容到 N」
```bash
kubectl scale deploy <n> --replicas=N
```

### 「更新 Deployment 镜像」
```bash
kubectl set image deploy/<n> <container>=<image>:<tag>
kubectl rollout status deploy/<n>
```

### 「回滚到上一个版本 / 指定版本」
```bash
kubectl rollout undo deploy/<n>
kubectl rollout undo deploy/<n> --to-revision=1
kubectl rollout history deploy/<n>
```

### 「重启 Deployment」
```bash
kubectl rollout restart deploy/<n>
```

### 「把某个 Pod 暴露为 Service」
```bash
kubectl expose pod <p> --port=80 --target-port=8080 --type=NodePort --name=<svc>
```

### 「Service 只能从某 namespace 访问」
→ NetworkPolicy（见模板）

### 「让节点只能跑特定 Pod」
```bash
kubectl taint node <n> dedicated=infra:NoSchedule
kubectl label node <n> dedicated=infra
# Pod 加 toleration + nodeSelector
```

### 「让 Pod 分散到不同节点」
→ podAntiAffinity `preferred` + `topologyKey: kubernetes.io/hostname`

### 「创建静态 Pod」
```bash
# 在目标节点上（不在集群层）
mkdir -p /etc/kubernetes/manifests
cat > /etc/kubernetes/manifests/<name>.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: <name>}
spec:
  containers: [{name: c, image: nginx}]
EOF
kubectl get pods -A | grep <name>
```

### 「给用户/SA 授权」
```bash
kubectl create sa <sa> -n <ns>
kubectl create role <r> --verb=get,list --resource=pods -n <ns>
kubectl create rolebinding <rb> --role=<r> --serviceaccount=<ns>:<sa> -n <ns>
kubectl auth can-i get pods --as=system:serviceaccount:<ns>:<sa> -n <ns>
```

### 「创建 PVC 供 Pod 使用」
→ 见 PV/PVC 模板，三步：PV → PVC → Pod volumeMount

### 「扩展 PVC 容量」
```bash
kubectl patch pvc <n> -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
# 需要 SC allowVolumeExpansion: true
```

### 「修复 Released 状态的 PV」
```bash
kubectl edit pv <n>     # 删除 spec.claimRef 整段
```

### 「备份 etcd」
```bash
etcdctl snapshot save /opt/backup/etcd.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
etcdctl snapshot status /opt/backup/etcd.db -w table
```

### 「从备份恢复 etcd」
```bash
etcdctl snapshot restore /opt/backup/etcd.db --data-dir=/var/lib/etcd-restore
systemctl stop kubelet
mv /var/lib/etcd /var/lib/etcd.bak
mv /var/lib/etcd-restore /var/lib/etcd
chown -R etcd:etcd /var/lib/etcd      # 视发行版
systemctl start kubelet
sleep 30 && kubectl get nodes
```

### 「节点维护 / 下线」
```bash
kubectl drain <n> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <n>
kubectl cordon <n>
```

### 「加入新节点」
```bash
# master
kubeadm token create --print-join-command
# worker 执行上一步输出
```

### 「创建 Ingress」
```bash
kubectl create ingress <n> --rule="/path=svc:80" --class=nginx $do > /tmp/i.yaml
kubectl apply -f /tmp/i.yaml
```

### 「让所有 Pod 都能到达某个外部服务」
→ 无 selector 的 Service + 手动 Endpoints

---

## 4. 排障速查

### 四步法

```
① 划定范围（Pod / 节点 / 集群 / 网络）
② kubectl get 看 STATUS
③ kubectl describe → 看 Events（90% 答案在这）
④ kubectl logs / journalctl / crictl logs
```

### Pod 状态对照表

| 状态 | 查什么 | 常见修复 |
|------|--------|---------|
| `Pending` | `describe` → Events `FailedScheduling` | 资源不足 / 污点 / 亲和性 / PVC 未绑定 / cordon |
| `ContainerCreating` | `describe` → Events | 卷挂载失败 / 镜像拉取慢 / CNI 未就绪 |
| `ImagePullBackOff` | `describe` → Events | 镜像名错 / 无 imagePullSecrets / 网络 |
| `ErrImagePull` | 同上 | 同上 |
| `CrashLoopBackOff` | `logs --previous` | 启动命令错 / 依赖缺失 / 探针失败 |
| `RunContainerError` | `describe` | 命令不存在 / 挂载路径错 |
| `OOMKilled` | `describe` → Last State | 增大 memory limits / 修内存泄漏 |
| `CreateContainerConfigError` | `describe` | CM/Secret 不存在、key 名错 |
| `Completed` | `get pod` | Job 正常结束 |
| `Terminating` 卡住 | `describe` → finalizers | `--force --grace-period=0` / 清 finalizer |

### FailedScheduling 事件文本 → 原因

| 文本 | 原因 |
|------|------|
| `Insufficient cpu` / `Insufficient memory` | 资源不足 |
| `node(s) had untolerated taint {x: y}` | 有污点没容忍 |
| `node(s) didn't match Pod's node affinity` | 亲和性不匹配 |
| `node(s) didn't match Pod's node selector` | nodeSelector 不匹配 |
| `node(s) were unschedulable` | 节点 cordon |
| `pod has unbound immediate PersistentVolumeClaims` | PVC 未 Bound |
| `didn't match pod anti-affinity rules` | 反亲和冲突 |
| `exceeded quota` | 资源配额超限 |

### 节点 NotReady 排查顺序

```bash
# 1. 宿主机资源
df -h; free -m; top -bn1 | head -20

# 2. 服务状态
systemctl status kubelet containerd
journalctl -u kubelet -n 100 --no-pager
journalctl -u containerd -n 50 --no-pager

# 3. 连通性
curl -k https://<apiserver>:6443/healthz
ss -tlnp | grep 10250

# 4. 证书
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates

# 5. CNI
ls /etc/cni/net.d/
crictl ps | grep -E 'calico|cilium|flannel'

# 6. 磁盘急救
crictl rmi --prune
journalctl --vacuum-size=200M
```

**关键错误 → 修复**

| 错误 | 修复 |
|------|------|
| `cgroupfs differs from systemd` | containerd 配 `SystemdCgroup = true`，重启 |
| `certificate has expired` | `kubeadm certs renew` |
| `PLEG is not healthy` | 重启 containerd 再重启 kubelet |
| `network plugin is not ready` | 修 CNI |
| `low on resource: nodefs` | 清镜像/日志 |

### 控制平面故障

```bash
# kubectl 不可用时唯一工具
crictl ps -a | grep -E 'etcd|apiserver|scheduler|controller'
crictl logs <container-id>

# 静态 Pod manifest 目录
ls -l /etc/kubernetes/manifests/

# 修复方式：改 yaml → kubelet 自动重建
cp /tmp/good.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
sleep 30 && kubectl get nodes

# 健康检查
kubectl get --raw='/healthz'
kubectl get --raw='/readyz'
```

| 症状 | 挂的组件 |
|------|---------|
| `kubectl` connection refused | apiserver |
| `kubectl get` 卡住无响应 | etcd |
| Pod 全 Pending 且无 FailedScheduling 事件 | scheduler |
| Deployment 建了但没有 ReplicaSet | controller-manager |

### Service / DNS 排障

```bash
# 1. Endpoints 是否为空
kubectl get endpoints <svc>

# 2. selector 与 Pod label
kubectl get svc <svc> -o yaml | grep -A3 selector
kubectl get pods --show-labels

# 3. Pod 是否 Ready（不 Ready 不进 Endpoints）
kubectl get pods
kubectl describe pod <p> | grep -A10 Conditions

# 4. 容器实际监听端口
kubectl exec -it <p> -- ss -tlnp

# 5. DNS
kubectl exec -it <p> -- cat /etc/resolv.conf
kubectl exec -it <p> -- nslookup <svc>.<ns>.svc.cluster.local
kubectl get svc -n kube-system kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50

# 6. NetworkPolicy 是否误伤
kubectl get netpol -A
kubectl describe netpol <n> -n <ns>

# 7. kube-proxy / CNI
kubectl get pods -n kube-system
```

**Endpoints 为空 4 原因**

1. selector 与 Pod label 不匹配
2. Pod 未 Ready（readinessProbe 失败）
3. Pod 在别的 namespace
4. Service 的 targetPort 与容器端口不符（不导致空，但访问不通）

---

## 5. 官方文档检索路径

> 考试只有 kubernetes.io 可用。**Tasks 页面**是 yaml 天库。

| 需求 | 搜索关键词 | 直达 |
|------|-----------|------|
| Pod 模板 | `pods` → Concepts → Pods | `/docs/concepts/workloads/pods/` |
| Deployment | `deployment` | `/docs/concepts/workloads/controllers/deployment/` |
| Service | `service` | `/docs/concepts/services-networking/service/` |
| NetworkPolicy | `network policies` | `/docs/concepts/services-networking/network-policies/` |
| Ingress | `ingress` | `/docs/concepts/services-networking/ingress/` |
| PV/PVC | `configure persistent volume` | `/docs/tasks/configure-pod-container/configure-persistent-volume-storage/` |
| StorageClass | `storage classes` | `/docs/concepts/storage/storage-classes/` |
| RBAC | `rbac` / `using rbac authorization` | `/docs/reference/access-authn-authz/rbac/` |
| Taint/Toleration | `taint toleration` | `/docs/concepts/scheduling-eviction/taint-and-toleration/` |
| 亲和性 | `assigning pods to nodes` | `/docs/concepts/scheduling-eviction/assign-pod-node/` |
| DaemonSet | `daemonset` | `/docs/concepts/workloads/controllers/daemonset/` |
| Static Pod | `static pod` | `/docs/tasks/configure-pod-container/static-pod/` |
| ConfigMap | `configmap` | `/docs/concepts/configuration/configmap/` |
| Secret | `secret` | `/docs/concepts/configuration/secret/` |
| Job/CronJob | `cronjob` | `/docs/concepts/workloads/controllers/cron-jobs/` |
| HPA | `horizontal pod autoscale` | `/docs/tasks/run-application/horizontal-pod-autoscale/` |
| etcd 备份恢复 | `operating etcd` | `/docs/tasks/administer-cluster/configure-upgrade-etcd/` |
| kubeadm 升级 | `upgrading kubeadm clusters` | `/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/` |
| 证书 | `certificate management` | `/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/` |
| 节点排障 | `troubleshoot clusters` | `/docs/tasks/debug/debug-cluster/` |
| 服务排障 | `debug services` | `/docs/tasks/debug/debug-application/debug-service/` |
| 私有镜像 | `pull image from private registry` | `/docs/tasks/configure-pod-container/pull-image-private-registry/` |
| kubectl 速查 | `kubectl cheat sheet` | `/docs/reference/kubectl/quick-reference/` |

**技巧**：每个 Tasks 页面底部都有 **完整可直接复制的 yaml**。搜到页面 → 往下翻到 yaml → 复制 → 改名字和参数。

---

## 6. 易错点清单

### 🔴 致命错误（直接 0 分）

- [ ] **没切 context** → 操作了别的集群
- [ ] **对象名字拼错** → 判分脚本找不到资源
- [ ] **namespace 错** → 资源建在了 default
- [ ] **改动了不该改的资源** → 题目说"不影响其他资源"

### 🟠 高频失分点

| 易错点 | 正确做法 |
|--------|---------|
| Tab 缩进 | yaml **只能用空格**，`.vimrc` 设 `expandtab` |
| 多个对象粘在一个文件 | 用 `---` 分隔 |
| `kubectl run` 没有 `--dry-run` 直接跑 | 加 `$do` 生成 yaml 再改 |
| Service 的 `port` 和 `targetPort` 混了 | `port` = Service 端口；`targetPort` = **容器端口** |
| PVC 与 PV 的 `storageClassName` 不一致 | 两边必须相同（都空也算相同） |
| `namespaceSelector` 与 `podSelector` 缩进位置 | 同 item = AND，分 item = OR |
| Egress 策略忘了放行 DNS | 必须加 53 端口 UDP/TCP |
| Job 的 `restartPolicy: Always` | 只能 `Never` / `OnFailure` |
| CronJob 缩进层级 | `spec.jobTemplate.spec.template.spec` |
| 忘 `--ignore-daemonsets` 就 drain | 会报错 |
| 忘 `--delete-emptydir-data` 就 drain | 会报错 |
| 用 `kubectl delete pod` 删 Static Pod | 删不掉，要删 manifest 文件 |
| PV `Released` 想复用 | 删 `spec.claimRef` |
| HPA 显示 `<unknown>` | 检查 metrics-server + Pod 的 requests.cpu |
| 探针 `port` 用了 Service 端口 | 应该用**容器端口** |
| `imagePullSecrets` 忘了加 | 私有镜像必备 |

### 🟡 时间陷阱

- [ ] 在一道题上超过 10 分钟 → **跳过**
- [ ] 按题号顺序做 → 应该先扫一遍，简单的先做
- [ ] 手写长 yaml → 用 `--dry-run=client -o yaml` 生成
- [ ] 反复 `kubectl edit` 试错 → 一次生成正确 yaml 再 apply

---

## 7. 一页纸终极 checklist（考前 5 分钟看这个）

```
┌─────────────────────────────────────────────┐
│  1. 每题第一句：kubectl config use-context  │
│  2. 读题划出：ns / 名字 / 镜像 / 副本 / 端口 │
│  3. 能 dry-run 就不手写                      │
│  4. 做完立即 kubectl get/describe 验证       │
│  5. 8 分钟没进展 → 标记跳过                  │
│  6. 留 10 分钟回查标记题                     │
│  7. 66 分就过，不用满分                      │
└─────────────────────────────────────────────┘
```

**三大高频题的标准操作**

| 题 | 关键动作 |
|----|---------|
| **etcd 备份恢复** | 4 个证书路径 + `restore --data-dir` 新目录 + 换 `/var/lib/etcd` |
| **RBAC 授权** | `create sa` → `create role` → `create rolebinding --serviceaccount=ns:sa` → `auth can-i` |
| **Taint 部署** | `taint node` → Pod 加 `tolerations: [{operator: Exists}]` |

---

*[返回索引](README.md) ｜ [Week1](Week1-环境与基础.md) · [Week2](Week2-工作负载.md) · [Week3](Week3-调度与亲和性.md) · [Week4](Week4-服务与网络.md) · [Week5](Week5-存储与RBAC.md) · [Week6](Week6-集群运维.md) · [Week7](Week7-故障排查.md) · [Week8](Week8-模拟冲刺.md)*