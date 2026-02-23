// Analytics Page Management
class AnalyticsPage {
    constructor() {
        this.charts = {};
        this.metrics = null;
    }

    // Initialize page
    async init() {
        this.showLoading(true);
        
        try {
            await this.loadMetrics();
            this.updateStats();
            this.initCharts();
            this.updateMetricsTable();
        } catch (error) {
            console.error('Failed to initialize analytics page:', error);
            this.showError('Failed to load analytics data');
        } finally {
            this.showLoading(false);
        }
    }

    // Load metrics from API
    async loadMetrics() {
        try {
            const response = await fetch(`${API_BASE_URL}/metrics`);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            this.metrics = await response.json();
        } catch (error) {
            console.error('Error loading metrics:', error);
            this.metrics = {
                accuracy: 0,
                macro_precision: 0,
                macro_recall: 0,
                macro_f1: 0,
                total_samples: 0,
                per_class_metrics: {}
            };
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
                        backgroundColor: '#00B894'
                    },
                    {
                        label: 'False Positives',
                        data: falsePositives,
                        backgroundColor: '#F59E0B'
                    },
                    {
                        label: 'False Negatives',
                        data: falseNegatives,
                        backgroundColor: '#D63031'
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
                        borderColor: '#4DD0CE',
                        backgroundColor: 'rgba(77, 208, 206, 0.1)',
                        pointBackgroundColor: '#4DD0CE'
                    },
                    {
                        label: 'Recall',
                        data: recall,
                        borderColor: '#00B894',
                        backgroundColor: 'rgba(0, 184, 148, 0.1)',
                        pointBackgroundColor: '#00B894'
                    },
                    {
                        label: 'F1-Score',
                        data: f1,
                        borderColor: '#F59E0B',
                        backgroundColor: 'rgba(245, 158, 11, 0.1)',
                        pointBackgroundColor: '#F59E0B'
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
    async initConfidenceChart() {
        const ctx = document.getElementById('confidenceChart');
        if (!ctx) return;

        // Fetch fingerprints to get confidence distribution
        try {
            const response = await fetch(`${API_BASE_URL}/fingerprints`);
            const data = await response.json();
            const fingerprints = data.fingerprints || [];

            // Create confidence bins
            const bins = [0, 0, 0, 0, 0]; // 0-20%, 20-40%, 40-60%, 60-80%, 80-100%
            
            fingerprints.forEach(fp => {
                const conf = fp.confidence;
                if (conf !== null && conf !== undefined) {
                    const index = Math.min(Math.floor(conf * 5), 4);
                    bins[index]++;
                }
            });

            this.charts.confidence = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: ['0-20%', '20-40%', '40-60%', '60-80%', '80-100%'],
                    datasets: [{
                        label: 'Number of Predictions',
                        data: bins,
                        backgroundColor: [
                            '#D63031',
                            '#F59E0B',
                            '#F59E0B',
                            '#4DD0CE',
                            '#00B894'
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
        } catch (error) {
            console.error('Error creating confidence chart:', error);
        }
    }

    // Initialize modality usage chart
    initModalityChart() {
        const ctx = document.getElementById('modalityChart');
        if (!ctx) return;

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
                        '#4DD0CE',
                        '#00B894',
                        '#F59E0B',
                        '#8B5CF6',
                        '#EC4899'
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
                    <td>${this.formatPercent(metrics.precision)}</td>
                    <td>${this.formatPercent(metrics.precision)}</td>
                    <td>${this.formatPercent(metrics.recall)}</td>
                    <td>${this.formatPercent(metrics.f1_score)}</td>
                    <td><span class="confidence-badge high">${metrics.true_positive || 0}</span></td>
                    <td><span class="confidence-badge medium">${metrics.false_positive || 0}</span></td>
                    <td><span class="confidence-badge low">${metrics.false_negative || 0}</span></td>
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
