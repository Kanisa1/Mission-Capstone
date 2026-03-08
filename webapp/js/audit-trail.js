const FALLBACK_API_BASE_URL = 'https://mineraltrace-api.onrender.com';

function resolveApiBaseUrl() {
    const globalUrl = globalThis?.API_BASE_URL;
    return typeof globalUrl === 'string' && globalUrl.trim()
        ? globalUrl.trim()
        : FALLBACK_API_BASE_URL;
}

class AuditTrailPage {
    constructor() {
        this.apiBaseUrl = resolveApiBaseUrl();
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
            const response = await fetch(`${this.apiBaseUrl}/audit-trail/chain?limit=1000`);
            if (!response.ok) {
                throw new Error(`Failed to load blockchain audit trail: ${response.status}`);
            }

            let payload = await response.json();
            let blocks = payload.blocks || [];

            // If empty, trigger one-time backfill from existing records and reload.
            if (blocks.length === 0) {
                try {
                    const backfillResponse = await fetch(`${this.apiBaseUrl}/audit-trail/backfill`, {
                        method: 'POST'
                    });
                    if (backfillResponse.ok) {
                        const reloadResponse = await fetch(`${this.apiBaseUrl}/audit-trail/chain?limit=1000`);
                        if (reloadResponse.ok) {
                            payload = await reloadResponse.json();
                            blocks = payload.blocks || [];
                        }
                    }
                } catch (backfillError) {
                    console.warn('Audit trail backfill fallback failed:', backfillError);
                }
            }

            this.allEvents = blocks.map(block => this.mapBlockToEvent(block));
            this.setChainStatus(payload);

            // Populate user filter
            this.populateUserFilter();

        } catch (error) {
            console.error('Error loading audit trail:', error);
            this.allEvents = [];
            this.setChainStatus(null, error);
        }
    }

    mapBlockToEvent(block) {
        const rawType = (block.event_type || 'system').toLowerCase();
        const type = rawType === 'auth' ? 'user' : rawType;
        const action = String(block.action || 'event').replace(/_/g, ' ');
        const actor = block.actor || 'System';
        const details = block.details || {};

        let icon = 'fa-cube';
        let color = 'info';
        if (type === 'scan' || action.includes('scan') || action.includes('fingerprint')) {
            icon = 'fa-camera';
            color = action.includes('rejected') ? 'error' : 'primary';
        } else if (type === 'verification') {
            icon = 'fa-check-circle';
            color = 'success';
        } else if (type === 'user' || type === 'auth') {
            icon = 'fa-user-shield';
            color = 'info';
        }

        return {
            id: `block_${block.block_index || Date.now()}`,
            type,
            action: this.toTitleCase(action),
            description: `${this.toTitleCase(action)} recorded on immutable audit chain`,
            user: actor,
            timestamp: block.timestamp,
            details: {
                blockIndex: block.block_index,
                source: block.source,
                previousHash: block.previous_hash,
                hash: block.hash,
                ...details
            },
            icon,
            color
        };
    }

    setChainStatus(payload, error = null) {
        const chainStatusEl = document.getElementById('chainStatus');
        const latestHashEl = document.getElementById('latestBlockHash');
        if (!chainStatusEl || !latestHashEl) return;

        if (error || !payload) {
            chainStatusEl.textContent = 'Unavailable';
            chainStatusEl.classList.remove('success');
            latestHashEl.textContent = '--';
            return;
        }

        const isValid = !!payload.chain_valid;
        chainStatusEl.textContent = isValid ? 'Valid' : 'Invalid';
        chainStatusEl.classList.toggle('success', isValid);

        const latestHash = payload.latest_block_hash || '';
        latestHashEl.textContent = latestHash ? `${latestHash.substring(0, 10)}...` : '--';
        latestHashEl.title = latestHash || 'No hash available';
    }

    toTitleCase(value) {
        return String(value || '')
            .split(' ')
            .map(part => part ? part.charAt(0).toUpperCase() + part.slice(1) : part)
            .join(' ');
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

        document.getElementById('verifyChainBtn')?.addEventListener('click', async () => {
            await this.verifyChain();
        });
    }

    async verifyChain() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/audit-trail/chain?limit=1`);
            if (!response.ok) {
                throw new Error(`Chain verification failed: ${response.status}`);
            }

            const payload = await response.json();
            this.setChainStatus(payload);

            const valid = !!payload.chain_valid;
            const message = valid
                ? `Blockchain integrity verified (${payload.total_events || 0} blocks).`
                : `Blockchain integrity failed at block ${payload?.integrity?.invalid_block_index ?? 'unknown'}.`;
            alert(message);
        } catch (error) {
            console.error('Chain verification error:', error);
            alert('Unable to verify blockchain integrity right now.');
        }
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
