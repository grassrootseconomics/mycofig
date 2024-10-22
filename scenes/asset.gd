extends Node
class_name Asset


var long_name = "none"
var symbol = "?"
var color = Color.ALICE_BLUE
var amt = 0 #amount held   
var need = 0 
var bar = null #shows the current status
var bar_offset = null
var current_excess = 0
var current_need = 0


func setup(ref):
	long_name = ref["long_name"]
	symbol = ref["symbol"]
	color = ref["color"]
	amt = ref["amt"]
	need = ref["need"]
	current_need = ref["current_need"]
	current_excess = ref["current_excess"]
	bar = ref["bar"]
	bar_offset = ref["bar_offset"]
