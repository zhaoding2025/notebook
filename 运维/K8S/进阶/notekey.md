


nfs存储
nfs server
(base) [root@nfs ~]# mkdir -p /home/nfs/rw/www/wolfcode
(base) [root@nfs ~]# echo '<h1>wolfcode</h1>' > /home/nfs/rw/www/wolfcode/index.html




第一阶段：核心资源对象的深度应用
目标： 不再只用 kubectl apply，而是理解资源间的联动逻辑。

控制器进阶 (StatefulSet & DaemonSet)

知识点： 理解有状态应用与无状态应用的区别，存储状态的持久化绑定。

练习案例： 部署一个高可用的 Redis 集群（StatefulSet），测试删除 Pod 后数据是否丢失，以及 Pod 编号的稳定性。

配置管理 (ConfigMap & Secret)

知识点： 热更新机制，Secret 的加密与挂载。

练习案例： 将 Nginx 的配置文件存入 ConfigMap，实现修改 ConfigMap 后 Nginx 容器内的配置自动重新加载（可以使用 sidecar 或手动 reload）。

服务暴露 (Ingress 进阶)

知识点： 证书自动化 (Cert-Manager)、路径重写、限流配置。

练习案例： 配置 Nginx Ingress，实现 test.com/api 转发到 A 服务，test.com/static 转发到 B 服务，并配置强制 HTTPS 跳转。

第二阶段：可观测性与生产级运维（运维核心）
目标： 建立“看得见”的集群，能在故障发生前收到报警。

监控系统 (Prometheus & Grafana)

知识点： Operator 模式部署，自定义监控指标 (PromQL)。

练习案例： 部署 Prometheus Stack，通过 Grafana 配置一个面板，实时展示 Pod 的 CPU 压测曲线。

日志处理 (EFK/Loki)

知识点： 日志采集策略（DaemonSet 模式 vs Sidecar 模式）。

练习案例： 使用 Loki + Promtail 采集集群日志，在 Grafana 界面根据关键词搜索特定 Pod 的错误日志。

节点与资源治理 (HPA & VPA)

知识点： 基于 CPU 利用率的自动扩缩容。

练习案例： 对一个 Web 应用进行压力测试（使用 ab 或 hey 工具），观察 Pod 数量如何从 1 个自动增加到 10 个。

第三阶段：网络与存储深挖（进阶难点）
目标： 解决 K8s 最头疼的两大问题：网络不通和数据丢失。

网络插件 (CNI) 原理

知识点： Flannel 与 Calico 的区别（VXLAN 模式 vs BGP 模式），NetworkPolicy 网络策略。

练习案例： 编写一条 NetworkPolicy，禁止 default 命名空间的所有 Pod 访问 kube-system 命名空间。

持久化存储 (CSI)

知识点： 动态配置 (StorageClass)，PV/PVC 生命周期。

练习案例： 搭建一个 NFS Server，在 K8s 中创建动态 StorageClass，实现创建 PVC 时自动在 NFS 上生成目录。

Service 原理

知识点： IPVS 与 iptables 模式的区别，CoreDNS 解析流程。

练习案例： 追踪一个请求从 Pod 出发到 Service ClusterIP，再到目标 Pod 的完整路径。

第四阶段：CI/CD 与 GitOps（开发运维一体化）
目标： 实现从代码提交到集群部署的全自动化。

Helm 包管理

知识点： Chart 模板编写，版本回滚。

练习案例： 将你自己的业务应用打包成 Helm Chart，实现通过一条命令 helm install 完成所有资源部署。

ArgoCD 或 Flux (GitOps)

知识点： “声明式”部署，Git 仓库作为单一信任源。

练习案例： 搭建 ArgoCD，当你在 GitHub 修改了 YAML 文件后，集群自动同步更新应用。

第五阶段：集群安全与高级架构
目标： 能够架构一个生产级、安全稳固的集群。

RBAC 权限控制

知识点： Role、ClusterRole、ServiceAccount。

练习案例： 创建一个权限受限的 User，使其只能查看 dev 命名空间的 Pod，不能删除或修改。

调度策略 (Affinity & Taints)

知识点： 亲和性、污点与容忍。

练习案例： 给特定的 GPU 节点打上污点，确保只有标注了“需要 GPU”的 Pod 才能调度上去。

💡 进阶建议：
别只用一键脚本： 尝试用 Kubeadm 手动搭建一次高可用集群（多 Master 节点），这能帮你理解 etcd 备份和 API Server 的负载均衡。

考取认证： 如果需要职业背书，建议去考 CKA (Certified Kubernetes Administrator)。

工具推荐： 日常操作多使用 k9s（终端 UI）提高效率；学习时多看官方文档的 Tasks 章节。

你可以先从第一阶段的 StatefulSet 部署 Redis 开始尝试，遇到具体的报错随时可以发给我分析。