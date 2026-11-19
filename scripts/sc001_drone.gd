extends AudioStreamPlayer
# Дрон кабинета: длинный свод, края файла сведены в тишину — играем петлёй.

const VOLUME_DB: float = -6.0

func _ready() -> void:
	volume_db = VOLUME_DB
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
	play()
