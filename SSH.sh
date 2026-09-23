#!/bin/bash

export LANG=en_US.UTF-8

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 root 权限或通过 sudo 运行此脚本！"
    exit 1
fi

# 定义颜色变量
GREEN='\033[1;32m'
SKYBLUE='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # 恢复默认颜色

# SSH 脚本相关的颜色与变量
gl_lv="\033[32m"
gl_huang="\033[33m"
gl_hong="\033[31m"
gl_hui="\033[90m"
gl_bai="\033[0m"

# 核心状态组合展示函数
show_system_status() {
    echo ""
    
    # 0. 系统发行版本
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS_NAME="${PRETTY_NAME:-$NAME}"
    elif [ -f /etc/redhat-release ]; then
        OS_NAME="$(cat /etc/redhat-release)"
    else
        OS_NAME="未知系统"
    fi

    printf "%-18s : %s\n" "系统版本" "$OS_NAME"
    echo "----------------------------------------"

    # 1. CPU 与内核架构信息
    CPU_ARCH=$(uname -m)
    KERNEL_VER=$(uname -r)
    CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -n 1 | cut -d ':' -f2 | xargs)
    CPU_CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null)
    CPU_MHZ=$(grep "cpu MHz" /proc/cpuinfo 2>/dev/null | head -n 1 | cut -d ':' -f2 | xargs)
    [ -n "$CPU_MHZ" ] && CPU_FREQ=$(awk "BEGIN {print $CPU_MHZ/1000}")" GHz" || CPU_FREQ="未知"

    printf "%-18s : %s\n" "CPU架构" "${CPU_ARCH:-未知}"
    printf "%-18s : %s\n" "内核版本" "${KERNEL_VER:-未知}"
    printf "%-18s : %s\n" "CPU型号" "${CPU_MODEL:-未知}"
    printf "%-18s : %s\n" "CPU核心数" "${CPU_CORES:-未知}"
    printf "%-18s : %s\n" "CPU频率" "$CPU_FREQ"
    echo "----------------------------------------"

    # 2. 负载与内存
    CPU_USAGE=$(top -b -n1 2>/dev/null | grep "Cpu(s)" | awk '{print 100 - $8"%"}')
    [ -z "$CPU_USAGE" ] && CPU_USAGE="0%"
    
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    
    TCP_CONN=$(ss -t 2>/dev/null | wc -l)
    UDP_CONN=$(ss -u 2>/dev/null | wc -l)
    
    if command -v free &>/dev/null; then
        MEM_INFO=$(free -m | awk 'NR==2{printf "%.2f/%.2fM (%.2f%%)", $3, $2, $3*100/$2}')
        SWAP_INFO=$(free -m | awk 'NR==3{printf "%dM/%dM (%.0f%%)", $3, $2, ($2>0? $3*100/$2 : 0)}')
    else
        MEM_INFO="未知"
        SWAP_INFO="未知"
    fi

    DISK_INFO=$(df -h / 2>/dev/null | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}')

    printf "%-18s : %s\n" "CPU占用" "$CPU_USAGE"
    printf "%-18s : %s\n" "系统负载" "${LOAD_AVG:-未知}"
    printf "%-18s : %s|%s\n" "TCP|UDP连接数" "$TCP_CONN" "$UDP_CONN"
    printf "%-18s : %s\n" "物理内存" "$MEM_INFO"
    printf "%-18s : %s\n" "虚拟内存" "$SWAP_INFO"
    printf "%-18s : %s\n" "硬盘占用" "${DISK_INFO:-未知}"
    echo "----------------------------------------"

    # 3. 网络流量与算法
    DEFAULT_IFACE=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -n 1)
    if [ -n "$DEFAULT_IFACE" ] && [ -f /sys/class/net/$DEFAULT_IFACE/statistics/rx_bytes ]; then
        RX_BYTES=$(cat /sys/class/net/$DEFAULT_IFACE/statistics/rx_bytes)
        TX_BYTES=$(cat /sys/class/net/$DEFAULT_IFACE/statistics/tx_bytes)
        RX_GB=$(awk "BEGIN {print $RX_BYTES/1024/1024/1024}")"G"
        TX_GB=$(awk "BEGIN {print $TX_BYTES/1024/1024/1024}")"G"
    else
        RX_GB="0G"
        TX_GB="0G"
    fi

    TCP_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    TCP_QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    NET_ALGO="${TCP_CC:-bbr} ${TCP_QDISC:-fq}"

    printf "%-18s : %s\n" "总接收" "$RX_GB"
    printf "%-18s : %s\n" "总发送" "$TX_GB"
    echo "----------------------------------------"
    printf "%-18s : %s\n" "网络算法" "$NET_ALGO"
    echo "----------------------------------------"

    # 4. IP 与归属地信息
    PUB_DATA=$(curl -s --max-time 3 https://ipinfo.io/json)
    if [ -n "$PUB_DATA" ]; then
        IP_ADDR=$(echo "$PUB_DATA" | grep -o '"ip": "[^"]*' | head -n 1 | cut -d'"' -f4)
        ORG=$(echo "$PUB_DATA" | grep -o '"org": "[^"]*' | head -n 1 | cut -d'"' -f4)
        CITY=$(echo "$PUB_DATA" | grep -o '"city": "[^"]*' | head -n 1 | cut -d'"' -f4)
        REGION=$(echo "$PUB_DATA" | grep -o '"region": "[^"]*' | head -n 1 | cut -d'"' -f4)
        COUNTRY=$(echo "$PUB_DATA" | grep -o '"country": "[^"]*' | head -n 1 | cut -d'"' -f4)
    else
        IP_ADDR=$(curl -s --max-time 3 https://api.ip.sb/ip)
        ORG="未知"
        CITY=""
        REGION=""
        COUNTRY="未知"
    fi
    
    CIP_RES=$(curl -s --max-time 3 https://cip.cc)
    CH_ADDR=$(echo "$CIP_RES" | grep "地址" | awk -F: '{print $2}' | xargs)
    [ -z "$CH_ADDR" ] && CH_ADDR="$COUNTRY $REGION $CITY"

    DNS_SERVERS=$(grep -E "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')

    printf "%-18s : %s\n" "运营商" "${ORG:-未知}"
    printf "%-18s : %s\n" "IPv4地址" "${IP_ADDR:-获取失败}"
    printf "%-18s : %s\n" "DNS地址" "${DNS_SERVERS:-未知}"
    printf "%-18s : %s\n" "地理位置" "${CH_ADDR:-未知}"
    
    SYS_TIME=$(date +"%Z %Y-%m-%d %I:%M %p")
    UP_DAYS=$(awk '{print int($1/86400)}' /proc/uptime 2>/dev/null)
    UP_HOURS=$(awk '{print int(($1%86400)/3600)}' /proc/uptime 2>/dev/null)
    UP_MINS=$(awk '{print int(($1%3600)/60)}' /proc/uptime 2>/dev/null)
    
    if [ "$UP_DAYS" -gt 0 ]; then
        UPTIME_STR="${UP_DAYS}天 ${UP_HOURS}时 ${UP_MINS}分"
    else
        UPTIME_STR="${UP_HOURS}时 ${UP_MINS}分"
    fi

    printf "%-18s : %s\n" "系统时间" "$SYS_TIME"
    echo "----------------------------------------"
    printf "%-18s : %s\n" "运行时长" "$UPTIME_STR"
    echo ""
    echo -e "${GREEN}操作完成${NC}"
}

change_user_password() {
    echo ""
    echo -e "${YELLOW}=== 修改系统用户密码 ===${NC}"
    
    DEFAULT_TARGET="${SUDO_USER:-root}"
    read -p "请输入要修改密码的用户名 (默认回车为 $DEFAULT_TARGET): " TARGET_USER
    TARGET_USER="${TARGET_USER:-$DEFAULT_TARGET}"

    if id "$TARGET_USER" &>/dev/null; then
        echo -e "正在为用户 ${GREEN}$TARGET_USER${NC} 修改密码..."
        passwd "$TARGET_USER"
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}===============================================${NC}"
            echo -e "${GREEN} ✔ 用户 [$TARGET_USER] 密码修改成功！${NC}"
            echo -e "${GREEN} 💡 提示：请断开当前的 SSH 登录，${NC}"
            echo -e "${GREEN}           然后务必使用新密码重新登录进行测试！${NC}"
            echo -e "${GREEN}===============================================${NC}"
        else
            echo -e "${RED}❌ 密码修改失败或操作被取消。${NC}"
        fi
    else
        echo -e "${RED}❌ 错误：用户 '$TARGET_USER' 不存在！${NC}"
    fi
}

send_stats() {
    local action="$1"
}

break_end() {
    echo ""
    read -n 1 -s -r -p "按任意键继续..."
    echo ""
}

ip_address() {
    ipv4_address=$(curl -s 4.ip.sb || hostname -I | awk '{print $1}')
}

restart_ssh() {
    if systemctl list-units --full -all | grep -Fq "ssh.service"; then
        systemctl restart ssh
    elif systemctl list-units --full -all | grep -Fq "sshd.service"; then
        systemctl restart sshd
    else
        service ssh restart 2>/dev/null || service sshd restart 2>/dev/null
    fi
}

sshkey_on() {
    sed -i -e 's/^\s*#\?\s*PermitRootLogin .*/PermitRootLogin prohibit-password/' \
           -e 's/^\s*#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' \
           -e 's/^\s*#\?\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' \
           -e 's/^\s*#\?\s*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
    restart_ssh
    echo -e "${gl_lv}用户密钥登录模式已开启，已关闭密码登录模式，重连将会生效${gl_bai}"
}

add_sshkey() {
    chmod 700 "${HOME}"
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
    touch "${HOME}/.ssh/authorized_keys"

    ssh-keygen -t ed25519 -C "xxxx@gmail.com" -f "${HOME}/.ssh/sshkey" -N ""

    cat "${HOME}/.ssh/sshkey.pub" >> "${HOME}/.ssh/authorized_keys"
    chmod 600 "${HOME}/.ssh/authorized_keys"

    ip_address
    echo -e "私钥信息已生成，务必复制保存，可保存成 ${gl_huang}${ipv4_address}_ssh.key${gl_bai} 文件，用于以后的SSH登录"

    echo "--------------------------------"
    cat "${HOME}/.ssh/sshkey"
    echo "--------------------------------"

    sshkey_on
}

clean_old_sshkeys() {
    if [[ -f "${HOME}/.ssh/sshkey.pub" ]]; then
        cat "${HOME}/.ssh/sshkey.pub" > "${HOME}/.ssh/authorized_keys"
        chmod 600 "${HOME}/.ssh/authorized_keys"
        echo -e "${gl_lv}清理成功！已清除所有旧公钥，现在只保留了最新生成的公钥。${gl_bai}"
    else
        echo -e "${gl_hong}错误：未找到本地的 sshkey.pub 文件，请先生成新密钥对。${gl_bai}"
    fi
}

add_sshpasswd() {
    send_stats "设置密码登录模式"
    echo "设置密码登录模式"

    local target_user="$1"

    if [[ -z "$target_user" ]]; then
        read -e -p "请输入要修改密码的用户名（默认 root）: " target_user
    fi

    target_user=${target_user:-root}

    if ! id "$target_user" >/dev/null 2>&1; then
        echo "错误：用户 $target_user 不存在"
        return 1
    fi

    passwd "$target_user"

    if [[ "$target_user" == "root" ]]; then
        sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    fi

    sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*

    restart_ssh

    echo -e "${gl_lv}密码设置完毕，已更改为密码登录模式！${gl_bai}"
}

sshkey_panel() {
  send_stats "用户密钥登录"
  while true; do
    clear
    local REAL_STATUS=$(grep -i "^PubkeyAuthentication" /etc/ssh/sshd_config 2>/dev/null | tr '[:upper:]' '[:lower:]')
    if [[ "$REAL_STATUS" =~ "yes" ]]; then
        IS_KEY_ENABLED="${gl_lv}已启用${gl_bai}"
    else
        IS_KEY_ENABLED="${gl_hui}未启用${gl_bai}"
    fi
    echo -e "用户密钥登录模式 ${IS_KEY_ENABLED}"
    echo "进阶玩法: https://blog.kejilion.pro/ssh-key"
    echo "------------------------------------------------"
    echo "将会生成密钥对，更安全的方式SSH登录"
    echo "------------------------"
    echo "1. 生成新密钥对"
    echo "2. 查看本机密钥"
    echo "3. 一键清理旧公钥（仅保留最新）"
    echo "4. 恢复/设置密码登录模式"
    echo "------------------------"
    echo "0. 返回上一级选单"
    echo "------------------------"
    read -e -p "请输入你的选择: " host_dns
    case $host_dns in
        1)
            send_stats "生成新密钥"
            add_sshkey
            break_end
            ;;
        2)
            send_stats "查看本机密钥"
            echo "------------------------"
            echo "公钥信息"
            cat ${HOME}/.ssh/authorized_keys 2>/dev/null || echo "暂无公钥"
            echo "------------------------"
            echo "私钥信息"
            cat ${HOME}/.ssh/sshkey 2>/dev/null || echo "暂无私钥"
            echo "------------------------"
            break_end
            ;;
        3)
            send_stats "一键清理旧公钥"
            clean_old_sshkeys
            break_end
            ;;
        4)
            add_sshpasswd
            break_end
            ;;
        0)
            echo "正在返回主菜单..."
            sleep 1
            break
            ;;
        *)
            echo "无效的选择，请重新输入"
            sleep 1
            ;;
    esac
  done
}

while true; do
    echo ""
    echo -e "${SKYBLUE}==================================================${NC}"
    echo -e "${SKYBLUE}          📊 Linux 系统信息与工具面板         ${NC}"
    echo -e "${SKYBLUE}==================================================${NC}"
    echo " 1. 查看系统版本,硬件,IP等信息"
    echo " 2. 修改系统用户密码"
    echo " 3. SSH 密钥与登录安全管理"
    echo " 0. 退出脚本"
    echo -e "${SKYBLUE}==================================================${NC}"
    read -p "请选择操作 [0-3]: " CHOICE

    case "$CHOICE" in
        1) show_system_status ;;
        2) change_user_password ;;
        3) sshkey_panel ;;
        0)
            echo -e "${GREEN}已安全退出脚本。${NC}"
            break
            ;;
        *)
            echo -e "${RED}❌ 无效的选项，请输入 0 到 3 之间的数字。${NC}"
            ;;
    esac
    
    echo ""
    read -p "按任意键继续..."
done
