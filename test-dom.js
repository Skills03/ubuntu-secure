const http = require('http');
const { JSDOM } = require('jsdom');

http.get('http://127.0.0.1:8888/linux-blockchain-sync.html', (res) => {
    let html = '';
    res.on('data', chunk => html += chunk);
    res.on('end', () => {
        console.log('HTML loaded, parsing...\n');

        const dom = new JSDOM(html, {
            runScripts: 'dangerously',
            resources: 'usable',
            beforeParse(window) {
                // Capture console
                window.console.log = (...args) => {
                    console.log('[PAGE]', ...args);
                };
                window.console.error = (...args) => {
                    console.error('[ERROR]', ...args);
                };
            }
        });

        setTimeout(() => {
            const doc = dom.window.document;
            console.log('\n=== DOM Elements Check ===');
            console.log('screen_container:', doc.getElementById('screen_container'));
            console.log('loading:', doc.getElementById('loading'));
            console.log('blockchain-badge:', doc.getElementById('blockchain-badge'));

            console.log('\n=== Test Complete ===');
            process.exit(0);
        }, 2000);
    });
}).on('error', (e) => {
    console.error('HTTP error:', e);
    process.exit(1);
});
