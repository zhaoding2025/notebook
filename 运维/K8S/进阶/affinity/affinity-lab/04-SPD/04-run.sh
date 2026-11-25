#!/usr/bin/env bash
# ============================================================
# 实验4:TopologySpreadConstraints 拓扑分布约束(进阶,1.19+)
# 用 maxSkew 让副本「尽量均摊」到各节点,避免扎堆
# ============================================================
DIR="$(dirname "${BASH_SOURCE[0]}")"
cd "$DIR"

echo "##########################################"
echo " Experiment 4: maxSkew=1 跨 hostname 均匀   "
echo "  4 副本.稀疏环境:优先铺开后剩下也没关系    "
echo "  (用 ScheduleAnyway,不强制,结论重点在观察分布艺术) "
echo "##########################################"
kubectl apply -f spread.yaml
sleep 8
echo "--- web3 各副本的节点分布 ---"
kubectl get pods -l app=web3 -o wide

echo ""
echo "--- 分布统计(每节点 Pod 数) ---"
kubectl get pods -l app=web3 -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort | uniq -c

echo ""
echo "→ 理想:3 台可调度节点上各放 1,剩余 1 个放到其中一台(maxSkew=1)"
echo "  (node1/node2 各1,第3副本上,第4再补齐到差值不过1)"
echo ""
echo "注意:当前 master 若有污点、节点压力等,实际分布可能有偏差,以节点物理可用为准。"

echo ""
echo "=== 实验4 完成 ==="