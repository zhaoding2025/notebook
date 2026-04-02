## 安装Apache
## 功能用途：自动化安装并启动Apache服务器
#!/bin/bash
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
echo "Apache服务器已安装并启动"

## 安装MySQL数据库
## 功能用途：自动化安装MySQL数据库，并提示进行安装设置
#!/bin/bash
sudo apt-get update
sudo apt-get install -y mysql-server
sudo mysql_secure_installation
sudo systemctl start mysql
sudo systemctl enable mysql
echo "MySQL数据库已安装并启动"

## 备份MySQL数据库
## 功能用途：备份指定的MySQL数据库到指定目录
#!/bin/bash
USER="your_mysql_user"
PASSWORD="your_mysql_password"
DB_NAME="your_database_name"
BACKUP_DIR="/path/to/backup"
DATE=$(date + "%Y-%m-%d")
mysqldump -u $USER -p$PASSWORD $DB_NAME > $BACKUP_DIR/$DB_NAME - $DATE.sql
echo "数据库已备份到 $BACKUP_DIR"


## 安装Nginx
## 功能用途：自动化安装并启动Nginx服务器
#!/bin/bash
sudo apt-get update
sudo apt-get install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo "Nginx 服务器已安装并启动"


## 配置防火墙
## 功能用途：配置防火墙以允许Nginx和SSH服务
#!/bin/bash
sudo ufw allow 'Nginx Full'
sudo ufw allow 'OpenSSH'
sudo ufw enable
sudo ufw status 
echo "防火墙已配置并启用"

## 更新系统
## 功能用途：更新系统软件包，并重启系统以应用更改
#!/bin/bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get dist_upgrade -y
sudo reboot
echo "系统已更新并重启"

## 监控CPU和内存使用率
## 功能用途：用于快速、集中地获取系统资源的实时状态
#!/bin/bash
watch -n 1 'free -m && top -bn1 |grep "Cpu(s)"'

## 安装PHP
## 功能用途：安装PHP及其Apache模块，以便在Apache服务器上运行PHP代理
#!/bin/bash
sudo apt-get update
sudo apt-get install -y php libapache2-mod-php php-mysql
sudo systemctl restart apache2
echo "PHP已安装并配置为Apache模块"

## 清理系统日志
## 清空系统日志文件
#!/bin/bash
sudo find /var/log/ -type f -name "*.log" -exec truncate -s 0 {} \;
echo "系统日志已清空"

## 查找大文件
## 查找系统中大于100MB的文件
#!/bin/bash
sudo find / -type f -size +100M -exec ls -lh {} \; | awk '{ print $9 ":" $5 }'

## 安装Git
## 更新系统软件包，并重启系统以应用更改
#!/bin/bash
sudo apt-get update
VERSION="node_14.x"
DISTRO=$(lsb_release -s -c)
echo "deb https://deb:nodesource.com/$VERSION $DISTRO main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update
sudo apt-get install -y nodejs
echo "Node.js已安装"

## 检查磁盘空间
## 功能用途：用于快速扫描和分析存储设备的空间使用情况
#!/bin/bash
df -h | grep -Ev '^Filesystem|tmpfs|cdrom'

## 压缩目录
## 功能用途：压缩指定目录为tar.gz格式文件
#!/bin/bash
read -p "请输入要压缩的目录路径：" DIR_PATH
read -p "请输入压缩文件的名称：" ARCHIVE_NAME
tar -czvf $ARCHIVE_NAME.tar.gz -C $(dirname $DIR_PATH) $(basename $DIR_PATH)
echo "目录已压缩为 $ARCHIVE_NAME.tar.gz"

## 安装Python虚拟环境
## 安装指定版本的Python及其虚拟环境工具
#!/bin/bash
PYTHON_VERSION="3.8"
sudo apt-get update
sudo apt-get install -y python3-$PYTHON_VERSION python3-venv
echo "Python虚拟环境工具已安装"