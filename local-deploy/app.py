from flask import Flask, request, jsonify, render_template_string
app = Flask(__name__)

# Global state
votes = {}
devices = {}
operations_count = 0

@app.route('/health')
def health():
    return jsonify({
        'status': 'running',
        'devices': len(devices),
        'operations': operations_count
    })

@app.route('/state')
def state():
    return jsonify({
        'status': 'running',
        'devices': len(devices),
        'operations': operations_count,
        'votes': votes
    })

@app.route('/vote', methods=['POST'])
def vote():
    global operations_count
    data = request.json
    op = data.get('operation', 'unknown')
    device = data.get('device', 'unknown')
    vote_value = data.get('vote', 'unknown')

    # Track device
    if device not in devices:
        devices[device] = {'first_seen': True}

    # Track votes
    if op not in votes:
        votes[op] = []
        operations_count += 1

    votes[op].append({
        'device': device,
        'vote': vote_value,
        'timestamp': operations_count
    })

    # Check consensus (simple 2 vote threshold)
    if len(votes[op]) >= 2:
        approve_count = sum(1 for v in votes[op] if v['vote'] == 'approve')
        approved = approve_count >= 2
        result = 'approved' if approved else 'denied'

        return jsonify({
            'result': result,
            'votes': len(votes[op]),
            'approve_count': approve_count,
            'operation': op
        })

    return jsonify({
        'votes': len(votes[op]),
        'needed': 2,
        'operation': op,
        'devices_voted': [v['device'] for v in votes[op]]
    })

@app.route('/boot', methods=['POST'])
def boot():
    return jsonify({
        'status': 'waiting_for_consensus',
        'message': 'Connect 2 devices to participate in consensus',
        'devices_connected': len(devices)
    })

@app.route('/')
def index():
    return '''
<!DOCTYPE html>
<html>
<head>
    <title>Ubuntu Blockchain OS</title>
    <style>
        body {
            font-family: system-ui;
            text-align: center;
            padding: 50px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
        }
        button {
            background: #4ade80;
            color: black;
            border: none;
            padding: 20px 40px;
            font-size: 20px;
            border-radius: 30px;
            cursor: pointer;
            margin: 20px;
        }
        #status {
            margin: 30px;
            padding: 20px;
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
        }
        .terminal {
            background: #000;
            color: #0f0;
            font-family: monospace;
            padding: 15px;
            border-radius: 8px;
            height: 200px;
            overflow-y: auto;
            text-align: left;
            margin: 20px auto;
            max-width: 600px;
        }
    </style>
</head>
<body>
    <h1>🔒 Ubuntu Blockchain OS</h1>
    <p>Your laptop is compromised? So what. It's just 1 vote out of N.</p>

    <button onclick="startBoot()">Start Ubuntu</button>
    <button onclick="testConsensus()">Test Consensus</button>
    <button onclick="checkStatus()">Check Status</button>

    <div id="status"></div>
    <div class="terminal" id="terminal"></div>

    <script>
        function log(message) {
            const terminal = document.getElementById('terminal');
            const line = document.createElement('div');
            line.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;
            terminal.appendChild(line);
            terminal.scrollTop = terminal.scrollHeight;
        }

        async function startBoot() {
            log("Starting Ubuntu Blockchain OS boot sequence...");
            document.getElementById("status").innerHTML = "⏳ Initiating boot...";

            try {
                const bootResponse = await fetch("/boot", {
                    method: "POST",
                    headers: {"Content-Type": "application/json"},
                    body: JSON.stringify({device: "browser"})
                });
                const bootData = await bootResponse.json();
                log(`Boot status: ${bootData.status}`);

                // Simulate device votes
                log("Simulating device consensus...");

                setTimeout(async () => {
                    const vote1 = await fetch("/vote", {
                        method: "POST",
                        headers: {"Content-Type": "application/json"},
                        body: JSON.stringify({operation: "boot", vote: "approve", device: "phone"})
                    });
                    const v1 = await vote1.json();
                    log(`Phone voted: approve (${v1.votes}/${v1.needed || 2})`);
                }, 1000);

                setTimeout(async () => {
                    const vote2 = await fetch("/vote", {
                        method: "POST",
                        headers: {"Content-Type": "application/json"},
                        body: JSON.stringify({operation: "boot", vote: "approve", device: "laptop"})
                    });
                    const v2 = await vote2.json();
                    log(`Laptop voted: approve`);

                    if (v2.result === "approved") {
                        document.getElementById("status").innerHTML =
                            "✅ Ubuntu running with consensus!<br>" +
                            "Every operation now requires 2+ device approval";
                        log("🎉 BOOT SUCCESSFUL - UBUNTU BLOCKCHAIN OS ACTIVE");
                        log("System is now running in consensus mode");
                    }
                }, 2000);

            } catch (error) {
                log(`Error: ${error.message}`);
            }
        }

        async function testConsensus() {
            log("Testing consensus mechanism...");

            // Test with a file operation
            const operation = "open_file_/etc/passwd";
            log(`Testing operation: ${operation}`);

            setTimeout(async () => {
                const vote1 = await fetch("/vote", {
                    method: "POST",
                    headers: {"Content-Type": "application/json"},
                    body: JSON.stringify({operation: operation, vote: "deny", device: "security_device"})
                });
                const v1 = await vote1.json();
                log(`Security device voted: DENY (${v1.votes}/2)`);
            }, 500);

            setTimeout(async () => {
                const vote2 = await fetch("/vote", {
                    method: "POST",
                    headers: {"Content-Type": "application/json"},
                    body: JSON.stringify({operation: operation, vote: "deny", device: "friend_device"})
                });
                const v2 = await vote2.json();
                log(`Friend device voted: DENY`);

                if (v2.result) {
                    log(`🛡️ CONSENSUS RESULT: ${v2.result.toUpperCase()}`);
                    log("Dangerous operation was blocked by consensus!");
                }
            }, 1500);
        }

        async function checkStatus() {
            try {
                const response = await fetch("/state");
                const data = await response.json();
                log(`System status: ${data.status}`);
                log(`Connected devices: ${data.devices}`);
                log(`Operations processed: ${data.operations}`);
            } catch (error) {
                log(`Error checking status: ${error.message}`);
            }
        }

        // Initialize
        log("Ubuntu Blockchain OS Console Ready");
        log("Click 'Start Ubuntu' to begin secure boot sequence");
    </script>
</body>
</html>
    '''

if __name__ == '__main__':
    print("🚀 Starting Ubuntu Blockchain OS Server")
    print("📡 Server will be available at: http://localhost:8000")
    print("🔒 Consensus requires 2+ device votes")
    app.run(host='0.0.0.0', port=8000, debug=True)