Kubernetes的服务暴露和七层代理Ingress
# 主要内容
# •Kubernetes 的服务暴露机制
# •Kubernetes 的 Ingress 工作原理
# •Kubernetes 的 Ingress controller 实现方案
# •Kubernetes Ingress-Nginx Controller 安装和配置
# •Kubernetes Ingress-Nginx 创建方式说明
# •Kubernetes Ingress-Nginx 实战案例

1 Kubernetes 的服务暴露机制
# Kubernetes集群中的通信的不仅有内部的流量，还有外部流量

# 流量方向
# • 将集群内部pod之类对象之间的网络通信称为东西向流量
# • 将集群外部应用和集群内部之间对象之间的网络通信称为南北向流量
#   ◦ 南入↓ -- ingress
#   ◦ 北出↑ -- egress

# 可以基于四层的两种常用的方式实现将集群外部的流量引入到集群的内部中来，从而实现外部客户的正常访问。
# • Host方式：通过使用node节点的hostNetwork与hostPort及配套的port映射，以间接的方式实现service的效果
# • Service方式：nodePort、externalIP等service对象方式，借助于namespace、iptables、ipvs等四层反向代理实现流量的转发

# 四层方式存在的问题
# • 基于service或host等多种方式实现集群内外的网络通信都是基于四层协议来进行调度的，而且应用级别的健康检查功能很难实现。
# • 对于外部流量的接入，一般都是http(s)协议通信，四层协议是无法实现的。尤其是涉及到各种ssl会话的管理
# • 不支持基于FQDN的方式进行访问应用
# • 不支持基于URL等机制对HTTP/HTTPS协议进行高级路由、超时/重试、基于流量的灰度等高级流量治理机制
# • service其本质上，是通过网络规则方式来进行转发的，将集群内部的服务暴露到外部。这会造成对外过多的地址和端口暴露

2 Kubernetes 的 Ingress 工作原理
# https://kubernetes.github.io/ingress-nginx/
# https://kubernetes.io/zh-cn/docs/concepts/services-networking/ingress/
# https://kubernetes.io/zh-cn/docs/concepts/services-networking/ingress-controllers/

# 解决方案
# 虽然可以自行通过部署七层代理解决上述问题,但配置过程繁琐以及无法和Kubernetes集群更好的结合联动.
# 因此Kubernetes引入了一种新的资源 ingress, 可以解决上面提出问题:
# • Ingress本质就是七层代理, 所以可以基于http/https的方式, 将集群外部的流量统一的引入到集群内部
# • 通过一个统一的流量入口, 避免将集群内部大量的端口直接暴露给外部

# Ingress公开从集群外部到集群内服务 HTTP 和 HTTPS 路由。流量路由由 Ingress 资源上定义的规则控制。
# 下面是一个将所有流量都发送到同一 Service 的简单 Ingress 示例:  
# Ingress 可为 Service 提供外部可访问的 URL、负载均衡流量、终止 SSL/TLS，以及基于名称的虚拟托管。Ingress 控制器通常负责通过负载均衡器来实现 Ingress，尽管它也可以配置边缘路由器或其他前端来帮助处理流量。
# Ingress 不会公开任意端口或协议。将 HTTP 和 HTTPS 以外的服务公开到 Internet 时，通常使用 Service.Type=NodePort 或 Service.Type=LoadBalancer 类型的 Service。
# Ingress这种利用应用层协议来进行流量的负载均衡效果，它可以实现让用户通过域名来访问相应的service就可以了，无需关心Node IP及Port是什么，避免了信息的泄露。
# Ingress 是kubernetes上的一种标准化资源格式，它为了剥离与特定负载均衡功能实现软件的相关性，而抽象出来的一种公共的统一的声明式配置格式。然后借助于特定的ingress controller功能负责将其加载并转换成k8s集群内部的配置信息。
# Ingress是授权入站连接到达集群服务的规则集合。
# ingress 主要包含两个组件Ingress API和Ingress Controller
# ingress 其具备了动态更新并加载新配置的特性。而且ingress本身是不具备实现集群内外流量通信的功能的，这个功能是通过controller来实现的。Ingress Controller本身是运行于集群中的Pod资源对象

# | 组件         | 解析 |
# | ------------| ---- |
# | Ingress API | Kubernetes上的标准API资源类型之一<br>仅定义了抽象路由配置信息，只是元数据，需要由相应的控制器动态加载<br>将代理配置抽象成一个Ingress对象，
#                     每个服务对应一个yaml配置文件<br>负责以k8s标准的资源格式定义流量调度、路由等规则 |
# | Ingress Controller | 反向代理服务程序<br>需要监视（watch）API Server上Ingress资源的变动，并生成具体应用的自身的配置文件格式，即将新加入的Ingress转化成反向代理的配置文件并动态加载使之生效，
#                         最终并据此完成流量转发<br>Ingress Controller非为内置的控制器，需要额外部署<br>通常以Pod形式运行于Kubernetes集群之上<br>一般应该由专用的LB Service负责为其接入集群外部流量 |

# Ingress 访问过程
# • 从外部流量调度到kubernetes中Ingress service，有多种实现方案，比如使用节点网络中的EXTERNAL-IP或者NodePort方式
# • 从service调度到ingress-controller
# • ingress-controller根据ingress Pod中的定义，比如虚拟主机或者后端的url
# • 根据虚拟主机名直接调度到后端的一组应用pod中


## 注意:
# - 整个流程中涉及到了两处service内容
# - service ingress-nginx 是帮助 ingress controller Pod 接入外部流量的
# - 后端的服务对应的service 只起到帮助 ingress controller Pod 找到具体的服务的Pod，即只用于服务发现，而流量不需要经过后端服务的Service，直接从ingress controller Pod转到至具体的Pod
# - 虚线表示service对后端的应用进行分组，实线表示ingress实际的访问流向

3 Ingress controller 常见的解决方案
# Ingress controller 支持由任何具有反向代理功能的程序实现，如Nginx、Traefik、Envoy、HAProxy、Vulcand等

# Kubernetes支持同时部署二个或以上的数量的Ingress Controller

# Ingress资源配置指定Ingress Controller类型的方法
# - 专用的annotation: kubernetes.io/ingress.class
# - Ingress资源的spec的专有字段：ingressClassName，引用的IngressClass是一种特定的资源类型，此方式v1.18版本起使用

# Ingress controller常见的实现方式有:
# https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/


# Kubernetes Ingress
# Kubernetes官方发布, Ingress-Nginx 自从k8s-v1.6版本引入, 在k8s-v1.19正式进入了一个稳定版本状态。
# http://github.com/kubernetes/ingress-nginx

# Nginx Ingress
# github.com/nginxinc/kubernetes-ingress
# Nginx Ingress是NGINX开发的官方版本，它基于NGINX Plus商业版本，NGINX控制器具有很高的稳定性，持续的向后兼容性，没有任何第三方模块，并且由于消除了Lua代码而保证了较高的速度（与官方控制器相比）。
# 相比官方控制器，它支持TCP/UDP的流量转发，付费版有很广泛的附加功能，主要缺点就是缺失了鉴权方式、流量调度等其他功能。

# Kong Ingress
# github.com/Kong/kubernetes-ingress-controller
# Kong Ingress建立在NGINX之上，并增加了扩展其功能的Lua模块。
# kong在之前是专注于API网关，现在已经成为了成熟的Ingress控制器，相较于官方控制器，在路由匹配规则、upstream探针、鉴权上做了提升，并且支持大量的模块插件，并且便于配置。
# 它提供了一些API、服务的定义，可以抽象成Kubernetes的CRD，通过Kubernetes Ingress配置便可完成同步状态至Kong集群。

# HAProxy Ingress
# 性能相对于nginx来说，较稳定
# http://github.com/jcmoraisjr/haproxy-ingress


# Envoy:
# 基于C++语言开发，本身就为动态环境设计的，支持配置动态加载的XDS API
# 不能像ingress-nginx一样，直接加载配置文件并动态加载转换成对应的应用配置，所以需要借助于其他控制平面工具来实现。
# 常见解决方案: Contour, Gloo

# Traefik Ingress
# Traefik的设计目标是成为一个现代化的云原生应用反向代理和负载均衡器。它专注于与容器化环境（如Docker、Kubernetes）集成，并具有自动发现和动态配置的能力。相比之下，Nginx是一个多用途的Web服务器和反向代理，旨在提供高性能和广泛的功能。
# 配置语言和方式：Traefik使用声明性的配置语言，通常基于YAML或TOML格式。它支持自动发现和动态配置，可以根据容器的状态和标签进行自动路由。Nginx使用基于文本文件的配置语言，通常使用Nginx专有的配置语法。
# 由于Traefik专注于容器环境，并提供自动配置功能，对于那些熟悉Docker和Kubernetes的用户来说，使用Traefik可能更加容易上手
# 当前使用得较多的是 traefik 和 nginx-controller，traefik 的性能较 nginx-controller 差，但是配置使用要简单许多
# https://traefik.io/
# https://github.com/containous/traefik
# https://github.com/traefik/traefik/releases
# https://github.com/traefik/traefik/tree/v1.7/examples/k8s

# 各种 Ingress Controller 比较
# https://docs.google.com/spreadsheets/d/1DnsHtdHbxjvHmxv1u7VhzwCwgLAn_Mc5L1W1hLDA__k/edit?spm=a2c6h.12873639.article-detail.4.1eff3d8d053Ifj#gid=0

4 Ingress-nginx 安装和配置
4.1 部署说明
# 注意: Ingress-nginx 有两个项目,一个Kubernetes维护和Nginx官方维护,下面以Kubernetes官方维护的项目为例

#参考资料:
# https://github.com/kubernetes/ingress-nginx
# https://kubernetes.io/docs/concepts/services-networking/ingress/

#安装文档:
# https://kubernetes.github.io/ingress-nginx/deploy/
# https://github.com/kubernetes/ingress-nginx/blob/main/docs/deploy/index.md

# https://github.com/kubernetes/ingress-nginx

ingress-nginx-controller 部署模式
# 外部用户通过使用ingress-nginx-controller pod所在主机的物理网络访问,可以配置daemonset实现,此方式性能最好
# 外部用户通过ingress-nginx-controller的service对应的外部IP访问
#   通过ingress-nginx-controller对应service中的externalIPs指定外部IP
#   使用LB指定ingress-nginx-controller对应NodePort类型Service的节点IP:NodePort实现
#   使用ingress-nginx-controller对应LoadBalancer类型Service的节点IP实现

4.2 部署案例
ingress-nginx 有两种主要的部署方式
#   with Helm, using the project repository chart
#   with kubectl apply, using YAML manifests

4.2.1 基于 kubectl apply 部署
# 范例: 基于 kubectl apply 部署

#获取配置文件,可能需要科学上网才能下载
# https://kubernetes.github.io/ingress-nginx/deploy/

#新版
#[root@master1 ~]#wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.0/deploy/static/provider/cloud/deploy.yaml

[root@master1 ~]#wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.0/deploy/static/provider/cloud/deploy.yaml

#旧版
[root@master1 ~]#wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.4.0/deploy/static/provider/cloud/deploy.yaml

#旧版
[root@master1 ~]#wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.3.1/deploy/static/provider/cloud/deploy.yaml

#旧版
[root@master1 ~]#wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.0.3/deploy/static/provider/baremetal/deploy.yaml

#查看资源
[root@master1 ~]#grep '^kind' deploy.yaml





5 Kubernetes Ingress-Nginx 创建方式
# 和其它Kubernetes资源一样,Ingress-Nginx 创建同样也有命令和声明式创建两种方式

5.1 命令式方式说明
#创建Ingress的命令:
# kubectl create ingress NAME --rule=host/path=service:port[,tls=secret] [options]

#常用选项
# host/path        #服务对应的FQDN和URL
# --annotation=[]  #注解信息，格式"annotation=value"
# --rule=[]        #代理规则，格式"host/path=service:port[,tls=secretname]"
# --class=''       #此Ingress适配的Ingress Class

#基于URI方式代理不同应用的请求时，后端应用的URI若与代理时使用的URI不同，则需要启用URL Rewrite完成URI的重写
# Ingress-Nginx支持使用"annotation nginx.ingress.kubernetes.io/rewrite-target"注解进行

5.2 声明式方式说明
# 基于命令方式格式功能有限，且不利于后续的重复使用，工作中更多的使用声明式实现Ingress
# 在实际的工作中，可能会基于域名访问,也可能会基于不同的功能服务以子路径的方式来进行访问，以及与https相关的访问。
# 注意: k8s-v1.22之前后版本的声明式的yaml格式有所不同
# 官方配置参考
# https://kubernetes.io/docs/concepts/services-networking/ingress/
# https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/

配置文件解析
# apiVersion: networking.k8s.io/v1        # 资源所属的API群组和版本
# kind: Ingress                           # 资源类型标识符
# metadata:                               # 元数据
#   name <string>                         # 资源名称
#   annotations:                          # 资源注解，v1beta1使用下面的注解来指定要解析该资源的控制器类型
#     kubernetes.io/ingress.class: <string># 适配的Ingress控制器类别,便于多ingress组件场景下，挑选针对的类型
#   namespace <string>                    # 名称空间
# spec:
#   rules <[]Object>                      # Ingress规则列表，也就是http转发时候用到的 url关键字
#   - host <string>                       # 虚拟主机的FQDN，支持"*"前缀通配，不支持IP，不支持指定端口
#     http <Object>
#       paths <[]Object>                  # 虚拟主机PATH定义的列表，由path和backend组成
#       - path <string>                  # 流量匹配的HTTP PATH，必须以/开头
#         pathType <string>               # 支持Exact、Prefix和ImplementationSpecific，必选
#         backend <Object>                # 匹配到的流量转发到的目标后端
#           resource <Object>             # 引用的同一名称空间下的资源，与下面两个字段互斥
#           service <object>              # 关联的后端Service对象
#             name <string>               # 后端Service的名称
#             port <object>               # 后端Service上的端口对象
#               name <string>             # 端口名称
#               number <integer>          # 端口号
#   tls <[]Object>                        # TLS配置，用于指定上rules中定义的哪些host需要工作HTTPS模式
#   - hosts <[]string>                    # 使用同一组证书的主机名称列表
#     secretName <string>                 # 保存于数字证书和私钥信息的secret资源名称，用于主机认证
#   backend <Object>                      # 默认backend的定义，可嵌套字段及使用格式跟rules字段中的相同
#   ingressClassName <string>             # ingress类名称，用于指定适配的控制器，类似于注解的功能，未来代替annotations

范例:
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: minimal-ingress
#   annotations:
#     nginx.ingress.kubernetes.io/rewrite-target: / #默认会转发给后端时会带有URL,添加此行，表示转发时删除后面的URL
# spec:
#   ingressClassName: nginx-example
#   rules:
#   - http:
#       paths:
#       - path: /testpath
#         pathType: Prefix
#         backend:
#           service:
#             name: test
#             port:
#               number: 80


6 Kubernetes Ingress-Nginx 实战案例
# 范例: 准备环境实现两个service应用 pod-test1和pod-test2

#准备后端的应用pod-test v0.1和相应的service
[root@master1 ~]#kubectl create deployment pod-test1 --image=wangxiaochun/pod-test:v0.1 --replicas=3
[root@master1 ~]#kubectl create service clusterip pod-test1 --tcp=80:80

#准备后端的应用pod-test v0.2和相应的service
[root@master1 ~]#kubectl create deployment pod-test2 --image=wangxiaochun/pod-test:v0.2 --replicas=3
[root@master1 ~]#kubectl create service clusterip pod-test2 --tcp=80:80

[root@master1 ~]#kubectl get endpoints
# NAME         ENDPOINTS                                   AGE
# pod-test1    10.244.1.60:80,10.244.1.64:80,10.244.1.69:80 21h
# pod-test2    10.244.1.65:80,10.244.1.66:80,10.244.1.70:80 21h




















常见命令:
kubectl get ingress                 # 查看当前集群ingress规则
kubectl describe ingress <name>     # 查看特定路由规则的详细配置与后端映射
kubectl get pods -n ingress-nginx   # 查看执行转发任务的Controller容器状态
kubectl apply -f ingress.yaml       # 声明式创建或热更新路由规则



ingress常见异常故障排查:
场景1:外部访问直接返回404
# 检查 kubectl describe ingress 确认Host域名和Path路径是否精确匹配
场景2:ingress找不到指向的backend service
# 检查：kubectl get svc 确保yaml里的service名字和端口完全对得上
场景3:转发正常但是没有pod响应(endpoint为空)
# 检查：kubectl get endpoints确认service的selector标签是否和pod匹配

总结: service解决内部通信,Ingress解决外部用户如何安全高效的访问整个K8S系统











