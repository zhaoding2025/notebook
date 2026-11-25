# 案例一：pi
# 查看job
kubectl get jobs pi
# 看这个job对应的pod
kubectl get pods -l job-name=pi
# 查看pod输出（拿到π的结果）
kubectl logs <pod名称>

# 案例二：cron
# 查看 cronjob：
kubectl get cronjob
# 查看 job：
kubectl get jobs
# 查看 pod 日志：
kubectl logs <pod-name>

# 案例三：hello
# 找到这个job对应的pod
kubectl get pods -l job-name=hello
# 查看pod输出日志
kubectl logs <pod名称>
# 清理这个已经完成很久的job
kubectl delete job hello