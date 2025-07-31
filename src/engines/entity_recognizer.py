"""
Entity Recognition Engine
实体识别引擎 - 从安全日志中识别和提取实体
"""

import re
import json
import logging
from typing import List, Dict, Any, Optional, Set
from datetime import datetime
import ipaddress
import hashlib

from ..models.entities import SecurityEntity, EntityType, SecurityEvent

class EntityRecognizer:
    """实体识别引擎"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        
        # 正则表达式模式
        self.patterns = {
            'ip': r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b',
            'domain': r'\b[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}\b',
            'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
            'url': r'https?://[^\s<>"{}|\\^`\[\]]+',
            'file_path_windows': r'[a-zA-Z]:\\[^:*?"<>|\r\n]*',
            'file_path_linux': r'\/[^\s:*?"<>|\r\n]*',
            'hash_md5': r'\b[a-fA-F0-9]{32}\b',
            'hash_sha1': r'\b[a-fA-F0-9]{40}\b',
            'hash_sha256': r'\b[a-fA-F0-9]{64}\b',
            'process_name': r'\b[a-zA-Z0-9_\-]+\.exe\b',
            'username': r'\b[a-zA-Z][a-zA-Z0-9_\-\.]{2,20}\b'
        }
        
        # 编译正则表达式
        self.compiled_patterns = {}
        for name, pattern in self.patterns.items():
            try:
                self.compiled_patterns[name] = re.compile(pattern, re.IGNORECASE)
            except re.error as e:
                self.logger.error(f"Failed to compile pattern {name}: {e}")
        
        # 私有IP地址范围
        self.private_ip_ranges = [
            ipaddress.ip_network('10.0.0.0/8'),
            ipaddress.ip_network('172.16.0.0/12'),
            ipaddress.ip_network('192.168.0.0/16'),
        ]
        
        # 系统文件路径白名单
        self.system_paths = {
            'windows': [
                r'C:\Windows\System32',
                r'C:\Windows\SysWOW64',
                r'C:\Program Files',
                r'C:\Program Files (x86)'
            ],
            'linux': [
                '/usr/bin',
                '/bin',
                '/sbin',
                '/usr/sbin',
                '/lib',
                '/usr/lib'
            ]
        }
    
    def extract_entities(self, log_data: Dict[str, Any], 
                        event_id: str = None) -> List[SecurityEntity]:
        """从日志数据中提取实体"""
        entities = []
        extracted_values = set()  # 防重复
        
        try:
            # 转换日志数据为字符串用于模式匹配
            log_text = json.dumps(log_data) if isinstance(log_data, dict) else str(log_data)
            
            # 提取各种类型的实体
            entities.extend(self._extract_ip_entities(log_data, log_text, extracted_values))
            entities.extend(self._extract_user_entities(log_data, extracted_values))
            entities.extend(self._extract_file_entities(log_data, extracted_values))
            entities.extend(self._extract_process_entities(log_data, extracted_values))
            entities.extend(self._extract_domain_entities(log_data, log_text, extracted_values))
            entities.extend(self._extract_email_entities(log_data, log_text, extracted_values))
            entities.extend(self._extract_url_entities(log_data, log_text, extracted_values))
            entities.extend(self._extract_hash_entities(log_data, log_text, extracted_values))
            
            # 为所有实体添加事件关联信息
            for entity in entities:
                if event_id:
                    entity.add_metadata('source_event_id', event_id)
                entity.add_metadata('extraction_timestamp', datetime.now().isoformat())
                
        except Exception as e:
            self.logger.error(f"Error extracting entities from log: {e}")
        
        return entities
    
    def _extract_ip_entities(self, log_data: Dict, log_text: str, 
                           extracted_values: Set) -> List[SecurityEntity]:
        """提取IP实体"""
        entities = []
        
        # 从结构化字段提取
        ip_fields = ['src_ip', 'dst_ip', 'source_ip', 'dest_ip', 'remote_ip', 
                    'client_ip', 'server_ip', 'host_ip']
        
        for field in ip_fields:
            if field in log_data and self._is_valid_ip(log_data[field]):
                ip = log_data[field]
                if ip not in extracted_values:
                    entity = SecurityEntity(
                        entity_type=EntityType.IP,
                        entity_id=ip,
                        metadata={
                            'field_source': field,
                            'is_private': self._is_private_ip(ip),
                            'direction': 'source' if 'src' in field or 'source' in field else 'destination'
                        }
                    )
                    entities.append(entity)
                    extracted_values.add(ip)
        
        # 从文本中提取IP地址
        if 'ip' in self.compiled_patterns:
            for match in self.compiled_patterns['ip'].finditer(log_text):
                ip = match.group()
                if self._is_valid_ip(ip) and ip not in extracted_values:
                    entity = SecurityEntity(
                        entity_type=EntityType.IP,
                        entity_id=ip,
                        metadata={
                            'field_source': 'text_extraction',
                            'is_private': self._is_private_ip(ip)
                        }
                    )
                    entities.append(entity)
                    extracted_values.add(ip)
        
        return entities
    
    def _extract_user_entities(self, log_data: Dict, extracted_values: Set) -> List[SecurityEntity]:
        """提取用户实体"""
        entities = []
        
        user_fields = ['username', 'user', 'account', 'login_name', 'user_name',
                      'src_user', 'dst_user', 'target_user']
        
        for field in user_fields:
            if field in log_data and isinstance(log_data[field], str):
                username = log_data[field].strip()
                if username and username not in extracted_values and self._is_valid_username(username):
                    entity = SecurityEntity(
                        entity_type=EntityType.USER,
                        entity_id=username,
                        metadata={
                            'field_source': field,
                            'is_system_account': self._is_system_account(username)
                        }
                    )
                    entities.append(entity)
                    extracted_values.add(username)
        
        return entities
    
    def _extract_file_entities(self, log_data: Dict, extracted_values: Set) -> List[SecurityEntity]:
        """提取文件实体"""
        entities = []
        
        file_fields = ['file_path', 'filename', 'file_name', 'path', 'target_filename',
                      'process_path', 'image_path', 'command_line']
        
        for field in file_fields:
            if field in log_data and isinstance(log_data[field], str):
                file_path = log_data[field].strip()
                if file_path and file_path not in extracted_values:
                    # 验证是否为有效文件路径
                    if self._is_valid_file_path(file_path):
                        entity = SecurityEntity(
                            entity_type=EntityType.FILE,
                            entity_id=file_path,
                            metadata={
                                'field_source': field,
                                'is_system_file': self._is_system_file(file_path),
                                'file_extension': self._get_file_extension(file_path)
                            }
                        )
                        entities.append(entity)
                        extracted_values.add(file_path)
        
        return entities
    
    def _extract_process_entities(self, log_data: Dict, extracted_values: Set) -> List[SecurityEntity]:
        """提取进程实体"""
        entities = []
        
        process_fields = ['process_name', 'image_name', 'command', 'process_command_line']
        
        for field in process_fields:
            if field in log_data and isinstance(log_data[field], str):
                process_info = log_data[field].strip()
                if process_info and process_info not in extracted_values:
                    # 提取进程名称
                    process_name = self._extract_process_name(process_info)
                    if process_name:
                        entity = SecurityEntity(
                            entity_type=EntityType.PROCESS,
                            entity_id=process_name,
                            metadata={
                                'field_source': field,
                                'full_command': process_info if field == 'process_command_line' else None,
                                'is_system_process': self._is_system_process(process_name)
                            }
                        )
                        entities.append(entity)
                        extracted_values.add(process_info)
        
        return entities
    
    def _extract_domain_entities(self, log_data: Dict, log_text: str, 
                                extracted_values: Set) -> List[SecurityEntity]:
        """提取域名实体"""
        entities = []
        
        # 从结构化字段提取
        domain_fields = ['domain', 'hostname', 'dest_domain', 'target_domain', 'dns_query']
        
        for field in domain_fields:
            if field in log_data and isinstance(log_data[field], str):
                domain = log_data[field].strip().lower()
                if domain and domain not in extracted_values and self._is_valid_domain(domain):
                    entity = SecurityEntity(
                        entity_type=EntityType.DOMAIN,
                        entity_id=domain,
                        metadata={
                            'field_source': field,
                            'tld': self._get_tld(domain)
                        }
                    )
                    entities.append(entity)
                    extracted_values.add(domain)
        
        # 从文本中提取域名
        if 'domain' in self.compiled_patterns:
            for match in self.compiled_patterns['domain'].finditer(log_text):
                domain = match.group().lower()
                if domain not in extracted_values and self._is_valid_domain(domain):
                    entity = SecurityEntity(
                        entity_type=EntityType.DOMAIN,
                        entity_id=domain,
                        metadata={
                            'field_source': 'text_extraction',
                            'tld': self._get_tld(domain)
                        }
                    )
                    entities.append(entity)
                    extracted_values.add(domain)
        
        return entities
    
    def _extract_email_entities(self, log_data: Dict, log_text: str, 
                               extracted_values: Set) -> List[SecurityEntity]:
        """提取邮箱实体"""
        entities = []
        
        # 从结构化字段提取
        email_fields = ['email', 'sender', 'recipient', 'from_email', 'to_email']
        
        for field in email_fields:
            if field in log_data and isinstance(log_data[field], str):
                email = log_data[field].strip().lower()
                if email and email not in extracted_values and self._is_valid_email(email):
                    entity = SecurityEntity(
                        entity_type=EntityType.EMAIL,
                        entity_id=email,
                        metadata={
                            'field_source': field,
                            'domain': email.split('@')[1] if '@' in email else None
                        }
                    )
                    entities.append(entity)
                    extracted_values.add(email)
        
        # 从文本中提取邮箱
        if 'email' in self.compiled_patterns:
            for match in self.compiled_patterns['email'].finditer(log_text):
                email = match.group().lower()
                if email not in extracted_values:
                    entity = SecurityEntity(
                        entity_type=EntityType.EMAIL,
                        entity_id=email,
                        metadata={
                            'field_source': 'text_extraction',
                            'domain': email.split('@')[1] if '@' in email else None
                        }
                    )
                    entities.append(entity)
                    extracted_values.add(email)
        
        return entities
    
    def _extract_url_entities(self, log_data: Dict, log_text: str, 
                             extracted_values: Set) -> List[SecurityEntity]:
        """提取URL实体"""
        entities = []
        
        # 从结构化字段提取
        url_fields = ['url', 'uri', 'request_url', 'referer', 'redirect_url']
        
        for field in url_fields:
            if field in log_data and isinstance(log_data[field], str):
                url = log_data[field].strip()
                if url and url not in extracted_values and self._is_valid_url(url):
                    entity = SecurityEntity(
                        entity_type=EntityType.URL,
                        entity_id=url,
                        metadata={
                            'field_source': field,
                            'domain': self._extract_domain_from_url(url),
                            'scheme': url.split('://')[0] if '://' in url else None
                        }
                    )
                    entities.append(entity)
                    extracted_values.add(url)
        
        # 从文本中提取URL
        if 'url' in self.compiled_patterns:
            for match in self.compiled_patterns['url'].finditer(log_text):
                url = match.group()
                if url not in extracted_values:
                    entity = SecurityEntity(
                        entity_type=EntityType.URL,
                        entity_id=url,
                        metadata={
                            'field_source': 'text_extraction',
                            'domain': self._extract_domain_from_url(url),
                            'scheme': url.split('://')[0] if '://' in url else None
                        }
                    )
                    entities.append(entity)
                    extracted_values.add(url)
        
        return entities
    
    def _extract_hash_entities(self, log_data: Dict, log_text: str, 
                              extracted_values: Set) -> List[SecurityEntity]:
        """提取哈希值实体"""
        entities = []
        
        # 从结构化字段提取
        hash_fields = ['md5', 'sha1', 'sha256', 'file_hash', 'hash']
        
        for field in hash_fields:
            if field in log_data and isinstance(log_data[field], str):
                hash_value = log_data[field].strip().lower()
                if hash_value and hash_value not in extracted_values and self._is_valid_hash(hash_value):
                    hash_type = self._determine_hash_type(hash_value)
                    entity = SecurityEntity(
                        entity_type=EntityType.FILE,  # 哈希通常关联文件
                        entity_id=hash_value,
                        metadata={
                            'field_source': field,
                            'hash_type': hash_type,
                            'is_hash': True
                        }
                    )
                    entities.append(entity)
                    extracted_values.add(hash_value)
        
        # 从文本中提取哈希
        for hash_type in ['md5', 'sha1', 'sha256']:
            if hash_type in self.compiled_patterns:
                for match in self.compiled_patterns[f'hash_{hash_type}'].finditer(log_text):
                    hash_value = match.group().lower()
                    if hash_value not in extracted_values:
                        entity = SecurityEntity(
                            entity_type=EntityType.FILE,
                            entity_id=hash_value,
                            metadata={
                                'field_source': 'text_extraction',
                                'hash_type': hash_type.upper(),
                                'is_hash': True
                            }
                        )
                        entities.append(entity)
                        extracted_values.add(hash_value)
        
        return entities
    
    # 辅助验证方法
    def _is_valid_ip(self, ip: str) -> bool:
        """验证IP地址有效性"""
        try:
            ipaddress.ip_address(ip)
            return True
        except ValueError:
            return False
    
    def _is_private_ip(self, ip: str) -> bool:
        """检查是否为私有IP"""
        try:
            ip_obj = ipaddress.ip_address(ip)
            return any(ip_obj in network for network in self.private_ip_ranges)
        except ValueError:
            return False
    
    def _is_valid_username(self, username: str) -> bool:
        """验证用户名有效性"""
        if len(username) < 2 or len(username) > 50:
            return False
        # 排除一些明显不是用户名的字符串
        invalid_patterns = ['null', 'undefined', 'anonymous', 'guest']
        return username.lower() not in invalid_patterns
    
    def _is_system_account(self, username: str) -> bool:
        """检查是否为系统账户"""
        system_accounts = ['system', 'administrator', 'root', 'admin', 'service']
        return username.lower() in system_accounts
    
    def _is_valid_file_path(self, path: str) -> bool:
        """验证文件路径有效性"""
        if len(path) < 3:
            return False
        # Windows路径或Linux路径
        return (path.startswith('/') or 
                (len(path) >= 3 and path[1:3] == ':\\'))
    
    def _is_system_file(self, file_path: str) -> bool:
        """检查是否为系统文件"""
        for os_type, paths in self.system_paths.items():
            for sys_path in paths:
                if file_path.startswith(sys_path):
                    return True
        return False
    
    def _get_file_extension(self, file_path: str) -> Optional[str]:
        """获取文件扩展名"""
        if '.' in file_path:
            return file_path.split('.')[-1].lower()
        return None
    
    def _extract_process_name(self, process_info: str) -> Optional[str]:
        """从进程信息中提取进程名"""
        # 简单实现，可以根据需要增强
        if '\\' in process_info:
            return process_info.split('\\')[-1]
        elif '/' in process_info:
            return process_info.split('/')[-1]
        return process_info
    
    def _is_system_process(self, process_name: str) -> bool:
        """检查是否为系统进程"""
        system_processes = ['svchost.exe', 'explorer.exe', 'winlogon.exe', 
                           'csrss.exe', 'lsass.exe', 'systemd', 'kernel']
        return process_name.lower() in system_processes
    
    def _is_valid_domain(self, domain: str) -> bool:
        """验证域名有效性"""
        if len(domain) < 4 or len(domain) > 255:
            return False
        if '..' in domain or domain.startswith('.') or domain.endswith('.'):
            return False
        return True
    
    def _get_tld(self, domain: str) -> Optional[str]:
        """获取顶级域名"""
        parts = domain.split('.')
        return parts[-1] if len(parts) > 1 else None
    
    def _is_valid_email(self, email: str) -> bool:
        """验证邮箱有效性"""
        return '@' in email and '.' in email.split('@')[1]
    
    def _is_valid_url(self, url: str) -> bool:
        """验证URL有效性"""
        return url.startswith(('http://', 'https://')) and len(url) > 10
    
    def _extract_domain_from_url(self, url: str) -> Optional[str]:
        """从URL中提取域名"""
        try:
            from urllib.parse import urlparse
            parsed = urlparse(url)
            return parsed.netloc
        except:
            return None
    
    def _is_valid_hash(self, hash_value: str) -> bool:
        """验证哈希值有效性"""
        return len(hash_value) in [32, 40, 64] and all(c in '0123456789abcdef' for c in hash_value.lower())
    
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