extends Node

var score := 0

var move_rate = 6
var movement_speed = 200
var active_agent = null

var is_dragging = false
var bars_on = true
var stage_inc = 0
var max_stage_inc = 5
var baby_mode = true
var draw_lines = false

var social_mode = false

var num_connectors = 5

var sparkle_scene: PackedScene = load("res://scenes/sparkle.tscn")

var growth_time = 0.4
var decay_time = 1110.6
var action_time = 0.3
var evap_time = 1
var mode = "challenge"
var stage = 1
var is_raining = true
var is_birding = true
var is_killing = true
var is_max_babies = true

var quarry_type = "maize"

var eco_names = ["bean","squash","maize","tree", "myco"]
var social_names = ["service","good","city","foreign", "basket"]

var inventory = { #how many of each plant do we have to use
	"bean": 12,
	"squash": 12,				
	"maize": 12,
	"tree": 12,
	"myco": 12
	}

var social_inventory = { #how many of each plant do we have to use
	"service": 12,
	"good": 12,				
	"foreign": 12,
	"city": 12,
	"basket": 12
	}

var values = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"N": 1,
	"P": 1,				
	"K": 1,
	"R": 1
	
	}
	
var assets_social = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"N": "Services",
	"P": "Goods",				
	"K": "Foreign",
	"R": "Money"
	
	}

var social_values = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"S": 1, #services
	"G": 1, #goods	
	"F": 1, #foreign
	"M": 1 #money
	
	}


var asset_colors = {
	"N": Color.SPRING_GREEN,
	"P": Color.ORANGE,
	"K": Color.VIOLET,
	"R": Color.DEEP_SKY_BLUE
	}
	
var asset_colors_social = {
	"S": Color.SPRING_GREEN,
	"G": Color.ORANGE,
	"F": Color.VIOLET,
	"M": Color.DEEP_SKY_BLUE
	}

	
var ranks = {
	0: "Sporeling",
	5000: "Mycelium Weaver",
	10000: "Mycorrhizal Guardian",
	50000: "Myceliator",
	100000: "Shroom Architect",
	500000: "Nutrient Flow Oracle",
	1000000: "Fungal Network Shepherd",
	5000000: "Mycorrhizal Visionary",
	10000000: "Soil Web Custodian",
	50000000: "Grassroots Economist"
}



var birds = {
	0: 0,
	5000: 1,
	10000: 5,
	50000: 5,
	100000: 10,
	500000: 20,
	1000000: 30,
	5000000: 40,
	10000000: 50,
	50000000: 1
}

var birds_quarry = {
	0: "maize",
	5000: "squash",
	10000: "bean",
	50000: "maize",
	100000: "maize",
	500000: "bean",
	1000000: "bean",
	5000000: "squash",
	10000000: "maize",
	50000000: "maize"
}

var rand_quarry = ["maize","bean","squash"]
#var rand_quarry = ["bean"]

var stage_text = {
	1: "Stage 1: Each plant is rich in minerals:
	Beans -> (N) Nitrogen (Green)
	Squash -> (P) Potassium (Orange)
	Maize -> (K) Phosphorus (Pink)
	Trees -> (R) Water (Blue)
	** Click and drag the mushroom and plants so that the mycorrhizal fungi touches all five plants.",
	2: "Stage 2: The mycorrhizal fungi is now distributing resources to the plants and more plants should start growing!
	
	** Click and drag another mushroom from your inventory below, into the garden to help the baby plants.",
	3: "Stage 3: Now you have two mycorrhizal fungi! 
	
	When fungi are connected together they can also help each other and store nutrients for hard times. 
	** Click and drag another mushroom from your inventory below and ensure all 3 fungi are connected to eachother and that they have all the resources they need.",
	
	4: "Stage 4: You are doing great!
	
	With all these fungi connected your garden should be able to feed some hungry birds!
	
	** After the birds have eaten your maize. Add three maize from your inventory.",
	5: "Stage 5: Grow maize faster by increasing the relative value of phosporus (K) in the mycorrhizal network. 
	
	** Adjust the purple level at the bottom.",
	6: "Stage 6: 
	Make sure your maize crop has all the nutrients it needs. 
	Try to grow as much  maize as you can!
	
	**Use your inventory as needed.
	**Press q to start over.",
	7: "Stage 7: 
	Now that the birds have migrated you should return the value of phosporus (K) back to normal, so that the other plants have a chance to grow.",
	8: "Stage 8: 
		
		Well done!
		
		You have grown a Mycorrhizal Fungi network and a nice garden!
		Press q and try Challenge Mode!"

}

var stage_colors = {
	1: Color(Color.DARK_GREEN,0.8),
	2: Color(Color.DARK_ORCHID,0.8),
	3: Color(Color.DARK_RED,0.8),
	4: Color(Color.DARK_BLUE,0.8),
	5: Color(Color.DARK_MAGENTA,0.8),
	6: Color(Color.DARK_GOLDENROD,0.8),
	7: Color(Color.DARK_ORANGE,0.8),
	8: Color(Color.DARK_SEA_GREEN,0.8),
	}
