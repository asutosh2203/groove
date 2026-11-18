const assert = require('node:assert/strict');
const { test } = require('node:test');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { load, j } = require('./logic-loader.cjs');

const A = load('ArtCache.js');
const SPOTIFY = 'https://i.scdn.co/image/ab67616d0000b27305d081cbdc2f67d37a364d63';

test('only http(s) URLs are remote; local files and empties pass through untouched', () => {
    assert.equal(A.isRemote(SPOTIFY), true);
    assert.equal(A.isRemote('http://x.test/a.png'), true);
    for (const u of ['file:///tmp/a.png', '/tmp/a.png', '', null, undefined, 'ftp://x/a'])
        assert.equal(A.isRemote(u), false);
    const states = {};
    assert.equal(A.sourceFor('file:///tmp/a.png', states), 'file:///tmp/a.png');
    assert.equal(A.sourceFor('', states), '');
});

test('fetchable: no quote, whitespace or control characters, bounded length', () => {
    assert.equal(A.isFetchable(SPOTIFY), true);
    for (const bad of ["https://x.test/a'b", 'https://x.test/a b', 'https://x.test/a\nb', 'https://x.test/\x00', 'https://x.test/' + 'a'.repeat(3000), 'file:///x'])
        assert.equal(A.isFetchable(bad), false, bad);
    assert.equal(A.command("https://x.test/a'; rm -rf ~ #"), '');
});

test('the file name is stable, safe and differs per URL', () => {
    const a = A.fileName(SPOTIFY);
    assert.equal(a, A.fileName(SPOTIFY));
    assert.match(a, /^art-[0-9a-f]+-[0-9a-z]+$/);
    assert.notEqual(a, A.fileName(SPOTIFY.replace('0000b273', '0000b274')));
});

test('source: nothing while pending, the file when fetched, the original URL after a failure', () => {
    const states = {};
    assert.equal(A.sourceFor(SPOTIFY, states), '');
    A.remember(states, SPOTIFY, { path: '/home/u/.cache/kove/art/art-1' });
    assert.equal(A.sourceFor(SPOTIFY, states), 'file:///home/u/.cache/kove/art/art-1');
    const other = 'https://x.test/b.jpg';
    A.remember(states, other, { failed: true });
    assert.equal(A.sourceFor(other, states), other);
});

test('remembered results stay bounded and drop the oldest first', () => {
    const states = {};
    for (let i = 0; i < 200; ++i) A.remember(states, 'https://x.test/' + i, { failed: true });
    const keys = Object.keys(states);
    assert.equal(keys.length, 64);
    assert.equal(keys[keys.length - 1], 'https://x.test/199');
    assert.equal(states['https://x.test/0'], undefined);
});

test('the path is taken from the first line of output only, and only when absolute', () => {
    assert.equal(A.pathFrom('/home/u/.cache/kove/art/art-1\n'), '/home/u/.cache/kove/art/art-1');
    for (const bad of ['', '\n', 'error: nope', null, undefined, 'curl: (22) fail\n/tmp/x'])
        assert.equal(A.pathFrom(bad), '');
});

const http = require('node:http');
const { execFile } = require('node:child_process');

// Runs the cache command for real against a local server and a throwaway cache directory.
async function withServer(handler, body) {
    const hits = [];
    const server = http.createServer((req, res) => { hits.push(req.url); handler(req, res); });
    await new Promise((r) => server.listen(0, '127.0.0.1', r));
    const base = 'http://127.0.0.1:' + server.address().port;
    const cacheHome = fs.mkdtempSync(path.join(os.tmpdir(), 'kove-art-'));
    const run = (cmd, env = {}) => new Promise((resolve) => execFile('sh', ['-c', cmd], { cwd: cacheHome, env: { ...process.env, XDG_CACHE_HOME: cacheHome, ...env } }, (err, stdout) => resolve({ err, stdout })));
    try {
        await body({ base, cacheHome, hits, run, dir: path.join(cacheHome, 'kove/art') });
    } finally {
        server.close();
        fs.rmSync(cacheHome, { recursive: true, force: true });
    }
}
const image = (req, res) => { res.writeHead(req.url === '/missing' ? 404 : 200, { 'Content-Length': 5 }); res.end('IMAGE'); };

test('the command fetches once, reuses the file, prints its path and leaves no partial file behind', () => withServer(image, async ({ base, cacheHome, hits, run, dir }) => {
    const file = A.pathFrom((await run(A.command(base + '/a.jpg'))).stdout);
    assert.equal(file.startsWith(cacheHome + '/kove/art/art-'), true);
    assert.equal(fs.readFileSync(file, 'utf8'), 'IMAGE');
    assert.equal(A.pathFrom((await run(A.command(base + '/a.jpg'))).stdout), file);
    assert.equal(hits.length, 1); // reused, not fetched again
    assert.equal(A.pathFrom((await run(A.command(base + '/missing'))).stdout), '');
    assert.deepEqual(fs.readdirSync(dir).filter((n) => n.endsWith('.part')), []);
}));

test('the script is constant: the URL only ever travels as an argument, so shell syntax in it is inert', () => withServer(image, async ({ base, cacheHome, run }) => {
    const a = A.command('https://x.test/a.jpg');
    const b = A.command('https://y.test/b.jpg?$(id)');
    assert.equal(a.slice(0, a.indexOf(' kove-art ')), b.slice(0, b.indexOf(' kove-art ')));
    const nasty = base + '/a.jpg?x=$(touch${IFS}PWNED1)&y=`touch${IFS}PWNED2`;touch${IFS}PWNED3|touch${IFS}PWNED4>PWNED5';
    assert.equal(A.isFetchable(nasty), true);
    const out = A.pathFrom((await run(A.command(nasty))).stdout);
    assert.equal(fs.readFileSync(out, 'utf8'), 'IMAGE');
    assert.deepEqual(fs.readdirSync(cacheHome).filter((n) => n.startsWith('PWNED')), []);
}));

test('only http and https are fetched; a local file is shown as it is and never copied', () => withServer(image, async ({ run, dir }) => {
    for (const u of ['file:///etc/passwd', '/etc/passwd', 'ftp://x/a', 'gopher://x/a', 'data:image/png;base64,AAAA']) {
        assert.equal(A.command(u), '', u);
        assert.equal(A.sourceFor(u, {}), u);
    }
    assert.equal(fs.existsSync(dir), false);
}));

test('a redirect to another scheme is refused', () => withServer((req, res) => { res.writeHead(302, { Location: 'file:///etc/passwd' }); res.end(); }, async ({ base, run, dir }) => {
    assert.equal(A.pathFrom((await run(A.command(base + '/r'))).stdout), '');
    assert.deepEqual(fs.readdirSync(dir), []);
}));

test('a file past the size limit is refused, whether or not the server states its length', () => {
    const big = Buffer.alloc(9000000, 1);
    return withServer((req, res) => {
        if (req.url === '/stated') { res.writeHead(200, { 'Content-Length': big.length }); res.end(big); } else { res.writeHead(200); res.write(big); res.end(); }
    }, async ({ base, run, dir }) => {
        for (const u of ['/stated', '/chunked']) {
            assert.equal(A.pathFrom((await run(A.command(base + u))).stdout), '', u);
            assert.deepEqual(fs.readdirSync(dir).filter((n) => n.startsWith('art-')), [], u);
        }
    });
});

test('without curl nothing is printed and nothing is cached, so the caller falls back to the original URL', () => withServer(image, async ({ base, run, dir }) => {
    const bin = fs.mkdtempSync(path.join(os.tmpdir(), 'kove-bin-'));
    try {
        for (const t of ['sh', 'mkdir', 'mv', 'rm', 'touch', 'find', 'sort', 'awk', 'xargs', 'stat', 'true']) {
            const real = execFileSync('sh', ['-c', 'command -v ' + t]).toString().trim();
            if (real) fs.symlinkSync(real, path.join(bin, t));
        }
        const out = (await run(A.command(base + '/a.jpg'), { PATH: bin })).stdout;
        assert.equal(A.pathFrom(out), '');
        assert.equal(A.sourceFor(base + '/a.jpg', { [base + '/a.jpg']: { failed: true } }), base + '/a.jpg');
        assert.deepEqual(fs.readdirSync(dir).filter((n) => n.startsWith('art-')), []);
    } finally {
        fs.rmSync(bin, { recursive: true, force: true });
    }
}));

test('eviction: past the cap the least recently used files go first, and the fresh cover always stays', () => withServer((req, res) => { res.writeHead(200, { 'Content-Length': 1000 }); res.end(Buffer.alloc(1000, 2)); }, async ({ base, run, dir }) => {
    fs.mkdirSync(dir, { recursive: true });
    const now = Date.now() / 1000;
    for (let i = 0; i < 6; ++i) { // 6 old files of 1000 bytes, i = 0 the oldest
        const f = path.join(dir, 'art-old' + i);
        fs.writeFileSync(f, Buffer.alloc(1000, 1));
        fs.utimesSync(f, now - 1000 + i, now - 1000 + i);
    }
    fs.writeFileSync(path.join(dir, 'other.txt'), 'not ours'); // never touched
    const cap = 3500;
    const file = A.pathFrom((await run(A.command(base + '/new.jpg', cap))).stdout);
    const left = fs.readdirSync(dir).filter((n) => n.startsWith('art-')).sort();
    assert.equal(left.includes(path.basename(file)), true);
    assert.deepEqual(left, [path.basename(file), 'art-old4', 'art-old5'].sort()); // 3 x 1000 fit under 3500, a 4th does not
    assert.equal(fs.existsSync(path.join(dir, 'other.txt')), true);
}));

test('reusing a cover refreshes it, so a cover in use outlives older unused ones', () => withServer(image, async ({ base, run, dir }) => {
    const first = A.pathFrom((await run(A.command(base + '/keep.jpg'))).stdout);
    const old = Date.now() / 1000 - 5000;
    fs.utimesSync(first, old, old);
    await run(A.command(base + '/keep.jpg')); // played again
    assert.ok(fs.statSync(first).mtimeMs / 1000 > old + 1000);
}));

test('the default cap is about 50 MB', () => {
    assert.match(A.command(SPOTIFY), / 52428800$/);
});
