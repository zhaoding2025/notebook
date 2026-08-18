报错1:登录报错
[root@localhost ~]# ansible 172.16.96.139 -m ping
172.16.96.139 | UNREACHABLE! => {
    "changed": false,
    "msg": "Failed to connect to the host via ssh: root@172.16.96.139: Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password).",
    "unreachable": true
}

# 解决方法：
# 方法1
[root@localhost ~]# ansible all -m ping -k
SSH password: 
172.16.96.139 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
[root@localhost ~]# ansible 172.16.96.139 -m ping

# 方法2:
在 inventory 清单里写死密码（快速）
如果你的主机清单是 hosts,改成：
[servers]
172.16.96.139 ansible_ssh_user=root ansible_ssh_pass=你的root密码

# 方法3:
配置免密登录
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ssh-copy-id root@172.16.96.139


报错2:root@172.16.96.140: Permission denied
Jenkins 运行用户是 jenkins，不是 root！
# 解决方法：
# 1. 切换到 jenkins 用户
su - jenkins -s /bin/bash
# 2. 生成密钥（一路回车）
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
# 3. 发送免密到 140 机器
ssh-copy-id root@172.16.96.140
ssh-copy-id root@172.16.96.139
ssh-copy-id root@172.16.96.100
ssh-copy-id root@172.16.96.141
