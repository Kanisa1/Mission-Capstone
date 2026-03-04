// Dashboard Management
class Dashboard {
    constructor() {
        this.charts = {};
        this.refreshTimer = null;
    }

    // Initialize dashboard
    async init() {
        try {
            this.showLoading(true);
            
            // Check API health
            const isHealthy = await apiService.checkHealth();
            if (!isHealthy) {
                console.warn('API is not responding, showing cached data');
            }

            // Load all data
            await this.loadDashboardData();
            
            // Check for pending user approvals
            await this.checkPendingApprovals();
            
            // Initialize charts
            this.initCharts();
            
            // Set up auto-refresh
            this.setupAutoRefresh();
            
            this.showLoading(false);
        } catch (error) {
            console.error('Failed to initialize dashboard:', error);
            this.showLoading(false);
            this.showError('Failed to load dashboard data');
        }
    }

    // Load all dashboard data
    async loadDashboardData() {
        const stats = await apiService.getStatistics();
        const metrics = await apiService.getModelMetrics();
        const heatmap = await apiService.getHeatmapData();

        // Update top bar stats
        this.updateTopBarStats(stats);

        // Update metrics cards
        this.updateMetricsCards(stats);

        // Update activity feed
        this.updateActivityFeed(stats.recentActivity);

        // Update site performance
        this.updateSitePerformance(stats.sitePerformance);

        // Update model performance
        this.updateModelPerformance(metrics);

        // Update heatmap
        this.updateHeatmap(heatmap);

        // Store data for charts
        this.stats = stats;
        this.metrics = metrics;
    }

    // Check for pending user approvals
    async checkPendingApprovals() {
        try {
            const response = await fetch(`${API_BASE_URL}/api/admin/pending-users`);
            if (!response.ok) {
                console.warn('Could not fetch pending users');
                return;
            }
            
            const data = await response.json();
            const pendingCount = data.users ? data.users.length : 0;
            
            // Update alert banner
            const alertBanner = document.getElementById('pendingApprovalsAlert');
            const countElement = document.getElementById('pendingUsersCount');
            const notifBadge = document.querySelector('.notification-badge');
            
            if (pendingCount > 0) {
                if (alertBanner) alertBanner.style.display = 'flex';
                if (countElement) countElement.textContent = pendingCount;
                if (notifBadge) {
                    notifBadge.textContent = pendingCount;
                    notifBadge.style.display = 'block';
                }
            } else {
                if (alertBanner) alertBanner.style.display = 'none';
                if (notifBadge) notifBadge.style.display = 'none';
            }
        } catch (error) {
            console.error('Error checking pending approvals:', error);
        }
    }

    // Update top bar statistics
    updateTopBarStats(stats) {
        document.getElementById('totalScans').textContent = stats.totalScans;
        document.getElementById('verifiedCount').textContent = stats.verifiedCount;
        document.getElementById('accuracyRate').textContent = `${stats.accuracy}%`;
    }

    // Update metrics cards
    updateMetricsCards(stats) {
        document.getElementById('goldCount').textContent = stats.mineralCounts.gold;
        document.getElementById('chalcoCount').textContent = stats.mineralCounts.chalcopyrite;
        document.getElementById('hematiteCount').textContent = stats.mineralCounts.hematite;
    }

    // Update activity feed
    updateActivityFeed(activities) {
        const activityList = document.querySelector('.activity-list');
        
        if (activities.length === 0) {
            activityList.innerHTML = `
                <div style="text-align: center; padding: 2rem; color: #9CA3AF;">
                    <i class="fas fa-inbox" style="font-size: 48px; margin-bottom: 1rem;"></i>
                    <p>No recent activity</p>
                </div>
            `;
            return;
        }

        activityList.innerHTML = activities.map(activity => {
            const icon = activity.verified 
                ? '<i class="fas fa-check-circle"></i>'
                : '<i class="fas fa-clock"></i>';
            
            const iconClass = activity.verified ? 'verified' : '';
            const statusText = activity.verified ? 'Verified' : 'Pending';
            
            return `
                <div class="activity-item">
                    <div class="activity-icon ${iconClass}">
                        ${icon}
                    </div>
                    <div class="activity-content">
                        <div class="activity-title">${activity.mineral} detected</div>
                        <div class="activity-meta">
                            <span>${activity.site}</span>
                            <span class="activity-time">${apiService.formatTimestamp(activity.timestamp)}</span>
                        </div>
                    </div>
                </div>
            `;
        }).join('');
    }

    // Update site performance cards
    updateSitePerformance(sitePerformance) {
        const sitesContainer = document.querySelector('.sites-grid');
        
        sitesContainer.innerHTML = SITES.map(site => {
            const perf = sitePerformance[site] || { total: 0, verified: 0, accuracy: 0 };
            const displayName = site.replace(/_/g, ' ');
            
            return `
                <div class="site-item">
                    <div class="site-header">
                        <span class="site-name">${displayName}</span>
                        <span class="site-badge active">Active</span>
                    </div>
                    <div class="site-stats">
                        <div class="site-stat">
                            <span class="label">Total Scans</span>
                            <span class="value">${perf.total}</span>
                        </div>
                        <div class="site-stat">
                            <span class="label">Verified</span>
                            <span class="value success">${perf.verified}</span>
                        </div>
                        <div class="site-stat">
                            <span class="label">Accuracy</span>
                            <span class="value success">${perf.accuracy}%</span>
                        </div>
                    </div>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: ${perf.accuracy}%"></div>
                    </div>
                </div>
            `;
        }).join('');
    }

    // Update model performance
    updateModelPerformance(metrics) {
        // Update stats
        const statsContainer = document.querySelector('.performance-stats');
        statsContainer.innerHTML = `
            <div class="perf-stat">
                <span class="label">Precision</span>
                <span class="value">${metrics.precision}%</span>
            </div>
            <div class="perf-stat">
                <span class="label">Recall</span>
                <span class="value">${metrics.recall}%</span>
            </div>
            <div class="perf-stat">
                <span class="label">F1-Score</span>
                <span class="value">${metrics.f1Score}%</span>
            </div>
        `;
    }

    // Update heatmap
    updateHeatmap(heatmapData) {
        const heatmapContainer = document.querySelector('.heatmap-grid');
        
        // Calculate totals for each site
        const siteTotals = SITES.map(site => {
            const total = MINERALS.reduce((sum, mineral) => {
                return sum + (heatmapData[`${site}_${mineral}`] || 0);
            }, 0);
            return { site, total };
        }).sort((a, b) => b.total - a.total);

        heatmapContainer.innerHTML = siteTotals.map((item, index) => {
            const displayName = item.site.replace(/_/g, ' ');
            const intensity = index === 0 ? 'high' : index === 1 ? 'medium' : 'low';
            
            return `
                <div class="heatmap-item ${intensity}">
                    <span class="heatmap-label">${displayName}</span>
                    <span class="heatmap-value">${item.total}</span>
                </div>
            `;
        }).join('');
    }

    // Initialize Chart.js charts
    initCharts() {
        this.initTrendsChart();
        this.initAccuracyGauge();
    }

    // Initialize trends chart
    initTrendsChart() {
        const ctx = document.getElementById('trendsChart');
        if (!ctx) return;

        if (this.charts.trends) {
            this.charts.trends.destroy();
        }

        const trends = this.stats.trends;

        this.charts.trends = new Chart(ctx, {
            type: 'line',
            data: {
                labels: trends.labels,
                datasets: [
                    {
                        label: 'Gold',
                        data: trends.gold,
                        borderColor: '#F59E0B',
                        backgroundColor: 'rgba(245, 158, 11, 0.1)',
                        tension: 0.4,
                        fill: true
                    },
                    {
                        label: 'Chalcopyrite',
                        data: trends.chalcopyrite,
                        borderColor: '#EA580C',
                        backgroundColor: 'rgba(234, 88, 12, 0.1)',
                        tension: 0.4,
                        fill: true
                    },
                    {
                        label: 'Hematite',
                        data: trends.hematite,
                        borderColor: '#DC2626',
                        backgroundColor: 'rgba(220, 38, 38, 0.1)',
                        tension: 0.4,
                        fill: true
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: true,
                        position: 'top',
                        align: 'end'
                    },
                    tooltip: {
                        mode: 'index',
                        intersect: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            precision: 0
                        },
                        grid: {
                            color: 'rgba(0, 0, 0, 0.05)'
                        }
                    },
                    x: {
                        grid: {
                            display: false
                        }
                    }
                },
                interaction: {
                    mode: 'nearest',
                    axis: 'x',
                    intersect: false
                }
            }
        });
    }

    // Initialize accuracy gauge chart
    initAccuracyGauge() {
        const ctx = document.getElementById('accuracyGauge');
        if (!ctx) return;

        if (this.charts.gauge) {
            this.charts.gauge.destroy();
        }

        const accuracy = this.metrics.accuracy;

        this.charts.gauge = new Chart(ctx, {
            type: 'doughnut',
            data: {
                datasets: [{
                    data: [accuracy, 100 - accuracy],
                    backgroundColor: ['#2C6E91', '#E5E7EB'],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '75%',
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        enabled: false
                    }
                }
            }
        });

        // Update gauge label
        document.querySelector('.gauge-value').textContent = `${accuracy}%`;
    }

    // Set up auto-refresh
    setupAutoRefresh() {
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
        }

        this.refreshTimer = setInterval(async () => {
            console.log('Auto-refreshing dashboard data...');
            await this.loadDashboardData();
            this.updateCharts();
        }, REFRESH_INTERVAL);
    }

    // Update charts with new data
    updateCharts() {
        if (this.charts.trends) {
            const trends = this.stats.trends;
            this.charts.trends.data.labels = trends.labels;
            this.charts.trends.data.datasets[0].data = trends.gold;
            this.charts.trends.data.datasets[1].data = trends.chalcopyrite;
            this.charts.trends.data.datasets[2].data = trends.hematite;
            this.charts.trends.update();
        }

        if (this.charts.gauge) {
            const accuracy = this.metrics.accuracy;
            this.charts.gauge.data.datasets[0].data = [accuracy, 100 - accuracy];
            this.charts.gauge.update();
            document.querySelector('.gauge-value').textContent = `${accuracy}%`;
        }
    }

    // Show/hide loading overlay
    showLoading(show) {
        const overlay = document.getElementById('loadingOverlay');
        if (overlay) {
            overlay.style.display = show ? 'flex' : 'none';
        }
    }

    // Show error message
    showError(message) {
        alert(message); // Replace with a better notification system
    }

    // Clean up
    destroy() {
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
        }

        Object.values(this.charts).forEach(chart => {
            if (chart) chart.destroy();
        });
    }
}

// Initialize dashboard when DOM is ready
let dashboard;

document.addEventListener('DOMContentLoaded', () => {
    dashboard = new Dashboard();
    dashboard.init();
});

// Clean up on page unload
window.addEventListener('beforeunload', () => {
    if (dashboard) {
        dashboard.destroy();
    }
});
