const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {
  cardFromInt,
  cardToInt,
  getEffectiveWildRank,
  createShuffledDeck,
  validateDeclaration,
  calculateLoserScore,
} = require('./engine/rummyRules');

admin.initializeApp();
const db = admin.firestore();

// Helper: Generate collision-free 6-char alphanumeric room code
function generateRoomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Omitted I, O, 0, 1 to prevent ambiguity
  let result = '';
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * 1. createTable
 * Creates a new multiplayer table lobby.
 */
exports.createTable = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to create a table.');
  }

  const uid = context.auth.uid;
  const displayName = context.auth.token.name || data.displayName || 'Player';
  const photoURL = context.auth.token.picture || data.photoURL || '';
  const tableName = (data.tableName || `${displayName}'s Table`).trim().substring(0, 30);
  const maxPlayers = Math.min(Math.max(parseInt(data.maxPlayers, 10) || 2, 2), 6);
  const password = data.password ? String(data.password).trim() : null;

  // Generate unique room code
  let roomCode = generateRoomCode();
  let existing = await db.collection('tables').where('roomCode', '==', roomCode).where('status', '==', 'WAITING').get();
  while (!existing.empty) {
    roomCode = generateRoomCode();
    existing = await db.collection('tables').where('roomCode', '==', roomCode).where('status', '==', 'WAITING').get();
  }

  const tableRef = db.collection('tables').doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  const hostPlayer = {
    uid,
    displayName,
    photoURL,
    seatIndex: 0,
    isHost: true,
    connected: true,
    lastSeenAt: new Date().toISOString(),
  };

  const gameMode = data.gameMode || 'Points Rummy';
  const turnTimerSeconds = data.turnTimerSeconds !== undefined ? parseInt(data.turnTimerSeconds, 10) : 30;
  const firstDropPenalty = data.firstDropPenalty !== undefined ? parseInt(data.firstDropPenalty, 10) : 20;
  const middleDropPenalty = data.middleDropPenalty !== undefined ? parseInt(data.middleDropPenalty, 10) : 40;
  const maxPenalty = data.maxPenalty !== undefined ? parseInt(data.maxPenalty, 10) : 80;

  const tableData = {
    tableId: tableRef.id,
    roomCode,
    tableName,
    hostUid: uid,
    maxPlayers,
    playerCount: 1,
    status: 'WAITING', // WAITING | STARTING | PLAYING | COMPLETED | ABANDONED
    gameType: '13_CARD_RUMMY',
    gameMode,
    turnTimerSeconds,
    firstDropPenalty,
    middleDropPenalty,
    maxPenalty,
    entryType: 'FREE',
    hasPassword: !!password,
    passwordHash: password || null,
    activeGameId: null,
    createdAt: now,
    updatedAt: now,
    players: [hostPlayer],
  };

  await tableRef.set(tableData);
  await tableRef.collection('players').doc(uid).set(hostPlayer);

  return { tableId: tableRef.id, roomCode };
});

/**
 * 2. joinTable
 * Joins an existing table using roomCode.
 */
exports.joinTable = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to join a table.');
  }

  const uid = context.auth.uid;
  const displayName = context.auth.token.name || data.displayName || 'Player';
  const photoURL = context.auth.token.picture || data.photoURL || '';
  const roomCode = (data.roomCode || '').toUpperCase().trim();
  const password = data.password ? String(data.password).trim() : null;

  if (!roomCode) {
    throw new functions.https.HttpsError('invalid-argument', 'Room code is required.');
  }

  const querySnap = await db.collection('tables').where('roomCode', '==', roomCode).where('status', '==', 'WAITING').limit(1).get();
  if (querySnap.empty) {
    throw new functions.https.HttpsError('not-found', 'Table not found or game has already started.');
  }

  const tableDoc = querySnap.docs[0];
  const tableRef = tableDoc.ref;

  return await db.runTransaction(async (transaction) => {
    const freshTable = await transaction.get(tableRef);
    if (!freshTable.exists) {
      throw new functions.https.HttpsError('not-found', 'Table does not exist.');
    }

    const tData = freshTable.data();
    if (tData.status !== 'WAITING') {
      throw new functions.https.HttpsError('failed-precondition', 'Game has already started or table is closed.');
    }

    // Check password
    if (tData.hasPassword && tData.passwordHash !== password) {
      throw new functions.https.HttpsError('permission-denied', 'Incorrect table password.');
    }

    // Check if player is already in table
    const existingPlayer = tData.players.find(p => p.uid === uid);
    if (existingPlayer) {
      return { tableId: tData.tableId, roomCode: tData.roomCode, seatIndex: existingPlayer.seatIndex };
    }

    if (tData.players.length >= tData.maxPlayers) {
      throw new functions.https.HttpsError('resource-exhausted', `Table is full (max ${tData.maxPlayers} players).`);
    }

    // Find first available seat index
    const takenSeats = new Set(tData.players.map(p => p.seatIndex));
    let seatIndex = 0;
    while (takenSeats.has(seatIndex)) {
      seatIndex++;
    }

    const newPlayer = {
      uid,
      displayName,
      photoURL,
      seatIndex,
      isHost: false,
      connected: true,
      lastSeenAt: new Date().toISOString(),
    };

    const updatedPlayers = [...tData.players, newPlayer];

    transaction.update(tableRef, {
      players: updatedPlayers,
      playerCount: updatedPlayers.length,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.set(tableRef.collection('players').doc(uid), newPlayer);

    return { tableId: tData.tableId, roomCode: tData.roomCode, seatIndex };
  });
});

/**
 * 3. leaveTable
 * Leaves a table lobby.
 */
exports.leaveTable = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = context.auth.uid;
  const tableId = data.tableId;
  if (!tableId) {
    throw new functions.https.HttpsError('invalid-argument', 'Table ID is required.');
  }

  const tableRef = db.collection('tables').doc(tableId);

  return await db.runTransaction(async (transaction) => {
    const tableDoc = await transaction.get(tableRef);
    if (!tableDoc.exists) return { success: true };

    const tData = tableDoc.data();
    const remainingPlayers = tData.players.filter(p => p.uid !== uid);

    if (remainingPlayers.length === 0) {
      // Table is now empty -> mark ABANDONED
      transaction.update(tableRef, {
        status: 'ABANDONED',
        players: [],
        playerCount: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // If host left, assign host to first remaining player
      let newHostUid = tData.hostUid;
      if (tData.hostUid === uid) {
        remainingPlayers[0].isHost = true;
        newHostUid = remainingPlayers[0].uid;
      }

      transaction.update(tableRef, {
        players: remainingPlayers,
        playerCount: remainingPlayers.length,
        hostUid: newHostUid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    transaction.delete(tableRef.collection('players').doc(uid));
    return { success: true };
  });
});

/**
 * 4. startGame
 * Server-authoritative start:
 * - Shuffles 106 cards
 * - Cuts random card to determine Open Joker (Printed Joker cut -> Ace wild)
 * - Deals 13 cards to each player's private hand
 * - Pushes first card to open pile
 * - Initializes public game state
 */
exports.startGame = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = context.auth.uid;
  const tableId = data.tableId;
  if (!tableId) {
    throw new functions.https.HttpsError('invalid-argument', 'Table ID is required.');
  }

  const tableRef = db.collection('tables').doc(tableId);
  const tableDoc = await tableRef.get();
  if (!tableDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Table not found.');
  }

  const tData = tableDoc.data();
  if (tData.hostUid !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Only the table host can start the game.');
  }

  if (tData.players.length < 2) {
    throw new functions.https.HttpsError('failed-precondition', 'At least 2 players are required to start a game.');
  }

  if (tData.status !== 'WAITING') {
    throw new functions.https.HttpsError('failed-precondition', 'Game is already running or completed.');
  }

  // 1. Generate & shuffle 106 cards (2 full decks)
  const fullDeck = createShuffledDeck();

  // 2. Select Open Joker (wild card cut)
  const openJoker = fullDeck.pop();
  const effectiveWildRank = getEffectiveWildRank(openJoker);

  // 3. Deal 13 cards to each player
  const playerHands = {};
  const gamePlayers = [];
  const players = tData.players;

  for (const p of players) {
    const hand = [];
    for (let c = 0; c < 13; c++) {
      hand.push(fullDeck.pop());
    }
    playerHands[p.uid] = hand;
    gamePlayers.push({
      uid: p.uid,
      displayName: p.displayName,
      photoURL: p.photoURL,
      seatIndex: p.seatIndex,
      cardCount: 13,
      score: 0,
      connected: true,
      status: 'ACTIVE',
    });
  }

  // 4. First card on Open Discard Pile
  const firstOpenCard = fullDeck.pop();
  const openPile = [firstOpenCard];

  // 5. Remaining closed deck
  const remainingClosedCards = fullDeck; // Kept in serverState!

  const gameRef = db.collection('games').doc();
  const gameId = gameRef.id;
  const now = admin.firestore.FieldValue.serverTimestamp();

  const turnTimerSeconds = tData.turnTimerSeconds !== undefined ? parseInt(tData.turnTimerSeconds, 10) : 30;
  const firstDropPenalty = tData.firstDropPenalty !== undefined ? parseInt(tData.firstDropPenalty, 10) : 20;
  const middleDropPenalty = tData.middleDropPenalty !== undefined ? parseInt(tData.middleDropPenalty, 10) : 40;
  const maxPenalty = tData.maxPenalty !== undefined ? parseInt(tData.maxPenalty, 10) : 80;
  const turnDeadline = turnTimerSeconds > 0 ? new Date(Date.now() + (turnTimerSeconds + 5) * 1000) : null;

  // Public Game Document
  const publicGameState = {
    gameId,
    tableId,
    roomCode: tData.roomCode || '',
    tableName: tData.tableName || 'Maya Table',
    gameMode: tData.gameMode || 'Points Rummy',
    status: 'IN_PROGRESS',
    playerCount: players.length,
    currentTurnPlayerId: players[0].uid,
    turnNumber: 0,
    phase: 'DRAW_PHASE', // DRAW_PHASE | DISCARD_PHASE
    turnTimerSeconds,
    firstDropPenalty,
    middleDropPenalty,
    maxPenalty,
    turnDeadline: turnDeadline ? admin.firestore.Timestamp.fromDate(turnDeadline) : null,
    openJoker,
    effectiveWildRank,
    openPile: openPile.map(c => ({ suit: c.suit, rank: c.rank, isPrintedJoker: c.isPrintedJoker, intVal: c.intVal })),
    closedDeckRemaining: remainingClosedCards.length,
    dealerPlayerId: players[players.length - 1].uid,
    cardDrawnFromOpenThisTurn: null,
    winnerPlayerId: null,
    createdAt: now,
    lastActionAt: now,
    players: gamePlayers,
  };

  const batch = db.batch();

  // Write public game state
  batch.set(gameRef, publicGameState);

  // Write private hands for each player (Restricted to player owner!)
  for (const p of players) {
    const privateHandRef = gameRef.collection('privateHands').doc(p.uid);
    batch.set(privateHandRef, {
      uid: p.uid,
      cardCount: 13,
      cards: playerHands[p.uid],
      updatedAt: now,
    });
  }

  // Write server-only secret state (the rest of the closed deck)
  const serverStateRef = gameRef.collection('serverState').doc('deck');
  batch.set(serverStateRef, {
    hiddenCards: remainingClosedCards,
  });

  // Update table doc
  batch.update(tableRef, {
    status: 'PLAYING',
    activeGameId: gameId,
    updatedAt: now,
  });

  await batch.commit();

  return { gameId };
});

/**
 * 5. drawFromClosed
 * Server-authoritative draw from closed deck:
 * Pops top hidden card from serverState/deck and appends to player's private hand.
 */
exports.drawFromClosed = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = context.auth.uid;
  const gameId = data.gameId;
  const actionId = data.actionId;

  if (!gameId) {
    throw new functions.https.HttpsError('invalid-argument', 'Game ID is required.');
  }

  const gameRef = db.collection('games').doc(gameId);
  const serverDeckRef = gameRef.collection('serverState').doc('deck');
  const privateHandRef = gameRef.collection('privateHands').doc(uid);

  return await db.runTransaction(async (transaction) => {
    const gameDoc = await transaction.get(gameRef);
    if (!gameDoc.exists) throw new functions.https.HttpsError('not-found', 'Game not found.');

    const gData = gameDoc.data();
    if (gData.status !== 'IN_PROGRESS') {
      throw new functions.https.HttpsError('failed-precondition', 'Game is not active.');
    }
    if (gData.currentTurnPlayerId !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'It is not your turn.');
    }
    if (gData.phase !== 'DRAW_PHASE') {
      throw new functions.https.HttpsError('failed-precondition', 'Player must draw before discarding.');
    }

    const deckDoc = await transaction.get(serverDeckRef);
    if (!deckDoc.exists) throw new functions.https.HttpsError('internal', 'Server deck state missing.');

    const hiddenCards = deckDoc.data().hiddenCards || [];
    if (hiddenCards.length === 0) {
      throw new functions.https.HttpsError('resource-exhausted', 'Closed deck is empty.');
    }

    const drawnCard = hiddenCards.pop();

    const handDoc = await transaction.get(privateHandRef);
    if (!handDoc.exists) throw new functions.https.HttpsError('not-found', 'Private hand missing.');

    const handCards = handDoc.data().cards || [];
    handCards.push(drawnCard);

    // Update public game: phase -> DISCARD_PHASE, deck count decremented, clear open drawn card
    const updatedPlayers = gData.players.map(p => {
      if (p.uid === uid) return { ...p, cardCount: handCards.length };
      return p;
    });

    transaction.update(gameRef, {
      phase: 'DISCARD_PHASE',
      closedDeckRemaining: hiddenCards.length,
      cardDrawnFromOpenThisTurn: null,
      players: updatedPlayers,
      lastActionAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(serverDeckRef, { hiddenCards });
    transaction.update(privateHandRef, {
      cards: handCards,
      cardCount: handCards.length,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, drawnCard };
  });
});

/**
 * 6. drawFromOpen
 * Server-authoritative draw from open discard pile.
 */
exports.drawFromOpen = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = context.auth.uid;
  const gameId = data.gameId;

  if (!gameId) {
    throw new functions.https.HttpsError('invalid-argument', 'Game ID is required.');
  }

  const gameRef = db.collection('games').doc(gameId);
  const privateHandRef = gameRef.collection('privateHands').doc(uid);

  return await db.runTransaction(async (transaction) => {
    const gameDoc = await transaction.get(gameRef);
    if (!gameDoc.exists) throw new functions.https.HttpsError('not-found', 'Game not found.');

    const gData = gameDoc.data();
    if (gData.status !== 'IN_PROGRESS') {
      throw new functions.https.HttpsError('failed-precondition', 'Game is not active.');
    }
    if (gData.currentTurnPlayerId !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'It is not your turn.');
    }
    if (gData.phase !== 'DRAW_PHASE') {
      throw new functions.https.HttpsError('failed-precondition', 'Player must draw before discarding.');
    }
    if (!gData.openPile || gData.openPile.length === 0) {
      throw new functions.https.HttpsError('failed-precondition', 'Open pile is empty.');
    }

    const openPile = [...gData.openPile];
    const drawnCard = openPile.pop();

    const handDoc = await transaction.get(privateHandRef);
    if (!handDoc.exists) throw new functions.https.HttpsError('not-found', 'Private hand missing.');

    const handCards = handDoc.data().cards || [];
    handCards.push(drawnCard);

    const updatedPlayers = gData.players.map(p => {
      if (p.uid === uid) return { ...p, cardCount: handCards.length };
      return p;
    });

    transaction.update(gameRef, {
      openPile,
      phase: 'DISCARD_PHASE',
      cardDrawnFromOpenThisTurn: drawnCard,
      players: updatedPlayers,
      lastActionAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(privateHandRef, {
      cards: handCards,
      cardCount: handCards.length,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, drawnCard };
  });
});

/**
 * 7. discardCard
 * Discards 1 card from player's hand.
 * Enforces Indian Rummy Rule: Cannot discard the card drawn from the open pile in the same turn!
 */
exports.discardCard = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = context.auth.uid;
  const gameId = data.gameId;
  const cardIntVal = parseInt(data.cardIntVal, 10);

  if (!gameId || isNaN(cardIntVal)) {
    throw new functions.https.HttpsError('invalid-argument', 'Game ID and card value are required.');
  }

  const gameRef = db.collection('games').doc(gameId);
  const privateHandRef = gameRef.collection('privateHands').doc(uid);

  return await db.runTransaction(async (transaction) => {
    const gameDoc = await transaction.get(gameRef);
    if (!gameDoc.exists) throw new functions.https.HttpsError('not-found', 'Game not found.');

    const gData = gameDoc.data();
    if (gData.status !== 'IN_PROGRESS') {
      throw new functions.https.HttpsError('failed-precondition', 'Game is not active.');
    }
    if (gData.currentTurnPlayerId !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'It is not your turn.');
    }
    if (gData.phase !== 'DISCARD_PHASE') {
      throw new functions.https.HttpsError('failed-precondition', 'Must draw a card before discarding.');
    }

    // STRICT INDIAN RUMMY RULE: Cannot discard the card just drawn from open pile!
    if (gData.cardDrawnFromOpenThisTurn && gData.cardDrawnFromOpenThisTurn.intVal === cardIntVal) {
      throw new functions.https.HttpsError('invalid-argument', 'Indian Rummy Rule: You cannot discard the card drawn from the open pile on the same turn.');
    }

    const handDoc = await transaction.get(privateHandRef);
    if (!handDoc.exists) throw new functions.https.HttpsError('not-found', 'Private hand missing.');

    const handCards = handDoc.data().cards || [];
    const cardIndex = handCards.findIndex(c => c.intVal === cardIntVal);
    if (cardIndex === -1) {
      throw new functions.https.HttpsError('invalid-argument', 'Card does not exist in your hand.');
    }

    const [discardedCard] = handCards.splice(cardIndex, 1);

    // Push discarded card to open pile
    const openPile = [...(gData.openPile || []), discardedCard];

    // Determine next player (clockwise)
    const activePlayers = gData.players.filter(p => p.status === 'ACTIVE');
    const currentIndex = activePlayers.findIndex(p => p.uid === uid);
    const nextIndex = (currentIndex + 1) % activePlayers.length;
    const nextPlayerId = activePlayers[nextIndex].uid;

    const turnTimerSeconds = gData.turnTimerSeconds !== undefined ? parseInt(gData.turnTimerSeconds, 10) : 30;
    const nextTurnDeadline = turnTimerSeconds > 0 ? new Date(Date.now() + (turnTimerSeconds + 5) * 1000) : null;

    const updatedPlayers = gData.players.map(p => {
      if (p.uid === uid) return { ...p, cardCount: handCards.length };
      return p;
    });

    transaction.update(gameRef, {
      openPile,
      currentTurnPlayerId: nextPlayerId,
      turnNumber: (gData.turnNumber || 0) + 1,
      phase: 'DRAW_PHASE',
      turnDeadline: nextTurnDeadline ? admin.firestore.Timestamp.fromDate(nextTurnDeadline) : null,
      cardDrawnFromOpenThisTurn: null,
      players: updatedPlayers,
      lastActionAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.update(privateHandRef, {
      cards: handCards,
      cardCount: handCards.length,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, discardedCard };
  });
});

/**
 * 7b. dropGame
 * Allows player to drop during DRAW_PHASE before picking a card.
 */
exports.dropGame = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = context.auth.uid;
  const gameId = data.gameId;

  if (!gameId) {
    throw new functions.https.HttpsError('invalid-argument', 'Game ID is required.');
  }

  const gameRef = db.collection('games').doc(gameId);

  return await db.runTransaction(async (transaction) => {
    const gameDoc = await transaction.get(gameRef);
    if (!gameDoc.exists) throw new functions.https.HttpsError('not-found', 'Game not found.');

    const gData = gameDoc.data();
    if (gData.status !== 'IN_PROGRESS') {
      throw new functions.https.HttpsError('failed-precondition', 'Game is not active.');
    }
    if (gData.currentTurnPlayerId !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'It is not your turn to drop.');
    }
    if (gData.phase !== 'DRAW_PHASE') {
      throw new functions.https.HttpsError('failed-precondition', 'Cannot drop after drawing a card. You must discard.');
    }

    const players = [...(gData.players || [])];
    const playerIdx = players.findIndex(p => p.uid === uid);
    if (playerIdx === -1) {
      throw new functions.https.HttpsError('not-found', 'Player not found in game.');
    }

    const turnNumber = gData.turnNumber || 0;
    const actionLog = [...(gData.actionLog || [])];
    const hasDrawnOrDiscarded = actionLog.some(a => a.playerId === uid && (a.type === 'DRAW_CLOSED' || a.type === 'DRAW_OPEN' || a.type === 'DISCARD'));
    const isFirstDrop = turnNumber === 0 || !hasDrawnOrDiscarded;
    const penalty = isFirstDrop ? (gData.firstDropPenalty || 20) : (gData.middleDropPenalty || 40);

    const droppedPlayer = {
      ...players[playerIdx],
      status: 'DROPPED',
      score: penalty,
    };
    players[playerIdx] = droppedPlayer;

    const remainingActive = players.filter(p => p.status === 'ACTIVE');
    const now = admin.firestore.FieldValue.serverTimestamp();

    actionLog.push({
      seq: actionLog.length + 1,
      timestamp: new Date().toISOString(),
      type: 'DROP',
      playerId: uid,
      description: `${droppedPlayer.displayName || 'Player'} dropped from the round (${penalty} pts, ${isFirstDrop ? 'First Drop' : 'Middle Drop'}).`,
    });

    if (remainingActive.length <= 1) {
      // 1 active player remains -> concludes game
      const winner = remainingActive.length === 1 ? remainingActive[0] : players[0];
      const finalResults = players.map(p => ({
        uid: p.uid,
        displayName: p.displayName || 'Player',
        photoURL: p.photoURL || '',
        seatIndex: p.seatIndex || 0,
        score: p.uid === winner.uid ? 0 : p.score,
        isWinner: p.uid === winner.uid,
      }));

      transaction.update(gameRef, {
        status: 'COMPLETED',
        winnerPlayerId: winner.uid,
        finalResults,
        players,
        actionLog,
        lastActionAt: now,
      });

      const tableRef = db.collection('tables').doc(gData.tableId);
      transaction.update(tableRef, {
        status: 'WAITING',
        activeGameId: null,
        updatedAt: now,
      });

      return { success: true, message: 'Game completed. Remaining player won.', penalty };
    } else {
      // Advance to next active player
      const activeIdx = remainingActive.findIndex(p => p.uid === uid);
      const nextActivePlayer = remainingActive[0];

      const turnTimerSeconds = gData.turnTimerSeconds !== undefined ? parseInt(gData.turnTimerSeconds, 10) : 30;
      const nextTurnDeadline = turnTimerSeconds > 0 ? new Date(Date.now() + (turnTimerSeconds + 5) * 1000) : null;

      transaction.update(gameRef, {
        currentTurnPlayerId: nextActivePlayer.uid,
        turnNumber: (gData.turnNumber || 0) + 1,
        phase: 'DRAW_PHASE',
        turnDeadline: nextTurnDeadline ? admin.firestore.Timestamp.fromDate(nextTurnDeadline) : null,
        players,
        actionLog,
        lastActionAt: now,
      });

      return { success: true, message: `Dropped successfully (${penalty} pts).`, penalty };
    }
  });
});

/**
 * 8. declareGame
 * Declares 13 cards partitioned into melds.
 * Authoritative Indian Rummy validation:
 * - 1 pure sequence minimum
 * - 2 sequences minimum
 * - All cards valid
 */
exports.declareGame = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = context.auth.uid;
  const gameId = data.gameId;
  const discardCardIntVal = parseInt(data.discardCardIntVal, 10);
  const groupsData = data.groups; // Array of arrays of card objects or intVals

  if (!gameId || isNaN(discardCardIntVal) || !Array.isArray(groupsData)) {
    throw new functions.https.HttpsError('invalid-argument', 'Game ID, discard card, and card groups are required.');
  }

  const gameRef = db.collection('games').doc(gameId);
  const privateHandRef = gameRef.collection('privateHands').doc(uid);

  const gameDoc = await gameRef.get();
  if (!gameDoc.exists) throw new functions.https.HttpsError('not-found', 'Game not found.');

  const gData = gameDoc.data();
  if (gData.status !== 'IN_PROGRESS') {
    throw new functions.https.HttpsError('failed-precondition', 'Game is not active.');
  }
  if (gData.currentTurnPlayerId !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'It is not your turn to declare.');
  }
  if (gData.phase !== 'DISCARD_PHASE') {
    throw new functions.https.HttpsError('failed-precondition', 'Must draw before declaring.');
  }

  // Convert groups data to Card objects
  const groups = groupsData.map(group =>
    group.map(c => (typeof c === 'number' ? cardFromInt(c) : c))
  );

  const wildJoker = gData.openJoker;
  const valResult = validateDeclaration(groups, wildJoker);

  if (valResult.isValid) {
    // 🏆 VALID DECLARATION — WINNER!
    const finalResults = [];
    const allHandsSnap = await gameRef.collection('privateHands').get();

    for (const hDoc of allHandsSnap.docs) {
      const pUid = hDoc.id;
      const pHands = hDoc.data().cards || [];
      const pSummary = gData.players.find(p => p.uid === pUid);
      const isWinner = pUid === uid;

      let score = 0;
      if (!isWinner) {
        score = calculateLoserScore(pHands, wildJoker, 80);
      }

      finalResults.push({
        uid: pUid,
        displayName: pSummary ? pSummary.displayName : 'Player',
        photoURL: pSummary ? pSummary.photoURL : '',
        seatIndex: pSummary ? pSummary.seatIndex : 0,
        score,
        isWinner,
        declaredGroups: isWinner ? groups : null,
      });

      // Update user stats in users/{uid}
      try {
        const userRef = db.collection('users').doc(pUid);
        await userRef.set({
          stats: {
            gamesPlayed: admin.firestore.FieldValue.increment(1),
            gamesWon: admin.firestore.FieldValue.increment(isWinner ? 1 : 0),
            totalScore: admin.firestore.FieldValue.increment(score),
          },
        }, { merge: true });
      } catch (err) {
        console.error('Stats update error for', pUid, err);
      }
    }

    await gameRef.update({
      status: 'COMPLETED',
      winnerPlayerId: uid,
      finalResults,
      lastActionAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Also update table status
    if (gData.tableId) {
      await db.collection('tables').doc(gData.tableId).update({
        status: 'COMPLETED',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      isValid: true,
      message: 'Valid Declaration! You won the game with 0 points!',
      finalResults,
    };
  } else {
    // ❌ INVALID DECLARATION — WRONG SHOW (80 Points Penalty!)
    const updatedPlayers = gData.players.map(p => {
      if (p.uid === uid) {
        return { ...p, score: 80, status: 'WRONG_SHOW' };
      }
      return p;
    });

    // Discard the card and pass turn to next player
    const openPile = [...(gData.openPile || []), cardFromInt(discardCardIntVal)];
    const activePlayers = updatedPlayers.filter(p => p.status === 'ACTIVE');
    const nextPlayerId = activePlayers.length > 0 ? activePlayers[0].uid : uid;

    await gameRef.update({
      openPile,
      currentTurnPlayerId: nextPlayerId,
      phase: 'DRAW_PHASE',
      players: updatedPlayers,
      lastActionAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      isValid: false,
      message: `Invalid Declaration: ${valResult.errorMessage}. 80 points penalty applied.`,
      errorMessage: valResult.errorMessage,
    };
  }
});

/**
 * 9. updatePresence
 * Updates heartbeat and connection status for a player at a table.
 */
exports.updatePresence = functions.https.onCall(async (data, context) => {
  if (!context.auth) return { ok: false };
  const uid = context.auth.uid;
  const tableId = data.tableId;
  const connected = data.connected !== false;

  if (!tableId) return { ok: false };

  const tableRef = db.collection('tables').doc(tableId);
  const tableDoc = await tableRef.get();
  if (!tableDoc.exists) return { ok: false };

  const players = tableDoc.data().players || [];
  const updated = players.map(p => {
    if (p.uid === uid) {
      return { ...p, connected, lastSeenAt: new Date().toISOString() };
    }
    return p;
  });

  await tableRef.update({
    players: updated,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

/**
 * 10. createUserAccount
 * Profile completion + idempotent 5,000 initial virtual coins reward
 */
exports.createUserAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = context.auth.uid;
  const email = (context.auth.token.email || '').toLowerCase().trim();
  const name = (data.name || '').trim();
  const dateOfBirth = (data.dateOfBirth || '').trim();
  const country = (data.country || '').trim();

  if (!name || !dateOfBirth || !country) {
    throw new functions.https.HttpsError('invalid-argument', 'Name, Date of Birth, and Country are mandatory.');
  }

  const userRef = db.collection('users').doc(uid);
  const txId = `tx_init_${Date.now()}_${uid.substring(0, 6)}`;
  const txRef = db.collection('coinTransactions').doc(txId);
  const now = admin.firestore.FieldValue.serverTimestamp();

  return await db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    const existing = userDoc.exists ? userDoc.data() : null;

    const isAdmin = email.includes('vamsi') || email.includes('admin') || (existing && existing.role === 'ADMIN');
    const role = isAdmin ? 'ADMIN' : 'PLAYER';
    const isProfileComplete = true;

    // Check if initial reward was already granted
    const alreadyGranted = existing && (existing.lifetimeCoinsEarned || 0) > 0;
    const initialReward = alreadyGranted ? 0 : 5000;
    const currentCoins = existing ? (existing.coins || 0) : 0;
    const newCoins = currentCoins + initialReward;

    transaction.set(userRef, {
      uid,
      email,
      name,
      displayName: name,
      dateOfBirth,
      country,
      role,
      accountStatus: existing ? (existing.accountStatus || 'ACTIVE') : 'ACTIVE',
      coins: newCoins,
      lifetimeCoinsEarned: (existing ? (existing.lifetimeCoinsEarned || 0) : 0) + initialReward,
      lifetimeCoinsSpent: existing ? (existing.lifetimeCoinsSpent || 0) : 0,
      xp: existing ? (existing.xp || 0) : 0,
      currentTier: existing ? (existing.currentTier || 'BRONZE') : 'BRONZE',
      currentLevelIndex: existing ? (existing.currentLevelIndex || 1) : 1,
      currentLevel: existing ? (existing.currentLevel || 'Bronze I') : 'Bronze I',
      loginStreak: existing ? (existing.loginStreak || 1) : 1,
      lastRewardDate: existing ? existing.lastRewardDate : null,
      isProfileComplete,
      gamesPlayed: existing ? (existing.gamesPlayed || 0) : 0,
      gamesWon: existing ? (existing.gamesWon || 0) : 0,
      gamesLost: existing ? (existing.gamesLost || 0) : 0,
      createdAt: existing ? existing.createdAt : now,
      updatedAt: now,
      lastActiveAt: now,
    }, { merge: true });

    if (initialReward > 0) {
      transaction.set(txRef, {
        transactionId: txId,
        uid,
        type: 'INITIAL_ACCOUNT_REWARD',
        amount: initialReward,
        balanceBefore: currentCoins,
        balanceAfter: newCoins,
        referenceId: 'welcome_bonus',
        reason: 'Welcome bonus for completing player profile registration',
        createdAt: now,
        createdBy: 'system',
      });
    }

    return {
      success: true,
      coins: newCoins,
      role,
      initialRewardGranted: initialReward > 0,
    };
  });
});

/**
 * 11. claimDailyReward
 * 7-Day login streak claim with UTC validation
 */
exports.claimDailyReward = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = context.auth.uid;
  const userRef = db.collection('users').doc(uid);
  const now = new Date();
  const todayUtc = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));

  const schedule = [
    { day: 1, coins: 100, xp: 50 },
    { day: 2, coins: 150, xp: 75 },
    { day: 3, coins: 200, xp: 100 },
    { day: 4, coins: 300, xp: 150 },
    { day: 5, coins: 400, xp: 200 },
    { day: 6, coins: 600, xp: 300 },
    { day: 7, coins: 1000, xp: 500 },
  ];

  return await db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) throw new functions.https.HttpsError('not-found', 'User not found.');

    const u = userDoc.data();
    if (u.accountStatus === 'BLOCKED' || u.accountStatus === 'SUSPENDED') {
      throw new functions.https.HttpsError('permission-denied', 'Account is suspended or blocked.');
    }

    let lastReward = null;
    if (u.lastRewardDate) {
      const parsed = new Date(u.lastRewardDate);
      lastReward = new Date(Date.UTC(parsed.getUTCFullYear(), parsed.getUTCMonth(), parsed.getUTCDate()));
    }

    let streak = u.loginStreak || 1;
    if (lastReward) {
      const diffDays = Math.floor((todayUtc.getTime() - lastReward.getTime()) / (1000 * 60 * 60 * 24));
      if (diffDays === 0) {
        throw new functions.https.HttpsError('already-exists', 'Daily reward has already been claimed today.');
      } else if (diffDays === 1) {
        streak = (streak % 7) + 1;
      } else {
        streak = 1;
      }
    }

    const reward = schedule[streak - 1];
    const currentCoins = u.coins || 0;
    const newCoins = currentCoins + reward.coins;
    const newXp = (u.xp || 0) + reward.xp;

    const txId = `tx_daily_${Date.now()}_${uid.substring(0, 6)}`;
    const txRef = db.collection('coinTransactions').doc(txId);
    const serverNow = admin.firestore.FieldValue.serverTimestamp();

    transaction.update(userRef, {
      coins: newCoins,
      lifetimeCoinsEarned: (u.lifetimeCoinsEarned || 0) + reward.coins,
      xp: newXp,
      loginStreak: streak,
      lastRewardDate: todayUtc.toISOString(),
      updatedAt: serverNow,
    });

    transaction.set(txRef, {
      transactionId: txId,
      uid,
      type: 'DAILY_LOGIN_REWARD',
      amount: reward.coins,
      balanceBefore: currentCoins,
      balanceAfter: newCoins,
      referenceId: `day_${streak}`,
      reason: `Day ${streak} Daily Streak Reward`,
      createdAt: serverNow,
      createdBy: 'system',
    });

    return {
      success: true,
      day: streak,
      coinsEarned: reward.coins,
      xpEarned: reward.xp,
      newBalance: newCoins,
    };
  });
});

/**
 * 12. adminAdjustCoins
 * Authoritative admin coin adjustments
 */
exports.adminAdjustCoins = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Admin authentication required.');
  }

  const adminUid = context.auth.uid;
  const adminEmail = (context.auth.token.email || '').toLowerCase();
  const isAdmin = adminEmail.includes('vamsi') || adminEmail.includes('admin') || context.auth.token.role === 'ADMIN';

  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Administrative privileges required.');
  }

  const targetUid = data.targetUid;
  const amount = parseInt(data.amount, 10);
  const reason = (data.reason || '').trim();

  if (!targetUid || isNaN(amount) || amount === 0 || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid, non-zero amount, and audit reason are required.');
  }

  const targetRef = db.collection('users').doc(targetUid);
  const txId = `tx_admin_${Date.now()}_${targetUid.substring(0, 6)}`;
  const txRef = db.collection('coinTransactions').doc(txId);
  const auditId = `audit_${Date.now()}`;
  const auditRef = db.collection('adminAuditLogs').doc(auditId);
  const now = admin.firestore.FieldValue.serverTimestamp();

  return await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(targetRef);
    if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Target user does not exist.');

    const targetData = snap.data();
    const currentBalance = targetData.coins || 0;
    const newBalance = currentBalance + amount;

    if (newBalance < 0) {
      throw new functions.https.HttpsError('failed-precondition', 'Adjustment would produce negative balance.');
    }

    transaction.update(targetRef, {
      coins: newBalance,
      updatedAt: now,
    });

    transaction.set(txRef, {
      transactionId: txId,
      uid: targetUid,
      type: amount > 0 ? 'ADMIN_CREDIT' : 'ADMIN_DEBIT',
      amount,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      referenceId: 'admin_action',
      reason: `${reason} (Admin: ${adminEmail})`,
      createdAt: now,
      createdBy: adminUid,
    });

    transaction.set(auditRef, {
      auditId,
      adminUid,
      adminEmail,
      targetUid,
      action: amount > 0 ? 'ADMIN_CREDIT' : 'ADMIN_DEBIT',
      amount,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      reason,
      timestamp: now,
    });

    return { success: true, newBalance };
  });
});

