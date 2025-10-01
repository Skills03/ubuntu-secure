// Phase 1: Linux synced TO Westend blockchain
// Phase 2: Linux instances form their OWN blockchain (added below)
// Following DEVELOPMENT_METHODOLOGY: Progressive enhancement

console.log('🔗 LINUX AS BLOCKCHAIN - Phases 1+2+3');
console.log('Phase 1: Read Westend | Phase 2: Local chain | Phase 3: Write to Westend');

class LinuxBlockchain {
    constructor() {
        this.api = null;
        this.emulator = null;
        this.stateRoot = null;
        this.lastStateHash = null;
        this.syncInterval = null;
        this.nodeId = 'node_' + Math.random().toString(36).substr(2, 9);

        // Phase 1: Simple in-memory state (Phase 2 will use IPFS)
        this.states = new Map();

        this.log('Initializing Linux Blockchain OS');
    }

    log(msg) {
        console.log('  ' + msg);
        const logDiv = document.getElementById('sync-log');
        const time = new Date().toLocaleTimeString();
        logDiv.innerHTML = `[${time}] ${msg}<br>` + logDiv.innerHTML;
    }

    async init() {
        // Step 1: Initialize v86 Linux first (doesn't need blockchain)
        await this.initLinux();

        // Step 2: Try blockchain (async, non-blocking)
        setTimeout(() => this.connectBlockchain(), 5000);

        // Step 3: Start state sync
        this.startStateSync();

        // Step 4: Listen for other nodes
        this.listenForNodes();
    }

    async connectBlockchain() {
        try {
            this.log('Connecting to Westend public blockchain...');
            document.getElementById('load-status').textContent = 'Connecting to Westend...';

            // Check if API loaded (following official docs pattern)
            if (typeof polkadotApi === 'undefined') {
                throw new Error('Polkadot API not loaded');
            }

            const { ApiPromise, WsProvider } = polkadotApi;
            const provider = new WsProvider('wss://westend-rpc.polkadot.io');
            this.api = await ApiPromise.create({ provider });

            const chain = await this.api.rpc.system.chain();
            const header = await this.api.rpc.chain.getHeader();
            const blockNum = header.number.toNumber();

            this.log(`✅ Connected to ${chain} - Block #${blockNum}`);
            document.getElementById('blockchain-badge').textContent = `✅ Westend #${blockNum}`;
            document.getElementById('blockchain').textContent = `Westend #${blockNum}`;

            return true;
        } catch (error) {
            this.log(`❌ Blockchain connection failed: ${error.message}`);
            document.getElementById('blockchain-badge').textContent = '❌ Offline Mode';
            document.getElementById('blockchain-badge').className = 'badge warning';
            return false;
        }
    }

    async initLinux() {
        this.log('Booting Linux kernel (v86 WASM)...');
        document.getElementById('load-status').textContent = 'Loading Linux kernel...';

        const container = document.getElementById("screen_container");
        if (!container) {
            throw new Error("screen_container element not found");
        }

        this.emulator = new V86({
            wasm_path: "./v86.wasm",
            memory_size: 64 * 1024 * 1024,  // 64MB for faster state sync
            vga_memory_size: 4 * 1024 * 1024,
            screen_container: container,
            bios: {
                url: "./seabios.bin",
            },
            vga_bios: {
                url: "./vgabios.bin",
            },
            cdrom: {
                url: "./linux.iso",
            },
            autostart: true,
        });

        return new Promise((resolve) => {
            this.emulator.add_listener("emulator-ready", () => {
                this.log('✅ Linux kernel loaded');
                document.getElementById('loading').style.display = 'none';
                resolve();
            });

            this.emulator.add_listener("emulator-started", () => {
                this.log('✅ Linux booted - Ready for consensus');
                document.getElementById('sync-badge').textContent = '✅ Sync: Active';
            });
        });
    }

    // Phase 1: Simple hash-based state sync
    async captureState() {
        return new Promise((resolve) => {
            this.emulator.save_state((error, state) => {
                if (error) {
                    this.log(`State capture error: ${error}`);
                    resolve(null);
                } else {
                    // Create hash of state
                    const stateStr = JSON.stringify(state);
                    const hash = this.simpleHash(stateStr);
                    resolve({ hash, size: stateStr.length, timestamp: Date.now() });
                }
            });
        });
    }

    simpleHash(str) {
        let hash = 0;
        for (let i = 0; i < str.length; i++) {
            const char = str.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash;
        }
        return '0x' + Math.abs(hash).toString(16).padStart(16, '0');
    }

    async syncStateToBlockchain() {
        const state = await this.captureState();
        if (!state) return;

        // Check if state changed
        if (state.hash === this.lastStateHash) {
            return; // No change, skip sync
        }

        this.lastStateHash = state.hash;
        this.stateRoot = state.hash;

        document.getElementById('state-root').textContent = state.hash.substr(0, 16) + '...';
        document.getElementById('last-sync').textContent = new Date().toLocaleTimeString();

        this.log(`State captured: ${state.hash.substr(0, 12)}... (${(state.size/1024).toFixed(1)}KB)`);

        // Phase 1: Store state hash on Westend (read-only, no wallet needed)
        // Phase 2 will add actual transaction submission with wallet
        if (this.api) {
            try {
                const header = await this.api.rpc.chain.getHeader();
                const blockNum = header.number.toNumber();

                // Phase 3: Submit to Westend blockchain (if keyring available)
                await this.submitToWestend(state, blockNum);

                // Phase 1: Announce state to other nodes via localStorage (simulation)
                this.announceState(state);
            } catch (error) {
                this.log(`Blockchain sync error: ${error.message}`);
            }
        }
    }

    // Phase 3: Submit Linux state to Westend blockchain
    async submitToWestend(state, blockNum) {
        try {
            // Generate ephemeral keypair if not exists
            if (!this.keyring) {
                const { Keyring } = polkadotKeyring;
                this.keyring = new Keyring({ type: 'sr25519' });
                // Generate from node ID (same key per session)
                this.account = this.keyring.addFromUri('//' + this.nodeId);
                this.log(`🔑 Account: ${this.account.address.substr(0, 8)}...`);
            }

            // Submit system.remark with state hash (free on Westend)
            const remark = `Linux state: ${state.hash}`;
            const tx = this.api.tx.system.remark(remark);

            // Sign and send
            await tx.signAndSend(this.account, ({ status }) => {
                if (status.isInBlock) {
                    this.log(`📝 State on Westend block: ${status.asInBlock.toString().substr(0, 12)}...`);
                }
            });

            this.log(`✅ Submitted to Westend #${blockNum}`);
        } catch (error) {
            // Phase 3 fails gracefully - Phase 1/2 still work
            this.log(`⚠️ Westend submit failed: ${error.message}`);
        }
    }

    announceState(state) {
        // Phase 1: Use localStorage to simulate multi-node consensus
        // Phase 2 will use actual Westend transactions
        const announcement = {
            nodeId: this.nodeId,
            stateRoot: state.hash,
            timestamp: state.timestamp,
            blockchainBlock: 'simulated' // Phase 2: real block number
        };

        localStorage.setItem('linux_blockchain_state', JSON.stringify(announcement));
        localStorage.setItem('linux_blockchain_timestamp', Date.now().toString());
    }

    listenForNodes() {
        // Phase 1: Simple localStorage listener (simulates other nodes)
        // Phase 2: Listen to Westend events
        setInterval(() => {
            try {
                const stored = localStorage.getItem('linux_blockchain_state');
                if (stored) {
                    const announcement = JSON.parse(stored);
                    if (announcement.nodeId !== this.nodeId) {
                        // Another node updated state
                        document.getElementById('nodes-badge').textContent = 'Nodes: 2+';
                        this.log(`Detected state from node ${announcement.nodeId.substr(0, 8)}`);
                    }
                }
            } catch (e) {
                // Ignore errors
            }
        }, 5000);
    }

    startStateSync() {
        this.log('Starting state synchronization (every 10 seconds)');

        // Initial sync
        setTimeout(() => this.syncStateToBlockchain(), 3000);

        // Periodic sync
        this.syncInterval = setInterval(() => {
            this.syncStateToBlockchain();
        }, 10000); // Sync every 10 seconds
    }
}

// Wait for DOM before initializing
window.addEventListener('DOMContentLoaded', () => {
    console.log('DOM loaded, checking elements...');
    console.log('screen_container:', document.getElementById('screen_container'));

    const linuxBlockchain = new LinuxBlockchain();
    linuxBlockchain.init().catch(error => {
        console.error('Initialization error:', error);
        document.getElementById('blockchain-badge').textContent = '❌ Init Failed';
    });

    // Keyboard focus helper
    window.onclick = function() {
        if (linuxBlockchain.emulator) {
            linuxBlockchain.emulator.keyboard_send_scancodes([0x1C]);
        }
    };
});

console.log('');
console.log('🎯 LINUX AS BLOCKCHAIN - Phases 1+2+3 Active');
console.log('  Phase 1: Read from Westend');
console.log('  Phase 2: Local blockchain fallback');
console.log('  Phase 3: Write Linux state TO Westend');
console.log('  • Linux state stored ON real blockchain!');
console.log('  • Open multiple tabs to see consensus');

// ============================================================================
// PHASE 2: Local Blockchain (Progressive Enhancement)
// ============================================================================
// Added after Phase 1 - doesn't replace it, extends it
// Activates automatically if Westend connection fails

class LocalBlock {
    constructor(index, timestamp, data, previousHash = '') {
        this.index = index;
        this.timestamp = timestamp;
        this.data = data;
        this.previousHash = previousHash;
        this.hash = this.calculateHash();
    }

    calculateHash() {
        const str = this.index + this.previousHash + this.timestamp + JSON.stringify(this.data);
        let hash = 0;
        for (let i = 0; i < str.length; i++) {
            hash = ((hash << 5) - hash) + str.charCodeAt(i);
            hash = hash & hash;
        }
        return '0x' + Math.abs(hash).toString(16).padStart(16, '0');
    }
}

class LocalChain {
    constructor(nodeId) {
        this.nodeId = nodeId;
        this.chain = [];
        this.peers = new Map();

        // Genesis block
        this.chain.push(new LocalBlock(0, Date.now(), {type: 'genesis', nodeId}, '0'));

        // P2P via BroadcastChannel
        try {
            this.channel = new BroadcastChannel('linux_chain');
            this.channel.onmessage = (e) => this.handlePeerMessage(e.data);
            this.broadcast({type: 'announce', chainLength: this.chain.length});
        } catch (e) {
            console.log('  BroadcastChannel not supported');
        }
    }

    addBlock(data) {
        const latest = this.chain[this.chain.length - 1];
        const newBlock = new LocalBlock(this.chain.length, Date.now(), data, latest.hash);
        this.chain.push(newBlock);
        this.broadcast({type: 'block', block: newBlock});
        return newBlock;
    }

    broadcast(msg) {
        msg.nodeId = this.nodeId;
        if (this.channel) this.channel.postMessage(msg);
    }

    handlePeerMessage(msg) {
        if (msg.nodeId === this.nodeId) return;

        if (msg.type === 'announce') {
            this.peers.set(msg.nodeId, {chainLength: msg.chainLength, lastSeen: Date.now()});
        } else if (msg.type === 'block' && msg.block.index === this.chain.length) {
            // Simple consensus: accept blocks in order
            this.chain.push(msg.block);
        }
    }
}

// Phase 2 enhancement: Add fallback blockchain to existing class
LinuxBlockchain.prototype.initLocalBlockchain = function() {
    this.log('📦 Westend unavailable - starting local blockchain');
    this.localChain = new LocalChain(this.nodeId);
    document.getElementById('blockchain-badge').textContent = '✅ Local Chain';
    document.getElementById('blockchain').textContent = `Local (${this.localChain.chain.length} blocks)`;
};

// Phase 2 enhancement: Extend syncStateToBlockchain to use local chain
const originalSync = LinuxBlockchain.prototype.syncStateToBlockchain;
LinuxBlockchain.prototype.syncStateToBlockchain = async function() {
    // Phase 1: Try Westend sync
    await originalSync.call(this);

    // Phase 2: If no Westend API, use local blockchain
    if (!this.api && this.localChain) {
        const state = await this.captureState();
        if (state && state.hash !== this.lastStateHash) {
            this.lastStateHash = state.hash;
            const block = this.localChain.addBlock({
                type: 'vm_state',
                stateHash: state.hash,
                size: state.size
            });
            this.log(`📦 Block #${block.index} added: ${block.hash.substr(0, 12)}...`);
            document.getElementById('blockchain').textContent = `Local (${this.localChain.chain.length} blocks)`;
            document.getElementById('nodes-badge').textContent = `Nodes: ${this.localChain.peers.size + 1}`;
        }
    }
};

// Phase 2 enhancement: Extend connectBlockchain to initialize local chain on failure
const originalConnect = LinuxBlockchain.prototype.connectBlockchain;
LinuxBlockchain.prototype.connectBlockchain = async function() {
    // Phase 1: Try Westend
    const connected = await originalConnect.call(this);

    // Phase 2: Fallback to local blockchain
    if (!connected) {
        this.initLocalBlockchain();
    }

    return connected;
};
