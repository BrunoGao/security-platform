"""
Response Execution Engine
响应执行引擎 - 自动化执行安全响应措施
"""

import logging
import asyncio
from abc import ABC, abstractmethod
from enum import Enum
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime
import json

from ..models.entities import SecurityEntity, EntityType, EntityStatus


class ResponseAction(Enum):
    """响应动作枚举"""
    # 网络响应
    BLOCK_IP = "block_ip"
    UNBLOCK_IP = "unblock_ip"
    ISOLATE_HOST = "isolate_host"
    
    # 用户响应
    DISABLE_USER = "disable_user"
    ENABLE_USER = "enable_user"
    RESET_PASSWORD = "reset_password"
    REVOKE_TOKEN = "revoke_token"
    
    # 文件响应
    QUARANTINE_FILE = "quarantine_file"
    DELETE_FILE = "delete_file"
    RESTORE_FILE = "restore_file"
    
    # 进程响应
    KILL_PROCESS = "kill_process"
    SUSPEND_PROCESS = "suspend_process"
    
    # 告警响应
    SEND_ALERT = "send_alert"
    CREATE_TICKET = "create_ticket"
    NOTIFY_ADMIN = "notify_admin"
    
    # 取证响应
    COLLECT_EVIDENCE = "collect_evidence"
    TAKE_SNAPSHOT = "take_snapshot"
    DUMP_MEMORY = "dump_memory"


class ResponseStatus(Enum):
    """响应状态枚举"""
    PENDING = "待执行"
    EXECUTING = "执行中"
    SUCCESS = "执行成功"
    FAILED = "执行失败"
    TIMEOUT = "执行超时"
    CANCELLED = "已取消"


class ResponseExecutor(ABC):
    """响应执行器抽象基类"""
    
    def __init__(self, executor_id: str, config: Dict[str, Any] = None):
        self.executor_id = executor_id
        self.config = config or {}
        self.logger = logging.getLogger(f"{__name__}.{executor_id}")
    
    @abstractmethod
    async def execute(self, entity: SecurityEntity, action: ResponseAction, 
                     params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """
        执行响应动作
        Returns: (success, message)
        """
        pass
    
    @abstractmethod
    def can_handle(self, entity: SecurityEntity, action: ResponseAction) -> bool:
        """检查是否能处理指定的实体和动作"""
        pass


class FirewallExecutor(ResponseExecutor):
    """防火墙执行器"""
    
    def __init__(self, config: Dict[str, Any] = None):
        super().__init__("firewall", config)
        self.api_endpoint = self.config.get('api_endpoint', 'http://firewall-api:8080')
        self.api_key = self.config.get('api_key', '')
    
    def can_handle(self, entity: SecurityEntity, action: ResponseAction) -> bool:
        """检查是否能处理指定的实体和动作"""
        if entity.entity_type != EntityType.IP:
            return False
        return action in [ResponseAction.BLOCK_IP, ResponseAction.UNBLOCK_IP]
    
    async def execute(self, entity: SecurityEntity, action: ResponseAction, 
                     params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """执行防火墙操作"""
        try:
            ip_address = entity.entity_id
            
            if action == ResponseAction.BLOCK_IP:
                success, message = await self._block_ip(ip_address, params)
            elif action == ResponseAction.UNBLOCK_IP:
                success, message = await self._unblock_ip(ip_address, params)
            else:
                return False, f"Unsupported action: {action}"
            
            if success:
                self.logger.info(f"Successfully executed {action.value} for IP {ip_address}")
            else:
                self.logger.error(f"Failed to execute {action.value} for IP {ip_address}: {message}")
            
            return success, message
            
        except Exception as e:
            error_msg = f"Error executing firewall action: {e}"
            self.logger.error(error_msg)
            return False, error_msg
    
    async def _block_ip(self, ip_address: str, params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """阻断IP地址"""
        try:
            # 这里实现具体的防火墙API调用
            # 示例实现
            rule_data = {
                'action': 'block',
                'source_ip': ip_address,
                'duration': params.get('duration', 3600) if params else 3600,  # 默认1小时
                'reason': params.get('reason', 'Security threat detected') if params else 'Security threat detected'
            }
            
            # 模拟API调用
            await asyncio.sleep(0.1)  # 模拟网络延迟
            
            # 实际实现中这里应该是HTTP请求
            # response = await self._make_api_call('/api/firewall/block', rule_data)
            
            self.logger.info(f"Blocked IP {ip_address} with rule: {rule_data}")
            return True, f"Successfully blocked IP {ip_address}"
            
        except Exception as e:
            return False, f"Failed to block IP {ip_address}: {e}"
    
    async def _unblock_ip(self, ip_address: str, params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """解除IP阻断"""
        try:
            rule_data = {
                'action': 'unblock',
                'source_ip': ip_address,
                'reason': params.get('reason', 'Manual unblock') if params else 'Manual unblock'
            }
            
            await asyncio.sleep(0.1)
            
            self.logger.info(f"Unblocked IP {ip_address}")
            return True, f"Successfully unblocked IP {ip_address}"
            
        except Exception as e:
            return False, f"Failed to unblock IP {ip_address}: {e}"


class ADExecutor(ResponseExecutor):
    """Active Directory执行器"""
    
    def __init__(self, config: Dict[str, Any] = None):
        super().__init__("active_directory", config)
        self.ldap_server = self.config.get('ldap_server', 'ldap://ad-server:389')
        self.admin_user = self.config.get('admin_user', 'admin')
        self.admin_password = self.config.get('admin_password', '')
    
    def can_handle(self, entity: SecurityEntity, action: ResponseAction) -> bool:
        """检查是否能处理指定的实体和动作"""
        if entity.entity_type != EntityType.USER:
            return False
        return action in [
            ResponseAction.DISABLE_USER, ResponseAction.ENABLE_USER,
            ResponseAction.RESET_PASSWORD, ResponseAction.REVOKE_TOKEN
        ]
    
    async def execute(self, entity: SecurityEntity, action: ResponseAction, 
                     params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """执行AD操作"""
        try:
            username = entity.entity_id
            
            if action == ResponseAction.DISABLE_USER:
                success, message = await self._disable_user(username, params)
            elif action == ResponseAction.ENABLE_USER:
                success, message = await self._enable_user(username, params)
            elif action == ResponseAction.RESET_PASSWORD:
                success, message = await self._reset_password(username, params)
            elif action == ResponseAction.REVOKE_TOKEN:
                success, message = await self._revoke_token(username, params)
            else:
                return False, f"Unsupported action: {action}"
            
            if success:
                self.logger.info(f"Successfully executed {action.value} for user {username}")
            else:
                self.logger.error(f"Failed to execute {action.value} for user {username}: {message}")
            
            return success, message
            
        except Exception as e:
            error_msg = f"Error executing AD action: {e}"
            self.logger.error(error_msg)
            return False, error_msg
    
    async def _disable_user(self, username: str, params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """禁用用户账户"""
        try:
            # 实际实现中这里应该调用LDAP API
            await asyncio.sleep(0.1)
            
            reason = params.get('reason', 'Security incident') if params else 'Security incident'
            self.logger.info(f"Disabled user {username}, reason: {reason}")
            
            return True, f"Successfully disabled user {username}"
            
        except Exception as e:
            return False, f"Failed to disable user {username}: {e}"
    
    async def _enable_user(self, username: str, params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """启用用户账户"""
        try:
            await asyncio.sleep(0.1)
            
            self.logger.info(f"Enabled user {username}")
            return True, f"Successfully enabled user {username}"
            
        except Exception as e:
            return False, f"Failed to enable user {username}: {e}"
    
    async def _reset_password(self, username: str, params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """重置用户密码"""
        try:
            await asyncio.sleep(0.1)
            
            # 生成临时密码
            import secrets
            import string
            temp_password = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(12))
            
            self.logger.info(f"Reset password for user {username}")
            return True, f"Successfully reset password for user {username}, temp password: {temp_password}"
            
        except Exception as e:
            return False, f"Failed to reset password for user {username}: {e}"
    
    async def _revoke_token(self, username: str, params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """撤销用户令牌"""
        try:
            await asyncio.sleep(0.1)
            
            self.logger.info(f"Revoked tokens for user {username}")
            return True, f"Successfully revoked tokens for user {username}"
            
        except Exception as e:
            return False, f"Failed to revoke tokens for user {username}: {e}"


class EDRExecutor(ResponseExecutor):
    """EDR执行器"""
    
    def __init__(self, config: Dict[str, Any] = None):
        super().__init__("edr", config)
        self.edr_api_endpoint = self.config.get('api_endpoint', 'http://edr-server:8080')
        self.api_key = self.config.get('api_key', '')
    
    def can_handle(self, entity: SecurityEntity, action: ResponseAction) -> bool:
        """检查是否能处理指定的实体和动作"""
        entity_actions = {
            EntityType.DEVICE: [ResponseAction.ISOLATE_HOST, ResponseAction.TAKE_SNAPSHOT, ResponseAction.DUMP_MEMORY],
            EntityType.FILE: [ResponseAction.QUARANTINE_FILE, ResponseAction.DELETE_FILE, ResponseAction.RESTORE_FILE],
            EntityType.PROCESS: [ResponseAction.KILL_PROCESS, ResponseAction.SUSPEND_PROCESS]
        }
        
        return entity.entity_type in entity_actions and action in entity_actions[entity.entity_type]
    
    async def execute(self, entity: SecurityEntity, action: ResponseAction, 
                     params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """执行EDR操作"""
        try:
            if entity.entity_type == EntityType.DEVICE:
                return await self._execute_device_action(entity, action, params)
            elif entity.entity_type == EntityType.FILE:
                return await self._execute_file_action(entity, action, params)
            elif entity.entity_type == EntityType.PROCESS:
                return await self._execute_process_action(entity, action, params)
            else:
                return False, f"Unsupported entity type: {entity.entity_type}"
                
        except Exception as e:
            error_msg = f"Error executing EDR action: {e}"
            self.logger.error(error_msg)
            return False, error_msg
    
    async def _execute_device_action(self, entity: SecurityEntity, action: ResponseAction, 
                                   params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """执行设备相关操作"""
        device_id = entity.entity_id
        
        try:
            if action == ResponseAction.ISOLATE_HOST:
                await asyncio.sleep(0.2)
                self.logger.info(f"Isolated host {device_id}")
                return True, f"Successfully isolated host {device_id}"
                
            elif action == ResponseAction.TAKE_SNAPSHOT:
                await asyncio.sleep(0.5)
                snapshot_id = f"snapshot_{device_id}_{int(datetime.now().timestamp())}"
                self.logger.info(f"Created snapshot {snapshot_id} for host {device_id}")
                return True, f"Successfully created snapshot {snapshot_id}"
                
            elif action == ResponseAction.DUMP_MEMORY:
                await asyncio.sleep(1.0)
                dump_id = f"memdump_{device_id}_{int(datetime.now().timestamp())}"
                self.logger.info(f"Created memory dump {dump_id} for host {device_id}")
                return True, f"Successfully created memory dump {dump_id}"
                
            else:
                return False, f"Unsupported device action: {action}"
                
        except Exception as e:
            return False, f"Failed to execute device action {action}: {e}"
    
    async def _execute_file_action(self, entity: SecurityEntity, action: ResponseAction, 
                                 params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """执行文件相关操作"""
        file_path = entity.entity_id
        
        try:
            if action == ResponseAction.QUARANTINE_FILE:
                await asyncio.sleep(0.1)
                quarantine_id = f"quarantine_{int(datetime.now().timestamp())}"
                self.logger.info(f"Quarantined file {file_path} with ID {quarantine_id}")
                return True, f"Successfully quarantined file {file_path}"
                
            elif action == ResponseAction.DELETE_FILE:
                await asyncio.sleep(0.1)
                self.logger.info(f"Deleted file {file_path}")
                return True, f"Successfully deleted file {file_path}"
                
            elif action == ResponseAction.RESTORE_FILE:
                await asyncio.sleep(0.1)
                self.logger.info(f"Restored file {file_path}")
                return True, f"Successfully restored file {file_path}"
                
            else:
                return False, f"Unsupported file action: {action}"
                
        except Exception as e:
            return False, f"Failed to execute file action {action}: {e}"
    
    async def _execute_process_action(self, entity: SecurityEntity, action: ResponseAction, 
                                    params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """执行进程相关操作"""
        process_name = entity.entity_id
        
        try:
            if action == ResponseAction.KILL_PROCESS:
                await asyncio.sleep(0.1)
                self.logger.info(f"Killed process {process_name}")
                return True, f"Successfully killed process {process_name}"
                
            elif action == ResponseAction.SUSPEND_PROCESS:
                await asyncio.sleep(0.1)
                self.logger.info(f"Suspended process {process_name}")
                return True, f"Successfully suspended process {process_name}"
                
            else:
                return False, f"Unsupported process action: {action}"
                
        except Exception as e:
            return False, f"Failed to execute process action {action}: {e}"


class AlertExecutor(ResponseExecutor):
    """告警执行器"""
    
    def __init__(self, config: Dict[str, Any] = None):
        super().__init__("alert", config)
        self.email_server = self.config.get('email_server', 'smtp.company.com')
        self.webhook_url = self.config.get('webhook_url', '')
        self.ticket_system_api = self.config.get('ticket_system_api', '')
    
    def can_handle(self, entity: SecurityEntity, action: ResponseAction) -> bool:
        """检查是否能处理指定的实体和动作"""
        return action in [
            ResponseAction.SEND_ALERT, ResponseAction.CREATE_TICKET, 
            ResponseAction.NOTIFY_ADMIN, ResponseAction.COLLECT_EVIDENCE
        ]
    
    async def execute(self, entity: SecurityEntity, action: ResponseAction, 
                     params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """执行告警操作"""
        try:
            if action == ResponseAction.SEND_ALERT:
                return await self._send_alert(entity, params)
            elif action == ResponseAction.CREATE_TICKET:
                return await self._create_ticket(entity, params)
            elif action == ResponseAction.NOTIFY_ADMIN:
                return await self._notify_admin(entity, params)
            elif action == ResponseAction.COLLECT_EVIDENCE:
                return await self._collect_evidence(entity, params)
            else:
                return False, f"Unsupported action: {action}"
                
        except Exception as e:
            error_msg = f"Error executing alert action: {e}"
            self.logger.error(error_msg)
            return False, error_msg
    
    async def _send_alert(self, entity: SecurityEntity, params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """发送告警"""
        try:
            alert_data = {
                'entity_type': entity.entity_type.value,
                'entity_id': entity.entity_id,
                'risk_score': entity.risk_score,
                'threat_level': entity.threat_level.value,
                'timestamp': datetime.now().isoformat(),
                'message': params.get('message', 'Security threat detected') if params else 'Security threat detected'
            }
            
            # 模拟发送告警
            await asyncio.sleep(0.1)
            
            self.logger.info(f"Sent alert for entity {entity.entity_id}: {alert_data}")
            return True, f"Successfully sent alert for entity {entity.entity_id}"
            
        except Exception as e:
            return False, f"Failed to send alert: {e}"
    
    async def _create_ticket(self, entity: SecurityEntity, params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """创建工单"""
        try:
            ticket_data = {
                'title': f"Security Incident - {entity.entity_type.value.upper()} {entity.entity_id}",
                'description': f"Risk Score: {entity.risk_score}, Threat Level: {entity.threat_level.value}",
                'priority': 'High' if entity.risk_score >= 70 else 'Medium',
                'assignee': params.get('assignee', 'security-team') if params else 'security-team',
                'entity_data': entity.to_dict()
            }
            
            await asyncio.sleep(0.2)
            
            ticket_id = f"SEC-{int(datetime.now().timestamp())}"
            self.logger.info(f"Created ticket {ticket_id} for entity {entity.entity_id}")
            
            return True, f"Successfully created ticket {ticket_id}"
            
        except Exception as e:
            return False, f"Failed to create ticket: {e}"
    
    async def _notify_admin(self, entity: SecurityEntity, params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """通知管理员"""
        try:
            notification_data = {
                'subject': f"URGENT: Security Threat Detected - {entity.entity_id}",
                'body': f"Entity: {entity.entity_type.value} {entity.entity_id}\n"
                       f"Risk Score: {entity.risk_score}\n"
                       f"Threat Level: {entity.threat_level.value}\n"
                       f"Time: {datetime.now().isoformat()}",
                'recipients': params.get('recipients', ['admin@company.com']) if params else ['admin@company.com']
            }
            
            await asyncio.sleep(0.1)
            
            self.logger.info(f"Sent admin notification for entity {entity.entity_id}")
            return True, f"Successfully notified admin about entity {entity.entity_id}"
            
        except Exception as e:
            return False, f"Failed to notify admin: {e}"
    
    async def _collect_evidence(self, entity: SecurityEntity, params: Dict[str, Any] = None) -> Tuple[bool, str]:
        """收集证据"""
        try:
            evidence_data = {
                'entity_info': entity.to_dict(),
                'collection_time': datetime.now().isoformat(),
                'collection_type': params.get('collection_type', 'automatic') if params else 'automatic',
                'evidence_id': f"evidence_{entity.entity_type.value}_{int(datetime.now().timestamp())}"
            }
            
            await asyncio.sleep(0.3)
            
            evidence_id = evidence_data['evidence_id']
            self.logger.info(f"Collected evidence {evidence_id} for entity {entity.entity_id}")
            
            return True, f"Successfully collected evidence {evidence_id}"
            
        except Exception as e:
            return False, f"Failed to collect evidence: {e}"


class ResponseOrchestrator:
    """响应编排器"""
    
    def __init__(self, config: Dict[str, Any] = None):
        self.logger = logging.getLogger(__name__)
        self.config = config or {}
        
        # 初始化各种执行器
        self.executors: List[ResponseExecutor] = [
            FirewallExecutor(self.config.get('firewall', {})),
            ADExecutor(self.config.get('ad', {})),
            EDRExecutor(self.config.get('edr', {})),
            AlertExecutor(self.config.get('alert', {}))
        ]
        
        # 定义响应策略 - 根据风险分数确定响应动作
        self.response_policies = {
            30: [ResponseAction.SEND_ALERT],  # 低风险：仅发送告警
            50: [ResponseAction.SEND_ALERT, ResponseAction.COLLECT_EVIDENCE],  # 中风险：告警+证据收集
            70: [ResponseAction.SEND_ALERT, ResponseAction.CREATE_TICKET, ResponseAction.COLLECT_EVIDENCE],  # 高风险：告警+工单+证据
            85: [ResponseAction.BLOCK_IP, ResponseAction.SEND_ALERT, ResponseAction.CREATE_TICKET, ResponseAction.NOTIFY_ADMIN],  # 严重威胁：阻断+告警+工单+通知
            95: [ResponseAction.BLOCK_IP, ResponseAction.DISABLE_USER, ResponseAction.ISOLATE_HOST, 
                ResponseAction.SEND_ALERT, ResponseAction.CREATE_TICKET, ResponseAction.NOTIFY_ADMIN, ResponseAction.COLLECT_EVIDENCE]  # 极严重：全面响应
        }
        
        # 响应动作优先级
        self.action_priorities = {
            ResponseAction.BLOCK_IP: 1,
            ResponseAction.ISOLATE_HOST: 1,
            ResponseAction.DISABLE_USER: 2,
            ResponseAction.KILL_PROCESS: 2,
            ResponseAction.QUARANTINE_FILE: 3,
            ResponseAction.SEND_ALERT: 4,
            ResponseAction.CREATE_TICKET: 5,
            ResponseAction.NOTIFY_ADMIN: 5,
            ResponseAction.COLLECT_EVIDENCE: 6
        }
    
    async def execute_response(self, entity: SecurityEntity, 
                             custom_actions: List[ResponseAction] = None) -> List[Dict[str, Any]]:
        """执行响应动作"""
        results = []
        
        try:
            # 确定要执行的动作
            if custom_actions:
                actions = custom_actions
            else:
                actions = self._determine_actions(entity.risk_score)
            
            if not actions:
                self.logger.info(f"No actions determined for entity {entity.entity_id} with risk score {entity.risk_score}")
                return results
            
            # 按优先级排序动作
            sorted_actions = sorted(actions, key=lambda x: self.action_priorities.get(x, 10))
            
            self.logger.info(f"Executing {len(sorted_actions)} actions for entity {entity.entity_id}")
            
            # 并行执行所有动作
            tasks = []
            for action in sorted_actions:
                executor = self._find_executor(entity, action)
                if executor:
                    task = self._execute_single_action(entity, action, executor)
                    tasks.append(task)
                else:
                    self.logger.warning(f"No executor found for action {action} on entity {entity.entity_id}")
                    results.append({
                        'action': action.value,
                        'status': ResponseStatus.FAILED.value,
                        'message': 'No suitable executor found',
                        'timestamp': datetime.now().isoformat()
                    })
            
            # 等待所有任务完成
            if tasks:
                task_results = await asyncio.gather(*tasks, return_exceptions=True)
                
                for i, result in enumerate(task_results):
                    if isinstance(result, Exception):
                        self.logger.error(f"Task {i} failed with exception: {result}")
                        results.append({
                            'action': sorted_actions[i].value,
                            'status': ResponseStatus.FAILED.value,
                            'message': str(result),
                            'timestamp': datetime.now().isoformat()
                        })
                    else:
                        results.append(result)
            
            # 更新实体状态
            self._update_entity_status(entity, results)
            
            # 记录响应结果
            self.logger.info(f"Response execution completed for entity {entity.entity_id}. "
                           f"Successful: {sum(1 for r in results if r.get('status') == ResponseStatus.SUCCESS.value)}, "
                           f"Failed: {sum(1 for r in results if r.get('status') == ResponseStatus.FAILED.value)}")
            
        except Exception as e:
            error_msg = f"Error in response orchestration for entity {entity.entity_id}: {e}"
            self.logger.error(error_msg)
            results.append({
                'action': 'orchestration',
                'status': ResponseStatus.FAILED.value,
                'message': error_msg,
                'timestamp': datetime.now().isoformat()
            })
        
        return results
    
    async def _execute_single_action(self, entity: SecurityEntity, action: ResponseAction, 
                                   executor: ResponseExecutor) -> Dict[str, Any]:
        """执行单个响应动作"""
        start_time = datetime.now()
        
        try:
            self.logger.info(f"Executing action {action.value} for entity {entity.entity_id} using executor {executor.executor_id}")
            
            success, message = await executor.execute(entity, action)
            
            end_time = datetime.now()
            execution_time = (end_time - start_time).total_seconds()
            
            result = {
                'action': action.value,
                'status': ResponseStatus.SUCCESS.value if success else ResponseStatus.FAILED.value,
                'message': message,
                'executor': executor.executor_id,
                'execution_time': execution_time,
                'timestamp': end_time.isoformat()
            }
            
            if success:
                self.logger.info(f"Successfully executed {action.value} for entity {entity.entity_id}")
            else:
                self.logger.error(f"Failed to execute {action.value} for entity {entity.entity_id}: {message}")
            
            return result
            
        except Exception as e:
            end_time = datetime.now()
            execution_time = (end_time - start_time).total_seconds()
            
            error_msg = f"Exception during action execution: {e}"
            self.logger.error(error_msg)
            
            return {
                'action': action.value,
                'status': ResponseStatus.FAILED.value,
                'message': error_msg,
                'executor': executor.executor_id,
                'execution_time': execution_time,
                'timestamp': end_time.isoformat()
            }
    
    def _determine_actions(self, risk_score: float) -> List[ResponseAction]:
        """根据风险分数确定响应动作"""
        for threshold in sorted(self.response_policies.keys(), reverse=True):
            if risk_score >= threshold:
                return self.response_policies[threshold]
        return []
    
    def _find_executor(self, entity: SecurityEntity, action: ResponseAction) -> Optional[ResponseExecutor]:
        """查找能处理指定动作的执行器"""
        for executor in self.executors:
            if executor.can_handle(entity, action):
                return executor
        return None
    
    def _update_entity_status(self, entity: SecurityEntity, results: List[Dict[str, Any]]):
        """根据响应结果更新实体状态"""
        successful_actions = [r for r in results if r.get('status') == ResponseStatus.SUCCESS.value]
        
        if not successful_actions:
            return
        
        # 根据成功执行的动作更新实体状态
        action_values = [r.get('action') for r in successful_actions]
        
        if ResponseAction.BLOCK_IP.value in action_values:
            entity.update_status(EntityStatus.BLOCKED, "IP已被阻断")
        elif ResponseAction.DISABLE_USER.value in action_values:
            entity.update_status(EntityStatus.BLEEDING_STOP, "用户已被禁用，执行止血操作")
        elif ResponseAction.QUARANTINE_FILE.value in action_values:
            entity.update_status(EntityStatus.BLOCKED, "文件已被隔离")
        elif ResponseAction.ISOLATE_HOST.value in action_values:
            entity.update_status(EntityStatus.BLOCKED, "主机已被隔离")
        else:
            entity.update_status(EntityStatus.INVESTIGATED, "已执行响应动作")
        
        # 记录响应动作到实体时间线
        entity.timeline.append({
            'action': 'response_executed',
            'response_actions': action_values,
            'successful_count': len(successful_actions),
            'total_count': len(results),
            'timestamp': int(datetime.now().timestamp())
        })
    
    def add_executor(self, executor: ResponseExecutor):
        """添加新的执行器"""
        self.executors.append(executor)
        self.logger.info(f"Added executor: {executor.executor_id}")
    
    def remove_executor(self, executor_id: str):
        """移除执行器"""
        self.executors = [e for e in self.executors if e.executor_id != executor_id]
        self.logger.info(f"Removed executor: {executor_id}")
    
    def get_executor_status(self) -> Dict[str, Any]:
        """获取所有执行器状态"""
        return {
            'total_executors': len(self.executors),
            'executors': [
                {
                    'id': executor.executor_id,
                    'type': executor.__class__.__name__,
                    'config': executor.config
                }
                for executor in self.executors
            ]
        }