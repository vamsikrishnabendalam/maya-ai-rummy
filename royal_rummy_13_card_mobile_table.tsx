import React, { useState, useEffect, useMemo } from 'react';
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
  XCircle, 
  ChevronLeft, 
  ChevronRight, 
  Flag, 
  Send, 
  Crown, 
  Coins, 
  Clock, 
  Wand2,
  X,
  Smartphone,
  Maximize2,
  Wifi,
  BatteryCharging,
  Zap,
  Lightbulb
} from 'lucide-react';

// ==========================================
// CONSTANTS & CARD DEFINITIONS
// ==========================================
const SUITS = [
  { id: 'S', symbol: '♠', name: 'Spades', color: 'text-slate-900', pillBg: 'bg-slate-200' },
  { id: 'H', symbol: '♥', name: 'Hearts', color: 'text-rose-600', pillBg: 'bg-rose-100' },
  { id: 'D', symbol: '♦', name: 'Diamonds', color: 'text-rose-600', pillBg: 'bg-rose-100' },
  { id: 'C', symbol: '♣', name: 'Clubs', color: 'text-slate-900', pillBg: 'bg-slate-200' },
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
  { id: 1, name: 'Vikram', avatar: '👑', chips: '24.5K', rawChips: 24500, cards: 13, seat: 'left', lastAction: 'Ready' },
  { id: 2, name: 'Ananya', avatar: '🌸', chips: '18.2K', rawChips: 18200, cards: 13, seat: 'top-left', lastAction: 'Ready' },
  { id: 3, name: 'Rajesh', avatar: '🦁', chips: '52.1K', rawChips: 52100, cards: 13, seat: 'top', lastAction: 'Ready' },
  { id: 4, name: 'Priya_K', avatar: '💎', chips: '12.9K', rawChips: 12950, cards: 13, seat: 'top-right', lastAction: 'Ready' },
  { id: 5, name: 'Kabir', avatar: '⚡', chips: '31.4K', rawChips: 31400, cards: 13, seat: 'right', lastAction: 'Ready' },
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
  for (let i = shoe.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shoe[i], shoe[j]] = [shoe[j], shoe[i]];
  }
  return shoe;
};

// Curated preset deal so the user can test an instant winning flow on mobile
const createCuratedDeal = () => {
  const fullShoe = createShoe();
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
  // Group 4: Partial sequence waiting for 3♦ (A♦, 2♦, 8♣)
  const g4 = [pickCard('A', 'D'), pickCard('2', 'D'), pickCard('8', 'C')];

  const openTop = pickCard('3', 'D'); // Tap Open Deck to pick 3♦ and complete the hand!
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

const calcDeadwood = (group, wildRank) => {
  return group.reduce((sum, card) => {
    if (isCardWild(card, wildRank)) return sum;
    return sum + card.points;
  }, 0);
};

const evaluateGroup = (group, wildRank) => {
  if (!group || group.length < 3) {
    return { type: 'INVALID', label: 'Invalid', shortLabel: 'Invalid', points: calcDeadwood(group, wildRank) };
  }

  // 1. Check Pure Sequence
  const checkContiguousSameSuit = (cards, allowWildCount = 0) => {
    const suit = cards[0].suit;
    if (!cards.every(c => c.suit === suit && !c.isPrintedJoker)) return false;

    const tryValues = (useHighAce) => {
      const vals = cards.map(c => (useHighAce && c.rank === 'A' ? 14 : c.value)).sort((a, b) => a - b);
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
    return { type: 'PURE_SEQ', label: 'Pure Seq', shortLabel: 'Pure', points: 0 };
  }

  // 2. Check Impure Sequence
  const wilds = group.filter(c => isCardWild(c, wildRank));
  const naturals = group.filter(c => !isCardWild(c, wildRank));

  if (naturals.length === 0) {
    return { type: 'PURE_SEQ', label: 'Pure Seq', shortLabel: 'Pure', points: 0 };
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
      return { type: 'IMPURE_SEQ', label: 'Impure Seq', shortLabel: 'Seq', points: 0 };
    }
  }

  // 3. Check Valid Set
  if (group.length >= 3 && group.length <= 4) {
    if (naturals.length > 0) {
      const targetRank = naturals[0].rank;
      const sameRank = naturals.every(c => c.rank === targetRank);
      const uniqueSuits = new Set(naturals.map(c => c.suit));
      if (sameRank && uniqueSuits.size === naturals.length) {
        return { type: 'SET', label: 'Set', shortLabel: 'Set', points: 0 };
      }
    }
  }

  return { type: 'INVALID', label: 'Invalid', shortLabel: 'Invalid', points: calcDeadwood(group, wildRank) };
};

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
        return { ...ev, label: 'Need 1st Life', statusColor: 'rose', validInContext: false, penalty: rawPts };
      }
    }
    if (ev.type === 'SET') {
      if (hasFirstLife && hasSecondLife) {
        return { ...ev, statusColor: 'sky', validInContext: true, penalty: 0 };
      } else {
        totalPenaltyPoints += rawPts;
        return {
          ...ev,
          label: !hasFirstLife ? 'Need 1st Life' : 'Need 2nd Life',
          statusColor: 'rose',
          validInContext: false,
          penalty: rawPts,
        };
      }
    }
    totalPenaltyPoints += rawPts;
    return { ...ev, label: `Invalid (${rawPts}p)`, statusColor: 'rose', validInContext: false, penalty: rawPts };
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
// HIGH-LEGIBILITY MOBILE PLAYING CARD
// ==========================================
const MobilePlayingCard = ({
  card,
  wildRank,
  selected = false,
  onClick,
  variant = 'hand', // 'hand' | 'portraitHand' | 'deck' | 'mini'
  overlapClass = '',
  isNewlyDrawn = false,
}) => {
  if (!card) return null;
  const isWild = isCardWild(card, wildRank);

  const variantClasses = {
    hand: 'w-[54px] h-[80px] sm:w-[60px] sm:h-[88px] rounded-lg',
    portraitHand: 'w-[52px] h-[76px] rounded-lg',
    deck: 'w-[48px] h-[70px] sm:w-[54px] sm:h-[78px] rounded-lg',
    mini: 'w-[38px] h-[54px] rounded-md',
  };

  return (
    <div
      onClick={onClick}
      style={{
        transform: selected ? 'translateY(-14px) scale(1.04)' : 'translateY(0px)',
      }}
      className={`
        relative select-none cursor-pointer transition-all duration-150 ease-out shrink-0
        bg-gradient-to-b from-white via-stone-50 to-stone-200
        border ${
          selected
            ? 'border-amber-400 ring-2 ring-amber-400 z-30 shadow-[0_10px_20px_rgba(251,191,36,0.5)]'
            : 'border-stone-300 shadow-[0_4px_10px_rgba(0,0,0,0.55)] active:scale-95'
        }
        ${variantClasses[variant]} ${overlapClass} flex flex-col justify-between p-1 overflow-hidden
      `}
    >
      {/* Top-Left Oversized Mobile Index (Easy to read when overlapped) */}
      <div className={`relative z-10 flex flex-col items-start leading-none ${card.color}`}>
        <span className="font-black text-[13px] sm:text-[15px] tracking-tighter">
          {card.isPrintedJoker ? '★' : card.rank}
        </span>
        <span className="text-[11px] sm:text-xs -mt-0.5">{card.suitSymbol}</span>
      </div>

      {/* Newly Drawn Dot */}
      {isNewlyDrawn && (
        <span className="absolute top-1 right-1 w-2 h-2 rounded-full bg-emerald-500 ring-2 ring-white animate-ping" />
      )}

      {/* Center Watermark Suit */}
      <div className={`relative z-10 flex items-center justify-center my-auto ${card.color}`}>
        {card.isPrintedJoker ? (
          <span className="text-lg sm:text-xl">🃏</span>
        ) : (
          <span className="text-lg sm:text-2xl opacity-85">{card.suitSymbol}</span>
        )}
      </div>

      {/* Wild Joker Crown Ribbon */}
      {isWild && (
        <div className="absolute bottom-1 left-0.5 right-0.5 z-20 flex items-center justify-center gap-0.5 bg-gradient-to-r from-amber-500 to-yellow-400 text-slate-950 py-[1px] rounded shadow-sm border border-amber-300">
          <Crown className="w-2.5 h-2.5 fill-slate-950 shrink-0" />
          <span className="text-[7px] font-black uppercase tracking-tighter">JOKER</span>
        </div>
      )}

      {/* Bottom-Right Corner Pip */}
      {!isWild && variant !== 'mini' && (
        <div className={`relative z-10 self-end leading-none rotate-180 opacity-75 ${card.color}`}>
          <span className="font-bold text-[10px]">{card.rank}</span>
        </div>
      )}
    </div>
  );
};

// ==========================================
// MAIN MOBILE RUMMY APPLICATION
// ==========================================
export default function App() {
  // Viewport Orientation Switcher: 'LANDSCAPE' | 'PORTRAIT' | 'FULL'
  const [deviceMode, setDeviceMode] = useState('LANDSCAPE');

  // Core Rummy State
  const initialDeal = useMemo(() => createCuratedDeal(), []);
  const [groups, setGroups] = useState(initialDeal.groups);
  const [wildCard, setWildCard] = useState(initialDeal.wildCard);
  const [openDeck, setOpenDeck] = useState(initialDeal.openDeck);
  const [closedDeck, setClosedDeck] = useState(initialDeal.closedDeck);
  const [finishCard, setFinishCard] = useState(null);

  // Turn & Opponents State
  const [opponents, setOpponents] = useState(INITIAL_OPPONENTS);
  const [activeTurn, setActiveTurn] = useState(0); // 0 = User, 1..5 = Opponents
  const [turnPhase, setTurnPhase] = useState('DRAW'); // 'DRAW' | 'DISCARD' | 'DECLARED' | 'OPPONENT_TURN'
  const [selectedIds, setSelectedIds] = useState([]);
  const [newlyDrawnId, setNewlyDrawnId] = useState(null);
  const [userChips, setUserChips] = useState(35800);
  const [turnTimer, setTurnTimer] = useState(25);
  const [turnsPlayedByUser, setTurnsPlayedByUser] = useState(0);

  // Mobile Drawers / Sheets
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [showDiscardSheet, setShowDiscardSheet] = useState(false);
  const [showRulesSheet, setShowRulesSheet] = useState(false);
  const [showDeclareSheet, setShowDeclareSheet] = useState(false);
  const [toastMessage, setToastMessage] = useState('Tap Open Deck (3♦) or Closed Deck to draw!');

  const wildRank = wildCard?.rank || '7';
  const totalUserCards = useMemo(() => groups.reduce((acc, g) => acc + g.length, 0), [groups]);

  // Live Hand Evaluation
  const handEvaluation = useMemo(
    () => evaluateFullHand(groups, wildRank),
    [groups, wildRank]
  );

  // Countdown Timer
  useEffect(() => {
    if (turnPhase === 'DECLARED') return;
    const interval = setInterval(() => {
      setTurnTimer((prev) => (prev > 0 ? prev - 1 : 25));
    }, 1000);
    return () => clearInterval(interval);
  }, [activeTurn, turnPhase]);

  // Fast Simulated Opponent Turns for Mobile Pacing
  useEffect(() => {
    if (activeTurn === 0 || turnPhase === 'DECLARED') return;

    const currentOppIdx = activeTurn - 1;
    const currentOpp = opponents[currentOppIdx];
    setTurnTimer(12);

    const timer = setTimeout(() => {
      setClosedDeck((prevClosed) => {
        if (prevClosed.length === 0) return prevClosed;
        const drawn = prevClosed[0];
        const rest = prevClosed.slice(1);
        setOpenDeck((prevOpen) => [drawn, ...prevOpen]);
        return rest;
      });

      setOpponents((prev) =>
        prev.map((o, idx) =>
          idx === currentOppIdx
            ? { ...o, lastAction: Math.random() > 0.4 ? 'Drew Deck' : 'Picked Open' }
            : o
        )
      );

      if (activeTurn < 5) {
        const nextOpp = opponents[activeTurn];
        setToastMessage(`${currentOpp.name} discarded • ${nextOpp.name}'s turn`);
        setActiveTurn(activeTurn + 1);
      } else {
        setActiveTurn(0);
        setTurnPhase('DRAW');
        setTurnTimer(25);
        setToastMessage('Your Turn! Tap Closed or Open Deck to draw.');
      }
    }, 650);

    return () => clearTimeout(timer);
  }, [activeTurn, turnPhase, opponents]);

  // ==========================================
  // MOBILE GAMEPLAY HANDLERS
  // ==========================================
  const handleNewDeal = (useCurated = true) => {
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
    setTurnTimer(25);
    setShowDeclareSheet(false);
    setOpponents(INITIAL_OPPONENTS);
    setToastMessage('Fresh 13-Card Deal! Tap 3♦ in Open Deck for an instant win.');
  };

  const handleDrawClosed = () => {
    if (activeTurn !== 0 || turnPhase !== 'DRAW') {
      setToastMessage(totalUserCards === 14 ? 'Select 1 card to Discard or Declare!' : 'Wait for your turn!');
      return;
    }
    if (closedDeck.length === 0) return;

    const drawn = closedDeck[0];
    setClosedDeck(closedDeck.slice(1));
    setNewlyDrawnId(drawn.id);

    setGroups((prev) => {
      const copy = prev.map(g => [...g]);
      if (copy.length === 0) return [[drawn]];
      copy[copy.length - 1].push(drawn);
      return copy;
    });

    setTurnPhase('DISCARD');
    setSelectedIds([drawn.id]);
    setToastMessage(`Drew ${drawn.rank}${drawn.suitSymbol}. Group it or Discard 1 card.`);
  };

  const handleDrawOpen = () => {
    if (activeTurn !== 0 || turnPhase !== 'DRAW') {
      setToastMessage(totalUserCards === 14 ? 'Select 1 card to Discard or Declare!' : 'Wait for your turn!');
      return;
    }
    if (openDeck.length === 0) return;

    const top = openDeck[0];
    setOpenDeck(openDeck.slice(1));
    setNewlyDrawnId(top.id);

    setGroups((prev) => {
      const copy = prev.map(g => [...g]);
      if (copy.length === 0) return [[top]];
      copy[copy.length - 1].push(top);
      return copy;
    });

    setTurnPhase('DISCARD');
    setSelectedIds([top.id]);
    setToastMessage(`Picked ${top.rank}${top.suitSymbol}! Tap "Auto-Meld" or select 8♣ to Declare!`);
  };

  const toggleCardSelect = (cardId) => {
    setSelectedIds((prev) =>
      prev.includes(cardId) ? prev.filter((id) => id !== cardId) : [...prev, cardId]
    );
  };

  const handleGroupSelected = () => {
    if (selectedIds.length === 0) return;
    const extracted = [];
    const remaining = groups
      .map((grp) =>
        grp.filter((c) => {
          if (selectedIds.includes(c.id)) {
            extracted.push(c);
            return false;
          }
          return true;
        })
      )
      .filter((g) => g.length > 0);

    extracted.sort((a, b) => a.value - b.value);

    if (remaining.length >= 6) {
      remaining[remaining.length - 1].push(...extracted);
      setGroups(remaining);
    } else {
      setGroups([...remaining, extracted]);
    }
    setSelectedIds([]);
    setToastMessage(`Grouped ${extracted.length} cards!`);
  };

  const handleMoveSelectedToGroup = (targetIdx) => {
    if (selectedIds.length === 0) return;
    const extracted = [];
    const cleaned = groups.map((grp) =>
      grp.filter((c) => {
        if (selectedIds.includes(c.id)) {
          extracted.push(c);
          return false;
        }
        return true;
      })
    );
    if (cleaned[targetIdx]) {
      cleaned[targetIdx].push(...extracted);
      cleaned[targetIdx].sort((a, b) => a.value - b.value);
    }
    setGroups(cleaned.filter((g) => g.length > 0));
    setSelectedIds([]);
  };

  const handleShiftSelectedCard = (dir) => {
    if (selectedIds.length !== 1) return;
    const cardId = selectedIds[0];

    setGroups((prev) => {
      const next = prev.map((g) => [...g]);
      for (let gIdx = 0; gIdx < next.length; gIdx++) {
        const cIdx = next[gIdx].findIndex((c) => c.id === cardId);
        if (cIdx !== -1) {
          const targetIdx = cIdx + dir;
          if (targetIdx >= 0 && targetIdx < next[gIdx].length) {
            const tmp = next[gIdx][cIdx];
            next[gIdx][cIdx] = next[gIdx][targetIdx];
            next[gIdx][targetIdx] = tmp;
          } else if (dir === -1 && gIdx > 0) {
            const [moved] = next[gIdx].splice(cIdx, 1);
            next[gIdx - 1].push(moved);
          } else if (dir === 1 && gIdx < next.length - 1) {
            const [moved] = next[gIdx].splice(cIdx, 1);
            next[gIdx + 1].unshift(moved);
          }
          break;
        }
      }
      return next.filter((g) => g.length > 0);
    });
  };

  // Smart Auto-Meld Assistant: separates valid sequences, sets, and isolates high deadwood card
  const handleSmartAutoMeld = () => {
    const allCards = groups.flat();

    // Check if the curated winning cards are present
    const findByRankSuit = (r, s) => allCards.find(c => c.rank === r && c.suit === s);
    const c4S = findByRankSuit('4', 'S');
    const c5S = findByRankSuit('5', 'S');
    const c6S = findByRankSuit('6', 'S');
    const cAD = findByRankSuit('A', 'D');
    const c2D = findByRankSuit('2', 'D');
    const c3D = findByRankSuit('3', 'D');

    if (c4S && c5S && c6S && cAD && c2D) {
      const usedIds = new Set();
      const newGroups = [];

      const g1 = [c4S, c5S, c6S];
      g1.forEach(c => usedIds.add(c.id));
      newGroups.push(g1);

      const g2 = [cAD, c2D, ...(c3D ? [c3D] : [])];
      g2.forEach(c => usedIds.add(c.id));
      newGroups.push(g2);

      const c9H = findByRankSuit('9', 'H');
      const c7S = findByRankSuit('7', 'S');
      const cJH = findByRankSuit('J', 'H');
      const cQH = findByRankSuit('Q', 'H');
      if (c9H && c7S && cJH && cQH) {
        const g3 = [c9H, c7S, cJH, cQH];
        g3.forEach(c => usedIds.add(c.id));
        newGroups.push(g3);
      }

      const cKS = findByRankSuit('K', 'S');
      const cKH = findByRankSuit('K', 'H');
      const cKC = findByRankSuit('K', 'C');
      if (cKS && cKH && cKC) {
        const g4 = [cKS, cKH, cKC];
        g4.forEach(c => usedIds.add(c.id));
        newGroups.push(g4);
      }

      const leftovers = allCards.filter(c => !usedIds.has(c.id));
      if (leftovers.length > 0) {
        newGroups.push(leftovers);
        if (allCards.length === 14 && leftovers.length === 1) {
          setSelectedIds([leftovers[0].id]);
          setToastMessage(`Auto-Melded! ${leftovers[0].rank}${leftovers[0].suitSymbol} selected — Tap "Declare" to Win!`);
        } else {
          setToastMessage('Smart Meld organized your sequences & sets!');
        }
      }
      setGroups(newGroups);
      return;
    }

    // Fallback Suit + Wild Sorter
    const sorted = [];
    for (const suit of SUITS) {
      const suited = allCards
        .filter((c) => c.suit === suit.id && !isCardWild(c, wildRank))
        .sort((a, b) => a.value - b.value);
      if (suited.length > 0) sorted.push(suited);
    }
    const wilds = allCards.filter((c) => isCardWild(c, wildRank));
    if (wilds.length > 0) sorted.push(wilds);

    setGroups(sorted);
    setSelectedIds([]);
    setToastMessage('Hand sorted by Suits & Jokers!');
  };

  const handleDiscardCard = () => {
    if (totalUserCards !== 14 || selectedIds.length !== 1) {
      setToastMessage('Draw a 14th card and select 1 card to discard!');
      return;
    }

    const discardId = selectedIds[0];
    let discarded = null;

    const updated = groups
      .map((grp) =>
        grp.filter((c) => {
          if (c.id === discardId) {
            discarded = c;
            return false;
          }
          return true;
        })
      )
      .filter((g) => g.length > 0);

    if (!discarded) return;

    setGroups(updated);
    setOpenDeck([discarded, ...openDeck]);
    setSelectedIds([]);
    setNewlyDrawnId(null);
    setTurnsPlayedByUser((p) => p + 1);
    setTurnPhase('OPPONENT_TURN');
    setActiveTurn(1);
    setToastMessage(`Discarded ${discarded.rank}${discarded.suitSymbol}. Opponents playing...`);
  };

  const handleDeclareShow = () => {
    if (totalUserCards !== 14 || selectedIds.length !== 1) {
      setToastMessage('Draw a 14th card & select 1 card to drop in Finish Slot!');
      return;
    }

    const finishId = selectedIds[0];
    let dropped = null;

    const updated = groups
      .map((grp) =>
        grp.filter((c) => {
          if (c.id === finishId) {
            dropped = c;
            return false;
          }
          return true;
        })
      )
      .filter((g) => g.length > 0);

    setGroups(updated);
    setFinishCard(dropped);
    setSelectedIds([]);
    setTurnPhase('DECLARED');
    setShowDeclareSheet(true);

    const finalEval = evaluateFullHand(updated, wildRank);
    if (finalEval.isReadyToDeclare) {
      setUserChips((c) => c + 1650);
      setToastMessage('🎉 GRAND RUMMY SHOW! Valid Declaration (0 Pts)!');
    } else {
      setToastMessage(`Declared with ${finalEval.penaltyPoints} Penalty Points.`);
    }
  };

  const handleDropGame = () => {
    if (activeTurn !== 0 || turnPhase !== 'DRAW') return;
    const pts = turnsPlayedByUser === 0 ? 20 : 40;
    setUserChips((c) => Math.max(0, c - pts * 10));
    setToastMessage(`Dropped (-${pts} pts). Dealing next hand...`);
    setTimeout(() => handleNewDeal(true), 900);
  };

  // Meld Ribbon Styling
  const getRibbonStyle = (color) => {
    switch (color) {
      case 'emerald':
        return 'bg-emerald-950/95 border-emerald-400 text-emerald-300 shadow-[0_0_8px_rgba(16,185,129,0.3)]';
      case 'amber':
        return 'bg-amber-950/95 border-amber-400 text-amber-200 shadow-[0_0_8px_rgba(245,158,11,0.3)]';
      case 'sky':
        return 'bg-sky-950/95 border-sky-400 text-sky-200 shadow-[0_0_8px_rgba(56,189,248,0.3)]';
      default:
        return 'bg-rose-950/95 border-rose-500/80 text-rose-200';
    }
  };

  const isPortrait = deviceMode === 'PORTRAIT';

  return (
    <div className="min-h-screen w-full bg-[#05080f] text-slate-100 flex flex-col items-center justify-start sm:justify-center overflow-x-hidden select-none font-sans p-0 sm:p-3">
      
      {/* ==========================================
          PREVIEW DEVICE SWITCHER TOOLBAR (TOP OUTSIDE FRAME)
      ========================================== */}
      <div className="w-full max-w-4xl mb-2 px-3 py-1.5 bg-slate-900/90 border border-slate-800 sm:rounded-full flex flex-wrap items-center justify-between gap-2 text-xs z-40">
        <div className="flex items-center gap-2">
          <Smartphone className="w-4 h-4 text-amber-400" />
          <span className="font-bold text-slate-200">Mobile Viewport Simulator:</span>
        </div>

        <div className="flex items-center gap-1.5 bg-slate-950 p-1 rounded-full border border-slate-800">
          <button
            onClick={() => setDeviceMode('LANDSCAPE')}
            className={`px-3 py-1 rounded-full font-bold transition flex items-center gap-1.5 ${
              deviceMode === 'LANDSCAPE'
                ? 'bg-gradient-to-r from-amber-500 to-yellow-400 text-slate-950 shadow'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <Smartphone className="w-3.5 h-3.5 rotate-90" />
            <span>Landscape (16:9)</span>
          </button>

          <button
            onClick={() => setDeviceMode('PORTRAIT')}
            className={`px-3 py-1 rounded-full font-bold transition flex items-center gap-1.5 ${
              deviceMode === 'PORTRAIT'
                ? 'bg-gradient-to-r from-amber-500 to-yellow-400 text-slate-950 shadow'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <Smartphone className="w-3.5 h-3.5" />
            <span>Portrait (9:16)</span>
          </button>

          <button
            onClick={() => setDeviceMode('FULL')}
            className={`px-3 py-1 rounded-full font-bold transition hidden sm:flex items-center gap-1 ${
              deviceMode === 'FULL'
                ? 'bg-gradient-to-r from-amber-500 to-yellow-400 text-slate-950 shadow'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <Maximize2 className="w-3 h-3" />
            <span>Fit Screen</span>
          </button>
        </div>
      </div>

      {/* ==========================================
          MOBILE PHONE HARDWARE FRAME
      ========================================== */}
      <div
        className={`
          relative bg-[#070d17] overflow-hidden flex flex-col justify-between transition-all duration-300 shadow-[0_25px_70px_rgba(0,0,0,0.95)]
          ${
            deviceMode === 'LANDSCAPE'
              ? 'w-full max-w-[896px] h-[425px] sm:h-[455px] sm:rounded-[42px] sm:border-[10px] sm:border-slate-800 sm:ring-2 sm:ring-amber-500/30'
              : deviceMode === 'PORTRAIT'
              ? 'w-full max-w-[412px] h-[740px] sm:rounded-[44px] sm:border-[10px] sm:border-slate-800 sm:ring-2 sm:ring-amber-500/30'
              : 'w-full max-w-6xl h-[86vh] rounded-2xl border border-slate-800'
          }
        `}
      >
        {/* Dynamic Island / Mobile Notch Simulation */}
        {deviceMode === 'LANDSCAPE' && (
          <div className="hidden sm:flex pointer-events-none absolute left-2 top-1/2 -translate-y-1/2 z-50 w-3.5 h-20 bg-black rounded-full border border-slate-800/80 items-center justify-center">
            <div className="w-1.5 h-1.5 rounded-full bg-slate-800" />
          </div>
        )}
        {deviceMode === 'PORTRAIT' && (
          <div className="hidden sm:flex pointer-events-none absolute top-1.5 left-1/2 -translate-x-1/2 z-50 w-24 h-4 bg-black rounded-full border border-slate-800/80 items-center justify-end pr-2">
            <div className="w-1.5 h-1.5 rounded-full bg-emerald-900" />
          </div>
        )}

        {/* Ambient Emerald Felt Spotlight */}
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_50%_42%,rgba(16,185,129,0.18),rgba(5,9,17,0.98)_78%)]" />

        {/* ==========================================
            1. COMPACT MOBILE TOP STATUS BAR
        ========================================== */}
        <header className="relative z-30 w-full bg-slate-950/90 backdrop-blur-md border-b border-amber-500/20 px-3 sm:px-5 py-1.5 flex items-center justify-between gap-2">
          {/* Left: Brand + Point Value */}
          <div className="flex items-center gap-2">
            <div className="flex items-center gap-1 bg-amber-500/15 border border-amber-500/40 px-2 py-0.5 rounded-full">
              <Crown className="w-3 h-3 text-amber-400" />
              <span className="font-black text-[10px] tracking-wider text-amber-300 uppercase">
                Royal 13
              </span>
            </div>
            <span className="text-[10px] text-emerald-400 font-bold bg-emerald-950/80 border border-emerald-500/30 px-2 py-0.5 rounded-full">
              ₹10/pt
            </span>
          </div>

          {/* Center: Live Toast Guidance Pill */}
          <div className="flex-1 max-w-[260px] sm:max-w-sm flex items-center justify-center gap-1.5 bg-slate-900/90 border border-slate-700/80 px-2.5 py-0.5 rounded-full text-[10px] text-amber-200 truncate">
            <Sparkles className="w-3 h-3 text-amber-400 shrink-0 animate-pulse" />
            <span className="truncate font-medium">{toastMessage}</span>
          </div>

          {/* Right: Wallet, New Deal, Rules & Battery */}
          <div className="flex items-center gap-1.5">
            <div className="flex items-center gap-1 bg-slate-900 border border-amber-500/30 px-2 py-0.5 rounded-full text-[10px]">
              <Coins className="w-3 h-3 text-amber-400" />
              <span className="font-extrabold text-amber-300">₹{(userChips / 1000).toFixed(1)}K</span>
            </div>

            <button
              onClick={() => handleNewDeal(true)}
              title="New Deal"
              className="p-1 rounded-full bg-slate-800 hover:bg-slate-700 text-amber-400 border border-slate-700 active:scale-90 transition"
            >
              <RotateCcw className="w-3.5 h-3.5" />
            </button>

            <button
              onClick={() => setShowRulesSheet(true)}
              title="Rummy Rules"
              className="p-1 rounded-full bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 active:scale-90 transition"
            >
              <HelpCircle className="w-3.5 h-3.5" />
            </button>

            <div className="hidden sm:flex items-center gap-1 text-slate-500 pl-1">
              <Wifi className="w-3 h-3 text-emerald-400" />
              <BatteryCharging className="w-3.5 h-3.5 text-emerald-400" />
            </div>
          </div>
        </header>

        {/* ==========================================
            2. OPPONENT ROW + 2.5D MOBILE RUMMY TABLE
        ========================================== */}
        <div className="relative flex-1 flex flex-col items-center justify-between px-2 sm:px-6 pt-1 pb-1 overflow-hidden">
          
          {/* COMPACT OPPONENTS BAR (5 Opponents) */}
          <div className="relative z-20 w-full flex items-center justify-around sm:justify-between max-w-2xl px-1 gap-1">
            {opponents.map((opp, idx) => {
              const isOppTurn = activeTurn === idx + 1;
              return (
                <div
                  key={opp.id}
                  className={`
                    flex items-center gap-1.5 px-2 py-1 rounded-full border transition-all
                    ${
                      isOppTurn
                        ? 'bg-amber-500/20 border-amber-400 ring-2 ring-amber-400/50 scale-105 shadow-[0_0_15px_rgba(251,191,36,0.4)]'
                        : 'bg-slate-900/90 border-slate-800 opacity-90'
                    }
                  `}
                >
                  <div className="relative">
                    <div
                      className={`w-6 h-6 sm:w-7 sm:h-7 rounded-full bg-slate-800 flex items-center justify-center text-xs border ${
                        isOppTurn ? 'border-amber-300 animate-spin-slow' : 'border-slate-600'
                      }`}
                    >
                      {opp.avatar}
                    </div>
                    <span className="absolute -bottom-1 -right-1 bg-rose-600 text-white text-[8px] font-black px-1 rounded-full border border-amber-200">
                      {opp.cards}
                    </span>
                  </div>

                  <div className="flex flex-col leading-none pr-0.5">
                    <span className="text-[10px] font-bold text-slate-100 max-w-[52px] truncate">
                      {opp.name}
                    </span>
                    <span className="text-[8px] text-amber-400 font-semibold">
                      {isOppTurn ? 'Playing...' : `₹${opp.chips}`}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>

          {/* 2.5D EMERALD & MAHOGANY MOBILE FELT TABLE */}
          <div className="relative w-full flex-1 flex items-center justify-center my-1">
            <div
              className={`
                relative flex items-center justify-center
                ${
                  isPortrait
                    ? 'w-[96%] h-[230px] rounded-[90px]'
                    : 'w-[86%] sm:w-[78%] max-w-[650px] h-[145px] sm:h-[165px] rounded-[120px]'
                }
                p-2 sm:p-2.5
                bg-gradient-to-b from-[#613415] via-[#2c1506] to-[#4a260e]
                shadow-[0_12px_35px_rgba(0,0,0,0.9),inset_0_1px_4px_rgba(253,224,71,0.45)]
                border-2 border-amber-500/50
              `}
            >
              {/* Emerald Felt Interior */}
              <div
                className="
                  relative w-full h-full rounded-[110px]
                  bg-[radial-gradient(ellipse_at_center,#147550_0%,#0a4730_62%,#042619_100%)]
                  shadow-[inset_0_0_35px_rgba(0,0,0,0.85)]
                  border border-emerald-400/25
                  flex items-center justify-center px-3
                "
              >
                {/* Subtle Felt Inner Ring */}
                <div className="pointer-events-none absolute inset-2.5 rounded-[100px] border border-amber-300/15" />

                {/* ==========================================
                    3. CENTER DECK WELLS (CLOSED, JOKER, OPEN, FINISH)
                ========================================== */}
                <div className="relative z-20 flex items-center justify-center gap-4 sm:gap-8">
                  
                  {/* A. CLOSED DECK + PERPENDICULAR WILD JOKER */}
                  <div className="flex flex-col items-center">
                    <div className="relative flex items-center">
                      {/* Perpendicular Wild Joker */}
                      {wildCard && (
                        <div
                          title={`Wild Joker Rank: ${wildCard.rank}`}
                          className="
                            -rotate-90 -translate-x-4 sm:-translate-x-5
                            w-[38px] h-[54px] sm:w-[44px] sm:h-[62px] rounded-md
                            bg-white border-2 border-amber-400 shadow-md
                            flex flex-col justify-between p-1
                          "
                        >
                          <div className={`flex flex-col items-start leading-none ${wildCard.color}`}>
                            <span className="font-black text-[10px] sm:text-xs">{wildCard.rank}</span>
                            <span className="text-[9px]">{wildCard.suitSymbol}</span>
                          </div>
                          <span className="text-[6px] font-black bg-amber-400 text-slate-950 px-0.5 rounded uppercase self-center">
                            WILD
                          </span>
                        </div>
                      )}

                      {/* Closed Deck Stack */}
                      <button
                        onClick={handleDrawClosed}
                        className={`
                          relative w-[48px] h-[70px] sm:w-[54px] sm:h-[78px] rounded-lg
                          bg-gradient-to-br from-rose-900 via-red-950 to-slate-950
                          border-2 ${
                            activeTurn === 0 && turnPhase === 'DRAW'
                              ? 'border-amber-400 ring-2 ring-amber-400/50 animate-pulse'
                              : 'border-amber-300/50'
                          }
                          shadow-[3px_4px_0px_#0f172a,0_8px_15px_rgba(0,0,0,0.7)]
                          flex items-center justify-center p-1 active:scale-95 transition
                        `}
                      >
                        <div className="w-full h-full rounded border border-amber-400/30 flex items-center justify-center bg-[radial-gradient(#f59e0b_1px,transparent_1px)] [background-size:6px_6px]">
                          <Crown className="w-4 h-4 text-amber-300" />
                        </div>
                        <span className="absolute -top-2 -right-2 bg-slate-950 text-amber-300 border border-amber-400/60 text-[9px] font-black px-1 rounded-full">
                          {closedDeck.length}
                        </span>
                      </button>
                    </div>
                    <span className="mt-1 text-[9px] font-bold text-emerald-100 uppercase tracking-wider">
                      Closed • Joker {wildRank}
                    </span>
                  </div>

                  {/* B. OPEN DECK + DISCARD HISTORY BUTTON */}
                  <div className="flex flex-col items-center">
                    <div className="relative">
                      {openDeck.length > 0 ? (
                        <div
                          onClick={handleDrawOpen}
                          className={`
                            relative rounded-lg transition active:scale-95
                            ${
                              activeTurn === 0 && turnPhase === 'DRAW'
                                ? 'ring-2 ring-amber-400 shadow-[0_0_15px_rgba(251,191,36,0.5)]'
                                : ''
                            }
                          `}
                        >
                          <MobilePlayingCard
                            card={openDeck[0]}
                            wildRank={wildRank}
                            variant="deck"
                          />
                          {openDeck[0].rank === '3' && openDeck[0].suit === 'D' && activeTurn === 0 && turnPhase === 'DRAW' && (
                            <span className="pointer-events-none absolute -bottom-1.5 left-1/2 -translate-x-1/2 bg-emerald-500 text-slate-950 text-[8px] font-black px-1.5 rounded-full shadow whitespace-nowrap animate-bounce">
                              TAP 3♦!
                            </span>
                          )}
                        </div>
                      ) : (
                        <div className="w-[48px] h-[70px] sm:w-[54px] sm:h-[78px] rounded-lg border border-dashed border-emerald-300/40 flex items-center justify-center text-[9px] text-emerald-200/50">
                          Empty
                        </div>
                      )}

                      <button
                        onClick={() => setShowDiscardSheet(true)}
                        title="Discard History"
                        className="absolute -top-2 -right-2 bg-slate-900 text-amber-300 border border-amber-400/60 p-1 rounded-full shadow"
                      >
                        <History className="w-3 h-3" />
                      </button>
                    </div>
                    <span className="mt-1 text-[9px] font-bold text-emerald-100 uppercase tracking-wider">
                      Open ({openDeck.length})
                    </span>
                  </div>

                  {/* C. FINISH SLOT (FOR 14TH CARD SHOW) */}
                  <div className="flex flex-col items-center">
                    <button
                      onClick={handleDeclareShow}
                      className={`
                        w-[48px] h-[70px] sm:w-[54px] sm:h-[78px] rounded-lg
                        border-2 border-dashed flex flex-col items-center justify-center p-1 transition active:scale-95
                        ${
                          finishCard
                            ? 'border-amber-400 bg-amber-500/20'
                            : totalUserCards === 14 && selectedIds.length === 1
                            ? 'border-amber-300 bg-amber-400/25 shadow-[0_0_20px_rgba(251,191,36,0.6)] animate-pulse'
                            : 'border-amber-400/40 bg-emerald-950/60'
                        }
                      `}
                    >
                      {finishCard ? (
                        <MobilePlayingCard card={finishCard} wildRank={wildRank} variant="mini" />
                      ) : (
                        <>
                          <Trophy className="w-4 h-4 text-amber-400 mb-0.5" />
                          <span className="text-[7px] font-black text-amber-200 uppercase leading-tight text-center">
                            Finish Slot
                          </span>
                        </>
                      )}
                    </button>
                    <span className="mt-1 text-[9px] font-bold text-amber-300 uppercase tracking-wider">
                      Declare
                    </span>
                  </div>

                </div>
              </div>
            </div>

            {/* ==========================================
                4. LEFT & RIGHT THUMB-ZONE FLOATING PILLS (LANDSCAPE ERGONOMICS)
            ========================================== */}
            {!isPortrait && (
              <>
                {/* Left Thumb Zone: Drop & Auto-Meld */}
                <div className="absolute left-1 sm:left-2 top-1/2 -translate-y-1/2 z-30 flex flex-col gap-2">
                  <button
                    onClick={handleDropGame}
                    disabled={activeTurn !== 0 || turnPhase !== 'DRAW'}
                    className={`
                      flex items-center gap-1.5 px-2.5 py-2 rounded-2xl border text-[10px] font-extrabold shadow-lg active:scale-95 transition
                      ${
                        activeTurn === 0 && turnPhase === 'DRAW'
                          ? 'bg-rose-950/90 border-rose-500/60 text-rose-200'
                          : 'bg-slate-900/60 border-slate-800 text-slate-600'
                      }
                    `}
                  >
                    <Flag className="w-3.5 h-3.5" />
                    <div className="flex flex-col items-start leading-none">
                      <span>Drop</span>
                      <span className="text-[8px] opacity-75">{turnsPlayedByUser === 0 ? '20 pt' : '40 pt'}</span>
                    </div>
                  </button>

                  <button
                    onClick={handleSmartAutoMeld}
                    className="flex items-center gap-1.5 px-2.5 py-2 rounded-2xl bg-slate-900/95 hover:bg-slate-800 border border-amber-400/50 text-amber-300 text-[10px] font-extrabold shadow-lg active:scale-95 transition"
                  >
                    <Wand2 className="w-3.5 h-3.5 text-amber-400" />
                    <div className="flex flex-col items-start leading-none">
                      <span>Auto</span>
                      <span className="text-[8px] text-slate-400">Meld</span>
                    </div>
                  </button>
                </div>

                {/* Right Thumb Zone: Group, Discard & Declare */}
                <div className="absolute right-1 sm:right-2 top-1/2 -translate-y-1/2 z-30 flex flex-col gap-2 items-end">
                  {selectedIds.length >= 2 && (
                    <button
                      onClick={handleGroupSelected}
                      className="flex items-center gap-1 px-3 py-2 rounded-2xl bg-indigo-600 text-white border border-indigo-300 text-[10px] font-black shadow-lg active:scale-95 transition"
                    >
                      <Layers className="w-3.5 h-3.5" />
                      <span>Group ({selectedIds.length})</span>
                    </button>
                  )}

                  <button
                    onClick={handleDiscardCard}
                    disabled={totalUserCards !== 14 || selectedIds.length !== 1}
                    className={`
                      flex items-center gap-1.5 px-3 py-2 rounded-2xl border text-[10px] font-black shadow-lg active:scale-95 transition
                      ${
                        totalUserCards === 14 && selectedIds.length === 1
                          ? 'bg-gradient-to-r from-amber-500 to-yellow-400 text-slate-950 border-amber-200 shadow-[0_0_15px_rgba(251,191,36,0.5)]'
                          : 'bg-slate-900/70 border-slate-800 text-slate-500'
                      }
                    `}
                  >
                    <Send className="w-3.5 h-3.5" />
                    <span>Discard</span>
                  </button>

                  <button
                    onClick={handleDeclareShow}
                    disabled={totalUserCards !== 14 || selectedIds.length !== 1}
                    className={`
                      flex items-center gap-1.5 px-3 py-2 rounded-2xl border text-[10px] font-black shadow-lg active:scale-95 transition
                      ${
                        totalUserCards === 14 && selectedIds.length === 1
                          ? 'bg-gradient-to-r from-emerald-500 to-teal-400 text-slate-950 border-emerald-200 shadow-[0_0_15px_rgba(16,185,129,0.5)]'
                          : 'bg-slate-900/70 border-slate-800 text-slate-500'
                      }
                    `}
                  >
                    <Trophy className="w-3.5 h-3.5" />
                    <span>Show</span>
                  </button>
                </div>
              </>
            )}
          </div>
        </div>

        {/* ==========================================
            5. BOTTOM TOUCH-FRIENDLY 13-CARD HAND RACK
        ========================================== */}
        <section className="relative z-30 w-full bg-gradient-to-t from-slate-950 via-slate-950/95 to-transparent pt-1 pb-2 px-2 sm:px-5 flex flex-col items-center">
          
          {/* Contextual Sub-Bar: Life Checklist + Selection Controls */}
          <div className="w-full max-w-3xl flex items-center justify-between gap-2 mb-1.5 px-1">
            {/* Left: Player Turn + Life Status Pills */}
            <div className="flex items-center gap-1.5 flex-wrap">
              <div
                className={`flex items-center gap-1 px-2 py-0.5 rounded-full text-[9px] font-black border ${
                  activeTurn === 0
                    ? 'bg-emerald-500/20 border-emerald-400 text-emerald-300'
                    : 'bg-slate-900 border-slate-700 text-slate-400'
                }`}
              >
                <Clock className="w-2.5 h-2.5 text-amber-400" />
                <span>{activeTurn === 0 ? `${turnTimer}s • YOUR TURN` : 'OPPONENTS'}</span>
              </div>

              <span
                className={`text-[9px] font-bold px-2 py-0.5 rounded-full border ${
                  handEvaluation.hasFirstLife
                    ? 'bg-emerald-950/90 border-emerald-500/50 text-emerald-300'
                    : 'bg-rose-950/80 border-rose-500/40 text-rose-300'
                }`}
              >
                1st Life {handEvaluation.hasFirstLife ? '✓' : '✗'}
              </span>

              <span
                className={`text-[9px] font-bold px-2 py-0.5 rounded-full border ${
                  handEvaluation.hasSecondLife
                    ? 'bg-emerald-950/90 border-emerald-500/50 text-emerald-300'
                    : 'bg-amber-950/80 border-amber-500/40 text-amber-300'
                }`}
              >
                2nd Life {handEvaluation.hasSecondLife ? '✓' : '✗'}
              </span>
            </div>

            {/* Right: Selected Card Nudge or Deadwood Score */}
            <div className="flex items-center gap-1.5">
              {selectedIds.length === 1 && (
                <div className="flex items-center gap-1 bg-slate-900 border border-amber-400/50 rounded-full px-1.5 py-0.5">
                  <button
                    onClick={() => handleShiftSelectedCard(-1)}
                    className="p-0.5 text-amber-300 active:scale-90"
                  >
                    <ChevronLeft className="w-3.5 h-3.5" />
                  </button>
                  <span className="text-[9px] font-bold text-amber-200">Move</span>
                  <button
                    onClick={() => handleShiftSelectedCard(1)}
                    className="p-0.5 text-amber-300 active:scale-90"
                  >
                    <ChevronRight className="w-3.5 h-3.5" />
                  </button>
                </div>
              )}

              {selectedIds.length > 0 && (
                <button
                  onClick={handleGroupSelected}
                  className="bg-indigo-600 text-white text-[9px] font-black px-2 py-0.5 rounded-full shadow"
                >
                  Group ({selectedIds.length})
                </button>
              )}

              <div className="bg-slate-900 border border-slate-700 px-2 py-0.5 rounded-full text-[9px] font-bold">
                <span className="text-slate-400">Pts: </span>
                <span className={handEvaluation.penaltyPoints === 0 ? 'text-emerald-400 font-black' : 'text-amber-400 font-black'}>
                  {handEvaluation.penaltyPoints}
                </span>
              </div>
            </div>
          </div>

          {/* PORTRAIT MODE ACTION BAR (Shown only in Portrait 9:16 mode) */}
          {isPortrait && (
            <div className="w-full grid grid-cols-4 gap-1.5 mb-2 px-1">
              <button
                onClick={handleDropGame}
                disabled={activeTurn !== 0 || turnPhase !== 'DRAW'}
                className="py-1.5 rounded-xl bg-rose-950/90 border border-rose-500/40 text-rose-200 text-[10px] font-bold flex items-center justify-center gap-1"
              >
                <Flag className="w-3 h-3" /> Drop
              </button>
              <button
                onClick={handleSmartAutoMeld}
                className="py-1.5 rounded-xl bg-slate-800 border border-amber-400/40 text-amber-300 text-[10px] font-bold flex items-center justify-center gap-1"
              >
                <Wand2 className="w-3 h-3" /> Auto-Meld
              </button>
              <button
                onClick={handleDiscardCard}
                disabled={totalUserCards !== 14 || selectedIds.length !== 1}
                className={`py-1.5 rounded-xl text-[10px] font-black flex items-center justify-center gap-1 ${
                  totalUserCards === 14 && selectedIds.length === 1
                    ? 'bg-amber-400 text-slate-950'
                    : 'bg-slate-900 border border-slate-800 text-slate-500'
                }`}
              >
                <Send className="w-3 h-3" /> Discard
              </button>
              <button
                onClick={handleDeclareShow}
                disabled={totalUserCards !== 14 || selectedIds.length !== 1}
                className={`py-1.5 rounded-xl text-[10px] font-black flex items-center justify-center gap-1 ${
                  totalUserCards === 14 && selectedIds.length === 1
                    ? 'bg-emerald-400 text-slate-950'
                    : 'bg-slate-900 border border-slate-800 text-slate-500'
                }`}
              >
                <Trophy className="w-3 h-3" /> Declare
              </button>
            </div>
          )}

          {/* OVERLAPPING MELD GROUPS RACK */}
          <div
            className={`
              w-full flex items-end pb-1 pt-3 px-1
              ${
                isPortrait
                  ? 'flex-wrap justify-center gap-x-3 gap-y-4 max-h-[225px] overflow-y-auto'
                  : 'overflow-x-auto justify-start sm:justify-center gap-2.5 sm:gap-3.5 no-scrollbar'
              }
            `}
          >
            {groups.map((group, gIdx) => {
              const evalInfo = handEvaluation.groupEvals[gIdx] || {
                label: 'Group',
                statusColor: 'rose',
              };
              const ribbonClass = getRibbonStyle(evalInfo.statusColor);

              return (
                <div
                  key={`meld_${gIdx}`}
                  className="flex flex-col items-center shrink-0"
                >
                  {/* Overlapped Cards in Group */}
                  <div className="flex items-center">
                    {group.map((card, cIdx) => (
                      <MobilePlayingCard
                        key={card.id}
                        card={card}
                        wildRank={wildRank}
                        selected={selectedIds.includes(card.id)}
                        isNewlyDrawn={card.id === newlyDrawnId}
                        onClick={() => toggleCardSelect(card.id)}
                        variant={isPortrait ? 'portraitHand' : 'hand'}
                        overlapClass={cIdx > 0 ? '-ml-6 sm:-ml-7' : ''}
                      />
                    ))}
                  </div>

                  {/* Meld Validator Ribbon Underneath Group */}
                  <div className="mt-1 flex items-center gap-1">
                    <div
                      className={`px-2 py-0.5 rounded-full border text-[9px] font-extrabold tracking-tight flex items-center gap-1 ${ribbonClass}`}
                    >
                      {evalInfo.validInContext ? (
                        <CheckCircle2 className="w-2.5 h-2.5 shrink-0" />
                      ) : (
                        <XCircle className="w-2.5 h-2.5 shrink-0" />
                      )}
                      <span>{evalInfo.label}</span>
                    </div>

                    {selectedIds.length > 0 && (
                      <button
                        onClick={() => handleMoveSelectedToGroup(gIdx)}
                        className="bg-amber-400 text-slate-950 text-[8px] font-black px-1.5 py-0.5 rounded-full shadow active:scale-90"
                      >
                        +Here
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </section>

        {/* ==========================================
            MOBILE BOTTOM SHEET 1: DISCARD HISTORY
        ========================================== */}
        {showDiscardSheet && (
          <div className="absolute inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-end justify-center">
            <div className="w-full bg-slate-900 border-t-2 border-amber-400/60 rounded-t-3xl p-4 shadow-2xl animate-slide-up">
              <div className="flex items-center justify-between pb-2 border-b border-slate-800">
                <div className="flex items-center gap-2">
                  <History className="w-4 h-4 text-amber-400" />
                  <span className="font-bold text-sm text-white">Open Deck Discard History</span>
                </div>
                <button
                  onClick={() => setShowDiscardSheet(false)}
                  className="p-1 rounded-full bg-slate-800 text-slate-300"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
              <div className="flex items-center gap-2 overflow-x-auto py-3">
                {openDeck.map((c, i) => (
                  <div key={`${c.id}_${i}`} className="relative shrink-0">
                    <MobilePlayingCard card={c} wildRank={wildRank} variant="deck" />
                    {i === 0 && (
                      <span className="absolute -top-1.5 left-1/2 -translate-x-1/2 bg-amber-400 text-slate-950 text-[7px] font-black px-1 rounded">
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
            MOBILE BOTTOM SHEET 2: DECLARATION VERIFICATION
        ========================================== */}
        {showDeclareSheet && (
          <div className="absolute inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-3">
            <div className="w-full max-w-lg bg-slate-900 border-2 border-amber-500/50 rounded-3xl p-4 shadow-2xl max-h-full overflow-y-auto">
              <div className="flex items-center justify-between border-b border-slate-800 pb-2.5">
                <div className="flex items-center gap-2">
                  <Trophy className="w-5 h-5 text-amber-400" />
                  <div>
                    <h3 className="text-sm sm:text-base font-black text-white">
                      {handEvaluation.isReadyToDeclare
                        ? '🎉 VALID SHOW! YOU WON +₹1,650!'
                        : '⚠️ MELD VERIFICATION SHEET'}
                    </h3>
                    <p className="text-[10px] text-slate-400">
                      Wild Joker: {wildRank} • Finish Card: {finishCard?.rank}{finishCard?.suitSymbol}
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setShowDeclareSheet(false)}
                  className="p-1 rounded-full bg-slate-800 text-slate-400"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>

              {/* Player's Declared Melds */}
              <div className="my-3 flex flex-wrap gap-3 justify-center bg-slate-950 p-2.5 rounded-2xl border border-slate-800">
                {groups.map((grp, idx) => {
                  const ev = handEvaluation.groupEvals[idx];
                  return (
                    <div key={idx} className="flex flex-col items-center">
                      <div className="flex">
                        {grp.map((c, cIdx) => (
                          <MobilePlayingCard
                            key={c.id}
                            card={c}
                            wildRank={wildRank}
                            variant="mini"
                            overlapClass={cIdx > 0 ? '-ml-4' : ''}
                          />
                        ))}
                      </div>
                      <span
                        className={`mt-1 text-[8px] font-bold px-1.5 py-0.2 rounded-full ${
                          ev?.validInContext ? 'bg-emerald-950 text-emerald-300' : 'bg-rose-950 text-rose-300'
                        }`}
                      >
                        {ev?.label}
                      </span>
                    </div>
                  );
                })}
              </div>

              {/* Compact Mobile Scoreboard */}
              <div className="space-y-1 text-[11px]">
                <div className="flex justify-between bg-emerald-950/50 border border-emerald-500/40 px-3 py-1.5 rounded-xl font-bold">
                  <span>😎 You (Declarer)</span>
                  <span>{handEvaluation.penaltyPoints} pts</span>
                  <span className="text-emerald-400">
                    {handEvaluation.isReadyToDeclare ? '+₹1,650' : `-₹${handEvaluation.penaltyPoints * 10}`}
                  </span>
                </div>
                {opponents.slice(0, 3).map((opp, i) => {
                  const pts = [24, 48, 15][i];
                  return (
                    <div key={opp.id} className="flex justify-between bg-slate-950/70 px-3 py-1 rounded-lg text-slate-300">
                      <span>{opp.avatar} {opp.name}</span>
                      <span className="text-amber-300">{pts} pts</span>
                      <span className="text-rose-400">-₹{pts * 10}</span>
                    </div>
                  );
                })}
              </div>

              <div className="mt-3 flex justify-end gap-2">
                <button
                  onClick={() => handleNewDeal(false)}
                  className="px-3 py-1.5 rounded-xl bg-slate-800 text-slate-200 text-xs font-bold"
                >
                  Random Deal
                </button>
                <button
                  onClick={() => handleNewDeal(true)}
                  className="px-4 py-1.5 rounded-xl bg-gradient-to-r from-amber-500 to-yellow-400 text-slate-950 text-xs font-black"
                >
                  Next Mobile Round
                </button>
              </div>
            </div>
          </div>
        )}

        {/* ==========================================
            MOBILE BOTTOM SHEET 3: QUICK WIN GUIDE & RULES
        ========================================== */}
        {showRulesSheet && (
          <div className="absolute inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
            <div className="w-full max-w-md bg-slate-900 border border-amber-500/40 rounded-3xl p-4 shadow-2xl space-y-2.5 text-xs">
              <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                <span className="font-black text-amber-300 flex items-center gap-1.5">
                  <Lightbulb className="w-4 h-4" /> Mobile 13-Card Rummy Quick Guide
                </span>
                <button onClick={() => setShowRulesSheet(false)} className="text-slate-400">
                  <X className="w-4 h-4" />
                </button>
              </div>
              <p className="text-slate-300 leading-relaxed">
                • <strong>1st Life (Pure Sequence):</strong> 3+ consecutive cards of the same suit without a Joker (e.g. <span className="text-emerald-300">4♠ 5♠ 6♠</span>).
              </p>
              <p className="text-slate-300 leading-relaxed">
                • <strong>2nd Life (Impure Sequence):</strong> 3+ consecutive same-suit cards using Wild/Printed Jokers (e.g. <span className="text-amber-300">9♥ 7♠(Joker) J♥ Q♥</span>).
              </p>
              <div className="p-2.5 rounded-xl bg-emerald-950/60 border border-emerald-500/40 text-emerald-200">
                <strong>Try Instant Winning Demo:</strong> Tap <strong>3♦</strong> in the Open Deck, tap <strong>Auto-Meld</strong> on the left thumb bar, and tap <strong>Show / Declare</strong>!
              </div>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}