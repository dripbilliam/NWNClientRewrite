extends RefCounted
# Positively identified helper models. Identity includes original bytes;
# white pixels, table row numbers and resource-name patterns are not criteria.
const MODEL="pwc_block_01"
const SOURCE_SHA256="d82528dca8952e3a2190df956f7692ebac957f8914f56fd574916aaadab90089"
const IDENTIFIED_MODELS={
	MODEL:SOURCE_SHA256,
	"al_block_02":"e39bac1be65077a7702d2cec469884af5189159b047e655f3ad754875c2f606c",
	"al_block_03":"d8754a4b3b526237ab003f73e6e0c1c86fe7463c371722c337a5be4436276b0d",
	"al_block_04":"f35dc2f4eaef5359f3e166c9d164b4b68604af1184ac7372e8f2310874adff8d",
	"al_block_06":"a7da0a1080b205f78ae0a4938502b3af9654be6f2e5beffd2b2bc9d2d887f605",
	"al_block_07":"3b95a8a7c5a49fd7fe76d649b5862858c50d7a12a7a362ea967f9a5fbdd4ab4f"
}
static func identified(bundle: Dictionary) -> bool:
	var model:=str(bundle.get("resource_name",bundle.get("value",{}).get("name",""))).to_lower()
	return IDENTIFIED_MODELS.has(model) and str(bundle.get("sha256","")).to_lower()==IDENTIFIED_MODELS[model]
