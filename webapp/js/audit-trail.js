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
                anchorStatus: block.anchor_status,
                anchorTxHash: block.anchor_tx_hash,
                anchorChainId: block.anchor_chain_id,
                anchorExplorerUrl: block.anchor_explorer_url,
                anchorError: block.anchor_error,
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

        userFilter.innerHTML = '<option value="">All Users</option>';

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

        document.getElementById('anchorMissingBtn')?.addEventListener('click', async () => {
            await this.anchorMissingEntries();
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

    async anchorMissingEntries() {
        const ok = confirm('Anchor missing records to blockchain? This submits real transactions and consumes testnet gas.');
        if (!ok) return;

        const button = document.getElementById('anchorMissingBtn');
        const originalLabel = button ? button.innerHTML : null;

        try {
            if (button) {
                button.disabled = true;
                button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Anchoring...';
            }

            const response = await fetch(`${this.apiBaseUrl}/audit-trail/anchor-missing?limit=20`, {
                method: 'POST'
            });
            if (!response.ok) {
                throw new Error(`Anchor migration failed: ${response.status}`);
            }

            const payload = await response.json();
            await this.loadData();
            this.currentPage = 1;
            this.renderTimeline();
            this.updateStats();

            alert(
                `Anchor migration complete.\n` +
                `Processed: ${payload.processed || 0}\n` +
                `Submitted: ${payload.submitted || 0}\n` +
                `Failed: ${payload.failed || 0}\n` +
                `Remaining: ${payload.remaining || 0}`
            );
        } catch (error) {
            console.error('Anchor migration error:', error);
            alert('Unable to anchor missing records right now.');
        } finally {
            if (button) {
                button.disabled = false;
                button.innerHTML = originalLabel || 'Anchor Missing';
            }
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
        
        // Attach event listeners to export buttons after rendering
        this.attachExportListeners();
    }

    createTimelineItem(event) {
        const div = document.createElement('div');
        div.className = 'audit-item';

        const formattedDate = this.formatTimestamp(event.timestamp);
        const anchorHtml = this.formatAnchorBadge(event.details);
        const detailsHtml = this.formatDetails(event.details);
        const durationHtml = this.formatActionDuration(event.details);
        const verificationHtml = this.formatHashVerification(event.details);
        const exportBtn = this.createExportButton(event);

        div.innerHTML = `
            <div class="audit-icon ${event.color}">
                <i class="fas ${event.icon}"></i>
            </div>
            <div class="audit-content">
                <div class="audit-header">
                    <div class="audit-title">
                        <strong>${event.action}</strong>
                        <span class="audit-type">${event.type}</span>
                        ${verificationHtml}
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
                ${anchorHtml}
                ${durationHtml}
                ${detailsHtml}
                <div class="audit-actions">
                    ${exportBtn}
                </div>
            </div>
        `;

        // Add click handler for expandable details
        const detailsSection = div.querySelector('.audit-details-section');
        if (detailsSection) {
            const toggleBtn = div.querySelector('.details-toggle');
            if (toggleBtn) {
                toggleBtn.addEventListener('click', (e) => {
                    e.preventDefault();
                    detailsSection.classList.toggle('expanded');
                    toggleBtn.classList.toggle('expanded');
                });
            }
        }

        return div;
    }

    formatAnchorBadge(details) {
        const ANCHOR_KEYS = new Set(['anchorStatus', 'anchorTxHash', 'anchorChainId', 'anchorExplorerUrl', 'anchorError', 'anchorEnabled']);
        if (!details || !Object.keys(details).some(k => ANCHOR_KEYS.has(k))) return '';

        const status = details.anchorStatus || null;
        if (!status || status === 'disabled') return '';

        const statusMap = {
            submitted:         { cls: 'anchor-badge--submitted', icon: 'fa-check-circle',   label: 'Anchored on-chain' },
            failed:            { cls: 'anchor-badge--failed',    icon: 'fa-times-circle',   label: 'Anchor failed' },
            skipped_bootstrap: { cls: 'anchor-badge--skipped',   icon: 'fa-minus-circle',   label: 'Anchor skipped (bootstrap)' },
        };
        const { cls, icon, label } = statusMap[status] || { cls: 'anchor-badge--pending', icon: 'fa-hourglass-half', label: status };

        const txHash  = details.anchorTxHash   ? String(details.anchorTxHash) : null;
        const explorerUrl = details.anchorExplorerUrl ? String(details.anchorExplorerUrl) : null;
        const chainId = details.anchorChainId !== undefined && details.anchorChainId !== null
            ? `Chain ${details.anchorChainId}` : null;
        const errMsg  = details.anchorError ? String(details.anchorError) : null;

        const shortTx = txHash ? `${txHash.slice(0, 10)}...${txHash.slice(-6)}` : null;
        const explorerLink = explorerUrl && txHash
            ? `<a class="anchor-tx-link" href="${explorerUrl}" target="_blank" rel="noopener noreferrer">
                   <i class="fas fa-external-link-alt"></i> ${shortTx}
               </a>`
            : (shortTx ? `<span class="anchor-tx-link">${shortTx}</span>` : '');
        const chainBadge = chainId ? `<span class="anchor-chain">${chainId}</span>` : '';
        const errorHtml  = errMsg  ? `<span class="anchor-error-msg"><i class="fas fa-exclamation-triangle"></i> ${errMsg}</span>` : '';

        return `<div class="anchor-badge ${cls}">
            <i class="fas ${icon}"></i>
            <span class="anchor-badge-label">${label}</span>
            ${explorerLink}
            ${chainBadge}
            ${errorHtml}
        </div>`;
    }

    formatHashVerification(details) {
        if (!details || !details.hash) return '';
        
        const hash = String(details.hash);
        const isVerified = details.anchorStatus === 'submitted';
        
        const badge = isVerified 
            ? `<span class="hash-verification verified" title="Hash verified on blockchain">
                   <i class="fas fa-shield-alt"></i> Verified
               </span>`
            : `<span class="hash-verification pending" title="Hash pending blockchain verification">
                   <i class="fas fa-clock"></i> Pending
               </span>`;
        
        return badge;
    }

    formatActionDuration(details) {
        if (!details) return '';
        
        // Since timestamps are typically based on action, this shows pending
        // For actual duration tracking, you would need blockchain timestamp data
        // This is a placeholder that shows when blockchain integration is ready
        return '';
    }

    createExportButton(event) {
        const blockIndex = event.details.blockIndex || Date.now();
        
        const btnId = `export-btn-${blockIndex}`;
        const htmlBtn = `<button id="${btnId}" class="btn-export-audit" title="Export this audit record as PDF">
            <i class="fas fa-file-pdf"></i> Export PDF
        </button>`;
        
        this.pendingExports = this.pendingExports || {};
        this.pendingExports[btnId] = event;
        
        return htmlBtn;
    }

    attachExportListeners() {
        if (!this.pendingExports) return;
        
        for (const [btnId, event] of Object.entries(this.pendingExports)) {
            const btn = document.getElementById(btnId);
            if (btn) {
                btn.addEventListener('click', () => {
                    this.generateAuditPDF(event);
                });
            }
        }
        
        this.pendingExports = {};
    }

    generateAuditPDF(event) {
        const blockIndex = event.details.blockIndex || Date.now();
        const timestamp = new Date(event.timestamp).toLocaleString();

        // Create a container to hold canvas elements temporarily
        const container = document.createElement('div');
        container.style.display = 'none';
        document.body.appendChild(container);

        // Create Status Chart (Canvas) - Smaller for one-page layout
        const statusChartCanvas = document.createElement('canvas');
        statusChartCanvas.width = 200;
        statusChartCanvas.height = 120;
        container.appendChild(statusChartCanvas);

        const statusCtx = statusChartCanvas.getContext('2d');
        const statusChart = new Chart(statusCtx, {
            type: 'doughnut',
            data: {
                labels: ['Verified', 'Pending'],
                datasets: [{
                    data: [event.details.anchorStatus === 'submitted' ? 100 : 0, event.details.anchorStatus === 'submitted' ? 0 : 100],
                    backgroundColor: ['#2E8B6E', '#F59E0B'],
                    borderColor: ['#2E8B6E', '#F59E0B'],
                    borderWidth: 2
                }]
            },
            options: {
                responsive: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            font: { size: 9, family: 'Arial' },
                            padding: 8
                        }
                    },
                    tooltip: {
                        enabled: true
                    }
                }
            }
        });

        // Create Event Type Distribution Chart - Smaller for one-page layout
        const typeChartCanvas = document.createElement('canvas');
        typeChartCanvas.width = 200;
        typeChartCanvas.height = 120;
        container.appendChild(typeChartCanvas);

        const typeCtx = typeChartCanvas.getContext('2d');
        const typeChart = new Chart(typeCtx, {
            type: 'bar',
            data: {
                labels: [event.type.toUpperCase()],
                datasets: [{
                    label: 'Count',
                    data: [1],
                    backgroundColor: ['#0A3552'],
                    borderColor: ['#0A3552'],
                    borderWidth: 0,
                    borderRadius: 2
                }]
            },
            options: {
                responsive: false,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        enabled: true
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 1,
                        ticks: {
                            font: { size: 8 },
                            stepSize: 0.5
                        },
                        grid: {
                            drawBorder: true,
                            color: '#eee'
                        }
                    },
                    x: {
                        ticks: {
                            font: { size: 8 }
                        },
                        grid: {
                            display: false
                        }
                    }
                }
            }
        });

        // Wait for charts to render then export
        setTimeout(() => {
            const statusChartImage = statusChartCanvas.toDataURL('image/png');
            const typeChartImage = typeChartCanvas.toDataURL('image/png');

            const htmlContent = `
                <div style="font-family: Arial, sans-serif; padding: 12px; color: #333; font-size: 13px;">
                    <div style="text-align: center; border-bottom: 2px solid #0A3552; padding-bottom: 8px; margin-bottom: 10px;">
                        <h1 style="margin: 0; color: #0A3552; font-size: 18px;">MineralTrace Audit Report</h1>
                        <p style="margin: 5px 0 0 0; color: #666; font-size: 10px;">Blockchain-Backed Audit Trail</p>
                    </div>
                    
                    <div style="background: #f9f9f9; padding: 8px; border-radius: 4px; margin-bottom: 8px;">
                        <h2 style="color: #0A3552; font-size: 12px; margin: 0 0 6px 0;">Event Summary</h2>
                        <table style="width: 100%; border-collapse: collapse; font-size: 11px;" border="0">
                            <tr><td style="padding: 3px 0; border-bottom: 1px solid #ddd; font-weight: bold; width: 30%;">Action:</td><td style="padding: 3px 0; border-bottom: 1px solid #ddd;">${event.action}</td></tr>
                            <tr><td style="padding: 3px 0; border-bottom: 1px solid #ddd; font-weight: bold;">Actor:</td><td style="padding: 3px 0; border-bottom: 1px solid #ddd;">${event.user}</td></tr>
                            <tr><td style="padding: 3px 0; border-bottom: 1px solid #ddd; font-weight: bold;">Type:</td><td style="padding: 3px 0; border-bottom: 1px solid #ddd;"><span style="display: inline-block; background: #0A3552; color: white; padding: 2px 6px; border-radius: 2px; font-size: 9px; font-weight: bold;">${event.type.toUpperCase()}</span></td></tr>
                        </table>
                    </div>
                    
                    <div style="background: #f9f9f9; padding: 8px; border-radius: 4px; margin-bottom: 8px;">
                        <h2 style="color: #0A3552; font-size: 12px; margin: 0 0 6px 0;">Blockchain Verification</h2>
                        <table style="width: 100%; border-collapse: collapse; font-size: 11px;" border="0">
                            <tr>
                                <td style="padding: 3px 0; border-bottom: 1px solid #ddd; font-weight: bold; width: 30%;">Status:</td>
                                <td style="padding: 3px 0; border-bottom: 1px solid #ddd;">
                                    ${event.details.anchorStatus === 'submitted' ? '<span style="color: #2E8B6E; font-weight: bold;">✓ VERIFIED</span>' : '<span style="color: #F59E0B; font-weight: bold;">⊘ PENDING</span>'}
                                </td>
                            </tr>
                            <tr><td style="padding: 3px 0; border-bottom: 1px solid #ddd; font-weight: bold;">Chain:</td><td style="padding: 3px 0; border-bottom: 1px solid #ddd;">Chain ${event.details.anchorChainId || 'N/A'}</td></tr>
                            <tr><td style="padding: 3px 0; border-bottom: 1px solid #ddd; font-weight: bold;">TxHash:</td><td style="padding: 3px 0; border-bottom: 1px solid #ddd; font-family: monospace; font-size: 9px;">${event.details.anchorTxHash ? event.details.anchorTxHash.substring(0, 30) + '...' : 'N/A'}</td></tr>
                        </table>
                    </div>
                    
                    <div style="display: flex; gap: 10px; margin-bottom: 8px;">
                        <div style="flex: 1; background: #f9f9f9; padding: 8px; border-radius: 4px; text-align: center;">
                            <h3 style="color: #0A3552; font-size: 11px; margin: 0 0 4px 0;">Status</h3>
                            <img src="${statusChartImage}" style="width: 100%; height: auto;" />
                        </div>
                        <div style="flex: 1; background: #f9f9f9; padding: 8px; border-radius: 4px; text-align: center;">
                            <h3 style="color: #0A3552; font-size: 11px; margin: 0 0 4px 0;">Event Type</h3>
                            <img src="${typeChartImage}" style="width: 100%; height: auto;" />
                        </div>
                    </div>
                    
                    <div style="text-align: center; padding-top: 8px; border-top: 1px solid #ddd; color: #999; font-size: 9px;">
                        <p style="margin: 0;">Generated: ${new Date().toLocaleString()} • Block #${blockIndex}</p>
                    </div>
                </div>
            `;

            const element = document.createElement('div');
            element.innerHTML = htmlContent;
            
            const options = {
                margin: 5,
                filename: `audit-report-${blockIndex}.pdf`,
                image: { type: 'jpeg', quality: 0.98 },
                html2canvas: { scale: 2 },
                jsPDF: { orientation: 'portrait', unit: 'mm', format: 'a4' }
            };

            html2pdf().set(options).from(element).save();
            
            // Cleanup
            document.body.removeChild(container);
        }, 500);
    }

    formatDetails(details) {
        const ANCHOR_KEYS = new Set(['anchorStatus', 'anchorTxHash', 'anchorChainId', 'anchorExplorerUrl', 'anchorError', 'anchorEnabled']);
        if (!details || Object.keys(details).length === 0) return '';

        let html = '';
        let detailItems = [];
        
        for (const [key, value] of Object.entries(details)) {
            if (ANCHOR_KEYS.has(key)) continue;
            if (value === undefined || value === null) continue;

            const label = key.replace(/([A-Z])/g, ' $1').replace(/^./, str => str.toUpperCase());
            let renderedValue = String(value);
            if ((key === 'hash' || key === 'previousHash') && renderedValue.length > 18) {
                renderedValue = `${renderedValue.slice(0, 12)}...${renderedValue.slice(-6)}`;
            }
            detailItems.push(`<span class="detail-item"><strong>${label}:</strong> ${renderedValue}</span>`);
        }

        if (detailItems.length === 0) return '';

        html = `<div class="audit-details-section">
                    <button class="details-toggle" title="Show/hide details">
                        <i class="fas fa-chevron-down"></i> Show Details
                    </button>
                    <div class="audit-details">
                        ${detailItems.join('')}
                    </div>
                </div>`;
        
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
