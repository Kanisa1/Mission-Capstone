// API Configuration
const API_BASE_URL = (() => {
    const runtimeOverride = globalThis.__API_BASE_URL__;
    if (typeof runtimeOverride === 'string' && runtimeOverride.trim()) {
        return runtimeOverride.trim().replace(/\/$/, '');
    }

    const isLocalHost = ['localhost', '127.0.0.1'].includes(window.location.hostname);
    if (isLocalHost) {
        return 'http://127.0.0.1:8000';
    }

    const host = window.location.hostname;
    if (host.endsWith('.onrender.com') && host.includes('-web')) {
        return `${window.location.protocol}//${host.replace('-web', '-api')}`;
    }

    return 'https://mineraltrace-api.onrender.com';
})();

const API_ENDPOINTS = {
    predict: `${API_BASE_URL}/predict`,
    fingerprint: `${API_BASE_URL}/fingerprint`,
    verify: `${API_BASE_URL}/verify`,
    health: `${API_BASE_URL}/`
};

// Application constants
const MINERALS = ['gold', 'chalcopyrite', 'hematite'];
const SITES = ['Kapoeta_East', 'Central_Equatoria', 'Yei_River'];
const REFRESH_INTERVAL = 30000; // 30 seconds

// Chart.js default configuration
if (window.Chart?.defaults) {
    Chart.defaults.font.family = "'Inter', sans-serif";
    Chart.defaults.font.size = 12;
    Chart.defaults.color = '#6B7280';
}
