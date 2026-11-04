1 Nginx基础
# 背景介绍
# Nginx（"engine x"）一个具有高性能的HTTP和反向代理的WEB服务器，同时也是一个POP3/SMTP/IMAP代理服务器，Nginx是由伊戈尔·赛索耶夫为俄罗斯访问量第二的http://Rambler.ru站点（俄文：Рамблер）开发的，
# 第一个公开版本0.1.0发布于2004年10月4日，另外值得一提的是伊戈尔·赛索耶夫将Nginx的源码进行了开源，这也为Nginx的发展提供了良好的保障。其特点是占有内存少，并发能力强，
# 事实上nginx的并发能力确实在同类型的网页服务器中表现较好，中国大陆使用nginx网站用户有：百度、京东、新浪、网易、腾讯、淘宝等。
反向代理
# 正向代理
# 正向代理需要主动设置代理服务器ip或者域名进行访问，由设置的服务器ip或者域名去访问内容并返回
# 正向代理是代理客户端，为客户端收发请求，使真实客户端对服务器不可见。
# 用途
# 突破访问显示：通过代理服务器，可以突破自身ip访问限制，访问国外网站等
# 提高访问速度：通常代理服务器都设置一个较大的硬盘缓冲区，会将部分请求的响应保存到缓冲区中，当其他用户再访问相同的信息时，则直接由缓冲区中取出信息，传给用户，以提高访问速度
# 隐藏客户端真实ip：上网者可以通过正向代理的方法隐藏自己的ip，免受攻击

# 反向代理
# 正向代理需要配置代理服务器，而反向代理不需要做任何设置。
# 反向代理是代理服务器，为服务器收发请求，使真实服务器对客户端不可见。
# 用途
# 隐藏服务器真实ip：使用反向代理，可以对客户端隐藏服务器的ip地址
# 负载均衡：反向代理服务器可以做负载均衡，根据所有真实服务器的负载情况，将客户端请求分发到不同的真实服务器上
# 提高访问速度：反向代理服务器可以对静态内容及短时间内有大量访问请求的动态内容提供缓存服务，提高访问速度
# 提供安全保障：反向代理服务器可以作为应用层防火墙，为网站提供对基于web的攻击行为（例如DoS/DDoS）的防护，更容易排查恶意软件等。还可以为后端服务器统一提供加密和SSL加速（如SSL终端代理），提供HTTP访问认证等。

Nginx的优点
# 市面上的服务器非常多，我们为什么选择Nginx？Nginx以性能为王
# (1)速度更快、并发更高
# 这表现在两个方面：一方面，在正常情况下，单次请求会得到更快的响应；另一方面，在高峰期（如有数以万计的并发请求），Nginx可以比其他Web服务器更快地响应请求。
# (2)高扩展性，跨平台
# Nginx的设计极具扩展性，它完全是由多个不同功能、不同层次、不同类型且耦合度极低的模块组成。因此，当对某一个模块修复Bug或进行升级时，可以专注于模块自身，无须在意其他。而且在HTTP模块中，还设计了HTTP过滤器模块：一个正常的HTTP模块在处理完请求后，会有一串HTTP过滤器模块对请求的结果进行再处理。这样，当我们开发一个新的HTTP模块时，不但可以使用诸如HTTP核心模块、events模块、log模块等不同层次或者不同类型的模块，还可以原封不动地复用大量已有的HTTP过滤器模块。这种低耦合度的优秀设计，造就了Nginx庞大的第三方模块，当然，公开的第三方模块也如官方发布的模块一样容易使用。
# Nginx的模块都是嵌入到二进制文件中执行的，无论官方发布的模块还是第三方模块都是如此。这使得第三方模块一样具备极其优秀的性能，充分利用Nginx的高并发特性，因此，许多高流量的网站都倾向于开发符合自己业务特性的定制模块。
# (3)高可靠性：用于反向代理，宕机的概率微乎其微
# 高可靠性是我们选择Nginx的最基本条件，因为Nginx的可靠性是大家有目共睹的，很多家高流量网站都在核心服务器上大规模使用Nginx。Nginx的高可靠性来自于其核心框架代码的优秀设计、模块设计的简单性；另外，官方提供的常用模块都非常稳定，每个worker进程相对独立，master进程在1个worker进程出错时可以快速“拉起”新的worker子进程提供服务。
# (4)低内存消耗
# 一般情况下，10 000个非活跃的HTTP Keep-Alive连接在Nginx中仅消耗2.5MB的内存，这是Nginx支持高并发连接的基础。
# (5)单机支持10万以上的并发连接
# 这是一个非常重要的特性！随着互联网的迅猛发展和互联网用户数量的成倍增长，各大公司、网站都需要应付海量并发请求，一个能够在峰值期顶住10万以上并发请求的Server，无疑会得到大家的青睐。理论上，Nginx支持的并发连接上限取决于内存，10万远未封顶。当然，能够及时地处理更多的并发请求，是与业务特点紧密相关的。
# (6)热部署
# master管理进程与worker工作进程的分离设计，使得Nginx能够提供热部署功能，即可以在7×24小时不间断服务的前提下，升级Nginx的可执行文件。当然，它也支持不停止服务就更新配置项、更换日志文件等功能。
# (7)最自由的BSD许可协议
# 这是Nginx可以快速发展的强大动力。BSD许可协议不只是允许用户免费使用Nginx，它还允许用户在自己的项目中直接使用或修改Nginx源码，然后发布。这吸引了无数开发者继续为Nginx贡献自己的智慧。

2 Nginx安装
    Nginx版本
    获取Nginx源码
# 准备服务器系统

# (1)确认centos的内核
# 准备一个内核为2.6及以上版本的操作系统，因为linux2.6及以上内核才支持epoll,而Nginx需要解决高并发压力问题是需要用到epoll，所以我们需要有这样的版本要求。
# 我们可以使用 uname -a 命令来查询linux的内核版本。
[root@localhost ~]# uname -a
Linux localhost.localdomain 3.10.0-1062.el7.x86_64 #1 SMP Wed Aug 7 18:08:02 UTC 2019 x86_64 x86_64 x86_64 GNU/Linux

# (2)确保centos能联网
ping www.baidu.com

# (3)确认关闭防火墙
# 这一项的要求仅针对于那些对linux系统的防火墙设置规则不太清楚的，建议大家把防火墙都关闭掉，因为我们此次课程主要的内容是对Nginx的学习，把防火墙关闭掉，可以省掉后续Nginx学习过程中遇到的诸多问题。
# 关闭的方式有如下两种：
systemctl stop firewalld      # 关闭运行的防火墙，系统重新启动后，防火墙将重新打开
systemctl disable firewalld   # 永久关闭防火墙，系统重新启动后，防火墙依然关闭
systemctl status firewalld    # 查看防火墙状态

Nginx安装方式介绍
# Nginx的安装方式有两种分别是:
# 通过Nginx源码
# 通过yum安装

# 如果通过Nginx源码安装需要提前准备的内容:
# GCC编译器
# Nginx是使用C语言编写的程序，因此想要运行Nginx就需要安装一个编译工具。GCC就是一个开源的编译器集合，用于处理各种各样的语言，其中就包含了C语言。
# 使用命令 yum install -y gcc 来安装
yum install -y gcc
# 安装成功后，可以通过 gcc --version 来查看gcc是否安装成功
gcc --version

# PCRE
# Nginx在编译过程中需要使用到PCRE库（perl Compatible Regular Expressoin 兼容正则表达式库)，因为在Nginx的Rewrite模块和http核心模块都会使用到PCRE正则表达式语法。
# 可以使用命令 yum install -y pcre pcre-devel 来进行安装
yum install -y pcre pcre-devel
# 安装成功后，可以通过 rpm -qa pcre pcre-devel 来查看是否安装成功
rpm -qa pcre pcre-devel

# zlib
# zlib库提供了开发人员的压缩算法，在Nginx的各个模块中需要使用gzip压缩，所以我们也需要提前安装其库及源代码zlib和zlib-devel
yum install -y zlib zlib-devel
# 安装成功后，可以通过 rpm -qa zlib zlib-devel 来查看是否安装成功
rpm -qa zlib zlib-devel

# OpenSSL
# OpenSSL是一个开放源代码的软件库包，应用程序可以使用这个包进行安全通信，并且避免被窃听。
# SSL:Secure Sockets Layer安全套接协议的缩写，可以在Internet上提供秘密性传输，其目标是保证两个应用间通信的保密性和可靠性。
# 在Nginx中，如果服务器需要提供安全网页时就需要用到OpenSSL库，所以我们需要对OpenSSL的库文件及它的开发安装包进行一个安装。
yum install -y openssl openssl-devel
# 安装成功后，可以通过 rpm -qa openssl openssl-devel 来查看是否安装成功
rpm -qa openssl openssl-devel

# 上述命令，一个个来的话比较麻烦，我们也可以通过一条命令来进行全部安装
yum install -y gcc pcre pcre-devel zlib zlib-devel openssl openssl-devel

方案一: Nginx的源码简单安装
# (1)进入官网查找需要下载版本的链接地址，然后使用wget命令进行下载
wget http://nginx.org/download/nginx-1.22.1.tar.gz

# (2)建议大家将下载的资源进行包管理
mkdir -p nginx/core
mv nginx-1.22.1.tar.gz nginx/core

# (3)解压缩
tar -xzf nginx-1.22.1.tar.gz

# (4)进入资源文件中，发现configure
./configure

# (5)编译
make

# (6)安装
make install

方案二: yum安装
# 使用源码进行简单安装，我们会发现安装的过程比较繁琐，需要提前准备GCC编译器、PCRE兼容正则表达式库、zlib压缩库、OpenSSL安全通信的软件库包，然后才能进行Nginx的安装。
# (1) 安装yum-utils
sudo yum install -y yum-utils

# (2) 添加yum源文件
vim /etc/yum.repos.d/nginx.repo

# 写入下面内容到nginx.repo文件
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

# (3) 安装稳定版
# sudo yum-config-manager -- enable nginx-mainline

# (4) 安装
# sudo yum install nginx

# (5) 查看是否安装成功
# whereis nginx
nginx: /usr/sbin/nginx /usr/lib64/nginx /etc/nginx /usr/share/nginx /usr/share/man/man8/nginx.8.gz

源码简单安装和yum安装的差异:
# 这里先介绍一个命令: ./nginx -V ,通过该命令可以查看到所安装Nginx的版本及相关配置信息。
./nginx -V

# 简单安装
[root@test sbin]# ./nginx -V
# configure:nginx软件的自动脚本程序,是一个比较重要的文件，作用如下：
# (1) 检测环境及根据环境检测结果生成C代码
# (2) 生成编译代码需要的Makefile文件

# 通过 ./configure 来对编译参数进行设置，需要我们手动来指定。那么都有哪些参数可以进行设置，接下来我们进行一个详细的说明。

# PATH:是和路径相关的配置信息
# with:是启动模块，默认是关闭的
# without:是关闭模块，默认是开启的

# 我们先来认识一些简单的路径配置已经通过这些配置来完成一个简单的编译:
# --prefix=PATH
# 指向Nginx的安装目录，默认值为/usr/local/nginx

# --sbin-path=PATH
# 指向(执行)程序文件(nginx)的路径,默认值为<prefix>/sbin/nginx

# --modules-path=PATH
# 指向Nginx动态模块安装目录，默认值为<prefix>/modules

# --conf-path=PATH
# 指向配置文件(nginx.conf)的路径,默认值为<prefix>/conf/nginx.conf

# --error-log-path=PATH
# 指向错误日志文件的路径,默认值为<prefix>/logs/error.log

# --http-log-path=PATH
# 指向访问日志文件的路径,默认值为<prefix>/logs/access.log

# --pid-path=PATH
# 指向Nginx启动后进程ID的文件路径，默认值为<prefix>/logs/nginx.pid

# --lock-path=PATH
# 指向Nginx锁文件的存放路径,默认值为<prefix>/logs/nginx.lock

# 要想使用可以通过如下命令
./configure --prefix=/usr/local/nginx \
--sbin-path=/usr/local/nginx/sbin/nginx \
--modules-path=/usr/local/nginx/modules \
--conf-path=/usr/local/nginx/conf/nginx.conf \
--error-log-path=/usr/local/nginx/logs/error.log \
--http-log-path=/usr/local/nginx/logs/access.log \
--pid-path=/usr/local/nginx/logs/nginx.pid \
--lock-path=/usr/local/nginx/logs/nginx.lock

# 在使用上述命令之前，需要将之前服务器已经安装的nginx进行卸载，卸载的步骤分为三步骤：
# 步骤一：需要将nginx的进程关闭
./nginx -s stop

# 步骤二:将安装的nginx进行删除
rm -rf /usr/local/nginx

# 步骤三:将安装包之前编译的环境清除掉
make clean


Nginx目录结构分析
# 在使用Nginx之前，我们先对安装好的Nginx目录文件进行一个分析，在这块给大家介绍一个工具tree，通过tree我们可以很方面的去查看centos系统上的文件目录结构，当然，如果想使用tree工具，就得先通过 yum install -y tree 来进行安装，安装成功后，可以通过执行 tree /usr/local/nginx(tree后面跟的是Nginx的安装目录)，获取的结果如下:

# 安装tree工具
yum install -y tree
# 查看nginx目录结构
tree /usr/local/nginx/

# [root@localhost nginx-1.16.1]# tree /usr/local/nginx/
# /usr/local/nginx/
# ├── conf
# │   ├── fastcgi.conf
# │   ├── fastcgi.conf.default
# │   ├── fastcgi_params
# │   ├── fastcgi_params.default
# │   ├── koi-utf
# │   ├── koi-win
# │   ├── mime.types
# │   ├── mime.types.default
# │   ├── nginx.conf
# │   ├── nginx.conf.default
# │   ├── scgi_params
# │   ├── scgi_params.default
# │   ├── uwsgi_params
# │   ├── uwsgi_params.default
# │   └── win-utf
# ├── html
# │   ├── 50x.html
# │   └── index.html
# ├── logs
# └── sbin
#     └── nginx
# 4 directories, 18 files

# conf:nginx所有配置文件目录
# nginx.conf:这个是Nginx的核心配置文件，这个文件非常重要，也是我们即将要学习的重点
# html:存放nginx自带的两个静态的html页面
# 50x.html:访问失败后的失败页面
# index.html:成功访问的默认首页

# logs:记录日志的文件，当nginx服务器启动后，这里面会有 access.log error.log 和nginx.pid三个文件出现。
# sbin:是存放执行程序文件nginx
# nginx是用来控制Nginx的启动和停止等相关的命令。

# Nginx服务器启停命令
# Nginx安装完成后，接下来我们要学习的是如何启动、重启和停止Nginx的服务。
# 对于Nginx的启停在linux系统中也有很多种方式，我们本次课程介绍两种方式:
# 1. Nginx服务的信号控制
# 2. Nginx的命令行控制

Nginx服务的信号控制
# 前面在提到Nginx的高性能，其实也和它的架构模式有关。Nginx默认采用的是多进程的方式来工作的，当将Nginx启动后，我们通过 ps -ef | grep nginx 命令可以查看到如下内容：
ps -ef | grep nginx

# [root@silence0306 local]# ps -ef | grep nginx
# root      23959     1  0 00:00 ?        00:00:00 nginx: master process ./nginx
# nobody    23960 23959  0 00:00 ?        00:00:00 nginx: worker process
# root      25989 11467  0 02:15 pts/0    00:00:00 grep --color=auto nginx
# [root@silence0306 local]#

# 从上图中可以看到,Nginx后台进程中包含一个master进程和多个worker进程，master进程主要用来管理worker进程，包含接收外界的信息，并将接收到的信号发送给各个worker进程，监控worker进程的状态，当worker进程出现异常退出后，会自动重新启动新的worker进程。而worker进程则是专门用来处理用户请求的，各个worker进程之间是平等的并且相互独立，处理请求的机会也是一样的。nginx的进程模型，我们可以通过下图来说明下:

# 我们现在作为管理员，只需要通过给master进程发送信号就可以来控制Nginx,这个时候我们需要有两个前提条件，一个是要操作的master进程，一个是信号。

# (1) 要想操作Nginx的master进程，就需要获取到master进程的进程号ID。获取方式简单介绍两个，
# 方式一：通过 ps -ef | grep nginx;
ps -ef | grep nginx
# 方式二：在讲解nginx的./configure的配置参数的时候，有一个参数是--pid-path=PATH 默认是/usr/local/nginx/logs/nginx.pid,所以可以通过查看该文件来获取nginx的master进程ID.
cat /usr/local/nginx/logs/nginx.pid

# (2) 信号
# 信号	作用
# TERM/INT	立即关闭整个服务
# QUIT	    "优雅"地关闭整个服务
# HUP	    重读配置文件并使用服务对新配置项生效
# USR1	    重新打开日志文件，可以用来进行日志切割
# USR2	    平滑升级到最新版的nginx
# WINCH	    所有子进程不在接收处理新连接，相当于给work进程发送QUIT指令

# 调用命令为 kill -signal PID
# signal:即为信号；PID即为获取到的master线程ID

# 1.发送TERM/INT信号给master进程，会将Nginx服务立即关闭。
kill -TERM PID
kill -TERM `cat /usr/local/nginx/logs/nginx.pid`
kill -INT PID
kill -INT `cat /usr/local/nginx/logs/nginx.pid`

# 2.发送QUIT信号给master进程，master进程会控制所有的work进程不再接收新的请求，等所有请求处理完后，在把进程都关闭掉。
kill -QUIT PID
kill -QUIT `cat /usr/local/nginx/logs/nginx.pid`

# 3.发送HUP信号给master进程，master进程会把控制旧的work进程不再接收新的请求，等处理完请求后将旧的work进程关闭，然后根据nginx的配置文件重新启动新的work进程
kill -HUP PID
kill -HUP `cat /usr/local/nginx/logs/nginx.pid`

# 4.发送USR1信号给master进程，告诉Nginx重新开启日志文件
kill -USR1 PID
kill -USR1 `cat /usr/local/nginx/logs/nginx.pid`

# 5.发送USR2信号给master进程，告诉master进程要平滑升级，这个时候，会重新开启对应的master进程和work进程，整个系统中将会有两个master进程，并且新的master进程的PID会被记录在/usr/local/nginx/logs/nginx.pid而之前的旧的master进程PID会被记录在/usr/local/nginx/logs/nginx.pid.oldbin文件中，接着再次发送QUIT信号给旧的master进程，让其处理完请求后进行关闭
kill -USR2 PID
kill -USR2 `cat /usr/local/nginx/logs/nginx.pid`
kill -QUIT PID
kill -QUIT `cat /usr/local/nginx/logs/nginx.pid.oldbin`

# 6.发送WINCH信号给master进程,让master进程控制不让所有的work进程在接收新的请求了，请求处理完后关闭work进程。注意master进程不会被关闭掉
kill -WINCH PID
kill -WINCH `cat /usr/local/nginx/logs/nginx.pid`


Nginx的命令行控制
# 此方式是通过Nginx安装目录下的sbin下的可执行文件nginx来进行Nginx状态的控制，我们可以通过 nginx -h 来查看都有哪些参数可以用：
./nginx -h

# [root@localhost sbin]# ./nginx -h
# nginx version: nginx/1.16.1
# Usage: nginx [-?hvVtTq] [-s signal] [-c filename] [-p prefix] [-g directives]
#
# Options:
#   -?,-h         : this help
#   -v            : show version and exit
#   -V            : show version and configure options then exit
#   -t            : test configuration and exit
#   -T            : test configuration, dump it and exit
#   -q            : suppress non-error messages during configuration testing
#   -s signal     : send signal to a master process: stop, quit, reopen, reload
#   -p prefix     : set prefix path (default: /usr/local/nginx/)
#   -c filename   : set configuration file (default: conf/nginx.conf)
#   -g directives : set global directives out of configuration file

# -?和-h:显示帮助信息
# -v:打印版本号信息并退出
# -V:打印版本号信息和配置信息并退出
# -t:测试nginx的配置文件语法是否正确并退出
# -T:测试nginx的配置文件语法是否正确并列出用到的配置文件信息然后退出
# -q:在配置测试期间禁止显示非错误消息
# -s:signal信号，后面可以跟 :
#   stop[快速关闭，类似于TERM/INT信号的作用]
#   quit[优雅的关闭，类似于QUIT信号的作用]
#   reopen[重新打开日志文件类似于USR1信号的作用]
#   reload[类似于HUP信号的作用]
# -p:prefix，指定Nginx的prefix路径，(默认为: /usr/local/nginx/)
# -c:filename,指定Nginx的配置文件路径,(默认为: conf/nginx.conf)
# -g:用来补充Nginx配置文件，向Nginx服务指定启动时应用全局的配置

Nginx核心配置文件结构
# 从前面的内容学习中，我们知道Nginx的核心配置文件默认是放在/usr/local/nginx/conf/nginx.conf，这一节，我们就来学习下nginx.conf的内容和基本配置方法。
# 读取Nginx自带的Nginx配置文件，我们将其中的注释部分【学习一个技术点就是在Nginx的配置文件中可以使用 # 来注释】删除掉后，就剩下下面内容:

worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;
        location / {
            root   html;
            index  index.html index.htm;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}

# 指令名 指令值;  #全局块，主要设置Nginx服务器整体运行的配置指令
# #events块,主要设置,Nginx服务器与用户的网络连接,这一部分对Nginx服务器的性能影响较大
# events {
#     指令名 指令值;
# }

# #http块，是Nginx服务器配置中的重要部分，代理、缓存、日志记录、第三方模块配置...
# http {
#     指令名 指令值;
#     server { #server块，是Nginx配置和虚拟主机相关的内容
#         指令名 指令值;
#         location / {
#             #location块，基于Nginx服务器接收请求字符串与location后面的值进行匹配，对特定请求进行处理
#             指令名 指令值;
#         }
#     }
#     ...
# }

# nginx.conf配置文件中默认有三大块：全局块、events块、http块
# http块中可以配置多个server块，每个server块又可以配置多个location块。

Nginx基础配置
# 最小配置文件
# 核心配置
# 虚拟主机配置

最小配置
# worker_processes
worker_processes  1; #默认为1，表示开启一个业务进程

# worker_connections
worker_connections  1024; #单个业务进程可接受连接数

# include mime.types;
include       mime.types; #引入http mime类型

# default_type application/octet-stream;
default_type  application/octet-stream; #如果mime类型没匹配上，默认使用二进制流的方式传输。

# sendfile on;
sendfile        on; #使用linux的sendfile(socket, file, len)高效网络传输，也就是数据0拷贝。
# 未开启sendfile 

















