import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {PassThrough} from 'node:stream';
import {selectReplayDisplay,resolveReplayDisplay,applyReplayDisplay,discoverReplayDisplay} from './replay_display.mjs';

const topology = primary => [0,1,2].map(index => ({index,primary:index===primary,workWidth:1000+index,workHeight:800}));

test('current topology replaces historical capsule screen and changes between launches', async () => {
 let current = topology(2), calls = 0;
 const options = {capsule:{screen:2},headless:false,project:'unused'};
 const discover = async () => { calls++; return current; };
 assert.equal((await resolveReplayDisplay(options,discover)).screen,1);
 current=topology(1);
 assert.equal((await resolveReplayDisplay(options,discover)).screen,2);
 assert.equal(calls,2);
});

test('explicit primary, absent display and no secondary fail before engine launch', () => {
 assert.throws(()=>selectReplayDisplay(topology(2),'2'),/nonprimary/);
 assert.throws(()=>selectReplayDisplay(topology(2),'3'),/nonprimary/);
 assert.throws(()=>selectReplayDisplay([topology(0)[0]]),/nonprimary/);
 const accepted=selectReplayDisplay(topology(2),'0');
 assert.equal(accepted.screen,0); assert.equal(accepted.primary,2);
});

test('malformed current topology fails closed', () => {
 for (const value of [null,[],{},topology(3),topology(1).reverse(),
   topology(1).map(s=>({...s,primary:true})),
   topology(1).map(s=>({...s,workWidth:NaN})),
   topology(1).map(s=>({...s,workHeight:0}))]) assert.throws(()=>selectReplayDisplay(value),/topology/);
 for (const requested of ['-1','1.0','32','no',null]) assert.throws(()=>selectReplayDisplay(topology(2),requested),/index/);
});

test('equal-area secondary selection is stable and leaves input untouched', () => {
 const screens=topology(2).map(s=>({...s,workWidth:1000}));
 const before=structuredClone(screens);
 assert.equal(selectReplayDisplay(screens).screen,0);
 assert.deepEqual(screens,before);
});

test('headless and ordinary replay do not run display discovery', async () => {
 const forbidden=()=>{throw Error('Discovery must not run');};
 assert.equal(await resolveReplayDisplay({capsule:{},headless:true},forbidden),null);
 assert.equal(await resolveReplayDisplay({capsule:null,headless:false},forbidden),null);
});

test('only engine-side stale screen arguments are replaced', () => {
 const args=['--screen','2','--path','project','--screen=0','--','--screen=script-value'];
 assert.deepEqual(applyReplayDisplay(args,{screen:1}),['--screen','1','--path','project','--','--screen=script-value']);
 assert.deepEqual(args,['--screen','2','--path','project','--screen=0','--','--screen=script-value']);
 assert.equal(applyReplayDisplay(args,null),args);
});

function fakeProcess(code,stdout,stderr='') {
 const child=new EventEmitter(); child.stdout=new PassThrough(); child.stderr=new PassThrough();
 child.kill=()=>{child.killed=true;};
 queueMicrotask(()=>{child.stdout.write(stdout);child.stderr.write(stderr);child.emit('close',code);});
 return child;
}

test('bounded read-only discovery command uses hidden PowerShell and quotes paths', async () => {
 let invocation;
 const screens=await discoverReplayDisplay("C:/work/agent's project",(...args)=>{
   invocation=args;return fakeProcess(0,JSON.stringify(topology(2)));
 });
 assert.deepEqual(screens,topology(2));
 assert.equal(invocation[0],'pwsh.exe');
 assert.ok(invocation[1].includes('-NonInteractive'));
 assert.match(invocation[1].at(-1),/agent''s project/);
 assert.match(invocation[1].at(-1),/Get-NativeScreenTopology$/);
 assert.equal(invocation[2].windowsHide,true);
});

test('discovery error, malformed response, output flood and spawn failure reject', async () => {
 await assert.rejects(()=>discoverReplayDisplay('unused',()=>fakeProcess(1,'','unavailable')),/unavailable/);
 await assert.rejects(()=>discoverReplayDisplay('unused',()=>fakeProcess(0,'not JSON')),/invalid JSON/);
 const child=fakeProcess(0,'x'.repeat(8193));
 await assert.rejects(()=>discoverReplayDisplay('unused',()=>child),/bound/);
 assert.equal(child.killed,true);
 await assert.rejects(()=>discoverReplayDisplay('unused',()=>{const child=new EventEmitter();child.stdout=new PassThrough();child.stderr=new PassThrough();queueMicrotask(()=>child.emit('error',Error('not found')));return child;}),/not found/);
});
