import React, { useState, useEffect, useMemo, useRef } from 'react';
import { 
  Trophy, 
  Volume2, 
  VolumeX, 
  HelpCircle, 
  RotateCcw, 
  Layers, 
  Sparkles, 
  History, 
  CheckCircle2, 
  AlertTriangle, 
  XCircle, 
  ChevronLeft, 
  ChevronRight, 
  Plus, 
  Flag, 
  Send, 
  Crown, 
  Coins, 
  Clock, 
  ShieldAlert,
  Eye,
  Wand2,
  X
} from 'lucide-react';

// ==========================================
// CONSTANTS & CARD DEFINITIONS
// ==========================================
const SUITS = [
  { id: 'S', symbol: '♠', name: 'Spades', color: 'text-slate-900', bg: 'bg-slate-100' },
  { id: 'H', symbol: '♥', name: 'Hearts', color: 'text-rose-600', bg: 'bg-rose-50' },
  { id: 'D', symbol: '♦', name: 'Diamonds', color: 'text-rose-600', bg: 'bg-rose-50' },
  { id: 'C', symbol: '♣', name: 'Clubs', color: 'text-slate-900', bg: 'bg-slate-100' },
];

const RANKS = [
  { rank: 'A', value: 1, highValue: 14, points: 10 },
  { rank: '2', value: 2, points: 2 },
  { rank: '3', value: 3, points: 3 },
  { rank: '4', value: 4, points: 4 },
  { rank: '5', value: 5, points: 5 },
  { rank: '6', value: 6, points: 6 },
  { rank: '7', value: 7, points: 7 },
  { rank: '8', value: 8, points: 8 },
  { rank: '9', value: 9, points: 9 },
  { rank: '10', value: 10, points: 10 },
  { rank: 'J', value: 11, points: 10 },
  { rank: 'Q', value: 12, points: 10 },
  { rank: 'K', value: 13, points: 10 },
];

const INITIAL_OPPONENTS = [
  { id: 1, name: 'Vikramaditya', avatar: '👑', chips: 24500, cards: 13, position: 'mid-left', status: 'Playing', lastAction: 'Waiting' },
  { id: 2, name: 'Ananya S.', avatar: '🌸', chips: 18200, cards: 13, position: 'top-left', status: 'Playing', lastAction: 'Waiting' },
  { id: 3, name: 'Rajesh_99', avatar: '🦁', chips: 52100, cards: 13, position: 'top', status: 'Playing', lastAction: 'Waiting' },
  { id: 4, name: 'Priya_K', avatar: '💎', chips: 12950, cards: 13, position: 'top-right', status: 'Playing', lastAction: 'Waiting' },
  { id: 5, name: 'Kabir Khan', avatar: '⚡', chips: 31400, cards: 13, position: 'mid-right', status: 'Playing', lastAction: 'Waiting' },
];

// Create a full 2-deck + 2 Printed Jokers shoe (106 cards)
const createShoe = () => {
  const shoe = [];
  let uid = 1;
  for (let d = 1; d <= 2; d++) {
    for (const suit of SUITS) {
      for (const r of RANKS) {
        shoe.push({
          id: `card_${uid++}`,
          deck: d,
          suit: suit.id,
          suitSymbol: suit.symbol,
          color: suit.color,
          rank: r.rank,
          value: r.value,
          points: r.points,
          isPrintedJoker: false,
        });
      }
    }
    shoe.push({
      id: `card_${uid++}`,
      deck: d,
      suit: 'JOKER',
      suitSymbol: '🃏',
      color: 'text-purple-700',
      rank: 'JOKER',
      value: 0,
      points: 0,
      isPrintedJoker: true,
    });
  }
  // Fisher-Yates shuffle
  for (let i = shoe.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shoe[i], shoe[j]] = [shoe[j], shoe[i]];
  }
  return shoe;
};

// Curated preset deal so the user immediately sees Pure Sequence, Impure Sequence, Set & Loose cards
const createCuratedDeal = () => {
  const fullShoe = createShoe();
  const wildRank = '7';
  const wildCard = fullShoe.find(c => c.rank === '7' && c.suit === 'D') || fullShoe[0];

  const pickCard = (rank, suit) => {
    const idx = fullShoe.findIndex(c => c.rank === rank && c.suit === suit && c.id !== wildCard.id);
    if (idx !== -1) return fullShoe.splice(idx, 1)[0];
    return fullShoe.pop();
  };

  // Group 1: Pure Sequence (4♠, 5♠, 6♠)
  const g1 = [pickCard('4', 'S'), pickCard('5', 'S'), pickCard('6', 'S')];
  // Group 2: Impure Sequence (9♥, 7♠ [Wild], J♥, Q♥)
  const g2 = [pickCard('9', 'H'), pickCard('7', 'S'), pickCard('J', 'H'), pickCard('Q', 'H')];
  // Group 3: Valid Set (K♠, K♥, K♣)
  const g3 = [pickCard('K', 'S'), pickCard('K', 'H'), pickCard('K', 'C')];
  // Group 4: Nearly complete sequence (A♦, 2♦, 8♣)
  const g4 = [pickCard('A', 'D'), pickCard('2', 'D'), pickCard('8', 'C')];

  const openTop = pickCard('3', 'D'); // Perfect card for the user to pick from Open Deck!
  const remainingShoe = fullShoe.filter(c => c.id !== wildCard.id);

  return {
    groups: [g1, g2, g3, g4],
    wildCard,
    openDeck: [openTop],
    closedDeck: remainingShoe.slice(0, 52),
  };
};

// ==========================================
// MELD VALIDATION ENGINE (INDIAN 13-CARD RUMMY)
// ==========================================
const isCardWild = (card, wildRank) => {
  if (!card) return false;
  if (card.isPrintedJoker) return true;
  if (wildRank === 'JOKER' && card.rank === 'A') return true;
  return card.rank === wildRank;
};

// Evaluates a single group of cards and returns its type:
// 'PURE_SEQ' | 'IMPURE_SEQ' | 'SET' | 'INVALID'
const evaluateGroup = (group, wildRank) => {
  if (!group || group.length < 3) {
    return { type: 'INVALID', label: 'Min 3 Cards', points: calcDeadwood(group, wildRank) };
  }

  // 1. Check Pure Sequence (No wild cards used as substitutes; wild card can act as its natural rank/suit)
  const checkContiguousSameSuit = (cards, allowWildCount = 0) => {
    const suit = cards[0].suit;
    if (!cards.every(c => c.suit === suit && !c.isPrintedJoker)) return false;

    const tryValues = (useHighAce) => {
      const vals = cards.map(c => (useHighAce && c.rank === 'A' ? 14 : c.value)).sort((a, b) => a - b);
      // Check for duplicate ranks
      for (let i = 1; i < vals.length; i++) {
        if (vals[i] === vals[i - 1]) return false;
      }
      let gaps = 0;
      for (let i = 1; i < vals.length; i++) {
        gaps += vals[i] - vals[i - 1] - 1;
      }
      return gaps <= allowWildCount;
    };

    return tryValues(false) || tryValues(true);
  };

  if (checkContiguousSameSuit(group, 0)) {
    return { type: 'PURE_SEQ', label: 'Pure Sequence', points: 0 };
  }

  // 2. Check Impure Sequence (With Jokers / Wilds)
  const wilds = group.filter(c => isCardWild(c, wildRank));
  const naturals = group.filter(c => !isCardWild(c, wildRank));

  if (naturals.length === 0) {
    return { type: 'PURE_SEQ', label: 'Joker Sequence', points: 0 };
  }

  const allSameNaturalSuit = naturals.every(c => c.suit === naturals[0].suit);
  if (allSameNaturalSuit && wilds.length > 0) {
    const tryImpure = (useHighAce) => {
      const vals = naturals.map(c => (useHighAce && c.rank === 'A' ? 14 : c.value)).sort((a, b) => a - b);
      for (let i = 1; i < vals.length; i++) {
        if (vals[i] === vals[i - 1]) return false;
      }
      let gaps = 0;
      for (let i = 1; i < vals.length; i++) {
        gaps += vals[i] - vals[i - 1] - 1;
      }
      return gaps <= wilds.length;
    };
    if (tryImpure(false) || tryImpure(true)) {
      return { type: 'IMPURE_SEQ', label: 'Impure Sequence', points: 0 };
    }
  }

  // 3. Check Valid Set (3 or 4 cards of same rank, distinct suits, jokers allowed)
  if (group.length >= 3 && group.length <= 4) {
    if (naturals.length > 0) {
      const targetRank = naturals[0].rank;
      const sameRank = naturals.every(c => c.rank === targetRank);
      const uniqueSuits = new Set(naturals.map(c => c.suit));
      if (sameRank && uniqueSuits.size === naturals.length) {
        return { type: 'SET', label: 'Valid Set', points: 0 };
      }
    }
  }

  return { type: 'INVALID', label: 'Invalid Group', points: calcDeadwood(group, wildRank) };
};

const calcDeadwood = (group, wildRank) => {
  return group.reduce((sum, card) => {
    if (isCardWild(card, wildRank)) return sum;
    return sum + card.points;
  }, 0);
};

// Evaluates entire hand according to Indian 13-card Rummy rules:
// - Must have at least 1 Pure Sequence (1st Life)
// - Must have at least 2 Sequences total (1st Life + 2nd Life)
const evaluateFullHand = (groups, wildRank) => {
  const evals = groups.map(g => evaluateGroup(g, wildRank));
  const pureCount = evals.filter(e => e.type === 'PURE_SEQ').length;
  const impureCount = evals.filter(e => e.type === 'IMPURE_SEQ').length;
  const totalSequences = pureCount + impureCount;

  const hasFirstLife = pureCount >= 1;
  const hasSecondLife = totalSequences >= 2 && hasFirstLife;

  let totalPenaltyPoints = 0;
  const enhancedEvals = evals.map((ev, idx) => {
    const groupCards = groups[idx];
    const rawPts = calcDeadwood(groupCards, wildRank);

    if (ev.type === 'PURE_SEQ') {
      return { ...ev, statusColor: 'emerald', validInContext: true, penalty: 0 };
    }
    if (ev.type === 'IMPURE_SEQ') {
      if (hasFirstLife) {
        return { ...ev, statusColor: 'amber', validInContext: true, penalty: 0 };
      } else {
        totalPenaltyPoints += rawPts;
        return { ...ev, label: 'Impure Seq (1st Life Needed)', statusColor: 'rose', validInContext: false, penalty: rawPts };
      }
    }
    if (ev.type === 'SET') {
      if (hasFirstLife && hasSecondLife) {
        return { ...ev, statusColor: 'sky', validInContext: true, penalty: 0 };
      } else {
        totalPenaltyPoints += rawPts;
        return {
          ...ev,
          label: !hasFirstLife ? 'Set (1st Life Needed)' : 'Set (2nd Life Needed)',
          statusColor: 'rose',
          validInContext: false,
          penalty: rawPts,
        };
      }
    }
    totalPenaltyPoints += rawPts;
    return { ...ev, label: `Invalid (${rawPts} pts)`, statusColor: 'rose', validInContext: false, penalty: rawPts };
  });

  const cappedPoints = Math.min(80, totalPenaltyPoints);
  const isReadyToDeclare = enhancedEvals.every(e => e.validInContext) && groups.flat().length === 13;

  return {
    groupEvals: enhancedEvals,
    hasFirstLife,
    hasSecondLife,
    penaltyPoints: cappedPoints,
    isReadyToDeclare,
  };
};

// ==========================================
// PLAYING CARD COMPONENT
// ==========================================
const PlayingCard = ({
  card,
  wildRank,
  selected = false,
  onClick,
  size = 'normal',
  overlapClass = '',
  rotation = 0,
  liftY = 0,
  isNewlyDrawn = false,
}) => {
  if (!card) return null;
  const isWild = isCardWild(card, wildRank);

  const sizeStyles = {
    small: 'w-14 h-20 rounded-lg text-xs',
    normal: 'w-16 h-24 sm:w-20 sm:h-28 md:w-[86px] md:h-[124px] rounded-xl',
    deck: 'w-16 h-24 sm:w-20 sm:h-28 rounded-xl',
  };

  return (
    <div
      onClick={onClick}
      style={{
        transform: `translateY(${selected ? -18 : liftY}px) rotate(${rotation}deg)`,
      }}
      className={`
        relative select-none cursor-pointer transition-all duration-200 ease-out
        bg-gradient-to-br from-white via-stone-50 to-stone-200
        border ${selected ? 'border-amber-400 ring-2 ring-amber-400/80 z-30 shadow-[0_12px_25px_rgba(251,191,36,0.45)]' : 'border-stone-300/90 shadow-[0_6px_14px_rgba(0,0,0,0.45)] hover:-translate-y-2 hover:border-amber-200/80'}
        ${sizeStyles[size]} ${overlapClass} flex flex-col justify-between p-1.5 sm:p-2 overflow-hidden group
      `}
    >
      {/* Subtle glossy card highlight */}
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-tr from-transparent via-white/40 to-white/70 opacity-60" />

      {/* Newly drawn highlight pulse */}
      {isNewlyDrawn && (
        <span className="absolute top-1 right-1 px-1 py-0.5 text-[8px] font-bold uppercase tracking-wider bg-emerald-500 text-white rounded shadow">
          New
        </span>
      )}

      {/* Top-left index */}
      <div className={`relative z-10 flex flex-col items-center leading-none w-5 ${card.color}`}>
        <span className="font-extrabold text-sm sm:text-base md:text-lg tracking-tighter">
          {card.isPrintedJoker ? '★' : card.rank}
        </span>
        <span className="text-xs sm:text-sm -mt-0.5">{card.suitSymbol}</span>
      </div>

      {/* Center Watermark Pip */}
      <div className={`relative z-10 flex items-center justify-center my-auto ${card.color}`}>
        {card.isPrintedJoker ? (
          <div className="flex flex-col items-center">
            <span className="text-2xl sm:text-3xl drop-shadow-sm">🃏</span>
            <span className="text-[8px] font-black tracking-widest text-purple-800 uppercase">Joker</span>
          </div>
        ) : (
          <span className="text-2xl sm:text-4xl opacity-90 drop-shadow-sm transform group-hover:scale-110 transition-transform">
            {card.suitSymbol}
          </span>
        )}
      </div>

      {/* Wild Joker Cap / Badge */}
      {isWild && (
        <div
          title="Wild Joker"
          className="absolute bottom-1.5 left-1.5 z-20 flex items-center gap-0.5 bg-gradient-to-r from-amber-500 to-yellow-400 text-slate-950 px-1.5 py-0.5 rounded-full shadow-md border border-amber-200"
        >
          <Crown className="w-2.5 h-2.5 fill-slate-950" />
          <span className="text-[8px] sm:text-[9px] font-black tracking-tighter uppercase">JOKER</span>
        </div>
      )}

      {/* Bottom-right inverted index */}
      <div className={`relative z-10 flex flex-col items-center leading-none self-end rotate-180 w-5 ${card.color}`}>
        <span className="font-extrabold text-sm sm:text-base md:text-lg tracking-tighter">
          {card.isPrintedJoker ? '★' : card.rank}
        </span>
        <span className="text-xs sm:text-sm -mt-0.5">{card.suitSymbol}</span>
      </div>
    </div>
  );
};

// ==========================================
// MAIN RUMMY TABLE APPLICATION
// ==========================================
export default function App() {
  // Game State
  const initialDeal = useMemo(() => createCuratedDeal(), []);
  const [groups, setGroups] = useState(initialDeal.groups);
  const [wildCard, setWildCard] = useState(initialDeal.wildCard);
  const [openDeck, setOpenDeck] = useState(initialDeal.openDeck);
  const [closedDeck, setClosedDeck] = useState(initialDeal.closedDeck);
  const [finishCard, setFinishCard] = useState(null);

  // Player & Turn State
  const [opponents, setOpponents] = useState(INITIAL_OPPONENTS);
  const [activeTurn, setActiveTurn] = useState(0); // 0 = User, 1..5 = Opponents
  const [turnPhase, setTurnPhase] = useState('DRAW'); // 'DRAW' | 'DISCARD' | 'DECLARED' | 'OPPONENT_TURN'
  const [selectedIds, setSelectedIds] = useState([]);
  const [newlyDrawnId, setNewlyDrawnId] = useState(null);
  const [userChips, setUserChips] = useState(35800);
  const [turnTimer, setTurnTimer] = useState(30);
  const [turnsPlayedByUser, setTurnsPlayedByUser] = useState(0);

  // UI & Modals
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [showDiscardModal, setShowDiscardModal] = useState(false);
  const [showRulesModal, setShowRulesModal] = useState(false);
  const [showDeclareModal, setShowDeclareModal] = useState(false);
  const [toastMessage, setToastMessage] = useState('Your Turn! Pick a card from the Closed or Open Deck.');

  const wildRank = wildCard?.rank || '7';
  const totalUserCards = useMemo(() => groups.reduce((acc, g) => acc + g.length, 0), [groups]);

  // Live Hand Evaluation
  const handEvaluation = useMemo(
    () => evaluateFullHand(groups, wildRank),
    [groups, wildRank]
  );

  // Show temporary banner notification
  const triggerToast = (msg) => {
    setToastMessage(msg);
  };

  // Turn countdown timer
  useEffect(() => {
    if (turnPhase === 'DECLARED') return;
    const timer = setInterval(() => {
      setTurnTimer((prev) => (prev > 0 ? prev - 1 : 30));
    }, 1000);
    return () => clearInterval(timer);
  }, [activeTurn, turnPhase]);

  // Simulated Opponent Turns Loop
  useEffect(() => {
    if (activeTurn === 0 || turnPhase === 'DECLARED') return;

    const currentOppIndex = activeTurn - 1;
    const currentOpp = opponents[currentOppIndex];
    setTurnTimer(15);

    const timeout = setTimeout(() => {
      // Simulate opponent drawing & discarding a card
      setClosedDeck((prevClosed) => {
        if (prevClosed.length === 0) return prevClosed;
        const drawn = prevClosed[0];
        const rest = prevClosed.slice(1);
        setOpenDeck((prevOpen) => [drawn, ...prevOpen]);
        return rest;
      });

      setOpponents((prevOpps) =>
        prevOpps.map((o, idx) =>
          idx === currentOppIndex
            ? { ...o, lastAction: Math.random() > 0.35 ? 'Drew Closed Deck' : 'Picked Open Card' }
            : o
        )
      );

      if (activeTurn < 5) {
        const nextOpp = opponents[activeTurn];
        triggerToast(`${currentOpp.name} discarded a card. ${nextOpp.name}'s turn...`);
        setActiveTurn(activeTurn + 1);
      } else {
        // Back to User
        setActiveTurn(0);
        setTurnPhase('DRAW');
        setTurnTimer(30);
        triggerToast('Your Turn! Draw a card from the Closed Deck or Open Deck.');
      }
    }, 950);

    return () => clearTimeout(timeout);
  }, [activeTurn, turnPhase, opponents]);

  // ==========================================
  // GAMEPLAY ACTIONS
  // ==========================================

  // Start a fresh deal
  const handleNewDeal = (useCurated = false) => {
    if (useCurated) {
      const curated = createCuratedDeal();
      setGroups(curated.groups);
      setWildCard(curated.wildCard);
      setOpenDeck(curated.openDeck);
      setClosedDeck(curated.closedDeck);
    } else {
      const shoe = createShoe();
      const hand = shoe.slice(0, 13);
      const wild = shoe[13];
      const open = [shoe[14]];
      const closed = shoe.slice(15, 75);

      // Split into 4 default groups by suit
      const bySuit = SUITS.map(s => hand.filter(c => c.suit === s.id));
      const jokers = hand.filter(c => c.isPrintedJoker);
      if (jokers.length > 0) bySuit[0].push(...jokers);
      setGroups(bySuit.filter(g => g.length > 0));
      setWildCard(wild);
      setOpenDeck(open);
      setClosedDeck(closed);
    }

    setFinishCard(null);
    setSelectedIds([]);
    setNewlyDrawnId(null);
    setActiveTurn(0);
    setTurnPhase('DRAW');
    setTurnTimer(30);
    setShowDeclareModal(false);
    setOpponents(INITIAL_OPPONENTS);
    triggerToast('New Hand Dealt! Organize your melds and draw a card.');
  };

  // Draw from Closed Deck
  const handleDrawClosed = () => {
    if (activeTurn !== 0 || turnPhase !== 'DRAW') {
      triggerToast(totalUserCards === 14 ? 'You already have 14 cards! Discard or Declare one card.' : 'Wait for your turn to draw!');
      return;
    }
    if (closedDeck.length === 0) return;

    const drawnCard = closedDeck[0];
    setClosedDeck(closedDeck.slice(1));
    setNewlyDrawnId(drawnCard.id);

    setGroups((prev) => {
      const copy = prev.map(g => [...g]);
      if (copy.length === 0) return [[drawnCard]];
      copy[copy.length - 1].push(drawnCard);
      return copy;
    });

    setTurnPhase('DISCARD');
    setSelectedIds([drawnCard.id]);
    triggerToast(`Drew ${drawnCard.rank}${drawnCard.suitSymbol} from Closed Deck. Select 1 card to Discard or Declare.`);
  };

  // Draw from Open Deck
  const handleDrawOpen = () => {
    if (activeTurn !== 0 || turnPhase !== 'DRAW') {
      triggerToast(totalUserCards === 14 ? 'You already have 14 cards! Discard or Declare one card.' : 'Wait for your turn to draw!');
      return;
    }
    if (openDeck.length === 0) return;

    const topCard = openDeck[0];
    setOpenDeck(openDeck.slice(1));
    setNewlyDrawnId(topCard.id);

    setGroups((prev) => {
      const copy = prev.map(g => [...g]);
      if (copy.length === 0) return [[topCard]];
      copy[copy.length - 1].push(topCard);
      return copy;
    });

    setTurnPhase('DISCARD');
    setSelectedIds([topCard.id]);
    triggerToast(`Picked ${topCard.rank}${topCard.suitSymbol} from Open Deck. Group it or discard a card!`);
  };

  // Toggle selection of a card in hand
  const toggleCardSelect = (cardId) => {
    setSelectedIds((prev) =>
      prev.includes(cardId) ? prev.filter((id) => id !== cardId) : [...prev, cardId]
    );
  };

  // Group all currently selected cards into a new meld group
  const handleGroupSelected = () => {
    if (selectedIds.length === 0) return;

    const extracted = [];
    const remainingGroups = groups
      .map((group) => {
        return group.filter((card) => {
          if (selectedIds.includes(card.id)) {
            extracted.push(card);
            return false;
          }
          return true;
        });
      })
      .filter((g) => g.length > 0);

    // Sort extracted cards by value for convenience
    extracted.sort((a, b) => a.value - b.value);

    // Limit max groups to 6 to keep UI clean
    if (remainingGroups.length >= 6) {
      remainingGroups[remainingGroups.length - 1].push(...extracted);
      setGroups(remainingGroups);
    } else {
      setGroups([...remainingGroups, extracted]);
    }

    setSelectedIds([]);
    triggerToast(`Created a new group with ${extracted.length} card${extracted.length > 1 ? 's' : ''}.`);
  };

  // Move selected cards to a specific existing group index
  const handleMoveSelectedToGroup = (targetGroupIdx) => {
    if (selectedIds.length === 0) return;

    const extracted = [];
    const cleaned = groups.map((group) =>
      group.filter((card) => {
        if (selectedIds.includes(card.id)) {
          extracted.push(card);
          return false;
        }
        return true;
      })
    );

    if (cleaned[targetGroupIdx]) {
      cleaned[targetGroupIdx].push(...extracted);
    }

    setGroups(cleaned.filter((g) => g.length > 0));
    setSelectedIds([]);
  };

  // Shift a single selected card left or right inside its group
  const handleShiftSelectedCard = (direction) => {
    if (selectedIds.length !== 1) return;
    const cardId = selectedIds[0];

    setGroups((prev) => {
      const next = prev.map((g) => [...g]);
      for (let gIdx = 0; gIdx < next.length; gIdx++) {
        const cIdx = next[gIdx].findIndex((c) => c.id === cardId);
        if (cIdx !== -1) {
          const targetIdx = cIdx + direction;
          if (targetIdx >= 0 && targetIdx < next[gIdx].length) {
            const temp = next[gIdx][cIdx];
            next[gIdx][cIdx] = next[gIdx][targetIdx];
            next[gIdx][targetIdx] = temp;
          } else if (direction === -1 && gIdx > 0) {
            const [moved] = next[gIdx].splice(cIdx, 1);
            next[gIdx - 1].push(moved);
          } else if (direction === 1 && gIdx < next.length - 1) {
            const [moved] = next[gIdx].splice(cIdx, 1);
            next[gIdx + 1].unshift(moved);
          }
          break;
        }
      }
      return next.filter((g) => g.length > 0);
    });
  };

  // Auto-Sort Hand by Suits & Rank
  const handleAutoSort = () => {
    const allCards = groups.flat();
    const sortedGroups = [];

    for (const suit of SUITS) {
      const suited = allCards
        .filter((c) => c.suit === suit.id && !isCardWild(c, wildRank))
        .sort((a, b) => a.value - b.value);
      if (suited.length > 0) sortedGroups.push(suited);
    }

    const wildCards = allCards.filter((c) => isCardWild(c, wildRank));
    if (wildCards.length > 0) {
      sortedGroups.push(wildCards);
    }

    setGroups(sortedGroups);
    setSelectedIds([]);
    triggerToast('Hand sorted by suits and wild jokers!');
  };

  // Discard 1 selected card to the Open Deck and trigger Opponent turns
  const handleDiscardCard = () => {
    if (totalUserCards !== 14) {
      triggerToast('Draw a card first (you must hold 14 cards to discard).');
      return;
    }
    if (selectedIds.length !== 1) {
      triggerToast('Select exactly 1 card to discard!');
      return;
    }

    const discardId = selectedIds[0];
    let discardedCard = null;

    const updatedGroups = groups
      .map((group) =>
        group.filter((c) => {
          if (c.id === discardId) {
            discardedCard = c;
            return false;
          }
          return true;
        })
      )
      .filter((g) => g.length > 0);

    if (!discardedCard) return;

    setGroups(updatedGroups);
    setOpenDeck([discardedCard, ...openDeck]);
    setSelectedIds([]);
    setNewlyDrawnId(null);
    setTurnsPlayedByUser((p) => p + 1);

    // Trigger Opponent Turn Simulation
    setTurnPhase('OPPONENT_TURN');
    setActiveTurn(1);
    triggerToast(`You discarded ${discardedCard.rank}${discardedCard.suitSymbol}. Opponents are playing...`);
  };

  // Declare / Drop 14th card into the Finish Slot
  const handleDeclareShow = () => {
    if (totalUserCards !== 14) {
      triggerToast('To Declare Rummy, first draw a 14th card and select 1 card to place in the Finish Slot!');
      return;
    }
    if (selectedIds.length !== 1) {
      triggerToast('Select the 14th card you want to place into the Finish Slot!');
      return;
    }

    const finishId = selectedIds[0];
    let droppedFinishCard = null;

    const updatedGroups = groups
      .map((group) =>
        group.filter((c) => {
          if (c.id === finishId) {
            droppedFinishCard = c;
            return false;
          }
          return true;
        })
      )
      .filter((g) => g.length > 0);

    setGroups(updatedGroups);
    setFinishCard(droppedFinishCard);
    setSelectedIds([]);
    setTurnPhase('DECLARED');
    setShowDeclareModal(true);

    const finalEval = evaluateFullHand(updatedGroups, wildRank);
    if (finalEval.isReadyToDeclare) {
      setUserChips((c) => c + 1650);
      triggerToast('🎉 GRAND RUMMY SHOW! Valid Declaration (0 Points)!');
    } else {
      triggerToast(`Declaration Verified: ${finalEval.penaltyPoints} Penalty Points remaining.`);
    }
  };

  // Drop out of current round
  const handleDropGame = () => {
    const dropPts = turnsPlayedByUser === 0 ? 20 : 40;
    const dropCost = dropPts * 10;
    setUserChips((c) => Math.max(0, c - dropCost));
    triggerToast(`You dropped the hand (${dropPts} pts / -₹${dropCost}). Dealing a fresh hand...`);
    setTimeout(() => handleNewDeal(true), 1200);
  };

  // Helper to get Opponent Seat Coordinates on the Oval Perimeter
  const getSeatPositionClasses = (position) => {
    switch (position) {
      case 'mid-left':
        return 'left-2 sm:left-5 top-[48%] -translate-y-1/2';
      case 'top-left':
        return 'left-[10%] sm:left-[16%] top-2 sm:top-4';
      case 'top':
        return 'left-1/2 -translate-x-1/2 -top-2 sm:top-1';
      case 'top-right':
        return 'right-[10%] sm:right-[16%] top-2 sm:top-4';
      case 'mid-right':
        return 'right-2 sm:right-5 top-[48%] -translate-y-1/2';
      default:
        return '';
    }
  };

  // Badge styling for Meld Groups
  const getBadgeStyle = (color) => {
    switch (color) {
      case 'emerald':
        return {
          bg: 'bg-emerald-950/90 border-emerald-400/80 text-emerald-300 shadow-[0_0_12px_rgba(16,185,129,0.3)]',
          icon: <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />,
        };
      case 'amber':
        return {
          bg: 'bg-amber-950/90 border-amber-400/80 text-amber-200 shadow-[0_0_12px_rgba(245,158,11,0.25)]',
          icon: <Sparkles className="w-3.5 h-3.5 text-amber-400 shrink-0" />,
        };
      case 'sky':
        return {
          bg: 'bg-sky-950/90 border-sky-400/80 text-sky-200 shadow-[0_0_12px_rgba(56,189,248,0.25)]',
          icon: <CheckCircle2 className="w-3.5 h-3.5 text-sky-400 shrink-0" />,
        };
      default:
        return {
          bg: 'bg-rose-950/90 border-rose-500/70 text-rose-200',
          icon: <XCircle className="w-3.5 h-3.5 text-rose-400 shrink-0" />,
        };
    }
  };

  return (
    <div className="min-h-screen w-full bg-[#070b12] text-slate-100 flex flex-col justify-between overflow-x-hidden select-none font-sans relative">
      {/* Ambient Background Glow */}
      <div className="pointer-events-none fixed inset-0 bg-[radial-gradient(circle_at_50%_38%,rgba(16,185,129,0.14),rgba(7,11,18,0.98)_75%)]" />

      {/* ==========================================
          1. TOP HEADER BAR
      ========================================== */}
      <header className="relative z-30 w-full bg-slate-950/90 backdrop-blur-md border-b border-amber-500/20 px-3 sm:px-6 py-2 flex flex-wrap items-center justify-between gap-2 shadow-lg">
        {/* Left: Brand & Table Info */}
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 bg-gradient-to-r from-amber-500/20 to-amber-600/5 border border-amber-500/40 px-3 py-1 rounded-full">
            <Crown className="w-4 h-4 text-amber-400" />
            <span className="font-black tracking-wider text-xs sm:text-sm bg-gradient-to-r from-amber-200 via-yellow-400 to-amber-200 bg-clip-text text-transparent">
              ROYAL RUMMY
            </span>
          </div>

          <div className="hidden md:flex items-center gap-4 text-xs text-slate-300 bg-slate-900/90 px-3 py-1 rounded-lg border border-slate-800">
            <span>
              Mode: <strong className="text-amber-300">13-Card Points</strong>
            </span>
            <span className="text-slate-600">|</span>
            <span>
              Point Value: <strong className="text-emerald-400">₹10 / pt</strong>
            </span>
            <span className="text-slate-600">|</span>
            <span>
              Table: <strong className="text-slate-200">#RR-8092</strong>
            </span>
          </div>
        </div>

        {/* Center Live Status Banner */}
        <div className="flex items-center gap-2 bg-emerald-950/70 border border-emerald-500/30 px-3 py-1 rounded-full text-xs text-emerald-200 max-w-md truncate">
          <Sparkles className="w-3.5 h-3.5 text-amber-400 shrink-0 animate-pulse" />
          <span className="truncate font-medium">{toastMessage}</span>
        </div>

        {/* Right: User Wallet & Utility Controls */}
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 bg-slate-900 border border-amber-500/30 px-2.5 py-1 rounded-lg text-xs">
            <Coins className="w-3.5 h-3.5 text-amber-400" />
            <span className="text-slate-400 hidden sm:inline">Chips:</span>
            <span className="font-bold text-amber-300">₹{userChips.toLocaleString('en-IN')}</span>
          </div>

          <button
            onClick={() => handleNewDeal(true)}
            title="Deal Curated Showcase Hand"
            className="flex items-center gap-1 bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 px-2.5 py-1.5 rounded-lg text-xs font-semibold transition"
          >
            <RotateCcw className="w-3.5 h-3.5 text-amber-400" />
            <span className="hidden sm:inline">New Deal</span>
          </button>

          <button
            onClick={() => setShowRulesModal(true)}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 transition"
            title="Rummy Rules & Life Guide"
          >
            <HelpCircle className="w-4 h-4 text-amber-400" />
          </button>

          <button
            onClick={() => setSoundEnabled(!soundEnabled)}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 transition"
            title="Toggle Audio"
          >
            {soundEnabled ? <Volume2 className="w-4 h-4 text-emerald-400" /> : <VolumeX className="w-4 h-4 text-slate-500" />}
          </button>
        </div>
      </header>

      {/* ==========================================
          2. 2.5D OVAL RUMMY TABLE & OPPONENTS
      ========================================== */}
      <main className="relative flex-1 flex flex-col items-center justify-center px-2 sm:px-8 py-4 my-auto">
        <div className="relative w-full max-w-6xl h-[340px] sm:h-[400px] md:h-[430px] flex items-center justify-center">
          
          {/* Outer Golden-Mahogany Wood Table Rim */}
          <div
            className="
              relative w-[94%] sm:w-[90%] h-[84%] sm:h-[88%]
              rounded-[180px] sm:rounded-[260px]
              p-3 sm:p-5
              bg-gradient-to-b from-[#5c3214] via-[#2e1607] to-[#47250d]
              shadow-[0_25px_70px_rgba(0,0,0,0.95),inset_0_2px_6px_rgba(253,224,71,0.45)]
              border-[3px] border-amber-500/50
              flex items-center justify-center
            "
          >
            {/* Inner Gold Metallic Trim Ring */}
            <div
              className="
                relative w-full h-full
                rounded-[170px] sm:rounded-[245px]
                p-2 sm:p-3.5
                bg-gradient-to-b from-slate-950 via-stone-900 to-slate-950
                border border-amber-400/40
                shadow-inner
                flex items-center justify-center
              "
            >
              {/* Rich Emerald Felt Surface */}
              <div
                className="
                  relative w-full h-full
                  rounded-[160px] sm:rounded-[235px]
                  bg-[radial-gradient(ellipse_at_center,#126b49_0%,#0a4630_58%,#05291c_100%)]
                  shadow-[inset_0_0_65px_rgba(0,0,0,0.85)]
                  border-2 border-emerald-400/20
                  flex flex-col items-center justify-center
                  overflow-hidden
                "
              >
                {/* Inner Felt Betting Line */}
                <div className="pointer-events-none absolute inset-4 sm:inset-7 rounded-[150px] sm:rounded-[215px] border border-amber-300/15" />

                {/* Center Table Branding Watermark */}
                <div className="pointer-events-none flex flex-col items-center justify-center mb-28 sm:mb-32 opacity-25 select-none">
                  <div className="flex items-center gap-1.5 text-amber-300 font-serif tracking-[0.28em] text-xs sm:text-base font-bold uppercase">
                    <span>♠</span> ROYAL RUMMY - 13 CARDS <span>♥</span>
                  </div>
                  <span className="text-[10px] sm:text-xs text-emerald-200 tracking-widest uppercase mt-0.5">
                    1st Life Pure Sequence • 2nd Life Sequence Required
                  </span>
                </div>

                {/* ==========================================
                    3. CENTER DECK AREA (CLOSED, JOKER, OPEN, FINISH)
                ========================================== */}
                <div className="relative z-20 flex items-center justify-center gap-5 sm:gap-10 md:gap-14 mt-6 sm:mt-8">
                  
                  {/* A. CLOSED DECK + PERPENDICULAR WILD JOKER */}
                  <div className="flex flex-col items-center">
                    <div className="relative flex items-center justify-center">
                      {/* Perpendicular Printed/Wild Joker slipped underneath */}
                      {wildCard && (
                        <div
                          title={`Wild Joker Rank: All ${wildCard.rank}s are Wild Jokers`}
                          className="
                            -rotate-90 -translate-x-7 sm:-translate-x-9 translate-y-1
                            w-14 h-20 sm:w-16 sm:h-24 rounded-lg
                            bg-white border-2 border-amber-400 shadow-xl
                            flex flex-col justify-between p-1.5 select-none
                          "
                        >
                          <div className={`flex flex-col items-center leading-none w-4 ${wildCard.color}`}>
                            <span className="font-black text-xs sm:text-sm">{wildCard.rank}</span>
                            <span className="text-xs">{wildCard.suitSymbol}</span>
                          </div>
                          <div className="self-center">
                            <span className={`text-lg sm:text-xl ${wildCard.color}`}>{wildCard.suitSymbol}</span>
                          </div>
                        </div>
                      )}

                      {/* Face-Down Closed Deck Stack */}
                      <button
                        onClick={handleDrawClosed}
                        className={`
                          relative w-16 h-24 sm:w-20 sm:h-28 rounded-xl
                          bg-gradient-to-br from-rose-900 via-red-950 to-slate-950
                          border-2 ${activeTurn === 0 && turnPhase === 'DRAW' ? 'border-amber-400 ring-4 ring-amber-400/30 animate-pulse cursor-pointer' : 'border-amber-200/50'}
                          shadow-[4px_6px_0px_#1e293b,8px_12px_20px_rgba(0,0,0,0.75)]
                          flex flex-col items-center justify-center p-1.5 group transition-transform hover:-translate-y-1
                        `}
                      >
                        {/* Ornate Back Pattern */}
                        <div className="w-full h-full rounded-lg border border-amber-400/40 bg-[radial-gradient(#f59e0b_1px,transparent_1px)] [background-size:8px_8px] flex flex-col items-center justify-center">
                          <div className="w-8 h-8 rounded-full bg-amber-500/20 border border-amber-400/60 flex items-center justify-center">
                            <Crown className="w-4 h-4 text-amber-300" />
                          </div>
                        </div>

                        {/* Remaining Card Count Pill */}
                        <span className="absolute -top-2.5 -right-2.5 bg-slate-950 text-amber-300 border border-amber-400/60 text-[10px] font-extrabold px-1.5 py-0.5 rounded-full shadow">
                          {closedDeck.length}
                        </span>
                      </button>
                    </div>

                    <div className="mt-2 flex items-center gap-1.5">
                      <span className="text-[10px] sm:text-xs font-semibold text-emerald-100 uppercase tracking-wider">
                        Closed Deck
                      </span>
                      <span className="text-[10px] bg-amber-500/20 border border-amber-400/40 text-amber-200 px-1.5 py-0.2 rounded font-bold">
                        Joker: {wildCard?.rank}
                      </span>
                    </div>
                  </div>

                  {/* B. OPEN DECK (DISCARD PILE) */}
                  <div className="flex flex-col items-center">
                    <div className="relative">
                      {openDeck.length > 0 ? (
                        <div
                          onClick={handleDrawOpen}
                          className={`
                            transition-transform hover:-translate-y-1
                            ${activeTurn === 0 && turnPhase === 'DRAW' ? 'ring-4 ring-amber-400/30 rounded-xl' : ''}
                          `}
                        >
                          <PlayingCard
                            card={openDeck[0]}
                            wildRank={wildRank}
                            size="deck"
                          />
                        </div>
                      ) : (
                        <div className="w-16 h-24 sm:w-20 sm:h-28 rounded-xl border-2 border-dashed border-emerald-300/40 flex items-center justify-center text-xs text-emerald-200/50">
                          Empty
                        </div>
                      )}

                      {/* Discard History Trigger Button */}
                      <button
                        onClick={() => setShowDiscardModal(true)}
                        title="View Discard Pile History"
                        className="absolute -top-2.5 -right-2.5 bg-slate-900 hover:bg-slate-800 text-amber-300 border border-amber-400/60 p-1.5 rounded-full shadow-lg transition"
                      >
                        <History className="w-3.5 h-3.5" />
                      </button>
                    </div>

                    <div className="mt-2 flex items-center gap-1">
                      <span className="text-[10px] sm:text-xs font-semibold text-emerald-100 uppercase tracking-wider">
                        Open Deck ({openDeck.length})
                      </span>
                    </div>
                  </div>

                  {/* C. FINISH SLOT (FOR 14TH CARD DECLARATION) */}
                  <div className="flex flex-col items-center">
                    <button
                      onClick={handleDeclareShow}
                      title="Select 1 card from your 14-card hand and click here to Declare Rummy"
                      className={`
                        w-16 h-24 sm:w-20 sm:h-28 rounded-xl
                        border-2 border-dashed transition-all flex flex-col items-center justify-center p-2
                        ${
                          finishCard
                            ? 'border-amber-400 bg-amber-500/20'
                            : totalUserCards === 14 && selectedIds.length === 1
                            ? 'border-amber-300 bg-amber-400/20 shadow-[0_0_25px_rgba(251,191,36,0.5)] scale-105 animate-pulse cursor-pointer'
                            : 'border-amber-400/40 bg-emerald-950/50 hover:border-amber-300/70'
                        }
                      `}
                    >
                      {finishCard ? (
                        <PlayingCard card={finishCard} wildRank={wildRank} size="small" />
                      ) : (
                        <>
                          <Trophy className="w-6 h-6 text-amber-400/80 mb-1" />
                          <span className="text-[9px] sm:text-[10px] font-extrabold text-amber-200 uppercase text-center leading-tight">
                            Finish Slot
                          </span>
                          <span className="text-[8px] text-emerald-200/70 mt-0.5 text-center">
                            Drop 14th Card
                          </span>
                        </>
                      )}
                    </button>
                    <span className="mt-2 text-[10px] sm:text-xs font-semibold text-amber-300 uppercase tracking-wider">
                      Declare Slot
                    </span>
                  </div>

                </div>
              </div>
            </div>
          </div>

          {/* ==========================================
              OPPONENT SEATS AROUND PERIMETER (5 PLAYERS)
          ========================================== */}
          {opponents.map((opp, idx) => {
            const isOppTurn = activeTurn === idx + 1;
            return (
              <div
                key={opp.id}
                className={`
                  absolute z-20 flex flex-col items-center
                  ${getSeatPositionClasses(opp.position)}
                `}
              >
                <div
                  className={`
                    relative flex items-center gap-2.5 px-3 py-1.5 rounded-2xl
                    bg-slate-900/95 backdrop-blur-md border transition-all duration-300
                    ${
                      isOppTurn
                        ? 'border-amber-400 ring-2 ring-amber-400/50 shadow-[0_0_20px_rgba(251,191,36,0.5)] scale-105'
                        : 'border-slate-700/80 shadow-lg'
                    }
                  `}
                >
                  {/* Avatar with Animated Turn Ring */}
                  <div className="relative">
                    <div
                      className={`
                        w-9 h-9 sm:w-11 sm:h-11 rounded-full flex items-center justify-center text-lg sm:text-xl
                        bg-gradient-to-br from-slate-700 to-slate-900 border-2
                        ${isOppTurn ? 'border-amber-400 animate-pulse' : 'border-slate-600'}
                      `}
                    >
                      {opp.avatar}
                    </div>
                    {/* Card Count Badge */}
                    <div
                      title="Cards in hand"
                      className="absolute -bottom-1 -right-1 bg-rose-700 text-white border border-amber-300 text-[9px] font-black px-1.5 rounded-full shadow"
                    >
                      {opp.cards}
                    </div>
                  </div>

                  {/* Name & Balance */}
                  <div className="flex flex-col leading-tight">
                    <span className="text-xs font-bold text-slate-100 max-w-[90px] truncate">
                      {opp.name}
                    </span>
                    <span className="text-[10px] font-semibold text-amber-400">
                      ₹{opp.chips.toLocaleString('en-IN')}
                    </span>
                    <span className="text-[9px] text-emerald-300/90 truncate max-w-[95px]">
                      {isOppTurn ? 'Thinking...' : opp.lastAction}
                    </span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </main>

      {/* ==========================================
          4. INTERACTIVE PLAYER HAND & MELD GROUPS (BOTTOM)
      ========================================== */}
      <section className="relative z-30 w-full max-w-7xl mx-auto px-2 sm:px-6 pb-3 flex flex-col items-center">
        
        {/* Floating Contextual Selection Action Bar */}
        <div className="h-11 flex items-center justify-center mb-1">
          {selectedIds.length > 0 ? (
            <div className="flex items-center gap-2 bg-slate-900/95 border border-amber-400/60 px-3.5 py-1.5 rounded-full shadow-[0_8px_25px_rgba(0,0,0,0.8)] animate-fade-in">
              <span className="text-xs font-bold text-amber-300 mr-1">
                {selectedIds.length} Selected
              </span>

              {/* Reorder single card Left / Right */}
              {selectedIds.length === 1 && (
                <div className="flex items-center gap-1 border-r border-slate-700 pr-2">
                  <button
                    onClick={() => handleShiftSelectedCard(-1)}
                    title="Move Card Left"
                    className="p-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200"
                  >
                    <ChevronLeft className="w-3.5 h-3.5" />
                  </button>
                  <button
                    onClick={() => handleShiftSelectedCard(1)}
                    title="Move Card Right"
                    className="p-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200"
                  >
                    <ChevronRight className="w-3.5 h-3.5" />
                  </button>
                </div>
              )}

              {/* Group Selected Button */}
              <button
                onClick={handleGroupSelected}
                className="flex items-center gap-1 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold px-3 py-1 rounded-full shadow transition"
              >
                <Layers className="w-3.5 h-3.5" />
                <span>Group ({selectedIds.length})</span>
              </button>

              {/* Discard Button (when holding 14 cards & 1 card selected) */}
              {totalUserCards === 14 && selectedIds.length === 1 && (
                <>
                  <button
                    onClick={handleDiscardCard}
                    className="flex items-center gap-1 bg-amber-500 hover:bg-amber-400 text-slate-950 text-xs font-extrabold px-3 py-1 rounded-full shadow transition"
                  >
                    <Send className="w-3.5 h-3.5" />
                    <span>Discard</span>
                  </button>

                  <button
                    onClick={handleDeclareShow}
                    className="flex items-center gap-1 bg-emerald-500 hover:bg-emerald-400 text-slate-950 text-xs font-extrabold px-3 py-1 rounded-full shadow transition"
                  >
                    <Trophy className="w-3.5 h-3.5" />
                    <span>Declare</span>
                  </button>
                </>
              )}

              <button
                onClick={() => setSelectedIds([])}
                className="p-1 text-slate-400 hover:text-white"
                title="Clear Selection"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          ) : (
            /* Live Life / Validation Summary Pill when no cards are selected */
            <div className="flex flex-wrap items-center justify-center gap-2 sm:gap-4 bg-slate-900/85 border border-slate-800 px-4 py-1.5 rounded-full text-xs">
              <div className="flex items-center gap-1.5">
                <span className={`w-2 h-2 rounded-full ${handEvaluation.hasFirstLife ? 'bg-emerald-400' : 'bg-rose-500'}`} />
                <span className={handEvaluation.hasFirstLife ? 'text-emerald-300 font-semibold' : 'text-slate-400'}>
                  1st Life (Pure Seq): {handEvaluation.hasFirstLife ? 'Done ✓' : 'Needed'}
                </span>
              </div>
              <span className="text-slate-700">|</span>
              <div className="flex items-center gap-1.5">
                <span className={`w-2 h-2 rounded-full ${handEvaluation.hasSecondLife ? 'bg-emerald-400' : 'bg-amber-400'}`} />
                <span className={handEvaluation.hasSecondLife ? 'text-emerald-300 font-semibold' : 'text-slate-400'}>
                  2nd Life (Seq): {handEvaluation.hasSecondLife ? 'Done ✓' : 'Needed'}
                </span>
              </div>
              <span className="text-slate-700">|</span>
              <div className="flex items-center gap-1">
                <span className="text-slate-400">Hand Score:</span>
                <span className={`font-extrabold ${handEvaluation.penaltyPoints === 0 ? 'text-emerald-400' : 'text-amber-400'}`}>
                  {handEvaluation.penaltyPoints} pts
                </span>
              </div>
            </div>
          )}
        </div>

        {/* MELD GROUPS CONTAINER */}
        <div className="w-full overflow-x-auto pb-2 pt-5 px-2 flex items-end justify-start lg:justify-center gap-4 sm:gap-6 no-scrollbar">
          {groups.map((group, gIdx) => {
            const evalInfo = handEvaluation.groupEvals[gIdx] || {
              label: 'Group',
              statusColor: 'rose',
            };
            const badge = getBadgeStyle(evalInfo.statusColor);
            const midIndex = (group.length - 1) / 2;

            return (
              <div
                key={`group_${gIdx}`}
                className="flex flex-col items-center shrink-0 group/meld"
              >
                {/* Cards Fan inside this Meld Group */}
                <div className="flex items-center px-2">
                  {group.map((card, cIdx) => {
                    const offsetFromCenter = cIdx - midIndex;
                    const rotation = offsetFromCenter * 2.2;
                    const liftY = Math.abs(offsetFromCenter) * 2.2;

                    return (
                      <PlayingCard
                        key={card.id}
                        card={card}
                        wildRank={wildRank}
                        selected={selectedIds.includes(card.id)}
                        isNewlyDrawn={card.id === newlyDrawnId}
                        onClick={() => toggleCardSelect(card.id)}
                        overlapClass={cIdx > 0 ? '-ml-7 sm:-ml-9 md:-ml-10' : ''}
                        rotation={rotation}
                        liftY={liftY}
                      />
                    );
                  })}
                </div>

                {/* Group Status Tag Pill + Move Here Button */}
                <div className="mt-2.5 flex items-center gap-1.5">
                  <div
                    className={`
                      flex items-center gap-1.5 px-3 py-1 rounded-full border text-[11px] font-bold tracking-wide transition-all
                      ${badge.bg}
                    `}
                  >
                    {badge.icon}
                    <span>{evalInfo.label}</span>
                  </div>

                  {selectedIds.length > 0 && (
                    <button
                      onClick={() => handleMoveSelectedToGroup(gIdx)}
                      title="Move selected cards into this group"
                      className="bg-amber-500 hover:bg-amber-400 text-slate-950 text-[10px] font-extrabold px-2 py-1 rounded-full shadow transition"
                    >
                      + Here
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>

        {/* ==========================================
            5. BOTTOM CONTROL DASHBOARD & ACTIVE PLAYER HUD
        ========================================== */}
        <div className="w-full max-w-5xl mt-2 bg-slate-900/95 backdrop-blur-md border border-amber-500/30 rounded-2xl px-3 sm:px-6 py-2.5 flex flex-wrap items-center justify-between gap-3 shadow-2xl">
          
          {/* Left: Active Player Avatar & Turn Status */}
          <div className="flex items-center gap-3">
            <div className="relative">
              <div
                className={`
                  w-11 h-11 rounded-full bg-gradient-to-br from-emerald-500 to-teal-800
                  flex items-center justify-center text-xl font-bold border-2
                  ${activeTurn === 0 ? 'border-amber-400 ring-4 ring-amber-400/25' : 'border-slate-600'}
                `}
              >
                😎
              </div>
              <span className="absolute -bottom-1 -right-1 bg-amber-400 text-slate-950 text-[10px] font-black px-1.5 rounded-full">
                {totalUserCards}
              </span>
            </div>

            <div>
              <div className="flex items-center gap-2">
                <span className="font-extrabold text-sm text-white">You (Player 1)</span>
                <span
                  className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                    activeTurn === 0
                      ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/40'
                      : 'bg-slate-800 text-slate-400'
                  }`}
                >
                  {activeTurn === 0
                    ? turnPhase === 'DRAW'
                      ? 'YOUR TURN • DRAW CARD'
                      : 'YOUR TURN • DISCARD / SHOW'
                    : 'WAITING FOR OPPONENTS'}
                </span>
              </div>
              <div className="flex items-center gap-3 text-xs text-slate-400 mt-0.5">
                <span className="flex items-center gap-1 text-amber-300 font-semibold">
                  <Clock className="w-3.5 h-3.5" /> {turnTimer}s
                </span>
                <span>•</span>
                <span>Wild Joker: <strong className="text-amber-300">{wildCard?.rank}</strong></span>
              </div>
            </div>
          </div>

          {/* Right: Game Action Buttons */}
          <div className="flex flex-wrap items-center gap-2 sm:gap-3">
            {/* Drop Button */}
            <button
              onClick={handleDropGame}
              disabled={activeTurn !== 0 || turnPhase !== 'DRAW'}
              className={`
                flex flex-col items-center px-3.5 py-1.5 rounded-xl border text-xs font-bold transition
                ${
                  activeTurn === 0 && turnPhase === 'DRAW'
                    ? 'bg-rose-950/80 hover:bg-rose-900 border-rose-500/50 text-rose-200 cursor-pointer'
                    : 'bg-slate-800/50 border-slate-800 text-slate-600 cursor-not-allowed'
                }
              `}
            >
              <div className="flex items-center gap-1">
                <Flag className="w-3.5 h-3.5" />
                <span>Drop</span>
              </div>
              <span className="text-[9px] font-normal opacity-80">
                {turnsPlayedByUser === 0 ? 'First Drop (20 pts)' : 'Mid Drop (40 pts)'}
              </span>
            </button>

            {/* Auto-Sort Hand Button */}
            <button
              onClick={handleAutoSort}
              className="flex flex-col items-center px-3.5 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-600 text-slate-100 text-xs font-bold transition"
            >
              <div className="flex items-center gap-1">
                <Wand2 className="w-3.5 h-3.5 text-amber-400" />
                <span>Sort Hand</span>
              </div>
              <span className="text-[9px] font-normal text-slate-400">By Suits</span>
            </button>

            {/* Discard Button */}
            <button
              onClick={handleDiscardCard}
              disabled={totalUserCards !== 14 || selectedIds.length !== 1}
              className={`
                flex flex-col items-center px-4 py-1.5 rounded-xl border text-xs font-extrabold transition
                ${
                  totalUserCards === 14 && selectedIds.length === 1
                    ? 'bg-gradient-to-r from-amber-500 to-yellow-400 hover:from-amber-400 hover:to-yellow-300 text-slate-950 border-amber-200 shadow-[0_0_20px_rgba(251,191,36,0.4)] cursor-pointer'
                    : 'bg-slate-800/60 border-slate-700/70 text-slate-500 cursor-not-allowed'
                }
              `}
            >
              <div className="flex items-center gap-1">
                <Send className="w-3.5 h-3.5" />
                <span>Discard</span>
              </div>
              <span className="text-[9px] font-semibold opacity-80">
                {totalUserCards === 14 ? '1 Card Selected' : 'Need 14 Cards'}
              </span>
            </button>

            {/* Show / Declare Rummy Button */}
            <button
              onClick={handleDeclareShow}
              disabled={totalUserCards !== 14 || selectedIds.length !== 1}
              className={`
                flex flex-col items-center px-4 py-1.5 rounded-xl border text-xs font-extrabold transition
                ${
                  totalUserCards === 14 && selectedIds.length === 1
                    ? 'bg-gradient-to-r from-emerald-500 to-teal-400 hover:from-emerald-400 hover:to-teal-300 text-slate-950 border-emerald-200 shadow-[0_0_20px_rgba(16,185,129,0.5)] cursor-pointer'
                    : 'bg-slate-800/60 border-slate-700/70 text-slate-500 cursor-not-allowed'
                }
              `}
            >
              <div className="flex items-center gap-1">
                <Trophy className="w-3.5 h-3.5" />
                <span>Declare / Show</span>
              </div>
              <span className="text-[9px] font-semibold opacity-80">Finish Hand</span>
            </button>
          </div>
        </div>
      </section>

      {/* ==========================================
          MODAL 1: DISCARD HISTORY POPOVER
      ========================================== */}
      {showDiscardModal && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-amber-500/40 rounded-2xl max-w-md w-full p-5 shadow-2xl">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center gap-2">
                <History className="w-5 h-5 text-amber-400" />
                <h3 className="font-bold text-base text-white">Open Deck Discard History</h3>
              </div>
              <button
                onClick={() => setShowDiscardModal(false)}
                className="text-slate-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <p className="text-xs text-slate-400 mt-2 mb-4">
              Most recently discarded card is first. Only the top card can be picked during your draw phase.
            </p>

            <div className="flex flex-wrap gap-2.5 max-h-64 overflow-y-auto p-2 bg-slate-950/70 rounded-xl border border-slate-800">
              {openDeck.map((c, idx) => (
                <div key={`${c.id}_${idx}`} className="relative">
                  <PlayingCard card={c} wildRank={wildRank} size="small" />
                  {idx === 0 && (
                    <span className="absolute -top-2 left-1/2 -translate-x-1/2 bg-amber-400 text-slate-950 text-[8px] font-black px-1.5 py-0.5 rounded-full">
                      TOP
                    </span>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ==========================================
          MODAL 2: DECLARATION / MELD VERIFICATION SCOREBOARD
      ========================================== */}
      {showDeclareModal && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-md flex items-center justify-center p-4">
          <div className="bg-slate-900 border-2 border-amber-500/50 rounded-3xl max-w-3xl w-full p-5 sm:p-6 shadow-2xl overflow-y-auto max-h-[92vh]">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-2xl bg-amber-500/20 border border-amber-400 flex items-center justify-center">
                  <Trophy className="w-6 h-6 text-amber-400" />
                </div>
                <div>
                  <h2 className="text-lg sm:text-xl font-black text-white">
                    {handEvaluation.isReadyToDeclare
                      ? '🎉 VALID RUMMY DECLARATION! YOU WIN!'
                      : '⚠️ MELD VERIFICATION SUMMARY'}
                  </h2>
                  <p className="text-xs text-slate-400">
                    Wild Joker Rank: <strong className="text-amber-300">{wildRank}</strong> • Finish Card:{' '}
                    <strong className="text-emerald-300">
                      {finishCard?.rank}
                      {finishCard?.suitSymbol}
                    </strong>
                  </p>
                </div>
              </div>

              <button
                onClick={() => setShowDeclareModal(false)}
                className="p-1.5 rounded-lg bg-slate-800 text-slate-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Player Declared Melds Preview */}
            <div className="my-4 bg-slate-950/90 border border-slate-800 rounded-2xl p-4">
              <div className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-3">
                Your Declared 13-Card Melds
              </div>
              <div className="flex flex-wrap gap-5 items-end">
                {groups.map((grp, idx) => {
                  const ev = handEvaluation.groupEvals[idx];
                  return (
                    <div key={idx} className="flex flex-col items-center">
                      <div className="flex">
                        {grp.map((c, cIdx) => (
                          <PlayingCard
                            key={c.id}
                            card={c}
                            wildRank={wildRank}
                            size="small"
                            overlapClass={cIdx > 0 ? '-ml-5' : ''}
                          />
                        ))}
                      </div>
                      <span
                        className={`mt-1.5 text-[10px] font-bold px-2 py-0.5 rounded-full ${
                          ev?.validInContext
                            ? 'bg-emerald-950 text-emerald-300 border border-emerald-500/40'
                            : 'bg-rose-950 text-rose-300 border border-rose-500/40'
                        }`}
                      >
                        {ev?.label}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Table Scoreboard */}
            <div className="space-y-2">
              <div className="grid grid-cols-4 text-xs font-bold text-slate-400 px-3 py-1">
                <span>Player</span>
                <span>Status</span>
                <span>Penalty Points</span>
                <span className="text-right">Winnings / Chips</span>
              </div>

              {/* User Row */}
              <div className="grid grid-cols-4 items-center bg-emerald-950/40 border border-emerald-500/40 rounded-xl px-3 py-2.5 text-xs sm:text-sm">
                <span className="font-bold text-white flex items-center gap-2">
                  😎 You (Declarer)
                </span>
                <span className={handEvaluation.isReadyToDeclare ? 'text-emerald-400 font-bold' : 'text-rose-400 font-bold'}>
                  {handEvaluation.isReadyToDeclare ? 'Winner (Valid Show)' : 'Invalid Show'}
                </span>
                <span className="font-bold text-white">{handEvaluation.penaltyPoints} pts</span>
                <span className={`text-right font-extrabold ${handEvaluation.isReadyToDeclare ? 'text-emerald-400' : 'text-rose-400'}`}>
                  {handEvaluation.isReadyToDeclare ? '+₹1,650' : `-₹${handEvaluation.penaltyPoints * 10}`}
                </span>
              </div>

              {/* Opponent Rows */}
              {opponents.map((opp, i) => {
                const oppPts = [24, 48, 15, 62, 16][i];
                return (
                  <div
                    key={opp.id}
                    className="grid grid-cols-4 items-center bg-slate-950/60 border border-slate-800 rounded-xl px-3 py-2 text-xs"
                  >
                    <span className="font-semibold text-slate-200 flex items-center gap-2">
                      <span>{opp.avatar}</span> {opp.name}
                    </span>
                    <span className="text-slate-400">Melding</span>
                    <span className="text-amber-300 font-semibold">{oppPts} pts</span>
                    <span className="text-right text-rose-400 font-bold">-₹{oppPts * 10}</span>
                  </div>
                );
              })}
            </div>

            <div className="mt-6 flex justify-end gap-3">
              <button
                onClick={() => handleNewDeal(false)}
                className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold"
              >
                Deal Random Hand
              </button>
              <button
                onClick={() => handleNewDeal(true)}
                className="px-5 py-2 rounded-xl bg-gradient-to-r from-amber-500 to-yellow-400 text-slate-950 text-xs font-extrabold shadow-lg"
              >
                Play Next Round
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ==========================================
          MODAL 3: 13-CARD INDIAN RUMMY RULES & GUIDE
      ========================================== */}
      {showRulesModal && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-amber-500/40 rounded-2xl max-w-lg w-full p-5 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <Crown className="w-5 h-5 text-amber-400" />
                <h3 className="font-bold text-base text-white">13-Card Indian Rummy Rules</h3>
              </div>
              <button
                onClick={() => setShowRulesModal(false)}
                className="text-slate-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-3 text-xs text-slate-300 leading-relaxed">
              <div className="p-3 rounded-xl bg-emerald-950/40 border border-emerald-500/30">
                <strong className="text-emerald-300 block mb-0.5">1. Mandatory 1st Life (Pure Sequence)</strong>
                At least 3 consecutive cards of the exact same suit without using any Wild or Printed Joker (e.g., 4♠ 5♠ 6♠).
              </div>

              <div className="p-3 rounded-xl bg-amber-950/40 border border-amber-500/30">
                <strong className="text-amber-300 block mb-0.5">2. Mandatory 2nd Life (Pure or Impure Sequence)</strong>
                Another sequence of 3+ cards of the same suit. Wild Jokers or Printed Jokers can be used to substitute missing cards.
              </div>

              <div className="p-3 rounded-xl bg-sky-950/40 border border-sky-500/30">
                <strong className="text-sky-300 block mb-0.5">3. Valid Sets (Optional after 1st & 2nd Life)</strong>
                3 or 4 cards of the same rank but different suits (e.g., K♠ K♥ K♣).
              </div>

              <div className="p-3 rounded-xl bg-slate-950 border border-slate-800">
                <strong className="text-white block mb-0.5">Quick Tip for Current Hand:</strong>
                On the initial deal, try picking <strong>3♦</strong> from the Open Deck, group it with <strong>A♦ 2♦</strong> to form another Pure Sequence, and then discard or declare <strong>8♣</strong>!
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}