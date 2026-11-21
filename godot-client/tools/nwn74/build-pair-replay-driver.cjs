'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sourceFile=path.join(__dirname,'replay-render-probe.mjs'),target=path.join(__dirname,'replay-pair-probe.mjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const original=fs.readFileSync(sourceFile);
assert.equal(sha(original),'cafcf235c0e4fc9ba72a2d842d85c15b24ce1a9344c0336a3a2362873b13d15b');
assert(!fs.existsSync(target),'Preserve private pair driver');
let code=original.toString();
function replaceOnce(before,after){assert.equal(code.split(before).length,2,'Private driver seam changed');code=code.replace(before,after);}
replaceOnce('.cache/nwn74/engine-build-b/receipt.json','.cache/nwn74/engine-build-c/receipt.json');
replaceOnce('35e47e75fb71dac4ae91140026d1b333988c1546e8033f86a8624702b12da64f','07d0989649b6b4722921cca2d0ce2960cfe8b732e012a9a8dfda134a8f96afe5');
replaceOnce("args.push('--capture-preview='+process.argv.includes('--preview'));","args.push('--capture-preview='+process.argv.includes('--preview'));\nconst nwn74PairIndex=arg('nwn74-pair-index')??'off';\nif(!['off','consumer'].includes(nwn74PairIndex))throw Error('NWN-74 private pair-index mode differs');\nif(nwn74PairIndex==='consumer')args.push('--nwn74-pair-index=consumer');");
replaceOnce('report.privateRenderProbe={issue:"NWN-74",accepted:false,receipt:nwn74ReceiptFile,receiptSha256:sha(await fs.readFile(nwn74ReceiptFile)),engineSha256:nwn74Receipt.binary.sha256};','report.privateRenderProbe={issue:"NWN-74",accepted:false,receipt:nwn74ReceiptFile,receiptSha256:sha(await fs.readFile(nwn74ReceiptFile)),engineSha256:nwn74Receipt.binary.sha256,pairIndexRequested:arg("nwn74-pair-index")??"off"};');
fs.writeFileSync(target,code,{flag:'wx'});
console.log(JSON.stringify({source:sourceFile,sourceSha256:sha(original),target,sha256:sha(fs.readFileSync(target)),bytes:code.length}));
