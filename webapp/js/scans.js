// Scans Page Management
class ScansPage {
    constructor() {
        this.currentPage = 1;
        this.pageSize = 20;
        this.allScans = [];
        this.filteredScans = [];
        this.filters = {
            site: '',
            mineral: '',
            search: ''
        };
    }

    // Initialize page
    async init() {
        this.showLoading(true);
        
        try {
            await this.loadScans();
            this.setupEventListeners();
            this.renderTable();
            this.updateStats();
        } catch (error) {
            console.error('Failed to initialize scans page:', error);
            this.showError('Failed to load scans');
        } finally {
            this.showLoading(false);
        }
    }

    // Load scans from API
    async loadScans() {
        try {
            const response = await fetch(`${API_BASE_URL}/fingerprints`);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const data = await response.json();
            this.allScans = data.fingerprints || [];
            this.filteredScans = [...this.allScans];
        } catch (error) {
            console.error('Error loading scans:', error);
            this.allScans = [];
            this.filteredScans = [];
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

        // Mineral filter
        const mineralFilter = document.getElementById('mineralFilter');
        if (mineralFilter) {
            mineralFilter.addEventListener('change', (e) => {
                this.filters.mineral = e.target.value.toLowerCase();
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
        this.filteredScans = this.allScans.filter(scan => {
            // Site filter
            if (this.filters.site && scan.site !== this.filters.site) {
                return false;
            }

            // Mineral filter
            if (this.filters.mineral && scan.mineral?.toLowerCase() !== this.filters.mineral) {
                return false;
            }

            // Search filter
            if (this.filters.search) {
                const searchText = this.filters.search;
                const matchesSearch = 
                    (scan.sample_id && scan.sample_id.toLowerCase().includes(searchText)) ||
                    (scan.mineral && scan.mineral.toLowerCase().includes(searchText)) ||
                    (scan.site && scan.site.toLowerCase().includes(searchText)) ||
                    (scan.user_name && scan.user_name.toLowerCase().includes(searchText));
                
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
        const tbody = document.getElementById('scansTableBody');
        if (!tbody) return;

        // Calculate pagination
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        const pageData = this.filteredScans.slice(startIndex, endIndex);

        // Clear table
        tbody.innerHTML = '';

        if (pageData.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="10" style="text-align: center; padding: 3rem;">
                        <i class="fas fa-inbox" style="font-size: 48px; color: #9CA3AF; margin-bottom: 1rem;"></i>
                        <p style="color: #6B7280;">No scans found</p>
                    </td>
                </tr>
            `;
            this.updatePagination();
            return;
        }

        // Render rows
        pageData.forEach(scan => {
            const row = this.createTableRow(scan);
            tbody.appendChild(row);
        });

        this.updatePagination();
    }

    // Create table row
    createTableRow(scan) {
        const tr = document.createElement('tr');
        
        // Format timestamp
        const date = new Date(scan.timestamp);
        const formattedDate = date.toLocaleString('en-US', { 
            month: 'short', 
            day: 'numeric', 
            hour: '2-digit',
            minute: '2-digit'
        });

        // Confidence display
        const confidence = scan.confidence !== null && scan.confidence !== undefined
            ? `${Math.round(scan.confidence * 100)}%`
            : 'N/A';

        // Modalities used
        const modalities = scan.modalities_used || {};
        const modalityIcons = [];
        if (modalities.image) modalityIcons.push('<i class="fas fa-image" title="Image"></i>');
        if (modalities.audio) modalityIcons.push('<i class="fas fa-volume-up" title="Audio"></i>');
        if (modalities.chemical) modalityIcons.push('<i class="fas fa-flask" title="Chemical"></i>');
        const modalityDisplay = modalityIcons.length > 0 ? modalityIcons.join(' ') : 'N/A';

        // GPS coordinates
        const gps = scan.gps;
        const gpsDisplay = gps && gps.latitude && gps.longitude
            ? `<a href="https://www.google.com/maps?q=${gps.latitude},${gps.longitude}" target="_blank" title="View on map">
                   <i class="fas fa-map-marker-alt"></i>
               </a>`
            : 'N/A';

        // Site display name
        const siteDisplay = scan.site ? scan.site.replace(/_/g, ' ') : 'Unknown';

        tr.innerHTML = `
            <td>${formattedDate}</td>
            <td><code>${scan.sample_id || 'N/A'}</code></td>
            <td>${siteDisplay}</td>
            <td>
                <span class="mineral-badge ${scan.mineral?.toLowerCase()}">${scan.mineral || 'N/A'}</span>
            </td>
            <td>
                <span class="mineral-badge ${scan.predicted_mineral?.toLowerCase()}">${scan.predicted_mineral || 'N/A'}</span>
            </td>
            <td>
                <span class="confidence-badge ${this.getConfidenceClass(scan.confidence)}">${confidence}</span>
            </td>
            <td style="font-size: 16px;">${modalityDisplay}</td>
            <td style="font-size: 16px;">${gpsDisplay}</td>
            <td>${scan.user_name || 'Unknown'}</td>
            <td>
                <button class="btn-icon" onclick="scansPage.viewDetails('${scan.sample_id}')" title="View Details">
                    <i class="fas fa-eye"></i>
                </button>
            </td>
        `;

        return tr;
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
        const totalPages = Math.ceil(this.filteredScans.length / this.pageSize);
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = Math.min(startIndex + this.pageSize, this.filteredScans.length);

        // Update info
        document.getElementById('showingStart').textContent = this.filteredScans.length > 0 ? startIndex + 1 : 0;
        document.getElementById('showingEnd').textContent = endIndex;
        document.getElementById('totalRecords').textContent = this.filteredScans.length;
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
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        
        const todayScans = this.allScans.filter(scan => {
            const scanDate = new Date(scan.timestamp);
            scanDate.setHours(0, 0, 0, 0);
            return scanDate.getTime() === today.getTime();
        }).length;
        
        document.getElementById('totalCount').textContent = this.allScans.length;
        document.getElementById('todayCount').textContent = todayScans;
    }

    // Pagination methods
    previousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.renderTable();
        }
    }

    nextPage() {
        const totalPages = Math.ceil(this.filteredScans.length / this.pageSize);
        if (this.currentPage < totalPages) {
            this.currentPage++;
            this.renderTable();
        }
    }

    // View details
    viewDetails(sampleId) {
        const scan = this.allScans.find(s => s.sample_id === sampleId);
        if (scan) {
            const gpsInfo = scan.gps && scan.gps.latitude && scan.gps.longitude
                ? `GPS: ${scan.gps.latitude.toFixed(6)}, ${scan.gps.longitude.toFixed(6)}\n`
                : '';
            
            const modalitiesUsed = scan.modalities_used || {};
            const modsList = Object.entries(modalitiesUsed)
                .filter(([_, used]) => used)
                .map(([mod]) => mod)
                .join(', ') || 'None';
            
            alert(
                `Sample ID: ${scan.sample_id}\n` +
                `Mineral: ${scan.mineral}\n` +
                `Predicted: ${scan.predicted_mineral}\n` +
                `Confidence: ${scan.confidence ? (scan.confidence * 100).toFixed(2) + '%' : 'N/A'}\n` +
                `Site: ${scan.site}\n` +
                `User: ${scan.user_name}\n` +
                `Modalities: ${modsList}\n` +
                gpsInfo +
                `Timestamp: ${new Date(scan.timestamp).toLocaleString()}`
            );
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
let scansPage;

document.addEventListener('DOMContentLoaded', () => {
    scansPage = new ScansPage();
    scansPage.init();
});
