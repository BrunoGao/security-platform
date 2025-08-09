#!/bin/bash

# 安全告警分析系统 - 基础设施配置脚本
# Security Alert Analysis System - Infrastructure Setup Script
# Version: 1.0
# 功能: 拉取和配置所有基础组件，确保系统依赖完整

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                🏗️  安全告警分析系统 - 基础设施配置 🏗️                        ║"
    echo "║              Security Alert Analysis System - Infrastructure Setup          ║"
    echo "║                              v1.0                                           ║"
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

# 检查必要工具
check_prerequisites() {
    print_section "🔍 检查必要工具"
    
    local missing_tools=()
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("Docker")
        print_error "Docker未安装"
    else
        print_status "Docker已安装: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
        
        # 检查Docker是否运行
        if ! docker info &> /dev/null; then
            print_error "Docker服务未运行，请启动Docker"
            return 1
        else
            print_status "Docker服务运行正常"
        fi
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        missing_tools+=("Docker Compose")
        print_error "Docker Compose未安装"
    else
        print_status "Docker Compose已安装: $(docker-compose --version | cut -d' ' -f4 | cut -d',' -f1)"
    fi
    
    # 检查Python3
    if ! command -v python3 &> /dev/null; then
        missing_tools+=("Python3")
        print_error "Python3未安装"
    else
        print_status "Python3已安装: $(python3 --version | cut -d' ' -f2)"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "缺少必要工具: ${missing_tools[*]}"
        print_info "请安装缺少的工具后重新运行此脚本"
        return 1
    fi
    
    print_status "所有必要工具检查通过"
}

# Docker镜像列表 (适配OrbStack和M2芯片，使用镜像加速器)
DOCKER_IMAGES=(
    # 基础设施
    "confluentinc/cp-zookeeper:7.0.1|Zookeeper"
    "confluentinc/cp-kafka:7.0.1|Kafka"
    "elasticsearch:8.11.1|Elasticsearch"
    "kibana:8.11.1|Kibana"
    "neo4j:4.4-community|Neo4j"
    "clickhouse/clickhouse-server:23.8-alpine|ClickHouse"
    "redis:6.2-alpine|Redis"
    "mysql:8.0|MySQL"
    
    # 流处理 (可选)
    "apache/flink:1.17.0|Flink"
    
    # 管理工具
    "provectuslabs/kafka-ui:latest|Kafka UI"
)

# 问题镜像的替代方案
ALTERNATIVE_MIRRORS=(
    "apache/flink:1.17.0|flink:1.14.0-scala_2.11"
    "wurstmeister/zookeeper:latest|confluentinc/cp-zookeeper:7.0.1"
    "wurstmeister/kafka:latest|confluentinc/cp-kafka:7.0.1"
)

# 拉取Docker镜像
pull_docker_images() {
    print_section "📥 拉取Docker镜像"
    
    # 检查并配置Docker镜像加速器 (优化支持OrbStack)
    print_info "检查Docker环境和镜像配置..."
    
    # 检测OrbStack
    if command -v orb &> /dev/null || pgrep -f "OrbStack" > /dev/null 2>&1; then
        print_status "检测到OrbStack环境"
        if [ ! -f "$HOME/.orbstack/config/daemon.json" ]; then
            print_info "配置OrbStack镜像加速器..."
            if [ -f "./configure_docker_mirrors.sh" ]; then
                ./configure_docker_mirrors.sh
            fi
        fi
    else
        print_info "使用标准Docker环境"
        if ! docker info | grep -q "Registry Mirrors" || [ "$(docker info | grep -A 5 'Registry Mirrors' | wc -l)" -lt 3 ]; then
            print_warning "Docker镜像加速器未配置或配置不全"
            if [ -f "./configure_docker_mirrors.sh" ]; then
                ./configure_docker_mirrors.sh
                print_info "请重启Docker后重新运行此脚本"
                exit 1
            fi
        else
            print_status "Docker镜像加速器已配置"
        fi
    fi
    
    # 检查网络连接
    print_info "检查网络连接..."
    if curl -s --connect-timeout 3 https://docker.1ms.run/v2/ > /dev/null; then
        print_status "1MS镜像源连接正常"
    elif curl -s --connect-timeout 3 https://mirror.ccs.tencentyun.com/v2/ > /dev/null; then
        print_status "腾讯云镜像源连接正常"
    elif curl -s --connect-timeout 3 https://docker.m.daocloud.io/v2/ > /dev/null; then
        print_status "DaoCloud镜像源连接正常"
    elif curl -s --connect-timeout 5 https://registry-1.docker.io/v2/ > /dev/null; then
        print_status "Docker Hub连接正常"
    else
        print_warning "网络连接可能有问题，将使用现有镜像"
    fi
    
    local total_images=${#DOCKER_IMAGES[@]}
    local current=0
    local failed_images=()
    local success_count=0
    
    for image_info in "${DOCKER_IMAGES[@]}"; do
        IFS='|' read -r image_name description <<< "$image_info"
        ((current++))
        
        print_progress "[$current/$total_images] 拉取 $description ($image_name)..."
        
        # 检查镜像是否已存在
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image_name}$"; then
            print_status "$description 镜像已存在"
            ((success_count++))
            continue
        fi
        
        # 将description转换为小写（兼容旧版bash）
        description_lower=$(echo "$description" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
        
        # 尝试拉取镜像，设置超时
        if timeout 300 docker pull "$image_name" > "${LOG_DIR}/pull_${description_lower}.log" 2>&1; then
            print_status "$description 镜像拉取成功"
            ((success_count++))
        else
            print_warning "$description 镜像拉取失败，尝试备选镜像..."
            
            # 尝试备选镜像源
            alternative_found=false
            for alt_mapping in "${ALTERNATIVE_MIRRORS[@]}"; do
                IFS='|' read -r orig_image alt_image <<< "$alt_mapping"
                image_basename=$(echo "$image_name" | cut -d':' -f1 | sed 's|.*/||')
                orig_basename=$(echo "$orig_image" | cut -d':' -f1 | sed 's|.*/||')
                
                if [[ "$image_basename" == "$orig_basename" ]] || [[ "$image_name" == "$orig_image" ]]; then
                    print_info "尝试备选镜像: $alt_image"
                    if timeout 300 docker pull "$alt_image" > "${LOG_DIR}/pull_${description_lower}_alt.log" 2>&1; then
                        # 为备选镜像打标签
                        docker tag "$alt_image" "$image_name" > /dev/null 2>&1 || true
                        print_status "$description 备选镜像拉取成功"
                        ((success_count++))
                        alternative_found=true
                        break
                    fi
                fi
            done
            
            if [ "$alternative_found" = false ]; then
                failed_images+=("$description")
                # 显示具体错误信息
                if [ -f "${LOG_DIR}/pull_${description_lower}.log" ]; then
                    error_msg=$(tail -n 3 "${LOG_DIR}/pull_${description_lower}.log" | head -n 1)
                    print_info "错误详情: $error_msg"
                fi
            fi
        fi
        
        # 添加短暂延迟避免过于频繁的请求
        sleep 1
    done
    
    echo ""
    print_info "镜像拉取结果: 成功 $success_count/$total_images"
    
    if [ ${#failed_images[@]} -eq 0 ]; then
        print_status "所有Docker镜像准备完成"
    elif [ $success_count -gt 0 ]; then
        print_warning "部分镜像拉取失败: ${failed_images[*]}"
        print_info "已有 $success_count 个镜像可用，系统可以启动"
    else
        print_error "所有镜像拉取失败，请检查网络连接"
        return 1
    fi
}

# 创建Docker网络和卷
setup_docker_resources() {
    print_section "🔧 配置Docker资源"
    
    # 创建自定义网络
    print_info "创建Docker网络..."
    if docker network ls | grep -q security-network; then
        print_status "Docker网络已存在"
    else
        docker network create security-network --driver bridge > /dev/null 2>&1
        print_status "Docker网络创建完成"
    fi
    
    # 创建必要的卷
    print_info "创建Docker卷..."
    local volumes=(
        "zookeeper-data"
        "zookeeper-logs"
        "kafka-data"
        "elasticsearch-data"
        "kibana-data"
        "neo4j-data"
        "neo4j-logs"
        "neo4j-import"
        "neo4j-plugins"
        "clickhouse-data"
        "redis-data"
        "mysql-data"
        "flink-checkpoints"
        "flink-jobmanager-logs"
        "flink-taskmanager-logs"
        "kafka-ui-data"
    )
    
    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            print_status "卷 $volume 已存在"
        else
            docker volume create "$volume" > /dev/null 2>&1
            print_status "卷 $volume 创建完成"
        fi
    done
}

# 设置Python环境
setup_python_environment() {
    print_section "🐍 配置Python环境"
    
    # 检查虚拟环境
    if [ ! -d "venv" ]; then
        print_info "创建Python虚拟环境..."
        python3 -m venv venv
        print_status "虚拟环境创建完成"
    else
        print_status "虚拟环境已存在"
    fi
    
    # 激活虚拟环境
    print_info "激活虚拟环境..."
    source venv/bin/activate
    
    # 升级pip
    print_info "升级pip..."
    pip install --upgrade pip > "${LOG_DIR}/pip_upgrade.log" 2>&1
    
    # 安装依赖
    if [ -f "requirements.txt" ]; then
        print_info "安装Python依赖..."
        pip install -r requirements.txt > "${LOG_DIR}/pip_install_setup.log" 2>&1
        
        if [ $? -eq 0 ]; then
            print_status "Python依赖安装完成"
        else
            print_warning "Python依赖安装失败，查看 ${LOG_DIR}/pip_install_setup.log"
        fi
    else
        print_warning "未找到 requirements.txt 文件"
    fi
    
    # 设置演示环境
    print_info "设置演示环境..."
    if [ ! -d "demo_venv" ]; then
        python3 -m venv demo_venv
        demo_venv/bin/pip install --upgrade pip > /dev/null 2>&1
        
        if [ -f "demo_requirements.txt" ]; then
            demo_venv/bin/pip install -r demo_requirements.txt > "${LOG_DIR}/demo_pip_install.log" 2>&1
        else
            demo_venv/bin/pip install Flask Flask-CORS Flask-SocketIO psutil requests eventlet > "${LOG_DIR}/demo_pip_install.log" 2>&1
        fi
        print_status "演示环境配置完成"
    else
        print_status "演示环境已存在"
    fi
}

# 验证配置
verify_setup() {
    print_section "🔍 验证配置"
    
    local issues=()
    
    # 检查Docker镜像
    print_info "检查Docker镜像..."
    local missing_images=0
    for image_info in "${DOCKER_IMAGES[@]}"; do
        IFS='|' read -r image_name description <<< "$image_info"
        if ! docker images | grep -q "$(echo $image_name | cut -d':' -f1)"; then
            ((missing_images++))
        fi
    done
    
    if [ $missing_images -eq 0 ]; then
        print_status "所有Docker镜像已准备就绪"
    else
        print_warning "$missing_images 个Docker镜像缺失"
        issues+=("Docker镜像缺失")
    fi
    
    # 检查Python环境
    print_info "检查Python环境..."
    if [ -d "venv" ] && [ -f "venv/bin/python" ]; then
        print_status "Python虚拟环境正常"
    else
        print_warning "Python虚拟环境有问题"
        issues+=("Python环境")
    fi
    
    # 检查演示环境
    if [ -d "demo_venv" ] && [ -f "demo_venv/bin/python" ]; then
        print_status "演示环境正常"
    else
        print_warning "演示环境有问题"
        # 尝试重新创建演示环境
        print_info "尝试修复演示环境..."
        if python3 -m venv demo_venv > /dev/null 2>&1; then
            demo_venv/bin/pip install --upgrade pip > /dev/null 2>&1
            if [ -f "demo_requirements.txt" ]; then
                demo_venv/bin/pip install -r demo_requirements.txt > /dev/null 2>&1
            else
                demo_venv/bin/pip install Flask Flask-CORS Flask-SocketIO psutil requests eventlet > /dev/null 2>&1
            fi
            print_status "演示环境修复完成"
        else
            issues+=("演示环境")
        fi
    fi
    
    # 检查配置文件
    print_info "检查配置文件..."
    local config_files=("docker-compose.yml" "requirements.txt")
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            print_status "配置文件 $file 存在"
        else
            print_warning "配置文件 $file 缺失"
            issues+=("配置文件缺失")
        fi
    done
    
    if [ ${#issues[@]} -eq 0 ]; then
        print_status "所有配置验证通过"
        return 0
    else
        print_warning "发现问题: ${issues[*]}"
        return 1
    fi
}

# 清理函数
cleanup_on_failure() {
    print_info "清理失败的配置..."
    # 这里可以添加清理逻辑
}

# 创建启动就绪标记
create_ready_marker() {
    print_info "创建配置完成标记..."
    cat > .infrastructure_ready << EOF
# 基础设施配置完成标记
# Infrastructure Setup Complete Marker
setup_date=$(date '+%Y-%m-%d %H:%M:%S')
setup_version=1.0
docker_images_pulled=true
python_env_ready=true
demo_env_ready=true
EOF
    print_status "配置完成标记已创建"
}

# 显示总结信息
show_summary() {
    print_section "🎉 配置完成"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         🛡️  基础设施配置完成 🛡️                             ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    echo -e "${GREEN}📦 已配置组件:${NC}"
    echo "   • Docker镜像 (Elasticsearch, Kafka, Neo4j, ClickHouse, Redis, MySQL等)"
    echo "   • Python虚拟环境和依赖"
    echo "   • 演示环境"
    echo "   • Docker网络和存储卷"
    echo ""
    
    echo -e "${BLUE}🚀 下一步操作:${NC}"
    echo "   1. 运行 ./start_app.sh 启动完整系统"
    echo "   2. 或运行 docker-compose up -d 仅启动Docker服务"
    echo ""
    
    echo -e "${YELLOW}📁 重要文件:${NC}"
    echo "   • 配置日志: $LOG_DIR/"
    echo "   • Python环境: ./venv/"
    echo "   • 演示环境: ./demo_venv/"
    echo "   • 配置标记: ./.infrastructure_ready"
    echo ""
    
    echo -e "${CYAN}💡 提示:${NC}"
    echo "   • 如需重新配置，请删除 .infrastructure_ready 文件"
    echo "   • 查看日志文件了解详细配置过程"
    echo ""
    
    echo -e "${GREEN}✨ 基础设施配置完成，现在可以启动系统了！${NC}"
}

# 主函数
main() {
    # 设置错误处理
    trap cleanup_on_failure ERR
    
    print_banner
    
    # 检查是否已经配置过
    if [ -f ".infrastructure_ready" ]; then
        print_warning "基础设施已配置完成"
        read -p "是否重新配置? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "跳过配置，使用现有设置"
            exit 0
        fi
        rm -f .infrastructure_ready
    fi
    
    # 执行配置步骤
    if ! check_prerequisites; then
        exit 1
    fi
    
    pull_docker_images
    setup_docker_resources
    setup_python_environment
    
    if verify_setup; then
        create_ready_marker
        show_summary
    else
        print_error "配置验证失败，请检查日志文件"
        exit 1
    fi
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi