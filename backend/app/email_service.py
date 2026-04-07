import os
import smtplib
import threading
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from dotenv import load_dotenv

load_dotenv()

SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
APP_URL = os.getenv("APP_URL", "http://localhost:8000")
EMAIL_ENABLED = bool(SMTP_USER and SMTP_PASSWORD)


def _send_email(to: str, subject: str, html: str):
    if not EMAIL_ENABLED:
        print(f"[EMAIL DISABLED] To: {to} | Subject: {subject}")
        return
    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"Intern KZ <{SMTP_USER}>"
        msg["To"] = to
        msg.attach(MIMEText(html, "html"))
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.ehlo()
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.sendmail(SMTP_USER, to, msg.as_string())
    except Exception as e:
        print(f"[EMAIL ERROR] {e}")


def send_status_email(to: str, name: str, internship_title: str, status: str):
    configs = {
        'accepted': ('Поздравляем! Заявка принята — Intern KZ', 'Принята ✓', '#22C55E',
                     'Поздравляем! Ваша заявка была <b>принята</b>. Ожидайте контакта от работодателя.'),
        'rejected': ('Обновление по заявке — Intern KZ', 'Отклонена', '#EF4444',
                     'К сожалению, ваша заявка была <b>отклонена</b>. Не расстраивайтесь — продолжайте искать!'),
        'pending': ('Заявка на рассмотрении — Intern KZ', 'На рассмотрении', '#6C7DFF',
                    'Ваша заявка <b>находится на рассмотрении</b>. Мы сообщим о результатах.'),
    }
    subject, label, color, message = configs.get(
        status, ('Обновление — Intern KZ', status, '#6C7DFF', ''))
    html = f"""
    <div style="font-family:sans-serif;max-width:480px;margin:auto;padding:32px">
      <div style="background:#6C7DFF;padding:24px 32px;border-radius:16px 16px 0 0;text-align:center">
        <h1 style="color:#fff;margin:0;font-size:28px">Intern KZ</h1>
        <p style="color:rgba(255,255,255,.8);margin:8px 0 0">Статус заявки обновлён</p>
      </div>
      <div style="background:#fff;padding:32px;border-radius:0 0 16px 16px;border:1px solid #E2E8F0;border-top:none">
        <p style="font-size:16px;color:#1E293B">Привет, <b>{name}</b>!</p>
        <p style="color:#64748B">Статус вашей заявки на стажировку <b>«{internship_title}»</b> изменён:</p>
        <div style="text-align:center;margin:24px 0">
          <span style="background:{color};color:#fff;padding:10px 24px;border-radius:10px;font-weight:700;font-size:15px;display:inline-block">
            {label}
          </span>
        </div>
        <p style="color:#64748B">{message}</p>
        <p style="color:#CBD5E1;font-size:12px;margin-top:24px;border-top:1px solid #F1F5F9;padding-top:16px">
          © 2025 Intern KZ
        </p>
      </div>
    </div>
    """
    thread = threading.Thread(
        target=_send_email, args=(to, subject, html), daemon=True)
    thread.start()


def send_verification_email(to: str, name: str, token: str):
    link = f"{APP_URL}/auth/verify/{token}"
    html = f"""
    <div style="font-family:sans-serif;max-width:480px;margin:auto;padding:32px">
      <div style="background:#6C7DFF;padding:24px 32px;border-radius:16px 16px 0 0;text-align:center">
        <h1 style="color:#fff;margin:0;font-size:28px">Intern KZ</h1>
        <p style="color:rgba(255,255,255,.8);margin:8px 0 0">Подтвердите email</p>
      </div>
      <div style="background:#fff;padding:32px;border-radius:0 0 16px 16px;border:1px solid #E2E8F0;border-top:none">
        <p style="font-size:16px;color:#1E293B">Привет, <b>{name}</b>!</p>
        <p style="color:#64748B">Нажмите кнопку ниже, чтобы подтвердить ваш email-адрес и активировать аккаунт.</p>
        <div style="text-align:center;margin:32px 0">
          <a href="{link}" style="background:#6C7DFF;color:#fff;text-decoration:none;padding:14px 32px;border-radius:12px;font-weight:700;font-size:15px;display:inline-block">
            Подтвердить email
          </a>
        </div>
        <p style="color:#94A3B8;font-size:13px">Если вы не регистрировались — просто проигнорируйте это письмо.</p>
        <p style="color:#CBD5E1;font-size:12px;margin-top:24px;border-top:1px solid #F1F5F9;padding-top:16px">
          Ссылка действительна 24 часа.<br>
          © 2025 Intern KZ
        </p>
      </div>
    </div>
    """
    thread = threading.Thread(
        target=_send_email,
        args=(to, "Подтвердите email — Intern KZ", html),
        daemon=True,
    )
    thread.start()
