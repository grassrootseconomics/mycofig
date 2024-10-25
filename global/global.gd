extends Node

var score := 0

var move_rate = 6
var movement_speed = 200
var social_buddy_radius = 200
var active_agent = null

var is_dragging = false
var bars_on = true
var stage_inc = 0
var max_stage_inc = 5
var baby_mode = true
var draw_lines = false

var social_mode = false



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
var social_names = ["service","good","city","value add", "basket"]

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
	"value add": 12,
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
	"N": "Farming",
	"P": "Vegetables",				
	"K": "Cooking",
	"R": "Money"
	
	}
	
var assets_plant = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"N": "Nitrogen (N)",
	"P": "Potassium (P)",				
	"K": "Phosphorous (K)",
	"R": "Rain Water (R)"
	
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
	1000: "Mycelium Weaver",
	2000: "Mycorrhizal Guardian",
	5000: "Myceliator",
	10000: "Shroom Architect",
	50000: "Nutrient Flow Oracle",
	100000: "Fungal Network Shepherd",
	500000: "Mycorrhizal Visionary",
	1000000: "Soil Web Custodian Moja",
	2000000: "Soil Web Custodian Mbili",
	3000000: "Soil Web Custodian Tatu",
	4000000: "Soil Web Custodian Nne",
	5000000: "Grassroots Economist"
}



var birds = {
	0: 0,
	1000: 1,
	2000: 1,
	5000: 1,
	10000: 1,
	50000: 1,
	100000: 5,
	500000: 10,
	1000000: 15,
	2000000: 20,
	3000000: 23,
	4000000: 25,
	5000000: 1
}

var rand_quarry = ["maize","bean","squash"]
#var rand_quarry_social = ["maize","bean","squash"]
#var rand_quarry = ["bean"]

var stage_text = {
	1: "Stage 1: Each plant is rich in minerals:
	Beans -> (N) Nitrogen (Green)
	Squash -> (P) Potassium (Orange)
	Maize -> (K) Phosphorous (Pink)
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
	5: "Stage 5: Grow maize faster by increasing the relative value of Phosphorous (K) in the mycorrhizal network. 
	
	** Adjust the purple level at the bottom.",
	6: "Stage 6: 
	Make sure your maize crop has all the nutrients it needs. 
	Try to grow as much  maize as you can!
	
	**Use your inventory as needed.",
	7: "Stage 7: 
	Now that the birds have migrated you should return the value of Phosphorous (K) back to normal, so that the other plants have a chance to grow.",
	8: "Stage 8: 
		
		Well done!
		
		You have grown a Mycorrhizal Fungi network and a nice garden!
		Head back to the main menu and try challenge mode to reach the rank of 
		Grassroots Economist!"

}


var social_stage_text = {
	1: "Stage 1: Each person is rich in their own resources:
	Farmers -> Labor (Green), Mama Mboga -> Vegetables (Orange)
	Mpishi -> Cooking (Pink), Bank -> Money (Blue)
	
	The baskets here represent agreements that connect certain resources together. 
	For now, all we have are colored baskets (bank agreements) that connect to money.
	But what happens if the money from the city or bank stop comming?
	
	** Click and drag a new basket from your inventory so that the people have a 
	way to trade with eachother directly without using the money.",
	2: "Stage 2: The people using the baskets are now able to fairly exchange and distribute resources 
	and more people are becomming farmers, cooks and selling vegetables to eachoter!
	
	** Click and drag another basket from your inventory below, into the economy to help the new service providers.",
	3: "Stage 3: Now you have two new baskets!! 
	
	When baskets are connected together they can also help each other and store commitemnts for resources for hard times. 
	
	** Click and drag a 3rd basket from your inventory below and ensure all 3 baskets are connected to eachother and each is connected to a cook, farmer and mama mboga.",
	4: "Stage 4: You are doing great!
	
	With all these baskets connected your economy should be able to deal with some losses.
	
	** After the cooks have migrated to the city on tuktuks, train 3 more cooks from your inventory.",
	5: "Stage 5: Train cooks faster by increasing the relative value of Cooking in the economy. 
	
	** Increase the Cooking level in purple at the bottom.",
	6: "Stage 6: 
	Make sure your cooks have all the resources they need (Farming Labor and Vegetables). 
	Try to train as many cooks as you can!
	
	**Use your inventory as needed.",
	7: "Stage 7: 
	Now that the tuktuks have left you should return the value of Cooking (purple) back to normal, 
	so that the other services are equally valued again. ",
	8: "Stage 8: 
		
		Well done!
		
		You have grown a small local economy!
		Head back to the main menu and try challenge mode to reach the rank of Grassroots Economist!"

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
