extends RefCounted
# Original CWorldTimer::TranslateWorldTimeToString597a70; labels are active TLK.
static func parts(date: int,time: int,minutes_per_hour: int) -> Dictionary:
	var length:=minutes_per_hour&255
	if length==0: return {"error":"Journal world timer has no valid hour length"}
	var day:=date&0xffffffff; var ticks:=time&0xffffffff; var month:=int(day/28); var year:=int(month/12); var minutes:=int(ticks/60000)
	return {"error":"","day":day%28+1,"month":month%12+1,"year":1340 if year>32767 else year,"hour":int(minutes/length),"minute":minutes%length}
static func format(date: int,time: int,minutes_per_hour: int,day_label: String,month_label: String) -> String:
	var value:=parts(date,time,minutes_per_hour)
	if not str(value.error).is_empty(): return ""
	return "%s %02d, %s %02d, %04d  [%02d:%02d]"%[day_label,value.day,month_label,value.month,value.year,value.hour,value.minute]
