#!/bin/bash

# 简化测试执行脚本
# Simplified Test Execution Script

set -e

echo "🧪 启动安全分析系统验证测试..."

# 检查API服务状态
echo "🔍 检查API服务状态..."
if curl -s http://localhost:8000/health > /dev/null; then
    echo "✅ API服务运行正常"
else
    echo "❌ API服务未运行，请先启动服务"
    exit 1
fi

echo ""
echo "==================== 开始验证测试 ===================="

# 1. 基础功能测试
echo ""
echo "🔬 执行基础功能测试..."
pytest tests/test_security_analysis.py::TestSecurityAnalysisSystem::test_single_event_analysis \
    -v --tb=short --no-cov

# 2. API测试
echo ""
echo "🌐 执行API集成测试..."
pytest tests/test_api_integration.py::TestSecurityAnalysisAPI::test_single_event_analysis \
    -v --tb=short --no-cov

pytest tests/test_api_integration.py::TestSecurityAnalysisAPI::test_health_check_endpoint \
    -v --tb=short --no-cov

# 3. 系统健康检查
echo ""
echo "🏥 执行系统健康检查..."
pytest tests/test_security_analysis.py::TestSecurityAnalysisSystem::test_system_health_check \
    -v --tb=short --no-cov

# 4. 实体识别测试
echo ""
echo "🎯 执行实体识别测试..."
pytest tests/test_security_analysis.py::TestSecurityAnalysisSystem::test_entity_recognition_accuracy \
    -v --tb=short --no-cov

# 5. 响应执行测试  
echo ""
echo "⚡ 执行响应执行测试..."
pytest tests/test_security_analysis.py::TestSecurityAnalysisSystem::test_manual_response_execution \
    -v --tb=short --no-cov

echo ""
echo "==================== 验证测试完成 ===================="

# 生成简单的测试报告
echo ""
echo "📊 测试结果摘要:"
echo "✅ 基础功能测试: 通过"
echo "✅ API集成测试: 通过" 
echo "✅ 健康检查测试: 通过"
echo "✅ 实体识别测试: 通过"
echo "✅ 响应执行测试: 通过"

echo ""
echo "🎉 所有关键功能验证通过！"
echo ""
echo "🎯 系统运行状态："
echo "   - API服务: http://localhost:8000"
echo "   - 健康检查: http://localhost:8000/health"
echo "   - API文档: http://localhost:8000/docs"
echo "   - Kibana: http://localhost:5601"
echo "   - Neo4j: http://localhost:7474"
echo "   - ClickHouse: http://localhost:8123/play"
echo "   - Kafka UI: http://localhost:8082"
echo ""
echo "📋 下一步操作建议："
echo "   1. 访问 http://localhost:8000/docs 查看API文档"
echo "   2. 使用 API 测试工具发送测试请求"
echo "   3. 在 Kibana 中查看分析结果"
echo "   4. 通过 Neo4j 浏览器探索实体关系图"