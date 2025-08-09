#!/bin/bash

# Docker国内镜像源配置脚本
# Docker Domestic Mirror Configuration Script

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

echo "🐳 Docker国内镜像源配置工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
print_info "检测到操作系统: $OS"

# 配置Docker daemon镜像加速器
configure_docker_daemon() {
    print_progress "配置Docker daemon镜像加速器..."
    
    if [ "$OS" = "macos" ]; then
        # 检测是否使用OrbStack
        if command -v orb &> /dev/null || pgrep -f "OrbStack" > /dev/null 2>&1; then
            print_info "检测到OrbStack环境"
            
            # OrbStack配置路径
            ORBSTACK_CONFIG_DIR="$HOME/.orbstack"
            DAEMON_JSON="$ORBSTACK_CONFIG_DIR/config/daemon.json"
            
            mkdir -p "$ORBSTACK_CONFIG_DIR/config"
            
            # 备份现有配置
            if [ -f "$DAEMON_JSON" ]; then
                cp "$DAEMON_JSON" "$DAEMON_JSON.backup.$(date +%Y%m%d_%H%M%S)"
                print_info "已备份OrbStack配置: $DAEMON_JSON.backup.*"
            fi
            
            # 创建或更新OrbStack daemon.json
            cat > "$DAEMON_JSON" << 'EOF'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://mirror.ccs.tencentyun.com",
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "insecure-registries": [],
  "debug": false,
  "experimental": false,
  "features": {
    "buildkit": true
  }
}
EOF
            
            print_status "OrbStack Docker daemon配置已更新: $DAEMON_JSON"
            print_info "OrbStack通常会自动重载配置，无需手动重启"
            
            # 尝试重启OrbStack服务
            if command -v orb &> /dev/null; then
                print_progress "重启OrbStack服务..."
                orb restart > /dev/null 2>&1 || print_warning "无法自动重启OrbStack，请手动重启"
            fi
            
        else
            # Docker Desktop配置
            DOCKER_CONFIG_DIR="$HOME/.docker"
            DAEMON_JSON="$DOCKER_CONFIG_DIR/daemon.json"
            
            mkdir -p "$DOCKER_CONFIG_DIR"
            
            # 备份现有配置
            if [ -f "$DAEMON_JSON" ]; then
                cp "$DAEMON_JSON" "$DAEMON_JSON.backup.$(date +%Y%m%d_%H%M%S)"
                print_info "已备份现有配置: $DAEMON_JSON.backup.*"
            fi
            
            # 创建或更新daemon.json
            cat > "$DAEMON_JSON" << 'EOF'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://mirror.ccs.tencentyun.com",
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "insecure-registries": [],
  "debug": false,
  "experimental": false
}
EOF
            
            print_status "Docker daemon配置已更新: $DAEMON_JSON"
            print_warning "请重启Docker Desktop以使配置生效"
        fi
        
    elif [ "$OS" = "linux" ]; then
        # Linux Docker配置
        DAEMON_JSON="/etc/docker/daemon.json"
        
        # 检查权限
        if [ "$EUID" -ne 0 ]; then
            print_error "Linux系统需要root权限配置Docker daemon"
            print_info "请使用: sudo $0"
            exit 1
        fi
        
        # 创建目录
        mkdir -p /etc/docker
        
        # 备份现有配置
        if [ -f "$DAEMON_JSON" ]; then
            cp "$DAEMON_JSON" "$DAEMON_JSON.backup.$(date +%Y%m%d_%H%M%S)"
            print_info "已备份现有配置: $DAEMON_JSON.backup.*"
        fi
        
        # 创建或更新daemon.json
        cat > "$DAEMON_JSON" << 'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://ccr.ccs.tencentyun.com"
  ],
  "insecure-registries": [],
  "debug": false,
  "experimental": false
}
EOF
        
        print_status "Docker daemon配置已更新: $DAEMON_JSON"
        
        # 重启Docker服务
        print_progress "重启Docker服务..."
        systemctl daemon-reload
        systemctl restart docker
        print_status "Docker服务已重启"
        
    else
        print_error "不支持的操作系统: $OS"
        exit 1
    fi
}

# 测试镜像拉取
test_mirror_connection() {
    print_progress "测试镜像加速器连接..."
    
    # 测试拉取一个小镜像
    if docker pull hello-world > /dev/null 2>&1; then
        print_status "镜像加速器配置成功"
        docker rmi hello-world > /dev/null 2>&1 || true
    else
        print_warning "镜像拉取测试失败，可能需要手动重启Docker"
    fi
}

# 显示配置信息
show_configuration() {
    echo ""
    print_info "已配置的镜像加速器:"
    echo "  • 1MS镜像: https://docker.1ms.run"
    echo "  • 腾讯云镜像: https://mirror.ccs.tencentyun.com"
    echo "  • DaoCloud镜像: https://docker.m.daocloud.io"
    echo "  • DockerProxy: https://dockerproxy.com"
    echo "  • 中科大镜像: https://docker.mirrors.ustc.edu.cn"
    echo "  • 网易镜像: https://hub-mirror.c.163.com"
    echo ""
    
    if [ "$OS" = "macos" ]; then
        print_info "macOS用户请手动重启Docker Desktop:"
        echo "  1. 点击Docker Desktop图标"
        echo "  2. 选择 'Restart Docker Desktop'"
        echo "  3. 等待重启完成后继续"
    fi
    
    echo ""
    print_info "配置完成后可以运行以下命令验证:"
    echo "  docker info | grep -A 10 'Registry Mirrors'"
    echo ""
}

# 主函数
main() {
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker服务未运行，请先启动Docker"
        exit 1
    fi
    
    configure_docker_daemon
    
    if [ "$OS" = "linux" ]; then
        # Linux系统可以立即测试
        test_mirror_connection
    fi
    
    show_configuration
    
    print_status "Docker镜像加速器配置完成"
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi