# Maya AI Rummy — Knowledge Base for AI Agents

> **Purpose**: This document is a comprehensive codebase map designed to eliminate redundant
> research by AI agents. Before reading any source file, check this document first.
> Line numbers are accurate as of **2026-09-25**.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Environment & Build Commands](#2-environment--build-commands)
3. [Directory Structure](#3-directory-structure)
4. [Architecture & Data Flow](#4-architecture--data-flow)
5. [Routing & Navigation](#5-routing--navigation)
6. [File-by-File Reference Map](#6-file-by-file-reference-map)
7. [Game Engine Package](#7-game-engine-package)
8. [AI Engine Package](#8-ai-engine-package)
9. [Firebase Cloud Functions](#9-firebase-cloud-functions)
10. [Data Models](#10-data-models)
11. [State Management (Riverpod)](#11-state-management-riverpod)
12. [Multiplayer Game Flow](#12-multiplayer-game-flow)
13. [Single-Player (Maya Bot) Reference](#13-single-player-maya-bot-reference)
14. [Known Bug Patterns & Gotchas](#14-known-bug-patterns--gotchas)
15. [Test Suites](#15-test-suites)
16. [Configuration Files](#16-configuration-files)
17. [Firestore Data Schema](#17-firestore-data-schema)

---

## 1. Project Overview

**Maya AI Rummy** is a Flutter web app for 13-card Indian Rummy with:
- **Single-player** mode against "Maya" AI bot (offline, local state)
- **Multiplayer** mode via Firebase (Firestore real-time sync, Cloud Functions)
- **Game Engine** in pure Dart (card models, validation, scoring, hand partitioning)
- **AI Engine** in pure Dart (bot strategy, probability, threat tracking)

**Production URLs**: `https://mayarummy.cwards.com` and `https://maya-rummy-vk.web.app`
**Firebase Project**: `maya-rummy-vk`

---

## 2. Environment & Build Commands

| What | Command |
|------|---------|
| Flutter path | `C:\Users\Bhava\flutter\bin\flutter.bat` |
| Dart SDK | `C:\Users\Bhava\flutter\bin\cache\dart-sdk\bin\dart.exe` |
| Run game-engine tests | `cd packages/game-engine && dart test` |
| Run AI engine tests | `cd packages/ai-engine && dart test` |
| Flutter analyze | `cd apps/mobile && flutter analyze lib` |
| Flutter build web | `cd apps/mobile && flutter build web --base-href /` |
| Firebase deploy hosting | `$env:PATH = "C:\Program Files\nodejs;" + $env:PATH; cmd /c "npx firebase-tools deploy --only hosting --project maya-rummy-vk"` |
| Firebase deploy functions | `$env:PATH = "C:\Program Files\nodejs;" + $env:PATH; cmd /c "npx firebase-tools deploy --only functions --project maya-rummy-vk"` |
| Firebase deploy all | `$env:PATH = "C:\Program Files\nodejs;" + $env:PATH; cmd /c "npx firebase-tools deploy --project maya-rummy-vk"` |
| Cloud Functions test | `cd functions && node test/rules.test.js` |
| Local dev server | `cd apps/mobile && node serve.js` |
| Workspace root | `c:\Users\Bhava\Documents\antigravity\friendly-lavoisier` |

---

## 3. Directory Structure

```
friendly-lavoisier/
├── apps/
│   └── mobile/                          # Flutter web app (59 files, 21 dirs)
│       ├── lib/
│       │   ├── main.dart                # App entry point (31 lines)
│       │   ├── core/
│       │   │   ├── config/firebase_config.dart
│       │   │   ├── router/app_router.dart         # GoRouter (47 lines)
│       │   │   ├── theme/
│       │   │   │   ├── app_colors.dart             # Color constants (105 lines)
│       │   │   │   ├── app_text_styles.dart
│       │   │   │   └── app_theme.dart
│       │   │   └── utils/responsive.dart
│       │   └── features/
│       │       ├── auth/                           # Authentication
│       │       │   ├── models/multiplayer_user.dart
│       │       │   ├── providers/auth_provider.dart
│       │       │   └── services/auth_service.dart  # Google + Guest sign-in (195 lines)
│       │       ├── game/                           # Single-player (Maya Bot)
│       │       │   ├── models/
│       │       │   │   ├── card_group.dart
│       │       │   │   ├── game_settings.dart
│       │       │   │   └── round_score.dart
│       │       │   ├── providers/
│       │       │   │   ├── game_provider.dart       # ★ MAYA BOT REFERENCE (1,515 lines)
│       │       │   │   └── game_ui_provider.dart
│       │       │   ├── presentation/
│       │       │   │   ├── screens/game_table_screen.dart  (628 lines)
│       │       │   │   └── widgets/                        (16 widget files)
│       │       │   │       ├── card_widget.dart      # Card rendering (377 lines)
│       │       │   │       ├── center_table.dart     # Closed deck + open pile (243 lines)
│       │       │   │       ├── player_hand.dart      # Drag-and-drop hand
│       │       │   │       ├── opponent_panel.dart
│       │       │   │       ├── action_bar.dart
│       │       │   │       ├── score_card_modal.dart
│       │       │   │       └── ... (10 more)
│       │       │   └── services/spectator_sync_service.dart
│       │       ├── multiplayer/                     # ★ MULTIPLAYER (main feature)
│       │       │   ├── models/table_models.dart      # All data classes (485 lines)
│       │       │   ├── providers/multiplayer_providers.dart  # State + Notifiers (915 lines)
│       │       │   ├── services/multiplayer_service.dart     # Firestore CRUD (1,597 lines)
│       │       │   ├── presentation/screens/
│       │       │   │   ├── multiplayer_table_screen.dart     # Game table UI (1,431 lines)
│       │       │   │   ├── multiplayer_lobby_screen.dart     # Lobby/waiting room (406 lines)
│       │       │   │   ├── multiplayer_hub_screen.dart       # Create/Join hub
│       │       │   │   └── join_redirect_screen.dart         # Invite link handler
│       │       │   └── utils/
│       │       │       ├── game_log_exporter.dart
│       │       │       ├── file_saver_web.dart
│       │       │       └── file_saver_stub.dart
│       │       ├── home/                            # Home screen & settings
│       │       │   ├── presentation/screens/home_screen.dart
│       │       │   ├── presentation/widgets/ (11 files)
│       │       │   ├── providers/home_provider.dart
│       │       │   └── services/player_preferences_*.dart
│       │       └── rules/                           # Rule book modal
│       │           └── presentation/
│       ├── web/index.html
│       ├── pubspec.yaml
│       └── serve.js                     # Local dev server
├── packages/
│   ├── game-engine/                     # Pure Dart game logic (17 files)
│   │   ├── lib/
│   │   │   ├── game_engine.dart         # Barrel export
│   │   │   └── src/
│   │   │       ├── models/              # Card, Deck, GameState, Player, etc.
│   │   │       ├── rules/               # Validators, HandPartitioner, Scoring
│   │   │       └── engine/              # GameEngine, StateMachine
│   │   └── test/                        # 6 test files
│   └── ai-engine/                       # AI bot strategy
│       ├── lib/src/                     # Bot decision algorithms
│       └── test/                        # 2 test files
├── functions/                           # Firebase Cloud Functions
│   ├── index.js                         # 9 exported functions (765 lines)
│   ├── engine/rummyRules.js             # JS port of game rules (352 lines)
│   ├── test/rules.test.js
│   ├── package.json
│   └── package-lock.json
├── firebase.json                        # Firebase config
├── firestore.rules                      # Security rules (66 lines)
└── melos.yaml                           # Workspace orchestration
```

---

## 4. Architecture & Data Flow

### State Management Pattern
```
┌─────────────────────────────────────────────────────────┐
│                    Flutter UI Layer                       │
│  multiplayer_table_screen.dart ◄──── ref.watch(provider) │
│  multiplayer_lobby_screen.dart                            │
└──────────────────┬──────────────────────────────────────┘
                   │ ref.read(provider.notifier).action()
                   ▼
┌─────────────────────────────────────────────────────────┐
│              Riverpod Providers Layer                     │
│  MultiplayerGameNotifier ──── MultiplayerGameTableState  │
│  MultiplayerLobbyNotifier ── AsyncValue<TableLobby?>     │
│  AuthNotifier ─────────────── MultiplayerUser?           │
└──────────────────┬──────────────────────────────────────┘
                   │ _service.method()
                   ▼
┌─────────────────────────────────────────────────────────┐
│                  Service Layer                            │
│  MultiplayerService (singleton)                          │
│  ├── Cloud Functions (httpsCallable)                     │
│  ├── Firestore (direct reads/writes + transactions)      │
│  └── Local mock fallback (_mockGames, _mockTables)       │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│               Firebase Backend                            │
│  Firestore: /tables/{tableId}                            │
│             /games/{gameId}                               │
│             /games/{gameId}/privateHands/{uid}            │
│  Cloud Functions: createTable, joinTable, startGame,     │
│    drawFromClosed, drawFromOpen, discardCard,            │
│    declareGame, updatePresence, leaveTable               │
└─────────────────────────────────────────────────────────┘
```

### Dual Execution Path
The `MultiplayerService` has a **dual path** for every operation:
1. **Cloud Functions first** (via `_functions!.httpsCallable('functionName')`)
2. **Direct Firestore fallback** if Cloud Function fails (via `_firestore!.runTransaction(...)`)
3. **Local mock fallback** if Firebase not initialized (uses `_mockGames` / `_mockTables` maps)

### Card Encoding
- Cards use integer encoding: `deckIndex * 53 + suit.index * 13 + rank.index`
- 106 cards total: 2 decks × 52 suited cards + 2 printed jokers
- `Card.fromInt(val)` / `Card.toInt()` for serialization
- `Card.cardId` = `"${rankShort}${suitShort}-D${deckIndex}-${toInt()}"`
- Equality: based on `suit + rank + deckIndex + isPrintedJoker`

---

## 5. Routing & Navigation

**File**: `apps/mobile/lib/core/router/app_router.dart` (47 lines)

| Route | Screen | Purpose |
|-------|--------|---------|
| `/` | `HomeScreen` | Main menu |
| `/play-ai` | `GameTableScreen` | Single-player vs Maya Bot |
| `/multiplayer` | `MultiplayerHubScreen` | Create/Join table |
| `/lobby/:roomCode` | `MultiplayerLobbyScreen` | Waiting room with player slots |
| `/join/:roomCode` | `JoinRedirectScreen` | ★ Invite link handler (auto-auth + join) |
| `/table/:gameId` | `MultiplayerTableScreen` | Active game table |

**Critical**: `usePathUrlStrategy()` from `flutter_web_plugins` is **NOT called** in `main.dart`.
Flutter defaults to **hash URL strategy** (`/#/path`), so direct path URLs like
`https://mayarummy.cwards.com/lobby/MAYA1234` resolve to `/` (home) instead of the lobby.

**Invite links**: Generated in `multiplayer_lobby_screen.dart` L137-139 as `$origin/lobby/${roomCode}`,
but should use `/join/${roomCode}` to hit the `JoinRedirectScreen`.

---

## 6. File-by-File Reference Map

### 6.1 `multiplayer_service.dart` (1,597 lines) — ★ Core Backend Service

**File**: `apps/mobile/lib/features/multiplayer/services/multiplayer_service.dart`

| Method | Lines | What it does |
|--------|-------|-------------|
| `createTable(...)` | 28–105 | Creates lobby with room code, Firestore doc |
| `joinTable(...)` | 108–231 | Joins by room code, seats player |
| `leaveTable(tableId, uid)` | 234–270 | Removes player, handles host migration |
| `startGame(tableId)` | 273–460 | ★ Deals 13 cards, creates game doc + privateHands |
| `drawFromClosed(...)` | 465–605 | Draws from closed deck, sets DISCARD_PHASE |
| `drawFromOpen(...)` | 608–717 | Draws from open pile, tracks cardDrawnFromOpen |
| `discardCard(...)` | 720–865 | Discards to open pile, advances turn |
| `declareGame(...)` | 868–959 | Validates declaration, sets DECLARING status |
| `submitFinalHand(...)` | 962–1037 | Other players submit hands after declaration |
| `checkDeclarationTimeout(gameId)` | 1040–1057 | 30s deadline for final hand submissions |
| `_finalizeGameResults(game)` | 1059–1097 | Calculates final scores and winner |
| `recordPlayerHeartbeat(...)` | 1102–1144 | Updates heartbeat timestamp |
| `markPlayerDisconnected(...)` | 1147–1182 | Marks player as disconnected |
| `checkDisconnections(gameId)` | 1185–1373 | ★ Eliminates players disconnected >3min at 80pts |
| `forceAdvanceTurnOnTimeout(gameId)` | 1376–1501 | ★ Auto-advances turn on timeout |
| `watchTable(tableId)` | 1505–1519 | Returns Stream<TableLobby> |
| `watchGame(gameId, myUid)` | 1521–1587 | Returns Stream<MultiplayerGameState> (combines game + privateHand) |

### 6.2 `multiplayer_providers.dart` (915 lines) — ★ State Management

**File**: `apps/mobile/lib/features/multiplayer/providers/multiplayer_providers.dart`

**Providers defined**:
- `multiplayerServiceProvider` — `Provider<MultiplayerService>` [L11]
- `multiplayerLobbyProvider` — `StateNotifierProvider<MultiplayerLobbyNotifier, AsyncValue<TableLobby?>>` [L115]
- `multiplayerGameProvider` — `StateNotifierProvider<MultiplayerGameNotifier, MultiplayerGameTableState>` [L912]

**`MultiplayerGameTableState`** [L121–169]:
- Fields: `gameState`, `cardGroups`, `selectedCard`, `selectedCards`, `hasDrawnThisTurn`, `isSubmitting`, `isHandLocked`, `currentScore`, `statusMessage`

**`MultiplayerGameNotifier`** key methods [L171–910]:

| Method | Lines | Purpose |
|--------|-------|---------|
| `watchGame(gameId)` | 180–227 | Sets up Firestore stream, syncs local groups |
| `selectCard(card)` | 230–240 | Single-card exclusive selection (Maya Bot pattern) |
| `toggleCardSelection(card)` | 243–257 | Multi-select for grouping |
| `drawFromClosed()` | 264–296 | Draws card, creates DRAWN group, clears selection |
| `drawFromOpen()` | 299–331 | Draws from open pile |
| `discardSelectedCard()` | 334–374 | ★ Discards selectedCard (silently returns if null!) |
| `declareHand()` | 377–426 | Validates and declares |
| `submitFinalHand()` | 429–450 | Submits hand after opponent declares |
| `autoSortHand()` | 543–569 | Sorts by rank then suit |
| `autoGroupHand()` | 571–666 | ★ Uses HandPartitioner; only selects discard when allCards.length==14 |
| `handleTurnTimeout()` | 668–688 | ★ Client-side timeout: draw → autoGroup → discard |
| `forceAdvanceTurnOnTimeout()` | 710–714 | Delegates to service |
| `groupSelectedCards(cards)` | 716–757 | Creates new group from selected cards |
| `_syncGroupsWithHand(...)` | 759–809 | Syncs server hand with local card groups |
| `_revalidateGroups(...)` | 834–855 | Re-validates group types using validators |
| `_recalculateScore(...)` | 857–864 | Calculates deadwood score |

### 6.3 `multiplayer_table_screen.dart` (1,431 lines) — Game Table UI

**File**: `apps/mobile/lib/features/multiplayer/presentation/screens/multiplayer_table_screen.dart`

| Section | Lines | What it renders |
|---------|-------|----------------|
| `initState` + Timer | 29–77 | ★ 1-second periodic timer: timeout handling, heartbeat, disconnection checks |
| `didChangeAppLifecycleState` | 81–89 | App pause/resume → heartbeat/disconnect |
| `_showScoreboardModal` | 98–317 | Player scores, export button (locked during play) |
| `_showDeclarationDialog` | 319–376 | Confirmation dialog before declaring |
| `_showResultDialog` | 378–484 | Declaration result with score |
| `_buildDeclarationBanner` | 486–582 | "Player X has declared!" banner + submit button |
| Main `build` | 585–1265 | Full game table layout |
| Top Nav Bar | 664–795 | Back button, turn timer, scoreboard, table badge |
| Center Table (Decks) | 835–955 | Closed deck, wild joker, open pile |
| Opponents Orbit | 960–965 | Opponent avatars around table |
| Action Buttons | 1078–1232 | SORT, AUTO GROUP, GROUP, DISCARD, DECLARE |
| PlayerHand widget | 1241–1253 | Drag-and-drop card groups |
| `_buildOpponentsOrbit` | 1268–1429 | Dynamic 1-5 opponent seating layout |

**Timer logic (L38–77)** — Fires every 1 second:
- If `isMyTurn && now > turnDeadline`: calls `handleTurnTimeout()` (no debounce!)
- If `!isMyTurn && now > turnDeadline + 3s`: calls `forceAdvanceTurnOnTimeout()`
- Every 5 ticks: `recordHeartbeat()`
- Every 3 ticks: `checkDisconnections()`

### 6.4 `multiplayer_lobby_screen.dart` (406 lines)

**File**: `apps/mobile/lib/features/multiplayer/presentation/screens/multiplayer_lobby_screen.dart`

| Section | Lines | Purpose |
|---------|-------|---------|
| `_ensureJoined()` | 32–50 | Auto-join + auto guest-auth on direct URL visit |
| Room Code + Invite Link | 137–230 | Displays code, copy button, invite URL |
| Player Slots | 237–332 | 2-6 player slots with avatars |
| Host Start Button | 333–367 | "START GAME" (min 2 players) |
| Leave Table | 388–404 | Leave button |

**Invite link generated at L137-139**: `'$origin/lobby/${lobby.roomCode}'`

### 6.5 `join_redirect_screen.dart`

**File**: `apps/mobile/lib/features/multiplayer/presentation/screens/join_redirect_screen.dart`
- **Purpose**: Handles `/join/:roomCode` invite links
- Auto-authenticates as guest if not signed in [L38-40]
- Joins table and redirects to `/table/{gameId}` if game active, or `/lobby/{roomCode}` [L43-53]

### 6.6 `table_models.dart` (485 lines) — All Data Models

**File**: `apps/mobile/lib/features/multiplayer/models/table_models.dart`

| Class | Lines | Key Fields |
|-------|-------|-----------|
| `TablePlayer` | 3–98 | `uid`, `displayName`, `photoURL`, `seatIndex`, `isHost`, `connected`, `cardCount`, `score`, `status` (ACTIVE/DECLARED/WRONG_SHOW/DROPPED/ELIMINATED), `disconnectedAt`, `lastHeartbeat` |
| `TableLobby` | 100–213 | `tableId`, `roomCode`, `tableName`, `hostUid`, `maxPlayers`, `playerCount`, `status` (WAITING/STARTING/PLAYING/COMPLETED/ABANDONED), `hasPassword`, `activeGameId`, `players`, `gameMode`, `turnTimerSeconds`, penalties |
| `MultiplayerFinalResult` | 215–249 | `uid`, `displayName`, `score`, `isWinner` |
| `MultiplayerGameState` | 251–484 | `gameId`, `tableId`, `status` (IN_PROGRESS/DECLARING/COMPLETED), `currentTurnPlayerId`, `turnNumber`, `phase` (DRAW_PHASE/DISCARD_PHASE), `turnDeadline`, `openJoker`, `openPile`, `closedDeck`, `declaringPlayerId`, `declarationDeadline`, `submittedPlayerUids`, `finalResults`, `players`, `myHand`, `actionLog` |

**Getters on MultiplayerGameState** [L312-318]:
- `isDrawPhase`, `isDiscardPhase`, `isDeclaring`, `isGameOver`, `isCompleted`, `isMyTurn(uid)`

---

## 7. Game Engine Package

**Path**: `packages/game-engine/lib/src/`

### 7.1 Card Model (`models/card.dart`, 70 lines)

```dart
enum Suit { hearts, diamonds, clubs, spades }
enum Rank { ace, two, three, ... king }

class Card {
  final Suit? suit;          // null for printed jokers
  final Rank? rank;          // null for printed jokers
  final int deckIndex;       // 0 or 1 (two decks)
  final bool isPrintedJoker;

  int toInt()                // deckIndex * 53 + suit.index * 13 + rank.index
  static Card fromInt(int)   // Reverse of toInt()
  String get cardId          // e.g., "AH-D0-0"
}
```

### 7.2 Hand Partitioner (`rules/hand_partitioner.dart`, 526 lines) — ★ Core Algorithm

| Method | Lines | Purpose |
|--------|-------|---------|
| `evaluateGroups(groups, openJoker)` | 52–161 | Evaluates pre-formed groups, returns HandPartitionResult |
| `findValidPartition(hand, openJoker)` | 165–214 | Finds first valid declaration (2 sequences + all melds) |
| `findBestPartition(hand, openJoker)` | 220–372 | ★ Finds minimum-deadwood partition |
| `_findCandidateSequences(...)` | 447–472 | Generates sequence candidates (length 5→3, descending) |
| `_findCandidateSets(...)` | 474–491 | Generates set candidates (length 5→3, descending) |

**Key types**:
- `enum HandGroupType { pureSequence, impureSequence, validSet, invalid }`
- `class HandPartitionResult { groups, deadwoodScore, hasPureSequence, hasSecondSequence, isValidDeclaration }`

### 7.3 Validators

**`sequence_validator.dart`** (229 lines):
- `SequenceValidator.validate(cards, openJoker)` → `SequenceValidationResult` (pure/impure/invalid)
- Handles ace-low (A-2-3), ace-high (Q-K-A), wild joker substitution
- No wrap-around (K-A-2 is invalid)

**`set_validator.dart`** (108 lines):
- `SetValidator.validate(cards, openJoker)` → `SetValidationResult` (validPure/validImpure/invalid)
- 3-5 cards, same rank, different suits among natural cards
- Allows duplicate suits from different decks in impure sets (per test expectations)

**`declaration_validator.dart`** (55 lines):
- `DeclarationValidator.validate(groups, wildJoker)` → `ValidationResult`
- Requires: at least 1 pure sequence, at least 2 total sequences, all groups valid

### 7.4 Scoring (`rules/scoring.dart`, 111 lines)

- `Scoring.getCardValue(card, wildJoker)` — Face cards = 10, Ace = 10, others = face value, jokers = 0
- `Scoring.calculateDeadwood(deadwood, wildJoker, maxPenalty: 80)` — Sum capped at maxPenalty
- `Scoring.calculateHandDeadwood(groups:, wildJoker:, maxPenalty:)` — Evaluates grouped hand

### 7.5 Other Files

- `models/deck.dart` — `Deck.create()` returns 106-card List<Card>
- `models/game_state.dart` — Single-player game state
- `models/player.dart` — Single-player Player model with hand
- `models/game_action.dart` — Action types (DrawFromClosedDeck, DiscardCard, etc.)
- `models/game_config.dart` — Game configuration
- `models/game_result.dart` — Round result
- `engine/game_engine.dart` — `processAction(state, action)` → new GameState
- `engine/state_machine.dart` — Phase transitions
- `rules/joker_utils.dart` — `JokerUtils.isWildJoker(card, openJoker)`
- `rules/probability_engine.dart` — Card probability calculations

---

## 8. AI Engine Package

**Path**: `packages/ai-engine/lib/src/`

Contains Maya Bot's decision-making algorithms:
- Draw decision (open vs closed)
- Discard selection (minimize deadwood)
- Declaration decision (when to declare)
- Opponent threat tracking

---

## 9. Firebase Cloud Functions

**File**: `functions/index.js` (765 lines)

| Function | Lines | Purpose |
|----------|-------|---------|
| `createTable` | 29–84 | Creates table doc with unique room code |
| `joinTable` | 90–168 | Atomic room code lookup + seat assignment |
| `leaveTable` | 174–221 | Player exit, host reassignment, ABANDONED status |
| `startGame` | 232–360 | ★ Cryptographic shuffle, wild joker cut, 13-card deal to privateHands |
| `drawFromClosed` | 365–437 | Atomic draw + auto-reshuffle when deck empty |
| `drawFromOpen` | 442–507 | Atomic draw from discard pile top |
| `discardCard` | 512–599 | Validates open-drawn card rule, rotates turn |
| `declareGame` | 604–733 | Full rules validation, wrong show = 80pts |
| `updatePresence` | 738–764 | Heartbeat updates |

**Server-side rules engine**: `functions/engine/rummyRules.js` (352 lines) — 1:1 JavaScript port of Dart validators.

**No Cloud Functions exist for**: turn timeout, force-advance, disconnection elimination, tournament management. All handled client-side.

---

## 10. Data Models

### Firestore Collections

```
/tables/{tableId}        → TableLobby JSON
/games/{gameId}          → MultiplayerGameState JSON (public game state)
/games/{gameId}/privateHands/{uid}  → { cards: [int, int, ...] }
/users/{uid}             → User profile
```

### Key Status Enums

**Table Status**: `WAITING` → `STARTING` → `PLAYING` → `COMPLETED` | `ABANDONED`

**Game Status**: `IN_PROGRESS` → `DECLARING` → `COMPLETED`

**Game Phase**: `DRAW_PHASE` → `DISCARD_PHASE` → `DRAW_PHASE` (rotates)

**Player Status**: `ACTIVE` | `DECLARED` | `WRONG_SHOW` | `DROPPED` | `ELIMINATED`

---

## 11. State Management (Riverpod)

### All Providers

| Provider | Type | File | Line | State Type |
|----------|------|------|------|------------|
| `multiplayerServiceProvider` | `Provider` | multiplayer_providers.dart | L11 | `MultiplayerService` |
| `multiplayerLobbyProvider` | `StateNotifierProvider` | multiplayer_providers.dart | L115 | `AsyncValue<TableLobby?>` |
| `multiplayerGameProvider` | `StateNotifierProvider` | multiplayer_providers.dart | L912 | `MultiplayerGameTableState` |
| `authProvider` | `StateNotifierProvider` | auth_provider.dart | — | `MultiplayerUser?` |
| `gameTableProvider` | `StateNotifierProvider` | game_provider.dart | L1512 | `GameTableState` |
| `gameUIProvider` | `StateNotifierProvider` | game_ui_provider.dart | — | `GameUIState` |
| `homeProvider` | `StateNotifierProvider` | home_provider.dart | — | `HomeState` |

---

## 12. Multiplayer Game Flow

### Turn Lifecycle
```
DRAW_PHASE ──→ Player draws from closed/open deck
              (drawFromClosed/drawFromOpen in service)
              Hand goes from 13 → 14 cards
              Phase changes to DISCARD_PHASE
                    │
                    ▼
DISCARD_PHASE ──→ Player selects and discards 1 card
                 (discardCard in service)
                 Hand goes from 14 → 13 cards
                 currentTurnPlayerId advances to next player
                 Phase resets to DRAW_PHASE
```

### Declaration Flow
```
1. Player has 14 cards (just drew)
2. Selects 1 card to discard
3. Clicks DECLARE → declareGame() called
4. Service validates: discards card, checks 13 remaining cards
5. If valid: status → DECLARING, declarationDeadline set (30s)
6. Other players see banner, must submitFinalHand() within 30s
7. After all submit (or timeout): scores tallied, status → COMPLETED
```

### Timeout Flow (Current — Buggy)
```
My Turn:
  Timer fires every 1s
  If now > turnDeadline:
    handleTurnTimeout() called (NO DEBOUNCE!)
    → If DRAW_PHASE: drawFromClosed() → autoGroupHand() → discardSelectedCard()
    → If DISCARD_PHASE: autoGroupHand() → discardSelectedCard()
    ⚠ BUG: autoGroupHand() only selects card when allCards.length==14
    ⚠ BUG: discardSelectedCard() silently returns if selectedCard==null

Opponent's Turn:
  If now > turnDeadline + 3s:
    forceAdvanceTurnOnTimeout() called
    → If DRAW_PHASE: auto-draw to open pile, advance turn
    → If DISCARD_PHASE: just advance turn (NO discard from hand!)
```

### Disconnection Flow
```
Every 5s: recordHeartbeat() → updates lastHeartbeat in Firestore
Every 3s: checkDisconnections() →
  If player disconnected > 180s: ELIMINATED at 80pts
  If only 1 active player remains: auto-win, COMPLETED
```

---

## 13. Single-Player (Maya Bot) Reference

**File**: `apps/mobile/lib/features/game/providers/game_provider.dart` (1,515 lines)

This is the **authoritative reference** for correct game behavior. Key patterns:

| What | Maya Bot Pattern | Lines |
|------|-----------------|-------|
| Card selection | Exclusive single-select: tap = toggle | 195–203 |
| Can discard | `isDiscardPhase && isHumanTurn && selectedCard != null` | 145–152 |
| Discard flow | Select card → validate → `processAction(DiscardCard)` | 559–626 |
| Auto group | Works on any hand size, no `length==14` constraint | 1006–1012 |
| AI turn | Draw → decide discard → discard (atomic, no race conditions) | 1020–1175 |
| Tournament reset | `resetTournament()` resets scores and starts new game | 408–412 |
| Tournament check | Shows dialog when player hits elimination score | 577–620 (screen) |

**Center Table Widget** (`presentation/widgets/center_table.dart`, 243 lines):
- Open pile shows **up to 3 fanned cards** with diagonal offset [L164–241]
- Only top card is interactive (tappable for draw)
- Pattern: `Stack` with `Positioned` children, `xOffset = index * 8.0`, `yOffset = index * 6.0`

---

## 14. Known Bug Patterns & Gotchas

### ⚠ 15+ Cards Accumulation Bug
**Root cause chain**:
1. `Timer.periodic(1s)` in `multiplayer_table_screen.dart` L60-61 calls `handleTurnTimeout()` every second with **no debounce/lock**
2. `handleTurnTimeout()` calls `drawFromClosed()` which **clears selectedCard** via `clearSelectedCard: true`
3. `autoGroupHand()` only sets `selectedCard` when `allCards.length == 14` (rigid check at L577)
4. `discardSelectedCard()` silently returns at L335 when `selectedCard == null`
5. Net result: card drawn but never discarded → 15, 16, 17+ cards
6. `forceAdvanceTurnOnTimeout()` in DISCARD_PHASE does NOT discard from player's hand

### ⚠ Invite Link Redirect to Home
**Root cause**: Missing `usePathUrlStrategy()` in `main.dart`. Flutter defaults to hash URLs.
Invite links use path format (`/lobby/CODE`) which resolves to `/` without path URL strategy.
Also: invite links generated with `/lobby/` instead of `/join/` route.

### ⚠ Race Condition on Turn Timeout
When player's timer expires:
- Player's client calls `handleTurnTimeout()` (draws card, tries to discard)
- Opponent's client calls `forceAdvanceTurnOnTimeout()` 3s later (changes currentTurnPlayerId)
- Player's `discardCard()` fails with "Not your turn" because turn already advanced

### ⚠ copyWith selectedCards Bug (FIXED)
`MultiplayerGameTableState.copyWith` previously didn't clear `selectedCards` when `clearSelectedCard: true`.
Fixed: `selectedCards: clearSelectedCard ? const {} : (selectedCards ?? this.selectedCards)`

### ⚠ 5-Card Sets with 3 Wild Jokers (FIXED)
`HandPartitioner._findCandidateSets` only searched lengths 3-4, missing length 5.
Fixed: Loop changed to `for (int len = 5; len >= 3; len--)`.

---

## 15. Test Suites

| # | Path | Framework | Tests | Focus |
|---|------|-----------|-------|-------|
| 1 | `packages/game-engine/test/models/card_test.dart` | Dart | — | Card encoding 0-105 |
| 2 | `packages/game-engine/test/models/deck_test.dart` | Dart | — | 106-card deck |
| 3 | `packages/game-engine/test/rules/sequence_validator_test.dart` | Dart | — | Sequences |
| 4 | `packages/game-engine/test/rules/declaration_validator_test.dart` | Dart | — | Declarations |
| 5 | `packages/game-engine/test/rules/hand_partitioner_test.dart` | Dart | — | Partitioning |
| 6 | `packages/game-engine/test/engine/multiplayer_lifecycle_simulation_test.dart` | Dart | — | E2E lifecycle |
| 7 | `packages/ai-engine/test/ai_player_test.dart` | Dart | — | AI decisions |
| 8 | `packages/ai-engine/test/ai_regression_test.dart` | Dart | — | AI regression |
| 9 | `functions/test/rules.test.js` | Node.js | — | Server rules parity |

**Run all game-engine tests**: `cd packages/game-engine && dart test`
**Last known result**: 41/41 passed

---

## 16. Configuration Files

### `apps/mobile/pubspec.yaml`
- Flutter SDK: `>=3.0.0 <4.0.0`
- Key dependencies: `flutter_riverpod: ^2.4.9`, `go_router: ^13.1.0`, `firebase_core: ^3.12.0`, `firebase_auth: ^5.5.1`, `cloud_firestore: ^5.6.5`, `cloud_functions: ^5.3.3`, `google_sign_in: ^6.2.2`
- Local packages: `game_engine: path: ../../packages/game-engine`, `ai_engine: path: ../../packages/ai-engine`

### `firebase.json`
- Hosting: `public: apps/mobile/build/web`, rewrites `** → /index.html`
- Firestore: rules at `firestore.rules`, indexes at `firestore.indexes.json`
- Functions: source `functions/`, runtime `nodejs20`
- Emulators: auth (9099), functions (5001), firestore (8085), hosting (5000), UI (4000)

### `functions/package.json`
- Node `>=18`, `main: index.js`
- Dependencies: `firebase-admin: ^12.0.0`, `firebase-functions: ^5.0.0`

---

## 17. Firestore Data Schema

### `/tables/{tableId}`
```json
{
  "tableId": "string",
  "roomCode": "MAYA1234",
  "tableName": "string",
  "hostUid": "uid",
  "maxPlayers": 6,
  "playerCount": 2,
  "status": "WAITING|STARTING|PLAYING|COMPLETED|ABANDONED",
  "hasPassword": false,
  "activeGameId": "gameId|null",
  "gameMode": "Points Rummy|Pool 101|Pool 201|Best of 2 Deals",
  "turnTimerSeconds": 30,
  "firstDropPenalty": 20,
  "middleDropPenalty": 40,
  "maxPenalty": 80,
  "players": [
    {
      "uid": "string",
      "displayName": "string",
      "photoURL": "string",
      "seatIndex": 0,
      "isHost": true,
      "connected": true,
      "cardCount": 13,
      "score": 0,
      "status": "ACTIVE",
      "disconnectedAt": null,
      "lastHeartbeat": "ISO8601"
    }
  ]
}
```

### `/games/{gameId}`
```json
{
  "gameId": "string",
  "tableId": "string",
  "roomCode": "MAYA1234",
  "gameMode": "Points Rummy",
  "status": "IN_PROGRESS|DECLARING|COMPLETED",
  "playerCount": 2,
  "currentTurnPlayerId": "uid",
  "turnNumber": 1,
  "phase": "DRAW_PHASE|DISCARD_PHASE",
  "turnDeadline": "ISO8601",
  "openJoker": 42,
  "effectiveWildRank": "seven",
  "openPile": [12, 34, 56],
  "closedDeck": [1, 2, 3, ...],
  "closedDeckRemaining": 58,
  "dealerPlayerId": "uid",
  "cardDrawnFromOpenThisTurn": null,
  "winnerPlayerId": null,
  "declaringPlayerId": null,
  "declaringPlayerName": null,
  "declarationDeadline": null,
  "submittedPlayerUids": [],
  "finalResults": [],
  "players": [/* same as table players */],
  "actionLog": [
    { "seq": 1, "timestamp": "ISO8601", "type": "DRAW_CLOSED", "playerId": "uid", "description": "..." }
  ],
  "startedAt": "ISO8601",
  "endedAt": null
}
```

### `/games/{gameId}/privateHands/{uid}`
```json
{
  "cards": [12, 45, 78, ...]
}
```
**Security rule**: Only the owning player (`uid`) can read their own private hand.

---

## Quick Lookup Index

| I need to... | Look in... |
|-------------|-----------|
| Fix card rendering | `apps/mobile/lib/features/game/presentation/widgets/card_widget.dart` |
| Fix card grouping/partitioning | `packages/game-engine/lib/src/rules/hand_partitioner.dart` |
| Fix set/sequence validation | `packages/game-engine/lib/src/rules/set_validator.dart` or `sequence_validator.dart` |
| Fix declaration validation | `packages/game-engine/lib/src/rules/declaration_validator.dart` |
| Fix scoring | `packages/game-engine/lib/src/rules/scoring.dart` |
| Fix draw/discard/declare | `apps/mobile/lib/features/multiplayer/services/multiplayer_service.dart` |
| Fix turn timer/timeout | `multiplayer_table_screen.dart` L38-77 + `multiplayer_providers.dart` L668-714 + `multiplayer_service.dart` L1376-1501 |
| Fix multiplayer state bugs | `apps/mobile/lib/features/multiplayer/providers/multiplayer_providers.dart` |
| Fix routing/navigation | `apps/mobile/lib/core/router/app_router.dart` |
| Fix invite links | `app_router.dart` + `join_redirect_screen.dart` + `multiplayer_lobby_screen.dart` L137 |
| Fix auth/login | `apps/mobile/lib/features/auth/services/auth_service.dart` |
| Fix lobby/waiting room | `apps/mobile/lib/features/multiplayer/presentation/screens/multiplayer_lobby_screen.dart` |
| Fix game table UI layout | `apps/mobile/lib/features/multiplayer/presentation/screens/multiplayer_table_screen.dart` |
| Fix open pile display | `multiplayer_table_screen.dart` L910-953 (MP) or `center_table.dart` L164-241 (Bot ref) |
| Fix opponent display | `multiplayer_table_screen.dart` L1268-1429 |
| Fix colors/theme | `apps/mobile/lib/core/theme/app_colors.dart` |
| Fix Cloud Functions | `functions/index.js` |
| Fix server-side rules | `functions/engine/rummyRules.js` |
| Fix Firestore security | `firestore.rules` |
| See correct game behavior | `apps/mobile/lib/features/game/providers/game_provider.dart` (Maya Bot reference) |
| Fix AI bot behavior | `packages/ai-engine/lib/src/` |
| Add/run tests | `packages/game-engine/test/` or `functions/test/` |
| Deploy to production | See [Environment & Build Commands](#2-environment--build-commands) |
| Export game logs | `apps/mobile/lib/features/multiplayer/utils/game_log_exporter.dart` |
| Fix home screen | `apps/mobile/lib/features/home/presentation/` |
| Fix card animations | `apps/mobile/lib/features/game/presentation/widgets/card_animation_layer.dart` |
| Fix responsive layout | `apps/mobile/lib/core/utils/responsive.dart` |
| Fix Firebase config | `apps/mobile/lib/core/config/firebase_config.dart` |
| Fix player preferences | `apps/mobile/lib/features/home/services/player_preferences_service.dart` |

---

## 18. Widget Catalog

### Game Widgets (`features/game/presentation/widgets/`)

| Widget | File | Purpose |
|--------|------|---------|
| `ActionBar` | `action_bar.dart` | Bottom action controls: Sort, Auto-Group, Discard, Declare, Drop, Submit Show |
| `CardAnimationLayer` | `card_animation_layer.dart` | Animated card flights: dealing cascade, draw, discard |
| `CardBackWidget` | `card_back_widget.dart` | Face-down card with navy gradient and diamond pattern |
| `CardGroupWidget` | `card_group_widget.dart` | Meld group with color-coded badge, fanned cards, DragTarget |
| `CardWidget` | `card_widget.dart` | Face-up playing card with rank, suit, selection glow, Wild Joker badge (377 lines) |
| `CenterTable` | `center_table.dart` | Central felt: closed deck, wild joker, open pile fanned display (243 lines) |
| `DeclarationResultModal` | `declaration_result_modal.dart` | Valid/Invalid declaration diagnostics |
| `GameSettingsModal` | `game_settings_modal.dart` | Penalty settings (Drop, Full Count, Elimination Score) |
| `GameTableBackground` | `game_table_background.dart` | Full-screen navy gradient felt with spotlight |
| `GroupSuggestionsModal` | `group_suggestions_modal.dart` | AI meld suggestions with probability % |
| `OpponentPanel` | `opponent_panel.dart` | Maya Bot status bar with thinking indicator |
| `PlayerHand` | `player_hand.dart` | Scrollable row of CardGroupWidgets + New Group drop target |
| `ScoreBottomLeft` | `score_bottom_left.dart` | HUD: deadwood pts, tournament score, round badge |
| `ScoreCardModal` | `score_card_modal.dart` | Tournament history scorecard with round-by-round table |
| `ScorePanel` | `score_panel.dart` | Horizontal score strip: YOU / BOT / ROUND / TARGET |
| `TurnIndicator` | `turn_indicator.dart` | Contextual guidance: "YOUR TURN - DRAW", "MAYA THINKING" |

### Home Widgets (`features/home/presentation/widgets/`)

| Widget | File | Purpose |
|--------|------|---------|
| `DailyChallengeCard` | `daily_challenge_card.dart` | Daily mission card with progress bar |
| `DifficultySelector` | `difficulty_selector.dart` | EASY/MEDIUM/HARD selector |
| `GameModesSelector` | `game_modes_selector.dart` | 2x2 mode cards (Solo, Friends, Tournament, Pass & Play) |
| `HeroSection` | `hero_section.dart` | Animated header with 5-card fan |
| `HomeBottomNav` | `home_bottom_nav.dart` | Bottom nav: Home, Play, Rules, Rewards, Profile |
| `HomeTopBar` | `home_top_bar.dart` | Header: logo, coins, daily reward, rules, sound |
| `MayaAvatarWidget` | `maya_avatar_widget.dart` | Maya avatar orb with speech bubbles |
| `PlayWithMayaCTA` | `play_with_maya_cta.dart` | "PLAY WITH MAYA AI" animated CTA button |
| `PlayerProgressWidget` | `player_progress_widget.dart` | Level, XP bar, win rate |
| `ProfileModal` | `profile_modal.dart` | Full player career stats modal |
| `RewardsModal` | `rewards_modal.dart` | 7-day login streak + quest rewards |

---

## 19. All Enums

### Game Engine (`packages/game-engine/`)

| Enum | File | Values |
|------|------|--------|
| `Suit` | `models/card.dart:1` | `hearts, diamonds, clubs, spades` |
| `Rank` | `models/card.dart:2` | `ace, two, three, ... king` |
| `HandGroupType` | `rules/hand_partitioner.dart:6` | `pureSequence, impureSequence, validSet, invalid` |
| `SequenceType` | `rules/sequence_validator.dart:4` | `pure, impure` |
| `GamePhase` | `models/game_state.dart:5` | `WAITING, MATCHED, DEALING, PLAYER_TURN, DRAW_PHASE, DISCARD_PHASE, DECLARATION, VALIDATION, RESULT, SETTLEMENT, COMPLETE` |
| `GameMode` | `models/game_config.dart:1` | `POINTS, POOL_101, POOL_201, DEALS` |
| `PlayerStatus` | `models/player.dart:3` | `ACTIVE, DROPPED, DECLARED, DISCONNECTED` |
| `DropType` | `models/game_action.dart:35` | `FIRST_DROP, MIDDLE_DROP` |

### AI Engine (`packages/ai-engine/`)

| Enum | File | Values |
|------|------|--------|
| `AILevel` | `config/ai_config.dart:1` | `beginner, intermediate, advanced, expert` |
| `DrawChoice` | `simulation/action_simulator.dart:7` | `closedDeck, openPile` |
| `DrawDecision` | `ai_player.dart:9` | `closedDeck, openPile` |
| `ThreatLevel` | `analysis/opponent_threat_tracker.dart:3` | `low, medium, high, critical` |

### Flutter App (`apps/mobile/`)

| Enum | File | Values |
|------|------|--------|
| `CardGroupType` | `game/models/card_group.dart:4` | `pureSequence, impureSequence, set, deadwood` |
| `GameActionType` | `game/providers/game_ui_provider.dart:5` | `none, dealing, drewFromClosed, drewFromOpen, discarded, sorted, grouped, declared, botDrew, botDiscarded` |
| `AnimationPhase` | `game/providers/game_ui_provider.dart:19` | `idle, cardFlying, cardLanding, complete` |

---

## 20. Barrel Exports

### `packages/game-engine/lib/game_engine.dart`
```dart
export 'src/models/card.dart';
export 'src/models/deck.dart';
export 'src/models/player.dart';
export 'src/models/game_state.dart';
export 'src/models/game_action.dart';
export 'src/models/game_config.dart';
export 'src/models/game_result.dart';
export 'src/rules/declaration_validator.dart';
export 'src/rules/sequence_validator.dart';
export 'src/rules/set_validator.dart';
export 'src/rules/hand_partitioner.dart';
export 'src/rules/probability_engine.dart';
export 'src/rules/scoring.dart';
export 'src/rules/joker_utils.dart';
export 'src/engine/game_engine.dart';
export 'src/engine/state_machine.dart';
```

### `packages/ai-engine/lib/ai_engine.dart`
```dart
export 'src/observation.dart';
export 'src/hand_evaluator.dart';
export 'src/card_tracker.dart';
export 'src/opponent_model.dart';
export 'src/config/ai_config.dart';
export 'src/ai_player.dart';
export 'src/models/bot_knowledge_state.dart';
export 'src/analysis/hand_analyzer.dart';
export 'src/analysis/opponent_threat_tracker.dart';
export 'src/simulation/action_simulator.dart';
export 'src/strategy/bot_strategy_engine.dart';
```

---

## 21. Responsive Breakpoints

**File**: `apps/mobile/lib/core/utils/responsive.dart` (133 lines)

| Breakpoint | Width | Card Width | Card Height | Card Overlap |
|-----------|-------|-----------|------------|-------------|
| Mobile Portrait | <600px | 52px | 78px | 28px |
| Mobile Landscape | 600-900px | 60px | 90px | 32px |
| Tablet | 900-1200px | 68px | 102px | 36px |
| Desktop | ≥1200px | 72px | 108px | 36px |

---

## 22. User Accounts, Login Steps & Admin Dashboard Guide

### A. Account Types & Virtual Currency
- **Virtual Coins**: Strict virtual in-game economy. No real-money gambling, deposits, or withdrawals.
- **Account Registration**: Handled via Google Sign-In (`AuthService.signInWithGoogle()`).
- **Initial Grant**: 5,000 Free Virtual Coins upon completing profile (`createAccountWithProfile`).
- **Guest Access**: 0 coins, restricted to free AI tables (`signInAsGuest`).

### B. Admin Dashboard Access (`/admin`)
- **Route**: `https://mayarummy.cwards.com/#/admin`
- **Role Detection**:
  - `email.contains('vamsi')`, `email.contains('admin')`, or `email.contains('bhava')` -> Automatically sets `role = 'ADMIN'`.
  - Admin functions enforce `role == 'ADMIN'` in `users/{uid}`.
- **Admin Actions**:
  - `fetchKPIs()`: Aggregates real-time active users, coin circulation, monetized table stats.
  - `adminAdjustCoins()`: Credits or debits player coins with mandatory audit logging.
  - `adminSetAccountStatus()`: Suspends or bans abusive players.
  - `streamAuditLogs()`: Real-time stream of `adminAuditLogs` collection.

---

## 23. AI Prompting & Model Context Guide

When instructing future AI assistants on this repository, use these prompt context templates:

### Prompt 1: Modifying Game Rules & Declarations
> "Modify `packages/game-engine/lib/src/rules/declaration_validator.dart` to support standard 13-card Indian Rummy sequence checks. Ensure pure sequences contain no wild or printed jokers, and impure sequences validate wild joker substitution. Run `cd packages/game-engine && dart test` to verify."

### Prompt 2: Extending AI Bot Decision Logic
> "Update `packages/ai-engine/lib/src/strategy/bot_strategy_engine.dart` and `hand_partitioner.dart` to calculate deadwood point penalties. Ensure `HandPartitioner.findBestPartition()` is pure and deterministic. Run `cd packages/ai-engine && dart test` to verify."

### Prompt 3: Updating Admin Dashboard & LiveOps
> "Modify `apps/mobile/lib/features/admin/presentation/screens/admin_dashboard_screen.dart` and `admin_service.dart` to fetch realtime player stats from Firestore collection `users`. Ensure role check validates `role == 'ADMIN'`."

---

*Last updated: 2026-10-04. Maintained for AI Agents and Developers.*


