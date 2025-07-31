#!/bin/bash

# 安全平台状态检查脚本
set -e

echo "=== 安全告警分析平台状态检查 ==="

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

# 检查服务状态
check_services() {
    log_info "检查Docker容器状态..."
    echo
    
    cd "$(dirname "$0")/.."
    
    if [ -f docker-compose.yml ]; then
        docker-compose ps
    else
        log_error "未找到 docker-compose.yml 文件"
        return 1
    fi
}

# 检查服务健康状态
check_health() {
    log_info "检查服务健康状态..."
    echo
    
    # 定义服务和端口
    declare -A services
    services[Elasticsearch]="localhost:9200"
    services[Kibana]="localhost:5601"
    services[Neo4j]="localhost:7474"
    services[ClickHouse]="localhost:8123"
    services[Kafka-UI]="localhost:8080"
    services[Flink]="localhost:8081"
    services[MySQL]="localhost:3306"
    services[Redis]="localhost:6379"
    
    for service in "${!services[@]}"; do
        endpoint=${services[$service]}
        host=$(echo $endpoint | cut -d: -f1)
        port=$(echo $endpoint | cut -d: -f2)
        
        if nc -z $host $port 2>/dev/null; then
            log_success "$service ($endpoint) - 运行正常"
        else
            log_error "$service ($endpoint) - 无法连接"
        fi
    done
}

# 检查资源使用情况
check_resources() {
    log_info "检查系统资源使用情况..."
    echo
    
    # 检查磁盘空间
    echo "磁盘使用情况:"
    df -h | grep -E "(Filesystem|/dev/)"
    echo
    
    # 检查内存使用
    echo "内存使用情况:"
    free -h
    echo
    
    # 检查Docker资源使用
    if command -v docker &> /dev/null; then
        echo "Docker容器资源使用:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    fi
}

# 检查日志
check_logs() {
    log_info "检查服务日志（最近10行）..."
    echo
    
    cd "$(dirname "$0")/.."
    
    services=("elasticsearch" "kafka" "neo4j" "clickhouse" "flink-jobmanager")
    
    for service in "${services[@]}"; do
        echo -e "${YELLOW}=== $service 日志 ===${NC}"
        docker-compose logs --tail=5 $service 2>/dev/null || log_warning "$service 容器未运行"
        echo
    done
}

# 显示Web界面地址
show_web_interfaces() {
    log_info "Web界面访问地址:"
    echo
    
    interfaces=(
        "Kibana (日志分析):http://localhost:5601"
        "Neo4j Browser (图数据库):http://localhost:7474"
        "Kafka UI (消息队列管理):http://localhost:8080"
        "Flink Dashboard (流处理):http://localhost:8081"
        "ClickHouse Play (分析数据库):http://localhost:8123/play"
    )
    
    for interface in "${interfaces[@]}"; do
        name=$(echo $interface | cut -d: -f1)
        url=$(echo $interface | cut -d: -f2-3)
        
        # 检查服务是否可访问
        port=$(echo $url | grep -oE '[0-9]+' | tail -1)
        if nc -z localhost $port 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $name - $url"
        else
            echo -e "${RED}✗${NC} $name - $url (不可访问)"
        fi
    done
    echo
}

# 检查数据目录
check_data_directories() {
    log_info "检查数据目录..."
    echo
    
    data_dirs=("data/elasticsearch" "data/neo4j" "data/clickhouse" "data/mysql" "data/kafka" "data/redis")
    
    for dir in "${data_dirs[@]}"; do
        if [ -d "$dir" ]; then
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            log_success "$dir - 大小: $size"
        else
            log_warning "$dir - 目录不存在"
        fi
    done
}

# 系统性能测试
performance_test() {
    log_info "执行基础性能测试..."
    echo
    
    # 测试Elasticsearch
    echo "测试 Elasticsearch..."
    if curl -s "http://localhost:9200/_cluster/health" | jq -r '.status' >/dev/null 2>&1; then
        status=$(curl -s "http://localhost:9200/_cluster/health" | jq -r '.status')
        log_success "Elasticsearch 集群状态: $status"
    else
        log_error "Elasticsearch 健康检查失败"
    fi
    
    # 测试MySQL连接
    echo "测试 MySQL 连接..."
    if docker exec security-mysql mysql -u security -psecurity123 -e "SELECT 1" >/dev/null 2>&1; then
        log_success "MySQL 连接正常"
    else
        log_error "MySQL 连接失败"
    fi
    
    # 测试Redis连接
    echo "测试 Redis 连接..."
    if docker exec security-redis redis-cli -a security123 ping >/dev/null 2>&1; then
        log_success "Redis 连接正常"
    else
        log_error "Redis 连接失败"
    fi
}

# 主函数
main() {
    case "$1" in
        --health)
            check_health
            ;;
        --resources)
            check_resources
            ;;
        --logs)
            check_logs
            ;;
        --performance)
            performance_test
            ;;
        --all)
            check_services
            echo
            check_health
            echo
            show_web_interfaces
            check_data_directories
            echo
            check_resources
            ;;
        "")
            check_services
            echo
            check_health
            echo
            show_web_interfaces
            ;;
        *)
            echo "用法: $0 [选项]"
            echo
            echo "选项:"
            echo "  --health       检查服务健康状态"
            echo "  --resources    检查系统资源使用"
            echo "  --logs         查看服务日志"
            echo "  --performance  执行性能测试"
            echo "  --all          执行所有检查"
            echo
            exit 1
            ;;
    esac
}

main "$@"