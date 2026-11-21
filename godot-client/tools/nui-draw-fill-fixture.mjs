import {nuiFixture} from './nui-fixture.mjs';

// Authored JSON values, not captured server layouts or proprietary resources.
export const fillCases = [
 {name:'missing',expected:false},
 {name:'null',value:null,expected:false},
 {name:'false',value:false,expected:false},
 {name:'true',value:true,expected:true},
 {name:'zero',value:0,expected:false},
 {name:'negative',value:-2,expected:true},
 {name:'fraction',value:0.5,expected:true},
 {name:'empty string',value:'',expected:false},
 {name:'nonempty string',value:'false',expected:true},
 {name:'empty array',value:[],expected:true},
 {name:'empty object',value:{},expected:true},
 {name:'nonempty object',value:{enabled:false},expected:true},
];
export async function drawFillFixture(){
 const commands=fillCases.map((row,i)=>({type:7,rect:{x:10+i*48,y:10,w:36,h:36},color:{r:255,g:0,b:0,a:255},line_thickness:2,...('value'in row?{fill:row.value}:{})}));
 // All primitive paths include nullable/mistyped optional numeric values, like
 // those that previously passed straight into GDScript constructors.
 for(let type=0;type<8;type++)commands.push({type,fill:false,line_thickness:null,order:null,render:null,image_aspect:null,color:{r:0,g:255,b:0,a:255},rect:{x:10+type*70,y:70,w:40,h:30},a:{x:10+type*70,y:100},b:{x:50+type*70,y:'110'},c:{x:30+type*70,y:100},ctrl0:{x:20+type*70,y:null},ctrl1:{x:40+type*70,y:110},radius:'12',amin:null,amax:3.14,points:[10,110,30,null,50,110],text:'Draw',font:null});
 const layout={title:'',closable:false,collapsed:false,border:false,resizable:false,transparent:true,geometry:{x:20,y:20,w:620,h:180},root:{type:'spacer',id:'drawing',draw_list:commands}};
 const fixture=nuiFixture({layout,count:0});
 try{
  await fixture.service.sync();
  return{scope:'Authored NUI draw-fill conversion and actual native canvas drawing; no public connection',cases:fillCases,raw:commands,messages:fixture.sent.filter(row=>['nui-frame','nui-nodes','nui-commit'].includes(row.kind))};
 }finally{await fixture.service.retire();}
}
