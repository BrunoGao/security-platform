// 安全告警分析系统演示界面 JavaScript 应用

class DemoApp {
    constructor() {
        this.socket = null;
        this.autoScroll = true;
        this.statusInterval = null;
        this.systemInfo = null;
        this.lastStatusUpdate = null;
        
        this.init();
    }
    
    init() {
        console.log('🚀 初始化演示应用...');
        
        // 首先隐藏加载遮罩层
        this.hideLoading();
        
        // 初始化WebSocket连接
        this.initWebSocket();
        
        // 初始化页面元素
        this.initPageElements();
        
        // 开始定时更新
        this.startStatusUpdates();
        
        // 绑定事件处理器
        this.bindEventHandlers();
        
        console.log('✅ 演示应用初始化完成');
    }
    
    initWebSocket() {
        try {
            this.socket = io();
            
            this.socket.on('connect', () => {
                console.log('🔌 WebSocket连接成功');
                this.showNotification('WebSocket连接成功', 'success');
            });
            
            this.socket.on('disconnect', () => {
                console.log('🔌 WebSocket连接断开');
                this.showNotification('WebSocket连接断开', 'warning');
            });
            
            this.socket.on('log_update', (data) => {
                this.addLogEntry(data);
            });
            
            this.socket.on('status_update', (data) => {
                this.updateSystemStatus(data);
            });
            
            // 监听攻击演示更新
            this.socket.on('attack_demo_update', (data) => {
                this.handleAttackDemoUpdate(data);
            });
            
            // 监听实体分析结果
            this.socket.on('entity_analysis', (data) => {
                this.handleEntityAnalysis(data);
            });
            
        } catch (error) {
            console.error('WebSocket初始化失败:', error);
            this.showNotification('WebSocket连接失败', 'error');
        }
    }
    
    initPageElements() {
        // 更新当前时间
        this.updateCurrentTime();
        setInterval(() => this.updateCurrentTime(), 1000);
        
        // 初始化进度圆环
        this.initProgressCircles();
        
        // 加载初始数据
        this.loadInitialData();
    }
    
    bindEventHandlers() {
        // 处理页面可见性变化
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.pauseUpdates();
            } else {
                this.resumeUpdates();
            }
        });
        
        // 处理窗口关闭
        window.addEventListener('beforeunload', () => {
            if (this.socket) {
                this.socket.disconnect();
            }
        });
    }
    
    startStatusUpdates() {
        this.refreshStatus();
        this.statusInterval = setInterval(() => {
            this.refreshStatus();
        }, 20000); // 每20秒更新一次（从10秒优化到20秒）
    }
    
    pauseUpdates() {
        if (this.statusInterval) {
            clearInterval(this.statusInterval);
            this.statusInterval = null;
        }
    }
    
    resumeUpdates() {
        if (!this.statusInterval) {
            this.startStatusUpdates();
        }
    }
    
    updateCurrentTime() {
        const now = new Date();
        const timeString = now.toLocaleString('zh-CN', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
        
        const timeElement = document.getElementById('current-time');
        if (timeElement) {
            timeElement.textContent = timeString;
        }
    }
    
    initProgressCircles() {
        const circles = document.querySelectorAll('.progress-circle');
        circles.forEach(circle => {
            circle.style.setProperty('--percent', '0%');
        });
    }
    
    async loadInitialData() {
        try {
            await this.refreshStatus();
            await this.loadLogs();
        } catch (error) {
            console.error('加载初始数据失败:', error);
        }
    }
    
    async refreshStatus() {
        try {
            const response = await fetch('/api/system/status');
            const data = await response.json();
            
            this.updateSystemStatus(data);
            this.lastStatusUpdate = new Date();
            
            // 更新最后更新时间
            const lastUpdateElement = document.getElementById('last-update');
            if (lastUpdateElement) {
                lastUpdateElement.textContent = this.lastStatusUpdate.toLocaleTimeString('zh-CN');
            }
            
        } catch (error) {
            console.error('刷新状态失败:', error);
            this.showNotification('状态刷新失败', 'error');
        }
    }
    
    updateSystemStatus(data) {
        // 更新系统状态徽章
        const statusElement = document.getElementById('system-status');
        if (statusElement && data.system_status) {
            const statusMap = {
                'running': { text: '运行中', class: 'bg-success' },
                'starting': { text: '启动中', class: 'bg-warning' },
                'stopping': { text: '停止中', class: 'bg-warning' },
                'stopped': { text: '已停止', class: 'bg-danger' },
                'failed': { text: '异常', class: 'bg-danger' },
                'unknown': { text: '未知', class: 'bg-secondary' }
            };
            
            const status = statusMap[data.system_status] || statusMap['unknown'];
            statusElement.textContent = status.text;
            statusElement.className = `badge ${status.class}`;
        }
        
        // 更新Docker服务状态
        if (data.docker && data.docker.services) {
            this.updateServicesStatus(data.docker.services);
        }
        
        // 更新系统资源信息
        this.updateSystemResources();
        
        // 更新按钮状态
        this.updateControlButtons(data);
    }
    
    updateServicesStatus(services) {
        const container = document.getElementById('services-status');
        if (!container) return;
        
        // 获取当前主机地址
        const currentHost = window.location.hostname;
        
        const servicesList = [
            { key: 'elasticsearch', name: 'Elasticsearch', icon: 'fas fa-search', port: '9200', url: `http://${currentHost}:9200` },
            { key: 'kibana', name: 'Kibana', icon: 'fas fa-chart-bar', port: '5601', url: `http://${currentHost}:5601` },
            { key: 'neo4j', name: 'Neo4j', icon: 'fas fa-project-diagram', port: '7474', url: `http://${currentHost}:7474` },
            { key: 'clickhouse', name: 'ClickHouse', icon: 'fas fa-table', port: '8123', url: `http://${currentHost}:8123/play` },
            { key: 'mysql', name: 'MySQL', icon: 'fas fa-database', port: '3307', url: null },
            { key: 'redis', name: 'Redis', icon: 'fas fa-memory', port: '6380', url: null },
            { key: 'kafka', name: 'Kafka', icon: 'fas fa-stream', port: '9093', url: null },
            { key: 'kafka-ui', name: 'Kafka UI', icon: 'fas fa-tachometer-alt', port: '8082', url: `http://${currentHost}:8082` }
        ];
        
        let html = '';
        servicesList.forEach(service => {
            const serviceData = services[service.key];
            const status = serviceData ? serviceData.status : 'unknown';
            const isRunning = status && (status.toLowerCase().includes('up') || status.toLowerCase() === 'running');
            
            const statusClass = isRunning ? 'status-running' : 'status-stopped';
            const statusText = isRunning ? '运行中' : '已停止';
            const statusIcon = isRunning ? 'fas fa-check-circle text-success' : 'fas fa-times-circle text-danger';
            
            // 健康状态
            const health = serviceData ? serviceData.health : '';
            const healthInfo = health ? `<small class="text-muted d-block">健康状态: ${health}</small>` : '';
            
            // 端口信息
            const portInfo = service.port ? `<small class="text-muted d-block">端口: ${service.port}</small>` : '';
            
            // 可点击链接
            const linkHtml = service.url && isRunning ? 
                `<a href="${service.url}" target="_blank" class="btn btn-sm btn-outline-primary mt-1">
                    <i class="fas fa-external-link-alt me-1"></i>打开
                </a>` : '';
            
            html += `
                <div class="col-md-2 col-sm-3 col-6 mb-2">
                    <div class="service-status-compact ${statusClass}">
                        <div class="service-icon-small">
                            <i class="${service.icon}"></i>
                        </div>
                        <div class="service-info">
                            <div class="service-name-small">${service.name}</div>
                            <div class="service-state-small">
                                <i class="${statusIcon} me-1"></i>
                                ${statusText}
                            </div>
                            ${service.url && isRunning ? `<a href="${service.url}" target="_blank" class="service-link-small"><i class="fas fa-external-link-alt"></i></a>` : ''}
                        </div>
                    </div>
                </div>
            `;
        });
        
        container.innerHTML = html;
    }
    
    async updateSystemResources() {
        try {
            const response = await fetch('/api/system/info');
            const data = await response.json();
            
            if (data.cpu) {
                this.updateProgressCircle('cpu-progress', data.cpu.percent, 'CPU');
            }
            
            if (data.memory) {
                this.updateProgressCircle('memory-progress', data.memory.percent, '内存');
            }
            
            if (data.disk) {
                this.updateProgressCircle('disk-progress', data.disk.percent, '磁盘');
            }
            
        } catch (error) {
            console.error('更新系统资源失败:', error);
        }
    }
    
    updateProgressCircle(elementId, percent, label) {
        const element = document.getElementById(elementId);
        if (!element) return;
        
        const roundedPercent = Math.round(percent);
        element.style.setProperty('--percent', `${roundedPercent}%`);
        
        const textElement = element.querySelector('.progress-text');
        if (textElement) {
            textElement.innerHTML = `${label}<br><strong>${roundedPercent}%</strong>`;
        }
        
        // 根据使用率设置颜色
        let color = '#0d6efd'; // 默认蓝色
        if (percent > 80) {
            color = '#dc3545'; // 红色
        } else if (percent > 60) {
            color = '#ffc107'; // 黄色
        } else if (percent > 40) {
            color = '#fd7e14'; // 橙色
        }
        
        element.style.setProperty('--primary-color', color);
    }
    
    updateControlButtons(data) {
        const startBtn = document.getElementById('start-btn');
        const stopBtn = document.getElementById('stop-btn');
        const restartBtn = document.getElementById('restart-btn');
        
        if (data.is_starting) {
            this.setButtonLoading(startBtn, '启动中...');
            this.disableButton(stopBtn);
            this.disableButton(restartBtn);
        } else if (data.is_stopping) {
            this.setButtonLoading(stopBtn, '停止中...');
            this.disableButton(startBtn);
            this.disableButton(restartBtn);
        } else {
            this.resetButton(startBtn, '启动系统', 'fas fa-play');
            this.resetButton(stopBtn, '停止系统', 'fas fa-stop');
            this.resetButton(restartBtn, '重启系统', 'fas fa-redo');
        }
    }
    
    setButtonLoading(button, text) {
        if (!button) return;
        button.disabled = true;
        button.innerHTML = `<i class="fas fa-spinner fa-spin me-2"></i>${text}`;
    }
    
    disableButton(button) {
        if (!button) return;
        button.disabled = true;
        button.classList.add('opacity-50');
    }
    
    resetButton(button, text, icon) {
        if (!button) return;
        button.disabled = false;
        button.classList.remove('opacity-50');
        button.innerHTML = `<i class="${icon} me-2"></i>${text}`;
    }
    
    async loadLogs() {
        try {
            const response = await fetch('/api/logs?limit=50');
            const data = await response.json();
            
            if (data.logs && data.logs.length > 0) {
                data.logs.forEach(log => this.addLogEntry(log));
            }
            
        } catch (error) {
            console.error('加载日志失败:', error);
        }
    }
    
    addLogEntry(logData) {
        const container = document.getElementById('log-container');
        if (!container) return;
        
        // 清除初始消息
        const initialMessage = container.querySelector('.text-center');
        if (initialMessage) {
            initialMessage.remove();
        }
        
        const logElement = document.createElement('div');
        logElement.className = `log-entry log-${logData.level.toLowerCase()}`;
        
        const timestamp = new Date(logData.timestamp).toLocaleTimeString('zh-CN');
        logElement.innerHTML = `
            <span class="log-timestamp">[${timestamp}]</span>
            <span class="log-level">[${logData.level}]</span>
            <span class="log-message">${logData.message}</span>
        `;
        
        container.appendChild(logElement);
        
        // 自动滚动到底部
        if (this.autoScroll) {
            container.scrollTop = container.scrollHeight;
        }
        
        // 限制日志条数，避免内存过多占用
        const maxLogs = 200;
        const logEntries = container.querySelectorAll('.log-entry');
        if (logEntries.length > maxLogs) {
            logEntries[0].remove();
        }
    }
    
    showNotification(message, type = 'info', duration = 3000) {
        // 创建通知元素
        const notification = document.createElement('div');
        notification.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
        notification.style.cssText = 'top: 20px; right: 20px; z-index: 10000; min-width: 300px;';
        
        notification.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;
        
        document.body.appendChild(notification);
        
        // 自动移除通知
        setTimeout(() => {
            if (notification.parentNode) {
                notification.remove();
            }
        }, duration);
    }
    
    handleAttackDemoUpdate(data) {
        console.log('🎯 收到攻击演示更新:', data);
        
        // 根据更新类型处理不同的演示阶段
        switch(data.stage) {
            case 'intrusion_detected':
                this.updateDemoStage('stage-intrusion', data);
                break;
            case 'lateral_movement':
                this.updateDemoStage('stage-lateral', data);
                break;
            case 'threat_analysis':
                this.updateDemoStage('stage-analysis', data);
                break;
        }
    }
    
    handleEntityAnalysis(data) {
        console.log('🔍 收到实体分析结果:', data);
        
        // 实时更新攻击图节点
        if (data.entities) {
            data.entities.forEach((entity, index) => {
                const nodeId = `node-entity-${index}`;
                const node = document.getElementById(nodeId);
                if (node) {
                    node.title = `${entity.entity_type}: ${entity.entity_id} (风险: ${entity.risk_score?.toFixed(1) || 0})`;
                    
                    if (entity.risk_score > 70) {
                        node.classList.add('compromised');
                    } else if (entity.risk_score > 30) {
                        node.classList.add('investigating');
                    }
                }
            });
        }
        
        // 添加策略匹配信息到日志
        if (data.matched_policy) {
            this.addLogEntry({
                timestamp: new Date().toISOString(),
                level: 'SUCCESS',
                message: `🛡️ 触发安全策略: ${data.matched_policy.policy_name}`
            });
            
            if (data.matched_policy.description) {
                this.addLogEntry({
                    timestamp: new Date().toISOString(),
                    level: 'INFO',
                    message: `📋 策略描述: ${data.matched_policy.description}`
                });
            }
        }
        
        // 添加实体分析日志
        this.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'INFO',
            message: `🔍 实体分析完成: ${data.entities?.length || 0} 个实体，最高风险: ${data.max_risk_score?.toFixed(1) || 0}`
        });
        
        // 如果没有匹配的策略，提示用户
        if (!data.matched_policy) {
            this.addLogEntry({
                timestamp: new Date().toISOString(),
                level: 'WARNING',
                message: '⚠️ 未匹配到任何安全策略，建议检查策略配置'
            });
        }
    }
    
    updateDemoStage(stageId, data) {
        const stage = document.getElementById(stageId);
        if (!stage) return;
        
        // 激活当前阶段
        stage.classList.add('active');
        
        // 更新步骤状态
        if (data.steps) {
            data.steps.forEach(step => {
                const stepElement = document.getElementById(step.id);
                if (stepElement) {
                    stepElement.classList.remove('investigating', 'completed', 'threat-detected');
                    stepElement.classList.add(step.status);
                }
            });
        }
        
        // 更新图节点
        if (data.nodes) {
            data.nodes.forEach(nodeData => {
                const node = document.getElementById(nodeData.id);
                if (node) {
                    node.classList.remove('compromised', 'investigating');
                    if (nodeData.status) {
                        node.classList.add(nodeData.status);
                    }
                }
            });
        }
    }
    
    showLoading() {
        const overlay = document.getElementById('loading-overlay');
        if (overlay) {
            overlay.classList.remove('d-none');
        }
    }
    
    hideLoading() {
        const overlay = document.getElementById('loading-overlay');
        if (overlay) {
            overlay.classList.add('d-none');
        }
    }
}

// 全局函数定义
window.demoApp = null;

// 系统控制函数
async function startSystem() {
    if (!confirm('确定要启动安全告警分析系统吗？')) return;
    
    window.demoApp.showLoading();
    
    try {
        const response = await fetch('/api/system/start', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.demoApp.showNotification('系统启动命令已发送', 'success');
        } else {
            window.demoApp.showNotification(`启动失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('启动系统失败:', error);
        window.demoApp.showNotification('启动系统失败', 'error');
    } finally {
        window.demoApp.hideLoading();
    }
}

async function stopSystem() {
    if (!confirm('确定要停止安全告警分析系统吗？')) return;
    
    window.demoApp.showLoading();
    
    try {
        const response = await fetch('/api/system/stop', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.demoApp.showNotification('系统停止命令已发送', 'success');
        } else {
            window.demoApp.showNotification(`停止失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('停止系统失败:', error);
        window.demoApp.showNotification('停止系统失败', 'error');
    } finally {
        window.demoApp.hideLoading();
    }
}

async function restartSystem() {
    if (!confirm('确定要重启安全告警分析系统吗？这可能需要几分钟时间。')) return;
    
    window.demoApp.showLoading();
    
    try {
        const response = await fetch('/api/system/restart', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.demoApp.showNotification('系统重启命令已发送', 'success');
        } else {
            window.demoApp.showNotification(`重启失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('重启系统失败:', error);
        window.demoApp.showNotification('重启系统失败', 'error');
    } finally {
        window.demoApp.hideLoading();
    }
}

async function createTestEvent() {
    try {
        // 显示攻击演示面板
        showAttackDemonstration();
        
        // 立即开始演示动画，与API调用并行执行
        const demonstrationPromise = startAttackDemonstration();
        
        const response = await fetch('/api/demo/test-event', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.demoApp.showNotification('测试事件创建成功', 'success');
            
            // 解析API响应数据并更新演示
            if (data.response && data.response.data) {
                updateDemonstrationWithApiData(data.response.data);
            }
            
            // 等待演示完成
            await demonstrationPromise;
        } else {
            window.demoApp.showNotification(`创建失败: ${data.message}`, 'error');
            hideAttackDemonstration();
        }
        
    } catch (error) {
        console.error('创建测试事件失败:', error);
        window.demoApp.showNotification('创建测试事件失败', 'error');
        hideAttackDemonstration();
    }
}

async function showDemoScenarios() {
    try {
        const response = await fetch('/api/demo/scenarios');
        const data = await response.json();
        
        const modalBody = document.querySelector('#demoScenariosModal .modal-body #demo-scenarios-list');
        if (!modalBody) return;
        
        let html = '';
        data.scenarios.forEach(scenario => {
            // 构建策略信息
            let policiesHtml = '';
            if (scenario.related_policies && scenario.related_policies.length > 0) {
                policiesHtml = '<div class="scenario-policies mt-2">';
                policiesHtml += '<small class="text-muted d-block"><i class="fas fa-shield-alt me-1"></i>相关策略:</small>';
                scenario.related_policies.forEach(policy => {
                    const statusClass = policy.enabled ? 'text-success' : 'text-danger';
                    const statusIcon = policy.enabled ? 'fas fa-check-circle' : 'fas fa-times-circle';
                    policiesHtml += `
                        <small class="d-block ${statusClass}">
                            <i class="${statusIcon} me-1"></i>${policy.name}
                        </small>
                    `;
                });
                policiesHtml += '</div>';
            } else {
                policiesHtml = '<div class="scenario-policies mt-2"><small class="text-warning"><i class="fas fa-exclamation-triangle me-1"></i>暂无关联策略，建议先创建相应的检测策略</small></div>';
            }
            
            html += `
                <div class="scenario-card" onclick="runDemoScenario('${scenario.id}')">
                    <div class="scenario-title">${scenario.name}</div>
                    <div class="scenario-description">${scenario.description}</div>
                    <div class="scenario-meta">
                        <span><i class="fas fa-calendar me-1"></i>事件数: ${scenario.events}</span>
                        <span><i class="fas fa-clock me-1"></i>持续时间: ${scenario.duration}</span>
                    </div>
                    ${policiesHtml}
                </div>
            `;
        });
        
        modalBody.innerHTML = html;
        
        // 显示模态框
        const modal = new bootstrap.Modal(document.getElementById('demoScenariosModal'));
        modal.show();
        
    } catch (error) {
        console.error('加载演示场景失败:', error);
        window.demoApp.showNotification('加载演示场景失败', 'error');
    }
}

async function runDemoScenario(scenarioId) {
    if (!confirm(`确定要运行演示场景"${scenarioId}"吗？`)) return;
    
    try {
        const response = await fetch(`/api/demo/run-scenario/${scenarioId}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.demoApp.showNotification(`演示场景"${scenarioId}"开始执行`, 'success');
            
            // 关闭模态框
            const modal = bootstrap.Modal.getInstance(document.getElementById('demoScenariosModal'));
            if (modal) modal.hide();
        } else {
            window.demoApp.showNotification(`场景执行失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('运行演示场景失败:', error);
        window.demoApp.showNotification('运行演示场景失败', 'error');
    }
}

async function openServiceUrls() {
    try {
        const response = await fetch('/api/system/status');
        const data = await response.json();
        
        const modalBody = document.querySelector('#serviceUrlsModal .modal-body #service-urls-list');
        if (!modalBody) return;
        
        const urls = data.urls || {};
        const urlList = [
            { key: 'api', name: 'API服务', icon: 'fas fa-code' },
            { key: 'api_docs', name: 'API文档', icon: 'fas fa-book' },
            { key: 'kibana', name: 'Kibana', icon: 'fas fa-chart-bar' },
            { key: 'neo4j', name: 'Neo4j', icon: 'fas fa-project-diagram' },
            { key: 'clickhouse', name: 'ClickHouse', icon: 'fas fa-database' },
            { key: 'kafka_ui', name: 'Kafka UI', icon: 'fas fa-stream' },
            { key: 'elasticsearch', name: 'Elasticsearch', icon: 'fas fa-search' }
        ];
        
        let html = '';
        urlList.forEach(item => {
            const url = urls[item.key];
            if (url) {
                html += `
                    <div class="col-md-6">
                        <div class="url-card">
                            <div class="d-flex align-items-center">
                                <i class="${item.icon} me-3 text-info"></i>
                                <div>
                                    <strong>${item.name}</strong><br>
                                    <a href="${url}" target="_blank">${url}</a>
                                </div>
                            </div>
                        </div>
                    </div>
                `;
            }
        });
        
        modalBody.innerHTML = html;
        
        // 显示模态框
        const modal = new bootstrap.Modal(document.getElementById('serviceUrlsModal'));
        modal.show();
        
    } catch (error) {
        console.error('加载服务链接失败:', error);
        window.demoApp.showNotification('加载服务链接失败', 'error');
    }
}

function refreshStatus() {
    if (window.demoApp) {
        window.demoApp.refreshStatus();
    }
}

function clearLogs() {
    const container = document.getElementById('log-container');
    if (container) {
        container.innerHTML = '<div class="text-center text-muted p-4">日志已清空</div>';
    }
}

function toggleAutoScroll() {
    if (window.demoApp) {
        window.demoApp.autoScroll = !window.demoApp.autoScroll;
        const message = window.demoApp.autoScroll ? '自动滚动已开启' : '自动滚动已关闭';
        window.demoApp.showNotification(message, 'info');
    }
}

// 攻击演示系统
function showAttackDemonstration() {
    const panel = document.getElementById('attack-demo-panel');
    if (panel) {
        panel.style.display = 'block';
        panel.scrollIntoView({ behavior: 'smooth', block: 'start' });
        console.log('🎯 显示攻击演示面板');
    }
}

function hideAttackDemonstration() {
    const panel = document.getElementById('attack-demo-panel');
    if (panel) {
        panel.style.display = 'none';
        console.log('🎯 隐藏攻击演示面板');
    }
}

async function startAttackDemonstration() {
    console.log('🎯 开始攻击演示序列...');
    
    try {
        // 重置所有阶段
        resetAttackStages();
        
        // 阶段1: 初始入侵 (0-5秒)
        await demonstrateInitialIntrusion();
        
        // 等待3秒
        await sleep(3000);
        
        // 阶段2: 横向移动 (5-12秒)
        await demonstrateLateralMovement();
        
        // 等待3秒
        await sleep(3000);
        
        // 阶段3: 威胁研判 (12-20秒)
        await demonstrateThreatAnalysis();
        
        console.log('🎯 攻击演示序列完成');
        window.demoApp.showNotification('攻击路径分析演示完成', 'success');
        
    } catch (error) {
        console.error('攻击演示失败:', error);
        window.demoApp.showNotification('攻击演示失败', 'error');
    }
}

function resetAttackStages() {
    // 隐藏所有阶段
    const stages = document.querySelectorAll('.attack-stage');
    stages.forEach(stage => {
        stage.classList.remove('active');
    });
    
    // 重置所有步骤状态
    const steps = document.querySelectorAll('.analysis-step');
    steps.forEach(step => {
        step.classList.remove('completed', 'investigating', 'threat-detected');
    });
    
    // 重置图节点状态
    const nodes = document.querySelectorAll('.graph-node');
    nodes.forEach(node => {
        node.classList.remove('compromised', 'investigating');
    });
}

async function demonstrateInitialIntrusion() {
    console.log('🚪 演示初始入侵阶段...');
    
    // 显示阶段1
    const stage = document.getElementById('stage-intrusion');
    if (stage) {
        stage.classList.add('active');
    }
    
    // 动画1: 检测异常登录
    await sleep(1000);
    const step1 = document.getElementById('step-detect-intrusion');
    if (step1) {
        step1.classList.add('investigating');
        window.demoApp.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'WARNING',
            message: '🔍 检测到来自外部IP的异常登录尝试: 192.168.1.100'
        });
    }
    
    await sleep(2000);
    if (step1) {
        step1.classList.remove('investigating');
        step1.classList.add('completed');
    }
    
    // 动画2: 分析攻击源
    const step2 = document.getElementById('step-analyze-source');
    if (step2) {
        step2.classList.add('investigating');
        window.demoApp.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'INFO',
            message: '🌐 正在分析攻击源IP地址地理位置和威胁情报...'
        });
    }
    
    await sleep(2000);
    if (step2) {
        step2.classList.remove('investigating');
        step2.classList.add('threat-detected');
        window.demoApp.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'ERROR',
            message: '⚠️  攻击源确认: 已知恶意IP，风险等级: 高'
        });
    }
    
    // 图节点动画
    const targetNode = document.getElementById('node-target');
    if (targetNode) {
        targetNode.classList.add('compromised');
    }
}

async function demonstrateLateralMovement() {
    console.log('↔️  演示横向移动阶段...');
    
    // 隐藏阶段1，显示阶段2
    const stage1 = document.getElementById('stage-intrusion');
    const stage2 = document.getElementById('stage-lateral');
    
    if (stage1) stage1.classList.remove('active');
    if (stage2) stage2.classList.add('active');
    
    // 动画1: 追踪横向移动
    await sleep(1000);
    const step1 = document.getElementById('step-track-movement');
    if (step1) {
        step1.classList.add('investigating');
        window.demoApp.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'WARNING',
            message: '🔄 检测到横向移动活动: 192.168.1.100 → 192.168.1.50'
        });
    }
    
    // 节点动画序列
    const nodes = ['node-entry', 'node-server1', 'node-server2', 'node-database'];
    for (let i = 0; i < nodes.length; i++) {
        await sleep(1500);
        const node = document.getElementById(nodes[i]);
        if (node) {
            if (i === 0) {
                node.classList.add('compromised');
            } else if (i === nodes.length - 1) {
                node.classList.add('investigating');
                window.demoApp.addLogEntry({
                    timestamp: new Date().toISOString(),
                    level: 'ERROR',
                    message: `🔍 发现攻击路径: 步骤${i+1} - 正在尝试访问关键数据库`
                });
            } else {
                node.classList.add('investigating');
                window.demoApp.addLogEntry({
                    timestamp: new Date().toISOString(),
                    level: 'WARNING',
                    message: `🔍 攻击路径: 步骤${i+1} - ${nodes[i].replace('node-', '')}被入侵`
                });
            }
        }
    }
    
    await sleep(2000);
    if (step1) {
        step1.classList.remove('investigating');
        step1.classList.add('completed');
    }
    
    // 动画2: 识别受影响资产
    const step2 = document.getElementById('step-identify-assets');
    if (step2) {
        step2.classList.add('investigating');
        window.demoApp.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'INFO',
            message: '📊 正在评估受影响的系统资产和数据范围...'
        });
    }
    
    await sleep(2500);
    if (step2) {
        step2.classList.remove('investigating');
        step2.classList.add('threat-detected');
        window.demoApp.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'ERROR',
            message: '🚨 影响评估完成: 4个系统受影响，包含敏感数据库'
        });
    }
}

async function demonstrateThreatAnalysis() {
    console.log('🧠 演示威胁研判阶段...');
    
    // 隐藏阶段2，显示阶段3
    const stage2 = document.getElementById('stage-lateral');
    const stage3 = document.getElementById('stage-analysis');
    
    if (stage2) stage2.classList.remove('active');
    if (stage3) stage3.classList.add('active');
    
    // 动画1: 关联攻击事件 (已完成状态)
    const step1 = document.getElementById('step-correlate-events');
    if (step1) {
        window.demoApp.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'SUCCESS',
            message: '🔗 攻击事件关联分析完成: 检测到完整攻击链条'
        });
    }
    
    await sleep(1000);
    
    // 动画2: 评估安全影响
    const step2 = document.getElementById('step-assess-impact');
    if (step2) {
        step2.classList.add('investigating');
        window.demoApp.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'INFO',
            message: '📈 正在进行安全影响评估和风险计算...'
        });
    }
    
    await sleep(3000);
    if (step2) {
        step2.classList.remove('investigating');
        step2.classList.add('threat-detected');
        window.demoApp.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'ERROR',
            message: '⚠️  风险评估结果: 综合风险等级 - 严重 (9.2/10)'
        });
    }
    
    await sleep(1000);
    
    // 动画3: 生成威胁情报报告
    const step3 = document.getElementById('step-generate-report');
    if (step3) {
        step3.classList.add('investigating');
        window.demoApp.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'INFO',
            message: '📄 正在生成威胁情报报告和处置建议...'
        });
    }
    
    await sleep(2500);
    if (step3) {
        step3.classList.remove('investigating');
        step3.classList.add('completed');
        window.demoApp.addLogEntry({
            timestamp: new Date().toISOString(),
            level: 'SUCCESS',
            message: '✅ 威胁分析报告生成完成，建议立即采取安全措施'
        });
    }
    
    // 最终总结
    await sleep(1000);
    window.demoApp.addLogEntry({
        timestamp: new Date().toISOString(),
        level: 'INFO',
        message: '🎯 攻击路径分析完成: 入侵→横向移动→数据访问 (共4个步骤)'
    });
}

function openNeo4jView() {
    // 获取当前主机地址
    const currentHost = window.location.hostname;
    const neo4jUrl = `http://${currentHost}:7474`;
    
    // 显示认证信息提示
    const authInfo = `
        <div class="alert alert-info">
            <h6><i class="fas fa-key me-2"></i>Neo4j 认证信息</h6>
            <div class="row">
                <div class="col-md-6">
                    <p class="mb-2"><strong>用户名:</strong> <code>neo4j</code></p>
                    <p class="mb-2"><strong>密码:</strong> <code>security123</code></p>
                    <p class="mb-2"><strong>数据库:</strong> <code>neo4j</code></p>
                </div>
                <div class="col-md-6">
                    <p class="mb-2"><strong>连接类型:</strong> Username/Password</p>
                    <p class="mb-2"><strong>服务器:</strong> bolt://localhost:7687</p>
                </div>
            </div>
        </div>
        
        <div class="alert alert-success">
            <h6><i class="fas fa-chart-line me-2"></i>预装攻击演示数据</h6>
            <p class="mb-2">系统已预装完整的攻击路径演示数据，包括:</p>
            <ul class="mb-2">
                <li>🎯 外部攻击者 → Web网关 → Web服务器 → 应用服务器</li>
                <li>🔍 6个系统节点 + 2个用户账户 + 完整攻击关系</li>
                <li>⚡ 真实的攻击技术和检测状态</li>
            </ul>
        </div>
        
        <div class="alert alert-warning">
            <h6><i class="fas fa-terminal me-2"></i>推荐查询命令</h6>
            <div class="mb-2">
                <strong>1. 查看所有节点:</strong>
                <div class="input-group input-group-sm mb-1">
                    <input type="text" class="form-control font-monospace" value="MATCH (n) RETURN n LIMIT 25" readonly onclick="this.select()">
                    <button class="btn btn-outline-secondary" onclick="copyToClipboard('MATCH (n) RETURN n LIMIT 25')">
                        <i class="fas fa-copy"></i>
                    </button>
                </div>
            </div>
            <div class="mb-2">
                <strong>2. 查看完整攻击路径:</strong>
                <div class="input-group input-group-sm mb-1">
                    <input type="text" class="form-control font-monospace" value="MATCH path = (a:Attacker)-[*]->(s:System) RETURN path" readonly onclick="this.select()">
                    <button class="btn btn-outline-secondary" onclick="copyToClipboard('MATCH path = (a:Attacker)-[*]->(s:System) RETURN path')">
                        <i class="fas fa-copy"></i>
                    </button>
                </div>
            </div>
            <div class="mb-2">
                <strong>3. 查看已入侵系统:</strong>
                <div class="input-group input-group-sm">
                    <input type="text" class="form-control font-monospace" value="MATCH (s:System {compromised: true}) RETURN s" readonly onclick="this.select()">
                    <button class="btn btn-outline-secondary" onclick="copyToClipboard('MATCH (s:System {compromised: true}) RETURN s')">
                        <i class="fas fa-copy"></i>
                    </button>
                </div>
            </div>
        </div>
    `;
    
    // 创建模态框显示认证信息
    const modal = document.createElement('div');
    modal.className = 'modal fade';
    modal.innerHTML = `
        <div class="modal-dialog">
            <div class="modal-content bg-dark text-light">
                <div class="modal-header">
                    <h5 class="modal-title">
                        <i class="fas fa-project-diagram me-2"></i>Neo4j 图形界面
                    </h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    ${authInfo}
                    <div class="mt-3">
                        <button class="btn btn-primary" onclick="window.open('${neo4jUrl}', '_blank'); bootstrap.Modal.getInstance(this.closest('.modal')).hide();">
                            <i class="fas fa-external-link-alt me-2"></i>打开 Neo4j 浏览器
                        </button>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">关闭</button>
                    <small class="text-muted me-auto">
                        <i class="fas fa-lightbulb me-1"></i>
                        点击查询命令右侧的复制按钮可快速复制到剪贴板
                    </small>
                </div>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
    const bootstrapModal = new bootstrap.Modal(modal);
    bootstrapModal.show();
    
    // 模态框关闭后移除
    modal.addEventListener('hidden.bs.modal', () => {
        modal.remove();
    });
    
    window.demoApp.addLogEntry({
        timestamp: new Date().toISOString(),
        level: 'INFO',
        message: '🔗 Neo4j认证信息已显示，请使用 neo4j/security123 登录'
    });
}

// 更新演示数据与API响应关联
function updateDemonstrationWithApiData(apiData) {
    console.log('🔄 使用API数据更新演示:', apiData);
    
    try {
        // 提取实体信息
        const entities = apiData.entities || [];
        const riskScore = apiData.risk_score || 0;
        const eventId = apiData.event_id || 'unknown';
        
        // 更新实体显示
        if (entities.length > 0) {
            let entityDetails = [];
            let maxRisk = 0;
            let threatLevel = '低';
            
            entities.forEach(entity => {
                const entityType = entity.entity_type || 'unknown';
                const entityId = entity.entity_id || 'N/A';
                const risk = entity.risk_score || 0;
                
                entityDetails.push(`${entityType}:${entityId}(${risk.toFixed(1)})`);
                
                if (risk > maxRisk) {
                    maxRisk = risk;
                }
            });
            
            // 确定威胁等级
            if (maxRisk > 70) {
                threatLevel = '严重';
            } else if (maxRisk > 50) {
                threatLevel = '高';
            } else if (maxRisk > 30) {
                threatLevel = '中';
            }
            
            // 动态更新日志内容
            setTimeout(() => {
                window.demoApp.addLogEntry({
                    timestamp: new Date().toISOString(),
                    level: 'INFO',
                    message: `🎯 实时分析结果: 检测到 ${entities.length} 个实体 - ${entityDetails.join(', ')}`
                });
            }, 2000);
            
            setTimeout(() => {
                window.demoApp.addLogEntry({
                    timestamp: new Date().toISOString(),
                    level: maxRisk > 50 ? 'ERROR' : 'WARNING',
                    message: `⚡ API风险评分: ${maxRisk.toFixed(2)}/100 (威胁等级: ${threatLevel})`
                });
            }, 4000);
            
            setTimeout(() => {
                window.demoApp.addLogEntry({
                    timestamp: new Date().toISOString(),
                    level: 'SUCCESS',
                    message: `📊 事件ID: ${eventId} - 分析完成，数据已写入Neo4j图数据库`
                });
            }, 6000);
        }
        
        // 更新图节点风险显示
        setTimeout(() => {
            const nodes = document.querySelectorAll('.graph-node');
            nodes.forEach((node, index) => {
                if (entities[index]) {
                    const risk = entities[index].risk_score || 0;
                    if (risk > 50) {
                        node.classList.add('compromised');
                        node.title = `风险评分: ${risk.toFixed(1)}`;
                    } else if (risk > 20) {
                        node.classList.add('investigating');
                        node.title = `风险评分: ${risk.toFixed(1)}`;
                    }
                }
            });
        }, 3000);
        
    } catch (error) {
        console.error('更新演示数据失败:', error);
    }
}

// 复制到剪贴板功能
function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(() => {
        // 显示复制成功提示
        window.demoApp.showNotification(`已复制查询命令: ${text.substring(0, 30)}...`, 'success', 2000);
    }).catch(err => {
        // 降级方案
        const textArea = document.createElement('textarea');
        textArea.value = text;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        window.demoApp.showNotification('已复制到剪贴板', 'success', 2000);
    });
}

// 工具函数
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Event Creator Functions
let selectedEventType = null;
let currentYamlData = null;

function showEventCreator() {
    const modal = new bootstrap.Modal(document.getElementById('eventCreatorModal'));
    modal.show();
}

function selectEventType(element, eventType) {
    // Remove selection from all cards
    document.querySelectorAll('.event-type-card').forEach(card => {
        card.classList.remove('selected');
    });
    
    // Select current card
    element.classList.add('selected');
    selectedEventType = eventType;
    
    // Update form fields based on event type
    updateFormFieldsForEventType(eventType);
}

function updateFormFieldsForEventType(eventType) {
    const eventTypeConfigs = {
        brute_force: {
            src_ip: '203.0.113.100',
            dst_ip: '10.0.0.1',
            username: 'admin',
            severity: 'high'
        },
        malware: {
            src_ip: '192.168.1.100',
            dst_ip: '10.0.0.50',
            username: 'user',
            severity: 'critical'
        },
        lateral_movement: {
            src_ip: '192.168.1.100',
            dst_ip: '192.168.1.50',
            username: 'service_account',
            severity: 'high'
        },
        data_exfiltration: {
            src_ip: '192.168.1.100',
            dst_ip: '198.51.100.1',
            username: 'admin',
            severity: 'critical'
        },
        privilege_escalation: {
            src_ip: '10.0.0.100',
            dst_ip: '10.0.0.1',
            username: 'user',
            severity: 'high'
        },
        command_injection: {
            src_ip: '203.0.113.50',
            dst_ip: '10.0.0.10',
            username: 'web_user',
            severity: 'critical'
        }
    };
    
    const config = eventTypeConfigs[eventType];
    if (config) {
        document.getElementById('quick-src-ip').value = config.src_ip;
        document.getElementById('quick-dst-ip').value = config.dst_ip;
        document.getElementById('quick-username').value = config.username;
        document.getElementById('quick-severity').value = config.severity;
    }
}

async function createQuickEvent() {
    if (!selectedEventType) {
        window.demoApp.showNotification('请先选择事件类型', 'warning');
        return;
    }
    
    const srcIp = document.getElementById('quick-src-ip').value;
    const dstIp = document.getElementById('quick-dst-ip').value;
    const username = document.getElementById('quick-username').value;
    const severity = document.getElementById('quick-severity').value;
    
    const eventData = {
        event_type: `security_${selectedEventType}`,
        log_data: {
            src_ip: srcIp,
            dst_ip: dstIp,
            username: username,
            action: getActionForEventType(selectedEventType),
            timestamp: new Date().toISOString(),
            severity: severity,
            event_category: selectedEventType
        }
    };
    
    try {
        // Close modal
        const modal = bootstrap.Modal.getInstance(document.getElementById('eventCreatorModal'));
        if (modal) modal.hide();
        
        // Execute the event with animation
        await executeEventWithAnimation(eventData);
        
    } catch (error) {
        console.error('创建快速事件失败:', error);
        window.demoApp.showNotification('创建事件失败', 'error');
    }
}

function getActionForEventType(eventType) {
    const actions = {
        brute_force: 'failed_login_attempt',
        malware: 'malware_detected',
        lateral_movement: 'lateral_connection',
        data_exfiltration: 'large_data_transfer',
        privilege_escalation: 'privilege_escalation_attempt',
        command_injection: 'command_execution'
    };
    return actions[eventType] || 'security_event';
}

// YAML Import Functions
function handleYamlDragOver(event) {
    event.preventDefault();
    document.getElementById('yaml-upload-area').classList.add('dragover');
}

function handleYamlDrop(event) {
    event.preventDefault();
    const area = document.getElementById('yaml-upload-area');
    area.classList.remove('dragover');
    
    const files = event.dataTransfer.files;
    if (files.length > 0) {
        processYamlFile(files[0]);
    }
}

function handleYamlFileSelect(event) {
    const files = event.target.files;
    if (files.length > 0) {
        processYamlFile(files[0]);
    }
}

async function processYamlFile(file) {
    try {
        const text = await file.text();
        // Simple YAML parsing (basic implementation)
        currentYamlData = parseSimpleYaml(text);
        
        // Show preview
        const preview = document.getElementById('yaml-preview');
        preview.innerHTML = `<pre>${escapeHtml(text)}</pre>`;
        
        // Enable import button
        document.getElementById('yaml-import-btn').disabled = false;
        
        // Update upload area
        const area = document.getElementById('yaml-upload-area');
        area.classList.add('success');
        area.innerHTML = `
            <i class="fas fa-check-circle fa-2x mb-2 text-success"></i>
            <p class="mb-1">文件已加载: ${file.name}</p>
            <p class="text-muted small">找到 ${currentYamlData ? currentYamlData.length || 1 : 1} 个事件</p>
        `;
        
        window.demoApp.showNotification(`YAML文件加载成功: ${file.name}`, 'success');
        
    } catch (error) {
        console.error('YAML文件处理失败:', error);
        window.demoApp.showNotification('YAML文件格式错误', 'error');
    }
}

function parseSimpleYaml(yamlText) {
    // Basic YAML parsing - convert to JSON-like structure
    // This is a simplified implementation
    try {
        // If it starts with events:, parse as array
        if (yamlText.includes('events:')) {
            const lines = yamlText.split('\n');
            const events = [];
            let currentEvent = null;
            let inLogData = false;
            
            for (const line of lines) {
                const trimmed = line.trim();
                if (trimmed.startsWith('- event_type:')) {
                    if (currentEvent) events.push(currentEvent);
                    currentEvent = {
                        event_type: trimmed.split(':')[1].trim().replace(/['"]/g, ''),
                        log_data: {}
                    };
                    inLogData = false;
                } else if (trimmed === 'log_data:') {
                    inLogData = true;
                } else if (inLogData && trimmed.includes(':')) {
                    const [key, value] = trimmed.split(':');
                    currentEvent.log_data[key.trim()] = value.trim().replace(/['"]/g, '');
                } else if (!inLogData && trimmed.includes(':') && currentEvent) {
                    const [key, value] = trimmed.split(':');
                    if (key.trim() !== 'log_data') {
                        currentEvent[key.trim()] = value.trim().replace(/['"]/g, '');
                    }
                }
            }
            if (currentEvent) events.push(currentEvent);
            return events;
        } else {
            // Single event
            const event = { log_data: {} };
            const lines = yamlText.split('\n');
            let inLogData = false;
            
            for (const line of lines) {
                const trimmed = line.trim();
                if (trimmed === 'log_data:') {
                    inLogData = true;
                } else if (inLogData && trimmed.includes(':')) {
                    const [key, value] = trimmed.split(':');
                    event.log_data[key.trim()] = value.trim().replace(/['"]/g, '');
                } else if (!inLogData && trimmed.includes(':')) {
                    const [key, value] = trimmed.split(':');
                    event[key.trim()] = value.trim().replace(/['"]/g, '');
                }
            }
            return [event];
        }
    } catch (error) {
        console.error('YAML解析失败:', error);
        return null;
    }
}

function loadYamlTemplate(templateType) {
    const templates = {
        attack_scenario: `events:
  - event_type: security_lateral_movement
    log_data:
      src_ip: "192.168.1.100"
      dst_ip: "192.168.1.50"
      username: "attacker"
      action: "ssh_login"
      timestamp: "2024-01-15T10:30:00Z"
      severity: "high"
      
  - event_type: security_privilege_escalation
    log_data:
      src_ip: "192.168.1.50"
      dst_ip: "192.168.1.200"
      username: "root"
      action: "privilege_escalation"
      timestamp: "2024-01-15T10:35:00Z"
      severity: "critical"`,
      
        malware_detection: `event_type: security_malware
log_data:
  src_ip: "203.0.113.50"
  dst_ip: "10.0.0.100"
  username: "user"
  action: "malware_detected"
  file_path: "/tmp/suspicious.exe"
  malware_family: "trojan"
  timestamp: "2024-01-15T10:00:00Z"
  severity: "critical"`,
  
        data_breach: `event_type: security_data_exfiltration
log_data:
  src_ip: "10.0.0.100"
  dst_ip: "198.51.100.1"
  username: "admin"
  action: "large_data_transfer"
  data_size: "500MB"
  file_types: "database,documents"
  timestamp: "2024-01-15T14:30:00Z"
  severity: "critical"`
    };
    
    const template = templates[templateType];
    if (template) {
        currentYamlData = parseSimpleYaml(template);
        document.getElementById('yaml-preview').innerHTML = `<pre>${escapeHtml(template)}</pre>`;
        document.getElementById('yaml-import-btn').disabled = false;
        
        // Update upload area
        const area = document.getElementById('yaml-upload-area');
        area.classList.add('success');
        area.innerHTML = `
            <i class="fas fa-file-alt fa-2x mb-2 text-info"></i>
            <p class="mb-1">已加载模板: ${templateType}</p>
            <p class="text-muted small">找到 ${currentYamlData.length} 个事件</p>
        `;
    }
}

async function importYamlEvents() {
    if (!currentYamlData) {
        window.demoApp.showNotification('请先导入YAML文件', 'warning');
        return;
    }
    
    try {
        // Close modal
        const modal = bootstrap.Modal.getInstance(document.getElementById('eventCreatorModal'));
        if (modal) modal.hide();
        
        window.demoApp.showNotification(`开始导入 ${currentYamlData.length} 个事件`, 'info');
        
        for (let i = 0; i < currentYamlData.length; i++) {
            const event = currentYamlData[i];
            await executeEventWithAnimation(event);
            
            if (i < currentYamlData.length - 1) {
                await sleep(2000); // 2秒间隔
            }
        }
        
        window.demoApp.showNotification('YAML事件导入完成', 'success');
        
    } catch (error) {
        console.error('YAML事件导入失败:', error);
        window.demoApp.showNotification('事件导入失败', 'error');
    }
}

function downloadYamlTemplate() {
    const template = `# 安全事件YAML模板
# 支持单个事件或事件数组

# 单个事件示例:
event_type: security_demo
log_data:
  src_ip: "192.168.1.100"
  dst_ip: "10.0.0.1"
  username: "admin"
  action: "login_attempt"
  timestamp: "2024-01-15T10:00:00Z"
  severity: "medium"

# 多个事件示例:
# events:
#   - event_type: security_brute_force
#     log_data:
#       src_ip: "203.0.113.100"
#       dst_ip: "10.0.0.1"
#       username: "admin"
#       action: "failed_login"
#       timestamp: "2024-01-15T10:00:00Z"
#       severity: "high"
#   
#   - event_type: security_malware
#     log_data:
#       src_ip: "192.168.1.100"
#       dst_ip: "10.0.0.50"
#       username: "user"
#       action: "malware_detected"
#       timestamp: "2024-01-15T10:05:00Z"
#       severity: "critical"`;

    const blob = new Blob([template], { type: 'text/yaml' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'security_event_template.yaml';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    window.demoApp.showNotification('模板已下载', 'success');
}

// JSON Editor Functions
let jsonEditorValidation = null;

function formatJsonEditor() {
    const editor = document.getElementById('json-editor');
    try {
        const json = JSON.parse(editor.value);
        editor.value = JSON.stringify(json, null, 2);
        window.demoApp.showNotification('JSON已格式化', 'success');
        validateJsonEditor();
    } catch (error) {
        window.demoApp.showNotification('JSON格式错误', 'error');
    }
}

function validateJsonEditor() {
    const editor = document.getElementById('json-editor');
    const validationResult = document.getElementById('json-validation-result');
    
    try {
        if (!editor.value.trim()) {
            validationResult.innerHTML = '<div class="text-muted">输入JSON数据开始验证</div>';
            validationResult.className = 'validation-result';
            return;
        }
        
        const json = JSON.parse(editor.value);
        
        // Basic validation
        const errors = [];
        const warnings = [];
        
        if (!json.event_type) {
            errors.push('缺少 event_type 字段');
        }
        
        if (!json.log_data) {
            errors.push('缺少 log_data 字段');
        } else {
            if (!json.log_data.timestamp) {
                warnings.push('建议添加 timestamp 字段');
            }
            if (!json.log_data.severity) {
                warnings.push('建议添加 severity 字段');
            }
        }
        
        let resultHtml = '';
        if (errors.length === 0) {
            resultHtml = '<div class="text-success"><i class="fas fa-check-circle me-2"></i>JSON格式正确</div>';
            validationResult.className = 'validation-result success';
            document.getElementById('json-execute-btn').disabled = false;
        } else {
            resultHtml = '<div class="text-danger"><i class="fas fa-times-circle me-2"></i>验证失败</div>';
            validationResult.className = 'validation-result error';
            document.getElementById('json-execute-btn').disabled = true;
        }
        
        if (errors.length > 0) {
            resultHtml += '<div class="mt-2"><strong>错误:</strong></div>';
            errors.forEach(error => {
                resultHtml += `<div class="text-danger small">• ${error}</div>`;
            });
        }
        
        if (warnings.length > 0) {
            resultHtml += '<div class="mt-2"><strong>建议:</strong></div>';
            warnings.forEach(warning => {
                resultHtml += `<div class="text-warning small">• ${warning}</div>`;
            });
        }
        
        // Show structure info
        resultHtml += '<div class="mt-3"><strong>结构信息:</strong></div>';
        resultHtml += `<div class="small text-muted">事件类型: ${json.event_type || 'N/A'}</div>`;
        if (json.log_data) {
            resultHtml += `<div class="small text-muted">字段数量: ${Object.keys(json.log_data).length}</div>`;
        }
        
        validationResult.innerHTML = resultHtml;
        
    } catch (error) {
        validationResult.innerHTML = `
            <div class="text-danger">
                <i class="fas fa-times-circle me-2"></i>JSON语法错误
            </div>
            <div class="small text-danger mt-2">${error.message}</div>
        `;
        validationResult.className = 'validation-result error';
        document.getElementById('json-execute-btn').disabled = true;
    }
}

function clearJsonEditor() {
    document.getElementById('json-editor').value = '';
    validateJsonEditor();
}

function loadJsonTemplate(templateType) {
    const templates = {
        basic_alert: {
            event_type: "security_alert",
            log_data: {
                src_ip: "192.168.1.100",
                dst_ip: "10.0.0.1",
                username: "user",
                action: "login_attempt",
                timestamp: new Date().toISOString(),
                severity: "medium"
            }
        },
        network_event: {
            event_type: "security_network",
            log_data: {
                src_ip: "203.0.113.50",
                dst_ip: "10.0.0.100",
                src_port: 45123,
                dst_port: 22,
                protocol: "TCP",
                action: "connection_attempt",
                bytes_transferred: 1024,
                timestamp: new Date().toISOString(),
                severity: "medium"
            }
        },
        file_event: {
            event_type: "security_file",
            log_data: {
                username: "admin",
                file_path: "/etc/passwd",
                action: "file_read",
                file_size: 2048,
                permissions: "644",
                timestamp: new Date().toISOString(),
                severity: "high"
            }
        },
        process_event: {
            event_type: "security_process",
            log_data: {
                username: "user",
                process_name: "suspicious.exe",
                process_id: 1234,
                parent_process: "cmd.exe",
                command_line: "suspicious.exe --payload",
                action: "process_created",
                timestamp: new Date().toISOString(),
                severity: "critical"
            }
        }
    };
    
    const template = templates[templateType];
    if (template) {
        document.getElementById('json-editor').value = JSON.stringify(template, null, 2);
        validateJsonEditor();
    }
}

async function executeJsonEvent() {
    const editor = document.getElementById('json-editor');
    try {
        const eventData = JSON.parse(editor.value);
        
        // Close modal
        const modal = bootstrap.Modal.getInstance(document.getElementById('eventCreatorModal'));
        if (modal) modal.hide();
        
        await executeEventWithAnimation(eventData);
        
    } catch (error) {
        console.error('执行JSON事件失败:', error);
        window.demoApp.showNotification('JSON事件执行失败', 'error');
    }
}

function previewJsonEvent() {
    const editor = document.getElementById('json-editor');
    try {
        const eventData = JSON.parse(editor.value);
        
        let previewHtml = `
            <div class="alert alert-info">
                <h6><i class="fas fa-eye me-2"></i>事件预览</h6>
                <p><strong>类型:</strong> ${eventData.event_type}</p>
        `;
        
        if (eventData.log_data) {
            previewHtml += '<p><strong>关键信息:</strong></p><ul>';
            Object.keys(eventData.log_data).forEach(key => {
                previewHtml += `<li>${key}: ${eventData.log_data[key]}</li>`;
            });
            previewHtml += '</ul>';
        }
        
        previewHtml += '</div>';
        
        // Show in validation area
        document.getElementById('json-validation-result').innerHTML = previewHtml;
        
    } catch (error) {
        window.demoApp.showNotification('预览失败: JSON格式错误', 'error');
    }
}

// Common Functions
async function executeEventWithAnimation(eventData) {
    try {
        // Show attack demonstration
        showAttackDemonstration();
        
        // Start demonstration animation
        const demonstrationPromise = startAttackDemonstration();
        
        const host = window.location.hostname;
        const response = await fetch(`http://${host}:8000/api/v1/analyze/event`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(eventData)
        });
        
        const data = await response.json();
        
        if (response.ok && data.success) {
            window.demoApp.showNotification('事件分析完成', 'success');
            
            // Parse and display results
            if (data.data) {
                const eventResult = data.data;
                const entities = eventResult.entities || [];
                const riskScore = eventResult.risk_score || 0;
                
                // Update demonstration with real data
                updateDemonstrationWithApiData(eventResult);
            }
            
            await demonstrationPromise;
        } else {
            window.demoApp.showNotification(`事件分析失败: ${data.message || '未知错误'}`, 'error');
            hideAttackDemonstration();
        }
        
    } catch (error) {
        console.error('事件执行失败:', error);
        window.demoApp.showNotification('事件执行失败', 'error');
        hideAttackDemonstration();
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Event listeners for JSON editor
document.addEventListener('DOMContentLoaded', function() {
    // Real-time JSON validation
    const jsonEditor = document.getElementById('json-editor');
    if (jsonEditor) {
        let validationTimeout;
        jsonEditor.addEventListener('input', function() {
            clearTimeout(validationTimeout);
            validationTimeout = setTimeout(validateJsonEditor, 500);
        });
    }
});

// Replace the old createTestEvent function
async function createTestEvent() {
    // This is now handled by showEventCreator
    showEventCreator();
}

// Security Policy Management Functions
let currentPolicyData = null;
let selectedPoliciesForExport = new Set();

function showSecurityPolicies() {
    loadPoliciesList();
    const modal = new bootstrap.Modal(document.getElementById('securityPoliciesModal'));
    modal.show();
}

async function loadPoliciesList() {
    try {
        const response = await fetch('/api/policies');
        const data = await response.json();
        
        const container = document.getElementById('policies-list');
        if (!container) return;
        
        let html = '';
        if (data.policies && data.policies.length > 0) {
            data.policies.forEach(policy => {
                const statusBadge = policy.enabled ? 
                    '<span class="badge bg-success">已启用</span>' : 
                    '<span class="badge bg-secondary">已禁用</span>';
                
                const severityColor = {
                    'low': 'text-success',
                    'medium': 'text-warning',
                    'high': 'text-danger',
                    'critical': 'text-danger'
                }[policy.severity] || 'text-muted';
                
                html += `
                    <div class="policy-card mb-3" data-policy-id="${policy.policy_id}">
                        <div class="card bg-secondary">
                            <div class="card-body">
                                <div class="row align-items-center">
                                    <div class="col-md-8">
                                        <h6 class="card-title mb-1">
                                            <i class="fas fa-shield-alt me-2"></i>${policy.name}
                                            ${statusBadge}
                                        </h6>
                                        <p class="card-text text-muted mb-2">${policy.description}</p>
                                        <small class="text-muted">
                                            <i class="fas fa-clock me-1"></i>创建: ${new Date(policy.created_at).toLocaleDateString()}
                                            <i class="fas fa-exclamation-triangle ms-3 me-1 ${severityColor}"></i>严重度: ${policy.severity}
                                            <i class="fas fa-list-ul ms-3 me-1"></i>规则数: ${policy.rules?.length || 0}
                                        </small>
                                    </div>
                                    <div class="col-md-4 text-end">
                                        <div class="btn-group" role="group">
                                            <button class="btn btn-outline-info btn-sm" onclick="editPolicy('${policy.policy_id}')" title="编辑">
                                                <i class="fas fa-edit"></i>
                                            </button>
                                            <button class="btn btn-outline-success btn-sm" onclick="testPolicy('${policy.policy_id}')" title="测试">
                                                <i class="fas fa-play"></i>
                                            </button>
                                            <button class="btn btn-outline-${policy.enabled ? 'warning' : 'success'} btn-sm" 
                                                    onclick="togglePolicy('${policy.policy_id}', ${!policy.enabled})" 
                                                    title="${policy.enabled ? '禁用' : '启用'}">
                                                <i class="fas fa-${policy.enabled ? 'pause' : 'play'}"></i>
                                            </button>
                                            <button class="btn btn-outline-danger btn-sm" onclick="deletePolicy('${policy.policy_id}')" title="删除">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                `;
            });
        } else {
            html = `
                <div class="text-center text-muted p-4">
                    <i class="fas fa-shield-alt fa-3x mb-3 opacity-50"></i>
                    <h5>暂无安全策略</h5>
                    <p>点击"新建策略"或"导入策略"开始创建您的第一个安全策略</p>
                    <button class="btn btn-primary" onclick="createNewPolicy()">
                        <i class="fas fa-plus me-1"></i>新建策略
                    </button>
                </div>
            `;
        }
        
        container.innerHTML = html;
        
    } catch (error) {
        console.error('加载策略列表失败:', error);
        window.demoApp.showNotification('加载策略列表失败', 'error');
    }
}

function searchPolicies() {
    const searchTerm = document.getElementById('policy-search').value.toLowerCase();
    const policyCards = document.querySelectorAll('.policy-card');
    
    policyCards.forEach(card => {
        const title = card.querySelector('.card-title').textContent.toLowerCase();
        const description = card.querySelector('.card-text').textContent.toLowerCase();
        
        if (title.includes(searchTerm) || description.includes(searchTerm)) {
            card.style.display = 'block';
        } else {
            card.style.display = 'none';
        }
    });
}

function createNewPolicy() {
    // Switch to editor tab with template
    document.getElementById('policy-editor-tab').click();
    
    const defaultPolicy = {
        policy_id: `policy_${Date.now()}`,
        name: "新建安全策略",
        description: "请在此输入策略描述",
        severity: "medium",
        enabled: true,
        rules: [
            {
                rule_id: "rule_1",
                name: "规则1",
                condition: "event_type == 'security_alert'",
                action: "alert",
                description: "检测安全告警事件"
            }
        ],
        metadata: {
            created_by: "admin",
            created_at: new Date().toISOString(),
            version: "1.0"
        }
    };
    
    document.getElementById('policy-editor').value = JSON.stringify(defaultPolicy, null, 2);
    validatePolicyEditor();
}

// Policy Import Functions
function handlePolicyDragOver(event) {
    event.preventDefault();
    document.getElementById('policy-upload-area').classList.add('dragover');
}

function handlePolicyDrop(event) {
    event.preventDefault();
    const area = document.getElementById('policy-upload-area');
    area.classList.remove('dragover');
    
    const files = event.dataTransfer.files;
    if (files.length > 0) {
        processPolicyFile(files[0]);
    }
}

function handlePolicyFileSelect(event) {
    const files = event.target.files;
    if (files.length > 0) {
        processPolicyFile(files[0]);
    }
}

async function processPolicyFile(file) {
    try {
        const text = await file.text();
        const fileExtension = file.name.split('.').pop().toLowerCase();
        
        let policyData;
        if (fileExtension === 'json') {
            policyData = JSON.parse(text);
        } else if (fileExtension === 'yaml' || fileExtension === 'yml') {
            policyData = parseSimpleYaml(text);
        } else if (fileExtension === 'xml') {
            window.demoApp.showNotification('XML格式暂不支持，请使用JSON或YAML格式', 'warning');
            return;
        }
        
        currentPolicyData = policyData;
        
        // Show preview
        const preview = document.getElementById('policy-preview');
        preview.innerHTML = `<pre>${escapeHtml(JSON.stringify(policyData, null, 2))}</pre>`;
        
        // Enable import button
        document.getElementById('policy-import-btn').disabled = false;
        
        // Update upload area
        const area = document.getElementById('policy-upload-area');
        area.classList.add('success');
        area.innerHTML = `
            <i class="fas fa-check-circle fa-2x mb-2 text-success"></i>
            <p class="mb-1">文件已加载: ${file.name}</p>
            <p class="text-muted small">找到 ${Array.isArray(policyData) ? policyData.length : 1} 个策略</p>
        `;
        
        window.demoApp.showNotification(`策略文件加载成功: ${file.name}`, 'success');
        
    } catch (error) {
        console.error('策略文件处理失败:', error);
        window.demoApp.showNotification('策略文件格式错误', 'error');
    }
}

function loadPolicyTemplate(templateType) {
    const templates = {
        brute_force_detection: {
            policy_id: "brute_force_detection",
            name: "暴力破解检测策略",
            description: "检测短时间内多次登录失败的暴力破解行为",
            severity: "high",
            enabled: true,
            rules: [
                {
                    rule_id: "brute_force_rule_1",
                    name: "多次登录失败检测",
                    condition: "event_type == 'security_brute_force' AND log_data.action == 'failed_login'",
                    action: "alert",
                    threshold: {
                        count: 5,
                        time_window: "5m"
                    },
                    description: "5分钟内超过5次登录失败触发告警"
                },
                {
                    rule_id: "brute_force_rule_2",
                    name: "异常源IP检测",
                    condition: "log_data.src_ip NOT IN known_ips",
                    action: "block",
                    description: "来自未知IP的登录尝试"
                }
            ],
            metadata: {
                created_by: "system",
                created_at: new Date().toISOString(),
                version: "1.0",
                tags: ["authentication", "brute_force", "security"]
            }
        },
        lateral_movement_detection: {
            policy_id: "lateral_movement_detection",
            name: "横向移动检测策略",
            description: "检测网络内部的横向移动和权限提升行为",
            severity: "critical",
            enabled: true,
            rules: [
                {
                    rule_id: "lateral_rule_1",
                    name: "异常内网连接检测",
                    condition: "event_type == 'security_lateral_movement' AND log_data.src_ip LIKE '192.168.*'",
                    action: "alert",
                    description: "检测内网间的异常连接行为"
                },
                {
                    rule_id: "lateral_rule_2",
                    name: "权限提升检测",
                    condition: "log_data.action == 'privilege_escalation'",
                    action: "alert",
                    severity: "critical",
                    description: "检测权限提升尝试"
                }
            ],
            metadata: {
                created_by: "system", 
                created_at: new Date().toISOString(),
                version: "1.0",
                tags: ["lateral_movement", "privilege_escalation", "internal"]
            }
        },
        data_exfiltration_detection: {
            policy_id: "data_exfiltration_detection",
            name: "数据泄露检测策略",
            description: "检测大量数据外传和敏感文件访问行为",
            severity: "critical",
            enabled: true,
            rules: [
                {
                    rule_id: "exfiltration_rule_1",
                    name: "大数据量传输检测",
                    condition: "event_type == 'security_data_exfiltration' AND log_data.data_size > '100MB'",
                    action: "alert",
                    description: "检测大于100MB的数据传输"
                },
                {
                    rule_id: "exfiltration_rule_2", 
                    name: "敏感文件访问检测",
                    condition: "log_data.file_types CONTAINS 'database' OR log_data.file_types CONTAINS 'financial'",
                    action: "block",
                    description: "检测对敏感数据类型的访问"
                }
            ],
            metadata: {
                created_by: "system",
                created_at: new Date().toISOString(),
                version: "1.0",
                tags: ["data_exfiltration", "sensitive_data", "dLP"]
            }
        }
    };
    
    const template = templates[templateType];
    if (template) {
        currentPolicyData = template;
        document.getElementById('policy-preview').innerHTML = `<pre>${escapeHtml(JSON.stringify(template, null, 2))}</pre>`;
        document.getElementById('policy-import-btn').disabled = false;
        
        // Update upload area
        const area = document.getElementById('policy-upload-area');
        area.classList.add('success');
        area.innerHTML = `
            <i class="fas fa-file-alt fa-2x mb-2 text-info"></i>
            <p class="mb-1">已加载模板: ${template.name}</p>
            <p class="text-muted small">包含 ${template.rules.length} 个检测规则</p>
        `;
    }
}

async function importPolicies() {
    if (!currentPolicyData) {
        window.demoApp.showNotification('请先选择策略文件', 'warning');
        return;
    }
    
    try {
        const response = await fetch('/api/policies/import', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ policies: Array.isArray(currentPolicyData) ? currentPolicyData : [currentPolicyData] })
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.demoApp.showNotification(`成功导入 ${data.imported_count} 个策略`, 'success');
            
            // Refresh policy list
            loadPoliciesList();
            
            // Switch back to list tab
            document.getElementById('policy-list-tab').click();
            
            // Reset import area
            resetPolicyImportArea();
        } else {
            window.demoApp.showNotification(`导入失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('导入策略失败:', error);
        window.demoApp.showNotification('导入策略失败', 'error');
    }
}

function resetPolicyImportArea() {
    const area = document.getElementById('policy-upload-area');
    area.classList.remove('success');
    area.innerHTML = `
        <i class="fas fa-cloud-upload-alt fa-2x mb-2"></i>
        <p class="mb-1">拖放策略文件到此处</p>
        <p class="text-muted small">支持 JSON、YAML、XML 格式</p>
    `;
    
    document.getElementById('policy-preview').innerHTML = `
        <div class="text-center text-muted p-4">
            选择或导入策略文件进行预览
        </div>
    `;
    
    document.getElementById('policy-import-btn').disabled = true;
    currentPolicyData = null;
}

function downloadPolicyTemplate() {
    const template = {
        policy_id: "example_policy",
        name: "示例安全策略",
        description: "这是一个示例安全策略，展示了策略的基本结构",
        severity: "medium",
        enabled: true,
        rules: [
            {
                rule_id: "example_rule_1",
                name: "示例规则1",
                condition: "event_type == 'security_alert' AND log_data.severity == 'high'",
                action: "alert",
                description: "检测高严重度安全告警"
            }
        ],
        metadata: {
            created_by: "admin",
            created_at: new Date().toISOString(),
            version: "1.0",
            tags: ["example", "template"]
        }
    };
    
    const blob = new Blob([JSON.stringify(template, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'security_policy_template.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    window.demoApp.showNotification('策略模板已下载', 'success');
}

// Policy Editor Functions
function switchPolicyFormat() {
    const format = document.getElementById('policy-format-select').value;
    const editor = document.getElementById('policy-editor');
    
    try {
        if (!editor.value.trim()) return;
        
        const currentData = JSON.parse(editor.value);
        
        if (format === 'yaml') {
            // Simple JSON to YAML conversion
            editor.value = jsonToSimpleYaml(currentData);
        } else {
            // Format as JSON
            editor.value = JSON.stringify(currentData, null, 2);
        }
        
        validatePolicyEditor();
        
    } catch (error) {
        window.demoApp.showNotification('格式转换失败，请检查当前内容', 'error');
    }
}

function jsonToSimpleYaml(obj, indent = 0) {
    let yaml = '';
    const spaces = '  '.repeat(indent);
    
    for (const [key, value] of Object.entries(obj)) {
        if (typeof value === 'object' && value !== null) {
            if (Array.isArray(value)) {
                yaml += `${spaces}${key}:\n`;
                value.forEach(item => {
                    if (typeof item === 'object') {
                        yaml += `${spaces}- \n`;
                        yaml += jsonToSimpleYaml(item, indent + 1).replace(/^/gm, '  ');
                    } else {
                        yaml += `${spaces}- ${item}\n`;
                    }
                });
            } else {
                yaml += `${spaces}${key}:\n`;
                yaml += jsonToSimpleYaml(value, indent + 1);
            }
        } else {
            yaml += `${spaces}${key}: ${value}\n`;
        }
    }
    
    return yaml;
}

function formatPolicyEditor() {
    const editor = document.getElementById('policy-editor');
    const format = document.getElementById('policy-format-select').value;
    
    try {
        if (format === 'json') {
            const json = JSON.parse(editor.value);
            editor.value = JSON.stringify(json, null, 2);
        }
        window.demoApp.showNotification('策略已格式化', 'success');
        validatePolicyEditor();
    } catch (error) {
        window.demoApp.showNotification('格式化失败，请检查语法', 'error');
    }
}

function validatePolicyEditor() {
    const editor = document.getElementById('policy-editor');
    const validationResult = document.getElementById('policy-validation-result');
    const format = document.getElementById('policy-format-select').value;
    
    try {
        if (!editor.value.trim()) {
            validationResult.innerHTML = '<div class="text-muted">输入策略数据开始验证</div>';
            validationResult.className = 'validation-result';
            document.getElementById('policy-save-btn').disabled = true;
            return;
        }
        
        let policyData;
        if (format === 'json') {
            policyData = JSON.parse(editor.value);
        } else {
            policyData = parseSimpleYaml(editor.value);
        }
        
        // Policy validation
        const errors = [];
        const warnings = [];
        
        if (!policyData.policy_id) {
            errors.push('缺少 policy_id 字段');
        }
        if (!policyData.name) {
            errors.push('缺少 name 字段');
        }
        if (!policyData.rules || !Array.isArray(policyData.rules) || policyData.rules.length === 0) {
            errors.push('缺少 rules 字段或规则为空');
        }
        
        if (!policyData.description) {
            warnings.push('建议添加 description 字段');
        }
        if (!policyData.severity) {
            warnings.push('建议添加 severity 字段');
        }
        
        // Validate rules
        if (policyData.rules && Array.isArray(policyData.rules)) {
            policyData.rules.forEach((rule, index) => {
                if (!rule.rule_id) {
                    errors.push(`规则 ${index + 1} 缺少 rule_id 字段`);
                }
                if (!rule.condition) {
                    errors.push(`规则 ${index + 1} 缺少 condition 字段`);
                }
                if (!rule.action) {
                    warnings.push(`规则 ${index + 1} 建议添加 action 字段`);
                }
            });
        }
        
        let resultHtml = '';
        if (errors.length === 0) {
            resultHtml = '<div class="text-success"><i class="fas fa-check-circle me-2"></i>策略格式正确</div>';
            validationResult.className = 'validation-result success';
            document.getElementById('policy-save-btn').disabled = false;
        } else {
            resultHtml = '<div class="text-danger"><i class="fas fa-times-circle me-2"></i>验证失败</div>';
            validationResult.className = 'validation-result error';
            document.getElementById('policy-save-btn').disabled = true;
        }
        
        if (errors.length > 0) {
            resultHtml += '<div class="mt-2"><strong>错误:</strong></div>';
            errors.forEach(error => {
                resultHtml += `<div class="text-danger small">• ${error}</div>`;
            });
        }
        
        if (warnings.length > 0) {
            resultHtml += '<div class="mt-2"><strong>建议:</strong></div>';
            warnings.forEach(warning => {
                resultHtml += `<div class="text-warning small">• ${warning}</div>`;
            });
        }
        
        // Show structure info
        resultHtml += '<div class="mt-3"><strong>策略信息:</strong></div>';
        resultHtml += `<div class="small text-muted">策略名称: ${policyData.name || 'N/A'}</div>`;
        resultHtml += `<div class="small text-muted">规则数量: ${policyData.rules ? policyData.rules.length : 0}</div>`;
        resultHtml += `<div class="small text-muted">严重度: ${policyData.severity || 'N/A'}</div>`;
        
        validationResult.innerHTML = resultHtml;
        
    } catch (error) {
        validationResult.innerHTML = `
            <div class="text-danger">
                <i class="fas fa-times-circle me-2"></i>策略语法错误
            </div>
            <div class="small text-danger mt-2">${error.message}</div>
        `;
        validationResult.className = 'validation-result error';
        document.getElementById('policy-save-btn').disabled = true;
    }
}

function clearPolicyEditor() {
    document.getElementById('policy-editor').value = '';
    validatePolicyEditor();
}

async function savePolicyEditor() {
    const editor = document.getElementById('policy-editor');
    const format = document.getElementById('policy-format-select').value;
    
    try {
        let policyData;
        if (format === 'json') {
            policyData = JSON.parse(editor.value);
        } else {
            policyData = parseSimpleYaml(editor.value);
        }
        
        const response = await fetch('/api/policies', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(policyData)
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.demoApp.showNotification('策略保存成功', 'success');
            loadPoliciesList();
            // Switch back to list tab
            document.getElementById('policy-list-tab').click();
        } else {
            window.demoApp.showNotification(`保存失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('保存策略失败:', error);
        window.demoApp.showNotification('保存策略失败', 'error');
    }
}

function previewPolicyEditor() {
    const editor = document.getElementById('policy-editor');
    const format = document.getElementById('policy-format-select').value;
    
    try {
        let policyData;
        if (format === 'json') {
            policyData = JSON.parse(editor.value);
        } else {
            policyData = parseSimpleYaml(editor.value);
        }
        
        let previewHtml = `
            <div class="alert alert-info">
                <h6><i class="fas fa-eye me-2"></i>策略预览</h6>
                <p><strong>名称:</strong> ${policyData.name}</p>
                <p><strong>描述:</strong> ${policyData.description || 'N/A'}</p>
                <p><strong>严重度:</strong> ${policyData.severity || 'N/A'}</p>
                <p><strong>状态:</strong> ${policyData.enabled ? '启用' : '禁用'}</p>
        `;
        
        if (policyData.rules && policyData.rules.length > 0) {
            previewHtml += '<p><strong>规则:</strong></p><ul>';
            policyData.rules.forEach(rule => {
                previewHtml += `<li>${rule.name || rule.rule_id}: ${rule.description || rule.condition}</li>`;
            });
            previewHtml += '</ul>';
        }
        
        previewHtml += '</div>';
        
        // Show in validation area
        document.getElementById('policy-validation-result').innerHTML = previewHtml;
        
    } catch (error) {
        window.demoApp.showNotification('预览失败: 策略格式错误', 'error');
    }
}

async function testPolicyEditor() {
    const editor = document.getElementById('policy-editor');
    const format = document.getElementById('policy-format-select').value;
    
    try {
        let policyData;
        if (format === 'json') {
            policyData = JSON.parse(editor.value);
        } else {
            policyData = parseSimpleYaml(editor.value);
        }
        
        // Create a test event that should match this policy
        const testEvent = {
            event_type: "security_alert",
            log_data: {
                src_ip: "192.168.1.100",
                dst_ip: "10.0.0.1", 
                username: "test_user",
                action: "test_action",
                severity: "high",
                timestamp: new Date().toISOString(),
                policy_test: true
            }
        };
        
        window.demoApp.showNotification('正在测试策略...', 'info');
        
        // Send test event with policy context
        const response = await fetch('/api/policies/test', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                policy: policyData,
                test_event: testEvent
            })
        });
        
        const data = await response.json();
        
        if (data.success) {
            let resultMessage = `策略测试完成: ${data.matches_count} 个规则匹配`;
            if (data.triggered_rules && data.triggered_rules.length > 0) {
                resultMessage += `\n触发规则: ${data.triggered_rules.join(', ')}`;
            }
            window.demoApp.showNotification(resultMessage, 'success');
        } else {
            window.demoApp.showNotification(`测试失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('测试策略失败:', error);
        window.demoApp.showNotification('测试策略失败', 'error');
    }
}

// Policy Management Functions
async function editPolicy(policyId) {
    try {
        const response = await fetch(`/api/policies/${policyId}`);
        const data = await response.json();
        
        if (data.success && data.policy) {
            // Switch to editor tab
            document.getElementById('policy-editor-tab').click();
            
            // Load policy into editor
            document.getElementById('policy-editor').value = JSON.stringify(data.policy, null, 2);
            validatePolicyEditor();
            
            window.demoApp.showNotification(`已加载策略: ${data.policy.name}`, 'info');
        } else {
            window.demoApp.showNotification('加载策略失败', 'error');
        }
        
    } catch (error) {
        console.error('编辑策略失败:', error);
        window.demoApp.showNotification('编辑策略失败', 'error');
    }
}

async function testPolicy(policyId) {
    try {
        const response = await fetch(`/api/policies/${policyId}/test`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.demoApp.showNotification(`策略测试完成: ${data.message}`, 'success');
        } else {
            window.demoApp.showNotification(`测试失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('测试策略失败:', error);
        window.demoApp.showNotification('测试策略失败', 'error');
    }
}

async function togglePolicy(policyId, enabled) {
    try {
        const response = await fetch(`/api/policies/${policyId}/toggle`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ enabled: enabled })
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.demoApp.showNotification(`策略已${enabled ? '启用' : '禁用'}`, 'success');
            loadPoliciesList();
        } else {
            window.demoApp.showNotification(`操作失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('切换策略状态失败:', error);
        window.demoApp.showNotification('操作失败', 'error');
    }
}

async function deletePolicy(policyId) {
    if (!confirm('确定要删除这个策略吗？此操作不可恢复。')) return;
    
    try {
        const response = await fetch(`/api/policies/${policyId}`, {
            method: 'DELETE'
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.demoApp.showNotification('策略已删除', 'success');
            loadPoliciesList();
        } else {
            window.demoApp.showNotification(`删除失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('删除策略失败:', error);
        window.demoApp.showNotification('删除策略失败', 'error');
    }
}

// Policy Export Functions
async function loadPoliciesForExport() {
    try {
        const response = await fetch('/api/policies');
        const data = await response.json();
        
        const container = document.getElementById('export-policy-list');
        if (!container) return;
        
        let html = '';
        if (data.policies && data.policies.length > 0) {
            data.policies.forEach(policy => {
                const statusBadge = policy.enabled ? 
                    '<span class="badge bg-success ms-2">已启用</span>' : 
                    '<span class="badge bg-secondary ms-2">已禁用</span>';
                
                html += `
                    <div class="form-check mb-2">
                        <input class="form-check-input" type="checkbox" value="${policy.policy_id}" id="export-${policy.policy_id}">
                        <label class="form-check-label" for="export-${policy.policy_id}">
                            ${policy.name} ${statusBadge}
                            <div class="text-muted small">${policy.description}</div>
                        </label>
                    </div>
                `;
            });
        } else {
            html = '<div class="text-muted">暂无可导出的策略</div>';
        }
        
        container.innerHTML = html;
        
    } catch (error) {
        console.error('加载导出列表失败:', error);
        window.demoApp.showNotification('加载导出列表失败', 'error');
    }
}

function selectAllPoliciesForExport() {
    const checkboxes = document.querySelectorAll('#export-policy-list input[type="checkbox"]');
    checkboxes.forEach(checkbox => {
        checkbox.checked = true;
    });
}

function clearExportSelection() {
    const checkboxes = document.querySelectorAll('#export-policy-list input[type="checkbox"]');
    checkboxes.forEach(checkbox => {
        checkbox.checked = false;
    });
}

async function exportSelectedPolicies() {
    const checkboxes = document.querySelectorAll('#export-policy-list input[type="checkbox"]:checked');
    const selectedPolicyIds = Array.from(checkboxes).map(cb => cb.value);
    
    if (selectedPolicyIds.length === 0) {
        window.demoApp.showNotification('请选择要导出的策略', 'warning');
        return;
    }
    
    const format = document.getElementById('export-format').value;
    const filename = document.getElementById('export-filename').value || 'security_policies';
    const includeDisabled = document.getElementById('export-include-disabled').checked;
    const includeMetadata = document.getElementById('export-include-metadata').checked;
    
    try {
        const response = await fetch('/api/policies/export', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                policy_ids: selectedPolicyIds,
                format: format,
                include_disabled: includeDisabled,
                include_metadata: includeMetadata
            })
        });
        
        if (response.ok) {
            const blob = await response.blob();
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `${filename}.${format}`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            
            window.demoApp.showNotification(`成功导出 ${selectedPolicyIds.length} 个策略`, 'success');
        } else {
            const data = await response.json();
            window.demoApp.showNotification(`导出失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('导出策略失败:', error);
        window.demoApp.showNotification('导出策略失败', 'error');
    }
}

// Event listener for policy tabs
document.addEventListener('DOMContentLoaded', function() {
    // Load export list when export tab is shown
    const exportTab = document.getElementById('policy-export-tab');
    if (exportTab) {
        exportTab.addEventListener('shown.bs.tab', function() {
            loadPoliciesForExport();
        });
    }
    
    // Real-time policy editor validation
    const policyEditor = document.getElementById('policy-editor');
    if (policyEditor) {
        let validationTimeout;
        policyEditor.addEventListener('input', function() {
            clearTimeout(validationTimeout);
            validationTimeout = setTimeout(validatePolicyEditor, 500);
        });
    }
});

// 页面加载完成后初始化应用
document.addEventListener('DOMContentLoaded', function() {
    console.log('📱 页面加载完成，初始化演示应用...');
    window.demoApp = new DemoApp();
});