// Exit zero alone is insufficient: the native client must retire the world
// and its UI before the engine/window disappear, on the current connection.
function nativeShutdownComplete(report){
 const shutdown=report.nativeShutdown,seen=shutdown?.observed;
 return Boolean(report.nativeExit===0&&report.disconnected===true&&shutdown?.forced===false&&Number.isSafeInteger(shutdown.connection)&&shutdown.connection>=0&&seen?.kind==='shutdown-observed'&&seen.connection===shutdown.connection&&Number.isSafeInteger(seen.frames)&&seen.frames>=2&&seen.frames<=60&&Number.isSafeInteger(seen.retiredWorldOwners)&&seen.retiredWorldOwners>=0&&seen.worldSurvivors===0&&(seen.audioSurvivors===undefined||seen.audioSurvivors===0)&&seen.nui?.windows===0&&seen.nui?.resources===0&&seen.partySurvivors===0&&seen.buffSurvivors===0);
}
module.exports={nativeShutdownComplete};
