"""
Risk Scoring Engine  
风险评分引擎 - 通过算法模型对实体和行为进行风险量化
"""

import math
import logging
import numpy as np
from typing import List, Dict, Any, Tuple, Optional
from datetime import datetime, timedelta
from collections import defaultdict, Counter
import asyncio

from ..models.entities import SecurityEntity, EntityType, ThreatLevel


class RiskScoringEngine:
    """风险评分引擎"""
    
    def __init__(self, ml_model_service=None, threat_intel_service=None):
        self.logger = logging.getLogger(__name__)
        self.ml_model_service = ml_model_service
        self.threat_intel_service = threat_intel_service
        
        # 单点风险指标权重
        self.single_point_weights = {
            'threat_intel_match': 0.35,          # 威胁情报匹配
            'anomaly_behavior': 0.25,            # 异常行为
            'privilege_escalation': 0.20,        # 权限提升
            'suspicious_file': 0.10,             # 可疑文件
            'malicious_domain': 0.30,            # 恶意域名
            'blacklist_match': 0.40,             # 黑名单匹配
            'vulnerability_exploit': 0.25,        # 漏洞利用
            'lateral_movement': 0.20,            # 横向移动
            'data_exfiltration': 0.30,           # 数据外泄
            'brute_force': 0.15                  # 暴力破解
        }
        
        # 多点行为序列权重
        self.multi_point_weights = {
            'time_correlation': 0.30,            # 时间相关性
            'entity_correlation': 0.35,          # 实体相关性
            'behavior_sequence': 0.35            # 行为序列
        }
        
        # 实体类型基础风险分数
        self.entity_base_scores = {
            EntityType.IP: 20.0,
            EntityType.USER: 15.0,
            EntityType.FILE: 25.0,
            EntityType.PROCESS: 20.0,
            EntityType.DEVICE: 10.0,
            EntityType.DOMAIN: 30.0,
            EntityType.EMAIL: 15.0,
            EntityType.URL: 25.0
        }
        
        # 威胁类型严重性分数
        self.threat_severity_scores = {
            'malware': 90,
            'botnet': 85,
            'apt': 95,
            'phishing': 70,
            'ransomware': 95,
            'trojan': 80,
            'backdoor': 85,
            'spyware': 75,
            'adware': 30,
            'suspicious': 50
        }
        
        # 行为模式分数
        self.behavior_pattern_scores = {
            'login_anomaly': 60,
            'file_access_anomaly': 55,
            'network_anomaly': 65,
            'process_anomaly': 70,
            'privilege_escalation': 85,
            'lateral_movement': 80,
            'data_exfiltration': 90,
            'command_injection': 85,
            'sql_injection': 80,
            'xss': 60,
            'brute_force': 70
        }
    
    async def calculate_entity_risk_score(self, entity: SecurityEntity, 
                                        context_entities: List[SecurityEntity] = None) -> float:
        """计算实体风险分数"""
        try:
            # 获取单点风险指标
            single_point_indicators = await self._extract_single_point_indicators(entity)
            
            # 计算单点风险分数
            single_point_score = self._calculate_single_point_risk(entity, single_point_indicators)
            
            # 如果有上下文实体，计算多点行为序列分数
            multi_point_score = 0.0
            if context_entities and len(context_entities) > 0:
                all_entities = [entity] + context_entities
                multi_point_score = await self._calculate_multi_point_risk(all_entities)
            
            # 综合计算最终风险分数
            final_score = self._combine_scores(single_point_score, multi_point_score)
            
            # 更新实体风险分数
            entity.update_risk_score(
                final_score, 
                f"单点分数: {single_point_score:.2f}, 多点分数: {multi_point_score:.2f}"
            )
            
            self.logger.info(f"Entity {entity.entity_id} risk score calculated: {final_score:.2f}")
            
            return final_score
            
        except Exception as e:
            self.logger.error(f"Error calculating risk score for entity {entity.entity_id}: {e}")
            return 0.0
    
    async def calculate_batch_risk_scores(self, entities: List[SecurityEntity]) -> Dict[str, float]:
        """批量计算实体风险分数"""
        risk_scores = {}
        
        try:
            # 并行计算每个实体的风险分数
            tasks = []
            for entity in entities:
                # 获取相关的上下文实体
                context_entities = self._get_context_entities(entity, entities)
                task = self.calculate_entity_risk_score(entity, context_entities)
                tasks.append((entity.entity_id, task))
            
            # 等待所有计算完成
            for entity_id, task in tasks:
                try:
                    score = await task
                    risk_scores[entity_id] = score
                except Exception as e:
                    self.logger.error(f"Failed to calculate risk score for {entity_id}: {e}")
                    risk_scores[entity_id] = 0.0
                    
        except Exception as e:
            self.logger.error(f"Error in batch risk score calculation: {e}")
        
        return risk_scores
    
    async def _extract_single_point_indicators(self, entity: SecurityEntity) -> Dict[str, float]:
        """提取单点风险指标"""
        indicators = {}
        
        try:
            # 威胁情报匹配检查
            indicators['threat_intel_match'] = await self._check_threat_intel_match(entity)
            
            # 异常行为检查
            indicators['anomaly_behavior'] = await self._check_anomaly_behavior(entity)
            
            # 黑名单匹配检查
            indicators['blacklist_match'] = await self._check_blacklist_match(entity)
            
            # 根据实体类型进行特定检查
            if entity.entity_type == EntityType.IP:
                indicators.update(await self._check_ip_indicators(entity))
            elif entity.entity_type == EntityType.USER:
                indicators.update(await self._check_user_indicators(entity))
            elif entity.entity_type == EntityType.FILE:
                indicators.update(await self._check_file_indicators(entity))
            elif entity.entity_type == EntityType.PROCESS:
                indicators.update(await self._check_process_indicators(entity))
            elif entity.entity_type == EntityType.DOMAIN:
                indicators.update(await self._check_domain_indicators(entity))
            
        except Exception as e:
            self.logger.error(f"Error extracting indicators for entity {entity.entity_id}: {e}")
        
        return indicators
    
    async def _check_threat_intel_match(self, entity: SecurityEntity) -> float:
        """检查威胁情报匹配"""
        if not self.threat_intel_service:
            return 0.0
        
        try:
            threat_info = None
            
            if entity.entity_type == EntityType.IP:
                threat_info = await self.threat_intel_service.query_ip(entity.entity_id)
            elif entity.entity_type == EntityType.DOMAIN:
                threat_info = await self.threat_intel_service.query_domain(entity.entity_id)
            elif entity.entity_type == EntityType.FILE and entity.metadata.get('is_hash'):
                threat_info = await self.threat_intel_service.query_hash(entity.entity_id)
            
            if threat_info:
                # 根据威胁类型和置信度计算分数
                threat_types = threat_info.get('threat_types', [])
                confidence = threat_info.get('confidence', 0.0)
                
                if threat_types:
                    max_severity = max([
                        self.threat_severity_scores.get(threat_type, 50) 
                        for threat_type in threat_types
                    ])
                    return (max_severity / 100.0) * confidence
            
        except Exception as e:
            self.logger.error(f"Error checking threat intel for {entity.entity_id}: {e}")
        
        return 0.0
    
    async def _check_anomaly_behavior(self, entity: SecurityEntity) -> float:
        """检查异常行为"""
        anomaly_score = 0.0
        
        try:
            # 从实体元数据中检查异常标记
            if entity.metadata.get('is_anomaly'):
                anomaly_type = entity.metadata.get('anomaly_type', 'general')
                anomaly_score = self.behavior_pattern_scores.get(anomaly_type, 50) / 100.0
            
            # 检查连接中的异常关系
            for connection in entity.connections:
                if connection.get('metadata', {}).get('anomaly_related'):
                    anomaly_score = max(anomaly_score, 0.6)
            
            # 如果有ML模型服务，使用模型预测异常分数
            if self.ml_model_service:
                ml_anomaly_score = await self.ml_model_service.predict_anomaly(entity)
                anomaly_score = max(anomaly_score, ml_anomaly_score)
                
        except Exception as e:
            self.logger.error(f"Error checking anomaly behavior for {entity.entity_id}: {e}")
        
        return min(anomaly_score, 1.0)
    
    async def _check_blacklist_match(self, entity: SecurityEntity) -> float:
        """检查黑名单匹配"""
        # 这里可以集成各种黑名单数据源
        # 示例实现
        blacklist_indicators = [
            'malicious', 'suspicious', 'blocked', 'quarantined'
        ]
        
        for indicator in blacklist_indicators:
            if indicator in str(entity.metadata).lower():
                return 0.8
        
        return 0.0
    
    async def _check_ip_indicators(self, entity: SecurityEntity) -> Dict[str, float]:
        """检查IP特有指标"""
        indicators = {}
        
        try:
            # 检查是否为私网IP
            if entity.metadata.get('is_private', False):
                indicators['internal_ip'] = 0.2  # 内网IP风险较低
            else:
                indicators['external_ip'] = 0.4  # 外网IP风险较高
            
            # 检查地理位置异常
            location = entity.metadata.get('location')
            if location and self._is_suspicious_location(location):
                indicators['suspicious_location'] = 0.6
            
            # 检查端口扫描行为
            if self._has_port_scanning_behavior(entity):
                indicators['port_scanning'] = 0.7
            
            # 检查DDoS行为
            if self._has_ddos_behavior(entity):
                indicators['ddos_behavior'] = 0.8
                
        except Exception as e:
            self.logger.error(f"Error checking IP indicators: {e}")
        
        return indicators
    
    async def _check_user_indicators(self, entity: SecurityEntity) -> Dict[str, float]:
        """检查用户特有指标"""
        indicators = {}
        
        try:
            # 检查权限提升
            if self._has_privilege_escalation(entity):
                indicators['privilege_escalation'] = 0.8
            
            # 检查异常登录
            login_anomaly_score = self._check_login_anomaly(entity)
            if login_anomaly_score > 0:
                indicators['login_anomaly'] = login_anomaly_score
            
            # 检查横向移动
            if self._has_lateral_movement(entity):
                indicators['lateral_movement'] = 0.7
            
            # 检查数据访问异常
            data_access_score = self._check_data_access_anomaly(entity)
            if data_access_score > 0:
                indicators['data_access_anomaly'] = data_access_score
                
        except Exception as e:
            self.logger.error(f"Error checking user indicators: {e}")
        
        return indicators
    
    async def _check_file_indicators(self, entity: SecurityEntity) -> Dict[str, float]:
        """检查文件特有指标"""
        indicators = {}
        
        try:
            # 检查文件类型风险
            file_ext = entity.metadata.get('file_extension', '').lower()
            if file_ext in ['exe', 'bat', 'ps1', 'sh', 'scr', 'vbs']:
                indicators['executable_file'] = 0.6
            elif file_ext in ['doc', 'docx', 'pdf', 'xls', 'xlsx']:
                indicators['document_file'] = 0.3
            
            # 检查系统文件修改
            if entity.metadata.get('is_system_file') and self._has_modification(entity):
                indicators['system_file_modification'] = 0.9
            
            # 检查加密/打包文件
            if self._is_encrypted_or_packed(entity):
                indicators['encrypted_packed'] = 0.5
            
            # 如果是哈希值，检查已知恶意哈希
            if entity.metadata.get('is_hash'):
                indicators['malicious_hash'] = await self._check_malicious_hash(entity)
                
        except Exception as e:
            self.logger.error(f"Error checking file indicators: {e}")
        
        return indicators
    
    async def _check_process_indicators(self, entity: SecurityEntity) -> Dict[str, float]:
        """检查进程特有指标"""
        indicators = {}
        
        try:
            # 检查系统进程异常
            if entity.metadata.get('is_system_process') and self._has_anomalous_behavior(entity):
                indicators['system_process_anomaly'] = 0.8
            
            # 检查进程注入
            if self._has_process_injection(entity):
                indicators['process_injection'] = 0.9
            
            # 检查网络连接异常
            if self._has_suspicious_network_activity(entity):
                indicators['suspicious_network'] = 0.7
            
            # 检查命令行参数异常
            cmd_line = entity.metadata.get('full_command', '')
            if self._has_suspicious_command_line(cmd_line):
                indicators['suspicious_command'] = 0.6
                
        except Exception as e:
            self.logger.error(f"Error checking process indicators: {e}")
        
        return indicators
    
    async def _check_domain_indicators(self, entity: SecurityEntity) -> Dict[str, float]:
        """检查域名特有指标"""
        indicators = {}
        
        try:
            domain = entity.entity_id.lower()
            
            # 检查域名年龄
            if self._is_newly_registered_domain(domain):
                indicators['new_domain'] = 0.6
            
            # 检查DGA域名特征
            if self._is_dga_domain(domain):
                indicators['dga_domain'] = 0.8
            
            # 检查钓鱼域名特征
            if self._is_phishing_domain(domain):
                indicators['phishing_domain'] = 0.9
            
            # 检查恶意TLD
            tld = entity.metadata.get('tld', '').lower()
            if tld in ['tk', 'ml', 'ga', 'cf']:  # 常见免费TLD
                indicators['suspicious_tld'] = 0.4
                
        except Exception as e:
            self.logger.error(f"Error checking domain indicators: {e}")
        
        return indicators
    
    def _calculate_single_point_risk(self, entity: SecurityEntity, 
                                   indicators: Dict[str, float]) -> float:
        """计算单点风险分数"""
        try:
            # 基础分数
            base_score = self.entity_base_scores.get(entity.entity_type, 10.0)
            
            # 加权计算指标分数
            weighted_score = 0.0
            total_weight = 0.0
            
            for indicator, value in indicators.items():
                weight = self.single_point_weights.get(indicator, 0.1)
                weighted_score += weight * value * 100  # 转换为0-100分制
                total_weight += weight
            
            # 如果有指标，使用加权平均；否则使用基础分数
            if total_weight > 0:
                indicator_score = weighted_score / total_weight
                # 结合基础分数和指标分数
                final_score = base_score + (indicator_score * 0.8)
            else:
                final_score = base_score
            
            # 应用sigmoid函数进行归一化，确保分数在合理范围内
            normalized_score = 100 / (1 + math.exp(-(final_score - 50) / 20))
            
            return min(max(normalized_score, 0.0), 100.0)
            
        except Exception as e:
            self.logger.error(f"Error calculating single point risk: {e}")
            return 0.0
    
    async def _calculate_multi_point_risk(self, entities: List[SecurityEntity]) -> float:
        """计算多点行为序列风险分数"""
        if len(entities) < 2:
            return 0.0
        
        try:
            # 时间相关性分析
            time_correlation = self._analyze_time_correlation(entities)
            
            # 实体相关性分析
            entity_correlation = self._analyze_entity_correlation(entities)
            
            # 行为序列分析
            behavior_sequence = await self._analyze_behavior_sequence(entities)
            
            # 加权计算多点分数
            multi_point_score = (
                self.multi_point_weights['time_correlation'] * time_correlation +
                self.multi_point_weights['entity_correlation'] * entity_correlation +
                self.multi_point_weights['behavior_sequence'] * behavior_sequence
            )
            
            return multi_point_score * 100
            
        except Exception as e:
            self.logger.error(f"Error calculating multi-point risk: {e}")
            return 0.0
    
    def _analyze_time_correlation(self, entities: List[SecurityEntity]) -> float:
        """分析时间相关性"""
        try:
            # 提取所有实体的时间戳信息
            timestamps = []
            for entity in entities:
                # 从时间线中提取时间戳
                for event in entity.timeline:
                    timestamps.append(event.get('timestamp', 0))
                
                # 从连接中提取时间戳
                for connection in entity.connections:
                    timestamps.append(connection.get('timestamp', 0))
            
            if len(timestamps) < 2:
                return 0.0
            
            # 计算时间集中度
            timestamps.sort()
            time_ranges = []
            for i in range(1, len(timestamps)):
                time_ranges.append(timestamps[i] - timestamps[i-1])
            
            if not time_ranges:
                return 0.0
            
            # 计算时间方差，方差小说明时间集中度高
            mean_range = sum(time_ranges) / len(time_ranges)
            variance = sum((x - mean_range) ** 2 for x in time_ranges) / len(time_ranges)
            
            # 时间窗口内的事件越集中，相关性越高
            correlation_score = 1.0 / (1.0 + math.sqrt(variance) / 3600)  # 标准化到小时
            
            return min(correlation_score, 1.0)
            
        except Exception as e:
            self.logger.error(f"Error analyzing time correlation: {e}")
            return 0.0
    
    def _analyze_entity_correlation(self, entities: List[SecurityEntity]) -> float:
        """分析实体相关性"""
        try:
            if len(entities) < 2:
                return 0.0
            
            # 构建实体关系图
            entity_graph = defaultdict(set)
            
            for entity in entities:
                for connection in entity.connections:
                    target_id = connection.get('target_id')
                    if target_id:
                        entity_graph[entity.entity_id].add(target_id)
            
            # 计算实体间的连通性
            total_possible_connections = len(entities) * (len(entities) - 1) / 2
            actual_connections = 0
            
            for entity_id, connected_entities in entity_graph.items():
                # 计算与其他实体的连接数
                other_entities = {e.entity_id for e in entities if e.entity_id != entity_id}
                actual_connections += len(connected_entities.intersection(other_entities))
            
            # 连通性分数
            connectivity_score = actual_connections / max(total_possible_connections, 1)
            
            # 考虑实体类型的相关性
            type_diversity = len(set(entity.entity_type for entity in entities))
            type_correlation = min(type_diversity / 4.0, 1.0)  # 类型越多样，相关性可能越高
            
            # 综合计算实体相关性
            correlation_score = (connectivity_score * 0.7 + type_correlation * 0.3)
            
            return min(correlation_score, 1.0)
            
        except Exception as e:
            self.logger.error(f"Error analyzing entity correlation: {e}")
            return 0.0
    
    async def _analyze_behavior_sequence(self, entities: List[SecurityEntity]) -> float:
        """分析行为序列"""
        try:
            # 提取行为模式
            behavior_patterns = []
            
            for entity in entities:
                # 从元数据中提取行为类型
                anomaly_type = entity.metadata.get('anomaly_type')
                if anomaly_type:
                    behavior_patterns.append(anomaly_type)
                
                # 从连接关系中提取行为
                for connection in entity.connections:
                    conn_type = connection.get('connection_type', '')
                    if 'ANOMALY' in conn_type or 'THREAT' in conn_type:
                        behavior_patterns.append(conn_type.lower())
            
            if not behavior_patterns:
                return 0.0
            
            # 检查已知攻击序列模式
            attack_sequences = [
                ['login_anomaly', 'privilege_escalation', 'lateral_movement'],
                ['malware', 'process_injection', 'network_anomaly'],
                ['phishing', 'credential_theft', 'data_exfiltration'],
                ['vulnerability_exploit', 'backdoor', 'persistence']
            ]
            
            max_sequence_score = 0.0
            
            for sequence in attack_sequences:
                # 检查行为模式中是否包含攻击序列
                matches = sum(1 for pattern in behavior_patterns if any(seq in pattern for seq in sequence))
                sequence_score = matches / len(sequence)
                max_sequence_score = max(max_sequence_score, sequence_score)
            
            # 如果有ML模型，使用模型分析行为序列
            if self.ml_model_service:
                try:
                    ml_sequence_score = await self.ml_model_service.analyze_behavior_sequence(behavior_patterns)
                    max_sequence_score = max(max_sequence_score, ml_sequence_score)
                except Exception as e:
                    self.logger.warning(f"ML sequence analysis failed: {e}")
            
            return min(max_sequence_score, 1.0)
            
        except Exception as e:
            self.logger.error(f"Error analyzing behavior sequence: {e}")
            return 0.0
    
    def _combine_scores(self, single_point_score: float, multi_point_score: float) -> float:
        """组合单点和多点分数"""
        # 如果没有多点分数，直接返回单点分数
        if multi_point_score == 0.0:
            return single_point_score
        
        # 使用加权平均，多点分数权重较高
        combined_score = single_point_score * 0.4 + multi_point_score * 0.6
        
        # 确保分数在0-100范围内
        return min(max(combined_score, 0.0), 100.0)
    
    def _get_context_entities(self, target_entity: SecurityEntity, 
                            all_entities: List[SecurityEntity]) -> List[SecurityEntity]:
        """获取目标实体的上下文实体"""
        context_entities = []
        
        # 获取与目标实体有连接关系的实体
        connected_entity_ids = {conn.get('target_id') for conn in target_entity.connections}
        
        for entity in all_entities:
            if entity.entity_id != target_entity.entity_id and entity.entity_id in connected_entity_ids:
                context_entities.append(entity)
        
        return context_entities[:10]  # 限制上下文实体数量
    
    # 以下是各种检查方法的示例实现，实际项目中需要根据具体业务逻辑实现
    def _is_suspicious_location(self, location: str) -> bool:
        """检查是否为可疑地理位置"""
        suspicious_countries = ['CN', 'RU', 'KP', 'IR']  # 示例
        return any(country in location.upper() for country in suspicious_countries)
    
    def _has_port_scanning_behavior(self, entity: SecurityEntity) -> bool:
        """检查是否有端口扫描行为"""
        return 'port_scan' in str(entity.metadata).lower()
    
    def _has_ddos_behavior(self, entity: SecurityEntity) -> bool:
        """检查是否有DDoS行为"""
        return 'ddos' in str(entity.metadata).lower()
    
    def _has_privilege_escalation(self, entity: SecurityEntity) -> bool:
        """检查是否有权限提升"""
        return 'privilege_escalation' in str(entity.metadata).lower()
    
    def _check_login_anomaly(self, entity: SecurityEntity) -> float:
        """检查登录异常"""
        if 'login_anomaly' in str(entity.metadata).lower():
            return 0.6
        return 0.0
    
    def _has_lateral_movement(self, entity: SecurityEntity) -> bool:
        """检查是否有横向移动"""
        return 'lateral_movement' in str(entity.metadata).lower()
    
    def _check_data_access_anomaly(self, entity: SecurityEntity) -> float:
        """检查数据访问异常"""
        if 'data_access_anomaly' in str(entity.metadata).lower():
            return 0.5
        return 0.0
    
    def _has_modification(self, entity: SecurityEntity) -> bool:
        """检查文件是否被修改"""
        return 'modified' in str(entity.metadata).lower()
    
    def _is_encrypted_or_packed(self, entity: SecurityEntity) -> bool:
        """检查文件是否加密或打包"""
        return any(keyword in str(entity.metadata).lower() 
                  for keyword in ['encrypted', 'packed', 'compressed'])
    
    async def _check_malicious_hash(self, entity: SecurityEntity) -> float:
        """检查恶意哈希"""
        # 这里可以集成各种哈希黑名单数据库
        if 'malicious' in str(entity.metadata).lower():
            return 0.9
        return 0.0
    
    def _has_anomalous_behavior(self, entity: SecurityEntity) -> bool:
        """检查是否有异常行为"""
        return entity.metadata.get('is_anomaly', False)
    
    def _has_process_injection(self, entity: SecurityEntity) -> bool:
        """检查是否有进程注入"""
        return 'injection' in str(entity.metadata).lower()
    
    def _has_suspicious_network_activity(self, entity: SecurityEntity) -> bool:
        """检查是否有可疑网络活动"""
        return 'network_anomaly' in str(entity.metadata).lower()
    
    def _has_suspicious_command_line(self, cmd_line: str) -> bool:
        """检查命令行是否可疑"""
        suspicious_patterns = ['powershell', 'cmd.exe', 'wmic', 'netsh', 'reg.exe']
        return any(pattern in cmd_line.lower() for pattern in suspicious_patterns)
    
    def _is_newly_registered_domain(self, domain: str) -> bool:
        """检查是否为新注册域名"""
        # 实际实现需要查询域名注册信息
        return False
    
    def _is_dga_domain(self, domain: str) -> bool:
        """检查是否为DGA域名"""
        # 简单的DGA检测逻辑
        if len(domain) > 20:
            consonants = sum(1 for c in domain if c in 'bcdfghjklmnpqrstvwxyz')
            vowels = sum(1 for c in domain if c in 'aeiou')
            if consonants > vowels * 2:  # 辅音过多
                return True
        return False
    
    def _is_phishing_domain(self, domain: str) -> bool:
        """检查是否为钓鱼域名"""
        # 检查是否包含知名品牌名称但不是官方域名
        brands = ['google', 'microsoft', 'apple', 'amazon', 'facebook']
        for brand in brands:
            if brand in domain and not domain.endswith(f'{brand}.com'):
                return True
        return False