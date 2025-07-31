#!/bin/bash

# 安全告警分析系统 - 管理工具
# Security Alert Analysis System - Management Tool
# Version: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        安全告警分析系统 - 管理工具                           ║"
    echo "║                    Security Alert Analysis System                            ║"
    echo "║                           Management Tool v2.0                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

show_help() {
    print_banner
    echo -e "${WHITE}使用说明:${NC}"
    echo "  $0 [命令] [选项]"
    echo ""
    echo -e "${GREEN}主要命令:${NC}"
    echo "  start           启动整个系统"
    echo "  stop            停止整个系统"
    echo "  restart         重启整个系统"
    echo "  status          检查系统状态"
    echo ""
    echo -e "${BLUE}服务管理:${NC}"
    echo "  start-docker    只启动Docker服务"
    echo "  stop-docker     只停止Docker服务"
    echo "  start-api       只启动API服务"
    echo "  stop-api        只停止API服务"
    echo ""
    echo -e "${YELLOW}状态检查:${NC}"
    echo "  status --brief  简要状态信息"
    echo "  status --json   JSON格式状态"
    echo "  status --api    只检查API状态"
    echo "  status --docker 只检查Docker状态"
    echo ""
    echo -e "${CYAN}日志管理:${NC}"
    echo "  logs            查看所有服务日志"
    echo "  logs [服务名]   查看特定服务日志"
    echo "  logs-api        查看API服务日志"
    echo ""
    echo -e "${PURPLE}系统维护:${NC}"
    echo "  clean           清理系统（停止服务、删除容器）"
    echo "  clean-all       深度清理（包括数据卷）"
    echo "  backup          备份系统配置"
    echo "  update          更新系统镜像"
    echo ""
    echo -e "${WHITE}示例:${NC}"
    echo "  $0 start        # 启动整个系统"
    echo "  $0 status       # 检查系统状态"
    echo "  $0 logs elasticsearch  # 查看Elasticsearch日志"
    echo "  $0 restart      # 重启系统"
    echo ""
}

execute_command() {
    local cmd="$1"
    shift
    
    case "$cmd" in
        "start")
            echo -e "${GREEN}🚀 启动安全告警分析系统...${NC}"
            ./one_click_start.sh
            ;;
        "stop")
            echo -e "${RED}🛑 停止安全告警分析系统...${NC}"
            ./stop_system.sh
            ;;
        "restart")
            echo -e "${YELLOW}🔄 重启安全告警分析系统...${NC}"
            ./stop_system.sh
            sleep 3
            ./one_click_start.sh
            ;;
        "status")
            echo -e "${BLUE}📊 检查系统状态...${NC}"
            ./status_check.sh "$@"
            ;;
        "start-docker")
            echo -e "${GREEN}🐳 启动Docker服务...${NC}"
            docker-compose up -d
            ;;
        "stop-docker")
            echo -e "${RED}🐳 停止Docker服务...${NC}"
            docker-compose down
            ;;
        "start-api")
            echo -e "${GREEN}🌐 启动API服务...${NC}"
            nohup python -m uvicorn src.apis.security_api:app --host 0.0.0.0 --port 8000 --reload > logs/api_service.log 2>&1 &
            echo $! > security_system.pid
            echo "API服务已启动，PID: $(cat security_system.pid)"
            ;;
        "stop-api")
            echo -e "${RED}🌐 停止API服务...${NC}"
            if [ -f "security_system.pid" ]; then
                local pid=$(cat security_system.pid)
                kill -TERM "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
                rm -f security_system.pid
                echo "API服务已停止"
            else
                echo "未找到API服务PID文件"
            fi
            ;;
        "logs")
            if [ -z "$1" ]; then
                echo -e "${CYAN}📋 查看所有服务日志...${NC}"
                docker-compose logs -f
            else
                echo -e "${CYAN}📋 查看 $1 服务日志...${NC}"
                docker-compose logs -f "$1"
            fi
            ;;
        "logs-api")
            echo -e "${CYAN}📋 查看API服务日志...${NC}"
            tail -f logs/api_service.log
            ;;
        "clean")
            echo -e "${YELLOW}🧹 清理系统...${NC}"
            docker-compose down
            docker-compose rm -f
            echo "系统清理完成"
            ;;
        "clean-all")
            echo -e "${RED}🧹 深度清理系统（包括数据）...${NC}"
            read -p "警告：这将删除所有数据！确认继续？(y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                docker-compose down -v
                docker system prune -f
                echo "深度清理完成"
            else
                echo "操作已取消"
            fi
            ;;
        "backup")
            echo -e "${BLUE}💾 备份系统配置...${NC}"
            local backup_dir="backup/manual_backup_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$backup_dir"
            cp -r src config docker-compose.yml requirements.txt "$backup_dir/" 2>/dev/null || true
            echo "备份完成: $backup_dir"
            ;;
        "update")
            echo -e "${BLUE}🔄 更新系统镜像...${NC}"
            docker-compose pull
            echo "镜像更新完成，请重启系统以应用更新"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}❌ 未知命令: $cmd${NC}"
            echo "使用 '$0 help' 查看帮助信息"
            exit 1
            ;;
    esac
}

# 检查是否在正确的目录中
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ 错误: 未在正确的项目目录中运行脚本${NC}"
    echo "请在包含 docker-compose.yml 的目录中运行此脚本"
    exit 1
fi

# 主逻辑
if [ $# -eq 0 ]; then
    show_help
else
    execute_command "$@"
fi