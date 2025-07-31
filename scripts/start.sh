#!/bin/bash

# 安全平台启动脚本
set -e

echo "=== 安全告警分析平台启动脚本 ==="

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

# 检查Docker是否安装
check_docker() {
    log_info "检查Docker环境..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
    
    log_success "Docker环境检查通过"
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用情况..."
    ports=(2181 9092 9200 5601 7474 7687 8123 9000 6379 3306 8081 8080)
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_warning "端口 $port 已被占用，可能会导致服务启动失败"
        fi
    done
    
    log_success "端口检查完成"
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."
    
    directories=(
        "logs"
        "data/elasticsearch"
        "data/neo4j"
        "data/clickhouse"
        "data/mysql"
        "data/kafka"
        "data/zookeeper"
        "data/redis"
        "data/flink"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done
    
    log_success "目录创建完成"
}

# 设置环境变量
setup_environment() {
    log_info "设置环境变量..."
    
    if [ ! -f .env ]; then
        cat > .env << 'EOF'
# 安全平台环境变量配置

# 通用配置
COMPOSE_PROJECT_NAME=security-platform
TZ=Asia/Shanghai

# 数据库密码
MYSQL_ROOT_PASSWORD=security123
MYSQL_PASSWORD=security123
NEO4J_PASSWORD=security123
CLICKHOUSE_PASSWORD=security123
REDIS_PASSWORD=security123

# JVM内存设置
ES_JAVA_OPTS=-Xms1g -Xmx1g
FLINK_JM_HEAP=1280m
FLINK_TM_HEAP=1280m

# 网络配置
KAFKA_ADVERTISED_HOST=localhost
ELASTICSEARCH_HOST=localhost
NEO4J_HOST=localhost
CLICKHOUSE_HOST=localhost
REDIS_HOST=localhost
MYSQL_HOST=localhost

# 日志级别
LOG_LEVEL=INFO
EOF
        log_success "环境变量文件创建完成"
    else
        log_info "环境变量文件已存在"
    fi
}

# 启动服务
start_services() {
    log_info "启动基础组件服务..."
    
    # 按顺序启动服务
    log_info "启动存储服务..."
    docker-compose up -d zookeeper mysql redis
    sleep 10
    
    log_info "启动消息队列..."
    docker-compose up -d kafka
    sleep 15
    
    log_info "启动数据库服务..."
    docker-compose up -d elasticsearch neo4j clickhouse
    sleep 20
    
    log_info "启动处理服务..."
    docker-compose up -d flink-jobmanager flink-taskmanager
    sleep 10
    
    log_info "启动Web界面..."
    docker-compose up -d kibana kafka-ui
    sleep 10
    
    log_success "所有服务启动完成"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务就绪..."
    
    services=(
        "elasticsearch:9200"
        "kibana:5601"
        "neo4j:7474"
        "clickhouse:8123"
        "kafka-ui:8080"
        "flink-jobmanager:8081"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r host port <<< "$service"
        log_info "等待 $host:$port 服务就绪..."
        
        max_attempts=30
        attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if curl -s -f "http://localhost:$port" >/dev/null 2>&1; then
                log_success "$host:$port 服务已就绪"
                break
            fi
            
            if [ $attempt -eq $max_attempts ]; then
                log_error "$host:$port 服务启动超时"
                return 1
            fi
            
            sleep 5
            ((attempt++))
        done
    done
    
    log_success "所有服务已就绪"
}

# 显示服务状态
show_status() {
    log_info "服务状态概览:"
    echo
    docker-compose ps
    echo
    
    log_info "Web界面访问地址:"
    echo -e "${GREEN}Kibana (日志分析):${NC} http://localhost:5601"
    echo -e "${GREEN}Neo4j Browser (图数据库):${NC} http://localhost:7474"
    echo -e "${GREEN}Kafka UI (消息队列管理):${NC} http://localhost:8080"
    echo -e "${GREEN}Flink Dashboard (流处理):${NC} http://localhost:8081"
    echo -e "${GREEN}ClickHouse Play (分析数据库):${NC} http://localhost:8123/play"
    echo
    
    log_info "数据库连接信息:"
    echo -e "${YELLOW}MySQL:${NC} localhost:3306 (security/security123)"
    echo -e "${YELLOW}Redis:${NC} localhost:6379 (password: security123)"
    echo -e "${YELLOW}Elasticsearch:${NC} localhost:9200"
    echo -e "${YELLOW}Neo4j:${NC} localhost:7687 (neo4j/security123)"
    echo -e "${YELLOW}ClickHouse:${NC} localhost:8123 (admin/security123)"
    echo
}

# 主函数
main() {
    cd "$(dirname "$0")/.."
    
    log_info "当前目录: $(pwd)"
    
    check_docker
    check_ports
    create_directories
    setup_environment
    start_services
    wait_for_services
    show_status
    
    log_success "安全告警分析平台启动完成！"
    log_info "使用 './scripts/stop.sh' 停止所有服务"
    log_info "使用 './scripts/status.sh' 查看服务状态"
}

# 错误处理
trap 'log_error "脚本执行失败"; exit 1' ERR

main "$@"