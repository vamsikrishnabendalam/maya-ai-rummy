# PART 4: BACKEND SERVICES, DATABASE, APIs & INFRASTRUCTURE

## 1. Backend Architecture Overview

The backend system is designed for high availability, strong consistency in ledgers, and low-latency game state synchronization. We adopt a **Modular Monolith** architecture for the API services paired with a **Dedicated Game Server** for real-time play.

- **API Services (Modular Monolith):** Built using **Node.js with TypeScript** and Express/NestJS. This handles all out-of-game logic: user profiles, matchmaking, wallet ledgers, social features, and rewards. It scales horizontally via AWS ECS (Fargate).
- **Game Server (Real-time):** Built using **Dart (Standalone)** to maximize code reuse with the Flutter client. It hosts the in-memory game state and handles WebSocket communication via `dart:io`.
- **API Gateway / Application Load Balancer (ALB):** Routes HTTP traffic to the Node.js API and WebSocket traffic (`/game-ws`) to the Dart Game Server fleet.
- **State & Persistence:** 
  - **PostgreSQL (AWS RDS)** is the primary source of truth, enforcing ACID compliance for wallet transactions and user data.
  - **Redis (AWS ElastiCache)** acts as a real-time state store (matchmaking queues, online presence, active game instances, leaderboards).
  - **AWS SQS** provides asynchronous event decoupling between the game servers and the API services (e.g., game end events triggering wallet updates).

---

## 2. API Server Modules

Each module represents a logical boundary within the Node.js monolithic API server.

### Auth Module
- **Purpose:** Handles authentication via Firebase Auth and exchanges Firebase tokens for custom application JWTs.
- **Dependencies:** Firebase Admin SDK, PostgreSQL (`users` table), Redis (session caching).
- **Endpoints:**
  - `POST /api/v1/auth/login` (Body: `{ firebaseToken }`, Returns: `{ jwt, refreshToken, user }`)
  - `POST /api/v1/auth/refresh`
  - `POST /api/v1/auth/link-account` (Upgrades guest account)
  - `POST /api/v1/auth/logout`

### User/Profile Module
- **Purpose:** Manages user identity, profile customization, and statistics.
- **Dependencies:** S3 (Avatar uploads), PostgreSQL (`users`, `user_settings`).
- **Endpoints:**
  - `GET /api/v1/users/me`
  - `PATCH /api/v1/users/me`
  - `GET /api/v1/users/:id/profile`
  - `POST /api/v1/users/me/avatar`
  - `GET /api/v1/users/me/stats`

### Wallet Module
- **Purpose:** Manages player balances. Implements a server-side ledger using a **double-entry bookkeeping** pattern to ensure complete auditability and prevent race conditions.
- **Dependencies:** PostgreSQL (`wallets`, `wallet_transactions`).
- **Endpoints:**
  - `GET /api/v1/wallet/balance`
  - `GET /api/v1/wallet/transactions?page=1&limit=20`
  - `POST /api/v1/wallet/credit` *(Internal/Admin only)*
  - `POST /api/v1/wallet/debit` *(Internal/Admin only)*

### Matchmaking Module
- **Purpose:** Groups players into tables based on game mode, table size, skill (MMR), and connection quality.
- **Dependencies:** Redis (Sorted Sets for queues).
- **Algorithm:** 
  1. Player joins a queue (e.g., `matchmaking:point_rummy:100`).
  2. Redis Sorted Set stores player with score = entry timestamp.
  3. A cron/worker scans the queue every 2 seconds. Groups players with similar MMR.
  4. If a lobby isn't filled within 30 seconds, expands the MMR search radius. After 45 seconds, injects AI bots to guarantee a match.
- **Endpoints:**
  - `POST /api/v1/matchmaking/join` (Body: `{ mode: 'points', tableSize: 6, entryFee: 100 }`)
  - `DELETE /api/v1/matchmaking/cancel`
  - `GET /api/v1/matchmaking/status`

### Game Module
- **Purpose:** Manages game metadata, history, and private room instantiation.
- **Dependencies:** PostgreSQL (`games`, `game_players`, `game_replays`), S3.
- **Endpoints:**
  - `GET /api/v1/games/:id`
  - `GET /api/v1/games/:id/replay` (Returns signed S3 URL for replay JSON)
  - `GET /api/v1/games/history?page=1&limit=20`
  - `POST /api/v1/games/private-room`
  - `POST /api/v1/games/private-room/:code/join`

### Social Module
- **Purpose:** Manages friends, presence, and moderation.
- **Dependencies:** PostgreSQL (`friendships`, `reports`), Redis (online status).
- **Endpoints:**
  - `GET /api/v1/friends`
  - `POST /api/v1/friends/request`
  - `POST /api/v1/friends/accept/:id`
  - `DELETE /api/v1/friends/:id`
  - `POST /api/v1/friends/block/:id`
  - `GET /api/v1/friends/online`
  - `POST /api/v1/reports`

### Reward Module
- **Purpose:** Distributes daily login bonuses, mission rewards, and achievements.
- **Dependencies:** PostgreSQL, Wallet Module (Internal API).
- **Endpoints:**
  - `GET /api/v1/rewards/daily`
  - `POST /api/v1/rewards/daily/claim`
  - `GET /api/v1/rewards/missions`
  - `POST /api/v1/rewards/missions/:id/claim`
  - `GET /api/v1/rewards/achievements`

### Leaderboard Module
- **Purpose:** Real-time ranking of players globally and among friends.
- **Dependencies:** Redis (Sorted Sets), PostgreSQL (Archived snapshots).
- **Endpoints:**
  - `GET /api/v1/leaderboard?type=daily&scope=global&page=1`
  - `GET /api/v1/leaderboard/friends`
  - `GET /api/v1/leaderboard/me`

### Ad Module
- **Purpose:** Tracks ad impressions and issues rewards via server-to-server callbacks to prevent client-side spoofing.
- **Endpoints:**
  - `POST /api/v1/ads/rewarded/request`
  - `POST /api/v1/ads/rewarded/complete` (Server-to-server webhook from AdMob/Mediation)

### Notification Module
- **Purpose:** Manages device tokens and push notification preferences.
- **Dependencies:** Firebase Cloud Messaging (FCM).
- **Endpoints:**
  - `POST /api/v1/notifications/register-device`
  - `GET /api/v1/notifications/preferences`
  - `PATCH /api/v1/notifications/preferences`

---

## 3. Complete Database Schema

The primary database is **PostgreSQL**.

```sql
-- Core User Tables
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid VARCHAR(128) UNIQUE,
  username VARCHAR(30) UNIQUE,
  display_name VARCHAR(50),
  avatar_url TEXT,
  avatar_frame_id VARCHAR(50),
  level INTEGER DEFAULT 1,
  xp INTEGER DEFAULT 0,
  mmr INTEGER DEFAULT 1000,
  status VARCHAR(20) DEFAULT 'active', -- 'active', 'banned', 'suspended'
  language VARCHAR(10) DEFAULT 'en',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_login_at TIMESTAMPTZ
);
CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);
CREATE INDEX idx_users_username ON users(username);

CREATE TABLE user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  device_id VARCHAR(100),
  fcm_token TEXT,
  platform VARCHAR(20), -- 'ios', 'android', 'web'
  os_version VARCHAR(30),
  app_version VARCHAR(30),
  last_used_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, device_id)
);

CREATE TABLE user_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  sound_enabled BOOLEAN DEFAULT TRUE,
  vibration_enabled BOOLEAN DEFAULT TRUE,
  chat_enabled BOOLEAN DEFAULT TRUE,
  friend_requests_enabled BOOLEAN DEFAULT TRUE,
  push_notifications_enabled BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Wallet & Ledger System
CREATE TABLE wallets (
  user_id UUID PRIMARY KEY REFERENCES users(id),
  coins BIGINT DEFAULT 0 CHECK (coins >= 0),
  gems BIGINT DEFAULT 0 CHECK (gems >= 0),
  tickets INTEGER DEFAULT 0 CHECK (tickets >= 0),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  version INTEGER DEFAULT 1 -- For optimistic locking
);

CREATE TABLE wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  currency VARCHAR(10), -- 'coins', 'gems', 'tickets'
  type VARCHAR(30),     -- 'game_entry', 'game_win', 'daily_reward', 'ad_reward', 'purchase', 'admin'
  amount BIGINT,        -- positive = credit, negative = debit
  balance_after BIGINT,
  reference_type VARCHAR(30), -- 'game', 'ad', 'reward'
  reference_id VARCHAR(100),  -- e.g., game_id
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_wallet_tx_user ON wallet_transactions(user_id, created_at DESC);
CREATE INDEX idx_wallet_tx_ref ON wallet_transactions(reference_type, reference_id);

-- Social Tables
CREATE TABLE friend_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID REFERENCES users(id),
  receiver_id UUID REFERENCES users(id),
  status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'accepted', 'rejected'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(sender_id, receiver_id)
);

CREATE TABLE friendships (
  user_id UUID REFERENCES users(id),
  friend_id UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, friend_id)
);

CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES users(id),
  reported_id UUID REFERENCES users(id),
  game_id UUID, -- Optional, if reported in-game
  reason VARCHAR(50), -- 'cheating', 'abusive_chat', 'stalling', 'inappropriate_name'
  details TEXT,
  status VARCHAR(20) DEFAULT 'open', -- 'open', 'investigating', 'resolved', 'dismissed'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Game Metadata Tables
CREATE TABLE games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mode VARCHAR(30), -- 'points', 'pool_101', 'pool_201', 'deals'
  table_size INTEGER,
  entry_fee BIGINT,
  prize_pool BIGINT,
  status VARCHAR(20), -- 'created', 'running', 'completed', 'aborted'
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  server_ip VARCHAR(50)
);

CREATE TABLE game_players (
  game_id UUID REFERENCES games(id),
  user_id UUID REFERENCES users(id),
  seat_number INTEGER,
  score INTEGER DEFAULT 0,
  winnings BIGINT DEFAULT 0,
  placement INTEGER,
  is_bot BOOLEAN DEFAULT FALSE,
  PRIMARY KEY (game_id, user_id)
);

CREATE TABLE game_replays (
  game_id UUID PRIMARY KEY REFERENCES games(id),
  s3_bucket VARCHAR(50),
  s3_key VARCHAR(255),
  file_size INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Rewards & Progression
CREATE TABLE daily_rewards (
  user_id UUID PRIMARY KEY REFERENCES users(id),
  current_streak INTEGER DEFAULT 0,
  last_claim_date DATE,
  next_reward_tier INTEGER DEFAULT 1
);

CREATE TABLE missions (
  id VARCHAR(50) PRIMARY KEY,
  type VARCHAR(30), -- 'daily', 'weekly', 'lifetime'
  description TEXT,
  target_value INTEGER,
  reward_type VARCHAR(20), -- 'coins', 'gems'
  reward_amount INTEGER,
  is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE user_missions (
  user_id UUID REFERENCES users(id),
  mission_id VARCHAR(50) REFERENCES missions(id),
  progress INTEGER DEFAULT 0,
  status VARCHAR(20) DEFAULT 'in_progress', -- 'in_progress', 'completed', 'claimed'
  completed_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, mission_id)
);

CREATE TABLE achievements (
  id VARCHAR(50) PRIMARY KEY,
  category VARCHAR(30), -- 'gameplay', 'social', 'collection'
  name VARCHAR(100),
  description TEXT,
  icon_url TEXT,
  points INTEGER
);

CREATE TABLE user_achievements (
  user_id UUID REFERENCES users(id),
  achievement_id VARCHAR(50) REFERENCES achievements(id),
  unlocked_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, achievement_id)
);

-- Infrastructure & Admin
CREATE TABLE leaderboard_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type VARCHAR(30), -- 'daily_winnings', 'weekly_xp'
  period_start TIMESTAMPTZ,
  period_end TIMESTAMPTZ,
  data JSONB, -- Array of top 100 users
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE feature_flags (
  key VARCHAR(50) PRIMARY KEY,
  is_enabled BOOLEAN DEFAULT FALSE,
  percentage INTEGER DEFAULT 100,
  rules JSONB
);

CREATE TABLE admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(100) UNIQUE,
  password_hash TEXT,
  role VARCHAR(30), -- 'super_admin', 'support', 'fraud'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id),
  action VARCHAR(50),
  entity_type VARCHAR(50),
  entity_id VARCHAR(100),
  old_values JSONB,
  new_values JSONB,
  ip_address VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Inventory
CREATE TABLE user_inventory (
  user_id UUID REFERENCES users(id),
  item_id VARCHAR(50),
  item_type VARCHAR(30), -- 'avatar', 'frame', 'emote'
  acquired_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, item_id)
);
```

---

## 4. Redis Architecture

Redis is heavily utilized for transient, high-speed read/write operations.

```text
# Session Management
session:{userId}               → Hash { jwt, deviceId, ip, createdAt } (TTL: 24h)

# Presence & Liveness
online:{userId}                → String (Timestamp) (TTL: 5min, refreshed by heartbeat)
online_count                   → Integer (incremented/decremented)

# Matchmaking
matchmaking:{mode}:{tier}      → Sorted Set (Value: userId, Score: entryTimestamp)
match_lock:{userId}            → String (TTL: 30s, prevents joining multiple queues)

# Active Games
game:{gameId}:state            → JSON String (Complete serialized game state) (TTL: 2h)
game:{gameId}:players          → Set [userIds]
game:{gameId}:events           → List [Event JSON] (For real-time reconnection replay)

# Player Mapping (O(1) lookup for routing)
player_game:{userId}           → String (gameId) (TTL: 2h)
player_server:{userId}         → String (Server IP/ID of Dart Game Server)

# Leaderboards (Score based)
leaderboard:daily:{date}       → Sorted Set (Value: userId, Score: winnings) (TTL: 48h)
leaderboard:weekly:{weekId}    → Sorted Set (Value: userId, Score: xp) (TTL: 14 days)

# Rate Limiting & Anti-Spam
ratelimit:{endpoint}:{ip}      → Integer (counter, TTL: window duration)
chat_spam:{userId}             → Integer (counter, TTL: 60s)
```

---

## 5. Event-Driven Architecture

To decouple systems (like wallet updates from game logic), we use an event-driven model powered by AWS SQS/SNS (migrating to Kafka at scale).

### Event Schema Definition
```typescript
interface SystemEvent<T = any> {
  eventId: string;           // UUID
  eventType: EventType;      // Enum string
  version: number;           // Schema version (e.g., 1)
  timestamp: string;         // ISO-8601
  payload: T;                // Event specific data
  metadata: {
    userId?: string;
    gameId?: string;
    source: string;          // e.g., 'game-server-node-12', 'api-service'
    correlationId?: string;
  };
}
```

### Event Catalog & Consumers

| Event Type | Producer | Consumer | Action Taken |
|------------|----------|----------|--------------|
| `USER_REGISTERED` | API (Auth) | API (Reward, Social) | Grant starting coins, create empty inventory. |
| `GAME_STARTED` | Game Server | API (Wallet, Analytics) | Deduct entry fees from players via ledger. |
| `GAME_COMPLETED` | Game Server | API (Wallet, Reward, DB) | Distribute prize pool, save replay, update MMR, update missions. |
| `PLAYER_DROPPED` | Game Server | API (Wallet, Analytics) | Process drop penalty (first drop vs middle drop in points rummy). |
| `COINS_CREDITED` | API (Wallet) | Client (WebSocket push) | Push updated balance to UI. |
| `AD_REWARDED_COMPLETE`| API (Ads) | API (Wallet, Reward) | Credit gems/coins, update daily mission progress. |
| `SUSPICIOUS_ACTIVITY` | Game Server | API (Admin/Fraud) | Flag account if excessive drops or bot-like behavior is detected. |

---

## 6. WebSocket Protocol

The Game Server uses raw WebSockets (`dart:io` ServerSocket). Payloads are JSON. Every message contains a `type`.

```typescript
// --- Client to Server ---
type ClientMessage = 
  | { type: 'AUTH', token: string }
  | { type: 'JOIN_GAME', gameId: string }
  | { type: 'ACTION', action: GameAction, seq: number } // e.g. draw, discard, group, declare
  | { type: 'HEARTBEAT' } // Sent every 10 seconds
  | { type: 'CHAT', message: string }
  | { type: 'EMOTE', emoteId: string }
  | { type: 'RECONNECT', token: string, lastSeq: number }

type GameAction = 
  | { actionType: 'DRAW', source: 'deck' | 'discard' }
  | { actionType: 'DISCARD', card: string } // e.g., 'H-7'
  | { actionType: 'DECLARE', groups: string[][] } 
  | { actionType: 'DROP' }


// --- Server to Client ---
type ServerMessage =
  | { type: 'AUTH_OK', playerId: string }
  | { type: 'GAME_STATE', state: GameStateView, seq: number } // Full sync
  | { type: 'ACTION_ACK', seq: number } // Confirms client action received
  | { type: 'ACTION_REJECT', seq: number, reason: string }
  | { type: 'OPPONENT_ACTION', action: PublicAction, seq: number }
  | { type: 'TURN_START', playerId: string, timeLimit: number } // timeLimit in seconds
  | { type: 'GAME_RESULT', result: GameResult }
  | { type: 'ERROR', code: string, message: string }
  | { type: 'HEARTBEAT_ACK' }
  | { type: 'CHAT', from: string, message: string }
  | { type: 'PLAYER_STATUS', playerId: string, status: 'online' | 'offline' }

type PublicAction =
  | { actionType: 'DRAW_DEIGHT', playerId: string }
  | { actionType: 'DRAW_DISCARD', playerId: string, card: string }
  | { actionType: 'DISCARD', playerId: string, card: string }
  | { actionType: 'DROP', playerId: string, penalty: number }
```
*Note: The `seq` (sequence) number ensures ordering. If a client receives a seq out of order, it can request a full `GAME_STATE` resync.*

---

## 7. AWS Cloud Architecture

### V1 Architecture (0-100K users)

```mermaid
flowchart TD
    Client[Mobile/Web Client]
    
    subedge[AWS Cloud]
        CF[CloudFront / WAF]
        ALB[Application Load Balancer]
        
        Client -->|HTTPS / WSS| CF
        CF --> ALB
        
        subgraph Compute[ECS Fargate Cluster]
            API[Node.js API Services]
            GS[Dart Game Servers]
        end
        
        ALB -->|/api/*| API
        ALB -->|/game-ws| GS
        
        subgraph Data[Data Layer]
            RDS[(RDS PostgreSQL \n db.r6g.large)]
            Redis[(ElastiCache Redis \n cache.r6g.large)]
        end
        
        API --> RDS
        API --> Redis
        GS --> Redis
        
        SQS[SQS Event Queue]
        GS -->|Publish Event| SQS
        API -->|Consume Event| SQS
        
        S3[(S3 Buckets: Assets, Replays)]
        GS --> S3
        API --> S3
    end
```

### V2 Architecture (100K-1M users)
- **Auto-Scaling:** ECS Tasks scale based on CPU and memory utilization metrics.
- **Data Scaling:** RDS gains read-replicas for analytical queries and player history lookups. Redis transitions to a clustered setup.
- **Queueing:** Transition from SQS to **Amazon MSK (Kafka)** for high-throughput, replayable event streaming.
- **Search:** Introduce OpenSearch for complex admin queries (searching audit logs, user histories).

### V3 Architecture (1M-10M+ users)
- **Compute:** Migrate API layer to EKS (Kubernetes) for finer-grained microservices orchestration.
- **Game Servers:** Move Dart game servers to dedicated EC2 fleets (or AWS GameLift) with static IPs to bypass ALB limitations for long-lived WebSocket connections at massive scale.
- **Global Routing:** Implement AWS Global Accelerator for improved latency across regions (e.g., North vs. South India).
- **Database:** Migrate to Aurora PostgreSQL for seamless auto-scaling storage and multi-AZ failover.

---

## 8. AWS Cost Estimates

*Assumptions: Pricing based on AWS ap-south-1 (Mumbai). Traffic assumptions: 5% of MAU are DAU, peak concurrency is 10% of DAU.*

### V1: 10K MAU / ~500 Concurrent
| Service | Specification / Usage | Est. Monthly Cost |
|---------|-----------------------|-------------------|
| ECS Fargate (API) | 2 tasks (1 vCPU, 2GB) | $70.00 |
| ECS Fargate (Game) | 2 tasks (2 vCPU, 4GB) | $140.00 |
| ALB | 1 ALB, moderate data processed | $25.00 |
| RDS PostgreSQL | Single-AZ `db.t4g.medium` (4GB RAM) | $50.00 |
| ElastiCache Redis | Single node `cache.t4g.medium` | $35.00 |
| S3 & CloudFront | 50GB storage, 500GB outbound | $45.00 |
| SQS / CloudWatch | Standard usage, logs | $20.00 |
| **Total** | | **~$385.00 / month** |

### V2: 100K MAU / ~5,000 Concurrent
| Service | Specification / Usage | Est. Monthly Cost |
|---------|-----------------------|-------------------|
| ECS Fargate (API) | 6 tasks (2 vCPU, 4GB) | $420.00 |
| ECS Fargate (Game) | 10 tasks (2 vCPU, 4GB) | $700.00 |
| RDS PostgreSQL | Multi-AZ `db.r6g.large` (16GB RAM) | $320.00 |
| ElastiCache Redis | 2 Node Cluster `cache.r6g.large` | $250.00 |
| Network / ALB / CF | ~5TB outbound | $400.00 |
| Aux (S3, SQS, MSK) | Standard storage + basic MSK | $200.00 |
| **Total** | | **~$2,290.00 / month** |

### V3: 1M MAU / ~50,000 Concurrent
*Estimated Total:* **~$18,000 - $22,000 / month** (Requires Aurora DB, Large EC2 Game Fleets, Global Accelerator, heavy egress bandwidth).

---

## 9. Admin Panel

Built using **React (Next.js)** with TailwindCSS. Communicates directly with the API Server via specific `/api/v1/admin/*` routes authenticated via JWTs assigned to internal staff.

### Key Modules
1. **Dashboard:** Real-time metrics (Concurrent users, active tables, daily revenue, ARPU).
2. **User Management:** View player profiles, edit wallet balances (with mandatory audit notes), view game history, suspend/ban users.
3. **Games & Replays:** Search past games by ID. Launch visual replay viewer (fetches JSON from S3 and renders Game UI on the web).
4. **Fraud & Risk:** Dashboard highlighting players with suspicious win rates, repeated drop patterns, or colluding IP addresses.
5. **Wallet & Economy:** Track system-wide sink/source metrics. Total coins injected vs. consumed.
6. **Config & Feature Flags:** Toggle features (e.g., `enable_tournaments`), tweak MMR algorithms, adjust bot injection timers.

### Role-Based Access Control (RBAC)
- **Super Admin:** Full access, can create other admins.
- **Operations:** Can view dashboards, manage tournaments, send global announcements.
- **Customer Support:** Can view user profiles, reset passwords, refund game entries (up to a limit).
- **Fraud Analyst:** Can view logs, ban users, trigger manual reviews.
- **Developer:** Read-only access to system health, server logs, and feature flags.

---

## 10. Notification System

Push notifications are critical for retention (daily rewards, friend invites, tournament starts).

### Infrastructure
- **Firebase Cloud Messaging (FCM):** Used as the abstraction layer for both Android (native FCM) and iOS (APNs via Firebase).
- **Database:** `user_devices` stores the active FCM token per device. `user_settings` stores the notification opt-ins.

### Triggers & Categories
1. **Transactional (High Priority):** Friend requests, game invites, purchase confirmations.
2. **Lifecycle (Medium Priority):** Daily reward available, weekly leaderboard results, inactive for 3 days ("Come back and play!").
3. **Marketing (Low Priority):** Special coin bundle offers, holiday events.

### Implementation Rules
- **Rate Limiting:** A user must not receive more than 3 marketing/lifecycle notifications per 24-hour period.
- **Silent Pushes:** Used to trigger background data syncs in the app without alerting the user (e.g., syncing new cosmetic inventory).
- **Queueing:** Scheduled notifications (e.g., "Tournament starts in 5 minutes") are pushed to SQS with a `DelaySeconds` parameter, and consumed by a Lambda function that calls the FCM API exactly when needed.
