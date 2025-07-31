#!/bin/bash

# Neo4j数据库配置脚本
# Neo4j Database Configuration Script

set -e

echo "🕸️  配置Neo4j数据库结构..."

# 等待Neo4j启动
echo "⏳ 等待Neo4j服务启动..."
until curl -s http://localhost:7474 > /dev/null; do
    echo "   等待Neo4j..."
    sleep 2
done

echo "✅ Neo4j服务已就绪"

# Neo4j连接参数
NEO4J_URL="bolt://localhost:7687"
NEO4J_USER="neo4j"
NEO4J_PASSWORD="security123"

# 使用cypher-shell执行Cypher查询
run_cypher() {
    local query="$1"
    echo "执行: $query"
    echo "$query" | cypher-shell -a "$NEO4J_URL" -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" || {
        echo "⚠️  Cypher查询失败，尝试使用HTTP API..."
        
        # 使用HTTP API作为备选方案
        curl -X POST http://localhost:7474/db/data/transaction/commit \
          -H "Content-Type: application/json" \
          -H "Authorization: Basic $(echo -n neo4j:security123 | base64)" \
          -d "{\"statements\":[{\"statement\":\"$query\"}]}" 2>/dev/null || true
    }
}

echo ""
echo "🏗️  创建节点标签和约束..."

# 1. 创建唯一约束
run_cypher "CREATE CONSTRAINT entity_id_unique IF NOT EXISTS FOR (e:Entity) REQUIRE e.entity_id IS UNIQUE;"
run_cypher "CREATE CONSTRAINT ip_address_unique IF NOT EXISTS FOR (ip:IP) REQUIRE ip.address IS UNIQUE;"
run_cypher "CREATE CONSTRAINT user_username_unique IF NOT EXISTS FOR (u:User) REQUIRE u.username IS UNIQUE;"
run_cypher "CREATE CONSTRAINT file_path_unique IF NOT EXISTS FOR (f:File) REQUIRE f.path IS UNIQUE;"
run_cypher "CREATE CONSTRAINT process_name_unique IF NOT EXISTS FOR (p:Process) REQUIRE p.name IS UNIQUE;"
run_cypher "CREATE CONSTRAINT domain_name_unique IF NOT EXISTS FOR (d:Domain) REQUIRE d.name IS UNIQUE;"

echo ""
echo "📋 创建索引..."

# 2. 创建索引
run_cypher "CREATE INDEX entity_type_index IF NOT EXISTS FOR (e:Entity) ON (e.entity_type);"
run_cypher "CREATE INDEX risk_score_index IF NOT EXISTS FOR (e:Entity) ON (e.risk_score);"
run_cypher "CREATE INDEX timestamp_index IF NOT EXISTS FOR (e:Entity) ON (e.first_seen);"
run_cypher "CREATE INDEX threat_level_index IF NOT EXISTS FOR (e:Entity) ON (e.threat_level);"

echo ""
echo "🎭 创建节点标签结构..."

# 3. 创建基础节点类型示例（这些将在实际使用中动态创建）
run_cypher "
MERGE (schema:Schema {name: 'SecurityEntities'})
SET schema.created_at = datetime(),
    schema.version = '1.0',
    schema.description = 'Security entities relationship schema'
"

echo ""
echo "🔗 创建关系类型..."

# 4. 预定义关系类型和属性
run_cypher "
MERGE (relationships:RelationshipTypes {name: 'SecurityRelationships'})
SET relationships.types = [
  'CONNECTS_TO',
  'BELONGS_TO', 
  'ACCESSES',
  'EXECUTES',
  'COMMUNICATES_WITH',
  'CONTAINS',
  'SPAWNS',
  'MODIFIES',
  'READS',
  'WRITES',
  'TRIGGERS',
  'ASSOCIATED_WITH'
],
relationships.created_at = datetime()
"

echo ""
echo "🎯 创建示例安全实体和关系..."

# 5. 创建示例数据结构
run_cypher "
// 创建示例IP实体
MERGE (ip1:Entity:IP {entity_id: '192.168.1.100'})
SET ip1.address = '192.168.1.100',
    ip1.entity_type = 'ip',
    ip1.is_private = true,
    ip1.risk_score = 0.0,
    ip1.threat_level = 'LOW',
    ip1.first_seen = datetime(),
    ip1.last_seen = datetime(),
    ip1.status = 'active'

// 创建示例用户实体
MERGE (user1:Entity:User {entity_id: 'admin'})
SET user1.username = 'admin',
    user1.entity_type = 'user',
    user1.is_system_account = true,
    user1.risk_score = 0.0,
    user1.threat_level = 'LOW',
    user1.first_seen = datetime(),
    user1.last_seen = datetime(),
    user1.status = 'active'

// 创建示例文件实体  
MERGE (file1:Entity:File {entity_id: 'C:\\Windows\\System32\\cmd.exe'})
SET file1.path = 'C:\\\\Windows\\\\System32\\\\cmd.exe',
    file1.entity_type = 'file',
    file1.is_system_file = true,
    file1.risk_score = 0.0,
    file1.threat_level = 'LOW',
    file1.first_seen = datetime(),
    file1.last_seen = datetime(),
    file1.status = 'active'

// 创建示例进程实体
MERGE (proc1:Entity:Process {entity_id: 'cmd.exe'})
SET proc1.name = 'cmd.exe',
    proc1.entity_type = 'process',
    proc1.is_system_process = true,
    proc1.risk_score = 0.0,
    proc1.threat_level = 'LOW',
    proc1.first_seen = datetime(),
    proc1.last_seen = datetime(),
    proc1.status = 'active'
"

# 6. 创建关系示例
run_cypher "
// 创建实体间关系
MATCH (user:User {username: 'admin'}), (ip:IP {address: '192.168.1.100'})
MERGE (user)-[r:CONNECTS_FROM]->(ip)
SET r.first_seen = datetime(),
    r.last_seen = datetime(),
    r.frequency = 1,
    r.confidence = 0.9

MATCH (user:User {username: 'admin'}), (proc:Process {name: 'cmd.exe'})
MERGE (user)-[r:EXECUTES]->(proc)
SET r.first_seen = datetime(),
    r.last_seen = datetime(),
    r.frequency = 1,
    r.confidence = 0.95

MATCH (proc:Process {name: 'cmd.exe'}), (file:File {path: 'C:\\\\Windows\\\\System32\\\\cmd.exe'})
MERGE (proc)-[r:LOADS_FROM]->(file)
SET r.first_seen = datetime(),
    r.last_seen = datetime(),
    r.confidence = 1.0
"

echo ""
echo "📊 创建统计和监控节点..."

# 7. 创建统计节点
run_cypher "
MERGE (stats:Statistics {name: 'SecurityGraphStats'})
SET stats.total_entities = 0,
    stats.total_relationships = 0,
    stats.last_updated = datetime(),
    stats.high_risk_entities = 0,
    stats.active_threats = 0
"

echo ""
echo "🔍 验证数据库结构..."

# 8. 验证创建的结构
echo "📋 节点统计:"
run_cypher "
MATCH (n) 
RETURN labels(n) as labels, count(n) as count 
ORDER BY count DESC
"

echo ""
echo "🔗 关系统计:"
run_cypher "
MATCH ()-[r]->() 
RETURN type(r) as relationship_type, count(r) as count 
ORDER BY count DESC
"

echo ""
echo "📚 约束列表:"
run_cypher "SHOW CONSTRAINTS"

echo ""
echo "📇 索引列表:"
run_cypher "SHOW INDEXES"

echo ""
echo "✅ Neo4j数据库配置完成！"
echo ""
echo "🎯 可以通过以下方式访问Neo4j:"
echo "   - Browser: http://localhost:7474"
echo "   - Bolt: bolt://localhost:7687"
echo "   - 用户名: neo4j"
echo "   - 密码: security123"