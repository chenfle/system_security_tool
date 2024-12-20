#!/bin/bash

# 安全检查和修复工具
# 作者：陈甫罗恩@正元数币
# 参考来源：李宇辰@正元数币 
# 版本：5.0

# 设置错误处理
set -e
trap 'error_exit "第 $LINENO 行发生错误"' ERR

# 导入函数库
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_DIR}/lib/common.sh" || error_exit "加载 common.sh 失败"
source "${SCRIPT_DIR}/lib/functions.sh" || error_exit "加载 functions.sh 失败"

# 全局变量定义
BACKUP_DIR="${SCRIPT_DIR}/logs"
VERSION="5.0"
AUTHOR="  陈甫罗恩@正元数币"
REFERENCE=" 李宇辰@正元智慧"
GLOBAL_CHOICE=""  # 全局选择变量

# 检查必要的命令
check_required_commands() {
    local required_commands=(
        "systemctl"
        "sed"
        "awk"
        "grep"
        "cp"
        "mv"
        "rm"
        "cat"
        "chmod"
        "chown"
    )
    
    for cmd in "${required_commands[@]}"; do
        check_command_exists "$cmd"
    done
}

# 检查运行环境
check_environment() {
    # 检查是否为root用户
    if [ "$(id -u)" != "0" ]; then
        error_exit "此脚本必须以root用户运行"
    fi
    
    # 检查必要命令
    check_required_commands
    
    # 创建备份目录
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR" || error_exit "创建备份目录失败"
    fi
}

# 主菜单函数
show_main_menu() {
    show_title "等保测评检查和修复工具 V${VERSION}"
    echo "     作者：${AUTHOR}"
    echo "     参考来源：${REFERENCE}"
    show_separator
    echo "     警告：本工具未经过严格测试，请谨慎使用"
    show_separator
    echo " 1. 设置SSH端口(1727)并配置防火墙"
    echo " 2. 检查危险的主机和用户信任文件"
    echo " 3. 检测同名账户"
    echo " 4. 检测空密码账户"
    echo " 5. 检查密码有效期设置"
    echo " 6. 密码复杂策略设置"
    echo " 7. 配置密码最长使用时间"
    echo " 8. 配置登录失败策略"
    echo " 9. 配置会话超时"
    echo "10. 关闭telnet和ftp服务"
    echo "11. 创建审计账户"
    echo "12. 配置审计账户sudo权限"
    echo "13. 检测多余过期共享账户"
    echo "14. 限制root用户远程登录(非必要不操作)"
    echo "15. 开启审计功能"
    echo "16. 关闭非必要服务"
    echo "17. 配置远程接入限制"
    echo "18. 卸载不必要的软件包"
    echo "19. 禁止soocroot用户使用su命令"
    echo "20. 关闭扩展非必要服务"
    echo "21. 查看配置文件备份"
    echo " q. 退出"
    show_separator
}

# 处理用户输入函数
handle_user_input() {
    local choice
    read -r -p "请输入选项 [1-21/q]: " choice
    case $choice in
        1) configure_ssh_port ;;          # 设置SSH端口(1727)并配置防火墙
        2) check_dangerous_trust_files ;; # 检查危险的主机和用户信任文件
        3) check_duplicate_accounts ;;    # 检测同名账户
        4) check_empty_passwords ;;       # 检测空密码账户
        5) check_password_validity ;;     # 检查密码有效期设置
        6) configure_password_complexity ;; # 密码复杂策略设置
        7) configure_password_max_days ;; # 配置密码最长使用时间
        8) configure_login_failure_policy ;; # 配置登录失败策略
        9) configure_session_timeout ;;      # 配置会话超时
        10) disable_telnet_ftp ;;           # 关闭telnet和ftp服务
        11) create_audit_account ;;          # 创建审计账户
        12) configure_audit_sudo ;;          # 配置审计账户sudo权限
        13) check_expired_shared_accounts ;; # 检测多余过期共享账户
        14) restrict_root_login ;;        # 限制root用户远程登录
        15) configure_audit ;;            # 开启审计功能
        16) disable_unnecessary_services ;; # 关闭非必要服务
        17) configure_remote_access ;;    # 配置远程接入限制
        18) remove_unnecessary_packages ;; # 卸载不必要的软件包
        19) restrict_soocroot_su ;;       # 禁止soocroot用户使用su命令
        20) disable_extended_services ;;  # 关闭扩展非必要服务
        21) show_backup_files ;;    # 查看配置文件备份
        q|Q) exit 0 ;;
        *) echo "无效选项，请重新选择" ;;
    esac
}

# 主程序循环
main() {
    # 检查运行环境
    check_environment
    
    # 主循环
    while true; do
        show_main_menu
        handle_user_input
        # 重置全局选择
        GLOBAL_CHOICE=""
        wait_for_enter
    done
}

# 启动主程序
main