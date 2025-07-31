#!/bin/bash

# 自动化测试执行脚本
# Automated Test Execution Script

set -e

echo "🧪 启动安全分析系统自动化测试..."

# 检查Python环境
python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
echo "📋 Python版本: $python_version"

# 检查测试依赖
echo "📦 检查测试依赖..."
python -c "import pytest, pytest_asyncio, httpx, psutil" 2>/dev/null || {
    echo "⚠️  安装测试依赖..."
    pip install pytest pytest-asyncio pytest-cov httpx psutil
}

# 确保API服务运行
echo "🔍 检查API服务状态..."
if ! curl -s http://localhost:8000/health > /dev/null; then
    echo "⚠️  API服务未运行，正在启动..."
    nohup python -m uvicorn src.apis.security_api:app --host 0.0.0.0 --port 8000 > api_test.log 2>&1 &
    sleep 5
    
    # 再次检查
    if ! curl -s http://localhost:8000/health > /dev/null; then
        echo "❌ API服务启动失败，请检查日志"
        exit 1
    fi
fi

echo "✅ API服务运行正常"

# 创建测试报告目录
mkdir -p test_reports

# 运行不同类型的测试
echo ""
echo "==================== 开始测试执行 ===================="

# 1. 单元测试
echo ""
echo "🔬 执行单元测试..."
pytest tests/test_security_analysis.py -m "not performance" -v \
    --junitxml=test_reports/unit_tests.xml \
    --html=test_reports/unit_tests.html \
    --self-contained-html || {
    echo "❌ 单元测试失败"
    exit 1
}

# 2. API集成测试  
echo ""
echo "🌐 执行API集成测试..."
pytest tests/test_api_integration.py -m "not performance" -v \
    --junitxml=test_reports/api_tests.xml \
    --html=test_reports/api_tests.html \
    --self-contained-html || {
    echo "❌ API集成测试失败"
    exit 1
}

# 3. 性能测试
echo ""
echo "⚡ 执行性能测试..."
pytest tests/test_security_analysis.py::TestPerformanceBenchmarks -v \
    --junitxml=test_reports/performance_tests.xml \
    --html=test_reports/performance_tests.html \
    --self-contained-html || {
    echo "⚠️  性能测试失败，但继续执行"
}

pytest tests/test_api_integration.py::TestAPIPerformance -v \
    --junitxml=test_reports/api_performance_tests.xml \
    --html=test_reports/api_performance_tests.html \
    --self-contained-html || {
    echo "⚠️  API性能测试失败，但继续执行"
}

# 4. 生成综合测试报告
echo ""
echo "📊 生成综合测试报告..."
python -c "
import json
import xml.etree.ElementTree as ET
from datetime import datetime
import os

def parse_junit_xml(file_path):
    if not os.path.exists(file_path):
        return {'tests': 0, 'failures': 0, 'errors': 0, 'time': 0}
    
    tree = ET.parse(file_path)
    root = tree.getroot()
    
    return {
        'tests': int(root.get('tests', 0)),
        'failures': int(root.get('failures', 0)),
        'errors': int(root.get('errors', 0)),
        'time': float(root.get('time', 0))
    }

# 解析测试结果
results = {
    'unit_tests': parse_junit_xml('test_reports/unit_tests.xml'),
    'api_tests': parse_junit_xml('test_reports/api_tests.xml'),
    'performance_tests': parse_junit_xml('test_reports/performance_tests.xml'),
    'api_performance_tests': parse_junit_xml('test_reports/api_performance_tests.xml'),
}

# 计算总体统计
total_tests = sum(r['tests'] for r in results.values())
total_failures = sum(r['failures'] for r in results.values())
total_errors = sum(r['errors'] for r in results.values())
total_time = sum(r['time'] for r in results.values())

# 生成报告
report = {
    'timestamp': datetime.now().isoformat(),
    'summary': {
        'total_tests': total_tests,
        'passed': total_tests - total_failures - total_errors,
        'failures': total_failures,
        'errors': total_errors,
        'success_rate': ((total_tests - total_failures - total_errors) / total_tests * 100) if total_tests > 0 else 0,
        'total_time': total_time
    },
    'details': results
}

# 保存报告
with open('test_reports/summary.json', 'w', encoding='utf-8') as f:
    json.dump(report, f, indent=2, ensure_ascii=False)

print('✅ 测试报告已生成')
"

# 5. 显示测试结果摘要
echo ""
echo "==================== 测试结果摘要 ===================="
python -c "
import json
import os

if os.path.exists('test_reports/summary.json'):
    with open('test_reports/summary.json', 'r', encoding='utf-8') as f:
        report = json.load(f)
    
    summary = report['summary']
    print(f'📊 总测试数: {summary[\"total_tests\"]}')
    print(f'✅ 通过: {summary[\"passed\"]}')
    print(f'❌ 失败: {summary[\"failures\"]}')
    print(f'🚫 错误: {summary[\"errors\"]}')
    print(f'📈 成功率: {summary[\"success_rate\"]:.1f}%')
    print(f'⏱️  总耗时: {summary[\"total_time\"]:.2f}秒')
    
    if summary['failures'] == 0 and summary['errors'] == 0:
        print('🎉 所有测试通过！')
        exit(0)
    else:
        print('⚠️  部分测试失败，请查看详细报告')
        exit(1)
else:
    print('❌ 无法生成测试摘要')
    exit(1)
"

echo ""
echo "📁 测试报告位置:"
echo "   - 单元测试: test_reports/unit_tests.html"
echo "   - API测试: test_reports/api_tests.html"
echo "   - 性能测试: test_reports/performance_tests.html"
echo "   - 综合报告: test_reports/summary.json"
echo ""
echo "🎯 测试执行完成！"