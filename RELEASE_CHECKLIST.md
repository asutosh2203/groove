# Release Checklist

Use this before publishing a new GitHub release or KDE Store update.

**Before the first public Kove release** also finish the items under "Before the first public release" in
[docs/ROADMAP.md](docs/ROADMAP.md): the new plugin ID, name and URLs in `metadata.json` (D-66), the manifest i18n pipeline,
and the hybrid-laptop GPU power check.

1. Bump `KPlugin.Version` in `metadata.json`.
2. Move the `CHANGELOG.md` "Unreleased" entries into a section for that version.
3. Run the automated checks (the same ones CI runs, see `docs/CI.md`; the pull request must pass **Checks (pinned Arch
   container)** before it can merge into `main`):

   ```bash
   node --test tests/*.test.cjs
   python3 -m unittest discover -s integrations/claude-code -q
   scripts/check-qml.sh
   QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qmltestrunner -input tests
   scripts/package.sh
   unzip -t kove-*.plasmoid
   ```

   `qmllint` and `qmltestrunner` live in `/usr/lib/qt6/bin` on Arch. A local `scripts/check-qml.sh` may count more warnings
   than CI's container does; CI is the reference.

4. Validate appstream metadata:

   ```bash
   kpackagetool6 --type Plasma/Applet --appstream-metainfo .
   ```

5. Reinstall locally:

   ```bash
   kpackagetool6 --type Plasma/Applet --upgrade .
   ```

6. Clear the QML cache and restart Plasma:

   ```bash
   rm -rf ~/.cache/plasmashell/qmlcache
   systemctl --user restart plasma-plasmashell.service
   ```

7. Test, in both Notch and Pill mode:

   - compact idle face (time and weather) and the time and weather clicks
   - media playback start, pause, previous, next, and the elapsed time
   - notification popup, rounded notification image, click-through and the inline reply
   - a download or file copy as a job
   - deck pages and the page-control capsule (click and drag); Esc and outside click close it
   - Control Center open and close, click-to-focus, outside-click dismissal
   - Control Center power menu opens without closing it
   - Control Center edit mode: drag, drop-to-hide, palette add, resize, save and cancel
   - preset editor: add, remove and reorder widgets, settings forms, the enum picker page, Done and Cancel
   - Clock, World Clock, Weather, Pomodoro, System Monitor and Claude Code widgets on their spans
   - brightness and volume sliders, including a missing audio sink or backlight
   - network tile: connected and disconnected Ethernet and Wi-Fi, networking disabled, multiple adapters, IPv6, refresh and settings buttons, compact sizes
   - Bluetooth and KDE Connect lists with more than three devices
   - Claude Code sessions (if the integration is installed): a working tile, "Needs your OK", "Done", click to raise the window

8. Create a tag matching the metadata version, optionally with the `-alpha` suffix (the only suffix the release workflow's
   version check accepts):

   ```bash
   git tag v0.3.2-alpha
   git push origin v0.3.2-alpha
   ```

   CI builds the `.plasmoid`, validates the version, and publishes the GitHub release. A tag with a suffix is marked as a
   prerelease.

9. **KDE Store listing.** Create or update the Kove entry (a new entry with its own plugin ID, D-66, not the upstream
   "Dynamic Island" listing). Check and fill in:
   - the description,
   - the screenshots,
   - the categories,
   - the release notes (copy them from the GitHub release and `CHANGELOG.md`),
   - the uploaded `.plasmoid` (the KDE Store gets the plasmoid only, not the optional panel preset or the Claude Code integration).
