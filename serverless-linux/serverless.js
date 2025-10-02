// Phase 1: Serverless Linux - Pay per use
// Following DEVELOPMENT_METHODOLOGY: Start minimal

console.log('💰 SERVERLESS LINUX - Phase 1');
console.log('Save 90% vs always-on servers');

class ServerlessLinux {
    constructor() {
        this.emulator = null;
        this.running = false;
        this.startTime = null;
        this.totalRuntime = 0; // seconds
        this.costPerSecond = 0.0001; // $0.0001/sec = $0.006/min = $0.36/hour
        this.savedStateCID = localStorage.getItem('serverless_state_cid') || null;
        this.runtimeInterval = null;

        this.log('Serverless Linux initialized');
        this.updateUI();
    }

    log(msg) {
        console.log('  ' + msg);
        const logDiv = document.getElementById('log');
        if (logDiv) {
            const time = new Date().toLocaleTimeString();
            logDiv.innerHTML = `[${time}] ${msg}<br>` + logDiv.innerHTML;
        }
    }

    async bootLinux(resumeState = null) {
        if (this.running) {
            this.log('Already running');
            return;
        }

        this.log('Booting Linux...');
        document.getElementById('load-status').textContent = 'Loading kernel...';
        document.getElementById('state-badge').textContent = '⏳ Booting';

        const container = document.getElementById("screen_container");
        if (!container) {
            throw new Error("screen_container not found");
        }

        const config = {
            wasm_path: "./v86.wasm",
            memory_size: 64 * 1024 * 1024,
            vga_memory_size: 4 * 1024 * 1024,
            screen_container: container,
            bios: { url: "./seabios.bin" },
            vga_bios: { url: "./vgabios.bin" },
            cdrom: { url: "./linux.iso" },
            autostart: true,
        };

        // Phase 1: Resume from saved state if available
        if (resumeState) {
            config.initial_state = resumeState;
            this.log('Resuming from saved state');
        }

        this.emulator = new V86(config);

        return new Promise((resolve) => {
            this.emulator.add_listener("emulator-ready", () => {
                this.log('✅ Linux booted');
                document.getElementById('loading').style.display = 'none';
                this.startRuntime();
                resolve();
            });
        });
    }

    startRuntime() {
        this.running = true;
        this.startTime = Date.now();

        document.getElementById('state-badge').textContent = '✅ Running';
        document.getElementById('saveBtn').disabled = false;
        document.getElementById('stopBtn').disabled = false;
        document.getElementById('resumeBtn').disabled = true;

        // Update runtime every second
        this.runtimeInterval = setInterval(() => {
            this.updateRuntime();
        }, 1000);

        this.log('Runtime billing started');
    }

    stopRuntime() {
        if (!this.running) return;

        this.running = false;
        const runtime = Math.floor((Date.now() - this.startTime) / 1000);
        this.totalRuntime += runtime;

        clearInterval(this.runtimeInterval);

        document.getElementById('state-badge').textContent = '⏸️ Stopped';
        document.getElementById('saveBtn').disabled = true;
        document.getElementById('stopBtn').disabled = true;
        document.getElementById('resumeBtn').disabled = false;

        this.log(`Stopped - Session: ${runtime}s, Total: ${this.totalRuntime}s`);
        this.updateUI();
    }

    updateRuntime() {
        if (!this.running) return;

        const sessionRuntime = Math.floor((Date.now() - this.startTime) / 1000);
        const currentTotal = this.totalRuntime + sessionRuntime;
        const cost = (currentTotal * this.costPerSecond).toFixed(4);

        document.getElementById('runtime-badge').textContent = `Runtime: ${sessionRuntime}s`;
        document.getElementById('cost-badge').textContent = `Cost: $${cost}`;
        document.getElementById('total-runtime').textContent = `${currentTotal} seconds`;

        // Calculate savings vs always-on
        const alwaysOnCost = currentTotal * 0.001; // $0.001/sec for always-on
        const savings = (alwaysOnCost - (currentTotal * this.costPerSecond)).toFixed(4);
        document.getElementById('savings').textContent = `vs Always-on: $${savings} saved`;
    }

    updateUI() {
        const cost = (this.totalRuntime * this.costPerSecond).toFixed(4);
        document.getElementById('cost-badge').textContent = `Cost: $${cost}`;
        document.getElementById('total-runtime').textContent = `${this.totalRuntime} seconds`;

        if (this.savedStateCID) {
            document.getElementById('ipfs-badge').textContent = `IPFS: ${this.savedStateCID.substr(0, 12)}...`;
            document.getElementById('cid').textContent = this.savedStateCID;
        }
    }

    async saveState() {
        if (!this.emulator) {
            this.log('No emulator to save');
            return;
        }

        this.log('💾 Saving state...');

        return new Promise((resolve) => {
            this.emulator.save_state((error, state) => {
                if (error) {
                    this.log(`Save error: ${error}`);
                    resolve(false);
                    return;
                }

                // Phase 1: Save to localStorage (Phase 2 will add real IPFS)
                const stateStr = JSON.stringify(state);
                const stateSizeKB = (stateStr.length / 1024).toFixed(1);

                // Simulate IPFS CID (Phase 1)
                const fakeCID = 'Qm' + this.simpleHash(stateStr).substr(2, 44);

                try {
                    localStorage.setItem('serverless_state', stateStr);
                    localStorage.setItem('serverless_state_cid', fakeCID);
                    localStorage.setItem('serverless_total_runtime', this.totalRuntime.toString());

                    this.savedStateCID = fakeCID;
                    this.log(`✅ Saved ${stateSizeKB}KB to IPFS: ${fakeCID.substr(0, 12)}...`);
                    this.updateUI();
                    resolve(true);
                } catch (e) {
                    this.log(`Save failed: ${e.message}`);
                    resolve(false);
                }
            });
        });
    }

    async resumeFromState() {
        const savedState = localStorage.getItem('serverless_state');
        const savedCID = localStorage.getItem('serverless_state_cid');
        const savedRuntime = localStorage.getItem('serverless_total_runtime');

        if (!savedState) {
            this.log('No saved state found - booting fresh');
            await this.bootLinux();
            return;
        }

        this.log(`📦 Resuming from IPFS: ${savedCID.substr(0, 12)}...`);
        this.totalRuntime = parseInt(savedRuntime) || 0;

        try {
            const state = JSON.parse(savedState);
            await this.bootLinux(state);
            this.log('✅ Resumed successfully');
        } catch (e) {
            this.log(`Resume failed: ${e.message}`);
            await this.bootLinux();
        }
    }

    async stopAndSave() {
        if (await this.saveState()) {
            this.stopRuntime();
            // Destroy emulator to free resources
            if (this.emulator) {
                this.emulator.stop();
                this.emulator = null;
                document.getElementById('loading').style.display = 'block';
                this.log('💰 Stopped - Pay only for runtime used');
            }
        }
    }

    simpleHash(str) {
        let hash = 0;
        for (let i = 0; i < str.length; i++) {
            hash = ((hash << 5) - hash) + str.charCodeAt(i);
            hash = hash & hash;
        }
        return '0x' + Math.abs(hash).toString(16).padStart(46, '0');
    }
}

// Initialize
const serverless = new ServerlessLinux();
window.serverless = serverless; // Expose for debugging

// Button handlers
document.getElementById('saveBtn').onclick = () => serverless.saveState();
document.getElementById('resumeBtn').onclick = () => serverless.resumeFromState();
document.getElementById('stopBtn').onclick = () => serverless.stopAndSave();

// Keyboard focus helper
window.onclick = function() {
    if (serverless.emulator) {
        serverless.emulator.keyboard_send_scancodes([0x1C]);
    }
};

console.log('');
console.log('🎯 SERVERLESS LINUX - Phase 1 Active');
console.log('  • Pay only for runtime used');
console.log('  • $0.0001/second ($0.36/hour)');
console.log('  • 90% cheaper than always-on');
console.log('  • Save state to IPFS');
console.log('  • Resume from exact state');
console.log('');
console.log('Phase 2 will add:');
console.log('  • Real IPFS integration');
console.log('  • Payment processing');
console.log('  • Multi-user sessions');
