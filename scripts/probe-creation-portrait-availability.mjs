// Catalog availability only; no downloads, portrait bytes or game assets saved.
import fs from 'node:fs/promises';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
const [install,downloadFile,advertisementFile,userDirectory,output]=process.argv.slice(2),download=JSON.parse(await fs.readFile(downloadFile,'utf8')),ad=JSON.parse(await fs.readFile(advertisementFile,'utf8')),report={scope:'Offline catalog audit of every selectable server portrait row, plus current user portrait names',httpAttempts:0};
const resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,userDirectory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline portrait audit may not fetch');}}});
try{
 const resolved=await resolveServerResources(ad.requirements,{...resources,language:0}),resolver=await resources.openModule(null,resolved.resolved),table=parse2da(decodeResourceText(await resolver.getResource('portraits',2017))),names=new Set([...resolver.resourceNames(3),...resolver.resourceNames(2033)]),suffixes=['m','l','s','h','t',''];
 const rows=table.orderedRows.map((row,id)=>({row,id})).filter(({row:r})=>r.BaseResRef&&r.BaseResRef!=='****'&&Number(r.Plot)===0&&[0,1].includes(Number(r.Sex)));
 report.rows=rows.map(({row,id})=>{const ref=row.BaseResRef.toLowerCase(),canonical='po_'+ref;return{id,base:row.BaseResRef,canonicalMatches:suffixes.map(s=>canonical+s).filter(n=>names.has(n)),unprefixedMatches:suffixes.map(s=>ref+s).filter(n=>names.has(n)),related:[...names].filter(n=>n.includes(ref)).slice(0,10)};});
 report.selectableRows=report.rows.length;report.canonicalAvailable=report.rows.filter(r=>r.canonicalMatches.length).length;report.unprefixedOnly=report.rows.filter(r=>!r.canonicalMatches.length&&r.unprefixedMatches.length);report.absent=report.rows.filter(r=>!r.canonicalMatches.length&&!r.unprefixedMatches.length);report.customImages=resolver.portraitNames().length;report.success=true;
}catch(error){report.failure=error.stack;process.exitCode=1;}finally{resources.close();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,httpAttempts:report.httpAttempts,selectableRows:report.selectableRows,canonicalAvailable:report.canonicalAvailable,unprefixedOnly:report.unprefixedOnly?.length,absent:report.absent?.length,customImages:report.customImages,failure:report.failure}));}
