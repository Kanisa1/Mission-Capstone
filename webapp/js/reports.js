// Reports Page Management
class ReportsPage {
    constructor() {
        this.data = null;
    }

    // Initialize page
    async init() {
        this.showLoading(true);
        
        try {
            await this.loadData();
            this.updateSummary();
        } catch (error) {
            console.error('Failed to initialize reports page:', error);
            this.showError('Failed to load report data');
        } finally {
            this.showLoading(false);
        }
    }

    // Load data from API
    async loadData() {
        try {
            const [statsResponse, fingerprintsResponse, metricsResponse, usersResponse] = await Promise.all([
                fetch(`${API_BASE_URL}/stats`),
                fetch(`${API_BASE_URL}/fingerprints`),
                fetch(`${API_BASE_URL}/metrics`),
                fetch(`${API_BASE_URL}/users`)
            ]);

            this.data = {
                stats: await statsResponse.json(),
                fingerprints: (await fingerprintsResponse.json()).fingerprints || [],
                metrics: await metricsResponse.json(),
                users: (await usersResponse.json()).users || []
            };
        } catch (error) {
            console.error('Error loading data:', error);
            this.data = {
                stats: {},
                fingerprints: [],
                metrics: {},
                users: []
            };
        }
    }

    // Update summary
    updateSummary() {
        if (!this.data) return;

        const stats = this.data.stats;
        const metrics = this.data.metrics;

        document.getElementById('summaryScans').textContent = stats.total_scans || 0;
        document.getElementById('summaryVerified').textContent = stats.verified || 0;
        document.getElementById('summaryAccuracy').textContent = metrics.accuracy 
            ? `${Math.round(metrics.accuracy * 100)}%` 
            : '0%';
        document.getElementById('summarySites').textContent = Object.keys(stats.by_site || {}).length;
        document.getElementById('summaryGold').textContent = stats.by_mineral?.gold || 0;
        document.getElementById('summaryChalco').textContent = stats.by_mineral?.chalcopyrite || 0;
        document.getElementById('summaryHematite').textContent = stats.by_mineral?.hematite || 0;
        document.getElementById('summaryUsers').textContent = this.data.users.length;
    }

    // Generate report
    async generateReport(type) {
        this.showLoading(true);

        try {
            let reportData = null;
            let fileName = '';

            switch (type) {
                case 'summary':
                    reportData = this.generateSummaryReport();
                    fileName = `summary_report_${this.getDateString()}.json`;
                    break;
                case 'performance':
                    reportData = this.generatePerformanceReport();
                    fileName = `performance_report_${this.getDateString()}.json`;
                    break;
                case 'verification':
                    reportData = this.generateVerificationReport();
                    fileName = `verification_report_${this.getDateString()}.json`;
                    break;
                case 'user-activity':
                    reportData = this.generateUserActivityReport();
                    fileName = `user_activity_report_${this.getDateString()}.json`;
                    break;
            }

            if (reportData) {
                this.downloadJSON(reportData, fileName);
            }
        } catch (error) {
            console.error('Error generating report:', error);
            this.showError('Failed to generate report');
        } finally {
            this.showLoading(false);
        }
    }

    // Generate summary report
    generateSummaryReport() {
        const report = {
            report_type: 'Summary Report',
            generated_at: new Date().toISOString(),
            period: 'All Time',
            summary: {
                total_scans: this.data.stats.total_scans || 0,
                verified_scans: this.data.stats.verified || 0,
                not_verified: this.data.stats.not_verified || 0,
                pending: this.data.stats.pending || 0,
                by_mineral: this.data.stats.by_mineral || {},
                by_site: this.data.stats.by_site || {}
            },
            model_performance: {
                accuracy: this.data.metrics.accuracy || 0,
                precision: this.data.metrics.macro_precision || 0,
                recall: this.data.metrics.macro_recall || 0,
                f1_score: this.data.metrics.macro_f1 || 0
            },
            total_users: this.data.users.length,
            active_sites: Object.keys(this.data.stats.by_site || {}).length
        };

        return report;
    }

    // Generate performance report
    generatePerformanceReport() {
        const report = {
            report_type: 'Performance Report',
            generated_at: new Date().toISOString(),
            overall_metrics: {
                accuracy: this.data.metrics.accuracy || 0,
                macro_precision: this.data.metrics.macro_precision || 0,
                macro_recall: this.data.metrics.macro_recall || 0,
                macro_f1: this.data.metrics.macro_f1 || 0
            },
            per_class_metrics: this.data.metrics.per_class_metrics || {},
            modality_usage: this.data.metrics.modality_usage || {},
            total_samples: this.data.metrics.total_samples || 0,
            samples_with_predictions: this.data.metrics.samples_with_predictions || 0
        };

        return report;
    }

    // Generate verification report
    generateVerificationReport() {
        const verified = this.data.fingerprints.filter(fp => {
            const predicted = fp.predicted_mineral?.toLowerCase();
            const claimed = fp.mineral?.toLowerCase();
            const confidence = fp.confidence;
            return predicted && claimed && confidence >= 0.80 && predicted === claimed;
        });

        const report = {
            report_type: 'Verification Report',
            generated_at: new Date().toISOString(),
            total_fingerprints: this.data.fingerprints.length,
            verified_count: verified.length,
            verification_rate: this.data.fingerprints.length > 0 
                ? (verified.length / this.data.fingerprints.length) * 100 
                : 0,
            by_site: {},
            by_mineral: {},
            verified_records: verified.map(fp => ({
                sample_id: fp.sample_id,
                timestamp: fp.timestamp,
                site: fp.site,
                mineral: fp.mineral,
                predicted_mineral: fp.predicted_mineral,
                confidence: fp.confidence,
                user: fp.user_name
            }))
        };

        // Group by site
        SITES.forEach(site => {
            const siteRecords = verified.filter(fp => fp.site === site);
            report.by_site[site] = {
                count: siteRecords.length,
                percentage: verified.length > 0 ? (siteRecords.length / verified.length) * 100 : 0
            };
        });

        // Group by mineral
        ['gold', 'chalcopyrite', 'hematite'].forEach(mineral => {
            const mineralRecords = verified.filter(fp => fp.mineral?.toLowerCase() === mineral);
            report.by_mineral[mineral] = {
                count: mineralRecords.length,
                percentage: verified.length > 0 ? (mineralRecords.length / verified.length) * 100 : 0
            };
        });

        return report;
    }

    // Generate user activity report
    generateUserActivityReport() {
        const userScans = {};

        this.data.fingerprints.forEach(fp => {
            const userId = fp.user_id || fp.user_name || 'Unknown';
            if (!userScans[userId]) {
                userScans[userId] = {
                    total_scans: 0,
                    by_mineral: {},
                    by_site: {},
                    verified_count: 0
                };
            }

            userScans[userId].total_scans++;

            const mineral = fp.mineral?.toLowerCase();
            if (mineral) {
                userScans[userId].by_mineral[mineral] = (userScans[userId].by_mineral[mineral] || 0) + 1;
            }

            const site = fp.site;
            if (site) {
                userScans[userId].by_site[site] = (userScans[userId].by_site[site] || 0) + 1;
            }

            // Check if verified
            const predicted = fp.predicted_mineral?.toLowerCase();
            const claimed = fp.mineral?.toLowerCase();
            const confidence = fp.confidence;
            if (predicted && claimed && confidence >= 0.80 && predicted === claimed) {
                userScans[userId].verified_count++;
            }
        });

        const report = {
            report_type: 'User Activity Report',
            generated_at: new Date().toISOString(),
            total_users: this.data.users.length,
            active_users: Object.keys(userScans).length,
            users: this.data.users.map(user => ({
                id: user.id,
                name: user.name,
                email: user.email,
                role: user.role,
                activity: userScans[user.id] || userScans[user.name] || {
                    total_scans: 0,
                    by_mineral: {},
                    by_site: {},
                    verified_count: 0
                }
            }))
        };

        return report;
    }

    // Export data
    async exportData(type) {
        this.showLoading(true);

        try {
            let data = null;
            let fileName = '';

            switch (type) {
                case 'fingerprints':
                    data = this.data.fingerprints;
                    fileName = `fingerprints_export_${this.getDateString()}.json`;
                    this.downloadJSON(data, fileName);
                    break;
                case 'verifications':
                    data = this.prepareVerificationsCSV();
                    fileName = `verifications_export_${this.getDateString()}.csv`;
                    this.downloadCSV(data, fileName);
                    break;
                case 'metrics':
                    data = this.data.metrics;
                    fileName = `metrics_export_${this.getDateString()}.json`;
                    this.downloadJSON(data, fileName);
                    break;
            }
        } catch (error) {
            console.error('Error exporting data:', error);
            this.showError('Failed to export data');
        } finally {
            this.showLoading(false);
        }
    }

    // Prepare verifications CSV
    prepareVerificationsCSV() {
        const headers = ['Sample ID', 'Timestamp', 'Site', 'Mineral', 'Predicted', 'Confidence', 'User', 'Status'];
        const rows = this.data.fingerprints.map(fp => {
            const predicted = fp.predicted_mineral?.toLowerCase();
            const claimed = fp.mineral?.toLowerCase();
            const confidence = fp.confidence;
            const status = predicted && claimed && confidence >= 0.80 && predicted === claimed ? 'Verified' : 'Not Verified';

            return [
                fp.sample_id || 'N/A',
                fp.timestamp || 'N/A',
                fp.site || 'N/A',
                fp.mineral || 'N/A',
                fp.predicted_mineral || 'N/A',
                confidence !== null && confidence !== undefined ? confidence.toFixed(3) : 'N/A',
                fp.user_name || 'Unknown',
                status
            ];
        });

        return [headers, ...rows];
    }

    // Download JSON
    downloadJSON(data, fileName) {
        const json = JSON.stringify(data, null, 2);
        const blob = new Blob([json], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = fileName;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    // Download CSV
    downloadCSV(data, fileName) {
        const csv = data.map(row => row.join(',')).join('\n');
        const blob = new Blob([csv], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = fileName;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    // Get date string
    getDateString() {
        const now = new Date();
        return now.toISOString().split('T')[0];
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
let reportsPage;

document.addEventListener('DOMContentLoaded', () => {
    reportsPage = new ReportsPage();
    reportsPage.init();
});
