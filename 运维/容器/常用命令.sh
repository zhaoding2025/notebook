1.镜像的分层结构
docker pull nginx时你会看到它一层层地下载:
# a076a6285026: Pull complete   ← 基础系统层（Debian）
# 38e9eb68733e: Pull complete   ← 系统依赖层
# 6c2fdb00dba8: Pull complete   ← Nginx 程序本体层

2.镜像的「名字」：仓库名:
[registry 地址 /] 仓库名 [: 标签]
# 例如 docker.io/library/nginx:1.25可以拆解为：
# 仓库名（repository）：镜像的名字，比如 nginx、mysql、ubuntu。
# 标签（tag）：同一个镜像的不同版本，比如 nginx:1.25、nginx:1.24、nginx:latest。
# registry 地址：省略时默认是 docker.io（Docker Hub）；
# library/是官方镜像的命名空间，也通常省略。

3.五个常用的镜像命令
3.1 搜索镜像 docker search
# docker search mysql        # 搜索 mysql 相关镜像
3.2 拉取镜像 docker pull
# docker pull nginx          # 拉取最新标签（latest）
# docker pull nginx:1.25     # 拉取指定版本
# docker pull redis:7        # 拉取 redis 7.x
3.3 查看本地镜像 docker images
# docker images              # 查看本地所有镜像
# docker images nginx        # 只看 nginx 相关镜像
3.4 查看镜像「底细」 docker inspect/ docker history
# docker inspect nginx:1.25  # 查看镜像完整元数据（JSON）
# docker history nginx:1.25  # 查看镜像的「层历史」，每层做了什么
3.5 打标签 / 重命名：docker tag
# docker tag nginx:1.25 myapp/nginx:prod        # 复制一个带新标签的镜像
# docker tag <IMAGE ID> myrepo/web:v2           # 用 IMAGE ID 也行

4.镜像的删除与清理
# 删除指定镜像（-f 强制删除）
# docker rmi nginx:1.25
# docker rmi <IMAGE ID>

# # 删除所有「悬空」镜像（无名字、无标签的中间层）
# docker image prune

# # 一键清理所有未使用的镜像（危险，慎用）
# docker image prune -a

# docker ps -a                 # 找到占用它的容器
# docker rm <容器ID>           # 删容器
# docker rmi <镜像ID>          # 再删镜像
# docker system df             # 总览镜像 / 容器 / 数据卷 / 构建缓存
# docker system df -v          # 详细列出每个对象
# docker image ls -q           # 只列出镜像 ID，方便批量处理
# docker images --digests      # 顺便看 digest

5.把镜像推送到远程仓库 login/ tag/ push
# ① 登录仓库（Docker Hub）
# docker login                # 输入用户名和密码（或 Access Token）

# # ② 给镜像打上「带账号前缀」的标签
# docker tag myapp:1.0 <你的用户名>/myapp:1.0

# # ③ 推送上去
# docker push <你的用户名>/myapp:1.0


6.镜像的导出和导入 save/ load
# ① 在有网的机器上：把镜像「打成包」
docker save -o nginx.tar nginx:1.25

# ② 把 nginx.tar 拷贝到目标机器
# ③ 在目标机器上：从包里「加载」镜像
docker load -i nginx.tar

7.容器的生命周期
# created：已创建但未启动（docker create 或刚 run时的瞬间）
# running：正在运行
# paused：暂停中（进程被挂起，docker pause）
# exited：已停止退出（正常退出或被杀）
# deleted：被删除，彻底消失
# 记住这条主线：create → run → stop → rm，其余都是这条线上的「驿站」

8.docker使用和操作
8.1 启动容器: docker run详解
docker run [选项] 镜像[:标签] [命令]
# -d 后台运行（守护模式）
docker run -d nginx

# -it 交互式终端（进入容器内）
docker run -it ubuntu bash

# --name 给容器起个名字
docker run --name web nginx

# --rm 容器退出后自动删除
docker run --rm ubuntu echo hi

# -p 端口映射（第 5 篇细讲）
docker run -p 8080:80 nginx

# -v 挂载数据卷（第 4 篇细讲）
docker run -v /data:/var/lib/mysql mysql

# -e 设置环境变量
docker run -e MYSQL_ROOT_PASSWORD=123 mysql

# --restart 重启策略
docker run --restart=always nginx

# 案例
# 后台跑一个 Web 服务
docker run -d --name my-nginx -p 8080:80 nginx     
# -d 后台运行，--name 命名，-p 把宿主机 8080 映射到容器 80

#交互式进入一个 Linux 环境
docker run -it --rm ubuntu bash       
# -it 交互终端，--rm 退出即删（不留垃圾）

# 💡 -d与 -it的区别：-d是「托管式」后台运行；-it是「面对面」进到容器里敲命令。二者通常二选一。


8.2 查看容器 docker ps
# docker ps          # 只看正在运行的容器
# docker ps -a       # 看所有容器（含已停止的）
# docker ps -l       # 看最近一个创建的容器
# docker ps -q       # 只输出容器 ID

# 几个常见的 STATUS 值
# Up 5 minutes          正在运行，已运行 5 分钟
# Exited (0) 2 hours ago 正常退出（返回码 0），2 小时前退出
# Exited (137)          被 SIGKILL（通常 docker kill）杀掉
# Paused                 已被 docker pause 挂起
# Created                已创建但未启动

8.3 进入一个正在运行的容器 docker exec
# docker exec -it my-nginx bash        # 进入容器，开个 bash
# docker exec my-nginx ls /            # 不进入，直接执行一条命令
# ⚠️ exec 与 attach 的区别：exec是「新开一个进程」进入（推荐）；attach是「接上主进程」的终端，退出时容易把容器一起搞停。日常用 exec -it就够了。


8.4 停止、启动、重启、暂停
# docker stop my-nginx         # 优雅停止（给进程时间善后）
# docker start my-nginx        # 启动一个已停止的容器
# docker restart my-nginx      # 重启（先 stop 再 start）
# docker pause my-nginx        # 暂停（挂起进程，内存保留）
# docker unpause my-nginx      # 恢复暂停

# 💡 stop与 kill的区别：stop先发 SIGTERM 优雅退出，超时（默认 10 秒）才 SIGKILL；kill直接 SIGKILL 强杀。日常优先用 stop

8.5 删除容器 docker rm
# docker rm my-nginx             # 删除已停止的容器
# docker rm -f my-nginx          # 强制删除（运行中的也能删）
# docker rm $(docker ps -aq)     # 删除所有容器（慎用）
# docker container prune         # 清理所有已停止的容器

# 先停再删是标准姿势；加了 -f才能删正在运行的容器（不推荐）。

8.6 日志与进程管理
# docker logs my-nginx                # 查看容器日志
# docker logs -f my-nginx             # 实时跟踪日志（类似 tail -f）
# docker logs --tail 100 my-nginx     # 只看最后 100 行
# docker top my-nginx                 # 查看容器内进程

8.7 宿主机与容器互拷文件 docker cp
# 宿主机 → 容器
docker cp ./index.html my-nginx:/usr/share/nginx/html/

# 容器 → 宿主机
docker cp my-nginx:/etc/nginx/nginx.conf ./










