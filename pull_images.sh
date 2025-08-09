#!/bin/bash

# Docker镜像快速拉取脚本
# Quick Docker Image Pull Script

set -e

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

print_progress() {
    echo -e "${PURPLE}🔄 $1${NC}"
}

echo "🐳 Docker镜像拉取工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 核心镜像列表（使用多个国内镜像源，兼容M2芯片）
CORE_IMAGES=(
    "elasticsearch:8.11.1"
    "kibana:8.11.1"
    "neo4j:4.4-community"
    "redis:6.2-alpine"
    "mysql:8.0"
)

# 可选镜像列表（使用官方镜像，通过加速器拉取）
OPTIONAL_IMAGES=(
    "confluentinc/cp-zookeeper:7.0.1"
    "confluentinc/cp-kafka:7.0.1"
    "clickhouse/clickhouse-server:23.8-alpine"
    "provectuslabs/kafka-ui:latest"
)

# 问题镜像的替代方案（兼容ARM64架构）
ALTERNATIVE_IMAGES=(
    "apache/flink:1.17.0|flink:1.14.0-scala_2.11"
    "wurstmeister/zookeeper:latest|confluentinc/cp-zookeeper:7.0.1"
    "wurstmeister/kafka:latest|confluentinc/cp-kafka:7.0.1"
)

# 问题镜像的替代方案
ALTERNATIVE_IMAGES=(
    "apache/flink:1.17.0|flink:1.14.0-scala_2.11"
    "wurstmeister/zookeeper:latest|confluentinc/cp-zookeeper:7.0.1"
    "wurstmeister/kafka:latest|confluentinc/cp-kafka:7.0.1"
)

pull_image_with_retry() {
    local image="$1"
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if docker pull "$image" > /dev/null 2>&1; then
            return 0
        else
            ((retry++))
            if [ $retry -lt $max_retries ]; then
                print_info "重试拉取 $image ($retry/$max_retries)"
                sleep 2
            fi
        fi
    done
    return 1
}

check_docker_connection() {
    print_info "检查Docker连接..."
    
    # 检查Docker daemon
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker服务未运行"
        return 1
    fi
    
    # 检查网络连接 - 优先检查新配置的国内镜像源
    if curl -s --connect-timeout 3 https://docker.1ms.run/v2/ > /dev/null 2>&1; then
        print_status "1MS镜像源连接正常"
        return 0
    elif curl -s --connect-timeout 3 https://mirror.ccs.tencentyun.com/v2/ > /dev/null 2>&1; then
        print_status "腾讯云镜像源连接正常"
        return 0
    elif curl -s --connect-timeout 3 https://docker.m.daocloud.io/v2/ > /dev/null 2>&1; then
        print_status "DaoCloud镜像源连接正常"
        return 0
    elif curl -s --connect-timeout 5 https://registry-1.docker.io/v2/ > /dev/null 2>&1; then
        print_status "Docker Hub连接正常"
        return 0
    else
        print_warning "网络连接可能不稳定，将尝试使用现有镜像"
        return 1
    fi
}

pull_core_images() {
    print_info "拉取核心镜像..."
    local success=0
    local total=${#CORE_IMAGES[@]}
    
    for image in "${CORE_IMAGES[@]}"; do
        print_progress "拉取 $image..."
        
        # 检查是否已存在
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
            print_status "$image 已存在"
            ((success++))
            continue
        fi
        
        if pull_image_with_retry "$image"; then
            print_status "$image 拉取成功"
            ((success++))
        else
            print_error "$image 拉取失败"
        fi
    done
    
    print_info "核心镜像: $success/$total 成功"
    return $((total - success))
}

pull_optional_images() {
    print_info "拉取可选镜像..."
    local success=0
    local total=${#OPTIONAL_IMAGES[@]}
    
    for image in "${OPTIONAL_IMAGES[@]}"; do
        print_progress "拉取 $image..."
        
        # 检查是否已存在
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
            print_status "$image 已存在"
            ((success++))
            continue
        fi
        
        if pull_image_with_retry "$image"; then
            print_status "$image 拉取成功"
            ((success++))
        else
            print_warning "$image 拉取失败 (可选)"
        fi
    done
    
    print_info "可选镜像: $success/$total 成功"
}

try_alternative_images() {
    print_info "尝试替代镜像..."
    
    for alt_info in "${ALTERNATIVE_IMAGES[@]}"; do
        IFS='|' read -r alt_image orig_image <<< "$alt_info"
        
        # 检查原镜像是否存在
        if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${orig_image}$"; then
            print_progress "尝试替代镜像: $alt_image (替代 $orig_image)"
            
            if pull_image_with_retry "$alt_image"; then
                print_status "替代镜像 $alt_image 拉取成功"
                # 给替代镜像打标签
                docker tag "$alt_image" "$orig_image" > /dev/null 2>&1 || true
            else
                print_warning "替代镜像 $alt_image 也拉取失败"
            fi
        fi
    done
}

show_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "镜像拉取总结"
    echo ""
    
    print_info "已拉取的镜像:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "(elasticsearch|kibana|neo4j|redis|mysql|kafka|zookeeper|clickhouse|flink)" || print_warning "没有找到相关镜像"
    
    echo ""
    print_info "接下来可以运行:"
    echo "  ./setup_infrastructure.sh  # 继续配置"
    echo "  ./start_app.sh            # 直接启动系统"
}

# 主函数
main() {
    if ! check_docker_connection; then
        print_error "Docker环境检查失败"
        exit 1
    fi
    
    echo ""
    
    # 拉取核心镜像
    if ! pull_core_images; then
        print_warning "部分核心镜像拉取失败，尝试替代方案..."
        try_alternative_images
    fi
    
    echo ""
    
    # 拉取可选镜像
    pull_optional_images
    
    echo ""
    
    # 显示总结
    show_summary
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi