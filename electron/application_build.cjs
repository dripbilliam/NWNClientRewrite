const fs=require('node:fs'),path=require('node:path');
const {pathToFileURL}=require('node:url');
function resolveApplicationBuild(root,args=process.argv){
 const choices=args.filter(arg=>arg.startsWith('--client-build='));
 if(choices.length>1)throw Error('Select one client build');
 let directory=path.resolve(root,'dist');
 if(choices.length){
  directory=path.resolve(root,choices[0].slice('--client-build='.length));
  const allowed=fs.realpathSync(path.join(root,'backups/animations/performance-queue'));
  const real=fs.realpathSync(directory),relative=path.relative(allowed,real);
  if(!relative||relative.startsWith('..')||path.isAbsolute(relative)||!['preview-build','diagnostic-build'].includes(path.basename(real)))throw Error('Client test build must be an owned performance artifact');
  directory=real;
 }
 const index=path.join(directory,'index.html');
 if(choices.length&&!fs.statSync(index).isFile())throw Error('Client build has no entry document');
 return {directory,index,applicationUrl:pathToFileURL(index).href,experimental:Boolean(choices.length)};
}
module.exports={resolveApplicationBuild};
