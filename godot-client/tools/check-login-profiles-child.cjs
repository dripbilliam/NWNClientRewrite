const {createSettingsClient}=require('./settings-client.cjs');
const key=Array(7).fill('AAAAA').join('-'),alt=key.replaceAll('A','B');
(async()=>{const client=createSettingsClient();try{
 let status=await client.saveProfile({label:'Fixture Main',playerName:'Main Test Player',cdKey:key});const main=status.activeProfileId;
 status=await client.saveProfile({label:'Fixture Alt',playerName:'Alt Test Player',cdKey:alt});
 if(await client.cdKey()!==alt)throw Error();await client.selectProfile(main);if(await client.cdKey()!==key)throw Error();
 status=await client.status();if(JSON.stringify(status).includes(key)||JSON.stringify(status).includes(alt)||JSON.stringify(status).includes('protectedCdKey'))throw Error();
 process.send({kind:'login-profile-check',success:true,profileCount:status.loginProfiles.length});
 }finally{client.close();process.disconnect();}})().catch(()=>{if(process.connected)process.send({kind:'login-profile-check',success:false});process.exitCode=1;});
