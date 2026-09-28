package gno4

import (
	"strings"
	"testing"

	"gno.land/p/nt/uassert/v0"
	"gno.land/p/nt/urequire/v0"
)

func TestEmojiIsTopRowFirst(t *testing.T) {
	b, err := Decode("4433")
	urequire.NoError(t, err)
	want := "⚫⚫⚫⚫⚫⚫⚫\n" +
		"⚫⚫⚫⚫⚫⚫⚫\n" +
		"⚫⚫⚫⚫⚫⚫⚫\n" +
		"⚫⚫⚫⚫⚫⚫⚫\n" +
		"⚫⚫🟡🟡⚫⚫⚫\n" +
		"⚫⚫🔴🔴⚫⚫⚫\n"
	uassert.Equal(t, want, b.Emoji())
}

func TestSVGIsWellFormedAndComplete(t *testing.T) {
	b, err := Decode("1122334")
	urequire.NoError(t, err)
	s := b.SVG()

	uassert.True(t, strings.HasPrefix(s, "<svg "), s[:40])
	uassert.True(t, strings.HasSuffix(s, "</svg>"))
	// 42 holes, always drawn, whether or not they hold a disc.
	uassert.Equal(t, Cols*Rows, strings.Count(s, "<circle"))
	// Seven column labels.
	uassert.Equal(t, Cols, strings.Count(s, "<text"))
	// The four winning cells are marked, and only those four.
	uassert.Equal(t, 4, strings.Count(s, `class="win"`))
}

func TestSVGMarksTheLastMoveUntilSomeoneWins(t *testing.T) {
	b, err := Decode("44")
	urequire.NoError(t, err)
	uassert.Equal(t, 1, strings.Count(b.SVG(), `class="last"`))

	// An empty board has no last move to mark.
	uassert.Equal(t, 0, strings.Count(New().SVG(), `class="last"`))
}

// gnoweb only lets an inline image through as a data URI when the media type is
// image/svg+xml, so the exact prefix is a contract with the renderer and not a
// formatting detail. Break it and the board silently stops appearing.
func TestImageIsAnSvgDataURI(t *testing.T) {
	b, err := Decode("4433")
	urequire.NoError(t, err)
	img := b.Image("board")
	uassert.True(t, strings.HasPrefix(img, "![board](data:image/svg+xml;base64,"), img[:60])
	uassert.True(t, strings.HasSuffix(img, ")"))
}
