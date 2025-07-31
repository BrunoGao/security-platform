#!/bin/bash

# 安全平台停止脚本
set -e

echo "=== 安全告警分析平台停止脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 停止服务
stop_services() {
    log_info "停止安全平台服务..."
    
    cd "$(dirname "$0")/.."
    
    if [ -f docker-compose.yml ]; then
        docker-compose down
        log_success "服务停止完成"
    else
        log_error "未找到 docker-compose.yml 文件"
        exit 1
    fi
}

# 清理资源
cleanup_resources() {
    if [ "$1" = "--clean-data" ]; then
        log_warning "清理所有数据..."
        
        read -p "确定要删除所有数据吗？(y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "删除数据卷..."
            docker-compose down -v
            
            log_info "删除本地数据目录..."
            if [ -d "data" ]; then
                rm -rf data/*
                log_success "数据清理完成"
            fi
        else
            log_info "取消数据清理"
        fi
    fi
}

# 清理容器和镜像
cleanup_containers() {
    if [ "$1" = "--clean-all" ]; then
        log_warning "清理容器和镜像..."
        
        read -p "确定要删除所有相关容器和镜像吗？(y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "删除相关容器..."
            docker ps -a --filter "name=security-" -q | xargs -r docker rm -f
            
            log_info "删除相关镜像..."
            docker images --filter "reference=*security*" -q | xargs -r docker rmi -f
            
            log_success "容器和镜像清理完成"
        else
            log_info "取消容器和镜像清理"
        fi
    fi
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  --clean-data    停止服务并删除所有数据"
    echo "  --clean-all     停止服务并删除容器、镜像和数据"
    echo "  -h, --help      显示帮助信息"
    echo
}

# 主函数
main() {
    case "$1" in
        --clean-data)
            stop_services
            cleanup_resources --clean-data
            ;;
        --clean-all)
            stop_services
            cleanup_resources --clean-data
            cleanup_containers --clean-all
            ;;
        -h|--help)
            show_help
            ;;
        "")
            stop_services
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
    
    log_success "安全告警分析平台已停止"
}

main "$@"