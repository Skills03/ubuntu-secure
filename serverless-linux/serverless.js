// Phase 1: Pay-per-use billing
// Phase 2: Save state to localStorage

console.log('💰 SERVERLESS LINUX - Phases 1-2');

class ServerlessLinux {
    constructor() {
        this.emulator = null;
        this.running = false;
        this.startTime = null;
        this.totalRuntime = parseInt(localStorage.getItem('totalRuntime')) || 0;
        this.costPerSecond = 0.0001;
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

        if (resumeState) {
            config.initial_state = resumeState;
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
        localStorage.setItem('totalRuntime', this.totalRuntime.toString());

        clearInterval(this.runtimeInterval);

        document.getElementById('state-badge').textContent = '⏸️ Stopped';
        document.getElementById('saveBtn').disabled = true;
        document.getElementById('stopBtn').disabled = true;

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
    }

    // Phase 2: Save state to localStorage
    async saveState() {
        if (!this.emulator) return;

        this.log('💾 Saving state...');
        try {
            const state = await this.emulator.save_state();
            localStorage.setItem('vmState', JSON.stringify(state));
            localStorage.setItem('totalRuntime', this.totalRuntime.toString());
            this.log('✅ Saved to browser');
        } catch (error) {
            this.log('❌ Save failed');
            console.error(error);
        }
    }

    // Phase 2: Resume from localStorage
    async resumeState() {
        const savedState = localStorage.getItem('vmState');
        if (!savedState) {
            this.log('No saved state - booting fresh');
            await this.bootLinux();
            return;
        }

        this.log('📦 Resuming from saved state...');
        try {
            const state = JSON.parse(savedState);
            await this.bootLinux(state);
            this.log('✅ Resumed');
        } catch (error) {
            this.log('❌ Resume failed - booting fresh');
            console.error(error);
            localStorage.removeItem('vmState');
            await this.bootLinux();
        }
    }

    stop() {
        this.stopRuntime();
        if (this.emulator) {
            this.emulator.stop();
            this.emulator = null;
            document.getElementById('loading').style.display = 'block';
            this.log('💰 Stopped');
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
window.serverless = serverless;

// Button handlers
document.getElementById('bootBtn').onclick = () => serverless.bootLinux();
document.getElementById('resumeBtn').onclick = () => serverless.resumeState();
document.getElementById('saveBtn').onclick = () => serverless.saveState();
document.getElementById('stopBtn').onclick = () => serverless.stop();

console.log('');
console.log('🎯 SERVERLESS LINUX - Phases 1-2 Complete');
console.log('  Phase 1: Pay-per-use billing ($0.36/hour) ✓');
console.log('  Phase 2: Save/resume state in browser ✓');
console.log('');
console.log('💡 How it works:');
console.log('  • Click Boot Fresh or Resume');
console.log('  • Click Save to save state to localStorage');
console.log('  • Refresh page and Resume to continue');
console.log('  • Pay only while running');
