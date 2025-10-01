// Phase 2: Linux AS Blockchain - Linux instances form their own blockchain
// Each Linux state = block, multiple instances = distributed chain

console.log('🔗 LINUX AS BLOCKCHAIN - Phase 2');
console.log('Linux instances forming their own blockchain network');

class Block {
    constructor(index, timestamp, stateHash, stateSize, previousHash = '') {
        this.index = index;
        this.timestamp = timestamp;
        this.stateHash = stateHash;      // Hash of Linux VM state
        this.stateSize = stateSize;
        this.previousHash = previousHash;
        this.hash = this.calculateHash();
        this.nonce = 0;
    }

    calculateHash() {
        const crypto = window.crypto || window.msCrypto;
        const data = this.index + this.previousHash + this.timestamp +
                    this.stateHash + this.stateSize + this.nonce;

        // Simple hash for browser (Phase 3 will use SHA-256)
        let hash = 0;
        for (let i = 0; i < data.length; i++) {
            const char = data.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash;
        }
        return '0x' + Math.abs(hash).toString(16).padStart(16, '0');
    }

    mineBlock(difficulty) {
        const target = '0'.repeat(difficulty);
        while (this.hash.substring(2, 2 + difficulty) !== target) {
            this.nonce++;
            this.hash = this.calculateHash();
        }
        return this.hash;
    }
}

class LinuxBlockchain {
    constructor(nodeId, emulator) {
        this.nodeId = nodeId;
        this.emulator = emulator;
        this.chain = [];
        this.difficulty = 2; // Proof of work difficulty
        this.peers = new Map(); // nodeId -> lastSeen
        this.channel = null;
        this.lastStateHash = null;

        // Create genesis block
        this.createGenesisBlock();

        // Initialize peer communication
        this.initPeerNetwork();

        this.log('Linux Blockchain initialized');
        this.log(`Node ID: ${this.nodeId}`);
    }

    createGenesisBlock() {
        const genesis = new Block(0, Date.now(), '0x0', 0, '0');
        genesis.hash = genesis.mineBlock(this.difficulty);
        this.chain.push(genesis);
        this.log(`Genesis block mined: ${genesis.hash.substr(0, 12)}...`);
    }

    initPeerNetwork() {
        // BroadcastChannel for same-browser tabs
        this.channel = new BroadcastChannel('linux_blockchain');

        this.channel.onmessage = (event) => {
            this.handlePeerMessage(event.data);
        };

        // Announce presence
        this.broadcast({
            type: 'PEER_ANNOUNCE',
            nodeId: this.nodeId,
            timestamp: Date.now(),
            chainLength: this.chain.length
        });

        // Periodic peer discovery
        setInterval(() => {
            this.broadcast({
                type: 'PEER_HEARTBEAT',
                nodeId: this.nodeId,
                chainLength: this.chain.length,
                latestBlock: this.getLatestBlock().hash
            });

            // Clean up stale peers (not seen in 30 seconds)
            const now = Date.now();
            for (const [peerId, lastSeen] of this.peers.entries()) {
                if (now - lastSeen > 30000) {
                    this.peers.delete(peerId);
                    this.log(`Peer ${peerId.substr(0, 8)} timed out`);
                }
            }
            this.updatePeerCount();
        }, 5000);
    }

    handlePeerMessage(message) {
        if (message.nodeId === this.nodeId) return; // Ignore own messages

        switch (message.type) {
            case 'PEER_ANNOUNCE':
                this.peers.set(message.nodeId, Date.now());
                this.log(`New peer discovered: ${message.nodeId.substr(0, 8)}`);
                this.updatePeerCount();

                // Send our chain if we have more blocks
                if (this.chain.length > message.chainLength) {
                    this.broadcast({
                        type: 'CHAIN_SYNC',
                        nodeId: this.nodeId,
                        chain: this.chain
                    });
                }
                break;

            case 'PEER_HEARTBEAT':
                this.peers.set(message.nodeId, Date.now());

                // Request chain if peer has more blocks
                if (message.chainLength > this.chain.length) {
                    this.broadcast({
                        type: 'CHAIN_REQUEST',
                        nodeId: this.nodeId,
                        targetNode: message.nodeId
                    });
                }
                break;

            case 'CHAIN_REQUEST':
                if (message.targetNode === this.nodeId) {
                    this.broadcast({
                        type: 'CHAIN_SYNC',
                        nodeId: this.nodeId,
                        chain: this.chain
                    });
                }
                break;

            case 'CHAIN_SYNC':
                this.replaceChain(message.chain, message.nodeId);
                break;

            case 'NEW_BLOCK':
                this.receiveBlock(message.block, message.nodeId);
                break;

            case 'CONSENSUS_VOTE':
                this.handleConsensusVote(message);
                break;
        }
    }

    broadcast(message) {
        if (this.channel) {
            this.channel.postMessage(message);
        }
    }

    getLatestBlock() {
        return this.chain[this.chain.length - 1];
    }

    async captureLinuxState() {
        return new Promise((resolve) => {
            if (!this.emulator) {
                resolve(null);
                return;
            }

            this.emulator.save_state((error, state) => {
                if (error) {
                    this.log(`State capture error: ${error}`);
                    resolve(null);
                } else {
                    const stateStr = JSON.stringify(state);
                    const hash = this.simpleHash(stateStr);
                    resolve({
                        hash,
                        size: stateStr.length,
                        timestamp: Date.now(),
                        state: state // Store actual state for restoration
                    });
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

    async addBlock() {
        const vmState = await this.captureLinuxState();
        if (!vmState) return null;

        // Skip if state hasn't changed
        if (vmState.hash === this.lastStateHash) {
            return null;
        }

        const latestBlock = this.getLatestBlock();
        const newBlock = new Block(
            latestBlock.index + 1,
            vmState.timestamp,
            vmState.hash,
            vmState.size,
            latestBlock.hash
        );

        this.log(`Mining block #${newBlock.index}...`);
        const startTime = Date.now();
        newBlock.hash = newBlock.mineBlock(this.difficulty);
        const mineTime = Date.now() - startTime;

        this.chain.push(newBlock);
        this.lastStateHash = vmState.hash;

        this.log(`Block #${newBlock.index} mined in ${mineTime}ms: ${newBlock.hash.substr(0, 12)}...`);
        this.updateChainInfo();

        // Broadcast new block to peers
        this.broadcast({
            type: 'NEW_BLOCK',
            nodeId: this.nodeId,
            block: newBlock
        });

        // Request consensus validation
        this.requestConsensus(newBlock);

        return newBlock;
    }

    receiveBlock(block, fromNodeId) {
        // Validate block
        if (!this.isValidBlock(block)) {
            this.log(`Invalid block received from ${fromNodeId.substr(0, 8)}`);
            return;
        }

        // Check if block extends our chain
        const latestBlock = this.getLatestBlock();
        if (block.previousHash === latestBlock.hash && block.index === latestBlock.index + 1) {
            this.chain.push(block);
            this.log(`Added block #${block.index} from peer ${fromNodeId.substr(0, 8)}`);
            this.updateChainInfo();
        }
    }

    isValidBlock(block) {
        // Verify hash has correct difficulty
        const target = '0'.repeat(this.difficulty);
        if (block.hash.substring(2, 2 + this.difficulty) !== target) {
            return false;
        }

        // Verify hash matches content
        const testBlock = new Block(
            block.index,
            block.timestamp,
            block.stateHash,
            block.stateSize,
            block.previousHash
        );
        testBlock.nonce = block.nonce;

        return testBlock.calculateHash() === block.hash;
    }

    isValidChain(chain) {
        // Check genesis block
        if (JSON.stringify(chain[0]) !== JSON.stringify(this.chain[0])) {
            return false;
        }

        // Validate each block
        for (let i = 1; i < chain.length; i++) {
            const currentBlock = chain[i];
            const previousBlock = chain[i - 1];

            if (!this.isValidBlock(currentBlock)) {
                return false;
            }

            if (currentBlock.previousHash !== previousBlock.hash) {
                return false;
            }
        }

        return true;
    }

    replaceChain(newChain, fromNodeId) {
        if (newChain.length <= this.chain.length) {
            this.log(`Received shorter chain from ${fromNodeId.substr(0, 8)}, ignoring`);
            return;
        }

        if (!this.isValidChain(newChain)) {
            this.log(`Received invalid chain from ${fromNodeId.substr(0, 8)}, rejecting`);
            return;
        }

        this.log(`Replacing chain with longer valid chain from ${fromNodeId.substr(0, 8)}`);
        this.chain = newChain;
        this.updateChainInfo();
    }

    requestConsensus(block) {
        // Simple majority voting (Phase 3: Byzantine fault tolerance)
        this.broadcast({
            type: 'CONSENSUS_VOTE',
            nodeId: this.nodeId,
            blockHash: block.hash,
            blockIndex: block.index,
            vote: 'ACCEPT'
        });
    }

    handleConsensusVote(message) {
        // Track votes (Phase 3: implement full voting)
        this.log(`Vote received from ${message.nodeId.substr(0, 8)}: ${message.vote}`);
    }

    updateChainInfo() {
        const latest = this.getLatestBlock();
        document.getElementById('state-root').textContent =
            `Block #${latest.index}: ${latest.hash.substr(0, 16)}...`;
        document.getElementById('last-sync').textContent =
            new Date(latest.timestamp).toLocaleTimeString();
    }

    updatePeerCount() {
        const peerCount = this.peers.size + 1; // +1 for self
        document.getElementById('nodes-badge').textContent = `Nodes: ${peerCount}`;

        if (peerCount > 1) {
            document.getElementById('nodes-badge').style.borderColor = '#4ade80';
            document.getElementById('nodes-badge').style.color = '#4ade80';
        }
    }

    log(msg) {
        console.log('  ' + msg);
        const logDiv = document.getElementById('sync-log');
        const time = new Date().toLocaleTimeString();
        logDiv.innerHTML = `[${time}] ${msg}<br>` + logDiv.innerHTML;
    }

    getChainStats() {
        return {
            length: this.chain.length,
            latestBlock: this.getLatestBlock(),
            peers: this.peers.size,
            difficulty: this.difficulty
        };
    }
}

// Main Application
class LinuxAsBlockchain {
    constructor() {
        this.nodeId = 'node_' + Math.random().toString(36).substr(2, 9);
        this.emulator = null;
        this.blockchain = null;
        this.syncInterval = null;

        this.log('Initializing Linux AS Blockchain');
    }

    log(msg) {
        console.log('  ' + msg);
        const logDiv = document.getElementById('sync-log');
        const time = new Date().toLocaleTimeString();
        logDiv.innerHTML = `[${time}] ${msg}<br>` + logDiv.innerHTML;
    }

    async init() {
        // Step 1: Boot Linux
        await this.initLinux();

        // Step 2: Initialize blockchain with Linux as nodes
        this.blockchain = new LinuxBlockchain(this.nodeId, this.emulator);

        // Step 3: Start mining blocks from Linux state
        this.startMining();
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
            memory_size: 64 * 1024 * 1024,
            vga_memory_size: 4 * 1024 * 1024,
            screen_container: container,
            bios: { url: "./seabios.bin" },
            vga_bios: { url: "./vgabios.bin" },
            cdrom: { url: "./linux.iso" },
            autostart: true,
        });

        return new Promise((resolve) => {
            this.emulator.add_listener("emulator-ready", () => {
                this.log('✅ Linux kernel loaded');
                document.getElementById('loading').style.display = 'none';
                resolve();
            });

            this.emulator.add_listener("emulator-started", () => {
                this.log('✅ Linux booted - Now operating as blockchain node');
                document.getElementById('sync-badge').textContent = '✅ Mining: Active';
                document.getElementById('blockchain-badge').textContent = '✅ Linux IS Blockchain';
            });
        });
    }

    startMining() {
        this.log('Starting block mining (every 10 seconds)');

        // Initial block after boot
        setTimeout(() => {
            this.blockchain.addBlock();
        }, 3000);

        // Mine new blocks periodically
        this.syncInterval = setInterval(() => {
            this.blockchain.addBlock();
        }, 10000);
    }
}

// Initialize when DOM ready
window.addEventListener('DOMContentLoaded', () => {
    console.log('DOM loaded, initializing Linux AS Blockchain...');

    const app = new LinuxAsBlockchain();
    app.init().catch(error => {
        console.error('Initialization error:', error);
        document.getElementById('blockchain-badge').textContent = '❌ Init Failed';
    });

    // Keyboard focus helper
    window.onclick = function() {
        if (app.emulator) {
            app.emulator.keyboard_send_scancodes([0x1C]);
        }
    };
});

console.log('');
console.log('🎯 LINUX AS BLOCKCHAIN - Phase 2 Active');
console.log('  • Each Linux instance = blockchain node');
console.log('  • Linux state = blocks on chain');
console.log('  • Proof of Work mining');
console.log('  • Peer-to-peer consensus via BroadcastChannel');
console.log('  • Open multiple tabs to see distributed blockchain');
console.log('');
console.log('Phase 3 will add:');
console.log('  • Byzantine fault tolerance');
console.log('  • IPFS state storage');
console.log('  • WebRTC for cross-browser peers');
console.log('  • Smart contracts in Linux syscalls');
