"""
安全分析系统全面测试用例
Comprehensive Test Cases for Security Analysis System
"""

import pytest
import asyncio
import json
import time
from datetime import datetime
from typing import Dict, Any, List

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.services.security_analysis_service import create_security_analysis_service
from src.models.entities import EntityType, ThreatLevel
from src.engines.response_executor import ResponseAction


class TestSecurityAnalysisSystem:
    """安全分析系统测试类"""

    @pytest.fixture
    def analysis_service(self):
        """创建分析服务实例"""
        config = {
            'processing_config': {
                'enable_connection_expansion': True,
                'enable_risk_scoring': True,
                'enable_auto_response': True,
                'max_concurrent_processing': 5,
                'min_risk_threshold_for_response': 50.0
            }
        }
        return create_security_analysis_service(config)

    @pytest.fixture
    def sample_events(self) -> List[Dict[str, Any]]:
        """测试事件数据"""
        return [
            {
                "event_type": "malware_detection",
                "log_data": {
                    "process_name": "malware.exe",
                    "process_path": "C:\\temp\\malware.exe",
                    "file_hash": "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678",
                    "username": "victim_user",
                    "src_ip": "192.168.1.50",
                    "timestamp": datetime.now().isoformat(),
                    "is_anomaly": True,
                    "anomaly_type": "malware_execution",
                    "command_line": "malware.exe -c http://c2.malicious.com/beacon",
                    "parent_process": "explorer.exe"
                }
            },
            {
                "event_type": "privilege_escalation",
                "log_data": {
                    "username": "standard_user",
                    "elevated_to": "admin",
                    "process_name": "cmd.exe",
                    "command_line": "net user administrator newpassword123",
                    "src_ip": "10.0.0.25",
                    "timestamp": datetime.now().isoformat(),
                    "is_anomaly": True,
                    "anomaly_type": "unauthorized_privilege_escalation",
                    "success": True
                }
            },
            {
                "event_type": "data_exfiltration",
                "log_data": {
                    "src_ip": "192.168.100.50",
                    "dst_ip": "45.67.89.123",
                    "username": "finance_user",
                    "file_path": "C:\\Finance\\sensitive_data.xlsx",
                    "bytes_transferred": 52428800,  # 50MB
                    "protocol": "HTTPS",
                    "destination": "external-storage.suspicious.com",
                    "timestamp": datetime.now().isoformat(),
                    "is_anomaly": True,
                    "anomaly_type": "large_data_transfer"
                }
            },
            {
                "event_type": "brute_force_attack",
                "log_data": {
                    "src_ip": "203.45.67.89",
                    "dst_ip": "192.168.1.10",
                    "username": "administrator",
                    "failed_attempts": 150,
                    "time_window": 300,  # 5 minutes
                    "protocol": "RDP",
                    "timestamp": datetime.now().isoformat(),
                    "is_anomaly": True,
                    "anomaly_type": "brute_force_login"
                }
            },
            {
                "event_type": "dns_tunneling",
                "log_data": {
                    "src_ip": "192.168.1.200",
                    "domain": "a1b2c3d4e5f6789012345678.malicious-tunnel.com",
                    "query_type": "TXT",
                    "response_size": 1024,
                    "frequency": 50,  # queries per minute
                    "timestamp": datetime.now().isoformat(),
                    "is_anomaly": True,
                    "anomaly_type": "dns_tunneling",
                    "username": "compromised_user"
                }
            },
            {
                "event_type": "lateral_movement",
                "log_data": {
                    "src_ip": "192.168.1.100",
                    "dst_ip": "192.168.1.150",
                    "username": "admin",
                    "process_name": "psexec.exe",
                    "command_line": "psexec \\\\192.168.1.150 -u domain\\admin -p password cmd.exe",
                    "timestamp": datetime.now().isoformat(),
                    "is_anomaly": True,
                    "anomaly_type": "remote_execution",
                    "protocol": "SMB"
                }
            }
        ]

    # 1. 基础功能测试
    @pytest.mark.asyncio
    async def test_single_event_analysis(self, analysis_service, sample_events):
        """测试单个事件分析"""
        event = sample_events[0]  # 恶意软件检测事件
        
        result = await analysis_service.analyze_security_event(
            log_data=event["log_data"],
            event_type=event["event_type"]
        )
        
        # 验证分析结果
        assert result["status"] == "completed"
        assert "event_id" in result
        assert result["summary"]["entities_extracted"] > 0
        assert result["summary"]["max_risk_score"] > 0
        assert len(result["entities"]) > 0
        
        # 验证实体类型
        entity_types = [entity["entity_type"] for entity in result["entities"]]
        assert "file" in entity_types or "process" in entity_types
        assert "user" in entity_types
        assert "ip" in entity_types

    @pytest.mark.asyncio
    async def test_batch_event_analysis(self, analysis_service, sample_events):
        """测试批量事件分析"""
        events_data = [event["log_data"] for event in sample_events]
        
        results = await analysis_service.batch_analyze_events(events_data)
        
        # 验证批量处理结果
        assert len(results) == len(sample_events)
        successful_results = [r for r in results if r.get("status") == "completed"]
        assert len(successful_results) > 0
        
        # 统计总体分析结果
        total_entities = sum(r.get("summary", {}).get("entities_extracted", 0) for r in results)
        assert total_entities > 0

    # 2. 实体识别测试
    @pytest.mark.asyncio
    async def test_entity_recognition_accuracy(self, analysis_service):
        """测试实体识别准确性"""
        complex_event = {
            "src_ip": "192.168.1.100",
            "dst_ip": "45.67.89.123",
            "username": "john.doe",
            "email": "john.doe@company.com",
            "file_path": "C:\\Users\\john.doe\\malware.exe",
            "file_hash": "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456", 
            "process_name": "powershell.exe",
            "domain": "malicious.com",
            "url": "https://malicious.com/payload.php",
            "timestamp": datetime.now().isoformat()
        }
        
        entities = analysis_service.entity_recognizer.extract_entities(complex_event, "test-event")
        
        # 验证实体识别覆盖率
        entity_types = [entity.entity_type.value for entity in entities]
        expected_types = ["ip", "user", "email", "file", "process", "domain", "url", "hash"]
        
        for expected_type in expected_types:
            assert expected_type in entity_types, f"Missing entity type: {expected_type}"

    # 3. 风险评分测试
    @pytest.mark.asyncio
    async def test_risk_scoring_levels(self, analysis_service):
        """测试风险评分等级"""
        # 高风险事件
        high_risk_event = {
            "process_name": "mimikatz.exe",
            "file_hash": "known_malware_hash",
            "src_ip": "192.168.1.100",
            "dst_ip": "suspicious_c2_server.com",
            "username": "compromised_admin",
            "command_line": "mimikatz.exe privilege::debug sekurlsa::logonpasswords",
            "is_anomaly": True,
            "anomaly_type": "credential_dumping"
        }
        
        result = await analysis_service.analyze_security_event(high_risk_event, "high_risk_test")
        
        # 验证高风险评分
        assert result["summary"]["max_risk_score"] > 30  # 应该触发中等以上风险
        
        # 验证威胁等级分布
        high_risk_entities = [e for e in result["entities"] if e["threat_level"] in ["高风险", "极高风险"]]
        medium_risk_entities = [e for e in result["entities"] if e["threat_level"] == "中风险"]
        
        assert len(high_risk_entities) > 0 or len(medium_risk_entities) > 0

    # 4. 响应执行测试
    @pytest.mark.asyncio
    async def test_automated_response_execution(self, analysis_service):
        """测试自动化响应执行"""
        # 创建会触发自动响应的高风险事件
        high_risk_event = {
            "src_ip": "malicious_ip_address",
            "process_name": "ransomware.exe",
            "file_hash": "known_ransomware_hash",
            "username": "victim_user",
            "url": "http://c2.ransomware.com/encrypt",
            "is_anomaly": True,
            "anomaly_type": "ransomware_execution",
            "threat_intel": True,
            "malicious": True
        }
        
        result = await analysis_service.analyze_security_event(high_risk_event, "response_test")
        
        # 如果风险分数足够高，应该触发自动响应
        if result["summary"]["max_risk_score"] >= 50:
            assert result["summary"]["responses_executed"] > 0
            assert len(result["response_results"]) > 0

    @pytest.mark.asyncio
    async def test_manual_response_execution(self, analysis_service):
        """测试手动响应执行"""
        # 测试IP封堵响应
        ip_responses = await analysis_service.manual_response_execution(
            entity_id="192.168.1.100",
            entity_type="ip",
            actions=["block_ip", "monitor_ip"]
        )
        
        assert len(ip_responses) == 2
        assert all(response.get("status") == "执行成功" for response in ip_responses)
        
        # 测试用户响应
        user_responses = await analysis_service.manual_response_execution(
            entity_id="suspicious_user",
            entity_type="user", 
            actions=["disable_user", "reset_password"]
        )
        
        assert len(user_responses) == 2
        assert all(response.get("status") == "执行成功" for response in user_responses)

    # 5. 性能测试
    @pytest.mark.asyncio
    async def test_concurrent_processing_performance(self, analysis_service, sample_events):
        """测试并发处理性能"""
        # 准备大量测试事件
        large_event_set = sample_events * 10  # 60个事件
        events_data = [event["log_data"] for event in large_event_set]
        
        start_time = time.time()
        results = await analysis_service.batch_analyze_events(events_data)
        end_time = time.time()
        
        processing_time = end_time - start_time
        
        # 验证性能指标
        assert len(results) == len(large_event_set)
        assert processing_time < 30  # 应该在30秒内完成
        
        # 计算吞吐量
        throughput = len(large_event_set) / processing_time
        assert throughput > 1  # 每秒至少处理1个事件

    @pytest.mark.asyncio 
    async def test_processing_timeout_handling(self, analysis_service):
        """测试处理超时处理"""
        # 创建可能导致超时的复杂事件
        complex_events = []
        for i in range(100):
            complex_events.append({
                f"field_{j}": f"value_{i}_{j}" for j in range(50)
            })
        
        # 设置较短的超时时间进行测试
        original_timeout = analysis_service.processing_config['processing_timeout']
        analysis_service.processing_config['processing_timeout'] = 5  # 5秒超时
        
        try:
            results = await analysis_service.batch_analyze_events(complex_events)
            # 应该能处理超时情况
            assert isinstance(results, list)
        finally:
            # 恢复原始超时设置
            analysis_service.processing_config['processing_timeout'] = original_timeout

    # 6. 错误处理测试
    @pytest.mark.asyncio
    async def test_invalid_event_handling(self, analysis_service):
        """测试无效事件处理"""
        # 测试空事件
        empty_result = await analysis_service.analyze_security_event({}, "empty_test")
        assert empty_result["status"] in ["completed", "error"]
        
        # 测试格式错误事件
        invalid_result = await analysis_service.analyze_security_event(
            {"invalid_field": None}, "invalid_test"
        )
        assert invalid_result["status"] in ["completed", "error"]

    # 7. 系统状态测试
    @pytest.mark.asyncio
    async def test_system_health_check(self, analysis_service):
        """测试系统健康检查"""
        health_status = await analysis_service.health_check()
        
        assert health_status["service"] == "healthy"
        assert "components" in health_status
        assert "statistics" in health_status
        
        # 验证各组件状态
        components = health_status["components"]
        expected_components = [
            "entity_recognizer", "connection_engine", 
            "risk_scoring_engine", "response_orchestrator"
        ]
        
        for component in expected_components:
            assert component in components
            assert components[component] == "healthy"

    @pytest.mark.asyncio
    async def test_system_statistics(self, analysis_service, sample_events):
        """测试系统统计功能"""
        # 先处理一些事件生成统计数据
        for event in sample_events[:3]:
            await analysis_service.analyze_security_event(
                event["log_data"], event["event_type"]
            )
        
        stats = analysis_service.get_processing_statistics()
        
        assert "statistics" in stats
        assert "configuration" in stats
        
        # 验证统计数据
        statistics = stats["statistics"]
        assert statistics["total_events_processed"] >= 3
        assert statistics["total_entities_extracted"] > 0
        assert statistics["average_processing_time"] >= 0

    # 8. 配置管理测试
    def test_configuration_update(self, analysis_service):
        """测试配置更新"""
        original_config = analysis_service.get_processing_statistics()["configuration"].copy()
        
        # 更新配置
        new_config = {
            "max_concurrent_processing": 20,
            "min_risk_threshold_for_response": 75.0
        }
        
        analysis_service.update_configuration(new_config)
        
        # 验证配置更新
        updated_stats = analysis_service.get_processing_statistics()
        updated_config = updated_stats["configuration"]
        
        assert updated_config["max_concurrent_processing"] == 20
        assert updated_config["min_risk_threshold_for_response"] == 75.0

    # 9. 边界条件测试
    @pytest.mark.asyncio
    async def test_extreme_entity_counts(self, analysis_service):
        """测试极端实体数量处理"""
        # 创建包含大量实体的事件
        massive_event = {}
        for i in range(100):
            massive_event[f"ip_{i}"] = f"192.168.1.{i}"
            massive_event[f"user_{i}"] = f"user{i}"
            massive_event[f"file_{i}"] = f"C:\\temp\\file{i}.exe"
        
        result = await analysis_service.analyze_security_event(massive_event, "massive_test")
        
        # 系统应该能处理大量实体而不崩溃
        assert result["status"] in ["completed", "error"]
        if result["status"] == "completed":
            assert result["summary"]["entities_extracted"] > 0

    @pytest.mark.asyncio
    async def test_unicode_and_special_characters(self, analysis_service):
        """测试Unicode和特殊字符处理"""
        unicode_event = {
            "username": "用户名测试",
            "file_path": "C:\\测试\\文件.exe",
            "domain": "测试域名.com",
            "command": "echo 'Special chars: !@#$%^&*()'"
        }
        
        result = await analysis_service.analyze_security_event(unicode_event, "unicode_test")
        
        # 系统应该能正确处理Unicode字符
        assert result["status"] == "completed"


# 性能基准测试
class TestPerformanceBenchmarks:
    """性能基准测试"""
    
    @pytest.fixture
    def benchmark_service(self):
        """性能测试专用服务配置"""
        config = {
            'processing_config': {
                'enable_connection_expansion': True,
                'enable_risk_scoring': True,
                'enable_auto_response': False,  # 关闭自动响应以专注测试分析性能
                'max_concurrent_processing': 10
            }
        }
        return create_security_analysis_service(config)

    @pytest.mark.asyncio
    async def test_throughput_benchmark(self, benchmark_service):
        """吞吐量基准测试"""
        # 生成标准测试事件
        standard_events = []
        for i in range(50):
            standard_events.append({
                "src_ip": f"192.168.1.{i}",
                "dst_ip": f"10.0.0.{i}",
                "username": f"user{i}",
                "timestamp": datetime.now().isoformat()
            })
        
        start_time = time.time()
        results = await benchmark_service.batch_analyze_events(standard_events)
        end_time = time.time()
        
        processing_time = end_time - start_time
        throughput = len(standard_events) / processing_time
        
        print(f"\n性能基准测试结果:")
        print(f"事件数量: {len(standard_events)}")
        print(f"处理时间: {processing_time:.2f}秒")
        print(f"吞吐量: {throughput:.2f} 事件/秒")
        
        # 基准要求：每秒至少处理5个事件
        assert throughput >= 5.0

    @pytest.mark.asyncio
    async def test_memory_usage_stability(self, benchmark_service):
        """内存使用稳定性测试"""
        import psutil
        import os
        
        process = psutil.Process(os.getpid())
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        # 处理大量事件测试内存稳定性
        for batch in range(10):
            events = [{"src_ip": f"192.168.{batch}.{i}", "username": f"user{i}"} 
                     for i in range(20)]
            await benchmark_service.batch_analyze_events(events)
        
        final_memory = process.memory_info().rss / 1024 / 1024  # MB
        memory_growth = final_memory - initial_memory
        
        print(f"\n内存使用情况:")
        print(f"初始内存: {initial_memory:.2f} MB")
        print(f"最终内存: {final_memory:.2f} MB")
        print(f"内存增长: {memory_growth:.2f} MB")
        
        # 内存增长不应超过100MB
        assert memory_growth < 100


if __name__ == "__main__":
    # 运行测试
    pytest.main([__file__, "-v", "--tb=short"])