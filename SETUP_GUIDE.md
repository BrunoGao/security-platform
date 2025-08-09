# 安全告警分析系统 - 快速配置指南

## 🚀 快速开始

### 1. 基础设施配置
```bash
# 配置所有基础组件（Docker镜像、Python环境等）
./setup_infrastructure.sh
```

### 2. 检查系统状态
```bash
# 检查基础设施是否准备就绪
./check_infrastructure.sh
```

### 3. 启动系统
```bash
# 一键启动完整系统
./start_app.sh
```

### 4. 停止系统
```bash
# 停止所有服务
./stop_all.sh
```

## 📋 脚本说明

### `setup_infrastructure.sh`
- **功能**: 拉取和配置所有基础组件
- **包含**:
  - Docker镜像下载 (Elasticsearch, Kafka, Neo4j, ClickHouse等)
  - Python虚拟环境创建
  - 依赖包安装
  - Docker网络和存储卷配置
- **使用**: 首次部署时运行，或需要重新配置时运行

### `check_infrastructure.sh`
- **功能**: 检查基础设施状态
- **检查项**:
  - Docker环境
  - Docker镜像完整性
  - Python环境
  - 配置文件
  - 端口占用情况
  - 容器运行状态
- **使用**: 问题排查和状态确认

### `start_app.sh`
- **功能**: 一键启动完整系统
- **包含**:
  - 系统环境检查
  - Docker服务启动
  - API服务启动
  - Web演示界面启动
  - 健康检查
- **使用**: 日常启动系统

## 🔧 配置要求

### 系统要求
- **操作系统**: macOS 或 Linux
- **内存**: 建议 8GB+
- **磁盘**: 建议 50GB+ 可用空间
- **网络**: 需要访问 Docker Hub

### 必要工具
- Docker (20.10+)
- Docker Compose (2.0+)
- Python 3.8+

## 📊 服务端口

| 服务 | 端口 | 用途 |
|------|------|------|
| API服务 | 8000 | 核心API接口 |
| Elasticsearch | 9200 | 日志搜索 |
| Kibana | 5601 | 日志可视化 |
| Neo4j | 7474 | 图数据库管理 |
| ClickHouse | 8123 | 分析数据库 |
| Redis | 6379 | 缓存服务 |
| MySQL | 3306 | 元数据存储 |
| Kafka | 9092 | 消息队列 |
| Kafka UI | 8082 | Kafka管理界面 |
| Web演示 | 5115 | 演示管理界面 |

## 🐛 常见问题

### 1. Docker镜像拉取失败
```bash
# 检查网络连接
ping docker.io

# 手动拉取单个镜像
docker pull elasticsearch:8.11.1

# 重新运行配置脚本
./setup_infrastructure.sh
```

### 2. 端口被占用
```bash
# 检查端口占用
./check_infrastructure.sh

# 停止现有服务
./stop_all.sh

# 或手动停止占用端口的进程
lsof -ti:8000 | xargs kill -9
```

### 3. Python依赖安装失败
```bash
# 检查Python版本
python3 --version

# 手动创建虚拟环境
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 📁 重要文件

- `logs/`: 系统日志目录
- `venv/`: Python虚拟环境
- `demo_venv/`: 演示界面环境
- `.infrastructure_ready`: 配置完成标记
- `docker-compose.yml`: Docker服务配置

## 💡 使用建议

1. **首次部署**: 按顺序运行 `setup_infrastructure.sh` → `check_infrastructure.sh` → `start_app.sh`
2. **日常使用**: 直接运行 `start_app.sh` 
3. **问题排查**: 运行 `check_infrastructure.sh` 检查状态
4. **重新配置**: 删除 `.infrastructure_ready` 文件后重新运行 `setup_infrastructure.sh`

## 🎯 快速验证

配置完成后，访问以下地址验证系统：
- API文档: http://localhost:8000/docs
- Web演示: http://localhost:5115
- Kibana: http://localhost:5601
- Neo4j: http://localhost:7474