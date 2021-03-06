extends Control

signal file_selected
signal file_item_selected
signal emulator_item_selected
signal help_item_selected

const pixel_scale = 8
const screen_size = 32

onready var file_menu = $MenuPanel/HBoxContainer/FileButton.get_popup()
onready var emulator_menu = $MenuPanel/HBoxContainer/EmulatorButton.get_popup()
onready var help_menu = $MenuPanel/HBoxContainer/HelpButton.get_popup()
var loaded_file = ""

func _ready():
	file_menu.connect("id_pressed", self, "file_menu_selected")
	emulator_menu.connect("id_pressed", self, "emulator_menu_selected")
	help_menu.connect("id_pressed", self, "help_menu_selected")
	init_syntax_highlighting()

func init_syntax_highlighting():
	$MainPanel/TextEdit.grab_focus()
	$MainPanel/TextEdit.add_color_region(";", "", Color.darkgray)
	for opcode in Opcodes.dict:
		$MainPanel/TextEdit.add_keyword_color(opcode, Color.green)
		$MainPanel/TextEdit.add_keyword_color(opcode.to_lower(), Color.green)

func pixel_size():
	return get_viewport().size.x / screen_size

func open_file_dialog(examples = true):
	if $FileDialog.visible:
		return
	if examples:
		$FileDialog.access = FileDialog.ACCESS_RESOURCES
		$FileDialog.set_title("Open example")
		$FileDialog.current_dir = "res://examples/"
	else:
		$FileDialog.access = FileDialog.ACCESS_FILESYSTEM
		$FileDialog.set_title("Open file")
	$FileDialog.popup()

func set_assembly_source(text: String, clear_undo = true):
	$MainPanel/TextEdit.text = text
	if clear_undo:
		$MainPanel/TextEdit.clear_undo_history()

func open_goto():
	$GoToAddressDialog.visible = true

func file_menu_selected(id):
	emit_signal("file_item_selected", id)

func emulator_menu_selected(id):
	emit_signal("emulator_item_selected", id)

func help_menu_selected(id):
	emit_signal("help_item_selected", id)

func hide_screen():
	$MainPanel/Screen.hide()

func show_screen():
	$MainPanel/Screen.show()

func log_print(s):
	$MainPanel/TabContainer/Status.write_line(s)
	
func log_reset():
	$MainPanel/TabContainer/Status.clear()
	
func log_line():
	$MainPanel/TabContainer/Status.write_linebreak()

func _unhandled_key_input(event):
	match event.scancode:
		KEY_F1:
			# load non-packaged file
			open_file_dialog(false)
		KEY_F2:
			# load example
			open_file_dialog(true)

func _on_FileDialog_file_selected(path):
	loaded_file = path
	if path != "":
		emit_signal("file_selected", path)

func _on_FileDialog_hide():
	loaded_file = ""

func _on_GoToAddressDialog_confirmed():
	log_print("Going to address %d" % $GoToAddressDialog.get_address())
