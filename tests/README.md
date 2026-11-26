Run the Node tests (pure logic modules, the widget registry and manifests, drift and ratchet checks) with a current Node.js; CI uses the version in its pinned Arch snapshot (D-30):

```bash
node --test tests/*.test.cjs
```

Run the Qt Quick tests (`tst_*.qml`: services, tiles, the deck, the editor and the widgets) with Qt 6, Qt Quick Test and the Plasma QML modules installed:

```bash
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input tests
```

Adjust the Qt tool path for your distribution. The tests use synthetic data and fake runners; they do not change network or system settings and do not need a running Plasma session.

The Claude Code integration has its own Python tests:

```bash
python3 -m unittest discover -s integrations/claude-code -q
```

All of these run in `.github/workflows/ci.yml` for every pull request and every push to `main`, together with the lint ratchet and the shader stamp check (see `docs/CI.md`). `tools/` holds manual test helpers, not tests.
