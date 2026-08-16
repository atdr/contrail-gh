# Flighty exports

Drop Flighty CSV exports in this directory and commit them. The next sync reads
every `*.csv` here, newest filename first.

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

## In the public template

**This directory must stay empty here.** An export is an entire travel history in
one file, and this repo is public. `check-template.yml` fails the build if a CSV
appears. In your own private repo, committing them is the whole point.
