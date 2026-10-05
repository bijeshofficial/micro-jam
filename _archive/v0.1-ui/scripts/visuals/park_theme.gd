class_name ParkTheme
extends RefCounted
## Colour sets for the bus park themes (cosmetics): Clear Morning, Rainy
## Day, Festival Day, Night Bus and Snowy Mountain Town.

const THEMES := {
	"theme_morning": {
		"sky_top": "5fa8ea", "sky_bottom": "cfe6f7", "mountain": "9fb7d9", "mountain_far": "c3d3ea", "snow": "ffffff",
		"asphalt": "b9b2a6", "asphalt_dark": "a39c90", "dust": "e8dcc6", "paint": "fff6dc", "bay_paint": "ffc300",
		"sun": "fff1b0", "weather": "", "night": false, "festival": false,
	},
	"theme_rain": {
		"sky_top": "7d8ea6", "sky_bottom": "b9c4d2", "mountain": "8697ad", "mountain_far": "a3b1c3", "snow": "e6ebf2",
		"asphalt": "8f8b86", "asphalt_dark": "7b7772", "dust": "cfc6b6", "paint": "eef0f2", "bay_paint": "ffd23f",
		"sun": "", "weather": "rain", "night": false, "festival": false,
	},
	"theme_festival": {
		"sky_top": "ff9a5c", "sky_bottom": "ffe0b0", "mountain": "c99bb5", "mountain_far": "e6c3cf", "snow": "fff6f0",
		"asphalt": "bfb2a2", "asphalt_dark": "a99c8c", "dust": "f0dcc0", "paint": "fff6dc", "bay_paint": "ff5fa2",
		"sun": "fff1b0", "weather": "", "night": false, "festival": true,
	},
	"theme_night": {
		"sky_top": "151d3d", "sky_bottom": "3a4a7a", "mountain": "2c3a63", "mountain_far": "3d4c7a", "snow": "c9d4f0",
		"asphalt": "5a5866", "asphalt_dark": "4a4856", "dust": "7e7a86", "paint": "e7e2c8", "bay_paint": "ffc300",
		"sun": "f4f1d0", "weather": "stars", "night": true, "festival": false,
	},
	"theme_snow": {
		"sky_top": "8fc1ee", "sky_bottom": "e6f2fb", "mountain": "a9bfdc", "mountain_far": "d2e0f0", "snow": "ffffff",
		"asphalt": "aeb2b8", "asphalt_dark": "9a9fa6", "dust": "f2f5f8", "paint": "ffffff", "bay_paint": "ffc300",
		"sun": "fff6d0", "weather": "snow", "night": false, "festival": false,
	},
}


static func get_theme(id: String) -> Dictionary:
	return THEMES.get(id, THEMES["theme_morning"])


static func c(theme: Dictionary, key: String) -> Color:
	return Color(String(theme.get(key, "ff00ff")))
