#!/bin/bash

# Security Alert Analysis System Startup Script
# 安全告警分析系统启动脚本

set -e

echo "🚀 Starting Security Alert Analysis System..."

# 检查Python版本
python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
echo "📋 Python version: $python_version"

# 检查是否在虚拟环境中
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "✅ Running in virtual environment: $VIRTUAL_ENV"
else
    echo "⚠️  Warning: Not running in a virtual environment"
    echo "   It's recommended to use a virtual environment"
fi

# 检查基础设施服务状态
echo "🔍 Checking infrastructure services..."

# 检查Docker Compose服务
if command -v docker-compose &> /dev/null; then
    echo "📊 Checking Docker Compose services..."
    docker-compose ps
    
    # 检查关键服务是否运行
    services=("elasticsearch" "redis" "mysql" "neo4j" "kafka")
    for service in "${services[@]}"; do
        if docker-compose ps | grep -q "$service.*Up"; then
            echo "✅ $service is running"
        else
            echo "❌ $service is not running"
            echo "   Please start it with: docker-compose up -d $service"
        fi
    done
else
    echo "⚠️  Docker Compose not found. Some features may not work."
fi

# 安装依赖
echo "📦 Installing Python dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "❌ requirements.txt not found"
    exit 1
fi

# 设置环境变量
export PYTHONPATH="${PYTHONPATH}:$(pwd)"

# 运行系统测试
echo "🧪 Running system tests..."
python test_system.py

if [ $? -eq 0 ]; then
    echo "✅ System tests passed!"
else
    echo "❌ System tests failed!"
    exit 1
fi

# 启动API服务
echo "🌐 Starting API server..."
echo "   API will be available at: http://localhost:8000"
echo "   API documentation: http://localhost:8000/docs"
echo "   Health check: http://localhost:8000/health"

# 启动FastAPI服务
python -m uvicorn src.apis.security_api:app --host 0.0.0.0 --port 8000 --reload

echo "🎉 Security Alert Analysis System started successfully!"