#!/bin/bash

# 安全告警分析系统 - 一键全量启动脚本
# Security Alert Analysis System - One-Click Full Startup Script
# Version: 5.0
# 功能: 直接启动完整系统，包含所有服务和演示功能
# Features: Direct full system startup with all services and demo features

set -e
set -o pipefail

# ==============================================================================
# 配置和常量定义
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
BACKUP_DIR="${SCRIPT_DIR}/backup"
PID_FILE="${SCRIPT_DIR}/security_system.pid"
DEMO_SYSTEM_PID="${SCRIPT_DIR}/demo_system.pid"
DEMO_WEB_PID="${SCRIPT_DIR}/demo_web.pid"

# 创建必要目录
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# 日志文件
MAIN_LOG="${LOG_DIR}/unified_startup_$(date +%Y%m%d_%H%M%S).log"
SYSTEM_LOG="${LOG_DIR}/system.log"
API_LOG="${LOG_DIR}/api_service.log"
DEMO_SYSTEM_LOG="${LOG_DIR}/demo_system.log"
DEMO_WEB_LOG="${LOG_DIR}/demo_web.log"

# 系统要求配置
MIN_MEMORY_GB=8
MIN_DISK_GB=50
REQUIRED_PORTS=(8000 5601 7474 8123 9200 6379 3306 9092 2181 5115)

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
    "http://localhost:5115|Web演示界面"
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
    echo "║                   🛡️  安全告警分析系统 - 一键全量启动 🛡️                     ║"
    echo "║                Security Alert Analysis System - One-Click Start             ║"
    echo "║               包含完整系统+Web演示+客户演示+监控的一站式启动                   ║"
    echo "║                                 v5.0                                        ║"
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


# ==============================================================================
# 系统检查功能
# ==============================================================================

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
    
    # 检查必要文件
    local required_files=(
        "docker-compose.yml"
        "src/apis/security_api.py"
        "requirements.txt"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            print_status "文件检查: $file 存在"
        else
            print_warning "文件检查: $file 缺失"
            ((failed++))
        fi
    done
    
    return $failed
}

check_system_resources() {
    print_section "📊 系统资源检查"
    
    # 检查内存 - 使用更通用的方法
    if command -v python3 &> /dev/null; then
        # 尝试使用psutil
        total_memory=$(python3 -c "
try:
    import psutil
    print(int(psutil.virtual_memory().total / 1024 / 1024 / 1024))
except ImportError:
    print('psutil_not_available')
except Exception:
    print('0')
        " 2>/dev/null)
        
        if [ "$total_memory" = "psutil_not_available" ]; then
            # 如果psutil不可用，尝试系统命令
            if [[ "$OSTYPE" == "darwin"* ]]; then
                total_memory=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
            else
                total_memory=$(free -g | awk 'NR==2{print $2}')
            fi
        fi
        
        if [ "$total_memory" -gt 0 ] 2>/dev/null; then
            if [ "$total_memory" -lt $MIN_MEMORY_GB ]; then
                print_warning "系统内存: ${total_memory}GB (建议至少${MIN_MEMORY_GB}GB)"
            else
                print_status "系统内存: ${total_memory}GB"
            fi
        else
            print_warning "无法检测系统内存"
        fi
        
        # 检查可用内存
        available_memory=$(python3 -c "
try:
    import psutil
    print(int(psutil.virtual_memory().available / 1024 / 1024 / 1024))
except ImportError:
    print('psutil_not_available')
except Exception:
    print('0')
        " 2>/dev/null)
        
        if [ "$available_memory" = "psutil_not_available" ]; then
            # 如果psutil不可用，尝试系统命令
            if [[ "$OSTYPE" == "darwin"* ]]; then
                available_memory=$(vm_stat | grep "Pages free" | awk '{print int($3 * 4096 / 1024 / 1024 / 1024)}')
            else
                available_memory=$(free -g | awk 'NR==2{print $7}')
            fi
        fi
        
        if [ "$available_memory" -gt 0 ] 2>/dev/null; then
            if [ "$available_memory" -lt 4 ]; then
                print_warning "可用内存: ${available_memory}GB (建议至少4GB)"
            else
                print_status "可用内存: ${available_memory}GB"
            fi
        else
            print_warning "无法检测可用内存"
        fi
    else
        print_warning "Python3不可用，跳过内存检查"
    fi
    
    # 检查磁盘空间 - 使用简单的sed和awk处理
    available_disk_raw=$(df -h . | awk 'NR==2 {print $4}')
    
    # 提取数字部分 (去掉单位)
    number_part=$(echo "$available_disk_raw" | sed 's/[^0-9.]//g')
    # 提取单位部分
    unit_part=$(echo "$available_disk_raw" | sed 's/[0-9.]//g')
    
    if [ -n "$number_part" ]; then
        # 转换为整数 (小数向上取整)
        if [[ "$number_part" == *"."* ]]; then
            integer_part=$(echo "$number_part" | cut -d'.' -f1)
            decimal_part=$(echo "$number_part" | cut -d'.' -f2 | head -c 1)
            if [ "$decimal_part" -gt 0 ] 2>/dev/null; then
                number=$((integer_part + 1))
            else
                number="$integer_part"
            fi
        else
            number="$number_part"
        fi
        
        # 根据单位转换为GB
        case "$unit_part" in
            *[Tt]*)
                # TB转GB
                available_disk=$((number * 1000))
                ;;
            *[Gg]*|"")
                # GB
                available_disk="$number"
                ;;
            *[Mm]*)
                # MB，按1GB计算
                available_disk=1
                ;;
            *)
                # 其他情况假设足够
                available_disk=100
                ;;
        esac
        
        if [ "$available_disk" -ge $MIN_DISK_GB ] 2>/dev/null; then
            print_status "可用磁盘空间: ${available_disk}GB"
        elif [ "$available_disk" -gt 0 ] 2>/dev/null; then
            print_warning "可用磁盘空间: ${available_disk}GB (建议至少${MIN_DISK_GB}GB)"
        else
            print_status "可用磁盘空间: ${available_disk_raw}"
        fi
    else
        # 如果无法解析数字，直接显示原始值
        print_status "可用磁盘空间: ${available_disk_raw}"
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
        print_info "检查端口占用进程..."
        
        local safe_to_kill_ports=()
        local system_ports=()
        
        for port in "${occupied_ports[@]}"; do
            local pids=$(lsof -ti:$port)
            if [ -n "$pids" ]; then
                local is_system_port=false
                
                # 检查每个PID
                for pid in $pids; do
                    local process_name=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
                    
                    # 检查是否为系统关键进程（OrbStack、Docker等）
                    if [[ "$process_name" =~ (OrbStack|Docker|dockerd|containerd|nexus) ]] || [[ "$pid" -eq "$PPID" ]]; then
                        is_system_port=true
                        print_info "端口 $port 被系统进程占用 ($process_name PID:$pid)，保持运行"
                        break
                    fi
                done
                
                if [ "$is_system_port" = true ]; then
                    system_ports+=($port)
                else
                    safe_to_kill_ports+=($port)
                    print_info "端口 $port 被用户进程占用，可以终止"
                fi
            fi
        done
        
        # 只终止安全的进程
        for port in "${safe_to_kill_ports[@]}"; do
            local pids=$(lsof -ti:$port)
            if [ -n "$pids" ]; then
                for pid in $pids; do
                    local process_name=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
                    # 再次确认不是系统进程
                    if [[ ! "$process_name" =~ (OrbStack|Docker|dockerd|containerd|nexus) ]]; then
                        print_info "停止端口 $port 上的进程 $process_name (PID: $pid)"
                        kill -TERM "$pid" 2>/dev/null || true
                        sleep 1
                        # 如果进程仍在运行，再尝试强制终止
                        if kill -0 "$pid" 2>/dev/null; then
                            kill -9 "$pid" 2>/dev/null || true
                        fi
                    fi
                done
            fi
        done
        
        if [ ${#system_ports[@]} -gt 0 ]; then
            print_warning "系统端口 ${system_ports[*]} 被占用，将使用不同端口启动服务"
        fi
        
        sleep 2
    else
        print_status "所有必需端口可用"
    fi
}

# ==============================================================================
# 环境配置功能
# ==============================================================================

setup_environment() {
    print_section "🔧 环境配置"
    
    # 设置环境变量
    export PYTHONPATH="${PYTHONPATH}:${SCRIPT_DIR}"
    export COMPOSE_PROJECT_NAME="security-analysis"
    
    # 检查是否在虚拟环境中
    if [[ "$VIRTUAL_ENV" == "" ]]; then
        print_warning "未在虚拟环境中运行"
        
        # 自动创建和激活虚拟环境
        if [ ! -d "venv" ]; then
            print_info "创建虚拟环境..."
            python3 -m venv venv
            if [ $? -ne 0 ]; then
                print_error "虚拟环境创建失败"
                return 1
            fi
        fi
        
        print_info "激活虚拟环境..."
        
        # 手动设置虚拟环境变量和PATH
        export VIRTUAL_ENV="$(pwd)/venv"
        export PATH="$VIRTUAL_ENV/bin:$PATH"
        
        # 验证虚拟环境激活成功
        if [ -f "$VIRTUAL_ENV/bin/python" ]; then
            print_status "虚拟环境已激活: $VIRTUAL_ENV"
        else
            print_error "虚拟环境激活失败"
            return 1
        fi
    else
        print_status "运行在虚拟环境: $VIRTUAL_ENV"
    fi
    
    # 安装Python依赖 - 使用更可靠的方式
    if [ -f "requirements.txt" ]; then
        print_info "安装Python依赖..."
        
        # 选择正确的pip命令 - 优先使用虚拟环境中的pip
        if [[ "$VIRTUAL_ENV" != "" ]] && [ -f "$VIRTUAL_ENV/bin/pip" ]; then
            pip_cmd="$VIRTUAL_ENV/bin/pip"
            print_info "使用虚拟环境pip: $pip_cmd"
        elif command -v pip3 &> /dev/null; then
            pip_cmd="pip3"
            print_info "使用系统pip3: $pip_cmd"
        elif command -v pip &> /dev/null; then
            pip_cmd="pip"
            print_info "使用系统pip: $pip_cmd"
        else
            print_error "未找到pip命令"
            return 1
        fi
        
        # 安装依赖
        $pip_cmd install -r requirements.txt > "${LOG_DIR}/pip_install.log" 2>&1 &
        local pip_pid=$!
        spinner $pip_pid
        wait $pip_pid
        
        if [ $? -eq 0 ]; then
            print_status "Python依赖安装完成"
        else
            print_error "Python依赖安装失败，查看 ${LOG_DIR}/pip_install.log"
            print_info "错误详情:"
            tail -n 5 "${LOG_DIR}/pip_install.log" 2>/dev/null || true
            return 1
        fi
    else
        print_warning "未找到 requirements.txt 文件"
    fi
    
    # 设置演示环境依赖
    setup_demo_environment
    
    print_status "环境配置完成"
}

setup_demo_environment() {
    print_info "设置演示环境..."
    
    # 创建演示虚拟环境
    if [ ! -d "demo_venv" ]; then
        print_info "创建演示虚拟环境..."
        python3 -m venv demo_venv
    fi
    
    # 安装演示依赖
    if [ -f "demo_requirements.txt" ]; then
        demo_venv/bin/pip install -r demo_requirements.txt > /dev/null 2>&1
    else
        demo_venv/bin/pip install Flask Flask-CORS Flask-SocketIO psutil requests eventlet > /dev/null 2>&1
    fi
    
    print_status "演示环境已准备"
}

# ==============================================================================
# 基础设施启动功能
# ==============================================================================

start_infrastructure() {
    print_section "🏗️  启动基础设施服务"
    
    # 检查docker-compose.yml是否存在
    if [ ! -f "docker-compose.yml" ]; then
        print_error "未找到 docker-compose.yml 文件"
        return 1
    fi
    
    # 检查Docker服务状态和现有容器
    print_info "检查Docker服务状态..."
    
    # 检查是否有正在运行的容器
    local running_containers=$(docker-compose --project-name security-analysis ps --services --filter "status=running" 2>/dev/null | wc -l | tr -d ' ')
    local total_services=$(docker-compose --project-name security-analysis config --services 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$running_containers" -gt 0 ] && [ "$total_services" -gt 0 ]; then
        print_status "检测到 $running_containers/$total_services 个服务正在运行"
        if [ "$running_containers" -eq "$total_services" ]; then
            print_status "所有服务已经在运行，跳过启动步骤"  
            log_message "INFO" "所有服务已经在运行"
            return 0
        else
            print_info "部分服务正在运行，将补充启动缺失的服务"
        fi
    else
        print_info "没有检测到运行中的服务，将启动所有服务"
    fi
    
    # 检查镜像（仅在需要启动服务时）
    print_info "检查Docker镜像..."
    
    local required_images=(
        "elasticsearch:8.11.1"
        "kibana:8.11.1" 
        "neo4j:4.4-community"
        "redis:6.2-alpine"
        "mysql:8.0"
        "confluentinc/cp-zookeeper:7.0.1"
        "confluentinc/cp-kafka:7.0.1"
        "clickhouse/clickhouse-server:23.8-alpine"
        "apache/flink:1.17.0"
        "provectuslabs/kafka-ui:latest"
    )
    
    local missing_images=0
    for image in "${required_images[@]}"; do
        if ! docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "^${image}$"; then
            ((missing_images++))
        fi
    done
    
    if [ $missing_images -eq 0 ]; then
        print_status "所有Docker镜像已准备就绪 (${#required_images[@]}/${#required_images[@]})"
        log_message "INFO" "所有Docker镜像已准备就绪"
    elif [ $missing_images -lt 3 ]; then
        print_warning "缺少 $missing_images 个镜像，但可以使用现有镜像启动"
        log_message "WARN" "缺少 $missing_images 个镜像，使用现有镜像启动"
    else
        print_warning "缺少 $missing_images 个镜像，建议先运行 ./temp_pull_images.sh"
        log_message "WARN" "缺少 $missing_images 个镜像"
    fi
    
    # 尝试启动基础设施服务 - 优化重试机制
    print_info "启动Docker Compose服务..."
    local max_retries=2
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        docker-compose --project-name security-analysis up -d > "${LOG_DIR}/docker_up_attempt_$((retry+1)).log" 2>&1
        
        if [ $? -eq 0 ]; then
            print_status "Docker服务启动命令执行成功"
            break
        else
            ((retry++))
            if [ $retry -lt $max_retries ]; then
                print_warning "Docker服务启动失败，第 $retry 次重试..."
                sleep 2
                
                # 快速清理残留容器
                docker-compose --project-name security-analysis down > /dev/null 2>&1 || true
                sleep 1
            else
                print_error "Docker服务启动失败，已尝试 $max_retries 次"
                print_info "最后一次错误详情:"
                tail -n 10 "${LOG_DIR}/docker_up_attempt_$retry.log" 2>/dev/null || true
                
                # 尝试启动核心服务（逐个启动重要服务）
                print_info "尝试启动核心服务..."
                local core_services=("elasticsearch" "redis" "mysql" "neo4j")
                local started_services=0
                
                for service in "${core_services[@]}"; do
                    print_info "启动 $service..."
                    if docker-compose --project-name security-analysis up -d "$service" > /dev/null 2>&1; then
                        ((started_services++))
                        print_status "$service 启动成功"
                    else
                        print_warning "$service 启动失败"
                    fi
                done
                
                if [ $started_services -gt 0 ]; then
                    print_warning "已启动 $started_services/${#core_services[@]} 个核心服务，部分功能可能受限"
                    break
                else
                    print_error "基础设施启动失败"
                    return 1
                fi
            fi
        fi
    done
    
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
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        print_warning "部分服务启动失败: ${failed_services[*]}"
        print_info "系统将继续启动，但功能可能受限"
    else
        print_status "所有基础设施服务启动成功"
    fi
}

# ==============================================================================
# 服务配置功能
# ==============================================================================

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
            local log_filename=$(echo "$service_name" | tr '[:upper:]' '[:lower:]')
            if bash "$script_path" > "${LOG_DIR}/setup_${log_filename}.log" 2>&1; then
                print_status "$service_name 配置完成"
            else
                print_warning "$service_name 配置失败，查看 ${LOG_DIR}/setup_${log_filename}.log"
            fi
        else
            print_warning "配置脚本不存在: $script_path"
        fi
    done
    
    print_status "服务配置完成"
}

# ==============================================================================
# API服务启动功能
# ==============================================================================

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

# ==============================================================================
# 演示功能启动
# ==============================================================================

prepare_demo_data() {
    print_info "准备演示数据..."
    
    # 创建演示配置
    cat > demo_config.json << EOF
{
    "demo_mode": true,
    "auto_scenarios": [
        {
            "name": "lateral_movement",
            "delay": 30,
            "auto_run": false
        },
        {
            "name": "brute_force", 
            "delay": 60,
            "auto_run": false
        }
    ],
    "demo_settings": {
        "show_real_data": false,
        "simulate_high_load": false,
        "enable_notifications": true
    }
}
EOF
    
    print_status "演示配置已生成"
}

start_demo_interface() {
    print_section "🎭 启动Web演示界面"
    
    # 检查演示界面文件
    if [ ! -f "demo_web_manager.py" ]; then
        print_warning "演示界面文件不存在，跳过演示界面启动"
        return 0
    fi
    
    # 检查端口5115
    if lsof -ti:5115 > /dev/null 2>&1; then
        local pid=$(lsof -ti:5115)
        local process_name=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
        
        if [[ "$process_name" =~ (OrbStack|Docker|dockerd|containerd|nexus) ]] || [[ "$pid" -eq "$PPID" ]]; then
            print_warning "端口5115被系统进程 $process_name 占用，将使用其他端口"
            # 可以在这里修改端口或跳过启动
        else
            print_warning "端口5115被进程 $process_name (PID: $pid) 占用，尝试释放..."
            kill -TERM "$pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
            sleep 2
        fi
    fi
    
    # 准备演示数据
    prepare_demo_data
    
    # 启动演示界面
    print_info "启动Web演示管理界面..."
    cd "$SCRIPT_DIR"
    source demo_venv/bin/activate
    nohup python3 demo_web_manager.py > "$DEMO_WEB_LOG" 2>&1 &
    local demo_pid=$!
    echo $demo_pid > "$DEMO_WEB_PID"
    
    print_status "演示界面已启动 (PID: $demo_pid)"
    
    # 等待演示界面就绪
    local max_wait=15
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        if curl -s http://localhost:5115 > /dev/null 2>&1; then
            print_status "演示界面已就绪"
            return 0
        else
            sleep 2
            ((waited+=2))
            echo -ne "\r等待演示界面启动... [${waited}s/${max_wait}s]"
        fi
    done
    
    echo ""
    print_warning "演示界面启动可能需要更多时间"
    return 0
}

# ==============================================================================
# 健康检查功能
# ==============================================================================

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
    
    if [ ${#failed_checks[@]} -eq 0 ]; then
        print_status "所有健康检查通过"
        return 0
    else
        print_warning "部分健康检查失败: ${failed_checks[*]}"
        return 1
    fi
}

# ==============================================================================
# 监控和管理功能
# ==============================================================================

create_monitoring_dashboard() {
    print_info "创建监控面板..."
    
    local dashboard_file="${SCRIPT_DIR}/monitoring_dashboard.html"
    
    cat > "$dashboard_file" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>安全分析系统 - 统一监控面板</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .service-card { background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .service-title { font-size: 18px; font-weight: bold; margin-bottom: 10px; color: #2c3e50; }
        .service-url { display: block; color: #3498db; text-decoration: none; margin: 5px 0; }
        .service-url:hover { text-decoration: underline; }
        .demo-section { background: #9b59b6; color: white; padding: 15px; border-radius: 8px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🛡️ 安全告警分析系统 - 统一监控面板</h1>
        <p>系统启动时间: <span id="startTime"></span></p>
        <p>启动模式: 统一全量启动 (完整系统 + Web演示 + 客户演示)</p>
    </div>
    
    <div class="demo-section">
        <h2>🎭 演示功能</h2>
        <p><strong>Web演示界面:</strong> <a href="http://localhost:5115" target="_blank" style="color: #ecf0f1;">http://localhost:5115</a></p>
        <p>提供一键控制、实时监控、场景演示等客户演示功能</p>
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
            <div class="service-title">🎭 演示功能</div>
            <a href="http://localhost:5115" class="service-url" target="_blank">Web演示管理界面</a>
            <p style="margin: 10px 0; font-size: 14px; color: #666;">
                提供完整的客户演示功能，包括系统监控、一键启停、场景演示等
            </p>
        </div>
    </div>
    
    <script>
        document.getElementById('startTime').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

    print_status "监控面板创建完成: $dashboard_file"
}

create_management_scripts() {
    print_info "创建管理脚本..."
    
    # 创建停止脚本
    cat > stop_all.sh << 'EOF'
#!/bin/bash

echo "🛑 停止安全告警分析系统..."

# 停止API服务
if [ -f "security_system.pid" ]; then
    kill $(cat security_system.pid) 2>/dev/null || true
    rm -f security_system.pid
    echo "✅ API服务已停止"
fi

# 停止演示界面
if [ -f "demo_web.pid" ]; then
    kill $(cat demo_web.pid) 2>/dev/null || true
    rm -f demo_web.pid
    echo "✅ 演示界面已停止"
fi

# 停止演示系统
if [ -f "demo_system.pid" ]; then
    kill $(cat demo_system.pid) 2>/dev/null || true
    rm -f demo_system.pid
    echo "✅ 演示系统已停止"
fi

# 停止Docker服务
docker-compose down
echo "✅ Docker服务已停止"

# 清理临时文件
rm -f demo_config.json
echo "✅ 临时文件已清理"

echo ""
echo "🎉 安全告警分析系统已完全停止"
EOF
    
    chmod +x stop_all.sh
    print_status "停止脚本创建完成: stop_all.sh"
}


# ==============================================================================
# 信息显示功能
# ==============================================================================

display_system_info() {
    print_section "🎉 系统启动完成"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         🛡️  一键全量启动完成 🛡️                             ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    echo -e "${PURPLE}🎭 演示功能 (客户演示推荐)${NC}"
    echo -e "   🌐 Web演示管理界面: ${GREEN}http://localhost:5115${NC}"
    echo -e "   📋 功能: 一键启停、实时监控、场景演示、客户演示"
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
    
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              系统管理命令                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}停止系统:${NC} ./stop_all.sh"
    echo -e "${GREEN}查看日志:${NC} docker-compose logs -f [服务名]"
    echo -e "${GREEN}重启服务:${NC} docker-compose restart [服务名]"
    echo ""
    
    echo -e "${CYAN}📁 重要文件位置:${NC}"
    echo "   📋 主日志: $MAIN_LOG"
    echo "   🚀 API日志: $API_LOG"
    echo "   🎭 演示日志: $DEMO_WEB_LOG"
    echo "   💾 PID文件: $PID_FILE"
    echo ""
    
    echo -e "${YELLOW}💡 客户演示建议:${NC}"
    echo "   1. 首先访问 Web演示管理界面: http://localhost:5115"
    echo "   2. 使用演示界面展示系统架构和功能"
    echo "   3. 演示一键启停和实时监控功能"
    echo "   4. 运行安全场景演示"
    echo "   5. 展示各个组件的管理界面"
    echo ""
    
    echo -e "${GREEN}✨ 安全告警分析系统一键全量启动完成！${NC}"
    echo -e "${PURPLE}🎪 客户演示模式已就绪，祝您演示成功！${NC}"
}

# ==============================================================================
# 主函数
# ==============================================================================

start_full_system() {
    print_info "启动完整安全分析系统..."
    echo ""
    
    # 检查系统先决条件
    if ! check_prerequisites; then
        print_error "系统先决条件检查失败，请解决问题后重试"
        return 1
    fi
    
    # 检查系统资源
    check_system_resources
    
    # 设置环境
    if ! setup_environment; then
        print_error "环境配置失败"
        return 1
    fi
    
    # 启动基础设施
    if ! start_infrastructure; then
        print_error "基础设施启动失败"
        return 1
    fi
    
    # 配置服务
    configure_services
    
    # 启动API服务
    if ! start_api_service; then
        print_error "API服务启动失败"
        return 1
    fi
    
    # 启动演示界面
    start_demo_interface
    
    # 执行健康检查
    perform_health_checks
    
    # 创建监控面板
    create_monitoring_dashboard
    
    # 创建管理脚本
    create_management_scripts
    
    # 显示系统信息
    display_system_info
    
    # 自动打开浏览器
    if command -v open &> /dev/null; then
        sleep 3
        open http://localhost:5115
        open http://localhost:8000/docs
    elif command -v xdg-open &> /dev/null; then
        sleep 3
        xdg-open http://localhost:5115
        xdg-open http://localhost:8000/docs
    fi
    
    log_message "SUCCESS" "统一全量系统启动完成"
    
    echo ""
    echo -e "${PURPLE}系统已完全启动，按 Ctrl+C 查看停止说明${NC}"
    
    # 等待用户中断
    trap 'echo -e "\n\n${YELLOW}要停止系统，请运行: ${GREEN}./stop_all.sh${NC}\n"; exit 0' INT
    
    # 保持脚本运行
    while true; do
        sleep 60
    done
}

cleanup_on_exit() {
    log_message "INFO" "清理临时文件..."
}

main() {
    # 设置退出时的清理函数
    trap cleanup_on_exit EXIT
    
    # 显示启动横幅
    print_banner
    
    # 直接启动完整系统
    print_info "开始全量启动安全告警分析系统..."
    echo ""
    
    if start_full_system; then
        log_message "SUCCESS" "系统启动成功"
    else
        print_error "系统启动失败，请检查错误信息"
        exit 1
    fi
}

# 检查是否直接运行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi