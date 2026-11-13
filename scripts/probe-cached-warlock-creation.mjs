// Offline fixture extraction only. Existing NWSync databases are READONLY.
// No game/login/HTTP/key/native process is created or queried.
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

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const label=process.argv[2],manifest=process.argv[3]??'7e0898127f44bd44f13bdab852ae85bb9badfd6b';
assert.match(label??'',/^[a-z0-9-]{3,80}$/);assert.match(manifest,/^[0-9a-f]{40}$/);
const output=path.join(root,'godot-client/.cache/cached-warlock-creation',label);
await fs.mkdir(path.dirname(output),{recursive:true});
await fs.mkdir(output,{recursive:false});
const data=path.join(output,'resources');await fs.mkdir(data);
const profile=path.join(os.homedir(),'Documents/Neverwinter Nights.0');
const cache=path.join(profile,'replacement-client/server-content');
const hash=(bytes,algorithm='sha256')=>createHash(algorithm).update(bytes).digest('hex');
const manifestBytes=await fs.readFile(path.join(cache,'manifests',manifest));
assert.equal(hash(manifestBytes,'sha1'),manifest);
const selected=parseNWSyncManifest(manifestBytes);
const dbPath=path.join(profile,'nwsync/nwsyncdata_0.sqlite3');
const metaPath=path.join(profile,'nwsync/nwsyncmeta.sqlite3');
const before=await Promise.all([dbPath,metaPath].map(async file=>{const s=await fs.stat(file);return {file,size:s.size,mtimeMs:s.mtimeMs};}));
const db=new DatabaseSync(dbPath,{readOnly:true});
const meta=new DatabaseSync(metaPath,{readOnly:true});
const report={kind:'cached-arelith-warlock-creation-v1',manifest,manifestSha256:hash(manifestBytes),manifestEntries:selected.entries.length,output,resources:[],captureGaps:[],baseFallbacks:[],tables:{},sourceFiles:[],httpAttempts:0,gameConnections:0,protectedProfilesRead:0,nativeHelperProcesses:0};
const loaded=new Map(),requested=new Set();
const present=v=>typeof v==='string'&&v!==''&&v!=='****';
const number=v=>Number.isFinite(Number(v))?Number(v):null;
async function read(name,type=2017){
 name=name.toLowerCase();const key=`${name}:${type}`;
 if(loaded.has(key))return loaded.get(key);
 const entry=selected.catalog.get(key);
 if(!entry){report.baseFallbacks.push({name,type,reason:'Not declared by the selected manifest; exact installed fallback still requires native catalog verification.'});loaded.set(key,null);return null;}
 let encoded,source;
 try{encoded=await fs.readFile(path.join(cache,'objects',entry.hash));source='existing_compressed_file_cache';}
 catch(error){if(error.code!=='ENOENT')throw error;const row=db.prepare('SELECT data,size FROM resrefs WHERE sha1=?').get(entry.hash);if(!row){report.captureGaps.push({name,type,sha1:entry.hash,size:entry.size});loaded.set(key,null);return null;}encoded=row.data;source='existing_native_sqlite_readonly';}
 const bytes=await decodeNWSyncBlob(encoded,{decompressZstd:b=>zstdDecompressSync(b)});
 assert.equal(hash(bytes,'sha1'),entry.hash);assert.equal(bytes.length,entry.size);
 assert.match(name,/^[a-z0-9_]+$/);const filename=name+(type===2018?'.tlk':'.2da');
 await fs.writeFile(path.join(data,filename),bytes,{flag:'wx'});
 report.resources.push({name,type,sha1:entry.hash,sha256:hash(bytes),bytes:bytes.length,source,file:`resources/${filename}`});loaded.set(key,bytes);return bytes;
}
async function table(name){
 const key=name.toLowerCase();if(requested.has(key))return report.tables[key]?.value??null;requested.add(key);
 const raw=await read(key);if(raw===null)return null;
 const value=parse2da(raw.toString('latin1'));report.tables[key]={physicalRows:value.orderedRows.length,columns:value.columns,value};return value;
}
try{
 report.cachedManifestMetadata=meta.prepare('SELECT m.sha1,m.origin_url,m.created_at,m.last_used_at,md.description FROM manifests m LEFT JOIN manifest_metadata md ON md.manifest_sha1=m.sha1 WHERE m.sha1=?').get(manifest)??null;
 const classes=await table('classes'),races=await table('racialtypes'),packages=await table('packages');
 assert.ok(classes&&races&&packages,'Required raw first-level tables must be captured.');
 const candidates=classes.orderedRows.map((row,id)=>({id,row})).filter(({row})=>/^warlock$/i.test(row.Label));assert.equal(candidates.length,1);
 const {id,row}=candidates[0];report.class={physicalId:id,...row};
 const tlkBytes=await read('arelith',2018);assert.ok(tlkBytes,'Captured custom TLK required');const tlk=parseTalkTable(tlkBytes);
 report.classTitle=tlk.get((Number(row.Name)&0xffffff)>>>0);
 report.race={physicalId:6,...races.orderedRows[6]};
 report.packages=packages.orderedRows.map((r,physicalId)=>({physicalId,...r})).filter(r=>number(r.ClassID)===id);
 report.selectedDefaultPackage=number(row.Package);
 const pending=new Set(['ruleset','feat','skills','spells','domains','spellschools','masterfeats','appearance','gender','phenotype','soundset','chargenclothes','portraits','stringtokens','hen_familiar','hen_companion','ranges','actions','exptable','baseitems','armor','itempropdef','iprp_costtable','iprp_paramtable','damagetypes','damagetypegroups','effecticons','traps','encumbrance','capart','parts_robe','cloakmodel','iprp_spells','keymap','damagelevels']);
 const fields=['PreReqTable','StatGainTable','SkillsTable','FeatsTable','BonusFeatsTable','SpellGainTable','SpellKnownTable','AttackBonusTable','SavingThrowTable'];
 for(const cls of classes.orderedRows)if(number(cls.PlayerClass)!==0)for(const field of fields)if(present(cls[field]))pending.add(cls[field].toLowerCase());
 for(const race of races.orderedRows)if(present(race.FeatsTable))pending.add(race.FeatsTable.toLowerCase());
 for(const pack of report.packages)for(const field of ['SkillPref2DA','FeatPref2DA','SpellPref2DA','Equip2DA'])if(present(pack[field]))pending.add(pack[field].toLowerCase());
 assert.ok(pending.size<400,'Bounded first-level table closure unexpectedly expanded');
 for(const name of pending)await table(name);
 const feat=report.tables.feat?.value,spells=report.tables.spells?.value;
 if(feat){
  report.featFamilies=feat.orderedRows.map((r,physicalId)=>({physicalId,label:r.LABEL??r.Label,master:r.MASTERFEAT??r.MasterFeat,allClasses:r.ALLCLASSESCANUSE??r.AllClassesCanUse})).filter(r=>present(r.master)).slice(0,40);
  const records=report.tables[String(row.FeatsTable).toLowerCase()]?.value;
  report.classFeats=records?.orderedRows.slice(0,40)??null;
 }
 const gain=report.tables[String(row.SpellGainTable).toLowerCase()]?.value,known=report.tables[String(row.SpellKnownTable).toLowerCase()]?.value;
 report.firstLevelSpells={gain:gain?.orderedRows[0]??null,known:known?.orderedRows[0]??null,spellColumn:row.SpellTableColumn,eligible:spells?spells.orderedRows.map((r,id)=>({id,level:number(r[row.SpellTableColumn])})).filter(r=>r.level!==null&&r.level>=0&&r.level<10).length:null};
 report.rawClassFields=Object.fromEntries(['PlayerClass','Package','SpellCaster','MemorizesSpells','LearnScroll','PickSchool','PickDomains','SpellbookRestricted','Arcane','MinAssociateLevel','PreReqTable'].map(k=>[k,row[k]??null]));
 for(const file of ['scripts/probe-cached-warlock-creation.mjs','src/nwsync_manifest.js','electron/nwsync_content.mjs','src/area.js','src/talk_table.js'])report.sourceFiles.push({path:file,sha256:hash(await fs.readFile(path.join(root,file)))});
 report.success=report.captureGaps.length===0;
 report.fixtureBoundary='Exact raw cached tables/custom TLK mounted above the original installed catalog. Physical class92/race6/default package and native controls; no authored replacement rule rows. Selected-manifest declared missing bytes must block acceptance. Installed-only fallbacks need native catalog verification. No active model/voice upload claim.';
 report.provenanceLimit='This manifest was previously identified as cached Arelith V1.1.2231; the user run descriptor was not persisted. No assertion that it matches the exact user screenshot session.';
}finally{
 db.close();meta.close();report.originalDatabaseMetadataUnchanged=true;
 for(const item of before){const s=await fs.stat(item.file);if(s.size!==item.size||s.mtimeMs!==item.mtimeMs)report.originalDatabaseMetadataUnchanged=false;}
 const details={...report,tables:Object.fromEntries(Object.entries(report.tables).map(([name,row])=>[name,{physicalRows:row.physicalRows,columns:row.columns}]))};
 await fs.writeFile(path.join(output,'fixture.json'),JSON.stringify(details,null,2)+'\n',{flag:'wx'});
}
console.log(JSON.stringify({success:report.success,output,classId:report.class?.physicalId,classTitle:report.classTitle,defaultPackage:report.selectedDefaultPackage,packages:report.packages?.map(r=>r.physicalId),cachedResources:report.resources.length,captureGaps:report.captureGaps,baseFallbacks:report.baseFallbacks.length,originalDatabaseMetadataUnchanged:report.originalDatabaseMetadataUnchanged,rawClassFields:report.rawClassFields,firstLevelSpells:report.firstLevelSpells}));
