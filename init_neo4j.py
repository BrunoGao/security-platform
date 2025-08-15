#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Neo4j 初始化脚本 - 创建演示数据和用户友好配置
"""

import requests
import time
import json

def init_neo4j_demo_data():
    """初始化Neo4j演示数据"""
    
    # 等待Neo4j完全启动
    print("等待Neo4j服务启动...")
    time.sleep(10)
    
    neo4j_urls = [
        'http://localhost:7474/db/neo4j/tx/commit',
        'http://127.0.0.1:7474/db/neo4j/tx/commit'
    ]
    
    # 创建演示攻击路径数据
    demo_cypher = {
        "statements": [{
            "statement": """
            // 清理所有现有数据
            MATCH (n) DETACH DELETE n
            
            WITH 1 as dummy
            
            // 创建演示攻击路径
            CREATE (attacker:Attacker {
                id: '192.168.1.100', 
                name: '外部攻击者',
                ip: '192.168.1.100',
                threat_level: '高危',
                first_seen: '2025-08-09T13:30:00Z',
                country: '未知',
                attack_type: '暴力破解'
            })
            
            CREATE (gateway:System {
                id: 'web_gateway', 
                name: 'Web网关',
                ip: '10.0.0.1',
                system_type: 'gateway',
                criticality: '高',
                compromised: true,
                compromise_time: '2025-08-09T13:30:15Z'
            })
            
            CREATE (webserver:System {
                id: 'web_server_01', 
                name: 'Web服务器',
                ip: '192.168.1.50',
                system_type: 'web_server',
                criticality: '中',
                compromised: true,
                compromise_time: '2025-08-09T13:31:30Z'
            })
            
            CREATE (appserver:System {
                id: 'app_server_01', 
                name: '应用服务器',
                ip: '192.168.1.75',
                system_type: 'application',
                criticality: '高',
                compromised: true,
                compromise_time: '2025-08-09T13:32:45Z'
            })
            
            CREATE (database:System {
                id: 'db_server_01', 
                name: '核心数据库',
                ip: '192.168.1.200',
                system_type: 'database',
                criticality: '极高',
                compromised: false,
                contains_sensitive_data: true
            })
            
            CREATE (fileserver:System {
                id: 'file_server_01', 
                name: '文件服务器',
                ip: '192.168.1.120',
                system_type: 'file_server',
                criticality: '中',
                compromised: false
            })
            
            // 创建攻击路径关系
            CREATE (attacker)-[:INITIAL_ACCESS {
                method: '暴力破解登录',
                timestamp: '2025-08-09T13:30:15Z',
                success_rate: '成功',
                tools_used: ['hydra', 'burp_suite'],
                detection_status: '已检测'
            }]->(gateway)
            
            CREATE (gateway)-[:LATERAL_MOVEMENT {
                method: 'SSH密钥复用',
                timestamp: '2025-08-09T13:31:30Z',
                privilege_level: 'user',
                detection_status: '已检测'
            }]->(webserver)
            
            CREATE (webserver)-[:PRIVILEGE_ESCALATION {
                method: '内核漏洞利用',
                timestamp: '2025-08-09T13:32:45Z',
                cve_id: 'CVE-2024-1086',
                privilege_level: 'root',
                detection_status: '已检测'
            }]->(appserver)
            
            CREATE (appserver)-[:ATTEMPTS_ACCESS {
                method: '数据库连接尝试',
                timestamp: '2025-08-09T13:33:15Z',
                status: '被阻止',
                detection_status: '已拦截'
            }]->(database)
            
            CREATE (appserver)-[:DISCOVERS {
                method: '网络扫描',
                timestamp: '2025-08-09T13:33:00Z',
                scan_type: 'port_scan',
                detection_status: '已检测'
            }]->(fileserver)
            
            // 创建用户账户
            CREATE (admin_user:User {
                id: 'admin',
                username: 'admin',
                account_type: 'administrator',
                last_login: '2025-08-09T13:29:45Z',
                compromised: true,
                compromise_method: '密码破解'
            })
            
            CREATE (service_user:User {
                id: 'webapp_service',
                username: 'webapp_service',
                account_type: 'service',
                privileges: ['web_access', 'db_read'],
                compromised: true,
                compromise_method: '权限提升'
            })
            
            // 用户与系统的关系
            CREATE (admin_user)-[:HAS_ACCESS {access_level: 'full'}]->(gateway)
            CREATE (admin_user)-[:HAS_ACCESS {access_level: 'full'}]->(webserver)
            CREATE (service_user)-[:HAS_ACCESS {access_level: 'limited'}]->(webserver)
            CREATE (service_user)-[:HAS_ACCESS {access_level: 'read_only'}]->(appserver)
            
            RETURN count(*) as nodes_created
            """
        }]
    }
    
    for neo4j_url in neo4j_urls:
        try:
            print(f"尝试连接 Neo4j: {neo4j_url}")
            response = requests.post(
                neo4j_url,
                json=demo_cypher,
                headers={'Content-Type': 'application/json'},
                auth=('neo4j', 'security123'),
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                if not result.get('errors'):
                    print("✅ Neo4j演示数据创建成功!")
                    print("📊 建议查询命令:")
                    print("   MATCH (n) RETURN n LIMIT 25")
                    print("   MATCH (a:Attacker)-[r*]->(s:System) RETURN a, r, s")
                    print("   MATCH path = (attacker:Attacker)-[*]->(database:System {system_type: 'database'}) RETURN path")
                    return True
                else:
                    print(f"❌ Neo4j查询错误: {result['errors']}")
            else:
                print(f"❌ HTTP错误: {response.status_code}")
                
        except requests.RequestException as e:
            print(f"❌ 连接失败: {neo4j_url} - {str(e)}")
            continue
    
    print("❌ 所有Neo4j连接尝试都失败了")
    return False

if __name__ == "__main__":
    print("🚀 初始化Neo4j演示数据...")
    success = init_neo4j_demo_data()
    
    if success:
        print("\n🎉 Neo4j现在已经包含丰富的演示数据!")
        print("🌐 访问 http://localhost:7474")
        print("🔑 用户名: neo4j")
        print("🔑 密码: security123")
        print("\n📈 推荐查询:")
        print("1. 查看所有节点: MATCH (n) RETURN n LIMIT 25")
        print("2. 查看攻击路径: MATCH path = (a:Attacker)-[*]->(s:System) RETURN path")
        print("3. 查看已入侵系统: MATCH (s:System {compromised: true}) RETURN s")
    else:
        print("\n❌ 初始化失败，请检查Neo4j服务状态")