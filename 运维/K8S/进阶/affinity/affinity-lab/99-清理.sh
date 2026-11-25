#!/usr/bin/env bash
# ============================================================
# 99-清理:删掉所有实验资源,恢复 master 污点(如有)
# ============================================================
echo "===== 删除实验全部资源 ====="
kubectl delete deployment web web2 web3 redis 2>/dev/null || true
kubectl delete pod aff-hard aff-soft redis web 2>/dev/null || true

echo "===== 恢复 master 污点(默认应有,若被移除则补上) ====="
kubectl taint node master node-role.kubernetes.io/master:NoSchedule 2>/dev/null || \
  echo "(master 污点已存在或非 master 角色,跳过)"

echo "===== 可选:清除实验节点标签(注释掉表示保留) ====="
# kubectl label node node1 disktype- zone- 2>/dev/null
# kubectl label node node2 disktype- zone- 2>/dev/null

echo ""
echo "===== 当前节点状态 ====="
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
echo ""
echo "清理完成"