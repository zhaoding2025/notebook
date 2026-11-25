#!/usr/bin/env bash
# ============================================================
# 实验2:PodAffinity 同节点亲和(本地缓存/同机通信)
# 重点演示顺序:必须先有 redis,web 才能"跟过去"
# ============================================================
DIR="$(dirname "${BASH_SOURCE[0]}")"
cd "$DIR"

echo "#############################################"
echo " 实验2a:先故意违反顺序,复现你遇到的报错     "
echo "#############################################"
kubectl apply -f pod.yaml   # 此时 redis 还没建
sleep 4
echo "--- web 的调度状态 ---"
kubectl get pod web -o wide
echo "--- 看 Events 里真正的失败原因 ---"
kubectl describe pod web | sed -n '/Events:/,$p'
echo ""
echo "→ 预期看到: did not match pod affinity 或 did not match node affinity 之类"
echo "→ 原因:集群里还没有 app=redis 的 Pod,亲和无处可依"
echo ""

echo "#############################################"
echo " 实验2b:按正确顺序,先建 redis 再建 web       "
echo "#############################################"
# 先清掉刚才那个 pending 的 web
kubectl delete pod web --ignore-not-found

kubectl apply -f redis.yaml
echo "--- redis 落点 -------------"
kubectl get pod redis -o wide
echo "→ 记住 redis 在 node1 还是 node2"

sleep 3
kubectl apply -f pod.yaml
sleep 4
echo "--- web 与 redis 是否同机 ---"
kubectl get pods -o wide | grep -E "^redis|^web"
echo ""
echo "验证:两行 NODE 应一致(同节点同居)"
RC1=$(kubectl get pod redis -o jsonpath='{.spec.nodeName}')
RC2=$(kubectl get pod web -o jsonpath='{.spec.nodeName}')
echo "[断言] redis 所在节点=$RC1   web 所在节点=$RC2"
if [ "$RC1" == "$RC2" ]; then
  echo "✅ PASS:web 与 redis 同机(真正的同节点亲和生效)"
else
  echo "⚠️ FAIL:web 与 redis 不在同一节点"
fi

echo ""
echo "=== 实验2 完成 ==="