"""
Email utility for sending notifications to users and admins
Supports SMTP-based email sending
"""

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import List
import logging
import os
from pathlib import Path

try:
    from dotenv import load_dotenv
except Exception:
    load_dotenv = None

logger = logging.getLogger(__name__)

if load_dotenv is not None:
    env_path = Path(__file__).resolve().parent / ".env"
    if env_path.exists():
        load_dotenv(dotenv_path=env_path)

# ===========================
# EMAIL CONFIGURATION
# ===========================
# For Gmail: use App Passwords (not regular password)
# Enable 2FA and generate app-specific password at https://myaccount.google.com/apppasswords

EMAIL_CONFIG = {
    'SENDER_EMAIL': os.getenv('SENDER_EMAIL', 'mineraltrace.system@gmail.com'),
    'SENDER_PASSWORD': os.getenv('SENDER_PASSWORD', 'your_app_password_here'),
    'SMTP_SERVER': os.getenv('SMTP_SERVER', 'smtp.gmail.com'),
    'SMTP_PORT': int(os.getenv('SMTP_PORT', 587)),
    'ADMIN_EMAIL': os.getenv('ADMIN_EMAIL', 'beckykanisa@gmail.com'),
}

WEBAPP_BASE_URL = os.getenv('WEBAPP_BASE_URL', 'https://mineraltrace-web.onrender.com').rstrip('/')


def build_webapp_url(path: str = 'index.html') -> str:
    """Build an absolute webapp URL for email CTAs."""
    safe_path = (path or 'index.html').lstrip('/')
    return f"{WEBAPP_BASE_URL}/{safe_path}"

# Set to True to enable emails (set False for testing without real email)
ENABLE_EMAIL = os.getenv('ENABLE_EMAIL', 'False').lower() == 'true'


def send_email(recipient: str, subject: str, html_content: str) -> bool:
    """
    Send email using SMTP
    
    Args:
        recipient: Email address to send to
        subject: Email subject
        html_content: HTML email body
        
    Returns:
        bool: True if successful, False otherwise
    """
    if not ENABLE_EMAIL:
        logger.info(f"📧 Email sending disabled. Would send to {recipient}: {subject}")
        return True
    
    try:
        # Create message
        message = MIMEMultipart('alternative')
        message['Subject'] = subject
        message['From'] = EMAIL_CONFIG['SENDER_EMAIL']
        message['To'] = recipient
        
        # Attach HTML content
        part = MIMEText(html_content, 'html')
        message.attach(part)
        
        # Send email
        with smtplib.SMTP(EMAIL_CONFIG['SMTP_SERVER'], EMAIL_CONFIG['SMTP_PORT']) as server:
            server.starttls()
            server.login(EMAIL_CONFIG['SENDER_EMAIL'], EMAIL_CONFIG['SENDER_PASSWORD'])
            server.send_message(message)
        
        logger.info(f"✅ Email sent successfully to {recipient}")
        return True
        
    except Exception as e:
        logger.error(f"❌ Failed to send email to {recipient}: {str(e)}")
        return False


def send_registration_confirmation(user_name: str, user_email: str) -> bool:
    """
    Send registration confirmation email to new user
    """
    subject = "✅ Account Created - Awaiting Admin Approval"
    
    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #4DD0CE 0%, #2AB8B6 100%); 
                        padding: 30px; color: white; border-radius: 8px 8px 0 0;">
                <h1 style="margin: 0;">Welcome to MineralTrace! 🎉</h1>
            </div>
            
            <div style="padding: 30px; background: #f5f5f5;">
                <p>Hi <strong>{user_name}</strong>,</p>
                
                <p>Thank you for registering with <strong>MineralTrace</strong>.</p>
                
                <p>Your account has been successfully created with the following details:</p>
                
                <div style="background: white; padding: 15px; border-radius: 5px; margin: 20px 0;">
                    <p><strong>Email:</strong> {user_email}</p>
                    <p><strong>Status:</strong> <span style="color: #FDCB6E;">⏳ Pending Admin Approval</span></p>
                </div>
                
                <p>An administrator will review your account and approve your access shortly. 
                You will receive another email once your account is approved.</p>
                
                <p>Once approved, you'll be able to:</p>
                <ul>
                    <li>✓ Scan and classify mineral samples</li>
                    <li>✓ Extract geoacoustic fingerprints</li>
                    <li>✓ Verify mineral authenticity</li>
                    <li>✓ View detailed analytics and reports</li>
                </ul>
                
                <p style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666;">
                    <small>If you did not create this account, please contact our support team immediately.</small>
                </p>
            </div>
            
            <div style="background: #2AB8B6; color: white; padding: 20px; text-align: center; border-radius: 0 0 8px 8px;">
                <p style="margin: 0;">MineralTrace System | AI-Powered Mineral Traceability</p>
            </div>
        </body>
    </html>
    """
    
    return send_email(user_email, subject, html_content)


def send_admin_approval_notification(new_user_count: int, pending_users: List[dict]) -> bool:
    """
    Send notification to admin about pending approvals
    """
    subject = f"🔔 {new_user_count} New User(s) Awaiting Approval"
    
    users_list = ""
    for user in pending_users[:5]:  # Show first 5 users
        users_list += f"""
        <tr style="border-bottom: 1px solid #ddd;">
            <td style="padding: 10px;">{user.get('name', 'N/A')}</td>
            <td style="padding: 10px;">{user.get('email', 'N/A')}</td>
            <td style="padding: 10px;">{user.get('role', 'N/A')}</td>
            <td style="padding: 10px; color: #FDCB6E;">⏳ Pending</td>
        </tr>
        """
    
    more_users = f"<p style='color: #666;'>... and {len(pending_users) - 5} more users</p>" if len(pending_users) > 5 else ""
    
    pending_users_url = build_webapp_url('users.html#pendingApprovalsSection')

    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; max-width: 700px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #4DD0CE 0%, #2AB8B6 100%); 
                        padding: 30px; color: white; border-radius: 8px 8px 0 0;">
                <h1 style="margin: 0;">🔔 New User Registrations Pending</h1>
            </div>
            
            <div style="padding: 30px; background: #f5f5f5;">
                <p>Hi Administrator,</p>
                
                <p>There are <strong>{new_user_count} new user(s)</strong> awaiting your approval on MineralTrace.</p>
                
                <h3 style="color: #2AB8B6;">Pending Users:</h3>
                
                <table style="width: 100%; background: white; border-collapse: collapse; border-radius: 5px; overflow: hidden;">
                    <thead>
                        <tr style="background: #2AB8B6; color: white;">
                            <th style="padding: 12px; text-align: left;">Name</th>
                            <th style="padding: 12px; text-align: left;">Email</th>
                            <th style="padding: 12px; text-align: left;">Role</th>
                            <th style="padding: 12px; text-align: left;">Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        {users_list}
                    </tbody>
                </table>
                
                {more_users}
                
                <p style="margin-top: 30px;">
                    <a href="{pending_users_url}" 
                       style="background: #4DD0CE; color: white; padding: 12px 30px; 
                              text-decoration: none; border-radius: 5px; display: inline-block;">
                        Review Pending Users
                    </a>
                </p>
                
                <p style="margin-top: 20px; color: #666; font-size: 14px;">
                    Log in to the MineralTrace dashboard to approve or deny these users.
                </p>
            </div>
            
            <div style="background: #2AB8B6; color: white; padding: 20px; text-align: center; border-radius: 0 0 8px 8px;">
                <p style="margin: 0;">MineralTrace System | AI-Powered Mineral Traceability</p>
            </div>
        </body>
    </html>
    """
    
    return send_email(EMAIL_CONFIG['ADMIN_EMAIL'], subject, html_content)


def send_approval_email(user_name: str, user_email: str) -> bool:
    """
    Send approval confirmation email to user
    """
    subject = "✅ Account Approved - Welcome to MineralTrace!"
    
    dashboard_url = build_webapp_url('index.html')

    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #4DD0CE 0%, #2AB8B6 100%); 
                        padding: 30px; color: white; border-radius: 8px 8px 0 0;">
                <h1 style="margin: 0;">✅ Your Account Has Been Approved!</h1>
            </div>
            
            <div style="padding: 30px; background: #f5f5f5;">
                <p>Hi <strong>{user_name}</strong>,</p>
                
                <p>Great news! Your account has been approved by our administrator.</p>
                
                <p style="margin: 30px 0;">
                    <a href="{dashboard_url}" 
                       style="background: #00B894; color: white; padding: 12px 30px; 
                              text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold;">
                        Login to MineralTrace →
                    </a>
                </p>
                
                <p>You can now:</p>
                <ul>
                    <li>✓ Scan mineral samples using the mobile app</li>
                    <li>✓ Extract and store geoacoustic fingerprints</li>
                    <li>✓ Verify mineral authenticity in real-time</li>
                    <li>✓ View your scan history and analytics</li>
                </ul>
                
                <div style="background: #E8F5E9; padding: 15px; border-left: 4px solid #4DD0CE; border-radius: 5px; margin: 20px 0;">
                    <p style="margin: 0; color: #2E7D32;">
                        <strong>📱 Get Started:</strong> Download the MineralTrace mobile app and log in with your email credentials.
                    </p>
                </div>
                
                <p style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666;">
                    <small>If you have any questions, please contact our support team.</small>
                </p>
            </div>
            
            <div style="background: #2AB8B6; color: white; padding: 20px; text-align: center; border-radius: 0 0 8px 8px;">
                <p style="margin: 0;">MineralTrace System | AI-Powered Mineral Traceability</p>
            </div>
        </body>
    </html>
    """
    
    return send_email(user_email, subject, html_content)


def send_admin_created_account_email(user_name: str, user_email: str) -> bool:
    """
    Send notification email when admin creates an account directly
    """
    subject = "✅ Your MineralTrace Account Has Been Created"

    dashboard_url = build_webapp_url('index.html')

    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #4DD0CE 0%, #2AB8B6 100%); 
                        padding: 30px; color: white; border-radius: 8px 8px 0 0;">
                <h1 style="margin: 0;">Welcome to MineralTrace! 🎉</h1>
            </div>

            <div style="padding: 30px; background: #f5f5f5;">
                <p>Hi <strong>{user_name}</strong>,</p>

                <p>An administrator has created your <strong>MineralTrace</strong> account.</p>

                <div style="background: white; padding: 15px; border-radius: 5px; margin: 20px 0;">
                    <p><strong>Email:</strong> {user_email}</p>
                    <p><strong>Status:</strong> <span style="color: #00B894;">✅ Active</span></p>
                </div>

                <p>Your account is ready to use. Please log in with the credentials provided by your administrator.</p>

                <p style="margin: 30px 0;">
                    <a href="{dashboard_url}" 
                       style="background: #00B894; color: white; padding: 12px 30px; 
                              text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold;">
                        Login to MineralTrace →
                    </a>
                </p>

                <p style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666;">
                    <small>If you were not expecting this email, please contact your system administrator.</small>
                </p>
            </div>

            <div style="background: #2AB8B6; color: white; padding: 20px; text-align: center; border-radius: 0 0 8px 8px;">
                <p style="margin: 0;">MineralTrace System | AI-Powered Mineral Traceability</p>
            </div>
        </body>
    </html>
    """

    return send_email(user_email, subject, html_content)


def send_admin_new_account_notification(
    user_name: str,
    user_email: str,
    created_by: str = "system",
    approval_status: str = "pending",
) -> bool:
    """
    Send admin notification when a new account is created.
    """
    status_label = "✅ Approved" if approval_status == "approved" else "⏳ Pending Approval"
    subject = f"📌 New Account Created: {user_name}"

    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; max-width: 650px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #4DD0CE 0%, #2AB8B6 100%);
                        padding: 28px; color: white; border-radius: 8px 8px 0 0;">
                <h1 style="margin: 0;">📌 New MineralTrace Account</h1>
            </div>

            <div style="padding: 28px; background: #f5f5f5;">
                <p>A new account has been created in MineralTrace:</p>

                <div style="background: white; padding: 14px; border-radius: 6px; margin: 18px 0;">
                    <p><strong>Name:</strong> {user_name}</p>
                    <p><strong>Email:</strong> {user_email}</p>
                    <p><strong>Created By:</strong> {created_by}</p>
                    <p><strong>Status:</strong> {status_label}</p>
                </div>

                <p style="color: #666; font-size: 14px;">
                    You can manage this user from the admin dashboard at any time.
                </p>
            </div>

            <div style="background: #2AB8B6; color: white; padding: 18px; text-align: center; border-radius: 0 0 8px 8px;">
                <p style="margin: 0;">MineralTrace System | AI-Powered Mineral Traceability</p>
            </div>
        </body>
    </html>
    """

    return send_email(EMAIL_CONFIG['ADMIN_EMAIL'], subject, html_content)


def send_admin_scan_notification(
    sample_id: str,
    site: str,
    mineral: str,
    predicted_mineral: str,
    confidence: float,
    status: str,
    user_name: str,
    user_id: str,
    scanned_at: str,
) -> bool:
    """
    Send admin notification when a new mining scan/fingerprint is stored.
    """
    subject = f"⛏️ New Mining Scan Recorded: {sample_id}"

    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; max-width: 650px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #4DD0CE 0%, #2AB8B6 100%);
                        padding: 28px; color: white; border-radius: 8px 8px 0 0;">
                <h1 style="margin: 0;">⛏️ New Mining Site Scan</h1>
            </div>

            <div style="padding: 28px; background: #f5f5f5;">
                <p>A new mineral scan has been recorded in MineralTrace:</p>

                <div style="background: white; padding: 14px; border-radius: 6px; margin: 18px 0;">
                    <p><strong>Sample ID:</strong> {sample_id}</p>
                    <p><strong>Site:</strong> {site}</p>
                    <p><strong>Claimed Mineral:</strong> {mineral}</p>
                    <p><strong>Predicted Mineral:</strong> {predicted_mineral}</p>
                    <p><strong>Confidence:</strong> {confidence:.4f}</p>
                    <p><strong>Status:</strong> {status}</p>
                    <p><strong>Scanned By:</strong> {user_name} ({user_id})</p>
                    <p><strong>Timestamp (UTC):</strong> {scanned_at}</p>
                </div>

                <p style="color: #666; font-size: 14px;">
                    Review scan details and audit logs in the admin dashboard.
                </p>
            </div>

            <div style="background: #2AB8B6; color: white; padding: 18px; text-align: center; border-radius: 0 0 8px 8px;">
                <p style="margin: 0;">MineralTrace System | AI-Powered Mineral Traceability</p>
            </div>
        </body>
    </html>
    """

    return send_email(EMAIL_CONFIG['ADMIN_EMAIL'], subject, html_content)


def send_denial_email(user_name: str, user_email: str, reason: str = "") -> bool:
    """
    Send denial notification email to user
    """
    subject = "Account Registration - Status Update"
    
    reason_text = f"<p><strong>Reason:</strong> {reason}</p>" if reason else ""
    
    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #D63031 0%, #E17055 100%); 
                        padding: 30px; color: white; border-radius: 8px 8px 0 0;">
                <h1 style="margin: 0;">Account Registration Status</h1>
            </div>
            
            <div style="padding: 30px; background: #f5f5f5;">
                <p>Hi <strong>{user_name}</strong>,</p>
                
                <p>Thank you for your interest in MineralTrace.</p>
                
                <p>Unfortunately, your registration request has been declined at this time.</p>
                
                {reason_text}
                
                <p>If you believe this is a mistake or would like to reapply, please contact our support team.</p>
                
                <p style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666;">
                    <small>For more information, please visit our website or contact support.</small>
                </p>
            </div>
            
            <div style="background: #E17055; color: white; padding: 20px; text-align: center; border-radius: 0 0 8px 8px;">
                <p style="margin: 0;">MineralTrace System | AI-Powered Mineral Traceability</p>
            </div>
        </body>
    </html>
    """
    
    return send_email(user_email, subject, html_content)
