// API Configuration
const DEPLOYED_API_BASE_URL = 'https://mineraltrace-api.onrender.com';

const API_BASE_URL = (() => {
    const runtimeOverride = globalThis.__API_BASE_URL__;
    if (typeof runtimeOverride === 'string' && runtimeOverride.trim()) {
        return runtimeOverride.trim().replace(/\/$/, '');
    }

    const isLocalHost = ['localhost', '127.0.0.1'].includes(window.location.hostname);
    if (isLocalHost) {
        // When previewing the static webapp locally, use the deployed backend by default.
        return DEPLOYED_API_BASE_URL;
    }

    const host = window.location.hostname;
    if (host.endsWith('.onrender.com') && host.includes('-web')) {
        return `${window.location.protocol}//${host.replace('-web', '-api')}`;
    }

    return DEPLOYED_API_BASE_URL;
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

// Expose runtime config for both classic scripts and ES modules.
globalThis.API_BASE_URL = API_BASE_URL;
globalThis.API_ENDPOINTS = API_ENDPOINTS;
globalThis.MINERALS = MINERALS;
globalThis.SITES = SITES;
globalThis.REFRESH_INTERVAL = REFRESH_INTERVAL;

// Chart.js default configuration
if (window.Chart?.defaults) {
    Chart.defaults.font.family = "'Inter', sans-serif";
    Chart.defaults.font.size = 12;
    Chart.defaults.color = '#6B7280';
}
