import fs from 'node:fs/promises';
import path from 'node:path';
import {readPrivateProbeInput} from './read-private-probe-input.mjs';
import {NetworkLoginIdentity} from '../electron/network_login_identity.mjs';
import {openServerResourceContext} from '../electron/server_resource_context.mjs';
import {loadCreationRules,initialCreationDraft,recommendCreation,createCharacterBic,creationErrors} from '../src/character_creation.js';
const request=await readPrivateProbeInput(),identity=new NetworkLoginIdentity(request.credentials);for(const name of Object.keys(request.credentials))request.credentials[name]='';delete request.credentials;
try{
 const directory=path.resolve(request.options.directory),workspace=path.resolve('.');if(directory.startsWith(workspace+path.sep))throw new Error('Fixture character files must stay outside the workspace');await fs.mkdir(directory,{recursive:false});const account=path.join(directory,'servervault',identity.publicKey.toLowerCase());await fs.mkdir(account,{recursive:true});
 const resolver=await openServerResourceContext({install:request.options.install}),rules=await loadCreationRules(resolver),draft=initialCreationDraft(rules);Object.assign(draft,{classId:10,raceId:6,gender:0,packageId:Number(rules.classes.orderedRows[10].Package),firstName:'Vault',lastName:'Fixture'});await recommendCreation(draft,rules);if(creationErrors(draft,rules).length)throw new Error('Fixture wizard creation failed validation');const bytes=await createCharacterBic(draft,rules);await fs.writeFile(path.join(account,'vaultfixture.bic'),bytes);await fs.writeFile(path.join(directory,'servervault','presetfixture.bic'),bytes);
 await fs.writeFile(path.join(directory,'settings.tml'),'[server]\nname = "Server Vault Compatibility Fixture"\npublic = false\n[server.net]\naccept-relayed-connections = false\n[server.login.player-dm]\nenabled = false\n');
 const report={directory,port:5124,module:'Prelude',seededCharacters:2,createdByReplacementWizard:true,level:1,characterName:'Vault Fixture',scope:'Separate external profile; original server and client untouched'};await fs.writeFile(request.options.output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
}finally{identity.dispose();}
