# 等保测评检查和修复工具 V5.0 使用说明

## 工具简介
- **作者**：陈甫罗恩@正元数币
- **参考来源**：李宇辰@正元智慧
- **版本**：5.0
- **功能**：自动化等保合规检查与修复工具

## 主要功能
1. **安全配置检查与加固**
   - SSH服务安全配置
   - 系统服务安全配置
   - 网络服务安全配置
   - 文件系统安全配置

2. **账户与密码安全**
   - 账户安全检查
   - 密码策略配置
   - 登录安全加固
   - 权限管理优化

3. **系统审计与监控**
   - 系统日志配置
   - 审计规则设置
   - 安全事件记录
   - 操作行为追踪

4. **网络访问控制**
   - 防火墙配置
   - 远程访问控制
   - 服务访问限制
   - 网络连接监控

5. **安全基线检查**
   - 系统基线配置
   - 服务基线检查
   - 安全漏洞扫描
   - 配置合规检查

## 功能特点
1. **自动化操作**
   - 自动检测系统配置
   - 自动修复安全隐患
   - 自动生成报告
   - 批量处理能力

2. **安全性**
   - 操作前自动备份
   - 防止误操作保护
   - 分��骤确认机制
   - 回滚能力支持

3. **易用性**
   - 交互式操作界面
   - 清晰的操作提示
   - 详细的执行日志
   - 人性化的确认机制

4. **可扩展性**
   - 模块化设计
   - 配置文件可定制
   - 规则可自定义
   - 便于功能扩展

## 工具优势
1. **符合等保要求**
   - 满足等保2.0标准
   - 符合基本安全要求
   - 支持安全加固
   - 提供合规检查

2. **完整的文档支持**
   - 详细的使用说明
   - 完整的配置文档
   - 故障排除指南
   - 最佳实践建议

3. **高效的问题处理**
   - 快速定位问题
   - 自动修复建议
   - 操作步骤明确
   - 结果即时反馈

## 适用场景
1. **等保合规检查**
   - 等保前期自查
   - 等保整改支持
   - 等保测评配合
   - 持续合规维护

2. **系统安全加固**
   - 系统初始化配置
   - 安全基线达标
   - 周期性安全检查
   - 安全漏洞修复

3. **日常安全运维**
   - 日常安全检查
   - 配置变更管理
   - 安全事件响应
   - 安全状态监控

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
- 防火墙规则：仅开放必要端口
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
- 审计规则��自定义审计策略
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
2. 在测试环境验证
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

## 使用方法

### 快速开始
1. **获取工具**
```bash
git clone [repository_url]
cd 等保检查5.0
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

### 执行流程
1. **准备阶段**
   - 确认系统环境
   - 检查必要命令
   - 创建工作目录
   - 初始化日志文件

2. **检查阶段**
   - 自动扫描配置
   - 对比安全基线
   - 生成问题清单
   - 提供修复建议

3. **修复阶段**
   - 自动备份配置
   - 执行修复操作
   - 验证修复结果
   - 生成修复报告

4. **验证阶段**
   - 检查修复结果
   - 验证服务状态
   - 确认功能正常
   - 记录操作日志

### 配置说明
1. **配置文件**
   - `config/main.conf`: 主配置文件
   - `config/check.conf`: 检查项配置
   - `config/fix.conf`: 修复项配置
   - `config/custom.conf`: 自定义配置

2. **日志文件**
   - `logs/check.log`: 检查日志
   - `logs/fix.log`: 修复日志
   - `logs/error.log`: 错误日志
   - `logs/audit.log`: 审计日志

## 最佳实践

### 使用建议
1. **执行前准备**
   - 完整备份系统
   - 记录当前配置
   - 准备回滚方案
   - 选择合适时间

2. **执行过程**
   - 分步骤执行
   - 及时确认结果
   - 记录重要信息
   - 注意异常提示

3. **执行后确认**
   - 验证系统功能
   - 检查服务状态
   - 确认安全配置
   - 保存执行记录

### 定期维护
1. **日常检查**
   - 每日安全检查
   - 服务状态监控
   - 日志分析
   - 配置核对

2. **周期性维护**
   - 更新安全基线
   - 优化检查规则
   - 完善修复方案
   - 更新工具版本

3. **应急响应**
   - 异常处理流程
   - 回滚操作指南
   - 问题告模板
   - 应急联系方式

## 故障排除

### 常见问题
1. **检查失败**
   - 检查执行权限
   - 验证依赖命令
   - 确认配置文件
   - 查看错误日志

2. **修复失败**
   - 检查系统环境
   - 确认修复条件
   - 验证配置正确
   - 查看修复日志

3. **服务异常**
   - 检查服务状态
   - 查看服务日志
   - 确认配置正确
   - 尝试重启服务

### 问题解决
1. **权限问题**
   ```bash
   # 检查文件权限
   ls -l security_check.sh
   # 修正权限
   chmod +x security_check.sh
   # 检查用户权限
   id
   ```

2. **配置问题**
   ```bash
   # 检查配置文件
   cat config/main.conf
   # 恢复默认配置
   cp config/main.conf.default config/main.conf
   # 修正配置格式
   dos2unix config/*.conf
   ```

3. **服务问题**
   ```bash
   # 检查服务状态
   systemctl status service_name
   # 查看服务日志
   journalctl -u service_name
   # 重启服务
   systemctl restart service_name
   ```

## 联系方式
- **技术支持**：[陈甫罗恩@正元数币]
- **问题反馈**：[邮箱/电话]
- **文档地址**：[文档链接]
- **项目地址**：[代码仓库]

## 参考资料
1. **等保标准**
   - 等级保护基本要求
   - 等级保护测评要求
   - 等级保护实施指南

2. **技术文档**
   - Linux系统安全配置指南
   - 服务安全加固手册
   - 安全基线配置手册

3. **相关规范**
   - 信息安全管理规范
   - 运维安全管理制度
   - 应急响应处理流程

## 功能模块列表

### 基础安全配置
1. **SSH安全配置**
   - 设置SSH端口(1727)并配置防火墙
   - 修改默认SSH端口
   - 配置防火墙规则
   - 确保远程访问安全

2. **危险文件检查**
   - 检查危险的主机和用户信任文件
   - 清理.rhosts文件
   - 清理hosts.equiv文件
   - 禁用不安全的远程访问

3. **账户安全检查**
   - 检测同名账户
   - 确保UID唯一性
   - 处理重复账户
   - 账户合规性检查

4. **密码安全检查**
   - 检测空密码账户
   - 锁定不安全账户
   - 强制密码更新
   - 密码策略检查

5. **密码有效期设置**
   - 检查密码有效期
   - 配置密码最短使用时间
   - 配置密码最长使用时间
   - 设置密码过期警告

6. **密码复杂度策略**
   - 设置密码复杂度要求
   - 配置密码长度限制
   - 设置字符类型要求
   - 配置密码历史记录

7. **密码使用时间**
   - 配置密码最长使用时间
   - 强制定期更换密码
   - 密码过期处理
   - 密码更新提醒

8. **登录失败策略**
   - 配置登录失败次数限制
   - 设置账户锁定时间
   - 配置解锁机制
   - 记录登录失败事件

9. **会话超时配置**
   - 设置会话超时时间
   - 配置TMOUT环境变量
   - 自动断开空闲会话
   - SSH超时设置

10. **基础服务管理**
    - 关闭telnet服务
    - 关闭ftp服务
    - 配置服务启动项
    - 优化服务配置

11. **审计账户管理**
    - 创建审计账户
    - 设置审计权限
    - 配置审计规则
    - 管理审计日志

12. **审计权限配置**
    - 配置审计账户sudo权限
    - 设置命令执行权限
    - 配置日志记录
    - 权限分配管理

13. **共享账户检查**
    - 检测多余过期共享账户
    - 清理无用账户
    - 账户使用审计
    - 权限优化建议

14. **Root访问限制**
    - 限制root用户远程登录
    - 配置sudo访问
    - 设置登录限制
    - 加强root安全

15. **系统审计功能**
    - 开启审计功能
    - 配置审计规则
    - 设置日志轮转
    - 审计报告生成

16. **服务优化配置**
    - 关闭非必要服务
    - 优化服务启动项
    - 配置服务参数
    - 服务安全加固

17. **远程访问控制**
    - 配置远程接入限制
    - 设置访问控制列表
    - 配置防火墙规则
    - 加��访问安全

18. **软件包管理**
    - 卸载不必要的软件包
    - 清理冗余软件
    - 优化系统资源
    - 减少攻击面

19. **特权命令控制**
    - 禁止soocroot用户使用su命令
    - 配置命令访问权限
    - 设置sudo规则
    - 加强命令控制

20. **扩展服务管理**
    - 关闭扩展非必要服务
    - 优化服务配置
    - 加强服务安全
    - 减少系统风险

21. **配置文件管理**
    - 查看配置文件备份
    - 管理备份文件
    - 恢复配置选项
    - 版本控制管理