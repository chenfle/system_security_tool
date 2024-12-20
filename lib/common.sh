#!/bin/bash
# -*- coding: utf-8 -*-

# 通用函数库

# 错误处理函数
error_exit() {
    echo "错误: $1" >&2
    exit "${2:-1}"
}

# 命令检查函数
check_command_exists() {
    local cmd=$1
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error_exit "命令 '$cmd' 不存在，请先安装"
    fi
}

# 文件检查函数
check_file_exists() {
    local file=$1
    if [ ! -f "$file" ]; then
        error_exit "文件 '$file' 不存在"
    fi
}

# 备份文件函数
backup_file() {
    local file=$1
    local backup_path="${BACKUP_DIR}/$(basename "${file}").bak.$(date +%Y%m%d%H%M%S)"
    
    # 检查文件是否存在
    if [ ! -f "$file" ]; then
        echo "警告: 文件 '$file' 不存在，跳过备份"
        return 0
    fi
    
    # 检查备份目录
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
    
    # 执行备份
    if cp -f "$file" "$backup_path" 2>/dev/null; then
        echo "已备份 $file 到 $backup_path"
        return 0
    else
        error_exit "备份文件 '$file' 失败"
    fi
}

# 确认用户输入函数
confirm_action() {
    local prompt=$1
    local response
    local global_choice=${GLOBAL_CHOICE:-""}
    
    # 如果已有全局选择，直接返回对应值
    case $global_choice in
        "a") return 0 ;;  # 全部是
        "r") return 1 ;;  # 全部否
        *) ;;            # 继续询问
    esac
    
    while true; do
        read -r -p "${prompt} (y/n/a/r/q): " response
        case $response in
            [Yy]) return 0 ;;      # 是
            [Nn]) return 1 ;;      # 否
            [Aa]) 
                GLOBAL_CHOICE="a"  # 设置全局选择为"全部是"
                return 0 
                ;;
            [Rr])
                GLOBAL_CHOICE="r"  # 设置全局选择为"全部否"
                return 1
                ;;
            [Qq]) exit 0 ;;        # 退出程序
            *) echo "请输入 y/n/a/r/q" ;;
        esac
    done
}

# 显示分隔线
show_separator() {
    printf "%s\n" "=================================================="
}

# 显示双线分隔符
show_double_separator() {
    printf "%s\n" "=================================================="
    printf "%s\n" "=================================================="
}

# 显示居中文本
show_centered_text() {
    local text="$1"
    local width=40  # 增加宽度，使显示更美观
    local padding=$(( (width - ${#text}) / 2 ))
    local extra_space=$(( width - padding - ${#text} - padding ))
    printf "%*s%s%*s\n" $padding "" "$text" $(( padding + extra_space )) ""
}

# 显示主菜单标题
show_main_menu_title() {
    # 主菜单只显示工具名称、作者信息和警告
    show_double_separator
    show_centered_text "   等保测评检查和修复工具 V${VERSION}"
    show_separator
    echo
    show_centered_text "                       作者：${AUTHOR}"
    show_centered_text "             参考来源：${REFERENCE}"
    show_double_separator
    echo
    show_centered_text "   警告：本工具未经过严格测试，请谨慎使用"
    show_double_separator
}

# 显示功能页面标题
show_function_title() {
    local title=$1
    # 功能页面只显示功能名称和操作说明
    show_double_separator
    show_centered_text "$title"
    show_separator
    echo "  操作说明:y是，n否，a全部是，r全部否，q退出程序"
    show_separator
    echo
}

# 显示标题
show_title() {
    local title=$1
    clear
    if [ -z "$title" ]; then
        show_main_menu_title
    else
        show_function_title "$title"
    fi
}

# 显示参数检查结果
show_param_check() {
    local param_name=$1
    local current_value=$2
    local expected_value=$3
    local description=$4
    
    echo "检查 $description:"
    echo "  - 当前值: ${current_value:-"未设置"}"
    echo "  - 推荐值: $expected_value"
    echo
}

# 等待用户确认
wait_for_enter() {
    read -r -p "按回车键继续..."
}