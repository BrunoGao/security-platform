#!/bin/bash

# Kibana仪表板配置脚本
# Kibana Dashboard Configuration Script

set -e

echo "📊 配置Kibana仪表板..."

# 等待Kibana启动
echo "⏳ 等待Kibana服务启动..."
until curl -s http://localhost:5601/api/status > /dev/null; do
    echo "   等待Kibana..."
    sleep 5
done

echo "✅ Kibana服务已就绪"

# Kibana API参数
KIBANA_URL="http://localhost:5601"
HEADERS="Content-Type: application/json"
HEADERS_NDJSON="Content-Type: application/x-ndjson"

echo ""
echo "🔍 创建索引模式..."

# 1. 创建索引模式
create_index_pattern() {
    local pattern_id="$1"
    local pattern_title="$2"
    local time_field="$3"
    
    echo "创建索引模式: $pattern_title"
    
    curl -s -X POST "$KIBANA_URL/api/saved_objects/index-pattern/$pattern_id" \
        -H "$HEADERS" \
        -H "kbn-xsrf: true" \
        -d "{
            \"attributes\": {
                \"title\": \"$pattern_title\",
                \"timeFieldName\": \"$time_field\"
            }
        }" > /dev/null
}

# 创建各种索引模式
create_index_pattern "security-logs" "security-logs-*" "timestamp"
create_index_pattern "security-alerts" "security-alerts-*" "timestamp"
create_index_pattern "security-entities" "security-entities-*" "first_seen"

echo ""
echo "📈 创建可视化图表..."

# 2. 创建安全事件趋势图
curl -s -X POST "$KIBANA_URL/api/saved_objects/visualization/security-events-timeline" \
    -H "$HEADERS" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "Security Events Timeline",
            "type": "histogram",
            "params": {
                "grid": {"categoryLines": false, "style": {"color": "#eee"}},
                "categoryAxes": [{"id": "CategoryAxis-1", "type": "category", "position": "bottom", "show": true, "style": {}, "scale": {"type": "linear"}, "labels": {"show": true, "truncate": 100}, "title": {}}],
                "valueAxes": [{"id": "ValueAxis-1", "name": "LeftAxis-1", "type": "value", "position": "left", "show": true, "style": {}, "scale": {"type": "linear", "mode": "normal"}, "labels": {"show": true, "rotate": 0, "filter": false, "truncate": 100}, "title": {"text": "Count"}}],
                "seriesParams": [{"show": "true", "type": "histogram", "mode": "stacked", "data": {"label": "Count", "id": "1"}, "valueAxis": "ValueAxis-1", "drawLinesBetweenPoints": true, "showCircles": true}],
                "addTooltip": true,
                "addLegend": true,
                "legendPosition": "right",
                "times": [],
                "addTimeMarker": false
            },
            "aggs": [
                {"id": "1", "enabled": true, "type": "count", "schema": "metric", "params": {}},
                {"id": "2", "enabled": true, "type": "date_histogram", "schema": "segment", "params": {"field": "timestamp", "interval": "auto", "customInterval": "2h", "min_doc_count": 1, "extended_bounds": {}}}
            ]
        }
    }' > /dev/null

# 3. 创建风险分数分布图
curl -s -X POST "$KIBANA_URL/api/saved_objects/visualization/risk-score-distribution" \
    -H "$HEADERS" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "Risk Score Distribution",
            "type": "histogram",
            "params": {
                "addTooltip": true,
                "addLegend": true,
                "scale": "linear",
                "mode": "stacked",
                "times": [],
                "addTimeMarker": false
            },
            "aggs": [
                {"id": "1", "enabled": true, "type": "count", "schema": "metric", "params": {}},
                {"id": "2", "enabled": true, "type": "histogram", "schema": "segment", "params": {"field": "risk_score", "interval": 10, "extended_bounds": {"min": 0, "max": 100}}}
            ]
        }
    }' > /dev/null

# 4. 创建威胁等级饼图
curl -s -X POST "$KIBANA_URL/api/saved_objects/visualization/threat-level-pie" \
    -H "$HEADERS" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "Threat Level Distribution",
            "type": "pie",
            "params": {
                "addTooltip": true,
                "addLegend": true,
                "legendPosition": "right",
                "isDonut": true
            },
            "aggs": [
                {"id": "1", "enabled": true, "type": "count", "schema": "metric", "params": {}},
                {"id": "2", "enabled": true, "type": "terms", "schema": "segment", "params": {"field": "threat_level", "size": 5, "order": "desc", "orderBy": "1"}}
            ]
        }
    }' > /dev/null

# 5. 创建实体类型统计图
curl -s -X POST "$KIBANA_URL/api/saved_objects/visualization/entity-types-bar" \
    -H "$HEADERS" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "Entity Types Statistics",
            "type": "horizontal_bar",
            "params": {
                "grid": {"categoryLines": false, "style": {"color": "#eee"}},
                "categoryAxes": [{"id": "CategoryAxis-1", "type": "category", "position": "left", "show": true, "style": {}, "scale": {"type": "linear"}, "labels": {"show": true, "rotate": 0, "filter": true, "truncate": 200}, "title": {}}],
                "valueAxes": [{"id": "ValueAxis-1", "name": "BottomAxis-1", "type": "value", "position": "bottom", "show": true, "style": {}, "scale": {"type": "linear", "mode": "normal"}, "labels": {"show": true, "rotate": 75, "filter": false, "truncate": 100}, "title": {"text": "Count"}}],
                "seriesParams": [{"show": true, "type": "histogram", "mode": "stacked", "data": {"label": "Count", "id": "1"}, "valueAxis": "ValueAxis-1", "drawLinesBetweenPoints": true, "showCircles": true}],
                "addTooltip": true,
                "addLegend": true,
                "legendPosition": "right",
                "times": [],
                "addTimeMarker": false
            },
            "aggs": [
                {"id": "1", "enabled": true, "type": "count", "schema": "metric", "params": {}},
                {"id": "2", "enabled": true, "type": "terms", "schema": "segment", "params": {"field": "entity_type", "size": 10, "order": "desc", "orderBy": "1"}}
            ]
        }
    }' > /dev/null

# 6. 创建异常类型统计表
curl -s -X POST "$KIBANA_URL/api/saved_objects/visualization/anomaly-types-table" \
    -H "$HEADERS" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "Anomaly Types Table",
            "type": "table",
            "params": {
                "perPage": 10,
                "showPartialRows": false,
                "showMeticsAtAllLevels": false,
                "sort": {"columnIndex": null, "direction": null},
                "showTotal": false,
                "totalFunc": "sum"
            },
            "aggs": [
                {"id": "1", "enabled": true, "type": "count", "schema": "metric", "params": {}},
                {"id": "2", "enabled": true, "type": "terms", "schema": "bucket", "params": {"field": "anomaly_type", "size": 20, "order": "desc", "orderBy": "1"}},
                {"id": "3", "enabled": true, "type": "avg", "schema": "metric", "params": {"field": "risk_score"}}
            ]
        }
    }' > /dev/null

echo ""
echo "📋 创建仪表板..."

# 7. 创建安全总览仪表板
curl -s -X POST "$KIBANA_URL/api/saved_objects/dashboard/security-overview-dashboard" \
    -H "$HEADERS" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "Security Analysis Overview",
            "hits": 0,
            "description": "Security events and threat analysis overview dashboard",
            "panelsJSON": "[{\"version\":\"7.15.0\",\"gridData\":{\"x\":0,\"y\":0,\"w\":24,\"h\":15,\"i\":\"1\"},\"panelIndex\":\"1\",\"embeddableConfig\":{},\"panelRefName\":\"panel_1\"},{\"version\":\"7.15.0\",\"gridData\":{\"x\":24,\"y\":0,\"w\":24,\"h\":15,\"i\":\"2\"},\"panelIndex\":\"2\",\"embeddableConfig\":{},\"panelRefName\":\"panel_2\"},{\"version\":\"7.15.0\",\"gridData\":{\"x\":0,\"y\":15,\"w\":24,\"h\":15,\"i\":\"3\"},\"panelIndex\":\"3\",\"embeddableConfig\":{},\"panelRefName\":\"panel_3\"},{\"version\":\"7.15.0\",\"gridData\":{\"x\":24,\"y\":15,\"w\":24,\"h\":15,\"i\":\"4\"},\"panelIndex\":\"4\",\"embeddableConfig\":{},\"panelRefName\":\"panel_4\"},{\"version\":\"7.15.0\",\"gridData\":{\"x\":0,\"y\":30,\"w\":48,\"h\":15,\"i\":\"5\"},\"panelIndex\":\"5\",\"embeddableConfig\":{},\"panelRefName\":\"panel_5\"}]",
            "optionsJSON": "{\"useMargins\":true,\"syncColors\":false,\"hidePanelTitles\":false}",
            "version": 1,
            "timeRestore": false,
            "kibanaSavedObjectMeta": {
                "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"
            }
        },
        "references": [
            {"name": "panel_1", "type": "visualization", "id": "security-events-timeline"},
            {"name": "panel_2", "type": "visualization", "id": "risk-score-distribution"},
            {"name": "panel_3", "type": "visualization", "id": "threat-level-pie"},
            {"name": "panel_4", "type": "visualization", "id": "entity-types-bar"},
            {"name": "panel_5", "type": "visualization", "id": "anomaly-types-table"}
        ]
    }' > /dev/null

echo ""
echo "🚨 创建实时告警仪表板..."

# 8. 创建实时告警仪表板
curl -s -X POST "$KIBANA_URL/api/saved_objects/dashboard/security-alerts-dashboard" \
    -H "$HEADERS" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "Security Alerts Dashboard",
            "hits": 0,
            "description": "Real-time security alerts monitoring dashboard",
            "panelsJSON": "[{\"version\":\"7.15.0\",\"gridData\":{\"x\":0,\"y\":0,\"w\":48,\"h\":20,\"i\":\"1\"},\"panelIndex\":\"1\",\"embeddableConfig\":{},\"panelRefName\":\"panel_1\"}]",
            "optionsJSON": "{\"useMargins\":true,\"syncColors\":false,\"hidePanelTitles\":false}",
            "version": 1,
            "timeRestore": true,
            "timeTo": "now",
            "timeFrom": "now-1h",
            "refreshInterval": {
                "pause": false,
                "value": 30000
            },
            "kibanaSavedObjectMeta": {
                "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"
            }
        },
        "references": [
            {"name": "panel_1", "type": "search", "id": "security-alerts-search"}
        ]
    }' > /dev/null

echo ""
echo "🔍 创建保存的搜索..."

# 9. 创建高风险事件搜索
curl -s -X POST "$KIBANA_URL/api/saved_objects/search/high-risk-events-search" \
    -H "$HEADERS" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "High Risk Security Events",
            "description": "Security events with risk score >= 70",
            "hits": 0,
            "columns": ["timestamp", "event_type", "src_ip", "username", "risk_score", "threat_level", "anomaly_type"],
            "sort": [["timestamp", "desc"]],
            "version": 1,
            "kibanaSavedObjectMeta": {
                "searchSourceJSON": "{\"index\":\"security-logs\",\"query\":{\"query\":\"risk_score >= 70\",\"language\":\"kuery\"},\"filter\":[]}"
            }
        }
    }' > /dev/null

# 10. 创建告警搜索
curl -s -X POST "$KIBANA_URL/api/saved_objects/search/security-alerts-search" \
    -H "$HEADERS" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "Security Alerts",
            "description": "All security alerts",
            "hits": 0,
            "columns": ["timestamp", "severity", "title", "description", "risk_score", "status"],
            "sort": [["timestamp", "desc"]],
            "version": 1,
            "kibanaSavedObjectMeta": {
                "searchSourceJSON": "{\"index\":\"security-alerts\",\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"
            }
        }
    }' > /dev/null

echo ""
echo "⏰ 配置Watcher告警..."

# 11. 创建高风险事件告警
curl -s -X PUT "$KIBANA_URL/api/watcher/watch/high-risk-events-alert" \
    -H "$HEADERS" \
    -H "kbn-xsrf: true" \
    -d '{
        "trigger": {
            "schedule": {
                "interval": "1m"
            }
        },
        "input": {
            "search": {
                "request": {
                    "search_type": "query_then_fetch",
                    "indices": ["security-logs-*"],
                    "body": {
                        "query": {
                            "bool": {
                                "must": [
                                    {"range": {"risk_score": {"gte": 80}}},
                                    {"range": {"timestamp": {"gte": "now-5m"}}}
                                ]
                            }
                        }
                    }
                }
            }
        },
        "condition": {
            "compare": {
                "ctx.payload.hits.total": {
                    "gt": 0
                }
            }
        },
        "actions": {
            "log_error": {
                "logging": {
                    "level": "error",
                    "text": "High risk security event detected: {{ctx.payload.hits.total}} events with risk score >= 80"
                }
            }
        }
    }' > /dev/null 2>&1 || echo "   ⚠️  Watcher可能未启用，跳过告警配置"

echo ""
echo "📊 验证仪表板配置..."

# 12. 验证创建的对象
echo "📋 验证索引模式:"
curl -s "$KIBANA_URL/api/saved_objects/_find?type=index-pattern" \
    -H "kbn-xsrf: true" | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for obj in data.get('saved_objects', []):
        print(f'  ✅ {obj[\"attributes\"][\"title\"]}')
except:
    print('  ⚠️  无法解析响应')
" 2>/dev/null || echo "  ⚠️  索引模式验证失败"

echo ""
echo "📈 验证可视化图表:"
curl -s "$KIBANA_URL/api/saved_objects/_find?type=visualization" \
    -H "kbn-xsrf: true" | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for obj in data.get('saved_objects', []):
        print(f'  ✅ {obj[\"attributes\"][\"title\"]}')
except:
    print('  ⚠️  无法解析响应')
" 2>/dev/null || echo "  ⚠️  可视化图表验证失败"

echo ""
echo "📊 验证仪表板:"
curl -s "$KIBANA_URL/api/saved_objects/_find?type=dashboard" \
    -H "kbn-xsrf: true" | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for obj in data.get('saved_objects', []):
        print(f'  ✅ {obj[\"attributes\"][\"title\"]}')
except:
    print('  ⚠️  无法解析响应')
" 2>/dev/null || echo "  ⚠️  仪表板验证失败"

echo ""
echo "✅ Kibana仪表板配置完成！"
echo ""
echo "🎯 可以通过以下链接访问仪表板："
echo "   - Kibana首页: http://localhost:5601"
echo "   - 安全总览: http://localhost:5601/app/dashboards#/view/security-overview-dashboard"
echo "   - 实时告警: http://localhost:5601/app/dashboards#/view/security-alerts-dashboard"
echo "   - Discover: http://localhost:5601/app/discover"
echo ""
echo "📊 建议的使用流程："
echo "   1. 使用Discover探索原始数据"
echo "   2. 查看安全总览仪表板了解整体态势"
echo "   3. 监控实时告警仪表板跟踪新威胁"
echo "   4. 使用保存的搜索快速定位高风险事件"