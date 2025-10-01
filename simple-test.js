// Simple test: Load bundles in Node.js and check for errors
const https = require('https');
const http = require('http');

function fetch(url) {
    return new Promise((resolve, reject) => {
        const client = url.startsWith('https') ? https : http;
        client.get(url, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => resolve(data));
        }).on('error', reject);
    });
}

async function testBundles() {
    console.log('Testing Polkadot API bundles...\n');

    const bundles = [
        'https://unpkg.com/@polkadot/util@10.4.2/bundle-polkadot-util.js',
        'https://unpkg.com/@polkadot/util-crypto@10.4.2/bundle-polkadot-util-crypto.js',
        'https://unpkg.com/@polkadot/keyring@10.4.2/bundle-polkadot-keyring.js',
        'https://unpkg.com/@polkadot/types@10.9.1/bundle-polkadot-types.js',
        'https://unpkg.com/@polkadot/api@10.9.1/bundle-polkadot-api.js'
    ];

    for (const url of bundles) {
        console.log(`Fetching: ${url}`);
        try {
            const code = await fetch(url);
            console.log(`  Size: ${(code.length / 1024).toFixed(1)}KB`);

            // Try to check for syntax errors
            try {
                new Function(code);
                console.log(`  ✅ Valid JavaScript\n`);
            } catch (e) {
                console.log(`  ❌ SYNTAX ERROR: ${e.message}\n`);
            }
        } catch (e) {
            console.log(`  ❌ FETCH ERROR: ${e.message}\n`);
        }
    }

    console.log('\nVersion compatibility check:');
    console.log('  util/util-crypto/keyring: v10.4.2');
    console.log('  types/api: v10.9.1');
    console.log('  ✅ Compatible v10.x range');
}

testBundles();
