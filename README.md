<h1 align="center">gno4</h1>

<p align="center">
  <b>Connect Four, with the chain as the referee.</b><br>
  The rules are a pure gno package. The realm decides who may move. The web page is
  only one of the ways to look at it.
</p>

<p align="center">
  <a href="https://github.com/moul/gno4/actions/workflows/ci.yml"><img src="https://github.com/moul/gno4/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://gnoscope.com/realm/r/moul/gno4"><img src="https://gnoscope.com/_badges/shield/status/r/moul/gno4?network=mainnet" alt="realm status on mainnet"></a>
  <a href="./CHECKLIST.md"><img src="https://img.shields.io/badge/web2.5-checklist-1d4ed8" alt="checklist"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-97ca00.svg" alt="License"></a>
</p>

> **This is an exploration, not a product.** It is one of four small games written to
> answer a single question: *what does a web2.5 application on gno.land actually have to
> get right?* The game is the vehicle. The decisions around it are the point, and they are
> written down in **[CHECKLIST.md](./CHECKLIST.md)**.

### ▶ [Play it](https://moul.github.io/gno4/) &nbsp;·&nbsp; [The realm in gnoweb](https://gno.land/r/moul/gno4) &nbsp;·&nbsp; [The checklist](./CHECKLIST.md)

---

## The shape

```
p/moul/gno4/v0     the rules. no chain import, no address, no height.
r/moul/gno4        who may move, when, and what the world sees.
r/moul/preview/gno4  the same source at a second path, private = true. generated.
web/               a static page. no build step, no node_modules.
```

Three properties hold the whole thing together:

**A game is a string.** `Encode` returns one digit per move and nothing else; `Decode`
replays it. The position, the winner and the winning line are all derived. So the realm
stores 42 bytes at most, the browser can render a finished game with no chain, and a match
is a link you can paste.

**The realm draws itself.** The board on a realm page is a real SVG, built at render time
and inlined as a data URI. It costs no storage, there is no asset to host, and the entire
game is playable from gnoweb with no wallet and no JavaScript at all.

**The same source is deployed twice.** `r/moul/gno4` is production; `r/moul/preview/gno4`
is the redeployable twin, flagged `private = true`, and is what staging is until a testnet
is worth pointing at. Only `gnomod.toml` differs between them, which is why no page in the
realm may hardcode its own path — a guard enforces it.

## Running it

```sh
make            # the list
make ci         # guards, lint, test: exactly what CI runs
make dev        # a local chain with these packages, at http://127.0.0.1:8888
make web        # the front-end at http://127.0.0.1:8080
make repin      # regenerate the pinned Render output, then read the diff
```

The only thing needed on the machine is a `gno` toolchain and `GNOROOT` pointing at a
[gnolang/gno](https://github.com/gnolang/gno) checkout, for the stdlibs. Every `gno.land`
dependency is committed under `vendor/`, so nothing here needs the network.

## What it does not do

**No wagers.** A table holds no coins, so there is no escrow, no payout and no
abandoned-table timeout to get wrong. Money is a second design, not a flag on this one.

**No matchmaking, no rating.** An Elo needs a K factor, a provisional period and a rule for
resignations; all three are policy arguments that would outlive the code.

**No timeout.** A game nobody finishes and nobody resigns stays live forever. That is a
known hole with a known fix, and it is not in this version.

## The other three

Same checklist, different pressure: [gnoplace](https://github.com/moul/gnoplace) (write
volume and cost), [gnordle](https://github.com/moul/gnordle) (hidden state on a transparent
chain), [gnosnake](https://github.com/moul/gnosnake) (a score the chain recomputes rather
than believes).
