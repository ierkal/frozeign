extends Node
signal home_menu_requested

signal buff_started(buff: ActiveBuff)
signal buff_ended(buff_id: String)
signal active_buff_modifiers_changed(total_effects: Dictionary)
signal buff_intro_card_shown(buff_data: Dictionary)
signal buff_intro_card_dismissed()