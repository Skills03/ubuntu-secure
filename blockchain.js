// Phase 2: Linux AS Blockchain - Core Blockchain Implementation
// Each Linux instance forms nodes of a distributed blockchain

class Block {
    constructor(index, timestamp, data, previousHash = '') {
        this.index = index;
        this.timestamp = timestamp;
        this.data = data;  // Linux VM state
        this.previousHash = previousHash;
        this.hash = this.calculateHash();
        this.nonce = 0;
    }

    calculateHash() {
        const crypto = window.crypto || window.msCrypto;
        const dataStr = this.index + this.previousHash + this.timestamp + JSON.stringify(this.data) + this.nonce;

        // Simple hash function (SHA-256 would be better but requires async)
        let hash = 0;
        for (let i = 0; i < dataStr.length; i++) {
            const char = dataStr.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash;
        }
        return '0x' + Math.abs(hash).toString(16).padStart(64, '0');
    }

    mineBlock(difficulty) {
        const target = '0'.repeat(difficulty);
        while (this.hash.substring(0, difficulty + 2) !== '0x' + target) {
            this.nonce++;
            this.hash = this.calculateHash();
        }
    }
}

class LinuxBlockchain {
    constructor(nodeId) {
        this.nodeId = nodeId;
        this.chain = [];
        this.difficulty = 2; // Proof of work difficulty
        this.pendingTransactions = [];
        this.peers = new Map(); // Connected peer nodes

        // Create genesis block
        this.createGenesisBlock();

        // Setup P2P communication
        this.setupP2P();
    }

    createGenesisBlock() {
        const genesis = new Block(0, Date.now(), {
            type: 'genesis',
            message: 'Linux AS Blockchain - Genesis Block',
            nodeId: this.nodeId
        }, '0');
        this.chain.push(genesis);
        console.log('🔗 Genesis block created:', genesis.hash);
    }

    getLatestBlock() {
        return this.chain[this.chain.length - 1];
    }

    addBlock(data) {
        const newBlock = new Block(
            this.chain.length,
            Date.now(),
            data,
            this.getLatestBlock().hash
        );

        // Mine the block (proof of work)
        newBlock.mineBlock(this.difficulty);

        // Add to chain
        this.chain.push(newBlock);

        // Broadcast to peers
        this.broadcastBlock(newBlock);

        console.log(`  ⛏️  Block #${newBlock.index} mined: ${newBlock.hash.substr(0, 16)}...`);

        return newBlock;
    }

    isChainValid(chain = this.chain) {
        // Check genesis block
        const genesisBlock = chain[0];
        if (genesisBlock.hash !== genesisBlock.calculateHash()) {
            return false;
        }

        // Check all subsequent blocks
        for (let i = 1; i < chain.length; i++) {
            const currentBlock = chain[i];
            const previousBlock = chain[i - 1];

            // Verify hash
            if (currentBlock.hash !== currentBlock.calculateHash()) {
                console.log(`Invalid hash at block ${i}`);
                return false;
            }

            // Verify chain link
            if (currentBlock.previousHash !== previousBlock.hash) {
                console.log(`Broken chain at block ${i}`);
                return false;
            }
        }

        return true;
    }

    setupP2P() {
        // Use BroadcastChannel for same-origin multi-tab communication
        try {
            this.channel = new BroadcastChannel('linux_blockchain');

            this.channel.onmessage = (event) => {
                this.handlePeerMessage(event.data);
            };

            // Announce presence
            this.broadcast({
                type: 'peer_announce',
                nodeId: this.nodeId,
                chainLength: this.chain.length,
                timestamp: Date.now()
            });

            console.log('  P2P channel established');
        } catch (e) {
            console.log('  BroadcastChannel not supported, using localStorage fallback');
            this.setupLocalStorageP2P();
        }
    }

    setupLocalStorageP2P() {
        // Fallback for browsers without BroadcastChannel
        window.addEventListener('storage', (e) => {
            if (e.key === 'linux_blockchain_message') {
                try {
                    const message = JSON.parse(e.newValue);
                    if (message.nodeId !== this.nodeId) {
                        this.handlePeerMessage(message);
                    }
                } catch (err) {
                    // Ignore parse errors
                }
            }
        });
    }

    broadcast(message) {
        message.nodeId = this.nodeId;

        if (this.channel) {
            this.channel.postMessage(message);
        } else {
            // localStorage fallback
            localStorage.setItem('linux_blockchain_message', JSON.stringify(message));
            localStorage.setItem('linux_blockchain_message_time', Date.now().toString());
        }
    }

    broadcastBlock(block) {
        this.broadcast({
            type: 'new_block',
            block: {
                index: block.index,
                timestamp: block.timestamp,
                data: block.data,
                previousHash: block.previousHash,
                hash: block.hash,
                nonce: block.nonce
            }
        });
    }

    handlePeerMessage(message) {
        if (message.nodeId === this.nodeId) return; // Ignore own messages

        switch (message.type) {
            case 'peer_announce':
                this.handlePeerAnnounce(message);
                break;
            case 'new_block':
                this.handleNewBlock(message.block);
                break;
            case 'chain_request':
                this.handleChainRequest(message);
                break;
            case 'chain_response':
                this.handleChainResponse(message);
                break;
        }
    }

    handlePeerAnnounce(message) {
        this.peers.set(message.nodeId, {
            chainLength: message.chainLength,
            lastSeen: Date.now()
        });

        console.log(`  📡 Peer discovered: ${message.nodeId.substr(0, 8)} (chain: ${message.chainLength} blocks)`);

        // If peer has longer chain, request it
        if (message.chainLength > this.chain.length) {
            this.broadcast({
                type: 'chain_request',
                requester: this.nodeId
            });
        }

        // Update UI
        this.updatePeerCount();
    }

    handleNewBlock(blockData) {
        // Reconstruct block object
        const block = new Block(
            blockData.index,
            blockData.timestamp,
            blockData.data,
            blockData.previousHash
        );
        block.hash = blockData.hash;
        block.nonce = blockData.nonce;

        // Validate block
        if (block.index === this.chain.length &&
            block.previousHash === this.getLatestBlock().hash &&
            block.hash === block.calculateHash()) {

            this.chain.push(block);
            console.log(`  📦 Received valid block #${block.index} from peer`);

            // Update UI
            this.updateChainDisplay();
        }
    }

    handleChainRequest(message) {
        if (message.requester !== this.nodeId) {
            // Send our chain
            this.broadcast({
                type: 'chain_response',
                chain: this.chain.map(b => ({
                    index: b.index,
                    timestamp: b.timestamp,
                    data: b.data,
                    previousHash: b.previousHash,
                    hash: b.hash,
                    nonce: b.nonce
                }))
            });
        }
    }

    handleChainResponse(message) {
        const receivedChain = message.chain.map(blockData => {
            const block = new Block(
                blockData.index,
                blockData.timestamp,
                blockData.data,
                blockData.previousHash
            );
            block.hash = blockData.hash;
            block.nonce = blockData.nonce;
            return block;
        });

        // Replace chain if valid and longer
        if (receivedChain.length > this.chain.length && this.isChainValid(receivedChain)) {
            console.log(`  🔄 Replacing chain with longer valid chain (${receivedChain.length} blocks)`);
            this.chain = receivedChain;
            this.updateChainDisplay();
        }
    }

    updatePeerCount() {
        const activePeers = Array.from(this.peers.values()).filter(
            p => Date.now() - p.lastSeen < 30000 // Active in last 30s
        ).length;

        const badge = document.getElementById('nodes-badge');
        if (badge) {
            badge.textContent = `Nodes: ${activePeers + 1}`; // +1 for self
        }
    }

    updateChainDisplay() {
        const stateRoot = document.getElementById('state-root');
        const blockchain = document.getElementById('blockchain');

        if (stateRoot) {
            const latest = this.getLatestBlock();
            stateRoot.textContent = `${latest.hash.substr(0, 16)}... (#${latest.index})`;
        }

        if (blockchain) {
            blockchain.textContent = `${this.chain.length} blocks`;
        }
    }

    // Get blockchain statistics
    getStats() {
        return {
            blocks: this.chain.length,
            peers: this.peers.size,
            latestBlock: this.getLatestBlock().hash,
            isValid: this.isChainValid()
        };
    }
}

// Export for use in app.js
window.LinuxBlockchain = LinuxBlockchain;
window.Block = Block;
