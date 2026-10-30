// Original server-page priorities/direction state:8c3990,8c2460,8d1eb0.
export function originalBrowserSort(tab){return{order:tab==='Internet'?[2,0,1,3,4,5]:[0,1,2,3,4,5],ascending:tab==='Internet'?[true,true,false,true,true,true]:[true,true,true,true,true,true],header:2};}
export function selectBrowserColumn(state,column){
 const next={order:[...state.order],ascending:[...state.ascending],header:column};
 if(next.order[0]===column)next.ascending[column]=!next.ascending[column];else next.order=[column,...next.order.filter(v=>v!==column)];return next;
}
const ascii=s=>String(s??'').replace(/[A-Z]/g,c=>c.toLowerCase());
const values=row=>[ascii(row.serverName),ascii(row.moduleName),(row.playerCount??0)*256+(row.maximumPlayers??0),(row.minimumLevel??0)*100+(row.maximumLevel??0),ascii(row.pvpSetting??''),row.syncAvailable===true?'ok':row.syncAvailable===false?'need':''];
export function compareBrowserRows(a,b,state){
 const av=values(a),bv=values(b);
 for(const column of state.order){const x=av[column],y=bv[column],order=x<y?-1:x>y?1:0;if(order)return state.ascending[column]?order:-order;}
 return 0;
}
// CGuiListBox::HandleKeyEvent1e9790; native row-selection policy only.
export function stepBrowserSelection(index,count,direction){
 if(![-1,1].includes(direction)||!Number.isInteger(index)||!Number.isInteger(count)||count<0)throw Error('Invalid server selection direction');
 const next=index+direction;return next>=0&&next<count?next:index;
}
