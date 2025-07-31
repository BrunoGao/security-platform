#!/bin/bash

# Elasticsearch配置脚本
# Elasticsearch Configuration Script

set -e

echo "🔍 配置Elasticsearch索引和模板..."

# 等待Elasticsearch启动
echo "⏳ 等待Elasticsearch服务启动..."
until curl -s http://localhost:9200/_cluster/health > /dev/null; do
    echo "   等待Elasticsearch..."
    sleep 2
done

echo "✅ Elasticsearch服务已就绪"

# 1. 创建安全日志索引模板
echo "📝 创建安全日志索引模板..."
curl -X PUT "localhost:9200/_index_template/security-logs-template" \
  -H 'Content-Type: application/json' \
  -d '{
    "index_patterns": ["security-logs-*"],
    "priority": 1,
    "template": {
      "settings": {
        "number_of_shards": 2,
        "number_of_replicas": 1,
        "index.refresh_interval": "30s",
        "index.max_result_window": 50000
      },
      "mappings": {
        "properties": {
          "timestamp": {
            "type": "date",
            "format": "strict_date_optional_time||epoch_millis"
          },
          "event_id": {
            "type": "keyword"
          },
          "event_type": {
            "type": "keyword"
          },
          "src_ip": {
            "type": "ip"
          },
          "dst_ip": {
            "type": "ip"
          },
          "username": {
            "type": "keyword",
            "fields": {
              "text": {
                "type": "text",
                "analyzer": "standard"
              }
            }
          },
          "process_name": {
            "type": "keyword",
            "fields": {
              "text": {
                "type": "text"
              }
            }
          },
          "file_path": {
            "type": "keyword",
            "fields": {
              "text": {
                "type": "text"
              }
            }
          },
          "file_hash": {
            "type": "keyword"
          },
          "domain": {
            "type": "keyword",
            "fields": {
              "text": {
                "type": "text"
              }
            }
          },
          "url": {
            "type": "keyword",
            "fields": {
              "text": {
                "type": "text"
              }
            }
          },
          "command_line": {
            "type": "text",
            "analyzer": "standard"
          },
          "risk_score": {
            "type": "float"
          },
          "threat_level": {
            "type": "keyword"
          },
          "is_anomaly": {
            "type": "boolean"
          },
          "anomaly_type": {
            "type": "keyword"
          },
          "raw_log": {
            "type": "text",
            "index": false
          },
          "location": {
            "type": "geo_point"
          },
          "tags": {
            "type": "keyword"
          }
        }
      }
    }
  }'

# 2. 创建安全告警索引模板
echo ""
echo "🚨 创建安全告警索引模板..."
curl -X PUT "localhost:9200/_index_template/security-alerts-template" \
  -H 'Content-Type: application/json' \
  -d '{
    "index_patterns": ["security-alerts-*"],
    "priority": 1,
    "template": {
      "settings": {
        "number_of_shards": 1,
        "number_of_replicas": 1,
        "index.refresh_interval": "5s"
      },
      "mappings": {
        "properties": {
          "alert_id": {
            "type": "keyword"
          },
          "timestamp": {
            "type": "date"
          },
          "severity": {
            "type": "keyword"
          },
          "title": {
            "type": "text",
            "fields": {
              "keyword": {
                "type": "keyword"
              }
            }
          },
          "description": {
            "type": "text"
          },
          "source_event_id": {
            "type": "keyword"
          },
          "entities": {
            "type": "nested",
            "properties": {
              "entity_type": {
                "type": "keyword"
              },
              "entity_id": {
                "type": "keyword"
              },
              "risk_score": {
                "type": "float"
              }
            }
          },
          "response_actions": {
            "type": "nested",
            "properties": {
              "action": {
                "type": "keyword"
              },
              "status": {
                "type": "keyword"
              },
              "timestamp": {
                "type": "date"
              }
            }
          },
          "status": {
            "type": "keyword"
          },
          "assigned_to": {
            "type": "keyword"
          }
        }
      }
    }
  }'

# 3. 创建实体关系索引模板
echo ""
echo "🕸️  创建实体关系索引模板..."
curl -X PUT "localhost:9200/_index_template/security-entities-template" \
  -H 'Content-Type: application/json' \
  -d '{
    "index_patterns": ["security-entities-*"],
    "priority": 1,
    "template": {
      "settings": {
        "number_of_shards": 2,
        "number_of_replicas": 1
      },
      "mappings": {
        "properties": {
          "entity_id": {
            "type": "keyword"
          },
          "entity_type": {
            "type": "keyword"
          },
          "first_seen": {
            "type": "date"
          },
          "last_seen": {
            "type": "date"
          },
          "risk_score": {
            "type": "float"
          },
          "threat_level": {
            "type": "keyword"
          },
          "status": {
            "type": "keyword"
          },
          "metadata": {
            "type": "object",
            "dynamic": true
          },
          "connections": {
            "type": "nested",
            "properties": {
              "target_entity_id": {
                "type": "keyword"
              },
              "target_entity_type": {
                "type": "keyword"
              },
              "relationship_type": {
                "type": "keyword"
              },
              "confidence": {
                "type": "float"
              },
              "timestamp": {
                "type": "date"
              }
            }
          },
          "timeline": {
            "type": "nested",
            "properties": {
              "action": {
                "type": "keyword"
              },
              "timestamp": {
                "type": "date"
              },
              "details": {
                "type": "object"
              }
            }
          }
        }
      }
    }
  }'

# 4. 创建当天的索引
current_date=$(date +%Y.%m.%d)

echo ""
echo "📅 创建当日索引: $current_date"

# 创建安全日志索引
curl -X PUT "localhost:9200/security-logs-$current_date" \
  -H 'Content-Type: application/json' \
  -d "{
    \"aliases\": {
      \"security-logs\": {}
    }
  }"

# 创建安全告警索引
curl -X PUT "localhost:9200/security-alerts-$current_date" \
  -H 'Content-Type: application/json' \
  -d "{
    \"aliases\": {
      \"security-alerts\": {}
    }
  }"

# 创建实体索引
curl -X PUT "localhost:9200/security-entities-$current_date" \
  -H 'Content-Type: application/json' \
  -d "{
    \"aliases\": {
      \"security-entities\": {}
    }
  }"

# 5. 创建索引生命周期策略
echo ""
echo "🔄 配置索引生命周期策略..."
curl -X PUT "localhost:9200/_ilm/policy/security-logs-policy" \
  -H 'Content-Type: application/json' \
  -d '{
    "policy": {
      "phases": {
        "hot": {
          "actions": {
            "rollover": {
              "max_size": "10GB",
              "max_age": "7d"
            }
          }
        },
        "warm": {
          "min_age": "7d",
          "actions": {
            "shrink": {
              "number_of_shards": 1
            }
          }
        },
        "cold": {
          "min_age": "30d",
          "actions": {
            "allocate": {
              "number_of_replicas": 0
            }
          }
        },
        "delete": {
          "min_age": "90d"
        }
      }
    }
  }'

echo ""
echo "✅ Elasticsearch配置完成！"
echo ""
echo "📊 索引状态:"
curl -s "localhost:9200/_cat/indices/security-*?v"

echo ""
echo "📝 模板列表:"
curl -s "localhost:9200/_cat/templates/security-*?v"