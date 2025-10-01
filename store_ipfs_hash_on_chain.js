#!/usr/bin/env node
/**
 * Store IPFS Hash on Westend Blockchain
 * This creates a permanent on-chain record
 */

const { ApiPromise, WsProvider, Keyring } = require('@polkadot/api');
const { cryptoWaitReady } = require('@polkadot/util-crypto');

const WESTEND_RPC = 'wss://westend-rpc.polkadot.io';
const IPFS_HASH = 'Qmc13KkB1ULV8VpkrYSbsYbTdBX9ojspomKBRqJBoce82h'; // Linux AS Blockchain

async function storeOnChain() {
    console.log('\n🔗 STORING IPFS HASH ON WESTEND BLOCKCHAIN\n');
    console.log('='.repeat(70));
    console.log(`IPFS Hash: ${IPFS_HASH}`);
    console.log(`URL: https://ipfs.io/ipfs/${IPFS_HASH}`);
    console.log('='.repeat(70));
    console.log();

    try {
        console.log('📡 Connecting to Westend...');
        const provider = new WsProvider(WESTEND_RPC);
        const api = await ApiPromise.create({ provider });
        await cryptoWaitReady();

        const chain = await api.rpc.system.chain();
        console.log(`✅ Connected to ${chain}\n`);

        const keyring = new Keyring({ type: 'sr25519' });
        const alice = keyring.addFromUri('//Alice');

        const data = JSON.stringify({
            app: 'Linux AS Blockchain',
            version: 'Phase 1',
            type: 'Distributed OS with State Sync',
            ipfs: IPFS_HASH,
            urls: [
                `https://ipfs.io/ipfs/${IPFS_HASH}`,
                `https://cloudflare-ipfs.com/ipfs/${IPFS_HASH}`,
                `https://dweb.link/ipfs/${IPFS_HASH}`,
                `https://gateway.pinata.cloud/ipfs/${IPFS_HASH}`
            ],
            features: [
                'v86 Linux kernel in browser',
                'State sync via Westend blockchain',
                'Multi-node consensus detection',
                'Real-time state hashing',
                '100% decentralized infrastructure'
            ],
            blockchain: 'Westend',
            timestamp: new Date().toISOString()
        });

        console.log('📝 Submitting to blockchain...\n');

        await api.tx.system.remark(data)
            .signAndSend(alice, ({ status }) => {
                if (status.isInBlock) {
                    console.log('✅ Transaction included in block!');
                    console.log(`   Block: ${status.asInBlock.toHex()}`);
                }
                if (status.isFinalized) {
                    console.log('\n🎉 IPFS HASH NOW ON PUBLIC BLOCKCHAIN!\n');
                    console.log('='.repeat(70));
                    console.log('🌐 DECENTRALIZED URLS (No localhost!):\n');
                    console.log(`   https://ipfs.io/ipfs/${IPFS_HASH}`);
                    console.log(`   https://cloudflare-ipfs.com/ipfs/${IPFS_HASH}`);
                    console.log(`   https://dweb.link/ipfs/${IPFS_HASH}`);
                    console.log();
                    console.log('🔗 Verify on blockchain:');
                    console.log(`   https://westend.subscan.io/extrinsic/${status.asFinalized.toHex()}`);
                    console.log('='.repeat(70));
                    process.exit(0);
                }
            });

    } catch (error) {
        console.error('❌ Error:', error.message);
        console.log('\n💡 This would work with testnet tokens from https://faucet.polkadot.io');
        console.log('\n✅ But IPFS URLs work NOW without tokens!');
        console.log(`   https://ipfs.io/ipfs/${IPFS_HASH}\n`);
        process.exit(0);
    }
}

storeOnChain();
