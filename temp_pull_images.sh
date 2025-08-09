#!/bin/bash

MIRRORS=(
    "https://docker.1ms.run"
    "https://mirror.ccs.tencentyun.com"
    "https://docker.m.daocloud.io"
    "https://dockerproxy.com"
)

IMAGES=(
    "elasticsearch:8.11.1"
    "kibana:8.11.1"
    "neo4j:4.4-community"
    "redis:6.2-alpine"
    "mysql:8.0"
    "confluentinc/cp-zookeeper:7.0.1"
    "confluentinc/cp-kafka:7.0.1"
    "clickhouse/clickhouse-server:23.8-alpine"
    "apache/flink:1.17.0"
    "provectuslabs/kafka-ui:latest"
)

echo "🐳 通过配置的镜像源拉取镜像..."

for image in "${IMAGES[@]}"; do
    echo "拉取 $image..."
    if docker pull "$image" > /dev/null 2>&1; then
        echo "✅ $image 拉取成功"
    else
        echo "⚠️  $image 拉取失败"
    fi
done
