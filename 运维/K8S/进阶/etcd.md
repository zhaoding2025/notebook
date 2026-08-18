一、环境
[root@master ~]# kubectl get pods -n kube-system | grep etcd
[root@master ~]# kubectl exec -it etcd-master -n kube-system -- sh
使用服务证书
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key

验证连接
etcdctl endpoint health -w table