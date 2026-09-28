package gno4

import (
	"strings"
	"testing"

	"gno.land/p/nt/uassert/v0"
)

// fixture builds one finished game and one open table, deterministically.
//
// Deterministic is the operative word. Render reads no current height and no
// clock, only heights already recorded in state, so the same fixture always
// produces the same bytes and the pins below can be exact. A page that said
// "3 blocks ago" could never be pinned, and a rendering regression would then
// only be caught by a human happening to look at it.
func fixture(cur realm, t *testing.T) {
	t.Helper()
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))
	testing.SetRealm(testing.NewUserRealm(bob))
	Join(cross(cur), id)
	playOut(cur, id, "1122334")

	testing.SetRealm(testing.NewUserRealm(carol))
	Open(cross(cur))
}

// pinnedPaths is the set of pages the pin covers: every branch of Render, on a
// fixture where each one has something to say.
func pinnedPaths() []string {
	return []string{"", "g/1", "g/2", "u/" + alice.String(), "about", "nope"}
}

// renderForPin strips the inline board, which is several kilobytes of base64
// and would make the pin unreadable. The SVG is asserted by shape in the
// engine's own tests; what is pinned here is the page this realm writes
// around it.
func renderForPin(path string) string {
	out := Render(path)
	start := strings.Index(out, "![")
	if start < 0 {
		return out
	}
	end := strings.Index(out[start:], ")")
	if end < 0 {
		return out
	}
	return out[:start] + "<board>" + out[start+end+1:]
}

type pinnedPage struct{ path, want string }

// pinnedPages is generated: `make repin` rewrites it from what Render actually
// produces, and the diff is the review. Writing one of these by hand is how a
// pin quietly stops matching the page.
//
// A gno raw string literal cannot contain a backtick, and these pages contain
// fenced code blocks, so every backtick is written {BT} and restored below.
var pinnedPages = []pinnedPage{
	{"", `# Connect Four

**The chain is the referee.** The rules live in a pure package that has never heard of a chain; this realm owns the only three things that package cannot decide: who may move, when, and what everyone else gets to see.

[Open a table](/r/moul/gno4$help&func=Open) and wait for someone, or join one below.

## Open tables
| table | opened by | at height | |
|---|---|---|---|
| [2](/r/moul/gno4:g/2) | [g1vdshym…sz94](/r/moul/gno4:u/g1vdshymmvta047h6lta047h6lta047h6l2asz94) | 123 | [join](/r/moul/gno4$help&func=Join&id=2) |

## Finished
| table | red | yellow | result |
|---|---|---|---|
| [1](/r/moul/gno4:g/1) | [g1v9kxjc…40gh](/r/moul/gno4:u/g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) | [g1vfhkyh…vdhu](/r/moul/gno4:u/g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu) | [g1v9kxjc…40gh](/r/moul/gno4:u/g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) |

## Standings
| player | won | lost | drawn |
|---|---|---|---|
| [g1v9kxjc…40gh](/r/moul/gno4:u/g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) | 1 | 0 | 0 |
| [g1vfhkyh…vdhu](/r/moul/gno4:u/g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu) | 0 | 1 | 0 |

---
<details><summary>How to play from a terminal</summary>

{BT}{BT}{BT}sh
# open a table; the transaction's output carries the id
gnokey maketx call -pkgpath gno.landr/moul/gno4 -func Open \
  -gas-fee 1000000ugnot -gas-wanted 2000000 -broadcast -chainid dev \
  -remote https://rpc.gno.land:443 YOURKEY

# drop a disc into column 4 of table 7
gnokey maketx call -pkgpath gno.landr/moul/gno4 -func Play -args 7 -args 4 \
  -gas-fee 1000000ugnot -gas-wanted 2000000 -broadcast -chainid dev \
  -remote https://rpc.gno.land:443 YOURKEY
{BT}{BT}{BT}

Those gas numbers are a starting point, not a measurement. Simulate first: drop {BT}-broadcast{BT} and the node answers with what the call actually costs.

</details>

[What this realm is exploring](/r/moul/gno4:about)
`},
	{"g/1", `# Table 1

<board>

**🔴 g1v9kxjc…40gh wins.** In 7 moves.

## Seats
| | player | record |
|---|---|---|
| 🔴 red | [g1v9kxjc…40gh](/r/moul/gno4:u/g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) | 1W / 0L / 0D |
| 🟡 yellow | [g1vfhkyh…vdhu](/r/moul/gno4:u/g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu) | 0W / 1L / 0D |

## The game, in full
The whole match is its move list, one digit per move. Replaying it reproduces this position exactly, which is why that string is the only thing stored on chain.

{BT}{BT}{BT}
1122334
{BT}{BT}{BT}

[Back to the lobby](/r/moul/gno4)
`},
	{"g/2", `# Table 2

<board>

**Waiting for an opponent.**

[Take the yellow seat](/r/moul/gno4$help&func=Join&id=2)

## Seats
| | player | record |
|---|---|---|
| 🔴 red | [g1vdshym…sz94](/r/moul/gno4:u/g1vdshymmvta047h6lta047h6lta047h6l2asz94) | 0W / 0L / 0D |
| 🟡 yellow | _open_ | |

## The game, in full
The whole match is its move list, one digit per move. Replaying it reproduces this position exactly, which is why that string is the only thing stored on chain.

{BT}{BT}{BT}
(no moves yet)
{BT}{BT}{BT}

[Back to the lobby](/r/moul/gno4)
`},
	{"u/g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh", `# g1v9kxjc…40gh

[g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh](/u/g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh)

Record: 1W / 0L / 0D

## Games
| table | against | result |
|---|---|---|
| [1](/r/moul/gno4:g/1) | [g1vfhkyh…vdhu](/r/moul/gno4:u/g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu) | [g1v9kxjc…40gh](/r/moul/gno4:u/g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) |

[Back to the lobby](/r/moul/gno4)
`},
	{"about", `# What this realm is exploring

This is one of four small games built to answer a single question: **what does a
web2.5 application on gno.land actually need to get right?** Not the game, the
scaffolding around it.

The engine is a pure package with no chain import, so its rules are testable
with no node. This realm owns authority and rendering, and nothing else. The
board you see is an SVG generated at render time and inlined as a data URI, so
it costs no storage and there is no asset to go missing. Every page here is
reachable with no wallet and no JavaScript.

There are two deployments of this same source: this one, and a {BT}/preview{BT}
twin flagged {BT}private = true{BT} so it stays redeployable while the design
is still moving. A public path can never be redeployed, which makes the flag the
most consequential line in the whole repository.

The repository, the checklist it is written against, and the other three games:
[github.com/moul/gno4](https://github.com/moul/gno4).

[Back to the lobby](/r/moul/gno4)
`},
	{"nope", `# Not found

No page at {BT}nope{BT}. [Back to the lobby](/r/moul/gno4).
`},
}

func TestRenderIsPinned(cur realm, t *testing.T) {
	fixture(cur, t)
	if len(pinnedPages) != len(pinnedPaths()) {
		t.Fatalf("pins are stale: %d pinned, %d paths. Run `make repin`.",
			len(pinnedPages), len(pinnedPaths()))
	}
	for _, p := range pinnedPages {
		uassert.Equal(t, strings.ReplaceAll(p.want, "{BT}", "\x60"), renderForPin(p.path),
			"page "+p.path+" changed. If you meant it, run `make repin` and read the diff.")
	}
}

func TestRenderAboutMentionsThePrivateFlag(cur realm, t *testing.T) {
	out := Render("about")
	uassert.True(t, strings.Contains(out, "private = true"))
	uassert.True(t, strings.Contains(out, "github.com/moul/gno4"))
}
