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
    
    def get_service_urls(self) -> Dict[str, str]:
        """获取服务访问URL"""
        return {
            'api': 'http://localhost:8000',
            'api_docs': 'http://localhost:8000/docs',
            'kibana': 'http://localhost:5601',
            'neo4j': 'http://localhost:7474',
            'clickhouse': 'http://localhost:8123/play',
            'kafka_ui': 'http://localhost:8082',
            'elasticsearch': 'http://localhost:9200'
        }

system_manager = SystemManager()

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
    docker_status = system_manager.check_docker_services()
    api_status = system_manager.check_api_status()
    service_urls = system_manager.get_service_urls()
    
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
            result = system_manager.execute_command('./one_click_start.sh')
            
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
            
            start_result = system_manager.execute_command('./one_click_start.sh')
            
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

@app.route('/api/demo/test-event', methods=['POST'])
def create_test_event():
    """创建测试事件"""
    try:
        # 发送测试事件到API
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
        
        response = requests.post(
            'http://localhost:8000/api/v1/analyze/event',
            json=test_data,
            timeout=10
        )
        
        if response.status_code == 200:
            system_manager.add_log('INFO', '测试事件创建成功')
            return jsonify({
                'success': True, 
                'message': '测试事件创建成功',
                'response': response.json()
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
    scenarios = [
        {
            'id': 'lateral_movement',
            'name': '横向移动攻击',
            'description': '模拟攻击者在内网中的横向移动行为',
            'events': 5,
            'duration': '30秒'
        },
        {
            'id': 'brute_force',
            'name': '暴力破解攻击',
            'description': '模拟对系统账户的暴力破解尝试',
            'events': 10,
            'duration': '60秒'
        },
        {
            'id': 'data_exfiltration',
            'name': '数据泄露',
            'description': '模拟敏感数据的非法外传行为',
            'events': 8,
            'duration': '45秒'
        }
    ]
    return jsonify({'scenarios': scenarios})

@app.route('/api/demo/run-scenario/<scenario_id>', methods=['POST'])
def run_demo_scenario(scenario_id):
    """运行演示场景"""
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
                    'http://localhost:8000/api/v1/analyze/event',
                    json=test_event,
                    timeout=30
                )
                
                if response.status_code == 200:
                    system_manager.add_log('INFO', f'场景事件 {i+1} 发送成功')
                else:
                    system_manager.add_log('ERROR', f'场景事件 {i+1} 发送失败')
                
                # 事件间隔
                time.sleep(5)
                
            except Exception as e:
                system_manager.add_log('ERROR', f'场景事件发送异常: {str(e)}')
        
        system_manager.add_log('SUCCESS', f'演示场景 {scenario_id} 执行完成')
    
    # 在后台线程中执行
    threading.Thread(target=generate_scenario_events, daemon=True).start()
    
    return jsonify({'success': True, 'message': f'演示场景 {scenario_id} 开始执行'})

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