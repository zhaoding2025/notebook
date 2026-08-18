一.Ansible安装
1.安装
# dnf -y install ansible-core
查看版本
# ansible --version

2.修改配置文件
备份并从新生成配置文件
# mv /etc/ansible/ansible.cfg /etc/ansible/ansible.cfg
# ansible-config init --disabled > /etc/ansible/ansible.

取消主机密钥检查
# vi /etc/ansible/ansible.cfg
host_key_checking=False    #318行

3.配置管理目标主机
# vim /etc/ansible/hosts
10.32.161.134
10.32.161.135


4.基础使用
查看所有主机情况
# ansible all --list-hosts

查看管理主机组情况
# ansible bigdata --list-hosts


二、Ansible相关文件
1.配置文件
/etc/ansible/ansible.cfg    主配置文件,配置ansible工作特性
/etc/ansible/hosts          主机清单
/etc/ansible/roles          存放角色的目录

2.ansible主配置文件
ansible的配置文件/etc/ansible/ansible.cfg




二.基本命令使用
1.ansible的ping模块
    使用ansible的ping模块可以快速检查目标主机是否可达,是ansible入门的首个命令
2.command模块
    允许执行远程主机上的命令,是执行简单任务的常用方式
3.copy模块
    文件复制操作:copy模块用于将文件从控制机复制到远程主机,是文件管理的基础操作
    权限和所有权设置:允许用户指定文件权限和所有权,确保文件在远程主机上的正确位置
    变量替换功能:支持在复制文件时进行变量替换,使得文件内容可以根据不同环境动态调整
4.hostname模块
    设置主机名:使用hostname模块可以远程设置或更改系统主机名
    持久化主机名:支持更改持久化到系统配置文件中,确保重启后主机名依然有效
    检查主机名状态:
5.file模块
    创建和删除文件:可以创建文件、目录或删除指定的文件和目录,实现文件管理
    修改文件权限:允许用户设置文件或目录的权限,如更改文件所有者、修改读写执行权限
    设置文件属性:可以设置文件的属性,例如修改文件的修改时间、访问时间





