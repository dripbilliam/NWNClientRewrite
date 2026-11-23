namespace cx_particle {
struct Random {
 uint32_t state=0;
 uint64_t draws=0;

 static constexpr uint32_t mix(uint32_t x){
  x^=x<<13;
  x^=x>>17;
  x^=x<<5;
  return x?x:0x01234567u;
 }
 void seed(uint64_t emitter){
  // The client's scene identity supplies the part index and its generation.
  state=mix(static_cast<uint32_t>(emitter)*0x9e3779b9u+static_cast<uint32_t>(emitter>>32)+1u);
  draws=0;
 }
 uint32_t next(){
  state=mix(state);
  ++draws;
  return state;
 }
};
} // namespace cx_particle
