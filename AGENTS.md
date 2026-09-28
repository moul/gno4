# Working in this repository

Read [CHECKLIST.md](./CHECKLIST.md) first. It is the spec; this file is how to not break it.

## The loop

```sh
make ci      # guards, lint, test. Green before every commit, and what CI runs.
make repin   # after any deliberate change to Render. Then read the diff.
```

`make ci` is the whole gate. There is no check in CI that does not run locally.

## Things that are permanent

1. **`private = true` on a realm.** Removing it publishes the path forever: it can never be
   redeployed, on any chain. Do not remove it as part of another change.
2. **A published package path.** `p/moul/gno4/v0` cannot be edited once it is on chain.
   A behaviour change is a `v1`, via `gnopm bump`, never an edit in place.
3. **The `Feed()` format.** It is a contract with a program. A column added in the middle
   is a broken front-end with nothing on chain to fix it with. Append, or add a function.

## Things that will bite

- **`testing.SetRealm` applies to the current frame.** Wrapped in a helper it sets the
  helper's frame, the helper returns, and the caller the realm sees is unchanged. The call
  still succeeds, so the test passes for the wrong reason. Always inline it in the test
  body. This is how two different players became the same address here once.
- **`avl.Tree.Get` returns one value**, not `(value, ok)`. Check for `nil`.
- **`ufmt` has no width verbs.** Zero-padding is written by hand.
- **gno has no `sort.Slice`.** Small slices get an insertion sort; large ones want a
  different data structure.
- **Row 0 is falsy in JavaScript.** `web/engine.js` returns the landing row from `drop`,
  and the floor is row 0, so callers compare against `null` and not truthiness.
- **A raw string literal cannot contain a backtick**, and the pinned pages contain fenced
  code blocks. `{BT}` stands in for one and the test restores it.

## Adding a page to Render

1. Write it, with no current height and no clock in it.
2. Add the path to `pinnedPaths()`.
3. `make repin`, read the diff, commit both.

## Adding a dependency

`make deps` vendors it from `GNOROOT/examples`. Commit `vendor/`. `make guards` fails on an
import that is not there, because a build that reaches for the network is a build that
fails for reasons unrelated to the change.
