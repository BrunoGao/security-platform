"""
Security Alert Analysis Service
安全告警分析服务 - 整合所有引擎的核心业务服务
"""

import asyncio
import logging
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime
import uuid
import json

from ..models.entities import SecurityEntity, SecurityEvent, EntityType, EntityStatus
from ..engines.entity_recognizer import EntityRecognizer
from ..engines.connection_expansion import ConnectionExpansionEngine
from ..engines.risk_scoring import RiskScoringEngine
from ..engines.response_executor import ResponseOrchestrator, ResponseAction


class SecurityAnalysisService:
    """安全分析服务主类"""
    
    def __init__(self, config: Dict[str, Any] = None):
        self.logger = logging.getLogger(__name__)
        self.config = config or {}
        
        # 初始化各个引擎
        self.entity_recognizer = EntityRecognizer()
        
        # 连接扩充引擎需要外部依赖
        self.connection_engine = ConnectionExpansionEngine(
            neo4j_client=self.config.get('neo4j_client'),
            threat_intel_api=self.config.get('threat_intel_api'),
            clickhouse_client=self.config.get('clickhouse_client'),
            redis_client=self.config.get('redis_client')
        )
        
        # 风险评分引擎
        self.risk_scoring_engine = RiskScoringEngine(
            ml_model_service=self.config.get('ml_model_service'),
            threat_intel_service=self.config.get('threat_intel_service')
        )
        
        # 响应执行引擎
        self.response_orchestrator = ResponseOrchestrator(
            config=self.config.get('response_config', {})
        )
        
        # 处理统计
        self.processing_stats = {
            'total_events_processed': 0,
            'total_entities_extracted': 0,
            'total_connections_expanded': 0,
            'total_responses_executed': 0,
            'average_processing_time': 0.0
        }
        
        # 处理配置
        self.processing_config = {
            'enable_connection_expansion': True,
            'enable_risk_scoring': True,
            'enable_auto_response': True,
            'max_concurrent_processing': 10,
            'processing_timeout': 300,  # 5分钟超时
            'min_risk_threshold_for_response': 50.0
        }
        
        # 更新配置
        self.processing_config.update(self.config.get('processing_config', {}))
    
    async def analyze_security_event(self, log_data: Dict[str, Any], 
                                   event_type: str = "security_alert") -> Dict[str, Any]:
        """
        分析单个安全事件
        这是核心的4步处理流程：
        1. 提取初始连接对（实体识别）
        2. 连接扩充
        3. 风险评分
        4. 执行响应动作
        """
        start_time = datetime.now()
        event_id = str(uuid.uuid4())
        
        try:
            self.logger.info(f"Starting analysis for event {event_id}")
            
            # 创建安全事件对象
            security_event = SecurityEvent(
                event_id=event_id,
                event_type=event_type,
                timestamp=start_time,
                raw_data=log_data
            )
            
            # 第一步：提取初始连接对（实体识别）
            self.logger.info(f"Step 1: Entity Recognition for event {event_id}")
            entities = await self._extract_entities(log_data, event_id)
            
            if not entities:
                self.logger.warning(f"No entities extracted from event {event_id}")
                return self._create_analysis_result(security_event, [], 0.0, [], start_time)
            
            security_event.entities = entities
            self.processing_stats['total_entities_extracted'] += len(entities)
            
            # 第二步：连接扩充
            if self.processing_config['enable_connection_expansion']:
                self.logger.info(f"Step 2: Connection Expansion for event {event_id}")
                await self._expand_connections(entities)
            
            # 第三步：风险评分
            if self.processing_config['enable_risk_scoring']:
                self.logger.info(f"Step 3: Risk Scoring for event {event_id}")
                max_risk_score = await self._calculate_risk_scores(entities)
                security_event.risk_score = max_risk_score
            else:
                max_risk_score = 0.0
            
            # 第四步：执行响应动作
            response_results = []
            if (self.processing_config['enable_auto_response'] and 
                max_risk_score >= self.processing_config['min_risk_threshold_for_response']):
                self.logger.info(f"Step 4: Response Execution for event {event_id}")
                response_results = await self._execute_responses(entities)
            
            # 标记事件为已处理
            security_event.processed = True
            
            # 更新统计信息
            self.processing_stats['total_events_processed'] += 1
            if response_results:
                self.processing_stats['total_responses_executed'] += len(response_results)
            
            # 计算处理时间
            processing_time = (datetime.now() - start_time).total_seconds()
            self._update_average_processing_time(processing_time)
            
            self.logger.info(f"Analysis completed for event {event_id} in {processing_time:.2f}s")
            
            return self._create_analysis_result(security_event, entities, max_risk_score, 
                                              response_results, start_time, processing_time)
            
        except Exception as e:
            error_msg = f"Error analyzing security event {event_id}: {e}"
            self.logger.error(error_msg)
            
            return {
                'event_id': event_id,
                'status': 'error',
                'error_message': error_msg,
                'timestamp': datetime.now().isoformat(),
                'processing_time': (datetime.now() - start_time).total_seconds()
            }
    
    async def batch_analyze_events(self, events: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """批量分析安全事件"""
        self.logger.info(f"Starting batch analysis of {len(events)} events")
        
        # 限制并发数量
        semaphore = asyncio.Semaphore(self.processing_config['max_concurrent_processing'])
        
        async def analyze_with_semaphore(event_data):
            async with semaphore:
                return await self.analyze_security_event(event_data)
        
        # 并发处理所有事件
        tasks = [analyze_with_semaphore(event) for event in events]
        
        try:
            results = await asyncio.wait_for(
                asyncio.gather(*tasks, return_exceptions=True),
                timeout=self.processing_config['processing_timeout']
            )
            
            # 处理异常结果
            processed_results = []
            for i, result in enumerate(results):
                if isinstance(result, Exception):
                    self.logger.error(f"Event {i} processing failed: {result}")
                    processed_results.append({
                        'event_index': i,
                        'status': 'error',
                        'error_message': str(result),
                        'timestamp': datetime.now().isoformat()
                    })
                else:
                    processed_results.append(result)
            
            self.logger.info(f"Batch analysis completed: {len(processed_results)} results")
            return processed_results
            
        except asyncio.TimeoutError:
            self.logger.error("Batch analysis timed out")
            return [{'status': 'timeout', 'message': 'Batch processing timed out'}]
    
    async def _extract_entities(self, log_data: Dict[str, Any], event_id: str) -> List[SecurityEntity]:
        """提取实体"""
        try:
            entities = self.entity_recognizer.extract_entities(log_data, event_id)
            self.logger.info(f"Extracted {len(entities)} entities from event {event_id}")
            return entities
        except Exception as e:
            self.logger.error(f"Error extracting entities: {e}")
            return []
    
    async def _expand_connections(self, entities: List[SecurityEntity]):
        """扩充实体连接"""
        try:
            expansion_tasks = []
            
            for entity in entities:
                # 异步扩充每个实体的连接
                task = self.connection_engine.expand_entity_connections(entity)
                expansion_tasks.append(task)
            
            # 并发执行所有扩充任务
            expanded_results = await asyncio.gather(*expansion_tasks, return_exceptions=True)
            
            total_expanded = 0
            for i, result in enumerate(expanded_results):
                if isinstance(result, Exception):
                    self.logger.error(f"Connection expansion failed for entity {entities[i].entity_id}: {result}")
                else:
                    total_expanded += len(result)
            
            self.processing_stats['total_connections_expanded'] += total_expanded
            self.logger.info(f"Expanded {total_expanded} connections across {len(entities)} entities")
            
        except Exception as e:
            self.logger.error(f"Error expanding connections: {e}")
    
    async def _calculate_risk_scores(self, entities: List[SecurityEntity]) -> float:
        """计算风险分数"""
        try:
            # 批量计算所有实体的风险分数
            risk_scores = await self.risk_scoring_engine.calculate_batch_risk_scores(entities)
            
            # 找出最高风险分数
            max_risk_score = max(risk_scores.values()) if risk_scores else 0.0
            
            self.logger.info(f"Calculated risk scores for {len(entities)} entities, max score: {max_risk_score:.2f}")
            
            return max_risk_score
            
        except Exception as e:
            self.logger.error(f"Error calculating risk scores: {e}")
            return 0.0
    
    async def _execute_responses(self, entities: List[SecurityEntity]) -> List[Dict[str, Any]]:
        """执行响应动作"""
        try:
            response_tasks = []
            
            # 对每个高风险实体执行响应
            for entity in entities:
                if entity.risk_score >= self.processing_config['min_risk_threshold_for_response']:
                    task = self.response_orchestrator.execute_response(entity)
                    response_tasks.append((entity.entity_id, task))
            
            # 并发执行所有响应任务
            all_results = []
            for entity_id, task in response_tasks:
                try:
                    results = await task
                    for result in results:
                        result['entity_id'] = entity_id
                    all_results.extend(results)
                except Exception as e:
                    self.logger.error(f"Response execution failed for entity {entity_id}: {e}")
                    all_results.append({
                        'entity_id': entity_id,
                        'status': 'error',
                        'message': str(e),
                        'timestamp': datetime.now().isoformat()
                    })
            
            self.logger.info(f"Executed {len(all_results)} response actions")
            return all_results
            
        except Exception as e:
            self.logger.error(f"Error executing responses: {e}")
            return []
    
    def _create_analysis_result(self, event: SecurityEvent, entities: List[SecurityEntity], 
                              max_risk_score: float, response_results: List[Dict[str, Any]], 
                              start_time: datetime, processing_time: float = None) -> Dict[str, Any]:
        """创建分析结果"""
        if processing_time is None:
            processing_time = (datetime.now() - start_time).total_seconds()
        
        return {
            'event_id': event.event_id,
            'status': 'completed',
            'timestamp': datetime.now().isoformat(),
            'processing_time': processing_time,
            'summary': {
                'entities_extracted': len(entities),
                'max_risk_score': max_risk_score,
                'responses_executed': len(response_results),
                'high_risk_entities': len([e for e in entities if e.risk_score >= 70])
            },
            'entities': [entity.to_dict() for entity in entities],
            'response_results': response_results,
            'event_data': event.to_dict()
        }
    
    def _update_average_processing_time(self, new_time: float):
        """更新平均处理时间"""
        current_avg = self.processing_stats['average_processing_time']
        total_events = self.processing_stats['total_events_processed']
        
        if total_events == 1:
            self.processing_stats['average_processing_time'] = new_time
        else:
            # 计算滑动平均
            self.processing_stats['average_processing_time'] = (
                (current_avg * (total_events - 1) + new_time) / total_events
            )
    
    async def get_entity_details(self, entity_id: str, entity_type: str) -> Optional[Dict[str, Any]]:
        """获取实体详细信息"""
        try:
            # 这里可以从数据库或缓存中获取实体详细信息
            # 示例实现
            entity_info = {
                'entity_id': entity_id,
                'entity_type': entity_type,
                'current_status': 'active',
                'risk_history': [],
                'connection_count': 0,
                'last_seen': datetime.now().isoformat()
            }
            
            return entity_info
            
        except Exception as e:
            self.logger.error(f"Error getting entity details: {e}")
            return None
    
    async def manual_response_execution(self, entity_id: str, entity_type: str, 
                                       actions: List[str]) -> List[Dict[str, Any]]:
        """手动执行响应动作"""
        try:
            # 创建临时实体对象
            entity = SecurityEntity(
                entity_type=EntityType(entity_type),
                entity_id=entity_id
            )
            
            # 转换动作字符串为枚举
            response_actions = []
            for action_str in actions:
                try:
                    action = ResponseAction(action_str)
                    response_actions.append(action)
                except ValueError:
                    self.logger.warning(f"Unknown response action: {action_str}")
            
            if not response_actions:
                return [{'status': 'error', 'message': 'No valid actions provided'}]
            
            # 执行响应
            results = await self.response_orchestrator.execute_response(entity, response_actions)
            
            self.logger.info(f"Manual response executed for entity {entity_id}: {len(results)} actions")
            return results
            
        except Exception as e:
            error_msg = f"Error in manual response execution: {e}"
            self.logger.error(error_msg)
            return [{'status': 'error', 'message': error_msg}]
    
    def get_processing_statistics(self) -> Dict[str, Any]:
        """获取处理统计信息"""
        return {
            'statistics': self.processing_stats.copy(),
            'configuration': self.processing_config.copy(),
            'timestamp': datetime.now().isoformat()
        }
    
    def update_configuration(self, new_config: Dict[str, Any]):
        """更新处理配置"""
        self.processing_config.update(new_config)
        self.logger.info(f"Configuration updated: {new_config}")
    
    async def health_check(self) -> Dict[str, Any]:
        """健康检查"""
        try:
            # 检查各个组件状态
            health_status = {
                'service': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'components': {
                    'entity_recognizer': 'healthy',
                    'connection_engine': 'healthy',
                    'risk_scoring_engine': 'healthy',
                    'response_orchestrator': 'healthy'
                },
                'statistics': self.processing_stats
            }
            
            # 这里可以添加更详细的健康检查逻辑
            # 例如检查外部依赖、数据库连接等
            
            return health_status
            
        except Exception as e:
            return {
                'service': 'unhealthy',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }


# 工厂函数，用于创建服务实例
def create_security_analysis_service(config: Dict[str, Any] = None) -> SecurityAnalysisService:
    """创建安全分析服务实例"""
    return SecurityAnalysisService(config)