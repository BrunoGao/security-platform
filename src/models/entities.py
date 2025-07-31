"""
Security Entity Models
安全实体数据模型定义
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import List, Dict, Any, Optional
import json
import time
from datetime import datetime

class EntityType(Enum):
    """实体类型枚举"""
    USER = "user"
    IP = "ip"
    FILE = "file"
    PROCESS = "process"
    DEVICE = "device"
    DOMAIN = "domain"
    EMAIL = "email"
    URL = "url"

class EntityStatus(Enum):
    """实体状态枚举"""
    PENDING = "待调查"
    INVESTIGATED = "已调查"
    SCORED = "已评分"
    COMPROMISED = "已沦陷"
    BLOCKED = "已阻断"
    BLEEDING_STOP = "待止血"
    WHITELISTED = "已白名单"

class ThreatLevel(Enum):
    """威胁等级枚举"""
    LOW = "低风险"
    MEDIUM = "中风险"
    HIGH = "高风险"
    CRITICAL = "严重威胁"

@dataclass
class SecurityEntity:
    """安全实体模型"""
    entity_type: EntityType
    entity_id: str
    status: EntityStatus = EntityStatus.PENDING
    risk_score: float = 0.0
    threat_level: ThreatLevel = ThreatLevel.LOW
    connections: List[Dict[str, Any]] = field(default_factory=list)
    timeline: List[Dict[str, Any]] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)
    first_seen: datetime = field(default_factory=datetime.now)
    last_seen: datetime = field(default_factory=datetime.now)
    confidence: float = 1.0  # 置信度
    
    def add_connection(self, target_entity: 'SecurityEntity', 
                      connection_type: str, timestamp: Optional[int] = None,
                      metadata: Optional[Dict] = None):
        """添加实体连接关系"""
        if timestamp is None:
            timestamp = int(time.time())
            
        connection = {
            'target_id': target_entity.entity_id,
            'target_type': target_entity.entity_type.value,
            'connection_type': connection_type,
            'timestamp': timestamp,
            'metadata': metadata or {}
        }
        self.connections.append(connection)
    
    def update_status(self, new_status: EntityStatus, reason: str = ""):
        """更新实体状态"""
        old_status = self.status
        self.status = new_status
        
        self.timeline.append({
            'action': 'status_change',
            'old_status': old_status.value,
            'new_status': new_status.value,
            'timestamp': int(time.time()),
            'reason': reason
        })
    
    def update_risk_score(self, new_score: float, reason: str = ""):
        """更新风险分数"""
        old_score = self.risk_score
        self.risk_score = new_score
        
        # 根据分数更新威胁等级
        if new_score >= 90:
            self.threat_level = ThreatLevel.CRITICAL
        elif new_score >= 70:
            self.threat_level = ThreatLevel.HIGH
        elif new_score >= 40:
            self.threat_level = ThreatLevel.MEDIUM
        else:
            self.threat_level = ThreatLevel.LOW
        
        self.timeline.append({
            'action': 'risk_score_update',
            'old_score': old_score,
            'new_score': new_score,
            'threat_level': self.threat_level.value,
            'timestamp': int(time.time()),
            'reason': reason
        })
    
    def add_metadata(self, key: str, value: Any):
        """添加元数据"""
        self.metadata[key] = value
        self.timeline.append({
            'action': 'metadata_update',
            'key': key,
            'value': value,
            'timestamp': int(time.time())
        })
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return {
            'entity_type': self.entity_type.value,
            'entity_id': self.entity_id,
            'status': self.status.value,
            'risk_score': self.risk_score,
            'threat_level': self.threat_level.value,
            'connections': self.connections,
            'timeline': self.timeline,
            'metadata': self.metadata,
            'first_seen': self.first_seen.isoformat(),
            'last_seen': self.last_seen.isoformat(),
            'confidence': self.confidence
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'SecurityEntity':
        """从字典创建实体"""
        entity = cls(
            entity_type=EntityType(data['entity_type']),
            entity_id=data['entity_id'],
            status=EntityStatus(data.get('status', EntityStatus.PENDING.value)),
            risk_score=data.get('risk_score', 0.0),
            threat_level=ThreatLevel(data.get('threat_level', ThreatLevel.LOW.value)),
            connections=data.get('connections', []),
            timeline=data.get('timeline', []),
            metadata=data.get('metadata', {}),
            confidence=data.get('confidence', 1.0)
        )
        
        if 'first_seen' in data:
            entity.first_seen = datetime.fromisoformat(data['first_seen'])
        if 'last_seen' in data:
            entity.last_seen = datetime.fromisoformat(data['last_seen'])
            
        return entity

@dataclass
class SecurityEvent:
    """安全事件模型"""
    event_id: str
    event_type: str
    timestamp: datetime
    entities: List[SecurityEntity] = field(default_factory=list)
    raw_data: Dict[str, Any] = field(default_factory=dict)
    processed: bool = False
    risk_score: float = 0.0
    
    def add_entity(self, entity: SecurityEntity):
        """添加实体到事件"""
        self.entities.append(entity)
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return {
            'event_id': self.event_id,
            'event_type': self.event_type,
            'timestamp': self.timestamp.isoformat(),
            'entities': [entity.to_dict() for entity in self.entities],
            'raw_data': self.raw_data,
            'processed': self.processed,
            'risk_score': self.risk_score
        }

@dataclass
class ThreatIntelligence:
    """威胁情报模型"""
    indicator: str
    indicator_type: str
    threat_type: str
    confidence: float
    severity: str
    source: str
    description: str
    tags: List[str] = field(default_factory=list)
    first_seen: datetime = field(default_factory=datetime.now)
    last_seen: datetime = field(default_factory=datetime.now)
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return {
            'indicator': self.indicator,
            'indicator_type': self.indicator_type,
            'threat_type': self.threat_type,
            'confidence': self.confidence,
            'severity': self.severity,
            'source': self.source,
            'description': self.description,
            'tags': self.tags,
            'first_seen': self.first_seen.isoformat(),
            'last_seen': self.last_seen.isoformat()
        }