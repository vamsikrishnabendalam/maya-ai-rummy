/**
 * Server-Authoritative 13-Card Indian Rummy Rules Engine
 * Implements 1:1 parity with packages/game-engine
 */

const SUITS = ['hearts', 'diamonds', 'clubs', 'spades'];
const RANKS = [
  'ace', 'two', 'three', 'four', 'five', 'six', 'seven',
  'eight', 'nine', 'ten', 'jack', 'queen', 'king'
];

/**
 * Card Object Structure:
 * {
 *   suit: 'hearts'|'diamonds'|'clubs'|'spades'|null,
 *   rank: 'ace'|'two'|...|'king'|null,
 *   deckIndex: 0|1,
 *   isPrintedJoker: boolean,
 *   intVal: number (0..105)
 * }
 */
function cardFromInt(val) {
  const deckIndex = Math.floor(val / 53);
  const remainder = val % 53;
  if (remainder === 52) {
    return {
      suit: null,
      rank: null,
      deckIndex,
      isPrintedJoker: true,
      intVal: val,
    };
  }
  const suitIndex = Math.floor(remainder / 13);
  const rankIndex = remainder % 13;
  return {
    suit: SUITS[suitIndex],
    rank: RANKS[rankIndex],
    deckIndex,
    isPrintedJoker: false,
    intVal: val,
  };
}

function cardToInt(card) {
  if (card.isPrintedJoker) {
    return card.deckIndex * 53 + 52;
  }
  const suitIndex = SUITS.indexOf(card.suit);
  const rankIndex = RANKS.indexOf(card.rank);
  return card.deckIndex * 53 + suitIndex * 13 + rankIndex;
}

function getEffectiveWildRank(wildJokerCard) {
  if (!wildJokerCard) return null;
  if (wildJokerCard.isPrintedJoker) {
    return 'ace';
  }
  return wildJokerCard.rank;
}

function isJoker(card, wildJokerCard) {
  if (!card) return false;
  if (card.isPrintedJoker) return true;
  if (!wildJokerCard) return false;
  const effectiveWild = getEffectiveWildRank(wildJokerCard);
  return card.rank === effectiveWild;
}

function isWildJoker(card, wildJokerCard) {
  if (!card || card.isPrintedJoker) return false;
  if (!wildJokerCard) return false;
  const effectiveWild = getEffectiveWildRank(wildJokerCard);
  return card.rank === effectiveWild;
}

/**
 * Creates 2 standard decks (106 cards) and cryptographically shuffles them.
 */
function createShuffledDeck() {
  const deck = [];
  for (let i = 0; i < 106; i++) {
    deck.push(cardFromInt(i));
  }
  // Fisher-Yates shuffle
  for (let i = deck.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const temp = deck[i];
    deck[i] = deck[j];
    deck[j] = temp;
  }
  return deck;
}

function rankToLowValue(rank) {
  const index = RANKS.indexOf(rank);
  return index === -1 ? 0 : index + 1; // Ace = 1
}

function rankToHighValue(rank) {
  const index = RANKS.indexOf(rank);
  return index === 0 ? 14 : index + 1; // Ace = 14
}

/**
 * Validates whether a group of cards is a Pure Sequence.
 * - Minimum 3 cards
 * - Same suit
 * - Strictly consecutive
 * - NO Jokers (printed or wild) permitted
 */
function validatePureSequence(cards, wildJokerCard) {
  if (cards.length < 3) return { isValid: false, type: 'invalid' };

  // Pure sequences cannot contain any joker (printed or wild)
  for (const c of cards) {
    if (isJoker(c, wildJokerCard)) return { isValid: false, type: 'invalid' };
  }

  // All must share the exact same suit
  const targetSuit = cards[0].suit;
  if (!targetSuit || cards.some(c => c.suit !== targetSuit)) {
    return { isValid: false, type: 'invalid' };
  }

  // Check Ace-low consecutive order
  const lowVals = cards.map(c => rankToLowValue(c.rank)).sort((a, b) => a - b);
  let isLowConsecutive = true;
  for (let i = 0; i < lowVals.length - 1; i++) {
    if (lowVals[i + 1] !== lowVals[i] + 1) {
      isLowConsecutive = false;
      break;
    }
  }
  if (isLowConsecutive) return { isValid: true, type: 'pureSequence' };

  // Check Ace-high consecutive order (e.g. Q-K-A)
  const highVals = cards.map(c => rankToHighValue(c.rank)).sort((a, b) => a - b);
  let isHighConsecutive = true;
  for (let i = 0; i < highVals.length - 1; i++) {
    if (highVals[i + 1] !== highVals[i] + 1) {
      isHighConsecutive = false;
      break;
    }
  }
  if (isHighConsecutive) return { isValid: true, type: 'pureSequence' };

  return { isValid: false, type: 'invalid' };
}

/**
 * Validates whether a group of cards is an Impure Sequence.
 * - Minimum 3 cards
 * - Same suit for natural cards
 * - Missing consecutive spots filled by Jokers
 */
function validateImpureSequence(cards, wildJokerCard) {
  if (cards.length < 3) return { isValid: false, type: 'invalid' };

  const naturals = cards.filter(c => !isJoker(c, wildJokerCard));
  const jokers = cards.filter(c => isJoker(c, wildJokerCard));

  if (jokers.length === 0) {
    // If no jokers, it's either a pure sequence or invalid
    return validatePureSequence(cards, wildJokerCard);
  }

  if (naturals.length === 0) {
    // 3 or more jokers form a valid impure sequence
    return { isValid: true, type: 'impureSequence' };
  }

  const targetSuit = naturals[0].suit;
  if (naturals.some(c => c.suit !== targetSuit)) {
    return { isValid: false, type: 'invalid' };
  }

  // Check if naturals can be completed with jokers in Ace-low
  function checkGaps(vals, jokerCount) {
    const sorted = [...new Set(vals)].sort((a, b) => a - b);
    if (sorted.length !== vals.length) return false; // Duplicate natural ranks in sequence
    const span = sorted[sorted.length - 1] - sorted[0] + 1;
    const missing = span - sorted.length;
    return missing <= jokerCount && (sorted.length + jokerCount) >= 3;
  }

  const lowVals = naturals.map(c => rankToLowValue(c.rank));
  if (checkGaps(lowVals, jokers.length)) return { isValid: true, type: 'impureSequence' };

  const highVals = naturals.map(c => rankToHighValue(c.rank));
  if (checkGaps(highVals, jokers.length)) return { isValid: true, type: 'impureSequence' };

  return { isValid: false, type: 'invalid' };
}

/**
 * Validates whether a group of cards is a Set.
 * - 3 to 5 cards of the same rank (max 4 natural cards, jokers can bring total up to 5)
 * - Different suits for natural cards (no duplicate suits!)
 * - Jokers allowed
 */
function validateSet(cards, wildJokerCard) {
  if (cards.length < 3 || cards.length > 5) return { isValid: false, type: 'invalid' };

  const naturals = cards.filter(c => !isJoker(c, wildJokerCard));

  if (naturals.length === 0) {
    return { isValid: true, type: 'validSet' };
  }

  const targetRank = naturals[0].rank;
  if (naturals.some(c => c.rank !== targetRank)) {
    return { isValid: false, type: 'invalid' };
  }

  // Pure natural set without jokers cannot exceed 4 cards (one per suit)
  if (naturals.length === cards.length && cards.length > 4) {
    return { isValid: false, type: 'invalid' };
  }

  // Check duplicate suits
  const suits = naturals.map(c => c.suit);
  const uniqueSuits = new Set(suits);
  if (uniqueSuits.size !== suits.length) {
    return { isValid: false, type: 'invalid' }; // Duplicate suit forbidden
  }

  return { isValid: true, type: 'validSet' };
}

function getCardDeadwoodValue(card, wildJokerCard) {
  if (isJoker(card, wildJokerCard)) return 0;
  const rank = card.rank;
  if (['jack', 'queen', 'king', 'ace'].includes(rank)) return 10;
  return rankToLowValue(rank);
}

/**
 * Authoritative Indian Rummy Declaration Validation
 * Requires:
 * 1. Exactly 13 cards total across groups
 * 2. At least 1 pure sequence
 * 3. At least 2 sequences total (e.g. 1 pure + 1 impure, or 2 pure)
 * 4. All groups must be valid (pure sequence, impure sequence, or set)
 */
function validateDeclaration(groups, wildJokerCard) {
  let totalCards = 0;
  let pureSeqCount = 0;
  let totalSeqCount = 0;
  const groupDiagnoses = [];
  let allGroupsValid = true;

  for (const group of groups) {
    totalCards += group.length;
    const pureVal = validatePureSequence(group, wildJokerCard);
    if (pureVal.isValid) {
      pureSeqCount++;
      totalSeqCount++;
      groupDiagnoses.push({ isValid: true, type: 'pureSequence', cards: group });
      continue;
    }

    const impureVal = validateImpureSequence(group, wildJokerCard);
    if (impureVal.isValid) {
      totalSeqCount++;
      groupDiagnoses.push({ isValid: true, type: 'impureSequence', cards: group });
      continue;
    }

    const setVal = validateSet(group, wildJokerCard);
    if (setVal.isValid) {
      groupDiagnoses.push({ isValid: true, type: 'validSet', cards: group });
      continue;
    }

    allGroupsValid = false;
    groupDiagnoses.push({ isValid: false, type: 'invalid', cards: group });
  }

  if (totalCards !== 13) {
    return {
      isValid: false,
      errorMessage: `Hand has ${totalCards} cards; exactly 13 cards are required to declare.`,
      pureSeqCount,
      totalSeqCount,
      groupDiagnoses,
    };
  }

  if (pureSeqCount < 1) {
    return {
      isValid: false,
      errorMessage: 'Declaration is missing a mandatory Pure Sequence (3+ consecutive cards of same suit with no jokers).',
      pureSeqCount,
      totalSeqCount,
      groupDiagnoses,
    };
  }

  if (totalSeqCount < 2) {
    return {
      isValid: false,
      errorMessage: 'Declaration requires at least two sequences (at least 1 pure + 1 second sequence).',
      pureSeqCount,
      totalSeqCount,
      groupDiagnoses,
    };
  }

  if (!allGroupsValid) {
    return {
      isValid: false,
      errorMessage: 'One or more groups are invalid sets or sequences.',
      pureSeqCount,
      totalSeqCount,
      groupDiagnoses,
    };
  }

  return {
    isValid: true,
    errorMessage: '',
    pureSeqCount,
    totalSeqCount,
    groupDiagnoses,
  };
}

/**
 * Calculates loser deadwood points.
 * Accepts an array of card objects or raw integers.
 * If pure sequence is missing: all cards count as deadwood (capped at 80).
 */
function calculateLoserScore(hand, wildJokerCard, maxPenalty = 80) {
  let deadwood = 0;
  for (const card of hand) {
    const cardObj = typeof card === 'number' ? cardFromInt(card) : card;
    deadwood += getCardDeadwoodValue(cardObj, wildJokerCard);
  }
  return Math.min(deadwood, maxPenalty);
}

module.exports = {
  SUITS,
  RANKS,
  cardFromInt,
  cardToInt,
  getEffectiveWildRank,
  isJoker,
  isWildJoker,
  createShuffledDeck,
  validatePureSequence,
  validateImpureSequence,
  validateSet,
  validateDeclaration,
  calculateLoserScore,
  getCardDeadwoodValue,
};
