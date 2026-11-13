// Authored private record schemas, not the proprietary original ABI.
// Resolve constant field names once into compact emitter/particle/pose slots.
constexpr size_t FIELD_COUNT=83;
constexpr uint64_t field_hash(const char* name){uint64_t hash=14695981039346656037ULL;while(*name){hash^=static_cast<uint8_t>(*name++);hash*=1099511628211ULL;}return hash;}
constexpr bool field_equal(const char* a,const char* b){while(*a&&*a==*b){++a;++b;}return *a==*b;}
constexpr int field_index(const char* name){switch(field_hash(name)){
 case 1703382833545304812ULL:return field_equal(name,"flags") ? 0 : -1; // flags
 case 6333895296410931593ULL:return field_equal(name,"chunkName") ? 1 : -1; // chunkName
 case 9413413830777659896ULL:return field_equal(name,"renderMode1a8") ? 2 : -1; // renderMode1a8
 case 10345882960104677773ULL:return field_equal(name,"blendMode68") ? 3 : -1; // blendMode68
 case 13097831443395057264ULL:return field_equal(name,"spawnType") ? 4 : -1; // spawnType
 case 14838486305852456427ULL:return field_equal(name,"loop") ? 5 : -1; // loop
 case 14943514207916079755ULL:return field_equal(name,"xGrid") ? 6 : -1; // xGrid
 case 9660049521884670740ULL:return field_equal(name,"yGrid") ? 7 : -1; // yGrid
 case 9044908970761240760ULL:return field_equal(name,"ageMode1cc") ? 8 : -1; // ageMode1cc
 case 13602634295325374865ULL:return field_equal(name,"accumulator198") ? 9 : -1; // accumulator198
 case 11421960627536128988ULL:return field_equal(name,"remaining164") ? 10 : -1; // remaining164
 case 2556635562604827672ULL:return field_equal(name,"detonate108") ? 11 : -1; // detonate108
 case 8108017570679017963ULL:return field_equal(name,"blastLatch1c8") ? 12 : -1; // blastLatch1c8
 case 6309036476857906615ULL:return field_equal(name,"elevationThreshold") ? 13 : -1; // elevationThreshold
 case 1160454645295528431ULL:return field_equal(name,"hit1f0") ? 14 : -1; // hit1f0
 case 15414843930336214642ULL:return field_equal(name,"twoSided") ? 15 : -1; // twoSided
 case 17337309468131702484ULL:return field_equal(name,"position1e0") ? 16 : -1; // position1e0
 case 11968470416919623008ULL:return field_equal(name,"quaternion1d0") ? 17 : -1; // quaternion1d0
 case 5220350889571025631ULL:return field_equal(name,"previous19c") ? 18 : -1; // previous19c
 case 6210474881772169180ULL:return field_equal(name,"previousQuaternion178") ? 19 : -1; // previousQuaternion178
 case 11144431935013624368ULL:return field_equal(name,"reference10c") ? 20 : -1; // reference10c
 case 7366830808324137072ULL:return field_equal(name,"referenceQuaternion118") ? 21 : -1; // referenceQuaternion118
 case 466070752045289136ULL:return field_equal(name,"basis140") ? 22 : -1; // basis140
 case 2173109042520705082ULL:return field_equal(name,"active188") ? 23 : -1; // active188
 case 8935962556139770085ULL:return field_equal(name,"free130") ? 24 : -1; // free130
 case 4193443296006200061ULL:return field_equal(name,"initialized208") ? 25 : -1; // initialized208
 case 2340538858396806597ULL:return field_equal(name,"source50") ? 26 : -1; // source50
 case 5389722048218423553ULL:return field_equal(name,"instance100") ? 27 : -1; // instance100
 case 5577956252630076450ULL:return field_equal(name,"enabled23c") ? 28 : -1; // enabled23c
 case 10275196238125585628ULL:return field_equal(name,"birthRate") ? 29 : -1; // birthRate
 case 13958056008981766390ULL:return field_equal(name,"lifeExp") ? 30 : -1; // lifeExp
 case 11263346319703191220ULL:return field_equal(name,"particleRot") ? 31 : -1; // particleRot
 case 12548674454127301348ULL:return field_equal(name,"blurLength") ? 32 : -1; // blurLength
 case 1671685757949751762ULL:return field_equal(name,"velocity") ? 33 : -1; // velocity
 case 12823091525524630889ULL:return field_equal(name,"randomVelocity") ? 34 : -1; // randomVelocity
 case 4134260821890764934ULL:return field_equal(name,"frameStart") ? 35 : -1; // frameStart
 case 12710757972204168131ULL:return field_equal(name,"frameEnd") ? 36 : -1; // frameEnd
 case 11582978583229437630ULL:return field_equal(name,"xSize") ? 37 : -1; // xSize
 case 8939466548580436909ULL:return field_equal(name,"ySize") ? 38 : -1; // ySize
 case 3384822429542269518ULL:return field_equal(name,"spread") ? 39 : -1; // spread
 case 2249362895655340721ULL:return field_equal(name,"mass") ? 40 : -1; // mass
 case 16650703037373682330ULL:return field_equal(name,"bounceCoefficient") ? 41 : -1; // bounceCoefficient
 case 6395723207181676592ULL:return field_equal(name,"sizeStart") ? 42 : -1; // sizeStart
 case 8328797202475071505ULL:return field_equal(name,"sizeEnd") ? 43 : -1; // sizeEnd
 case 11178442643113591403ULL:return field_equal(name,"sizeStartY") ? 44 : -1; // sizeStartY
 case 3661733909106827864ULL:return field_equal(name,"sizeEndY") ? 45 : -1; // sizeEndY
 case 11769205693254276105ULL:return field_equal(name,"alphaStart") ? 46 : -1; // alphaStart
 case 860436695813524984ULL:return field_equal(name,"alphaEnd") ? 47 : -1; // alphaEnd
 case 15890539075668851848ULL:return field_equal(name,"fps") ? 48 : -1; // fps
 case 7141355853087808259ULL:return field_equal(name,"deadspace") ? 49 : -1; // deadspace
 case 10789168880611334087ULL:return field_equal(name,"blastRadius") ? 50 : -1; // blastRadius
 case 4056113614567000385ULL:return field_equal(name,"blastLength") ? 51 : -1; // blastLength
 case 5800880813832995096ULL:return field_equal(name,"lightningDelay") ? 52 : -1; // lightningDelay
 case 9422704725721458771ULL:return field_equal(name,"lightningRadius") ? 53 : -1; // lightningRadius
 case 7350241706031192945ULL:return field_equal(name,"lightningScale") ? 54 : -1; // lightningScale
 case 7246233119888742116ULL:return field_equal(name,"colorStart") ? 55 : -1; // colorStart
 case 8902315192639283933ULL:return field_equal(name,"colorEnd") ? 56 : -1; // colorEnd
 case 5893819405027239235ULL:return field_equal(name,"position10") ? 57 : -1; // position10
 case 17555188242574048714ULL:return field_equal(name,"quaternion34") ? 58 : -1; // quaternion34
 case 11856104900981205774ULL:return field_equal(name,"inheritedSpeed20") ? 59 : -1; // inheritedSpeed20
 case 10976733417342337480ULL:return field_equal(name,"inheritedDirection24") ? 60 : -1; // inheritedDirection24
 case 4502964970067806075ULL:return field_equal(name,"direction4c") ? 61 : -1; // direction4c
 case 16441878800288363047ULL:return field_equal(name,"velocity58") ? 62 : -1; // velocity58
 case 15717380717020295905ULL:return field_equal(name,"trail64") ? 63 : -1; // trail64
 case 7034226765917764625ULL:return field_equal(name,"stopped70") ? 64 : -1; // stopped70
 case 1937504742354487947ULL:return field_equal(name,"rotation1c") ? 65 : -1; // rotation1c
 case 12157135644318584355ULL:return field_equal(name,"field48") ? 66 : -1; // field48
 case 16651413216827089244ULL:return field_equal(name,"age") ? 67 : -1; // age
 case 12904827556261408582ULL:return field_equal(name,"frame44") ? 68 : -1; // frame44
 case 5530202806555891530ULL:return field_equal(name,"position") ? 69 : -1; // position
 case 471364855340913645ULL:return field_equal(name,"quaternion") ? 70 : -1; // quaternion
 case 3865385212132933471ULL:return field_equal(name,"adjustedScale") ? 71 : -1; // adjustedScale
 case 2122458820793481989ULL:return field_equal(name,"opacity108") ? 72 : -1; // opacity108
 case 4704593978500022610ULL:return field_equal(name,"instance") ? 73 : -1; // instance
 case 11709876839689393901ULL:return field_equal(name,"records") ? 74 : -1; // records
 case 12802099281859290601ULL:return field_equal(name,"capacity") ? 75 : -1; // capacity
 case 6991063326977151602ULL:return field_equal(name,"normal") ? 76 : -1; // normal
 case 17232805691389541363ULL:return field_equal(name,"fade") ? 77 : -1; // fade
 case 3856963543781787103ULL:return field_equal(name,"height50") ? 78 : -1; // height50
 case 11392773958928481033ULL:return field_equal(name,"opacity70") ? 79 : -1; // opacity70
 case 4991654806971935910ULL:return field_equal(name,"factor") ? 80 : -1; // factor
 case 8056904078410733902ULL:return field_equal(name,"camera") ? 81 : -1; // camera
 case 2182421657251318348ULL:return field_equal(name,"tint") ? 82 : -1; // tint
 default:return -1;}}
struct RecordSchema {std::vector<const char*> names;std::array<int,FIELD_COUNT> offsets{};RecordSchema(std::initializer_list<const char*> fields):names(fields){offsets.fill(-1);for(size_t n=0;n<names.size();++n)offsets[static_cast<size_t>(field_index(names[n]))]=static_cast<int>(n);}};
inline const RecordSchema* primary_schema(int field){
 static const RecordSchema emitter{"flags","chunkName","renderMode1a8","blendMode68","spawnType","loop","xGrid","yGrid","ageMode1cc","accumulator198","remaining164","detonate108","blastLatch1c8","elevationThreshold","hit1f0","twoSided","position1e0","quaternion1d0","previous19c","previousQuaternion178","reference10c","referenceQuaternion118","basis140","active188","free130","initialized208","source50","instance100","enabled23c","birthRate","lifeExp","particleRot","blurLength","velocity","randomVelocity","frameStart","frameEnd","xSize","ySize","spread","mass","bounceCoefficient","sizeStart","sizeEnd","sizeStartY","sizeEndY","alphaStart","alphaEnd","fps","deadspace","blastRadius","blastLength","lightningDelay","lightningRadius","lightningScale","colorStart","colorEnd"};
 static const RecordSchema particle{"position10","quaternion34","inheritedSpeed20","inheritedDirection24","direction4c","velocity58","trail64","stopped70","rotation1c","field48","age","frame44"};
 static const RecordSchema pose{"position","quaternion","adjustedScale","opacity108","instance"};
 static const RecordSchema list{"records","capacity"};
 static const RecordSchema hit{"normal"};
 static const RecordSchema instance{"fade","height50","opacity70"};
 static const RecordSchema draw{"factor","camera","tint"};
 switch(field){
 case 0: case 1: case 2: case 3: case 4: case 5: case 6: case 7: case 8: case 9: case 10: case 11: case 12: case 13: case 14: case 15: case 16: case 17: case 18: case 19: case 20: case 21: case 22: case 23: case 24: case 25: case 26: case 27: case 28: case 29: case 30: case 31: case 32: case 33: case 34: case 35: case 36: case 37: case 38: case 39: case 40: case 41: case 42: case 43: case 44: case 45: case 46: case 47: case 48: case 49: case 50: case 51: case 52: case 53: case 54: case 55: case 56:return &emitter;
 case 57: case 58: case 59: case 60: case 61: case 62: case 63: case 64: case 65: case 66: case 67: case 68:return &particle;
 case 69: case 70: case 71: case 72: case 73:return &pose;
 case 74: case 75:return &list;
 case 76:return &hit;
 case 77: case 78: case 79:return &instance;
 case 80: case 81: case 82:return &draw;
 default:return nullptr;}}

// Tie every compiled slot to the checked runtime resolver.
static_assert(field_index(particle_field::flags.name)==particle_field::flags.index,"Particle field slot drift");
static_assert(field_index(particle_field::chunkName.name)==particle_field::chunkName.index,"Particle field slot drift");
static_assert(field_index(particle_field::renderMode1a8.name)==particle_field::renderMode1a8.index,"Particle field slot drift");
static_assert(field_index(particle_field::blendMode68.name)==particle_field::blendMode68.index,"Particle field slot drift");
static_assert(field_index(particle_field::spawnType.name)==particle_field::spawnType.index,"Particle field slot drift");
static_assert(field_index(particle_field::loop.name)==particle_field::loop.index,"Particle field slot drift");
static_assert(field_index(particle_field::xGrid.name)==particle_field::xGrid.index,"Particle field slot drift");
static_assert(field_index(particle_field::yGrid.name)==particle_field::yGrid.index,"Particle field slot drift");
static_assert(field_index(particle_field::ageMode1cc.name)==particle_field::ageMode1cc.index,"Particle field slot drift");
static_assert(field_index(particle_field::accumulator198.name)==particle_field::accumulator198.index,"Particle field slot drift");
static_assert(field_index(particle_field::remaining164.name)==particle_field::remaining164.index,"Particle field slot drift");
static_assert(field_index(particle_field::detonate108.name)==particle_field::detonate108.index,"Particle field slot drift");
static_assert(field_index(particle_field::blastLatch1c8.name)==particle_field::blastLatch1c8.index,"Particle field slot drift");
static_assert(field_index(particle_field::elevationThreshold.name)==particle_field::elevationThreshold.index,"Particle field slot drift");
static_assert(field_index(particle_field::hit1f0.name)==particle_field::hit1f0.index,"Particle field slot drift");
static_assert(field_index(particle_field::twoSided.name)==particle_field::twoSided.index,"Particle field slot drift");
static_assert(field_index(particle_field::position1e0.name)==particle_field::position1e0.index,"Particle field slot drift");
static_assert(field_index(particle_field::quaternion1d0.name)==particle_field::quaternion1d0.index,"Particle field slot drift");
static_assert(field_index(particle_field::previous19c.name)==particle_field::previous19c.index,"Particle field slot drift");
static_assert(field_index(particle_field::previousQuaternion178.name)==particle_field::previousQuaternion178.index,"Particle field slot drift");
static_assert(field_index(particle_field::reference10c.name)==particle_field::reference10c.index,"Particle field slot drift");
static_assert(field_index(particle_field::referenceQuaternion118.name)==particle_field::referenceQuaternion118.index,"Particle field slot drift");
static_assert(field_index(particle_field::basis140.name)==particle_field::basis140.index,"Particle field slot drift");
static_assert(field_index(particle_field::active188.name)==particle_field::active188.index,"Particle field slot drift");
static_assert(field_index(particle_field::free130.name)==particle_field::free130.index,"Particle field slot drift");
static_assert(field_index(particle_field::initialized208.name)==particle_field::initialized208.index,"Particle field slot drift");
static_assert(field_index(particle_field::source50.name)==particle_field::source50.index,"Particle field slot drift");
static_assert(field_index(particle_field::instance100.name)==particle_field::instance100.index,"Particle field slot drift");
static_assert(field_index(particle_field::enabled23c.name)==particle_field::enabled23c.index,"Particle field slot drift");
static_assert(field_index(particle_field::birthRate.name)==particle_field::birthRate.index,"Particle field slot drift");
static_assert(field_index(particle_field::lifeExp.name)==particle_field::lifeExp.index,"Particle field slot drift");
static_assert(field_index(particle_field::particleRot.name)==particle_field::particleRot.index,"Particle field slot drift");
static_assert(field_index(particle_field::blurLength.name)==particle_field::blurLength.index,"Particle field slot drift");
static_assert(field_index(particle_field::velocity.name)==particle_field::velocity.index,"Particle field slot drift");
static_assert(field_index(particle_field::randomVelocity.name)==particle_field::randomVelocity.index,"Particle field slot drift");
static_assert(field_index(particle_field::frameStart.name)==particle_field::frameStart.index,"Particle field slot drift");
static_assert(field_index(particle_field::frameEnd.name)==particle_field::frameEnd.index,"Particle field slot drift");
static_assert(field_index(particle_field::xSize.name)==particle_field::xSize.index,"Particle field slot drift");
static_assert(field_index(particle_field::ySize.name)==particle_field::ySize.index,"Particle field slot drift");
static_assert(field_index(particle_field::spread.name)==particle_field::spread.index,"Particle field slot drift");
static_assert(field_index(particle_field::mass.name)==particle_field::mass.index,"Particle field slot drift");
static_assert(field_index(particle_field::bounceCoefficient.name)==particle_field::bounceCoefficient.index,"Particle field slot drift");
static_assert(field_index(particle_field::sizeStart.name)==particle_field::sizeStart.index,"Particle field slot drift");
static_assert(field_index(particle_field::sizeEnd.name)==particle_field::sizeEnd.index,"Particle field slot drift");
static_assert(field_index(particle_field::sizeStartY.name)==particle_field::sizeStartY.index,"Particle field slot drift");
static_assert(field_index(particle_field::sizeEndY.name)==particle_field::sizeEndY.index,"Particle field slot drift");
static_assert(field_index(particle_field::alphaStart.name)==particle_field::alphaStart.index,"Particle field slot drift");
static_assert(field_index(particle_field::alphaEnd.name)==particle_field::alphaEnd.index,"Particle field slot drift");
static_assert(field_index(particle_field::fps.name)==particle_field::fps.index,"Particle field slot drift");
static_assert(field_index(particle_field::deadspace.name)==particle_field::deadspace.index,"Particle field slot drift");
static_assert(field_index(particle_field::blastRadius.name)==particle_field::blastRadius.index,"Particle field slot drift");
static_assert(field_index(particle_field::blastLength.name)==particle_field::blastLength.index,"Particle field slot drift");
static_assert(field_index(particle_field::lightningDelay.name)==particle_field::lightningDelay.index,"Particle field slot drift");
static_assert(field_index(particle_field::lightningRadius.name)==particle_field::lightningRadius.index,"Particle field slot drift");
static_assert(field_index(particle_field::lightningScale.name)==particle_field::lightningScale.index,"Particle field slot drift");
static_assert(field_index(particle_field::colorStart.name)==particle_field::colorStart.index,"Particle field slot drift");
static_assert(field_index(particle_field::colorEnd.name)==particle_field::colorEnd.index,"Particle field slot drift");
static_assert(field_index(particle_field::position10.name)==particle_field::position10.index,"Particle field slot drift");
static_assert(field_index(particle_field::quaternion34.name)==particle_field::quaternion34.index,"Particle field slot drift");
static_assert(field_index(particle_field::inheritedSpeed20.name)==particle_field::inheritedSpeed20.index,"Particle field slot drift");
static_assert(field_index(particle_field::inheritedDirection24.name)==particle_field::inheritedDirection24.index,"Particle field slot drift");
static_assert(field_index(particle_field::direction4c.name)==particle_field::direction4c.index,"Particle field slot drift");
static_assert(field_index(particle_field::velocity58.name)==particle_field::velocity58.index,"Particle field slot drift");
static_assert(field_index(particle_field::trail64.name)==particle_field::trail64.index,"Particle field slot drift");
static_assert(field_index(particle_field::stopped70.name)==particle_field::stopped70.index,"Particle field slot drift");
static_assert(field_index(particle_field::rotation1c.name)==particle_field::rotation1c.index,"Particle field slot drift");
static_assert(field_index(particle_field::field48.name)==particle_field::field48.index,"Particle field slot drift");
static_assert(field_index(particle_field::age.name)==particle_field::age.index,"Particle field slot drift");
static_assert(field_index(particle_field::frame44.name)==particle_field::frame44.index,"Particle field slot drift");
static_assert(field_index(particle_field::position.name)==particle_field::position.index,"Particle field slot drift");
static_assert(field_index(particle_field::quaternion.name)==particle_field::quaternion.index,"Particle field slot drift");
static_assert(field_index(particle_field::adjustedScale.name)==particle_field::adjustedScale.index,"Particle field slot drift");
static_assert(field_index(particle_field::opacity108.name)==particle_field::opacity108.index,"Particle field slot drift");
static_assert(field_index(particle_field::instance.name)==particle_field::instance.index,"Particle field slot drift");
static_assert(field_index(particle_field::records.name)==particle_field::records.index,"Particle field slot drift");
static_assert(field_index(particle_field::capacity.name)==particle_field::capacity.index,"Particle field slot drift");
static_assert(field_index(particle_field::normal.name)==particle_field::normal.index,"Particle field slot drift");
static_assert(field_index(particle_field::fade.name)==particle_field::fade.index,"Particle field slot drift");
static_assert(field_index(particle_field::height50.name)==particle_field::height50.index,"Particle field slot drift");
static_assert(field_index(particle_field::opacity70.name)==particle_field::opacity70.index,"Particle field slot drift");
static_assert(field_index(particle_field::factor.name)==particle_field::factor.index,"Particle field slot drift");
static_assert(field_index(particle_field::camera.name)==particle_field::camera.index,"Particle field slot drift");
static_assert(field_index(particle_field::tint.name)==particle_field::tint.index,"Particle field slot drift");
