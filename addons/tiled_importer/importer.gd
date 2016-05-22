tool
extends Node2D

onready var dialog = get_node("Dialog")
onready var info = get_node("Dialog/VBox/Info")
onready var inputField = get_node("Dialog/VBox/Input/LineEdit")
onready var outputField = get_node("Dialog/VBox/Output/LineEdit")
onready var fileDialog = get_node("Dialog/FileDialog")
onready var alter = get_node("Dialog/Alter")
onready var warning = get_node("Dialog/VBox/Warning")

var MapParser = preload("map.gd")
var map = MapParser.new()

signal confim_import(path, meta)

func alter(msg):
	alter.set_text(msg)
	alter.popup()

func showDialog(from):
	var meta = null
	info.set_text("")
	if from and from.length()>0:
		meta = ResourceLoader.load_import_metadata(from)
		if meta:
			inputField.set_text(meta.get_option("srcfile"))
			outputField.set_text(meta.get_option("tarScene"))
	else:
		inputField.set_text("")
		outputField.set_text("")
	_check("")
	dialog.popup()

func import(path, meta):
	path = meta.get_option("tarScene")
	var srcfile = meta.get_option("srcfile")
	# print("import tile map", srcfile, path)
	if map.loadFromFile(srcfile):
		var dir = path.substr(0, path.find_last("/"))
		# Save textures
		for k in map.textures:
			ResourceSaver.save(str(dir,"/",_getFileName(path),".",_getFileName(k),".tex"), map.textureMap[k])
		# Save tileset
		map.tileset.set_import_metadata(meta)
		ResourceSaver.save(str(dir,"/", _getFileName(path),".tilesets",".res"), map.tileset)
		# Save layers
		var packer = PackedScene.new()
		var node = Node2D.new()
		for l in map.layers:
			if l.get_parent():
				l.get_parent().remove_child(l)
				l.set_owner(null)
			node.add_child(l)
			l.set_owner(node)
		packer.pack(node)
		ResourceSaver.save(path, packer)

func _getFileName(path):
	var fileName = path.substr(path.find_last("/")+1, path.length() - path.find_last("/")-1)
	var dotPos = fileName.find_last(".")
	if dotPos != -1:
		fileName = fileName.substr(0,dotPos)
	return fileName

func _confirmed():
	if _check(""):
		var inpath = inputField.get_text()
		var outfile = outputField.get_text()
		var meta = ResourceImportMetadata.new()
		meta.set_editor("com.geequlim.gdplugin.importer.tiled")
		meta.add_source(inpath, File.new().get_md5(inpath))
		meta.set_option("tarScene", outfile)
		meta.set_option("srcfile", inpath)
		emit_signal("confim_import", outfile, meta)
		dialog.hide()
	else:
		alter(warning.get_text())

func _ready():
	info.set_readonly(true)
	get_node("Dialog/VBox/Input/Button").connect("pressed", self, "_browseInput")
	get_node("Dialog/VBox/Output/Button").connect("pressed", self, "_browseOutput")
	inputField.connect("text_changed", self, "_check")
	outputField.connect("text_changed", self, "_check")
	fileDialog.connect("file_selected", self, "_fileSelected")
	if not get_tree().is_editor_hint():
		warning.set_text("")
	dialog.get_ok().set_text("Import")
	dialog.set_hide_on_ok(false)
	dialog.get_ok().connect("pressed", self, "_confirmed")

func _browseInput():
	fileDialog.set_mode(FileDialog.MODE_OPEN_FILE)
	fileDialog.set_access(FileDialog.ACCESS_FILESYSTEM)
	fileDialog.clear_filters()
	fileDialog.add_filter("*.tmx")
	fileDialog.add_filter("*.json")
	fileDialog.popup()

func _browseOutput():
	fileDialog.set_mode(FileDialog.MODE_SAVE_FILE)
	fileDialog.set_access(FileDialog.ACCESS_RESOURCES)
	fileDialog.clear_filters()
	fileDialog.add_filter("*.tscn")
	fileDialog.add_filter("*.scn")
	fileDialog.add_filter("*.res")
	fileDialog.add_filter("*.xscn")
	fileDialog.add_filter("*.xml")
	fileDialog.set_current_file(".tscn")
	fileDialog.popup()

func _fileSelected(path):
	if fileDialog.get_mode() == FileDialog.MODE_OPEN_FILE:
		inputField.set_text(path)
	elif fileDialog.get_mode() == FileDialog.MODE_SAVE_FILE:
		outputField.set_text(path)
	_check(path)

func _check(unused):
	info.set_text("")
	var inputPath = inputField.get_text()
	var outputPath = outputField.get_text()
	var file = File.new()
	var passed = true
	var dir = Directory.new()
	var outDir = outputPath.substr(0, outputPath.find_last("/"))
	if not file.file_exists(inputPath):
		warning.set_text("The input file does not exists!")
		passed = false
	if passed:
		if not map.loadFromFile(inputPath):
			warning.set_text("Parse map file failed!")
			passed = false
			return passed
		else:
			var infoTex = str("Tileset count: ", map.tileset.get_tiles_ids().size(), "\n\n")
			infoTex += "Layers:\n"
			for l in map.layers:
				infoTex += str("  ",l.get_name(), "\n")
			infoTex += "\n"

			infoTex += "Textures to import:\n"
			for tp in map.textures:
				infoTex += str("  ", tp, "\n")
			infoTex += "\n"
			info.set_text(infoTex)
	if not outputPath.begins_with("res://") or outputPath == "res://":
		warning.set_text("Output file must under project folder!")
		passed = false
	elif not dir.dir_exists(outDir):
		if outDir != "res:/":
			warning.set_text("Output directory does not exists!")
			passed = false
	if passed:
		warning.set_text("")
	return passed
