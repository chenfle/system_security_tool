#!/bin/bash
# -*- coding: utf-8 -*-

# 设置语言环境，防止乱码
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志文件路径
LOG_FILE="$(dirname $0)/system_config_$(date +%Y%m%d_%H%M%S).log"

# 记录日志的函数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo -e "${GREEN}$1${NC}"
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        handle_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 显示菜单函数
show_menu() {
    clear
    echo "============================================"
    echo "      Linux 系统配置工具 v2.0"
    echo "      作者: 陈甫罗恩@正元数币"
    echo "      日期: 2024年12月20日"
    echo "============================================"
    echo
    echo "警告: 本工具未经充分验证，请谨慎使用"
    echo
    echo "1. 一键系统检查"
    echo "2. 修改主机名"
    echo "3. 配置网络参数"
    echo "4. 配置DNS"
    echo "5. 配置防火墙"
    echo "6. 配置SELinux"
    echo "7. 配置时区"
    echo "8. 配置用户资源限制"
    echo "9. 退出"
    echo
}

# 检查外网连接
check_internet() {
    log_message "检查外网连接..."
    if ping -c 2 baidu.com &>/dev/null; then
        echo -e "${GREEN}外网连接: 正常${NC}"
    else
        echo -e "${RED}外网连接: 异常${NC}"
    fi
}

# 获取系统信息
get_system_info() {
    log_message "获取系统信息..."
    
    # 获取操作系统信息
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
    else
        OS_NAME="Unknown"
        OS_VERSION="Unknown"
    fi

    # 获取架构信息
    ARCH=$(uname -m)
    
    # 获取主机名
    HOSTNAME=$(hostname)

    # 输出信息
    echo -e "操作系统: ${GREEN}$OS_NAME $OS_VERSION${NC}"
    echo -e "系统架构: ${GREEN}$ARCH${NC}"
    echo -e "主机名: ${GREEN}$HOSTNAME${NC}"
}

# 检查SELinux状态
check_selinux() {
    log_message "检查SELinux状态..."
    if command -v getenforce &>/dev/null; then
        SELINUX_STATUS=$(getenforce)
        echo -e "SELinux状态: ${YELLOW}$SELINUX_STATUS${NC}"
    else
        echo -e "SELinux: ${YELLOW}未安装${NC}"
    fi
}

# 检查系统资源信息
check_system_resources() {
    log_message "检查系统资源信息..."
    
    # 获取CPU信息
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')
    CPU_CORES=$(nproc)
    
    # 获取内存信息
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    MEM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
    
    # 获取硬盘信息
    ROOT_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    ROOT_USED=$(df -h / | awk 'NR==2 {print $3}')
    ROOT_FREE=$(df -h / | awk 'NR==2 {print $4}')
    ROOT_FREE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    # 输出信息
    echo -e "\n=== 系统资源信息 ==="
    echo -e "CPU型号: ${GREEN}$CPU_MODEL${NC}"
    echo -e "CPU核心数: ${GREEN}$CPU_CORES${NC}"
    echo -e "\n内存信息:"
    echo -e "总容量: ${GREEN}$MEM_TOTAL${NC}"
    echo -e "已使用: ${YELLOW}$MEM_USED${NC}"
    echo -e "可用: ${GREEN}$MEM_FREE${NC}"
    echo -e "\n根目录空间:"
    echo -e "总容量: ${GREEN}$ROOT_TOTAL${NC}"
    echo -e "已使用: ${YELLOW}$ROOT_USED${NC}"
    echo -e "可用: ${GREEN}$ROOT_FREE${NC}"
    
    # 检查根目录空间是否不足
    if [ "$ROOT_FREE_GB" -lt "100" ]; then
        echo -e "${RED}警告: 根目录可用空间小于100GB，可能存在风险！${NC}"
    fi
}

# 检查网络配置
check_network_config() {
    log_message "检查网络配置..."
    
    # 获取默认网卡
    DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$DEFAULT_IFACE" ]; then
        echo -e "${RED}错误: 未找到默认网卡${NC}"
        return 1
    fi
    
    # 获取IP地址和子网掩码
    IP_INFO=$(ip addr show $DEFAULT_IFACE | grep "inet " | awk '{print $2}')
    IP_ADDR=$(echo $IP_INFO | cut -d/ -f1)
    NETMASK=$(echo $IP_INFO | cut -d/ -f2)
    
    # 获取网关
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1)
    
    # 检查网卡自启动状态
    if [ -f "/etc/sysconfig/network-scripts/ifcfg-$DEFAULT_IFACE" ]; then
        ONBOOT=$(grep "ONBOOT" "/etc/sysconfig/network-scripts/ifcfg-$DEFAULT_IFACE" | cut -d= -f2)
    else
        ONBOOT="未知"
    fi
    
    echo -e "\n=== 网络配置信息 ==="
    echo -e "默认网卡: ${GREEN}$DEFAULT_IFACE${NC}"
    echo -e "IP地址: ${GREEN}$IP_ADDR${NC}"
    echo -e "子网掩码: ${GREEN}$NETMASK${NC}"
    echo -e "网关: ${GREEN}$GATEWAY${NC}"
    echo -e "自启动状态: ${GREEN}$ONBOOT${NC}"
}

# 检查DNS配置
check_dns_config() {
    log_message "检查DNS配置..."
    
    if [ -f "/etc/resolv.conf" ]; then
        DNS_SERVERS=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}')
        if [ -z "$DNS_SERVERS" ]; then
            echo -e "${RED}警告: 未配置DNS服务器${NC}"
        else
            echo -e "\n=== DNS配置 ==="
            echo -e "当前DNS服务器:"
            while read -r dns; do
                echo -e "${GREEN}$dns${NC}"
            done <<< "$DNS_SERVERS"
        fi
    else
        echo -e "${RED}错误: 未找到DNS配置文件${NC}"
    fi
}

# 检查防火墙状态
check_firewall() {
    log_message "检查防火墙状态..."
    
    # 检查firewalld
    if command -v firewall-cmd &>/dev/null; then
        FIREWALL_STATUS=$(systemctl is-active firewalld)
        FIREWALL_ENABLED=$(systemctl is-enabled firewalld)
        echo -e "\n=== 防火墙状态(firewalld) ==="
        echo -e "当前状态: ${YELLOW}$FIREWALL_STATUS${NC}"
        echo -e "开机自启: ${YELLOW}$FIREWALL_ENABLED${NC}"
    # 检查ufw (Ubuntu/Debian)
    elif command -v ufw &>/dev/null; then
        UFW_STATUS=$(ufw status | grep "Status" | cut -d' ' -f2)
        echo -e "\n=== 防火墙状态(ufw) ==="
        echo -e "当前状态: ${YELLOW}$UFW_STATUS${NC}"
    else
        echo -e "${YELLOW}未检测到支持的防火墙服务${NC}"
    fi
}

# 检查时区信息
check_timezone() {
    log_message "检查时区信息..."
    
    CURRENT_TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "\n=== 时区信息 ==="
    echo -e "当前时区: ${GREEN}$CURRENT_TZ${NC}"
    echo -e "当前时间: ${GREEN}$CURRENT_TIME${NC}"
    
    if [ "$CURRENT_TZ" != "Asia/Shanghai" ]; then
        echo -e "${YELLOW}警告: 当前时区不是北京时间 (Asia/Shanghai)${NC}"
    fi
}

# 检查自定义用户
check_custom_users() {
    log_message "检查自定义用户..."
    
    # 定义系统用户UID范围
    MIN_UID=1000
    MAX_UID=60000
    
    # 获取自定义用户列表
    CUSTOM_USERS=$(awk -F: -v min=$MIN_UID -v max=$MAX_UID \
        '$3 >= min && $3 < max {print $1}' /etc/passwd)
    
    echo -e "\n=== 自定义用户列表 ==="
    if [ -z "$CUSTOM_USERS" ]; then
        echo -e "${GREEN}未发现自定义用户${NC}"
    else
        echo -e "发现以下自定义用户:"
        while read -r user; do
            echo -e "${YELLOW}- $user${NC}"
            # 检查用户限制文件
            if [ ! -f "/etc/security/limits.d/${user}.conf" ]; then
                echo -e "${RED}���告: 用户 $user 未配置资源限制文件${NC}"
            fi
        done <<< "$CUSTOM_USERS"
    fi
}

# 修改主机名配置函数
modify_hostname() {
    clear
    echo "=== 修改主机名 ==="
    CURRENT_HOSTNAME=$(hostname)
    echo "当前主机名: $CURRENT_HOSTNAME"
    read -p "请输入新的主机名(直接回车保持不变): " new_hostname
    
    if [ -n "$new_hostname" ]; then
        hostnamectl set-hostname "$new_hostname"
        echo "127.0.0.1 $new_hostname" >> /etc/hosts
        log_message "主机名已修改为: $new_hostname"
    fi
}

# 配置用户资源限制
configure_user_limits() {
    clear
    echo "=== 配置用户资源限制 ==="
    
    # 定义系统用户UID范围
    MIN_UID=1000
    MAX_UID=60000
    
    # 获取自定义用户列表
    CUSTOM_USERS=$(awk -F: -v min=$MIN_UID -v max=$MAX_UID \
        '$3 >= min && $3 < max {print $1}' /etc/passwd)
    
    if [ -z "$CUSTOM_USERS" ]; then
        echo "系统中未发现自定义用户"
        read -p "按回车键继续..."
        return 1
    fi
    
    # 显示现有用户列表
    echo "系统中的自定义用户列表:"
    echo "------------------------"
    i=1
    declare -A user_array
    while read -r user; do
        echo "$i. $user"
        user_array[$i]=$user
        i=$((i+1))
    done <<< "$CUSTOM_USERS"
    echo "------------------------"
    
    # 让用户选择要配置的用户
    read -p "请选择要配置的用户编号 (1-$((i-1)), 直接回车取消): " choice
    
    if [ -z "$choice" ]; then
        echo "已取消配置"
        return 0
    fi
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$i" ]; then
        echo "无效的选择"
        read -p "按回车键继续..."
        return 1
    fi
    
    username=${user_array[$choice]}
    
    # 检查用户是否存在
    if ! id "$username" >/dev/null 2>&1; then
        echo "错误: 用户 $username 不存在"
        read -p "按回车键继续..."
        return 1
    fi
    
    # 显示当前配置（如果存在）
    if [ -f "/etc/security/limits.d/${username}.conf" ]; then
        echo "当前用户 $username 的资源限制配置:"
        cat "/etc/security/limits.d/${username}.conf"
        echo
    fi
    
    # 确认是否要修改配置
    read -p "是否要配置用户 $username 的资源限制? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消配置"
        read -p "按回车键继续..."
        return 0
    fi
    
    # 创建或更新配置文件
    cat > "/etc/security/limits.d/${username}.conf" << EOF
# Default limit for number of user's processes to prevent
${username}   soft   nofile    4096
${username}   hard   nofile    65536
${username}   soft   nproc    16384
${username}   hard   nproc    16384
${username}   soft   stack    10240
${username}   hard   stack    32768
${username}   hard   memlock    134217728
${username}   soft   memlock    134217728
${username}   soft   nice       0
${username}   hard   nice       0
${username}   soft   as         unlimited
${username}   hard   as         unlimited
${username}   soft   fsize      unlimited
${username}   hard   fsize      unlimited
${username}   soft   core       unlimited
${username}   hard   core       unlimited
${username}   soft   data       unlimited
${username}   hard   data       unlimited
EOF
    
    if [ $? -eq 0 ]; then
        log_message "用户 $username 的资源限制配置已完成"
        echo "注意: 需要用户重新登录或重启服务器才能生效"
    else
        echo "错误: 配置文件创建失败"
    fi
    
    read -p "按回车键继续..."
}

# 添加错误处理函数
handle_error() {
    echo "错误: $1" >&2
    log_message "错误: $1"
    return 1
}

# 修改网络配置函数
configure_network() {
    clear
    echo "=== 配置网络参数 ==="
    
    # 获取并显示当前配置
    DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$DEFAULT_IFACE" ]; then
        echo "错误: 未找到默认网卡"
        return 1
    fi
    
    check_network_config
    read -p "是否要修改网络配置? [y/N]: " choice
    
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        read -p "请输入新的IP地址: " new_ip
        read -p "请输入子网掩码(例如: 24): " new_netmask
        read -p "请输入网关地址: " new_gateway
        
        local config_file="/etc/sysconfig/network-scripts/ifcfg-$DEFAULT_IFACE"
        if [ -f "$config_file" ]; then
            cp "$config_file" "${config_file}.bak"
            cat > "$config_file" << EOF
TYPE=Ethernet
BOOTPROTO=none
NAME=$DEFAULT_IFACE
DEVICE=$DEFAULT_IFACE
ONBOOT=yes
IPADDR=$new_ip
PREFIX=$new_netmask
GATEWAY=$new_gateway
EOF
            echo "正在重启网络服务..."
            systemctl restart network
            log_message "网络配置已更新"
        else
            echo "错误: 未找到网卡配置文件"
        fi
    fi
}

# 修改DNS配置函数
configure_dns() {
    clear
    echo "=== 配置DNS服务器 ==="
    
    # 检查当前网络管理工具
    if command -v nmcli >/dev/null 2>&1; then
        use_networkmanager=true
    else
        use_networkmanager=false
    fi
    
    # 显示当前配置
    echo "当前DNS配置:"
    if [ "$use_networkmanager" = true ]; then
        nmcli dev show | grep DNS
    else
        cat /etc/resolv.conf | grep -E "^nameserver|^search|^domain"
    fi
    
    echo
    echo "可选的DNS服务器:"
    echo "1. 阿里DNS (223.5.5.5, 223.6.6.6)"
    echo "2. 114 DNS (114.114.114.114)"
    echo "3. Google DNS (8.8.8.8)"
    echo "4. 自定义DNS"
    echo "5. 保持当前配置"
    
    read -p "请选择 (1-5): " dns_choice
    
    case "$dns_choice" in
        1)
            dns1="223.5.5.5"
            dns2="223.6.6.6"
            ;;
        2)
            dns1="114.114.114.114"
            dns2="114.114.114.115"
            ;;
        3)
            dns1="8.8.8.8"
            dns2="8.8.4.4"
            ;;
        4)
            while true; do
                read -p "请输入首选DNS服务器: " dns1
                if [[ $dns1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    break
                else
                    echo "无效的IP地址格式，请重新输入"
                fi
            done
            while true; do
                read -p "请输入备用DNS服务器: " dns2
                if [[ $dns2 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    break
                else
                    echo "无效的IP地址格式，请重新输入"
                fi
            done
            ;;
        5)
            return
            ;;
        *)
            echo "无效的选择"
            return
            ;;
    esac
    
    # 测试DNS服务器可用性
    echo "正在测试DNS服务器可用性..."
    if ! ping -c 1 -W 2 $dns1 >/dev/null 2>&1; then
        echo "警告: 首选DNS服务器 $dns1 可能无法访问"
        read -p "是否继续? [y/N]: " continue_choice
        [[ ! "$continue_choice" =~ ^[Yy]$ ]] && return
    fi
    
    # 备份当前配置
    local timestamp=$(date +%Y%m%d_%H%M%S)
    if [ -f /etc/resolv.conf ]; then
        cp /etc/resolv.conf "/etc/resolv.conf.bak.$timestamp"
        log_message "DNS配置已备份到 /etc/resolv.conf.bak.$timestamp"
    fi
    
    # 应用新配置
    if [ "$use_networkmanager" = true ]; then
        # 获取当前活动连接
        local connection=$(nmcli -t -f NAME,DEVICE c show --active | head -n1 | cut -d: -f1)
        if [ -n "$connection" ]; then
            nmcli connection modify "$connection" ipv4.dns "$dns1 $dns2"
            nmcli connection up "$connection"
            log_message "已通过NetworkManager更新DNS配置"
        else
            echo "错误: 未找到活动的网络连接"
            return 1
        fi
    else
        # 配置resolv.conf
        if [ -L /etc/resolv.conf ]; then
            echo "警告: /etc/resolv.conf 是符号链接，可能会被系统重置"
            read -p "是否继续? [y/N]: " continue_choice
            [[ ! "$continue_choice" =~ ^[Yy]$ ]] && return
        fi
        
        # 保留原有的search和domain配置
        local search_line=$(grep "^search" /etc/resolv.conf)
        local domain_line=$(grep "^domain" /etc/resolv.conf)
        
        # 写入新配置
        {
            [ -n "$search_line" ] && echo "$search_line"
            [ -n "$domain_line" ] && echo "$domain_line"
            echo "nameserver $dns1"
            echo "nameserver $dns2"
        } > /etc/resolv.conf
        
        # 设置权限
        chown root:root /etc/resolv.conf
        chmod 644 /etc/resolv.conf
        
        log_message "DNS配置已更新到 /etc/resolv.conf"
    fi
    
    # 验证新配置
    echo "正在验证DNS配置..."
    if host -W 2 www.baidu.com >/dev/null 2>&1; then
        echo "DNS配置测试成功"
    else
        echo "警告: DNS解析测试失败，请检查配置"
        echo "如需恢复配置，可以使用备份文件: /etc/resolv.conf.bak.$timestamp"
    fi
}

# 修改防火墙配置函数
configure_firewall() {
    clear
    echo "=== 配置防火墙 ==="
    
    if command -v firewall-cmd &>/dev/null; then
        echo "当前防火墙(firewalld)状态:"
        echo "运行状态: $(systemctl is-active firewalld)"
        echo "开机启动: $(systemctl is-enabled firewalld)"
        
        echo
        echo "1. 停止并禁用防火墙"
        echo "2. 启动并启用防火墙"
        echo "3. 保持当前状态"
        
        read -p "请选择 (1-3): " choice
        case "$choice" in
            1)
                systemctl stop firewalld
                systemctl disable firewalld
                log_message "防火墙已停止并禁用"
                ;;
            2)
                systemctl start firewalld
                systemctl enable firewalld
                log_message "防火墙已启动并启用"
                ;;
            3)
                return
                ;;
        esac
    elif command -v ufw &>/dev/null; then
        echo "当前防火墙(ufw)状态:"
        ufw status
        
        echo
        echo "1. 禁用防火墙"
        echo "2. 启用防火墙"
        echo "3. 保持当前状态"
        
        read -p "请选择 (1-3): " choice
        case "$choice" in
            1)
                ufw disable
                log_message "防火墙已禁用"
                ;;
            2)
                ufw enable
                log_message "防火墙已启用"
                ;;
            3)
                return
                ;;
        esac
    else
        echo "未检测到支持的防火墙服务"
    fi
}

# 修改SELinux配置函数
configure_selinux() {
    clear
    echo "=== 配置SELinux ==="
    
    if command -v getenforce &>/dev/null; then
        echo "当前SELinux状态: $(getenforce)"
        echo
        echo "1. 禁用SELinux"
        echo "2. 启用SELinux"
        echo "3. 保持当前状态"
        
        read -p "请选择 (1-3): " choice
        case "$choice" in
            1)
                setenforce 0
                sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
                log_message "SELinux已禁用（重启后永久生效）"
                ;;
            2)
                setenforce 1
                sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
                log_message "SELinux已启用"
                ;;
            3)
                return
                ;;
        esac
    else
        echo "系统未安装SELinux"
    fi
}

# 修改时区配置函数
configure_timezone() {
    clear
    echo "=== 配置时区 ==="
    echo "当前时区: $(timedatectl | grep "Time zone" | awk '{print $3}')"
    echo "当前时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    echo "1. 设置为北京时间 (Asia/Shanghai)"
    echo "2. 保持当前时区"
    
    read -p "请选择 (1-2): " choice
    case "$choice" in
        1)
            timedatectl set-timezone Asia/Shanghai
            log_message "时区已设置为北京时间"
            ;;
        2)
            return
            ;;
    esac
}

# 测试中文显示
test_chinese_display() {
    echo -e "${GREEN}测试中文显示...${NC}"
    echo -e "${RED}错误信息测试${NC}"
    echo -e "${YELLOW}警告信息测试${NC}"
    echo "标准信息测试"
}

# 一键系统检查函数
check_all_system() {
    clear
    echo "=== 开始系统全面检查 ==="
    check_internet
    get_system_info
    check_selinux
    check_system_resources
    check_network_config
    check_dns_config
    check_firewall
    check_timezone
    check_custom_users
    read -p "按回车键继续..."
}

# 主函数
main() {
    # 检查root权限
    check_root
    
    # 创建日志目录（如果不存在）
    LOG_DIR="$(dirname $0)/logs"
    mkdir -p "$LOG_DIR"
    
    # 设置��志文件名
    LOG_FILE="$LOG_DIR/system_config_$(date +%Y%m%d_%H%M%S).log"
    
    # 记录脚本启动
    log_message "脚本开始执行"
    
    while true; do
        show_menu
        read -p "请选择功能 (1-9): " choice
        case $choice in
            1)
                check_all_system
                ;;
            2)
                modify_hostname
                read -p "按回车键继续..."
                ;;
            3)
                configure_network
                read -p "按回车键继续..."
                ;;
            4)
                configure_dns
                read -p "按回车键继续..."
                ;;
            5)
                configure_firewall
                read -p "按回车键继续..."
                ;;
            6)
                configure_selinux
                read -p "按回车键继续..."
                ;;
            7)
                configure_timezone
                read -p "按回车键继续..."
                ;;
            8)
                configure_user_limits
                ;;
            9)
                log_message "程序退出"
                exit 0
                ;;
            *)
                echo "无效的选择，请重试"
                sleep 2
                ;;
        esac
    done
}

# 启动程序
main 