// The page. Three modes over one board: hot-seat, a local bot, and a live
// table on chain. They share a single `state.board`, so the same renderer,
// the same animation and the same rules serve all three; only where a move
// goes differs.
import * as e from "./engine.js";
import { NETWORKS, qevalString, parseFeed, wallet, gnokeyCommand } from "./chain.js";
import * as onboarding from "./onboarding.js";
import * as gnosession from "./session.js";

const $ = (id) => document.getElementById(id);
const state = {
  mode: "local",
  board: e.newBoard(),
  net: NETWORKS.mainnet,
  netName: "mainnet",
  account: null,
  table: null,      // the chain game being watched, if any
  tables: [],
  animate: -1,      // the cell to drop in, once
  poll: null,
  // When a session is granted, moves are signed here instead of by the wallet.
  // Same caller either way: the chain sees the master, so the seat is the same.
  session: null,
  grant: null,
};

// ---- drawing -------------------------------------------------------------
// Same geometry and same palette as p/moul/gno4's SVG, so a board drawn here
// and a board drawn by the realm are the same picture.
const PAD = 10, CELL = 74, HOLE = 30;
const W = e.COLS * CELL + 2 * PAD, H = e.ROWS * CELL + 2 * PAD;
const FILL = { [e.EMPTY]: "var(--hole)", [e.RED]: "var(--red)", [e.YELLOW]: "var(--yellow)" };

function draw() {
  const b = state.board;
  const parts = [`<rect width="${W}" height="${H}" rx="14" fill="var(--board)"/>`];
  for (let row = e.ROWS - 1; row >= 0; row--) {
    for (let col = 0; col < e.COLS; col++) {
      const cx = PAD + col * CELL + CELL / 2, cy = PAD + (e.ROWS - 1 - row) * CELL + CELL / 2;
      const i = e.idx(col, row);
      const won = b.line.includes(i);
      const dropping = i === state.animate;
      parts.push(
        `<circle cx="${cx}" cy="${cy}" r="${HOLE}" fill="${FILL[e.at(b, col, row)]}"` +
        (won ? ` stroke="var(--ink)" stroke-width="5"` : "") +
        (dropping ? ` class="falling" style="--from:${-(cy + HOLE * 2)}px"` : "") +
        `/>`);
    }
  }
  $("board").innerHTML =
    `<svg viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${ariaLabel()}">${parts.join("")}</svg>`;
  state.animate = -1;

  $("columns").innerHTML = Array.from({ length: e.COLS }, (_, col) =>
    `<button type="button" data-col="${col}"${playable(col) ? "" : " disabled"}>${col + 1}</button>`).join("");
  $("verdict").textContent = verdict();
  $("movelist").textContent = e.encode(b) || "no moves yet";
}

function ariaLabel() {
  const b = state.board;
  return b.winner ? `${name(b.winner)} has won` : `${name(e.turn(b))} to move, ${b.moves.length} discs played`;
}

const name = (d) => (d === e.RED ? "Red" : d === e.YELLOW ? "Yellow" : "nobody");

function verdict() {
  const b = state.board;
  if (b.winner) return `${name(b.winner)} wins, in ${b.moves.length} moves.`;
  if (e.full(b)) return "A draw. Forty-two discs, no line of four.";
  if (state.mode === "chain" && state.table) {
    const seat = e.turn(b) === e.RED ? state.table.red : state.table.yellow;
    if (state.table.state === "open") return "Waiting for an opponent.";
    return `${name(e.turn(b))} to move — ${shortAddr(seat)}${seat === state.account ? " (you)" : ""}.`;
  }
  return `${name(e.turn(b))} to move.`;
}

const shortAddr = (a) => (a && a.length > 12 ? `${a.slice(0, 8)}…${a.slice(-4)}` : a || "—");

function playable(col) {
  if (!e.canDrop(state.board, col)) return false;
  if (state.mode === "bot" && e.turn(state.board) !== Number($("botside").value)) return false;
  if (state.mode === "chain") {
    if (!state.table || state.table.state !== "live" || !state.account) return false;
    const seat = e.turn(state.board) === e.RED ? state.table.red : state.table.yellow;
    return seat === state.account;
  }
  return true;
}

// ---- moves ---------------------------------------------------------------

async function play(col) {
  if (state.mode === "chain") return playOnChain(col);
  const row = e.drop(state.board, col);
  if (row === null) return;
  state.animate = e.idx(col, row);
  draw();
  writeHash();
  if (state.mode === "bot" && !e.over(state.board)) {
    setTimeout(() => {
      const c = e.bestMove(state.board, 6);
      const r = e.drop(state.board, c);
      if (r !== null) state.animate = e.idx(c, r);
      draw();
      writeHash();
    }, 180);
  }
}

async function playOnChain(col) {
  return tx("Play", [state.table.id, col + 1]);
}

// ---- chain ---------------------------------------------------------------

async function refresh() {
  if (state.mode !== "chain") return;
  try {
    state.tables = parseFeed(await qevalString(state.net, "Feed()"));
    say(`${state.tables.length} table(s) on ${state.netName}`, "live");
  } catch (err) {
    state.tables = [];
    // The realm may simply not be deployed on this network yet, which is a
    // normal state for a repository whose whole point is the deploy story.
    // renderTables below prints the empty state, so the panel never sits blank.
    say(`${state.netName}: ${err.message}`, "bad");
  }
  renderTables();
  if (state.table) {
    const fresh = state.tables.find((t) => t.id === state.table.id);
    if (fresh) {
      state.table = fresh;
      state.board = e.decode(fresh.moves) || e.newBoard();
      draw();
    }
  }
}

function renderTables() {
  if (!state.tables.length) {
    $("tables").innerHTML = `<p class="fine">No tables here yet.</p>`;
    return;
  }
  $("tables").innerHTML = state.tables.slice(0, 12).map((t) => {
    const action = t.state === "open" && state.account && t.red !== state.account
      ? `<button data-join="${t.id}" type="button">join</button>`
      : `<button data-watch="${t.id}" type="button">watch</button>`;
    return `<div class="table-row"><span class="id">${t.id}</span>` +
      `<span class="who">${shortAddr(t.red)} vs ${t.yellow ? shortAddr(t.yellow) : "…"}</span>` +
      `<span class="fine">${t.state === "open" || t.state === "live" ? t.state : "done"}</span>${action}</div>`;
  }).join("");
}

async function tx(fn, args) {
  if (!state.account) { say("connect a wallet first, or paste the command below", "bad"); return; }
  try {
    if (state.grant) {
      say("signing here…");
      await gnosession.call({
        rpcUrl: state.net.rpc, chainId: state.net.chainId,
        session: state.session, grant: state.grant, func: fn, args,
      });
    } else {
      say("signing…");
      await wallet.call(state.net, state.account, fn, args);
    }
    say("sent — waiting for the block", "live");
    setTimeout(refresh, 1500);
  } catch (err) { say(err.message, "bad"); }
}

const say = (msg, cls = "") => { const s = $("status"); s.textContent = msg; s.className = `status ${cls}`; };

// ---- url -----------------------------------------------------------------
// A game is a string, so a game is a link. Nothing is stored, nothing is
// shortened, and the link opens with no chain and no wallet.

function writeHash() {
  const m = e.encode(state.board);
  history.replaceState(null, "", m ? `#m=${m}` : location.pathname);
}

function readHash() {
  const m = new URLSearchParams(location.hash.slice(1)).get("m");
  if (!m) return;
  const b = e.decode(m);
  if (b) state.board = b;
}

// ---- wiring --------------------------------------------------------------

function setMode(mode) {
  state.mode = mode;
  for (const el of document.querySelectorAll(".tabs button")) el.classList.toggle("on", el.dataset.mode === mode);
  for (const p of ["local", "bot", "chain"]) $(`pane-${p}`).classList.toggle("hidden", p !== mode);
  clearInterval(state.poll);
  if (mode === "chain") {
    refresh();
    state.poll = setInterval(refresh, 6000);
  } else {
    state.table = null;
    say("reading only — no wallet needed");
  }
  draw();
}

function setNetwork(name) {
  state.netName = name;
  state.net = NETWORKS[name];
  $("link-realm").href = `https://gno.land/${state.net.realm.replace("gno.land/", "")}`;
  $("cmd").textContent = gnokeyCommand(state.net, "Play", ["<table>", "<column>"]);
  sessionPanel.refresh();
  if (state.mode === "chain") refresh();
}

document.addEventListener("click", async (ev) => {
  const t = ev.target;
  if (t.dataset.col !== undefined && !t.disabled) return play(Number(t.dataset.col));
  if (t.dataset.mode) return setMode(t.dataset.mode);
  if (t.dataset.join) return tx("Join", [t.dataset.join]);
  if (t.dataset.watch) {
    state.table = state.tables.find((x) => x.id === Number(t.dataset.watch));
    state.board = e.decode(state.table.moves) || e.newBoard();
    return draw();
  }
  if (t.id === "open-table") return tx("Open", []);
  if (t.id === "reset") { state.board = e.newBoard(); state.table = null; writeHash(); return draw(); }
  if (t.id === "undo") {
    const moves = state.board.moves.slice(0, -1);
    state.board = e.decode(moves.map((c) => c + 1).join("")) || e.newBoard();
    writeHash();
    return draw();
  }
  if (t.id === "share") {
    await navigator.clipboard.writeText(location.href);
    say("link copied — it opens with no chain and no wallet", "live");
  }
  if (t.id === "connect") {
    try {
      state.account = await wallet.connect();
      say(`connected ${shortAddr(state.account)}`, "live");
      renderTables(); draw(); sessionPanel.refresh();
    }
    catch (err) { say(err.message, "bad"); }
  }
});

$("network").addEventListener("change", (ev) => setNetwork(ev.target.value));
$("botside").addEventListener("change", draw);
window.addEventListener("hashchange", () => { readHash(); draw(); });

const sessionPanel = onboarding.mount({
  el: $("session"),
  net: () => state.net,
  getAccount: () => state.account,
  setAccount: (addr) => {
    // Named, not connected: good enough to read a grant and to be the caller in
    // one, and it never lets this page sign anything the session cannot.
    state.account = addr;
    say(`playing as ${shortAddr(addr)}`, "live");
    renderTables();
  },
  keyName: "YOURKEY",
  onChange: ({ session, grant }) => {
    state.session = session;
    state.grant = grant;
    draw(); // the move buttons are enabled by having a signer, whichever it is
  },
});

setNetwork("mainnet");
readHash();
draw();
