const puppeteer = require('puppeteer');

(async () => {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Capture console messages
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();
        console.log(`[CONSOLE ${type.toUpperCase()}] ${text}`);
    });

    // Capture errors
    page.on('pageerror', error => {
        console.log(`[PAGE ERROR] ${error.message}`);
        console.log(error.stack);
    });

    // Capture failed requests
    page.on('requestfailed', request => {
        console.log(`[REQUEST FAILED] ${request.url()}`);
        console.log(`  ${request.failure().errorText}`);
    });

    console.log('Loading page...');
    await page.goto('http://127.0.0.1:8888/linux-blockchain-sync.html', {
        waitUntil: 'networkidle0',
        timeout: 30000
    });

    // Wait a bit for scripts to execute
    await new Promise(resolve => setTimeout(resolve, 5000));

    console.log('\n=== Test Complete ===');
    await browser.close();
})();
