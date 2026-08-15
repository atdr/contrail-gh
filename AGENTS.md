# contrail-gh

A GitHub **template repository**. Someone clicks "Use this template", makes their
own **private** repo, adds two secrets, and gets a daily flight-emissions log
committed back to it.

This repo holds **no logic**. It installs [atdr/contrail](https://github.com/atdr/contrail)
from a pinned release tag and runs it. Behaviour questions belong there; this repo
is scaffolding.

## What's here

```
.github/workflows/sync.yml            the daily run
.github/workflows/check-template.yml  guards the invariants below
flight_emissions.csv                  header row only, never data
README.md                             setup instructions for a derived repo
```

## Rules

**Never commit flight data.** This repo is public. `flight_emissions.csv` is the
header row and nothing else, and `flight_emissions.raw.jsonl` must never appear
at all. `check-template.yml` enforces both — but only when running in
`atdr/contrail-gh`, since a derived repo legitimately has data in both.

**The header must match the contrail version `sync.yml` pins.** Not contrail's
`main` — the pinned tag. Regenerate it after installing that version:

```bash
python -c 'from contrail.storage.local_csv import CSV_FIELDS; print(",".join(CSV_FIELDS))' \
  > flight_emissions.csv
```

**The version pin is deliberate.** `sync.yml` installs `contrail@vX.Y.Z` and must
never track `main`: a change upstream would otherwise reach every derived repo
unannounced. Bumping it is a one-line, opt-in edit — and a derived repo's owner
may have pinned something older on purpose, which is why the "Staying up to date"
section of the README tells them to re-apply their own pin after pulling this
file.

**`git add` in `sync.yml` must cover every file contrail writes.** Today:
`flight_emissions.csv`, `flight_emissions.raw.jsonl`, `last_checked.txt`. A new
output file that isn't added is silently lost on every run.

**`last_checked.txt` is load-bearing.** GitHub disables scheduled workflows after
60 days of no repository activity, and a quiet stretch of travel can easily reach
that with no new flights to commit. Don't remove the keepalive as redundant.

**`permissions: contents: write` is required.** `GITHUB_TOKEN` has been read-only
by default since February 2023; without it the commit-back step 403s.

## When contrail changes

Anything in [contrail's docs/contrail-gh.md](https://github.com/atdr/contrail/blob/main/docs/contrail-gh.md)
that lists a schema or output change means this repo needs the same release:
regenerate the header, bump the pin, and check the README still describes the
columns accurately.
