const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  page.on('console', msg => console.log('PAGE LOG:', msg.text()));
  page.on('pageerror', err => console.log('PAGE ERROR:', err.message));
  await page.goto('http://localhost:8000/#demo');
  await page.waitForTimeout(4000);
  await page.click('#start-demo-btn');
  console.log("Clicked simulate");
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'screenshot-anim3.png' });
  await browser.close();
})();
