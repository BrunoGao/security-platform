#!/bin/bash

# 强制配置Docker镜像源（适用于OrbStack）
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "🔧 强制配置Docker镜像源"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 尝试多种配置方式
CONFIG_DIRS=(
    "$HOME/.orbstack/config"
    "$HOME/.docker"
    "/etc/docker"
)

MIRROR_CONFIG='{
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
}'

for config_dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$config_dir" ] || [ "$config_dir" = "/etc/docker" ]; then
        if [ "$config_dir" = "/etc/docker" ] && [ "$EUID" -ne 0 ]; then
            print_info "跳过 $config_dir (需要root权限)"
            continue
        fi
        
        mkdir -p "$config_dir" 2>/dev/null || true
        daemon_json="$config_dir/daemon.json"
        
        # 备份现有配置
        if [ -f "$daemon_json" ]; then
            cp "$daemon_json" "$daemon_json.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        fi
        
        # 写入新配置
        echo "$MIRROR_CONFIG" > "$daemon_json" 2>/dev/null && {
            print_status "已更新配置: $daemon_json"
        } || {
            print_warning "无法写入: $daemon_json"
        }
    fi
done

# 尝试通过环境变量设置
print_info "设置Docker环境变量..."
export DOCKER_CONFIG="$HOME/.docker"
mkdir -p "$DOCKER_CONFIG"

# 创建临时的docker pull脚本，直接使用镜像源
print_info "创建临时拉取脚本..."
cat > ./temp_pull_images.sh << 'EOF'
#!/bin/bash

MIRRORS=(
    "https://docker.1ms.run"
    "https://mirror.ccs.tencentyun.com"
    "https://docker.m.daocloud.io"
    "https://dockerproxy.com"
)

IMAGES=(
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

echo "🐳 通过配置的镜像源拉取镜像..."

for image in "${IMAGES[@]}"; do
    echo "拉取 $image..."
    if docker pull "$image" > /dev/null 2>&1; then
        echo "✅ $image 拉取成功"
    else
        echo "⚠️  $image 拉取失败"
    fi
done
EOF

chmod +x ./temp_pull_images.sh

print_status "配置完成！"
print_info "请执行以下步骤："
echo "1. 重启OrbStack应用程序"
echo "2. 运行: ./temp_pull_images.sh"
echo "3. 运行: ./start_app.sh"