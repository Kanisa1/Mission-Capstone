// Reports Page Management
class ReportsPage {
    constructor() {
        this.data = null;
    }

    normalizeText(value) {
        if (value === null || value === undefined) return '';
        return String(value).trim().toLowerCase();
    }

    normalizeNumber(value, fallback = 0) {
        const parsed = Number(value);
        return Number.isFinite(parsed) ? parsed : fallback;
    }

    getSafeFingerprints() {
        if (!Array.isArray(this.data?.fingerprints)) return [];
        return this.data.fingerprints.filter(item => item && typeof item === 'object' && !Array.isArray(item));
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
                    fileName = `summary_report_${this.getDateString()}.pdf`;
                    break;
                case 'performance':
                    reportData = this.generatePerformanceReport();
                    fileName = `performance_report_${this.getDateString()}.pdf`;
                    break;
                case 'verification':
                    reportData = this.generateVerificationReport();
                    fileName = `verification_report_${this.getDateString()}.pdf`;
                    break;
                case 'user-activity':
                    reportData = this.generateUserActivityReport();
                    fileName = `user_activity_report_${this.getDateString()}.pdf`;
                    break;
            }

            if (reportData) {
                await this.downloadPDF(type, reportData, fileName);
            }
        } catch (error) {
            console.error('Error generating report:', error);
            this.showError(`Failed to generate ${type} report: ${error?.message || error}`);
        } finally {
            this.showLoading(false);
        }
    }

    async downloadPDF(type, reportData, fileName) {
        if (!window.html2canvas || !window.jspdf || !window.Chart) {
            throw new Error('PDF/chart dependencies are not loaded');
        }

        const reportRoot = this.buildReportDOM(type, reportData);
        document.body.appendChild(reportRoot);

        const charts = this.renderReportCharts(reportRoot, type, reportData);

        await this.waitForReportAssets(reportRoot);
        await new Promise(resolve => setTimeout(resolve, 350));

        const canvas = await window.html2canvas(reportRoot, {
            scale: 2,
            useCORS: true,
            backgroundColor: '#ffffff'
        });

        charts.forEach(chart => chart.destroy());
        reportRoot.remove();

        const { jsPDF } = window.jspdf;
        const pdf = new jsPDF('p', 'mm', 'a4');
        this.addCanvasToPdfPages(pdf, canvas, type);
        pdf.save(fileName);
    }

    async waitForReportAssets(root) {
        const images = Array.from(root.querySelectorAll('img'));
        if (!images.length) return;

        await Promise.all(
            images.map((img) => {
                if (img.complete && img.naturalWidth > 0) {
                    return Promise.resolve();
                }
                return new Promise((resolve) => {
                    img.onload = () => resolve();
                    img.onerror = () => resolve();
                });
            })
        );
    }

    addCanvasToPdfPages(pdf, canvas, type) {
        const margin = 10;
        const pageWidth = 210;
        const pageHeight = 297;
        const usableWidth = pageWidth - (margin * 2);
        const usableHeight = pageHeight - (margin * 2);

        const imgData = canvas.toDataURL('image/png');
        const imgHeight = (canvas.height * usableWidth) / canvas.width;

        let heightLeft = imgHeight;
        let position = margin;

        pdf.addImage(imgData, 'PNG', margin, position, usableWidth, imgHeight);
        heightLeft -= usableHeight;

        while (heightLeft > 0) {
            pdf.addPage();
            position = margin - (imgHeight - heightLeft);
            pdf.addImage(imgData, 'PNG', margin, position, usableWidth, imgHeight);
            heightLeft -= usableHeight;
        }

        this.addPdfFooterAndWatermark(pdf, type);
    }

    addPdfFooterAndWatermark(pdf, type) {
        const pageCount = pdf.getNumberOfPages();
        const titleMap = {
            summary: 'Summary Report',
            performance: 'Performance Report',
            verification: 'Verification Report',
            'user-activity': 'User Activity Report'
        };
        const title = titleMap[type] || 'Report';

        for (let page = 1; page <= pageCount; page++) {
            pdf.setPage(page);

            pdf.setTextColor(190, 198, 208);
            pdf.setFontSize(28);
            pdf.text('MineralTrace', 105, 145, { align: 'center', angle: 35 });

            pdf.setTextColor(95, 114, 128);
            pdf.setFontSize(9);
            pdf.text(`${title} • Page ${page} of ${pageCount}`, 105, 292, { align: 'center' });
        }
    }

    buildReportDOM(type, reportData) {
        const root = document.createElement('div');
        root.style.position = 'fixed';
        root.style.left = '-10000px';
        root.style.top = '0';
        root.style.width = '1080px';
        root.style.background = '#ffffff';
        root.style.padding = '28px';
        root.style.fontFamily = 'Inter, Arial, sans-serif';
        root.style.color = '#0A3552';
        root.style.zIndex = '-1';
        root.style.position = 'fixed';
        root.style.overflow = 'hidden';

        const titleMap = {
            summary: 'Summary Report',
            performance: 'Performance Report',
            verification: 'Verification Report',
            'user-activity': 'User Activity Report'
        };

        const generatedAt = new Date(reportData.generated_at || Date.now()).toLocaleString();

        root.innerHTML = `
            <img src="../assets/logo.png" alt="logo" style="position:absolute; right:22px; top:18px; width:52px; opacity:0.9;" />
            <div style="display:flex; justify-content:space-between; align-items:flex-start; margin-bottom: 18px; border-bottom: 2px solid #E5E7EB; padding-bottom: 12px;">
                <div>
                    <div style="font-size:28px; font-weight:700; color:#0A3552;">${titleMap[type] || 'Report'}</div>
                    <div style="font-size:13px; color:#5F7280; margin-top:4px;">Generated: ${generatedAt}</div>
                </div>
                <div style="font-size:14px; font-weight:600; color:#2C6E91;">MineralTrace</div>
            </div>
            ${this.buildReportSummaryBlocks(type, reportData)}
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-top: 18px;">
                <div style="border:1px solid #E5E7EB; border-radius:12px; padding:12px; min-height:300px;">
                    <canvas id="report-chart-1" width="500" height="280"></canvas>
                </div>
                <div style="border:1px solid #E5E7EB; border-radius:12px; padding:12px; min-height:300px;">
                    <canvas id="report-chart-2" width="500" height="280"></canvas>
                </div>
            </div>
            <div style="margin-top: 18px; border:1px solid #E5E7EB; border-radius:12px; padding:12px;">
                ${this.buildReportTable(type, reportData)}
            </div>
        `;

        return root;
    }

    buildReportSummaryBlocks(type, reportData) {
        const blocks = [];

        if (type === 'summary') {
            blocks.push(['Total Scans', reportData.summary?.total_scans ?? 0]);
            blocks.push(['Verified', reportData.summary?.verified_scans ?? 0]);
            blocks.push(['Accuracy', `${Math.round((reportData.model_performance?.accuracy || 0) * 100)}%`]);
            blocks.push(['Active Sites', reportData.active_sites ?? 0]);
        } else if (type === 'performance') {
            blocks.push(['Accuracy', `${Math.round((reportData.overall_metrics?.accuracy || 0) * 100)}%`]);
            blocks.push(['Precision', `${Math.round((reportData.overall_metrics?.macro_precision || 0) * 100)}%`]);
            blocks.push(['Recall', `${Math.round((reportData.overall_metrics?.macro_recall || 0) * 100)}%`]);
            blocks.push(['F1 Score', `${Math.round((reportData.overall_metrics?.macro_f1 || 0) * 100)}%`]);
        } else if (type === 'verification') {
            blocks.push(['Total Fingerprints', reportData.total_fingerprints ?? 0]);
            blocks.push(['Verified Count', reportData.verified_count ?? 0]);
            blocks.push(['Verification Rate', `${Math.round(reportData.verification_rate || 0)}%`]);
            blocks.push(['Sites Covered', Object.keys(reportData.by_site || {}).length]);
        } else if (type === 'user-activity') {
            blocks.push(['Total Users', reportData.total_users ?? 0]);
            blocks.push(['Active Users', reportData.active_users ?? 0]);
            const totalScans = (reportData.users || []).reduce((sum, user) => sum + (user.activity?.total_scans || 0), 0);
            blocks.push(['Total User Scans', totalScans]);
            const totalVerified = (reportData.users || []).reduce((sum, user) => sum + (user.activity?.verified_count || 0), 0);
            blocks.push(['Verified by Users', totalVerified]);
        }

        return `
            <div style="display:grid; grid-template-columns: repeat(4, 1fr); gap: 12px;">
                ${blocks.map(([label, value]) => `
                    <div style="background:#F8FAFC; border:1px solid #E5E7EB; border-radius:10px; padding:10px;">
                        <div style="font-size:12px; color:#5F7280;">${label}</div>
                        <div style="font-size:22px; font-weight:700; color:#0A3552; margin-top:4px;">${value}</div>
                    </div>
                `).join('')}
            </div>
        `;
    }

    buildReportTable(type, reportData) {
        if (type === 'verification') {
            const rows = (reportData.verified_records || []).slice(0, 15).map(record => `
                <tr>
                    <td>${record.sample_id || 'N/A'}</td>
                    <td>${record.site || 'N/A'}</td>
                    <td>${record.mineral || 'N/A'}</td>
                    <td>${record.predicted_mineral || 'N/A'}</td>
                    <td>${record.confidence != null ? Number(record.confidence).toFixed(3) : 'N/A'}</td>
                </tr>
            `).join('');

            return `
                <div style="font-size:16px; font-weight:700; margin-bottom:10px;">Latest Verified Records</div>
                <table style="width:100%; border-collapse:collapse; font-size:12px;">
                    <thead>
                        <tr style="background:#F1F5F9; text-align:left;">
                            <th style="padding:8px; border-bottom:1px solid #E5E7EB;">Sample ID</th>
                            <th style="padding:8px; border-bottom:1px solid #E5E7EB;">Site</th>
                            <th style="padding:8px; border-bottom:1px solid #E5E7EB;">Mineral</th>
                            <th style="padding:8px; border-bottom:1px solid #E5E7EB;">Predicted</th>
                            <th style="padding:8px; border-bottom:1px solid #E5E7EB;">Confidence</th>
                        </tr>
                    </thead>
                    <tbody>${rows || '<tr><td colspan="5" style="padding:8px;">No verified records available</td></tr>'}</tbody>
                </table>
            `;
        }

        if (type === 'user-activity') {
            const rows = (reportData.users || []).slice(0, 15).map(user => `
                <tr>
                    <td>${user.name || 'N/A'}</td>
                    <td>${user.role || 'N/A'}</td>
                    <td>${user.activity?.total_scans || 0}</td>
                    <td>${user.activity?.verified_count || 0}</td>
                </tr>
            `).join('');

            return `
                <div style="font-size:16px; font-weight:700; margin-bottom:10px;">User Activity Breakdown</div>
                <table style="width:100%; border-collapse:collapse; font-size:12px;">
                    <thead>
                        <tr style="background:#F1F5F9; text-align:left;">
                            <th style="padding:8px; border-bottom:1px solid #E5E7EB;">User</th>
                            <th style="padding:8px; border-bottom:1px solid #E5E7EB;">Role</th>
                            <th style="padding:8px; border-bottom:1px solid #E5E7EB;">Total Scans</th>
                            <th style="padding:8px; border-bottom:1px solid #E5E7EB;">Verified</th>
                        </tr>
                    </thead>
                    <tbody>${rows || '<tr><td colspan="4" style="padding:8px;">No user activity data available</td></tr>'}</tbody>
                </table>
            `;
        }

        return `
            <div style="font-size:16px; font-weight:700; margin-bottom:10px;">Key Notes</div>
            <ul style="margin:0; padding-left:18px; color:#334155; font-size:13px; line-height:1.7;">
                <li>Report generated directly from live API data.</li>
                <li>Charts summarize current dataset and model behavior.</li>
                <li>Use this PDF for compliance reporting and stakeholder sharing.</li>
            </ul>
        `;
    }

    renderReportCharts(reportRoot, type, reportData) {
        const chart1 = reportRoot.querySelector('#report-chart-1');
        const chart2 = reportRoot.querySelector('#report-chart-2');
        const charts = [];

        const makeChart = (canvas, config) => {
            if (!canvas) return;
            charts.push(new Chart(canvas.getContext('2d'), config));
        };

        if (type === 'summary') {
            const byMineral = reportData.summary?.by_mineral || {};
            const bySite = reportData.summary?.by_site || {};

            makeChart(chart1, {
                type: 'bar',
                data: {
                    labels: Object.keys(byMineral),
                    datasets: [{
                        label: 'Scans by Mineral',
                        data: Object.values(byMineral),
                        backgroundColor: ['#2C6E91', '#3F87AF', '#6BA9C9']
                    }]
                },
                options: { responsive: false, plugins: { legend: { display: false } } }
            });

            makeChart(chart2, {
                type: 'pie',
                data: {
                    labels: Object.keys(bySite),
                    datasets: [{
                        data: Object.values(bySite),
                        backgroundColor: ['#0A3552', '#2C6E91', '#BFDCD0', '#6FAF98']
                    }]
                },
                options: { responsive: false }
            });
        }

        if (type === 'performance') {
            const perClass = reportData.per_class_metrics || {};
            const labels = Object.keys(perClass);

            makeChart(chart1, {
                type: 'bar',
                data: {
                    labels,
                    datasets: [
                        {
                            label: 'Precision',
                            data: labels.map(k => (perClass[k].precision || 0) * 100),
                            backgroundColor: '#2C6E91'
                        },
                        {
                            label: 'Recall',
                            data: labels.map(k => (perClass[k].recall || 0) * 100),
                            backgroundColor: '#6FAF98'
                        },
                        {
                            label: 'F1',
                            data: labels.map(k => (perClass[k].f1 || 0) * 100),
                            backgroundColor: '#BFDCD0'
                        }
                    ]
                },
                options: { responsive: false }
            });

            const modality = reportData.modality_usage || {};
            makeChart(chart2, {
                type: 'doughnut',
                data: {
                    labels: Object.keys(modality),
                    datasets: [{
                        data: Object.values(modality),
                        backgroundColor: ['#0A3552', '#2C6E91', '#BFDCD0']
                    }]
                },
                options: { responsive: false }
            });
        }

        if (type === 'verification') {
            makeChart(chart1, {
                type: 'doughnut',
                data: {
                    labels: ['Verified', 'Not Verified'],
                    datasets: [{
                        data: [
                            reportData.verified_count || 0,
                            Math.max((reportData.total_fingerprints || 0) - (reportData.verified_count || 0), 0)
                        ],
                        backgroundColor: ['#2E8B6E', '#DC2626']
                    }]
                },
                options: { responsive: false }
            });

            const bySite = reportData.by_site || {};
            const siteLabels = Object.keys(bySite);
            const siteCounts = siteLabels.map(label => this.normalizeNumber(bySite[label]?.count, 0));
            makeChart(chart2, {
                type: 'bar',
                data: {
                    labels: siteLabels,
                    datasets: [{
                        label: 'Verified by Site',
                        data: siteCounts,
                        backgroundColor: '#2C6E91'
                    }]
                },
                options: { responsive: false, plugins: { legend: { display: false } } }
            });
        }

        if (type === 'user-activity') {
            const users = (reportData.users || []).filter(u => (u.activity?.total_scans || 0) > 0);

            makeChart(chart1, {
                type: 'bar',
                data: {
                    labels: users.map(u => u.name || u.id || 'User').slice(0, 12),
                    datasets: [{
                        label: 'Total Scans',
                        data: users.map(u => u.activity?.total_scans || 0).slice(0, 12),
                        backgroundColor: '#2C6E91'
                    }]
                },
                options: { responsive: false, plugins: { legend: { display: false } } }
            });

            const roleCounts = {};
            (reportData.users || []).forEach(u => {
                const role = u.role || 'unknown';
                roleCounts[role] = (roleCounts[role] || 0) + 1;
            });

            makeChart(chart2, {
                type: 'pie',
                data: {
                    labels: Object.keys(roleCounts),
                    datasets: [{
                        data: Object.values(roleCounts),
                        backgroundColor: ['#0A3552', '#2C6E91', '#BFDCD0', '#6FAF98']
                    }]
                },
                options: { responsive: false }
            });
        }

        return charts;
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
        const fingerprints = this.getSafeFingerprints();
        const configuredSites = Array.isArray(globalThis.SITES) ? globalThis.SITES : [];
        const discoveredSites = [...new Set(fingerprints.map(fp => fp?.site).filter(Boolean))];
        const allSites = [...new Set([...configuredSites, ...discoveredSites])];

        const verified = fingerprints.filter(fp => {
            const predicted = this.normalizeText(fp.predicted_mineral);
            const claimed = this.normalizeText(fp.mineral);
            const confidence = this.normalizeNumber(fp.confidence, -1);
            return predicted && claimed && confidence >= 0.80 && predicted === claimed;
        });

        const report = {
            report_type: 'Verification Report',
            generated_at: new Date().toISOString(),
            total_fingerprints: fingerprints.length,
            verified_count: verified.length,
            verification_rate: fingerprints.length > 0 
                ? (verified.length / fingerprints.length) * 100 
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
        allSites.forEach(site => {
            const siteRecords = verified.filter(fp => fp.site === site);
            report.by_site[site] = {
                count: siteRecords.length,
                percentage: verified.length > 0 ? (siteRecords.length / verified.length) * 100 : 0
            };
        });

        // Group by mineral
        ['gold', 'chalcopyrite', 'hematite'].forEach(mineral => {
            const mineralRecords = verified.filter(fp => this.normalizeText(fp.mineral) === mineral);
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
        const fingerprints = this.getSafeFingerprints();

        fingerprints.forEach(fp => {
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

            const mineral = this.normalizeText(fp.mineral);
            if (mineral) {
                userScans[userId].by_mineral[mineral] = (userScans[userId].by_mineral[mineral] || 0) + 1;
            }

            const site = fp.site;
            if (site) {
                userScans[userId].by_site[site] = (userScans[userId].by_site[site] || 0) + 1;
            }

            // Check if verified
            const predicted = this.normalizeText(fp.predicted_mineral);
            const claimed = this.normalizeText(fp.mineral);
            const confidence = this.normalizeNumber(fp.confidence, -1);
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
        const rows = this.getSafeFingerprints().map(fp => {
            const predicted = this.normalizeText(fp.predicted_mineral);
            const claimed = this.normalizeText(fp.mineral);
            const confidence = this.normalizeNumber(fp.confidence, NaN);
            const status = predicted && claimed && confidence >= 0.80 && predicted === claimed ? 'Verified' : 'Not Verified';

            return [
                fp.sample_id || 'N/A',
                fp.timestamp || 'N/A',
                fp.site || 'N/A',
                fp.mineral || 'N/A',
                fp.predicted_mineral || 'N/A',
                Number.isFinite(confidence) ? confidence.toFixed(3) : 'N/A',
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
