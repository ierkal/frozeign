extends Node
signal home_menu_requested
signal hub_ui_requested

# Minigame signals
signal minigame_requested(minigame_id: String, card_data: Dictionary)
signal minigame_completed(minigame_id: String, success: bool)

# Reward popup signals
signal reward_popup_requested(icon: Texture2D, reward_name: String, description: String, minigame_id: String)
signal reward_popup_closed

# Shop signals
signal shop_requested(card_id: String)
signal shop_closed

# NPC reaction system
var npc_name_resolver: Callable = Callable()