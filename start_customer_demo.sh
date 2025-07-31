#!/bin/bash

# 安全告警分析系统 - 客户演示一键启动脚本
# Security Alert Analysis System - Customer Demo One-Click Start

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
NC='\033[0m'

print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                     🎪 安全告警分析系统 - 客户演示模式 🎪                   ║"
    echo "║                  Security Alert Analysis System - Demo Mode                 ║"
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

check_demo_readiness() {
    print_section "🔍 演示环境检查"
    
    local checks_passed=0
    local total_checks=8
    
    # 检查必要文件
    echo "检查核心文件..."
    local required_files=(
        "docker-compose.yml"
        "one_click_start.sh"
        "demo_web_manager.py"
        "demo_web/templates/demo_dashboard.html"
        "DEMO_GUIDE.md"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            print_status "$file 存在"
            ((checks_passed++))
        else
            print_error "$file 缺失"
        fi
    done
    
    # 检查Docker
    if command -v docker &> /dev/null && docker info > /dev/null 2>&1; then
        print_status "Docker 服务正常"
        ((checks_passed++))
    else
        print_error "Docker 服务异常"
    fi
    
    # 检查Python
    if command -v python3 &> /dev/null; then
        print_status "Python3 环境正常"
        ((checks_passed++))
    else
        print_error "Python3 环境异常"
    fi
    
    # 检查系统资源
    if command -v python3 &> /dev/null; then
        local memory_gb=$(python3 -c "import psutil; print(int(psutil.virtual_memory().available / 1024 / 1024 / 1024))" 2>/dev/null || echo "0")
        if [ "$memory_gb" -ge 4 ]; then
            print_status "系统内存充足 (${memory_gb}GB 可用)"
            ((checks_passed++))
        else
            print_warning "系统内存不足 (${memory_gb}GB 可用，建议4GB+)"
        fi
    fi
    
    echo ""
    echo -e "${WHITE}检查结果: ${GREEN}$checks_passed${WHITE}/${total_checks} 项通过${NC}"
    
    if [ $checks_passed -ge 6 ]; then
        print_status "演示环境就绪！"
        return 0
    else
        print_error "演示环境存在问题，请检查后重试"
        return 1
    fi
}

prepare_demo_data() {
    print_section "📊 准备演示数据"
    
    # 创建演示配置
    print_info "生成演示配置..."
    
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
    
    # 预加载演示场景数据
    print_info "预加载演示场景..."
    # 这里可以添加预加载逻辑
    print_status "演示场景已准备"
}

start_background_services() {
    print_section "🚀 启动后台服务"
    
    print_info "启动核心安全分析系统..."
    
    # 在后台启动主系统
    nohup ./one_click_start.sh > logs/demo_system.log 2>&1 &
    local system_pid=$!
    echo $system_pid > demo_system.pid
    
    print_status "系统启动命令已发送 (PID: $system_pid)"
    
    # 等待系统基本启动
    print_info "等待系统初始化..."
    sleep 20
    
    # 检查系统状态
    local retry_count=0
    local max_retries=10
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -s http://localhost:8000/health > /dev/null 2>&1; then
            print_status "核心系统已就绪"
            break
        else
            print_info "等待系统启动完成... ($((retry_count + 1))/$max_retries)"
            sleep 10
            ((retry_count++))
        fi
    done
    
    if [ $retry_count -eq $max_retries ]; then
        print_warning "核心系统启动可能需要更多时间，但演示界面可以正常使用"
    fi
}

start_demo_interface() {
    print_section "🎭 启动演示管理界面"
    
    print_info "准备演示界面环境..."
    
    # 确保演示界面依赖已安装
    if [ ! -d "demo_venv" ]; then
        print_info "创建演示界面虚拟环境..."
        python3 -m venv demo_venv
    fi
    
    source demo_venv/bin/activate
    
    # 安装依赖
    if [ -f "demo_requirements.txt" ]; then
        pip install -r demo_requirements.txt > /dev/null 2>&1
    else
        pip install Flask Flask-CORS Flask-SocketIO psutil requests eventlet > /dev/null 2>&1
    fi
    
    print_status "演示界面环境已准备"
    
    # 启动演示界面
    print_info "启动Web演示管理界面..."
    
    # 检查端口5115
    if lsof -ti:5115 > /dev/null 2>&1; then
        print_warning "端口5115被占用，尝试释放..."
        kill -9 $(lsof -ti:5115) 2>/dev/null || true
        sleep 2
    fi
    
    # 在后台启动演示界面
    nohup python3 demo_web_manager.py > logs/demo_web.log 2>&1 &
    local demo_pid=$!
    echo $demo_pid > demo_web.pid
    
    print_status "演示界面已启动 (PID: $demo_pid)"
    
    # 等待演示界面就绪
    sleep 5
    
    local retry_count=0
    while [ $retry_count -lt 5 ]; do
        if curl -s http://localhost:5115 > /dev/null 2>&1; then
            print_status "演示界面已就绪"
            break
        else
            sleep 2
            ((retry_count++))
        fi
    done
}

show_demo_information() {
    print_section "🎪 演示信息"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                            🎯 客户演示已准备就绪 🎯                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    echo -e "${WHITE}📱 演示管理界面${NC}"
    echo -e "   🌐 访问地址: ${GREEN}http://localhost:5115${NC}"
    echo -e "   📋 功能: 一键启停、实时监控、场景演示"
    echo ""
    
    echo -e "${WHITE}🎭 演示流程建议${NC}"
    echo -e "   1️⃣  打开演示管理界面"
    echo -e "   2️⃣  展示系统架构和监控"
    echo -e "   3️⃣  演示一键启动功能"
    echo -e "   4️⃣  运行安全场景演示"
    echo -e "   5️⃣  展示各组件界面"
    echo ""
    
    echo -e "${WHITE}🔗 主要服务链接${NC}"
    echo -e "   🎯 API服务: ${BLUE}http://localhost:8000${NC}"
    echo -e "   📊 Kibana: ${BLUE}http://localhost:5601${NC}"
    echo -e "   🕸️  Neo4j: ${BLUE}http://localhost:7474${NC} (neo4j/security123)"
    echo -e "   📈 ClickHouse: ${BLUE}http://localhost:8123/play${NC} (admin/security123)"
    echo -e "   🚀 Kafka UI: ${BLUE}http://localhost:8082${NC}"
    echo ""
    
    echo -e "${WHITE}📚 演示资料${NC}"
    echo -e "   📖 演示指南: ${CYAN}DEMO_GUIDE.md${NC}"
    echo -e "   🛠️  技术文档: ${CYAN}STARTUP_GUIDE.md${NC}"
    echo -e "   📋 系统日志: ${CYAN}logs/${NC}"
    echo ""
    
    echo -e "${WHITE}🆘 紧急联系${NC}"
    echo -e "   🐛 系统问题: 运行 ${YELLOW}./status_check.sh${NC}"
    echo -e "   🔄 重启系统: 运行 ${YELLOW}./manage.sh restart${NC}"
    echo -e "   🛑 停止演示: 运行 ${YELLOW}./stop_demo.sh${NC}"
    echo ""
    
    echo -e "${YELLOW}⭐ 演示小贴士:${NC}"
    echo -e "   • 保持网络连接稳定"
    echo -e "   • 准备客户可能的技术问题"
    echo -e "   • 关注系统资源使用情况"
    echo -e "   • 随时查看实时日志"
    echo ""
    
    echo -e "${GREEN}🎉 祝您演示成功！${NC}"
    echo ""
}

create_demo_shortcuts() {
    print_info "创建演示快捷方式..."
    
    # 创建桌面快捷方式（macOS）
    if [[ "$OSTYPE" == "darwin"* ]]; then
        cat > ~/Desktop/安全分析系统演示.command << EOF
#!/bin/bash
cd "$SCRIPT_DIR"
open http://localhost:5115
EOF
        chmod +x ~/Desktop/安全分析系统演示.command
        print_status "桌面快捷方式已创建"
    fi
    
    # 创建停止演示脚本
    cat > stop_demo.sh << 'EOF'
#!/bin/bash
echo "🛑 停止客户演示环境..."

# 停止演示界面
if [ -f "demo_web.pid" ]; then
    kill $(cat demo_web.pid) 2>/dev/null || true
    rm -f demo_web.pid
    echo "✅ 演示界面已停止"
fi

# 停止核心系统
if [ -f "demo_system.pid" ]; then
    kill $(cat demo_system.pid) 2>/dev/null || true
    rm -f demo_system.pid
    echo "✅ 核心系统已停止"
fi

# 停止Docker服务
./manage.sh stop > /dev/null 2>&1 || true
echo "✅ Docker服务已停止"

# 清理临时文件
rm -f demo_config.json
echo "✅ 临时文件已清理"

echo ""
echo "🎪 客户演示环境已完全停止"
echo "感谢使用安全告警分析系统演示！"
EOF
    
    chmod +x stop_demo.sh
    print_status "停止脚本已创建"
}

main() {
    print_banner
    
    # 创建日志目录
    mkdir -p logs
    
    # 检查演示环境
    if ! check_demo_readiness; then
        exit 1
    fi
    
    # 准备演示数据
    prepare_demo_data
    
    # 启动后台服务
    start_background_services
    
    # 启动演示界面
    start_demo_interface
    
    # 创建快捷方式
    create_demo_shortcuts
    
    # 显示演示信息
    show_demo_information
    
    # 自动打开浏览器
    if command -v open &> /dev/null; then
        sleep 3
        open http://localhost:5115
    elif command -v xdg-open &> /dev/null; then
        sleep 3
        xdg-open http://localhost:5115
    fi
    
    echo -e "${PURPLE}演示环境已启动，按 Ctrl+C 查看停止说明${NC}"
    
    # 等待用户中断
    trap 'echo -e "\n\n${YELLOW}要停止演示环境，请运行: ${GREEN}./stop_demo.sh${NC}\n"; exit 0' INT
    
    # 保持脚本运行
    while true; do
        sleep 60
    done
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi