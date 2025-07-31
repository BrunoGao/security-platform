"""
Connection Expansion Engine
连接扩充引擎 - 基于多维度信息丰富实体关系图谱
"""

import logging
import time
from typing import List, Dict, Any, Set, Optional, Tuple
from datetime import datetime, timedelta
import asyncio
import networkx as nx

from ..models.entities import SecurityEntity, EntityType, EntityStatus


class ConnectionExpansionEngine:
    """连接扩充引擎"""
    
    def __init__(self, neo4j_client=None, threat_intel_api=None, 
                 clickhouse_client=None, redis_client=None):
        self.logger = logging.getLogger(__name__)
        self.neo4j_client = neo4j_client
        self.threat_intel_api = threat_intel_api
        self.clickhouse_client = clickhouse_client
        self.redis_client = redis_client
        
        # 创建内存图用于快速关系分析
        self.asset_graph = nx.Graph()
        
        # 扩充策略配置
        self.expansion_config = {
            'max_expansion_depth': 3,
            'max_entities_per_expansion': 50,
            'time_window_hours': 24,
            'min_confidence_threshold': 0.3
        }
        
        # 关系类型权重
        self.relationship_weights = {
            'COMMUNICATES_WITH': 0.8,
            'BELONGS_TO': 0.9,
            'USED_BY': 0.7,
            'ACCESSES': 0.6,
            'EXECUTES': 0.8,
            'CREATES': 0.7,
            'MODIFIES': 0.6,
            'THREAT_INTEL_RELATED': 0.9,
            'ANOMALY_RELATED': 0.7
        }
    
    async def expand_entity_connections(self, entity: SecurityEntity, 
                                      expansion_methods: List[str] = None) -> List[SecurityEntity]:
        """扩充实体连接关系"""
        if expansion_methods is None:
            expansion_methods = ['asset_relationship', 'threat_intel', 'baseline_anomaly', 'temporal_correlation']
        
        expanded_entities = []
        
        try:
            # 并行执行不同的扩充方法
            tasks = []
            
            if 'asset_relationship' in expansion_methods:
                tasks.append(self._expand_by_asset_relationship(entity))
            
            if 'threat_intel' in expansion_methods:
                tasks.append(self._expand_by_threat_intel(entity))
            
            if 'baseline_anomaly' in expansion_methods:
                tasks.append(self._expand_by_baseline_anomaly(entity))
            
            if 'temporal_correlation' in expansion_methods:
                tasks.append(self._expand_by_temporal_correlation(entity))
            
            # 等待所有扩充任务完成
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            # 合并结果
            for result in results:
                if isinstance(result, list):
                    expanded_entities.extend(result)
                elif isinstance(result, Exception):
                    self.logger.error(f"Expansion task failed: {result}")
            
            # 去重和过滤
            expanded_entities = self._deduplicate_entities(expanded_entities)
            expanded_entities = self._filter_by_confidence(expanded_entities)
            
            # 建立连接关系
            self._establish_connections(entity, expanded_entities)
            
            # 更新实体状态
            entity.update_status(EntityStatus.INVESTIGATED, "完成连接扩充")
            
        except Exception as e:
            self.logger.error(f"Error expanding entity connections: {e}")
        
        return expanded_entities
    
    async def _expand_by_asset_relationship(self, entity: SecurityEntity) -> List[SecurityEntity]:
        """基于资产责任关系扩充"""
        expanded_entities = []
        
        try:
            if entity.entity_type == EntityType.IP:
                expanded_entities.extend(await self._expand_ip_by_asset(entity))
            elif entity.entity_type == EntityType.USER:
                expanded_entities.extend(await self._expand_user_by_asset(entity))
            elif entity.entity_type == EntityType.DEVICE:
                expanded_entities.extend(await self._expand_device_by_asset(entity))
            elif entity.entity_type == EntityType.FILE:
                expanded_entities.extend(await self._expand_file_by_asset(entity))
        
        except Exception as e:
            self.logger.error(f"Asset relationship expansion failed: {e}")
        
        return expanded_entities
    
    async def _expand_ip_by_asset(self, ip_entity: SecurityEntity) -> List[SecurityEntity]:
        """基于IP扩充相关资产"""
        entities = []
        
        if not self.neo4j_client:
            return entities
        
        try:
            # 查找IP对应的设备和用户
            query = """
            MATCH (ip:IP {address: $ip_address})
            OPTIONAL MATCH (ip)-[:BELONGS_TO]->(device:Device)
            OPTIONAL MATCH (device)-[:USED_BY]->(user:User)
            OPTIONAL MATCH (ip)-[:ACCESSED_BY]->(process:Process)
            RETURN device, user, process
            LIMIT 20
            """
            
            result = await self.neo4j_client.run(query, ip_address=ip_entity.entity_id)
            
            async for record in result:
                # 设备实体
                if record.get('device'):
                    device = record['device']
                    device_entity = SecurityEntity(
                        entity_type=EntityType.DEVICE,
                        entity_id=device.get('hostname', device.get('name')),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'BELONGS_TO',
                            'os': device.get('os'),
                            'location': device.get('location')
                        }
                    )
                    entities.append(device_entity)
                
                # 用户实体
                if record.get('user'):
                    user = record['user']
                    user_entity = SecurityEntity(
                        entity_type=EntityType.USER,
                        entity_id=user.get('username'),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'USED_BY',
                            'department': user.get('department'),
                            'role': user.get('role')
                        }
                    )
                    entities.append(user_entity)
                
                # 进程实体
                if record.get('process'):
                    process = record['process']
                    process_entity = SecurityEntity(
                        entity_type=EntityType.PROCESS,
                        entity_id=process.get('name'),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'ACCESSED_BY',
                            'pid': process.get('pid'),
                            'command_line': process.get('command_line')
                        }
                    )
                    entities.append(process_entity)
        
        except Exception as e:
            self.logger.error(f"IP asset expansion failed: {e}")
        
        return entities
    
    async def _expand_user_by_asset(self, user_entity: SecurityEntity) -> List[SecurityEntity]:
        """基于用户扩充相关资产"""
        entities = []
        
        if not self.neo4j_client:
            return entities
        
        try:
            # 查找用户使用的设备和访问的资源
            query = """
            MATCH (user:User {username: $username})
            OPTIONAL MATCH (user)-[:USES]->(device:Device)
            OPTIONAL MATCH (user)-[:ACCESSES]->(file:File)
            OPTIONAL MATCH (device)-[:HAS_IP]->(ip:IP)
            RETURN device, file, ip
            LIMIT 30
            """
            
            result = await self.neo4j_client.run(query, username=user_entity.entity_id)
            
            async for record in result:
                # 设备实体
                if record.get('device'):
                    device = record['device']
                    device_entity = SecurityEntity(
                        entity_type=EntityType.DEVICE,
                        entity_id=device.get('hostname'),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'USES'
                        }
                    )
                    entities.append(device_entity)
                
                # 文件实体
                if record.get('file'):
                    file = record['file']
                    file_entity = SecurityEntity(
                        entity_type=EntityType.FILE,
                        entity_id=file.get('path'),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'ACCESSES'
                        }
                    )
                    entities.append(file_entity)
                
                # IP实体
                if record.get('ip'):
                    ip = record['ip']
                    ip_entity = SecurityEntity(
                        entity_type=EntityType.IP,
                        entity_id=ip.get('address'),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'HAS_IP'
                        }
                    )
                    entities.append(ip_entity)
        
        except Exception as e:
            self.logger.error(f"User asset expansion failed: {e}")
        
        return entities
    
    async def _expand_device_by_asset(self, device_entity: SecurityEntity) -> List[SecurityEntity]:
        """基于设备扩充相关资产"""
        entities = []
        
        if not self.neo4j_client:
            return entities
        
        try:
            query = """
            MATCH (device:Device {hostname: $hostname})
            OPTIONAL MATCH (device)-[:HAS_IP]->(ip:IP)
            OPTIONAL MATCH (device)-[:USED_BY]->(user:User)
            OPTIONAL MATCH (device)-[:RUNS_PROCESS]->(process:Process)
            RETURN ip, user, process
            LIMIT 25
            """
            
            result = await self.neo4j_client.run(query, hostname=device_entity.entity_id)
            
            async for record in result:
                if record.get('ip'):
                    ip = record['ip']
                    ip_entity = SecurityEntity(
                        entity_type=EntityType.IP,
                        entity_id=ip.get('address'),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'HAS_IP'
                        }
                    )
                    entities.append(ip_entity)
                
                if record.get('user'):
                    user = record['user']
                    user_entity = SecurityEntity(
                        entity_type=EntityType.USER,
                        entity_id=user.get('username'),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'USED_BY'
                        }
                    )
                    entities.append(user_entity)
                
                if record.get('process'):
                    process = record['process']
                    process_entity = SecurityEntity(
                        entity_type=EntityType.PROCESS,
                        entity_id=process.get('name'),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'RUNS_PROCESS'
                        }
                    )
                    entities.append(process_entity)
        
        except Exception as e:
            self.logger.error(f"Device asset expansion failed: {e}")
        
        return entities
    
    async def _expand_file_by_asset(self, file_entity: SecurityEntity) -> List[SecurityEntity]:
        """基于文件扩充相关资产"""
        entities = []
        
        if not self.neo4j_client:
            return entities
        
        try:
            query = """
            MATCH (file:File {path: $file_path})
            OPTIONAL MATCH (file)-[:ACCESSED_BY]->(user:User)
            OPTIONAL MATCH (file)-[:EXECUTED_BY]->(process:Process)
            OPTIONAL MATCH (file)-[:LOCATED_ON]->(device:Device)
            RETURN user, process, device
            LIMIT 20
            """
            
            result = await self.neo4j_client.run(query, file_path=file_entity.entity_id)
            
            async for record in result:
                if record.get('user'):
                    user = record['user']
                    user_entity = SecurityEntity(
                        entity_type=EntityType.USER,
                        entity_id=user.get('username'),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'ACCESSED_BY'
                        }
                    )
                    entities.append(user_entity)
                
                if record.get('process'):
                    process = record['process']
                    process_entity = SecurityEntity(
                        entity_type=EntityType.PROCESS,
                        entity_id=process.get('name'),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'EXECUTED_BY'
                        }
                    )
                    entities.append(process_entity)
                
                if record.get('device'):
                    device = record['device']
                    device_entity = SecurityEntity(
                        entity_type=EntityType.DEVICE,
                        entity_id=device.get('hostname'),
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'asset_relationship',
                            'relationship_type': 'LOCATED_ON'
                        }
                    )
                    entities.append(device_entity)
        
        except Exception as e:
            self.logger.error(f"File asset expansion failed: {e}")
        
        return entities
    
    async def _expand_by_threat_intel(self, entity: SecurityEntity) -> List[SecurityEntity]:
        """基于威胁情报扩充"""
        entities = []
        
        if not self.threat_intel_api:
            return entities
        
        try:
            threat_info = None
            
            if entity.entity_type == EntityType.IP:
                threat_info = await self.threat_intel_api.query_ip(entity.entity_id)
            elif entity.entity_type == EntityType.DOMAIN:
                threat_info = await self.threat_intel_api.query_domain(entity.entity_id)
            elif entity.entity_type == EntityType.FILE:
                # 如果是哈希值
                if entity.metadata.get('is_hash'):
                    threat_info = await self.threat_intel_api.query_hash(entity.entity_id)
            
            if threat_info:
                # 处理相关IP
                for related_ip in threat_info.get('related_ips', []):
                    ip_entity = SecurityEntity(
                        entity_type=EntityType.IP,
                        entity_id=related_ip,
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'threat_intel',
                            'relationship_type': 'THREAT_INTEL_RELATED',
                            'threat_types': threat_info.get('threat_types', []),
                            'confidence': threat_info.get('confidence', 0.5)
                        }
                    )
                    entities.append(ip_entity)
                
                # 处理相关域名
                for related_domain in threat_info.get('related_domains', []):
                    domain_entity = SecurityEntity(
                        entity_type=EntityType.DOMAIN,
                        entity_id=related_domain,
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'threat_intel',
                            'relationship_type': 'THREAT_INTEL_RELATED',
                            'threat_types': threat_info.get('threat_types', [])
                        }
                    )
                    entities.append(domain_entity)
                
                # 处理相关哈希
                for related_hash in threat_info.get('related_hashes', []):
                    hash_entity = SecurityEntity(
                        entity_type=EntityType.FILE,
                        entity_id=related_hash,
                        status=EntityStatus.INVESTIGATED,
                        metadata={
                            'expansion_source': 'threat_intel',
                            'relationship_type': 'THREAT_INTEL_RELATED',
                            'is_hash': True,
                            'hash_type': self._determine_hash_type(related_hash)
                        }
                    )
                    entities.append(hash_entity)
        
        except Exception as e:
            self.logger.error(f"Threat intel expansion failed: {e}")
        
        return entities
    
    async def _expand_by_baseline_anomaly(self, entity: SecurityEntity) -> List[SecurityEntity]:
        """基于基线异常扩充"""
        entities = []
        
        if not self.clickhouse_client:
            return entities
        
        try:
            # 根据实体类型查询异常行为
            if entity.entity_type == EntityType.USER:
                entities.extend(await self._find_user_anomalies(entity))
            elif entity.entity_type == EntityType.IP:
                entities.extend(await self._find_ip_anomalies(entity))
            elif entity.entity_type == EntityType.DEVICE:
                entities.extend(await self._find_device_anomalies(entity))
        
        except Exception as e:
            self.logger.error(f"Baseline anomaly expansion failed: {e}")
        
        return entities
    
    async def _find_user_anomalies(self, user_entity: SecurityEntity) -> List[SecurityEntity]:
        """查找用户异常行为相关实体"""
        entities = []
        
        try:
            # 查找异常登录IP
            query = """
            SELECT DISTINCT src_ip, COUNT(*) as login_count
            FROM login_logs 
            WHERE username = %s 
            AND timestamp > now() - INTERVAL 7 DAY
            AND is_anomaly = 1
            GROUP BY src_ip
            ORDER BY login_count DESC
            LIMIT 10
            """
            
            result = await self.clickhouse_client.execute(query, (user_entity.entity_id,))
            
            for row in result:
                ip_entity = SecurityEntity(
                    entity_type=EntityType.IP,
                    entity_id=row[0],
                    status=EntityStatus.INVESTIGATED,
                    metadata={
                        'expansion_source': 'baseline_anomaly',
                        'relationship_type': 'ANOMALY_RELATED',
                        'anomaly_type': 'unusual_login_location',
                        'event_count': row[1]
                    }
                )
                entities.append(ip_entity)
        
        except Exception as e:
            self.logger.error(f"User anomaly expansion failed: {e}")
        
        return entities
    
    async def _find_ip_anomalies(self, ip_entity: SecurityEntity) -> List[SecurityEntity]:
        """查找IP异常行为相关实体"""
        entities = []
        
        try:
            # 查找从该IP登录的异常用户
            query = """
            SELECT DISTINCT username, COUNT(*) as access_count
            FROM access_logs 
            WHERE src_ip = %s 
            AND timestamp > now() - INTERVAL 24 HOUR
            AND is_anomaly = 1
            GROUP BY username
            ORDER BY access_count DESC
            LIMIT 15
            """
            
            result = await self.clickhouse_client.execute(query, (ip_entity.entity_id,))
            
            for row in result:
                user_entity = SecurityEntity(
                    entity_type=EntityType.USER,
                    entity_id=row[0],
                    status=EntityStatus.INVESTIGATED,
                    metadata={
                        'expansion_source': 'baseline_anomaly',
                        'relationship_type': 'ANOMALY_RELATED',
                        'anomaly_type': 'unusual_access_pattern',
                        'event_count': row[1]
                    }
                )
                entities.append(user_entity)
        
        except Exception as e:
            self.logger.error(f"IP anomaly expansion failed: {e}")
        
        return entities
    
    async def _find_device_anomalies(self, device_entity: SecurityEntity) -> List[SecurityEntity]:
        """查找设备异常行为相关实体"""
        entities = []
        
        try:
            # 查找设备上的异常进程
            query = """
            SELECT DISTINCT process_name, COUNT(*) as exec_count
            FROM process_logs 
            WHERE hostname = %s 
            AND timestamp > now() - INTERVAL 12 HOUR
            AND is_anomaly = 1
            GROUP BY process_name
            ORDER BY exec_count DESC
            LIMIT 10
            """
            
            result = await self.clickhouse_client.execute(query, (device_entity.entity_id,))
            
            for row in result:
                process_entity = SecurityEntity(
                    entity_type=EntityType.PROCESS,
                    entity_id=row[0],
                    status=EntityStatus.INVESTIGATED,
                    metadata={
                        'expansion_source': 'baseline_anomaly',
                        'relationship_type': 'ANOMALY_RELATED',
                        'anomaly_type': 'unusual_process_execution',
                        'event_count': row[1]
                    }
                )
                entities.append(process_entity)
        
        except Exception as e:
            self.logger.error(f"Device anomaly expansion failed: {e}")
        
        return entities
    
    async def _expand_by_temporal_correlation(self, entity: SecurityEntity) -> List[SecurityEntity]:
        """基于时间相关性扩充"""
        entities = []
        
        if not self.clickhouse_client:
            return entities
        
        try:
            # 查找时间窗口内相关的实体
            time_window = self.expansion_config['time_window_hours']
            
            # 根据实体类型构建不同的时间相关查询
            if entity.entity_type == EntityType.IP:
                entities.extend(await self._find_temporal_ip_relations(entity, time_window))
            elif entity.entity_type == EntityType.USER:
                entities.extend(await self._find_temporal_user_relations(entity, time_window))
        
        except Exception as e:
            self.logger.error(f"Temporal correlation expansion failed: {e}")
        
        return entities
    
    async def _find_temporal_ip_relations(self, ip_entity: SecurityEntity, time_window: int) -> List[SecurityEntity]:
        """查找IP的时间相关实体"""
        entities = []
        
        try:
            # 查找同时间段内通信的其他IP
            query = """
            SELECT DISTINCT dst_ip, COUNT(*) as comm_count
            FROM network_logs 
            WHERE src_ip = %s 
            AND timestamp > now() - INTERVAL %s HOUR
            GROUP BY dst_ip
            HAVING comm_count > 5
            ORDER BY comm_count DESC
            LIMIT 20
            """
            
            result = await self.clickhouse_client.execute(query, (ip_entity.entity_id, time_window))
            
            for row in result:
                related_ip = SecurityEntity(
                    entity_type=EntityType.IP,
                    entity_id=row[0],
                    status=EntityStatus.INVESTIGATED,
                    metadata={
                        'expansion_source': 'temporal_correlation',
                        'relationship_type': 'COMMUNICATES_WITH',
                        'communication_count': row[1],
                        'time_window_hours': time_window
                    }
                )
                entities.append(related_ip)
        
        except Exception as e:
            self.logger.error(f"Temporal IP relations expansion failed: {e}")
        
        return entities
    
    async def _find_temporal_user_relations(self, user_entity: SecurityEntity, time_window: int) -> List[SecurityEntity]:
        """查找用户的时间相关实体"""
        entities = []
        
        try:
            # 查找同时间段内访问的文件
            query = """
            SELECT DISTINCT file_path, COUNT(*) as access_count
            FROM file_access_logs 
            WHERE username = %s 
            AND timestamp > now() - INTERVAL %s HOUR
            GROUP BY file_path
            HAVING access_count > 1
            ORDER BY access_count DESC
            LIMIT 15
            """
            
            result = await self.clickhouse_client.execute(query, (user_entity.entity_id, time_window))
            
            for row in result:
                file_entity = SecurityEntity(
                    entity_type=EntityType.FILE,
                    entity_id=row[0],
                    status=EntityStatus.INVESTIGATED,
                    metadata={
                        'expansion_source': 'temporal_correlation',
                        'relationship_type': 'ACCESSES',
                        'access_count': row[1],
                        'time_window_hours': time_window
                    }
                )
                entities.append(file_entity)
        
        except Exception as e:
            self.logger.error(f"Temporal user relations expansion failed: {e}")
        
        return entities
    
    def _deduplicate_entities(self, entities: List[SecurityEntity]) -> List[SecurityEntity]:
        """去重实体"""
        seen = set()
        deduplicated = []
        
        for entity in entities:
            entity_key = (entity.entity_type, entity.entity_id)
            if entity_key not in seen:
                seen.add(entity_key)
                deduplicated.append(entity)
        
        return deduplicated
    
    def _filter_by_confidence(self, entities: List[SecurityEntity]) -> List[SecurityEntity]:
        """根据置信度过滤实体"""
        min_confidence = self.expansion_config['min_confidence_threshold']
        filtered = []
        
        for entity in entities:
            confidence = entity.metadata.get('confidence', entity.confidence)
            if confidence >= min_confidence:
                filtered.append(entity)
        
        return filtered[:self.expansion_config['max_entities_per_expansion']]
    
    def _establish_connections(self, source_entity: SecurityEntity, 
                             expanded_entities: List[SecurityEntity]):
        """建立实体间的连接关系"""
        for target_entity in expanded_entities:
            relationship_type = target_entity.metadata.get('relationship_type', 'RELATED_TO')
            
            # 添加双向连接
            source_entity.add_connection(
                target_entity, 
                relationship_type,
                metadata={
                    'expansion_method': target_entity.metadata.get('expansion_source'),
                    'weight': self.relationship_weights.get(relationship_type, 0.5)
                }
            )
            
            target_entity.add_connection(
                source_entity,
                f"REVERSE_{relationship_type}",
                metadata={
                    'expansion_method': target_entity.metadata.get('expansion_source'),
                    'weight': self.relationship_weights.get(relationship_type, 0.5)
                }
            )
    
    def _determine_hash_type(self, hash_value: str) -> str:
        """确定哈希类型"""
        length = len(hash_value)
        if length == 32:
            return 'MD5'
        elif length == 40:
            return 'SHA1'
        elif length == 64:
            return 'SHA256'
        return 'UNKNOWN'