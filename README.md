# 系统安全工具集

## 项目说明
本项目包含两个主要工具：
1. [等保测评检查工具](#等保测评检查和修复工具-v50-使用说明)：自动化等保合规检查与修复工具
2. [系统配置工具](#linux系统配置工具)：Linux系统基础配置管理工具

## 快速开始

### 获取代码
```bash
# 克隆仓库
git clone https://github.com/chenfle/system_security_tool.git

# 进入项目目录
cd system_security_tool

# 赋予执行权限
chmod +x *.sh  */*.sh
```

### 分支说明
- `main`: 主分支，稳定版本
- `develop`: 开发分支，最新特性
- `release/*`: 发布分支
- `hotfix/*`: 紧急修复分支

### 贡献代码
1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/xxx`
3. 提交更改：`git commit -am 'Add feature xxx'`
4. 推送分支：`git push origin feature/xxx`
5. 提交 Pull Request

---

# 等保测评检查和修复工具 V5.0 使用说明

## 工具简介
- **作者**：陈甫罗恩@正元数币
- **参考来源**：李宇辰@正元智慧
- **版本**：5.0
- **功能**：自动化等保合规检查与修复工具

## 使用方法

### 快速开始
1. **获取工具**
```bash
# 克隆仓库
git clone [https://github.com/chenfle/system_security_tool.git]

# 赋予执行权限
chmod +x security_check.sh 
```

2. **运行检查**
```bash
sudo ./security_check.sh
```

3. **查看结果**
- 检查日志位于 `logs` 目录
- 配置备份位于 `logs/backup` 目录
- 报告文件位于 `logs/report` 目录

## 环境要求

### 系统要求
- 必须以root用户运行
- Linux操作系统（推荐CentOS/RHEL）

### 依赖命令
必需的系统命令：
- systemctl：系统服务管理
- sed：文本处理
- awk：文本分析
- grep：文本搜索
- cp：文件复制
- mv：文件移动
- rm：文件删除
- cat：文件查看
- chmod：权限修改
- chown：所有者修改

## 功能模块说明及实现代码

### 1. SSH安全配置
**功能说明**：
- 通过修改SSH默认端口和配置防火墙规则，提高系统安全性
- 防止常见的SSH暴力破解和扫描攻击
- 确保远程管理访问的安全性

**检查和配置项目**：
- 防火墙状态：确保firewalld服务正常运行
- SSH端口：修改默认22端口为1727
- 防��墙规则：仅开放必要端口
- 服务状态：确保配置后SSH服务正常运行

**预期效果**：
- 降低被扫描和攻击的风险
- 保持系统远程管理功能可用
- 提供安全的远程访问方式

**实现代码**：
```bash
# 1. 检查并启用防火墙
systemctl status firewalld
systemctl start firewalld
systemctl enable firewalld

# 2. 修改SSH端口
sed -i 's/^#Port 22/Port 1727/' /etc/ssh/sshd_config
# 或者追加新端口
echo "Port 1727" >> /etc/ssh/sshd_config

# 3. 配置防火墙规则
firewall-cmd --permanent --add-port=1727/tcp
firewall-cmd --reload

# 4. 重启SSH服务
systemctl restart sshd
```

### 2. 信任关系检查
**功能说明**：
- 检查并清理系统中可能存在的危险信任关系
- 防止通过信任关系进行未授权访问
- 加强系统访问控制

**检查和配置项目**：
- .rhosts文件：用户级别的信任关系文件
- hosts.equiv：系统级别的信任关系文件
- rsh相关服务：不安全的远程shell服务
- 信任关系配置：清理危险的信任配置

**预期效果**：
- 消除不安全的信任关系
- 防止未授权的远程访问
- 提高系统安全性

**实现代码**：
```bash
# 1. 检查并删除.rhosts文件
find / -name .rhosts -type f -exec rm -f {} \;

# 2. 检查并删除hosts.equiv文件
rm -f /etc/hosts.equiv

# 3. 禁用rsh服务
systemctl stop rsh.socket
systemctl disable rsh.socket
```

### 3. 账户安全检查
**功能说明**：
- 全面检查系统账户安全状况
- 识别和处理重复的用户账户
- 确保账户唯一性和安全性

**检查和配置项目**：
- 用户名重复：检查同名账户
- UID重复：检查重复的用户ID
- 账户权限：检查特权账户
- 账户状态：检查僵尸账户和过期账户

**预期效果**：
- 确保账户管理规范
- 防止账户混乱和越权
- 提高系统账户安全性

**实现代码**：
```bash
# 1. 检查重复用户
cat /etc/passwd | cut -d: -f1 | sort | uniq -d

# 2. 检查重复UID
cat /etc/passwd | cut -d: -f3 | sort | uniq -d

# 3. 显示详细信息
awk -F: '{print $1,$3}' /etc/passwd | sort -n -k2 | awk '{
    if(uid==$2) {
        if(count==0) print last;
        print $0;
        count++
    } else {
        uid=$2;
        last=$0;
        count=0
    }
}'
```

### 4. 密码安全检查
**功能说明**：
- 全面检查系统密码安全状况
- 处理存在安全隐患的账户
- 强制实施密码安全策略

**检查和配置项目**：
- 空密码账户：检查和处理无密码账户
- 密码锁定：对不安全账户进行锁定
- 密码过期：强制密码更新策略
- 密码合规：确保密码符合安全要求

**预期效果**：
- 消除空密码安全隐患
- 确保密码管理规范
- 提高账户访问安全性

**实现代码**：
```bash
# 1. 检查空密码账户
awk -F: '($2 == "" ) { print $1 }' /etc/shadow

# 2. 锁定空密码账户
awk -F: '($2 == "" ) { print $1 }' /etc/shadow | xargs -I {} passwd -l {}

# 3. 强制用户下次登录修改密码
awk -F: '($2 == "" ) { print $1 }' /etc/shadow | xargs -I {} chage -d 0 {}
```

### 5. 密码策略配置
**功能说明**：
- 实施严格的密码生命周期管理
- 强制密码定期更新机制
- 预防密码过期风险

**检查和配置项目**：
- 密码最长使用期限：90天
- 密码最短使用期限：7天
- 密码过期警告：提前7天
- 密码更新策略：自动提醒和强制更新

**预期效果**：
- 确保密码定期更新
- 防止密码长期不变
- 降低密码泄露风险

**实现代码**：
```bash
# 1. 修改/etc/login.defs文件
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 7/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 7/' /etc/login.defs

# 2. 应用到现有用户
for user in $(cat /etc/shadow | cut -d: -f1); do
    chage --maxdays 90 --mindays 7 --warndays 7 $user
done

# 3. 检查设置
grep "^PASS" /etc/login.defs
```

### 6. 密码复杂度设置
**功能说明**：
- 实施强密码策略
- 确保密码符合复杂度要求
- 防止简单密码的使用

**检查和配置项目**：
- 最小长度：不少于8个字符
- 字符组成：必须包含大小写字母、数字和特殊字符
- 历史记录：防止重复使用最近的密码
- 复杂度规则：限制连续和重复字符

**预期效果**：
- 提高密码强度
- 防止弱密码使用
- 增强账户安全性

**实现代码**：
```bash
# 1. 安装pam_cracklib
yum install -y libpwquality

# 2. 修改/etc/pam.d/system-auth文件
sed -i '/pam_pwquality.so/c\password    requisite     pam_pwquality.so try_first_pass retry=3 minlen=8 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1' /etc/pam.d/system-auth

# 3. 修改/etc/security/pwquality.conf
cat > /etc/security/pwquality.conf << EOF
minlen = 8
ucredit = -1
lcredit = -1
dcredit = -1
ocredit = -1
minclass = 4
maxrepeat = 3
EOF
```

### 7. 登录失败策略
**功能说明**：
- 防止暴力破解攻击
- 实施账户保护机制
- 记录异常登录行为

**检查和配置项目**：
- 失败次数限制：连续5次失败后锁定
- 锁定时间：300秒自动解锁
- 记录管理：保存登录失败记录
- 解锁机制：支持手动解锁

**预期效果**：
- 防止密码暴力破解
- 保护账户安全
- 便于安全审计

**实现代码**：
```bash
# 1. 配置PAM模块
cat >> /etc/pam.d/system-auth << EOF
auth        required      pam_tally2.so deny=5 unlock_time=300 even_deny_root root_unlock_time=300
account     required      pam_tally2.so
EOF

# 2. 查看失败记录
pam_tally2 --user username

# 3. 解锁用户
pam_tally2 -r -u username
```

### 8. 会话超时配置
**功能说明**：
- 防止会话劫持风险
- 保护空闲会话安全
- 强制会话自动断开

**检查和配置项目**：
- 全局超时：设置TMOUT环境变量
- SSH超时：配置客户端活动检测
- 自动断开：空闲会话处理
- 超时时间：统一设置为300秒

**预期效果**：
- 防止会话被盗用
- 保护空闲终端
- 减少安全隐患

**实现代码**：
```bash
# 1. 设置全局TMOUT
echo "TMOUT=300" >> /etc/profile
echo "readonly TMOUT" >> /etc/profile
echo "export TMOUT" >> /etc/profile

# 2. 设置SSH超时
sed -i 's/#ClientAliveInterval.*/ClientAliveInterval 300/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveCountMax.*/ClientAliveCountMax 0/' /etc/ssh/sshd_config

# 3. 应用设置
source /etc/profile
systemctl restart sshd
```

### 9. 服务安全配置
**功能说明**：
- 关闭不必要的网络服务
- 减少系统攻击面
- 优化系统服务配置

**检查和配置项目**：
- 不安全服务：telnet、ftp等
- 系统服务：优化开机自启服务
- 服务管理：统一服务启停控制
- 安全加固：关闭高风险服务

**预期效果**：
- 减少安全风险
- 优化系统性能
- 加强服务管理

**实现代码**：
```bash
# 1. 停止并禁用telnet服务
systemctl stop telnet.socket
systemctl disable telnet.socket

# 2. 停止并禁用FTP服务
systemctl stop vsftpd
systemctl disable vsftpd

# 3. 检查并关闭其他不必要服务
for service in rsh rlogin rexec; do
    systemctl stop $service
    systemctl disable $service
done
```

### 10. 审计配置
**功能说明**：
- 实施系统审计机制
- 记录关键操作行为
- 支持安全事件追溯

**检查和配置项目**：
- 审计范围：系统关键文件和操作
- 审计规则：自定义审计策略
- 日志管理：审计日志的存储和轮转
- 权限控制：审计用户的权限管理

**预期效果**：
- 记录重要操作
- 支持安全审计
- 便于事件追溯

**实现代码**：
```bash
# 1. 安装审计工具
yum install -y audit

# 2. 配置审计规则
cat >> /etc/audit/rules.d/audit.rules << EOF
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity
EOF

# 3. 启动审计服务
systemctl enable auditd
systemctl start auditd

# 4. 创建审计用户
useradd -m -s /bin/bash audit_user
usermod -aG wheel audit_user

# 5. 配置sudo权限
echo "audit_user ALL=(ALL) NOPASSWD: /usr/bin/ausearch, /usr/bin/aureport" >> /etc/sudoers.d/audit_user
```

### 11. 审计账户管理
**功能说明**：
- 创建专用审计账户
- 配置审计权限
- 设置日志记录
- 管理审计功能

**实现代码**：
```bash
# 1. 创建审计账户
useradd -m -s /bin/bash auditor
echo "[Ejgm9@#Y+9BD" | passwd --stdin auditor

# 2. 设置目录权限
setfacl -m u:auditor:rx /*

# 3. 配置审计权限
usermod -aG wheel auditor
```

### 12. 审计权限配置
**功能说明**：
- 配置sudo权限
- 限制命令执行
- 记录审计日志

**实现代码**：
```bash
# 1. 配置sudo权限
cat >> /etc/sudoers << EOF
auditor ALL=(ALL) NOPASSWD:/usr/bin/ls
auditor ALL=(ALL) NOPASSWD:/usr/bin/cat
auditor ALL=(ALL) NOPASSWD:/usr/bin/grep
auditor ALL=(ALL) NOPASSWD:/usr/bin/tail
auditor ALL=(ALL) NOPASSWD:/usr/bin/head
EOF

# 2. 设置日志记录
echo 'Defaults:auditor logfile="/var/log/sudo_audit.log"' >> /etc/sudoers
```

### 13. 共享账户检查
**功能说明**：
- 检查系统共享账户
- 清理过期账户
- 优化账户权限

**实现代码**：
```bash
# 1. 检查共享账户
for account in ftp games gopher operator; do
    if id "$account" &>/dev/null; then
        echo "发现共享账户: $account"
        userdel -r "$account"
    fi
done

# 2. 检查账户状态
chage -l username
```

### 14. Root访问限制
**功能说明**：
- 限制root远程登录
- 配置sudo访问控制
- 加强root安全性

**实现代码**：
```bash
# 1. 禁止root远程登录
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# 2. 重启SSH服务
systemctl restart sshd

# 3. 配置sudo访问
echo "Defaults requiretty" >> /etc/sudoers
```

### 15. 系统审计功能
**功能说明**：
- 配置审计系统
- 设置审计规则
- 管理审计日志

**实现代码**：
```bash
# 1. 安装审计系统
yum install -y audit

# 2. 配置审计规则
cat > /etc/audit/rules.d/audit.rules << EOF
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins
EOF

# 3. 启动审计服务
systemctl enable auditd
systemctl start auditd
```

### 16. 服务优化配置
**功能说明**：
- 关闭非必要服务
- 优化服务配置
- 加强服务安全

**实现代码**：
```bash
# 1. 检查并关闭服务
for service in chargen-dgram chargen-stream daytime-dgram daytime-stream \
    discard-dgram discard-stream echo-dgram echo-stream time-dgram time-stream \
    tftp xinetd; do
    systemctl stop $service
    systemctl disable $service
done

# 2. 检查服务状态
systemctl list-unit-files | grep enabled
```

### 17. 远程访问控制
**功能说明**：
- 配置访问限制
- 设置防火墙规则
- 控制远程连接

**实现代码**：
```bash
# 1. 配置hosts.allow
echo "sshd: 10.14.252.0/24" > /etc/hosts.allow

# 2. 配置hosts.deny
echo "sshd: ALL" > /etc/hosts.deny

# 3. 重启SSH服务
systemctl restart sshd
```

### 18. 软件包管理
**功能说明**：
- 清理不必要软件
- 优化系统资源
- 减少攻击面

**实现代码**：
```bash
# 1. 卸载不必要的软件包
for package in ypbind rsh talk telnet openldap-clients ntalk; do
    yum remove -y $package
done

# 2. 清理依赖
yum autoremove -y
```

### 19. 特权命令控制
**功能说明**：
- 限制su命令使用
- 配置命令权限
- 加强访问控制

**实现代码**：
```bash
# 1. 配置soocroot限制
cat >> /etc/sudoers << EOF
soocroot ALL=(root) !/usr/bin/passwd
soocroot ALL=(root) !/usr/bin/passwd [A-Za-z]*
soocroot ALL=(root) !/usr/bin/passwd root
soocroot ALL=(root) !/usr/bin/su
soocroot ALL=(root) !/usr/sbin/userdel
EOF
```

### 20. 扩展服务管理
**功能说明**：
- 管理扩展服务
- 优化服务配置
- 加强服务安全

**实现代码**：
```bash
# 1. 关闭扩展服务
for service in avahi-daemon cups dhcpd slapd nfs named httpd dovecot smb squid snmpd ypserv rsyncd ntalk; do
    systemctl stop $service
    systemctl disable $service
done

# 2. 检查服务状态
systemctl list-unit-files --state=enabled
```

### 21. 配置文件管理
**功能说明**：
- 管理配置备份
- 恢复配置文件
- 版本控制管理

**实现代码**：
```bash
# 1. 查看备份文件
find /path/to/backup -type f -name "*.bak.*" | sort

# 2. 恢复配置文件
cp /path/to/backup/file.bak.timestamp /etc/original/path/file

# 3. 检查文件内容
diff /path/to/backup/file.bak.timestamp /etc/original/path/file
```

## 操作指南

### 交互式操作说明
- `y`：确认执行当前操作
- `n`：拒绝执行当前操作
- `a`：确认执行所有后续操作
- `r`：拒绝执行所有后续操作
- `q`：退出程序

### 备份说明
- 位置：`logs/` 目录
- 命名：`原文件名.bak.时间戳`
- 查看：通过菜单选项21

## 注意事项

### 安全建议
1. 使用前完整备份重要数据
2. 在测试��境验证
3. 修改SSH端口后先测试新端口
4. 定期检查系统安全状态
5. 保持工具版本最新
6. 定期查看审计日志
7. 及时修复安全隐患

### 常见问题
1. **权限不足**
   - 确保使用root用户运行
   - 检查文件权限

2. **服务启动失败**
   - 检查系统日志
   - 验证配置文件语法

3. **配置未生效**
   - 确认服务重启
   - 检查配置文件位置

## 技术支持
- 问题反馈：[陈甫罗恩@正元数币]

## 免责声明
本工具仅用于系统安全检查和加固，使用前请：
1. 完整备份重要数据
2. 在测试环境验证
3. 评估对业务影响
4. 遵守相关法律法规

## 更新日志
### V5.0
- 初始版本发布
- 完整的等保检查功能
- 自动化修复能力
- 详细的操作日志 

# Linux系统配置工具

## 工具说明
- **版本**：v2.0
- **作者**：陈甫罗恩@正元数币
- **功能**：Linux系统基础配置管理工具，提供全面的系统配置和优化功能
- **运行环境**：Linux (CentOS/RHEL/Ubuntu)
- **开发语言**：Shell Script
- **授权方式**：开源免费

## 主要功能

### 1. 系统检查
- **网络连接检查**
  - 检测网络连通性
  - 显示网络接口状态
  - 测试DNS解析
  - 检查网关可达性

- **系统资源监控**
  - CPU使用��和负载
  - 内存使用情况
  - 磁盘空间占用
  - 系统进程状态

- **系统信息获取**
  - 操作系统版本
  - 内核信息
  - 硬件配置
  - 系统运行时间

- **服务状态检查**
  - 关键系统服务状态
  - 开机自启动服务
  - 异常服务识别
  - 服务依赖关系

### 2. 网络配置

- **主机名设置**
  - 修改系统主机名
  - 更新hosts文件
  - 确保主机名解析
  - 验证配置生效

- **网络参数配置**
  - IP地址设置
  - 子网掩码配置
  - 网关地址设置
  - 网络接口管理

- **DNS服务器设置**
  - 主备DNS配置
  - 域名解析测试
  - 自动备份机制
  - 配置还原功能

- **防火墙管理**
  - 防火墙规则配置
  - 端口开放管理
  - 服务访问控制
  - 安全策略设置

### 3. 系统设置

- **SELinux配置**
  - 模式切换（强制/宽容/禁用）
  - 安全策略管理
  - 上下文配置
  - 规则优化

- **时区设置**
  - 时区选择
  - 时间同步
  - NTP服务配置
  - 时间格式设置

- **用户资源限制**
  - 进程数限制
  - 文件句柄限制
  - 内存使用限制
  - CPU使用限制

- **系统日志管理**
  - 日志级别设置
  - 日志轮转策略
  - 日志存储优化
  - 审计日志配置

## 使用方法

### 运行要求
- **系统要求**
  - 必须以root权限运行
  - 支持systemd的Linux系统
  - 基础系统工具完整
  - 2GB以上可用内存

- **依赖命令**
  - systemctl：服务管理
  - ip/ifconfig：网络配置
  - firewall-cmd/ufw：防火墙管理
  - timedatectl：时间管理
  - ulimit：资源限制

- **网络要求**
  - 基础网络连接
  - DNS服务可用
  - NTP服务可访问
  - 防火墙端口开放

### 快速开始
```bash
# 1. 下载工具
git clone https://github.com/chenfle/system_security_tool.git
cd system_security_tool

# 2. 赋予执行权限
chmod +x system_config.sh

# 3. 运行脚本
sudo ./system_config.sh

# 4. 查看帮助
./system_config.sh --help
```

### 功能菜单详解
1. **一键系统检查**
   - 执行全面系统检查
   - 生成检查报告
   - 提供优化建议
   - 显示警告信息

2. **修改主机名**
   - 支持完整主机名
   - 自动更新hosts文件
   - 即时生效无需重启
   - 备份原配置

3. **配置网络参数**
   - 支持IPv4/IPv6
   - 多网卡配置
   - DHCP/静态IP设置
   - 路由表管理

4. **配置DNS**
   - 多DNS服务器支持
   - 智能DNS测试
   - 自动备份还原
   - 解析性能优化

5. **配置防火墙**
   - 规则批量管理
   - 服务组配置
   - 端口转发设置
   - 安��区域管理

6. **配置SELinux**
   - 模式切换
   - 策略管理
   - 上下文设置
   - 故障排除

7. **配置时区**
   - 图形化时区选择
   - NTP同步配置
   - 自动对时设置
   - 时间格式化

8. **配置用户资源限制**
   - 用户级限制
   - 组级限制
   - 全局限制
   - 临时限制

9. **退出**
   - 保存配置
   - 清理临时文件
   - 记录操作日志
   - 状态检查

### 日志记录
- **日志位置**：`logs/system_config_时间戳.log`
- **记录内容**
  - 操作时间和用户
  - 执行的命令
  - 配置变更记录
  - 错误和警告信息
- **日志格式**：`[时间] [级别] [模块] 具体信息`
- **日志管理**
  - 自动轮转
  - 压缩归档
  - 定期清理
  - 审计跟踪

## 配置文件说明
- **/etc/system_config/main.conf**：主配置文件
- **/etc/system_config/network.conf**：网络配置
- **/etc/system_config/security.conf**：安全策略
- **/etc/system_config/limits.conf**：资源限制

## 注意事项
1. **网络配置**
   - 修改前备份配置
   - 保持备用连接
   - 验证配置正确性
   - 预留回退方案

2. **DNS设置**
   - 自动备份原配置
   - 测试新DNS可用性
   - 保留至少一个可用DNS
   - 配置容错机制

3. **防火墙配置**
   - 谨慎修改规���
   - 保留管理端口
   - 测试规则有效性
   - 记录规则变更

4. **系统优化**
   - 分步骤实施
   - 及时验证效果
   - 记录修改内容
   - 保留回退空间

## 常见问题解答

### 1. 配置不生效
- 检查权限是否足够
- 确认服务是否重启
- 验证配置文件语法
- 查看错误日志

### 2. 网络连接断开
- 使用备用连接
- 还原配置备份
- 检查配置正确性
- 重启网络服务

### 3. 资源限制问题
- 确认限制值合理性
- 检查应用兼容性
- 调整系统参数
- 监控系统负载

## 技术支持
- **作者**：陈甫罗恩
- **单位**：正元数币
- **邮箱**：support@example.com
- **日期**：2024年12月20日
- **文档版本**：2.0.1

## 更新日志

### v2.0.1 (2024-12-20)
- 优化DNS配置功能
- 添加网络性能诊断
- 完善资源限制选项
- 更新使用文档

### v2.0.0 (2024-12-01)
- 重构配置管理模块
- 添加自动化配置功能
- 优化用户交互界面
- 增强安全性检查

### v1.5.0 (2024-11-15)
- 添加SELinux配置
- 优化防火墙管理
- 完善日志记录
- 修复已知问题
