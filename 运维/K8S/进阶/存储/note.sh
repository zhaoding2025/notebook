## 一、本地存储HostPath
# 1.创建hostpath
[root@master storage]# vi hostpath-deployment.yml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hostpath-deployment
  namespace: test
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      annotations:
        update: 2026-0428
      labels:
        app: nginx
    spec:
      volumes:
      - name: config
        configMap:
          name: nginx-config
      - name: html
        hostPath:
          path: /html
          type: DirectoryOrCreate
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/
        - name: html
          mountPath: /usr/share/nginx/html
# 2.部署
[root@master storage]# kubectl apply -f hostpath-deployment.yml 
# 3.获取pod
[root@master storage]# kubectl get pod -n test -o wide
NAME                                   READY   STATUS    RESTARTS   AGE   IP               NODE    NOMINATED NODE   READINESS GATES
hostpath-deployment-585795db67-8mhkm   1/1     Running   0          16s   172.18.166.182   node1   <none>           <none>
hostpath-deployment-585795db67-x8sj2   1/1     Running   0          16s   172.18.104.63    node2   <none>           <none>
# 4.访问
[root@master storage]# curl 172.18.166.182:8080
# 5.编写页面
# 在node1节点/home目录下编写index.html
# 6.再访问
[root@master storage]# curl 172.18.166.182:8080
# 7.删除pod
[root@master storage]# kubectl apply -f hostpath-deployment.yml 
# 8.node1节点 /html文件仍然存在
# 9.再部署
[root@master storage]# kubectl apply -f hostpath-deployment.yml 
# 10.再访问
[root@master storage]# curl 172.18.166.182:8080

## 二、网络存储NFS
[root@master storage]# cat nfs-deployment.yml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-deployment
  namespace: test
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      annotations:
        update: 2026-05-07
      labels:
        app: nginx
    spec:
      volumes:
      - name: config
        configMap:
          name: nginx-config
      - name: html
        nfs:
          server: 172.16.96.100
          path: /volume-k8s/nginx/html
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/
        - name: html
          mountPath: /usr/share/nginx/html















