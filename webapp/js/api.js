// API Service Layer
class APIService {
    constructor(baseURL) {
        this.baseURL = baseURL;
    }

    // Load fingerprints from API
    async loadFingerprints() {
        try {
            const response = await fetch(`${this.baseURL}/fingerprints`);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const data = await response.json();
            return data.fingerprints || [];
        } catch (error) {
            console.error('Error loading fingerprints:', error);
            return [];
        }
    }

    // Public alias used by other modules.
    async getFingerprints() {
        return this.loadFingerprints();
    }

    async getUsers() {
        try {
            const response = await fetch(`${this.baseURL}/users`);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const data = await response.json();
            return data.users || [];
        } catch (error) {
            console.error('Error loading users:', error);
            return [];
        }
    }

    // Load predictions from fingerprints (each fingerprint has prediction data)
    async loadPredictions() {
        try {
            const fingerprints = await this.loadFingerprints();
            // Convert fingerprints to prediction format
            return fingerprints.map(fp => ({
                predicted: fp.predicted_mineral,
                expected: fp.mineral,
                confidence: fp.confidence,
                site: fp.site,
                timestamp: fp.timestamp
            })).filter(p => p.predicted && p.expected);
        } catch (error) {
            console.error('Error loading predictions:', error);
            return [];
        }
    }

    // Check API health
    async checkHealth() {
        try {
            const response = await fetch(API_ENDPOINTS.health);
            return response.ok;
        } catch (error) {
            console.error('API health check failed:', error);
            return false;
        }
    }

    // Calculate statistics from API
    async getStatistics() {
        try {
            // Fetch stats from API
            const statsResponse = await fetch(`${this.baseURL}/stats`);
            const statsData = await statsResponse.json();
            
            const fingerprints = await this.loadFingerprints();
            const predictions = await this.loadPredictions();

            // Use API stats data
            const mineralCounts = {
                gold: statsData.by_mineral?.gold || 0,
                chalcopyrite: statsData.by_mineral?.chalcopyrite || 0,
                hematite: statsData.by_mineral?.hematite || 0
            };
            
            const siteCounts = statsData.by_site || {};
            const verifiedCount = statsData.verified || 0;
            
            // Calculate accuracy from predictions
            let correctPredictions = 0;
            predictions.forEach(pred => {
                if (pred.predicted?.toLowerCase() === pred.expected?.toLowerCase()) {
                    correctPredictions++;
                }
            });

            const accuracy = predictions.length > 0 
                ? Math.round((correctPredictions / predictions.length) * 100) 
                : 0;

            // Get recent activity
            const recentActivity = fingerprints
                .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
                .slice(0, 10)
                .map(fp => ({
                    mineral: fp.mineral,
                    site: fp.site,
                    timestamp: fp.timestamp,
                    verified: this.isVerified(fp)
                }));

            // Calculate site performance
            const sitePerformance = {};
            SITES.forEach(site => {
                const sitePreds = predictions.filter(p => p.site === site);
                const siteCorrect = sitePreds.filter(p => 
                    p.predicted?.toLowerCase() === p.expected?.toLowerCase()
                ).length;
                
                sitePerformance[site] = {
                    total: siteCounts[site] || 0,
                    verified: fingerprints.filter(fp => fp.site === site && this.isVerified(fp)).length,
                    accuracy: sitePreds.length > 0 
                        ? Math.round((siteCorrect / sitePreds.length) * 100)
                        : 0
                };
            });

            // Calculate trends (daily counts for last 7 days)
            const trends = this.calculateTrends(fingerprints);

            return {
                totalScans: statsData.total_scans || fingerprints.length,
                verifiedCount,
                accuracy,
                mineralCounts,
                siteCounts,
                sitePerformance,
                recentActivity,
                trends,
                predictions
            };
        } catch (error) {
            console.error('Error getting statistics:', error);
            return {
                totalScans: 0,
                verifiedCount: 0,
                accuracy: 0,
                mineralCounts: { gold: 0, chalcopyrite: 0, hematite: 0 },
                siteCounts: {},
                sitePerformance: {},
                recentActivity: [],
                trends: { labels: [], gold: [], chalcopyrite: [], hematite: [] },
                predictions: []
            };
        }
    }

    // Check if fingerprint is verified
    isVerified(fp) {
        const predicted = fp.predicted_mineral?.toLowerCase();
        const claimed = fp.mineral?.toLowerCase();
        const confidence = fp.confidence;
        
        if (predicted && claimed && confidence !== null && confidence !== undefined) {
            return predicted === claimed && confidence >= 0.80;
        }
        return false;
    }

    // Calculate daily trends for charts
    calculateTrends(fingerprints) {
        const days = 7;
        const trends = {
            labels: [],
            gold: [],
            chalcopyrite: [],
            hematite: []
        };

        for (let i = days - 1; i >= 0; i--) {
            const date = new Date();
            date.setDate(date.getDate() - i);
            date.setHours(0, 0, 0, 0);
            
            const nextDate = new Date(date);
            nextDate.setDate(nextDate.getDate() + 1);

            const dayLabel = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
            trends.labels.push(dayLabel);

            // Count fingerprints for this day
            const dayFingerprints = fingerprints.filter(fp => {
                const fpDate = new Date(fp.timestamp);
                return fpDate >= date && fpDate < nextDate;
            });

            trends.gold.push(dayFingerprints.filter(fp => 
                fp.mineral?.toLowerCase() === 'gold'
            ).length);
            
            trends.chalcopyrite.push(dayFingerprints.filter(fp => 
                fp.mineral?.toLowerCase() === 'chalcopyrite'
            ).length);
            
            trends.hematite.push(dayFingerprints.filter(fp => 
                fp.mineral?.toLowerCase() === 'hematite'
            ).length);
        }

        return trends;
    }

    // Calculate heatmap data (mineral counts by site)
    async getHeatmapData() {
        const fingerprints = await this.loadFingerprints();
        const heatmap = {};

        SITES.forEach(site => {
            MINERALS.forEach(mineral => {
                const key = `${site}_${mineral}`;
                heatmap[key] = fingerprints.filter(fp => 
                    fp.site === site && 
                    fp.mineral?.toLowerCase() === mineral
                ).length;
            });
        });

        return heatmap;
    }

    // Get model performance metrics from API
    async getModelMetrics() {
        try {
            const response = await fetch(`${this.baseURL}/metrics`);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const data = await response.json();
            
            // Return formatted metrics
            return {
                accuracy: Math.round(data.accuracy * 100) || 0,
                precision: Math.round(data.macro_precision * 100) || 0,
                recall: Math.round(data.macro_recall * 100) || 0,
                f1Score: Math.round(data.macro_f1 * 100) || 0,
                byMineral: data.per_class_metrics || {}
            };
        } catch (error) {
            console.error('Error fetching metrics:', error);
            // Fallback to local calculation
            return this.calculateLocalMetrics();
        }
    }

    // Fallback: Calculate metrics locally if API fails
    async calculateLocalMetrics() {
        const predictions = await this.loadPredictions();
        
        if (predictions.length === 0) {
            return {
                accuracy: 0,
                precision: 0,
                recall: 0,
                f1Score: 0
            };
        }

        // Calculate per-mineral metrics
        const metrics = {};
        MINERALS.forEach(mineral => {
            const mineralPreds = predictions.filter(p => 
                p.expected?.toLowerCase() === mineral
            );
            
            const truePositive = mineralPreds.filter(p => 
                p.predicted?.toLowerCase() === mineral
            ).length;
            
            const falsePositive = predictions.filter(p => 
                p.predicted?.toLowerCase() === mineral && 
                p.expected?.toLowerCase() !== mineral
            ).length;
            
            const falseNegative = mineralPreds.length - truePositive;

            const precision = truePositive + falsePositive > 0 
                ? truePositive / (truePositive + falsePositive)
                : 0;
            
            const recall = mineralPreds.length > 0
                ? truePositive / mineralPreds.length
                : 0;
            
            const f1 = precision + recall > 0
                ? 2 * (precision * recall) / (precision + recall)
                : 0;

            metrics[mineral] = {
                precision: Math.round(precision * 100),
                recall: Math.round(recall * 100),
                f1: Math.round(f1 * 100)
            };
        });

        // Calculate overall accuracy
        const correct = predictions.filter(p => 
            p.predicted?.toLowerCase() === p.expected?.toLowerCase()
        ).length;
        
        const accuracy = Math.round((correct / predictions.length) * 100);

        // Average metrics
        const avgPrecision = Math.round(
            MINERALS.reduce((sum, m) => sum + metrics[m].precision, 0) / MINERALS.length
        );
        
        const avgRecall = Math.round(
            MINERALS.reduce((sum, m) => sum + metrics[m].recall, 0) / MINERALS.length
        );
        
        const avgF1 = Math.round(
            MINERALS.reduce((sum, m) => sum + metrics[m].f1, 0) / MINERALS.length
        );

        return {
            accuracy,
            precision: avgPrecision,
            recall: avgRecall,
            f1Score: avgF1,
            byMineral: metrics
        };
    }

    // Format timestamp for display
    formatTimestamp(timestamp) {
        const date = new Date(timestamp);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        
        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        
        const diffHours = Math.floor(diffMins / 60);
        if (diffHours < 24) return `${diffHours}h ago`;
        
        const diffDays = Math.floor(diffHours / 24);
        if (diffDays < 7) return `${diffDays}d ago`;
        
        return date.toLocaleDateString();
    }
}

// Export API service instance
const apiService = new APIService(API_BASE_URL);

// Make service available to module scripts that do not import api.js directly.
globalThis.apiService = apiService;
