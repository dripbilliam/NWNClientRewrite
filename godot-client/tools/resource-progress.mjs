// Only bounded download counters cross the native UI boundary. Repository
// URLs, cache paths, manifests and provider objects stay in the backend.
export function finiteResourceProgress(value){
 if(!value||!['server-manifest','server-content'].includes(value.phase)||!['completed','total','downloadedBytes'].every(k=>Number.isSafeInteger(value[k])&&value[k]>=0)||value.completed>value.total||value.total>1_000_000)return null;
 return{phase:value.phase,completed:value.completed,total:value.total,downloadedBytes:value.downloadedBytes};
}
export const canCancelResources=session=>Boolean(session&&!session.closed&&!session.characterSubmitted&&!session.characterUploaded&&['connecting','resources','resources-unavailable'].includes(session.phase));
