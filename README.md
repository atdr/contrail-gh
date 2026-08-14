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

Click **Use this template → Create a new repository**, and **set it to Private**.

Your flight history is personal, and this repo will accumulate all of it. A repo created from a
template can be private even though the template is public — that's different from forking, where
a fork of a public repo is forced public.

### 2. Add your secrets — do this first

**Secrets do not carry over from a template.** Your new repo has none, and the first scheduled run
will fail without them.

Go to **Settings → Secrets and variables → Actions → New repository secret** and add both:

| Secret | Where to get it |
|---|---|
| `TRIPIT_ICAL_URL` | TripIt → profile icon → Settings → enable Calendar Sync if needed → Calendar Feed. **Treat this as a password** — anyone holding it can read your itineraries. |
| `TIM_API_KEY` | [console.cloud.google.com](https://console.cloud.google.com) → create or pick a project → APIs & Services → Library → search "Travel Impact Model API" → Enable → Credentials → Create Credentials → API key. Free, no billing required. Restricting the key to just that API is recommended. |

### 3. Run it once by hand

Go to the **Actions** tab → **Sync flight emissions** → **Run workflow**.

(If you don't see the button, check that `.github/workflows/sync.yml` is on your repo's default
branch — that's what makes it appear.)

That first run is your backfill: it reads your whole TripIt feed at once. Expect most of it to
come back as `typical_route_average` rather than `exact` — see below.

After that it runs itself, daily.

## What you get

`flight_emissions.csv`, committed back to your repo after every run: one row per flight, sorted
by date, with **`emissions_kg_actual`** as the per-flight figure.

There's deliberately no running-total column — the file is a record of your flights, not an
analysis of them, so nothing in it goes stale when you edit a row and a backfilled old flight
doesn't rewrite every row after it. The workflow log prints the current total on every run, and
this gets it from the file:

```
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
run: pip install "contrail @ git+https://github.com/atdr/contrail.git@v0.1.0"
```

Bump that tag when you want a newer version. It's pinned rather than tracking `main` so a change
upstream can never surprise a working setup. See
[contrail's releases](https://github.com/atdr/contrail/releases) for what's changed.

Dependabot (`.github/dependabot.yml`) keeps the *actions* in the workflow current, but it will
**not** touch this pin — it's a plain shell command, not a dependency manifest. Upgrading contrail
is always your deliberate edit.

## Staying up to date

This repo was created from the [atdr/contrail-gh](https://github.com/atdr/contrail-gh)
template. Unlike a fork, it has no ongoing link back to the template, so
there's no automatic way to pull in future changes — you set this up
once, yourself. This should rarely matter: contrail-gh's workflow and
README change infrequently, and most contrail *upgrades* only need you to
bump the version tag in `.github/workflows/sync.yml`, not touch anything
here.

**One-time setup**, right after creating your repo:

    git remote add upstream https://github.com/atdr/contrail-gh.git
    git fetch upstream

**To check for and pull in updates later:**

    git fetch upstream
    git diff upstream/main -- .github/workflows/sync.yml

Files here fall into two groups. `.github/workflows/sync.yml` and
`README.md` are template-owned and safe to pull from upstream.
`flight_emissions.csv` is yours — your real flight data — and should
never be overwritten from upstream; `last_checked.txt` is regenerated
every run and can be ignored either way.

Pull just the workflow file rather than merging the whole branch:

    git checkout upstream/main -- .github/workflows/sync.yml
    # review the diff and re-apply your own version pin (the "@vX.Y.Z" in
    # the pip install line) if upstream's copy overwrote it, then:
    git add .github/workflows/sync.yml
    git commit -m "Update workflow from contrail-gh"

A full `git merge upstream/main` is possible instead, but needs
`--allow-unrelated-histories` the first time, and will try to merge
`flight_emissions.csv` too — which doesn't make sense, since your copy has
real data and upstream's is just a header row. If you go this route,
resolve that file by always keeping your own version
(`git checkout --ours flight_emissions.csv`). Pulling the one file you
actually want is simpler and avoids this entirely.

## Troubleshooting

**The first scheduled run failed.** Almost always missing secrets — see step 2. Secrets never
carry over from a template.

**The commit-back step failed with a 403.** `permissions: contents: write` is missing from
`sync.yml`. `GITHUB_TOKEN` has been read-only by default since February 2023.

**Rows say `unparsed`.** contrail found something that looked like a flight but couldn't
confidently read the carrier, flight number, or airports from it. Check the `raw_summary` column
and fill the emissions in by hand if you want them counted — the figure counts from the next run
onwards. If you see a pattern of these, it's worth
[opening an issue](https://github.com/atdr/contrail/issues) on contrail.

**The workflow stopped running.** GitHub disables scheduled workflows after 60 days of no
repository activity. `last_checked.txt` exists to prevent this, but if it happens, re-enable the
workflow from the Actions tab.

## License

MIT — see [LICENSE](LICENSE).
