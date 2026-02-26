# Email Notification System

## Overview
The MineralTrace system now includes automated email notifications for the user registration and approval workflow.

## Email Workflow

### 1. **User Registration**
When a new user registers:
- **User receives:** Confirmation email saying "Your account has been created and is pending admin approval"
- **Admin receives:** Notification email listing all pending users awaiting approval
- **Email template:** Professional HTML with MineralTrace branding (teal/cyan colors)

### 2. **Admin Approves User**
When an admin approves a pending user:
- **User receives:** Approval email with activation details and login instructions
- **Status:** User can now log in to the system

### 3. **Admin Denies User**
When an admin denies a user:
- **User receives:** Denial email with (optional) reason provided by admin
- **Status:** User account remains in "denied" state

## Configuration

### Environment Variables
Set these in your `.env` file or system environment:

```
ENABLE_EMAIL=true                          # Set to 'false' to disable emails (logs instead)
SENDER_EMAIL=mineraltrace.system@gmail.com # Your Gmail address
SENDER_PASSWORD=your_app_password_here     # Gmail App Password (NOT your main password)
ADMIN_EMAIL=admin@mineraltrace.com         # Admin email for approval notifications
SMTP_SERVER=smtp.gmail.com                 # Gmail SMTP server
SMTP_PORT=587                              # Gmail SMTP port
```

### Gmail Setup (Recommended)
1. Enable 2-Step Verification on your Gmail account
2. Create an **App Password**: https://support.google.com/accounts/answer/185833
3. Use the 16-character app password as `SENDER_PASSWORD`
4. Do NOT use your main Gmail password

### Testing
To test emails without sending:
```
ENABLE_EMAIL=false
```
This will log all email content to the console instead of actually sending.

## Email Templates

### Registration Confirmation
- **Subject:** Welcome to MineralTrace!
- **Content:** Account created, awaiting admin approval
- **Recipient:** New user

### Admin Approval Notification
- **Subject:** New Users Pending Approval - MineralTrace
- **Content:** List of pending users with their details
- **Recipient:** Admin email

### Approval Notification
- **Subject:** Your MineralTrace Account is Approved!
- **Content:** Account activated, ready to use
- **Recipient:** Approved user

### Denial Notification
- **Subject:** MineralTrace Registration Update
- **Content:** Registration denied, with optional reason
- **Recipient:** Denied user

## Implementation Details

All email functions are in `API/email_utils.py`:
- `send_registration_confirmation(name, email)` - Called after user registers
- `send_admin_approval_notification(count, users)` - Called when new user joins
- `send_approval_email(name, email)` - Called when admin approves
- `send_denial_email(name, email, reason)` - Called when admin denies

These are automatically called from the API endpoints:
- `/api/auth/register` → sends confirmation + admin notification
- `/api/admin/approve-user` → sends approval email
- `/api/admin/deny-user` → sends denial email

## Troubleshooting

### Emails not sending?
1. Check that `ENABLE_EMAIL=true`
2. Verify SMTP credentials are correct
3. For Gmail: Ensure App Password is used (not main password)
4. Check API logs for error messages

### Using a different email provider?
Update `SMTP_SERVER` and `SMTP_PORT` in email_utils.py or environment variables:
- **Outlook:** smtp.outlook.com:587
- **Yahoo:** smtp.mail.yahoo.com:587
- **Custom server:** Update as needed

### Development mode
Set `ENABLE_EMAIL=false` to skip sending and just log content. This is useful for testing the registration and approval flows without actually sending emails.
