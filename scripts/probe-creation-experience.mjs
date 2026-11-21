import fs from 'node:fs/promises';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText,RESOURCE_TYPE} from '../src/resource_archive.js';
const [install,cacheDirectory,advertisementFile,userDirectory,output]=process.argv.slice(2),ad=JSON.parse(await fs.readFile(advertisementFile,'utf8')),report={http:0,tables:{},resources:[]};
const resources=installedNetworkResources({install,cacheDirectory,userDirectory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.http++;throw Error('Offline probe');}}});
try{const result=await resolveServerResources(ad.requirements,{...resources,language:0});const resolver=await resources.openModule(null,result.resolved);
 for(const name of ['masterfeats','feat','portraits','soundset']){const t=parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA)));report.tables[name]={columns:t.columns,count:t.orderedRows.length,rows:t.orderedRows.filter((r,i)=>i<10||/edisum|egbert|orcafrun|weaponfocus|spellfocus/i.test(JSON.stringify(r))).slice(0,45)};}
 const images=new Set([...resolver.resourceNames(3),...resolver.resourceNames(2033)]);const portraits=parse2da(decodeResourceText(await resolver.getResource('portraits',2017)));report.portraits={total:portraits.orderedRows.length,missing:portraits.orderedRows.filter(r=>r.BaseResRef!=='****'&&![...['m','l','h','s','t',''].map(s=>'po_'+r.BaseResRef.toLowerCase()+s)].some(n=>images.has(n))).map(r=>r.BaseResRef)};
 const races=parse2da(decodeResourceText(await resolver.getResource('racialtypes',2017))),appearance=parse2da(decodeResourceText(await resolver.getResource('appearance',2017)));report.raceAppearance=races.orderedRows.filter(r=>Number(r.PlayerRace)).map(r=>({race:r.Label,appearance:r.Appearance,row:appearance.orderedRows[Number(r.Appearance)]}));
 for(const [name,type]of [['pmoo_neck001',6],['pmoo_neck001',2002],['pmo0_neck001',6],['pmo0_neck001',2002],['pmh0_neck001',6]]){try{report.resources.push({name,type,bytes:(await resolver.getResource(name,type)).byteLength});}catch(e){report.resources.push({name,type,code:e.code,error:e.message});}}
}finally{resources.close();await fs.writeFile(output,JSON.stringify(report,null,2));console.log(JSON.stringify(report));}
