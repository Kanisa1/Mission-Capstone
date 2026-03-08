const apiService = globalThis.apiService;

class NotificationManager {
    constructor() {
        this.notifications = [];
        this.lastCheckTimestamp = this.getLastCheckTime();
        this.updateInterval = 30000; // Check every 30 seconds
        this.maxNotifications = 50; // Keep last 50 notifications
    }

    async init() {
        // Load cached notifications from localStorage
        this.loadCachedNotifications();
        
        // Check for new notifications
        await this.checkForNewNotifications();
        
        // Set up periodic checking
        setInterval(() => {
            this.checkForNewNotifications();
        }, this.updateInterval);

        // Set up UI
        this.setupNotificationUI();
    }

    loadCachedNotifications() {
        try {
            const cached = localStorage.getItem('notifications');
            if (cached) {
                this.notifications = JSON.parse(cached);
                this.updateBadge();
            }
        } catch (error) {
            console.error('Error loading cached notifications:', error);
        }
    }

    saveNotifications() {
        try {
            // Keep only the last maxNotifications
            const toSave = this.notifications.slice(0, this.maxNotifications);
            localStorage.setItem('notifications', JSON.stringify(toSave));
        } catch (error) {
            console.error('Error saving notifications:', error);
        }
    }

    getLastCheckTime() {
        const saved = localStorage.getItem('lastNotificationCheck');
        if (saved) {
            return new Date(saved);
        }
        // Default to 1 hour ago
        const oneHourAgo = new Date();
        oneHourAgo.setHours(oneHourAgo.getHours() - 1);
        return oneHourAgo;
    }

    setLastCheckTime(time) {
        localStorage.setItem('lastNotificationCheck', time.toISOString());
        this.lastCheckTimestamp = time;
    }

    async checkForNewNotifications() {
        if (!apiService) {
            return;
        }

        try {
            const now = new Date();
            const [users, fingerprints] = await Promise.all([
                apiService.getUsers(),
                apiService.getFingerprints()
            ]);

            let newNotifications = [];

            // Check for new user registrations
            users.forEach(user => {
                if (user.created_at) {
                    const createdDate = new Date(user.created_at);
                    if (createdDate > this.lastCheckTimestamp) {
                        newNotifications.push({
                            id: `user_${user.id}_${Date.now()}`,
                            type: 'user_registration',
                            title: 'New User Registration',
                            message: `${user.name} (${user.role}) has registered`,
                            timestamp: user.created_at,
                            icon: 'fa-user-plus',
                            color: 'info',
                            read: false,
                            data: {
                                userId: user.id,
                                userName: user.name,
                                userRole: user.role,
                                userEmail: user.email
                            }
                        });
                    }
                }
            });

            // Check for new scans
            fingerprints.forEach(fp => {
                const scanDate = new Date(fp.timestamp || fp.created_at);
                if (scanDate > this.lastCheckTimestamp) {
                    newNotifications.push({
                        id: `scan_${fp.id}_${Date.now()}`,
                        type: 'new_scan',
                        title: 'New Scan Captured',
                        message: `${fp.predicted_mineral || 'Unknown mineral'} scan by ${fp.user_name || fp.user || 'Unknown'}`,
                        timestamp: fp.timestamp || fp.created_at,
                        icon: 'fa-camera',
                        color: 'primary',
                        read: false,
                        data: {
                            scanId: fp.id,
                            mineral: fp.predicted_mineral,
                            confidence: fp.confidence,
                            site: fp.site,
                            user: fp.user_name || fp.user
                        }
                    });
                }
            });

            // Sort by timestamp (newest first)
            newNotifications.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

            if (newNotifications.length > 0) {
                // Add new notifications to the beginning
                this.notifications = [...newNotifications, ...this.notifications];
                
                // Show browser notification for the most recent one
                this.showBrowserNotification(newNotifications[0]);
                
                // Play notification sound (optional)
                this.playNotificationSound();
                
                // Save to localStorage
                this.saveNotifications();
                
                // Update UI
                this.updateBadge();
                this.renderNotifications();
            }

            // Update last check time
            this.setLastCheckTime(now);

        } catch (error) {
            console.error('Error checking notifications:', error);
        }
    }

    showBrowserNotification(notification) {
        if ('Notification' in window && Notification.permission === 'granted') {
            new Notification(notification.title, {
                body: notification.message,
                icon: '../assets/logo.png',
                badge: '../assets/logo.png',
                tag: notification.id
            });
        } else if ('Notification' in window && Notification.permission !== 'denied') {
            Notification.requestPermission().then(permission => {
                if (permission === 'granted') {
                    new Notification(notification.title, {
                        body: notification.message,
                        icon: '../assets/logo.png'
                    });
                }
            });
        }
    }

    playNotificationSound() {
        // Create a subtle notification sound
        try {
            const audioContext = new (window.AudioContext || window.webkitAudioContext)();
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();
            
            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);
            
            oscillator.frequency.value = 800;
            oscillator.type = 'sine';
            
            gainNode.gain.setValueAtTime(0.1, audioContext.currentTime);
            gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.3);
            
            oscillator.start(audioContext.currentTime);
            oscillator.stop(audioContext.currentTime + 0.3);
        } catch (error) {
            // Silently fail if audio is not supported
        }
    }

    setupNotificationUI() {
        const notificationBtn = document.querySelector('.btn-notification');
        const notificationBadge = document.querySelector('.notification-badge');
        
        if (notificationBtn) {
            // Create dropdown
            const dropdown = this.createNotificationDropdown();
            notificationBtn.parentElement.style.position = 'relative';
            notificationBtn.parentElement.appendChild(dropdown);
            
            // Toggle dropdown on click
            notificationBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                dropdown.classList.toggle('show');
                
                // Mark all as read when opened
                if (dropdown.classList.contains('show')) {
                    this.markAllAsRead();
                }
            });
            
            // Close dropdown when clicking outside
            document.addEventListener('click', (e) => {
                if (!notificationBtn.contains(e.target) && !dropdown.contains(e.target)) {
                    dropdown.classList.remove('show');
                }
            });
        }

        // Initial render
        this.updateBadge();
        this.renderNotifications();
    }

    createNotificationDropdown() {
        const dropdown = document.createElement('div');
        dropdown.className = 'notification-dropdown';
        dropdown.innerHTML = `
            <div class="notification-header">
                <h4>Notifications</h4>
                <button class="clear-all-btn" onclick="notificationManager.clearAll()">
                    <i class="fas fa-trash"></i> Clear All
                </button>
            </div>
            <div class="notification-list" id="notificationList">
                <!-- Notifications will be inserted here -->
            </div>
            <div class="notification-footer">
                <a href="audit-trail.html">View All Activity</a>
            </div>
        `;
        return dropdown;
    }

    renderNotifications() {
        const list = document.getElementById('notificationList');
        if (!list) return;

        if (this.notifications.length === 0) {
            list.innerHTML = `
                <div class="notification-empty">
                    <i class="fas fa-bell-slash"></i>
                    <p>No notifications</p>
                </div>
            `;
            return;
        }

        // Show last 10 notifications in dropdown
        const recentNotifications = this.notifications.slice(0, 10);
        
        list.innerHTML = recentNotifications.map(notification => `
            <div class="notification-item ${notification.read ? 'read' : 'unread'}" 
                 data-id="${notification.id}"
                 onclick="notificationManager.handleNotificationClick('${notification.id}')">
                <div class="notification-icon ${notification.color}">
                    <i class="fas ${notification.icon}"></i>
                </div>
                <div class="notification-content">
                    <div class="notification-title">${notification.title}</div>
                    <div class="notification-message">${notification.message}</div>
                    <div class="notification-time">${this.formatTime(notification.timestamp)}</div>
                </div>
                ${!notification.read ? '<div class="notification-dot"></div>' : ''}
            </div>
        `).join('');
    }

    updateBadge() {
        const badge = document.querySelector('.notification-badge');
        if (badge) {
            const unreadCount = this.notifications.filter(n => !n.read).length;
            badge.textContent = unreadCount;
            badge.style.display = unreadCount > 0 ? 'block' : 'none';
        }
    }

    markAllAsRead() {
        this.notifications.forEach(n => n.read = true);
        this.saveNotifications();
        this.updateBadge();
        this.renderNotifications();
    }

    clearAll() {
        if (confirm('Are you sure you want to clear all notifications?')) {
            this.notifications = [];
            this.saveNotifications();
            this.updateBadge();
            this.renderNotifications();
        }
    }

    handleNotificationClick(notificationId) {
        const notification = this.notifications.find(n => n.id === notificationId);
        if (!notification) return;

        // Mark as read
        notification.read = true;
        this.saveNotifications();
        this.updateBadge();
        this.renderNotifications();

        // Navigate based on type
        if (notification.type === 'user_registration') {
            window.location.href = 'users.html';
        } else if (notification.type === 'new_scan') {
            window.location.href = 'scans.html';
        }
    }

    formatTime(timestamp) {
        if (!timestamp) return '';
        
        const date = new Date(timestamp);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        if (diffDays < 7) return `${diffDays}d ago`;
        
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    // Get unread count
    getUnreadCount() {
        return this.notifications.filter(n => !n.read).length;
    }
}

// Create global instance
window.notificationManager = new NotificationManager();

// Export for module usage
export { NotificationManager };
