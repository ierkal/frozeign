class_name GameConstants

## Centralized constants for the Frozeign game.
## Contains stat keys, resource paths, default values, and UI colors.

# Stat keys (used in 5+ files)
const STAT_HOPE := "Hope"
const STAT_DISCONTENT := "Discontent"
const STAT_ORDER := "Order"
const STAT_FAITH := "Faith"
const ALL_STATS := [STAT_HOPE, STAT_DISCONTENT, STAT_ORDER, STAT_FAITH]

# Resource paths
const JSON_PATH_CARDS := "res://Json/frozeign.json"
const JSON_PATH_BUFFS := "res://Json/buffs.json"
const JSON_PATH_QUESTS := "res://Json/quests.json"
const JSON_PATH_NPC_NAMES := "res://Json/npcnames.json"
const JSON_PATH_CHARACTERS := "res://Json/characters.json"

const NPC_SPRITES_PATH := "res://Assets/Sprites/npc/"

# Default values
const DEFAULT_STAT_VALUE := 50
const STAT_MIN := 0
const STAT_MAX := 100

# UI Colors
class Colors:
	const QUEST_INCOMPLETE := Color(0.3, 0.3, 0.35, 1)
	const QUEST_COMPLETE := Color(0.2, 0.7, 0.3, 1)
	const ITEM_LOCKED := Color(0.3, 0.3, 0.3, 1.0)
	const ITEM_ACTIVE := Color.WHITE
	const ITEM_COMPLETED := Color(0.5, 0.8, 0.5, 0.8)
