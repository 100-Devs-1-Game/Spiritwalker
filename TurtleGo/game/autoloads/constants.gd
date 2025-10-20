extends Node

# increase this to reduce CPU usage
# but in exchange, it will take longer to load maps that we've already downloaded
# which will impact players moving at higher speeds
const LOAD_QUEUED_TILE_EVERY_X_SECONDS := 0.25

# increase this to reduce CPU usage
# but in exchange, it will take longer to download maps
# which will impact players moving at higher speeds
const DOWNLOAD_QUEUED_TILE_EVERY_X_SECONDS := 0.5

# this is to prevent runaway download chains
# decrease it if you want to download more tiles faster
#     but be careful of rate limits from the API
# doesn't affect CPU
const DELAY_NEXT_DOWNLOAD_BY_X_SECONDS := 0.5

# this is a failsafe in case something goes wrong
const LOAD_OR_DOWNLOAD_NEIGHBOURING_TILES_EVERY_X_SECONDS := 20.0

# decrease this if there is too much lag, but it will increase CPU usage
const UNLOAD_DISTANT_TILES_EVERY_X_SECONDS := 4.0

# decrease this if there is too much lag from creating all the paths
# but players moving at high speeds might experience delays
# even if the tile is already downloaded
const MAXIMUM_TILES_TO_LOAD_AT_ONCE := 1

# this will allow each path to load over multiple frames
# e.g a road segment might take multiple frames to load
# turn this on if you want to minimize stutters/freezes
# turn this off if you want tiles to load quicker
# NOTE: kinda untested
# NOTE: if you turn this off, you may just want to turn off the matrix too
const WAIT_ONE_FRAME_BETWEEN_LOADING_EVERY_X_PATHS := 5
var LOADING_PATHS_FRAMESKIP_COUNTER := 0

# this will allow each polygon to load over multiple frames
# e.g a building might take multiple frames to load
# turn this on if you want to minimize stutters/freezes
# turn this off if you want tiles to load quicker
# NOTE: kinda untested
const WAIT_ONE_FRAME_BETWEEN_LOADING_EVERY_X_POLYGONS := 50
var LOADING_POLYGONS_FRAMESKIP_COUNTER := 0

# this will allow each matrix to load over multiple frames
# e.g each road will take one frame to load, so all roads take multiple frames
# turn this on if you want to minimize stutters/freezes
# turn this off if you want tiles to load instantly
# NOTE: kinda untested
const WAIT_ONE_FRAME_BETWEEN_LOADING_MATRIX := true

# turn this on if you want to minimize stutters/freezes
# turn this off if you want tiles to unload instantly
const WAIT_ONE_FRAME_BETWEEN_UNLOADING_PATHS := false

# pokemon go uses a zoom level of 17
# we wereusing a zoom level of 18 at one point
# a smaller zoom level (bigger tiles) means less tiles need to be downloaded as players move
#     which helps with API rate limits
# however, it also means it may take longer for the tile to finish loading
# as there is more data to parse and process in to visual paths
# creating bigger delays
# NOTE: this changes the directory name for maps, so it's safe to experiment with it
const WORLD_TILE_ZOOM_LEVEL := 17

# this is how far away a tile must be from the players tile
# before it is considered "distant"
# distant tiles will be unloaded (deleted)
# increase this value to allow the player to see further
# decrease this value to make the game more performant
# 0 = unload all adjacent tiles, only allowing the players current tile to stay loaded
# 1 = only allow the players current tile + 8 adjacent tiles to stay loaded
# 2 = only allow the players current tile + 8 + 16 adjacent tiles to stay loaded
# etc
# NOTE: depending on the "WAIT_ONE_FRAME" settings, it may take some time for the tile to fully unload
# NOTE: I suggest making this ADJACENT_TILE_RANGE+1 so the players previous tiles will be there if they turn around
const TILE_UNLOAD_RANGE := 3

# this is how many tiles to load around the player
# increase this to allow the player to see more around them, without increasing zoom level
# and without them having to move to another tile
# 0 = don't load any adjacent tiles
# 1 = load the 8 adjacent tiles
# 2 = load the 8 adjacent tiles, and the 16 tiles adjacent to those tiles
# etc
# NOTE: depending on the "WAIT_ONE_FRAME" settings, it may take some time for the tile to fully load
const ADJACENT_TILE_RANGE := 2
