---
name: two-audience-docs
description: Use when writing or editing any Markdown in contrail-gh — README.md, AGENTS.md, flighty/README.md, or a new doc — and when copying a doc between the template and a repo created from it. Every file here is copied wholesale by "Use this template", so a line written for one repo arrives as an instruction in the other, where it may be false or destructive.
---

# Docs here have two readers

This repository is a GitHub template. Every tracked file, including this skill,
is copied into each private repo created from it. So each doc is read in two
places:

| | `atdr/contrail-gh` | a repo created from it |
|---|---|---|
| Visibility | public | private |
| `flight_emissions.csv` | header row only | real flights |
| `flighty/` | must hold no CSV | the owner's exports |

The rules are near-opposites, and the data at stake is unrecoverable: contrail
cannot re-price a departed flight, and an export is someone's entire flying
history. A directive that lands in the wrong repo is how that data gets deleted.

## Name the repo; don't point at it

This is the whole skill. Scoping a section with a heading is not enough, because
the words inside it still move:

> `## In the public template`
> **This directory must stay empty here.**

*Here*, *this repo*, *this directory*, *this file* all rebind to wherever the
reader is standing. Read in a private repo, that line orders someone to delete
their own export, and the heading above it does not stop a skimming reader — or
an agent grepping for `flighty/` — from acting on the bold imperative.

Write the repo's name instead:

> **`atdr/contrail-gh` must never hold an export.**

That sentence is true and inert in both repos. Prefer `atdr/contrail-gh` and
"your own repo" over any word that depends on position.

## Checklist

1. **State the default audience once, at the top**, if the file has one. Most
   docs here speak to the repo owner; say so rather than letting the reader infer
   it from tone.
2. **Name the repo in every directive**, especially anything that says *must*,
   *never*, *delete*, or *must not exist*.
3. **Claims about CI are repo-conditional.** `check-template.yml` is gated by
   repository name and does nothing outside the template. Never write "CI
   enforces this" without saying where.
4. **Say when a section does not apply**, in the section itself. A reader who
   skipped the heading needs the body to tell them.
5. **Don't hand-align a table.** `markdown.yml` runs Prettier and
   markdownlint-cli2 on every pull request in both repos; Prettier decides the
   padding, and prose wraps at 80 (100 in `README.md`). That is mechanical and
   says nothing about wording — everything above still has to be got right by
   reading.
6. **Re-read as the other reader before committing.** Ask the direct question:
   *what does this tell them to delete?* That is the failure that costs data;
   being over-cautious in the public repo costs nothing.

## What not to do

Don't fix this with a general reminder to "consider both audiences". `AGENTS.md`
has carried that instruction from the start, and `flighty/README.md` still
shipped a delete-your-data directive into private repos while following it. The
rule has to name the mechanism — deictic words rebind — or it doesn't bite.

Don't try to enforce it in CI either. The check would have to tell a legitimate
"your repo" from a misplaced "this repo", and a guard that can't do that reliably
either blocks correct writing or waves the bad line through. Review the wording
instead.
