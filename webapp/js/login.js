class LoginPage {
    constructor() {
        this.form = document.getElementById('loginForm');
        this.emailInput = document.getElementById('email');
        this.passwordInput = document.getElementById('password');
        this.errorBox = document.getElementById('loginError');
        this.submitButton = document.getElementById('loginBtn');
    }

    init() {
        if (!this.form) return;
        this.form.addEventListener('submit', (event) => this.handleSubmit(event));
    }

    setLoading(loading) {
        if (!this.submitButton) return;
        this.submitButton.disabled = loading;
        this.submitButton.innerHTML = loading
            ? '<i class="fas fa-spinner fa-spin"></i> Signing in...'
            : '<i class="fas fa-sign-in-alt"></i> Sign In';
    }

    showError(message) {
        if (!this.errorBox) return;
        this.errorBox.textContent = message;
        this.errorBox.style.display = 'block';
    }

    clearError() {
        if (!this.errorBox) return;
        this.errorBox.style.display = 'none';
        this.errorBox.textContent = '';
    }

    async handleSubmit(event) {
        event.preventDefault();
        this.clearError();

        const email = this.emailInput?.value?.trim();
        const password = this.passwordInput?.value || '';

        if (!email || !password) {
            this.showError('Email and password are required.');
            return;
        }

        this.setLoading(true);

        try {
            const response = await fetch(`${API_BASE_URL}/login`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ email, password })
            });

            let data = null;
            try {
                data = await response.json();
            } catch (error) {
                data = null;
            }

            if (!response.ok) {
                const message = data?.detail || 'Login failed. Please try again.';
                throw new Error(message);
            }

            const user = data?.user;
            if (!user || String(user.role || '').toLowerCase() !== 'admin') {
                throw new Error('Only admin users can log in to the web dashboard.');
            }

            WebAuth.login(user);
            window.location.href = 'index.html';
        } catch (error) {
            this.showError(error.message || 'Failed to sign in.');
        } finally {
            this.setLoading(false);
        }
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const page = new LoginPage();
    page.init();
});
