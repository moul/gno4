package gno4

import (
	"strings"
	"testing"

	"gno.land/p/nt/uassert/v0"
	"gno.land/p/nt/urequire/v0"
)

// eqDisc compares two discs. uassert.Equal type-switches on the concrete type
// and Disc is a named byte, which matches no case, so a direct Equal reports
// "unsupported type" and passes for any pair. Comparing the String() forms is
// what makes these assertions able to fail at all.
func eqDisc(t *testing.T, want, got Disc, msgs ...string) {
	t.Helper()
	uassert.Equal(t, want.String(), got.String(), msgs...)
}

func TestEmptyBoard(t *testing.T) {
	b := New()
	eqDisc(t, Red, b.Turn(), "red moves first")
	uassert.Equal(t, 0, b.MoveCount())
	uassert.False(t, b.Over())
	uassert.False(t, b.Full())
	eqDisc(t, Empty, b.Winner())
	uassert.Equal(t, 7, len(b.Legal()))
	uassert.Equal(t, "", b.Encode())
}

func TestDrop(t *testing.T) {
	cases := []struct {
		name    string
		play    string // columns, 1-based, as Decode takes them
		col     int    // the column to drop next, 0-based
		wantRow int
		wantErr error
	}{
		{"first disc lands on the floor", "", 3, 0, nil},
		{"second disc stacks on the first", "4", 3, 1, nil},
		{"left edge", "", 0, 0, nil},
		{"right edge", "", 6, 0, nil},
		{"one below the rim", "1111 1", 0, 5, nil},
		{"a full column refuses", "111111", 0, 0, ErrColumnFull},
		{"below the board", "", -1, 0, ErrColumnRange},
		{"past the board", "", Cols, 0, ErrColumnRange},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			b, err := Decode(strings.ReplaceAll(tc.play, " ", ""))
			urequire.NoError(t, err)
			row, err := b.Drop(tc.col)
			if tc.wantErr != nil {
				uassert.ErrorIs(t, err, tc.wantErr)
				return
			}
			urequire.NoError(t, err)
			uassert.Equal(t, tc.wantRow, row)
		})
	}
}

func TestWin(t *testing.T) {
	// Every sequence here was generated and checked against an independent
	// implementation before it was written down. A win fixture that does not
	// actually win is a test that passes for the wrong reason, and there is no
	// way to tell by reading the digits.
	cases := []struct {
		name string
		play string
		want Disc
	}{
		{"nobody yet", "1234", Empty},
		{"red, horizontal", "1122334", Red},
		{"red, vertical", "1212121", Red},
		{"red, diagonal up-right", "1223733474744", Red},
		{"yellow, horizontal", "71727364", Yellow},
		{"yellow, vertical", "12121232", Yellow},
		{"yellow, diagonal up-left", "27665155414144", Yellow},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			b, err := Decode(tc.play)
			urequire.NoError(t, err)
			eqDisc(t, tc.want, b.Winner(), b.String())
			if tc.want == Empty {
				uassert.Equal(t, 0, len(b.Line()))
				uassert.False(t, b.Over())
				return
			}
			urequire.Equal(t, 4, len(b.Line()), "a win is exactly four cells")
			uassert.True(t, b.Over())
			// Every cell of the winning line holds the winner's disc, and the
			// line contains the move that just landed.
			for _, i := range b.Line() {
				eqDisc(t, tc.want, b.At(i%Cols, i/Cols), b.String())
			}
			lastCol := b.Moves()[b.MoveCount()-1]
			uassert.True(t, contains(b.Line(), idx(lastCol, b.Height(lastCol)-1)),
				"the winning line must contain the winning move")
		})
	}
}

func TestPlayingOnAFinishedGameIsRefused(t *testing.T) {
	b, err := Decode("1122334")
	urequire.NoError(t, err)
	eqDisc(t, Red, b.Winner())

	_, err = b.Drop(5)
	uassert.ErrorIs(t, err, ErrGameOver)
	uassert.Equal(t, 0, len(b.Legal()), "a finished game offers no moves")
	uassert.False(t, b.CanDrop(5))
}

func TestWinningMove(t *testing.T) {
	cases := []struct {
		name string
		play string
		disc Disc
		want int
	}{
		{"nothing is available on an empty board", "", Red, -1},
		{"red completes the bottom row at column 4", "112233", Red, 3},
		{"yellow's row is one higher, so column 4 does nothing yet", "112233", Yellow, -1},
		{"red is one disc from a vertical in column 1", "121212", Red, 0},
		{"and yellow is one from the same in column 2", "121212", Yellow, 1},
		{"a finished game offers nothing to anyone", "1122334", Red, -1},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			b, err := Decode(tc.play)
			urequire.NoError(t, err)
			uassert.Equal(t, tc.want, b.WinningMove(tc.disc), b.String())
		})
	}
}

// WinningMove is asked about a hypothetical disc, so it must leave the board
// exactly as it found it. A version that dropped and undid would pass every
// test above and corrupt the realm's state on the first hint.
func TestWinningMoveDoesNotMutate(t *testing.T) {
	b, err := Decode("112233")
	urequire.NoError(t, err)
	before := b.String()
	b.WinningMove(Red)
	b.WinningMove(Yellow)
	uassert.Equal(t, before, b.String())
	uassert.Equal(t, 6, b.MoveCount())
}

// A real 42-move draw, found by shuffling fill orders until one produced no
// line of four. It is the only way to exercise Full, Draw and the "no legal
// moves left, nobody won" branch, which a 12-move game never reaches.
const drawnGame = "315117645176335765636674142222472457245331"

func TestFullBoardDraws(t *testing.T) {
	b, err := Decode(drawnGame)
	urequire.NoError(t, err)
	uassert.Equal(t, Cols*Rows, b.MoveCount())
	uassert.True(t, b.Full(), b.String())
	uassert.True(t, b.Draw())
	uassert.True(t, b.Over())
	eqDisc(t, Empty, b.Winner())
	uassert.Equal(t, 0, len(b.Legal()))

	_, err = b.Drop(0)
	uassert.ErrorIs(t, err, ErrGameOver)
}

func TestCloneIsIndependent(t *testing.T) {
	b, err := Decode("4433")
	urequire.NoError(t, err)
	c := b.Clone()
	_, err = c.Drop(0)
	urequire.NoError(t, err)
	uassert.Equal(t, "4433", b.Encode())
	uassert.Equal(t, "44331", c.Encode())
}

func TestDiscOther(t *testing.T) {
	eqDisc(t, Yellow, Red.Other())
	eqDisc(t, Red, Yellow.Other())
	eqDisc(t, Empty, Empty.Other())
	uassert.Equal(t, "red", Red.String())
	uassert.Equal(t, "yellow", Yellow.String())
	uassert.Equal(t, "empty", Empty.String())
}

// At is called from render loops that walk past the edge on purpose. A panic
// here is a permanently unreadable realm page, so it is a tested property and
// not an implementation detail.
func TestAtOutOfRangeIsEmptyNotAPanic(t *testing.T) {
	b, err := Decode("1234")
	urequire.NoError(t, err)
	eqDisc(t, Empty, b.At(-1, 0))
	eqDisc(t, Empty, b.At(0, -1))
	eqDisc(t, Empty, b.At(Cols, 0))
	eqDisc(t, Empty, b.At(0, Rows))
	uassert.Equal(t, 0, b.Height(-1))
	uassert.Equal(t, 0, b.Height(Cols))
}
