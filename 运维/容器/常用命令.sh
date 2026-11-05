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

5.把镜像推送到远程仓库：login/ tag/ push
# ① 登录仓库（Docker Hub）
# docker login                # 输入用户名和密码（或 Access Token）

# # ② 给镜像打上「带账号前缀」的标签
# docker tag myapp:1.0 <你的用户名>/myapp:1.0

# # ③ 推送上去
# docker push <你的用户名>/myapp:1.0


6.镜像的导出和导入：save/ load
# ① 在有网的机器上：把镜像「打成包」
docker save -o nginx.tar nginx:1.25

# ② 把 nginx.tar 拷贝到目标机器
# ③ 在目标机器上：从包里「加载」镜像
docker load -i nginx.tar
