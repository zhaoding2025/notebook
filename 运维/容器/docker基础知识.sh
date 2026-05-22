#第五章：Docker资源限额
#内存限制
#    格式：-m 或 --memory
#    [root@master ~]# docker run -id --name=rocky01 -m 100m rockylinux:9.0
    # 通过容器元数据过滤内存信息
#    [root@master ~]# docker inspect rocky01|grep Memory
    # 后续可通过docker update更新资源
#    [root@master ~]# docker update -m 200m rocky01
#CPU限制
#    格式：--cpuset-cpus
#    [root@master ~]# docker run -id --name rocky02 --cpuset-cpus 1 rockylinux:9.0
    # 通过容器元数据过滤CPU信息
#    [root@master ~]# docker inspect rocky02|grep -i cpusetcpus
    # 通过docker update更新资源
#    [root@master ~]# docker update --cpuset-cpus 0 rocky02

#第六章：Docker Compose容器编排
#概述：
#    Docker Swarm，面向集群的，Docker Compose，单机版容器编排工具
#    遵循YAML文件形式创建或启动所有容器
#环境准备
    # 1.下载程序文件
 #   [root@master ~]# wget https://github.com/docker/compose/releases/download/v2.22.0/docker-compose-linux-x86_64
    # 1.1 一键安装，自动匹配架构
 #   [root@master ~]# sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    # 2.修改文件名称
    [root@master ~]# mv docker-compose-linux-x86_64 docker-compose
    # 3.添加执行权限
    [root@master ~]# chmod +x docker-compose
    # 4.移动程序文件到/usr/local/bin/目录
    [root@master ~]# mv docker-compose /usr/local/bin/
    # 5.查看docker-compose版本
    [root@master bin]# docker-compose version
    # 检测docker-compose.yml配置文件（不需要指定文件）
    docker-compose config
    # -q 显示错误输出
    docker-compose config -q
创建容器
    # -d 指定容器后台运行
    docker-compose up -d
    # 查看容器信息
    docker-compose ps
    # 停止运行的容器
    docker-compose stop
    # 启动被停止的容器
    docker-compose start
    # 可通过服务名称管理服务中的容器（服务名称在yml文件中查看）
    docker-compose stop/start web
    # 停止运行的容器并删除（容器和网络会被删除）
    docker-compose down
进阶
    [root@master ~]# mkdir compose-wordpress && cd compose-wordpress
    docker-compose-wordpress部署

第七章 Docker私有仓库
安装harbor仓库
    # 1.下载离线安装包
    wget
    # 解压harborharbor压缩包
    tar xf harbor-offline-installer-v2.14.1.tgz
    # 进入解压目录
    cd harbor/ && ls 
    # 导入harbor镜像
    docker load -i harbor.v.tar.gz
    (base) [root@nfs harbor]# nerdctl load -i harbor.v2.14.1.tar.gz --all-platforms
    # 准备harbor.yml配置文件并修改
    (base) [root@nfs harbor]# mv harbor.yml.tmpl harbor.yml 
    (base) [root@nfs harbor]# vi harbor.yml 
    hostname: 172.16.96.100     # 通过主机IP访问Harbor，也可以定义域名
    http:                       # 访问方式为http（不用修改）
      port: 80                  # 默认端口（不用修改）
    
    # https:                    # 注释HTTPS访问方式（需要证书才可以使用）
    #  port: 443                # 注释HTTPS端口
    harbor_admin_password: 12345     # admin密码  
Tips: Harbor的每个组件都是以容器的形式构建的,且需要通过docker-compose进行后期的启动、关闭等,如果在新的主机部署harbor,需要提前安装docker环境和docker-compose程序
    # 执行当前路径的安装脚本
    (base) [root@nfs harbor]# ./install.sh 

    # 安装docker 
    # 1.删掉错误的源
    rm -rf /etc/yum.repos.d/mirrors.aliyun.com_do.repo
    # 2.配置正确的阿里云docker ce源
    dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    # 3.更新缓存
    dnf clean all
    dnf makecache
    # 4.安装 Docker 版本
    dnf install -y docker-ce-3:20.10.24-3.el9
    # 5.安装完成启动docker
    systemctl enable docker
    systemctl start docker
    docker --version
    
















