#!/usr/bin/env bash
# ============================================================
# 实验3:PodAntiAffinity 反亲和 —— 打散高可用
# 3A 硬约束:强制分散;3B 软约束:尽量分散
# ============================================================
DIR="$(dirname "${BASH_SOURCE[0]}")"
cd "$DIR"

echo "##########################################"
echo " 实验3A:反亲和硬约束 required,2 副本       "
echo " 拓扑域 = hostname(每台机器一个域,彼此互斥)  "
echo "##########################################"
kubectl apply -f anti-hard.yaml
sleep 6
echo "--- web 各副本分布在哪些节点 ---"
kubectl get pod -l app=web -o wide
echo ""
echo "验证是否有副本同节点:"
kubectl get pods -l app=web -o jsonpath='{range .items[*]}{.metadata.name} -> {.spec.nodeName}{"\n"}{end}'
echo ""
echo "→ 期望:两个副本 node 不同(一台机器一个)"

echo ""
echo "### 3A-进阶:把 replicas 改成 3,观察多余副本 Pending ###"
kubectl scale deployment web --replicas=3
sleep 4
echo "--- 3 副本在 2 台工作节点的分布 ---"
kubectl get pods -l app=web -o wide
echo "→ 期望:第 3 个副本卡 Pending(因为 node/主机只有2个工作节点可用)"

echo ""
echo "--- 找出 Pending 的副本并看事件 ---"
PODP=$(kubectl get pods -l app=web --field-selector=status.phase=Pending -o name 2>/dev/null | head -1)
if [ -n "$PODP" ]; then
  echo "发现 Pending: $PODP"
  kubectl describe $PODP | sed -n '/Events:/,$p'
  echo "→ 事件里应有: 0/N nodes are available: N node(s) didn't match pod anti-affinity rules"
else
  echo "尚未 Pending(可能还在调度),稍等再看"
fi

echo ""
echo "恢复副本数为 2,释放"
kubectl scale deployment web --replicas=2
sleep 3

echo ""
echo "##########################################"
echo " 实验3B:反亲和软约束 preferred             "
echo " 演示:即使把副本数加到>节点数,也不会 Pending  "
echo "##########################################"
kubectl apply -f anti-soft.yaml
sleep 6
kubectl scale deployment web2 --replicas=2
kubectl get pods -l app=web2 -o wide
echo ""
echo "--- 故意扩到 3 副本,观察 web2 不 Pending(能挤) ---"
kubectl scale deployment web2 --replicas=3
sleep 6
echo "--- web2 三个副本状态(应当都能 Running,即使挤在同一节点) ---"
kubectl get pods -l app=web2 -o wide

echo ""
echo "=== 实验3 完成 ==="