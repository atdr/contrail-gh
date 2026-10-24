# OpenFlights backups

This file ships in the public template and in every repo created from it. Unless
a line names a repo, it is addressed to **your own private repo**; the template's
own copy of this directory is covered in the last section.

In your own repo, drop an [OpenFlights](https://openflights.org) CSV backup into
this directory and commit it. The next sync reads the newest one.

This is optional. Leave the directory empty and contrail syncs from your other
sources alone.

## Why bother

OpenFlights is where many people logged their flying for years before TripIt or
Flighty, so a backup is often the only record of the oldest flights. Adding it
backfills those years in one go.

## Getting one

OpenFlights → Settings → Backup to CSV. It arrives named
`openflights-backup-YYYY-MM-DD-HHMM.csv`; keep that name.

**Only the newest backup is read**, by that name. Each one is your whole account,
so an older one adds nothing but rows you have since corrected. Replacing the old
file with the new one is the tidy way to update; keeping both is harmless.

## What it does to your log

Everything in a backup was typed by hand, so contrail ranks it below your other
sources. It is listed last: where TripIt or Flighty also has a flight, they own
the row, and the backup only fills in blanks such as the cabin or the reason for
the trip.

Dates typed by hand go wrong in one predictable way: a departure just after
midnight entered under the day before. That flight then matches nothing else and
would be counted twice, so the sync warns about it. Check the Actions log of the
first sync after you add a backup, or open a pull request with it and read the
`check-instance` dry run, which lists any `DAY OFF?` flights before anything is
written. Fix the date in OpenFlights, back up again, and if a sync has already
written the wrongly dated row, delete that row from `flight_emissions.csv`: a
departed row is never removed by a later sync.

Like a Flighty export, almost every row is a flight that already departed, so it
prices to a route average rather than an exact figure.

## The public template's own copy

Everything below is about `atdr/contrail-gh`, the public template. It is not an
instruction for your repo — if you are reading this in your own private repo,
there is nothing here for you to act on.

**`atdr/contrail-gh` must never hold a backup.** One is an entire travel history
in a single file, and that repository is public. Its `check-template.yml` fails
the build if a CSV appears in `openflights/`, and separately if one appears in
any commit — deleting the file afterwards doesn't help, because it stays
reachable in the history. That workflow is gated to the template by repository
name and does nothing in a repo created from it.

Treat those checks as a backstop rather than a safety net: CI runs after a push,
so a backup that reaches a public branch should be assumed disclosed.

Committing a backup to `openflights/` in your own private repo is the whole point
of the directory, and none of the above argues against it.
