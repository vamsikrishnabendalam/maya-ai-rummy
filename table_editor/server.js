const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8088;
const ROOT_DIR = __dirname;
const ASSETS_DIR = path.join(__dirname, '..', 'apps', 'mobile', 'assets');
const SAVE_FILE = path.join(__dirname, 'saved_positions.json');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
};

const server = http.createServer((req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // API endpoint to save positions
  if (req.method === 'POST' && req.url === '/api/save') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        fs.writeFileSync(SAVE_FILE, JSON.stringify(data, null, 2), 'utf-8');
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, message: 'Saved successfully!' }));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: err.message }));
      }
    });
    return;
  }

  // API endpoint to load saved positions
  if (req.method === 'GET' && req.url === '/api/load') {
    if (fs.existsSync(SAVE_FILE)) {
      const data = fs.readFileSync(SAVE_FILE, 'utf-8');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(data);
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ notFound: true }));
    }
    return;
  }

  // API endpoint to list all available avatars
  if (req.method === 'GET' && req.url === '/api/avatars') {
    const avatarDir = path.join(ASSETS_DIR, 'avatars');
    if (fs.existsSync(avatarDir)) {
      const files = fs.readdirSync(avatarDir)
        .filter(f => f.endsWith('.webp') && !f.includes('thumb'));
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(files));
    } else {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(['default_avatar.webp', 'female_01.webp', 'male_01.webp']));
    }
    return;
  }

  // Static assets under /assets/
  let filePath;
  if (req.url.startsWith('/assets/')) {
    const relPath = req.url.replace('/assets/', '');
    filePath = path.join(ASSETS_DIR, relPath);
  } else {
    const cleanUrl = req.url.split('?')[0];
    filePath = path.join(ROOT_DIR, cleanUrl === '/' ? 'index.html' : cleanUrl);
  }

  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(ROOT_DIR, 'index.html');
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(404);
      res.end('File Not Found: ' + req.url);
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content);
    }
  });
});

server.listen(PORT, () => {
  console.log(`[TableEditor] Localhost template editor active at http://localhost:${PORT}/`);
});

