# 安全告警分析系统 - 一键启动解决方案

## 概述

本解决方案提供了一套完整的安全告警分析系统管理脚本，实现了系统的一键启动、停止、状态监控和维护功能。

## 脚本功能

### 🚀 主要管理脚本

#### 1. `manage.sh` - 统一管理入口
这是系统的主要管理入口，提供了所有常用操作的统一接口。

**基本用法:**
```bash
./manage.sh [命令] [选项]
```

**主要命令:**
- `start` - 启动整个系统
- `stop` - 停止整个系统  
- `restart` - 重启整个系统
- `status` - 检查系统状态

**使用示例:**
```bash
./manage.sh start          # 启动系统
./manage.sh status         # 检查状态
./manage.sh logs elasticsearch  # 查看ES日志
./manage.sh restart        # 重启系统
```

#### 2. `one_click_start.sh` - 一键启动脚本
完整的系统启动脚本，包含所有必要的检查和配置。

**主要功能:**
- ✅ 系统环境检查（Docker、Python、资源等）
- ✅ 自动修复常见问题
- ✅ 基础设施服务启动
- ✅ 服务健康检查
- ✅ API服务启动
- ✅ 监控面板创建
- ✅ 详细的启动日志

**使用方法:**
```bash
./one_click_start.sh
```

#### 3. `stop_system.sh` - 系统停止脚本
安全地停止所有系统服务。

**主要功能:**
- 🛑 优雅停止API服务
- 🛑 停止Docker容器
- 🧹 清理相关进程
- 🔌 释放占用端口
- 💾 自动备份配置
- 📊 生成停止报告

**使用方法:**
```bash
./stop_system.sh
```

#### 4. `status_check.sh` - 状态检查脚本
全面的系统状态检查和监控。

**主要功能:**
- 🌐 API服务状态检查
- 🐳 Docker服务状态检查
- 🔗 HTTP端点健康检查
- 🗄️ 数据库连接测试
- 📊 系统资源监控
- 📋 日志文件检查
- 🔒 安全配置检查

**使用方法:**
```bash
./status_check.sh           # 完整检查
./status_check.sh --brief   # 简要信息
./status_check.sh --json    # JSON格式输出
./status_check.sh --api     # 仅检查API
```

## 系统架构

### 核心组件
- **Elasticsearch** - 日志搜索和分析
- **Kibana** - 数据可视化
- **Neo4j** - 图数据库
- **ClickHouse** - 分析数据库
- **MySQL** - 关系数据库
- **Redis** - 缓存系统
- **Kafka** - 消息队列
- **Flink** - 流处理

### 服务端口
| 服务 | 端口 | 用途 |
|------|------|------|
| API服务 | 8000 | RESTful API |
| Kibana | 5601 | 数据可视化 |
| Neo4j | 7474 | 图数据库管理 |
| ClickHouse | 8123 | 数据分析 |
| Elasticsearch | 9200 | 搜索引擎 |
| MySQL | 3307 | 关系数据库 |
| Redis | 6380 | 缓存服务 |
| Kafka | 9092 | 消息队列 |
| Kafka UI | 8082 | Kafka管理界面 |

## 快速开始

### 1. 系统要求
- **操作系统**: macOS/Linux
- **内存**: 建议8GB以上
- **磁盘空间**: 建议50GB以上
- **软件依赖**: Docker, Docker Compose, Python3

### 2. 安装和启动
```bash
# 克隆项目（如果需要）
git clone <repository-url>
cd security-platform

# 一键启动系统
./manage.sh start

# 或者直接使用
./one_click_start.sh
```

### 3. 验证安装
```bash
# 检查系统状态
./manage.sh status

# 测试API接口
curl -X POST "http://localhost:8000/api/v1/analyze/event" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "security_test",
    "log_data": {
      "src_ip": "192.168.1.100",
      "username": "test_user",
      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'"
    }
  }'
```

### 4. 访问系统
- **API服务**: http://localhost:8000
- **API文档**: http://localhost:8000/docs
- **Kibana**: http://localhost:5601
- **Neo4j**: http://localhost:7474 (neo4j/security123)
- **ClickHouse**: http://localhost:8123/play (admin/security123)
- **Kafka UI**: http://localhost:8082

## 运维管理

### 日常操作
```bash
# 查看系统状态
./manage.sh status

# 查看服务日志
./manage.sh logs
./manage.sh logs elasticsearch

# 重启特定服务
docker-compose restart elasticsearch

# 停止系统
./manage.sh stop
```

### 故障排查
```bash
# 检查详细状态
./status_check.sh

# 查看启动日志
tail -f logs/startup_*.log

# 查看API日志
./manage.sh logs-api

# 检查Docker服务
docker-compose ps
docker-compose logs [服务名]
```

### 系统维护
```bash
# 备份配置
./manage.sh backup

# 更新镜像
./manage.sh update

# 清理系统
./manage.sh clean

# 深度清理（包括数据）
./manage.sh clean-all
```

## 高级功能

### 1. 自动化监控
系统会自动创建监控面板文件 `monitoring_dashboard.html`，提供可视化的系统状态监控。

### 2. 日志管理
- 所有操作日志保存在 `logs/` 目录
- 支持日志轮转和压缩
- 提供结构化的JSON状态报告

### 3. 错误恢复
- 自动检测和修复常见问题
- 智能重试机制
- 服务依赖管理

### 4. 安全配置
- 默认使用本地访问
- 可配置的认证信息
- 文件权限检查

## 自定义配置

### 环境变量
可以通过环境变量自定义系统行为：

```bash
export COMPOSE_PROJECT_NAME="my-security-system"
export API_PORT=8080
export LOG_LEVEL=DEBUG
```

### 配置文件
主要配置文件：
- `docker-compose.yml` - Docker服务配置
- `requirements.txt` - Python依赖
- `config/` - 各服务的配置文件

## 故障排查指南

### 常见问题

1. **端口冲突**
   ```bash
   # 检查端口占用
   lsof -i :8000
   # 杀死占用进程
   kill -9 <PID>
   ```

2. **内存不足**
   ```bash
   # 检查内存使用
   ./status_check.sh
   # 调整Docker内存限制
   ```

3. **服务启动失败**
   ```bash
   # 查看具体错误
   docker-compose logs [服务名]
   # 重启单个服务
   docker-compose restart [服务名]
   ```

4. **数据库连接失败**
   ```bash
   # 检查数据库状态
   ./status_check.sh --brief
   # 重置数据库
   docker-compose restart mysql redis
   ```

### 获取帮助
```bash
# 查看帮助信息
./manage.sh help

# 查看脚本选项
./status_check.sh --help
```

## 开发和扩展

### 添加新服务
1. 在 `docker-compose.yml` 中添加服务定义
2. 更新 `one_click_start.sh` 中的服务列表
3. 在 `status_check.sh` 中添加健康检查

### 自定义检查项
在 `status_check.sh` 中添加新的检查函数：

```bash
check_custom_service() {
    print_section "🔧 自定义服务检查"
    # 添加检查逻辑
    check_status "PASS" "自定义服务运行正常"
}
```

## 版本历史

- **v2.0** - 完整的管理脚本套件
- **v1.0** - 基础启动脚本

## 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证。

## 联系支持

如遇问题，请：
1. 查看日志文件
2. 运行状态检查
3. 提交Issue
4. 联系技术支持

---

**注意**: 本脚本套件专为安全分析系统设计，请在生产环境使用前进行充分测试。