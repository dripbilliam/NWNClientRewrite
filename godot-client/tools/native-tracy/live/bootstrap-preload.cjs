'use strict';
// Ordinary protected-settings broker. Only working-copy paths and host source differ.
if (process.type === 'browser' && process.env.NWN_PRIVATE_TRACY_CONFIG) {
 const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), Module = require('node:module'), cp = require('node:child_process'), assert = require('node:assert/strict');
 const config = JSON.parse(fs.readFileSync(process.env.NWN_PRIVATE_TRACY_CONFIG)), originalLoad = Module._load;
 const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
 assert.equal(sha(fs.readFileSync(process.env.NWN_PRIVATE_TRACY_CONFIG)), JSON.parse(fs.readFileSync(path.join(config.out, 'manifest.json'))).config.sha256);
 function install() {
  assert.equal(sha(fs.readFileSync(config.bootstrap)), config.bootstrapSha256);
  const { app } = require('electron'); app.setName('nwn-model-viewer-research');
  const original = app.getPath('userData'), copies = [];
  fs.mkdirSync(config.userdata, { recursive: true });
  function copy(source, destination) { if (fs.existsSync(source)) { fs.copyFileSync(source, destination, fs.constants.COPYFILE_EXCL); copies.push({ source, destination, sha256: sha(fs.readFileSync(source)), bytes: fs.statSync(source).size }); } }
  for (const name of ['Local State', 'client-settings.json', 'native-server-browser.json']) copy(path.join(original, name), path.join(config.userdata, name));
  const godot = path.join(app.getPath('appData'), 'Godot/app_userdata/NWN Native Engine Prototype');
  for (const [from, to] of [['native-options.cfg', 'native-render-preferences.cfg'], ['native-menu-layout.cfg', 'native-menu-layout.cfg'], ['native-character-lobby.cfg', 'native-lobby-preferences.cfg']]) copy(path.join(godot, from), path.join(config.userdata, to));
  fs.writeFileSync(path.join(config.out, 'working-settings-proof.json'), JSON.stringify({ version: 1, copies, scope: 'Working copies preserve encrypted settings and native preference bytes. No contents or credentials logged; original user profile/Documents/NWSync remain ordinary.' }) + '\n', { flag: 'wx' });
  for (const key of ['userData', 'sessionData', 'logs', 'crashDumps']) app.setPath(key, config.userdata);
  const spawn = cp.spawn;
  cp.spawn = function(file, args, options) {
   if (file === 'node' && Array.isArray(args) && path.resolve(args[0]) === config.host) {
    const env = { ...process.env, ...options?.env, NWN_PRIVATE_TRACY_CONFIG: process.env.NWN_PRIVATE_TRACY_CONFIG };
    delete env.NODE_OPTIONS;
    return Reflect.apply(spawn, this, [file, ['--require', path.join(__dirname, 'host-preload.cjs'), ...args], { ...options, env }]);
   }
   return Reflect.apply(spawn, this, [file, args, options]);
  };
 }
 Module._load = function(request, ...rest) {
  if (typeof request === 'string' && path.isAbsolute(request) && path.resolve(request) === config.bootstrap) { Module._load = originalLoad; install(); }
  return Reflect.apply(originalLoad, this, [request, ...rest]);
 };
}
