// Sites Page Management
class SitesPage {
    constructor() {
        this.charts = {};
        this.sitesData = {};
        this.siteKeys = [...SITES];
    }

    // Initialize page
    async init() {
        this.showLoading(true);
        
        try {
            await this.loadSitesData();
            this.renderSites();
            this.initCharts();
        } catch (error) {
            console.error('Failed to initialize sites page:', error);
            this.showError('Failed to load sites data');
        } finally {
            this.showLoading(false);
        }
    }

    // Load sites data from API
    async loadSitesData() {
        try {
            // Fetch fingerprints and stats
            const [fingerprintsResponse, statsResponse] = await Promise.all([
                fetch(`${API_BASE_URL}/fingerprints`),
                fetch(`${API_BASE_URL}/stats`)
            ]);

            const fingerprintsData = await fingerprintsResponse.json();
            const statsData = await statsResponse.json();

            const fingerprints = fingerprintsData.fingerprints || [];
            const detectedSites = [...new Set(
                fingerprints
                    .map(fp => (fp.site || '').toString().trim())
                    .filter(site => site.length > 0)
            )];
            this.siteKeys = [...new Set([...SITES, ...detectedSites])];

            // Calculate site-specific data
            this.siteKeys.forEach(site => {
                const siteFingerprints = fingerprints.filter(fp => fp.site === site);
                
                // Count by mineral
                const mineralCounts = {
                    gold: siteFingerprints.filter(fp => fp.mineral?.toLowerCase() === 'gold').length,
                    chalcopyrite: siteFingerprints.filter(fp => fp.mineral?.toLowerCase() === 'chalcopyrite').length,
                    hematite: siteFingerprints.filter(fp => fp.mineral?.toLowerCase() === 'hematite').length
                };

                // Count verified
                const verified = siteFingerprints.filter(fp => {
                    const predicted = fp.predicted_mineral?.toLowerCase();
                    const claimed = fp.mineral?.toLowerCase();
                    const confidence = fp.confidence;
                    return predicted && claimed && confidence >= 0.80 && predicted === claimed;
                }).length;

                // Calculate accuracy
                const withPredictions = siteFingerprints.filter(fp => 
                    fp.predicted_mineral && fp.mineral
                );
                const correct = withPredictions.filter(fp => 
                    fp.predicted_mineral?.toLowerCase() === fp.mineral?.toLowerCase()
                ).length;
                const accuracy = withPredictions.length > 0 
                    ? Math.round((correct / withPredictions.length) * 100)
                    : 0;

                // Get recent scans (last 24 hours)
                const oneDayAgo = new Date();
                oneDayAgo.setHours(oneDayAgo.getHours() - 24);
                const recentScans = siteFingerprints.filter(fp => 
                    new Date(fp.timestamp) > oneDayAgo
                ).length;

                this.sitesData[site] = {
                    name: site.replace(/_/g, ' '),
                    total: siteFingerprints.length,
                    verified,
                    accuracy,
                    mineralCounts,
                    recentScans
                };
            });

            const totalSitesElement = document.getElementById('totalSites');
            const activeSitesElement = document.getElementById('activeSites');
            if (totalSitesElement) {
                totalSitesElement.textContent = String(this.siteKeys.length);
            }
            if (activeSitesElement) {
                const activeCount = this.siteKeys.filter(site => (this.sitesData[site]?.total || 0) > 0).length;
                activeSitesElement.textContent = String(activeCount);
            }
        } catch (error) {
            console.error('Error loading sites data:', error);
            this.siteKeys = [...SITES];
            this.siteKeys.forEach(site => {
                this.sitesData[site] = {
                    name: site.replace(/_/g, ' '),
                    total: 0,
                    verified: 0,
                    accuracy: 0,
                    mineralCounts: { gold: 0, chalcopyrite: 0, hematite: 0 },
                    recentScans: 0
                };
            });
        }
    }

    // Render sites cards
    renderSites() {
        const container = document.getElementById('sitesContainer');
        if (!container) return;

        container.innerHTML = this.siteKeys.map(site => {
            const data = this.sitesData[site];
            const accuracyClass = data.accuracy >= 85 ? 'high' : data.accuracy >= 70 ? 'medium' : 'low';
            
            return `
                <div class="card site-detail-card">
                    <div class="site-detail-header">
                        <div>
                            <h2>${data.name}</h2>
                            <span class="site-badge active">Active</span>
                        </div>
                        <div class="site-icon">
                            <i class="fas fa-map-marker-alt"></i>
                        </div>
                    </div>
                    
                    <div class="site-stats-grid">
                        <div class="stat-box">
                            <span class="stat-label">Total Scans</span>
                            <span class="stat-value">${data.total}</span>
                        </div>
                        <div class="stat-box">
                            <span class="stat-label">Verified</span>
                            <span class="stat-value success">${data.verified}</span>
                        </div>
                        <div class="stat-box">
                            <span class="stat-label">Accuracy</span>
                            <span class="stat-value ${accuracyClass}">${data.accuracy}%</span>
                        </div>
                        <div class="stat-box">
                            <span class="stat-label">Recent (24h)</span>
                            <span class="stat-value">${data.recentScans}</span>
                        </div>
                    </div>

                    <div class="mineral-breakdown">
                        <div class="breakdown-title">Mineral Distribution</div>
                        <div class="mineral-bars">
                            <div class="mineral-bar-item">
                                <div class="mineral-bar-header">
                                    <span class="mineral-badge gold">Gold</span>
                                    <span class="mineral-count">${data.mineralCounts.gold}</span>
                                </div>
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: ${this.getPercentage(data.mineralCounts.gold, data.total)}%; background: #F59E0B;"></div>
                                </div>
                            </div>
                            <div class="mineral-bar-item">
                                <div class="mineral-bar-header">
                                    <span class="mineral-badge chalcopyrite">Chalcopyrite</span>
                                    <span class="mineral-count">${data.mineralCounts.chalcopyrite}</span>
                                </div>
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: ${this.getPercentage(data.mineralCounts.chalcopyrite, data.total)}%; background: #EA580C;"></div>
                                </div>
                            </div>
                            <div class="mineral-bar-item">
                                <div class="mineral-bar-header">
                                    <span class="mineral-badge hematite">Hematite</span>
                                    <span class="mineral-count">${data.mineralCounts.hematite}</span>
                                </div>
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: ${this.getPercentage(data.mineralCounts.hematite, data.total)}%; background: #DC2626;"></div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="site-actions">
                        <button class="action-btn secondary" onclick="window.location.href='scans.html?site=${encodeURIComponent(data.name)}'">
                            <i class="fas fa-list"></i>
                            View Scans
                        </button>
                    </div>
                </div>
            `;
        }).join('');
    }

    // Get percentage
    getPercentage(value, total) {
        return total > 0 ? (value / total) * 100 : 0;
    }

    // Initialize charts
    initCharts() {
        this.initSiteComparisonChart();
        this.initMineralDistributionChart();
    }

    // Initialize site comparison chart
    initSiteComparisonChart() {
        const ctx = document.getElementById('siteComparisonChart');
        if (!ctx) return;

        const siteNames = this.siteKeys.map(site => this.sitesData[site].name);
        const totalScans = this.siteKeys.map(site => this.sitesData[site].total);
        const verified = this.siteKeys.map(site => this.sitesData[site].verified);
        const accuracy = this.siteKeys.map(site => this.sitesData[site].accuracy);

        this.charts.comparison = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: siteNames,
                datasets: [
                    {
                        label: 'Total Scans',
                        data: totalScans,
                        backgroundColor: '#4DD0CE',
                        yAxisID: 'y'
                    },
                    {
                        label: 'Verified',
                        data: verified,
                        backgroundColor: '#00B894',
                        yAxisID: 'y'
                    },
                    {
                        label: 'Accuracy (%)',
                        data: accuracy,
                        backgroundColor: '#F59E0B',
                        type: 'line',
                        yAxisID: 'y1',
                        borderColor: '#F59E0B',
                        tension: 0.4
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
                    y: {
                        type: 'linear',
                        display: true,
                        position: 'left',
                        beginAtZero: true,
                        ticks: {
                            precision: 0
                        }
                    },
                    y1: {
                        type: 'linear',
                        display: true,
                        position: 'right',
                        beginAtZero: true,
                        max: 100,
                        grid: {
                            drawOnChartArea: false
                        }
                    }
                }
            }
        });
    }

    // Initialize mineral distribution chart
    initMineralDistributionChart() {
        const ctx = document.getElementById('mineralDistributionChart');
        if (!ctx) return;

        const siteNames = this.siteKeys.map(site => this.sitesData[site].name);
        const goldData = this.siteKeys.map(site => this.sitesData[site].mineralCounts.gold);
        const chalcoData = this.siteKeys.map(site => this.sitesData[site].mineralCounts.chalcopyrite);
        const hematiteData = this.siteKeys.map(site => this.sitesData[site].mineralCounts.hematite);

        this.charts.distribution = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: siteNames,
                datasets: [
                    {
                        label: 'Gold',
                        data: goldData,
                        backgroundColor: '#F59E0B'
                    },
                    {
                        label: 'Chalcopyrite',
                        data: chalcoData,
                        backgroundColor: '#EA580C'
                    },
                    {
                        label: 'Hematite',
                        data: hematiteData,
                        backgroundColor: '#DC2626'
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
                    x: {
                        stacked: true
                    },
                    y: {
                        stacked: true,
                        beginAtZero: true,
                        ticks: {
                            precision: 0
                        }
                    }
                }
            }
        });
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
let sitesPage;

document.addEventListener('DOMContentLoaded', () => {
    sitesPage = new SitesPage();
    sitesPage.init();
});
