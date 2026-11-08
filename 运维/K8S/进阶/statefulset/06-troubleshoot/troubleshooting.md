# StatefulSet 故障排查速查表

## 一、Pod 卡在 Pending

```bash
kubectl describe pod <sts>-0 | tail -30
kubectl get events --sort-by=.lastTimestamp | tail -20
```

| 现象 | 根因 | 解法 |
|---|---|---|
| `pod has unbound immediate PersistentVolumeClaims` | `volumeBindingMode: WaitForFirstConsumer` + 无可用节点满足本地盘 | 检查 PV 的 nodeAffinity 与节点标签；或改 SC |
| `no persistent volumes available` | SC 无 provisioner / PV 池耗尽 | `kubectl get pv`、`kubectl get sc` |
| `0/3 nodes are available: ... volume node affinity conflict` | 本地盘 PV 绑定在别的节点 | 换 SC 或用网络存储 |
| `TopologySpreadConstraints` 无法满足 | `whenUnsatisfiable: DoNotSchedule` 且节点不够 | 改为 `ScheduleAnyway` 或加节点 |

## 二、Pod 只起了 0 号，1/2 一直不创建

这是**预期行为**，不是 bug。`podManagementPolicy: OrderedReady` 要求前一个 Pod **Ready** 后才创建下一个。

```bash
kubectl get pod <sts>-0 -o jsonpath='{.status.conditions}'
kubectl logs <sts>-0 --tail=50
```

- 若 0 号 `Ready=False`：修好它的 readinessProbe / 依赖服务
- 若确实无启动顺序依赖：改 `podManagementPolicy: Parallel`
- 若依赖"成员互相发现后才就绪"（etcd/zk）：需要 `Parallel` + `publishNotReadyAddresses: true`

## 三、Pod 名字对，但没有 DNS / 解析不到

```bash
kubectl get svc <headless-svc> -o jsonpath='{.spec.clusterIP}'   # 必须是 None
kubectl get endpoints <headless-svc>                             # 应有各 Pod IP
kubectl get sts <name> -o jsonpath='{.spec.serviceName}'         # 必须等于 svc 名
kubectl exec <sts>-0 -- cat /etc/resolv.conf
```

高频错误：
1. `serviceName` 写错或漏写 → Pod 完全没有域名
2. Service 不是 `clusterIP: None` → 只有 ClusterIP 一个 A 记录，没有per-Pod 记录
3. Service `selector` 与 Pod `labels` 不匹配 → Endpoints 为空
4. Pod 未 Ready → 默认不进 Endpoints（`publishNotReadyAddresses: false`）
5. 用了 `hostNetwork: true` → 该 Pod 的身份不再走集群 DNS

正确的 DNS 形态（ns=default，sts=db，svc=db）：
```
db-0.db.default.svc.cluster.local   → 单个 Pod IP
db.default.svc.cluster.local        → 所有 Ready Pod IP 列表（可做客户端轮询）
```

## 四、PVC 相关

```bash
kubectl get pvc -o wide
kubectl get pvc <vct>-<sts>-0 -o jsonpath='{.spec.volumeName}'
kubectl get pv <pv-name>
```

| 问题 | 说明 |
|---|---|
| `Pending` | 无 PV 或 SC 不存在 / 容量不足 |
| 改 `volumeClaimTemplates` 容量没生效 | 模板只影响未来 PVC，存量需手动 patch |
| 想缩容 PVC | **不支持**，只能重建 PVC（先备份数据） |
| 删了 STS，PVC 还在 | 正常，默认 `whenDeleted: Retain` |
| 删了 PVC，PV 还在 | SC `reclaimPolicy: Retain`，需手动删 PV |

## 五、滚动更新卡住

```bash
kubectl rollout status sts/<name>
kubectl rollout history sts/<name>
kubectl get pods -l app=<name> -o wide
kubectl describe pod <sts>-2 | grep -A5 Events
```

常见原因：
- **新版本 Pod 起不来**（镜像拉不到 / CrashLoop）→ 卡在最大序号，前面已更新的回不去，需 `rollout undo`
- **`partition` 不是 0** → 部分 Pod 有意不更新，检查 `kubectl get sts <name> -o jsonpath='{.spec.updateStrategy}'`
- **`minReadySeconds` 太大** → 每个 Pod 都要等这么久，整体很慢
- **PVC 被手动删了** → 新 Pod 等 PVC 重新绑定，可能一直 Pending
- **`OnDelete` 策略** → 永远不会自动更新，必须手动删 Pod

## 六、Pod 反复重启（数据库类高发）

```bash
kubectl get pod <sts>-0 -o jsonpath='{.status.containerStatuses[0].restartCount}'
kubectl describe pod <sts>-0 | grep -A3 "Last State"
```

| 原因 | 特征 | 解法 |
|---|---|---|
| liveness 探针太激进 | `Last State: Terminated, Reason: Error, Exit Code: 137` | 加 `startupProbe`，放宽 `initialDelaySeconds` |
| 数据目录权限 | `Permission denied on /var/lib/mysql` | 加 `securityContext.fsGroup` 或用 initContainer chown |
| 旧数据目录版本不兼容 | 日志里有 "data directory has incompatible version" | 换回原镜像版本，或升级数据 |
| 优雅终止超时被 SIGKILL | `Exit Code: 137` 且刚好 `terminationGracePeriodSeconds` | 加大 grace period，加 `preStop` |

## 七、缩容后数据"丢了"

不是丢了，是**没有 Pod 挂它**。PVC 还在：

```bash
kubectl get pvc | grep <sts>
# 扩回原副本数，Pod 会重新挂回同序号的 PVC
kubectl scale sts <name> --replicas=<n>
```

⚠️ 反例：如果当初设置了 `persistentVolumeClaimRetentionPolicy.whenScaled: Delete`，缩容会真删 PVC —— 数据就没了。

## 八、删除 StatefulSet 的正确姿势

```bash
# 常规删除（Pod 会被级联删除，PVC 保留）
kubectl delete sts <name>

# 只删 STS，保留 Pod 继续跑（危险，慎用；用于迁移接管）
kubectl delete sts <name> --cascade=orphan

# 彻底清理（含数据）
kubectl delete sts <name>
kubectl delete pvc -l app=<name>
```

## 九、一分钟体检清单

```bash
# 一次性把所有相关对象列出来
kubectl get sts,svc,pod,pvc,pv -l app=<name> -o wide

# 看 STS 的状态汇总
kubectl get sts <name> -o custom-columns=\
NAME:.metadata.name,\
DESIRED:.spec.replicas,\
READY:.status.readyReplicas,\
CURRENT:.status.currentReplicas,\
UPDATED:.status.updatedReplicas,\
CURRENT_REV:.status.currentRevision,\
UPDATE_REV:.status.updateRevision
```