extends Node
signal home_menu_requested
signal hub_ui_requested

signal buff_started(buff: ActiveBuff)
signal buff_ended(buff_id: String)
signal active_buff_modifiers_changed(total_effects: Dictionary)
signal buff_intro_card_shown(buff_data: Dictionary)
signal buff_intro_card_dismissed()

# Minigame signals
signal minigame_requested(minigame_id: String, card_data: Dictionary)
signal minigame_completed(minigame_id: String, success: bool)

# Reward popup signals
signal reward_popup_requested(icon: Texture2D, reward_name: String, description: String, minigame_id: String)
signal reward_popup_closed

# Shop signals
signal shop_requested(card_id: String)
signal shop_closed