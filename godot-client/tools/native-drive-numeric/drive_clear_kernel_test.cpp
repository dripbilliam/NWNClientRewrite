#include "drive_clear_kernel.hpp"
#include <iostream>
#include <limits>
#include <cstring>
#include <random>
using namespace drive_clear_kernel;
struct Math {
 V2 sub(const V2&a,const V2&b)const{return {a[0]-b[0],a[1]-b[1]};}
 V2 add(const V2&a,const V2&b)const{return {a[0]+b[0],a[1]+b[1]};}
 V2 mul(const V2&a,double n)const{return {a[0]*static_cast<float>(n),a[1]*static_cast<float>(n)};}
 double dot(const V2&a,const V2&b)const{return a[0]*b[0]+a[1]*b[1];}
 double length_squared(const V2&a)const{return dot(a,a);}
 double distance_squared(const V2&a,const V2&b)const{return length_squared(sub(a,b));}
};
size_t checks=0;
void check(bool value,const char* label){++checks;if(!value)throw std::runtime_error(label);}
bool same(V2 a,V2 b){return std::memcmp(a.data(),b.data(),sizeof(a))==0;}
// Deliberate direct transcription of the original scalar/vector script rather
// than using the candidate's internal helper functions as its own oracle.
double rcross(V2 a,V2 b){return static_cast<double>(a[0])*b[1]-static_cast<double>(a[1])*b[0];}
V2 span(V2 a,V2 b,const Face&tri){
 const Math m;const V2 points[3]={{tri.a[0],tri.a[1]},{tri.b[0],tri.b[1]},{tri.c[0],tri.c[1]}};
 const double area=rcross(m.sub(points[1],points[0]),m.sub(points[2],points[0]));if(std::abs(area)<0.0000001)return {1,-1};
 double l=0,h=1;const double sign=area>0?1.0:-1.0;
 for(int i=0;i<3;++i){const auto e=m.sub(points[(i+1)%3],points[i]);const auto start=sign*rcross(e,m.sub(a,points[i])),end=sign*rcross(e,m.sub(b,points[i])),d=end-start;
  if(std::abs(d)<0.0000001){if(start< -0.00001)return {1,-1};}else if(d>0){const double r=-start/d;l=l>r?l:r;}else{const double r=-start/d;h=h<r?h:r;}}
 return {static_cast<float>(l),static_cast<float>(h)};
}
double pd(V2 p,V2 a,V2 b){const Math m;const auto d=m.sub(b,a);const double len=m.length_squared(d);double t=0;if(len>0){t=m.dot(m.sub(p,a),d)/len;t=t<0?0:(t>1?1:t);}return m.distance_squared(p,m.add(a,m.mul(d,t)));}
double sd(V2 a,V2 b,V2 c,V2 d){const Math m;const double den=rcross(m.sub(b,a),m.sub(d,c));if(std::abs(den)>0.00000001){const double t=rcross(m.sub(c,a),m.sub(d,c))/den,u=rcross(m.sub(c,a),m.sub(b,a))/den;if(t>=0&&t<=1&&u>=0&&u<=1)return 0;}const double w=pd(a,c,d),x=pd(b,c,d),y=pd(c,a,b),z=pd(d,a,b);const double l=w<x?w:x,r=y<z?y:z;return l<r?l:r;}
bool rhit(V2 a,V2 b,const Face&f,double radius,double zlow,double zhigh){
 if(f.maximum[2]<zlow||f.minimum[2]>zhigh)return false;
 const double maxx=a[0]>b[0]?a[0]:b[0],minx=a[0]<b[0]?a[0]:b[0],maxy=a[1]>b[1]?a[1]:b[1],miny=a[1]<b[1]?a[1]:b[1];
 if(maxx+radius<f.minimum[0]||minx-radius>f.maximum[0]||maxy+radius<f.minimum[1]||miny-radius>f.maximum[1])return false;
 const auto s=span(a,b,f);if(s[0]<=s[1]&&s[1]>=0&&s[0]<=1)return true;const V2 p[3]={{f.a[0],f.a[1]},{f.b[0],f.b[1]},{f.c[0],f.c[1]}};for(int i=0;i<3;++i)if(sd(a,b,p[i],p[(i+1)%3])<radius*radius)return true;return false;
}
Face face(V3 a,V3 b,V3 c,bool walk){Face f;f.a=a;f.b=b;f.c=c;f.walk=walk;for(size_t i=0;i<3;++i){f.minimum[i]=std::min(a[i],std::min(b[i],c[i]));f.maximum[i]=std::max(a[i],std::max(b[i],c[i]));}return f;}
template<class F>void rejects(F fn,const char* label){bool caught=false;try{fn();}catch(const std::exception&){caught=true;}check(caught,label);}
int main(){try{
 const Math math;std::mt19937 rng(0x915b6cU);std::uniform_real_distribution<float> real(-40,40);
 for(int n=0;n<5000;++n){auto next=[&](){return real(rng);};auto f=face({next(),next(),next()},{next(),next(),next()},{next(),next(),next()},(n%2)==0);if(n%13==0)f=face(f.a,f.a,f.c,f.walk);if(n%19==0)f=face(f.a,f.b,f.b,f.walk);V2 a={next(),next()},b=n%17==0?a:V2{next(),next()};const double radius=(n%31)/16.0,zlow=-1.5,zhigh=2.7;
  check(same(Batch::interval(a,b,f,math),span(a,b,f)),"Exact span bits differ");check(Batch::hits(a,b,f,radius,zlow,zhigh,math)==rhit(a,b,f,radius,zlow,zhigh),"Triangle hit differs");
 }
 const auto floor=face({0,0,0},{10,0,0},{0,10,0},true);const auto wall=face({3,0,-1},{3,10,-1},{3,10,3},false);Batch batch;batch.configure({floor,wall},true,1024);auto result=batch.floor({1,1},{2,1},0.3,-0.1,2,math);check(!result.blocked&&result.intervals.size()==1,"Walk span retained in source order");result=batch.floor({1,1},{4,1},0.3,-0.1,2,math);check(result.blocked&&result.intervals.empty(),"First wall stops tile batch");
 batch.configure({wall},false,1024);check(batch.obstacle({1,1},{4,1},0.3,-0.1,2,math),"Object wall");check(!batch.obstacle({1,1},{4,1},0.3,100,102,math),"Vertical filter");rejects([&](){batch.floor({1,1},{4,1},0.3,-0.1,2,math);},"Mode mismatch fallback");
 rejects([&](){batch.configure({wall},false,1);},"Payload bound enforced");check(!batch.configured&&batch.faces.empty(),"Rejected replacement clears prior native geometry");
 auto broken=wall;broken.minimum[0]=100;rejects([&](){batch.configure({broken},false,1024);},"Malformed bounds");
 broken=wall;broken.a[0]=std::numeric_limits<float>::quiet_NaN();rejects([&](){batch.configure({broken},false,1024);},"NaN source rejected");
 batch.configure({wall},false,1024);rejects([&](){batch.obstacle({1,1},{4,1},-1,-0.1,2,math);},"Negative radius fallback");rejects([&](){batch.obstacle({1,1},{4,1},0.3,2,-0.1,math);},"Inverted Z fallback");rejects([&](){batch.obstacle({std::numeric_limits<float>::infinity(),1},{4,1},0.3,0,2,math);},"Infinite endpoint fallback");
 batch.clear();check(!batch.configured&&batch.faces.empty(),"Retirement clears all calculations");std::cout<<"{\"success\":true,\"checks\":"<<checks<<",\"scope\":\"Pure typed-loop oracle; actual engine callbacks tested separately\"}\n";return 0;
 }catch(const std::exception&e){std::cerr<<"Clear oracle failure after "<<checks<<": "<<e.what()<<'\n';return 1;}}
