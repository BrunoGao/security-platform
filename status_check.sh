#!/bin/bash

# 安全告警分析系统 - 状态检查脚本
# Security Alert Analysis System - Status Check Script
# Version: 2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${SCRIPT_DIR}/security_system.pid"
LOG_DIR="${SCRIPT_DIR}/logs"
STATUS_LOG="${LOG_DIR}/status_$(date +%Y%m%d_%H%M%S).log"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 状态计数器
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNING_CHECKS=0
FAILED_CHECKS=0

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$STATUS_LOG"
}

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        安全告警分析系统 - 状态检查                           ║"
    echo "║                    Security Alert Analysis System                            ║"
    echo "║                            Status Check v2.0                                ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_section() {
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

check_status() {
    local status="$1"
    local message="$2"
    ((TOTAL_CHECKS++))
    
    case "$status" in
        "PASS")
            echo -e "${GREEN}✅ $message${NC}"
            ((PASSED_CHECKS++))
            log_message "PASS" "$message"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ((WARNING_CHECKS++))
            log_message "WARN" "$message"
            ;;
        "FAIL")
            echo -e "${RED}❌ $message${NC}"
            ((FAILED_CHECKS++))
            log_message "FAIL" "$message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            log_message "INFO" "$message"
            ;;
    esac
}

get_service_status() {
    local service="$1"
    if docker-compose ps | grep -q "$service.*Up"; then
        echo "运行中"
    else
        echo "已停止"
    fi
}

get_service_uptime() {
    local service="$1"
    local container_id=$(docker-compose ps -q "$service" 2>/dev/null)
    if [ -n "$container_id" ]; then
        docker inspect "$container_id" --format='{{.State.StartedAt}}' 2>/dev/null | xargs -I {} date -d {} '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知"
    else
        echo "未运行"
    fi
}

check_api_service() {
    print_section "🌐 API服务状态"
    
    # 检查PID文件
    if [ -f "$PID_FILE" ]; then
        local api_pid=$(cat "$PID_FILE")
        if ps -p "$api_pid" > /dev/null 2>&1; then
            check_status "PASS" "API服务进程运行中 (PID: $api_pid)"
            
            # 获取进程信息
            local process_info=$(ps -p "$api_pid" -o pid,ppid,pcpu,pmem,etime,cmd --no-headers)
            check_status "INFO" "进程详情: $process_info"
        else
            check_status "FAIL" "API服务进程不存在 (PID文件中的PID: $api_pid)"
        fi
    else
        check_status "WARN" "未找到PID文件: $PID_FILE"
        
        # 尝试查找API进程
        local api_pids=$(ps aux | grep "uvicorn.*security_api" | grep -v grep | awk '{print $2}')
        if [ -n "$api_pids" ]; then
            check_status "WARN" "发现API进程但无PID文件: $api_pids"
        else
            check_status "FAIL" "未发现API进程"
        fi
    fi
    
    # 检查API端点
    if curl -s --connect-timeout 5 http://localhost:8000/health > /dev/null 2>&1; then
        check_status "PASS" "API健康检查端点响应正常"
        
        # 获取API信息
        local api_info=$(curl -s http://localhost:8000/health 2>/dev/null)
        if [ -n "$api_info" ]; then
            check_status "INFO" "API响应: $api_info"
        fi
    else
        check_status "FAIL" "API健康检查端点无响应"
    fi
    
    # 检查API文档
    if curl -s --connect-timeout 5 http://localhost:8000/docs > /dev/null 2>&1; then
        check_status "PASS" "API文档可访问"
    else
        check_status "WARN" "API文档不可访问"
    fi
}

check_docker_services() {
    print_section "🐳 Docker服务状态"
    
    # 检查Docker是否运行
    if ! docker info > /dev/null 2>&1; then
        check_status "FAIL" "Docker服务未运行"
        return 1
    fi
    check_status "PASS" "Docker服务运行正常"
    
    # 检查docker-compose文件
    if [ ! -f "docker-compose.yml" ]; then
        check_status "FAIL" "未找到docker-compose.yml文件"
        return 1
    fi
    check_status "PASS" "docker-compose.yml文件存在"
    
    # 检查各个服务
    local services=("zookeeper" "kafka" "elasticsearch" "kibana" "neo4j" "clickhouse" "mysql" "redis" "flink-jobmanager" "flink-taskmanager" "kafka-ui")
    
    echo ""
    printf "%-20s %-10s %-20s %-15s\n" "服务名" "状态" "启动时间" "健康状态"
    echo "────────────────────────────────────────────────────────────────────────"
    
    for service in "${services[@]}"; do
        local status=$(get_service_status "$service")
        local uptime=$(get_service_uptime "$service")
        local health="未知"
        
        # 检查容器健康状态
        local container_id=$(docker-compose ps -q "$service" 2>/dev/null)
        if [ -n "$container_id" ]; then
            health=$(docker inspect "$container_id" --format='{{.State.Health.Status}}' 2>/dev/null || echo "无健康检查")
        fi
        
        printf "%-20s %-10s %-20s %-15s\n" "$service" "$status" "$uptime" "$health"
        
        if [ "$status" = "运行中" ]; then
            check_status "PASS" "$service 服务运行中"
        else
            check_status "FAIL" "$service 服务已停止"
        fi
    done
}

check_http_endpoints() {
    print_section "🔗 HTTP端点检查"
    
    local endpoints=(
        "http://localhost:8000|API服务"
        "http://localhost:8000/health|API健康检查"
        "http://localhost:8000/docs|API文档"
        "http://localhost:9200|Elasticsearch"
        "http://localhost:9200/_cluster/health|Elasticsearch集群健康"
        "http://localhost:5601|Kibana"
        "http://localhost:5601/api/status|Kibana状态"
        "http://localhost:7474|Neo4j浏览器"
        "http://localhost:8123|ClickHouse"
        "http://localhost:8123/ping|ClickHouse Ping"
        "http://localhost:8082|Kafka UI"
    )
    
    for endpoint_info in "${endpoints[@]}"; do
        IFS='|' read -r url description <<< "$endpoint_info"
        
        local response_time=$(curl -s -w "%{time_total}" -o /dev/null --connect-timeout 10 "$url" 2>/dev/null || echo "超时")
        
        if [ "$response_time" != "超时" ] && [ "$response_time" != "000" ]; then
            check_status "PASS" "$description 可访问 (响应时间: ${response_time}s)"
        else
            check_status "FAIL" "$description 不可访问"
        fi
    done
}

check_database_connections() {
    print_section "🗄️  数据库连接检查"
    
    # MySQL连接测试
    if docker exec security-mysql mysql -u security -psecurity123 -e "SELECT 1;" > /dev/null 2>&1; then
        check_status "PASS" "MySQL连接正常"
        
        # 获取MySQL版本和状态
        local mysql_version=$(docker exec security-mysql mysql -u security -psecurity123 -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
        check_status "INFO" "MySQL版本: $mysql_version"
    else
        check_status "FAIL" "MySQL连接失败"
    fi
    
    # Redis连接测试
    if docker exec security-redis redis-cli -a security123 ping > /dev/null 2>&1; then
        check_status "PASS" "Redis连接正常"
        
        # 获取Redis信息
        local redis_info=$(docker exec security-redis redis-cli -a security123 info server 2>/dev/null | grep "redis_version" | cut -d: -f2 | tr -d '\r')
        check_status "INFO" "Redis版本: $redis_info"
    else
        check_status "FAIL" "Redis连接失败"
    fi
    
    # Elasticsearch连接测试
    if curl -s http://localhost:9200/_cluster/health > /dev/null 2>&1; then
        check_status "PASS" "Elasticsearch连接正常"
        
        # 获取集群状态
        local es_status=$(curl -s http://localhost:9200/_cluster/health | jq -r '.status' 2>/dev/null || echo "未知")
        check_status "INFO" "Elasticsearch集群状态: $es_status"
    else
        check_status "FAIL" "Elasticsearch连接失败"
    fi
    
    # Neo4j连接测试
    if curl -s http://localhost:7474/db/data/ > /dev/null 2>&1; then
        check_status "PASS" "Neo4j连接正常"
    else
        check_status "FAIL" "Neo4j连接失败"
    fi
}

check_system_resources() {
    print_section "📊 系统资源状态"
    
    # 检查CPU使用率
    if command -v python3 &> /dev/null; then
        local cpu_usage=$(python3 -c "
import psutil
print(f'{psutil.cpu_percent(interval=1):.1f}')
        " 2>/dev/null || echo "未知")
        
        if [ "$cpu_usage" != "未知" ]; then
            local cpu_int=${cpu_usage%.*}
            if [ "$cpu_int" -lt 80 ]; then
                check_status "PASS" "CPU使用率: ${cpu_usage}%"
            elif [ "$cpu_int" -lt 90 ]; then
                check_status "WARN" "CPU使用率较高: ${cpu_usage}%"
            else
                check_status "FAIL" "CPU使用率过高: ${cpu_usage}%"
            fi
        fi
        
        # 检查内存使用率
        local memory_info=$(python3 -c "
import psutil
mem = psutil.virtual_memory()
print(f'{mem.percent:.1f}|{mem.total//1024//1024//1024}|{mem.available//1024//1024//1024}')
        " 2>/dev/null || echo "未知|未知|未知")
        
        IFS='|' read -r mem_percent total_gb available_gb <<< "$memory_info"
        
        if [ "$mem_percent" != "未知" ]; then
            local mem_int=${mem_percent%.*}
            if [ "$mem_int" -lt 80 ]; then
                check_status "PASS" "内存使用率: ${mem_percent}% (总计: ${total_gb}GB, 可用: ${available_gb}GB)"
            elif [ "$mem_int" -lt 90 ]; then
                check_status "WARN" "内存使用率较高: ${mem_percent}% (总计: ${total_gb}GB, 可用: ${available_gb}GB)"
            else
                check_status "FAIL" "内存使用率过高: ${mem_percent}% (总计: ${total_gb}GB, 可用: ${available_gb}GB)"
            fi
        fi
        
        # 检查磁盘使用率
        local disk_usage=$(python3 -c "
import psutil
disk = psutil.disk_usage('.')
print(f'{disk.percent:.1f}|{disk.total//1024//1024//1024}|{disk.free//1024//1024//1024}')
        " 2>/dev/null || echo "未知|未知|未知")
        
        IFS='|' read -r disk_percent total_disk_gb free_disk_gb <<< "$disk_usage"
        
        if [ "$disk_percent" != "未知" ]; then
            local disk_int=${disk_percent%.*}
            if [ "$disk_int" -lt 80 ]; then
                check_status "PASS" "磁盘使用率: ${disk_percent}% (总计: ${total_disk_gb}GB, 可用: ${free_disk_gb}GB)"
            elif [ "$disk_int" -lt 90 ]; then
                check_status "WARN" "磁盘使用率较高: ${disk_percent}% (总计: ${total_disk_gb}GB, 可用: ${free_disk_gb}GB)"
            else
                check_status "FAIL" "磁盘使用率过高: ${disk_percent}% (总计: ${total_disk_gb}GB, 可用: ${free_disk_gb}GB)"
            fi
        fi
    fi
    
    # 检查网络连接
    local network_connections=$(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l || echo "未知")
    check_status "INFO" "活跃网络连接数: $network_connections"
}

check_log_files() {
    print_section "📋 日志文件检查"
    
    # 检查日志目录
    if [ -d "$LOG_DIR" ]; then
        check_status "PASS" "日志目录存在: $LOG_DIR"
        
        # 检查日志文件大小
        local log_size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)
        check_status "INFO" "日志目录大小: $log_size"
        
        # 检查最新的日志文件
        local latest_logs=$(find "$LOG_DIR" -name "*.log" -type f -mtime -1 2>/dev/null | head -5)
        if [ -n "$latest_logs" ]; then
            check_status "PASS" "发现最近的日志文件"
            echo "$latest_logs" | while read -r log_file; do
                local file_size=$(ls -lh "$log_file" 2>/dev/null | awk '{print $5}')
                local file_date=$(ls -l "$log_file" 2>/dev/null | awk '{print $6, $7, $8}')
                check_status "INFO" "日志文件: $(basename "$log_file") (大小: $file_size, 日期: $file_date)"
            done
        else
            check_status "WARN" "未发现最近的日志文件"
        fi
    else
        check_status "FAIL" "日志目录不存在: $LOG_DIR"
    fi
    
    # 检查Docker日志
    if command -v docker-compose &> /dev/null; then
        check_status "INFO" "Docker服务日志状态:"
        local services=("elasticsearch" "neo4j" "mysql" "redis")
        for service in "${services[@]}"; do
            local log_lines=$(docker-compose logs --tail=10 "$service" 2>/dev/null | wc -l || echo "0")
            check_status "INFO" "$service 最近日志行数: $log_lines"
        done
    fi
}

check_security_configuration() {
    print_section "🔒 安全配置检查"
    
    # 检查文件权限
    local important_files=("docker-compose.yml" "requirements.txt" "$PID_FILE")
    for file in "${important_files[@]}"; do
        if [ -f "$file" ]; then
            local permissions=$(ls -l "$file" | awk '{print $1}')
            check_status "INFO" "$file 权限: $permissions"
        fi
    done
    
    # 检查端口安全性
    local public_ports=()
    for port in 8000 5601 7474 8123 9200; do
        if netstat -an 2>/dev/null | grep -q ":$port.*0.0.0.0"; then
            public_ports+=($port)
        fi
    done
    
    if [ ${#public_ports[@]} -gt 0 ]; then
        check_status "WARN" "发现对外开放的端口: ${public_ports[*]}"
    else
        check_status "PASS" "所有端口均为本地访问"
    fi
    
    # 检查默认密码
    check_status "WARN" "使用默认密码，建议在生产环境中修改"
}

generate_summary_report() {
    print_section "📊 状态汇总报告"
    
    local pass_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    local warn_rate=$((WARNING_CHECKS * 100 / TOTAL_CHECKS))
    local fail_rate=$((FAILED_CHECKS * 100 / TOTAL_CHECKS))
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              系统状态汇总                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${WHITE}检查统计:${NC}"
    echo -e "   总检查项: ${WHITE}$TOTAL_CHECKS${NC}"
    echo -e "   ${GREEN}通过: $PASSED_CHECKS ($pass_rate%)${NC}"
    echo -e "   ${YELLOW}警告: $WARNING_CHECKS ($warn_rate%)${NC}"
    echo -e "   ${RED}失败: $FAILED_CHECKS ($fail_rate%)${NC}"
    echo ""
    
    # 系统整体状态评估
    if [ $FAILED_CHECKS -eq 0 ] && [ $WARNING_CHECKS -eq 0 ]; then
        echo -e "${GREEN}🎉 系统状态: 优秀 - 所有检查都通过${NC}"
    elif [ $FAILED_CHECKS -eq 0 ] && [ $WARNING_CHECKS -le 3 ]; then
        echo -e "${YELLOW}⚠️  系统状态: 良好 - 有少量警告项${NC}"
    elif [ $FAILED_CHECKS -le 2 ]; then
        echo -e "${YELLOW}⚠️  系统状态: 一般 - 存在问题需要关注${NC}"
    else
        echo -e "${RED}❌ 系统状态: 异常 - 存在严重问题需要修复${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}建议操作:${NC}"
    
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo "   1. 查看失败项并修复问题"
        echo "   2. 重启相关服务: docker-compose restart [服务名]"
        echo "   3. 检查日志文件: $LOG_DIR"
    fi
    
    if [ $WARNING_CHECKS -gt 0 ]; then
        echo "   4. 关注警告项，考虑优化配置"
        echo "   5. 监控系统资源使用情况"
    fi
    
    echo "   6. 定期运行状态检查: ./status_check.sh"
    echo "   7. 查看详细状态日志: $STATUS_LOG"
    
    echo ""
    echo -e "${CYAN}快速操作命令:${NC}"
    echo "   重启系统: ./stop_system.sh && ./one_click_start.sh"
    echo "   查看日志: docker-compose logs -f [服务名]"
    echo "   服务管理: docker-compose [start|stop|restart] [服务名]"
    
    # 生成JSON格式的状态报告
    local json_report="${LOG_DIR}/status_report_$(date +%Y%m%d_%H%M%S).json"
    cat > "$json_report" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "total_checks": $TOTAL_CHECKS,
  "passed_checks": $PASSED_CHECKS,
  "warning_checks": $WARNING_CHECKS,
  "failed_checks": $FAILED_CHECKS,
  "pass_rate": $pass_rate,
  "warn_rate": $warn_rate,
  "fail_rate": $fail_rate,
  "system_status": "$([ $FAILED_CHECKS -eq 0 ] && [ $WARNING_CHECKS -eq 0 ] && echo "excellent" || ([ $FAILED_CHECKS -eq 0 ] && [ $WARNING_CHECKS -le 3 ] && echo "good" || ([ $FAILED_CHECKS -le 2 ] && echo "fair" || echo "poor")))",
  "log_file": "$STATUS_LOG",
  "report_file": "$json_report"
}
EOF
    
    echo ""
    echo -e "${GREEN}📊 JSON状态报告已生成: $json_report${NC}"
}

main() {
    print_banner
    
    log_message "START" "开始系统状态检查"
    
    # 执行各项检查
    check_api_service
    check_docker_services
    check_http_endpoints
    check_database_connections
    check_system_resources
    check_log_files
    check_security_configuration
    
    # 生成汇总报告
    generate_summary_report
    
    log_message "COMPLETE" "系统状态检查完成"
}

# 支持命令行参数
case "${1:-}" in
    --json)
        # 只输出JSON格式结果
        main > /dev/null 2>&1
        cat "${LOG_DIR}"/status_report_*.json | tail -1
        ;;
    --brief)
        # 简要输出
        main | grep -E "(✅|⚠️|❌|系统状态:)"
        ;;
    --api)
        # 只检查API服务
        print_banner
        check_api_service
        ;;
    --docker)
        # 只检查Docker服务
        print_banner
        check_docker_services
        ;;
    *)
        # 完整检查
        main
        ;;
esac