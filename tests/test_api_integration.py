"""
API端点集成测试
API Integration Tests
"""

import pytest
import httpx
import asyncio
import json
from datetime import datetime


class TestSecurityAnalysisAPI:
    """安全分析API集成测试"""
    
    BASE_URL = "http://localhost:8000"
    
    @pytest.fixture
    def client(self):
        """HTTP客户端"""
        return httpx.Client(base_url=self.BASE_URL)
    
    @pytest.fixture
    def sample_event_data(self):
        """示例事件数据"""
        return {
            "event_type": "security_alert",
            "log_data": {
                "src_ip": "192.168.1.100",
                "dst_ip": "103.45.67.89",
                "username": "test_user",
                "timestamp": datetime.now().isoformat(),
                "is_anomaly": True,
                "anomaly_type": "suspicious_activity"
            }
        }
    
    def test_health_check_endpoint(self, client):
        """测试健康检查端点"""
        response = client.get("/health")
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["service"] == "healthy"
        assert "components" in data
        assert "statistics" in data
        
        # 验证组件状态
        components = data["components"]
        expected_components = [
            "entity_recognizer", "connection_engine",
            "risk_scoring_engine", "response_orchestrator"
        ]
        
        for component in expected_components:
            assert component in components
            assert components[component] == "healthy"
    
    def test_root_endpoint(self, client):
        """测试根端点"""
        response = client.get("/")
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["service"] == "Security Alert Analysis System"
        assert data["version"] == "1.0.0"
        assert data["status"] == "running"
    
    def test_single_event_analysis(self, client, sample_event_data):
        """测试单个事件分析端点"""
        response = client.post("/api/v1/analyze/event", json=sample_event_data)
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["success"] is True
        assert "data" in data
        
        analysis_result = data["data"]
        assert analysis_result["status"] == "completed"
        assert "event_id" in analysis_result
        assert analysis_result["summary"]["entities_extracted"] > 0
        assert len(analysis_result["entities"]) > 0
    
    def test_batch_event_analysis(self, client, sample_event_data):
        """测试批量事件分析端点"""
        batch_data = {
            "events": [
                sample_event_data,
                {
                    "event_type": "file_access", 
                    "log_data": {
                        "username": "admin",
                        "file_path": "/etc/passwd",
                        "action": "read",
                        "timestamp": datetime.now().isoformat()
                    }
                },
                {
                    "event_type": "network_connection",
                    "log_data": {
                        "src_ip": "10.0.0.1",
                        "dst_ip": "8.8.8.8",
                        "port": 443,
                        "protocol": "HTTPS",
                        "timestamp": datetime.now().isoformat()
                    }
                }
            ]
        }
        
        response = client.post("/api/v1/analyze/batch", json=batch_data)
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["success"] is True
        assert data["data"]["total_events"] == 3
        assert len(data["data"]["results"]) == 3
        
        # 验证每个结果
        for result in data["data"]["results"]:
            assert result["status"] == "completed"
    
    def test_manual_response_execution(self, client):
        """测试手动响应执行端点"""
        response_data = {
            "entity_id": "192.168.1.100",
            "entity_type": "ip",
            "actions": ["block_ip", "send_alert"]
        }
        
        response = client.post("/api/v1/response/manual", json=response_data)
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["success"] is True
        assert data["data"]["entity_id"] == "192.168.1.100"
        assert data["data"]["actions_executed"] == 2
        assert len(data["data"]["results"]) == 2
    
    def test_statistics_endpoint(self, client):
        """测试统计信息端点"""
        response = client.get("/api/v1/statistics")
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["success"] is True
        assert "statistics" in data["data"]
        assert "configuration" in data["data"]
        
        # 验证统计字段
        stats = data["data"]["statistics"]
        expected_stats = [
            "total_events_processed", "total_entities_extracted",
            "total_connections_expanded", "total_responses_executed",
            "average_processing_time"
        ]
        
        for stat in expected_stats:
            assert stat in stats
            assert isinstance(stats[stat], (int, float))
    
    def test_configuration_endpoints(self, client):
        """测试配置管理端点"""
        # 获取当前配置
        get_response = client.get("/api/v1/config")
        assert get_response.status_code == 200
        
        current_config = get_response.json()["data"]["configuration"]
        assert isinstance(current_config, dict)
        
        # 更新配置
        new_config = {
            "config": {
                "max_concurrent_processing": 15,
                "min_risk_threshold_for_response": 60.0
            }
        }
        
        update_response = client.post("/api/v1/config", json=new_config)
        assert update_response.status_code == 200
        
        update_data = update_response.json()
        assert update_data["success"] is True
        assert "Configuration updated successfully" in update_data["message"]
    
    def test_sample_data_endpoint(self, client):
        """测试示例数据端点"""
        response = client.get("/api/v1/test/sample-data")
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["success"] is True
        assert "sample_events" in data["data"]
        assert len(data["data"]["sample_events"]) > 0
        
        # 验证示例事件格式
        sample_event = data["data"]["sample_events"][0]
        assert "event_type" in sample_event
        assert "log_data" in sample_event
    
    def test_entity_details_endpoint(self, client):
        """测试实体详情端点"""
        # 先分析一个事件创建实体
        sample_event = {
            "event_type": "test_event",
            "log_data": {
                "src_ip": "192.168.1.200",
                "username": "test_entity_user",
                "timestamp": datetime.now().isoformat()
            }
        }
        
        # 分析事件
        analyze_response = client.post("/api/v1/analyze/event", json=sample_event)
        assert analyze_response.status_code == 200
        
        # 获取实体详情
        response = client.get("/api/v1/entity/192.168.1.200?entity_type=ip")
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["success"] is True
        assert data["data"]["entity_id"] == "192.168.1.200"
        assert data["data"]["entity_type"] == "ip"
    
    def test_error_handling(self, client):
        """测试错误处理"""
        # 测试无效JSON
        response = client.post(
            "/api/v1/analyze/event",
            content="invalid json",
            headers={"Content-Type": "application/json"}
        )
        assert response.status_code == 422
        
        # 测试缺少必需字段
        invalid_event = {
            "event_type": "test",
            # 缺少 log_data 字段
        }
        
        response = client.post("/api/v1/analyze/event", json=invalid_event)
        assert response.status_code == 422
        
        # 测试不存在的实体
        response = client.get("/api/v1/entity/nonexistent?entity_type=ip")
        assert response.status_code == 404
    
    def test_concurrent_requests(self, client, sample_event_data):
        """测试并发请求处理"""
        import concurrent.futures
        import time
        
        def make_request():
            return client.post("/api/v1/analyze/event", json=sample_event_data)
        
        # 并发发送10个请求
        start_time = time.time()
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            responses = [future.result() for future in futures]
        end_time = time.time()
        
        # 验证所有请求都成功
        assert all(response.status_code == 200 for response in responses)
        
        # 验证响应时间合理
        total_time = end_time - start_time
        assert total_time < 30  # 所有请求应在30秒内完成
        
        print(f"\n并发测试结果: 10个请求用时 {total_time:.2f} 秒")


class TestAPIPerformance:
    """API性能测试"""
    
    BASE_URL = "http://localhost:8000"
    
    @pytest.fixture
    def async_client(self):
        """异步HTTP客户端"""
        return httpx.AsyncClient(base_url=self.BASE_URL)
    
    @pytest.mark.asyncio
    async def test_api_response_time(self, async_client):
        """测试API响应时间"""
        import time
        
        sample_event = {
            "event_type": "performance_test",
            "log_data": {
                "src_ip": "192.168.1.100",
                "username": "perf_user",
                "timestamp": datetime.now().isoformat()
            }
        }
        
        # 测试单个请求响应时间
        start_time = time.time()
        response = await async_client.post("/api/v1/analyze/event", json=sample_event)
        end_time = time.time()
        
        response_time = end_time - start_time
        
        assert response.status_code == 200
        assert response_time < 5.0  # 单个请求应在5秒内完成
        
        print(f"\nAPI响应时间: {response_time:.3f} 秒")
    
    @pytest.mark.asyncio
    async def test_api_throughput(self, async_client):
        """测试API吞吐量"""
        import time
        
        # 准备测试数据
        events = []
        for i in range(20):
            events.append({
                "event_type": "throughput_test",
                "log_data": {
                    "src_ip": f"192.168.1.{i}",
                    "username": f"user{i}",
                    "timestamp": datetime.now().isoformat()
                }
            })
        
        # 并发发送请求
        start_time = time.time()
        tasks = []
        for event in events:
            task = async_client.post("/api/v1/analyze/event", json=event)
            tasks.append(task)
        
        responses = await asyncio.gather(*tasks)
        end_time = time.time()
        
        # 计算吞吐量
        total_time = end_time - start_time
        throughput = len(events) / total_time
        
        # 验证结果
        assert all(response.status_code == 200 for response in responses)
        assert throughput > 2.0  # 每秒至少处理2个请求
        
        print(f"\nAPI吞吐量测试:")
        print(f"请求数量: {len(events)}")
        print(f"总耗时: {total_time:.2f} 秒")
        print(f"吞吐量: {throughput:.2f} 请求/秒")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])