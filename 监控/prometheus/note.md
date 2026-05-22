1.概述
    Prometheus 是一套开源的 云原生、时序型、指标监控与告警系统,专门用来监控服务器、容器、服务、中间件、K8s、GPU、大模型等各类基础设施与应用状态。
    简单说：它专门用来收指标、存指标、查指标、发告警。

2.特点
    1. 支持多维数据模型由key=value 标签指标名称和键值对标识的时间序列数据
    2. 内置时序数据库TSDB(Time Serices Database)专门存监控数据
    3. 支持强大的查询语言PromQL(Prometheus Query Language),对数据的查询和分析、图形展示和监控告警
    4. 不依赖分布式存储;单个服务器节点是自治的
    5. 支持HTTP被动拉取Pull模式为主收集时间序列数据
    6. 通过中间网关pushgateway推送时间序列
    7. 通过服务发现或静态配置2中方式发现目标
    8. 支持多种可视化和仪表盘,如:grafana

3.核心组件
    Prometheus server  主要用于抓取数据和存储时序数据,另外还提供查询和alert rule配置管理
    client libraries   用于检测应用程序代码的客户端库
    push gateway       用于批量,短期的监控数据的汇总节点,主要用于业务数据汇报等
    exporters          收集监控样本数据,并以标准格式向prometheus提供。例如:收集服务器系统数据的node_exporter,收集mysql监控样本数据的是mysql exporter
    alertmanager       用于告警通知管理

4. 基础架构
    






