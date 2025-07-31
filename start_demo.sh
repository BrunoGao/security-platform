#!/bin/bash

# 安全告警分析系统 - Web演示界面启动脚本
# Security Alert Analysis System - Web Demo Interface Startup Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    安全告警分析系统 - Web演示界面启动                        ║"
    echo "║                 Security Alert Analysis System - Web Demo                   ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
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

check_python() {
    print_info "检查Python环境..."
    
    if ! command -v python3 &> /dev/null; then
        print_error "Python3未安装，请先安装Python3"
        exit 1
    fi
    
    python_version=$(python3 --version | cut -d' ' -f2)
    print_status "Python3已安装: $python_version"
    
    # 检查pip
    if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
        print_error "pip未安装，请先安装pip"
        exit 1
    fi
    
    print_status "pip已安装"
}

setup_virtual_env() {
    print_info "设置Python虚拟环境..."
    
    if [ ! -d "demo_venv" ]; then
        print_info "创建虚拟环境..."
        python3 -m venv demo_venv
        print_status "虚拟环境创建完成"
    else
        print_status "虚拟环境已存在"
    fi
    
    print_info "激活虚拟环境..."
    source demo_venv/bin/activate
    
    print_status "虚拟环境已激活"
}

install_dependencies() {
    print_info "安装演示界面依赖..."
    
    if [ -f "demo_requirements.txt" ]; then
        pip install -r demo_requirements.txt > /dev/null 2>&1
        print_status "依赖安装完成"
    else
        print_warning "未找到 demo_requirements.txt，安装基础依赖..."
        pip install Flask Flask-CORS Flask-SocketIO psutil requests eventlet > /dev/null 2>&1
        print_status "基础依赖安装完成"
    fi
}

check_port() {
    local port=$1
    if lsof -ti:$port > /dev/null 2>&1; then
        print_warning "端口 $port 被占用，尝试释放..."
        local pid=$(lsof -ti:$port)
        kill -9 $pid 2>/dev/null || true
        sleep 2
    fi
}

start_demo_server() {
    print_info "启动Web演示管理界面..."
    
    # 检查端口5115是否被占用
    check_port 5115
    
    # 确保目录结构存在
    print_info "检查目录结构..."
    mkdir -p demo_web/templates demo_web/static/css demo_web/static/js
    
    # 检查必要文件是否存在
    if [ ! -f "demo_web_manager.py" ]; then
        print_error "未找到 demo_web_manager.py 文件"
        exit 1
    fi
    
    if [ ! -f "demo_web/templates/demo_dashboard.html" ]; then
        print_error "未找到演示界面模板文件"
        exit 1
    fi
    
    print_status "所有必要文件检查完成"
    
    # 启动Flask应用
    print_info "启动Flask服务器..."
    echo ""
    echo -e "${GREEN}🚀 Web演示管理界面启动中...${NC}"
    echo ""
    echo "==================== 访问信息 ===================="
    echo ""
    echo -e "${BLUE}📱 演示管理界面:${NC} http://localhost:5115"
    echo -e "${YELLOW}🎯 使用说明:${NC}"
    echo "   1. 在浏览器中打开演示管理界面"
    echo "   2. 使用界面中的按钮控制系统启停"
    echo "   3. 实时监控系统状态和资源使用"
    echo "   4. 创建测试事件和运行演示场景"
    echo "   5. 查看系统日志和服务状态"
    echo ""
    echo "==================== 快速演示 ===================="
    echo ""
    echo -e "${GREEN}客户演示流程:${NC}"
    echo "   → 展示系统架构和组件"
    echo "   → 一键启动整个系统"
    echo "   → 实时监控系统状态"
    echo "   → 运行安全场景演示"
    echo "   → 展示分析结果和响应"
    echo ""
    echo "=================================================="
    echo ""
    echo -e "${YELLOW}按 Ctrl+C 停止服务${NC}"
    echo ""
    
    # 启动Python应用
    python3 demo_web_manager.py
}

cleanup() {
    print_info "清理资源..."
    # 这里可以添加清理逻辑
    exit 0
}

main() {
    print_banner
    
    # 设置退出处理
    trap cleanup EXIT INT TERM
    
    # 检查环境
    check_python
    
    # 设置虚拟环境
    setup_virtual_env
    
    # 安装依赖
    install_dependencies
    
    # 启动演示服务器
    start_demo_server
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi