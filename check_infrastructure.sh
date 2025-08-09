#!/bin/bash

# 安全告警分析系统 - 基础设施检查脚本
# Security Alert Analysis System - Infrastructure Check Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

print_header() {
    echo -e "${PURPLE}🔍 $1${NC}"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️  安全告警分析系统 - 基础设施状态检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查Docker
print_header "Docker环境检查"
if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        print_status "Docker运行正常: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    else
        print_error "Docker未运行"
    fi
else
    print_error "Docker未安装"
fi

if command -v docker-compose &> /dev/null; then
    print_status "Docker Compose已安装: $(docker-compose --version | cut -d' ' -f4 | cut -d',' -f1)"
else
    print_error "Docker Compose未安装"
fi

echo ""

# 检查Docker镜像
print_header "Docker镜像检查"
REQUIRED_IMAGES=(
    "confluentinc/cp-zookeeper:7.0.1"
    "confluentinc/cp-kafka:7.0.1"
    "elasticsearch:8.11.1"
    "kibana:8.11.1"
    "neo4j:4.4-community"
    "clickhouse/clickhouse-server:23.8-alpine"
    "redis:6.2-alpine"
    "mysql:8.0"
)

missing_images=0
for image in "${REQUIRED_IMAGES[@]}"; do
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^$image$"; then
        print_status "$image"
    else
        print_warning "$image (缺失)"
        ((missing_images++))
    fi
done

if [ $missing_images -eq 0 ]; then
    print_status "所有核心镜像已准备就绪"
else
    print_warning "$missing_images 个镜像缺失，可运行 ./setup_infrastructure.sh 进行配置"
fi

echo ""

# 检查Python环境
print_header "Python环境检查"
if command -v python3 &> /dev/null; then
    print_status "Python3已安装: $(python3 --version | cut -d' ' -f2)"
else
    print_error "Python3未安装"
fi

if [ -d "venv" ]; then
    if [ -f "venv/bin/python" ]; then
        print_status "主虚拟环境已配置"
    else
        print_warning "主虚拟环境有问题"
    fi
else
    print_warning "主虚拟环境未创建"
fi

if [ -d "demo_venv" ]; then
    if [ -f "demo_venv/bin/python" ]; then
        print_status "演示虚拟环境已配置"
    else
        print_warning "演示虚拟环境有问题"
    fi
else
    print_warning "演示虚拟环境未创建"
fi

echo ""

# 检查配置文件
print_header "配置文件检查"
CONFIG_FILES=(
    "docker-compose.yml"
    "requirements.txt"
    "demo_requirements.txt"
    "start_app.sh"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_status "$file"
    else
        print_error "$file (缺失)"
    fi
done

echo ""

# 检查端口占用
print_header "端口占用检查"
REQUIRED_PORTS=(8000 5601 7474 8123 9200 6379 3306 9092 2181 5115)
occupied_ports=()

for port in "${REQUIRED_PORTS[@]}"; do
    if lsof -ti:$port > /dev/null 2>&1; then
        occupied_ports+=($port)
    fi
done

if [ ${#occupied_ports[@]} -eq 0 ]; then
    print_status "所有必需端口可用"
else
    print_warning "已占用端口: ${occupied_ports[*]}"
    print_info "可运行 ./stop_all.sh 停止现有服务"
fi

echo ""

# 检查运行中的容器
print_header "容器状态检查"
if command -v docker-compose &> /dev/null && [ -f "docker-compose.yml" ]; then
    running_containers=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
    all_containers=$(docker-compose config --services 2>/dev/null | wc -l)
    
    if [ "$running_containers" -gt 0 ]; then
        print_info "运行中的容器: $running_containers/$all_containers"
        docker-compose ps --format table 2>/dev/null || true
    else
        print_info "没有运行中的容器"
    fi
else
    print_warning "无法检查容器状态"
fi

echo ""

# 总结
print_header "检查总结"
if [ -f ".infrastructure_ready" ]; then
    print_status "基础设施已配置完成 ($(cat .infrastructure_ready | grep setup_date | cut -d'=' -f2))"
    print_info "可直接运行 ./start_app.sh 启动系统"
else
    print_warning "基础设施未完全配置"
    print_info "建议运行 ./setup_infrastructure.sh 进行初始配置"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"