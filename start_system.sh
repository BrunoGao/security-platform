#!/bin/bash

# 安全分析系统一键启动脚本
# Security Analysis System One-Click Start Script

set -e

echo "🚀 安全告警分析系统 - 一键启动"
echo "Security Alert Analysis System - One-Click Start"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检查系统要求
echo "🔍 检查系统要求..."

# 检查Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker未安装，请先安装Docker"
    exit 1
fi
print_status "Docker已安装"

# 检查Docker Compose  
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose未安装，请先安装Docker Compose"
    exit 1
fi
print_status "Docker Compose已安装"

# 检查Python
if ! command -v python3 &> /dev/null; then
    print_error "Python3未安装，请先安装Python3"
    exit 1
fi
print_status "Python3已安装"

# 检查可用内存
total_memory=$(python3 -c "
import psutil
print(int(psutil.virtual_memory().total / 1024 / 1024 / 1024))
" 2>/dev/null || echo "0")

if [ "$total_memory" -lt 8 ]; then
    print_warning "系统内存少于8GB，可能影响性能"
else
    print_status "系统内存充足: ${total_memory}GB"
fi

echo ""
echo "🏗️  启动基础设施服务..."

# 启动Docker服务
print_info "启动Docker Compose服务..."
docker-compose up -d

# 等待服务启动
echo ""
echo "⏳ 等待服务启动完成..."
sleep 10

# 检查服务状态
services=("elasticsearch" "kibana" "neo4j" "clickhouse" "mysql" "redis" "kafka" "kafka-ui")
failed_services=()

for service in "${services[@]}"; do
    if docker-compose ps | grep -q "$service.*Up"; then
        print_status "$service 服务运行正常"
    else
        print_error "$service 服务启动失败"
        failed_services+=("$service")
    fi
done

if [ ${#failed_services[@]} -gt 0 ]; then
    print_warning "部分服务启动失败: ${failed_services[*]}"
    print_info "继续启动分析系统..."
fi

echo ""
echo "🔧 配置数据库和索引..."

# 配置Elasticsearch
if ./scripts/setup_elasticsearch.sh > setup_es.log 2>&1; then
    print_status "Elasticsearch配置完成"
else
    print_warning "Elasticsearch配置失败，查看 setup_es.log"
fi

# 配置Neo4j
if ./scripts/setup_neo4j.sh > setup_neo4j.log 2>&1; then
    print_status "Neo4j配置完成"
else
    print_warning "Neo4j配置失败，查看 setup_neo4j.log"
fi

# 配置ClickHouse
if ./scripts/setup_clickhouse.sh > setup_clickhouse.log 2>&1; then
    print_status "ClickHouse配置完成"
else
    print_warning "ClickHouse配置失败，查看 setup_clickhouse.log"
fi

# 配置Kafka
if ./scripts/setup_kafka.sh > setup_kafka.log 2>&1; then
    print_status "Kafka配置完成"
else
    print_warning "Kafka配置失败，查看 setup_kafka.log"
fi

# 配置Kibana
if ./scripts/setup_kibana.sh > setup_kibana.log 2>&1; then
    print_status "Kibana配置完成"
else
    print_warning "Kibana配置失败，查看 setup_kibana.log"
fi

echo ""
echo "📦 安装Python依赖..."

# 检查是否在虚拟环境中
if [[ "$VIRTUAL_ENV" == "" ]]; then
    print_warning "建议在虚拟环境中运行"
    print_info "创建虚拟环境: python3 -m venv venv && source venv/bin/activate"
fi

# 安装Python依赖
if pip install -r requirements.txt > pip_install.log 2>&1; then
    print_status "Python依赖安装完成"
else
    print_warning "Python依赖安装失败，查看 pip_install.log"
fi

echo ""
echo "🧪 运行系统验证..."

# 运行系统测试
print_info "运行基础功能测试..."
python test_system.py > system_test.log 2>&1 || {
    print_warning "系统测试失败，查看 system_test.log"
}

echo ""
echo "🌐 启动API服务..."

# 检查端口是否被占用
if lsof -ti:8000 > /dev/null 2>&1; then
    print_warning "端口8000已被占用，尝试停止旧进程..."
    lsof -ti:8000 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

# 启动API服务
print_info "启动FastAPI服务..."
nohup python -m uvicorn src.apis.security_api:app --host 0.0.0.0 --port 8000 > api_service.log 2>&1 &
API_PID=$!

# 等待API服务启动
sleep 5

# 验证API服务
if curl -s http://localhost:8000/health > /dev/null; then
    print_status "API服务启动成功 (PID: $API_PID)"
else
    print_error "API服务启动失败"
    exit 1
fi

echo ""
echo "🎉 系统启动完成！"
echo ""
echo "==================== 系统访问信息 ===================="
echo ""
echo -e "${GREEN}🎯 核心服务${NC}"
echo "   API服务: http://localhost:8000"
echo "   API文档: http://localhost:8000/docs"
echo "   健康检查: http://localhost:8000/health"
echo ""
echo -e "${BLUE}📊 数据分析${NC}"
echo "   Kibana: http://localhost:5601"
echo "   Neo4j浏览器: http://localhost:7474 (neo4j/security123)"
echo "   ClickHouse Play: http://localhost:8123/play (admin/security123)"
echo ""
echo -e "${YELLOW}🔧 管理工具${NC}"
echo "   Kafka UI: http://localhost:8082"
echo ""
echo "==================== 快速测试 ===================="
echo ""
echo -e "${GREEN}📝 测试API接口${NC}"
echo "curl -X POST \"http://localhost:8000/api/v1/analyze/event\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{"
echo "    \"event_type\": \"security_test\","
echo "    \"log_data\": {"
echo "      \"src_ip\": \"192.168.1.100\","
echo "      \"username\": \"test_user\","
echo "      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\""
echo "    }"
echo "  }'"
echo ""
echo -e "${BLUE}🧪 运行验证测试${NC}"
echo "./run_verification.sh"
echo ""
echo "==================== 系统管理 ===================="
echo ""
echo -e "${GREEN}停止系统:${NC} docker-compose down"
echo -e "${GREEN}查看日志:${NC} docker-compose logs -f"
echo -e "${GREEN}重启服务:${NC} docker-compose restart [服务名]"
echo -e "${GREEN}停止API:${NC} kill $API_PID"
echo ""
echo -e "${YELLOW}注意: API服务日志位于 api_service.log${NC}"
echo -e "${YELLOW}其他日志文件: setup_*.log, system_test.log, pip_install.log${NC}"
echo ""
print_status "安全告警分析系统启动完成，开始您的安全分析之旅！"