Kubernetes的安全配置资源Secret
主要内容:
    kubernetes常用配置组件介绍
    secret介绍
    secret命令式创建
    secret声明式创建
    secret引用
    generic案例
    TLS案例
    Docker-registry案例


1 Secret 介绍
1.1 Kubernetes 配置组件简介
# https://kubernetes.io/zh-cn/docs/concepts/configuration/
# Configmap
# Configmap 是 Kubernetes 集群中非常重要的一种配置管理资源对象。借助于 ConfigMap API 向 pod 中的容器中注入配置信息的机制。
# ConfigMap 不仅仅可以保存环境变量或命令行参数等属性，也可以用来保存整个配置文件或者 JSON 格式的文件。
# 各种配置属性和数据以 k/v 或嵌套 k/v 样式存在到 Configmap 中
# 注意：所有的配置信息都是以明文的方式来进行保存
# Secret
# Kubernetes 集群中，有一些配置属性信息是非常敏感的，所以这些信息在传递的过程中，是不希望其他人能够看到的
# Kubernetes 提供了一种加密场景中的配置管理资源对象 Secret。
# 它在进行数据传输之前，会对数据进行编码，在数据获取的时候，会对数据进行解码。从而保证整个数据传输过程的安全。
# 注意：这些数据是根据不同的应用场景，采用不同的加密机制。
# downwardAPI
# downwardAPI 为运行在 pod 中的应用容器提供了一种反向引用。让容器中的应用程序了解所处 pod 或 Node 的一些基础属性信息。
# 从严格意义上来说，downwardAPI 不是存储卷，它自身就存在。
# 相较于 configmap、secret 等资源对象需要创建后才能使用，而 downwardAPI 引用的是 Pod 自身的运行环境信息，这些信息在 Pod 启动的时候就存在。

1.2 Secret 介绍
# https://kubernetes.io/zh-cn/docs/concepts/configuration/secret/
# https://kubernetes.io/zh-cn/docs/tasks/configmap-secret/
# Secret 和 Configmap 相似也可以提供配置数据，但主要用于为 Pod 提供敏感需要加密的信息
# Secret 主要用于存储密码、OAuth 令牌和 SSH 密钥等敏感信息，这些敏感信息采用 base64 编码保存，相对明文存储更安全
# 相比于直接将敏感数据配置在 Pod 的定义或者镜像中，Secret 提供了更加安全的机制，将需要共享的数据进行加密，防止数据泄露。
# Secret 的对象需要单独定义并创建，通常以数据卷的形式挂载到 Pod 中，Secret 的数据将以文件的形式保存，容器通过读取文件可以获取需要的数据。
# Secret volume 是通过 tmpfs（内存文件系统）实现的，所以这种类型的 volume 不是永久存储的。
# 每个 Secret 的数据不能超过 1MB, 支持通过资源限额控制每个名称空间的 Secret 的数量

# Secret 属于名称空间级别
# Secret 分成以下常见大的分类
#
# 类型         解析
# generic      通用类型，基于base64编码用来存储密码，公钥等。常见的子类型有：Opaque,kubernetes.io/service-account-token,kubernetes.io/basic-auth,kubernetes.io/ssh-auth,bootstrap.kubernetes.io/token,kubernetes.io/rbd
# tls          专门用于保存tls/ssl用到证书和配对的私钥,常见的子类型:kubernetes.io/tls
# docker-registry 专用于让kubelet启动Pod时从私有镜像仓库pull镜像时，首先认证到仓库Registry时使用
#                 常见的子类型:kubernetes.io/dockerconfig,kubernetes.io/dockerconfigjson
#
# Secret 细化为的子类型(Type)
#
# Builtin Type                          说明
# opaque                                arbitrary user-defined data
# kubernetes.io/service-account-token    service account token
# kubernetes.io/basic-auth               credentials for basic authentication
# kubernetes.io/ssh-auth                credentials for SSH authentication
# bootstrap.kubernetes.io/token         bootstrap token data 初始化
# kubernetes.io/tls                     data for a TLS client or server
# kubernetes.io/dockerconfigjson        serialized ~/.docker/config.json file 新版
# kubernetes.io/dockercfg               serialized ~/.dockercfg file 旧版

# 注意:
# 不同类型的Secret, 在定义时支持使用的标准字段也有所不同
# 例如: ssh-auth类型的Secret应该使用ssh-privatekey, 而basic-auth类型的Secret则需要使用username和password等。
# 另外也可能存在一些特殊的类型, 用于支撑第三方需求, 例如: ceph的keyring信息使用的kubernetes.io/rbd等
#
# Secret 创建方式
# • 手动创建: 用户自行创建的Secret 常用来存储用户私有的一些信息
# • 自动创建: 集群自动创建的Secret 用来作为集群中各个组件之间通信的身份校验使用
#
# 范例: Secret 大的类别
[root@master1 ~]#kubectl create secret -h
Create a secret using specified subcommand.

Available Commands:
  docker-registry   创建一个给 Docker registry 使用的 Secret
  generic           Create a secret from a local file, directory, or literal value
  tls               创建一个 TLS secret

Usage:
  kubectl create secret [flags] [options]

Use "kubectl <command> --help" for more information about a given command.
Use "kubectl options" for a list of global command-line options (applies to all commands).

# 范例: 查看 secret
[root@master1 ~]#kubectl get secrets -A
NAMESPACE       NAME                          TYPE                                  DATA   AGE
ingress-nginx   ingress-nginx-admission       Opaque                                3      3d17h
kube-system     bootstrap-token-n44d75        bootstrap.kubernetes.io/token         6      47d

[root@master1 ~]#kubectl get secrets -n ingress-nginx ingress-nginx-admission -o yaml

# 2 Secret 命令式创建
# 流程图文字说明：
# /Users/macbook/INF/notebook/运维/K8S/进阶/secret/img/secret创建.png
# 1.Creation request
# 2.Secret is created and stored in etcd
# 3.Consume secret request
# 4.Pod consumes secret
#
# 官方说明
# https://kubernetes.io/zh-cn/docs/tasks/configmap-secret/managing-secret-using-kubectl/
#
# 帮助信息
[root@master ~]# kubectl create secret -h
Create a secret using specified subcommand.

Available Commands:
  docker-registry  #创建一个给 Docker registry 使用的 secret
  generic          #从本地 file, directory 或者 literal value 创建一个 secret
  tls              #创建一个 TLS secret

Usage:
  kubectl create secret [flags] [options]

# 命令格式
#generic类型
kubectl create secret generic NAME [--type=string] [--from-file=[key=]source] [--from-literal=key1=value1]

--from-literal=key1=value1        #以命令行设置键值对的方式配置数据
--from-env-file=/PATH/TO/FILE     #以环境变量专用文件的方式配置数据
--from-file=[key=]/PATH/TO/FILE   #以配置文件的方式创建配置数据，如不指定key，FILE名称为key名
--from-file=/PATH/TO/DIR          #以配置文件所在目录的方式创建配置数据

#该命令中的--type选项进行定义除了后面docker-registry和tls命令之外的其它子类型，有些类型有key的特定要求
#注意 如果value中有特殊字符，比如:$ , \ , * , = , !等，需要用\进行转义或用单引号''引起来

#tls类型
kubectl create secret tls NAME --cert=/path/file --key=/path/file
#其保存cert文件内容的key名称不能指定自动为tls.crt，而保存private key的key不能指定自动为tls.key

#docker-registry类型
#方式1:基于用户名和密码方式实现
kubectl create secret docker-registry NAME --docker-username=user --docker-password=password --docker-email=email [--docker-server=string] [--from-file=[key=]source]

#方式2:基于dockerconfig文件方式实现
kubectl create secret docker-registry KEYNAME --from-file=.dockerconfigjson=path/to/.docker/config.json
#从已有的json格式的文件加载生成的就是dockerconfigjson类型，命令行直接生成的也是该类型

# 范例:
#创建generic类型
kubectl create secret generic my-secret-generic --from-file=/path/bar
kubectl create secret generic my-secret-generic --from-file=ssh-privatekey=~/.ssh/id_rsa --from-file=ssh-publickey=~/.ssh/id_rsa.pub
kubectl create secret generic my-secret-generic --from-literal=username=admin --from-literal=password=123456
kubectl create secret generic my-secret-generic --from-env-file=path/to/bar.env

#创建tls类型
kubectl create secret tls my-secret-tls --cert=certs/wang.org.cert --key=certs/wang.org.key

#创建docker-registry类型
#参考示例: https://Kubernetesmeetup.github.io/docs/tasks/configure-pod-container/pull-image-private-registry/
#基于私有仓库的用户名和密码
kubectl create secret docker-registry my-secret-docker-registry --docker-server=harbor.wang.org --docker-username=admin --docker-password=123456 --docker-email=29308620@qq.com

#先登录并认证到目标仓库server上，认证凭据自动保存在dockercfg文件中,基于dockerconfig文件实现
kubectl create secret docker-registry dockerharbor-auth --from-file=.dockerconfigjson=/root/.docker/config.json

kubectl create secret generic dockerharbor-auth --type='kubernetes.io/dockerconfigjson' --from-file=.dockerconfigjson=/root/.docker/config.json

# 3 Secret 声明式创建
# Secret 数据存放在data或stringData字段,其中data字段中的Key/value必须使用base64编码存放,而stringData使用明文存放
# Secret 资源的元数据：除了name, namespace之外，常用的还有labels, annotations
# • annotation的名称遵循类似于labels的名称命名格式，但其数据长度不受限制
# • 它不能用于被标签选择器作为筛选条件; 但常用于为那些仍处于Beta阶段的应用程序提供临时的配置接口
# • 管理命令： kubectl annotate TYPE/NAME KEY=VALUE

# 范例: 查看 Secret 字段说明
[root@master1 ~]#kubectl explain secret


# 4 Secret 引用
# /Users/macbook/INF/notebook/运维/K8S/进阶/secret/img/secret引用.png

Secret资源在Pod中引用的方式有三种
# • 环境变量
# 引用Secret对象上特定的key，以valueFrom赋值给Pod上指定的环境变量
# 在Pod上使用envFrom一次性导入Secret对象上的所有key-value，key(也可以统一附加特定前缀)即为环境变量名,value自动成为相应的变量值
# 注意：容器很可能会将环境变量打印到日志中,基于安全考虑不建议以环境变量方式引用Secret中的敏感数据

# • secret卷
# 在Pod上将Secret对象引用为存储卷，而后整体由容器mount至某个目录下,其中key名称转为文件名，value的值转为相应的文件内容
# 在Pod上定义Secret卷时，也可以仅引用其中的指定的部分key，而后由容器mount至目录下

# • 拉取镜像
# 在Pod 上使用 imagePullSecrets 拉取私有仓库镜像使用
# Pod引用Secret的方式：pods.spec.imagePullSecrets

# 5 Generic 案例
# 官方说明
# https://kubernetes.io/zh-cn/docs/tasks/configmap-secret/managing-secret-using-config-file/

# generic主要用于实现用户名和密码的加密保存
# 注意: generic加密保存要注意换行问题 \n

# 5.1 范例: Base64 编码数据
#将数据转换成base64编码,注意:需要加-n选项去掉换行符
[root@master1 ~]#echo -n 'admin' | base64
YWRtaW4=
[root@master1 ~]#echo -n 'password' | base64
cGFzc3dvcmQ=

#清单文件
[root@master1 yaml]#cat storage-secret-Opaque-data.yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-data
  namespace: default
type: Opaque
data:                     #data表示必须以base64编码存放,stringData表示明文存放数据
  user: YWRtaW4=
  password: cGFzc3dvcmQ=

#应用
[root@master1 yaml]#kubectl apply -f storage-secret-Opaque-data.yaml

[root@master1 ~]#kubectl get secrets
NAME          TYPE     DATA  AGE
secret-data   Opaque   2     5m5s
# 查看
[root@master1 ~]#kubectl get secrets secret-data -o yaml
#如果安装etcdctl工具,可以看到secret实际保存在etcd中
[root@master1 ~]#etcdctl get / --keys-only --prefix |grep secret-data
/registry/secrets/default/secret-data

#查看secret内容
[root@master1 ~]#etcdctl get /registry/secrets/default/secret-data

#删除
[root@master1 ~]#kubectl delete secrets secret-data

# 5.2 范例: stringData 明文数据
#清单文件
[root@master1 yaml]#cat storage-secret-Opaque-stringData.yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-stringdata
  namespace: default
type: Opaque
stringData:                    #stringData表示明文存放数据,data表示必须以base64编码存放
  user: 'admin'
  password: 'password'
#应用文件
[root@master1 yaml]#kubectl apply -f storage-secret-Opaque-stringData.yaml
#查看
[root@master1 ~]#kubectl get secrets
#查看
[root@master1 ~]#kubectl get secrets secret-stringdata -o yaml
apiVersion: v1
data:
  password: cGFzc3dvcmQ=  #此处显示base64编码形式
  user: YWRtaW4=
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Secret","metadata":{"annotations":{},"name":"secret-stringdata","namespace":"default"},"stringData":{"password":"password","user":"admin"},"type":"Opaque"}
  creationTimestamp: "2021-09-27T10:22:29Z"
  name: secret-stringdata
  namespace: default
  resourceVersion: "546179"
  uid: 03b3e308-43ff-4f8f-9ac4-a41589272664
type: Opaque

#删除
[root@master1 yaml]#kubectl delete -f storage-secret-Opaque-stringData.yaml


5.3 范例: Secret 通过环境变量为提供MySQL环境初始化的密码信息

#生成密码的base64编码
[root@master1 ~]#echo -n root | base64
cm9vdA==
[root@master1 ~]#echo -n 123456 | base64
MTIzNDU2

#清单文件 secret 通过环境为提供MySQL环境初始化的密码信息 但很不安全

[root@master secret]# cat storage-secret-mysql-init.yaml 
apiVersion: v1
kind: Secret
metadata:
  name: secret-mysql
type: Opaque            # 也可以用Opaque类型
#type: kubernetes.io/basic-auth      
data:
  username: cm9vdAo=        # key名称:username
  password: MTIzNDU2        # key名称:password

---
apiVersion: v1
kind: Pod
metadata:
  name: pod-secret-mysql-init
spec:
  containers:
  - name: mysql
    image: mysql:8.0
    env:
    - name: MYSQL_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: secret-mysql
          key: password

[root@master secret]# kubectl get pod
# 可以通过环境变量查看到密码 很不安全  
[root@master secret]# kubectl exec pod-secret-mysql-init -- env
[root@master secret]# kubectl exec pod-secret-mysql-init -- mysql -uroot -p123456 -e status


# 6 TLS 案例
# TLS类型的Secret主要用于对https场景的证书和密钥文件来进行加密传输
# 下面案例实现一个基于https的nginx的web服务

# 6.1 准备Nginx配置文件

#nginx主配置文件 myserver.conf
[root@master1 nginx-ssl-conf.d]#ls
myserver.conf  myserver-gzip.cfg  myserver-status.cfg
[root@master1 nginx-ssl-conf.d]#cat myserver.conf
server {
    listen 80;
    server_name www.wang.org;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name www.wang.org;

    ssl_certificate /etc/nginx/certs/tls.crt;
    ssl_certificate_key /etc/nginx/certs/tls.key;

    ssl_session_timeout 5m;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
    ssl_prefer_server_ciphers on;

    include /etc/nginx/conf.d/myserver-*.cfg;

    location / {
        root /usr/share/nginx/html;
    }
}

#nginx的压缩配置文件:myserver-gzip.cfg
[root@master1 nginx-ssl-conf.d]#cat myserver-gzip.cfg
gzip on;
gzip_comp_level 5;
gzip_proxied    expired no-cache no-store private auth;
gzip_types text/plain text/css application/xml text/javascript;

#nginx的状态页配置文件myserver-status.cfg
[root@master1 nginx-ssl-conf.d]#cat myserver-status.cfg
location /status {
    stub_status on;
    access_log off;
}

# 6.2 创建配置文件对应的 Configmap
[root@master1 yaml]#kubectl create configmap cm-nginx-ssl-conf --from-file=nginx-ssl-conf.d/

[root@master1 ~]#kubectl get cm
NAME               DATA   AGE
cm-nginx-ssl-conf  3      15m
kube-root-ca.crt   1      4d15h

# 6.3 创建 TLS 证书文件

#生成私钥匙
[root@master1 yaml]#openssl genrsa -out nginx-certs/wang.org.key 2048

#生成自签名证书
[root@master1 yaml]#openssl req -new -x509 -key nginx-certs/wang.org.key -days 3650 -out nginx-certs/wang.org.crt -subj /C=CN/ST=Beijing/L=Beijing/O=DevOps/CN=www.wang.org
#注意:CN指向的域名必须是nginx配置中使用的域名信息

#查看文件
[root@master1 yaml]#ls nginx-certs/
wang.org.crt  wang.org.key


# 6.4 基于 TLS 证书文件创建对应的 Secret
[root@master1 yaml]#kubectl create secret tls secret-nginx-ssl --cert=nginx-certs/wang.org.crt --key=nginx-certs/wang.org.key

#查看结果
[root@master1 ~]#kubectl get secrets
NAME             TYPE                DATA   AGE
secret-nginx-ssl kubernetes.io/tls   2      2m53s

#查看内容
[root@master1 ~]#kubectl get secrets secret-nginx-ssl -o yaml


# 6.5 创建引用Secret资源配置文件
#创建资源配置文件
[root@master1 yaml]#cat storage-secret-nginx-ssl.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-nginx-ssl
  namespace: default
spec:
  volumes:
  - name: nginx-certs
    secret:
      secretName: secret-nginx-ssl
  - name: nginx-confs
    configMap:
      name: cm-nginx-ssl-conf
      optional: false
  containers:
  - image: wangxiaochun/nginx:1.20.0
    name: nginx-ssl-server
    volumeMounts:
    - name: nginx-certs
      mountPath: /etc/nginx/certs/      # 其保存cert文件自动命名为tls.crt,而保存private key文件的自动命名为tls.key
      readOnly: true
    - name: nginx-confs
      mountPath: /etc/nginx/conf.d/
      readOnly: true

#创建pod
[root@master1 yaml]#kubectl apply -f storage-secret-nginx-ssl.yaml

# 6.6 验证结果
[root@master1 ~]#kubectl get pod pod-nginx-ssl -o wide
NAME           READY   STATUS    RESTARTS   AGE     IP           NODE           NOMINATED NODE   READINESS GATES
pod-nginx-ssl  1/1     Running   0          3m33s   172.16.3.13  node3.wang.org  <none>           <none>

#查看生成的证书文件，表示为关联时间戳目录下的两个双层软链接文件tls.crt和tls.key，保存证书的原始文件，而非base64格式
[root@master1 ~]#kubectl exec -it pod-nginx-ssl -- ls -l /etc/nginx/certs/
total 0
lrwxrwxrwx 1 root root 14 Mar 27 06:21 tls.crt -> ..data/tls.crt
lrwxrwxrwx 1 root root 14 Mar 27 06:21 tls.key -> ..data/tls.key

[root@master1 ~]#curl -I http://172.16.3.13
[root@master1 ~]#curl -Lkv http://172.16.3.13









