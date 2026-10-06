// Renders each banner in banners.html to docs/banners/<id>.png at 2160×2160.
//
//   flutter test tool/render --update-goldens   # app screens used in the mockups
//   node tool/banners/render.cjs                 # needs the `playwright` package
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const out = path.join(__dirname, '../../docs/banners');
  require('fs').mkdirSync(out, { recursive: true });

  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: 1200, height: 1200 },
    deviceScaleFactor: 2,
  });
  await page.goto('file://' + path.join(__dirname, 'banners.html'));
  await page.evaluate(() => document.fonts.ready);
  await page.waitForLoadState('networkidle');

  for (const banner of await page.$$('.banner')) {
    const id = await banner.getAttribute('id');
    await banner.screenshot({ path: path.join(out, `${id}.png`) });
    console.log(`docs/banners/${id}.png`);
  }
  await browser.close();
})();
