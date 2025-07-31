#!/bin/bash

# 安全告警分析系统 - 终极一键启动脚本
# Security Alert Analysis System - Ultimate One-Click Start Script
# Version: 2.0
# 功能: 系统检查、自动修复、服务启动、健康监控、日志管理

set -e
set -o pipefail

# ==============================================================================
# 配置和常量定义
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
BACKUP_DIR="${SCRIPT_DIR}/backup"
PID_FILE="${SCRIPT_DIR}/security_system.pid"

# 创建必要目录
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# 日志文件
MAIN_LOG="${LOG_DIR}/startup_$(date +%Y%m%d_%H%M%S).log"
SYSTEM_LOG="${LOG_DIR}/system.log"
API_LOG="${LOG_DIR}/api_service.log"

# 系统要求配置
MIN_MEMORY_GB=8
MIN_DISK_GB=50
REQUIRED_PORTS=(8000 5601 7474 8123 9200 6379 3306 9092 2181)

# 服务配置
DOCKER_SERVICES=("zookeeper" "kafka" "elasticsearch" "kibana" "neo4j" "clickhouse" "mysql" "redis" "flink-jobmanager" "flink-taskmanager" "kafka-ui")
CRITICAL_SERVICES=("elasticsearch" "neo4j" "mysql" "redis")

# 健康检查URL
HEALTH_URLS=(
    "http://localhost:8000/health|API服务"
    "http://localhost:9200/_cluster/health|Elasticsearch"
    "http://localhost:5601/api/status|Kibana"
    "http://localhost:7474/browser/|Neo4j"
    "http://localhost:8123/ping|ClickHouse"
    "http://localhost:8082|Kafka UI"
)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ==============================================================================
# 工具函数
# ==============================================================================

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$MAIN_LOG"
}

print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        安全告警分析系统 - 一键启动                           ║"
    echo "║                    Security Alert Analysis System                            ║"
    echo "║                           Ultimate Startup v2.0                             ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
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

print_progress() {
    echo -e "${PURPLE}🔄 $1${NC}"
    log_message "PROGRESS" "$1"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

check_prerequisites() {
    print_section "🔍 系统环境检查"
    
    local failed=0
    
    # 检查操作系统
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_status "操作系统: macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_status "操作系统: Linux"
    else
        print_warning "操作系统: $OSTYPE (未完全测试)"
    fi
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请访问 https://docs.docker.com/get-docker/ 安装Docker"
        ((failed++))
    else
        docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        print_status "Docker已安装: $docker_version"
        
        # 检查Docker是否运行
        if ! docker info &> /dev/null; then
            print_error "Docker服务未运行，请启动Docker"
            ((failed++))
        else
            print_status "Docker服务运行正常"
        fi
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose未安装，请安装Docker Compose"
        ((failed++))
    else
        compose_version=$(docker-compose --version | cut -d' ' -f4 | cut -d',' -f1)
        print_status "Docker Compose已安装: $compose_version"
    fi
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python3未安装，请安装Python3"
        ((failed++))
    else
        python_version=$(python3 --version | cut -d' ' -f2)
        print_status "Python3已安装: $python_version"
        
        # 检查pip
        if ! command -v pip &> /dev/null && ! command -v pip3 &> /dev/null; then
            print_warning "pip未安装，尝试安装..."
            python3 -m ensurepip --default-pip 2>/dev/null || print_error "pip安装失败"
        else
            print_status "pip已安装"
        fi
    fi
    
    # 检查必要的命令行工具
    local tools=("curl" "jq" "lsof" "ps")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_warning "$tool 未安装，部分功能可能受限"
        else
            print_status "$tool 已安装"
        fi
    done
    
    return $failed
}

check_system_resources() {
    print_section "📊 系统资源检查"
    
    # 检查内存
    if command -v python3 &> /dev/null; then
        total_memory=$(python3 -c "
import psutil
print(int(psutil.virtual_memory().total / 1024 / 1024 / 1024))
        " 2>/dev/null || echo "0")
        
        if [ "$total_memory" -lt $MIN_MEMORY_GB ]; then
            print_warning "系统内存: ${total_memory}GB (建议至少${MIN_MEMORY_GB}GB)"
        else
            print_status "系统内存: ${total_memory}GB"
        fi
        
        # 检查可用内存
        available_memory=$(python3 -c "
import psutil
print(int(psutil.virtual_memory().available / 1024 / 1024 / 1024))
        " 2>/dev/null || echo "0")
        
        if [ "$available_memory" -lt 4 ]; then
            print_warning "可用内存: ${available_memory}GB (建议至少4GB)"
        else
            print_status "可用内存: ${available_memory}GB"
        fi
    fi
    
    # 检查磁盘空间
    if [[ "$OSTYPE" == "darwin"* ]]; then
        available_disk=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G.*//')
    else
        available_disk=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G.*//')
    fi
    
    if [ "$available_disk" -lt $MIN_DISK_GB ]; then
        print_warning "可用磁盘空间: ${available_disk}GB (建议至少${MIN_DISK_GB}GB)"
    else
        print_status "可用磁盘空间: ${available_disk}GB"
    fi
    
    # 检查端口占用
    local occupied_ports=()
    for port in "${REQUIRED_PORTS[@]}"; do
        if lsof -ti:$port > /dev/null 2>&1; then
            occupied_ports+=($port)
        fi
    done
    
    if [ ${#occupied_ports[@]} -gt 0 ]; then
        print_warning "已占用端口: ${occupied_ports[*]}"
        print_info "将尝试停止冲突进程..."
        
        for port in "${occupied_ports[@]}"; do
            local pid=$(lsof -ti:$port)
            if [ -n "$pid" ]; then
                print_info "停止端口 $port 上的进程 (PID: $pid)"
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
        sleep 2
    else
        print_status "所有必需端口可用"
    fi
}

setup_environment() {
    print_section "🔧 环境配置"
    
    # 设置环境变量
    export PYTHONPATH="${PYTHONPATH}:${SCRIPT_DIR}"
    export COMPOSE_PROJECT_NAME="security-analysis"
    
    # 检查是否在虚拟环境中
    if [[ "$VIRTUAL_ENV" == "" ]]; then
        print_warning "未在虚拟环境中运行"
        print_info "建议创建虚拟环境: python3 -m venv venv && source venv/bin/activate"
        
        # 询问是否自动创建虚拟环境
        if [ -t 0 ]; then  # 检查是否为交互式终端
            read -p "是否自动创建并激活虚拟环境? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if [ ! -d "venv" ]; then
                    print_info "创建虚拟环境..."
                    python3 -m venv venv
                fi
                print_info "激活虚拟环境..."
                source venv/bin/activate
                export VIRTUAL_ENV="$(pwd)/venv"
                print_status "虚拟环境已激活: $VIRTUAL_ENV"
            fi
        fi
    else
        print_status "运行在虚拟环境: $VIRTUAL_ENV"
    fi
    
    # 安装Python依赖
    if [ -f "requirements.txt" ]; then
        print_info "安装Python依赖..."
        pip install -r requirements.txt > "${LOG_DIR}/pip_install.log" 2>&1 &
        local pip_pid=$!
        spinner $pip_pid
        wait $pip_pid
        
        if [ $? -eq 0 ]; then
            print_status "Python依赖安装完成"
        else
            print_error "Python依赖安装失败，查看 ${LOG_DIR}/pip_install.log"
            return 1
        fi
    else
        print_warning "未找到 requirements.txt 文件"
    fi
    
    # 创建必要的目录
    local dirs=("data" "logs" "backup" "config")
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_info "创建目录: $dir"
        fi
    done
    
    print_status "环境配置完成"
}

start_infrastructure() {
    print_section "🏗️  启动基础设施服务"
    
    # 检查docker-compose.yml是否存在
    if [ ! -f "docker-compose.yml" ]; then
        print_error "未找到 docker-compose.yml 文件"
        return 1
    fi
    
    # 拉取最新镜像
    print_info "拉取Docker镜像..."
    docker-compose pull > "${LOG_DIR}/docker_pull.log" 2>&1 &
    local pull_pid=$!
    spinner $pull_pid
    wait $pull_pid
    
    # 启动基础设施服务
    print_info "启动Docker Compose服务..."
    docker-compose up -d > "${LOG_DIR}/docker_up.log" 2>&1
    
    if [ $? -eq 0 ]; then
        print_status "Docker服务启动命令执行成功"
    else
        print_error "Docker服务启动失败，查看 ${LOG_DIR}/docker_up.log"
        return 1
    fi
    
    # 等待服务启动
    print_info "等待服务启动完成..."
    local max_wait=120
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        local healthy_services=0
        for service in "${DOCKER_SERVICES[@]}"; do
            if docker-compose ps | grep -q "$service.*Up"; then
                ((healthy_services++))
            fi
        done
        
        echo -ne "\r正在启动服务... ($healthy_services/${#DOCKER_SERVICES[@]}) [${waited}s/${max_wait}s]"
        
        if [ $healthy_services -eq ${#DOCKER_SERVICES[@]} ]; then
            echo ""
            break
        fi
        
        sleep 5
        ((waited+=5))
    done
    
    echo ""
    
    # 检查各服务状态
    print_info "检查服务状态..."
    local failed_services=()
    
    for service in "${DOCKER_SERVICES[@]}"; do
        if docker-compose ps | grep -q "$service.*Up"; then
            print_status "$service 服务运行正常"
        else
            print_error "$service 服务启动失败"
            failed_services+=("$service")
        fi
    done
    
    # 检查关键服务
    local critical_failed=()
    for service in "${CRITICAL_SERVICES[@]}"; do
        if [[ " ${failed_services[@]} " =~ " ${service} " ]]; then
            critical_failed+=("$service")
        fi
    done
    
    if [ ${#critical_failed[@]} -gt 0 ]; then
        print_error "关键服务启动失败: ${critical_failed[*]}"
        print_info "尝试重启失败的关键服务..."
        
        for service in "${critical_failed[@]}"; do
            print_info "重启 $service..."
            docker-compose restart "$service"
            sleep 10
        done
    fi
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        print_warning "部分服务启动失败: ${failed_services[*]}"
        print_info "系统将继续启动，但功能可能受限"
    else
        print_status "所有基础设施服务启动成功"
    fi
}

configure_services() {
    print_section "⚙️  配置服务"
    
    # 等待服务完全就绪
    print_info "等待服务就绪..."
    sleep 15
    
    # 配置脚本列表
    local setup_scripts=(
        "setup_elasticsearch.sh|Elasticsearch"
        "setup_neo4j.sh|Neo4j"
        "setup_clickhouse.sh|ClickHouse"
        "setup_kafka.sh|Kafka"
        "setup_kibana.sh|Kibana"
    )
    
    for script_info in "${setup_scripts[@]}"; do
        IFS='|' read -r script_name service_name <<< "$script_info"
        local script_path="./scripts/$script_name"
        
        if [ -f "$script_path" ]; then
            print_info "配置 $service_name..."
            if bash "$script_path" > "${LOG_DIR}/setup_${service_name,,}.log" 2>&1; then
                print_status "$service_name 配置完成"
            else
                print_warning "$service_name 配置失败，查看 ${LOG_DIR}/setup_${service_name,,}.log"
            fi
        else
            print_warning "配置脚本不存在: $script_path"
        fi
    done
    
    print_status "服务配置完成"
}

perform_health_checks() {
    print_section "🔍 健康检查"
    
    local failed_checks=()
    
    # 检查Docker服务健康状态
    print_info "检查Docker服务健康状态..."
    for service in "${DOCKER_SERVICES[@]}"; do
        local health_status=$(docker-compose ps "$service" 2>/dev/null | tail -n 1 | awk '{print $4}')
        if [[ "$health_status" == "Up" ]] || [[ "$health_status" =~ "Up" ]]; then
            print_status "$service: 健康"
        else
            print_warning "$service: 不健康 ($health_status)"
            failed_checks+=("$service")
        fi
    done
    
    # HTTP健康检查
    print_info "执行HTTP健康检查..."
    for url_info in "${HEALTH_URLS[@]}"; do
        IFS='|' read -r url service_name <<< "$url_info"
        
        local max_retries=3
        local retry=0
        local success=false
        
        while [ $retry -lt $max_retries ]; do
            if curl -s --connect-timeout 10 "$url" > /dev/null; then
                print_status "$service_name: HTTP检查通过"
                success=true
                break
            else
                ((retry++))
                if [ $retry -lt $max_retries ]; then
                    print_info "$service_name: 重试HTTP检查 ($retry/$max_retries)"
                    sleep 5
                fi
            fi
        done
        
        if [ "$success" = false ]; then
            print_warning "$service_name: HTTP检查失败"
            failed_checks+=("$service_name")
        fi
    done
    
    # 数据库连接测试
    print_info "测试数据库连接..."
    
    # 测试MySQL连接
    if docker exec security-mysql mysql -u security -psecurity123 -e "SELECT 1;" > /dev/null 2>&1; then
        print_status "MySQL: 连接正常"
    else
        print_warning "MySQL: 连接失败"
        failed_checks+=("MySQL")
    fi
    
    # 测试Redis连接
    if docker exec security-redis redis-cli -a security123 ping > /dev/null 2>&1; then
        print_status "Redis: 连接正常"
    else
        print_warning "Redis: 连接失败"
        failed_checks+=("Redis")
    fi
    
    if [ ${#failed_checks[@]} -eq 0 ]; then
        print_status "所有健康检查通过"
        return 0
    else
        print_warning "部分健康检查失败: ${failed_checks[*]}"
        return 1
    fi
}

start_api_service() {
    print_section "🌐 启动API服务"
    
    # 检查API文件是否存在
    if [ ! -f "src/apis/security_api.py" ]; then
        print_error "未找到API服务文件: src/apis/security_api.py"
        return 1
    fi
    
    # 运行系统验证测试
    if [ -f "test_system.py" ]; then
        print_info "运行系统验证测试..."
        if python test_system.py > "${LOG_DIR}/system_test.log" 2>&1; then
            print_status "系统验证测试通过"
        else
            print_warning "系统验证测试失败，查看 ${LOG_DIR}/system_test.log"
        fi
    fi
    
    # 启动API服务
    print_info "启动FastAPI服务..."
    nohup python -m uvicorn src.apis.security_api:app --host 0.0.0.0 --port 8000 --reload > "$API_LOG" 2>&1 &
    local api_pid=$!
    echo $api_pid > "$PID_FILE"
    
    print_info "等待API服务启动..."
    local max_wait=30
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        if curl -s http://localhost:8000/health > /dev/null 2>&1; then
            print_status "API服务启动成功 (PID: $api_pid)"
            return 0
        fi
        sleep 2
        ((waited+=2))
        echo -ne "\r等待API服务启动... [${waited}s/${max_wait}s]"
    done
    
    echo ""
    print_error "API服务启动失败或超时"
    return 1
}

create_monitoring_dashboard() {
    print_section "📊 创建监控面板"
    
    local dashboard_file="${SCRIPT_DIR}/monitoring_dashboard.html"
    
    cat > "$dashboard_file" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>安全分析系统 - 监控面板</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .service-card { background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .service-title { font-size: 18px; font-weight: bold; margin-bottom: 10px; color: #2c3e50; }
        .service-url { display: block; color: #3498db; text-decoration: none; margin: 5px 0; }
        .service-url:hover { text-decoration: underline; }
        .status { padding: 5px 10px; border-radius: 15px; font-size: 12px; font-weight: bold; }
        .status.online { background: #2ecc71; color: white; }
        .status.offline { background: #e74c3c; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🛡️ 安全告警分析系统 - 监控面板</h1>
        <p>系统启动时间: <span id="startTime"></span></p>
    </div>
    
    <div class="services">
        <div class="service-card">
            <div class="service-title">🎯 核心服务</div>
            <a href="http://localhost:8000" class="service-url" target="_blank">API服务</a>
            <a href="http://localhost:8000/docs" class="service-url" target="_blank">API文档</a>
            <a href="http://localhost:8000/health" class="service-url" target="_blank">健康检查</a>
        </div>
        
        <div class="service-card">
            <div class="service-title">📊 数据分析</div>
            <a href="http://localhost:5601" class="service-url" target="_blank">Kibana</a>
            <a href="http://localhost:7474" class="service-url" target="_blank">Neo4j浏览器</a>
            <a href="http://localhost:8123/play" class="service-url" target="_blank">ClickHouse Play</a>
        </div>
        
        <div class="service-card">
            <div class="service-title">🔧 管理工具</div>
            <a href="http://localhost:8082" class="service-url" target="_blank">Kafka UI</a>
            <a href="http://localhost:9200" class="service-url" target="_blank">Elasticsearch</a>
        </div>
        
        <div class="service-card">
            <div class="service-title">📝 系统信息</div>
            <p>项目目录: <code id="projectPath"></code></p>
            <p>日志目录: <code id="logPath"></code></p>
            <p>备份目录: <code id="backupPath"></code></p>
        </div>
    </div>
    
    <script>
        document.getElementById('startTime').textContent = new Date().toLocaleString();
        document.getElementById('projectPath').textContent = window.location.pathname;
        document.getElementById('logPath').textContent = './logs/';
        document.getElementById('backupPath').textContent = './backup/';
        
        // 定期检查服务状态
        setInterval(function() {
            // 这里可以添加AJAX请求来检查服务状态
        }, 30000);
    </script>
</body>
</html>
EOF

    print_status "监控面板创建完成: $dashboard_file"
}

display_system_info() {
    print_section "🎉 系统启动完成"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              系统访问信息                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}🎯 核心服务${NC}"
    echo "   📡 API服务: http://localhost:8000"
    echo "   📚 API文档: http://localhost:8000/docs"
    echo "   💓 健康检查: http://localhost:8000/health"
    echo ""
    echo -e "${BLUE}📊 数据分析${NC}"
    echo "   🔍 Kibana: http://localhost:5601"
    echo "   🕸️  Neo4j浏览器: http://localhost:7474 (neo4j/security123)"
    echo "   📈 ClickHouse Play: http://localhost:8123/play (admin/security123)"
    echo ""
    echo -e "${YELLOW}🔧 管理工具${NC}"
    echo "   🚀 Kafka UI: http://localhost:8082"
    echo "   🔎 Elasticsearch: http://localhost:9200"
    echo "   📊 监控面板: file://${SCRIPT_DIR}/monitoring_dashboard.html"
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              快速测试命令                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}📝 测试API接口${NC}"
    echo 'curl -X POST "http://localhost:8000/api/v1/analyze/event" \'
    echo '  -H "Content-Type: application/json" \'
    echo '  -d '"'"'{'
    echo '    "event_type": "security_test",'
    echo '    "log_data": {'
    echo '      "src_ip": "192.168.1.100",'
    echo '      "username": "test_user",'
    echo "      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\""
    echo '    }'
    echo '  }'"'"
    echo ""
    echo -e "${BLUE}🧪 运行验证测试${NC}"
    echo "./run_verification.sh"
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              系统管理命令                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}停止系统:${NC} docker-compose down && ./stop_system.sh"
    echo -e "${GREEN}查看日志:${NC} docker-compose logs -f [服务名]"
    echo -e "${GREEN}重启服务:${NC} docker-compose restart [服务名]"
    echo -e "${GREEN}系统状态:${NC} ./status_check.sh"
    echo ""
    if [ -f "$PID_FILE" ]; then
        local api_pid=$(cat "$PID_FILE")
        echo -e "${YELLOW}API服务PID:${NC} $api_pid"
        echo -e "${YELLOW}停止API:${NC} kill $api_pid"
    fi
    echo ""
    echo -e "${CYAN}📁 重要文件位置:${NC}"
    echo "   📋 主日志: $MAIN_LOG"
    echo "   🚀 API日志: $API_LOG"
    echo "   📊 系统日志: $SYSTEM_LOG"
    echo "   💾 PID文件: $PID_FILE"
    echo ""
    echo -e "${GREEN}✨ 安全告警分析系统启动完成，开始您的安全分析之旅！${NC}"
}

cleanup_on_exit() {
    print_info "清理临时文件..."
    # 这里可以添加清理逻辑
}

main() {
    # 设置退出时的清理函数
    trap cleanup_on_exit EXIT
    
    # 显示启动横幅
    print_banner
    
    # 检查系统先决条件
    if ! check_prerequisites; then
        print_error "系统先决条件检查失败，请解决问题后重试"
        exit 1
    fi
    
    # 检查系统资源
    check_system_resources
    
    # 设置环境
    if ! setup_environment; then
        print_error "环境配置失败"
        exit 1
    fi
    
    # 启动基础设施
    if ! start_infrastructure; then
        print_error "基础设施启动失败"
        exit 1
    fi
    
    # 配置服务
    configure_services
    
    # 执行健康检查
    perform_health_checks
    
    # 启动API服务
    if ! start_api_service; then
        print_error "API服务启动失败"
        exit 1
    fi
    
    # 创建监控面板
    create_monitoring_dashboard
    
    # 显示系统信息
    display_system_info
    
    log_message "SUCCESS" "系统启动完成"
}

# 检查是否以正确的方式运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi