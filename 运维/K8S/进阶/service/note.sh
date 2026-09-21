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
