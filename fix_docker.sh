#!/bin/bash

# Docker问题修复脚本
# Fix Docker Issues Script

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "🔧 Docker问题诊断和修复"
echo "=========================="
echo ""

print_info "1. 停止所有Docker相关进程..."
pkill -f "docker" || true
sleep 3

print_info "2. 重启Docker Desktop..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - 重启Docker Desktop
    killall "Docker Desktop" 2>/dev/null || true
    sleep 5
    open -a "Docker Desktop"
    print_status "Docker Desktop重启命令已发送"
else
    # Linux - 重启Docker服务
    sudo systemctl restart docker
    print_status "Docker服务已重启"
fi

print_info "3. 等待Docker服务启动..."
max_wait=60
waited=0

while [ $waited -lt $max_wait ]; do
    if timeout 10 docker info > /dev/null 2>&1; then
        print_status "Docker服务已就绪"
        break
    else
        echo -ne "\r等待Docker启动... [${waited}s/${max_wait}s]"
        sleep 5
        ((waited+=5))
    fi
done

echo ""

if [ $waited -ge $max_wait ]; then
    print_error "Docker服务启动超时"
    echo ""
    echo "手动修复步骤："
    echo "1. 打开Docker Desktop应用"
    echo "2. 等待Docker完全启动（右上角图标不再转动）"
    echo "3. 重新运行 ./start_all.sh"
    exit 1
fi

print_info "4. 清理Docker系统..."
docker system prune -f > /dev/null 2>&1 || print_warning "Docker清理跳过"

print_info "5. 测试Docker功能..."
if docker run --rm hello-world > /dev/null 2>&1; then
    print_status "Docker功能测试通过"
else
    print_warning "Docker功能测试失败，但可以继续尝试启动系统"
fi

echo ""
print_status "Docker修复完成！现在可以重新运行启动脚本"
echo ""
echo "建议的启动命令："
echo "./start_all.sh"