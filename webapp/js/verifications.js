// Verifications Page Management
class VerificationsPage {
    constructor() {
        this.currentPage = 1;
        this.pageSize = 20;
        this.allVerifications = [];
        this.filteredVerifications = [];
        this.filters = {
            site: '',
            status: '',
            search: ''
        };
    }

    // Initialize page
    async init() {
        this.showLoading(true);
        
        try {
            await this.loadVerifications();
            this.setupEventListeners();
            this.renderTable();
            this.updateStats();
        } catch (error) {
            console.error('Failed to initialize verifications page:', error);
            this.showError('Failed to load verifications');
        } finally {
            this.showLoading(false);
        }
    }

    // Load verifications from API
    async loadVerifications() {
        try {
            const response = await fetch(`${API_BASE_URL}/verifications`);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const data = await response.json();
            this.allVerifications = data.verifications || [];
            this.filteredVerifications = [...this.allVerifications];
        } catch (error) {
            console.error('Error loading verifications:', error);
            this.allVerifications = [];
            this.filteredVerifications = [];
        }
    }

    // Setup event listeners
    setupEventListeners() {
        // Search input
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.filters.search = e.target.value.toLowerCase();
                this.applyFilters();
            });
        }

        // Site filter
        const siteFilter = document.getElementById('siteFilter');
        if (siteFilter) {
            siteFilter.addEventListener('change', (e) => {
                this.filters.site = e.target.value;
                this.applyFilters();
            });
        }

        // Status filter
        const statusFilter = document.getElementById('statusFilter');
        if (statusFilter) {
            statusFilter.addEventListener('change', (e) => {
                this.filters.status = e.target.value;
                this.applyFilters();
            });
        }

        // Pagination
        const prevBtn = document.getElementById('prevPage');
        const nextBtn = document.getElementById('nextPage');
        
        if (prevBtn) {
            prevBtn.addEventListener('click', () => this.previousPage());
        }
        
        if (nextBtn) {
            nextBtn.addEventListener('click', () => this.nextPage());
        }
    }

    // Apply filters
    applyFilters() {
        this.filteredVerifications = this.allVerifications.filter(verification => {
            // Site filter
            if (this.filters.site && verification.site !== this.filters.site) {
                return false;
            }

            // Status filter
            if (this.filters.status && verification.status !== this.filters.status) {
                return false;
            }

            // Search filter (searches in sample_id, mineral, site, user_name)
            if (this.filters.search) {
                const searchText = this.filters.search;
                const matchesSearch = 
                    (verification.id && verification.id.toLowerCase().includes(searchText)) ||
                    (verification.mineral && verification.mineral.toLowerCase().includes(searchText)) ||
                    (verification.site && verification.site.toLowerCase().includes(searchText)) ||
                    (verification.user_name && verification.user_name.toLowerCase().includes(searchText));
                
                if (!matchesSearch) {
                    return false;
                }
            }

            return true;
        });

        this.currentPage = 1;
        this.renderTable();
        this.updateStats();
    }

    // Render table
    renderTable() {
        const tbody = document.getElementById('verificationsTableBody');
        if (!tbody) return;

        // Calculate pagination
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        const pageData = this.filteredVerifications.slice(startIndex, endIndex);

        // Clear table
        tbody.innerHTML = '';

        if (pageData.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="9" style="text-align: center; padding: 3rem;">
                        <i class="fas fa-inbox" style="font-size: 48px; color: #9CA3AF; margin-bottom: 1rem;"></i>
                        <p style="color: #6B7280;">No verifications found</p>
                    </td>
                </tr>
            `;
            this.updatePagination();
            return;
        }

        // Render rows
        pageData.forEach(verification => {
            const row = this.createTableRow(verification);
            tbody.appendChild(row);
        });

        this.updatePagination();
    }

    // Create table row
    createTableRow(verification) {
        const tr = document.createElement('tr');
        
        // Format timestamp
        const date = new Date(verification.timestamp);
        const formattedDate = date.toLocaleString('en-US', { 
            month: 'short', 
            day: 'numeric', 
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });

        // Status badge
        const statusBadge = this.getStatusBadge(verification.status);
        
        // Confidence display
        const confidence = verification.confidence !== null && verification.confidence !== undefined
            ? `${Math.round(verification.confidence * 100)}%`
            : 'N/A';

        // Site display name
        const siteDisplay = verification.site ? verification.site.replace(/_/g, ' ') : 'Unknown';

        tr.innerHTML = `
            <td>${formattedDate}</td>
            <td><code>${verification.id || 'N/A'}</code></td>
            <td>${siteDisplay}</td>
            <td>
                <span class="mineral-badge ${verification.mineral?.toLowerCase()}">${verification.mineral || 'N/A'}</span>
            </td>
            <td>
                <span class="mineral-badge ${verification.predicted_mineral?.toLowerCase()}">${verification.predicted_mineral || 'N/A'}</span>
            </td>
            <td>
                <span class="confidence-badge ${this.getConfidenceClass(verification.confidence)}">${confidence}</span>
            </td>
            <td>${verification.user_name || 'Unknown'}</td>
            <td>${statusBadge}</td>
            <td>
                <button class="btn-icon" onclick="verificationsPage.viewDetails('${verification.id}')" title="View Details">
                    <i class="fas fa-eye"></i>
                </button>
            </td>
        `;

        return tr;
    }

    // Get status badge HTML
    getStatusBadge(status) {
        const badges = {
            verified: '<span class="status-badge verified"><i class="fas fa-check-circle"></i> Verified</span>',
            pending: '<span class="status-badge pending"><i class="fas fa-clock"></i> Pending</span>',
            notVerified: '<span class="status-badge not-verified"><i class="fas fa-times-circle"></i> Not Verified</span>'
        };
        return badges[status] || '<span class="status-badge">Unknown</span>';
    }

    // Get confidence class
    getConfidenceClass(confidence) {
        if (confidence === null || confidence === undefined) return 'na';
        if (confidence >= 0.8) return 'high';
        if (confidence >= 0.6) return 'medium';
        return 'low';
    }

    // Update pagination
    updatePagination() {
        const totalPages = Math.ceil(this.filteredVerifications.length / this.pageSize);
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = Math.min(startIndex + this.pageSize, this.filteredVerifications.length);

        // Update info
        document.getElementById('showingStart').textContent = this.filteredVerifications.length > 0 ? startIndex + 1 : 0;
        document.getElementById('showingEnd').textContent = endIndex;
        document.getElementById('totalRecords').textContent = this.filteredVerifications.length;
        document.getElementById('currentPage').textContent = this.currentPage;
        document.getElementById('totalPages').textContent = totalPages || 1;

        // Update buttons
        const prevBtn = document.getElementById('prevPage');
        const nextBtn = document.getElementById('nextPage');
        
        if (prevBtn) prevBtn.disabled = this.currentPage === 1;
        if (nextBtn) nextBtn.disabled = this.currentPage >= totalPages;
    }

    // Update stats
    updateStats() {
        const verified = this.allVerifications.filter(v => v.status === 'verified').length;
        const pending = this.allVerifications.filter(v => v.status === 'pending').length;
        
        document.getElementById('totalCount').textContent = this.allVerifications.length;
        document.getElementById('verifiedCount').textContent = verified;
        document.getElementById('pendingCount').textContent = pending;
    }

    // Pagination methods
    previousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.renderTable();
        }
    }

    nextPage() {
        const totalPages = Math.ceil(this.filteredVerifications.length / this.pageSize);
        if (this.currentPage < totalPages) {
            this.currentPage++;
            this.renderTable();
        }
    }

    // View details
    viewDetails(sampleId) {
        const verification = this.allVerifications.find(v => v.id === sampleId);
        if (verification) {
            alert(`Sample ID: ${verification.id}\nMineral: ${verification.mineral}\nPredicted: ${verification.predicted_mineral}\nConfidence: ${verification.confidence ? (verification.confidence * 100).toFixed(2) + '%' : 'N/A'}\nSite: ${verification.site}\nUser: ${verification.user_name}\nStatus: ${verification.status}`);
        }
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
let verificationsPage;

document.addEventListener('DOMContentLoaded', () => {
    verificationsPage = new VerificationsPage();
    verificationsPage.init();
});
