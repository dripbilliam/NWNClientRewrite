const f=Math.fround;
const scalar=(v,n)=>{if(!Number.isFinite(v))throw new Error(`Native tile subdivision ${n} is unavailable`);return f(v);};
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native tile subdivision ${n} is unavailable`);return v|0;};
const cache=new WeakMap();
// RunSubdivision1402c4600. Preserve physical face order, three new vertices
// PER FACE (no deduplication), child0/1/centre2/3 order and native neighbour
// fallback. The same owner runs twice to construct the encoded hierarchy.
export function runTileSubdivision(mesh){
  if(!Array.isArray(mesh.vertices)||!Array.isArray(mesh.faces)||!Array.isArray(mesh.adjacency)||mesh.faces.length!==mesh.adjacency.length)
    throw new Error('Native tile subdivision mesh storage is unavailable');
  const vertices=mesh.vertices.map(v=>{if(v.length!==3)throw new Error('Native subdivision vertex is unavailable');return v.map((x,i)=>scalar(x,`vertex axis${i}`));}),faces=[],adjacency=[];
  for(let face=0;face<mesh.faces.length;face++){
    const indices=mesh.faces[face];if(indices.length!==3||indices.some(v=>!Number.isInteger(v)||v<0||v>=mesh.vertices.length))throw new Error('Native subdivision triangle is unavailable');
    const [a,b,c]=indices,first=vertices.length;
    for(const [x,y] of [[a,b],[a,c],[b,c]])vertices.push(vertices[x].map((v,i)=>f(f(vertices[y][i]+v)*f(.5))));
    faces.push([a,first,first+1],[first,b,first+2],[first+1,first,first+2],[first+1,first+2,c]);
    const base=face*4,rows=[[0,base+2,0],[0,0,base+2],[base,base+1,base+3],[base+2,0,0]];
    for(let edge=0;edge<3;edge++){
      const neighbour=integer(mesh.adjacency[face][edge],'adjacent triangle');let near=neighbour,far=neighbour;
      if(neighbour>=0){
        const other=mesh.adjacency[neighbour];if(!other)throw new Error('Native subdivision adjacent storage is unavailable');const n=neighbour*4;
        if(other[0]===face){near=n+1;far=n;}else if(other[1]===face){near=n+3;far=n+1;}else{near=n;far=n+3;}
      }
      if(edge===0){rows[0][0]=near;rows[1][0]=far;}
      else if(edge===1){rows[1][1]=near;rows[3][1]=far;}
      else{rows[3][2]=near;rows[0][2]=far;}
    }
    adjacency.push(...rows);
  }
  return{vertices,faces,adjacency};
}
export function tileSubdivision(mesh){
  if(!cache.has(mesh)){const middle=runTileSubdivision(mesh),deep=runTileSubdivision(middle);cache.set(mesh,[mesh,middle,deep]);}
  return cache.get(mesh);
}
function levelMesh(mesh,level){
  level=integer(level,'level');if(level<1)return mesh;
  const levels=cache.get(mesh);if(!levels)throw new Error('Native subdivided tile storage is unavailable');return levels[level===1?1:2];
}
export function subdivisionTriangleVertices(mesh,level,index){
  const selected=levelMesh(mesh,level);index=integer(index,'triangle index');
  if(index<0||index>=selected.faces.length)throw new Error('Native subdivision triangle output is unavailable');return selected.faces[index].slice();
}
export function subdivisionTriangleAdjacency(mesh,level,index){
  const selected=levelMesh(mesh,level);index=integer(index,'triangle index');
  if(index<0||index>=selected.faces.length)throw new Error('Native subdivision adjacency output is unavailable');return selected.adjacency[index].slice();
}
const half=(a,b,point)=>f(f(f(b[0]-a[0])*f(point[1]-a[1]))+f(f(a[1]-b[1])*f(point[0]-a[0])));
// FindTriangle1402bd610. Without a seed scan physical triangles. With a
// coarser seed, test centre child2 first and select a corner from its planes.
// Boundary ties differ from an unseeded scan; retain that encoded result.
export function findSubdivisionTriangle(mesh,level,remaining,point,seed=-1){
  level=integer(level,'search level');remaining=integer(remaining,'remaining levels');seed=integer(seed,'seed');point=point.map((v,i)=>scalar(v,`query axis${i}`));
  if(level<0||level>2||remaining<0||level+remaining>2)throw new Error('Native subdivision search level is unavailable');
  for(;;level++,remaining--){
    const selected=levelMesh(mesh,level);
    if(seed===-1){
      seed=selected.faces.findIndex(indices=>{const v=indices.map(n=>selected.vertices[n]);return v.every((a,e)=>half(a,v[(e+1)%3],point)>=0);});
      if(seed===-1)return -1;
    }else{
      const base=(seed*4)|0,indices=selected.faces[base+2];if(!indices)throw new Error('Native subdivision seeded triangle is unavailable');
      const [a,b,c]=indices.map(n=>selected.vertices[n]);seed=base;
      if(half(a,b,point)>=0){seed=half(b,c,point)>=0?(half(c,a,point)<0?base+3:base+2):base+1;}
    }
    if(remaining===0)return seed;
  }
}
