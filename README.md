# EasyTier Flask Dashboard

این پروژه یک داشبورد وب برای نمایش زنده اطلاعات EasyTier و EasyMesh است.  
با این پروژه می‌توانید:

- جدول **Route** و **Peer** را زنده مشاهده کنید.
- وضعیت **CPU، RAM و شبکه** سرور را ببینید.
- سرویس **EasyMesh** را از طریق وب ریستارت کنید.
- دسترسی با **Basic Auth** امن شده است.

---

## ویژگی‌ها

- Flask backend برای API و نمایش وب
- خواندن username و password از **Environment Variables**
- جدول‌ها و آمار زنده با **JavaScript**
- امکان ریستارت سرویس EasyMesh
- قابل اجرا به عنوان سرویس **systemd**

---

## نصب و اجرا

1. Clone یا دانلود پروژه:

```bash
git clone <Your_GitHub_Repo_URL>
cd <project-folder>

اجرای اسکریپت نصب و راه‌اندازی

```bash
chmod +x setup.sh
./setup.sh


سرویس systemd به صورت خودکار فعال و اجرا می‌شود

```bash
sudo systemctl status easytier.service


دسترسی به وب

بعد از اجرا، مرورگر را باز کنید:


```bash
http://<Server_IP>:<Port>

