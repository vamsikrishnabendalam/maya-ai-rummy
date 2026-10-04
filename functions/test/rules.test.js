const assert = require('assert');
const {
  cardFromInt,
  cardToInt,
  getEffectiveWildRank,
  isJoker,
  validatePureSequence,
  validateImpureSequence,
  validateSet,
  validateDeclaration,
  createShuffledDeck,
} = require('../engine/rummyRules');

console.log('Testing Server Rummy Engine...');

// 1. Test Card Serialization
const c1 = cardFromInt(0); // Deck 0, Hearts, Ace
assert.strictEqual(c1.suit, 'hearts');
assert.strictEqual(c1.rank, 'ace');
assert.strictEqual(c1.deckIndex, 0);
assert.strictEqual(c1.isPrintedJoker, false);
assert.strictEqual(cardToInt(c1), 0);

// 2. Printed Joker serialization
const pj = cardFromInt(52); // Deck 0 Printed Joker
assert.strictEqual(pj.isPrintedJoker, true);
assert.strictEqual(cardToInt(pj), 52);

// 3. Shuffled Deck length
const deck = createShuffledDeck();
assert.strictEqual(deck.length, 106);

// 4. Wild Joker resolution: printed cut -> Ace is wild
assert.strictEqual(getEffectiveWildRank(pj), 'ace');

// 5. Pure sequence
const wildJoker = cardFromInt(1); // 2 of hearts -> Two is wild
const pureSeq = [
  { suit: 'spades', rank: 'four', isPrintedJoker: false },
  { suit: 'spades', rank: 'five', isPrintedJoker: false },
  { suit: 'spades', rank: 'six', isPrintedJoker: false },
];
assert.strictEqual(validatePureSequence(pureSeq, wildJoker).isValid, true);

// Pure sequence with wild joker (Two of spades) is INVALID as pure sequence
const invalidPure = [
  { suit: 'spades', rank: 'four', isPrintedJoker: false },
  { suit: 'spades', rank: 'five', isPrintedJoker: false },
  { suit: 'spades', rank: 'two', isPrintedJoker: false }, // wild joker!
];
assert.strictEqual(validatePureSequence(invalidPure, wildJoker).isValid, false);

// 6. Impure sequence with joker
const impureSeq = [
  { suit: 'spades', rank: 'four', isPrintedJoker: false },
  { suit: 'spades', rank: 'five', isPrintedJoker: false },
  { suit: 'diamonds', rank: 'two', isPrintedJoker: false }, // wild joker acting as 6 of spades
];
assert.strictEqual(validateImpureSequence(impureSeq, wildJoker).isValid, true);

// 7. Set validation (valid set)
const validSet = [
  { suit: 'hearts', rank: 'seven', isPrintedJoker: false },
  { suit: 'diamonds', rank: 'seven', isPrintedJoker: false },
  { suit: 'clubs', rank: 'seven', isPrintedJoker: false },
];
assert.strictEqual(validateSet(validSet, wildJoker).isValid, true);

// Duplicate suit in set -> INVALID
const dupSet = [
  { suit: 'hearts', rank: 'seven', isPrintedJoker: false },
  { suit: 'hearts', rank: 'seven', isPrintedJoker: false },
  { suit: 'clubs', rank: 'seven', isPrintedJoker: false },
];
assert.strictEqual(validateSet(dupSet, wildJoker).isValid, false);

// 8. Full 13-Card Valid Declaration
const fullGroups = [
  // Pure sequence (3 cards)
  [
    { suit: 'hearts', rank: 'four', isPrintedJoker: false },
    { suit: 'hearts', rank: 'five', isPrintedJoker: false },
    { suit: 'hearts', rank: 'six', isPrintedJoker: false },
  ],
  // Impure sequence (3 cards)
  [
    { suit: 'spades', rank: 'seven', isPrintedJoker: false },
    { suit: 'spades', rank: 'eight', isPrintedJoker: false },
    { suit: 'diamonds', rank: 'two', isPrintedJoker: false }, // wild joker
  ],
  // Set (3 cards)
  [
    { suit: 'hearts', rank: 'king', isPrintedJoker: false },
    { suit: 'diamonds', rank: 'king', isPrintedJoker: false },
    { suit: 'clubs', rank: 'king', isPrintedJoker: false },
  ],
  // Set (4 cards)
  [
    { suit: 'hearts', rank: 'nine', isPrintedJoker: false },
    { suit: 'diamonds', rank: 'nine', isPrintedJoker: false },
    { suit: 'clubs', rank: 'nine', isPrintedJoker: false },
    { suit: 'spades', rank: 'nine', isPrintedJoker: false },
  ],
];
const decRes = validateDeclaration(fullGroups, wildJoker);
assert.strictEqual(decRes.isValid, true);
assert.strictEqual(decRes.pureSeqCount, 1);
assert.strictEqual(decRes.totalSeqCount, 2);

console.log('✅ All Server Rummy Engine Unit Tests Passed!');
