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

















