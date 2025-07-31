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
        
        const servicesList = [
            { key: 'elasticsearch', name: 'Elasticsearch', icon: 'fas fa-search' },
            { key: 'kibana', name: 'Kibana', icon: 'fas fa-chart-bar' },
            { key: 'neo4j', name: 'Neo4j', icon: 'fas fa-project-diagram' },
            { key: 'mysql', name: 'MySQL', icon: 'fas fa-database' },
            { key: 'redis', name: 'Redis', icon: 'fas fa-memory' },
            { key: 'kafka', name: 'Kafka', icon: 'fas fa-stream' }
        ];
        
        let html = '';
        servicesList.forEach(service => {
            const serviceData = services[service.key];
            const status = serviceData ? serviceData.status : 'unknown';
            const isRunning = status && status.toLowerCase().includes('up');
            
            const statusClass = isRunning ? 'status-running' : 'status-stopped';
            const statusText = isRunning ? '运行中' : '已停止';
            const statusIcon = isRunning ? 'fas fa-check-circle text-success' : 'fas fa-times-circle text-danger';
            
            html += `
                <div class="col-md-4 col-sm-6">
                    <div class="service-status ${statusClass}">
                        <div class="service-icon">
                            <i class="${service.icon}"></i>
                        </div>
                        <div class="service-name">${service.name}</div>
                        <div class="service-state">
                            <i class="${statusIcon} me-1"></i>
                            ${statusText}
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
        const response = await fetch('/api/demo/test-event', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.demoApp.showNotification('测试事件创建成功', 'success');
        } else {
            window.demoApp.showNotification(`创建失败: ${data.message}`, 'error');
        }
        
    } catch (error) {
        console.error('创建测试事件失败:', error);
        window.demoApp.showNotification('创建测试事件失败', 'error');
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
            html += `
                <div class="scenario-card" onclick="runDemoScenario('${scenario.id}')">
                    <div class="scenario-title">${scenario.name}</div>
                    <div class="scenario-description">${scenario.description}</div>
                    <div class="scenario-meta">
                        <span><i class="fas fa-calendar me-1"></i>事件数: ${scenario.events}</span>
                        <span><i class="fas fa-clock me-1"></i>持续时间: ${scenario.duration}</span>
                    </div>
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

// 页面加载完成后初始化应用
document.addEventListener('DOMContentLoaded', function() {
    console.log('📱 页面加载完成，初始化演示应用...');
    window.demoApp = new DemoApp();
});