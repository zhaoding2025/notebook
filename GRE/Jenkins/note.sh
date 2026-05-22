一.java安装
1.安装
# dnf install -y java-21-openjdk java-21-openjdk-devel
2.配置
  配置系统默认 Java 21
# alternatives --config java
# 这里会弹出选项，输入 java-21 对应的数字，按回车
3.配置java_home
# 配置 JAVA_HOME 指向 21
cat > /etc/profile.d/java.sh <<'EOF'
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export PATH=$JAVA_HOME/bin:$PATH
EOF
4.使环境变量生效
# source /etc/profile.d/java.sh

二、jenkins安装
1.添加Jekins存储库和安装jekins
# wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
# rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
#  dnf repolist
显示jekins

2.安装jenkins
# dnf install jenkins

3.创建自动启动命令
# systemctl daemon-reload
# systemctl status jenkins

4.修改端口到8100
# vim /usr/lib/systemd/system/jenkins.service

#Environment="JENKINS_PORT=8080"
Environment="JENKINS_PORT=8100"

-- 启动服务
# systemctl daemon-reload
# systemctl start jenkins

5.确认初始密码
# cat /var/lib/jenkins/secrets/initialAdminPassword
843080f02cf142a4afeceaa1b6083754

