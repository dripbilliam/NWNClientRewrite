// The isolated resource-staging frontend still replicates the world, but its
// DOM lobby must never send competing previews/selections behind native UI.
export function isolateLobby(frontend){
 if(frontend.id)throw Error('Detach the legacy lobby before connecting');
 const lobby=frontend.lobby;if(!lobby)return false;
 lobby.close();lobby.reset();lobby.clearBaseAssets();lobby.root.remove();lobby.menuButton.remove();frontend.lobby=null;return true;
}
