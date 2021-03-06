tool
extends Node2D


var AtlasParser = preload("atlas.gd")
var FrameItem = preload("frame_item.tscn")
onready var dialog = get_node("Dialog")
onready var listbox = dialog.get_node("Preview/Background/ScrollContainer/VBox")
var fileDialog = FileDialog.new()

const SEL_INPUT_META = 0;
const SEL_OUTPUT_TEX = 1;
var current_dialog = -1;

signal confim_import(path, meta)

func _ready():
	fileDialog.connect("file_selected", self, "_fileSelected")
	add_child(fileDialog)

	dialog.get_ok().set_text("Import")
	dialog.get_node("Input/Source/Browse").connect("pressed", self, "_selectMetaFile")
	dialog.get_node("Input/Target/Browse").connect("pressed", self, "_selectTargetFile")
	dialog.get_node("Input/Target/TargetDirField").connect("text_changed", self, "_checkPath")
	dialog.get_node("Input/Source/MetaFileField").connect("text_changed", self, "_checkPath")
	dialog.get_node("Input/Type/TypeButton").connect("item_selected", self, "_typeSelected")
	dialog.get_node("Input/Type/TypeButton").select(0)
	dialog.get_node("Preview/SelAll").connect("pressed", self, "_toggleAll")
	dialog.get_node("Preview/Clear").connect("pressed", self, "_untoggleAll")
	dialog.get_node("Preview/Inverse").connect("pressed", self, "_toggleInverse")
	dialog.connect("confirmed", self, "_confirmed")
	dialog.set_pos(Vector2(get_viewport_rect().size.width/2 - dialog.get_rect().size.width/2, get_viewport_rect().size.height/2 - dialog.get_rect().size.height/2))
	# dialog.show()

func _toggleAll():
	for item in listbox.get_children():
		item.selected = true

func _untoggleAll():
	for item in listbox.get_children():
		item.selected = false

func _toggleInverse():
	for item in listbox.get_children():
		item.selected = !item.selected

func _typeSelected(id):
	_checkPath("")

func _showFileDialog():
	fileDialog.set_custom_minimum_size(dialog.get_size() - Vector2(50, 50))
	fileDialog.set_pos(dialog.get_pos() + Vector2(25, 50))

	var file = File.new()
	if fileDialog.get_access() == FileDialog.ACCESS_FILESYSTEM:
		var path = dialog.get_node("Input/Source/MetaFileField").get_text()
		if file.file_exists(path):
			fileDialog.set_current_dir(_getParentDir(path))
	fileDialog.popup()
	fileDialog.invalidate()

func _selectMetaFile():
	current_dialog = SEL_INPUT_META
	fileDialog.clear_filters()
	if dialog.get_node("Input/Type/TypeButton").get_selected_ID() == 0:
		fileDialog.add_filter("*.xml")
	else:
		fileDialog.add_filter("*.json")
	fileDialog.set_access(FileDialog.ACCESS_FILESYSTEM)
	fileDialog.set_mode(FileDialog.MODE_OPEN_FILE)
	_showFileDialog()

func _selectTargetFile():
	current_dialog = SEL_OUTPUT_TEX
	fileDialog.clear_filters()
	fileDialog.add_filter("*.tex")
	fileDialog.add_filter("*.res")
	fileDialog.set_mode(FileDialog.MODE_SAVE_FILE)
	fileDialog.set_access(FileDialog.ACCESS_RESOURCES)
	fileDialog.set_current_file(".tex")
	_showFileDialog()

func _fileSelected(path):
	if current_dialog == SEL_INPUT_META:
		dialog.get_node("Input/Source/MetaFileField").set_text(path)
	elif current_dialog == SEL_OUTPUT_TEX:
		dialog.get_node("Input/Target/TargetDirField").set_text(path)
	_checkPath("")

func _getParentDir(path):
	var fileName = path.substr(0, path.find_last("/"))
	return fileName

func _getFileName(path):
	var fileName = path.substr(path.find_last("/")+1, path.length() - path.find_last("/")-1)
	var dotPos = fileName.find_last(".")
	if dotPos != -1:
		fileName = fileName.substr(0,dotPos)
	return fileName



func _checkPath(path):
	# Clear preview list
	for c in listbox.get_children():
		listbox.remove_child(c)
	listbox.update()
	
	# Check input file
	var file = File.new()
	var inpath = dialog.get_node("Input/Source/MetaFileField").get_text()
	if file.file_exists(inpath):
		if not _updatePreview(inpath):
			dialog.get_node("Status").set_text("No frame found")
			return false
	else:
		dialog.get_node("Status").set_text("Source meta file does not exists")
		return false
	
	# Check output file
	var tarfile = dialog.get_node("Input/Target/TargetDirField").get_text()
	if tarfile.substr(0, "res://".length()) != "res://":
		dialog.get_node("Status").set_text("Target file must under res://")
		return false
	# Check passed
	dialog.get_node("Status").set_text("")
	return true

func _loadAtlas(metaPath, format):
	var atlas = AtlasParser.new()
	atlas.loadFromFile(metaPath, format)
	return atlas

func _loadAtlasTex(metaPath, atlas):
	return load(str(_getParentDir(metaPath), "/", atlas.imagePath))

func _updatePreview(path):
	var atlas = _loadAtlas(path, get_node("Dialog/Input/Type/TypeButton").get_selected_ID())
	var tex = _loadAtlasTex(path, atlas)
	for i in range(atlas.sprites.size()):
		var item = FrameItem.instance()
		listbox.add_child(item)
		item.texture = tex
		item.frame_meta = atlas.sprites[i]
		item.set_custom_minimum_size(Vector2(0, 80))
	return atlas.sprites.size() > 0

func import(path, meta):
	var atlas = _loadAtlas(meta.get_source_path(0), meta.get_option("format"))
	var tex = _loadAtlasTex(meta.get_source_path(0), atlas)
	tex.set_import_metadata(meta)
	ResourceSaver.save(path, tex)
	
	var tarDir = _getParentDir(path)
	var sprites = meta.get_option("sprites")
	
	for s in atlas.sprites:
		if sprites.find(s.name) != -1:
			var atex = AtlasTexture.new()
			atex.set_atlas(tex)
			atex.set_region(s.region)
			ResourceSaver.save(str(tarDir, "/", _getFileName(s.name),".atex"), atex)

func _confirmed():
	if dialog.get_node("Status").get_text() == "":
		var inpath = dialog.get_node("Input/Source/MetaFileField").get_text()
		var outpath = dialog.get_node("Input/Target/TargetDirField").get_text()
		var meta = ResourceImportMetadata.new()
		meta.set_editor("com.geequlim.gdplugin.atlas.importer")
		meta.add_source(inpath, File.new().get_md5(inpath))
		meta.set_option("format", dialog.get_node("Input/Type/TypeButton").get_selected_ID())
		meta.set_option("selectIndex", dialog.get_node("Input/Type/TypeButton").get_selected())
		
		var atlas = _loadAtlas(meta.get_source_path(0), meta.get_option("format"))
		if listbox.get_child_count() > 0:
			var selectedSprites = []
			for i in range(listbox.get_child_count()):
				if listbox.get_child(i).selected:
					selectedSprites.append(atlas.sprites[i].name)
			meta.set_option("sprites", selectedSprites)
		
		emit_signal("confim_import", outpath, meta)
		dialog.hide()

func showDialog(from):
	var meta = null
	if from and from.length()>0:
		dialog.get_node("Input/Target/TargetDirField").set_text(from)
		meta = ResourceLoader.load_import_metadata(from)
	if meta:
		dialog.get_node("Input/Source/MetaFileField").set_text(meta.get_source_path(0))
		dialog.get_node("Input/Type/TypeButton").select(meta.get_option("selectIndex"))
	else:
		dialog.get_node("Input/Source/MetaFileField").set_text("")
		dialog.get_node("Input/Target/TargetDirField").set_text("")
		dialog.get_node("Input/Type/TypeButton").select(0)
	_checkPath("")
	# Select
	if meta and listbox.get_child_count() > 0:
		var selectedSprites = meta.get_option("sprites")
		for i in range(listbox.get_child_count()):
			if selectedSprites.find(listbox.get_child(i).title) != -1:
				listbox.get_child(i).selected = true
	dialog.popup()