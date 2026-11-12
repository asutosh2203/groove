# CI

One workflow (`.github/workflows/ci.yml`), one job, run inside a pinned Arch Linux container (D-36). It runs on every
push to `main`, every pull request and every `v*` tag; a tag also publishes a release after the checks pass.

## What it checks

1. Node tests: `node --test tests/*.test.cjs`
2. `scripts/check-qml.sh`: `qmllint` over every QML and JS file under `contents/`
   - errors (any non-zero qmllint exit, for example a syntax error) fail the job;
   - any `[import]` warning fails the job (a module that cannot be loaded would weaken every other check);
   - the warning count may not go above `.github/qmllint-baseline.txt`. It only ever goes down: when CI says the
     count dropped, lower the number in that file in the same change.
3. Qt Quick tests: `qmltestrunner -input tests` (offscreen, software backend)
4. Package build: `scripts/package.sh`, then `unzip -t`

You can run 2 locally with `scripts/check-qml.sh`. The baseline is defined by the qmllint in the CI container; a
different local Qt can count a little differently.

## Bumping the pinned environment

The image tag and the package snapshot must always carry the same date. To bump both:

1. Pick a tag from https://hub.docker.com/r/archlinux/archlinux/tags, in the form `base-YYYYMMDD.0.N` (the build
   number is part of the tag; `base-YYYYMMDD` alone does not exist).
2. In `.github/workflows/ci.yml` set `container.image` to that tag and `ALA_DATE` to the same date as `YYYY/MM/DD`.
   The snapshot must exist at `https://archive.archlinux.org/repos/YYYY/MM/DD/`.
3. Push to a branch and open a pull request: the run shows the Node, Qt and Plasma versions it resolved.
4. If qmllint now counts differently, set the new count in `.github/qmllint-baseline.txt` only if it is lower, and
   investigate if it is higher.

Dependabot (`.github/dependabot.yml`) keeps the GitHub Actions versions current. It does **not** update the container
image or `ALA_DATE`; those are bumped by hand as above.
