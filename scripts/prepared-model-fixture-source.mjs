export function preparedModelFixtureSource(){
 const vertices=[[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]],faces=[[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[3,7,6],[3,6,2],[0,4,7],[0,7,3],[1,2,6],[1,6,5]];
 return new TextEncoder().encode(`#MAXMODEL ASCII\nnewmodel cachedfixture\nsetsupermodel cachedfixture null\nclassification tile\nbeginmodelgeom cachedfixture\nnode trimesh mesh\n parent NULL\n position 0 0 0\n orientation 0 0 1 0\n bitmap first\n bitmap second\n verts 8\n${vertices.map(v=>v.join(' ')).join('\n')}\n tverts 8\n${vertices.map(v=>[(v[0]+1)/2,(v[1]+1)/2,0].join(' ')).join('\n')}\n faces 12\n${faces.map((v,i)=>[...v,1,...v,i%2].join(' ')).join('\n')}\nendnode\nendmodelgeom cachedfixture\ndonemodel cachedfixture\n`);
}
