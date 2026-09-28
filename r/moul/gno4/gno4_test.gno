package gno4

import (
	"strings"
	"testing"

	"gno.land/p/moul/gno4/v0"
	"gno.land/p/nt/avl/v0"
	"gno.land/p/nt/testutils/v0"
	"gno.land/p/nt/uassert/v0"
	"gno.land/p/nt/urequire/v0"
)

var (
	alice = testutils.TestAddress("alice")
	bob   = testutils.TestAddress("bob")
	carol = testutils.TestAddress("carol")
)

// reset clears every package-level variable. The realm's state is global and
// tests run in one process, so without this each test would inherit whatever
// the previous one left and the suite would only pass in file order.
func reset() {
	games = avl.Tree{}
	records = avl.Tree{}
	nextID = 1
	open = nil
	live = nil
	done = nil
}

// Every caller switch below is a literal testing.SetRealm, never a helper.
//
// SetRealm sets the realm of the CURRENT FRAME. Wrapped in a func, it sets the
// helper's frame, which then returns, and the caller the realm sees is whoever
// it was before. The call still succeeds, so the test passes for the wrong
// reason: this exact mistake made alice and bob the same player and turned a
// turn-order test into one that asserted nothing.

func TestOpenAndJoin(cur realm, t *testing.T) {
	reset()

	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))
	uassert.Equal(t, 1, id)
	uassert.Equal(t, 1, len(open))
	uassert.Equal(t, 0, len(live))

	testing.SetRealm(testing.NewUserRealm(bob))
	Join(cross(cur), id)
	uassert.Equal(t, 0, len(open))
	uassert.Equal(t, 1, len(live))

	red, yellow, moves, over := GameOf(id)
	uassert.Equal(t, alice, red)
	uassert.Equal(t, bob, yellow)
	uassert.Equal(t, "", moves)
	uassert.False(t, over)
}

func TestJoinRefusals(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))

	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, ErrOwnGame.Error(), func() {
		Join(cross(cur), id)
	})
	testing.SetRealm(testing.NewUserRealm(bob))
	Join(cross(cur), id)
	testing.SetRealm(testing.NewUserRealm(carol))
	urequire.AbortsContains(t, cur, ErrNotOpen.Error(), func() {
		Join(cross(cur), id)
	})
	testing.SetRealm(testing.NewUserRealm(carol))
	urequire.AbortsContains(t, cur, ErrNoSuchGame.Error(), func() {
		Join(cross(cur), 99)
	})
}

// Authority is the whole reason this realm exists: the engine cannot tell one
// caller from another, so every refusal here is a rule only the realm can make.
func TestOnlyTheRightPlayerMoves(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))
	testing.SetRealm(testing.NewUserRealm(bob))
	Join(cross(cur), id)

	testing.SetRealm(testing.NewUserRealm(bob))
	urequire.AbortsContains(t, cur, ErrNotYourTurn.Error(), func() {
		Play(cross(cur), id, 1)
	})
	testing.SetRealm(testing.NewUserRealm(carol))
	urequire.AbortsContains(t, cur, ErrNotYours.Error(), func() {
		Play(cross(cur), id, 1)
	})

	testing.SetRealm(testing.NewUserRealm(alice))
	Play(cross(cur), id, 1)

	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, ErrNotYourTurn.Error(), func() {
		Play(cross(cur), id, 2)
	})
}

func TestPlayingAnOpenTableIsRefused(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))
	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, ErrNotOpen.Error(), func() {
		Play(cross(cur), id, 1)
	})
}

// The engine's own refusals reach the caller unchanged: the realm does not
// re-implement "is that column legal", it forwards the error.
func TestIllegalColumnsComeFromTheEngine(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))
	testing.SetRealm(testing.NewUserRealm(bob))
	Join(cross(cur), id)

	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, gno4.ErrColumnRange.Error(), func() {
		Play(cross(cur), id, 0) // columns are 1-based at this boundary
	})
	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, gno4.ErrColumnRange.Error(), func() {
		Play(cross(cur), id, 8)
	})

	// Fill column 1, then overflow it.
	for i := 0; i < 3; i++ {
		testing.SetRealm(testing.NewUserRealm(alice))
		Play(cross(cur), id, 1)
		testing.SetRealm(testing.NewUserRealm(bob))
		Play(cross(cur), id, 1)
	}
	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, gno4.ErrColumnFull.Error(), func() {
		Play(cross(cur), id, 1)
	})
}

func TestAWinIsRecorded(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))
	testing.SetRealm(testing.NewUserRealm(bob))
	Join(cross(cur), id)

	// "1122334": red takes the bottom row of columns 1 to 4.
	playOut(cur, id, "1122334")

	_, _, moves, over := GameOf(id)
	uassert.Equal(t, "1122334", moves)
	uassert.True(t, over)
	uassert.Equal(t, 0, len(live))
	uassert.Equal(t, 1, len(done))

	w, l, d := RecordOf(alice)
	uassert.Equal(t, 1, w)
	uassert.Equal(t, 0, l)
	uassert.Equal(t, 0, d)
	w, l, d = RecordOf(bob)
	uassert.Equal(t, 0, w)
	uassert.Equal(t, 1, l)
	uassert.Equal(t, 0, d)

	testing.SetRealm(testing.NewUserRealm(bob))
	urequire.AbortsContains(t, cur, ErrFinished.Error(), func() {
		Play(cross(cur), id, 5)
	})
}

func TestResignationHandsTheGameOver(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))
	testing.SetRealm(testing.NewUserRealm(bob))
	Join(cross(cur), id)
	testing.SetRealm(testing.NewUserRealm(alice))
	Play(cross(cur), id, 4)

	testing.SetRealm(testing.NewUserRealm(bob))
	Resign(cross(cur), id)

	g := mustGame(id)
	uassert.True(t, g.Over())
	uassert.Equal(t, alice, g.Winner())
	w, _, _ := RecordOf(alice)
	uassert.Equal(t, 1, w)
}

// An open table nobody joined scores nothing when it is withdrawn. Crediting a
// win against the zero address is the bug this pins.
func TestWithdrawingAnOpenTableScoresNothing(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))
	testing.SetRealm(testing.NewUserRealm(alice))
	Resign(cross(cur), id)

	uassert.Equal(t, 0, len(open))
	uassert.Equal(t, 1, len(done))
	w, l, d := RecordOf(alice)
	uassert.Equal(t, 0, w)
	uassert.Equal(t, 0, l)
	uassert.Equal(t, 0, d)
	uassert.Equal(t, 0, records.Size(), "no record row is created at all")
}

func TestADrawScoresBothSides(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))
	testing.SetRealm(testing.NewUserRealm(bob))
	Join(cross(cur), id)
	playOut(cur, id, "315117645176335765636674142222472457245331")

	g := mustGame(id)
	uassert.True(t, g.Over())
	uassert.Equal(t, address(""), g.Winner())
	_, _, d := RecordOf(alice)
	uassert.Equal(t, 1, d)
	_, _, d = RecordOf(bob)
	uassert.Equal(t, 1, d)
}

// playOut replays an engine encoding through the realm, alternating callers,
// which is the only way to reach a finished game through the real authority
// checks rather than around them.
func playOut(cur realm, id int, encoded string) {
	g := mustGame(id)
	for i := 0; i < len(encoded); i++ {
		seat := g.Red
		if i%2 == 1 {
			seat = g.Yellow
		}
		// Inline, in this frame, for the reason at the top of the file.
		testing.SetRealm(testing.NewUserRealm(seat))
		Play(cross(cur), id, int(encoded[i]-'0'))
	}
}

func TestRenderNeverPanics(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))
	testing.SetRealm(testing.NewUserRealm(bob))
	Join(cross(cur), id)
	testing.SetRealm(testing.NewUserRealm(alice))
	Play(cross(cur), id, 4)

	paths := []string{
		"", "about", "g/1", "u/" + alice.String(),
		"g/", "g/0", "g/999", "g/abc", "g/-1", "g/99999999999999",
		"u/", "u/nonsense", "u/g1notanaddress",
		"nope", "g", "u", "../../etc/passwd", "g/1/extra",
		"<script>alert(1)</script>", "g/1?x=y",
	}
	for _, p := range paths {
		out := Render(p)
		uassert.True(t, len(out) > 0, "empty render for path "+p)
	}
}

// A caller-supplied path reaches the page, so it is escaped. Nothing else a
// caller types is ever stored by this realm, which is why this is the only
// escaping test: addresses come from the frame, not from a string argument.
func TestRenderEscapesThePathItEchoes(cur realm, t *testing.T) {
	reset()
	out := Render("g/<script>")
	uassert.False(t, strings.Contains(out, "<script>"), out)
}

// Feed is what the web front-end reads. It is a contract with a program, not a
// page, so its shape is pinned: a column added in the middle is a broken app,
// and there is nothing on the chain to fix it with afterwards.
func TestFeedShape(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Open(cross(cur))
	uassert.Equal(t, itoa(id)+"\t"+alice.String()+"\t\t\topen", Line(id))

	testing.SetRealm(testing.NewUserRealm(bob))
	Join(cross(cur), id)
	uassert.Equal(t, itoa(id)+"\t"+alice.String()+"\t"+bob.String()+"\t\tlive", Line(id))

	playOut(cur, id, "1122334")
	uassert.Equal(t, itoa(id)+"\t"+alice.String()+"\t"+bob.String()+"\t1122334\t"+alice.String(), Line(id))

	uassert.Equal(t, "", Line(999))

	// Newest first, so a front-end can stop reading once it has enough.
	testing.SetRealm(testing.NewUserRealm(carol))
	second := Open(cross(cur))
	feed := strings.Split(strings.TrimSuffix(Feed(), "\n"), "\n")
	uassert.Equal(t, 2, len(feed))
	uassert.True(t, strings.HasPrefix(feed[0], itoa(second)+"\t"), feed[0])
	uassert.True(t, strings.HasPrefix(feed[1], itoa(id)+"\t"), feed[1])
}
