#!/bin/bash
# =============================================================================
# CKA OFFICIAL STUDY OUTLINE (Current Version)
# 权重 + 细分知识点 | 适合cat查看、打印、本地留存
# =============================================================================
cat <<'EOF'
=============================
总分权重概览
=============================
模块 | 权重 | 优先级
Troubleshooting 故障排查                | 30% | ⭐⭐⭐⭐⭐ 最高，重中之重
Cluster Architecture, Installation & Config | 25% | ⭐⭐⭐⭐⭐ 非常核心
Services & Networking 服务与网络         | 20% | ⭐⭐⭐⭐ 高频
Workloads & Scheduling 工作负载与调度    | 15% | ⭐⭐⭐ 常用
Storage 存储                            | 10% | ⭐⭐⭐ 必掌握

💡 CKA 全部是实操题，不要只背概念，必须动手敲命令、排障

====================================================================
🔹 1. Troubleshooting｜故障排查 30%【最重要】
====================================================================
考试大量题目就是给你一个坏掉的集群 / 资源，让你定位、修复，非常贴近运维日常

✅ 细分知识点
- 节点故障排查
  node 状态 NotReady，定位 kubelet、容器运行时、网络问题
  查看节点日志 journalctl，系统资源（CPU / 内存 / 磁盘）
- 集群控制平面组件故障
  apiserver / etcd / scheduler / controller-manager 异常排查
- pod 状态异常：Pending / CrashLoopBackOff / ImagePullBackOff / RunContainerError
- 容器 & 应用排障
  kubectl logs 查看容器日志（多容器要指定 -c）
  kubectl describe pod 看事件 Events（非常关键！排障第一站）
  kubectl exec 进入容器调试
- 网络 & Service 排障
  Pod 之间不通、Pod 访问 Service 异常
  Endpoints 为空排查
  DNS 解析（CoreDNS）问题排查（nslookup、dig）
- 资源监控
  metric-server，kubectl top node / top pod
  资源耗尽导致的各种异常
- 通用调试思路：先看 describe → 看日志 → 看组件状态

✅ 必练命令
kubectl describe pod xxx
kubectl logs xxx [-c container] [-f]
kubectl get events
kubectl top node
kubectl top pod
journalctl -u kubelet

====================================================================
🔹 2. Cluster Architecture, Installation & Configuration｜集群架构、安装与配置 25%
====================================================================
✅ 细分知识点
- Kubernetes 整体架构
  控制平面组件：apiserver、etcd、kube-scheduler、kube-controller-manager、cloud-controller-manager
  节点组件：kubelet、kube-proxy、CRI 容器运行时
  理解 API 对象、etcd 存储集群状态
- kubeadm 部署集群
  kubeadm init / kubeadm join
  高可用控制平面 HA 部署
  kubeadm 升级集群
- 底层接口理解
  CNI（容器网络接口）、CSI（存储）、CRI（容器运行时）
- RBAC 权限管理（高频！）
  Role / ClusterRole
  RoleBinding / ClusterRoleBinding
  创建、授权、验证权限
- 扩展资源
  CRD 概念、Operator 基础认知
  Helm / Kustomize 基础，部署集群组件
- kubeconfig 管理、切换上下文 kubectl config
- 集群生命周期管理（备份恢复 etcd、升级）

✅ 必练
kubeadm 搭一套单节点 / HA 集群
手写 RBAC yaml、绑定用户
kubectl config use-context

====================================================================
🔹 3. Services & Networking｜服务与网络 20%
====================================================================
✅ 细分知识点
- K8s 网络模型基础：所有 Pod 之间不使用 NAT 可直接通信
- Service
  Service 类型：ClusterIP / NodePort / LoadBalancer
  Endpoints、EndpointSlice
  Service 选择器 selector
- CoreDNS
  集群内部 DNS，Pod、Service 域名解析
  DNS 故障排查
- NetworkPolicy 网络策略
  定义 Pod 之间入站、出站访问控制
  写 NetworkPolicy yaml，测试生效
- Ingress / Gateway API
  Ingress Controller、Ingress 资源，暴露集群内 http 服务
- kube‑proxy 原理基础

✅ 必练
创建不同类型 Service
写 NetworkPolicy 限制 pod 通信
部署简单 Ingress

====================================================================
🔹 4. Workloads & Scheduling｜工作负载与调度 15%
====================================================================
✅ 细分知识点
- Deployment
  创建、滚动更新 rollout，回滚 rollout undo
  扩缩容 scale
  理解 Deployment 管理 ReplicaSet
- Pod 基础
  Pod 资源 requests /limits（CPU、内存）
  QoS 等级
- 调度相关
  Label / Selector / Annotation
  NodeSelector
  NodeAffinity（节点亲和）、PodAffinity / PodAntiAffinity（Pod 亲和 / 反亲和）
  Taint & Toleration（污点与容忍 ⭐高频考点）
  DaemonSet（每个节点跑一个 Pod）
  Static Pod（静态 Pod，控制平面常用）
- 配置管理
  ConfigMap（配置，非机密）
  Secret（机密数据）
  注入到 Pod（env、volume 挂载）
- HPA 水平自动扩缩容基础

✅ 必练重点
Taint/Toleration、亲和性、deployment rollout 是考试高频

====================================================================
🔹 5. Storage｜存储 10%
====================================================================
✅ 细分知识点
- Volume 基础（emptyDir、hostPath 等）
- PV / PVC
  PersistentVolume、PersistentVolumeClaim
  访问模式 AccessModes
  回收策略 ReclaimPolicy
- StorageClass 存储类，动态供给（dynamic provisioning）
- PV 绑定、状态管理

✅ 必练
手写 PV、PVC yaml
StorageClass 创建、动态创建 PVC

====================================================================
🛠️ 前置基础（CKA 备考前最好掌握）
====================================================================
Linux 基础：shell、systemd、journalctl、权限、网络基础（ip、ss、curl、nslookup）
Docker / 容器基础：镜像、容器、日志
yaml 基础（缩进！考试 yaml 缩进错直接丢分）
kubectl 熟练度，建议配置别名 alias k=kubectl + bash/zsh 补全

====================================================================
💡 CKA 备考实操路线建议
====================================================================
1. 先过一遍架构、核心概念
2. 本地搭集群（kind /kubeadm）动手敲每一块
3. 专门大量练排障题（30%），这块是拉开差距关键
4. 刷模拟题库 killer.sh
5. 熟练查官方文档（考试环境允许打开 k8s docs，不要死记所有 yaml，学会复制修改）
6. 整套模拟计时训练，适应 2 小时压力

====================================================================
✅ 考试通用技巧（非常重要）
====================================================================
1. 每道题先切换指定 context！ 很多人踩坑，操作错集群直接不得分
2. 卡住的题标记跳过，不要死磕，时间很紧
3. 能用 --dry-run -o yaml 生成 yaml 模板就不要从零手写
4. 写完资源 kubectl get/describe 校验是否符合要求

====================================================================
📌 可选配套资料清单
====================================================================
官方文档：https://kubernetes.io/docs/
killer.sh（模拟考试环境，强烈推荐）
github cka 练习仓库
kind /kubeadm 本地实验环境
EOF