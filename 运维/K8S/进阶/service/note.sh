主要内容
Kubernetes 的服务发现和负载均衡机制
Kubernetes 的 Service 工作机制
Kubernetes 的 Service 工作模式
Kubernetes 的 Service 类型
Kubernetes 的 Service 实现和管理方法
Kubernetes 的 Service 实战案例


1 Kubernetes 的服务发现和负载均衡
# Kubernetes 集群中应用服务由 Pod 资源提供，由于每个 Pod 都有独立的 IP 地址，而随着 Pod 的大量的动态创建和销毁操作后，导致 Pod 的 IP 很有可能发生了变化，在集群的多个 Pod 应用该如何相互通信呢？
# Kubernetes 集群就为提供了这样的一个对象 Service，它定义了一组 Pod 的逻辑集合和一个用于访问它们的策略，它可以基于标签的方式自动找到对应的 pod 应用，而无需关心 pod 的 IP 地址变化与否，从而实现了类似负载均衡的效果
# Service 本质上就是一个四层的反向代理，集群外的客户端可以通过主机节点网络 --> service 网络 -->Pod 网络 --> 容器应用，最终实现访问
# Service 资源在 master 端的 Controller 组件中，由 Service Controller 来进行统一管理。
# service 是 Kubernetes 里最核心的资源对象之一，每一个 Service 一般都对应一个完整的业务服务
# Kubernetes 给 Service 分配一个全局唯一的虚拟 IP 地址 --cluster IP，它不存在任何网络设备上
# Pod 是工作在不同的节点上，而所有集群节点上都有一个 kube-proxy 组件，它就是一个软件负载均衡器，在内部有一套专有的负载均衡与会话保持机制，可以达到接收到所有对 Service 请求，进而通过 RANDOM 算法调度转发到后端的某个具体的 Pod 实例上来处理该请求。
# kube-proxy 本质就是 Service Controller 位于各节点上的 agent。
# Service 是基于名称空间的资源

Service 功能
# 服务发现：利用标签选择器，在同一个 namespace 中筛选符合的条件的 Pod, 发现一组提供了相同服务的 Pod
# 负载均衡: Service 作为流量入口和负载均衡器，其入口为 ClusterIP, 这组筛选出的 Pod 的 IP 地址，将作为该 Service 的后端服务器
# 名称解析：利用 Cluster DNS, 为该组 Pod 所代表的服务提供一个名称，在 DNS 中 对于每个 Service, 自动生成一个 A、PTR 和 SRV 记录

Service vs Endpoint
# 当创建 Service 资源的时候，最重要的就是为 Service 指定能够提供服务的标签选择器
# Service Controller 就会根据标签选择器创建一个同名的 Endpoint 资源对象，新版为 endpointslices 资源
# Endpoint Controller 使用 Endpoint 的标签选择器 (继承自 Service 标签选择器), 筛选符合条件 (包括符合标签选择器条件和处于 Ready 状态) 的 pod 资源
# Endpoint Controller 将符合要求的 pod 资源绑定到 Endpoint 上，并告知给 Service 资源谁可以正常提供服务
# Service 会自动获取一个固定的 cluster IP 向外提供由 Endpoint 提供的服务资源
# 所以 Service 其实就是为动态的一组 pod 资源对象提供一个固定的访问入口。即 Service 实现了服务发现功能

Service的访问流程 
# img/访问流程

2 Service工作机制
2.1 Service实现机制
# img/实现机制
# Service 作为一个资源对象，它会在 API Service 服务中定义出来的。
# 在创建任何存在标签选择器的 Service 时，都会被自动创建一个同名的 Endpoints 资源，Endpoints 对象会使用 Label Selector 自动发现后端端点，并各端点的 IP 配置为可用地址列表的元素
# Service Controller 触发每个节点上的 kube-proxy，由 kube-proxy 实时的转换为本地的 ipvs/iptables 规则。
# 如果 Pod 客户端向 Service 发出请求，客户端向内核发出请求，根据 ipvs 或 iptables 规则，匹配目标 service
# 如果 service 匹配，会返回当前 service 随对应的后端 endpoint 有哪些
# iptables 或 ipvs 会根据情况挑选一个合适的 endpoint 地址
#   如果 endpoint 是本机上的，则会转发给本机的 endpoint
#   如果 endpoint 是其他主机上的，则转发给其他主机上的 endpoint

2.2 代理模型
# 一个 Service 对象最终体现为工作节点上的一些 iptables 或 ipvs 规则，这些规则是由 kube-proxy 进行实时生成和维护
# 针对某一特定服务，如何将集群中的每个节点都变成其均衡器：
#   在每个节点上运行一个 kube-proxy，由 kube-proxy 注册监视 API Server 的 Service 资源；创建、修改和删除
#   将 Service 的定义，转为本地负载均衡功能的落地实现
# kube-proxy 将请求代理至相应端点的实现方式有四种：
#   userspace
#   iptables
#   ipvs
#   kernelspace: 仅 Windows 使用
# 这些方法的目的是：kube-proxy 如何确保 service 能在每个节点实现并正常工作
# 注意：一个集群只能选择使用一种 Mode, 即集群中所有节点要使用相同的方式
2.2.1 Userspace
# userspace 模型是 Kubernetes 最早的一种工作模型，从 kubernetes v1.1 版本之前使用，在 kubernetes v1.2 以后淘汰
# userspace 模式早由 Kube-proxy 自己来负责将 service 策略转换成 iptables 规则，这些规则仅做请求的拦截，而不对请求进行调度处理。
工作机制
# img/userspace工作机制
# 该模型中，请求流量到达内核空间后，由套接字送往用户空间的 kube-proxy，再由它送回内核空间，并调度至后端 Pod。
# 因为涉及到来回转发，效率低下

2.2.2 Iptables
# Iptables 模式在 kubernetes v1.1 版本开始使用。kubernetes v1.2 版本 iptables 成为默认代理模式
# 为 Service 创建 iptables 规则，直接捕获到达 ClusterIP 和 Port 的流量，并重定向至当前 Service 的后端。对每个 Endpoints 对象，Service 资源会为其创建 iptables 规则并关联至挑选的后端 Pod 资源
工作机制   
# img/iptables工作机制
#   kube-proxy 启动时候，监听 service 定义，将 service 定义转换成 iptables 拦截和调度规则
#   Pod 向外发起请求
#   内核空间的 iptables 拦截请求
#   iptables 规则使用自身的调度规则实现目标转发，借助于内核功能，将请求转发出去
# 优点：性能比 userspace 更加高效和可靠
# 缺点:
#   不会在后端 Pod 无响应时自动重定向，而 userspace 可以
#   一个 service 一般对应生成 20 条左右 iptables 规则，因此如果是中等规模的 Kubernetes 集群 (service 有几百个) 能够承受，但是大规模的 Kubernetes 集群 (service 有几千个) 维护达几万条规则，性能较差
#   集群节点数少于 50 个，服务数量少于 2000 个，可以使用此模式，否则使用 IPVS 模式性能更好
#   kube-proxy 在 iptables 模式下的复杂度程度为 O (n)

2.2.3 IPVS
# kubernetes v1.8 引入 ipvs 代理模块
# kubernetes v1.9 ipvs 代理模块成为 beta 版本
# kubernetes v1.11 ipvs 代理模式 GA,成为默认设置
# 请求流量的调度功能由ipvs实现，余下的其他功能仍由iptables完成
# ipvs流量转发速度快，规则同步性能好，且支持众多调度算法，如rr/lc/dh/sh/sed/nq等
工作机制
# img/ipvs工作机制

范例: kubeadm方式将默认的iptables模式修改为IPVS模式
#查看当前模式,默认为iptables
[root@master1 ~]# curl 127.0.0.1:10249/proxyMode
# iptables
[root@master1 ~]# apt install ipvsadm
[root@master1 ~]# ipvsadm -Ln
# IP Virtual Server version 1.2.1 (size=4096)
# Prot LocalAddress:Port Scheduler Flags
#   -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
[root@master1 ~]# kubectl edit configmap kube-proxy -n kube-system
# mode: "ipvs"    #修改此行,默认为""
#删除所有kube-proxy对应的Pod
[root@master1 ~]# kubectl delete pod -n kube-system -l k8s-app=kube-proxy
#查看Pod 自动创建
[root@master1 ~]# kubectl get pod -n kube-system -l k8s-app=kube-proxy
#验证结果
[root@master1 ~]# curl 127.0.0.1:10249/proxyMode
# ipvs
#每个节点都生成kube-ipvs0的虚拟网卡
[root@master1 ~]# ip a show kube-ipvs0
#再次查看出现IPVS规则
[root@master1 ~]# ipvsadm -Ln

# 3 Service 类型
对于Kubernetes 可以实现内部服务的自由通信(东西向通信),也可以将平台内部的服务发布到外部环境(南北向通信)

Service 有四种类型

# | 类型 | 解析 |
# | ---- | ---- |
# | ClusterIP | 为集群内部的客户端访问,包括节点和Pod等，外部网络无法访问<br/>In client --> clusterIP: ServicePort (Service) --> PodIP: PodPort |
# | NodePort | 本质上在ClusterIP模式基础上,再多了一层端口映射的封装<br/>&lt;NodeIP&gt;:&lt;NodePort&gt;对外部网络提供服务，
#                 默认随机端口范围 30000~32767,支持手动指定为固定端口<br/>NodePort是一个随机的端口，以防止端口冲突,在所有安装kube-proxy的节点上都会打开此相同的端口<br/>
#                 可通过访问ClusterIP实现集群内部访问,也可以通过NodeIP:NortPort的方式实现从集群外部至内部的访问<br/>Ex Client --> NodeIP:NodePort (Service) --> PodIP:PodPort |
# | LoadBalancer | 基于NodePort基础之上，使用集群外部的运营商负载均衡器方式实现对外提供服务<br/>底层是基于云运营商IaaS云创建一个Kubernetes云，
#                   同时该平台也支持LBaaS(Load Balance as a Service)产品服务<br/>Master 借助cloud-manager向 LBaaS 的管理API，请求动态创建一个软件LB,即支持向Kubernetes API Server 进行交互<br/>
#                   如果没有云服务,将无法获取EXTERNAL-IP,显示Pending状态,则降级为NodePort类型<br/>Ex Client --> LB_IP:LB_PORT --> NodeIP:NodePort(Service)--> PodIP:PodPort |
# | ExternalName | 当Kubernetes集群依赖集群外部服务时，需要通过externalName将外部主机引入到Kubernetes集群内部<br/>外部主机名以DNS方式解析为一个CNAME记录给Kubernetes集群的其他主机来使用<br/>
#                   这种Service既没有ClusterIP，也没有NodePort.而且依赖于内部的CoreDNS功能<br/>In client -->Cluster ServiceName --> CName --> External Service Name<br/>本方式的service没有selector,
#                   所以也不会创建同名的Endpoints资源对象<br/>示例:<br/>Service名称: MySQL服务内部域名 mysql.default.svc.cluster.local<br/>
#                   MySQL服务外部域名: mysql.wang.org<br/>In Client --> mysql.default.svc.cluster.local --> mysql.wang.org --> MYSQL IP |
4 Service 创建说明
# 对于Service的创建有两种方法：
# - 命令行方法
# - yaml文件方法
4.1 命令行方法
# http://docs.kubernetes.org.cn/564.html
# 基础语法
#创建命令1:
kubectl create service [flags] NAME [--tcp=port:targetPort] [--dry-run]

#作用：单独创建一个service服务
#flags 参数详解：
    # clusterip        Create a ClusterIP service.将集群专用服务接口
    # nodeport         创建一个 NodePort service.将集群内部服务以端口形式对外提供
    # loadbalancer     创建一个 LoadBalancer service.主要针对公有云服务
    # externalname     Create an ExternalName service.将集群外部服务引入集群内部

#创建命令2：
kubectl expose (-f FILENAME | TYPE NAME) [options]
#作用：针对一个已存在的deployment、pod、ReplicaSet等创建一个service
#参数详解：
  --cluster-ip=''        #设定对外的ClusterIP地址
  --name=''              #创建service对外的svc名称
  --port=''              #设定service对外的端口信息
  --target-port=''       #设定容器的端口
  --type=''              #设定类型，ClusterIP(默认)，NodePort，LoadBalancer,ExternalName

#查看命令：
kubectl get svc

#查看更多的信息
#查看更多信息的命令是一个通用的命令，一般常用两种方法显示更多的内容：yaml和json
#语法：
kubectl get 资源类型 [类型名称] -o yaml
kubectl get 资源类型 [类型名称] -o json

#yaml格式查看更多Service的信息
kubectl get svc <service-name> -o yaml

#注意：
# 在spec.ports的定义中，targetPort属性就是用来确定提供该服务的容器所暴露(EXPORT)的端口号，即通过targetPort端口来访问业务进程在容器。
# 默认情况下targetPort跟我们容器定义的port一致。

# 删除 service
kubectl delete svc <svc_name> [ -n <namespace>] [--all]

范例: kubectl create 创建 service

#简单示例
[root@master1 ~]#kubectl create service clusterip my-service1 --tcp=5678:80
[root@master1 ~]#kubectl create service clusterip my-service2 --clusterip="None"
[root@master1 ~]#kubectl create service clusterip my-service3 --clusterip="192.168.100.100" --tcp="999"

#查看效果
[root@master1 ~]#kubectl get svc
NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
kubernetes    ClusterIP   192.168.0.1      <none>        443/TCP    21h
my-service1   ClusterIP   192.168.146.176  <none>        5678/TCP   94s
my-service2   ClusterIP   None             <none>        <none>     58s
my-service3   ClusterIP   192.168.100.100  <none>        999/TCP    2s

#结果显示：
# cluster-ip是自动生成的，如果不再要，使用None
# 如果要自定义cluster-ip，必须附加 --tcp 参数，而且范围必须是集群初始化指定的集群，默认是 10.96.0.0/12

范例:
#两步实现
[root@master1 ~]#kubectl create deployment web --image=wangxiaochun/pod-test:v0.1
[root@master1 ~]#kubectl expose deployment web --name=web-service --port=80
[root@master1 ~]#kubectl expose deployment web --name=web-nodeport --port=999 --target-port='80' --type='NodePort'
[root@master1 ~]#kubectl get all
# NAME                          READY   STATUS    RESTARTS   AGE
# pod/web-65655fc68-cr2z7       1/1     Running   0          116s
# NAME                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
# service/kubernetes       ClusterIP   192.168.0.1      <none>        443/TCP        21h
# service/web-nodeport     NodePort    192.168.86.207   <none>        999:30959/TCP  3s
# service/web-service      ClusterIP   192.168.108.144  <none>        80/TCP         62s

[root@master1 ~]#curl 192.168.108.144
kubernetes pod-test v0.1!! ClientIP: 172.16.0.0, ServerName: web-65655fc68-cr2z7, ServerIP: 172.16.2.91!

#注意：只有NodePort类型才会在当前集群的所有主机上开放一个服务端口，这个服务端口是随机的
[root@master1 ~]#curl 192.168.86.207:999
kubernetes pod-test v0.1!! ClientIP: 172.16.0.0, ServerName: web-65655fc68-cr2z7, ServerIP: 172.16.2.91!
[root@master1 ~]#curl 10.0.0.101:30959
kubernetes pod-test v0.1!! ClientIP: 172.16.0.0, ServerName: web-65655fc68-cr2z7, ServerIP: 172.16.2.91!
[root@master1 ~]#curl 10.0.0.106:30959
kubernetes pod-test v0.1!! ClientIP: 172.16.2.1, ServerName: web-65655fc68-cr2z7, ServerIP: 172.16.2.91!

#清理还原环境
[root@master1 ~]#kubectl delete deployments.apps web
[root@master1 ~]#kubectl delete svc web-nodeport web-service

## 4.2 文件方式
# https://kubernetes.io/docs/concepts/services-networking/service/
# 语法解析
apiVersion: v1
kind: Service
metadata:
  name: ...
  namespace: ...
  labels:
    key1: value1
    key2: value2
spec:
  type: <string>                 # Service类型，默认为ClusterIP
  selector: <map[string]string>  # 指定用于过滤出service所代理的后端Pod的标签,只支持等值类型的标签选择器，多个条件内含“与”逻辑
  ports:                         # Service的端口对象列表
  - name: <string>               # 端口名称,需要保证唯一性
    protocol: <string>           # 协议，目前仅支持TCP、UDP和SCTP，默认为TCP
    port: <integer>              # Service的端口号
    targetPort: <string>         # 后端Pod的端口号或名称，名称需由Pod规范定义
    nodePort: <integer>          #节点端口号，仅适用NodePort和LoadBalancer类型,范围：30000-32768，建议不指定而由系统自动分配
  - name: <string>
      ......
  clusterIP:  <string>           # 指定Service的集群IP，建议不指定而由系统自动分配
  internalTrafficPolicy: <string> # 内部流量策略处理方式，Local表示由当前节点处理，Cluster表示向集群范围调度
  externalTrafficPolicy:  <string> # 外部流量策略处理方式，默认为Cluster，Local表示由当前节点处理，性能较好，但无负载均衡功能，且可以看到真实客户端IP，Cluster表示向集群范围调度，和Local相反，基于性能原因，生产更建议Local，此方式只支持type是NodePort和LoadBalancer类型
  loadBalancerIP:  <string>      # 外部负载均衡器使用的IP地址，仅适用于LoadBalancer,此字段未来可能被删除
  externalName: <string>         # 外部服务名称，该名称将作为Service的DNS CNAME值
  externalIPs  <[]string>        # 群集中的节点将接受此服务的流量的 IP 地址列表。这些IP不由 Kubernetes管理。用户负责确保流量到达具有此IP的节点。比如不属于Kubernetes系统的外部负载均衡器，注意：此IP和Type类型无关

5 Service 实战案例
## 5.1 ClusterIP Service 实现
### 5.1.1 范例: 单端口应用
#如果基于资源配置文件创建资源，依赖于后端pod的标签，才可以关联后端的资源
#准备多个后端pod对象
[root@master1 ~]#kubectl create deployment myweb --image=wangxiaochun/pod-test:v0.1 --replicas=3
#检查效果
[root@master1 ~]#kubectl get pod --show-labels -o wide
# NAME                         READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES   LABELS
# myweb-5df49fdd5-cd8b4        1/1     Running   0          18s   172.16.1.56  node2.wang.org <none>           <none>            app=myweb,pod-template-hash=5df49fdd5
# myweb-5df49fdd5-mvmrt        1/1     Running   0          18s   172.16.3.106 node1.wang.org <none>           <none>            app=myweb,pod-template-hash=5df49fdd5
# myweb-5df49fdd5-s2k5w        1/1     Running   0          18s   172.16.2.93  node3.wang.org <none>           <none>            app=myweb,pod-template-hash=5df49fdd5

# 创建service对象
[root@master1 yaml]# cat service-clusterip-test.yaml
kind: Service
apiVersion: v1
metadata:
  name: service-clusterip-test
spec:
  #type: ClusterIP          #默认为ClusterIP，此行可省略
  #clusterIP: 192.168.64.100 #可以手动指定IP，但一般都是系统自动指定而无需添加此行
  selector:
    app: myweb              #引用上面deployment的名称，同时也是Pod的Label中app的值,实现service代理指定Pod的功能
    #version: v1.0          #可以添加多个label与关系，即只过滤出有此处label匹配的pod，而非deployment的名称
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80

[root@master1 yaml]# kubectl apply -f service-clusterip-test.yaml

#查看
[root@master1 ~]# kubectl get all
[root@master1 ~]# kubectl get svc
# 自动创建同名的endpoint
[root@master1 ~]# kubectl get ep
#查看service信息
[root@master1 ~]#kubectl describe svc service-clusterip-test
# Name:              service-clusterip-test
# Namespace:         default
# Labels:            <none>
# Annotations:       <none>
# Selector:          app=myweb
# Type:              ClusterIP
# IP Family Policy:  SingleStack
# IP Families:       IPv4
# IP:                192.168.64.158        #对应的ClusterIP
# IPs:               192.168.64.158
# Port:              http  80/TCP
# TargetPort:        80/TCP
# Endpoints:         172.16.1.56:80,172.16.2.93:80,172.16.3.106:80  #对应后端Pod的地址
# Session Affinity:  None
# Events:            <none>
#结果显示：service 自动关联了多个Endpoints
#访问验证
[root@master1 ~]#curl 192.168.64.158
# kubernetes pod-test v0.1!! ClientIP: 172.16.0.0, ServerName: myweb-5df49fdd5-cd8b4, ServerIP: 172.16.1.56!
# [root@master1 ~]#curl 192.168.64.158
# kubernetes pod-test v0.1!! ClientIP: 172.16.0.0, ServerName: myweb-5df49fdd5-mvmrt, ServerIP: 172.16.3.106!
# [root@master1 ~]#curl 192.168.64.158
# kubernetes pod-test v0.1!! ClientIP: 172.16.0.0, ServerName: myweb-5df49fdd5-s2k5w, ServerIP: 172.16.2.93!
#结果显示：后端随机代理到不同的pod应用了
#在测试Pod内部也可以通过service名称访问
[root@master1 ~]#kubectl run client-test-$RANDOM --image wangxiaochun/admin-toolbox:v1.0 --restart=Never --rm -it -- /bin/bash
root@client-test-12345~# curl service-clusterip-test

#如果跨namespace,可以用<service>.<namespace>格式访问,一般用于公共的基础服务,比如:数据库,MQ服务等
root@client-test-12345~# curl service-clusterip-test.default
kubernetes pod-test v0.1!! ClientIP: 172.16.0.0, ServerName: myweb-5df49fdd5-mvmrt, ServerIP: 172.16.3.106!

#删除并重建Pod
[root@master1 ~]#kubectl delete myweb-5df49fdd5-cd8b4 myweb-5df49fdd5-mvmrt myweb-5df49fdd5-s2k5w

#通过原来的service名称和IP都还可访问,说明service比Pod地址更加稳定,可以用于Pod之间的访问
root@client-test-12345~# wget -qO - http://service-test
kubernetes pod-test v0.1!! ClientIP: 10.244.3.11, ServerName: myweb-f95974cf4-zqbzd, ServerIP: 10.244.3.12!

#查看Pod的调度算法RANDOM
[root@master1 ~]#iptables -vnL -t nat |grep random
# 清理环境
[root@master1 ~]#kubectl delete -f service-clusterip-test.yaml

5.1.2 范例: 多端口实现
# 有很多服务都会同时开启多个端口，典型的比如: tomcat三个端口
#资源定义文件
[root@master1 yaml]# cat service-clusterip-multi-port.yaml
kind: Service
apiVersion: v1
metadata:
  name: service-clusterip-multi-port
spec:
  selector:
    app: myweb
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
  - name: https
    protocol: TCP
    port: 443
    targetPort: 443

#关键点：只能有一个ports属性，多了会覆盖，每一个子port必须有一个name属性，由于service是基于标签的方式来管理pod的，所以必须有标签选择器

#创建服务service
[root@master1 yaml]# kubectl apply -f service-clusterip-multi-port.yaml
[root@master1 ~]# kubectl get svc
# NAME                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# kubernetes                    ClusterIP   192.168.0.1     <none>        443/TCP        21h
# service-clusterip-multi-port  ClusterIP   192.168.134.142 <none>        80/TCP,443/TCP 3s

5.1.3 范例: ClusterIP 类型同时指定externalIPs
# ClusterIP类型只能支持集群内容访问，如何想从集群外部访问，可以使用externalIPs实现
# 注意: externalIPs可以应用在所有的service模式下

#在集群中的某个节点添加一个公网ip
[root@node3 ~]# ip a a 10.0.0.66/24 dev eth0 label eth0:1
#注意：这里的模拟外网ip，必须被宿主机能够访问，而且与Kubernetes的集群Pod网段不一样

#配置清单文件
[root@master1 yaml]# cat service-clusterip-externalip.yaml
apiVersion: v1
kind: Service
metadata:
  name: service-clusterip-externalip
spec:
  type: ClusterIP
  selector:
    app: myweb
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
  externalIPs:
  - 10.0.0.66

#注意：这里的externalIPs对于使用哪种Service类型，其实关联度不大。
#创建
[root@master1 yaml]# kubectl apply -f service-clusterip-externalip.yaml

#查看
[root@master1 ~]# kubectl get svc service-test-externalip
NAME                          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service-clusterip-externalip   ClusterIP   192.168.213.247  10.0.0.66     80:32267/TCP   9s
#结果显示：EXTERNAL-IP 已经指定了公网能够正常访问的ip地址

#使用externalIPs和标准端口即可访问
[root@master1 ~]# curl 10.0.0.66
kubernetes pod-test v0.1!! ClientIP: 172.16.0.0, ServerName: myweb-5df49fdd5-mvmrt, ServerIP: 172.16.3.106!
[root@master1 ~]# curl 10.0.0.66
kubernetes pod-test v0.1!! ClientIP: 172.16.0.0, ServerName: myweb-5df49fdd5-s2k5w, ServerIP: 172.16.2.93!
[root@master1 ~]# curl 10.0.0.66
kubernetes pod-test v0.1!! ClientIP: 172.16.0.0, ServerName: myweb-5df49fdd5-cd8b4, ServerIP: 172.16.1.56!
#结果显示：对于EXTERNAL-IP来说，可以直接通过该ip和容器端口来进行服务访问，而无需通过其他端口
#清理环境
[root@master1 yaml]# kubectl delete -f service-clusterip-externalip.yaml


5.2 NodePort Service 实现
# NodePort会在所有节点主机上，向外暴露一个指定或者随机的端口，供集群外部的应用能够访问Kubernetes集群内部的Pod资源。
# 注意: 此方式有安全风险，端口为非标端口
# 生产中建议使用Ingress方式向外暴露集群内的服务
# 注意：nodePort 属性范围为 30000-32767，且type 类型只支持 NodePort或LoadBalancer

[root@master1 ~]# cat service-nodeport.yaml
kind: Service
apiVersion: v1
metadata:
  name: service-nodeport
spec:
  type: NodePort   #指定service的类型,默认值为ClusterIP
  #externalTrafficPolicy: Local #默认值为Cluster,如果是Local只能被当前运行Pod的节点处理流量.并且可以获取客户端真实IP
  selector:
    app: myweb
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30066  #指定固定端口（30000-32767）,使用NodePort类型且不指定nodeport,会自动分配随机端口向外暴露

5.3 LoadBalancer Service 实现
# 只有Kubernetes集群是部署在一个LBaaS平台上且提供有一个集群外部的LB才适合使用LoadBalancer
# 一般的公有云都提供了此功能,但可能会有费用产生
# 如果在一个非公用云的普通Kubernetes集群上,创建了一个LoadBalancer类型的Service的话,由于找不到指定的服务,所以状态会一直处于Pending状态

5.3.1 范例1
# 范例: LoadBalancer类型但没有loadBalancerIP
#清单文件
[root@master1 yaml]# cat service-loadbalancer.yaml
apiVersion: v1
kind: Service
metadata:
  name: service-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: myweb
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
  #loadBalancerIP: 6.6.6.6  #指定地址后,还需要连接云服务商的LBaaS服务才能真正获得此地址,否则为pending状态

[root@master1 yaml]#kubectl apply -f service-loadbalancer.yaml


5.4 ExternalName Service 实现
# service 不仅可以实现Kubernetes集群内Pod应用之间的相互访问以及从集群外部访问集群中的Pod,还可以支持做为外部服务的代理实现集群中Pod访问集群外的服务
# Service代理k8s外部应用的使用场景
# • 在生产环境中使用某个固定的名称而非IP地址进行访问外部的中间件服务
# • 使用Service指向另一个Namespace中或其他集群中的服务
# • 某个项目正在迁移至k8s集群, 但是一部分服务仍然在集群外部, 此时可以使用service代理至k8s集群外部的服务
5.4.1 范例: 使用 ExternalName Service 实现代理外部服务
#创建文件
[root@master1 yaml]# cat service-externalname-web.yaml
kind: Service
apiVersion: v1
metadata:
  name: svc-externalname-web
  namespace: default
spec:
  type: ExternalName
  externalName: www.wangxiaochun.com  #外部服务的FQDN,不支持IP
  ports:                             #以下行都可选
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 0
  selector: {}                        #没有标签选择器

#应用
[root@master1 ~]#kubectl apply -f service-externalname-web.yaml










