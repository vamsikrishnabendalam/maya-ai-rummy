const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer-core');

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const OUTPUT_DIR = path.join(__dirname, 'screenshots');

if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

const BASE_URL = 'https://maya-rummy-vk.web.app';

const VIEWPORTS = [
  {
    name: 'desktop_landscape',
    width: 1440,
    height: 900,
    isMobile: false,
    hasTouch: false,
    deviceScaleFactor: 1
  },
  {
    name: 'desktop_portrait',
    width: 900,
    height: 1200,
    isMobile: false,
    hasTouch: false,
    deviceScaleFactor: 1
  },
  {
    name: 'mobile_landscape',
    width: 844,
    height: 390,
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 2
  },
  {
    name: 'mobile_portrait',
    width: 390,
    height: 844,
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 2
  }
];

const SCREENS = [
  { id: '01_home', path: '/' },
  { id: '02_game_table_ai', path: '/play-ai', waitExtraMs: 6000 },
  { id: '03_multiplayer_hub', path: '/multiplayer' },
  { id: '04_profile_modal', path: '/profile', waitExtraMs: 2000 },
  { id: '05_rewards_modal', path: '/rewards', waitExtraMs: 2000 },
  { id: '06_admin_dashboard', path: '/admin' }
];

async function capture() {
  console.log('Launching browser at:', CHROME_PATH);
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-web-security',
      '--allow-running-insecure-content',
      '--disable-features=IsolateOrigins,site-per-process'
    ]
  });

  const page = await browser.newPage();

  for (const vp of VIEWPORTS) {
    console.log(`\n========================================`);
    console.log(`Setting Viewport: ${vp.name} (${vp.width}x${vp.height})`);
    console.log(`========================================`);

    await page.setViewport({
      width: vp.width,
      height: vp.height,
      isMobile: vp.isMobile,
      hasTouch: vp.hasTouch,
      deviceScaleFactor: vp.deviceScaleFactor
    });

    for (const screen of SCREENS) {
      const url = `${BASE_URL}${screen.path}`;
      const filename = `${screen.id}_${vp.name}.png`;
      const outputPath = path.join(OUTPUT_DIR, filename);

      console.log(`Capturing: ${screen.id} -> ${url}`);
      try {
        await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });
        // Give Flutter time to render CanvasKit and animations
        const waitTime = 4000 + (screen.waitExtraMs || 0);
        await new Promise((r) => setTimeout(r, waitTime));

        await page.screenshot({ path: outputPath, fullPage: false });
        console.log(`Saved: ${outputPath}`);
      } catch (err) {
        console.error(`Error capturing ${screen.id} on ${vp.name}:`, err.message);
      }
    }
  }

  await browser.close();
  console.log('\nAll screenshots captured successfully!');
}

capture().catch((err) => {
  console.error('Fatal error in capture script:', err);
  process.exit(1);
});
