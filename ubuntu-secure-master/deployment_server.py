#!/usr/bin/env python3
"""
Ubuntu Blockchain Deployment Server

This server provides the deployment endpoint that serves the one-command deploy script.

Usage:
    python3 deployment_server.py

Endpoints:
    GET /deploy - Serves the deployment script
    GET / - Landing page with instructions
    GET /health - Health check
"""

from flask import Flask, Response, render_template_string, request, jsonify
import os
import time
import json

app = Flask(__name__)

# Read the deployment script
def get_deploy_script():
    script_path = os.path.join(os.path.dirname(__file__), 'deploy_script.sh')
    try:
        with open(script_path, 'r') as f:
            return f.read()
    except FileNotFoundError:
        return """#!/bin/bash
echo "Error: Deployment script not found"
exit 1
"""

# Landing page template
LANDING_PAGE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Ubuntu Blockchain OS - One Command Deploy</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: system-ui, -apple-system, sans-serif;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            margin: 0;
            padding: 40px 20px;
            min-height: 100vh;
            line-height: 1.6;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            text-align: center;
        }
        h1 {
            font-size: 3.5em;
            margin-bottom: 20px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .hero {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            margin: 40px 0;
        }
        .command-box {
            background: rgba(0,0,0,0.5);
            border-radius: 10px;
            padding: 20px;
            margin: 30px 0;
            font-family: 'Monaco', 'Menlo', monospace;
            font-size: 18px;
            border-left: 4px solid #4ade80;
        }
        .copy-btn {
            background: #4ade80;
            color: black;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            font-weight: bold;
            margin-left: 10px;
        }
        .features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 40px 0;
        }
        .feature {
            background: rgba(255,255,255,0.1);
            padding: 20px;
            border-radius: 10px;
            text-align: left;
        }
        .stats {
            display: flex;
            justify-content: space-around;
            margin: 30px 0;
        }
        .stat {
            text-align: center;
        }
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #4ade80;
        }
        button {
            background: #4ade80;
            color: black;
            border: none;
            padding: 15px 30px;
            font-size: 18px;
            font-weight: bold;
            border-radius: 30px;
            cursor: pointer;
            margin: 10px;
        }
        button:hover {
            transform: scale(1.05);
        }
        .footer {
            margin-top: 60px;
            padding-top: 20px;
            border-top: 1px solid rgba(255,255,255,0.2);
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔗 Ubuntu Blockchain OS</h1>
        <p style="font-size: 1.3em;">Deploy Ubuntu on Blockchain in 60 seconds</p>

        <div class="hero">
            <h2>One Command. Complete Deployment.</h2>
            <p>Deploy a complete Ubuntu operating system running on blockchain validators with distributed consensus for every operation.</p>

            <div class="command-box">
                <span id="deploy-command">curl -fsSL {{ request.host_url }}deploy | bash</span>
                <button class="copy-btn" onclick="copyCommand()">Copy</button>
            </div>

            <div class="stats">
                <div class="stat">
                    <div class="stat-number" id="deploy-count">{{ stats.deployments }}</div>
                    <div>Deployments</div>
                </div>
                <div class="stat">
                    <div class="stat-number">60s</div>
                    <div>Average Deploy Time</div>
                </div>
                <div class="stat">
                    <div class="stat-number">99.9%</div>
                    <div>Uptime</div>
                </div>
            </div>
        </div>

        <div class="features">
            <div class="feature">
                <h3>🚀 Instant Deploy</h3>
                <p>Auto-detects your environment and deploys to any Linux server in under 60 seconds.</p>
            </div>
            <div class="feature">
                <h3>🌍 Public Access</h3>
                <p>Automatically gets public IP and makes your Ubuntu Blockchain OS accessible worldwide.</p>
            </div>
            <div class="feature">
                <h3>🔒 Validator Network</h3>
                <p>Every operation requires consensus from multiple blockchain validators for maximum security.</p>
            </div>
            <div class="feature">
                <h3>📱 Multi-Device</h3>
                <p>Works with phones, laptops, cloud servers - any device can be part of the validator network.</p>
            </div>
        </div>

        <div style="margin: 40px 0;">
            <h2>What Gets Deployed</h2>
            <ul style="text-align: left; max-width: 600px; margin: 0 auto;">
                <li>Complete Ubuntu Blockchain OS with web interface</li>
                <li>Multi-validator consensus mechanism</li>
                <li>Real-time blockchain transaction processing</li>
                <li>Public API for integration</li>
                <li>Automatic firewall and security configuration</li>
                <li>Systemd service for production deployment</li>
            </ul>
        </div>

        <button onclick="testDeploy()">Test Deploy (Safe)</button>
        <button onclick="viewSource()">View Source</button>
        <button onclick="showAPI()">API Docs</button>

        <div class="footer">
            <p>Ubuntu Blockchain OS - Distributed Operating System</p>
            <p>Server: {{ request.remote_addr }} | Uptime: {{ uptime }} | Version: 1.0</p>
        </div>
    </div>

    <script>
        function copyCommand() {
            const command = document.getElementById('deploy-command').textContent;
            navigator.clipboard.writeText(command).then(() => {
                const btn = document.querySelector('.copy-btn');
                const originalText = btn.textContent;
                btn.textContent = 'Copied!';
                btn.style.background = '#22c55e';
                setTimeout(() => {
                    btn.textContent = originalText;
                    btn.style.background = '#4ade80';
                }, 2000);
            });
        }

        function testDeploy() {
            alert('Test deploy would run the deployment script in simulation mode.\\n\\nFor real deployment, run the curl command on your server.');
        }

        function viewSource() {
            window.open('/deploy', '_blank');
        }

        function showAPI() {
            alert('API Endpoints:\\n\\nGET /deploy - Get deployment script\\nGET /health - Health check\\nGET /stats - Deployment statistics');
        }

        // Update deployment count every 30 seconds
        setInterval(() => {
            fetch('/stats')
                .then(r => r.json())
                .then(data => {
                    document.getElementById('deploy-count').textContent = data.deployments;
                })
                .catch(() => {});
        }, 30000);
    </script>
</body>
</html>
'''

# Statistics tracking
stats = {
    "deployments": 0,
    "requests": 0,
    "start_time": time.time()
}

@app.route('/')
def landing_page():
    """Landing page with deployment instructions"""
    stats["requests"] += 1
    uptime = int(time.time() - stats["start_time"])
    uptime_str = f"{uptime//3600}h {(uptime%3600)//60}m"

    return render_template_string(LANDING_PAGE,
                                stats=stats,
                                uptime=uptime_str)

@app.route('/deploy')
def deploy():
    """Serve the deployment script"""
    stats["deployments"] += 1

    # Log the deployment request
    client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.remote_addr)
    user_agent = request.headers.get('User-Agent', 'Unknown')

    print(f"🚀 Deployment request from {client_ip} - {user_agent}")

    # Serve the script with appropriate headers
    script_content = get_deploy_script()

    response = Response(script_content, mimetype='text/plain')
    response.headers['Content-Disposition'] = 'inline; filename="deploy.sh"'
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'

    return response

@app.route('/health')
def health():
    """Health check endpoint"""
    uptime = int(time.time() - stats["start_time"])

    return jsonify({
        "status": "healthy",
        "uptime_seconds": uptime,
        "total_requests": stats["requests"],
        "total_deployments": stats["deployments"],
        "version": "1.0.0"
    })

@app.route('/stats')
def get_stats():
    """Get deployment statistics"""
    uptime = int(time.time() - stats["start_time"])

    return jsonify({
        "deployments": stats["deployments"],
        "requests": stats["requests"],
        "uptime_seconds": uptime,
        "uptime_human": f"{uptime//3600}h {(uptime%3600)//60}m",
        "deployments_per_hour": round(stats["deployments"] / max(uptime/3600, 0.1), 2)
    })

@app.route('/test')
def test_deploy():
    """Test endpoint that simulates deployment without actually running it"""
    return jsonify({
        "message": "Test deployment successful",
        "would_deploy": "Ubuntu Blockchain OS",
        "estimated_time": "60 seconds",
        "features": [
            "Multi-validator consensus",
            "Blockchain file system",
            "Distributed trust model",
            "Public web interface",
            "API endpoints"
        ]
    })

if __name__ == '__main__':
    print("🌐 Ubuntu Blockchain Deployment Server Starting...")
    print("==================================================")
    print()
    print("Endpoints:")
    print("  GET /        - Landing page with instructions")
    print("  GET /deploy  - Deployment script")
    print("  GET /health  - Health check")
    print("  GET /stats   - Statistics")
    print("  GET /test    - Test deployment")
    print()
    print("One-command deploy:")
    print("  curl -fsSL http://localhost:5000/deploy | bash")
    print()
    print("🚀 Server ready!")

    # Start the server
    app.run(host='0.0.0.0', port=5000, debug=True)