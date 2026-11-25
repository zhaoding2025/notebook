#!/usr/bin/env bash
# ============================================================
# 实验1:NodeAffinity 节点亲和(硬约束 / 软约束)
# 前置:先跑 00-预备.sh
# ============================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "############################################"
echo "# 实验1a:硬约束 —— 必须去 disktype=ssd 节点 #"
echo "############################################"
kubectl apply -f hard-pod.yaml
sleep 3
echo "--- aff-hard 落在哪台节点 ---"
kubectl get pod aff-hard -o wide
echo "→ 期望:NODE=master 或 NODE=node1(node2 因 hdd 被排除)"

echo ""
echo "node2 为什么没被选?验证:"
kubectl describe node node2 | grep -i labels
echo "→ node2 没有 disktype=ssd,被硬约束排除"

echo ""
echo "############################################"
echo " 实验1b:软约束 preferred 优先 zone-a        "
echo "############################################"
kubectl apply -f soft-pod.yaml
sleep 3
echo "--- 先把 master 污点暂时拿掉,让 node1/node2/master 都可用,观察 soft 的行为 ---"
kubectl taint node master node-role.kubernetes.io/master:NoSchedule- 2>/dev/null || true
kubectl taint node node1 node-role.kubernetes.io/master:NoSchedule- 2>/dev/null || true
kubectl delete pod soft-pod --ignore-not-found
kubectl apply -f soft-pod.yaml
sleep 3
echo "--- 此时 zone-a 节点未饱和,soft Pod 应落在 zone-a(node1 或 node2) ---"
kubectl get pod aff-soft -o wide
echo "→ 期望:node1 或 node2(zone-a),不太可能去 master(zone-b)"

echo ""
echo "=== 实验1 完成。查看当前所有亲和 Pod ==="
kubectl get pods -o wide
echo ""
echo ""
echo "--- 恢复 master 污点(实验1临时移除,现在补回) ---"
kubectl taint node master node-role.kubernetes.io/master:NoSchedule 2>/dev/null || echo "(本机 master 角色污点恢复失败,请手动补: kubectl taint node master node-role.kubernetes.io/master:NoSchedule)"
kubectl taint node node1 node-role.kubernetes.io/master:NoSchedule- 2>/dev/null || true

kubectl delete pod aff-hard aff-soft --ignore-not-found

echo ""
echo "下一步:bash ../../02-podAffinity/02-run.sh"