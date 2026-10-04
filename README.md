# Maya AI Rummy — Cross-Platform Indian 13-Card Rummy Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Hosting%20%7C%20Firestore%20%7C%20Auth-FFCA28?logo=firebase)](https://firebase.google.com)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Maya AI Rummy** is a production-grade, server-authoritative cross-platform 13-card Indian Rummy platform built with Flutter Web/Mobile, Firebase (Firestore, Auth, Cloud Functions), a pure Dart Rules & State Engine, and an advanced AI opponent ("Maya").

---

## 🚀 Live Demo & Production URLs

- **Primary Custom Domain**: [https://mayarummy.cwards.com](https://mayarummy.cwards.com)
- **Firebase Hosting Fallback**: [https://maya-rummy-vk.web.app](https://maya-rummy-vk.web.app)
- **Admin Dashboard**: [https://mayarummy.cwards.com/#/admin](https://mayarummy.cwards.com/#/admin)

---

## 🔑 Authentication & Login Guide

### 1. Player User Login (Google Sign-In & Virtual Coin Wallet)
- **Authentication Standard**: Server-authoritative Google Sign-In via Firebase Auth.
- **How to Log In**:
  1. Open the app at [https://mayarummy.cwards.com](https://mayarummy.cwards.com).
  2. Click **Login with Google**.
  3. Complete your profile (Name, Date of Birth, Country).
  4. **Initial Bonus**: Upon first profile setup, the system atomically grants **5,000 Free Virtual Coins** into your server-persisted wallet (`users/{uid}` and `coinTransactions` ledger).
- **Guest Play Mode**:
  - Clicking **Play as Guest** allows immediate single-player games against the Maya AI bot.
  - Guest accounts receive 0 virtual coins and cannot access monetized tables or collect daily rewards.

### 2. Admin Dashboard Access (`/admin`)
- **URL Route**: Navigate to `/admin` or open [https://mayarummy.cwards.com/#/admin](https://mayarummy.cwards.com/#/admin).
- **Admin Authorization**:
  - Any Google account with an email containing `vamsi`, `admin`, or `bhava`, or assigned `role: 'ADMIN'` in Firestore (`users/{uid}`) is automatically granted Full Admin Rights.
- **Admin Features**:
  - **Live Analytics KPIs**: Real-time total users, monetized table volume, total virtual coin pool, banned/suspended count, active tables.
  - **Player Management**: Search users by UID/email/name, credit or debit virtual coins with audited transaction reason, toggle account status (`ACTIVE`, `SUSPENDED`, `BANNED`).
  - **Game History & Audit Logs**: Inspect game round scores, penalties, and stream live admin action audit logs (`adminAuditLogs`).

---

## 🏗️ Architecture Overview

```
friendly-lavoisier/
├── apps/
│   └── mobile/                # Flutter Cross-Platform Web & Mobile App
│       ├── lib/
│       │   ├── core/          # App router (GoRouter), theme, config
│       │   └── features/      # Admin, Auth, Game (Single-player), Multiplayer, Profile, Rewards, Wallet
│       └── web/               # Web index.html, CSP security headers, manifest.json
├── packages/
│   ├── game-engine/           # Pure Dart 13-Card Indian Rummy Rules, State Machine & Validation Engine
│   └── ai-engine/             # Pure Dart Maya AI Opponent (Hand partitioner, threat tracker, action simulator)
├── functions/                 # Firebase Cloud Functions (Multiplayer table sync, turn timers, score settlement)
├── infrastructure/            # Docker containers for local Redis, Postgres & Game server
└── docs/                      # Master technical specifications & architecture diagrams
```

---

## 🤖 AI Models & Developer Reference Guide

If you are an AI coding model (Gemini, Claude, GPT, Antigravity) working on this codebase, **READ THIS FIRST**:

1. **Comprehensive Codebase Map**: Refer to [`KNOWLEDGE_BASE.md`](KNOWLEDGE_BASE.md). It contains line-by-line file maps, Firestore schemas, state provider trees, and known gotchas.
2. **Technical Specifications**: Detailed deep-dives are located under [`docs/specification/`](docs/specification/):
   - [`part1_core_architecture.md`](docs/specification/part1_core_architecture.md)
   - [`part2_game_engine.md`](docs/specification/part2_game_engine.md)
   - [`part3_ai_system.md`](docs/specification/part3_ai_system.md)
   - [`part4_backend_infrastructure.md`](docs/specification/part4_backend_infrastructure.md)
   - [`part5_frontend_security_ops.md`](docs/specification/part5_frontend_security_ops.md)
   - [`part6_roadmap_costs.md`](docs/specification/part6_roadmap_costs.md)
3. **Core Development Guidelines**:
   - **Game Engine Isolation**: `packages/game-engine` and `packages/ai-engine` MUST remain 100% pure Dart packages zero-dependent on Flutter UI or Firebase SDKs.
   - **Spectator Sync Scoping**: `SpectatorSyncService` is strictly scoped to local debug environments (`kDebugMode && !kIsWeb`) to prevent mixed active content security warnings on HTTPS.
   - **Verification**: Always run `cd packages/game-engine && dart test` and `cd apps/mobile && flutter analyze lib` before submitting PRs or deploying.

---

## 🛠️ Local Development & Deployment

### Local Engine Testing
```bash
# Run 13-Card Rummy Engine Tests
cd packages/game-engine
C:\Users\Bhava\flutter\bin\cache\dart-sdk\bin\dart.exe test

# Run AI Bot Engine Tests
cd packages/ai-engine
C:\Users\Bhava\flutter\bin\cache\dart-sdk\bin\dart.exe test
```

### Build & Deploy Flutter Web App
```bash
# Analyze Flutter Code
cd apps/mobile
C:\Users\Bhava\flutter\bin\flutter.bat analyze lib

# Build Production Web Release
C:\Users\Bhava\flutter\bin\flutter.bat build web --base-href /

# Deploy to Firebase Hosting
cmd /c "set PATH=C:\Program Files\nodejs;%PATH% && C:\Users\Bhava\AppData\Roaming\npm\firebase.cmd deploy --only hosting --project maya-rummy-vk"
```

---

## 📦 Syncing with GitHub (`maya-ai-rummy`)

To initialize, link, and push this codebase to your GitHub repository:

```bash
# 1. Initialize Git and add all files
git init
git add .
git commit -m "feat: complete Maya AI Rummy platform with user accounts, virtual wallet, rewards & admin dashboard"

# 2. Login to GitHub CLI (if not already authenticated)
gh auth login

# 3. Create the remote repository on GitHub
gh repo create maya-ai-rummy --public --source=. --remote=origin --push

# Or if you created the repo manually on GitHub web:
git remote add origin https://github.com/<your-username>/maya-ai-rummy.git
git branch -M main
git push -u origin main
```

---

## 📄 License

This repository is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
