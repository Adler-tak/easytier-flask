#!/bin/bash
set -e

APP_FILE="app.py"
TEMPLATES_DIR="templates"
HTML_FILE="$TEMPLATES_DIR/index.html"
SERVICE_NAME="easytier"
PROJECT_DIR=$(pwd)

# درخواست یوزرنیم و پسورد از کاربر
read -p "لطفا یوزرنیم را وارد کنید: " INPUT_USER
read -sp "لطفا پسورد را وارد کنید: " INPUT_PASS
echo
read -p "لطفا پورت Flask را وارد کنید (مثلاً 65530): " INPUT_PORT

# ذخیره در متغیرهای محیطی برای session جاری
export EASYTIER_USER="$INPUT_USER"
export EASYTIER_PASS="$INPUT_PASS"
export EASYTIER_PORT="$INPUT_PORT"

echo "✅ یوزرنیم، پسورد و پورت تنظیم شدند."

# ساخت فولدر templates
mkdir -p "$TEMPLATES_DIR"

# ساخت app.py
cat > "$APP_FILE" <<'EOF'
from flask import Flask, jsonify, render_template, request, Response
import subprocess, base64, psutil, socket, time, netifaces, os

app = Flask(__name__)

USERNAME = os.getenv("EASYTIER_USER", "admin")
PASSWORD = os.getenv("EASYTIER_PASS", "1234")
PORT = int(os.getenv("EASYTIER_PORT", 65530))

def check_auth(auth_header):
    if not auth_header or not auth_header.startswith('Basic '):
        return False
    encoded = auth_header.split(' ')[1]
    try:
        decoded = base64.b64decode(encoded).decode('utf-8')
        username, password = decoded.split(':')
        return username == USERNAME and password == PASSWORD
    except:
        return False

@app.before_request
def require_auth():
    if request.path.startswith('/static'):
        return
    auth = request.headers.get('Authorization')
    if not check_auth(auth):
        return Response('نیاز به ورود دارید.', 401, {'WWW-Authenticate': 'Basic realm="Login Required"'})

def get_data(command):
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=2)
        if result.returncode != 0:
            return {"error": result.stderr.strip()}
        lines = [line for line in result.stdout.split('\n') if '│' in line]
        if not lines:
            return {"headers": [], "rows": []}
        headers = [h.strip() for h in lines[0].strip('│').split('│')]
        rows = []
        for line in lines[1:]:
            cols = [c.strip() for c in line.strip('│').split('│')]
            if len(cols) == len(headers):
                rows.append(dict(zip(headers, cols)))
        return {"headers": headers, "rows": rows}
    except Exception as e:
        return {"error": str(e)}

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/data')
def api_data():
    return jsonify(get_data(['/root/easytier/easytier-cli', 'route']))

@app.route('/api/peer')
def api_peer():
    return jsonify(get_data(['/root/easytier/easytier-cli', 'peer']))

@app.route('/api/stats')
def api_stats():
    cpu = psutil.cpu_percent(interval=None)
    ram = psutil.virtual_memory().percent
    net1 = psutil.net_io_counters()
    time.sleep(0.5)
    net2 = psutil.net_io_counters()
    sent_kbps = round((net2.bytes_sent - net1.bytes_sent) * 2 / 1024, 2)
    recv_kbps = round((net2.bytes_recv - net1.bytes_recv) * 2 / 1024, 2)
    ips = []
    try:
        ips.append(socket.gethostbyname(socket.gethostname()))
    except:
        pass
    for iface in netifaces.interfaces():
        addrs = netifaces.ifaddresses(iface)
        if netifaces.AF_INET in addrs:
            for link in addrs[netifaces.AF_INET]:
                ip = link.get('addr')
                if ip and ip not in ips and not ip.startswith('127.'):
                    ips.append(ip)
    return jsonify({"cpu": cpu,"ram": ram,"net_sent_kbps": sent_kbps,"net_recv_kbps": recv_kbps,"ips": ips})

@app.route('/api/restart', methods=['POST'])
def restart_service():
    SERVICE_FILE = '/etc/systemd/system/easymesh.service'
    check_file = subprocess.run(['test', '-f', SERVICE_FILE])
    if check_file.returncode != 0:
        return jsonify({"status":"error","message":"EasyMesh service does not exist."}), 404
    result = subprocess.run(['sudo','systemctl','restart','easymesh.service'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode == 0:
        return jsonify({"status":"success","message":"EasyMesh service restarted successfully."})
    else:
        return jsonify({"status":"error","message":"Failed to restart EasyMesh service."}), 500

if __name__=='__main__':
    app.run(host='0.0.0.0', port=PORT)
EOF

# ساخت index.html کامل (همان نسخه قبلی)
cat > "$HTML_FILE" <<'EOF'
<!DOCTYPE html>
<html lang="fa">
<head>
<meta charset="UTF-8">
<title>نمایش زنده EasyTier</title>
<style>
body { font-family: sans-serif; padding: 20px; direction: rtl; background: #f7f7f7; }
h2 { margin-top: 0; }
nav { margin-bottom: 20px; }
button.tab-btn { padding: 10px 20px; margin-left: 10px; cursor: pointer; border: 1px solid #aaa; background-color: white; border-radius: 5px 5px 0 0; }
button.tab-btn.active { background-color: #ddd; font-weight: bold; }
table { border-collapse: collapse; width: 100%; background: white; }
th, td { border: 1px solid #ccc; padding: 8px; text-align: center; }
th { background-color: #eee; }
#stats { margin-top: 20px; background: white; padding: 10px; border: 1px solid #ccc; font-size: 16px; }
#restart-btn { margin-top: 20px; padding: 10px 20px; background-color: #f44336; color: white; border: none; border-radius: 5px; cursor: pointer; }
#restart-msg { margin-top: 10px; font-weight: bold; }
</style>
</head>
<body>

<h2>نمایش زنده EasyTier</h2>

<nav>
  <button class="tab-btn active" data-tab="route">جدول Route</button>
  <button class="tab-btn" data-tab="peer">جدول Peer</button>
</nav>

<div id="tables">
  <table id="data-table">
    <thead><tr id="header-row"></tr></thead>
    <tbody></tbody>
  </table>
</div>

<div id="stats">
  <div>CPU: <span id="cpu">--%</span></div>
  <div>RAM: <span id="ram">--%</span></div>
  <div>IPهای سرور: <span id="ips">در حال بارگذاری...</span></div>
  <div>شبکه - ارسال: <span id="net-sent">--</span> کیلوبایت بر ثانیه</div>
  <div>شبکه - دریافت: <span id="net-recv">--</span> کیلوبایت بر ثانیه</div>
</div>

<button id="restart-btn">ریستارت سرویس EasyMesh</button>
<div id="restart-msg"></div>

<script>
const authHeader = 'Basic ' + btoa(prompt("Username") + ":" + prompt("Password"));
let currentTab = 'route';

function setActiveTab(tabName){
  currentTab = tabName;
  document.querySelectorAll('.tab-btn').forEach(btn=>btn.classList.toggle('active',btn.dataset.tab===tabName));
  fetchAndRenderData();
}

document.querySelectorAll('.tab-btn').forEach(btn=>btn.addEventListener('click',()=>setActiveTab(btn.dataset.tab)));

async function fetchAndRenderData(){
  const url = currentTab==='route'?'/api/data':'/api/peer';
  try{
    const res = await fetch(url, {headers:{Authorization:authHeader}});
    if(!res.ok) throw new Error('خطا در دریافت داده‌ها');
    const data = await res.json();
    const tbody = document.querySelector('#data-table tbody');
    const headerRow = document.getElementById('header-row');
    tbody.innerHTML=''; headerRow.innerHTML='';
    if(!data.rows||data.rows.length===0){
      tbody.innerHTML='<tr><td colspan="20">داده‌ای موجود نیست</td></tr>';
      return;
    }
    data.headers.forEach(h=>{const th=document.createElement('th'); th.textContent=h; headerRow.appendChild(th);});
    data.rows.forEach(row=>{const tr=document.createElement('tr'); data.headers.forEach(h=>{const td=document.createElement('td'); td.textContent=row[h]||''; tr.appendChild(td);}); tbody.appendChild(tr);});
  } catch(e){console.error(e);}
}

async function fetchStats(){
  try{
    const res = await fetch('/api/stats',{headers:{Authorization:authHeader}});
    if(!res.ok) throw new Error('خطا در دریافت آمار');
    const data = await res.json();
    document.getElementById('cpu').textContent = data.cpu+'%';
    document.getElementById('ram').textContent = data.ram+'%';
    document.getElementById('net-sent').textContent = data.net_sent_kbps;
    document.getElementById('net-recv').textContent = data.net_recv_kbps;
    document.getElementById('ips').textContent = data.ips.join(', ');
  } catch(e){console.error(e);}
}

setActiveTab('route');
setInterval(fetchStats,1000);
setInterval(fetchAndRenderData,2000);

document.getElementById('restart-btn').addEventListener('click', async ()=>{
  const msgDiv = document.getElementById('restart-msg');
  msgDiv.style.color='black';
  msgDiv.textContent='در حال ریستارت سرویس...';
  try{
    const res = await fetch('/api/restart',{method:'POST', headers:{Authorization:authHeader}});
    const data = await res.json();
    if(res.ok){msgDiv.style.color='green'; msgDiv.textContent = data.message;}
    else{msgDiv.style.color='red'; msgDiv.textContent = data.message || 'خطا در ریستارت سرویس';}
  }catch(e){msgDiv.style.color='red'; msgDiv.textContent='خطا در برقراری ارتباط با سرور';}
});
</script>

</body>
</html>
EOF

# نصب پیش‌نیازها
if ! command -v pip3 &>/dev/null; then
  apt update && apt install -y python3-pip
fi
python3 -m pip install --upgrade --ignore-installed flask psutil netifaces

# ساخت سرویس systemd با پورت و متغیرهای محیطی
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=EasyTier Flask Service
After=network.target

[Service]
User=root
WorkingDirectory=$PROJECT_DIR
Environment="EASYTIER_USER=$EASYTIER_USER"
Environment="EASYTIER_PASS=$EASYTIER_PASS"
Environment="EASYTIER_PORT=$EASYTIER_PORT"
ExecStart=/usr/bin/python3 $PROJECT_DIR/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# فعال و راه‌اندازی سرویس
systemctl daemon-reload
systemctl enable $SERVICE_NAME.service
systemctl restart $SERVICE_NAME.service

echo "✅ سرویس systemd ساخته و روی پورت $EASYTIER_PORT اجرا شد."
echo "برای بررسی وضعیت: sudo systemctl status $SERVICE_NAME.service"
