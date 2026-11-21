'use strict';
// Run byte-pinned overlaid host at its ordinary filename for protocol imports.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),Module=require('node:module'),assert=require('node:assert/strict');
const file=process.env.NWN_LIVE_REVIEW_CONFIG,c=JSON.parse(fs.readFileSync(file)),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert.equal(sha(fs.readFileSync(file)),JSON.parse(fs.readFileSync(path.join(c.out,'manifest.json'))).config.sha256);
assert.equal(path.resolve(process.argv[1]),c.host);assert.equal(sha(fs.readFileSync(c.host)),c.hostSha256);assert.equal(sha(fs.readFileSync(c.compiledHost)),c.compiledHostSha256);
const compile=Module.prototype._compile;Module.prototype._compile=function(source,filename){if(path.resolve(filename)!==c.host)return Reflect.apply(compile,this,[source,filename]);assert.equal(sha(Buffer.from(source)),c.hostSha256);Module.prototype._compile=compile;fs.writeFileSync(path.join(c.out,'host-start.json'),JSON.stringify({pid:process.pid,originalSha256:c.hostSha256,executedSha256:c.compiledHostSha256,sourceProject:c.view,normalEngine:true,automaticLogin:false})+'\n',{flag:'wx'});return Reflect.apply(compile,this,[fs.readFileSync(c.compiledHost,'utf8'),filename]);};
