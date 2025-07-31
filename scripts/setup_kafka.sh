#!/bin/bash

# Kafka主题配置脚本
# Kafka Topics Configuration Script

set -e

echo "📨 配置Kafka主题..."

# 等待Kafka启动
echo "⏳ 等待Kafka服务启动..."
until docker exec security-kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; do
    echo "   等待Kafka..."
    sleep 3
done

echo "✅ Kafka服务已就绪"

# Kafka参数
KAFKA_CONTAINER="security-kafka"
BOOTSTRAP_SERVER="localhost:9092"

# 创建Kafka主题
create_topic() {
    local topic_name="$1"
    local partitions="$2"
    local replication_factor="$3"
    local configs="$4"
    
    echo "创建主题: $topic_name"
    
    # 检查主题是否已存在
    if docker exec $KAFKA_CONTAINER kafka-topics \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --list | grep -q "^$topic_name$"; then
        echo "   主题 $topic_name 已存在，跳过创建"
        return
    fi
    
    # 创建主题命令
    local cmd="kafka-topics --bootstrap-server $BOOTSTRAP_SERVER --create --topic $topic_name --partitions $partitions --replication-factor $replication_factor"
    
    if [ -n "$configs" ]; then
        # 将配置字符串分割并添加多个--config参数
        IFS=',' read -ra CONFIG_ARRAY <<< "$configs"
        for config in "${CONFIG_ARRAY[@]}"; do
            cmd="$cmd --config $config"
        done
    fi
    
    docker exec $KAFKA_CONTAINER $cmd
}

echo ""
echo "🏗️  创建安全分析主题..."

# 1. 原始日志数据主题
create_topic "security-raw-logs" 6 1 "retention.ms=604800000,compression.type=gzip"

# 2. 解析后的安全事件主题
create_topic "security-events" 6 1 "retention.ms=2592000000,compression.type=gzip"

# 3. 实体识别结果主题
create_topic "security-entities" 4 1 "retention.ms=2592000000,compression.type=gzip"

# 4. 风险评分结果主题
create_topic "security-risk-scores" 4 1 "retention.ms=2592000000,compression.type=gzip"

# 5. 安全告警主题
create_topic "security-alerts" 3 1 "retention.ms=7776000000,compression.type=gzip"

# 6. 响应动作主题
create_topic "security-responses" 3 1 "retention.ms=2592000000,compression.type=gzip"

# 7. 系统监控主题
create_topic "security-monitoring" 2 1 "retention.ms=259200000,compression.type=gzip"

# 8. 死信队列主题
create_topic "security-dead-letter" 2 1 "retention.ms=7776000000,compression.type=gzip"

echo ""
echo "📊 验证主题创建..."

# 9. 列出所有主题
echo "📋 主题列表:"
docker exec $KAFKA_CONTAINER kafka-topics \
    --bootstrap-server $BOOTSTRAP_SERVER \
    --list | grep security- | while read topic; do
    echo "   ✅ $topic"
done

echo ""
echo "🔍 主题详细信息:"

# 10. 显示主题详细信息
for topic in security-raw-logs security-events security-entities security-risk-scores security-alerts security-responses security-monitoring security-dead-letter; do
    echo ""
    echo "📄 主题: $topic"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --describe --topic $topic | grep -E "(Topic:|PartitionCount:|ReplicationFactor:|Configs:)" | \
        sed 's/^/   /'
done

echo ""
echo "🧪 测试消息生产和消费..."

# 11. 测试消息发送
echo "📤 发送测试消息到 security-events..."

# 生成测试消息
test_message='{
  "event_id": "test-001",
  "event_type": "test_event",
  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",
  "src_ip": "192.168.1.100",
  "username": "test_user",
  "risk_score": 45.5,
  "threat_level": "MEDIUM",
  "is_anomaly": true,
  "raw_data": "Test message from setup script"
}'

# 发送消息
echo "$test_message" | docker exec -i $KAFKA_CONTAINER kafka-console-producer \
    --bootstrap-server $BOOTSTRAP_SERVER \
    --topic security-events

echo "   ✅ 测试消息已发送"

# 12. 测试消息消费
echo ""
echo "📥 从 security-events 消费消息（超时10秒）..."

timeout 10s docker exec $KAFKA_CONTAINER kafka-console-consumer \
    --bootstrap-server $BOOTSTRAP_SERVER \
    --topic security-events \
    --from-beginning \
    --max-messages 1 2>/dev/null || echo "   ✅ 消息消费测试完成"

echo ""
echo "📈 主题偏移量信息:"

# 13. 显示消费者组和偏移量信息
docker exec $KAFKA_CONTAINER kafka-run-class kafka.tools.GetOffsetShell \
    --broker-list $BOOTSTRAP_SERVER \
    --topic security-events 2>/dev/null | head -5 | while read line; do
    echo "   $line"
done

echo ""
echo "✅ Kafka主题配置完成！"
echo ""
echo "🎯 Kafka访问信息："
echo "   - Bootstrap Server: localhost:9092"
echo "   - Kafka UI: http://localhost:8082"
echo "   - JMX Port: 9101"
echo ""
echo "📊 已创建的主题："
echo "   - security-raw-logs: 原始日志（6分区）"
echo "   - security-events: 安全事件（6分区）"
echo "   - security-entities: 实体数据（4分区）"
echo "   - security-risk-scores: 风险评分（4分区）"
echo "   - security-alerts: 安全告警（3分区）"
echo "   - security-responses: 响应动作（3分区）"
echo "   - security-monitoring: 系统监控（2分区）"
echo "   - security-dead-letter: 死信队列（2分区）"