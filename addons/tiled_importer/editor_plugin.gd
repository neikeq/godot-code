tool
extends EditorPlugin

var importerPlugin = null
onready var importer = preload("./importer_gui.tscn").instance()

func _init():
	pass

func _ready():
	add_child(importer)
	importer.connect("confim_import", self, "_rowImport")

func _enter_tree():
	importerPlugin = ImportPlugin.new()
	importerPlugin.connect("show_import_dialog", self, "_showDialog")
	importerPlugin.connect("import_map", self, "_importMap")
	add_import_plugin(importerPlugin)

func _exit_tree():
	remove_import_plugin(importerPlugin)

func _showDialog(from):
	print(from)
	importer.showDialog(from)

func _importMap(path, meta):
	print(path, meta.get_options())
	importer.import(path, meta)

func _rowImport(path, meta):
	importerPlugin.import(path, meta)

# The import plugin class
class ImportPlugin extends EditorImportPlugin:
	signal show_import_dialog(from)
	signal import_map(path, from)

	func get_name():
		return "com.geequlim.gdplugin.importer.tiled"

	func get_visible_name():
		return "Tile Map from Tiled"

	func import_dialog(from):
		emit_signal("show_import_dialog",from)

	func import(path, from):
		emit_signal("import_map", path, from)
