const assert = require('node:assert/strict');
const { spawn, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createHash } = require('node:crypto');

const scripts = __dirname;
const root = path.dirname(scripts);

function run(command, args, cwd, ok = true) {
  const result = spawnSync(command, args, {
    cwd, encoding: 'utf8',
    env: { ...process.env, GIT_AUTHOR_NAME: 'Release Test', GIT_AUTHOR_EMAIL: 'test@example.invalid',
      GIT_COMMITTER_NAME: 'Release Test', GIT_COMMITTER_EMAIL: 'test@example.invalid',
      GIT_CONFIG_NOSYSTEM: '1', GIT_TERMINAL_PROMPT: '0' },
  });
  if (ok) assert.equal(result.status, 0, result.error?.message || result.stderr || result.stdout);
  return result;
}

function perl(code, cwd, args = [], ok = true) {
  return run('perl', ['-I', scripts, '-MReleaseUtil', '-e', code, ...args], cwd, ok);
}

function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'slackhacks-release-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const remote = path.join(dir, 'origin.git');
  const repo = path.join(dir, 'repo');
  run('git', ['init', '--bare', remote], dir);
  run('git', ['init', '-b', 'dev', repo], dir);
  run('git', ['remote', 'add', 'origin', remote], repo);
  fs.writeFileSync(path.join(repo, 'release.txt'), 'release');
  run('git', ['add', '.'], repo);
  run('git', ['commit', '-m', 'release'], repo);
  run('git', ['branch', 'prod'], repo);
  run('git', ['tag', '-a', 'v1', '-m', 'release'], repo);
  return repo;
}

test('Perl and Bash release entry points pass syntax checks', () => {
  for (const file of ['ReleaseUtil.pm', 'release.pl', 'deploy-github.pl', 'deploy-curseforge.pl']) {
    run('perl', ['-I', scripts, '-c', path.join(scripts, file)], root);
  }
  for (const file of ['deploy.sh', 'build.sh']) {
    run('bash', ['-n', path.join(scripts, file)], root);
  }
});

test('deployment requires a clean checkout and matching pushed prod tip and tag', t => {
  const repo = fixture(t);
  const verify = () => perl('ReleaseUtil::verify_release("v1", "prod")', repo, [], false);
  assert.notEqual(verify().status, 0, 'unpushed release must fail');
  run('git', ['push', 'origin', 'prod'], repo);
  assert.notEqual(verify().status, 0, 'unpushed tag must fail');
  run('git', ['push', 'origin', 'v1'], repo);
  let result = verify();
  assert.equal(result.status, 0, result.stderr);
  result = verify();
  assert.equal(result.status, 0, result.stderr);
  fs.writeFileSync(path.join(repo, 'dirty.txt'), 'dirty');
  assert.notEqual(verify().status, 0, 'untracked files must fail');
  fs.unlinkSync(path.join(repo, 'dirty.txt'));
  fs.appendFileSync(path.join(repo, 'release.txt'), 'changed');
  assert.notEqual(verify().status, 0, 'tracked changes must fail');
  run('git', ['add', '.'], repo);
  run('git', ['commit', '-m', 'new work'], repo);
  assert.notEqual(verify().status, 0, 'different HEAD must fail');
  run('git', ['branch', '-f', 'prod', 'HEAD'], repo);
  run('git', ['push', 'origin', 'prod'], repo);
  run('git', ['checkout', 'v1'], repo);
  assert.notEqual(verify().status, 0, 'old release must not roll back prod');
});

test('lightweight pushed tags are supported; mismatched remote tags are rejected', t => {
  const repo = fixture(t);
  run('git', ['tag', 'v2'], repo);
  run('git', ['push', 'origin', 'prod', 'v2'], repo);
  perl('ReleaseUtil::verify_release("v2", "prod")', repo);
  fs.appendFileSync(path.join(repo, 'release.txt'), 'next');
  run('git', ['add', '.'], repo);
  run('git', ['commit', '-m', 'next'], repo);
  run('git', ['tag', '-f', 'v2'], repo);
  run('git', ['branch', '-f', 'prod', 'HEAD'], repo);
  run('git', ['push', 'origin', 'prod'], repo);
  assert.notEqual(perl('ReleaseUtil::verify_release("v2", "prod")', repo, [], false).status, 0);
});

test('changelog notes preserve quotes, newlines, backslashes and UTF-8 through curl', async t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'slackhacks-json-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const changelog = '# Release\r\n"Quotes", \\\\paths\\\\, tabs\tand café ☃\n';
  fs.writeFileSync(path.join(dir, 'changelog-v1.md'), changelog);
  const server = http.createServer((req, res) => {
    let data = '';
    req.setEncoding('utf8');
    req.on('data', chunk => { data += chunk; });
    req.on('end', () => {
      const json = JSON.parse(data);
      assert.equal(json.body.replace(/\r\n/g, '\n'), changelog.replace(/\r\n/g, '\n'));
      assert.equal(json.generate_release_notes, false);
      assert.equal(req.headers['content-type'], 'application/json');
      res.writeHead(201);
      res.end('{"id":1}');
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const code = `
    my ($file, $body) = ReleaseUtil::read_changelog("", $ARGV[0], "v1");
    my $json = ReleaseUtil::json_file({body => $body, generate_release_notes => JSON::PP::false});
    my ($status, $response) = ReleaseUtil::curl_response("-H", "Content-Type: application/json",
        "--data-binary", "\\@$json", $ARGV[1]);
    die "$status: $response" unless $status == 201;
  `;
  const child = spawn('perl', ['-I', scripts, '-MReleaseUtil', '-e', code, dir,
    `http://127.0.0.1:${server.address().port}`], { cwd: dir });
  let stderr = '';
  child.stderr.on('data', chunk => { stderr += chunk; });
  await new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', status => status === 0 ? resolve() : reject(new Error(stderr)));
  });
  fs.writeFileSync(path.join(dir, 'changelog-v1.md'), '');
  assert.notEqual(perl('ReleaseUtil::read_changelog("", $ARGV[0], "v1")', dir, [dir], false).status, 0);
  assert.notEqual(perl('ReleaseUtil::read_changelog("missing.md", "", "v1")', dir, [], false).status, 0);
});

function prepareScripts(repo, baseUrl) {
  run('git', ['tag', '-d', 'v1'], repo);
  fs.mkdirSync(path.join(repo, 'scripts'));
  for (const file of ['release.pl', 'deploy.sh', 'load-env.sh', 'deploy-github.pl',
    'deploy-curseforge.pl', 'ReleaseUtil.pm', 'defaults.env']) {
    let content = fs.readFileSync(path.join(scripts, file), 'utf8');
    if (baseUrl) {
      content = content.replaceAll('https://api.github.com', baseUrl)
        .replaceAll('https://uploads.github.com', baseUrl)
        .replaceAll('https://wow.curseforge.com', baseUrl);
    }
    fs.writeFileSync(path.join(repo, 'scripts', file), content);
  }
  fs.writeFileSync(path.join(repo, '.gitignore'), 'dist/\n');
  fs.writeFileSync(path.join(repo, 'SlackHacks.toc'), '## Version: 1\n## Interface: 120000\n');
  fs.mkdirSync(path.join(repo, 'changelog'));
  fs.writeFileSync(path.join(repo, 'changelog', 'changelog-v1.md'), '# Release "one"\n\nNotes with café and \\\\paths.\n');
  fs.writeFileSync(path.join(repo, 'scripts', 'build.sh'),
    '#!/usr/bin/env bash\nset -euo pipefail\nmkdir -p dist\nprintf archive > dist/SlackHacks.zip\n' +
    'echo build >> dist/build-count\n');
  run('git', ['add', '.'], repo);
  run('git', ['commit', '-m', 'release scripts'], repo);
  run('git', ['branch', '-f', 'prod', 'HEAD'], repo);
  run('git', ['push', 'origin', 'prod'], repo);
}

function script(repo, file, args = [], ok = true) {
  return run('perl', [`scripts/${file}`, ...args], repo, ok);
}

test('local-only releases resume without retagging, deploying, or hiding new changes', t => {
  const repo = fixture(t);
  prepareScripts(repo);
  const deploy = path.join(repo, 'scripts', 'deploy.sh');
  fs.writeFileSync(deploy, '#!/usr/bin/env bash\nexit 97\n');
  run('git', ['add', '.'], repo);
  run('git', ['commit', '-m', 'deployment must not run'], repo);
  run('git', ['checkout', 'prod'], repo);
  fs.writeFileSync(path.join(repo, 'prod-only.txt'), 'production history');
  run('git', ['add', '.'], repo);
  run('git', ['commit', '-m', 'production-only commit'], repo);
  run('git', ['checkout', 'dev'], repo);
  script(repo, 'release.pl', ['--no-push']);
  const tag = run('git', ['rev-parse', 'v1'], repo).stdout;
  assert.equal(run('git', ['rev-list', '--parents', '-n', '1', 'v1'], repo).stdout.trim().split(/\s+/).length, 3);
  script(repo, 'release.pl', ['--no-push']);
  assert.equal(run('git', ['rev-parse', 'v1'], repo).stdout, tag);
  assert.equal(run('git', ['branch', '--show-current'], repo).stdout.trim(), 'dev');
  assert.equal(run('git', ['ls-remote', '--tags', 'origin', 'v1'], repo).stdout, '');
  fs.appendFileSync(path.join(repo, 'release.txt'), 'next');
  const dirty = script(repo, 'release.pl', ['--force'], false);
  assert.notEqual(dirty.status, 0);
  assert.match(dirty.stderr, /uncommitted changes/);
  run('git', ['add', '.'], repo);
  run('git', ['commit', '-m', 'new work without bump'], repo);
  const changed = script(repo, 'release.pl', ['--dry-run'], false);
  assert.notEqual(changed.status, 0);
  assert.match(changed.stderr, /unreleased changes/);
  assert.equal(run('git', ['rev-parse', 'v1'], repo).stdout, tag);
});

test('release deploys pushed prod, restores dev on failure, and retries the same tag', t => {
  const repo = fixture(t);
  prepareScripts(repo);
  fs.writeFileSync(path.join(repo, 'scripts', 'deploy.sh'),
    '#!/usr/bin/env bash\nset -eu\n' +
    'test "$(git branch --show-current)" = prod\n' +
    'test "$(git rev-parse HEAD)" = "$(git ls-remote origin refs/heads/prod | cut -f1)"\n' +
    'git ls-remote --exit-code --tags origin refs/tags/v1\nexit 97\n');
  run('git', ['add', '.'], repo);
  run('git', ['commit', '-m', 'failing deployment'], repo);
  const first = script(repo, 'release.pl', [], false);
  assert.notEqual(first.status, 0);
  assert.match(first.stderr, /exit code 97/);
  assert.equal(run('git', ['branch', '--show-current'], repo).stdout.trim(), 'dev');
  const tag = run('git', ['rev-parse', 'v1'], repo).stdout;
  const second = script(repo, 'release.pl', [], false);
  assert.notEqual(second.status, 0);
  assert.match(second.stdout, /Resuming existing release/);
  assert.match(second.stderr, /exit code 97/);
  assert.equal(run('git', ['rev-parse', 'v1'], repo).stdout, tag);
  assert.equal(run('git', ['branch', '--show-current'], repo).stdout.trim(), 'dev');
});

function asyncScript(repo, file, args = []) {
  const env = { ...process.env };
  const defaults = fs.readFileSync(path.join(scripts, 'defaults.env'), 'utf8');
  for (const match of defaults.matchAll(/^([A-Z_]+)=/gm)) delete env[match[1]];
  Object.assign(env, { GITHUB_TOKEN: 'test-token', CURSEFORGE_API_TOKEN: 'test-token' });
  return new Promise((resolve, reject) => {
    const child = spawn('perl', [`scripts/${file}`, ...args], { cwd: repo, env });
    let stdout = '', stderr = '';
    child.stdout.on('data', chunk => { stdout += chunk; });
    child.stderr.on('data', chunk => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', status => resolve({ status, stdout, stderr }));
  });
}

test('deployers reconcile GitHub releases and guard completed or uncertain CurseForge uploads', async t => {
  const state = { release: null, assets: [], creates: 0, patches: 0, uploads: 0, cfUploads: 0, cfFail: false };
  const server = http.createServer((req, res) => {
    const chunks = [];
    req.on('data', chunk => { chunks.push(chunk); });
    req.on('end', () => {
      const bytes = Buffer.concat(chunks);
      const reply = (status, data) => { res.writeHead(status, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(data)); };
      if (req.url.endsWith('/releases/tags/v1')) {
        return reply(state.release ? 200 : 404, state.release || { message: 'Not Found' });
      }
      if (req.url.endsWith('/releases') && req.method === 'POST') {
        state.creates++;
        const body = JSON.parse(bytes.toString());
        state.release = { ...body, id: 10, html_url: 'test-release' };
        return reply(201, state.release);
      }
      if (req.url.endsWith('/releases/10') && req.method === 'PATCH') {
        state.patches++;
        Object.assign(state.release, JSON.parse(bytes.toString()));
        return reply(200, state.release);
      }
      if (req.url.includes('/releases/10/assets?') && req.method === 'GET') {
        return reply(200, state.assets);
      }
      if (req.url.includes('/releases/10/assets?') && req.method === 'POST') {
        state.uploads++;
        const asset = { id: 11, name: 'SlackHacks.zip', state: 'uploaded', size: bytes.length,
          digest: `sha256:${createHash('sha256').update(bytes).digest('hex')}` };
        state.assets.push(asset);
        return reply(201, asset);
      }
      if (req.url.endsWith('/api/game/version-types')) return reply(200, [{ id: 1, name: 'Retail' }]);
      if (req.url.endsWith('/api/game/versions')) return reply(200, [{ id: 12, name: '12.0.0', gameVersionTypeID: 1 }]);
      if (req.url.endsWith('/upload-file')) {
        state.cfUploads++;
        const multipart = bytes.toString();
        assert.match(multipart, /name="metadata"/);
        assert.ok(multipart.includes('"changelog":"# Release \\"one\\"\\n\\nNotes with café'));
        return reply(state.cfFail ? 500 : 200, state.cfFail ? { error: 'uncertain' } : { id: 22 });
      }
      reply(500, { error: `Unexpected request ${req.method} ${req.url}` });
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const repo = fixture(t);
  prepareScripts(repo, `http://127.0.0.1:${server.address().port}`);
  run('git', ['tag', '-a', 'v1', '-m', 'release'], repo);
  for (const file of ['deploy-github.pl', 'deploy-curseforge.pl']) {
    assert.notEqual((await asyncScript(repo, file, ['--dry-run'])).status, 0, 'unpushed tag must block entry point');
  }
  assert.equal(fs.existsSync(path.join(repo, 'dist')), false);
  run('git', ['push', 'origin', 'v1'], repo);
  const deploy = async file => {
    const result = await asyncScript(repo, file);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    return result;
  };
  for (const file of ['deploy-github.pl', 'deploy-curseforge.pl']) {
    const dryRun = await asyncScript(repo, file, ['--dry-run']);
    assert.equal(dryRun.status, 0, dryRun.stderr + dryRun.stdout);
  }
  assert.equal(fs.existsSync(path.join(repo, 'dist')), false, 'dry runs must not build');
  assert.equal(state.creates + state.cfUploads, 0);
  await deploy('deploy-github.pl');
  await deploy('deploy-github.pl');
  assert.equal(state.creates, 1);
  assert.equal(state.uploads, 1);
  assert.equal(state.release.generate_release_notes, false);
  assert.equal(state.release.body, fs.readFileSync(path.join(repo, 'changelog', 'changelog-v1.md'), 'utf8'));
  state.release.body = 'old notes';
  await deploy('deploy-github.pl');
  assert.equal(state.patches, 1);
  assert.equal(state.uploads, 1);
  state.assets[0].digest = 'sha256:different';
  const conflict = await asyncScript(repo, 'deploy-github.pl');
  assert.notEqual(conflict.status, 0);
  assert.match(conflict.stderr, /Refusing to replace/);
  assert.equal(state.uploads, 1);

  await deploy('deploy-curseforge.pl');
  await deploy('deploy-curseforge.pl');
  assert.equal(state.cfUploads, 1);
  assert.equal(fs.readFileSync(path.join(repo, 'dist', 'build-count'), 'utf8'), 'build\n');
  state.assets[0].digest = `sha256:${createHash('sha256').update('archive').digest('hex')}`;
  const retry = await deploy('release.pl');
  assert.match(retry.stdout, /Resuming existing release/);
  assert.equal(run('git', ['branch', '--show-current'], repo).stdout.trim(), 'dev');
  assert.equal(state.creates, 1);
  assert.equal(state.uploads, 1);
  assert.equal(state.cfUploads, 1);

  const other = fixture(t);
  prepareScripts(other, `http://127.0.0.1:${server.address().port}`);
  run('git', ['tag', '-a', 'v1', '-m', 'release'], other);
  run('git', ['push', 'origin', 'v1'], other);
  state.cfFail = true;
  assert.notEqual((await asyncScript(other, 'deploy-curseforge.pl')).status, 0);
  const pending = await asyncScript(other, 'deploy-curseforge.pl');
  assert.notEqual(pending.status, 0);
  assert.match(pending.stderr, /pending or uncertain/);
  assert.equal(state.cfUploads, 2, 'uncertain upload must not be repeated');
});
