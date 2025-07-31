-- 安全平台数据库初始化脚本

-- 创建数据库
CREATE DATABASE IF NOT EXISTS security DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE security;

-- 创建用户管理表
CREATE TABLE IF NOT EXISTS users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('admin', 'analyst', 'viewer') DEFAULT 'viewer',
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建实体表
CREATE TABLE IF NOT EXISTS entities (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    entity_type ENUM('ip', 'user', 'file', 'process', 'device', 'domain') NOT NULL,
    entity_id VARCHAR(255) NOT NULL,
    entity_name VARCHAR(255),
    status ENUM('pending', 'investigated', 'scored', 'compromised', 'blocked', 'bleeding_stop') DEFAULT 'pending',
    risk_score DECIMAL(5,2) DEFAULT 0.00,
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_entity (entity_type, entity_id),
    INDEX idx_entity_type (entity_type),
    INDEX idx_status (status),
    INDEX idx_risk_score (risk_score),
    INDEX idx_first_seen (first_seen),
    INDEX idx_last_seen (last_seen)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建连接关系表
CREATE TABLE IF NOT EXISTS entity_connections (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_entity_id BIGINT NOT NULL,
    target_entity_id BIGINT NOT NULL,
    connection_type VARCHAR(50) NOT NULL,
    confidence_score DECIMAL(3,2) DEFAULT 0.50,
    first_observed TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_observed TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    observation_count INT DEFAULT 1,
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (source_entity_id) REFERENCES entities(id) ON DELETE CASCADE,
    FOREIGN KEY (target_entity_id) REFERENCES entities(id) ON DELETE CASCADE,
    UNIQUE KEY uk_connection (source_entity_id, target_entity_id, connection_type),
    INDEX idx_source_entity (source_entity_id),
    INDEX idx_target_entity (target_entity_id),
    INDEX idx_connection_type (connection_type),
    INDEX idx_confidence_score (confidence_score)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建告警事件表
CREATE TABLE IF NOT EXISTS security_alerts (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    alert_id VARCHAR(100) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    severity ENUM('low', 'medium', 'high', 'critical') NOT NULL,
    status ENUM('open', 'investigating', 'resolved', 'false_positive') DEFAULT 'open',
    rule_id VARCHAR(100),
    rule_name VARCHAR(255),
    source_system VARCHAR(50),
    raw_log JSON,
    entity_id BIGINT,
    risk_score DECIMAL(5,2) DEFAULT 0.00,
    assigned_to BIGINT,
    resolved_by BIGINT,
    resolved_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE SET NULL,
    FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_alert_id (alert_id),
    INDEX idx_severity (severity),
    INDEX idx_status (status),
    INDEX idx_rule_id (rule_id),
    INDEX idx_source_system (source_system),
    INDEX idx_risk_score (risk_score),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建响应动作表
CREATE TABLE IF NOT EXISTS response_actions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    action_id VARCHAR(100) NOT NULL UNIQUE,
    action_type ENUM('block_ip', 'disable_user', 'quarantine_file', 'isolate_host', 'send_alert') NOT NULL,
    target_entity_id BIGINT NOT NULL,
    status ENUM('pending', 'executing', 'completed', 'failed') DEFAULT 'pending',
    executor VARCHAR(100),
    result TEXT,
    error_message TEXT,
    triggered_by BIGINT,
    alert_id BIGINT,
    executed_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (target_entity_id) REFERENCES entities(id) ON DELETE CASCADE,
    FOREIGN KEY (triggered_by) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (alert_id) REFERENCES security_alerts(id) ON DELETE CASCADE,
    INDEX idx_action_id (action_id),
    INDEX idx_action_type (action_type),
    INDEX idx_status (status),
    INDEX idx_target_entity (target_entity_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建威胁情报表
CREATE TABLE IF NOT EXISTS threat_intelligence (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    ioc_value VARCHAR(255) NOT NULL,
    ioc_type ENUM('ip', 'domain', 'url', 'hash', 'email') NOT NULL,
    threat_type VARCHAR(100),
    malware_family VARCHAR(100),
    confidence_level ENUM('low', 'medium', 'high') DEFAULT 'medium',
    source VARCHAR(100) NOT NULL,
    description TEXT,
    tags JSON,
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    expiration_date TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_ioc (ioc_value, ioc_type),
    INDEX idx_ioc_type (ioc_type),
    INDEX idx_threat_type (threat_type),
    INDEX idx_confidence_level (confidence_level),
    INDEX idx_source (source),
    INDEX idx_is_active (is_active),
    INDEX idx_expiration_date (expiration_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建系统配置表
CREATE TABLE IF NOT EXISTS system_config (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value TEXT NOT NULL,
    config_type ENUM('string', 'number', 'boolean', 'json') DEFAULT 'string',
    description TEXT,
    is_encrypted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_config_key (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 插入默认管理员用户
INSERT INTO users (username, email, password_hash, role, status) VALUES 
('admin', 'admin@security.local', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4xXFk.CYvq', 'admin', 'active');
-- 默认密码: admin123

-- 插入系统默认配置
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES 
('alert_retention_days', '90', 'number', '告警数据保留天数'),
('risk_score_threshold_high', '80.0', 'number', '高风险阈值'),
('risk_score_threshold_critical', '90.0', 'number', '严重风险阈值'),
('auto_response_enabled', 'true', 'boolean', '是否启用自动响应'),
('threat_intel_update_interval', '3600', 'number', '威胁情报更新间隔（秒）'),
('kafka_bootstrap_servers', 'kafka:29092', 'string', 'Kafka服务器地址'),
('elasticsearch_hosts', 'http://elasticsearch:9200', 'string', 'Elasticsearch地址'),
('neo4j_uri', 'bolt://neo4j:7687', 'string', 'Neo4j连接地址'),
('clickhouse_host', 'clickhouse', 'string', 'ClickHouse主机地址'),
('redis_host', 'redis', 'string', 'Redis主机地址');

-- 创建数据统计视图
CREATE VIEW alert_statistics AS
SELECT 
    DATE(created_at) as alert_date,
    severity,
    status,
    COUNT(*) as alert_count
FROM security_alerts 
GROUP BY DATE(created_at), severity, status;

CREATE VIEW entity_risk_summary AS
SELECT 
    entity_type,
    status,
    COUNT(*) as entity_count,
    AVG(risk_score) as avg_risk_score,
    MAX(risk_score) as max_risk_score
FROM entities 
GROUP BY entity_type, status;

-- 创建存储过程：更新实体风险分数
DELIMITER //
CREATE PROCEDURE UpdateEntityRiskScore(
    IN p_entity_id BIGINT,
    IN p_risk_score DECIMAL(5,2)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    UPDATE entities 
    SET risk_score = p_risk_score,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_entity_id;
    
    -- 根据风险分数更新状态
    UPDATE entities 
    SET status = CASE 
        WHEN p_risk_score >= 90 THEN 'compromised'
        WHEN p_risk_score >= 80 THEN 'scored'
        ELSE status
    END
    WHERE id = p_entity_id;
    
    COMMIT;
END //
DELIMITER ;

-- 创建触发器：实体状态变更日志
CREATE TABLE IF NOT EXISTS entity_status_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    entity_id BIGINT NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    changed_by VARCHAR(50) DEFAULT 'system',
    change_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE,
    INDEX idx_entity_id (entity_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER //
CREATE TRIGGER entity_status_change_log 
AFTER UPDATE ON entities 
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO entity_status_log (entity_id, old_status, new_status, change_reason)
        VALUES (NEW.id, OLD.status, NEW.status, 'Status updated');
    END IF;
END //
DELIMITER ;

COMMIT;