extends EnemyAction

@export_range(1, 3) var notices_to_add := 1


func perform_action() -> void:
	if enemy == null:
		return

	var player_handler := enemy.get_tree().get_first_node_in_group("player_handler") as PlayerHandler
	if player_handler != null:
		player_handler.add_misfiled_notice_to_backlog(notices_to_add)

	Events.enemy_action_completed.emit(enemy)


func update_intent_text() -> void:
	intent.current_text = intent.base_text % notices_to_add
