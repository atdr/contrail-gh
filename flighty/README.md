# Flighty exports

This file ships in the public template and in every repo created from it. Unless
a line names a repo, it is addressed to **your own private repo**; the template's
own copy of this directory is covered in the last section.

In your own repo, drop Flighty CSV exports into this directory and commit them.
The next sync reads every `*.csv` in the directory, newest filename first.

This is optional. Leave the directory empty and contrail syncs from your TripIt
feed alone.

## Why bother

A Flighty export is the only source contrail has that reports **the cabin you
actually flew**. Everywhere else the log assumes economy, which understates a
long-haul business seat by roughly four times. An export is also your full
history, where a TripIt feed only carries recent and upcoming trips — so this is
how you backfill years of flying.

## Getting one

Flighty → Settings → Export → Export as CSV. It arrives named
`FlightyExport-YYYY-MM-DD.csv`; keep that name. The date in it is what orders
multiple exports, and the newest wins wherever two disagree about the same
flight.

Re-exporting later is safe and expected. Flighty gives each flight a stable ID,
so a re-export re-prices nothing and rewrites nothing — it just adds whatever is
new. You can keep one export and replace it each time, or keep them all.

## What it does to your log

Your TripIt feed is listed first, so it owns any row the two both describe; the
export fills in blanks and leaves its own key in `also_seen_as`. That one column
is what joins a row back to everything the export holds and contrail doesn't
store — seat, PNR, tail number, terminals.

Most rows in an export are flights that already departed, and those price to a
route average rather than an exact figure. That isn't a downgrade: the emissions
API won't quote a flight once it has flown, so a route average is the honest
number and much better than no row at all.

## The public template's own copy

Everything below is about `atdr/contrail-gh`, the public template. It is not an
instruction for your repo — if you are reading this in your own private repo,
there is nothing here for you to act on.

**`atdr/contrail-gh` must never hold an export.** One is an entire travel history
in a single file, and that repository is public. Its `check-template.yml` fails
the build if a CSV appears in `flighty/`, and separately if one appears in any
commit — deleting the file afterwards doesn't help, because it stays reachable in
the history. That workflow is gated to the template by repository name and does
nothing in a repo created from it.

Treat those checks as a backstop rather than a safety net: CI runs after a push,
so an export that reaches a public branch should be assumed disclosed.

Committing exports to `flighty/` in your own private repo is the whole point of
the directory, and none of the above argues against it.
