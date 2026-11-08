extends SceneTree
## Writes a tuning sheet: every exported setting of every tuning script, with its default
## value and the "##" line above it (the same text the Inspector shows as the tooltip), as one
## Markdown file a non-programmer can read instead of hovering forty names in the Inspector.
##
##   godot --headless --path <project> --import                    (once)
##   godot --headless --path <project> -s res://addons/agent_kit/tuning_sheet.gd -- options
##
## Options after `--`:
##   --folders=<res path,res path>  folders whose .tres files get a section each (by script)
##   --scripts=<res path,res path>  scripts to include even with no .tres in those folders
##   --out=<res path>               where to write (default res://docs/TUNING.md)
##   --title=<text>                 the sheet's title (default: the project name)
##   --check                        do not write; exit 1 if the file on disk is out of date
##
## A setting's value is its script default, read from a fresh instance of the script. Its
## text is the "##" line(s) above it, split at the first colon into "what you notice" and
## "what it does" when it has one. `--check` is for a test or CI step that fails when the
## committed sheet is stale.

var _folders: PackedStringArray = PackedStringArray()
var _scripts: PackedStringArray = PackedStringArray()
var _out: String = "res://docs/TUNING.md"
var _title: String = ""
var _check: bool = false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folders="):
			_folders = arg.trim_prefix("--folders=").split(",", false)
		elif arg.begins_with("--scripts="):
			_scripts = arg.trim_prefix("--scripts=").split(",", false)
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--title="):
			_title = arg.trim_prefix("--title=")
		elif arg == "--check":
			_check = true
	if _title == "":
		_title = str(ProjectSettings.get_setting("application/config/name", "Project"))
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	if _folders.is_empty() and _scripts.is_empty():
		push_error("tuning_sheet: pass --folders=res://... and/or --scripts=res://...")
		quit(2)
		return
	var text: String = build(_folders, _scripts, _title)
	if _check:
		var on_disk: String = FileAccess.get_file_as_string(_out)
		if on_disk == text:
			print("%s is up to date" % _out)
			quit(0)
		else:
			print("%s is out of date: run tuning_sheet.gd without --check" % _out)
			quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out.get_base_dir()))
	var f := FileAccess.open(_out, FileAccess.WRITE)
	if f == null:
		push_error("tuning_sheet: cannot write %s" % _out)
		quit(1)
		return
	f.store_string(text)
	f.close()
	print("Wrote %s (%d settings)" % [_out, rows(sections(_folders, _scripts)).size()])
	quit(0)


## The sheet's sections in order: {script, files, title}.
static func sections(folders: PackedStringArray, scripts: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for folder in folders:
		var names: PackedStringArray = DirAccess.get_files_at(folder)
		names.sort()
		for name in names:
			if not name.ends_with(".tres"):
				continue
			var res: Resource = load(folder.path_join(name))
			var script: Script = res.get_script() if res != null else null
			if script == null:
				continue
			var file: String = folder.path_join(name).trim_prefix("res://")
			if seen.has(script.resource_path):
				var earlier: Dictionary = out[seen[script.resource_path]]
				earlier["files"] = "%s, %s" % [earlier["files"], file]
				continue
			seen[script.resource_path] = out.size()
			out.append({"script": script.resource_path, "files": file})
	for s in scripts:
		if not seen.has(s):
			seen[s] = out.size()
			out.append({"script": s, "files": "(script defaults)"})
	for s in out:
		s["title"] = String(s["script"]).get_file().get_basename().replace("_tuning", "").capitalize()
	return out


## Every setting on the sheet, in order: {section, script, group, name, default, notice, does}.
static func rows(secs: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var own: Dictionary = {}
	for s in secs:
		own[s["script"]] = true
	for s in secs:
		var script: Script = load(s["script"])
		if script == null:
			continue
		var instance: Object = script.new()
		var chain: Array[String] = []
		var cur: Script = script
		while cur != null and cur.resource_path != "":
			var path: String = cur.resource_path
			if path != s["script"] and own.has(path):
				break
			chain.push_front(path)
			cur = cur.get_base_script()
		for path in chain:
			for setting in settings_in(path):
				setting["section"] = s["title"]
				setting["script"] = path
				setting["default"] = shown(instance.get(setting["name"]))
				out.append(setting)
		if instance is Node:
			(instance as Node).free()
	return out


## The exported settings a script's source declares, in order: {group, name, notice, does}.
static func settings_in(script_path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var export_re: RegEx = RegEx.create_from_string(r"^@export(?:_\w+(?:\([^)]*\))?)?\s+var\s+(\w+)")
	var group_re: RegEx = RegEx.create_from_string(r'^@export_group\("([^"]*)"')
	var group: String = ""
	var doc: PackedStringArray = PackedStringArray()
	for raw in FileAccess.get_file_as_string(script_path).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("##"):
			doc.append(line.trim_prefix("##").strip_edges())
			continue
		var g: RegExMatch = group_re.search(line)
		if g != null:
			group = g.get_string(1)
		var m: RegExMatch = export_re.search(line)
		if m != null:
			var text: String = " ".join(doc).strip_edges()
			var colon: int = text.find(":")
			var notice: String = text if colon < 0 else text.substr(0, colon)
			var does: String = "" if colon < 0 else text.substr(colon + 1).strip_edges()
			out.append({"group": group, "name": m.get_string(1), "notice": notice, "does": does})
		doc.clear()
	return out


## A value as the sheet prints it.
static func shown(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "(none)"
		TYPE_BOOL:
			return "on" if value else "off"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			var v: float = value
			return str(int(v)) if v == floorf(v) and absf(v) < 1e15 else str(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return "(empty)" if String(value) == "" else "\"%s\"" % value
		TYPE_COLOR:
			var c: Color = value
			return "#" + c.to_html(c.a < 1.0)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return "(%s, %s)" % [shown(value.x), shown(value.y)]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return "(%s, %s, %s)" % [shown(value.x), shown(value.y), shown(value.z)]
		TYPE_OBJECT:
			var o: Object = value
			if o == null:
				return "(none)"
			if o is Resource and (o as Resource).resource_path != "":
				return (o as Resource).resource_path.get_file()
			return "(set in the file)"
		TYPE_PACKED_COLOR_ARRAY:
			var parts: PackedStringArray = PackedStringArray()
			for c in value:
				parts.append(shown(c))
			return ", ".join(parts) if not parts.is_empty() else "(none)"
		TYPE_ARRAY, TYPE_DICTIONARY:
			return "(none)" if value.is_empty() else "%d set" % value.size()
	return str(value)


## The whole sheet as text.
static func build(folders: PackedStringArray, scripts: PackedStringArray, title: String) -> String:
	var secs: Array[Dictionary] = sections(folders, scripts)
	var all: Array[Dictionary] = rows(secs)
	var out: PackedStringArray = PackedStringArray()
	out.append("# %s: the tuning sheet\n" % title)
	out.append("Every number you can tune, what you would notice when you change it, and what it actually does.\n")
	out.append("- **Where the numbers live:** in the `.tres` files each section names. Open one in Godot and change a number in the Inspector.")
	out.append("- **Hover a setting's name in the Inspector** and the same text as here shows up as its tooltip.")
	out.append("- **The Default column is the script's default.** A setting missing from a `.tres` file means the default: Godot only writes the values you changed.")
	out.append("\nThis file is generated by `addons/agent_kit/tuning_sheet.gd`; edit the `##` line above the setting in its script instead, then run it again.\n")
	for s in secs:
		out.append("\n## %s\n" % s["title"])
		out.append("File: `%s` · script: `%s`" % [s["files"], String(s["script"]).trim_prefix("res://")])
		var group: String = "\n"
		for r in all:
			if r["section"] != s["title"]:
				continue
			if r["group"] != group:
				group = r["group"]
				if group != "":
					out.append("\n### %s — %s" % [s["title"], group])
				out.append("\n| Setting | Default | What you notice | What it actually does |\n|---|---|---|---|")
			out.append("| %s | %s | %s | %s |" % [_cell(String(r["name"]).capitalize()), _cell(r["default"]),
				_cell(r["notice"]), _cell(r["does"])])
	return "\n".join(out) + "\n"


static func _cell(text: String) -> String:
	return text.replace("|", "\\|").replace("\n", " ")
