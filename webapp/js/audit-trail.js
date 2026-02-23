import { API_BASE_URL } from './config.js';
import { apiService } from './api.js';

class AuditTrailPage {
    constructor() {
        this.allEvents = [];
        this.currentPage = 1;
        this.itemsPerPage = 20;
        this.filters = {
            action: '',
            user: '',
            time: 'all',
            search: ''
        };
    }

    async init() {
        await this.loadData();
        this.setupFilters();
        this.renderTimeline();
        this.updateStats();
    }

    async loadData() {
        try {
            // Fetch fingerprints and users to build audit trail
            const [fingerprints, users] = await Promise.all([
                apiService.getFingerprints(),
                apiService.getUsers()
            ]);

            // Build audit trail from fingerprints
            this.allEvents = [];
            
            fingerprints.forEach(fp => {
                // Scan creation event
                this.allEvents.push({
                    id: `scan_${fp.id}`,
                    type: 'scan',
                    action: 'Scan Created',
                    description: `Fingerprint scan created for ${fp.predicted_mineral || 'unknown mineral'}`,
                    user: fp.user_name || fp.user || 'System',
                    timestamp: fp.timestamp || fp.created_at,
                    details: {
                        mineral: fp.predicted_mineral,
                        confidence: fp.confidence,
                        site: fp.site,
                        modalities: this.getModalities(fp)
                    },
                    icon: 'fa-camera',
                    color: 'primary'
                });

                // Verification event (if verified)
                if (fp.verified !== undefined && fp.verified !== null) {
                    this.allEvents.push({
                        id: `verify_${fp.id}`,
                        type: 'verification',
                        action: fp.verified ? 'Verified' : 'Rejected',
                        description: `Fingerprint ${fp.verified ? 'verified' : 'rejected'} - ${fp.predicted_mineral}`,
                        user: fp.verified_by || 'Regulator',
                        timestamp: fp.verified_at || fp.timestamp,
                        details: {
                            mineral: fp.predicted_mineral,
                            actualMineral: fp.actual_mineral,
                            verificationStatus: fp.verified ? 'Approved' : 'Rejected'
                        },
                        icon: fp.verified ? 'fa-check-circle' : 'fa-times-circle',
                        color: fp.verified ? 'success' : 'error'
                    });
                }
            });

            // User creation events
            users.forEach(user => {
                if (user.created_at) {
                    this.allEvents.push({
                        id: `user_${user.id}`,
                        type: 'user',
                        action: 'User Created',
                        description: `User account created: ${user.name}`,
                        user: 'Admin',
                        timestamp: user.created_at,
                        details: {
                            userName: user.name,
                            userEmail: user.email,
                            role: user.role
                        },
                        icon: 'fa-user-plus',
                        color: 'info'
                    });
                }

                // User update events
                if (user.updated_at && user.updated_at !== user.created_at) {
                    this.allEvents.push({
                        id: `user_update_${user.id}`,
                        type: 'user',
                        action: 'User Updated',
                        description: `User account updated: ${user.name}`,
                        user: 'Admin',
                        timestamp: user.updated_at,
                        details: {
                            userName: user.name,
                            userEmail: user.email,
                            role: user.role
                        },
                        icon: 'fa-user-edit',
                        color: 'info'
                    });
                }
            });

            // Sort by timestamp (most recent first)
            this.allEvents.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

            // Populate user filter
            this.populateUserFilter();

        } catch (error) {
            console.error('Error loading audit trail:', error);
        }
    }

    populateUserFilter() {
        const userFilter = document.getElementById('userFilter');
        if (!userFilter) return;

        // Get unique users
        const users = [...new Set(this.allEvents.map(e => e.user))].sort();
        
        users.forEach(user => {
            const option = document.createElement('option');
            option.value = user;
            option.textContent = user;
            userFilter.appendChild(option);
        });
    }

    setupFilters() {
        // Search input
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.filters.search = e.target.value.toLowerCase();
                this.currentPage = 1;
                this.renderTimeline();
            });
        }

        // Action filter
        const actionFilter = document.getElementById('actionFilter');
        if (actionFilter) {
            actionFilter.addEventListener('change', (e) => {
                this.filters.action = e.target.value;
                this.currentPage = 1;
                this.renderTimeline();
            });
        }

        // User filter
        const userFilter = document.getElementById('userFilter');
        if (userFilter) {
            userFilter.addEventListener('change', (e) => {
                this.filters.user = e.target.value;
                this.currentPage = 1;
                this.renderTimeline();
            });
        }

        // Time filter
        const timeFilter = document.getElementById('timeFilter');
        if (timeFilter) {
            timeFilter.addEventListener('change', (e) => {
                this.filters.time = e.target.value;
                this.currentPage = 1;
                this.renderTimeline();
            });
        }

        // Pagination
        document.getElementById('prevPage')?.addEventListener('click', () => {
            if (this.currentPage > 1) {
                this.currentPage--;
                this.renderTimeline();
            }
        });

        document.getElementById('nextPage')?.addEventListener('click', () => {
            const totalPages = Math.ceil(this.getFilteredEvents().length / this.itemsPerPage);
            if (this.currentPage < totalPages) {
                this.currentPage++;
                this.renderTimeline();
            }
        });
    }

    getFilteredEvents() {
        return this.allEvents.filter(event => {
            // Action type filter
            if (this.filters.action && event.type !== this.filters.action) {
                return false;
            }

            // User filter
            if (this.filters.user && event.user !== this.filters.user) {
                return false;
            }

            // Time filter
            if (this.filters.time !== 'all') {
                const eventDate = new Date(event.timestamp);
                const now = new Date();
                const daysDiff = (now - eventDate) / (1000 * 60 * 60 * 24);

                if (this.filters.time === 'today' && daysDiff > 1) return false;
                if (this.filters.time === 'week' && daysDiff > 7) return false;
                if (this.filters.time === 'month' && daysDiff > 30) return false;
            }

            // Search filter
            if (this.filters.search) {
                const searchText = this.filters.search;
                return (
                    event.action.toLowerCase().includes(searchText) ||
                    event.description.toLowerCase().includes(searchText) ||
                    event.user.toLowerCase().includes(searchText)
                );
            }

            return true;
        });
    }

    renderTimeline() {
        const timeline = document.getElementById('auditTimeline');
        const emptyState = document.getElementById('emptyState');
        
        if (!timeline) return;

        const filteredEvents = this.getFilteredEvents();
        const startIdx = (this.currentPage - 1) * this.itemsPerPage;
        const endIdx = startIdx + this.itemsPerPage;
        const paginatedEvents = filteredEvents.slice(startIdx, endIdx);

        if (paginatedEvents.length === 0) {
            timeline.style.display = 'none';
            emptyState.style.display = 'flex';
            return;
        }

        timeline.style.display = 'block';
        emptyState.style.display = 'none';
        timeline.innerHTML = '';

        paginatedEvents.forEach(event => {
            const item = this.createTimelineItem(event);
            timeline.appendChild(item);
        });

        this.updatePagination(filteredEvents.length);
    }

    createTimelineItem(event) {
        const div = document.createElement('div');
        div.className = 'audit-item';
        
        const formattedDate = this.formatTimestamp(event.timestamp);
        const detailsHtml = this.formatDetails(event.details);

        div.innerHTML = `
            <div class="audit-icon ${event.color}">
                <i class="fas ${event.icon}"></i>
            </div>
            <div class="audit-content">
                <div class="audit-header">
                    <div class="audit-title">
                        <strong>${event.action}</strong>
                        <span class="audit-type">${event.type}</span>
                    </div>
                    <div class="audit-meta">
                        <span class="audit-user">
                            <i class="fas fa-user"></i> ${event.user}
                        </span>
                        <span class="audit-time">
                            <i class="fas fa-clock"></i> ${formattedDate}
                        </span>
                    </div>
                </div>
                <p class="audit-description">${event.description}</p>
                ${detailsHtml}
            </div>
        `;

        return div;
    }

    formatDetails(details) {
        if (!details || Object.keys(details).length === 0) return '';

        let html = '<div class="audit-details">';
        for (const [key, value] of Object.entries(details)) {
            if (value !== undefined && value !== null) {
                const label = key.replace(/([A-Z])/g, ' $1').replace(/^./, str => str.toUpperCase());
                html += `<span class="detail-item"><strong>${label}:</strong> ${value}</span>`;
            }
        }
        html += '</div>';
        return html;
    }

    formatTimestamp(timestamp) {
        if (!timestamp) return 'Unknown';
        
        const date = new Date(timestamp);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins} minute${diffMins !== 1 ? 's' : ''} ago`;
        if (diffHours < 24) return `${diffHours} hour${diffHours !== 1 ? 's' : ''} ago`;
        if (diffDays < 7) return `${diffDays} day${diffDays !== 1 ? 's' : ''} ago`;
        
        return date.toLocaleString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    getModalities(fp) {
        const modalities = [];
        if (fp.image_path) modalities.push('Image');
        if (fp.audio_path) modalities.push('Audio');
        if (fp.chemical_features || fp.chemical_fingerprint) modalities.push('Chemical');
        return modalities.join(', ') || 'None';
    }

    updatePagination(totalItems) {
        const totalPages = Math.ceil(totalItems / this.itemsPerPage);
        const startItem = totalItems === 0 ? 0 : (this.currentPage - 1) * this.itemsPerPage + 1;
        const endItem = Math.min(this.currentPage * this.itemsPerPage, totalItems);

        document.getElementById('totalItems').textContent = totalItems;
        document.getElementById('startItem').textContent = startItem;
        document.getElementById('endItem').textContent = endItem;
        document.getElementById('currentPage').textContent = this.currentPage;
        document.getElementById('totalPages').textContent = totalPages;

        const prevBtn = document.getElementById('prevPage');
        const nextBtn = document.getElementById('nextPage');
        
        if (prevBtn) prevBtn.disabled = this.currentPage === 1;
        if (nextBtn) nextBtn.disabled = this.currentPage >= totalPages;
    }

    updateStats() {
        document.getElementById('totalEvents').textContent = this.allEvents.length;
        
        // Count today's events
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const todayEvents = this.allEvents.filter(e => {
            const eventDate = new Date(e.timestamp);
            return eventDate >= today;
        }).length;
        
        document.getElementById('todayEvents').textContent = todayEvents;
    }
}

// Initialize page
const auditTrail = new AuditTrailPage();
auditTrail.init();
