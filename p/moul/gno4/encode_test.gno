package gno4

import (
	"testing"

	"gno.land/p/nt/uassert/v0"
	"gno.land/p/nt/urequire/v0"
)

func TestEncodeRoundTrip(t *testing.T) {
	cases := []string{"", "4", "4433", "1122334", "1213141"}
	for _, want := range cases {
		b, err := Decode(want)
		urequire.NoError(t, err)
		uassert.Equal(t, want, b.Encode())
	}
}

// Decode replays through Drop, so it is the one place an impossible game is
// refused. Writing cells directly would make every one of these a legal Board.
func TestDecodeRejectsImpossibleGames(t *testing.T) {
	cases := []struct {
		name string
		play string
	}{
		{"column zero does not exist", "0"},
		{"column eight does not exist", "8"},
		{"not a digit at all", "4a3"},
		{"a column overflows", "1111111"},
		{"a move after the game was won", "11223344"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			b, err := Decode(tc.play)
			uassert.ErrorIs(t, err, ErrBadEncoding)
			uassert.True(t, b == nil, "a refused encoding yields no board")
		})
	}
}

func TestStringIsTopRowFirst(t *testing.T) {
	b, err := Decode("4433")
	urequire.NoError(t, err)
	want := `.......
.......
.......
.......
..YY...
..RR...
1234567
`
	uassert.Equal(t, want, b.String())
}
