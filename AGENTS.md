# contrail-gh

Runs [contrail](https://github.com/atdr/contrail) on a schedule via GitHub
Actions and commits a flight-emissions log back to the repository. This repo
holds **no logic** — it installs contrail from a pinned release tag and runs it.
Behaviour questions belong in contrail; this is scaffolding.

## First: work out which repo you are in

This file ships **in the template and in every repo created from it**, so the
rules differ depending on where you have landed. They are close to opposites in
one place, so check before touching anything:

```bash
git remote get-url origin      # the authority: atdr/contrail-gh is the template
```

**Ask git, not `gh`.** `gh` chooses a repo by remote *name* and ranks `upstream`
above `origin`, so in an instance that added the template as `upstream`, every
bare `gh` command — including `gh repo view` — answers for the **public
template** instead. Believing it here is the worst case in this file: you would
read `isTemplate: true`, apply the template's "the CSV is a header row and
nothing else" rule, and truncate someone's real travel history. The README now
tells people to name that remote `template` for this reason, but don't rely on
it; `origin` is always the repo you are standing in.

| | The template (`atdr/contrail-gh`) | An instance (e.g. `octocat/my-contrail`) |
|---|---|---|
| Visibility | public | **private** |
| `flight_emissions.csv` | header row only | real flights, and it grows |
| `flight_emissions.raw.jsonl` | must not exist | present once a sync has run |
| `flighty/` | empty of CSVs | the owner's exports, committed by hand |
| Actions secrets | none | `TRIPIT_ICAL_URL`, `TIM_API_KEY` |
| Purpose | the thing people copy | someone's actual travel record |

A quick heuristic if `gh` isn't available: more than one line in
`flight_emissions.csv` means you are in an instance.

## If you are in an instance

**The data is the point. Never "clean up" the CSV or the raw log.** They are the
product. Deleting rows, truncating to the header, or removing
`flight_emissions.raw.jsonl` destroys travel history that mostly cannot be
re-fetched — contrail's emissions provider will not price a flight once it has
departed, and the calendar feed only carries recent trips.

- Editing a row by hand is supported and expected: fill in emissions on an
  `unparsed` row, or set `cabin_class_known`, and the next sync picks it up.
- Both files must stay committed. If they stop appearing in commits, check the
  `git add` line in `sync.yml`.
- **Never make this repo public**, and never copy its contents into a public
  one. The CSV is an itinerary; the raw log is worse; an export in `flighty/` is
  the owner's entire flying history in one file.
- Exports in `flighty/` are committed on purpose and are read by every sync.
  Don't tidy them away. Re-exporting is safe — Flighty ids are stable, so a
  re-export re-prices nothing.
- Upgrading contrail means editing one line — the `@vX.Y.Z` pin in `sync.yml`.
  Check [contrail's releases](https://github.com/atdr/contrail/releases) first.
- Pulling template updates is manual and one file at a time; see "Staying up to
  date" in the README. Re-apply your own pin afterwards.
- The template remote is called `template`, not `upstream`, so that `gh` keeps
  resolving to this repo rather than the public one. Don't "fix" the name, and
  pass `--repo` if you ever see `gh` answer for `atdr/contrail-gh` here.
- `check-template.yml` deliberately does nothing here. Its checks assume a
  header-only CSV and would fail against real data.
- `sync.yml` is the one that *does* run here. That is the whole point.

## If you are in the template

**Never commit flight data.** It is public. `flight_emissions.csv` is the header
row and nothing else, `flight_emissions.raw.jsonl` must not exist, and `flighty/`
must hold no CSV. `check-template.yml` enforces all three, and runs only here.

`flighty/` is the sharpest of them. A Flighty export is an entire travel history
in one file, and unlike the log it is a file someone puts there by hand, so
nothing else would catch it. It is checked twice — the tree, and every commit,
since removing an export in a later commit leaves it in the history of a public
repo. Both run after a push, so they are a backstop: an export that reaches a
public branch should be assumed disclosed, not merely caught.

**The header must match the contrail version `sync.yml` pins** — the pinned tag,
not contrail's `main`. Regenerate it after installing that version:

```bash
python -c 'from contrail.storage.local_csv import CSV_FIELDS; print(",".join(CSV_FIELDS))' \
  > flight_emissions.csv
```

If a schema change hasn't been released yet, regenerate the header in the same
change that bumps the pin — not before, or the template ships a header no
released contrail writes.

**The two workflows are guarded in opposite directions, and both guards are
load-bearing:**

| Workflow | Guard | Runs in |
|---|---|---|
| `check-template.yml` | `if: github.repository == 'atdr/contrail-gh'` | the template only |
| `sync.yml` | `if: github.repository != 'atdr/contrail-gh'` | instances only |

Removing either produces a workflow that fails forever in the wrong repo: the
checks assume a header-only CSV and would fail against real data, while the sync
has no secrets and nothing to log here. Both key off the repository name, so an
instance is simply "not the template" — no per-user configuration needed.

**Remember every edit here lands in someone's private repo later**, including
this file. Write instructions that still make sense there.

## True in both

**The version pin is deliberate.** `sync.yml` installs `contrail@vX.Y.Z` and must
never track `main`: a change upstream would otherwise reach every instance
unannounced. Bumping is opt-in, which is also why the README tells people to
re-apply their own pin after pulling template updates.

`sync.yml` is the only place that version is decided. The docs quote it back to
the reader, so bumping it means updating any doc that spells the tag out — in the
template `check-template.yml` fails the build if one disagrees, since a stale
quote sends people to a release this template doesn't install. Write `@vX.Y.Z`
where you mean the pin in general; only a real tag is checked.

**`git add` in `sync.yml` must cover every file contrail writes.** Today:
`flight_emissions.csv`, `flight_emissions.raw.jsonl`, `last_checked.txt`. A new
output that isn't added is silently lost on every run.

**`last_checked.txt` is load-bearing.** GitHub disables scheduled workflows after
60 days of no repository activity, and a quiet stretch of travel reaches that
easily with no new flights to commit. It is not redundant.

**`permissions: contents: write` is required.** `GITHUB_TOKEN` has been read-only
by default since February 2023; without it the commit-back step 403s.

## When contrail changes

[contrail's docs/contrail-gh.md](https://github.com/atdr/contrail/blob/main/docs/contrail-gh.md)
lists what a schema or output change upstream obliges here: regenerate the
header, bump the pin, check the README still describes the columns accurately.
