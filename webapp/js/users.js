// Users Page Management
class UsersPage {
    constructor() {
        this.allUsers = [];
        this.pendingUsers = [];
        this.filteredUsers = [];
        this.userScans = {};
        this.filters = {
            role: '',
            search: ''
        };
    }

    getApiBaseCandidates() {
        const configuredBase = typeof API_BASE_URL === 'string' && API_BASE_URL.trim()
            ? API_BASE_URL.trim()
            : 'https://mineraltrace-api.onrender.com';
        return [configuredBase.replace(/\/$/, '')];
    }

    async requestWithFallback(path, options = {}) {
        const bases = this.getApiBaseCandidates();
        let lastError = null;

        for (const base of bases) {
            try {
                const response = await fetch(`${base}${path}`, options);
                return { response, base };
            } catch (error) {
                lastError = error;
            }
        }

        throw lastError || new Error('Failed to fetch');
    }

    // Initialize page
    async init() {
        this.showLoading(true);
        
        try {
            await this.loadUsers();
            await this.loadPendingUsers();
            await this.loadUserScans();
            this.setupEventListeners();
            this.renderTable();
            this.renderPendingTable();
            this.updateStats();
        } catch (error) {
            console.error('Failed to initialize users page:', error);
            this.showError('Failed to load users');
        } finally {
            this.showLoading(false);
        }
    }

    // Load users from API
    async loadUsers() {
        try {
            const { response } = await this.requestWithFallback('/users');
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const data = await response.json();
            this.allUsers = data.users || [];
            this.filteredUsers = [...this.allUsers];
        } catch (error) {
            console.error('Error loading users:', error);
            this.allUsers = [];
            this.filteredUsers = [];
        }
    }

    // Load pending users from API
    async loadPendingUsers() {
        try {
            const { response } = await this.requestWithFallback('/api/admin/pending-users');
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const data = await response.json();
            this.pendingUsers = data.users || [];
            
            // Show/hide pending approvals section
            const section = document.getElementById('pendingApprovalsSection');
            if (section) {
                section.style.display = this.pendingUsers.length > 0 ? 'block' : 'none';
            }
            
            // Update pending count badge
            const badge = document.getElementById('pendingCount');
            if (badge) {
                badge.textContent = this.pendingUsers.length;
            }
            
            // Update notification badge in top bar
            const notifBadge = document.querySelector('.notification-badge');
            if (notifBadge && this.pendingUsers.length > 0) {
                notifBadge.textContent = this.pendingUsers.length;
                notifBadge.style.display = 'block';
            }
        } catch (error) {
            console.error('Error loading pending users:', error);
            this.pendingUsers = [];
        }
    }

    // Load user scan counts
    async loadUserScans() {
        try {
            const { response } = await this.requestWithFallback('/fingerprints');
            if (!response.ok) return;
            
            const data = await response.json();
            const fingerprints = data.fingerprints || [];

            // Count scans per user
            fingerprints.forEach(fp => {
                const userId = fp.user_id || fp.user_name || 'Unknown';
                this.userScans[userId] = (this.userScans[userId] || 0) + 1;
            });
        } catch (error) {
            console.error('Error loading user scans:', error);
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

        // Role filter
        const roleFilter = document.getElementById('roleFilter');
        if (roleFilter) {
            roleFilter.addEventListener('change', (e) => {
                this.filters.role = e.target.value.toLowerCase();
                this.applyFilters();
            });
        }
    }

    // Open add user modal
    openAddModal() {
        const modal = document.getElementById('addUserModal');
        const form = document.getElementById('addUserForm');
        if (form) {
            form.reset();
        }
        if (modal) {
            modal.style.display = 'flex';
        }
    }

    // Close add user modal
    closeAddModal() {
        const modal = document.getElementById('addUserModal');
        const form = document.getElementById('addUserForm');
        if (modal) {
            modal.style.display = 'none';
        }
        if (form) {
            form.reset();
        }
    }

    // Submit add user form
    async submitAddUser(event) {
        event.preventDefault();

        const formData = new FormData(event.target);
        const name = formData.get('name')?.toString().trim();
        const email = formData.get('email')?.toString().trim();
        const role = formData.get('role')?.toString().trim();
        const organization = formData.get('organization')?.toString().trim();
        const password = formData.get('password')?.toString();

        if (!name || !email || !role || !password) {
            alert('Please fill in all required fields.');
            return;
        }

        try {
            const body = new FormData();
            body.append('name', name);
            body.append('email', email);
            body.append('role', role);
            body.append('password', password);
            if (organization) {
                body.append('organization', organization);
            }

            const { response } = await this.requestWithFallback('/users', {
                method: 'POST',
                body
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.detail || 'Failed to create user');
            }

            const data = await response.json();

            if (data.success) {
                alert('User created successfully.');
                this.closeAddModal();
                await this.loadUsers();
                await this.loadPendingUsers();
                this.renderTable();
                this.renderPendingTable();
                this.updateStats();
            } else {
                throw new Error(data.message || 'Failed to create user');
            }
        } catch (error) {
            console.error('Error creating user:', error);
            alert('Failed to create user: ' + error.message);
        }
    }

    // Apply filters
    applyFilters() {
        this.filteredUsers = this.allUsers.filter(user => {
            // Role filter
            if (this.filters.role && user.role?.toLowerCase() !== this.filters.role) {
                return false;
            }

            // Search filter
            if (this.filters.search) {
                const searchText = this.filters.search;
                const matchesSearch = 
                    (user.name && user.name.toLowerCase().includes(searchText)) ||
                    (user.email && user.email.toLowerCase().includes(searchText)) ||
                    (user.role && user.role.toLowerCase().includes(searchText));
                
                if (!matchesSearch) {
                    return false;
                }
            }

            return true;
        });

        this.renderTable();
        this.updateStats();
    }

    // Render table
    renderTable() {
        const tbody = document.getElementById('usersTableBody');
        if (!tbody) return;

        // Clear table
        tbody.innerHTML = '';

        if (this.filteredUsers.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="7" style="text-align: center; padding: 3rem;">
                        <i class="fas fa-inbox" style="font-size: 48px; color: #9CA3AF; margin-bottom: 1rem;"></i>
                        <p style="color: #6B7280;">No users found</p>
                    </td>
                </tr>
            `;
            return;
        }

        // Render rows
        this.filteredUsers.forEach(user => {
            const row = this.createTableRow(user);
            tbody.appendChild(row);
        });
    }

    // Render pending users table
    renderPendingTable() {
        const tbody = document.getElementById('pendingUsersTableBody');
        if (!tbody) return;

        // Clear table
        tbody.innerHTML = '';

        if (this.pendingUsers.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="6" style="text-align: center; padding: 2rem;">
                        <i class="fas fa-check-circle" style="font-size: 36px; color: var(--success); margin-bottom: 0.5rem;"></i>
                        <p style="color: #6B7280;">No pending approvals</p>
                    </td>
                </tr>
            `;
            return;
        }

        // Render rows
        this.pendingUsers.forEach(user => {
            const row = this.createPendingTableRow(user);
            tbody.appendChild(row);
        });
    }

    // Create pending user table row
    createPendingTableRow(user) {
        const tr = document.createElement('tr');
        
        const avatarUrl = user.photo_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(user.name || 'User')}&background=F59E0B&color=fff`;
        const createdDate = user.created_at ? new Date(user.created_at).toLocaleDateString() : 'N/A';

        tr.innerHTML = `
            <td>
                <div style="display: flex; align-items: center; gap: 0.75rem;">
                    <img src="${avatarUrl}" alt="${user.name}" style="width: 36px; height: 36px; border-radius: 50%;">
                    <div>
                        <div style="font-weight: 600;">${user.name || 'Unknown'}</div>
                        <div style="font-size: 12px; color: #6B7280;">ID: ${user.id}</div>
                    </div>
                </div>
            </td>
            <td>${user.email || 'N/A'}</td>
            <td>${this.getRoleBadge(user.role)}</td>
            <td>${user.organization || 'N/A'}</td>
            <td>${createdDate}</td>
            <td>
                <button class="action-btn success" onclick="usersPage.approveUser('${user.id}')" title="Approve User">
                    <i class="fas fa-check"></i>
                    Approve
                </button>
                <button class="action-btn danger" onclick="usersPage.denyUser('${user.id}')" title="Deny User" style="margin-left: 0.5rem;">
                    <i class="fas fa-times"></i>
                    Deny
                </button>
            </td>
        `;

        return tr;
    }

    // Create table row
    createTableRow(user) {
        const tr = document.createElement('tr');
        
        // Get user scans count
        const scansCount = this.userScans[user.id] || this.userScans[user.name] || 0;
        
        // Get role badge
        const roleBadge = this.getRoleBadge(user.role);
        
        // Last active (mock data - would come from API in production)
        const lastActive = user.last_active || 'N/A';
        
        // User avatar
        const avatarUrl = `https://ui-avatars.com/api/?name=${encodeURIComponent(user.name || 'User')}&background=0A3552&color=fff`;

        tr.innerHTML = `
            <td>
                <div style="display: flex; align-items: center; gap: 0.75rem;">
                    <img src="${avatarUrl}" alt="${user.name}" style="width: 36px; height: 36px; border-radius: 50%;">
                    <div>
                        <div style="font-weight: 600;">${user.name || 'Unknown'}</div>
                        <div style="font-size: 12px; color: #6B7280;">ID: ${user.id}</div>
                    </div>
                </div>
            </td>
            <td>${user.email || 'N/A'}</td>
            <td>${roleBadge}</td>
            <td><span class="confidence-badge medium">${scansCount}</span></td>
            <td>${lastActive}</td>
            <td>
                <span class="status-badge verified">
                    <i class="fas fa-circle" style="font-size: 8px;"></i>
                    Active
                </span>
            </td>
            <td>
                <div style="display: flex; gap: 0.25rem;">
                    <button class="btn-icon" onclick="usersPage.viewDetails('${user.id}')" title="View Details">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button class="btn-icon" onclick="usersPage.openEditModal('${user.id}')" title="Edit User" style="background: #FEF3C7; color: #92400E;">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="btn-icon" onclick="usersPage.deleteUser('${user.id}')" title="Delete User" style="background: #FEE2E2; color: #991B1B;">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            </td>
        `;

        return tr;
    }

    // Get role badge
    getRoleBadge(role) {
        const badges = {
            admin: '<span class="status-badge verified"><i class="fas fa-shield-alt"></i> Admin</span>',
            inspector: '<span class="status-badge pending"><i class="fas fa-clipboard-check"></i> Inspector</span>',
            regulator: '<span class="status-badge not-verified"><i class="fas fa-gavel"></i> Regulator</span>',
            operator: '<span class="status-badge"><i class="fas fa-user"></i> Operator</span>'
        };
        return badges[role?.toLowerCase()] || '<span class="status-badge">Unknown</span>';
    }

    // Approve user
    async approveUser(userId) {
        if (!confirm('Are you sure you want to approve this user?')) {
            return;
        }

        try {
            const { response } = await this.requestWithFallback('/api/admin/approve-user', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ user_id: userId })
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            
            if (data.success) {
                const emailSent = data.notification?.email_sent;
                if (emailSent === true) {
                    alert('User approved successfully. Approval email sent to user.');
                } else if (emailSent === false) {
                    alert('User approved, but user email was not sent. Please check backend logs.');
                } else {
                    alert('User approved successfully!');
                }
                // Reload data
                await this.loadUsers();
                await this.loadPendingUsers();
                this.renderTable();
                this.renderPendingTable();
                this.updateStats();
            } else {
                throw new Error(data.message || 'Failed to approve user');
            }
        } catch (error) {
            console.error('Error approving user:', error);
            alert('Failed to approve user: ' + error.message);
        }
    }

    // Deny user
    async denyUser(userId) {
        const reason = prompt('Enter reason for denial (optional):');
        if (reason === null) return; // User cancelled

        try {
            const { response } = await this.requestWithFallback('/api/admin/deny-user', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ 
                    user_id: userId,
                    reason: reason || undefined
                })
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            
            if (data.success) {
                const emailSent = data.notification?.email_sent;
                if (emailSent === true) {
                    alert('User denied successfully. Denial email sent to user.');
                } else if (emailSent === false) {
                    alert('User denied, but user email was not sent. Please check backend logs.');
                } else {
                    alert('User denied successfully!');
                }
                // Reload data
                await this.loadUsers();
                await this.loadPendingUsers();
                this.renderTable();
                this.renderPendingTable();
                this.updateStats();
            } else {
                throw new Error(data.message || 'Failed to deny user');
            }
        } catch (error) {
            console.error('Error denying user:', error);
            alert('Failed to deny user: ' + error.message);
        }
    }

    // Open edit modal
    openEditModal(userId) {
        const user = this.allUsers.find(u => u.id === userId);
        if (!user) {
            alert('User not found');
            return;
        }

        // Populate form
        document.getElementById('editUserId').value = user.id;
        document.getElementById('editUserName').value = user.name;
        document.getElementById('editUserEmail').value = user.email;
        document.getElementById('editUserRole').value = user.role;
        document.getElementById('editUserPassword').value = '';

        // Show modal
        document.getElementById('editUserModal').style.display = 'flex';
    }

    // Close edit modal
    closeEditModal() {
        document.getElementById('editUserModal').style.display = 'none';
        document.getElementById('editUserForm').reset();
    }

    // Submit edit user form
    async submitEditUser(event) {
        event.preventDefault();

        const formData = new FormData(event.target);
        const userId = formData.get('userId');
        const name = formData.get('name');
        const email = formData.get('email');
        const role = formData.get('role');
        const password = formData.get('password');

        try {
            const body = new FormData();
            body.append('name', name);
            body.append('email', email);
            body.append('role', role);
            if (password) {
                body.append('password', password);
            }

            const { response } = await this.requestWithFallback(`/users/${userId}`, {
                method: 'PUT',
                body: body
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.detail || 'Failed to update user');
            }

            const data = await response.json();
            
            if (data.success) {
                alert('User updated successfully!');
                this.closeEditModal();
                // Reload data
                await this.loadUsers();
                await this.loadPendingUsers();
                this.renderTable();
                this.renderPendingTable();
                this.updateStats();
            } else {
                throw new Error(data.message || 'Failed to update user');
            }
        } catch (error) {
            console.error('Error updating user:', error);
            alert('Failed to update user: ' + error.message);
        }
    }

    // Delete user
    async deleteUser(userId) {
        const user = this.allUsers.find(u => u.id === userId);
        if (!user) {
            alert('User not found');
            return;
        }

        if (!confirm(`Are you sure you want to delete user "${user.name}"?\n\nThis action cannot be undone.`)) {
            return;
        }

        try {
            const { response } = await this.requestWithFallback(`/users/${userId}`, {
                method: 'DELETE'
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.detail || 'Failed to delete user');
            }

            const data = await response.json();
            
            if (data.success) {
                alert('User deleted successfully!');
                // Reload data
                await this.loadUsers();
                await this.loadPendingUsers();
                this.renderTable();
                this.renderPendingTable();
                this.updateStats();
            } else {
                throw new Error(data.message || 'Failed to delete user');
            }
        } catch (error) {
            console.error('Error deleting user:', error);
            alert('Failed to delete user: ' + error.message);
        }
    }

    // Update stats
    updateStats() {
        document.getElementById('totalUsers').textContent = this.allUsers.length;
        document.getElementById('activeUsers').textContent = this.allUsers.length; // All users are active for now
    }

    // View details
    viewDetails(userId) {
        const user = this.allUsers.find(u => u.id === userId);
        if (user) {
            const scansCount = this.userScans[user.id] || this.userScans[user.name] || 0;
            alert(
                `Name: ${user.name}\n` +
                `Email: ${user.email}\n` +
                `Role: ${user.role}\n` +
                `User ID: ${user.id}\n` +
                `Total Scans: ${scansCount}\n` +
                `Created: ${user.created_at || 'N/A'}`
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
let usersPage;

document.addEventListener('DOMContentLoaded', () => {
    usersPage = new UsersPage();
    usersPage.init();
});
