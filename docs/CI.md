# CI

One workflow (`.github/workflows/ci.yml`), one job, run inside a pinned Arch Linux container (D-36). It runs on every
push to `main`, every pull request and every `v*` tag; a tag also publishes a release after the checks pass.

## What it checks

1. Node tests: `node --test tests/*.test.cjs`
2. `scripts/check-qml.sh`: `qmllint` over every QML and JS file under `contents/`
   - errors (any non-zero qmllint exit, for example a syntax error) fail the job;
   - any `[import]` warning fails the job (a module that cannot be loaded would weaken every other check);
   - the warning count of each FILE may not go above its line in `.github/qmllint-baseline.txt` (`<count> <path>`; a
     file with no line has a baseline of 0, so new files must be warning-free). It only ever goes down: when CI says a
     file dropped, run `scripts/check-qml.sh --lower-baseline` (it only writes lower numbers and refuses while anything
     fails) and commit the file. A moved file keeps its count: rename its line by hand;
   - a file that drops by more than half gets a loud "verify the analysis didn't abort" warning;
   - a probe: qmllint 6.12 can silently stop analysing a file (for example a `const` inside an arrow function), which
     makes its warnings vanish and would pass the ratchet for the wrong reason. Each QML file is linted again as a
     temporary copy with one unresolved name appended, and qmllint must report exactly one more warning (two probe
     forms are tried, either may pass). Files where no form works are listed in `.github/qmllint-probe-exempt.txt`:
     their counts are unverifiable, so adding one there is a review decision (today: `configGeneral.qml`,
     `ControlCenterEditor.qml`, `WeatherService.qml`).
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
4. If qmllint now counts differently, lower the affected files' counts in `.github/qmllint-baseline.txt` with
   `scripts/check-qml.sh --lower-baseline`, and investigate any file that went up or fails the probe.

Dependabot (`.github/dependabot.yml`) keeps the GitHub Actions versions current. It does **not** update the container
image or `ALA_DATE`; those are bumped by hand as above.
