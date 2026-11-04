主要内容:
#Kubernetes 安全体系
#Kubernetes 认证机制
#Kubernetes 用户分类
#Kubernetes 认证插件
#Kubernetes 实现基于X509证书的UA
#Kubernetes 实现服务帐户SA
#Kubernetes 实现 Kubeconfig 配置
#Kubernetes 认证综合实战案例

3A:认证 授权 审计

1. 安全体系
#对于一些重要应用场景，其权限的认证管理都是非常重要的，对于linux系统，用户和组、文件权限、SELinux、防火墙、pam、sudo等，究其核心的目的都是为了保证系统是安全的
#对于kubernetes的这种大型的任务编排系统来说，同样也陆续产生了一系列对平台的权限认证、对业务的权限认证、对网络的安全认证等认证体系。
#对APIServer的访问一般都要经过的三个步骤的安全访问控制
# https://kubernetes.io/zh-cn/docs/reference/access-authn-authz/
# img/安全访问控制
# img/用户类型

2. 认证机制
主要涉及到用户帐号UA和服务帐号SA的认证内容
# img/认证机制

2.1 Kubernetes 中的用户
# https://kubernetes.io/zh-cn/docs/reference/access-authn-authz/authentication/

# 在 Kubernetes 中，subject 是指一个对象或实体，该对象或实体可以是用户、服务帐户、组或其他可识别的实体。它在授权策略中用于
# 标识哪些实体被允许或被拒绝访问资源。简而言之，subject 就是需要被授权访问资源的实体。认证用户即属于Subject
# 在Kubernetes集群中定义了两种类型的subject资源的认证用户:

# 用户种类 | 解析
# User Account
# 用户账户，指非Pod类的客户端访问API Server时使用的身份标识，一般是现实中的"人"
# API Server没有为这类账户提供保存其信息的资源类型，相关的信息通常保存于外部的文件或认证系统中,由外部独立服
# 务进行管理，所以用户不能通过集群内部的 API 来进行管理。
# 身份核验操作可由API Server进行，也可能是由外部身份认证服务完成
# 作用域为整个集群级别,常见的管理方式,如: openssl等

# Service Account
# Service Accounts（SA）在Kubernetes中是一种内建的、与Pod关联的账号类型。
# 它们主要是为了在Pod中运行的进程提供一个身份标识，以便访问Kubernetes API
# 通过Kubernetes API来管理的用户帐号，适用于集群中Pod内的进程访问API Server时使用的身份信息，需要通过 API
# 来完成权限认证
# API Server使用ServiceAccount类型的资源对象来保存该类账号
# 认证到API Server的认证信息称为Service Account Token，它们保存于同名的专用类型的Secret对象中
# 在集群内部进行权限操作，都需要使用到ServiceAccount
# namespace级别的资源类型，即账号隶属于名称空间，但可以授予集群级别的权限

# 匿名用户：不能被识别为Service Account，也不能被识别为User Account的用户，即"匿名用户"

# Kubernetes 假定普通用户是由一个与集群无关的服务进行管理的,因此Kubernetes 并不包含用来代表普通用户账号的对象。普通用户的
# 信息无法通过 API 调用添加到集群中。

# 尽管无法通过 API 调用来添加普通用户，Kubernetes 仍然认为能够提供由集群的证书机构签名的合法证书的用户是通过身份认证的用
# 户。基于这样的配置，Kubernetes 使用证书中的'subject'的通用名称（Common Name）字段（例如，"/CN=bob"）来确定用户名。
# 接下来，基于角色访问控制（RBAC）子系统会确定用户是否有权针对某资源执行特定的操作。

# 与此不同，服务账号是 Kubernetes API 所管理的用户。它们被绑定到特定的名字空间，或者由 API 服务器自动创建，或者通过 API 调用
# 创建。服务账号与一组以Secret保存的凭据相关，这些凭据会被挂载到 Pod 中，从而允许集群内的进程访问 Kubernetes API。

# API 请求则或者与某普通用户相关联，或者与某服务账号相关联，亦或者被视作匿名请求。这意味着集群内外的每个进程在向 API 服务器
# 发起请求时都必须通过身份认证，否则会被视作匿名用户。这里的进程可以是在某工作站上输入 kubectl 命令的操作人员，也可以是节
# 点上的 kubelet 组件，还可以是控制面的成员。

2.2 用户组
# 在kubernetes集群中，为了更方便的对某一类用户帐号UA进行方便管理，一般会通过用户组的方式来进行管理
# Kubernetes本身并没有对用户或用户组的内建概念或实体。
# 在Kubernetes中，用户和组是在身份提供者（如OpenID Connect，Active Directory等）中创建和管理的，而不是在Kubernetes集群自身中创建。所以，无法直接在Kubernetes中创建组。
# 这就意味着在Kubernetes中没有直接的方式去查看用户或用户组。通常情况下，用户和用户组是在Kubernetes集群外部定义和管理的。
# 这可能是在使用的身份提供商（例如OpenID或Active Directory）中或者在Kubeconfig文件中定义的。
# 在Kubernetes中，用户和用户组主要在认证(Authentication)和授权(Authorization)环节中发挥作用。
# 范例: 查看用户组system:masters的权限

#所有的k8s集群资源操作，其实都是通过node节点上的kubelet和master节点上的apiserver之间的通信实现，而在kubernetes的认证目录中
#有其专用的通信认证证书 apiserver-kubelet-client.crt，可以通过该文件来检查一下这两者之间是一个怎样的关系。
[root@master1 ~]# openssl x509 -in /etc/kubernetes/pki/apiserver-kubelet-client.crt -text -noout
Certificate:
    ...
    Issuer: CN = kubernetes
    Validity
        Not Before: Oct  3 03:06:43 2021 GMT
        Not After : Oct  3 03:06:43 2022 GMT
    Subject: O=system:masters, CN=kube-apiserver-kubelet-client
...
#结果显示：对于kubelet，用户名是kube-apiserver-kubelet-client，而且属于system:master的组，这两者的关系是在基于openssl或者csffl工具创建用户时候基于CN和O来设定的信息。

#查看集群角色的权限
[root@master1 ~]# kubectl get clusterrole cluster-admin -o yaml

2.3 认证插件
# img/认证插件
# img/认证方式
# API Server启用的身份认证机制
# 基于认证插件支持多种认证方式，而相应认证插件的启用需要经由kube-apiserver上的专用选项完成
# kubeadm部署的集群默认启用的认证机制包括如下几种
#    X509客户端证书认证
#    Bootstrap令牌认证
#    前端代理身份认证 front-proxy
#    Service Account令牌
# 注意: API Server并不保证各认证插件的生效次序与定义的次序相同

# 范例: 查看API Server 的认证机制
#在Master节查看认证机制
[root@master1 ~]# cat /etc/kubernetes/manifests/kube-apiserver.yaml

3 User Account 管理
3.1 X509 客户端认证说明
# 官方说明
# https://kubernetes.io/zh/docs/setup/best-practices/certificates/

# Kubernetes集群中的X509客户端认证依赖于PKI证书体系,有如下三套CA证书系统
# img/CA证书系统

3.2 案例
3.2.1 创建基于X509客户端普通的用户证书
# 范例: 创建基于X509客户端普通的用户证书, 并使用此证书访问kubernetes集群

#查看到以下内容，表示默认kubernetes的CA签发的证书，都是k8s客户端的用户
[root@master1 ~]# grep '\--client-ca-file' /etc/kubernetes/manifests/kube-apiserver.yaml
  - --client-ca-file=/etc/kubernetes/pki/ca.crt

#在master节点创建test用户证书
[root@master1 ~]# mkdir pki
[root@master1 ~]# (umask 077; openssl genrsa -out pki/test.key 4096)
[root@master1 ~]# ls pki/
test.key

#生成证书申请,加入ops组只具有普通权限
[root@master1 ~]# openssl req -new -key pki/test.key -out pki/test.csr -subj "/CN=test/O=ops"

#使用kubernetes-ca颁发证书
[root@master1 ~]# openssl x509 -req -days 3650 -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -in pki/test.csr -out pki/test.crt

#复制证书文件到worker节点
[root@master1 ~]# scp -r pki/ node1:

#在worker节点使用证书访问kubernetes集群,权限不足
[root@node1 ~]# ls pki/
test.crt  test.csr  test.key
[root@node1 ~]# ls /etc/kubernetes/pki/
ca.crt

#默认从worker节点无法访问,报错如下
[root@node1 ~]# kubectl get pod
# E0415 20:16:30.966136   668159 memcache.go:238] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp 127.0.0.1:8080: connect: connection refused

# #指定apiserver地址和证书信息等信息,再次执行可以看到下面提示已识别用户test，但无权限访问资源
# [root@node1 ~]# kubectl get pod --server=https://kubeapi.wang.org:6443 --client-certificate=pki/test.crt --client-key=pki/test.key --certificate-authority=/etc/kubernetes/pki/ca.crt
# Error from server (Forbidden): pods is forbidden: User "test" cannot list resource "pods" in API group "" in the namespace "default"

# #或者下面选项忽略证书校验也可以
# [root@node1 ~]# kubectl get pod -s https://kubeapi.wang.org:6443 --client-certificate=pki/test.crt --client-key=pki/test.key --insecure-skip-tls-verify=true
# Error from server (Forbidden): pods is forbidden: User "test" cannot list resource "pods" in API group "" in the namespace "default"

# #使用证书访问
# [root@node1 ~]# curl --cert pki/test.crt --key pki/test.key --key-type PEM --cacert /etc/kubernetes/pki/ca.crt https://kubeapi.wang.org:6443
# {
#   "kind": "Status",
#   "apiVersion": "v1",
#   "metadata": {},
#   "status": "Failure",
#   "message": "forbidden: User \"test\" cannot get path \"/\"",
#   "reason": "Forbidden",
#   "details": {},
#   "code": 403
# }
