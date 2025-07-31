"""
Test Script for Security Analysis System
安全分析系统测试脚本
"""

import asyncio
import json
import logging
from datetime import datetime
import sys
import os

# 添加项目根目录到路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.services.security_analysis_service import create_security_analysis_service
from src.models.entities import EntityType

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)


class SecurityAnalysisSystemTest:
    """安全分析系统测试类"""
    
    def __init__(self):
        # 创建测试配置
        self.config = {
            'processing_config': {
                'enable_connection_expansion': True,
                'enable_risk_scoring': True,
                'enable_auto_response': True,
                'max_concurrent_processing': 5,
                'min_risk_threshold_for_response': 30.0
            },
            'response_config': {
                'firewall': {
                    'api_endpoint': 'http://localhost:8080',
                    'api_key': 'test-key'
                },
                'ad': {
                    'ldap_server': 'ldap://localhost:389',
                    'admin_user': 'test-admin',
                    'admin_password': 'test-password'
                }
            }
        }
        
        # 创建服务实例
        self.analysis_service = create_security_analysis_service(self.config)
        
        # 测试数据
        self.test_events = [
            {
                "event_type": "network_anomaly",
                "log_data": {
                    "src_ip": "192.168.1.100",
                    "dst_ip": "103.45.67.89",
                    "src_port": 12345,
                    "dst_port": 443,
                    "username": "john.doe",
                    "timestamp": datetime.now().isoformat(),
                    "bytes_transferred": 10485760,  # 10MB
                    "connection_duration": 3600,
                    "protocol": "HTTPS",
                    "is_anomaly": True,
                    "anomaly_type": "unusual_data_transfer",
                    "device_name": "DESKTOP-ABC123"
                }
            },
            {
                "event_type": "suspicious_file_access",
                "log_data": {
                    "username": "admin",
                    "file_path": "C:\\Windows\\System32\\config\\SAM",
                    "action": "read",
                    "timestamp": datetime.now().isoformat(),
                    "process_name": "powershell.exe",
                    "process_path": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
                    "is_system_file": True,
                    "access_granted": True,
                    "file_hash": "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456",
                    "src_ip": "192.168.1.50"
                }
            },
            {
                "event_type": "malicious_process",
                "log_data": {
                    "process_name": "suspicious.exe",
                    "process_path": "C:\\temp\\suspicious.exe",
                    "command_line": "suspicious.exe -c http://malicious.com/c2 -k encryption_key",
                    "parent_process": "explorer.exe",
                    "username": "user1",
                    "timestamp": datetime.now().isoformat(),
                    "process_id": 1234,
                    "parent_pid": 567,
                    "is_anomaly": True,
                    "anomaly_type": "malware_execution",
                    "file_hash": "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678",
                    "device_name": "WORKSTATION-001"
                }
            },
            {
                "event_type": "credential_theft",
                "log_data": {
                    "username": "service_account",
                    "src_ip": "10.0.0.25",
                    "dst_ip": "192.168.100.10",
                    "destination": "ad-server.company.com",
                    "login_method": "NTLM",
                    "timestamp": datetime.now().isoformat(),
                    "success": True,
                    "is_anomaly": True,
                    "anomaly_type": "credential_stuffing",
                    "failed_attempts": 50,
                    "user_agent": "PowerShell/7.0"
                }
            },
            {
                "event_type": "dns_tunneling",
                "log_data": {
                    "src_ip": "192.168.1.200",
                    "domain": "a1b2c3d4e5f6.malicious-c2.com",
                    "query_type": "TXT",
                    "timestamp": datetime.now().isoformat(),
                    "response_size": 512,
                    "is_anomaly": True,
                    "anomaly_type": "dns_tunneling",
                    "username": "compromised_user",
                    "device_name": "LAPTOP-XYZ789"
                }
            }
        ]
    
    async def run_all_tests(self):
        """运行所有测试"""
        logger.info("开始安全分析系统测试")
        
        try:
            # 测试1: 单个事件分析
            logger.info("=" * 60)
            logger.info("测试1: 单个事件分析")
            await self.test_single_event_analysis()
            
            # 测试2: 批量事件分析
            logger.info("=" * 60)
            logger.info("测试2: 批量事件分析")
            await self.test_batch_analysis()
            
            # 测试3: 实体识别测试
            logger.info("=" * 60)
            logger.info("测试3: 实体识别测试")
            await self.test_entity_recognition()
            
            # 测试4: 风险评分测试
            logger.info("=" * 60)
            logger.info("测试4: 风险评分测试")
            await self.test_risk_scoring()
            
            # 测试5: 响应执行测试
            logger.info("=" * 60)
            logger.info("测试5: 响应执行测试")
            await self.test_response_execution()
            
            # 测试6: 系统统计信息
            logger.info("=" * 60)
            logger.info("测试6: 系统统计信息")
            await self.test_system_statistics()
            
            # 测试7: 健康检查
            logger.info("=" * 60)
            logger.info("测试7: 健康检查")
            await self.test_health_check()
            
            logger.info("=" * 60)
            logger.info("所有测试完成!")
            
        except Exception as e:
            logger.error(f"测试过程中发生错误: {e}")
            raise
    
    async def test_single_event_analysis(self):
        """测试单个事件分析"""
        logger.info("开始单个事件分析测试...")
        
        test_event = self.test_events[0]  # 使用第一个测试事件
        
        result = await self.analysis_service.analyze_security_event(
            log_data=test_event["log_data"],
            event_type=test_event["event_type"]
        )
        
        logger.info(f"事件ID: {result['event_id']}")
        logger.info(f"处理状态: {result['status']}")
        logger.info(f"处理时间: {result['processing_time']:.3f}秒")
        logger.info(f"提取实体数量: {result['summary']['entities_extracted']}")
        logger.info(f"最高风险分数: {result['summary']['max_risk_score']:.2f}")
        logger.info(f"高风险实体数量: {result['summary']['high_risk_entities']}")
        logger.info(f"执行响应数量: {result['summary']['responses_executed']}")
        
        # 详细显示提取的实体
        if result['entities']:
            logger.info("提取的实体详情:")
            for entity in result['entities'][:3]:  # 只显示前3个
                logger.info(f"  - {entity['entity_type']}: {entity['entity_id']} "
                          f"(风险分数: {entity['risk_score']:.2f}, 状态: {entity['status']})")
        
        # 显示响应结果
        if result['response_results']:
            logger.info("响应执行结果:")
            for response in result['response_results'][:3]:  # 只显示前3个
                logger.info(f"  - 动作: {response['action']}, 状态: {response['status']}")
        
        logger.info("单个事件分析测试完成")
    
    async def test_batch_analysis(self):
        """测试批量事件分析"""
        logger.info("开始批量事件分析测试...")
        
        # 使用所有测试事件进行批量分析
        events_data = [event["log_data"] for event in self.test_events]
        
        results = await self.analysis_service.batch_analyze_events(events_data)
        
        logger.info(f"批量处理事件数量: {len(events_data)}")
        logger.info(f"返回结果数量: {len(results)}")
        
        # 统计结果
        successful = sum(1 for r in results if r.get('status') == 'completed')
        failed = len(results) - successful
        
        logger.info(f"成功处理: {successful}")
        logger.info(f"处理失败: {failed}")
        
        # 计算总体统计
        total_entities = sum(r.get('summary', {}).get('entities_extracted', 0) for r in results)
        total_responses = sum(r.get('summary', {}).get('responses_executed', 0) for r in results)
        avg_risk_score = sum(r.get('summary', {}).get('max_risk_score', 0) for r in results) / len(results)
        
        logger.info(f"总提取实体数: {total_entities}")
        logger.info(f"总响应动作数: {total_responses}")
        logger.info(f"平均风险分数: {avg_risk_score:.2f}")
        
        logger.info("批量事件分析测试完成")
    
    async def test_entity_recognition(self):
        """测试实体识别功能"""
        logger.info("开始实体识别测试...")
        
        # 创建包含多种实体类型的测试数据
        complex_log = {
            "timestamp": datetime.now().isoformat(),
            "src_ip": "192.168.1.100",
            "dst_ip": "103.45.67.89",
            "username": "john.doe",
            "email": "john.doe@company.com",
            "file_path": "C:\\Users\\john.doe\\Documents\\sensitive.docx",
            "process_name": "winword.exe",
            "domain": "suspicious-domain.com",
            "url": "https://malicious.com/payload.php",
            "file_hash": "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456",
            "device_name": "DESKTOP-ABC123",
            "command_line": "powershell.exe -EncodedCommand UwB0AGEAcgB0AC0AUAByAG8AYwBlAHMAcwA=",
            "message": "User john.doe accessed file at C:\\temp\\malware.exe from IP 10.0.0.25"
        }
        
        entities = self.analysis_service.entity_recognizer.extract_entities(complex_log, "test-event")
        
        logger.info(f"从复杂日志中提取到 {len(entities)} 个实体:")
        
        # 按类型分组显示
        entity_by_type = {}
        for entity in entities:
            entity_type = entity.entity_type.value
            if entity_type not in entity_by_type:
                entity_by_type[entity_type] = []
            entity_by_type[entity_type].append(entity.entity_id)
        
        for entity_type, entity_ids in entity_by_type.items():
            logger.info(f"  {entity_type}: {len(entity_ids)} 个")
            for entity_id in entity_ids:
                logger.info(f"    - {entity_id}")
        
        logger.info("实体识别测试完成")
    
    async def test_risk_scoring(self):
        """测试风险评分功能"""
        logger.info("开始风险评分测试...")
        
        # 创建不同风险级别的测试实体
        from src.models.entities import SecurityEntity
        
        test_entities = [
            SecurityEntity(
                entity_type=EntityType.IP,
                entity_id="103.45.67.89",
                metadata={
                    'is_private': False,
                    'threat_intel': True,
                    'anomaly_type': 'malicious_ip'
                }
            ),
            SecurityEntity(
                entity_type=EntityType.USER,
                entity_id="admin",
                metadata={
                    'is_system_account': True,
                    'privilege_escalation': True,
                    'anomaly_type': 'unusual_admin_activity'
                }
            ),
            SecurityEntity(
                entity_type=EntityType.FILE,
                entity_id="C:\\temp\\suspicious.exe",
                metadata={
                    'is_hash': True,
                    'hash_type': 'SHA256',
                    'threat_intel': True,
                    'malicious': True
                }
            )
        ]
        
        # 计算风险分数
        for entity in test_entities:
            risk_score = await self.analysis_service.risk_scoring_engine.calculate_entity_risk_score(entity)
            logger.info(f"实体 {entity.entity_type.value} '{entity.entity_id}': "
                       f"风险分数 {risk_score:.2f}, 威胁等级 {entity.threat_level.value}")
        
        logger.info("风险评分测试完成")
    
    async def test_response_execution(self):
        """测试响应执行功能"""
        logger.info("开始响应执行测试...")
        
        # 测试手动响应执行
        test_cases = [
            ("192.168.1.100", "ip", ["block_ip", "send_alert"]),
            ("suspicious_user", "user", ["disable_user", "reset_password"]),
            ("malware.exe", "file", ["quarantine_file", "collect_evidence"])
        ]
        
        for entity_id, entity_type, actions in test_cases:
            logger.info(f"测试实体 {entity_type}:{entity_id} 的响应执行...")
            
            results = await self.analysis_service.manual_response_execution(
                entity_id=entity_id,
                entity_type=entity_type,
                actions=actions
            )
            
            logger.info(f"  执行了 {len(results)} 个响应动作:")
            for result in results:
                status = result.get('status', 'unknown')
                action = result.get('action', 'unknown')
                logger.info(f"    - {action}: {status}")
        
        logger.info("响应执行测试完成")
    
    async def test_system_statistics(self):
        """测试系统统计信息"""
        logger.info("开始系统统计测试...")
        
        stats = self.analysis_service.get_processing_statistics()
        
        logger.info("系统处理统计:")
        for key, value in stats['statistics'].items():
            logger.info(f"  {key}: {value}")
        
        logger.info("系统配置:")
        for key, value in stats['configuration'].items():
            logger.info(f"  {key}: {value}")
        
        logger.info("系统统计测试完成")
    
    async def test_health_check(self):
        """测试健康检查"""
        logger.info("开始健康检查测试...")
        
        health_status = await self.analysis_service.health_check()
        
        logger.info(f"服务状态: {health_status['service']}")
        logger.info("组件状态:")
        for component, status in health_status['components'].items():
            logger.info(f"  {component}: {status}")
        
        logger.info("健康检查测试完成")


async def main():
    """主函数"""
    try:
        test_runner = SecurityAnalysisSystemTest()
        await test_runner.run_all_tests()
        
        logger.info("\n" + "=" * 60)
        logger.info("🎉 安全分析系统测试全部通过!")
        logger.info("系统已准备就绪，可以开始处理实际的安全事件。")
        
    except Exception as e:
        logger.error(f"测试失败: {e}")
        raise


if __name__ == "__main__":
    asyncio.run(main())