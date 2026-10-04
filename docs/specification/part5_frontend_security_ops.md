# PART 5: FRONTEND, SECURITY, ANTI-CHEAT & OPERATIONS

## 1. Flutter Application Architecture

The Indian Rummy client is built using Flutter (Dart) to maximize code reuse across mobile (iOS/Android), web, and desktop platforms while maintaining native-level 60fps+ performance during complex game animations.

### Core Stack & Libraries
- **State Management**: **Riverpod** (`flutter_riverpod`). Chosen over BLoC to eliminate boilerplate, simplify provider dependency graphs, and ensure robust compile-time safety. 
- **Navigation**: **GoRouter** (`go_router`). Declarative, URL-based routing that seamlessly supports web deep-linking and complex nested navigation (e.g., bottom navigation bars).
- **Networking**: **Dio** (`dio`) for REST APIs (auth, profile, leaderboards). **web_socket_channel** for low-latency game server communication.
- **Local Storage**: **Hive** (`hive_flutter`) for fast, synchronous NoSQL storage (game state recovery, caching). **SharedPreferences** for simple key-value pairs (auth tokens, theme preferences).
- **Monetization**: **Google Mobile Ads** (`google_mobile_ads`) for rewarded videos and banners.
- **Backend Services**: **Firebase Core** integrating Auth, Messaging (Push Notifications), Analytics, and Crashlytics.
- **Animations**: Flutter's native `AnimationController` for UI transitions. **Rive** (`rive`) for complex vector animations (win screens, avatars, level-ups).

### Dependency Injection (Riverpod)
Providers are structured in a feature-first pattern. Example of the Auth and WebSocket DI setup:

```dart
// API Client Provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.rummy.com/v1'));
  dio.interceptors.add(AuthInterceptor(ref));
  return dio;
});

// WebSocket Connection Manager
final gameSocketProvider = StateNotifierProvider<GameSocketNotifier, SocketState>((ref) {
  final token = ref.watch(authProvider).token;
  return GameSocketNotifier(token);
});

// Game State Repository
final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState>((ref) {
  final socket = ref.watch(gameSocketProvider.notifier);
  return GameStateNotifier(socket);
});
```

---

## 2. Screen Map

The application follows a strictly defined screen hierarchy. GoRouter configurations map directly to this tree.

```text
SplashScreen (Initialization, asset pre-loading, token check)
├── OnboardingScreen (First launch tutorial and language selection)
├── LoginScreen
│   ├── PhoneLoginScreen (OTP verification)
│   └── EmailLoginScreen (Fallback/Legacy)
└── HomeScreen (Main Dashboard, Bottom Nav)
    ├── GameModesSheet (ModalBottomSheet for game selection)
    │   ├── PracticeSetup (AI difficulty)
    │   ├── QuickGameSetup (Points/Deals/Pool selection)
    │   ├── MultiplayerSetup (Stakes and player count)
    │   ├── PrivateRoomCreate (Generate Room Code)
    │   └── PrivateRoomJoin (Enter Room Code)
    ├── MatchmakingScreen (Searching for opponents, countdown)
    ├── GameTableScreen (The Main Game Interface)
    │   ├── ChatOverlay (Quick messages, emojis)
    │   ├── EmoteOverlay (Animated sticker selection)
    │   └── SettingsOverlay (Sound, Table Theme, Leave Game)
    ├── GameResultScreen (Scorecard, Winner declaration, Rematch)
    ├── ProfileScreen (User stats, VIP status)
    │   ├── EditProfileScreen (Avatar, Username)
    │   ├── AchievementsScreen (Badges, Milestones)
    │   └── GameHistoryScreen (Past matches, Replays)
    ├── FriendsScreen (Social graph)
    │   ├── FriendRequestsScreen
    │   └── InviteFriendsScreen (Referral codes)
    ├── WalletScreen (Virtual coin balance, transaction history)
    ├── ShopScreen (In-App Purchases for coins, cosmetic themes)
    ├── LeaderboardScreen (Daily, Weekly, All-Time rankings)
    ├── RewardsScreen (Monetization & Engagement)
    │   ├── DailyRewardsSheet (Spin wheel / Login streak)
    │   └── MissionsScreen (Daily/Weekly tasks)
    ├── TournamentScreen (Scheduled multi-table tournaments)
    ├── SettingsScreen (Audio, Accessibility, Legal)
    ├── HelpScreen (Rules, FAQs, Support Chat)
    └── NotificationsScreen (Inbox for system messages)
```

---

## 3. Game Table UI Design

The `GameTableScreen` is the most complex UI component, requiring a high-performance custom `Stack` layout.

### Layout Details
- **Top Area (Opponents)**: Rendered as a row or arc. Each opponent widget displays:
  - Avatar (Circular with level badge).
  - Username (Truncated to 10 chars).
  - Card Count (Hidden cards, just a number badge).
  - Turn Timer Overlay (Circular progress indicator around the avatar).
  - Status Icons (Disconnected, Auto-play).
- **Center Area (The Table)**:
  - **Closed Deck**: Stack of face-down cards. Tap to draw.
  - **Open Pile**: Stack of face-up cards (only top card visible). Tap to draw, drag to discard.
  - **Wild Joker Indicator**: A dedicated slot displaying the randomly selected wild joker for the round.
- **Bottom Area (Player's Hand)**:
  - A scrollable or scaled horizontal list of 13-14 cards.
  - **Groups**: Cards are visually separated into groups (sequences/sets) with slight gaps.
  - **Selection State**: Selected cards are elevated (Y-offset).
- **Bottom Action Bar**:
  - `Sort`: Auto-arranges cards by suit and value.
  - `Group`: Combines selected cards into a custom group.
  - `Declare`: Initiates the win sequence (only active if requirements met).
  - `Drop`: Concedes the game (penalty points applied).
- **Side Overlays**:
  - Left edge: Chat bubble icon.
  - Right edge: Emotes icon, Hamburger menu (Settings/Leave).

### Card Interactions (Gestures)
- **Tap**: Toggle card selection (elevates card).
- **Drag & Drop**: Move a card within the hand to rearrange, or drag it into another group.
- **Double-Tap**: Auto-moves the card into the most logical group based on Rummy heuristics.
- **Long Press**: Shows a tooltip with the card's exact name and point value.
- **Swipe Up**: Instantly discards the currently selected card(s).
- **Drag to Center**: Drags a card from hand to the open pile to discard.

---

## 4. Animation System

Animations are crucial for game feel. All animations must run at 60fps and use Flutter's hardware-accelerated transforms.

| Animation | Type | Duration | Implementation Details |
|-----------|------|----------|------------------------|
| **Card dealing** | Staggered fly-in | 1.5s total | `AnimationController` triggering staggered `SlideTransition` + `ScaleTransition` from center deck to player hands. |
| **Card draw (closed)** | Slide + flip | 0.5s | `AnimatedBuilder` with `Transform(Matrix4.identity()..rotateY)`. |
| **Card draw (open)** | Slide to hand | 0.4s | `AnimatedPositioned` moving card from pile coordinates to hand slot. |
| **Card discard** | Slide to pile | 0.3s | `TweenAnimationBuilder` animating X/Y coordinates. |
| **Turn indicator** | Glow pulse | Loop (2s) | `AnimatedContainer` with altering `BoxShadow` spread and color. |
| **Timer bar** | Linear shrink | Turn duration (e.g., 30s) | `LinearProgressIndicator` bound to a descending `AnimationController`. Colors change green → yellow → red. |
| **Declaration** | Card fan-out + glow | 2s | Custom `CustomPainter` animation with expanding radii. |
| **Win celebration** | Particles + coins | 3s | Integrated `.riv` (Rive) file overlaid on the screen. |
| **Lose** | Subtle fade | 1s | `FadeTransition` with grayscale shader. |
| **Coin earn** | Float up + counter | 1.5s | Flying widget animation + `Countup` text animation. |
| **Level up** | Badge + particles | 2s | Rive animation triggered by state change in Provider. |
| **Joker highlight** | Pulse glow | Loop (1s) | `AnimatedOpacity` applied to a glowing border widget. |

> [!TIP] 
> **Reduced-Motion Mode**: The app reads system accessibility settings (`MediaQuery.of(context).disableAnimations`). If true, all `Duration` values drop to `Duration.zero` and Rive files switch to static frames.

---

## 5. Card Themes & Customization

The game supports cosmetic monetization through themes. The `ThemeEngine` operates on a robust data structure.

### Theme Configurations
1. **Default Theme**: Classic playing cards, green felt table.
2. **Royal Theme**: Deep red table, gold-bordered cards, velvet textures.
3. **Neon Theme**: Dark UI, glowing card edges, futuristic fonts.
4. **Minimal Theme**: Flat colors, highly legible sans-serif card values, clean white background.
5. **Festival Themes**: Dynamic (Diwali lamps, Holi colors) pushed via Firebase Remote Config.

### Implementation
Themes are defined using Flutter's `ThemeExtension` combined with custom asset manifests.

```dart
class TableTheme extends ThemeExtension<TableTheme> {
  final Color tableBackground;
  final String cardBackAsset;
  final String cardFaceAtlas; // Sprite sheet for performance
  final Color actionButtonColor;
  
  // constructor, copyWith, lerp...
}
```
Card rendering uses a `CustomPaint` or cached `Image` widgets mapped from a sprite atlas to minimize memory overhead (only 1 image loaded for all 52 faces).

---

## 6. Responsive Layout

The client must adapt flawlessly across devices using `LayoutBuilder` and `MediaQuery`.

### Breakpoints
- **Mobile Portrait (<600dp)**: 
  - Cards overlap heavily in a horizontal scroll view.
  - Opponents grouped at the top.
- **Mobile Landscape (600-900dp)**: 
  - *Primary competitive orientation.*
  - Cards spread out, utilizing screen width.
  - Opponents distributed on left/top/right edges.
- **Tablet (900-1200dp)**: 
  - Larger card touch targets (min 80x120).
  - Persistent chat panel on the right side.
- **Desktop/Web (>1200dp)**: 
  - Full immersive table.
  - Expanded sidebars for friends list, live leaderboards, and chat.

---

## 7. Accessibility (A11y)

Inclusion is mandatory for the Indian demographic.

- **Semantics**: Every actionable widget is wrapped in `Semantics`. Screen readers will announce "Tap to select Queen of Hearts", "Your turn, 15 seconds remaining".
- **Touch Targets**: Strictly enforced minimum of `48x48 dp` for all buttons. Card tap areas are artificially expanded beyond their visual boundaries.
- **High Contrast Mode**: Adds thick black strokes around cards and uses WCAG AAA compliant text colors.
- **Color-Blind Friendly**: Beyond red/black, suits use distinct high-contrast secondary patterns (e.g., striped fill for diamonds).
- **Haptics**: `HapticFeedback.lightImpact()` on card drag, `heavyImpact()` on discard/declare. Configurable in settings.

---

## 8. Internationalization (I18n)

Targeting a pan-Indian audience requires a robust localization pipeline.

- **Engine**: Flutter's `intl` package with ARB (Application Resource Bundle) files.
- **Supported Languages (Phase 1)**: English, Hindi (हिन्दी).
- **Architecture Ready For**: Telugu, Tamil, Kannada, Malayalam, Marathi, Bengali.
- **Formatters**: 
  - Custom number formatters for the Indian numbering system (e.g., 1,50,000 for 1.5 Lakhs instead of 150,000).
  - Context-aware pluralization for time (e.g., "2 seconds left", "1 hour ago").
- **String Rule**: Absolutely NO hardcoded user-facing strings in the UI layer. `Text(AppLocalizations.of(context)!.startGame)` only.

---

## 9. Sound Design

Audio is managed by a centralized `AudioController` utilizing the `audioplayers` package. All assets are pre-loaded during the `SplashScreen`.

| Sound Event | Trigger Condition | File Format | Pan/Volume Rules |
|-------------|-------------------|-------------|------------------|
| `card_draw` | Pulling card from closed deck | `.wav` | Center pan, normal vol |
| `card_place` | Discarding to open pile | `.wav` | Center pan, normal vol |
| `card_sort` | Pressing auto-sort button | `.wav` | Rapid sequential trigger |
| `turn_start` | Player's timer begins | `.wav` | Prominent notification |
| `timer_warning`| 10 seconds remaining | `.wav` | Pitch shifts up slightly |
| `timer_critical`| 5 seconds remaining | `.wav` | Heartbeat pulse effect |
| `joker_reveal` | Start of game joker flip | `.wav` | Magical chime effect |
| `declare_success`| Valid combination submitted | `.wav` | High-impact fanfare |
| `victory` | Player wins the match | `.mp3` | Replaces BGM |
| `defeat` | Opponent wins the match | `.mp3` | Downward glissando |
| `coin_earn` | Wallet balance increases | `.wav` | Cha-ching effect |
| `bg_music` | App is active in foreground | `.mp3` | Looped, volume at 30% |

**Independent Audio Channels**: 
The settings screen provides distinct sliders for: Master Volume, Background Music, Sound Effects (Cards), and Notifications (Chat/Turns).

---

## 10. Security Architecture

Security is built on a Zero-Trust, Server-Authoritative model. The client is treated as an inherently compromised environment.

### Transport Security
- **TLS 1.3 everywhere**: Strict enforcement on load balancers.
- **Certificate Pinning**: Implemented in Dio to prevent Man-in-the-Middle (MitM) proxies (e.g., Charles, Fiddler) from intercepting API calls on rooted devices.
- **WSS Protocol**: Game server communicates strictly over Secure WebSockets.

### Authentication Security
- **Identity Provider**: Firebase Auth handles the heavy lifting of OAuth (Google/Apple) and Phone SMS OTP verification.
- **Custom JWTs**: Firebase tokens are exchanged for our custom JWTs (`RS256` signed). 
  - Access Token: 1-hour expiry.
  - Refresh Token: 30-day expiry, stored in HTTP-only secure cookies (for web) and encrypted Hive box (for mobile).
- **Session Limits**: Maximum 3 concurrent active devices per user. Logging into a 4th revokes the oldest.

### API & Data Security
- **Request Signing**: Sensitive endpoints (like `/wallet/withdraw` or `/store/purchase`) require an HMAC-SHA256 signature combining the request payload, timestamp, and a client-side secret nonce.
- **Input Validation**: All incoming backend data is strictly parsed using **Zod** (TypeScript) schemas.
- **SQL Injection Prevention**: Prisma ORM with parameterized queries guarantees immunity to injection.
- **Encryption at Rest**: AWS RDS uses KMS encryption. Player PII is stored with column-level encryption.

### Game State Security (Server-Authoritative)
- **Blind Client State**: The server *never* sends the full game state to a client. A player's client only receives their own hand, the top open card, the wild joker, and the count of opponents' cards. The rest of the deck is maintained solely in the Dart game server's RAM.
- **Action Validation**: Every user action (draw, discard, declare) includes a `sequence_number`. The server rejects out-of-order packets.
- **State Machine Enforcement**: If a client sends a "discard" packet during another player's turn, the server drops it and flags the account for anomalous behavior.

---

## 11. Security Threat Model

| Threat | Impact | Likelihood | Mitigation Strategy |
|--------|--------|------------|---------------------|
| **Client Manipulation (Modded APK)** | Game integrity compromised, forced wins | Medium | Server-authoritative logic. The server dictates all outcomes. Modded APKs can only affect local UI rendering. |
| **API Abuse / DDoS** | Service unavailability, server crash | High | AWS WAF rate limiting (e.g., max 100 req/min per IP), CloudFront edge caching, Shield Advanced. |
| **Account Takeover** | User data and virtual currency theft | Medium | Firebase Phone OTP (MFA), anomaly detection on IP/Device changes. |
| **Bot Farming** | Economy inflation, ruined matchmaking | High | Device fingerprinting, behavioral heuristics (predictable timing), CAPTCHA on suspicious registration. |
| **Cheating (Map Hack / Seeing Cards)** | Complete loss of game fairness | Low | **Absolute data denial**. The server simply does not transmit opponent hands or deck order to the client. |
| **Collusion (Team Play)** | Unfair advantage against innocent players | Medium | Graph analysis of matchmaking, preventing friends from joining the same public table. |
| **WebSocket Hijacking** | Injection of false moves | Low | Tokens passed in WSS handshake, connection bound to initial IP, strict sequence numbering. |
| **Replay Attacks** | Duplicate API actions (e.g., claiming rewards twice) | Medium | Idempotency keys required for state-mutating API calls. |

---

## 12. Anti-Cheat & Collusion Detection

Because pure technical hacks (like card reveals) are prevented by the server-authoritative architecture, **Collusion** (players teaming up at a table) and **Botting** are the primary threats.

### Server-Side Heuristics
The Game Server evaluates every action for:
- **Impossible Actions**: E.g., dropping a card the player doesn't have. Automatically drops the WebSocket connection and applies a strike.
- **Inhuman Speed**: Actions occurring consistently under 200ms indicate macro/bot usage.

### Collusion Detection Engine (Graph Analysis)
The backend runs asynchronous jobs over game logs to build a **Player Interaction Graph**.
1. **Frequency Checks**: Alerts if Player A and Player B end up in the same public matchmaking room > 3 times in 24 hours.
2. **Discard Synergies**: Tracks if Player A frequently discards high-value cards that Player B immediately picks up.
3. **Shared Infrastructure**: Flags players sharing identical IP addresses, device IDs, or GPS coordinates in the same match.

### Automated Risk Engine
Every player maintains a hidden `RiskScore` (0-100).
- `Base Score`: 0.
- `+10`: IP match with opponent.
- `+20`: Anomalous win rate (>75% over 50 games).
- `+15`: Suspicious discard synergy.
- `+50`: Impossible action packet detected.

**Graduated Enforcement:**
- **Score 0-30**: Normal player.
- **Score 31-60**: Shadow-pooled. Matchmaking algorithm silently pairs them only with other high-risk players.
- **Score 61-89**: Suspended. 24-hour temporary ban pending review.
- **Score 90+**: **Manual Review Required**. 

> [!WARNING]  
> **AI Ban Policy**: The system must NEVER permanently ban an account based solely on ML/Heuristic models. Permanent bans, especially reduction of wallets, require human CS confirmation.

---

## 13. Observability & Monitoring

High availability requires deep visibility into the distributed system.

### Logging (Structured JSON)
All Node.js and Dart server logs are emitted in JSON format for parsing.
- **Fields**: `timestamp`, `level`, `service`, `trace_id`, `user_id`, `game_id`, `message`, `metadata`.
- **Pipeline**: Application StdOut → FluentBit (DaemonSet) → AWS CloudWatch Logs → OpenSearch (for searching/dashboards).

### Metrics & Dashboards (Grafana + Prometheus)
Key metrics tracked in real-time:
- **Game Server**: Active concurrent games, tick rate latency, WSS message throughput.
- **Matchmaking**: Time-in-queue (p50, p90, p99), queue abandonment rate.
- **API**: HTTP error rates (4xx, 5xx), response times.
- **Infrastructure**: ECS CPU/Memory utilization, Redis hit rate, Postgres connection pool saturation.

### Tracing
**AWS X-Ray** is utilized to trace requests. A `trace_id` is generated at the API Gateway and propagated via headers through Node.js APIs down to the Postgres queries, allowing developers to identify exact latency bottlenecks.

### Alerting (PagerDuty Integration)
- **P1 (Critical)**: Game Server fleet CPU > 85%, DB connections maxed, WSS error rate > 5%. Pages the on-call engineer 24/7.
- **P2 (High)**: Matchmaking wait times > 30s, API 500 error rate > 1%. Pages on-call during business hours.
- **P3 (Warning)**: Node memory creeping, minor anomaly in player registrations. Creates Jira ticket.

---

## 14. Analytics Architecture

Data drives monetization and retention tuning. 

### Event Pipeline Architecture
```text
Mobile Client (Flutter) 
  │
  ├── Firebase Analytics (Core KPIs)
  │
  └── Custom Events (Dio HTTP POST)
        │
        ▼
    API Gateway
        │
        ▼
    AWS SQS (Buffer Queue) ─► Node.js Worker ─► Mixpanel (Product Analytics)
        │
        ▼
    AWS Kinesis Firehose
        │
        ▼
    AWS S3 (Data Lake, Parquet Format)
        │
        ▼
    AWS Athena (SQL Data Science Queries) & QuickSight (Exec Dashboards)
```

### Core KPIs Tracked
- **Acquisition**: CPA, Install-to-Registration conversion, Source attribution.
- **Activation**: Tutorial completion rate, % of users playing 1st multiplayer game within 1 hour.
- **Engagement**: DAU/MAU ratio, Average games per session, Session length.
- **Economy**: Faucet claim rates, daily coin sink (rake) vs coin source (rewards).
- **Game Health**: Average game duration (target: 3-5 mins), Drop rate on Turn 1, Invalid declaration rate.

---

## 15. Testing Strategy

A rigorous CI/CD testing pipeline implemented via **GitHub Actions**. Code cannot merge to `main` without passing all gates.

### 1. Unit Tests
- **Game Engine (Dart)**: **100% Code Coverage Required.** 
  - Exhaustive testing of the `RummyRules` class.
  - Tests for every possible valid and invalid sequence/set combination.
  - Tests for edge cases: double jokers, all cards of same suit, maximum point calculation (capped at 80).
- **Backend (Jest)**: Testing controllers, JWT issuance, database mock interactions.

### 2. Integration Tests
- API endpoints are tested against an ephemeral Postgres database container.
- **WebSocket Protocol Tests**: Automated scripts connect to the WSS endpoint, mimic standard player payloads, and assert the server's state transitions.

### 3. Game Simulation Tests (Monte Carlo)
A headless runner plays **100,000 simulated games** every night using varying AI difficulty profiles against each other. 
- *Pass Condition*: Zero server crashes, zero invalid state exceptions, zero deadlocks (infinite loops).
- *Metrics Extracted*: AI win rates, average turns to win, statistical distribution of points.

### 4. Load & Stress Tests
Executed via **k6**.
- **Baseline Test**: 1,000 concurrent active WebSocket connections playing random legal moves.
- **Stress Test**: 10,000 concurrent games (~40,000 players).
- **Assertion**: Server tick latency must remain under 100ms. Disconnect rate must be < 0.1%.

### 5. Client E2E (Patrol/Integration_Test)
Automated UI tests run on Firebase Test Lab (real Android/iOS devices).
- Script flows: Launch app → Login via mock OTP → Complete Tutorial → Enter Practice Match → Play 3 turns → Disconnect.

---

## 16. Customer Support Tools (Admin Panel)

Built with Next.js and React, sitting behind strict VPN and SSO access.

### Core Capabilities
- **User 360 View**: Search by ID/Phone/Email. View hardware IDs, IP history, registration date.
- **Game Replay Tool**: Step-by-step visual playback of any logged game to review cheating accusations.
- **Wallet Audit**: Immutable ledger view of every single coin credited or debited to the user.
- **Moderation Actions**: 
  - Issue temporary bans (1h, 24h, 7d).
  - Mute user in chat.
  - Force disconnect from current game.
- **Compensation Tool**: Ability to manually grant Virtual Coins. 
  - *Security*: Requires a mandatory note, logs the Admin ID, and alerts management if granted amount exceeds threshold.

---

## 17. Feature Flags

To support continuous deployment and A/B testing, features are toggled via a centralized configuration.

```typescript
// Shared definition
interface GlobalFeatureFlags {
  FEATURE_TOURNAMENTS: boolean;       // Enable scheduled tournament UI
  FEATURE_SPECTATOR_MODE: boolean;    // Allow users to watch friends
  FEATURE_POOL_RUMMY: boolean;        // Enable 101/201 Pool mode
  FEATURE_DEALS_RUMMY: boolean;       // Enable Best-of-X Deals mode
  FEATURE_REWARDED_ADS: boolean;      // Toggle AdMob integration
  MAX_CONCURRENT_GAMES: number;       // Load shedding throttle
  MAINTENANCE_MODE: boolean;          // Boot all players and lock logins
  FEATURE_REAL_MONEY: boolean;        // STRICTLY FALSE in V1.
}
```
Flags are stored in Postgres, cached in Redis, and pushed to clients upon login.

---

## 18. Future Real-Money Architecture (RMG)

While V1 is purely Virtual Coins (Freemium/Ads), the architecture is preemptively designed to support Real-Money Gaming (RMG) pending legal clearance in specific Indian states (e.g., barring Telangana, Andhra Pradesh, Assam, etc.).

### Isolation & Interfaces
The economy system is abstracted behind Provider interfaces so the implementation can be swapped without rewriting the Game Engine.

```typescript
interface WalletProvider {
  getBalance(userId: string): Promise<Balance>;
  holdFunds(userId: string, amount: number, matchId: string): Promise<HoldResult>;
  settleMatch(matchId: string, winners: WinnerMap): Promise<SettleResult>;
}

interface ComplianceProvider {
  // Verifies against IP geolocation and provided Aadhaar/KYC details
  checkJurisdiction(userId: string, ipAddress: string): Promise<JurisdictionResult>;
  verifyAge(userId: string): Promise<AgeVerification>;
}

interface ResponsibleGamingProvider {
  checkDepositLimits(userId: string): Promise<LimitCheck>;
  checkSelfExclusion(userId: string): Promise<boolean>;
}
```

### Critical Legal & Tech Boundaries
1. **One-Way Virtual Currency**: Virtual coins earned in V1 can **never** be converted to Real Money. They remain entirely separate database tables (`virtual_wallet` vs `rmg_wallet`).
2. **KYC & TDS (Tax)**: The RMG module will require integration with third-party Indian KYC providers (e.g., Digilocker/Pan verification) and automated TDS (Tax Deducted at Source) deduction on net winnings above INR 10,000.
3. **Payment Gateways**: Integration with Razorpay/Cashfree for UPI and NetBanking deposits.
4. **State-Level Geofencing**: Strict IP and GPS-based blocking for states where real-money rummy is restricted. App startup must verify location before showing the RMG lobby.
