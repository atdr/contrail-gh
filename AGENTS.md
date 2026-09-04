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
git remote get-url origin      # owner *and* name: only atdr/contrail-gh is the template
```

Match the owner too. Any repo name is allowed for an instance, so
`octocat/contrail-gh` is a perfectly legal private repo — matching on
`contrail-gh` alone would read it as the template.

**Ask git, not `gh`.** `gh` chooses a repo by remote _name_, ranking `upstream`,
then `github`, above `origin`. In an instance that added the template under
either name, every bare `gh` command — including `gh repo view` — answers for the
**public template** instead. Believing it here is the worst case in this file:
you would read `isTemplate: true`, apply the template's "the CSV is a header row
and nothing else" rule, and truncate someone's real travel history.

The README tells people to name that remote `template` for this reason, but the
naming is not what makes this safe, so don't conclude `gh` is fine here once you
see it. A `remote.<name>.gh-resolved` key — what `gh repo set-default` writes —
overrides remote names outright, and `gh` needs the network and a valid token
besides. The failure modes are what settle it: when git can't answer it exits
non-zero with nothing, which lands you in the fallback below, while `gh` returns
clean, confident JSON about the other repo. On the one decision where being
confidently wrong destroys data, prefer the detector that fails loudly.

|                              | The template (`atdr/contrail-gh`) | An instance (e.g. `octocat/my-contrail`) |
| ---------------------------- | --------------------------------- | ---------------------------------------- |
| Visibility                   | public                            | **private**                              |
| `flight_emissions.csv`       | header row only                   | real flights, and it grows               |
| `flight_emissions.raw.jsonl` | must not exist                    | present once a sync has run              |
| `flighty/`                   | empty of CSVs                     | the owner's exports, committed by hand   |
| Actions secrets              | none                              | `TRIPIT_ICAL_URL`, `TIM_API_KEY`         |
| Purpose                      | the thing people copy             | someone's actual travel record           |

**If there is no `origin` to ask** — a ZIP download, a checkout whose remote is
named something else, the wrong working directory — then assume you are in an
**instance** and touch no data. More than one line in `flight_emissions.csv`
proves it is an instance, but a header-only file proves nothing either way: a
private repo that hasn't run its first sync yet ships the identical header, and
it may already hold a hand-committed export in `flighty/`, which is someone's
entire flying history. Guessing "template" wrongly destroys that; guessing
"instance" wrongly just means being too careful in a public repo.

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
- The template remote should be called `template`, so that `gh` keeps resolving
  to this repo rather than the public one. Don't rename it to `upstream` or
  `github` — `gh` ranks both above `origin`. If you find one of those names here,
  rename it, and pass `--repo` on every `gh` command until you have.
- `check-template.yml` deliberately does nothing here. Its checks assume a
  header-only CSV and would fail against real data.
- `sync.yml` is the one that _does_ run here. That is the whole point.
- `check-instance.yml` runs in your own repo too, on every pull request: it
  dry-runs the sync against your feed, your exports and your log, so a change is
  known good before it merges rather than the next morning. It writes nothing
  and never calls the emissions API — a dry run doesn't price, so it isn't given
  `TIM_API_KEY` at all, which keeps the check quick and off the API. It also
  refuses a pull request that deletes a row, the raw log or an export; label the
  pull request `allow-data-loss` when that is genuinely what you mean.

## If you are in the template

**`atdr/contrail-gh` must never hold flight data**, because it is public. In the
template, and only there, `flight_emissions.csv` is the header row and nothing
else, `flight_emissions.raw.jsonl` must not exist, and `flighty/` must hold no
CSV. `check-template.yml` enforces all three and is gated to `atdr/contrail-gh`
by repository name, so it does nothing in a repo created from the template —
where all three files are the point.

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

**The workflows are guarded by repository name, and every guard is
load-bearing:**

| Workflow             | Guard                                         | Runs in               |
| -------------------- | --------------------------------------------- | --------------------- |
| `check-template.yml` | `if: github.repository == 'atdr/contrail-gh'` | the template only     |
| `sync.yml`           | `if: github.repository != 'atdr/contrail-gh'` | instances only        |
| `check-instance.yml` | `if: github.repository != 'atdr/contrail-gh'` | instances only        |
| `markdown.yml`       | none — it is `workflow_call` only             | wherever it is called |

Removing one produces a workflow that fails forever in the wrong repo: the
template checks assume a header-only CSV and would fail against real data, while
the sync and the pull request check have no secrets and nothing to log in
`atdr/contrail-gh`. The three guarded ones key off the repository name, so an
instance is simply "not the template" — no per-user configuration needed.

`markdown.yml` is the exception, and deliberately so: it carries no guard
because it never triggers on its own. `check-template.yml` and
`check-instance.yml` each call it behind their own guard, so it runs in
`atdr/contrail-gh` and in every repo created from the template, from one
definition. That is the point — a check defined twice is a check that drifts.

`check-instance.yml` is the one `atdr/contrail-gh` can never try out, because
its guard skips it there on every run. `check-template.yml` compensates with a
static check: the file must exist, must still carry that guard, and must declare
every `_URL` / `_PATH` environment variable `sync.yml` declares — or the pull
request check inspects a different set of sources than the sync reads. It does
_not_ take `TIM_API_KEY`, and that omission is deliberate: a dry run never
prices, so the key would go unused and the check stays quick and off the
emissions API.

The call to `markdown.yml` from `check-instance.yml` has the same blind spot,
and `check-template.yml` checks it the same way: `markdown.yml` must exist, both
workflows must still call it, and the three config files it reads
(`.markdownlint-cli2.yaml`, `.prettierrc.json`, `.prettierignore`) must be
present. Without that last one an instance can pull the workflow alone and lint
against markdownlint's defaults.

It is triggered by `pull_request` alone. A `workflow_dispatch` run would carry
the same name while checking less — the data-loss steps have no base commit to
compare against outside a pull request, and skip.

**Every edit here lands in someone's private repo later**, including this file.
Writing instructions that "still make sense there" is necessary and not
sufficient: words like _here_, _this repo_ and _this directory_ rebind to
wherever the file is being read, so a correctly scoped heading can still sit
above a directive that inverts. Name the repo — `atdr/contrail-gh`, or "your own
repo" — rather than pointing at it.

Before editing any Markdown here, read
[`.claude/skills/two-audience-docs`](.claude/skills/two-audience-docs/SKILL.md).

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

**Every workflow is named after its own file**, and the description goes on the
job. GitHub labels a check `<workflow name> / <job name>` and never shows the
filename, so a workflow named for what it does leaves a reader guessing which of
the four files to open — `check-template / template contract` names both. A
workflow reached through `workflow_call` adds a third segment, the calling job's:
`check-template / markdown / lint`. In `atdr/contrail-gh`, `check-template.yml`
fails the build when a workflow's name and its filename disagree; the job names
are a convention it does not check.

**Every job sets `timeout-minutes`.** GitHub's default is six hours, and the
failure that matters here is a stall rather than an error: `npx` fetching
Prettier and `pip` fetching contrail both hang instead of failing, and one
stalled Prettier download has already cost five minutes in a job that usually
runs in twelve seconds. The three checks allow ten minutes. `sync.yml` allows
sixty, and that one is deliberately generous — a sync killed mid-run commits
nothing, so every emissions figure it had already fetched is lost, and TIM will
not price a flight once it has departed. In a repo created from
`atdr/contrail-gh` a hung job also spends metered Actions minutes, which the
public `atdr/contrail-gh` never pays. The setting cannot go on a job that calls
`markdown.yml` — a job with `uses:` takes no `timeout-minutes` — so it lives on
the job inside `markdown.yml`, which covers both callers.

**Markdown is formatted, not hand-aligned.** Prettier owns table padding and
whitespace, markdownlint-cli2 owns line length and the rest, and
`markdown.yml` runs both on every pull request. Run
`npx prettier@3.9.6 --write "**/*.md"` rather than lining a table up by hand.
Prose wraps at 80, except `README.md`, which wraps at 100 and says so in a
`markdownlint-configure-file` comment at its foot. `CLAUDE.md` is excluded from
both tools because it is a symlink to this file.

The same three config files exist in `atdr/contrail`, as copies. Three
repositories cannot share one, so a rule changed in either place has to be
changed in the other or they start disagreeing about what correct Markdown is.

## When contrail changes

[contrail's docs/contrail-gh.md](https://github.com/atdr/contrail/blob/main/docs/contrail-gh.md)
lists what a schema or output change upstream obliges here: regenerate the
header, bump the pin, check the README still describes the columns accurately.
