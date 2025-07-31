#!/bin/bash

# 安全告警分析系统 - 停止脚本
# Security Alert Analysis System - Stop Script
# Version: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${SCRIPT_DIR}/security_system.pid"
LOG_DIR="${SCRIPT_DIR}/logs"
STOP_LOG="${LOG_DIR}/stop_$(date +%Y%m%d_%H%M%S).log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 创建日志目录
mkdir -p "$LOG_DIR"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$STOP_LOG"
}

print_banner() {
    clear
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        安全告警分析系统 - 停止服务                           ║"
    echo "║                    Security Alert Analysis System                            ║"
    echo "║                             Stop Services v2.0                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_section() {
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
    log_message "INFO" "$1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log_message "WARN" "$1"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    log_message "ERROR" "$1"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
    log_message "INFO" "$1"
}

stop_api_service() {
    print_section "🛑 停止API服务"
    
    if [ -f "$PID_FILE" ]; then
        local api_pid=$(cat "$PID_FILE")
        if ps -p "$api_pid" > /dev/null 2>&1; then
            print_info "停止API服务 (PID: $api_pid)"
            kill -TERM "$api_pid" 2>/dev/null || kill -9 "$api_pid" 2>/dev/null
            
            # 等待进程结束
            local max_wait=10
            local waited=0
            while ps -p "$api_pid" > /dev/null 2>&1 && [ $waited -lt $max_wait ]; do
                sleep 1
                ((waited++))
                echo -ne "\r等待API服务停止... [${waited}s/${max_wait}s]"
            done
            echo ""
            
            if ps -p "$api_pid" > /dev/null 2>&1; then
                print_warning "API服务未正常停止，强制终止"
                kill -9 "$api_pid" 2>/dev/null || true
            fi
            
            print_status "API服务已停止"
        else
            print_warning "API服务进程不存在 (PID: $api_pid)"
        fi
        
        rm -f "$PID_FILE"
    else
        print_warning "未找到PID文件，尝试查找API进程"
        
        # 查找可能的API进程
        local api_pids=$(ps aux | grep "uvicorn.*security_api" | grep -v grep | awk '{print $2}')
        if [ -n "$api_pids" ]; then
            print_info "发现API进程: $api_pids"
            for pid in $api_pids; do
                kill -TERM "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
                print_info "已终止进程: $pid"
            done
            print_status "API服务已停止"
        else
            print_status "未发现运行中的API服务"
        fi
    fi
    
    # 检查端口8000是否仍被占用
    if lsof -ti:8000 > /dev/null 2>&1; then
        local port_pid=$(lsof -ti:8000)
        print_warning "端口8000仍被占用 (PID: $port_pid)，强制释放"
        kill -9 "$port_pid" 2>/dev/null || true
    fi
}

stop_docker_services() {
    print_section "🐳 停止Docker服务"
    
    if [ ! -f "docker-compose.yml" ]; then
        print_warning "未找到 docker-compose.yml 文件"
        return 1
    fi
    
    # 获取当前运行的服务
    local running_services=$(docker-compose ps --services --filter "status=running" 2>/dev/null || true)
    
    if [ -z "$running_services" ]; then
        print_status "没有运行中的Docker服务"
        return 0
    fi
    
    print_info "正在停止Docker服务..."
    echo "运行中的服务: $running_services"
    
    # 优雅停止服务
    print_info "优雅停止服务..."
    if docker-compose stop > "$LOG_DIR/docker_stop.log" 2>&1; then
        print_status "Docker服务已停止"
    else
        print_warning "Docker服务停止失败，尝试强制停止"
        docker-compose kill > "$LOG_DIR/docker_kill.log" 2>&1
    fi
    
    # 询问是否删除容器和卷
    if [ -t 0 ]; then  # 检查是否为交互式终端
        echo ""
        read -p "是否删除容器? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "删除容器..."
            docker-compose rm -f > "$LOG_DIR/docker_rm.log" 2>&1
            print_status "容器已删除"
        fi
        
        read -p "是否删除数据卷? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_warning "警告: 这将删除所有数据!"
            read -p "确认删除数据卷? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "删除数据卷..."
                docker-compose down -v > "$LOG_DIR/docker_down_volumes.log" 2>&1
                print_status "数据卷已删除"
            fi
        fi
    else
        # 非交互模式，只停止服务
        print_info "非交互模式，仅停止服务"
    fi
}

cleanup_processes() {
    print_section "🧹 清理相关进程"
    
    # 清理可能残留的相关进程
    local process_patterns=(
        "python.*security_api"
        "uvicorn.*security"
        "kafka"
        "elasticsearch"
        "neo4j"
        "clickhouse"
        "redis"
        "mysql"
    )
    
    for pattern in "${process_patterns[@]}"; do
        local pids=$(ps aux | grep "$pattern" | grep -v grep | awk '{print $2}')
        if [ -n "$pids" ]; then
            print_info "发现相关进程: $pattern"
            for pid in $pids; do
                local process_info=$(ps -p "$pid" -o pid,comm,args --no-headers 2>/dev/null || echo "进程不存在")
                print_info "进程信息: $process_info"
                
                # 询问是否终止（仅在交互模式下）
                if [ -t 0 ]; then
                    read -p "是否终止此进程? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        kill -TERM "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
                        print_info "已终止进程: $pid"
                    fi
                else
                    # 非交互模式下，不自动终止系统进程
                    if [[ "$pattern" =~ "security" ]] || [[ "$pattern" =~ "uvicorn" ]]; then
                        kill -TERM "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
                        print_info "已终止安全系统相关进程: $pid"
                    else
                        print_info "跳过系统进程: $pid"
                    fi
                fi
            done
        fi
    done
}

cleanup_ports() {
    print_section "🔌 释放端口"
    
    local ports=(8000 5601 7474 8123 9200 6379 3306 9092 2181 8082)
    
    for port in "${ports[@]}"; do
        if lsof -ti:$port > /dev/null 2>&1; then
            local pid=$(lsof -ti:$port)
            local process_info=$(ps -p "$pid" -o comm --no-headers 2>/dev/null || echo "未知进程")
            
            print_warning "端口 $port 被占用 (PID: $pid, 进程: $process_info)"
            
            if [ -t 0 ]; then
                read -p "是否释放端口 $port? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    kill -9 "$pid" 2>/dev/null || true
                    print_info "已释放端口: $port"
                fi
            else
                # 非交互模式下，只释放系统相关端口
                if [ "$port" -eq 8000 ]; then
                    kill -9 "$pid" 2>/dev/null || true
                    print_info "已释放API端口: $port"
                else
                    print_info "跳过端口: $port"
                fi
            fi
        else
            print_status "端口 $port 空闲"
        fi
    done
}

create_backup() {
    print_section "💾 创建备份"
    
    local backup_dir="${SCRIPT_DIR}/backup/stop_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份重要文件
    local files_to_backup=(
        "docker-compose.yml"
        "requirements.txt"
        "src/"
        "config/"
    )
    
    for item in "${files_to_backup[@]}"; do
        if [ -e "$item" ]; then
            print_info "备份: $item"
            cp -r "$item" "$backup_dir/" 2>/dev/null || true
        fi
    done
    
    # 备份日志文件
    if [ -d "$LOG_DIR" ]; then
        print_info "备份日志文件"
        cp -r "$LOG_DIR" "$backup_dir/logs_backup" 2>/dev/null || true
    fi
    
    print_status "备份完成: $backup_dir"
}

generate_stop_report() {
    print_section "📊 生成停止报告"
    
    local report_file="${LOG_DIR}/stop_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
安全告警分析系统停止报告
==============================
停止时间: $(date)
脚本版本: 2.0
操作用户: $(whoami)
工作目录: $(pwd)

停止的服务:
-----------
EOF

    # 检查Docker服务状态
    if command -v docker-compose &> /dev/null; then
        echo "Docker服务状态:" >> "$report_file"
        docker-compose ps >> "$report_file" 2>/dev/null || echo "无法获取Docker服务状态" >> "$report_file"
    fi
    
    # 检查进程状态
    echo -e "\n进程检查:" >> "$report_file"
    local api_processes=$(ps aux | grep "uvicorn.*security" | grep -v grep || echo "无API进程运行")
    echo "API进程: $api_processes" >> "$report_file"
    
    # 检查端口状态
    echo -e "\n端口状态:" >> "$report_file"
    for port in 8000 5601 7474 8123 9200; do
        if lsof -ti:$port > /dev/null 2>&1; then
            echo "端口 $port: 占用" >> "$report_file"
        else
            echo "端口 $port: 空闲" >> "$report_file"
        fi
    done
    
    echo -e "\n日志文件:" >> "$report_file"
    echo "停止日志: $STOP_LOG" >> "$report_file"
    echo "主日志目录: $LOG_DIR" >> "$report_file"
    
    print_status "停止报告已生成: $report_file"
}

display_final_status() {
    print_section "✅ 停止完成"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              系统停止完成                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}✅ 已执行的操作:${NC}"
    echo "   • API服务已停止"
    echo "   • Docker容器已停止"
    echo "   • 相关进程已清理"
    echo "   • 端口已释放"
    echo "   • 配置已备份"
    echo ""
    echo -e "${BLUE}📁 重要文件:${NC}"
    echo "   📋 停止日志: $STOP_LOG"
    echo "   💾 备份目录: ${SCRIPT_DIR}/backup/"
    echo "   📊 日志目录: $LOG_DIR"
    echo ""
    echo -e "${YELLOW}🔄 重新启动:${NC}"
    echo "   ./one_click_start.sh"
    echo ""
    echo -e "${GREEN}🎉 安全告警分析系统已安全停止！${NC}"
}

main() {
    print_banner
    
    log_message "START" "开始停止安全告警分析系统"
    
    # 停止API服务
    stop_api_service
    
    # 停止Docker服务
    stop_docker_services
    
    # 清理相关进程
    cleanup_processes
    
    # 释放端口
    cleanup_ports
    
    # 创建备份
    create_backup
    
    # 生成停止报告
    generate_stop_report
    
    # 显示最终状态
    display_final_status
    
    log_message "COMPLETE" "系统停止完成"
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi