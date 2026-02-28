extends Node

const PORT = 25565
const MAX_PLAYERS = 8

var players = {}
var game_mode = "singleplayer" # "singleplayer", "local", "online"

signal player_connected(id)
signal player_disconnected(id)

# SINGLEPLAYER - just loads the game directly fr fr
func start_singleplayer():
	game_mode = "singleplayer"
	print("GOONING ALONE 😭")

# LOCAL MP - multiple people same pc same screen
func start_local(player_count: int):
	game_mode = "local"
	print("LOCAL GOON SESSION WITH", player_count, "GOOBERS 💀")

# ONLINE - ur existing code
func host_game():
	game_mode = "online"
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	print("SERVER GOONING ON PORT", PORT)

func join_game(ip: String):
	game_mode = "online"
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer
	print("JOINING THE GOON SESSION AT", ip)

func _on_player_connected(id: int):
	print("GOOBER JOINED:", id)
	players[id] = {"nickname": "Player" + str(id)}
	emit_signal("player_connected", id)

func _on_player_disconnected(id: int):
	print("GOOBER LEFT:", id)
	players.erase(id)
	emit_signal("player_disconnected", id)

func is_singleplayer() -> bool:
	return game_mode == "singleplayer"

func is_local() -> bool:
	return game_mode == "local"

func is_online() -> bool:
	return game_mode == "online"  
