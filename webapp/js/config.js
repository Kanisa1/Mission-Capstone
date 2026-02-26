// API Configuration
const API_BASE_URL = 'http://127.0.0.1:8000';

const API_ENDPOINTS = {
    predict: `${API_BASE_URL}/predict`,
    fingerprint: `${API_BASE_URL}/fingerprint`,
    verify: `${API_BASE_URL}/verify`,
    health: `${API_BASE_URL}/`
};

// Chart.js default configuration
Chart.defaults.font.family = "'Inter', sans-serif";
Chart.defaults.font.size = 12;
Chart.defaults.color = '#6B7280';

// Application constants
const MINERALS = ['gold', 'chalcopyrite', 'hematite'];
const SITES = ['Kapoeta_East', 'Central_Equatoria', 'Yei_River'];
const REFRESH_INTERVAL = 30000; // 30 seconds
