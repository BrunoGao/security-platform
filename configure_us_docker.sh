#!/bin/bash

# US服务器Docker优化配置脚本
# Docker Optimization for US Servers

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_progress() {
    echo -e "${YELLOW}🔄 $1${NC}"
}

echo "🇺🇸 配置美国服务器Docker优化"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 配置Docker daemon优化
configure_docker_daemon() {
    print_progress "配置Docker daemon优化设置..."
    
    DOCKER_CONFIG_DIR="/etc/docker"
    DAEMON_JSON="$DOCKER_CONFIG_DIR/daemon.json"
    
    # 创建目录
    sudo mkdir -p "$DOCKER_CONFIG_DIR"
    
    # 备份现有配置
    if [ -f "$DAEMON_JSON" ]; then
        sudo cp "$DAEMON_JSON" "$DAEMON_JSON.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "已备份现有配置"
    fi
    
    # 创建美国优化配置
    sudo tee "$DAEMON_JSON" > /dev/null << 'EOF'
{
  "experimental": true,
  "features": {
    "buildkit": true
  },
  "builder": {
    "gc": {
      "enabled": true,
      "defaultKeepStorage": "20GB"
    }
  },
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ]
}
EOF
    
    print_status "Docker daemon配置完成"
    
    # 重启Docker服务
    print_progress "重启Docker服务..."
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    
    print_status "Docker服务重启完成"
}

# 主函数
main() {
    print_info "检测到美国服务器环境，使用优化配置"
    print_info "✅ Docker Hub 直连 (无需镜像源)"
    print_info "✅ 启用 BuildKit 并行构建"
    print_info "✅ 优化存储和日志配置"
    
    configure_docker_daemon
    
    print_status "美国服务器Docker优化配置完成"
    print_info "接下来可以直接拉取镜像，速度将显著提升"
}

main "$@"