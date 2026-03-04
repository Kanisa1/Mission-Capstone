// Analytics Page Management
class AnalyticsPage {
    constructor() {
        this.charts = {};
        this.metrics = null;
        this.refreshTimer = null;
    }

    // Initialize page
    async init() {
        this.showLoading(true);
        
        try {
            await this.refreshData();
            this.startRealtimeUpdates();
        } catch (error) {
            console.error('Failed to initialize analytics page:', error);
            this.showError('Failed to load analytics data');
        } finally {
            this.showLoading(false);
        }
    }

    async refreshData() {
        await this.loadMetrics();
        this.updateStats();
        this.initCharts();
        this.updateMetricsTable();
    }

    startRealtimeUpdates() {
        const seconds = Number(this.metrics?.refresh_seconds) || 15;
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
        }
        this.refreshTimer = setInterval(async () => {
            try {
                await this.refreshData();
            } catch (error) {
                console.error('Real-time analytics refresh failed:', error);
            }
        }, Math.max(5, seconds) * 1000);
    }

    // Load metrics from API
    async loadMetrics() {
        try {
            const response = await fetch(`${API_BASE_URL}/analytics/realtime`);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const payload = await response.json();
            this.metrics = this.normalizeMetrics(payload);
        } catch (error) {
            console.error('Error loading metrics:', error);
            this.metrics = {
                status: 'no_data',
                accuracy: 0,
                macro_precision: 0,
                macro_recall: 0,
                macro_f1: 0,
                total_samples: 0,
                samples_with_predictions: 0,
                per_class_metrics: {},
                modality_usage: {},
                confidence_distribution: {
                    labels: ['0-20%', '20-40%', '40-60%', '60-80%', '80-100%'],
                    bins: [0, 0, 0, 0, 0]
                }
            };
        }
    }

    normalizeMetrics(payload) {
        const overall = payload?.overall_metrics || {};
        return {
            status: payload?.status || 'success',
            last_updated: payload?.last_updated || null,
            refresh_seconds: payload?.refresh_seconds || 15,
            accuracy: payload?.accuracy ?? overall.accuracy ?? 0,
            macro_precision: payload?.macro_precision ?? overall.macro_precision ?? 0,
            macro_recall: payload?.macro_recall ?? overall.macro_recall ?? 0,
            macro_f1: payload?.macro_f1 ?? overall.macro_f1_score ?? 0,
            total_samples: payload?.total_samples ?? 0,
            samples_with_predictions: payload?.samples_with_predictions ?? 0,
            per_class_metrics: payload?.per_class_metrics || {},
            modality_usage: payload?.modality_usage || {},
            confidence_distribution: payload?.confidence_distribution || {
                labels: ['0-20%', '20-40%', '40-60%', '60-80%', '80-100%'],
                bins: [0, 0, 0, 0, 0]
            }
        };
    }

    getCssVar(name, fallback) {
        const value = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
        return value || fallback;
    }

    destroyChart(name) {
        if (this.charts[name]) {
            this.charts[name].destroy();
            this.charts[name] = null;
        }
    }

    // Update stats cards
    updateStats() {
        const accuracy = this.metrics.accuracy || 0;
        const precision = this.metrics.macro_precision || 0;
        const recall = this.metrics.macro_recall || 0;
        const f1 = this.metrics.macro_f1 || 0;

        document.getElementById('overallAccuracy').textContent = `${Math.round(accuracy * 100)}%`;
        document.getElementById('overallPrecision').textContent = `${Math.round(precision * 100)}%`;
        document.getElementById('overallRecall').textContent = `${Math.round(recall * 100)}%`;
        document.getElementById('overallF1').textContent = `${Math.round(f1 * 100)}%`;
        document.getElementById('totalSamples').textContent = this.metrics.samples_with_predictions || 0;

        const lastUpdatedEl = document.getElementById('analyticsLastUpdated');
        if (lastUpdatedEl) {
            const ts = this.metrics.last_updated ? new Date(this.metrics.last_updated) : null;
            lastUpdatedEl.textContent = ts && !Number.isNaN(ts.getTime())
                ? ts.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })
                : '--';
        }
    }

    // Initialize charts
    initCharts() {
        this.initConfusionMatrix();
        this.initPerClassChart();
        this.initConfidenceChart();
        this.initModalityChart();
    }

    // Initialize confusion matrix visualization (as bar chart)
    initConfusionMatrix() {
        const ctx = document.getElementById('confusionMatrix');
        if (!ctx) return;

        this.destroyChart('confusion');

        const classMetrics = this.metrics.per_class_metrics || {};
        const minerals = Object.keys(classMetrics);

        // Create data for stacked bar chart
        const truePositives = minerals.map(m => classMetrics[m].true_positive || 0);
        const falsePositives = minerals.map(m => classMetrics[m].false_positive || 0);
        const falseNegatives = minerals.map(m => classMetrics[m].false_negative || 0);

        this.charts.confusion = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: minerals.map(m => m.charAt(0).toUpperCase() + m.slice(1)),
                datasets: [
                    {
                        label: 'True Positives',
                        data: truePositives,
                        backgroundColor: this.getCssVar('--success', '#2E8B6E')
                    },
                    {
                        label: 'False Positives',
                        data: falsePositives,
                        backgroundColor: this.getCssVar('--warning', '#F59E0B')
                    },
                    {
                        label: 'False Negatives',
                        data: falseNegatives,
                        backgroundColor: this.getCssVar('--error', '#DC2626')
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom'
                    },
                    title: {
                        display: false
                    }
                },
                scales: {
                    x: {
                        stacked: false
                    },
                    y: {
                        stacked: false,
                        beginAtZero: true,
                        ticks: {
                            precision: 0
                        }
                    }
                }
            }
        });
    }

    // Initialize per-class metrics chart
    initPerClassChart() {
        const ctx = document.getElementById('perClassChart');
        if (!ctx) return;

        this.destroyChart('perClass');

        const classMetrics = this.metrics.per_class_metrics || {};
        const minerals = Object.keys(classMetrics);

        const precision = minerals.map(m => (classMetrics[m].precision || 0) * 100);
        const recall = minerals.map(m => (classMetrics[m].recall || 0) * 100);
        const f1 = minerals.map(m => (classMetrics[m].f1_score || 0) * 100);

        this.charts.perClass = new Chart(ctx, {
            type: 'radar',
            data: {
                labels: minerals.map(m => m.charAt(0).toUpperCase() + m.slice(1)),
                datasets: [
                    {
                        label: 'Precision',
                        data: precision,
                        borderColor: this.getCssVar('--primary-light', '#2C6E91'),
                        backgroundColor: 'rgba(44, 110, 145, 0.10)',
                        pointBackgroundColor: this.getCssVar('--primary-light', '#2C6E91')
                    },
                    {
                        label: 'Recall',
                        data: recall,
                        borderColor: this.getCssVar('--success', '#2E8B6E'),
                        backgroundColor: 'rgba(46, 139, 110, 0.10)',
                        pointBackgroundColor: this.getCssVar('--success', '#2E8B6E')
                    },
                    {
                        label: 'F1-Score',
                        data: f1,
                        borderColor: this.getCssVar('--accent-gold', '#BFDCD0'),
                        backgroundColor: 'rgba(191, 220, 208, 0.18)',
                        pointBackgroundColor: this.getCssVar('--accent-gold', '#BFDCD0')
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                },
                scales: {
                    r: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            stepSize: 20
                        }
                    }
                }
            }
        });
    }

    // Initialize confidence distribution chart
    initConfidenceChart() {
        const ctx = document.getElementById('confidenceChart');
        if (!ctx) return;

        this.destroyChart('confidence');

        const distribution = this.metrics.confidence_distribution || {};
        const labels = distribution.labels || ['0-20%', '20-40%', '40-60%', '60-80%', '80-100%'];
        const bins = distribution.bins || [0, 0, 0, 0, 0];

        this.charts.confidence = new Chart(ctx, {
            type: 'bar',
            data: {
                labels,
                datasets: [{
                    label: 'Number of Predictions',
                    data: bins,
                    backgroundColor: [
                        this.getCssVar('--error', '#DC2626'),
                        this.getCssVar('--warning', '#F59E0B'),
                        this.getCssVar('--warning', '#F59E0B'),
                        this.getCssVar('--primary-light', '#2C6E91'),
                        this.getCssVar('--success', '#2E8B6E')
                    ]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            precision: 0
                        }
                    }
                }
            }
        });
    }

    // Initialize modality usage chart
    initModalityChart() {
        const ctx = document.getElementById('modalityChart');
        if (!ctx) return;

        this.destroyChart('modality');

        const modalityUsage = this.metrics.modality_usage || {};
        const labels = Object.keys(modalityUsage);
        const data = Object.values(modalityUsage);

        if (labels.length === 0) {
            labels.push('No Data');
            data.push(0);
        }

        this.charts.modality = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: [
                        this.getCssVar('--primary-light', '#2C6E91'),
                        this.getCssVar('--success', '#2E8B6E'),
                        this.getCssVar('--accent-gold', '#BFDCD0'),
                        this.getCssVar('--warning', '#F59E0B'),
                        this.getCssVar('--info', '#3B82F6')
                    ]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                }
            }
        });
    }

    // Update metrics table
    updateMetricsTable() {
        const tbody = document.getElementById('metricsTableBody');
        if (!tbody) return;

        const classMetrics = this.metrics.per_class_metrics || {};
        const minerals = Object.keys(classMetrics);

        if (minerals.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="9" style="text-align: center; padding: 2rem;">
                        <p style="color: #6B7280;">No metrics data available</p>
                    </td>
                </tr>
            `;
            return;
        }

        tbody.innerHTML = minerals.map(mineral => {
            const metrics = classMetrics[mineral];
            const mineralName = mineral.charAt(0).toUpperCase() + mineral.slice(1);
            
            return `
                <tr>
                    <td>
                        <span class="mineral-badge ${mineral}">${mineralName}</span>
                    </td>
                    <td>${metrics.support || 0}</td>
                    <td>${this.formatPercent(metrics.accuracy)}</td>
                    <td>${this.formatPercent(metrics.precision)}</td>
                    <td>${this.formatPercent(metrics.recall)}</td>
                    <td>${this.formatPercent(metrics.f1_score)}</td>
                    <td><span class="confidence-badge high">${metrics.true_positive ?? metrics.true_positives ?? 0}</span></td>
                    <td><span class="confidence-badge medium">${metrics.false_positive ?? metrics.false_positives ?? 0}</span></td>
                    <td><span class="confidence-badge low">${metrics.false_negative ?? metrics.false_negatives ?? 0}</span></td>
                </tr>
            `;
        }).join('');
    }

    // Format percentage
    formatPercent(value) {
        if (value === null || value === undefined) return 'N/A';
        return `${Math.round(value * 100)}%`;
    }

    // Loading overlay
    showLoading(show) {
        const overlay = document.getElementById('loadingOverlay');
        if (overlay) {
            overlay.style.display = show ? 'flex' : 'none';
        }
    }

    // Show error
    showError(message) {
        alert(message);
    }
}

// Initialize page
let analyticsPage;

document.addEventListener('DOMContentLoaded', () => {
    analyticsPage = new AnalyticsPage();
    analyticsPage.init();
});

window.addEventListener('beforeunload', () => {
    if (analyticsPage?.refreshTimer) {
        clearInterval(analyticsPage.refreshTimer);
    }
});
