'use strict';
// Execute pinned overlaid host bytes at the ordinary filename so protocol imports
// and install roots remain ordinary. Native executable selection is in those bytes;
// this preload never substitutes a spawned executable, ticket or network message.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), Module = require('node:module'), assert = require('node:assert/strict');
const config = JSON.parse(fs.readFileSync(process.env.NWN_PRIVATE_TRACY_CONFIG));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(sha(fs.readFileSync(process.env.NWN_PRIVATE_TRACY_CONFIG)), JSON.parse(fs.readFileSync(path.join(config.out, 'manifest.json'))).config.sha256);
assert.equal(path.resolve(process.argv[1]), config.host);
assert.equal(sha(fs.readFileSync(config.host)), config.hostSha256);
assert.equal(sha(fs.readFileSync(config.compiledHost)), config.compiledHostSha256);
assert(!process.argv.some(value => /^--(?:server=|player-name=|private-login-pipe=|.*check|record-loading|native-profile|offline-replay|recording)/.test(value)));
const compile = Module.prototype._compile;
Module.prototype._compile = function(source, filename) {
 if (path.resolve(filename) !== config.host) return Reflect.apply(compile, this, [source, filename]);
 assert.equal(sha(Buffer.from(source)), config.hostSha256);
 Module.prototype._compile = compile;
 fs.writeFileSync(path.join(config.out, 'host-start.json'), JSON.stringify({ version: 1, pid: process.pid, run: config.run, ordinaryResolutionFilename: filename, originalSourceSha256: config.hostSha256, executedSourceSha256: config.compiledHostSha256, view: config.view, diagnosticOnly: true, performanceAccepted: false, automaticLogin: false }) + '\n', { flag: 'wx' });
 return Reflect.apply(compile, this, [fs.readFileSync(config.compiledHost, 'utf8'), filename]);
};
