extends Control

var score: int = 0

func _ready() -> void:
    add_to_group("level_score")

func add_score(amount: int) -> void:
    if amount == 0:
        return
    score += amount
    _print_score()

func set_score(new_score: int) -> void:
    if new_score == score:
        return
    score = new_score
    _print_score()

func _print_score() -> void:
    print("Score: ", score)
