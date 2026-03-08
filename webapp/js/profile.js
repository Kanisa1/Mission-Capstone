class ProfileManager {
    constructor() {
        this.auth = window.WebAuth?.getAuth() || null;
        this.user = this.auth?.user || null;
        this.modalId = 'profileModal';
        this.pendingPhotoData = null;
        this.removePhoto = false;
    }

    init() {
        if (!this.user) return;
        this.applyUserBadge();
        this.attachMenuListeners();
    }

    applyUserBadge() {
        const menus = document.querySelectorAll('.user-menu');
        menus.forEach((menu) => {
            menu.title = this.user.name || this.user.email || 'Admin User';
            const avatar = menu.querySelector('.user-avatar-small');
            if (!avatar) return;

            if (this.user.photo_url) {
                avatar.innerHTML = `<img src="${this.user.photo_url}" alt="${this.user.name || 'Admin'}" style="width:100%;height:100%;border-radius:50%;object-fit:cover;">`;
            } else {
                avatar.innerHTML = '<i class="fas fa-user"></i>';
            }
        });
    }

    attachMenuListeners() {
        const menus = document.querySelectorAll('.user-menu');
        menus.forEach((menu) => {
            if (menu.dataset.profileBound === 'true') return;
            menu.dataset.profileBound = 'true';
            menu.style.cursor = 'pointer';
            menu.addEventListener('click', () => this.openModal());
        });
    }

    ensureModal() {
        let modal = document.getElementById(this.modalId);
        if (modal) return modal;

        modal = document.createElement('div');
        modal.id = this.modalId;
        modal.className = 'modal';
        modal.style.display = 'none';
        modal.innerHTML = `
            <div class="modal-content" style="max-width:560px;">
                <div class="modal-header">
                    <h3><i class="fas fa-user-cog"></i> Admin Profile</h3>
                    <button class="modal-close" type="button" id="profileModalClose">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <form id="profileForm">
                    <div class="form-group">
                        <label for="profileName">Name</label>
                        <input type="text" id="profileName" name="name" required>
                    </div>
                    <div class="form-group">
                        <label for="profileEmail">Email</label>
                        <input type="email" id="profileEmail" name="email" required>
                    </div>
                    <div class="form-group">
                        <label for="profileOrganization">Organization</label>
                        <input type="text" id="profileOrganization" name="organization">
                    </div>
                    <div class="form-group">
                        <label>Profile Picture</label>
                        <div style="display:flex;align-items:center;gap:12px;margin-bottom:10px;">
                            <img id="profilePhotoPreview" alt="Profile" style="width:52px;height:52px;border-radius:50%;object-fit:cover;border:1px solid var(--border-color);display:none;">
                            <div style="display:flex;gap:8px;flex-wrap:wrap;">
                                <input type="file" id="profilePhotoFile" accept="image/*">
                                <button type="button" class="action-btn secondary" id="removePhotoBtn">Remove Photo</button>
                            </div>
                        </div>
                        <input type="text" id="profilePhotoUrl" name="photo_url" placeholder="Or paste image URL">
                    </div>
                    <div class="form-group">
                        <label for="profileCurrentPassword">Current Password (required to change password)</label>
                        <input type="password" id="profileCurrentPassword" name="current_password" autocomplete="current-password">
                    </div>
                    <div class="form-group">
                        <label for="profileNewPassword">New Password</label>
                        <input type="password" id="profileNewPassword" name="new_password" autocomplete="new-password">
                    </div>
                    <div class="form-group">
                        <label for="profileConfirmPassword">Confirm New Password</label>
                        <input type="password" id="profileConfirmPassword" autocomplete="new-password">
                    </div>
                    <div class="modal-actions">
                        <button type="button" class="action-btn secondary" id="profileLogoutBtn">
                            <i class="fas fa-sign-out-alt"></i>
                            Logout
                        </button>
                        <button type="submit" class="action-btn primary" id="profileSaveBtn">
                            <i class="fas fa-save"></i>
                            Save Profile
                        </button>
                    </div>
                </form>
            </div>
        `;

        document.body.appendChild(modal);

        document.getElementById('profileModalClose')?.addEventListener('click', () => this.closeModal());
        document.getElementById('profileForm')?.addEventListener('submit', (event) => this.submit(event));
        document.getElementById('profileLogoutBtn')?.addEventListener('click', () => window.WebAuth?.logout());
        document.getElementById('removePhotoBtn')?.addEventListener('click', () => this.clearPhoto());
        document.getElementById('profilePhotoFile')?.addEventListener('change', (event) => this.onPhotoSelected(event));

        return modal;
    }

    populate() {
        const user = this.user || {};
        const nameInput = document.getElementById('profileName');
        const emailInput = document.getElementById('profileEmail');
        const orgInput = document.getElementById('profileOrganization');
        const photoUrlInput = document.getElementById('profilePhotoUrl');

        if (nameInput) nameInput.value = user.name || '';
        if (emailInput) emailInput.value = user.email || '';
        if (orgInput) orgInput.value = user.organization || '';
        if (photoUrlInput) photoUrlInput.value = user.photo_url || '';

        this.pendingPhotoData = null;
        this.removePhoto = false;
        this.updatePhotoPreview(user.photo_url || null);

        const currentPassword = document.getElementById('profileCurrentPassword');
        const newPassword = document.getElementById('profileNewPassword');
        const confirmPassword = document.getElementById('profileConfirmPassword');
        if (currentPassword) currentPassword.value = '';
        if (newPassword) newPassword.value = '';
        if (confirmPassword) confirmPassword.value = '';
    }

    openModal() {
        const modal = this.ensureModal();
        this.populate();
        modal.style.display = 'flex';
    }

    closeModal() {
        const modal = document.getElementById(this.modalId);
        if (modal) {
            modal.style.display = 'none';
        }
    }

    updatePhotoPreview(photoUrl) {
        const preview = document.getElementById('profilePhotoPreview');
        if (!preview) return;

        if (photoUrl) {
            preview.src = photoUrl;
            preview.style.display = 'block';
        } else {
            preview.removeAttribute('src');
            preview.style.display = 'none';
        }
    }

    clearPhoto() {
        this.pendingPhotoData = null;
        this.removePhoto = true;
        const photoUrlInput = document.getElementById('profilePhotoUrl');
        const fileInput = document.getElementById('profilePhotoFile');
        if (photoUrlInput) photoUrlInput.value = '';
        if (fileInput) fileInput.value = '';
        this.updatePhotoPreview(null);
    }

    onPhotoSelected(event) {
        const file = event.target.files?.[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = () => {
            this.pendingPhotoData = reader.result;
            this.removePhoto = false;
            this.updatePhotoPreview(this.pendingPhotoData);
        };
        reader.readAsDataURL(file);
    }

    async submit(event) {
        event.preventDefault();

        const saveButton = document.getElementById('profileSaveBtn');
        const form = event.target;
        const formData = new FormData(form);

        const currentPassword = (formData.get('current_password') || '').toString();
        const newPassword = (formData.get('new_password') || '').toString();
        const confirmPassword = (document.getElementById('profileConfirmPassword')?.value || '').toString();

        if (newPassword && newPassword !== confirmPassword) {
            alert('New password and confirmation do not match.');
            return;
        }

        if (newPassword && !currentPassword) {
            alert('Current password is required to change password.');
            return;
        }

        const payload = new FormData();
        payload.append('name', (formData.get('name') || '').toString().trim());
        payload.append('email', (formData.get('email') || '').toString().trim());
        payload.append('organization', (formData.get('organization') || '').toString().trim());

        if (currentPassword) payload.append('current_password', currentPassword);
        if (newPassword) payload.append('new_password', newPassword);

        if (this.removePhoto) {
            payload.append('remove_photo', 'true');
        } else if (this.pendingPhotoData) {
            payload.append('photo_url', this.pendingPhotoData);
        } else {
            const urlPhoto = (formData.get('photo_url') || '').toString().trim();
            if (urlPhoto) {
                payload.append('photo_url', urlPhoto);
            }
        }

        if (saveButton) {
            saveButton.disabled = true;
            saveButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';
        }

        try {
            const baseUrl = typeof API_BASE_URL !== 'undefined' ? API_BASE_URL : 'https://mineraltrace-api.onrender.com';
            const response = await fetch(`${baseUrl}/profile/${this.user.id}`, {
                method: 'PUT',
                body: payload
            });

            const data = await response.json();
            if (!response.ok) {
                throw new Error(data?.detail || 'Failed to update profile.');
            }

            if (data?.user) {
                this.user = data.user;
                window.WebAuth?.updateUser(data.user);
                this.applyUserBadge();
            }

            this.closeModal();
            alert('Profile updated successfully.');
        } catch (error) {
            alert(error.message || 'Failed to update profile.');
        } finally {
            if (saveButton) {
                saveButton.disabled = false;
                saveButton.innerHTML = '<i class="fas fa-save"></i> Save Profile';
            }
        }
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const manager = new ProfileManager();
    manager.init();
});
