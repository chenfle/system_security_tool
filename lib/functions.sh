#!/bin/bash
# -*- coding: utf-8 -*-

# 功能函数库

# 配置SSH端口和防火墙
configure_ssh_port() {
    show_title "设置SSH端口(1727)并配置防火墙"
    
    # 1. 检查必要命令
    check_command_exists "firewall-cmd"
    check_command_exists "systemctl"
    check_command_exists "netstat"
    
    # 2. 检查防火墙状态
    echo "正在检查防火墙状态..."
    local firewall_status
    if systemctl is-active firewalld &>/dev/null; then
        echo "成功: 防火墙已启用且正在运行"
        echo "当前开放的端口:"
        firewall-cmd --list-ports
        wait_for_enter
    else
        echo "警告: 防火墙未启用 - 系统可能存在安全风险"
        
        if confirm_action "是否启用防火墙？"; then
            echo "正在启用防火墙..."
            # 备份防火墙配置
            backup_file "/etc/sysconfig/iptables"
            
            # 启动防火墙
            if ! systemctl start firewalld; then
                error_exit "错误: 启动防火墙失败 - 请检查firewalld服务状态"
            fi
            if ! systemctl enable firewalld; then
                error_exit "错误: 设置防火墙开机启动失败 - 请检查系统服务配置"
            fi
            echo "成功: 防火墙已启用并设置为开机启动"
        else
            echo "提示: 用户选择不启用防火墙，系统可能存在安全风险"
            return
        fi
    fi
    
    # 3. 检查SSH端口
    echo -e "\n正在检查SSH端口配置..."
    local sshd_config="/etc/ssh/sshd_config"
    backup_file "$sshd_config"
    
    local current_port
    current_port=$(grep "^Port" "$sshd_config" | awk '{print $2}')
    current_port=${current_port:-22}  # 如果未设置，则默认为22
    
    echo "当前SSH端口: $current_port"
    if [ "$current_port" = "22" ]; then
        echo "说明: 当前使用默认端口(22)，建议修改为非默认端口以提高安全性"
        echo "推荐: 使用1727端口或其他非默认端口"
        
        if confirm_action "是否需要修改SSH端口？"; then
            echo "请选择:"
            echo "1. 自定义端口"
            echo "2. 使用推荐端口(1727)"
            read -r -p "请选择 [1/2]: " port_choice
            
            case $port_choice in
                1)
                    while true; do
                        read -r -p "请输入新的端口号(1-65535): " new_port
                        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -lt 65536 ]; then
                            break
                        else
                            echo "错误: 请输入有效的���口号(1-65535)"
                        fi
                    done
                    ;;
                2)
                    new_port=1727
                    ;;
                *)
                    echo "无效选择，操作取消"
                    return
                    ;;
            esac
            
            echo "正在修改SSH端口..."
            # 修改配置文件
            sed -i "s/^#\?Port .*/Port ${new_port}/" "$sshd_config"
            
            # 配置防火墙
            echo "正在配置防火墙规则..."
            if ! firewall-cmd --permanent --add-port=${new_port}/tcp; then
                error_exit "添加防火墙端口失败"
            fi
            if ! firewall-cmd --reload; then
                error_exit "重载防火墙配置失败"
            fi
            
            # 重启SSH服务
            echo "正在重启SSH服务..."
            if ! systemctl restart sshd; then
                error_exit "重启SSH服务失败"
            fi
            
            echo -e "\n配置完成:"
            echo "1. SSH端口已修改为: $new_port"
            echo "2. 防火墙规则已更新"
            echo "3. SSH服务已重启"
            echo -e "\n警告: 请确保在断开连接前测试新端口是否可用"
            echo "测试命令: ssh -p $new_port user@host"
        fi
    else
        echo "当前SSH端口($current_port)已经不是默认端口，无需修改"
    fi
}

# 检查危险的主机和用户信任文件
check_dangerous_trust_files() {
    show_title "检查危险的主机和用户信任文件"
    
    # 1. 检查必要命令
    check_command_exists "rm"
    check_command_exists "ls"
    
    # 2. 定义危险文件列表
    local dangerous_files=(
        ".rhosts:远程主机信任文件"
        "/etc/hosts.equiv:主机等效信任文件"
    )
    
    # 3. 检查文件状态
    echo "开始检查危险的信任文件..."
    echo "说明: 这些文件可能导致未授权的远程访问，建议删除"
    echo
    
    local found=0
    for file_info in "${dangerous_files[@]}"; do
        IFS=':' read -r file description <<< "$file_info"
        echo "检查 $description ($file):"
        if [ -f "$file" ]; then
            echo "  - 状态: 发现文件"
            echo "  - 建议: 删除此文件以提高系统安全性"
            found=1
            
            # 显示文件内容预览
            echo "  - 文件内容预览:"
            head -n 5 "$file" | sed 's/^/    /'
            echo
        else
            echo "  - 状态: 未发现文件"
            echo "  - 符合安全要求"
        fi
        echo
    done
    
    # 4. 处理发现的文件
    if [ $found -eq 1 ]; then
        echo "警告: 发现危险的信任文件"
        if confirm_action "是否删除这些文件？(推荐删除)"; then
            for file_info in "${dangerous_files[@]}"; do
                IFS=':' read -r file description <<< "$file_info"
                if [ -f "$file" ]; then
                    if rm -f "$file" 2>/dev/null; then
                        echo "已删除: $file"
                    else
                        error_exit "删除文件 $file 失败"
                    fi
                fi
            done
            echo "所有危险的信任文件已删除"
        else
            echo "警告: 用户选择保留危险文件，这可能带来安全风险"
        fi
    else
        echo "检查结果: 未发现危险的信任文件，符合安全要求"
    fi
}

# 检测同名账户
check_duplicate_accounts() {
    show_title "检测同名账户，并保证UID唯一"
    
    # 1. 检查必要命令
    check_command_exists "sort"
    check_command_exists "uniq"
    check_command_exists "awk"
    check_command_exists "cat"
    
    # 2. 检查passwd文件
    local passwd_file="/etc/passwd"
    check_file_exists "$passwd_file"
    
    # 3. 检查是否存在同名账户
    echo "正在检查同名账户..."
    echo "说明: 系统中不应存在同名账户，这可能导致安全问题"
    echo
    
    local duplicate_count
    local total_count
    
    duplicate_count=$(cat "$passwd_file" | sort -n | uniq -c | awk '{sum += $1};END {print sum}')
    total_count=$(wc -l < "$passwd_file")
    
    echo "账户检查结果:"
    echo "  - 总账户数: $total_count"
    echo "  - 重复计数: $duplicate_count"
    echo
    
    if [ "$duplicate_count" -gt "$total_count" ]; then
        echo "警告: 发现同名账户!"
        echo "详细信息:"
        echo "----------------------------------------"
        cat "$passwd_file" | sort -n | uniq -c | awk '$1 > 1 {print "  重复",$1"次:",$2}'
        echo "----------------------------------------"
        echo
        
        if confirm_action "是否处理这些同名账户？"; then
            echo
            echo "处理建议:"
            echo "1. 使用以下命令查看具体重复账户:"
            echo "   cat /etc/passwd | sort -n | uniq -c"
            echo
            echo "2. 使用以下命令删除不需要的账户:"
            echo "   userdel <username>"
            echo
            echo "3. 删���账户前请确认:"
            echo "   - 账户是否仍在使用"
            echo "   - 是否需要备份账户数据"
            echo "   - 是否有关联的系统服务"
            echo
            echo "警告: 为确保系统安全，建议手动处理同名账户"
            wait_for_enter
        else
            echo "用户选择不处理同名账户"
        fi
    else
        echo "检查结果: 未发现同名账户，符合安全要求"
    fi
}

# 检测空密码账户
check_empty_passwords() {
    show_title "检测系统中是否存在空密码账户"
    
    # 1. 检查必要命令
    check_command_exists "awk"
    check_command_exists "passwd"
    
    # 2. 检查shadow文件
    local shadow_file="/etc/shadow"
    check_file_exists "$shadow_file"
    
    # 3. 检查空密码账户
    echo "正在检查空密码账户..."
    echo "说明: 系统中不应存在空密码账户，这会带来严重的安全隐患"
    echo
    
    local empty_passwd_users
    empty_passwd_users=$(awk -F: '($2 == "") { print $1 }' "$shadow_file")
    
    if [ ! -z "$empty_passwd_users" ]; then
        echo "警告: 发现空密码账户!"
        echo "详细信息:"
        echo "----------------------------------------"
        echo "$empty_passwd_users" | while read -r user; do
            echo "  - 账户名: $user"
            # 显示账户详细信息
            echo "    账户状态: $(passwd -S "$user" 2>/dev/null || echo "无法获取")"
        done
        echo "----------------------------------------"
        echo
        
        if confirm_action "是否锁定这些空密码账户？(推荐锁定)"; then
            echo
            for user in $empty_passwd_users; do
                echo "正在处理账户: $user"
                if passwd -l "$user" 2>/dev/null; then
                    echo "  - 已锁定账户: $user"
                else
                    echo "  - 锁定账户失败: $user"
                fi
            done
            echo
            echo "处理完成"
            echo "提示: 被锁定的账户可以使用以下命令解锁:"
            echo "  passwd -u <username>"
        else
            echo "警告: 用户选择不锁定空密码账户，这可能带来安全风险"
        fi
    else
        echo "检查结果: 未发现空密码账户，符合安全要求"
    fi
}

# 检查密码有效期设置
check_password_validity() {
    show_title "检查密码有效期设置"
    
    # 1. 检查必要命令
    check_command_exists "sed"
    check_command_exists "grep"
    check_command_exists "awk"
    
    # 2. 检查配置文件
    local login_defs="/etc/login.defs"
    check_file_exists "$login_defs"
    
    # 3. 备份配置文件
    backup_file "$login_defs"
    
    # 4. 检查各项参数
    echo "正在检查密码有效期参数..."
    echo "说明: 这些参数用于控制系统密码策略，建议按照安全基线进行配置"
    echo
    
    local params=(
        "PASS_MAX_DAYS:120:密码最长使用时间(天):超过此天数必须修改密码"
        "PASS_MIN_DAYS:2:密码最短使用时间(天):两次修改密码的最小间隔"
        "PASS_WARN_AGE:7:密码过期警告时间(天):密码过期前多少天开始警告"
        "PASS_MIN_LEN:8:密码最小长度(位):密码最少需要多少个字符"
    )
    
    local need_update=0
    for param in "${params[@]}"; do
        IFS=':' read -r name value description detail <<< "$param"
        local current_value
        current_value=$(grep "^${name}" "$login_defs" | awk '{print $2}')
        
        echo "检查 $description:"
        echo "  - 当前值: ${current_value:-"未设置"}"
        echo "  - 推荐值: $value"
        echo "  - 说明: $detail"
        echo
        
        if [ "$current_value" != "$value" ]; then
            need_update=1
        fi
    done
    
    # 5. 处理不符合要求的参数
    if [ "${need_update:-0}" -eq 1 ]; then
        echo "发现部分参数不符合安全基线要求"
        if confirm_action "是否修改这些参数？"; then
            for param in "${params[@]}"; do
                IFS=':' read -r name value description detail <<< "$param"
                current_value=$(grep "^${name}" "$login_defs" | awk '{print $2}')
                
                if [ "$current_value" != "$value" ]; then
                    echo
                    echo "修改 $description:"
                    echo "  - 当前值: ${current_value:-"未设置"}"
                    echo "  - 推荐值: $value"
                    read -r -p "请输入新的值(直接回车使用推荐值): " input_value
                    
                    # 使用用户输入或推荐值
                    local new_value=${input_value:-$value}
                    
                    if grep -q "^${name}" "$login_defs"; then
                        sed -i "s/^${name}.*/${name}\t${new_value}/" "$login_defs"
                    else
                        echo "${name}\t${new_value}" >> "$login_defs"
                    fi
                    echo "已设置 $description 为: $new_value"
                fi
            done
            echo
            echo "密码有效期参数已更新"
            echo "注意: 这些修改只对新建用户生效"
            echo "      如需对现有用户生效，请使用 chage 命令手动修改"
        else
            echo "用户选择不修改参数"
        fi
    else
        echo "检查结果: 所有参数均符合安全基线要求"
    fi
}

# 密码复杂策略设置
configure_password_complexity() {
    show_title "密码复杂策略设置"
    
    # 1. 检查必要命令
    check_command_exists "sed"
    check_command_exists "grep"
    check_command_exists "chage"
    
    # 2. 检查配置文件
    local system_auth="/etc/pam.d/system-auth"
    local pwquality_conf="/etc/security/pwquality.conf"
    check_file_exists "$system_auth"
    check_file_exists "$pwquality_conf"
    
    # 3. 说明配置含义
    echo "密码复杂度策略说明:"
    echo "1. 密码复杂度要求:"
    echo "   - 最小长度: 8位"
    echo "   - 必须包含: 大写字母、小写字母、数字、特殊字符"
    echo "   - 不能包含用名"
    echo "   - 新密码不能与旧密码相似"
    echo
    echo "2. 密码更新策略:"
    echo "   - 配置后将强制所有用户在下次登录时修改密码"
    echo "   - 新密码必须符合复杂度要求"
    echo

    # 4. 检查当前配置
    echo "正在检查当前配置..."
    echo "----------------------------------------"
    
    # 检查PAM配置
    local pam_line="password    required    pam_pwquality.so retry=3 minlen=8 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1"
    local current_pam_line
    current_pam_line=$(grep "^password.*pam_pwquality.so" "$system_auth")
    
    # 初始化变量为false
    local need_pam_update=false
    local need_pwquality_update=false
    
    echo "PAM配置检查:"
    if [ -z "$current_pam_line" ]; then
        echo "  - 状态: 未配置密码复杂度要求"
        need_pam_update=true
    else
        echo "  - 当前配置: $current_pam_line"
        echo "  - 推荐配置: $pam_line"
        if [ "$current_pam_line" != "$pam_line" ]; then
            need_pam_update=true
        fi
    fi
    
    # 检查pwquality配置
    echo
    echo "pwquality配置检查:"
    local pwquality_params=(
        "minlen=8:最小长度"
        "dcredit=-1:必须含数字"
        "ucredit=-1:必须包含大写字母"
        "lcredit=-1:必须包含小写字母"
        "ocredit=-1:必须包含特殊字符"
    )
    
    for param in "${pwquality_params[@]}"; do
        IFS=':' read -r setting description <<< "$param"
        name="${setting%%=*}"
        value="${setting#*=}"
        current_value=$(grep "^${name}" "$pwquality_conf" | cut -d'=' -f2 | tr -d ' ')
        echo "检查 $description:"
        echo "  - 当前值: ${current_value:-"未设置"}"
        echo "  - 推荐值: $value"
        if [ "$current_value" != "$value" ]; then
            need_pwquality_update=true
        fi
    done
    
    # 使用字符串比较而不是数值比较
    if [ "$need_pam_update" = true ] || [ "$need_pwquality_update" = true ]; then
        echo
        echo "发现配置不符合安全基线要求"
        if confirm_action "是否修改这些配置？"; then
            # 备份配置文件
            backup_file "$system_auth"
            backup_file "$pwquality_conf"
            
            # 更新PAM配置
            if [ $need_pam_update -eq 1 ]; then
                sed -i '/^password.*pam_pwquality.so/c\'"$pam_line" "$system_auth"
                echo "已更新PAM配置"
            fi
            
            # 更新pwquality配置
            if [ $need_pwquality_update -eq 1 ]; then
                for param in "${pwquality_params[@]}"; do
                    setting="${param%%:*}"
                    name="${setting%%=*}"
                    value="${setting#*=}"
                    if grep -q "^${name}" "$pwquality_conf"; then
                        sed -i "s/^${name}.*/${name} = ${value}/" "$pwquality_conf"
                    else
                        echo "${name} = ${value}" >> "$pwquality_conf"
                    fi
                done
                echo "已更新pwquality配置"
            fi
            
            # 6. 强制所有用户下次登录时修改密码
            echo
            echo "正在设置用户密码状态..."
            for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
                echo "处理用户: $user"
                # 设置密码立即过期，强制用户下次登录时修改密码
                chage -d 0 "$user"
                echo "  - 已设置强制修改密码"
            done
            
            echo
            echo "配置更新完成:"
            echo "1. 密码复杂度策略已更新"
            echo "2. 所有用户将在下次登录时被要求修改���码"
            echo "3. 新密码必须符合以下要求:"
            echo "   - 最小长度：8位"
            echo "   - 必须包含：大写字母、小写字母、数字、特殊字符"
        fi
    else
        echo
        echo "检查结果: 所有配置均符合安全基线要求"
    fi
}

# 配置密码最长使用时间
configure_password_max_days() {
    show_title "配置密码最长使用时间"
    
    # 1. 检查必要命令
    check_command_exists "chage"
    check_command_exists "grep"
    check_command_exists "cut"
    
    # 2. 获取可登录用户列表
    echo "正在检查可登录用户的密码使用时间..."
    echo "说明: 密码使用时间不超过120天，以确保账户安全"
    echo
    
    # 获取可登录用户列表（排除系统账户）
    local users
    users=$(grep ^[^:]*:[^\!*] /etc/shadow | cut -d: -f1)
    
    if [ -z "$users" ]; then
        echo "未发现可登录用户"
        return
    fi
    
    # 3. 检查每个用户的密码状态
    echo "用户密码状态检查:"
    echo "----------------------------------------"
    local need_update=0
    
    for user in $users; do
        echo "检查用户: $user"
        local max_days
        max_days=$(chage -l "$user" | grep "Maximum" | cut -d: -f2 | tr -d ' ')
        
        # ���示当前状态
        echo "  - 当前长使用时间: ${max_days:-"未设置"} 天"
        echo "  - 推荐最长使用时间: 120 天"
        
        # 检查密码修改时间
        local last_change
        last_change=$(chage -l "$user" | grep "Last password change" | cut -d: -f2-)
        echo "  - 上次密码修改时间: $last_change"
        
        if [ "$max_days" != "120" ]; then
            need_update=1
            echo "  - 状态: 需要更新"
        else
            echo "  - 状态: 符合要求"
        fi
        echo
    done
    echo "----------------------------------------"
    
    # 4. 处理需要更新用户
    if [ $need_update -eq 1 ]; then
        echo "发现部分用户的密码最长使用时间不符合要求"
        if confirm_action "是否将所有用户的密码最长使用时间设置为120天？"; then
            echo
            for user in $users; do
                echo "正在处理用户: $user"
                if chage -M 120 "$user" 2>/dev/null; then
                    echo "  - 已设置 $user 的密码最长使用时间为120天"
                else
                    echo "  - 设置 $user 的密码最长使用时间失败"
                fi
            done
            echo
            echo "密码最长使用时间配置完成"
            echo "提示: 可以使用 'chage -l <username>' 命令查看用户密码状态"
        else
            echo "用户选择不修改密码最长使用时间"
        fi
    else
        echo "检查结果: 所有用户的密码最长使用时间均符合要求"
    fi
}

# 配置会话超时
configure_session_timeout() {
    show_title "配置会话超时"
    
    # 1. 检查必要命令
    check_command_exists "grep"
    check_command_exists "sed"
    
    # 2. 定义配置文件
    local profile_file="/etc/profile"
    
    # 3. 说明配置含义
    echo "会话超时配置说明:"
    echo "1. 超时时间: 600秒(10分钟)"
    echo "2. 作用范围: 所有用户"
    echo "3. 生效时机: 用户下次登录时"
    echo
    
    # 4. 检查当前配置
    echo "正在检查当前配置..."
    echo "----------------------------------------"
    
    if grep -q "^[^#]*TMOUT=" "$profile_file"; then
        local current_timeout
        current_timeout=$(grep "TMOUT=" "$profile_file" | grep -v "readonly" | grep -v "export" | cut -d'=' -f2)
        echo "当前配置:"
        echo "  - TMOUT值: ${current_timeout:-"未设置"} 秒"
        echo "  - 配置文件: $profile_file"
    else
        echo "当前状态: 未配置会话超时"
    fi
    echo "----------------------------------------"
    
    # 5. 询问是否修改
    if confirm_action "是否配置会话超时？"; then
        # 备份配置文件
        backup_file "$profile_file"
        
        # 删除已有的TMOUT配置
        sed -i '/TMOUT=/d' "$profile_file"
        
        # 添加新的配置
        echo >> "$profile_file"
        echo "# 设置会话超时时间为600秒(10分钟)" >> "$profile_file"
        echo "TMOUT=600" >> "$profile_file"
        echo "readonly TMOUT" >> "$profile_file"
        echo "export TMOUT" >> "$profile_file"
        
        echo
        echo "配置已更新:"
        echo "1. 超时时间已设置为600秒"
        echo "2. 配置已设为只读"
        echo "3. 变量已导出到环境"
        echo
        echo "注意: 新配置将在用户下次登录时生效"
        echo "      如需立即生效，请执行: source /etc/profile"
    fi
}

# 配置登录失败策略
configure_login_failure_policy() {
    show_title "配置登录失败策略"
    
    # 1. 检查必要命令
    check_command_exists "sed"
    check_command_exists "grep"
    
    # 2. 定义需检查的配置
    local main_pam_files=(
        "/etc/pam.d/system-auth"
        "/etc/pam.d/password-auth"
    )
    
    # 3. 说明配���含义
    echo "登录失败策略说明:"
    echo "1. 登录失败锁定:"
    echo "   - 连续失败5次将锁定账户900秒(15分钟)"
    echo "   - root账户锁定时间为10秒"
    echo "   - 锁定期间禁止任何登录尝试"
    echo
    echo "2. 会话超时设置:"
    echo "   - 空闲会话超时时间为600秒(10分钟)"
    echo "   - 超时后自动断开连接"
    echo
    
    # 4. 检查当前配置
    echo "正在检查当前配置..."
    echo "----------------------------------------"
    
    local need_update=false
    local required_line="password requisite pam_pwquality.so try_first_pass retry=5"
    
    # 检查PAM配置
    for file in "${main_pam_files[@]}"; do
        echo "检查 $file:"
        if [ -f "$file" ]; then
            if ! grep -q "^$required_line" "$file"; then
                need_update=true
                echo "  - 状态: 配置不完整或不符合要求"
            else
                echo "  - 状态: 配置正确"
            fi
        else
            echo "  - 状态: 文件不存在"
            need_update=true
        fi
    done
    
    # 5. 询问是否修改置
    if [ "$need_update" = true ]; then
        echo
        echo "发现配置不符合安全基线要求"
        if confirm_action "是��修改这些配置？"; then
            # 备份并更新配置文件
            for file in "${main_pam_files[@]}"; do
                if [ -f "$file" ]; then
                    backup_file "$file"
                    # 在文件开头添加配置行
                    sed -i "1i $required_line" "$file"
                    echo "已更新: $file"
                fi
            done
            
            echo
            echo "配置更新完成"
            echo "1. 已添加密码复杂度检查"
            echo "2. 已设置重试次数为5次"
        fi
    else
        echo
        echo "检查结果: 所有配置符合安全基线要求"
    fi
}

# 关闭telnet和ftp服务
disable_telnet_ftp() {
    show_title "关闭telnet和ftp服务"
    
    # 1. 检查必要命令
    check_command_exists "systemctl"
    check_command_exists "chkconfig"
    
    # 2. 定义需要关闭的服务
    local services=(
        "telnet:远程登录服务(不安全)"
        "telnet-server:Telnet服务器"
        "vsftpd:FTP服务"
    )
    
    echo "正在检查telnet和ftp服务..."
    echo "说明: 这些服务使用明文输，存在安全风险，建议关闭"
    echo
    
    # 3. 检查并关闭服务
    for service_info in "${services[@]}"; do
        IFS=':' read -r service description <<< "$service_info"
        echo "检查 $description ($service):"
        
        if systemctl is-active "$service" &>/dev/null || chkconfig --list "$service" &>/dev/null; then
            echo "  - 状态: 服务已启用"
            echo "  - 建议: 关闭此服务"
            
            if confirm_action "是否关闭 $service 服务？"; then
                systemctl stop "$service" 2>/dev/null || true
                systemctl disable "$service" 2>/dev/null || true
                chkconfig "$service" off 2>/dev/null || true
                echo "  - 已关闭并禁用 $service 服务"
            fi
        else
            echo "  - 状态: 服务未启用或未安装"
            echo "  - 符合安全要求"
        fi
        echo
    done
}

# 创建审计账户
create_audit_account() {
    show_title "创建审计账户"
    
    # 1. 检查必要命令
    check_command_exists "useradd"
    check_command_exists "passwd"
    check_command_exists "setfacl"
    
    # 2. 定义审计账户信息
    local audit_user="auditor"
    local audit_password="[Ejgm9@#Y+9BD"
    
    echo "正在检查审计账户..."
    echo "说明: 审计账户用于系统审计，只具有查看权限"
    echo
    
    # 3. 检查账是否存在
    if id "$audit_user" &>/dev/null; then
        echo "审计账户已存在:"
        echo "  - 用户名: $audit_user"
        echo "  - UID: $(id -u "$audit_user")"
        echo "  - 主: $(id -gn "$audit_user")"
    else
        echo "创建审计账户..."
        if useradd "$audit_user"; then
            echo "$audit_password" | passwd --stdin "$audit_user"
            echo "审计账户创建成功:"
            echo "  - 用户名: $audit_user"
            echo "  - 密码已设置"
        else
            error_exit "创建审计账户失败"
        fi
    fi
    
    # 4. 设置目录权限
    echo "设置目录访问权限..."
    if setfacl -m u:"$audit_user":rx /*; then
        echo "已设置根目录查看权限"
    else
        echo "警告: 设置目录权限失败，请手动检查"
    fi
}

# 配置审计账户sudo权限
configure_audit_sudo() {
    show_title "配置审计账户sudo权限"
    
    # 1. 检查必要命令
    check_command_exists "sudo"
    check_command_exists "visudo"
    
    # 2. 检查审账户
    local audit_user="auditor"
    if ! id "$audit_user" &>/dev/null; then
        echo "错误: 审计账户($audit_user)不存在，请先创建审计账户"
        return 1
    fi
    
    # 3. 备份sudoers文件
    local sudoers_file="/etc/sudoers"
    backup_file "$sudoers_file"
    
    echo "正在配置审计账户sudo权限..."
    echo "说明: 审账户将只被授予必要的查看权限"
    echo
    
    # 4. 配置sudo权限
    local sudo_rules=(
        "$audit_user ALL=(ALL) NOPASSWD:/usr/bin/ls"
        "$audit_user ALL=(ALL) NOPASSWD:/usr/bin/cat"
        "$audit_user ALL=(ALL) NOPASSWD:/usr/bin/grep"
        "$audit_user ALL=(ALL) NOPASSWD:/usr/bin/tail"
        "$audit_user ALL=(ALL) NOPASSWD:/usr/bin/head"
    )
    
    for rule in "${sudo_rules[@]}"; do
        if ! grep -q "^$rule" "$sudoers_file"; then
            echo "$rule" >> "$sudoers_file"
            echo "已添加规则: $rule"
        fi
    done
    
    echo "审计账户sudo权限配置完成"
    echo "授权的命令:"
    echo "  - ls: 列出目录内容"
    echo "  - cat: 查看文件内容"
    echo "  - grep: 搜索文件内容"
    echo "  - tail: 查看文件末尾"
    echo "  - head: 查看文件头"
}

# 检测多余过期共享账户
check_expired_shared_accounts() {
    show_title "检测多余过期共享账户"
    
    # 1. 检查必要命令
    check_command_exists "chage"
    check_command_exists "userdel"
    
    # 2. 定义共享账户列表
    local shared_accounts=(
        "ftp:FTP服务账户"
        "games:游戏账户"
        "gopher:Gopher服务账户"
        "operator:系统操作员账户"
    )
    
    echo "正在检查共享账户..."
    echo "说明: 系统中可能存在不必要的共享账户，建议删除"
    echo
    
    local found=0
    for account_info in "${shared_accounts[@]}"; do
        IFS=':' read -r account description <<< "$account_info"
        echo "检查 $description ($account):"
        
        if id "$account" &>/dev/null; then
            echo "  - 状态: 账户存在"
            echo "  - 账户信息:"
            echo "    $(id "$account")"
            echo "  - 密码状态:"
            echo "    $(chage -l "$account" 2>/dev/null | grep -E 'Last password change|Password expires' || echo '    无法获取密码信息')"
            found=1
        else
            echo "  - 状态: 账户不存在"
            echo "  - 符合安全要求"
        fi
        echo
    done
    
    if [ $found -eq 1 ]; then
        if confirm_action "是否删除这些共享账户？"; then
            for account_info in "${shared_accounts[@]}"; do
                IFS=':' read -r account description <<< "$account_info"
                if id "$account" &>/dev/null; then
                    echo "正在删除账户: $account"
                    if userdel -r "$account" 2>/dev/null; then
                        echo "  - 已删除账户及其主目录"
                    else
                        echo "  - 删除账户失败，可能正在使用"
                    fi
                fi
            done
        else
            echo "用户选择保留共享账户"
        fi
    else
        echo "检查结果: 未发现多余的共享账户"
    fi
}

# 限制root用户远程登录
restrict_root_login() {
    show_title "限制root用户远程登录"
    
    # 1. 检查必要命令
    check_command_exists "systemctl"
    check_command_exists "sed"
    
    # 2. 检查配置文件
    local sshd_config="/etc/ssh/sshd_config"
    check_file_exists "$sshd_config"
    backup_file "$sshd_config"
    
    echo "正在检查root远程登录设置..."
    echo "说明: 禁止root直接远程登录可以提高系统安全性"
    echo "警告: 确保系统中在其他可用的管理员账户，否则可能无法远程管理系"
    echo
    
    # 3. 检当前设置
    local current_setting
    current_setting=$(grep "^PermitRootLogin" "$sshd_config" | awk '{print $2}')
    
    echo "当前设置:"
    echo "  - PermitRootLogin: ${current_setting:-"未设置(默认yes)"}"
    echo "  - 建议设置: no"
    echo
    
    if [ "$current_setting" != "no" ]; then
        if confirm_action "是否禁止root用户远程登录？(高风险操作)"; then
            # 修改配置
            sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$sshd_config"
            
            # 重启服务
            echo "正在重启SSH服务..."
            if systemctl restart sshd; then
                echo "设置完成:"
                echo "1. 已禁止root用户远程登录"
                echo "2. SSH服务已重启"
                echo
                echo "注意: 请确保您有其他可用的管理员账户"
            else
                error_exit "重启SSH服务失败"
            fi
        else
            echo "用户选择不修改root登录限制"
        fi
    else
        echo "检查结果: root用户已被禁止远程登录，符合安全要求"
    fi
}

# 开启审计功能
configure_audit() {
    show_title "开启审计功能"
    
    # 1. 检查必要命令
    check_command_exists "systemctl"
    check_command_exists "auditctl"
    
    # 2. 检查配置文件
    local audit_conf="/etc/audit/auditd.conf"
    local audit_rules="/etc/audit/rules.d/audit.rules"
    
    # 3. 备份配置文件
    backup_file "$audit_conf"
    backup_file "$audit_rules"
    
    echo "正在检查审计服务..."
    echo "说明: 审计功能用于记录系统重要事件，有助于安全分析"
    echo
    
    # 4. 检查并启动服务
    local services=("rsyslog" "auditd")
    for service in "${services[@]}"; do
        echo "检查 $service 服务:"
        if systemctl is-active "$service" &>/dev/null; then
            echo "  - 状态: 已运行"
        else
            echo "  - 状态: 未运行"
            echo "  - 正在启动服务..."
            if ! systemctl start "$service"; then
                echo "  - 启动失败，尝试安装..."
                yum install -y "$service"
                systemctl start "$service"
            fi
            systemctl enable "$service"
        fi
    done
    
    # 5. 配置审计守护进程
    echo "配置审计守护进程..."
    local audit_settings=(
        "space_left_action = email:磁盘空间不足时发送邮件"
        "admin_space_left_action = halt:管理空间不足时停止系统"
        "disk_full_action = halt:磁盘满时停止系统"
        "disk_error_action = halt:磁盘错误时停止系统"
        "max_log_file = 8:最大日志文件大小(MB)"
        "num_logs = 99:保留的日志文件数量"
        "max_log_file_action = ROTATE:日志文件达到最大时轮转"
    )
    
    for setting in "${audit_settings[@]}"; do
        IFS=':' read -r config description <<< "$setting"
        name="${config%%=*}"
        value="${config#*=}"
        echo "设置 $description:"
        echo "  $config"
        if grep -q "^${name}" "$audit_conf"; then
            sed -i "s|^${name}.*|${config}|" "$audit_conf"
        else
            echo "$config" >> "$audit_conf"
        fi
    done
    
    # 6. 配置审计规则
    echo "配置审计规则..."
    cat > "$audit_rules" << 'EOF'
# 权限修改审计
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod

# 身份验证审计
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins

# sudo命令计
-w /var/log/sudo.log -p wa -k actions

# 审计工具保护
-w /sbin/auditctl -p x -k audittools
-w /sbin/auditd -p x -k audittools

# 启用审计规则
-e 2
EOF
    
    # 7. 重新加载审计规则
    echo "重新加载审计规则..."
    service auditd reload
    
    echo "审计功能配置完成"
    echo "提示: 可以使用 ausearch 命令查看审计日志"
}

# 关闭非必要服务
disable_unnecessary_services() {
    show_title "关闭非必要服务"
    
    # 1. 检查必要命令
    check_command_exists "systemctl"
    check_command_exists "chkconfig"
    
    # 2. 定义需要检查的服务
    local services=(
        "chargen-dgram:字符生成服务(UDP):不安全的调试服务"
        "chargen-stream:字符生成服务(TCP):不安全的调试服务"
        "daytime-dgram:日期时间服务(UDP):不安全的时间同步服务"
        "daytime-stream:日期时间服务(TCP):不安全的时间同步服务"
        "discard-dgram:数据丢弃服务(UDP):不安全的调试服务"
        "discard-stream:数据丢弃服务(TCP):不安全的调试服务"
        "echo-dgram:回显服务(UDP):不安全的调试服务"
        "echo-stream:回显服务(TCP):不安全的调试服务"
        "time-dgram:时间服务(UDP):过时的时间步服务"
        "time-stream:时间服务(TCP):过时的时间同步服务"
        "tftp:简单文件传输:不安全的文件传输服务"
        "xinetd:扩展互联网服务:过时的服务管理程序"
    )
    
    echo "正在检查非必要服务..."
    echo "说明: 这些服务可能存在安全风险，建议关闭不需要的服务"
    echo "警告: 关闭服务前请确认系统功能依赖"
    echo
    
    # 3. 检查并处理服务
    for service_info in "${services[@]}"; do
        IFS=':' read -r service name description <<< "$service_info"
        echo "检查 $name ($service):"
        echo "  - 说明: $description"
        
        if systemctl is-enabled "$service" &>/dev/null || chkconfig --list "$service" &>/dev/null; then
            echo "  - 状态: 服务已启用"
            if confirm_action "是否关闭 $service 服务？"; then
                systemctl stop "$service" 2>/dev/null || true
                systemctl disable "$service" 2>/dev/null || true
                chkconfig "$service" off 2>/dev/null || true
                echo "  - 已关闭并禁用服务"
            fi
        else
            echo "  - 状态: 服务未启用或未安装"
        fi
        echo
    done
    
    echo "服务检查完成"
}

# 配置远程接入限制
configure_remote_access() {
    show_title "配置远程接入限制(非必要不操作)"
    
    # 1. 检查必要命令
    check_command_exists "systemctl"
    
    # 2. 检查配置文件
    local hosts_allow="/etc/hosts.allow"
    local hosts_deny="/etc/hosts.deny"
    
    # 3. 备份配置文件
    backup_file "$hosts_allow"
    backup_file "$hosts_deny"
    
    echo "正在检查远程访问配置..."
    echo "说明: 限制远程访问可以提高系统安全性"
    echo "警告: 此操作具有高风险，配置不当可能导致无法远程访问系统"
    echo "      建议在确实需要时再进行配置"
    echo
    
    if ! confirm_action "此操作可能导致系统无法远程访问，是否继续？"; then
        echo "用户取消操作"
        return
    fi
    
    echo "当前配置状态:"
    echo "----------------------------------------"
    if [ -f "$hosts_allow" ]; then
        echo "允许访问的配置:"
        grep "sshd:" "$hosts_allow" || echo "  - 未配置允许访问的地址"
    fi
    if [ -f "$hosts_deny" ]; then
        echo "拒绝访问的配置:"
        grep "sshd:" "$hosts_deny" || echo "  - 未配置拒绝访问的地址"
    fi
    echo "----------------------------------------"
    echo
    
    echo "可选操作:"
    echo "1. 添加允许访问的IP/网段"
    echo "2. 删除现有配置"
    echo "3. 返回上级菜单"
    
    read -r -p "请选择操作 [1-3]: " choice
    
    case $choice in
        1)
            echo
            echo "请输入允许访问的IP地址或网段"
            echo "格式示例:"
            echo "  - 单个IP: 192.168.1.100"
            echo "  - IP网段: 10.14.252.0/24"
            echo "  - 多个地址: 192.168.1.100,10.14.252.0/24"
            echo
            read -r -p "请输入: " allowed_ip
            
            if [ ! -z "$allowed_ip" ]; then
                echo
                echo "警告: 即将限制SSH只允许以下地址访问:"
                echo "  $allowed_ip"
                echo "其他所有IP将被拒绝访问"
                echo
                if confirm_action "确定要应用这些设置吗？"; then
                    echo "sshd:$allowed_ip:allow" > "$hosts_allow"
                    echo "sshd:ALL" > "$hosts_deny"
                    
                    if systemctl restart sshd; then
                        echo
                        echo "配置已更新:"
                        echo "1. 已添加允许访问的地址: $allowed_ip"
                        echo "2. 已拒绝其他所有地址访问"
                        echo "3. SSH服务已重启"
                        echo
                        echo "警告: 请确保您��前的IP在允许范围内"
                        echo "      如果配置有误，您可能会立即断开连接"
                        echo "      建议保持当前会话，另开窗口测试配置"
                    else
                        error_exit "重启SSH服务失败"
                    fi
                fi
            fi
            ;;
        2)
            if confirm_action "是否清除所有访问限制？"; then
                echo "" > "$hosts_allow"
                echo "" > "$hosts_deny"
                if systemctl restart sshd; then
                    echo "已清除所有远程访问限制"
                else
                    error_exit "重启SSH服务失败"
                fi
            fi
            ;;
        3)
            return
            ;;
        *)
            echo "无效选择"
            ;;
    esac
}

# 卸载不必要的软件包
remove_unnecessary_packages() {
    show_title "卸载不必要的软件包"
    
    # 1. 检查必要命令
    check_command_exists "rpm"
    check_command_exists "yum"
    
    # 2. 定义不必要的软件包
    local packages=(
        "ypbind:NIS绑定服务:络信息服务客户端"
        "rsh:远程shell:不安全的远程登录工具"
        "talk:聊天服务:不安全的通讯工具"
        "telnet:远程登录:明文传输的远程登录工具"
        "openldap-clients:LDAP客户端:轻量目录访问协议客户端"
        "ntalk:网络通讯:不安全的网络通讯工具"
    )
    
    echo "正在检查不必要的软件包..."
    echo "说明: 这些软件包可能存在安全隐患，建议卸载"
    echo
    
    local need_cleanup=0
    for package_info in "${packages[@]}"; do
        IFS=':' read -r package name description <<< "$package_info"
        echo "检查 $name ($package):"
        echo "  - 说明: $description"
        
        if rpm -q "$package" &>/dev/null; then
            echo "  - 状态: 已安装"
            if confirm_action "是否卸载 $package？"; then
                echo "  - 正在卸载..."
                if yum remove -y "$package"; then
                    echo "  - 已成功卸载"
                    need_cleanup=1
                else
                    echo "  - 卸载失败"
                fi
            fi
        else
            echo "  - 状态: 未安装"
        fi
        echo
    done
    
    # 3. 清理依赖
    if [ "${need_cleanup:-0}" -eq 1 ]; then
        if confirm_action "是否清理不需要的依赖包？"; then
            echo "正在清理依赖..."
            yum autoremove -y
            echo "清理完成"
        fi
    fi
}

# 禁止soocroot用户使用su命令
restrict_soocroot_su() {
    show_title "禁止soocroot用户使用su命令"
    
    # 1. 检查必要命令
    check_command_exists "visudo"
    
    # 2. 检查配置文件
    local sudoers_file="/etc/sudoers"
    check_file_exists "$sudoers_file"
    backup_file "$sudoers_file"
    
    echo "正在配置soocroot用户权限..."
    echo "说明: 限制soocroot用户使用特权命令可以提高系统安全性"
    echo
    
    # 3. 定义限制规则
    local soocroot_restrictions=(
        "soocroot ALL=(root) !/usr/bin/passwd:禁止修改密码"
        "soocroot ALL=(root) !/usr/bin/passwd [A-Za-z]*:禁止修改其他用户密码"
        "soocroot ALL=(root) !/usr/bin/passwd root:禁止修改root密码"
        "soocroot ALL=(root) !/usr/bin/su:禁止使用su命令"
        "soocroot ALL=(root) !/usr/sbin/userdel:禁止删除用户"
    )
    
    # 4. 添加��制配置
    local need_restart=0
    for restriction_info in "${soocroot_restrictions[@]}"; do
        IFS=':' read -r rule description <<< "$restriction_info"
        echo "添加限制: $description"
        if ! grep -q "^$rule" "$sudoers_file"; then
            echo "$rule" >> "$sudoers_file"
            echo "  - 已添加规则: $rule"
            need_restart=1
        else
            echo "  - 规则已存在"
        fi
    done
    
    if [ $need_restart -eq 1 ]; then
        echo
        echo "soocroot用户权限限制已更新"
        echo "限制项目:"
        echo "1. 禁止修改任何用户密码"
        echo "2. 禁止使用su命令"
        echo "3. 禁止删除用户"
    else
        echo
        echo "所有限制规则已经配置"
    fi
}

# 关闭扩展非必要服务
disable_extended_services() {
    show_title "关闭扩展非必要服务"
    
    # 1. 检查必要命令
    check_command_exists "systemctl"
    
    # 2. 定义扩展服务
    local extended_services=(
        "avahi-daemon:Avahi服务:零配置网络服务"
        "cups:打印服务:通用打印系统"
        "dhcpd:DHCP服务:动态主机配置协议服务"
        "slapd:LDAP服务:轻量目录访问协议服务"
        "nfs:网络文件系统:NFS服务器"
        "named:DNS服务:域名解析服务"
        "httpd:Web服务:HTTP服务器"
        "dovecot:邮件服务:IMAP/POP3服务器"
        "smb:文件共享:Samba服务"
        "squid:代理服务:HTTP代理服务器"
        "snmpd:网络管理:简单网络管理协议服务"
        "ypserv:NIS服务:网络信息服务"
        "rsyncd:同步服务:远程同步服务"
        "ntalk:通讯服务:网络通讯服务"
    )
    
    echo "正在检查扩展服务..."
    echo "说明: 这些服务可能不是必需的，建议关闭不使用的服务"
    echo "警告: 关闭服务前请确认系统功能依赖"
    echo
    
    echo "服务列表:"
    echo "----------------------------------------"
    for service_info in "${extended_services[@]}"; do
        IFS=':' read -r service name description <<< "$service_info"
        echo "- $name ($service)"
        echo "  说明: $description"
    done
    echo "----------------------------------------"
    echo
    
    if confirm_action "是否检查这些服务？"; then
        for service_info in "${extended_services[@]}"; do
            IFS=':' read -r service name description <<< "$service_info"
            echo "检查 $name ($service):"
            if systemctl is-enabled "$service" &>/dev/null; then
                echo "  - ��态: 已启用"
                if confirm_action "是否关闭此服务？"; then
                    if systemctl stop "$service" && systemctl disable "$service"; then
                        echo "  - 已禁用并停止服务"
                    else
                        echo "  - 操作失败，请手动检查"
                    fi
                fi
            else
                echo "  - 状态: 未启用或未安装"
            fi
            echo
        done
    fi
    
    echo "扩展服务检查完成"
}

# 配置文件还原功能
restore_backup_files() {
    show_title "配置文件还原"
    
    # 1. 检查备份目录
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "未找到备份目录: $BACKUP_DIR"
        return 1
    fi
    
    # 2. 查找所有备份文件
    echo "正在搜索备份文件..."
    echo "----------------------------------------"
    
    # 查找并显示所有备份文件
    local i=1
    declare -A restore_map
    
    while read -r backup_file; do
        # 获取原始文件名和时间戳
        local orig_file=$(basename "$backup_file" | sed 's/\.bak\.[0-9]\{14\}$//')
        local timestamp=$(echo "$backup_file" | grep -o '[0-9]\{14\}$')
        local backup_time=$(echo "$timestamp" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
        
        echo "$i) 原始文件: /$orig_file"
        echo "   备份文件: $backup_file"
        echo "   备份时间: $backup_time"
        echo
        
        restore_map[$i]="$orig_file:$backup_file"
        ((i++))
    done < <(find "$BACKUP_DIR" -type f -name "*.bak.*" | sort)
    
    if [ ${#restore_map[@]} -eq 0 ]; then
        echo "未找到任何备份文件"
        return 1
    fi
    
    # 3. 选择要还原的文件
    echo "请选择要还原的文件编号(多个文件用空格分隔输入 'all' 还原所有，输入 'q' 退出):"
    read -r choice
    
    case $choice in
        q|Q)
            echo "操作已取消"
            return 0
            ;;
        all|ALL)
            if confirm_action "确定要还原所有配置文件吗？"; then
                for key in "${!restore_map[@]}"; do
                    IFS=: read -r orig backup <<< "${restore_map[$key]}"
                    echo "正在还原 /$orig..."
                    if cat "$backup" | sudo tee "/$orig" >/dev/null; then
                        echo "  - 还原成功"
                    else
                        echo "  - 还原失败"
                    fi
                done
            fi
            ;;
        *)
            for num in $choice; do
                if [ -n "${restore_map[$num]}" ]; then
                    IFS=: read -r orig backup <<< "${restore_map[$num]}"
                    if confirm_action "是否还原 /$orig？"; then
                        echo "正在还原 /$orig..."
                        if cat "$backup" | sudo tee "/$orig" >/dev/null; then
                            echo "  - 还原成功"
                        else
                            echo "  - 还原失败"
                        fi
                    fi
                else
                    echo "无效的选择: $num"
                fi
            done
            ;;
    esac
    
    echo
    echo "还原操作完成"
    echo "提示: 某些配置可能需要重启相关服务才能生效"
}

# 查看配置文件备份
show_backup_files() {
    show_title "查看配置文件备份"
    
    # 1. 检查备份目录
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "未找到备份目录: $BACKUP_DIR"
        return 1
    fi
    
    # 2. 查找所有备份文件
    echo "正在搜索备份文件..."
    echo "----------------------------------------"
    
    # 查找并显示所有备份文件，按时间倒序排序
    local found=0
    while read -r backup_file; do
        # 获取原始文件路径和时间戳
        local orig_file=$(basename "$backup_file" | sed 's/\.bak\.[0-9]\{14\}$//')
        local timestamp=$(echo "$backup_file" | grep -o '[0-9]\{14\}$')
        local backup_time=$(echo "$timestamp" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
        
        # 显示文件信息和权限
        echo "原始文件: /$orig_file"
        echo "备份文件: $backup_file"
        echo "备份时间: $backup_time"
        echo "文件大小: $(stat -c %s "$backup_file") 字节"
        echo "文件权限: $(stat -c %A "$backup_file")"
        echo "所有者: $(stat -c %U:%G "$backup_file")"
        echo
        found=1
    done < <(find "$BACKUP_DIR" -type f -name "*.bak.*" | sort -r)
    
    if [ $found -eq 0 ]; then
        echo "未找到任何备份文件"
        return 1
    fi
    
    echo "----------------------------------------"
    echo "如需还原配置文件，请使用以下命令："
    echo "cat 备份文件路径 > 原始文件路径"
    echo
    echo "示例："
    echo "cat $BACKUP_DIR/system-auth.bak.20240101000000 > /etc/pam.d/system-auth"
    echo
    echo "注意事项："
    echo "1. ���原前建议先备份当前文件："
    echo "   cp /path/to/original/file /path/to/original/file.bak"
    echo
    echo "2. 还原后可能需要重启相关服务，常见服务重启命令："
    echo "   - SSH服务: systemctl restart sshd"
    echo "   - 审计服务: service auditd restart"
    echo "   - PAM配置: authconfig --updateall"
    echo
    echo "3. 安全建议："
    echo "   - 还原前先查看文件内容: cat 备份文件路径"
    echo "   - 还原后验证文件内容: diff 原始文件 备份文件"
    echo "   - 如果还原后出现问题，可以使用之前的备份恢复"
}

# 其他功能函数将在这里继续添加... 