extends RefCounted
## Web writes synchronously; native replaces a flushed temporary file.
## The previous validated save is retained as a recovery copy.
const SCHEMA_VERSION := 1
const FILE_PATH := "user://taixu_local_save.json"
const STORAGE_KEY := "taixu.save.v1"
const MAX_BYTES := 524288
var path: String
var storage_key: String
var status := "ready"
var _last_good := ""
var _future_schema := false

func _init(file_path: String=FILE_PATH, key: String=STORAGE_KEY) -> void:
 path=file_path
 storage_key=key

func load_payload(validator: Callable) -> Dictionary:
 var primary:=_read(false)
 var result:=_decode(primary,validator)
 if not result.is_empty():
  _last_good=primary
  status="ready"
  return result
 var backup:=_read(true)
 result=_decode(backup,validator)
 if not result.is_empty():
  _last_good=backup
  status="incompatible" if _future_schema else "recovered"
  return result
 if _future_schema: status="incompatible"
 elif not primary.is_empty() or not backup.is_empty(): status="damaged"
 return {}

func write_payload(payload: Dictionary) -> bool:
 if _future_schema:
  status="incompatible"
  return false
 var encoded:=JSON.stringify({"schemaVersion":SCHEMA_VERSION,"payload":payload})
 if encoded.to_utf8_buffer().size()>MAX_BYTES:
  status="unavailable"
  return false
 var ok:=false
 if OS.has_feature("web"):
  var script: String="(function(){try{var k="+JSON.stringify(storage_key)+";var old="+JSON.stringify(_last_good)+";if(old)localStorage.setItem(k+'.backup',old);localStorage.setItem(k,"+JSON.stringify(encoded)+");return true;}catch(e){return false;}})()"
  ok=bool(JavaScriptBridge.eval(script,true))
 else:
  if not _last_good.is_empty() and not _write_file(path+".backup",_last_good):
   status="unavailable"
   return false
  ok=_write_file(path,encoded)
 if ok: _last_good=encoded
 status="saved" if ok else "unavailable"
 return ok

func _decode(encoded: String,validator: Callable) -> Dictionary:
 if encoded.is_empty() or encoded.to_utf8_buffer().size()>MAX_BYTES: return {}
 var parser:=JSON.new()
 if parser.parse(encoded)!=OK or not parser.data is Dictionary: return {}
 var envelope: Dictionary=parser.data
 var schema: Variant=envelope.get("schemaVersion",0)
 if not (schema is int or schema is float) or not is_finite(float(schema)) or float(schema)!=floorf(float(schema)): return {}
 if int(schema)>SCHEMA_VERSION:
  _future_schema=true
  return {}
 if int(schema)!=SCHEMA_VERSION or not envelope.get("payload") is Dictionary: return {}
 var payload: Dictionary=envelope.payload
 return payload if bool(validator.call(payload)) else {}

func _read(backup: bool) -> String:
 if OS.has_feature("web"):
  var key:=storage_key+(".backup" if backup else "")
  var result: Variant=JavaScriptBridge.eval("(function(){try{return localStorage.getItem("+JSON.stringify(key)+");}catch(e){return '__storage_unavailable__';}})()",true)
  if result=="__storage_unavailable__": status="unavailable"; return ""
  return str(result) if result is String else ""
 var target:=path+(".backup" if backup else "")
 if not FileAccess.file_exists(target): return ""
 var file:=FileAccess.open(target,FileAccess.READ)
 if file==null: status="unavailable"; return ""
 if file.get_length()>MAX_BYTES: return "__oversized_save__"
 return file.get_as_text()

func _write_file(target: String,encoded: String) -> bool:
 var absolute:=ProjectSettings.globalize_path(target)
 if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())!=OK: return false
 var temporary:=absolute+".tmp"
 var file:=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null: return false
 file.store_string(encoded)
 file.flush()
 var error:=file.get_error()
 file.close()
 if error!=OK: return false
 return DirAccess.rename_absolute(temporary,absolute)==OK
