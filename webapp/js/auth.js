(function () {
    const AUTH_STORAGE_KEY = 'webapp_admin_auth';

    function getCurrentPath() {
        const parts = window.location.pathname.split('/');
        return (parts[parts.length - 1] || 'index.html').toLowerCase();
    }

    function isLoginPage() {
        return getCurrentPath() === 'login.html';
    }

    function getAuth() {
        try {
            const raw = localStorage.getItem(AUTH_STORAGE_KEY);
            if (!raw) return null;
            return JSON.parse(raw);
        } catch (error) {
            return null;
        }
    }

    function isAdminAuthenticated() {
        const auth = getAuth();
        if (!auth || !auth.user) return false;
        return String(auth.user.role || '').toLowerCase() === 'admin';
    }

    function login(user) {
        const payload = {
            user,
            logged_in_at: new Date().toISOString()
        };
        localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(payload));
    }

    function updateUser(user) {
        const auth = getAuth();
        if (!auth) return;
        const payload = {
            ...auth,
            user: {
                ...auth.user,
                ...user
            },
            updated_at: new Date().toISOString()
        };
        localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(payload));
    }

    function logout() {
        localStorage.removeItem(AUTH_STORAGE_KEY);
        window.location.href = 'login.html';
    }

    function requireAdminAuth() {
        if (isLoginPage()) return;
        if (!isAdminAuthenticated()) {
            window.location.href = 'login.html';
        }
    }

    function redirectIfAlreadyLoggedIn() {
        if (isLoginPage() && isAdminAuthenticated()) {
            window.location.href = 'index.html';
        }
    }

    window.WebAuth = {
        login,
        updateUser,
        logout,
        getAuth,
        isAdminAuthenticated,
        requireAdminAuth,
        redirectIfAlreadyLoggedIn
    };

    requireAdminAuth();
    redirectIfAlreadyLoggedIn();
})();
