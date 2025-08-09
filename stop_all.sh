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
