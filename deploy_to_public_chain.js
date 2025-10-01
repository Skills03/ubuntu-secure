#!/usr/bin/env node
/**
 * Ubuntu Secure - Deploy to PUBLIC Blockchain
 *
 * This script deploys Ubuntu OS operations to Polkadot Westend PUBLIC testnet
 * Anyone can verify transactions at: https://westend.subscan.io
 */

const { ApiPromise, WsProvider, Keyring } = require('@polkadot/api');
const { cryptoWaitReady } = require('@polkadot/util-crypto');

// Public Westend Testnet RPC
const WESTEND_RPC = 'wss://westend-rpc.polkadot.io';

async function deployToPublicChain() {
    console.log('🔗 Ubuntu Secure - PUBLIC BLOCKCHAIN DEPLOYMENT');
    console.log('='.repeat(60));
    console.log('Deploying to: Polkadot Westend Public Testnet');
    console.log('Anyone can verify at: https://westend.subscan.io');
    console.log('='.repeat(60));
    console.log();

    try {
        // Connect to Westend public testnet
        console.log('📡 Connecting to Westend public testnet...');
        const provider = new WsProvider(WESTEND_RPC);
        const api = await ApiPromise.create({ provider });

        await cryptoWaitReady();

        // Get chain info
        const chain = await api.rpc.system.chain();
        const nodeName = await api.rpc.system.name();
        const nodeVersion = await api.rpc.system.version();
        const lastHeader = await api.rpc.chain.getHeader();

        console.log('✅ Connected to PUBLIC blockchain!');
        console.log(`   Chain: ${chain}`);
        console.log(`   Node: ${nodeName} v${nodeVersion}`);
        console.log(`   Latest Block: #${lastHeader.number.toNumber()}`);
        console.log();

        // Create Alice account (development key for testnet)
        const keyring = new Keyring({ type: 'sr25519' });
        const alice = keyring.addFromUri('//Alice');

        console.log('👤 Using testnet account:');
        console.log(`   Address: ${alice.address}`);
        console.log();

        // Get account info
        const { nonce, data: balance } = await api.query.system.account(alice.address);
        console.log('💰 Account Balance:');
        console.log(`   Free: ${balance.free.toHuman()}`);
        console.log(`   Nonce: ${nonce.toNumber()}`);
        console.log();

        // Submit Ubuntu OS operation as remark (stores data on-chain)
        console.log('📝 Submitting Ubuntu OS operation to PUBLIC blockchain...');

        const ubuntuOsData = 'UbuntuSecure:' + JSON.stringify({
            sys: 'Ubuntu',
            op: 'boot',
            consensus: '3of5',
            chain: 'public'
        });

        // Submit minimal remark transaction (stores data permanently on-chain)
        const txHash = await api.tx.system.remark(ubuntuOsData)
            .signAndSend(alice, ({ status, events }) => {
                if (status.isInBlock) {
                    console.log('✅ Transaction included in block!');
                    console.log(`   Block Hash: ${status.asInBlock.toHex()}`);
                    console.log();
                }
                if (status.isFinalized) {
                    console.log('🎉 Transaction FINALIZED on PUBLIC blockchain!');
                    console.log(`   Finalized Block: ${status.asFinalized.toHex()}`);
                    console.log();

                    // Show public explorer links
                    console.log('🌐 PUBLIC VERIFICATION LINKS:');
                    console.log('='.repeat(60));
                    console.log(`   Westend Explorer: https://westend.subscan.io/account/${alice.address}`);
                    console.log(`   Polkadot.js Apps: https://polkadot.js.org/apps/?rpc=${encodeURIComponent(WESTEND_RPC)}#/explorer`);
                    console.log();
                    console.log('✅ Ubuntu Secure is NOW LIVE on PUBLIC blockchain!');
                    console.log('   Anyone in the world can verify these transactions.');
                    process.exit(0);
                }
            });

        console.log(`   Transaction Hash: ${txHash.toHex()}`);
        console.log('   Waiting for finalization...');

    } catch (error) {
        console.error('❌ Error:', error.message);
        process.exit(1);
    }
}

// Run deployment
deployToPublicChain().catch(console.error);
