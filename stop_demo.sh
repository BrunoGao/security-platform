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
