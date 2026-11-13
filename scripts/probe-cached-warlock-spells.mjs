// Offline-only active-table diagnosis. Existing NWSync SQLite opens READONLY;
// no login/profile/key, native helper process, HTTP or game session is used.
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {DatabaseSync} from 'node:sqlite';
import {zstdDecompressSync} from 'node:zlib';
import {fileURLToPath} from 'node:url';
import {parseNWSyncManifest} from '../src/nwsync_manifest.js';
import {decodeNWSyncBlob} from '../electron/nwsync_content.mjs';
import {parse2da} from '../src/area.js';
import {parseTalkTable} from '../src/talk_table.js';

const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const project=path.join(workspace,'godot-client');
const [outputArg,manifest='7e0898127f44bd44f13bdab852ae85bb9badfd6b']=process.argv.slice(2);
assert.match(manifest,/^[0-9a-f]{40}$/);
const output=path.resolve(outputArg??path.join(project,'.cache/warlock-spell-diagnostics',new Date().toISOString().replace(/[-:.]/g,'').replace('T','-').replace('Z','')));
assert.ok(output.startsWith(path.join(project,'.cache/warlock-spell-diagnostics')+path.sep));
await fs.mkdir(output,{recursive:false});
const profile=path.join(os.homedir(),'Documents/Neverwinter Nights.0');
const cache=path.join(profile,'replacement-client/server-content');
const nativeDirectory=path.join(profile,'nwsync');
const hash=(bytes,algorithm='sha256')=>createHash(algorithm).update(bytes).digest('hex');
const manifestBytes=await fs.readFile(path.join(cache,'manifests',manifest));
assert.equal(hash(manifestBytes,'sha1'),manifest);
const selected=parseNWSyncManifest(manifestBytes);
const databasePath=path.join(nativeDirectory,'nwsyncdata_0.sqlite3');
const metaPath=path.join(nativeDirectory,'nwsyncmeta.sqlite3');
const before=await Promise.all([databasePath,metaPath].map(async file=>{const s=await fs.stat(file);return {file,size:s.size,mtimeMs:s.mtimeMs};}));
const db=new DatabaseSync(databasePath,{readOnly:true});
const meta=new DatabaseSync(metaPath,{readOnly:true});
const report={kind:'cached-arelith-warlock-spells-v1',manifest,manifestSha256:hash(manifestBytes),manifestEntries:selected.entries.length,httpAttempts:0,gameConnections:0,nativeHelperProcesses:0,protectedProfilesRead:0,resources:[],tables:{}};
try{
 report.cachedManifestMetadata=meta.prepare('SELECT m.sha1,m.origin_url,m.created_at,m.last_used_at,md.description FROM manifests m LEFT JOIN manifest_metadata md ON md.manifest_sha1=m.sha1 WHERE m.sha1=?').get(manifest)??null;
 const read=async(name,type=2017)=>{
  const entry=selected.catalog.get(`${name}:${type}`);assert.ok(entry,`Selected manifest lacks ${name}`);
  let encoded,source;
  try{encoded=await fs.readFile(path.join(cache,'objects',entry.hash));source='existing_compressed_file_cache';}
  catch(error){if(error.code!=='ENOENT')throw error;const row=db.prepare('SELECT data,size FROM resrefs WHERE sha1=?').get(entry.hash);assert.ok(row,`Offline selected resource absent: ${name}`);encoded=row.data;source='existing_native_sqlite_readonly';}
  const bytes=await decodeNWSyncBlob(encoded,{decompressZstd:b=>zstdDecompressSync(b)});
  assert.equal(hash(bytes,'sha1'),entry.hash);assert.equal(bytes.length,entry.size);
  const filename=name+(type===2018?'.tlk':'.2da');await fs.writeFile(path.join(output,filename),bytes,{flag:'wx'});
  report.resources.push({name,type,sha1:entry.hash,sha256:hash(bytes),bytes:bytes.length,source,file:filename});
  return bytes;
 };
 const table=async name=>{const value=parse2da((await read(name)).toString('latin1'));report.tables[name]={physicalRows:value.orderedRows.length,columns:value.columns};return value;};
 const classes=await table('classes');
 const candidates=classes.orderedRows.map((row,id)=>({id,row})).filter(({row})=>/^warlock$/i.test(row.Label));assert.equal(candidates.length,1);
 const {id,row}=candidates[0];report.class={physicalId:id,...row};
 const gainName=row.SpellGainTable.toLowerCase(),knownName=row.SpellKnownTable.toLowerCase();
 const gain=await table(gainName),known=await table(knownName),spells=await table('spells');
 await table('racialtypes');await table('ruleset');
 const custom=parseTalkTable(await read('arelith',2018));
 report.classTitle=custom.get((Number(row.Name)&0xffffff)>>>0);
 report.spellGainFirstLevels=gain.orderedRows.slice(0,3);report.spellKnownFirstLevels=known.orderedRows.slice(0,3);
 report.eligibleSpellsByLevel={};report.exampleSpells=[];
 for(let spellId=0;spellId<spells.orderedRows.length;spellId++){
  const spell=spells.orderedRows[spellId],raw=spell[row.SpellTableColumn];
  if(raw===undefined||raw==='****')continue;
  const level=Number(raw);if(!Number.isInteger(level)||level<0||level>=10)continue;
  report.eligibleSpellsByLevel[level]=(report.eligibleSpellsByLevel[level]??0)+1;
  if(report.exampleSpells.filter(s=>s.level===level).length<2){const ref=Number(spell.Name)>>>0;report.exampleSpells.push({physicalId:spellId,level,nameRef:ref,customName:ref&0x1000000?custom.get(ref&0xffffff):null,icon:spell.IconResRef});}
 }
 const count=Number(gain.orderedRows[0].NumSpellLevels)&255;
 const capacity=Array.from({length:10},(_,level)=>level<count&&known.orderedRows[0][`SpellLevel${level}`]!=='****'?Number(known.orderedRows[0][`SpellLevel${level}`])&255:0);
 const tabs=capacity.map(value=>value!==0); // This class has LearnScroll=0.
 assert.equal(id,92);assert.equal(Number(row.LearnScroll),0);assert.equal(count,0);assert.deepEqual(tabs,Array(10).fill(false));
 report.firstLevel={numSpellLevels:count,capacity,tabs,minimumCastingLevel:Number(row.MinCastingLevel),knownSelectionRequired:false};
 report.classification='Expected all ten tabs disabled for first-level Warlock in this SHA-verified cached Arelith manifest; zero level-one gain/known capacity. Requires actual native Snapshot/State replay before adapter acceptance.';
 report.provenanceLimit='Latest cached Arelith manifest matches the recorded V1.1.2231 resource description; the exact user-run selected descriptor was not persisted, so identity with that run is not asserted.';
 report.success=true;
}finally{
 db.close();meta.close();
 report.originalDatabaseMetadataUnchanged=true;
 for(const item of before){const s=await fs.stat(item.file);if(s.size!==item.size||s.mtimeMs!==item.mtimeMs)report.originalDatabaseMetadataUnchanged=false;}
 await fs.writeFile(path.join(output,'diagnostic.json'),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
}
console.log(JSON.stringify({success:report.success,output,manifest,classId:report.class.physicalId,classTitle:report.classTitle,firstLevel:report.firstLevel,eligibleSpellsByLevel:report.eligibleSpellsByLevel,originalDatabaseMetadataUnchanged:report.originalDatabaseMetadataUnchanged}));
