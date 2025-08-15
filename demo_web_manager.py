#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
安全告警分析系统 - Web演示管理API
Security Alert Analysis System - Web Demo Management API
"""

import os
import sys
import json
import time
import subprocess
import threading
import logging
import yaml
import uuid
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any

from flask import Flask, request, jsonify, render_template, Response
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import psutil
import requests

# 添加项目根目录到Python路径
project_root = Path(__file__).parent
sys.path.append(str(project_root))

# 配置日志
log_dir = project_root / 'logs'
log_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_dir / 'demo_system.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__, 
           template_folder=str(project_root / 'demo_web' / 'templates'),
           static_folder=str(project_root / 'demo_web' / 'static'))
app.config['SECRET_KEY'] = 'security-demo-2024'
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")

class SystemManager:
    """系统管理器"""
    
    def __init__(self):
        self.project_root = project_root
        self.is_starting = False
        self.is_stopping = False
        self.system_status = "unknown"
        self.logs = []
        self.max_logs = 1000
        
        # 缓存机制
        self._docker_status_cache = None
        self._docker_status_cache_time = 0
        self._system_info_cache = None
        self._system_info_cache_time = 0
        self.cache_duration = 5  # 缓存5秒
        
    def execute_command(self, command: str, cwd: str = None) -> Dict[str, Any]:
        """执行系统命令"""
        start_time = time.time()
        logger.info(f"执行命令: {command} (工作目录: {cwd})")
        
        try:
            if cwd is None:
                cwd = str(self.project_root)
                
            result = subprocess.run(
                command, 
                shell=True, 
                cwd=cwd,
                capture_output=True, 
                text=True, 
                timeout=30
            )
            
            duration = time.time() - start_time
            logger.info(f"命令执行完成: {command} (耗时: {duration:.2f}s, 返回码: {result.returncode})")
            
            if result.returncode != 0:
                logger.error(f"命令执行失败: {command}, stderr: {result.stderr}")
            
            return {
                'success': result.returncode == 0,
                'stdout': result.stdout,
                'stderr': result.stderr,
                'returncode': result.returncode,
                'duration': duration
            }
        except subprocess.TimeoutExpired:
            duration = time.time() - start_time
            logger.error(f"命令执行超时: {command} (耗时: {duration:.2f}s)")
            return {
                'success': False,
                'stdout': '',
                'stderr': 'Command timeout',
                'returncode': -1,
                'duration': duration
            }
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"命令执行异常: {command} (耗时: {duration:.2f}s), 错误: {str(e)}")
            return {
                'success': False,
                'stdout': '',
                'stderr': str(e),
                'returncode': -1,
                'duration': duration
            }
    
    def add_log(self, level: str, message: str):
        """添加日志"""
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'level': level,
            'message': message
        }
        self.logs.append(log_entry)
        
        # 保持日志数量限制
        if len(self.logs) > self.max_logs:
            self.logs = self.logs[-self.max_logs:]
            
        # 通过WebSocket发送日志
        socketio.emit('log_update', log_entry)
    
    def get_system_info(self) -> Dict[str, Any]:
        """获取系统信息（带缓存）"""
        current_time = time.time()
        
        # 检查缓存是否有效
        if (self._system_info_cache and 
            current_time - self._system_info_cache_time < self.cache_duration):
            logger.debug("使用系统信息缓存")
            return self._system_info_cache
            
        logger.info("获取系统信息...")
        start_time = time.time()
        
        try:
            # CPU信息 - 使用更快的方式，不阻塞
            cpu_percent = psutil.cpu_percent(interval=0)  # 不阻塞
            cpu_count = psutil.cpu_count()
            
            # 内存信息
            memory = psutil.virtual_memory()
            memory_total = memory.total // (1024**3)  # GB
            memory_used = memory.used // (1024**3)   # GB
            memory_percent = memory.percent
            
            # 磁盘信息
            disk = psutil.disk_usage(str(self.project_root))
            disk_total = disk.total // (1024**3)     # GB
            disk_used = disk.used // (1024**3)       # GB
            disk_percent = (disk.used / disk.total) * 100
            
            result = {
                'cpu': {
                    'percent': cpu_percent,
                    'count': cpu_count
                },
                'memory': {
                    'total_gb': memory_total,
                    'used_gb': memory_used,
                    'percent': memory_percent
                },
                'disk': {
                    'total_gb': disk_total,
                    'used_gb': disk_used,
                    'percent': disk_percent
                }
            }
            
            duration = time.time() - start_time
            logger.info(f"系统信息获取完成 (耗时: {duration:.3f}s, CPU: {cpu_percent:.1f}%, 内存: {memory_percent:.1f}%, 磁盘: {disk_percent:.1f}%)")
            
            # 更新缓存
            self._system_info_cache = result
            self._system_info_cache_time = current_time
            return result
            
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"获取系统信息失败 (耗时: {duration:.3f}s): {str(e)}")
            result = {'error': str(e)}
            self._system_info_cache = result
            self._system_info_cache_time = current_time
            return result
    
    def check_docker_services(self) -> Dict[str, Any]:
        """检查Docker服务状态（带缓存）"""
        current_time = time.time()
        
        # 检查缓存是否有效
        if (self._docker_status_cache and 
            current_time - self._docker_status_cache_time < self.cache_duration):
            logger.debug("使用Docker状态缓存")
            return self._docker_status_cache
            
        logger.debug("检查Docker服务状态...")
        start_time = time.time()
        
        try:
            # 检查Docker是否运行（快速检查）
            docker_check = self.execute_command('docker version --format "{{.Server.Version}}"')
            if not docker_check['success']:
                result = {'docker_running': False, 'services': {}}
                self._docker_status_cache = result
                self._docker_status_cache_time = current_time
                logger.warning("Docker未运行")
                return result
            
            # 检查docker-compose服务
            compose_check = self.execute_command('docker-compose ps --format json')
            services_status = {}
            
            if compose_check['success'] and compose_check['stdout'].strip():
                try:
                    # 解析docker-compose ps输出
                    lines = compose_check['stdout'].strip().split('\n')
                    services_found = 0
                    for line in lines:
                        if line.strip():
                            service_data = json.loads(line)
                            service_name = service_data.get('Service', 'unknown')
                            state = service_data.get('State', 'unknown')
                            services_status[service_name] = {
                                'status': state,
                                'health': service_data.get('Health', 'unknown')
                            }
                            services_found += 1
                    
                    logger.debug(f"找到 {services_found} 个Docker服务")
                    
                except json.JSONDecodeError:
                    logger.warning("docker-compose JSON解析失败，尝试传统方式")
                    # 如果JSON解析失败，尝试传统方式
                    ps_result = self.execute_command('docker-compose ps')
                    if ps_result['success']:
                        lines = ps_result['stdout'].split('\n')[2:]  # 跳过表头
                        services_found = 0
                        for line in lines:
                            if line.strip() and not line.startswith('-'):
                                parts = line.split()
                                if len(parts) >= 4:
                                    service_name = parts[0].split('_')[1] if '_' in parts[0] else parts[0]
                                    status = 'Up' if 'Up' in line else 'Down'
                                    services_status[service_name] = {
                                        'status': status,
                                        'health': 'unknown'
                                    }
                                    services_found += 1
                        logger.debug(f"通过传统方式找到 {services_found} 个Docker服务")
            
            result = {
                'docker_running': True,
                'services': services_status
            }
            
            duration = time.time() - start_time
            running_services = len([s for s in services_status.values() if 'up' in s['status'].lower()])
            total_services = len(services_status)
            logger.debug(f"Docker状态检查完成 (耗时: {duration:.3f}s, 运行中: {running_services}/{total_services})")
            
            # 更新缓存
            self._docker_status_cache = result
            self._docker_status_cache_time = current_time
            return result
            
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"Docker状态检查失败 (耗时: {duration:.3f}s): {str(e)}")
            result = {'docker_running': False, 'services': {}, 'error': str(e)}
            self._docker_status_cache = result
            self._docker_status_cache_time = current_time
            return result
    
    def check_api_status(self) -> Dict[str, Any]:
        """检查API服务状态"""
        try:
            # 检查API健康端点
            response = requests.get('http://localhost:8000/health', timeout=5)
            if response.status_code == 200:
                return {
                    'api_running': True,
                    'health_data': response.json() if response.content else {}
                }
            else:
                return {'api_running': False, 'status_code': response.status_code}
        except requests.RequestException:
            return {'api_running': False}
    
    def get_service_urls(self, host: str = 'localhost') -> Dict[str, str]:
        """获取服务访问URL"""
        return {
            'api': f'http://{host}:8000',
            'api_docs': f'http://{host}:8000/docs',
            'kibana': f'http://{host}:5601',
            'neo4j': f'http://{host}:7474',
            'clickhouse': f'http://{host}:8123/play',
            'kafka_ui': f'http://{host}:8082',
            'elasticsearch': f'http://{host}:9200'
        }

system_manager = SystemManager()

class SecurityPolicyManager:
    """安全策略管理器"""
    
    def __init__(self):
        self.policies_file = project_root / 'security_policies.json'
        self.policies = self.load_policies()
        
    def load_policies(self) -> List[Dict]:
        """加载策略列表"""
        try:
            if self.policies_file.exists():
                with open(self.policies_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    return data.get('policies', [])
            else:
                # 创建默认策略
                default_policies = self.create_default_policies()
                self.save_policies(default_policies)
                return default_policies
        except Exception as e:
            logger.error(f"加载策略失败: {str(e)}")
            return []
    
    def create_default_policies(self) -> List[Dict]:
        """创建默认策略"""
        timestamp = datetime.now().isoformat()
        return [
            {
                "policy_id": "default_brute_force_detection",
                "name": "暴力破解检测策略",
                "description": "检测短时间内多次登录失败的暴力破解行为",
                "severity": "high",
                "enabled": True,
                "rules": [
                    {
                        "rule_id": "brute_force_rule_1",
                        "name": "多次登录失败检测",
                        "condition": "event_type == 'security_brute_force' AND log_data.action == 'failed_login'",
                        "action": "alert",
                        "threshold": {
                            "count": 5,
                            "time_window": "5m"
                        },
                        "description": "5分钟内超过5次登录失败触发告警"
                    }
                ],
                "metadata": {
                    "created_by": "system",
                    "created_at": timestamp,
                    "version": "1.0",
                    "tags": ["authentication", "brute_force"]
                }
            },
            {
                "policy_id": "default_lateral_movement_detection",
                "name": "横向移动检测策略", 
                "description": "检测网络内部的横向移动和权限提升行为",
                "severity": "critical",
                "enabled": True,
                "rules": [
                    {
                        "rule_id": "lateral_rule_1",
                        "name": "异常内网连接检测",
                        "condition": "event_type == 'security_lateral_movement' AND log_data.src_ip LIKE '192.168.*'",
                        "action": "alert",
                        "description": "检测内网间的异常连接行为"
                    }
                ],
                "metadata": {
                    "created_by": "system",
                    "created_at": timestamp,
                    "version": "1.0", 
                    "tags": ["lateral_movement", "internal"]
                }
            }
        ]
    
    def save_policies(self, policies: List[Dict]) -> bool:
        """保存策略列表"""
        try:
            data = {
                'policies': policies,
                'updated_at': datetime.now().isoformat()
            }
            with open(self.policies_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            self.policies = policies
            return True
        except Exception as e:
            logger.error(f"保存策略失败: {str(e)}")
            return False
    
    def get_policies(self) -> List[Dict]:
        """获取所有策略"""
        return self.policies
    
    def get_policy(self, policy_id: str) -> Optional[Dict]:
        """获取单个策略"""
        for policy in self.policies:
            if policy['policy_id'] == policy_id:
                return policy
        return None
    
    def add_policy(self, policy_data: Dict) -> bool:
        """添加策略"""
        try:
            # 生成ID如果不存在
            if 'policy_id' not in policy_data:
                policy_data['policy_id'] = f"policy_{int(time.time())}_{uuid.uuid4().hex[:8]}"
            
            # 检查ID是否已存在
            if self.get_policy(policy_data['policy_id']):
                return False
            
            # 设置默认值
            policy_data.setdefault('enabled', True)
            policy_data.setdefault('severity', 'medium')
            
            # 添加元数据
            if 'metadata' not in policy_data:
                policy_data['metadata'] = {}
            policy_data['metadata'].update({
                'created_at': datetime.now().isoformat(),
                'created_by': 'admin'
            })
            
            self.policies.append(policy_data)
            return self.save_policies(self.policies)
        except Exception as e:
            logger.error(f"添加策略失败: {str(e)}")
            return False
    
    def update_policy(self, policy_id: str, policy_data: Dict) -> bool:
        """更新策略"""
        try:
            for i, policy in enumerate(self.policies):
                if policy['policy_id'] == policy_id:
                    # 保留原有的创建信息
                    if 'metadata' in policy:
                        policy_data.setdefault('metadata', {})
                        policy_data['metadata'].update({
                            'created_at': policy['metadata'].get('created_at', datetime.now().isoformat()),
                            'created_by': policy['metadata'].get('created_by', 'admin'),
                            'updated_at': datetime.now().isoformat(),
                            'updated_by': 'admin'
                        })
                    
                    self.policies[i] = policy_data
                    return self.save_policies(self.policies)
            return False
        except Exception as e:
            logger.error(f"更新策略失败: {str(e)}")
            return False
    
    def delete_policy(self, policy_id: str) -> bool:
        """删除策略"""
        try:
            self.policies = [p for p in self.policies if p['policy_id'] != policy_id]
            return self.save_policies(self.policies)
        except Exception as e:
            logger.error(f"删除策略失败: {str(e)}")
            return False
    
    def toggle_policy(self, policy_id: str, enabled: bool) -> bool:
        """启用/禁用策略"""
        policy = self.get_policy(policy_id)
        if policy:
            policy['enabled'] = enabled
            if 'metadata' not in policy:
                policy['metadata'] = {}
            policy['metadata']['updated_at'] = datetime.now().isoformat()
            return self.save_policies(self.policies)
        return False
    
    def import_policies(self, policies_data: List[Dict]) -> Dict[str, Any]:
        """导入策略"""
        try:
            imported_count = 0
            skipped_count = 0
            
            for policy_data in policies_data:
                # 检查必需字段
                if 'policy_id' not in policy_data or 'name' not in policy_data:
                    skipped_count += 1
                    continue
                
                # 如果策略已存在，跳过或更新
                existing_policy = self.get_policy(policy_data['policy_id'])
                if existing_policy:
                    # 可选择跳过或覆盖
                    skipped_count += 1
                    continue
                
                if self.add_policy(policy_data):
                    imported_count += 1
                else:
                    skipped_count += 1
            
            return {
                'success': True,
                'imported_count': imported_count,
                'skipped_count': skipped_count,
                'total_count': len(policies_data)
            }
        except Exception as e:
            logger.error(f"导入策略失败: {str(e)}")
            return {'success': False, 'message': str(e)}
    
    def export_policies(self, policy_ids: List[str] = None, format_type: str = 'json', 
                       include_disabled: bool = True, include_metadata: bool = True) -> Dict[str, Any]:
        """导出策略"""
        try:
            # 过滤策略
            policies_to_export = []
            for policy in self.policies:
                # 按ID过滤
                if policy_ids and policy['policy_id'] not in policy_ids:
                    continue
                
                # 按状态过滤
                if not include_disabled and not policy.get('enabled', True):
                    continue
                
                # 复制策略数据
                policy_copy = policy.copy()
                
                # 是否包含元数据
                if not include_metadata and 'metadata' in policy_copy:
                    del policy_copy['metadata']
                
                policies_to_export.append(policy_copy)
            
            # 根据格式导出
            if format_type == 'yaml':
                return {
                    'success': True,
                    'data': yaml.dump({'policies': policies_to_export}, default_flow_style=False, 
                                     allow_unicode=True, indent=2),
                    'content_type': 'text/yaml'
                }
            elif format_type == 'xml':
                # 简单的XML转换
                xml_data = '<policies>\n'
                for policy in policies_to_export:
                    xml_data += '  <policy>\n'
                    for key, value in policy.items():
                        if isinstance(value, (dict, list)):
                            xml_data += f'    <{key}><![CDATA[{json.dumps(value)}]]></{key}>\n'
                        else:
                            xml_data += f'    <{key}>{value}</{key}>\n'
                    xml_data += '  </policy>\n'
                xml_data += '</policies>'
                
                return {
                    'success': True,
                    'data': xml_data,
                    'content_type': 'text/xml'
                }
            else:  # JSON (default)
                return {
                    'success': True,
                    'data': json.dumps({'policies': policies_to_export}, ensure_ascii=False, indent=2),
                    'content_type': 'application/json'
                }
                
        except Exception as e:
            logger.error(f"导出策略失败: {str(e)}")
            return {'success': False, 'message': str(e)}
    
    def test_policy(self, policy_data: Dict, test_event: Dict = None) -> Dict[str, Any]:
        """测试策略"""
        try:
            if not test_event:
                # 创建默认测试事件
                test_event = {
                    "event_type": "security_alert",
                    "log_data": {
                        "src_ip": "192.168.1.100",
                        "dst_ip": "10.0.0.1",
                        "username": "test_user",
                        "action": "test_action",
                        "severity": "high",
                        "timestamp": datetime.now().isoformat()
                    }
                }
            
            matched_rules = []
            matches_count = 0
            
            # 简单的规则匹配逻辑
            rules = policy_data.get('rules', [])
            for rule in rules:
                condition = rule.get('condition', '')
                
                # 简化的条件匹配（实际应该使用表达式解析器）
                if self.evaluate_condition(condition, test_event):
                    matched_rules.append(rule.get('name', rule.get('rule_id', 'unknown')))
                    matches_count += 1
            
            return {
                'success': True,
                'matches_count': matches_count,
                'triggered_rules': matched_rules,
                'message': f'测试完成，{matches_count} 个规则匹配'
            }
        except Exception as e:
            logger.error(f"测试策略失败: {str(e)}")
            return {'success': False, 'message': str(e)}
    
    def evaluate_condition(self, condition: str, event: Dict) -> bool:
        """评估条件表达式（简化版本）"""
        try:
            # 这是一个简化的条件评估器，实际生产环境应该使用更安全的表达式解析器
            # 替换常见的条件
            condition = condition.replace('event_type', f'"{event.get("event_type", "")}"')
            
            # 处理log_data字段
            log_data = event.get('log_data', {})
            for key, value in log_data.items():
                condition = condition.replace(f'log_data.{key}', f'"{value}"')
            
            # 处理操作符
            condition = condition.replace(' AND ', ' and ')
            condition = condition.replace(' OR ', ' or ')
            condition = condition.replace(' == ', ' == ')
            condition = condition.replace(' LIKE ', ' in ')
            
            # 安全起见，只允许基本的比较操作
            if any(op in condition for op in ['import', 'exec', 'eval', 'open', 'file']):
                return False
            
            # 简单的字符串匹配检查
            if 'security_alert' in condition and event.get('event_type') == 'security_alert':
                return True
            if 'security_brute_force' in condition and event.get('event_type') == 'security_brute_force':
                return True
            if 'security_lateral_movement' in condition and event.get('event_type') == 'security_lateral_movement':
                return True
                
            return False
        except Exception as e:
            logger.error(f"条件评估失败: {str(e)}")
            return False

policy_manager = SecurityPolicyManager()

def generate_test_event_for_policy(policy: Dict) -> Dict:
    """根据策略生成匹配的测试事件"""
    try:
        policy_id = policy.get('policy_id', '')
        policy_name = policy.get('name', '')
        
        # 根据策略类型生成不同的测试事件
        if 'brute_force' in policy_id.lower() or 'brute_force' in policy_name.lower():
            return {
                "event_type": "security_brute_force",
                "log_data": {
                    "src_ip": "203.0.113.100",
                    "dst_ip": "10.0.0.1",
                    "username": "admin",
                    "action": "failed_login",
                    "failure_count": 6,
                    "timestamp": datetime.now().isoformat(),
                    "severity": "high",
                    "matched_policy": policy_id
                }
            }
        elif 'lateral_movement' in policy_id.lower() or 'lateral' in policy_name.lower():
            return {
                "event_type": "security_lateral_movement",
                "log_data": {
                    "src_ip": "192.168.1.100",
                    "dst_ip": "192.168.1.50",
                    "username": "attacker",
                    "action": "ssh_login",
                    "protocol": "SSH",
                    "timestamp": datetime.now().isoformat(),
                    "severity": "critical",
                    "matched_policy": policy_id
                }
            }
        elif 'data_exfiltration' in policy_id.lower() or 'exfiltration' in policy_name.lower():
            return {
                "event_type": "security_data_exfiltration",
                "log_data": {
                    "src_ip": "10.0.0.100",
                    "dst_ip": "198.51.100.1",
                    "username": "admin",
                    "action": "large_data_transfer",
                    "data_size": "250MB",
                    "file_types": "database,financial",
                    "timestamp": datetime.now().isoformat(),
                    "severity": "critical",
                    "matched_policy": policy_id
                }
            }
        elif 'malware' in policy_id.lower() or 'malware' in policy_name.lower():
            return {
                "event_type": "security_malware",
                "log_data": {
                    "src_ip": "192.168.1.100",
                    "dst_ip": "10.0.0.50",
                    "username": "user",
                    "action": "malware_detected",
                    "file_path": "/tmp/suspicious.exe",
                    "malware_family": "trojan",
                    "timestamp": datetime.now().isoformat(),
                    "severity": "critical",
                    "matched_policy": policy_id
                }
            }
        else:
            # 通用安全告警事件
            return {
                "event_type": "security_alert",
                "log_data": {
                    "src_ip": "192.168.1.100",
                    "dst_ip": "10.0.0.1",
                    "username": "test_user",
                    "action": "suspicious_activity",
                    "timestamp": datetime.now().isoformat(),
                    "severity": policy.get('severity', 'medium'),
                    "matched_policy": policy_id
                }
            }
    except Exception as e:
        logger.error(f"生成策略测试事件失败: {str(e)}")
        # 返回默认事件
        return {
            "event_type": "security_demo",
            "log_data": {
                "src_ip": "192.168.1.100",
                "dst_ip": "10.0.0.1",
                "username": "demo_user",
                "action": "test_action",
                "timestamp": datetime.now().isoformat(),
                "severity": "medium"
            }
        }

@app.route('/')
def index():
    """主页"""
    return render_template('demo_dashboard.html')

@app.route('/api/system/info')
def get_system_info():
    """获取系统信息"""
    return jsonify(system_manager.get_system_info())

@app.route('/api/system/status')
def get_system_status():
    """获取系统状态"""
    # 获取请求的主机地址
    host = request.headers.get('Host', 'localhost').split(':')[0]
    
    docker_status = system_manager.check_docker_services()
    api_status = system_manager.check_api_status()
    service_urls = system_manager.get_service_urls(host)
    
    return jsonify({
        'docker': docker_status,
        'api': api_status,
        'urls': service_urls,
        'is_starting': system_manager.is_starting,
        'is_stopping': system_manager.is_stopping,
        'system_status': system_manager.system_status
    })

@app.route('/api/system/start', methods=['POST'])
def start_system():
    """启动系统"""
    if system_manager.is_starting:
        return jsonify({'success': False, 'message': '系统正在启动中'})
    
    def start_process():
        system_manager.is_starting = True
        system_manager.system_status = "starting"
        system_manager.add_log('INFO', '开始启动安全告警分析系统...')
        
        try:
            # 执行启动脚本
            result = system_manager.execute_command('./start_app.sh')
            
            if result['success']:
                system_manager.add_log('SUCCESS', '系统启动成功')
                system_manager.system_status = "running"
            else:
                system_manager.add_log('ERROR', f'系统启动失败: {result["stderr"]}')
                system_manager.system_status = "failed"
                
        except Exception as e:
            system_manager.add_log('ERROR', f'启动过程异常: {str(e)}')
            system_manager.system_status = "failed"
        finally:
            system_manager.is_starting = False
    
    # 在后台线程中启动
    threading.Thread(target=start_process, daemon=True).start()
    
    return jsonify({'success': True, 'message': '启动命令已发送'})

@app.route('/api/system/stop', methods=['POST'])
def stop_system():
    """停止系统"""
    if system_manager.is_stopping:
        return jsonify({'success': False, 'message': '系统正在停止中'})
    
    def stop_process():
        system_manager.is_stopping = True
        system_manager.system_status = "stopping"
        system_manager.add_log('INFO', '开始停止安全告警分析系统...')
        
        try:
            # 执行停止脚本
            result = system_manager.execute_command('./stop_system.sh')
            
            if result['success']:
                system_manager.add_log('SUCCESS', '系统停止成功')
                system_manager.system_status = "stopped"
            else:
                system_manager.add_log('ERROR', f'系统停止失败: {result["stderr"]}')
                
        except Exception as e:
            system_manager.add_log('ERROR', f'停止过程异常: {str(e)}')
        finally:
            system_manager.is_stopping = False
    
    # 在后台线程中停止
    threading.Thread(target=stop_process, daemon=True).start()
    
    return jsonify({'success': True, 'message': '停止命令已发送'})

@app.route('/api/system/restart', methods=['POST'])
def restart_system():
    """重启系统"""
    def restart_process():
        system_manager.add_log('INFO', '开始重启安全告警分析系统...')
        
        # 先停止
        system_manager.is_stopping = True
        system_manager.system_status = "stopping"
        stop_result = system_manager.execute_command('./stop_system.sh')
        
        if stop_result['success']:
            system_manager.add_log('SUCCESS', '系统停止成功，开始启动...')
            time.sleep(3)  # 等待停止完成
            
            # 再启动
            system_manager.is_stopping = False
            system_manager.is_starting = True
            system_manager.system_status = "starting"
            
            start_result = system_manager.execute_command('./start_app.sh')
            
            if start_result['success']:
                system_manager.add_log('SUCCESS', '系统重启成功')
                system_manager.system_status = "running"
            else:
                system_manager.add_log('ERROR', f'系统启动失败: {start_result["stderr"]}')
                system_manager.system_status = "failed"
        else:
            system_manager.add_log('ERROR', f'系统停止失败: {stop_result["stderr"]}')
            
        system_manager.is_starting = False
        system_manager.is_stopping = False
    
    threading.Thread(target=restart_process, daemon=True).start()
    
    return jsonify({'success': True, 'message': '重启命令已发送'})

@app.route('/api/logs')
def get_logs():
    """获取日志"""
    limit = request.args.get('limit', 100, type=int)
    return jsonify({
        'logs': system_manager.logs[-limit:],
        'total': len(system_manager.logs)
    })

def create_attack_graph_in_neo4j(host: str, attack_data: dict):
    """在Neo4j中创建攻击路径图"""
    try:
        # 尝试多个Neo4j连接方式
        neo4j_urls = [
            f'http://localhost:7474/db/neo4j/tx/commit',
            f'http://{host}:7474/db/neo4j/tx/commit',
            f'http://127.0.0.1:7474/db/neo4j/tx/commit'
        ]
        
        # 创建攻击路径的Cypher查询
        cypher_statements = []
        
        # 创建一个简化的攻击路径图
        timestamp = datetime.now().isoformat()
        
        # 单个语句创建完整攻击图
        cypher_statements.append({
            "statement": """
            // 清理旧数据
            MATCH (n) WHERE n.demo_session = $session_id DELETE n
            WITH 1 as dummy
            
            // 创建攻击者
            CREATE (attacker:Attacker {
                id: $attacker_ip, 
                ip: $attacker_ip, 
                name: '攻击者',
                threat_level: '高',
                risk_score: 8.5,
                timestamp: $timestamp,
                demo_session: $session_id
            })
            
            // 创建目标系统
            CREATE (target:System {
                id: 'target_system', 
                name: '目标系统', 
                ip: '10.0.0.1',
                compromised: true,
                timestamp: $timestamp,
                demo_session: $session_id
            })
            
            // 创建服务器1
            CREATE (server1:System {
                id: 'server1', 
                name: '服务器1', 
                ip: '192.168.1.50',
                compromised: true,
                timestamp: $timestamp,
                demo_session: $session_id
            })
            
            // 创建数据库
            CREATE (database:System {
                id: 'database', 
                name: '数据库服务器', 
                ip: '192.168.1.200',
                compromised: false,
                timestamp: $timestamp,
                demo_session: $session_id
            })
            
            // 创建攻击关系
            CREATE (attacker)-[:ATTACKS {action: 'initial_access', method: 'brute_force', timestamp: $timestamp}]->(target)
            CREATE (target)-[:ATTACKS {action: 'lateral_movement', method: 'ssh_login', timestamp: $timestamp}]->(server1)
            CREATE (server1)-[:ATTACKS {action: 'data_access', method: 'privilege_escalation', timestamp: $timestamp}]->(database)
            
            RETURN count(*) as nodes_created
            """,
            "parameters": {
                "attacker_ip": "192.168.1.100",
                "timestamp": timestamp,
                "session_id": f"demo_{int(time.time())}"
            }
        })
        
        # 发送到Neo4j - 尝试多个连接方式
        payload = {"statements": cypher_statements}
        
        for neo4j_url in neo4j_urls:
            try:
                response = requests.post(
                    neo4j_url,
                    json=payload,
                    headers={'Content-Type': 'application/json'},
                    auth=('neo4j', 'security123'),
                    timeout=5  # 减少超时时间
                )
                
                if response.status_code == 200:
                    result = response.json()
                    if not result.get('errors'):
                        system_manager.add_log('SUCCESS', '攻击路径已写入Neo4j图数据库')
                        return True
                    else:
                        system_manager.add_log('WARNING', f'Neo4j查询错误: {result["errors"]}')
                else:
                    system_manager.add_log('DEBUG', f'Neo4j响应状态: {response.status_code} (URL: {neo4j_url})')
                    
            except requests.RequestException as e:
                system_manager.add_log('DEBUG', f'Neo4j连接尝试失败: {neo4j_url} - {str(e)}')
                continue
        
        system_manager.add_log('WARNING', 'Neo4j不可用，攻击路径图未创建（演示功能仍可正常使用）')
        return False
            
    except Exception as e:
        system_manager.add_log('WARNING', f'Neo4j连接失败: {str(e)}')
        return False

@app.route('/api/demo/test-event', methods=['POST'])
def create_test_event():
    """创建测试事件"""
    try:
        # 获取当前启用的策略列表
        enabled_policies = [p for p in policy_manager.get_policies() if p.get('enabled', True)]
        
        if enabled_policies:
            # 随机选择一个策略来生成匹配的测试事件
            import random
            selected_policy = random.choice(enabled_policies)
            test_data = generate_test_event_for_policy(selected_policy)
            
            # 记录使用的策略
            system_manager.add_log('INFO', f'基于策略"{selected_policy["name"]}"生成测试事件')
        else:
            # 如果没有启用的策略，使用默认测试事件
            test_data = {
                "event_type": "security_demo",
                "log_data": {
                    "src_ip": "192.168.1.100",
                    "dst_ip": "10.0.0.1",
                    "username": "demo_user",
                    "action": "login_attempt",
                    "timestamp": datetime.now().isoformat(),
                    "severity": "medium"
                }
            }
            system_manager.add_log('INFO', '使用默认测试事件（未找到启用的策略）')
        
        # 获取请求的主机地址
        host = request.headers.get('Host', 'localhost').split(':')[0]
        
        response = requests.post(
            f'http://{host}:8000/api/v1/analyze/event',
            json=test_data,
            timeout=10
        )
        
        if response.status_code == 200:
            result_data = response.json()
            system_manager.add_log('INFO', '测试事件分析完成')
            
            # 解析分析结果并显示详情
            if result_data.get('success') and result_data.get('data'):
                event_data = result_data['data']
                entities = event_data.get('entities', [])
                max_risk = event_data.get('risk_score', 0)
                
                # 发送实体分析结果到前端，包含策略信息
                matched_policy_id = test_data['log_data'].get('matched_policy')
                matched_policy = None
                if matched_policy_id:
                    matched_policy = policy_manager.get_policy(matched_policy_id)
                
                socketio.emit('entity_analysis', {
                    'entities': entities,
                    'max_risk_score': max_risk,
                    'event_id': event_data.get('event_id', 'unknown'),
                    'matched_policy': {
                        'policy_id': matched_policy_id,
                        'policy_name': matched_policy['name'] if matched_policy else '未知策略',
                        'description': matched_policy['description'] if matched_policy else ''
                    } if matched_policy_id else None,
                    'timestamp': datetime.now().isoformat()
                })
                
                # 发送攻击演示更新
                socketio.emit('attack_demo_update', {
                    'stage': 'intrusion_detected',
                    'steps': [
                        {'id': 'step-detect-intrusion', 'status': 'completed'},
                        {'id': 'step-analyze-source', 'status': 'investigating'}
                    ],
                    'nodes': [
                        {'id': 'node-target', 'status': 'compromised'}
                    ]
                })
                
                # 显示实体分析结果
                if entities:
                    entity_details = []
                    for entity in entities:
                        entity_type = entity.get('entity_type', 'unknown')
                        entity_id = entity.get('entity_id', 'N/A')
                        risk_score = entity.get('risk_score', 0)
                        threat_level = entity.get('threat_level', '未知')
                        
                        entity_details.append(f"{entity_type}:{entity_id}")
                    
                    system_manager.add_log('INFO', f'检测到 {len(entities)} 个实体: {", ".join(entity_details)}')
                    system_manager.add_log('INFO', f'最高风险评分: {max_risk:.1f}')
                    
                    # 显示威胁等级
                    high_risk_count = sum(1 for e in entities if e.get('risk_score', 0) > 70)
                    if high_risk_count > 0:
                        system_manager.add_log('WARNING', f'发现 {high_risk_count} 个高风险实体！')
                    
                    # 发送横向移动阶段更新
                    def send_lateral_movement_update():
                        import time
                        time.sleep(3)  # 延迟3秒
                        socketio.emit('attack_demo_update', {
                            'stage': 'lateral_movement',
                            'steps': [
                                {'id': 'step-track-movement', 'status': 'investigating'},
                                {'id': 'step-identify-assets', 'status': 'pending'}
                            ],
                            'nodes': [
                                {'id': 'node-entry', 'status': 'compromised'},
                                {'id': 'node-server1', 'status': 'investigating'}
                            ]
                        })
                    
                    # 发送威胁分析阶段更新
                    def send_threat_analysis_update():
                        import time
                        time.sleep(6)  # 延迟6秒
                        socketio.emit('attack_demo_update', {
                            'stage': 'threat_analysis',
                            'steps': [
                                {'id': 'step-assess-impact', 'status': 'investigating'},
                                {'id': 'step-generate-report', 'status': 'pending'}
                            ]
                        })
                    
                    # 在后台线程中发送延迟更新
                    threading.Thread(target=send_lateral_movement_update, daemon=True).start()
                    threading.Thread(target=send_threat_analysis_update, daemon=True).start()
                
                # 在Neo4j中创建攻击路径图
                create_attack_graph_in_neo4j(host, {
                    'timestamp': datetime.now().isoformat(),
                    'entities': entities,
                    'risk_score': max_risk
                })
            
            return jsonify({
                'success': True, 
                'message': '测试事件创建成功',
                'response': result_data
            })
        else:
            return jsonify({
                'success': False,
                'message': f'API返回错误: {response.status_code}'
            })
            
    except requests.RequestException as e:
        return jsonify({
            'success': False,
            'message': f'API连接失败: {str(e)}'
        })

@app.route('/api/demo/scenarios')
def get_demo_scenarios():
    """获取演示场景"""
    # 获取当前策略列表来关联场景
    policies = policy_manager.get_policies()
    policy_map = {p['policy_id']: p for p in policies}
    
    scenarios = [
        {
            'id': 'lateral_movement',
            'name': '横向移动攻击演示',
            'description': '模拟攻击者在内网中的横向移动行为，触发横向移动检测策略',
            'events': 5,
            'duration': '30秒',
            'related_policies': [
                {
                    'policy_id': 'default_lateral_movement_detection',
                    'name': policy_map.get('default_lateral_movement_detection', {}).get('name', '横向移动检测策略'),
                    'enabled': policy_map.get('default_lateral_movement_detection', {}).get('enabled', False)
                }
            ]
        },
        {
            'id': 'brute_force',
            'name': '暴力破解攻击演示',
            'description': '模拟对系统账户的暴力破解尝试，触发暴力破解检测策略',
            'events': 10,
            'duration': '60秒',
            'related_policies': [
                {
                    'policy_id': 'default_brute_force_detection',
                    'name': policy_map.get('default_brute_force_detection', {}).get('name', '暴力破解检测策略'),
                    'enabled': policy_map.get('default_brute_force_detection', {}).get('enabled', False)
                }
            ]
        },
        {
            'id': 'data_exfiltration',
            'name': '数据泄露攻击演示',
            'description': '模拟敏感数据的非法外传行为，触发数据泄露检测策略',
            'events': 8,
            'duration': '45秒',
            'related_policies': []  # 需要用户自己创建数据泄露策略
        },
        {
            'id': 'comprehensive_attack',
            'name': '综合攻击场景',
            'description': '完整的攻击链演示：暴力破解→横向移动→数据泄露',
            'events': 15,
            'duration': '90秒',
            'related_policies': [
                {
                    'policy_id': 'default_brute_force_detection',
                    'name': policy_map.get('default_brute_force_detection', {}).get('name', '暴力破解检测策略'),
                    'enabled': policy_map.get('default_brute_force_detection', {}).get('enabled', False)
                },
                {
                    'policy_id': 'default_lateral_movement_detection',
                    'name': policy_map.get('default_lateral_movement_detection', {}).get('name', '横向移动检测策略'),
                    'enabled': policy_map.get('default_lateral_movement_detection', {}).get('enabled', False)
                }
            ]
        }
    ]
    return jsonify({'scenarios': scenarios})

@app.route('/api/demo/run-scenario/<scenario_id>', methods=['POST'])
def run_demo_scenario(scenario_id):
    """运行演示场景"""
    # 获取请求的主机地址
    host = request.headers.get('Host', 'localhost').split(':')[0]
    
    def generate_scenario_events():
        system_manager.add_log('INFO', f'开始运行演示场景: {scenario_id}')
        
        scenarios_data = {
            'lateral_movement': [
                {'src_ip': '192.168.1.100', 'dst_ip': '192.168.1.50', 'action': 'ssh_login'},
                {'src_ip': '192.168.1.50', 'dst_ip': '192.168.1.75', 'action': 'file_access'},
                {'src_ip': '192.168.1.75', 'dst_ip': '192.168.1.200', 'action': 'network_scan'},
                {'src_ip': '192.168.1.200', 'dst_ip': '192.168.1.10', 'action': 'privilege_escalation'},
                {'src_ip': '192.168.1.10', 'dst_ip': '10.0.0.100', 'action': 'data_access'}
            ],
            'brute_force': [
                {'src_ip': '203.0.113.1', 'username': 'admin', 'action': 'failed_login'},
                {'src_ip': '203.0.113.1', 'username': 'root', 'action': 'failed_login'},
                {'src_ip': '203.0.113.1', 'username': 'administrator', 'action': 'failed_login'},
                {'src_ip': '203.0.113.1', 'username': 'user', 'action': 'failed_login'},
                {'src_ip': '203.0.113.1', 'username': 'guest', 'action': 'failed_login'}
            ],
            'data_exfiltration': [
                {'src_ip': '192.168.1.100', 'file_path': '/data/customer_info.db', 'action': 'file_read'},
                {'src_ip': '192.168.1.100', 'dst_ip': '198.51.100.1', 'action': 'large_upload'},
                {'src_ip': '192.168.1.100', 'file_path': '/data/financial_records.xlsx', 'action': 'file_copy'},
                {'src_ip': '192.168.1.100', 'dst_ip': '198.51.100.1', 'action': 'encrypted_transfer'}
            ]
        }
        
        events = scenarios_data.get(scenario_id, [])
        
        for i, event_data in enumerate(events):
            try:
                # 构造事件数据
                test_event = {
                    "event_type": f"demo_{scenario_id}",
                    "log_data": {
                        **event_data,
                        "timestamp": datetime.now().isoformat(),
                        "severity": "high" if scenario_id == 'data_exfiltration' else "medium",
                        "sequence": i + 1,
                        "scenario": scenario_id
                    }
                }
                
                # 发送到API
                response = requests.post(
                    f'http://{host}:8000/api/v1/analyze/event',
                    json=test_event,
                    timeout=30
                )
                
                if response.status_code == 200:
                    result_data = response.json()
                    system_manager.add_log('INFO', f'场景事件 {i+1} 分析完成')
                    
                    # 解析分析结果
                    if result_data.get('success') and result_data.get('data'):
                        event_data = result_data['data']
                        entities = event_data.get('entities', [])
                        max_risk = event_data.get('risk_score', 0)
                        
                        # 显示实体信息
                        if entities:
                            entity_info = []
                            for entity in entities:
                                entity_info.append(f"{entity.get('entity_type', 'unknown')}:{entity.get('entity_id', 'N/A')}(风险:{entity.get('risk_score', 0):.1f})")
                            
                            system_manager.add_log('INFO', f'  → 检测到 {len(entities)} 个实体: {", ".join(entity_info)}')
                            system_manager.add_log('INFO', f'  → 最高风险评分: {max_risk:.1f}')
                            
                            # 显示攻击链
                            if i > 0:
                                system_manager.add_log('WARNING', f'  → 横向移动检测: 攻击链第 {i+1} 步')
                else:
                    system_manager.add_log('ERROR', f'场景事件 {i+1} 分析失败')
                
                # 事件间隔
                time.sleep(5)
                
            except Exception as e:
                system_manager.add_log('ERROR', f'场景事件发送异常: {str(e)}')
        
        system_manager.add_log('SUCCESS', f'演示场景 {scenario_id} 执行完成')
    
    # 在后台线程中执行
    threading.Thread(target=generate_scenario_events, daemon=True).start()
    
    return jsonify({'success': True, 'message': f'演示场景 {scenario_id} 开始执行'})

@app.route('/api/demo/event-templates')
def get_event_templates():
    """获取事件模板"""
    templates = {
        'yaml_templates': {
            'attack_scenario': {
                'name': '攻击场景',
                'description': '多步骤横向移动攻击演示',
                'events_count': 2,
                'template': '''events:
  - event_type: security_lateral_movement
    log_data:
      src_ip: "192.168.1.100"
      dst_ip: "192.168.1.50"
      username: "attacker"
      action: "ssh_login"
      timestamp: "2024-01-15T10:30:00Z"
      severity: "high"
      
  - event_type: security_privilege_escalation
    log_data:
      src_ip: "192.168.1.50"
      dst_ip: "192.168.1.200"
      username: "root"
      action: "privilege_escalation"
      timestamp: "2024-01-15T10:35:00Z"
      severity: "critical"'''
            },
            'malware_detection': {
                'name': '恶意软件检测',
                'description': '恶意软件检测和分析事件',
                'events_count': 1,
                'template': '''event_type: security_malware
log_data:
  src_ip: "203.0.113.50"
  dst_ip: "10.0.0.100"
  username: "user"
  action: "malware_detected"
  file_path: "/tmp/suspicious.exe"
  malware_family: "trojan"
  timestamp: "2024-01-15T10:00:00Z"
  severity: "critical"'''
            },
            'data_breach': {
                'name': '数据泄露',
                'description': '敏感数据外传检测事件',
                'events_count': 1,
                'template': '''event_type: security_data_exfiltration
log_data:
  src_ip: "10.0.0.100"
  dst_ip: "198.51.100.1"
  username: "admin"
  action: "large_data_transfer"
  data_size: "500MB"
  file_types: "database,documents"
  timestamp: "2024-01-15T14:30:00Z"
  severity: "critical"'''
            }
        },
        'json_templates': {
            'basic_alert': {
                'name': '基础告警',
                'description': '标准安全告警事件',
                'template': {
                    "event_type": "security_alert",
                    "log_data": {
                        "src_ip": "192.168.1.100",
                        "dst_ip": "10.0.0.1",
                        "username": "user",
                        "action": "login_attempt",
                        "timestamp": datetime.now().isoformat(),
                        "severity": "medium"
                    }
                }
            },
            'network_event': {
                'name': '网络事件',
                'description': '网络连接和流量分析事件',
                'template': {
                    "event_type": "security_network",
                    "log_data": {
                        "src_ip": "203.0.113.50",
                        "dst_ip": "10.0.0.100",
                        "src_port": 45123,
                        "dst_port": 22,
                        "protocol": "TCP",
                        "action": "connection_attempt",
                        "bytes_transferred": 1024,
                        "timestamp": datetime.now().isoformat(),
                        "severity": "medium"
                    }
                }
            }
        }
    }
    
    return jsonify(templates)

@app.route('/api/demo/validate-event', methods=['POST'])
def validate_event():
    """验证事件格式"""
    try:
        event_data = request.get_json()
        
        if not event_data:
            return jsonify({
                'valid': False,
                'errors': ['请提供事件数据'],
                'warnings': []
            })
        
        errors = []
        warnings = []
        
        # 基础字段验证
        if not event_data.get('event_type'):
            errors.append('缺少必需字段: event_type')
        
        if not event_data.get('log_data'):
            errors.append('缺少必需字段: log_data')
        else:
            log_data = event_data['log_data']
            
            # 推荐字段检查
            recommended_fields = ['timestamp', 'severity', 'src_ip', 'action']
            for field in recommended_fields:
                if not log_data.get(field):
                    warnings.append(f'建议添加字段: {field}')
            
            # 数据类型检查
            if log_data.get('severity') and log_data['severity'] not in ['low', 'medium', 'high', 'critical']:
                warnings.append('severity建议使用: low, medium, high, critical')
        
        return jsonify({
            'valid': len(errors) == 0,
            'errors': errors,
            'warnings': warnings,
            'field_count': len(event_data.get('log_data', {})),
            'event_type': event_data.get('event_type', 'N/A')
        })
        
    except Exception as e:
        return jsonify({
            'valid': False,
            'errors': [f'JSON解析错误: {str(e)}'],
            'warnings': []
        }), 400

@socketio.on('connect')
def handle_connect():
    """WebSocket连接"""
    emit('connected', {'message': '连接成功'})

# Security Policies API Routes
@app.route('/api/policies', methods=['GET'])
def get_policies():
    """获取策略列表"""
    try:
        policies = policy_manager.get_policies()
        return jsonify({
            'success': True,
            'policies': policies,
            'count': len(policies)
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/policies/<policy_id>', methods=['GET'])
def get_policy(policy_id):
    """获取单个策略"""
    try:
        policy = policy_manager.get_policy(policy_id)
        if policy:
            return jsonify({'success': True, 'policy': policy})
        else:
            return jsonify({'success': False, 'message': '策略不存在'}), 404
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/policies', methods=['POST'])
def create_policy():
    """创建策略"""
    try:
        policy_data = request.get_json()
        if not policy_data:
            return jsonify({'success': False, 'message': '缺少策略数据'}), 400
        
        if policy_manager.add_policy(policy_data):
            return jsonify({'success': True, 'message': '策略创建成功'})
        else:
            return jsonify({'success': False, 'message': '策略创建失败'}), 500
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/policies/<policy_id>', methods=['PUT'])
def update_policy(policy_id):
    """更新策略"""
    try:
        policy_data = request.get_json()
        if not policy_data:
            return jsonify({'success': False, 'message': '缺少策略数据'}), 400
        
        if policy_manager.update_policy(policy_id, policy_data):
            return jsonify({'success': True, 'message': '策略更新成功'})
        else:
            return jsonify({'success': False, 'message': '策略更新失败'}), 404
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/policies/<policy_id>', methods=['DELETE'])
def delete_policy(policy_id):
    """删除策略"""
    try:
        if policy_manager.delete_policy(policy_id):
            return jsonify({'success': True, 'message': '策略删除成功'})
        else:
            return jsonify({'success': False, 'message': '策略删除失败'}), 404
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/policies/<policy_id>/toggle', methods=['PUT'])
def toggle_policy(policy_id):
    """启用/禁用策略"""
    try:
        data = request.get_json()
        if 'enabled' not in data:
            return jsonify({'success': False, 'message': '缺少enabled参数'}), 400
        
        if policy_manager.toggle_policy(policy_id, data['enabled']):
            return jsonify({'success': True, 'message': '策略状态更新成功'})
        else:
            return jsonify({'success': False, 'message': '策略状态更新失败'}), 404
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/policies/import', methods=['POST'])
def import_policies():
    """导入策略"""
    try:
        data = request.get_json()
        if not data or 'policies' not in data:
            return jsonify({'success': False, 'message': '缺少策略数据'}), 400
        
        result = policy_manager.import_policies(data['policies'])
        if result['success']:
            return jsonify(result)
        else:
            return jsonify(result), 500
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/policies/export', methods=['POST'])
def export_policies():
    """导出策略"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'message': '缺少导出参数'}), 400
        
        policy_ids = data.get('policy_ids', [])
        format_type = data.get('format', 'json')
        include_disabled = data.get('include_disabled', True)
        include_metadata = data.get('include_metadata', True)
        
        result = policy_manager.export_policies(
            policy_ids=policy_ids,
            format_type=format_type,
            include_disabled=include_disabled,
            include_metadata=include_metadata
        )
        
        if result['success']:
            response = Response(
                result['data'],
                mimetype=result['content_type'],
                headers={
                    'Content-Disposition': f'attachment; filename=security_policies.{format_type}'
                }
            )
            return response
        else:
            return jsonify(result), 500
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/policies/test', methods=['POST'])
def test_policy():
    """测试策略"""
    try:
        data = request.get_json()
        if not data or 'policy' not in data:
            return jsonify({'success': False, 'message': '缺少策略数据'}), 400
        
        policy_data = data['policy']
        test_event = data.get('test_event')
        
        result = policy_manager.test_policy(policy_data, test_event)
        return jsonify(result)
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/policies/<policy_id>/test', methods=['POST'])
def test_policy_by_id(policy_id):
    """按ID测试策略"""
    try:
        policy = policy_manager.get_policy(policy_id)
        if not policy:
            return jsonify({'success': False, 'message': '策略不存在'}), 404
        
        data = request.get_json() or {}
        test_event = data.get('test_event')
        
        result = policy_manager.test_policy(policy, test_event)
        return jsonify(result)
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@socketio.on('connect')
def handle_connect():
    """WebSocket连接"""
    emit('connected', {'message': '连接成功'})

@socketio.on('request_status')
def handle_status_request():
    """请求状态更新"""
    status = get_system_status().get_json()
    emit('status_update', status)

if __name__ == '__main__':
    print("🚀 启动安全告警分析系统演示管理界面...")
    print("📱 访问地址: http://localhost:5115")
    
    # 确保必要的目录存在
    demo_web_dir = project_root / 'demo_web'
    demo_web_dir.mkdir(exist_ok=True)
    (demo_web_dir / 'templates').mkdir(exist_ok=True)
    (demo_web_dir / 'static').mkdir(exist_ok=True)
    
    socketio.run(app, host='0.0.0.0', port=5115, debug=False, allow_unsafe_werkzeug=True)