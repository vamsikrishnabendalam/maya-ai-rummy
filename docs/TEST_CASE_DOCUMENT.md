# Maya AI Rummy — Comprehensive Master Test Case Document
**Version**: 2.5.0  
**Platforms**: Android Mobile (Native APK), iOS Mobile, Flutter Web (Desktop / Tablet / Mobile Browser), Cloud Functions Engine  
**Standard**: Indian Rummy 13-Card (Points, Pool 101/201/301, Best of 2 Deals)  
**Fair-Play Engine**: Fair-Play Engine v2.0 (Strict Conservation of Cards & Audit Logging)

---

## Architecture & Verification Overview

| Tier | Component | Tech Stack | Responsibility |
|---|---|---|---|
| **Client UI** | Mobile / Desktop App | Flutter 3.x / Riverpod | Immersive UI, card interactions, animations, drag-and-drop, modals |
| **Local State** | Game State Machine | Riverpod Notifiers | Hand state, phase synchronization (14-card invariant), grouping |
| **Service Layer**| `MultiplayerService` | Cloud Firestore / Functions | Real-time game room coordination, transactions, timers |
| **Fair-Play Engine**| `packages/game-engine` | Pure Dart Engine | Shuffle uniformity, card uniqueness, meld validation, score audit |
| **AI Bot Host** | `packages/ai-engine` | Pure Dart AI Strategy | Maya Bot opponent decision-making, sequence preservation, threat tracking |

---

## Test Suite Execution Summary

| Module | Test File / Command | Test Cases | Status |
|---|---|---|---|
| **Mobile State & Edge Cases** | `apps/mobile/test/multiplayer_submission_and_joker_test.dart` | 6 | ✅ PASS (6/6) |
| **Mobile UI & Table Layouts** | `apps/mobile/test/multiplayer_tables_ui_test.dart` | 8 | ✅ PASS (8/8) |
| **Closed Joker Scenarios** | `apps/mobile/test/closed_joker_scenarios_test.dart` | 5 | ✅ PASS (5/5) |
| **Mobile Landscape Ergonomics**| `apps/mobile/test/mobile_landscape_playability_test.dart` | 8 | ✅ PASS (8/8) |
| **Declaration & Finish Flow** | `apps/mobile/test/declaration_open_drawn_card_test.dart` | 3 | ✅ PASS (3/3) |
| **Settings & Exit Flow** | `apps/mobile/test/exit_game_and_locked_settings_test.dart` | 6 | ✅ PASS (6/6) |
| **Action Logs & Fair-Play** | `apps/mobile/test/game_action_logs_test.dart` | 5 | ✅ PASS (5/5) |
| **Round Completion Flow** | `apps/mobile/test/round_completion_flow_test.dart` | 5 | ✅ PASS (5/5) |
| **Opponent Declaration Modal** | `apps/mobile/test/opponent_declaration_modal_test.dart` | 3 | ✅ PASS (3/3) |
| **Full Mobile Suite Total** | `cd apps/mobile; flutter test` | **49** | ✅ **PASS (49/49)** |
| **Pure Game Engine Lifecycle**| `cd packages/game-engine; dart test` | **44** | ✅ **PASS (44/44)** |
| **AI Decision & Regression** | `cd packages/ai-engine; dart test` | **9** | ✅ **PASS (9/9)** |
| **Cloud Functions Rules** | `cd functions; npm.cmd test` | **10** | ✅ **PASS (10/10)** |
| **Total Automated Tests** | Across entire repository | **112** | ✅ **PASS (112/112)** |

---

## Detailed Test Cases & Edge Case Specification

### Module 1: Authentication & User Lifecycle

#### TC-AUTH-01: Native Google Sign-In with Account Selection (Android Mobile)
- **Precondition**: User is on Mobile Login Screen or Profile Modal with Google Play Services installed.
- **Execution Steps**:
  1. Tap "Sign in with Google".
  2. Select Google account from Android OS system dialog.
  3. Verify Firebase authentication completes.
- **Expected Result**:
  - User displayName, email, and photoURL populate the user profile.
  - User status changes from `isGuest: true` to `isGuest: false`.
  - Snack bar indicates `"Signed in as [Name]!"`.

#### TC-AUTH-02: Native Google Sign-In Fallback on Missing SHA-1 / Missing google-services.json
- **Precondition**: Native Google Sign-In returns `idToken == null` or Firebase Auth rejects the OAuth credential.
- **Execution Steps**:
  1. Trigger Google sign-in flow.
  2. Simulate null `idToken` from Google Play Services.
- **Expected Result**:
  - `AuthService` gracefully activates Firebase anonymous session (satisfying Firestore security rules `request.auth != null`).
  - Account profile (`/users/{uid}`) is created with Google user details and 1000 virtual coins.
  - User interface transitions seamlessly without silent freeze or deadlock.

#### TC-AUTH-03: Guest Sign-In & Profile Persistence
- **Precondition**: App launched for the first time.
- **Execution Steps**:
  1. Tap "Play as Guest".
  2. Enter guest display name.
- **Expected Result**:
  - Guest profile generated with 0 initial coin requirement.
  - Coin tables restricted with a prompt: "Guest players cannot create coin tables. Please sign in with Google."

---

### Module 2: Closed Joker & Life (Pure Sequence) Verification

#### TC-CJ-01: Initial Deal without Pure Sequence
- **Precondition**: Closed Joker mode active. Dealt 13 cards do not contain a 3+ card natural sequence.
- **Execution Steps**:
  1. Observe center table deck stack.
  2. Tap on Closed Joker card.
- **Expected Result**:
  - Joker card remains face-down (card back displayed).
  - Tapping displays SnackBar: `"Form a Pure Sequence (Life) of 3+ cards to view the Joker."`
  - Deadwood calculation treats wild rank as natural card (not wild).

#### TC-CJ-02: Initial Deal with Natural Pure Sequence
- **Precondition**: Closed Joker mode active. Dealt 13 cards contain a pure sequence (e.g. 2♥ 3♥ 4♥).
- **Execution Steps**:
  1. Deal completes.
- **Expected Result**:
  - Closed Joker automatically unlocks at deal start.
  - Secret royal reveal overlay triggers.
  - Joker card flips face-up on center table.

#### TC-CJ-03: Forming Pure Sequence from 14th Drawn Card (Strict Guard)
- **Precondition**: Player has 13 cards without pure sequence, draws 14th card completing a pure sequence.
- **Execution Steps**:
  1. Draw 14th card. Hand now holds 14 cards in `DISCARD_PHASE`.
  2. Tap Closed Joker or observe center table.
- **Expected Result**:
  - **CRITICAL**: Closed Joker MUST NOT unlock before discarding!
  - `hasLife` evaluates to false while holding 14 cards before discard.
  - Tapping Joker displays: `"Please discard a card to complete your turn before viewing the Closed Joker."`

#### TC-CJ-04: Discarding with Pure Sequence
- **Precondition**: Player holds 14 cards with a pure sequence.
- **Execution Steps**:
  1. Discard 14th card into Open Pile.
- **Expected Result**:
  - Hand size returns to 13 cards.
  - `discardSelectedCard()` automatically unlocks Closed Joker on server and client.
  - Secret royal reveal overlay fires with wild joker card.

---

### Module 3: Turn Synchronization & Hand Size Invariants

#### TC-TURN-01: 14-Card Discard Phase Guarantee (No Stuck Draws)
- **Precondition**: Player's turn. Hand holds 14 cards (already drawn), but local state or server packet lags in `DRAW_PHASE`.
- **Execution Steps**:
  1. Inspect `isDrawPhase` and `isDiscardPhase` getters.
  2. Attempt to draw 15th card.
  3. Attempt to discard a card via drag-and-drop or tap.
- **Expected Result**:
  - Invariant enforces: `isDrawPhase` evaluates to `false` and `isDiscardPhase` evaluates to `true` whenever holding $\ge 14$ cards.
  - Tapping deck does NOT draw a 15th card.
  - Discard button and Open Pile `DragTarget` are active and accept the card.

#### TC-TURN-02: Indian Rummy Open Draw Discard Prohibition
- **Precondition**: Player draws 8♣ from the Open Discard Pile. Hand has 14 cards.
- **Execution Steps**:
  1. Select 8♣ and tap Discard (or drag 8♣ to Open Pile).
- **Expected Result**:
  - Action is rejected with message: `"Indian Rummy Rule: You cannot discard the card drawn from the open pile in the same turn!"`
  - Selecting any other card allows clean discard.

#### TC-TURN-03: Drag & Drop Discard without Pre-Selection
- **Precondition**: Player's turn, 14 cards in hand, no card tapped or pre-selected in state.
- **Execution Steps**:
  1. Drag a card directly from the hand onto the Discard button or Open Pile.
- **Expected Result**:
  - Discard button and Open Pile highlight green.
  - Dropping the card discards it immediately to 13 cards and advances the turn.

---

### Module 4: Drops & Multi-Round Tournament Lifecycle

#### TC-DROP-01: First Drop in Pool 201 Rummy (Multi-Round Continuity)
- **Precondition**: 2-player Pool 201 game, Round 1, Turn 0 (before drawing).
- **Execution Steps**:
  1. Player 1 taps "Drop (20)".
  2. Confirm drop in dialog.
- **Expected Result**:
  - **CRITICAL**: Game status transitions to `ROUND_OVER`, NOT `COMPLETED`!
  - Player 1 receives +20 penalty points (Cumulative: 20 pts).
  - Player 2 wins Round 1 with 0 points (Cumulative: 0 pts).
  - Both players see "Round 1 Completed! Deal Next (#2)" countdown bar (6s).
  - Dropping player dialog displays `"YOU DROPPED (20 pts)"`, NOT `"GAME WON! 🏆"`.

#### TC-DROP-02: Middle Drop in Pool 201 Rummy
- **Precondition**: Player drops after turn 1 has passed (before drawing on turn 2).
- **Execution Steps**:
  1. Tap "Drop (40)". Confirm.
- **Expected Result**:
  - Dropped player receives 40 points penalty.
  - Round ends with `ROUND_OVER`. Next round automatically queues.

#### TC-DROP-03: Elimination Threshold in Pool Rummy (101/201/301)
- **Precondition**: Player reaches $\ge 201$ cumulative points.
- **Execution Steps**:
  1. Round finishes.
- **Expected Result**:
  - Player status transitions to `ELIMINATED`.
  - If only 1 active player remains, match transitions to `status: 'COMPLETED'` with `tournamentWinnerId`.

#### TC-DROP-04: Single-Round Points Rummy Drop
- **Precondition**: Points Rummy game (single deal).
- **Execution Steps**:
  1. Player drops on first turn.
- **Expected Result**:
  - Match completes immediately (`status: 'COMPLETED'`).
  - Dropper loses 20 points, opponent wins. Result dialog displays accurate Victory/Defeat.

---

### Module 5: Declarations & Finish Card Rendering on Table Canvas

#### TC-DEC-01: Drag 14th Card to Finish Slot
- **Precondition**: Player has 14 cards with valid show (1st Life + 2nd Life + melds).
- **Execution Steps**:
  1. Drag the 14th finish card onto the center Finish / Declare Slot.
- **Expected Result**:
  - **CRITICAL**: Finish card is physically rendered face-up inside the Finish Slot on the table canvas with a golden "FINISH" badge.
  - Declaration validation succeeds.
  - Opponents see the declared card placed on the center table.

#### TC-DEC-02: Opponent 30-Second Final Hand Submission
- **Precondition**: Player 1 declares valid show. Player 2 has 13 cards.
- **Execution Steps**:
  1. Player 2 receives prompt with 30s countdown: `"vk HAS DECLARED! Arrange your cards to minimize penalty points, then tap SUBMIT FINAL HAND"`.
  2. Player 2 groups cards into pure sequence and taps "Submit Final Hand".
- **Expected Result**:
  - Opponent's hand is validated and deadwood penalty calculated (e.g. 5 pts instead of default 80 pts).
  - Table transitions to round completion without giving default full-count penalty.

#### TC-DEC-03: Invalid Declaration (Wrong Show)
- **Precondition**: Player declares with missing second sequence.
- **Execution Steps**:
  1. Tap Declare with invalid melds.
- **Expected Result**:
  - Declaration rejected. Player penalized with 80 points (Full Count Penalty).

---

### Module 6: Mobile Ergonomics & Immersive UI

#### TC-UI-01: System Status Bar Hidden (Android Immersive Mode)
- **Precondition**: Launch app on physical Android device or emulator.
- **Execution Steps**:
  1. Observe top edge of screen.
- **Expected Result**:
  - Android status bar (battery, wifi, clock, notifications) is completely hidden (`SystemUiMode.immersiveSticky`).
  - No notch or status bar overlap on table buttons or Declare Hand banner.

#### TC-UI-02: Zero-Overflow Mobile Landscape Layout
- **Precondition**: Test on 850x390, 720p, 1080p, and tablet viewports.
- **Execution Steps**:
  1. Draw 14 cards.
  2. Inspect card fans and thumb action buttons (Group, Drop, Sort, AI Group, Discard).
- **Expected Result**:
  - All 14 cards fit within horizontal screen width with generous overlapping fan.
  - Zero RenderFlex overflow errors.

#### TC-UI-03: Royal Game Menu Optimization
- **Precondition**: Open Royal Game Menu from top-right.
- **Execution Steps**:
  1. Verify items: Live Scorecard, Game Action Logs, Table Settings, Exit Game.
- **Expected Result**:
  - Redundant "Download Android App" option is removed on mobile app.
  - Modals feature compact headers with action buttons aligned to the right.
