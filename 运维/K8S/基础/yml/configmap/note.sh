1. 查看nginx default配置文件
root@nginx-deployment-9594ff8d7-g6rkq:/# egrep -v "#|^$" /etc/nginx/conf.d/default.conf 
server {
    listen       80;
    listen  [::]:80;
    server_name  localhost;
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}

2. 创建configmap
[root@master configmap]# kubectl create configmap my-config --from-file=/root/apr/configmap/default.conf -n test   # 创建方式一：
[root@master configmap]# kubectl create configmap my-config --from-file=config=/root/apr/configmap/default.conf -n test   # 创建方式二：指定key
[root@master configmap]# kubectl get cm -n test                     # 查看cm
[root@master configmap]# kubectl delete cm nginx-config -n test     # 删除cm
[root@master configmap]# kubectl edit cm my-config -n test          # 编辑cm
[root@master configmap]# kubectl get cm my-config -n test -o yaml > nginx-config.yml        # 
[root@master configmap]# kubectl apply -f nginx-config.yml 
[root@master configmap]# kubectl apply -f nginx-deployment.yml 
[root@master configmap]# cat nginx-config.yml 
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: test
data:
  ngx.conf: |
    server {
        listen       80;
        listen  [::]:80;
        server_name  localhost;
        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
[root@master configmap]# cat nginx-deployment.yml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
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
      labels:
        app: nginx
    spec:
      volumes:
      - name: config
        configMap:
          name: nginx-config
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/
[root@master configmap]# kubectl exec -it nginx-deployment-cb75bcdbb-n9qmb -n test -- ls /etc/nginx/conf.d/
ngx.conf

案例二：修改主配置文件: nginx.conf     通过subpath
1.获取nginx.conf
[root@master subpath]# egrep -v "#|^$" nginx.conf 
user  nginx;
worker_processes  auto;
error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    keepalive_timeout  65;
    include /etc/nginx/conf.d/*.conf;
}
2.创建configmap
[root@master subpath]# kubectl create configmap nginx-conf --from-file=/root/apr/configmap/subpath/nginx.conf -n test
configmap/nginx-conf created
[root@master subpath]# kubectl get cm nginx-conf -n test -o yaml
apiVersion: v1
data:
  nginx.conf: |
    user  nginx;
    worker_processes  auto;
    error_log  /var/log/nginx/error.log notice;
    pid        /var/run/nginx.pid;
    events {
        worker_connections  1024;
    }
    http {
        include       /etc/nginx/mime.types;
        default_type  application/octet-stream;
        log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                          '$status $body_bytes_sent "$http_referer" '
                          '"$http_user_agent" "$http_x_forwarded_for"';
        access_log  /var/log/nginx/access.log  main;
        sendfile        on;
        keepalive_timeout  65;
        include /etc/nginx/conf.d/*.conf;
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2026-04-29T11:34:07Z"
  name: nginx-conf
  namespace: test
  resourceVersion: "1781006"
  uid: 4c3f1914-eab5-42b5-ac4b-2f371037cfd3
3.创建configmap配置文件
[root@master subpath]# kubectl get cm nginx-conf -n test -o yaml > nginx-conf.yaml
4.创建nginx-config deployment中有两个configmap
[root@master subpath]# cat nginx-config.yml 
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: test
data:
  ngx.conf: |
    server {
        listen       8080;
        server_name  localhost;
        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
[root@master subpath]# kubectl apply -f nginx-config.yml
5.修改并查看configmap文件
[root@master subpath]# cat nginx-conf.yaml 
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
  namespace: test
data:
  nginx.conf: |
    user  nginx;
    worker_processes  auto;
    error_log  /var/log/nginx/error.log notice;
    pid        /var/run/nginx.pid;
    events {
        worker_connections  1024;
    }
    http {
        include       /etc/nginx/mime.types;
        default_type  application/octet-stream;
        log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                          '$status $body_bytes_sent "$http_referer" '
                          '"$http_user_agent" "$http_x_forwarded_for"';
        access_log  /var/log/nginx/access.log  main;
        sendfile        on;
        keepalive_timeout  65;
        include /etc/nginx/conf.d/*.conf;
    }
6.通过yaml配置文件创建configmap
[root@master subpath]# kubectl apply -f nginx-conf.yaml 
7.创建deployment配置文件
[root@master subpath]# cat nginx-deployment.yml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
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
      - name: conf
        configMap:
          name: nginx-conf
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/
        - name: conf
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
8.创建deployment
[root@master subpath]# kubectl apply -f nginx-deployment.yml 
9.查看pod
[root@master subpath]# kubectl exec -it -n test  nginx-deployment-5659f76447-jcdkq -- ls /etc/nginx/
10.验证及更新
a.修改nginx-conf.yaml文件内容
[root@master subpath]# vi nginx-conf.yaml 
[root@master subpath]# kubectl apply -f nginx-conf.yaml 
b.修改nginx-deployment.yaml文件内容
[root@master subpath]# vi nginx-deployment.yml 
template:
    metadata:
      annotations:
        update: 2026-05-06:12:00    # 修改注解
[root@master subpath]# kubectl apply -f nginx-deployment.yml 
[root@master subpath]# kubectl exec -it -n test nginx-deployment-7b6bcf7566-n6kwt -- cat /etc/nginx/nginx.conf


案例三 通过ConfigMap存储MySQL root密码
1.创面mysql configmap
[root@master mysql]# cat mysql-root-passwd-cm.yml 
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-root-passwd
  namespace: test
data:
  passwd: "Admin123..."
  database: "backup"
[root@master mysql]# kubectl apply -f mysql-root-passwd-cm.yml 
2.创建mysql deployment
[root@master mysql]# cat mysql-deployment.yml 
apiVersion: apps/v1         # 控制器对象版本
kind: Deployment            # 控制器类型
metadata:                   # 控制器元数据
  name: mysql            # 控制器名称
  namespace: test           # 控制器的名称空间
spec:                       # 控制器详细配置信息
  replicas: 1               # 定义Pod的副本数
  selector:                 # 标签选择器（根据标签选择管理的Pod）
    matchExpressions:       # 定义标签的类型
    - key: db              # 标签名称         - 代表列表类型
      operator: In          # In表示包含
      values:               # 定义标签的值
      - mysql               # 值名称
  template:                 # Pod模版（母版）用于定义Pod配置
    metadata:               # Pod模版元数据（Pod元数据）
      labels:               # 定义Pod标签
        db: mysql          # 标签（要与selector中定义的标签一致）
    spec:                   # 定义Pod详细配置
      nodeSelector:
        selector: node1
      containers:           # 容器列表
      - name: mysql         # 容器名称
        image: mysql:8.0 # 容器镜像
        ports:              # 容器端口
        - containerPort: 3306 # 端口号
        env:                # 定义变量
        - name: TZ          # 变量名称
          value: "Asia/Shanghai"  # 变量值
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: mysql-root-passwd
              key: passwd
        - name: MYSQL_DATABASE
          valueFrom: 
            configMapKeyRef:
              name: mysql-root-passwd
              key: database
        - name: MYSQL_USER
          value: test
[root@master mysql]# kubectl apply -f mysql-deployment.yml
3.验证
[root@master mysql]# kubectl exec -it -n test mysql-7f6b9d9978-sfkqs -- /bin/bash 
bash-5.1# env






        
