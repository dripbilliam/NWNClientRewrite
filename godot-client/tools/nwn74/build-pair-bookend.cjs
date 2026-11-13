'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const base=__dirname,source=path.join(base,'run-pair-probe.cjs'),target=path.join(base,'run-pair-bookend.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');const original=fs.readFileSync(source);
assert.equal(sha(original),'d22f26b06b296bb641daef5bfdd5c180b48bdefc0233a3312827293ee02d053b');
assert(!fs.existsSync(target));const code=original.toString().replace("const run='nwn74-pair-entry-a-'+mode", "const run='nwn74-pair-entry-b-'+mode");
assert.notEqual(code,original.toString());fs.writeFileSync(target,code,{flag:'wx'});console.log(JSON.stringify({sourceSha256:sha(original),target,sha256:sha(fs.readFileSync(target))}));
