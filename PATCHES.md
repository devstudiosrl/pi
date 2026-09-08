# The Printalo patches

**There are none, and that is the point.**

Printalo takes `@earendil-works/pi-coding-agent` from npm and has nothing to
change in it: the helpdesk drives the SDK from its own backend
(`made/helpdesk/backend/src/services/motore-pi.js`), with its own six tools and
its own prompt, so everything Printalo needs to be different is already outside
this package.

This fork exists for the day that stops being true — a fix that cannot wait for
an upstream release, a behaviour that has to differ. A fork created that day, in
a hurry, is a fork nobody has ever rebased; this one is rebased whenever
upstream releases, so the machinery is known to work before anybody needs it.

`main` mirrors upstream and is never touched. `printalo` is the upstream release
tag that Printalo runs on, plus nothing. When a patch lands here it goes in the
table below, one commit, prefixed `printalo:`, written as a general change and
proposed upstream — the same rules as the pi-web-ui fork, which does carry
patches and explains them in its own `PATCHES.md`.

| # | Patch | Upstream PR | State |
|---|---|---|---|
| — | none | — | — |

## How to update

    ./scripts/sync-upstream.sh

rebases `printalo` onto the newest upstream tag, runs the checks and tags the
result `v<upstream version>-printalo.<n>`. The weekly `upstream check` workflow
opens an issue when upstream has released something this branch is not on.

## When a patch does land

Then, and only then, `made/deploy` in the `ddra` repository changes the
dependency in `made/helpdesk/backend/package.json` from the npm package to this
fork's release asset. Until that day the fork ships nothing and the server
installs from npm, which is one moving part fewer.
