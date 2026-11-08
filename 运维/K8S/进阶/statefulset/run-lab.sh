#!/usr/bin/env bash
# ============================================================
# StatefulSet 全流程体验脚本
# ------------------------------------------------------------
# 用法：./run-lab.sh
# 前置：本地有 k3d / kind / minikube 任一集群（默认 SC 可用）
# 依赖：kubectl
#
# 脚本做四件事：
#   1. 部署 01-basic，观察有序创建
#   2. 验证稳定 DNS
#   3. 部署 03-storage，验证 PVC 与序号绑定
#   4. 演示 partition 灰度更新
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

C=bash
say() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$*"; }

say "0. 集群检查"
kubectl cluster-info | head -3
kubectl get sc

say "1. 部署基础 StatefulSet（串行创建）"
kubectl apply -f 01-basic/statefulset-simple.yaml
# -w 观察 0 → 1 → 2 的串行创建过程
kubectl get pods -l app=nginx-sts -w &
WATCH_PID=$!
sleep 25
kill $WATCH_PID 2>/dev/null || true

say "2. 验证稳定身份"
kubectl get pods -l app=nginx-sts -o custom-columns=\
NAME:.metadata.name,POD_IP:.status.podIP,NODE:.spec.nodeName
for i in 0 1 2; do
  echo "--- nginx-sts-$i 自报家门 ---"
  kubectl exec nginx-sts-$i -- sh -c 'cat /usr/share/nginx/html/index.html'
done

say "3. 验证 Headless Service 的稳定 DNS"
kubectl run dns-tester --rm -i --restart=Never --image=busybox:1.36 -- \
  nslookup nginx-sts-0.nginx-sts.default.svc.cluster.local || true

say "4. 有序缩减（3→1→3），观察逆序删除"
kubectl scale sts nginx-sts --replicas=1
kubectl get pods
kubectl scale sts nginx-sts --replicas=3
kubectl rollout status sts/nginx-sts --timeout=180s

say "5. 持久化实验：写入数据 → 删 Pod → 数据仍在"
kubectl apply -f 03-storage/pvc-lab.yaml
kubectl rollout status sts/store --timeout=180s
kubectl get pvc -l app=store
for i in 0 1 2; do
  kubectl exec store-$i -- sh -c "echo pod-$i-$(date +%s) > /data/id"
done
kubectl exec store-1 -- cat /data/id
echo ">>> 删除 store-1 ..."
kubectl delete pod store-1
kubectl rollout status sts/store --timeout=180s
echo -n ">>> store-1 重启后 /data/id = "
kubectl exec store-1 -- cat /data/id

say "6. 缩容 1 → 扩回 3，验证 PVC 不被回收"
kubectl scale sts store --replicas=1
echo "--- 缩容后 PVC 依然存在 ---"
kubectl get pvc -l app=store
kubectl scale sts store --replicas=3
kubectl rollout status sts/store --timeout=180s
echo -n ">>> store-2 重启后 /data/id = "
kubectl exec store-2 -- cat /data/id

say "7. partition 灰度更新演示"
kubectl apply -f 04-update/rolling-update.yaml
kubectl patch sts roll -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":1}}}}'
kubectl set image sts/roll web=nginx:1.26-alpine
echo ">>> 现在只有 roll-2 会更新，观察："
kubectl rollout status sts/roll --timeout=120s
kubectl get pods -l app=roll -o custom-columns=\
NAME:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready
echo ">>> 放开全部："
kubectl patch sts/roll -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
kubectl rollout status sts/roll --timeout=180s

say "8. 回滚"
kubectl rollout undo sts/roll
kubectl rollout status sts/roll --timeout=180s

say "清理（保留 PVC 以演示其独立生命周期）"
kubectl delete sts --all --cascade=orphan=false 2>/dev/null || true
kubectl delete svc --all 2>/dev/null || true
kubectl delete pod dns-client 2>/dev/null || true
kubectl delete configmap pvc-expand-notes 2>/dev/null || true
echo ">>> 注意：以下 PVC 仍然存在，需手动删除"
kubectl get pvc
echo ">>> 手动清理：kubectl delete pvc --all"