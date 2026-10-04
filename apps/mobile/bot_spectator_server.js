const http = require('http');
const url = require('url');

const PORT = 8081;

// In-memory state synchronized from active game on http://localhost:8080/
let latestGameState = null;
let eventLogs = [];
let lastSyncTimestamp = 0;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, CORS_HEADERS);
    res.end();
    return;
  }

  // API: Receive state sync from Flutter web client (:8080)
  if (req.method === 'POST' && pathname === '/api/sync') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body);
        lastSyncTimestamp = Date.now();
        latestGameState = payload;

        if (payload.event) {
          const evt = payload.event;
          const exists = eventLogs.some(e => e.id === evt.id);
          if (!exists) {
            eventLogs.push(evt);
          }
        }

        res.writeHead(200, { ...CORS_HEADERS, 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true, logsCount: eventLogs.length }));
      } catch (err) {
        res.writeHead(400, { ...CORS_HEADERS, 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  // API: Get latest game state & event logs
  if (req.method === 'GET' && pathname === '/api/state') {
    const isConnected = (Date.now() - lastSyncTimestamp) < 15000 && latestGameState !== null;
    res.writeHead(200, { ...CORS_HEADERS, 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      connected: isConnected,
      lastSyncTimestamp,
      state: latestGameState,
      logs: eventLogs,
    }));
    return;
  }

  // API: Download complete game review logs as JSON file
  if (req.method === 'GET' && pathname === '/api/logs/export') {
    const exportData = {
      gameId: latestGameState ? latestGameState.gameId : 'none',
      exportedAt: new Date().toISOString(),
      totalEvents: eventLogs.length,
      latestGameState: latestGameState,
      chronologicalLogs: eventLogs,
    };
    const jsonStr = JSON.stringify(exportData, null, 2);
    res.writeHead(200, {
      ...CORS_HEADERS,
      'Content-Type': 'application/json',
      'Content-Disposition': `attachment; filename="maya_rummy_game_log_${Date.now()}.json"`,
    });
    res.end(jsonStr);
    return;
  }

  // API: Clear logs
  if (req.method === 'POST' && pathname === '/api/clear') {
    eventLogs = [];
    res.writeHead(200, { ...CORS_HEADERS, 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true }));
    return;
  }

  // Serve Dashboard HTML
  if (req.method === 'GET' && (pathname === '/' || pathname === '/index.html')) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(DASHBOARD_HTML);
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not Found');
});

server.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(` Maya AI Bot Live Spectator & Match Mirror running at:`);
  console.log(` 👉 http://localhost:${PORT}/`);
  console.log(` Listening for live game events from http://localhost:8080/`);
  console.log(`=======================================================`);
});

const DASHBOARD_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Maya AI Rummy — Live Match Mirror & Bot Spectator (:8081)</title>
  <style>
    :root {
      --bg-dark: #070D09;
      --panel-bg: #0F1A13;
      --panel-border: #1C3324;
      --felt-dark: #12281C;
      --accent: #E5A93C;
      --accent-glow: rgba(229, 169, 60, 0.35);
      --pure-green: #2ECC71;
      --impure-blue: #3498DB;
      --set-purple: #9B59B6;
      --deadwood-red: #E74C3C;
      --text: #F1F5F2;
      --text-muted: #8E9E94;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    body { background: var(--bg-dark); color: var(--text); height: 100vh; display: flex; flex-direction: column; overflow: hidden; }

    /* Header */
    header {
      background: #0B160F;
      border-bottom: 1px solid var(--panel-border);
      padding: 10px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .brand { display: flex; align-items: center; gap: 12px; font-weight: 800; font-size: 16px; color: var(--accent); }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 4px 10px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 700;
    }
    .badge.connected { background: rgba(46, 204, 113, 0.2); border: 1px solid var(--pure-green); color: var(--pure-green); }
    .badge.waiting { background: rgba(229, 169, 60, 0.2); border: 1px solid var(--accent); color: var(--accent); }

    .header-actions { display: flex; align-items: center; gap: 10px; }
    button {
      background: rgba(255,255,255,0.08);
      color: var(--text);
      border: 1px solid rgba(255,255,255,0.18);
      padding: 6px 14px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 12px;
      font-weight: 600;
      transition: all 0.2s;
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }
    button:hover { background: rgba(255,255,255,0.16); }
    button.primary { background: var(--accent); color: #000; border-color: var(--accent); }
    button.primary:hover { background: #f3b953; }

    /* Main Container */
    .main-container {
      flex: 1;
      display: flex;
      height: calc(100vh - 54px);
    }

    /* Left Pane: Live Game Mirror */
    .mirror-pane {
      flex: 1.45;
      background: radial-gradient(circle at center, #143021 0%, #0a1710 80%, #050c08 100%);
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 14px;
      overflow-y: auto;
      border-right: 1px solid var(--panel-border);
    }

    /* Section Containers */
    .section-card {
      background: rgba(11, 22, 16, 0.85);
      border: 1px solid var(--panel-border);
      border-radius: 12px;
      padding: 12px 16px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    }
    .section-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 10px;
      padding-bottom: 8px;
      border-bottom: 1px solid rgba(255,255,255,0.06);
    }
    .section-title {
      font-size: 14px;
      font-weight: 700;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .stats-row {
      display: flex;
      gap: 12px;
      font-size: 12px;
    }
    .stat-pill {
      background: rgba(255,255,255,0.06);
      padding: 3px 8px;
      border-radius: 4px;
      color: var(--text-muted);
    }
    .stat-pill strong { color: var(--text); }
    .stat-pill.deadwood { border: 1px solid var(--deadwood-red); color: var(--deadwood-red); background: rgba(231,76,60,0.1); }
    .stat-pill.pure { border: 1px solid var(--pure-green); color: var(--pure-green); background: rgba(46,204,113,0.1); }

    /* Meld Groups Container */
    .melds-wrapper {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
    }
    .meld-box {
      background: rgba(0,0,0,0.35);
      border-radius: 8px;
      padding: 8px;
      border: 1px solid rgba(255,255,255,0.1);
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .meld-box.pureSequence { border-color: var(--pure-green); background: rgba(46, 204, 113, 0.08); }
    .meld-box.impureSequence { border-color: var(--impure-blue); background: rgba(52, 152, 219, 0.08); }
    .meld-box.validSet { border-color: var(--set-purple); background: rgba(155, 89, 182, 0.08); }
    .meld-box.invalid { border-color: rgba(231, 76, 60, 0.4); background: rgba(231, 76, 60, 0.05); }

    .meld-header {
      font-size: 10px;
      font-weight: 800;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      display: flex;
      justify-content: space-between;
      color: var(--text-muted);
    }
    .meld-box.pureSequence .meld-header { color: var(--pure-green); }
    .meld-box.impureSequence .meld-header { color: var(--impure-blue); }
    .meld-box.validSet .meld-header { color: var(--set-purple); }
    .meld-box.invalid .meld-header { color: #e57373; }

    .cards-row {
      display: flex;
      gap: 4px;
    }

    /* Playing Card Visual */
    .card-ui {
      width: 42px;
      height: 60px;
      background: #FFFFFF;
      border-radius: 5px;
      box-shadow: 0 2px 5px rgba(0,0,0,0.4);
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      padding: 3px;
      position: relative;
      user-select: none;
      border: 1px solid #ddd;
    }
    .card-ui.red { color: #D32F2F; }
    .card-ui.black { color: #212121; }
    .card-ui.wild {
      border: 2px solid var(--accent);
      box-shadow: 0 0 8px var(--accent-glow);
    }
    .card-rank { font-size: 13px; font-weight: 900; line-height: 1; }
    .card-suit { font-size: 15px; line-height: 1; align-self: flex-end; }
    .card-joker-tag {
      position: absolute;
      bottom: 2px;
      left: 2px;
      background: #E5A93C;
      color: #000;
      font-size: 7px;
      font-weight: 900;
      padding: 1px 2px;
      border-radius: 2px;
    }

    /* Center Table */
    .center-table {
      display: flex;
      justify-content: space-around;
      align-items: center;
      background: rgba(0,0,0,0.3);
      border-radius: 12px;
      padding: 12px;
      border: 1px dashed rgba(255,255,255,0.12);
    }
    .table-slot {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
    }
    .slot-label { font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; }
    .deck-back {
      width: 44px;
      height: 62px;
      background: linear-gradient(135deg, #1b4d3e, #0e2a22);
      border: 2px solid #2d7a62;
      border-radius: 5px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--accent);
      font-size: 11px;
      font-weight: 800;
      box-shadow: 0 4px 8px rgba(0,0,0,0.4);
    }

    /* Right Pane: Logs & Telemetry */
    .telemetry-pane {
      flex: 1;
      background: #0B130E;
      display: flex;
      flex-direction: column;
      border-left: 1px solid var(--panel-border);
    }
    .telemetry-header {
      padding: 12px 16px;
      background: #0F1A13;
      border-bottom: 1px solid var(--panel-border);
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .filter-chips {
      display: flex;
      gap: 6px;
      overflow-x: auto;
    }
    .filter-chip {
      background: rgba(255,255,255,0.06);
      border: 1px solid rgba(255,255,255,0.1);
      padding: 4px 10px;
      border-radius: 14px;
      font-size: 11px;
      cursor: pointer;
      color: var(--text-muted);
    }
    .filter-chip.active {
      background: var(--accent);
      color: #000;
      border-color: var(--accent);
      font-weight: 700;
    }
    .log-stream {
      flex: 1;
      overflow-y: auto;
      padding: 12px 16px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }

    /* Event Card */
    .event-card {
      background: #111E16;
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 8px;
      padding: 10px 12px;
      display: flex;
      flex-direction: column;
      gap: 6px;
      font-size: 12px;
      border-left: 4px solid #7f8c8d;
    }
    .event-card.bot { border-left-color: var(--accent); }
    .event-card.player { border-left-color: var(--impure-blue); }
    .event-card.declare { border-left-color: var(--pure-green); background: rgba(46,204,113,0.06); }
    .event-card.drop { border-left-color: var(--deadwood-red); background: rgba(231,76,60,0.06); }

    .event-top {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .actor-tag {
      font-size: 10px;
      font-weight: 800;
      padding: 2px 6px;
      border-radius: 3px;
      text-transform: uppercase;
    }
    .actor-tag.bot { background: rgba(229,169,60,0.2); color: var(--accent); }
    .actor-tag.player { background: rgba(52,152,219,0.2); color: var(--impure-blue); }
    .actor-tag.dealer { background: rgba(255,255,255,0.1); color: var(--text-muted); }

    .event-time { font-size: 10px; color: var(--text-muted); }
    .event-title { font-weight: 700; font-size: 13px; color: var(--text); }
    .event-details { color: #C5D1CA; line-height: 1.4; font-size: 11px; }

    /* Collapsible Telemetry Details */
    .telemetry-box {
      margin-top: 4px;
      background: rgba(0,0,0,0.3);
      border-radius: 6px;
      padding: 6px 8px;
      font-family: monospace;
      font-size: 10.5px;
      color: #A3B8AD;
      border: 1px solid rgba(255,255,255,0.05);
    }
    .telemetry-row { display: flex; justify-content: space-between; padding: 2px 0; border-bottom: 1px solid rgba(255,255,255,0.04); }
    .telemetry-row:last-child { border-bottom: none; }
  </style>
</head>
<body>

  <!-- Top Bar -->
  <header>
    <div class="brand">
      <span>🦚</span>
      <span>Maya AI Rummy — Match Mirror & Bot Spectator</span>
      <span id="connectionBadge" class="badge waiting">● WAITING FOR GAME ON :8080</span>
    </div>
    <div class="header-actions">
      <button onclick="downloadLogs()" class="primary">
        <span>📥</span> Download Game Log (JSON)
      </button>
      <button onclick="clearLogs()">
        <span>🗑️</span> Clear Logs
      </button>
    </div>
  </header>

  <!-- Main Split Layout -->
  <div class="main-container">
    
    <!-- LEFT: Live Game Mirror -->
    <div class="mirror-pane">
      
      <!-- MAYA AI BOT (Transparent Cards) -->
      <div class="section-card">
        <div class="section-header">
          <div class="section-title">
            <span>🤖</span>
            <span>Maya AI Bot (Revealed Face-Up Hand)</span>
            <span id="botDealerBadge" style="display:none; margin-left:8px; padding:2px 6px; font-size:10px; font-weight:800; border-radius:4px; background:rgba(229,169,60,0.25); color:var(--accent); border:1px solid var(--accent);">🅳 DEALER</span>
          </div>
          <div class="stats-row">
            <span class="stat-pill">Cards: <strong id="botCardCount">0</strong></span>
            <span class="stat-pill deadwood">Deadwood: <strong id="botDeadwood">0 pts</strong></span>
            <span class="stat-pill pure">Pure Seq: <strong id="botPureSeq">0</strong></span>
            <span class="stat-pill">Total Seq: <strong id="botTotalSeq">0</strong></span>
          </div>
        </div>
        <div id="botMeldsContainer" class="melds-wrapper">
          <div style="color: var(--text-muted); font-size: 12px;">Waiting for cards from http://localhost:8080/...</div>
        </div>
      </div>

      <!-- CENTER TABLE -->
      <div class="center-table">
        <div class="table-slot">
          <span class="slot-label">Closed Deck</span>
          <div id="closedDeckView" class="deck-back">--</div>
        </div>

        <div class="table-slot">
          <span class="slot-label">Wild Joker</span>
          <div id="wildJokerView">
            <div class="card-ui" style="opacity:0.5;"></div>
          </div>
        </div>

        <div class="table-slot">
          <span class="slot-label">Open Discard Pile</span>
          <div id="openPileView">
            <div class="card-ui" style="opacity:0.5;"></div>
          </div>
        </div>

        <div class="table-slot">
          <span class="slot-label">Game Status</span>
          <div id="turnStatusView" style="font-size:12px; font-weight:700; color:var(--accent);">Ready</div>
        </div>
      </div>

      <!-- HUMAN PLAYER HAND MIRROR -->
      <div class="section-card">
        <div class="section-header">
          <div class="section-title">
            <span>👤</span>
            <span>Human Player Hand (:8080 Mirror)</span>
            <span id="playerDealerBadge" style="display:none; margin-left:8px; padding:2px 6px; font-size:10px; font-weight:800; border-radius:4px; background:rgba(229,169,60,0.25); color:var(--accent); border:1px solid var(--accent);">🅳 DEALER</span>
          </div>
          <div class="stats-row">
            <span class="stat-pill">Cards: <strong id="playerCardCount">0</strong></span>
            <span class="stat-pill deadwood">Current Score: <strong id="playerScore">0 pts</strong></span>
          </div>
        </div>
        <div id="playerMeldsContainer" class="melds-wrapper">
          <div style="color: var(--text-muted); font-size: 12px;">Waiting for player hand...</div>
        </div>
      </div>

      <!-- TOURNAMENT SCORECARD -->
      <div class="section-card">
        <div class="section-header">
          <div class="section-title">
            <span>🏆</span>
            <span>Tournament Scorecard (Elimination: 201 pts)</span>
          </div>
        </div>
        <div id="scorecardTable" style="font-size:12px; overflow-x:auto;">
          <table style="width:100%; border-collapse:collapse; text-align:left;">
            <thead>
              <tr style="border-bottom:1px solid rgba(255,255,255,0.1); color:var(--text-muted);">
                <th style="padding:6px;">Round</th>
                <th style="padding:6px;">Human</th>
                <th style="padding:6px;">Maya Bot</th>
                <th style="padding:6px;">Outcome</th>
              </tr>
            </thead>
            <tbody id="scorecardBody">
              <tr><td colspan="4" style="padding:8px; color:var(--text-muted);">No completed rounds yet.</td></tr>
            </tbody>
          </table>
        </div>
      </div>

    </div>

    <!-- RIGHT: Real-Time Event & Decision Stream -->
    <div class="telemetry-pane">
      <div class="telemetry-header">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <strong style="font-size:13px;">Game Events & Bot Rationale Stream</strong>
          <span id="logCountLabel" style="font-size:11px; color:var(--text-muted);">0 events</span>
        </div>
        <div class="filter-chips">
          <div class="filter-chip active" onclick="setFilter('ALL', this)">All Events</div>
          <div class="filter-chip" onclick="setFilter('BOT', this)">🤖 Bot Decisions</div>
          <div class="filter-chip" onclick="setFilter('PLAYER', this)">👤 Player Moves</div>
          <div class="filter-chip" onclick="setFilter('FINALS', this)">🏆 Declarations / Drops</div>
        </div>
      </div>
      <div id="logStream" class="log-stream">
        <div style="color: var(--text-muted); font-size: 12px; text-align: center; margin-top: 20px;">
          Awaiting moves from http://localhost:8080/...
        </div>
      </div>
    </div>

  </div>

  <script>
    let activeFilter = 'ALL';
    let knownLogIds = new Set();
    let currentLogs = [];

    const SUIT_SYMBOLS = {
      hearts: '♥',
      diamonds: '♦',
      clubs: '♣',
      spades: '♠'
    };

    function setFilter(filter, el) {
      activeFilter = filter;
      document.querySelectorAll('.filter-chip').forEach(c => c.classList.remove('active'));
      el.classList.add('active');
      renderLogs();
    }

    function renderCard(card) {
      if (!card) return '<div class="card-ui" style="opacity:0.2;"></div>';
      if (card.isPrintedJoker) {
        return '<div class="card-ui black wild"><div class="card-rank">JK</div><div class="card-suit">★</div><div class="card-joker-tag">JOKER</div></div>';
      }
      const suit = card.suit ? card.suit.toLowerCase() : 'spades';
      const isRed = suit === 'hearts' || suit === 'diamonds';
      const symbol = SUIT_SYMBOLS[suit] || '♠';
      const rankUpper = card.rank ? card.rank.toUpperCase() : '?';
      const rankShort = rankUpper.replace('TEN', '10').replace('NINE', '9').replace('EIGHT', '8')
        .replace('SEVEN', '7').replace('SIX', '6').replace('FIVE', '5').replace('FOUR', '4')
        .replace('THREE', '3').replace('TWO', '2').replace('ACE', 'A').replace('JACK', 'J')
        .replace('QUEEN', 'Q').replace('KING', 'K');

      const wildClass = card.isWild ? 'wild' : '';
      const wildTag = card.isWild ? '<div class="card-joker-tag">WILD</div>' : '';

      return '<div class="card-ui ' + (isRed ? 'red' : 'black') + ' ' + wildClass + '">' +
        '<div class="card-rank">' + rankShort + '</div>' +
        '<div class="card-suit">' + symbol + '</div>' +
        wildTag +
        '</div>';
    }

    function renderMelds(groups, containerId) {
      const container = document.getElementById(containerId);
      if (!groups || groups.length === 0) {
        container.innerHTML = '<div style="color: var(--text-muted); font-size:12px;">No cards yet.</div>';
        return;
      }

      let html = '';
      groups.forEach(g => {
        const typeClass = g.type || 'invalid';
        html += '<div class="meld-box ' + typeClass + '">';
        html += '<div class="meld-header">';
        html += '<span>' + (g.label || 'GROUP') + '</span>';
        if (g.isValid) html += '<span>✓ VALID</span>';
        html += '</div>';
        html += '<div class="cards-row">';
        (g.cards || []).forEach(c => {
          html += renderCard(c);
        });
        html += '</div></div>';
      });

      container.innerHTML = html;
    }

    function renderTableState(data) {
      if (!data) return;

      // Update badge
      const badge = document.getElementById('connectionBadge');
      badge.className = 'badge connected';
      badge.textContent = '● LIVE MIRROR ACTIVE (:8080)';

      // Maya Bot
      if (data.botPlayer) {
        document.getElementById('botCardCount').textContent = data.botPlayer.handCount || 0;
        document.getElementById('botDeadwood').textContent = (data.botPlayer.deadwoodPoints || 0) + ' pts';
        document.getElementById('botPureSeq').textContent = data.botPlayer.pureSeqCount || 0;
        document.getElementById('botTotalSeq').textContent = data.botPlayer.totalSeqCount || 0;
        renderMelds(data.botPlayer.groups, 'botMeldsContainer');
      }

      // Dealer badge toggles
      const botDealer = document.getElementById('botDealerBadge');
      const playerDealer = document.getElementById('playerDealerBadge');
      if (botDealer && playerDealer) {
        if (data.dealerId === 'ai_bot_1') {
          botDealer.style.display = 'inline-block';
          playerDealer.style.display = 'none';
        } else if (data.dealerId === 'human_player') {
          botDealer.style.display = 'none';
          playerDealer.style.display = 'inline-block';
        } else {
          botDealer.style.display = 'none';
          playerDealer.style.display = 'none';
        }
      }

      // Center Table
      document.getElementById('closedDeckView').textContent = (data.closedDeckCount || 0) + ' cards';
      if (data.wildJoker) {
        document.getElementById('wildJokerView').innerHTML = renderCard(data.wildJoker);
      }
      if (data.openPile && data.openPile.length > 0) {
        const topOpen = data.openPile[data.openPile.length - 1];
        document.getElementById('openPileView').innerHTML = renderCard(topOpen);
      } else {
        document.getElementById('openPileView').innerHTML = '<div class="card-ui" style="opacity:0.2;"></div>';
      }

      // Turn status
      const turnLabel = data.isAwaitingHumanDeclarationShow
        ? '🤖 Maya Declared Show — Human Rearranging Hand'
        : (data.isRoundOver ? 'ROUND COMPLETE' :
          (data.currentPlayerId === 'human_player' ? '👉 Human Turn' : '🤖 Maya Bot Turn'));
      document.getElementById('turnStatusView').textContent = turnLabel + ' (' + (data.phase || '') + ')';

      // Human Player
      if (data.humanPlayer) {
        document.getElementById('playerCardCount').textContent = data.humanPlayer.handCount || 0;
        document.getElementById('playerScore').textContent = (data.humanPlayer.score || 0) + ' pts';
        renderMelds(data.humanPlayer.groups, 'playerMeldsContainer');
      }

      // Scorecard
      if (data.roundScores && data.roundScores.length > 0) {
        let scHtml = '';
        data.roundScores.forEach(r => {
          scHtml += '<tr style="border-bottom:1px solid rgba(255,255,255,0.05);">';
          scHtml += '<td style="padding:6px;">Round ' + r.roundNumber + '</td>';
          scHtml += '<td style="padding:6px; color:#3498DB;">' + r.humanScore + ' (tot: ' + r.cumulativeHumanScore + ')</td>';
          scHtml += '<td style="padding:6px; color:#E5A93C;">' + r.aiScore + ' (tot: ' + r.cumulativeAiScore + ')</td>';
          scHtml += '<td style="padding:6px; font-weight:600;">' + (r.humanOutcome || '') + '</td>';
          scHtml += '</tr>';
        });
        document.getElementById('scorecardBody').innerHTML = scHtml;
      }
    }

    function renderLogs() {
      const stream = document.getElementById('logStream');
      const filtered = currentLogs.filter(e => {
        if (activeFilter === 'ALL') return true;
        if (activeFilter === 'BOT') return e.actor === 'Maya AI Bot';
        if (activeFilter === 'PLAYER') return e.actor === 'Human Player';
        if (activeFilter === 'FINALS') return e.type.includes('DECLAR') || e.type.includes('DROP');
        return true;
      });

      document.getElementById('logCountLabel').textContent = filtered.length + ' events';

      if (filtered.length === 0) {
        stream.innerHTML = '<div style="color:var(--text-muted); font-size:12px; text-align:center; margin-top:20px;">No events matching filter.</div>';
        return;
      }

      let html = '';
      filtered.slice().reverse().forEach(e => {
        const actorClass = (e.actor === 'Maya AI Bot') ? 'bot' : (e.actor === 'Human Player' ? 'player' : 'dealer');
        let cardTypeClass = actorClass;
        if (e.type && e.type.includes('DECLAR')) cardTypeClass = 'declare';
        if (e.type && e.type.includes('DROP')) cardTypeClass = 'drop';

        const timeStr = e.timestamp ? (new Date(e.timestamp)).toLocaleTimeString() : '';

        html += '<div class="event-card ' + cardTypeClass + '">';
        html += '<div class="event-top">';
        html += '<span class="actor-tag ' + actorClass + '">' + (e.actor || 'SYSTEM') + '</span>';
        html += '<span class="event-time">' + timeStr + '</span>';
        html += '</div>';
        function cleanText(str) {
          if (!str) return '';
          return String(str).replace(/\$rankStr\$suitStr/gi, 'Card');
        }

        html += '<div class="event-title">' + cleanText(e.title || e.type) + '</div>';
        html += '<div class="event-details">' + cleanText(e.details || '') + '</div>';

        // Render Telemetry Box if present
        if (e.telemetry) {
          html += '<div class="telemetry-box">';
          if (e.telemetry.humanFinalCards && e.telemetry.botFinalCards) {
            html += '<div style="margin-top:4px; margin-bottom:6px; font-weight:700; color:var(--gold); border-bottom:1px solid rgba(255,255,255,0.1); padding-bottom:4px;">🃏 Final Cards & Counts on Declaration:</div>';
            
            html += '<div style="background:rgba(52,152,219,0.08); border:1px solid rgba(52,152,219,0.25); border-radius:6px; padding:6px 8px; margin-bottom:6px;">';
            html += '<div style="font-weight:700; color:#3498DB; font-size:12px; margin-bottom:4px;">👤 Human Player Hand (' + (e.telemetry.humanScore ?? 0) + ' pts total):</div>';
            e.telemetry.humanFinalCards.forEach(g => {
              html += '<div style="font-size:11px; margin-left:6px; margin-bottom:2px;"><span style="color:var(--text-muted);">' + g.label + ' (' + g.count + ' cards):</span> <b style="letter-spacing:1px; color:#fff;">' + g.cards + '</b> <span style="color:#F39C12;">[' + g.deadwood + ' pts]</span></div>';
            });
            html += '</div>';

            html += '<div style="background:rgba(229,169,60,0.08); border:1px solid rgba(229,169,60,0.25); border-radius:6px; padding:6px 8px; margin-bottom:6px;">';
            html += '<div style="font-weight:700; color:var(--gold); font-size:12px; margin-bottom:4px;">🤖 Maya AI Bot Hand (' + (e.telemetry.aiScore ?? 0) + ' pts total - Rearranged to Least Count):</div>';
            e.telemetry.botFinalCards.forEach(g => {
              html += '<div style="font-size:11px; margin-left:6px; margin-bottom:2px;"><span style="color:var(--text-muted);">' + g.label + ' (' + g.count + ' cards):</span> <b style="letter-spacing:1px; color:#fff;">' + g.cards + '</b> <span style="color:#F39C12;">[' + g.deadwood + ' pts]</span></div>';
            });
            html += '</div>';
          }

          for (const [k, v] of Object.entries(e.telemetry)) {
            if (k === 'humanFinalCards' || k === 'botFinalCards') continue;
            if (k === 'candidateEvaluations' && Array.isArray(v)) {
              html += '<div style="margin-top:4px; font-weight:700;">Evaluated Discard Candidates:</div>';
              v.forEach(c => {
                html += '<div class="telemetry-row"><span>' + c.card + '</span><span>Resulting Deadwood: ' + c.resultingDeadwood + ' pts</span></div>';
              });
            } else {
              html += '<div class="telemetry-row"><span>' + k + ':</span><span>' + JSON.stringify(v) + '</span></div>';
            }
          }
          html += '</div>';
        }

        html += '</div>';
      });

      stream.innerHTML = html;
    }

    async function pollState() {
      try {
        const res = await fetch('/api/state');
        if (!res.ok) return;
        const data = await res.json();
        if (data.state) {
          renderTableState(data.state);
        }
        if (data.logs) {
          currentLogs = data.logs;
          renderLogs();
        }
      } catch (err) {
        // Ignored
      }
    }

    function downloadLogs() {
      window.location.href = '/api/logs/export';
    }

    async function clearLogs() {
      if (!confirm('Clear all logged events?')) return;
      await fetch('/api/clear', { method: 'POST' });
      currentLogs = [];
      renderLogs();
    }

    // Auto poll every 400ms
    setInterval(pollState, 400);
    pollState();
  </script>
</body>
</html>
`;
