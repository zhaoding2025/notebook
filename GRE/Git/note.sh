一.gitlab安装
1.更新dnf软件包列表
# sudo dnf update -y

2.安装依赖包
# sudo dnf install curl policycoreutils-python-utils openssh-server -y

3.安装postfix
# sudo dnf install postfix -

4.添加gitlab仓库
# curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash

5.安装gitlab ce
# sudo dnf install gitlab-ce -y

6.配置gitlab
# sudo nano /etc/gitlab/gitlab.rb

常见的配置选项：

external_url: 设置 GitLab 的外部访问 URL。你需要将其替换为你的服务器的域名或 IP 地址。
ruby external_url 'http://your_server_ip'
或者，如果你有域名：
ruby external_url 'https://your_domain.com'
如果你使用了 HTTPS,你需要配置 SSL 证书。这里我们使用 HTTP 进行演示,如果需要HTTPS,请参考官方文档进行配置。
gitlab_rails['gitlab_shell_ssh_port']: 设置GitLab的SSH端口,默认为22。如果你的SSH使用了其他端口,则需要修改此处。
ruby gitlab_rails['gitlab_shell_ssh_port'] = 22

gitlab_rails['smtp_enable']: 如果你需要启用 SMTP 邮件通知，可以进行以下配置：
ruby gitlab_rails['smtp_enable'] = true gitlab_rails['smtp_address'] = "smtp.example.com" gitlab_rails['smtp_port'] = 587 gitlab_rails['smtp_user_name'] = "your_smtp_user" gitlab_rails['smtp_password'] = "your_smtp_password" gitlab_rails['smtp_domain'] = "example.com" gitlab_rails['smtp_authentication'] = "login" gitlab_rails['smtp_enable_starttls_auto'] = true
请将 smtp.example.com,your_smtp_user,your_smtp_password,example.com 替换为你自己的 SMTP 服务器信息。 如果不需要邮件功能，则可以忽略此配置。

7.重新配置gitlab
# sudo gitlab-ctl reconfigure

8.访问gitlab
地址是 http://your_server_ip 或 https://your_domain.com
首次访问需要设置 GitLab 的 root 用户的密码

9.登录gitlab

10.创建用户和项目

11.配置防火墙
允许 HTTP 端口 (默认 80) 或 HTTPS 端口 (默认 443) 通过。
# sudo firewall-cmd --permanent --add-service=http
# sudo firewall-cmd --permanent --add-service=https
# sudo firewall-cmd --reload

