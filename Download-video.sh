#!/bin/bash
set -e

# === CONFIGURATION ===
LOGIN_EMAIL="your-email@example.com"
LOGIN_PASSWORD="your-password"
URL_FILE="URL.txt"

# === INSTALL DEPENDENCIES ===
echo "[*] Installing dependencies..."
sudo apt update
sudo apt install -y curl python3-pip
pip install playwright python-dotenv
npm install -D playwright
npx playwright install --with-deps

# === Install yt-dlp ===
echo "[*] Installing yt-dlp..."
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
  -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp

# === Playwright login to YouTube and export cookies ===
echo "[*] Logging in to YouTube..."
cat > login.mjs << 'EOF'
import { chromium } from 'playwright';
import fs from 'fs';

const EMAIL = process.env.LOGIN_EMAIL;
const PASSWORD = process.env.LOGIN_PASSWORD;

const run = async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto('https://www.youtube.com/');
  await page.getByRole('link', { name: 'Sign in' }).click();
  await page.getByRole('textbox', { name: 'Email or phone' }).fill(EMAIL);
  await page.getByRole('button', { name: /^Next$/ }).click();
  await page.waitForTimeout(2000);
  await page.getByRole('textbox', { name: 'Username' }).fill(EMAIL);
  await page.getByRole('button', { name: /^Next$/ }).click();
  await page.getByRole('textbox', { name: 'Password' }).fill(PASSWORD);
  await page.getByRole('button', { name: /^Verify$/ }).click();

  await page.waitForURL('https://www.youtube.com/*');

  const cookies = await context.cookies();
  const netscape = cookies.map(c => [
    c.domain.startsWith('.') ? c.domain : '.' + c.domain,
    'TRUE',
    c.path,
    c.secure ? 'TRUE' : 'FALSE',
    (c.expires && c.expires > Date.now() / 1000
      ? Math.floor(c.expires)
      : Math.floor(Date.now() / 1000 + 3600)),
    c.name,
    c.value
  ].join('\t')).join('\n');

  fs.writeFileSync('cookies.txt', '# Netscape HTTP Cookie File\n' + netscape);
  await browser.close();
};

run();
EOF

LOGIN_EMAIL="$LOGIN_EMAIL" LOGIN_PASSWORD="$LOGIN_PASSWORD" node login.mjs

# === Create videos folder ===
mkdir -p videos

# === Download all videos / playlists from URL.txt ===
echo "[*] Downloading from URLs in $URL_FILE..."
yt-dlp --cookies cookies.txt \
  -f "bestvideo+bestaudio/best" --merge-output-format mp4 \
  -a "$URL_FILE" \
  -o "%(playlist_index)s - %(title)s.%(ext)s"

echo "[✓] All downloads complete. Files saved in ./videos"
