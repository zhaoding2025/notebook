## 一、PV & PVC使用
# 1.创建pv
[root@master pv]# cat nginx-pv.yml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nginx-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  nfs:
    server: 172.16.96.100
    path: "/volume-k8s/nginx/data"
[root@master pv]# kubectl apply -f nginx-pv.yml 
# 2.创建pvc
[root@master pv]# cat nginx-pvc.yml 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-pvc-data
  namespace: test
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
[root@master pv]# kubectl apply -f nginx-pvc.yml 
# 3.查看pvc信息
[root@master pv]# kubectl get pvc -n test
NAME             STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
nginx-pvc-data   Bound    nginx-pv   1Gi        RWO                           12s
# 4.创建pod
[root@master pv]# cat pvc-deployment.yml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pvc-deployment
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
      - name: data
        persistentVolumeClaim:
          claimName: nginx-pvc-data
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
        - name: data
          mountPath: /data






