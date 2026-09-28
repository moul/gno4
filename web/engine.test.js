// The browser engine must agree with the gno one. Same fixtures, same answers.
//
// This is the only thing keeping two implementations of one rulebook honest.
// Run: node web/engine.test.js  (no framework, no install)
import * as e from "./engine.js";

let failures = 0;
const check = (ok, msg) => { if (!ok) { console.error("FAIL", msg); failures++; } };

// Generated and verified alongside p/moul/gno4's own table-driven tests.
const games = [
  ["nobody yet", "1234", e.EMPTY],
  ["red, horizontal", "1122334", e.RED],
  ["red, vertical", "1212121", e.RED],
  ["red, diagonal up-right", "1223733474744", e.RED],
  ["yellow, horizontal", "71727364", e.YELLOW],
  ["yellow, vertical", "12121232", e.YELLOW],
  ["yellow, diagonal up-left", "27665155414144", e.YELLOW],
  ["a full-board draw", "315117645176335765636674142222472457245331", e.EMPTY],
];

for (const [name, play, want] of games) {
  const b = e.decode(play);
  check(b !== null, `${name}: decode refused a legal game`);
  if (!b) continue;
  check(b.winner === want, `${name}: winner ${b.winner}, want ${want}`);
  check(e.encode(b) === play, `${name}: encode round trip`);
  if (want !== e.EMPTY) check(b.line.length === 4, `${name}: a win is four cells`);
}

const draw = e.decode(games[games.length - 1][1]);
check(e.full(draw) && e.over(draw), "the drawn game is full and over");

for (const bad of ["0", "8", "4a3", "1111111", "11223344"]) {
  check(e.decode(bad) === null, `impossible game accepted: ${bad}`);
}

// Same one-ply answers as the gno package.
check(e.winningMove(e.decode("112233"), e.RED) === 3, "red wins at column 4");
check(e.winningMove(e.decode("112233"), e.YELLOW) === -1, "yellow cannot reach that row");
check(e.winningMove(e.decode(""), e.RED) === -1, "nothing on an empty board");

// The search must never hand back an illegal column.
const b = e.decode("112233");
check(e.canDrop(b, e.bestMove(b, 4)), "bestMove returned a legal column");
// ... and it must take a win it can see.
check(e.bestMove(e.decode("112233"), 4) === 3, "bestMove takes the win in front of it");

console.log(failures === 0
  ? `ok  engine.js agrees with the gno fixtures (${games.length} games)`
  : `FAIL ${failures} check(s)`);
process.exit(failures === 0 ? 0 : 1);
