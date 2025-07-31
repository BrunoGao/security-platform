# 安全告警日志研判系统 (Security Alert Analysis System)

## 系统概述

安全告警日志研判系统是一个基于多引擎架构的安全事件分析平台，能够自动化处理安全告警，提取关键实体，分析实体关联关系，评估威胁风险，并执行相应的安全响应措施。

### 核心功能

#### 四引擎架构

1. **实体识别引擎 (Entity Recognition Engine)**
   - 从日志数据中提取IP地址、用户、文件、进程、域名等安全实体
   - 支持正则表达式和结构化字段解析
   - 自动识别实体类型和属性

2. **连接扩充引擎 (Connection Expansion Engine)**
   - 基于资产关系、威胁情报、基线异常和时序关联扩充实体连接
   - 集成Neo4j图数据库进行关系分析
   - 支持多维度连接发现

3. **风险评分引擎 (Risk Scoring Engine)**
   - 结合单点指标和多点行为序列进行风险评分
   - 支持机器学习模型集成
   - 动态调整风险阈值

4. **响应执行引擎 (Response Executor Engine)**
   - 支持防火墙、AD、EDR等多种响应器
   - 自动化执行安全响应动作
   - 支持手动和自动响应模式

### 技术架构

#### 核心技术栈

- **Python 3.8+** - 主要开发语言
- **FastAPI** - REST API框架
- **asyncio** - 异步处理支持
- **Neo4j** - 图数据库，用于实体关系存储
- **ClickHouse** - 分析型数据库，用于日志查询
- **Redis** - 缓存和会话存储
- **MySQL** - 元数据存储
- **Kafka** - 消息队列
- **Elasticsearch** - 日志搜索引擎

#### 系统组件

```
security-platform/
├── docker-compose.yml          # Docker服务编排
├── requirements.txt            # Python依赖
├── start.sh                   # 系统启动脚本
├── test_system.py             # 系统测试脚本
├── src/
│   ├── models/
│   │   └── entities.py        # 数据模型定义
│   ├── engines/
│   │   ├── entity_recognizer.py      # 实体识别引擎
│   │   ├── connection_expansion.py   # 连接扩充引擎
│   │   ├── risk_scoring.py          # 风险评分引擎
│   │   └── response_executor.py     # 响应执行引擎
│   ├── services/
│   │   └── security_analysis_service.py  # 核心业务服务
│   └── apis/
│       └── security_api.py     # REST API接口
```

## API使用示例

### 单个事件分析

```bash
curl -X POST "http://localhost:8000/api/v1/analyze/event" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "network_anomaly",
    "log_data": {
      "src_ip": "192.168.1.100",
      "dst_ip": "103.45.67.89",
      "username": "john.doe",
      "timestamp": "2024-01-01T12:00:00Z",
      "is_anomaly": true,
      "anomaly_type": "unusual_data_transfer"
    }
  }'
```

### 批量事件分析

```bash
curl -X POST "http://localhost:8000/api/v1/analyze/batch" \
  -H "Content-Type: application/json" \
  -d '{
    "events": [
      {
        "event_type": "file_access",
        "log_data": {
          "username": "admin",
          "file_path": "/etc/passwd",
          "action": "read"
        }
      }
    ]
  }'
```

### 手动响应执行

```bash
curl -X POST "http://localhost:8000/api/v1/response/manual" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_id": "192.168.1.100",
    "entity_type": "ip",
    "actions": ["block_ip", "send_alert"]
  }'
```

## 系统配置

### 处理配置

```python
processing_config = {
    'enable_connection_expansion': True,
    'enable_risk_scoring': True, 
    'enable_auto_response': True,
    'max_concurrent_processing': 10,
    'min_risk_threshold_for_response': 50.0
}
```

### 响应配置

```python
response_config = {
    'firewall': {
        'api_endpoint': 'http://firewall-api:8080',
        'api_key': 'your-api-key'
    },
    'ad': {
        'ldap_server': 'ldap://ad-server:389',
        'admin_user': 'admin',
        'admin_password': 'password'
    }
}
```

## 监控指标

系统提供丰富的监控指标：

- **处理事件总数**: total_events_processed
- **提取实体总数**: total_entities_extracted  
- **扩充连接总数**: total_connections_expanded
- **执行响应总数**: total_responses_executed
- **平均处理时间**: average_processing_time

通过 `/api/v1/statistics` 接口获取实时统计信息。

## 实体类型支持

系统支持以下实体类型的识别和分析：

- **IP** - IP地址 (IPv4/IPv6)
- **USER** - 用户账户
- **FILE** - 文件路径
- **PROCESS** - 进程信息
- **DOMAIN** - 域名
- **EMAIL** - 邮箱地址
- **URL** - 网址链接
- **HASH** - 文件哈希值
- **DEVICE** - 设备名称

## 威胁等级

- **LOW** (0-30分) - 低风险
- **MEDIUM** (30-70分) - 中等风险  
- **HIGH** (70-90分) - 高风险
- **CRITICAL** (90-100分) - 极高风险

## 响应动作类型

### IP地址响应
- `block_ip` - 阻断IP
- `allow_ip` - 允许IP
- `monitor_ip` - 监控IP

### 用户响应  
- `disable_user` - 禁用用户
- `reset_password` - 重置密码
- `force_logout` - 强制登出

### 文件响应
- `quarantine_file` - 隔离文件
- `delete_file` - 删除文件
- `collect_evidence` - 收集证据

### 告警响应
- `send_alert` - 发送告警
- `create_ticket` - 创建工单

## 开发指南

### 运行测试

```bash
# 运行系统测试
python test_system.py

# 运行单元测试
pytest tests/
```

### 代码风格

```bash
# 代码格式化
black src/

# 类型检查
mypy src/

# 代码规范检查
flake8 src/
```

## 部署指南

### Docker部署

```bash
# 构建镜像
docker build -t security-analysis-system .

# 运行容器
docker run -p 8000:8000 security-analysis-system
```

### 生产环境配置

1. 配置环境变量
2. 设置数据库连接
3. 配置外部服务集成
4. 启用监控和日志收集

## 故障排除

### 常见问题

1. **服务启动失败**
   - 检查Docker服务状态
   - 验证端口占用情况
   - 查看日志文件

2. **分析超时**
   - 调整 `processing_timeout` 参数
   - 减少 `max_concurrent_processing` 值

3. **响应执行失败**
   - 验证外部系统连接
   - 检查API密钥配置

### 日志查看

```bash
# 查看API服务日志
docker-compose logs security-api

# 查看所有服务日志
docker-compose logs
```

---

基于流式处理的智能安全告警分析与响应平台，实现实时日志分析、实体识别、关系扩充、风险评分和自动化响应。

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    数据采集层                                │
├─────────────────────────────────────────────────────────────┤
│  Filebeat  │ Logstash │ Fluentd │ API Gateway │ Agent        │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    数据处理层                                │
├─────────────────────────────────────────────────────────────┤
│     Apache Kafka     │    Apache Flink    │    规则引擎      │
│     (消息队列)       │    (流式计算)       │    (Drools)      │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    存储层                                    │
├─────────────────────────────────────────────────────────────┤
│ Elasticsearch │ ClickHouse │ Neo4j │ Redis │ MySQL          │
│  (日志搜索)   │  (分析库)   │(图谱) │(缓存) │(元数据)        │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    分析决策层                                │
├─────────────────────────────────────────────────────────────┤
│ 实体识别引擎 │ 关系扩充引擎 │ 风险评分引擎 │ ML模型服务      │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    应用服务层                                │
├─────────────────────────────────────────────────────────────┤
│  告警服务  │  响应编排  │  取证分析  │  报表服务            │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 快速开始

### 系统要求

- **操作系统**: macOS / Linux / Windows (with WSL2)
- **Docker**: 20.10+ 
- **Docker Compose**: 2.0+
- **内存**: 最少8GB，推荐16GB+
- **磁盘**: 最少50GB可用空间
- **CPU**: 最少4核，推荐8核+

### 一键部署

```bash
# 克隆项目（如果需要）
git clone <repository-url>
cd security-platform

# 启动所有服务
./scripts/start.sh

# 检查服务状态
./scripts/status.sh

# 停止所有服务
./scripts/stop.sh
```

### 服务端口

| 服务 | 端口 | 用途 | 默认账号 |
|------|------|------|----------|
| Elasticsearch | 9200 | 日志搜索引擎 | - |
| Kibana | 5601 | 日志分析界面 | - |
| Neo4j | 7474, 7687 | 图数据库 | neo4j/security123 |
| ClickHouse | 8123, 9000 | 分析数据库 | admin/security123 |
| MySQL | 3306 | 元数据存储 | security/security123 |
| Redis | 6379 | 缓存服务 | password: security123 |
| Kafka | 9092 | 消息队列 | - |
| Kafka UI | 8080 | Kafka管理界面 | - |
| Flink | 8081 | 流处理界面 | - |

## 🔧 配置说明

### 环境配置

系统会自动创建 `.env` 文件，包含以下主要配置：

```bash
# 数据库密码
MYSQL_ROOT_PASSWORD=security123
NEO4J_PASSWORD=security123
CLICKHOUSE_PASSWORD=security123
REDIS_PASSWORD=security123

# JVM内存设置
ES_JAVA_OPTS=-Xms1g -Xmx1g
FLINK_JM_HEAP=1280m
FLINK_TM_HEAP=1280m
```

### 自定义配置

可以修改以下配置文件：

- `config/elasticsearch/elasticsearch.yml` - Elasticsearch配置
- `config/kibana/kibana.yml` - Kibana配置  
- `config/clickhouse/config.xml` - ClickHouse配置
- `config/flink/flink-conf.yaml` - Flink配置
- `config/mysql/my.cnf` - MySQL配置

## 📊 Web界面访问

启动成功后，可以通过以下地址访问各种管理界面：

### 🔍 日志分析 - Kibana
- **地址**: http://localhost:5601
- **功能**: 日志搜索、可视化分析、仪表板

### 🕸️ 图数据库 - Neo4j Browser  
- **地址**: http://localhost:7474
- **账号**: neo4j / security123
- **功能**: 实体关系图谱、Cypher查询

### 📈 消息队列管理 - Kafka UI
- **地址**: http://localhost:8080  
- **功能**: Topic管理、消息监控、性能统计

### ⚡ 流处理监控 - Flink Dashboard
- **地址**: http://localhost:8081
- **功能**: 作业管理、性能监控、检查点状态

### 📋 分析数据库 - ClickHouse Play
- **地址**: http://localhost:8123/play
- **账号**: admin / security123  
- **功能**: SQL查询、数据分析

## 🛠️ 运维管理

### 启动服务

```bash
# 完整启动（推荐）
./scripts/start.sh

# 手动启动特定服务
docker-compose up -d elasticsearch kibana
```

### 检查状态

```bash
# 基础状态检查
./scripts/status.sh

# 详细健康检查
./scripts/status.sh --health

# 资源使用情况
./scripts/status.sh --resources

# 查看服务日志
./scripts/status.sh --logs

# 性能测试
./scripts/status.sh --performance

# 完整检查
./scripts/status.sh --all
```

### 停止服务

```bash
# 仅停止服务
./scripts/stop.sh

# 停止并清理数据
./scripts/stop.sh --clean-data

# 停止并清理所有（容器+镜像+数据）
./scripts/stop.sh --clean-all
```

### 服务管理

```bash
# 查看运行状态
docker-compose ps

# 查看特定服务日志
docker-compose logs -f elasticsearch

# 重启特定服务
docker-compose restart kafka

# 扩展服务实例
docker-compose up -d --scale flink-taskmanager=3
```

## 📊 数据库结构

### MySQL - 元数据存储

核心表结构：

- `users` - 用户管理
- `entities` - 安全实体（IP、用户、文件等）
- `entity_connections` - 实体连接关系
- `security_alerts` - 安全告警事件
- `response_actions` - 响应动作记录
- `threat_intelligence` - 威胁情报
- `system_config` - 系统配置

### Elasticsearch - 日志存储

索引模式：

- `security-logs-YYYY.MM.DD` - 日志数据
- `security-alerts-YYYY.MM.DD` - 告警数据
- `security-entities-YYYY.MM.DD` - 实体数据

### Neo4j - 图数据库

节点类型：

- `:User` - 用户节点
- `:IP` - IP地址节点
- `:Device` - 设备节点
- `:File` - 文件节点
- `:Process` - 进程节点

关系类型：

- `:CONNECTS_TO` - 连接关系
- `:BELONGS_TO` - 归属关系
- `:ACCESSES` - 访问关系
- `:EXECUTES` - 执行关系

## 🔍 故障排除

### 常见问题

1. **端口占用错误**
   ```bash
   # 检查端口占用
   netstat -tuln | grep :9200
   
   # 停止占用进程
   sudo lsof -ti:9200 | xargs kill -9
   ```

2. **内存不足**
   ```bash
   # 调整JVM内存设置
   export ES_JAVA_OPTS="-Xms512m -Xmx512m"
   
   # 减少服务数量
   docker-compose up -d elasticsearch kibana mysql
   ```

3. **磁盘空间不足**
   ```bash
   # 清理Docker数据
   docker system prune -af
   docker volume prune -f
   
   # 检查磁盘使用
   df -h
   du -sh data/*
   ```

4. **服务启动失败**
   ```bash
   # 查看详细日志
   docker-compose logs service-name
   
   # 重启服务
   docker-compose restart service-name
   
   # 检查配置文件
   docker-compose config
   ```

### 性能优化

1. **Elasticsearch优化**
   ```yaml
   # 增加堆内存
   ES_JAVA_OPTS: "-Xms2g -Xmx2g"
   
   # 调整刷新间隔
   index.refresh_interval: 30s
   ```

2. **Kafka优化**
   ```yaml
   # 增加分区数
   KAFKA_NUM_PARTITIONS: 6
   
   # 调整批处理大小
   KAFKA_BATCH_SIZE: 16384
   ```

3. **ClickHouse优化**
   ```xml
   <!-- 增加内存限制 -->
   <max_memory_usage>8000000000</max_memory_usage>
   
   <!-- 启用压缩 -->
   <compression>
       <case>
           <method>lz4</method>
       </case>
   </compression>
   ```

## 📈 监控指标

### 关键性能指标

- **日志处理速率**: 条/秒
- **告警响应时间**: 秒
- **系统吞吐量**: 事件/分钟
- **误报率**: %
- **检测准确率**: %

### 监控命令

```bash
# 系统资源监控  
./scripts/status.sh --resources

# 服务健康检查
./scripts/status.sh --health

# 性能基准测试
./scripts/status.sh --performance
```

## 🔐 安全配置

### 默认账号

⚠️ **生产环境请务必修改默认密码！**

- MySQL: `security` / `security123`
- Neo4j: `neo4j` / `security123`
- ClickHouse: `admin` / `security123`
- Redis: `security123`

### 安全建议

1. 修改所有默认密码
2. 启用服务间TLS加密
3. 配置防火墙规则
4. 定期更新组件版本
5. 启用访问日志记录

## 🤝 贡献指南

1. Fork项目
2. 创建功能分支
3. 提交更改
4. 发起Pull Request

## 📄 许可证

MIT License

## 📞 技术支持

如有问题，请：

1. 查看故障排除文档
2. 检查系统日志
3. 提交Issue
4. 联系技术支持

---

**版本**: v1.0.0  
**最后更新**: 2025-07-29  
**维护者**: Security Team