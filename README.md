# contrail-gh

A GitHub Actions setup that runs [contrail](https://github.com/atdr/contrail) on a schedule and
keeps a log of your flight emissions in your own private repo.

Every day it reads your TripIt calendar feed, prices any new flights using Google's
[Travel Impact Model](https://travelimpactmodel.org/about-tim), appends them to
`flight_emissions.csv`, and commits the result back. No server, no machine to maintain.

Your flight history and your API keys stay in **your** repo. This template contains no data and
no secrets, and contrail itself is installed from a pinned release tag.

## Setup

### 1. Create your own repo from this template

Click **Use this template → Create a new repository**, then:

- **Name it `my-contrail`.** Any name works, but the docs, the issue tracker and
  `AGENTS.md` all use `my-contrail` as the example — so if you're `octocat`, you'll
  end up with `octocat/my-contrail` and everything you read will line up.
- **Set it to Private.** This is the important one.

Your flight history is personal, and **your new repo** will accumulate all of it — every route and
date you fly, plus the raw provider responses behind each figure. A repo created from a template
can be private even though the template is public; that's different from forking, where a fork of
a public repo is forced public.

Don't fork this repo, and don't copy the files by hand. "Use this template" is what gives you a
repo you can keep private.

### 2. Add your secrets — do this first

**Secrets do not carry over from a template.** Your new repo has none, and the first scheduled run
will fail without them.

Go to **Settings → Secrets and variables → Actions → New repository secret** and add both:

#### `TRIPIT_ICAL_URL`

TripIt → profile icon → Settings → enable Calendar Sync if needed → Calendar Feed.

**Treat this as a password.** Anyone holding it can read your itineraries.

#### `TIM_API_KEY`

[console.cloud.google.com](https://console.cloud.google.com) → create or pick a project → APIs &
Services → Library → search "Travel Impact Model API" → Enable → Credentials → Create Credentials →
API key.

Free, no billing required. Restricting the key to just that API is recommended.

### 3. Run it once by hand

Go to the **Actions** tab → **sync** → **Run workflow**.

(If you don't see the button, check that `.github/workflows/sync.yml` is on your repo's default
branch — that's what makes it appear.)

That first run is your backfill: it reads your whole TripIt feed at once. Expect most of it to
come back as `typical_route_average` rather than `exact` — see below.

After that it runs itself, daily.

### 4. Optional: add a Flighty export

If you use [Flighty](https://flightyapp.com), export your history (Settings → Export → Export as
CSV) and commit the file to `flighty/`. The next sync picks it up.

It's worth doing for two reasons. A TripIt feed only carries recent and upcoming trips, while an
export is your whole flying history — so this is how you backfill years at once. And the export is
the only source that records **the cabin you actually flew**; without it every row assumes economy,
which understates a long-haul business seat by roughly four times.

Your TripIt feed still owns any flight both describe. The export fills in blanks and leaves its own
key in `also_seen_as`, the column that joins a row back to the seat, PNR and tail number that only
Flighty holds. Keep the `FlightyExport-YYYY-MM-DD.csv` name: multiple exports are read newest
first, and the newest wins where two disagree.

Skip this entirely and nothing breaks — an empty `flighty/` is an ordinary state, and the sync runs
on TripIt alone. See [`flighty/README.md`](flighty/README.md) for the detail.

## What you get

`flight_emissions.csv`, committed back to your repo after every run: one row per flight, sorted
by date, with **`emissions_kg_actual`** as the per-flight figure.

Alongside it, `flight_emissions.raw.jsonl` keeps every response the emissions API
gave in full — the well-to-tank/tank-to-wake split, load factors, distance, data
provenance. TIM refuses to price a flight once it has departed, so whatever isn't
captured while a flight is upcoming is gone for good. It only records an answer
when it differs from the last one, so it grows when something changes, not daily.

There's deliberately no running-total column — the file is a record of your flights, not an
analysis of them, so nothing in it goes stale when you edit a row and a backfilled old flight
doesn't rewrite every row after it. The workflow log prints the current total on every run, and
this gets it from the file:

```bash
awk -F, 'NR==1{for(i=1;i<=NF;i++)if($i=="emissions_kg_actual")c=i;next} $c!=""{t+=$c} END{printf "%.1f kg CO2e\n",t}' flight_emissions.csv
```

Also `last_checked.txt`, a timestamp touched on every run. It exists to guarantee repository
activity: GitHub disables scheduled workflows after 60 days of inactivity, and a quiet stretch of
travel could easily mean no new flights to commit for that long.

Full column reference is in [contrail's README](https://github.com/atdr/contrail#csv-columns).

## Changed and cancelled flights

While a flight hasn't departed, contrail keeps it up to date: a retimed or
rerouted flight is corrected, and it is re-priced on every run, since the exact
figure depends on the aircraft and short-haul equipment changes right up to
departure.

If an upcoming flight disappears from the feed it is marked `cancelled` in the
`status` column rather than deleted. Its emissions figures are kept — TIM will
never price a past flight again — but it stops counting toward your total. If it
comes back, so does the row.

From the day after departure a row is frozen and only you can change it.

## Timing your syncs

You don't need to. Every upcoming flight is re-priced on every run, so the daily
sync already captures the best figure available before departure.

Scheduling a run _just_ before takeoff, to catch a last-minute aircraft change,
is unlikely to help: TIM's responses carry a dataset stamp (the `+dated` part of
`model_version`) that doesn't move daily, which suggests a late call returns what
the morning's call returned. And GitHub's scheduler is best-effort — routinely
delayed, occasionally skipped — so a precise time isn't available anyway.

## Exact vs. route-average emissions

The Travel Impact Model returns exact, flight-specific numbers **only for flights that haven't
departed yet**. That's how Google's API works, not a contrail limitation.

So contrail uses both: it asks for the exact figure first, and falls back to a route/market
average for anything that has already flown. The `emissions_source` column records which one each
row used.

The practical consequence: **running daily is the point.** Each upcoming flight gets its exact
number locked in before it departs. Anything first seen after it flew — your initial backfill,
mostly — keeps the route average permanently.

## Schedule

`sync.yml` runs at **15:37 UTC** daily. That's UTC year-round; it does not shift with BST or any
other DST.

The odd time is deliberate: workflows scheduled on the hour queue behind everyone else's and get
delayed. Change the `cron:` line if you'd rather it ran at another time.

## Upgrading contrail

`sync.yml` pins a contrail release:

```yaml
run: pip install "contrail @ git+https://github.com/atdr/contrail.git@v0.3.0"
```

Bump that tag when you want a newer version. It's pinned rather than tracking `main` so a change
upstream can never surprise a working setup. See
[contrail's releases](https://github.com/atdr/contrail/releases) for what's changed.

Dependabot (`.github/dependabot.yml`) keeps the _actions_ in the workflow current, but it will
**not** touch this pin — it's a plain shell command, not a dependency manifest. Upgrading contrail
is always your deliberate edit.

## Checking a change before you merge it

Bumping the pin, adding an export, editing the workflow — those are the changes that can
break a sync, and the scheduled run only tells you the next morning, once they've landed.
So `check-instance.yml` runs on every pull request in **your own repo** and does the sync
in advance:

```bash
contrail sync --csv-path flight_emissions.csv --dry-run
```

It installs whatever version your branch's `sync.yml` pins, reads your feed and your
exports, reconciles them against the log you already have, and prints what a real sync
would do — new flights, matches across sources, anything it couldn't parse. A broken feed
URL, an export contrail can't read, or a pin bumped across a change that doesn't suit
your data all fail the pull request instead of the next morning's run.

Two things it deliberately does not do:

- **It never writes.** `--dry-run` makes no changes, and the workflow checks that
  afterwards. Running it against your real log is safe.
- **It never calls the emissions API,** so the job isn't given `TIM_API_KEY` at all. A dry
  run doesn't price anything, so the key would go unused — and skipping the API is what
  keeps the check to a few seconds. It does mean the check can't tell you your key still
  works; the scheduled sync is what tells you that.

It also refuses a pull request that **deletes flight data** — a row gone from
`flight_emissions.csv`, a deleted `flight_emissions.raw.jsonl`, or a deleted export in
`flighty/`. Editing a row in place is fine and expected; deleting one throws away a
figure that usually can't be fetched again. When a deletion really is what you mean, add
the label `allow-data-loss` to the pull request.

The job is skipped in `atdr/contrail-gh`, which has no feed, no secrets and no log to
check.

## Staying up to date

This repo was created from the [atdr/contrail-gh](https://github.com/atdr/contrail-gh)
template. Unlike a fork, it has no ongoing link back to the template, so
there's no automatic way to pull in future changes — you set this up
once, yourself. This should rarely matter: contrail-gh's workflow and
README change infrequently, and most contrail _upgrades_ only need you to
bump the version tag in `.github/workflows/sync.yml`, not touch anything
here.

**One-time setup**, right after creating your repo:

```bash
git remote add template https://github.com/atdr/contrail-gh.git
git fetch template
```

**Call it `template`, not `upstream`.** `gh` picks which repo a command acts on
by remote name, and it ranks exactly three: `upstream`, then `github`, then
`origin`. Give this remote either of the first two and a bare `gh pr create` or
`gh issue create` in your private repo quietly targets this **public** template
instead. Avoid those two names and `origin` wins. `template` also describes the
relationship better: this isn't a fork, and there's nothing upstream of you.

Already added it as `upstream` or `github`? See
[Troubleshooting](#troubleshooting).

**To check for and pull in updates later:**

```bash
git fetch template
git diff template/main -- .github/workflows/ \
  .markdownlint-cli2.yaml .prettierrc.json .prettierignore
```

The files fall into two groups. Everything under `.github/workflows/`,
`README.md`, `AGENTS.md`, `.claude/` and the three Markdown config files
(`.markdownlint-cli2.yaml`, `.prettierrc.json`, `.prettierignore`) are
template-owned and safe to pull.
`flight_emissions.csv` is yours — your real flight data — and should
never be overwritten from the template; `last_checked.txt` is regenerated
every run and can be ignored either way.

`flighty/` is the one directory holding both: its `README.md` is
template-owned, while any `FlightyExport-*.csv` beside it is yours. The
template ships no exports, so pulling can't delete one — but if you
resolve conflicts by taking the template wholesale, keep your exports.

Pull just those files rather than merging the whole branch:

```bash
git checkout template/main -- .github/workflows/ \
  .markdownlint-cli2.yaml .prettierrc.json .prettierignore
# review the diff and re-apply your own version pin (the "@vX.Y.Z" in
# sync.yml's pip install line) if the template's copy overwrote it, then:
git add .github/workflows/ .markdownlint-cli2.yaml .prettierrc.json .prettierignore
git commit -m "Update workflows from contrail-gh"
```

The config files are named alongside the workflows because `markdown.yml` reads
them: pull the workflow without them and the Markdown check runs against
markdownlint's defaults instead of the settings it was written for. They are
listed one by one rather than pulling all of `.github/`, which would restore a
`dependabot.yml` you had deleted.

`sync.yml` is the only one carrying anything of yours. `check-instance.yml` reads
the pin out of `sync.yml` rather than repeating it, and `check-template.yml` does
nothing outside `atdr/contrail-gh` — so neither needs re-editing after a pull.

A full `git merge template/main` is possible instead, but needs
`--allow-unrelated-histories` the first time, and will try to merge
`flight_emissions.csv` too — which doesn't make sense, since your copy has
real data and the template's is just a header row. If you go this route,
resolve that file by always keeping your own version
(`git checkout --ours flight_emissions.csv`). Pulling the one file you
actually want is simpler and avoids this entirely.

## Troubleshooting

**`gh` commands here act on `atdr/contrail-gh` instead of my repo.** You named
the template remote `upstream` or `github`, both of which `gh` ranks above
`origin`. Rename it:

```bash
git remote rename upstream template     # or: github template
```

Anything you already created with a bare `gh` command went to that public repo
rather than this one, so it's worth a look before carrying on.

**The first scheduled run failed.** Almost always missing secrets — see step 2. Secrets never
carry over from a template.

**The commit-back step failed with a 403.** `permissions: contents: write` is missing from
`sync.yml`. `GITHUB_TOKEN` has been read-only by default since February 2023.

**Rows say `unparsed`.** contrail found something that looked like a flight but couldn't
confidently read the carrier, flight number, or airports from it. Check the `raw_summary` column
and fill the emissions in by hand if you want them counted — the figure counts from the next run
onwards. If you see a pattern of these, it's worth
[opening an issue](https://github.com/atdr/contrail/issues) on contrail.

**A pull request fails on "must not delete flight data".** It removes a row, the raw log,
or a `flighty/` export. Usually that's a merge or a rebase gone sideways rather than an
intention, so check the diff first. If you did mean it — replacing a superseded export,
say — add the label `allow-data-loss` to the pull request and re-run the check.

**The workflow stopped running.** GitHub disables scheduled workflows after 60 days of no
repository activity. `last_checked.txt` exists to prevent this, but if it happens, re-enable the
workflow from the Actions tab.

## License

MIT — see [LICENSE](LICENSE).

<!-- This file is wrapped at 100, not the 80 the rest of the repo uses. -->
<!-- markdownlint-configure-file {
  "MD013": { "line_length": 100, "tables": false, "code_blocks": false }
} -->
