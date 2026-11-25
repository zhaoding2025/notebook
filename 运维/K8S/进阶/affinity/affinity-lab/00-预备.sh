#!/usr/bin/env bash
# ============================================================
# 00-预备:清理环境 + 给节点打标签
# 用途:每次开始实验前运行一次,确保干净环境
# ============================================================
set -e
echo "===== [预备] 清理旧实验资源 ====="
kubectl delete deployment web redis app web2 probe 2>/dev/null || true
kubectl delete pod web redis 2>/dev/null || true
# 删除之前实验留下的范例 yaml(podAffinity 生成的 spec.priorityClassName 等无关紧要)

echo "===== [预备] 确认节点当前污点 ====="
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

echo ""
echo "===== [预备] 给节点打实验标签 ====="
# disktype:模拟"机型差异"
# zone:模拟"可用区"
kubectl label node node1 disktype=ssd  zone=zone-a --overwrite
kubectl label node node2 disktype=hdd  zone=zone-a --overwrite
kubectl label node master disktype=ssd zone=zone-b --overwrite
echo "--- 打标签后查看 ---"
kubectl get nodes --show-labels

echo ""
echo "===== [预备] 完成,可以开始实验 ====="