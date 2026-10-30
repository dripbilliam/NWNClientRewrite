// Authored private record schemas, not the proprietary original ABI.
// Resolve constant field names once into compact emitter/particle/pose slots.
constexpr size_t FIELD_COUNT=83;
constexpr uint64_t field_hash(const char* name){uint64_t hash=14695981039346656037ULL;while(*name){hash^=static_cast<uint8_t>(*name++);hash*=1099511628211ULL;}return hash;}
inline int field_index(const char* name){switch(field_hash(name)){
 case 1703382833545304812ULL:return std::strcmp(name,"flags") == 0 ? 0 : -1; // flags
 case 6333895296410931593ULL:return std::strcmp(name,"chunkName") == 0 ? 1 : -1; // chunkName
 case 9413413830777659896ULL:return std::strcmp(name,"renderMode1a8") == 0 ? 2 : -1; // renderMode1a8
 case 10345882960104677773ULL:return std::strcmp(name,"blendMode68") == 0 ? 3 : -1; // blendMode68
 case 13097831443395057264ULL:return std::strcmp(name,"spawnType") == 0 ? 4 : -1; // spawnType
 case 14838486305852456427ULL:return std::strcmp(name,"loop") == 0 ? 5 : -1; // loop
 case 14943514207916079755ULL:return std::strcmp(name,"xGrid") == 0 ? 6 : -1; // xGrid
 case 9660049521884670740ULL:return std::strcmp(name,"yGrid") == 0 ? 7 : -1; // yGrid
 case 9044908970761240760ULL:return std::strcmp(name,"ageMode1cc") == 0 ? 8 : -1; // ageMode1cc
 case 13602634295325374865ULL:return std::strcmp(name,"accumulator198") == 0 ? 9 : -1; // accumulator198
 case 11421960627536128988ULL:return std::strcmp(name,"remaining164") == 0 ? 10 : -1; // remaining164
 case 2556635562604827672ULL:return std::strcmp(name,"detonate108") == 0 ? 11 : -1; // detonate108
 case 8108017570679017963ULL:return std::strcmp(name,"blastLatch1c8") == 0 ? 12 : -1; // blastLatch1c8
 case 6309036476857906615ULL:return std::strcmp(name,"elevationThreshold") == 0 ? 13 : -1; // elevationThreshold
 case 1160454645295528431ULL:return std::strcmp(name,"hit1f0") == 0 ? 14 : -1; // hit1f0
 case 15414843930336214642ULL:return std::strcmp(name,"twoSided") == 0 ? 15 : -1; // twoSided
 case 17337309468131702484ULL:return std::strcmp(name,"position1e0") == 0 ? 16 : -1; // position1e0
 case 11968470416919623008ULL:return std::strcmp(name,"quaternion1d0") == 0 ? 17 : -1; // quaternion1d0
 case 5220350889571025631ULL:return std::strcmp(name,"previous19c") == 0 ? 18 : -1; // previous19c
 case 6210474881772169180ULL:return std::strcmp(name,"previousQuaternion178") == 0 ? 19 : -1; // previousQuaternion178
 case 11144431935013624368ULL:return std::strcmp(name,"reference10c") == 0 ? 20 : -1; // reference10c
 case 7366830808324137072ULL:return std::strcmp(name,"referenceQuaternion118") == 0 ? 21 : -1; // referenceQuaternion118
 case 466070752045289136ULL:return std::strcmp(name,"basis140") == 0 ? 22 : -1; // basis140
 case 2173109042520705082ULL:return std::strcmp(name,"active188") == 0 ? 23 : -1; // active188
 case 8935962556139770085ULL:return std::strcmp(name,"free130") == 0 ? 24 : -1; // free130
 case 4193443296006200061ULL:return std::strcmp(name,"initialized208") == 0 ? 25 : -1; // initialized208
 case 2340538858396806597ULL:return std::strcmp(name,"source50") == 0 ? 26 : -1; // source50
 case 5389722048218423553ULL:return std::strcmp(name,"instance100") == 0 ? 27 : -1; // instance100
 case 5577956252630076450ULL:return std::strcmp(name,"enabled23c") == 0 ? 28 : -1; // enabled23c
 case 10275196238125585628ULL:return std::strcmp(name,"birthRate") == 0 ? 29 : -1; // birthRate
 case 13958056008981766390ULL:return std::strcmp(name,"lifeExp") == 0 ? 30 : -1; // lifeExp
 case 11263346319703191220ULL:return std::strcmp(name,"particleRot") == 0 ? 31 : -1; // particleRot
 case 12548674454127301348ULL:return std::strcmp(name,"blurLength") == 0 ? 32 : -1; // blurLength
 case 1671685757949751762ULL:return std::strcmp(name,"velocity") == 0 ? 33 : -1; // velocity
 case 12823091525524630889ULL:return std::strcmp(name,"randomVelocity") == 0 ? 34 : -1; // randomVelocity
 case 4134260821890764934ULL:return std::strcmp(name,"frameStart") == 0 ? 35 : -1; // frameStart
 case 12710757972204168131ULL:return std::strcmp(name,"frameEnd") == 0 ? 36 : -1; // frameEnd
 case 11582978583229437630ULL:return std::strcmp(name,"xSize") == 0 ? 37 : -1; // xSize
 case 8939466548580436909ULL:return std::strcmp(name,"ySize") == 0 ? 38 : -1; // ySize
 case 3384822429542269518ULL:return std::strcmp(name,"spread") == 0 ? 39 : -1; // spread
 case 2249362895655340721ULL:return std::strcmp(name,"mass") == 0 ? 40 : -1; // mass
 case 16650703037373682330ULL:return std::strcmp(name,"bounceCoefficient") == 0 ? 41 : -1; // bounceCoefficient
 case 6395723207181676592ULL:return std::strcmp(name,"sizeStart") == 0 ? 42 : -1; // sizeStart
 case 8328797202475071505ULL:return std::strcmp(name,"sizeEnd") == 0 ? 43 : -1; // sizeEnd
 case 11178442643113591403ULL:return std::strcmp(name,"sizeStartY") == 0 ? 44 : -1; // sizeStartY
 case 3661733909106827864ULL:return std::strcmp(name,"sizeEndY") == 0 ? 45 : -1; // sizeEndY
 case 11769205693254276105ULL:return std::strcmp(name,"alphaStart") == 0 ? 46 : -1; // alphaStart
 case 860436695813524984ULL:return std::strcmp(name,"alphaEnd") == 0 ? 47 : -1; // alphaEnd
 case 15890539075668851848ULL:return std::strcmp(name,"fps") == 0 ? 48 : -1; // fps
 case 7141355853087808259ULL:return std::strcmp(name,"deadspace") == 0 ? 49 : -1; // deadspace
 case 10789168880611334087ULL:return std::strcmp(name,"blastRadius") == 0 ? 50 : -1; // blastRadius
 case 4056113614567000385ULL:return std::strcmp(name,"blastLength") == 0 ? 51 : -1; // blastLength
 case 5800880813832995096ULL:return std::strcmp(name,"lightningDelay") == 0 ? 52 : -1; // lightningDelay
 case 9422704725721458771ULL:return std::strcmp(name,"lightningRadius") == 0 ? 53 : -1; // lightningRadius
 case 7350241706031192945ULL:return std::strcmp(name,"lightningScale") == 0 ? 54 : -1; // lightningScale
 case 7246233119888742116ULL:return std::strcmp(name,"colorStart") == 0 ? 55 : -1; // colorStart
 case 8902315192639283933ULL:return std::strcmp(name,"colorEnd") == 0 ? 56 : -1; // colorEnd
 case 5893819405027239235ULL:return std::strcmp(name,"position10") == 0 ? 57 : -1; // position10
 case 17555188242574048714ULL:return std::strcmp(name,"quaternion34") == 0 ? 58 : -1; // quaternion34
 case 11856104900981205774ULL:return std::strcmp(name,"inheritedSpeed20") == 0 ? 59 : -1; // inheritedSpeed20
 case 10976733417342337480ULL:return std::strcmp(name,"inheritedDirection24") == 0 ? 60 : -1; // inheritedDirection24
 case 4502964970067806075ULL:return std::strcmp(name,"direction4c") == 0 ? 61 : -1; // direction4c
 case 16441878800288363047ULL:return std::strcmp(name,"velocity58") == 0 ? 62 : -1; // velocity58
 case 15717380717020295905ULL:return std::strcmp(name,"trail64") == 0 ? 63 : -1; // trail64
 case 7034226765917764625ULL:return std::strcmp(name,"stopped70") == 0 ? 64 : -1; // stopped70
 case 1937504742354487947ULL:return std::strcmp(name,"rotation1c") == 0 ? 65 : -1; // rotation1c
 case 12157135644318584355ULL:return std::strcmp(name,"field48") == 0 ? 66 : -1; // field48
 case 16651413216827089244ULL:return std::strcmp(name,"age") == 0 ? 67 : -1; // age
 case 12904827556261408582ULL:return std::strcmp(name,"frame44") == 0 ? 68 : -1; // frame44
 case 5530202806555891530ULL:return std::strcmp(name,"position") == 0 ? 69 : -1; // position
 case 471364855340913645ULL:return std::strcmp(name,"quaternion") == 0 ? 70 : -1; // quaternion
 case 3865385212132933471ULL:return std::strcmp(name,"adjustedScale") == 0 ? 71 : -1; // adjustedScale
 case 2122458820793481989ULL:return std::strcmp(name,"opacity108") == 0 ? 72 : -1; // opacity108
 case 4704593978500022610ULL:return std::strcmp(name,"instance") == 0 ? 73 : -1; // instance
 case 11709876839689393901ULL:return std::strcmp(name,"records") == 0 ? 74 : -1; // records
 case 12802099281859290601ULL:return std::strcmp(name,"capacity") == 0 ? 75 : -1; // capacity
 case 6991063326977151602ULL:return std::strcmp(name,"normal") == 0 ? 76 : -1; // normal
 case 17232805691389541363ULL:return std::strcmp(name,"fade") == 0 ? 77 : -1; // fade
 case 3856963543781787103ULL:return std::strcmp(name,"height50") == 0 ? 78 : -1; // height50
 case 11392773958928481033ULL:return std::strcmp(name,"opacity70") == 0 ? 79 : -1; // opacity70
 case 4991654806971935910ULL:return std::strcmp(name,"factor") == 0 ? 80 : -1; // factor
 case 8056904078410733902ULL:return std::strcmp(name,"camera") == 0 ? 81 : -1; // camera
 case 2182421657251318348ULL:return std::strcmp(name,"tint") == 0 ? 82 : -1; // tint
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
