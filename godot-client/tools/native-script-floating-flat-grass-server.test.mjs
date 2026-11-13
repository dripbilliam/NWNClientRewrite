import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {patchArea,compatibleJoins,TILE_ID,read} from './native-script-floating-flat-grass-server.mjs';
import {parseErf} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const fixture=path.join(project,'.cache/script-floating-authority/native-script-floating-flat-grass-v1/server');
test('actual prepared fixture passes unchanged base verifier and all flat-grass joins',async()=>{
 const value=await read(fixture);
 assert.equal(value.module,'ScriptFloat1');assert.equal(value.port,5129);assert.equal(value.public,false);
 assert.equal(value.flatGrassControl.tileId,120);assert.equal(value.flatGrassControl.model,'ttr01_p03_01');
 assert.equal(value.flatGrassControl.areas.length,2);
 assert.deepEqual(value.flatGrassControl.areas.map(a=>a.joins),[180,180]);
 const before=parseErf(await fs.readFile(path.join(fixture,'flat-grass-before/ScriptFloat1.mod'))).entries;
 const after=parseErf(await fs.readFile(path.join(fixture,'modules/ScriptFloat1.mod'))).entries;
 assert.equal(after.size,before.size);
 for(const[key,bytes]of before){
  if(!key.endsWith(':2012'))assert.deepEqual(after.get(key),bytes,key);
  else{const original=parseGff(bytes).root,changed=parseGff(after.get(key)).root;for(const tile of original.Tile_List)Object.assign(tile,{Tile_ID:TILE_ID,Tile_Orientation:0,Tile_Height:0});assert.deepEqual(changed,original,key);}
 }
});
test('byte patch rejects unsupported authored area rather than rewriting it',async()=>{
 const entries=parseErf(await fs.readFile(path.join(fixture,'flat-grass-before/ScriptFloat1.mod'))).entries;
 const original=entries.get('dense_a:2012');
 const valid=patchArea(original);assert.equal(valid.bytes.length,original.length);assert.ok(valid.changes.length>0);
 const corrupted=Buffer.from(original);corrupted.write('BAD ',0,'ascii');assert.throws(()=>patchArea(corrupted),/Expected ARE/);
 assert.deepEqual(entries.get('dense_a:2012'),original);
});
test('adjacency certification checks stream ports and height at both shared corners',()=>{
 const tile={TopRight:'Grass',BottomRight:'Grass',BottomLeft:'Grass',TopLeft:'Grass',TopRightHeight:'0',BottomRightHeight:'0',BottomLeftHeight:'0',TopLeftHeight:'0',Top:'',Right:'',Bottom:'',Left:''};
 const area={Width:2,Height:1,Tile_List:[{Tile_Orientation:0,Tile_Height:0},{Tile_Orientation:0,Tile_Height:0}]};
 assert.equal(compatibleJoins(area,tile),1);
 assert.throws(()=>compatibleJoins(area,{...tile,Right:'Stream'}));
 assert.throws(()=>compatibleJoins(area,{...tile,TopRightHeight:'1'}));
});
test('new wrapper prepares before all live activity and retains exclusive safe launch guards',async()=>{
 const source=await fs.readFile(path.join(project,'tools/test-native-flat-grass-visual.ps1'),'utf8');
 const end=source.indexOf("if(-not(Test-Path -LiteralPath (Join-Path $floatingHome 'flat-grass.json')))");
 const prepare=source.slice(0,end);
 assert.ok(prepare.includes('if($PrepareOnly)'));assert.ok(prepare.includes('return'));
 for(const forbidden of ['Get-CimInstance','Get-NetUDPEndpoint','Get-NativeSecondaryScreen','ProtectedKeyFile','native-barter-alt.dpapi','[Diagnostics.Process]::Start'])assert.ok(!prepare.includes(forbidden),forbidden);
 for(const token of ['[ValidateRange(30,90)][int]$Seconds=90','--verify $floatingHome','A secondary display is required','window/size/no_focus=true','-ScriptFloatingVisual -VisualSeconds $Seconds','-EngineRuntime editor -LocalOnly','-ProtectedKeyFile $floatingAlt','ProcessId-eq7568','ProcessId -eq 25060','FileShare]::None','NWN_DO_NOT_NAT_PUNCH',"'-port','5129','-publicserver','0'",'Assert-NativeLevelUpNoBuild','finally{','protectedProcesses=$floatingProcessGuards','nativeOutputs=$floatingOutputGuards','fixtureInputs=$floatingFixtureGuards','harnessInputs=$floatingHarnessGuards','startup.non_activating-ne$true','mouseMode-ne0'])assert.ok(source.includes(token),token);
 assert.ok(!source.includes('build-window-modes.ps1'));assert.ok(!source.includes('SendKeys'));assert.ok(!source.includes('SetForegroundWindow'));
});
