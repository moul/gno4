// The Connect Four rules, in the browser.
//
// This is a second implementation of gno.land/p/moul/gno4/v0, and that is a
// deliberate cost with a deliberate payoff: the page can show a board, animate
// a drop and refuse an illegal click without a round trip, and a shared link
// renders with no chain at all. What it must never do is disagree. The chain
// is always right; this only ever predicts it.
//
// Keeping them honest is cheap because a whole game is one string: the same
// encoding both sides read (`web/engine.test.js` replays the engine's own
// fixtures through this file).

export const COLS = 7;
export const ROWS = 6;
export const EMPTY = 0, RED = 1, YELLOW = 2;

const DIRS = [[1, 0], [0, 1], [1, 1], [1, -1]];

export function decode(s) {
  const b = newBoard();
  for (const ch of s || "") {
    const col = ch.charCodeAt(0) - 49; // '1'
    if (col < 0 || col >= COLS) return null;
    // `=== null`, not falsy: row 0 is a legal landing square and the floor is
    // where most moves land.
    if (drop(b, col) === null) return null;
  }
  return b;
}

export function newBoard() {
  return { cells: new Uint8Array(COLS * ROWS), moves: [], winner: EMPTY, line: [] };
}

export const idx = (col, row) => row * COLS + col;
export const at = (b, col, row) =>
  col < 0 || col >= COLS || row < 0 || row >= ROWS ? EMPTY : b.cells[idx(col, row)];
export const turn = (b) => (b.moves.length % 2 === 0 ? RED : YELLOW);
export const full = (b) => b.moves.length === COLS * ROWS;
export const over = (b) => b.winner !== EMPTY || full(b);
export const encode = (b) => b.moves.map((c) => c + 1).join("");

export function height(b, col) {
  let n = 0;
  while (n < ROWS && b.cells[idx(col, n)] !== EMPTY) n++;
  return n;
}

export function canDrop(b, col) {
  return !over(b) && col >= 0 && col < COLS && height(b, col) < ROWS;
}

// drop returns the row played, or null if the move is illegal. It is the only
// mutator, exactly as in the gno package, so an impossible position cannot be
// constructed by any other path.
export function drop(b, col) {
  if (!canDrop(b, col)) return null;
  const row = height(b, col);
  const d = turn(b);
  b.cells[idx(col, row)] = d;
  b.moves.push(col);
  const line = scan(b, col, row, d);
  if (line) { b.winner = d; b.line = line; }
  return row;
}

// scan never reads (col,row) itself, so it answers both "did this win" and
// "would this win", which is what makes winningMove need no copy.
function scan(b, col, row, d) {
  for (const [dx, dy] of DIRS) {
    const cells = [idx(col, row)];
    for (const sign of [1, -1]) {
      for (let step = 1; step < 4; step++) {
        const c = col + dx * sign * step, r = row + dy * sign * step;
        if (c < 0 || c >= COLS || r < 0 || r >= ROWS) break;
        if (b.cells[idx(c, r)] !== d) break;
        cells.push(idx(c, r));
      }
    }
    if (cells.length >= 4) {
      const out = [idx(col, row)];
      for (const sign of [1, -1]) {
        for (let step = 1; step < 4 && out.length < 4; step++) {
          const i = idx(col + dx * sign * step, row + dy * sign * step);
          if (!cells.includes(i)) break;
          out.push(i);
        }
      }
      return out.sort((x, y) => x - y);
    }
  }
  return null;
}

export function winningMove(b, d) {
  if (over(b)) return -1;
  for (let col = 0; col < COLS; col++) {
    const row = height(b, col);
    if (row >= ROWS) continue;
    if (scan(b, col, row, d)) return col;
  }
  return -1;
}

// bestMove is a small negamax with alpha-beta. It exists to make the page
// playable alone, and it is the part that could never live on chain: nobody
// should pay gas for someone else's search.
export function bestMove(b, depth = 6) {
  const order = [3, 2, 4, 1, 5, 0, 6];
  let best = -Infinity, bestCol = order.find((c) => canDrop(b, c));
  for (const col of order) {
    if (!canDrop(b, col)) continue;
    const child = clone(b);
    drop(child, col);
    const score = -negamax(child, depth - 1, -Infinity, Infinity);
    if (score > best) { best = score; bestCol = col; }
  }
  return bestCol;
}

function clone(b) {
  return { cells: b.cells.slice(), moves: b.moves.slice(), winner: b.winner, line: b.line.slice() };
}

function negamax(b, depth, alpha, beta) {
  if (b.winner !== EMPTY) return -1000 - depth; // losing sooner is worse
  if (full(b)) return 0;
  if (depth === 0) return heuristic(b, turn(b));
  let best = -Infinity;
  for (const col of [3, 2, 4, 1, 5, 0, 6]) {
    if (!canDrop(b, col)) continue;
    const child = clone(b);
    drop(child, col);
    best = Math.max(best, -negamax(child, depth - 1, -beta, -alpha));
    alpha = Math.max(alpha, best);
    if (alpha >= beta) break;
  }
  return best;
}

// heuristic: centre columns are worth more, because they take part in more
// possible lines than the edges do.
const WEIGHT = [1, 2, 3, 4, 3, 2, 1];
function heuristic(b, me) {
  let score = 0;
  for (let col = 0; col < COLS; col++)
    for (let row = 0; row < ROWS; row++) {
      const v = at(b, col, row);
      if (v === EMPTY) continue;
      score += (v === me ? 1 : -1) * WEIGHT[col];
    }
  return score;
}
