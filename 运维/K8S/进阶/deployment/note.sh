deployment常用命令:

kubectl apply -f deployment.yaml        # 创建Deployment
kubectl get deployment                  # 查看Deployment
kubectl describe deployment nginx       # 查看详细信息
kubectl get rs                          # 查看replicaSet
kubectl get pods                        # 查看pod
kubectl scale deploy nginx --replicas=10    # 扩容
kubectl rollout status deployment nginx     # 查看更新状态
kubectl rollout history deployment nginx    # 查看更新历史
kubectl rollout undo deployment nginx       # 回滚
kubectl delete deployment nginx             # 删除Deployment


