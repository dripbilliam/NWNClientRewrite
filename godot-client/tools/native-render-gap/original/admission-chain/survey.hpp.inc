 // Cold-only admission policy observation. Does not refresh Nodes, clocks,
 // controllers, wind services, simulation, geometry, radius/reject-plane caches.
 EngineVar admission_policy_survey()const{
  if(running)throw std::runtime_error("Cold admission survey requires a frame boundary");
  auto out=EngineVar::dictionary(),rows=::array_empty();
  int64_t examined=0,prepared_count=0,current_culled=0,native_current_rejects=0,scaled_rejects=0,conservative_rejects=0,extra_current=0,extra_scaled=0,negative_life=0,negative_radius=0,scale_expanded=0;
  for(const auto id:order){
   const auto& entry=*entries.at(id);auto row=EngineVar::dictionary();
   const auto integer=[&](const char* name,int64_t value){::set(row,name,EngineVar::integer(value));};
   const auto boolean=[&](const char* name,bool value){::set(row,name,EngineVar::boolean(value));};
   const auto number=[&](const char* name,float value){if(std::isfinite(value))::set(row,name,EngineVar::number(value));else ::set(row,name,EngineVar::text(std::isnan(value)?"NaN":value<0?"-Infinity":"Infinity"));};
   integer("id",id);boolean("enabled",entry.enabled);boolean("has_owner",entry.owner!=nullptr);
   if(!entry.owner){::method(rows,"append",{row});continue;}
   const auto& step=entry.step;const auto& owner=*entry.owner;const auto& emitter=owner.compact_state;
   ++examined;if(step.prepared)++prepared_count;if(step.culled)++current_culled;
   boolean("prepared",step.prepared);boolean("current_checked",step.checked);boolean("current_culled",step.culled);boolean("animation_invoked",step.animation_invoked);boolean("updated",step.updated);
   integer("pose_id",static_cast<int64_t>(owner.pose_id));integer("source_id",static_cast<int64_t>(owner.source_id));integer("source_flags",step.controls.source_flags);integer("emitter_flags",emitter.flags);integer("kind",owner.kind);integer("render_mode",emitter.renderMode1a8);
   integer("active",static_cast<int64_t>(owner.compact_pool.active.size()));integer("free",static_cast<int64_t>(owner.compact_pool.free.size()));integer("allocated",owner.allocations);boolean("chunk",emitter.chunk);
   number("birth_rate",emitter.birthRate);number("life_exp",emitter.lifeExp);number("velocity",emitter.velocity);number("random_velocity",emitter.randomVelocity);number("mass",emitter.mass);
   number("size_start",emitter.sizeStart);number("size_end",emitter.sizeEnd);number("size_start_y",emitter.sizeStartY);number("size_end_y",emitter.sizeEndY);number("x_size",emitter.xSize);number("y_size",emitter.ySize);
   number("last_radius",step.radius);number("pose_scale",step.pose.scale);number("pose_maximum_scale",step.pose.maximum_scale);number("source_scale",emitter.source.adjustedScale);::set(row,"pose_position",::array(step.pose.position));
   if(emitter.lifeExp<0)++negative_life;
   const auto* wind=((emitter.flags&4)&&step.controls.wind_token)?&scene_wind::owner(step.controls.wind_token):nullptr;
   const bool known_wind=!wind||wind->points.empty();boolean("known_wind",known_wind);
   // This recomputes the analytic sphere from CURRENT retained controller
   // fields. Original cached +0x20c, source prior-view and BSP placement may
   // differ, so it is explicitly a hypothetical policy comparison.
   int chunk_proof=emitter.chunk?1:0;
   if(emitter.chunk){for(auto* particle:owner.compact_pool.active){const auto found=owner.compact_extras.find(particle);if(found==owner.compact_extras.end()){chunk_proof=3;break;}if(!found->second.native_chunk){chunk_proof=4;break;}if(!found->second.child.nil()){chunk_proof=5;break;}chunk_proof=2;}}
   integer("current_chunk_proof",chunk_proof);
   const bool child_geometry_known=!emitter.chunk||chunk_proof==1||chunk_proof==2;
   const bool can_compare=step.prepared&&step.camera&&step.controls.source_flags>=0&&known_wind&&child_geometry_known;
   boolean("policy_comparable",can_compare);
   if(can_compare){
    resident::FieldKeyScope fields(owner.field_keys);
    const auto ambient=wind?wind->wind:V3{};const float analytic=owner.radius(step.controls.source_flags,ambient),scale=std::max(1.0f,step.pose.maximum_scale),scaled=analytic*scale;
    number("analytic_current_controller_radius",analytic);number("analytic_scaled_radius",scaled);::set(row,"ambient_wind",::array(ambient));
    if(analytic<0)++negative_radius;if(scale>1)++scale_expanded;
    const V3 point{step.pose.position[0],step.pose.position[2],-step.pose.position[1]};
    const auto rejected=[&](float radius){bool result=false;for(size_t n=0;n<6;++n){const size_t at=n*4;const auto& p=step.camera->planes;const float distance=((point[0]*p[at]-p[at+3])+point[1]*p[at+1])+point[2]*p[at+2];if(distance-radius>0){result=true;break;}}return result;};
    const bool native_reject=rejected(analytic),scaled_reject=rejected(scaled);float bound=0;const bool conservative_reject=owner.culled(*step.camera,step.pose.position,step.controls.source_flags,scale,bound,ambient);
    boolean("hypothetical_native_current_reject",native_reject);boolean("hypothetical_scaled_reject",scaled_reject);boolean("conservative_recomputed_reject",conservative_reject);number("conservative_recomputed_radius",bound);
    if(native_reject)++native_current_rejects;if(scaled_reject)++scaled_rejects;if(conservative_reject)++conservative_rejects;if(native_reject&&!conservative_reject)++extra_current;if(scaled_reject&&!conservative_reject)++extra_scaled;
    if(emitter.chunk)::set(row,"chunk_scope",EngineVar::text("Analytic policy only. A live child-Gob radius contribution is not reconstructed; check authoritative child metadata before using this comparison."));
   }
   ::method(rows,"append",{row});
  }
  ::set(out,"rows",rows);const auto integer=[&](const char* name,int64_t value){::set(out,name,EngineVar::integer(value));};
  integer("registered",static_cast<int64_t>(entries.size()));integer("examined",examined);integer("prepared",prepared_count);integer("current_culled",current_culled);integer("native_current_rejects",native_current_rejects);integer("scaled_rejects",scaled_rejects);integer("conservative_rejects",conservative_rejects);integer("extra_current_policy_admitted",extra_current);integer("extra_scaled_policy_admitted",extra_scaled);integer("negative_life",negative_life);integer("negative_analytic_radius",negative_radius);integer("scale_expanded",scale_expanded);
  ::set(out,"scope",EngineVar::text("Cold retained last-Step/current-state policy survey; no Node/controller/clock/simulation calls or cache writes. Last Step radius precedes its simulation; recomputed policies use the current post-simulation pool. Native-current comparisons are hypothetical: they do not reconstruct original cached +0x20c, prior model view/controller gates, live child-Gob spheres or BSP leaf traversal. Unknown/live-child chunk metadata is excluded from policy comparisons."));return out;
 }
