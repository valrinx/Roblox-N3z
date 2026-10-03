-- ============================================================
-- N3Z HUB v2.4.3 - n3z.lua (entrypoint)
-- Native-GUI dock hub. Run:
--   loadstring(game:HttpGet(
--     "https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/n3z.lua"))()
-- ============================================================

local Players = game:GetService("Players")

-- Executors can inject before Players.LocalPlayer is populated. Waiting here
-- keeps bootstrap from leaving an empty dock shell.
local localPlayer = Players.LocalPlayer
while not localPlayer do
    task.wait()
    localPlayer = Players.LocalPlayer
end
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- Mobile routing is platform-based so Android/iOS always use the mobile dock
-- even when an executor reports KeyboardEnabled/MouseEnabled as true.
-- Desktop platforms never fall into the mobile path because of touch flags.
local function detectMobilePlatform()
    local platform = nil
    pcall(function()
        platform = UserInputService:GetPlatform()
    end)

    if platform == Enum.Platform.Android or platform == Enum.Platform.IOS then
        return true
    end

    -- Fallback only for runtimes where GetPlatform is unavailable.
    if platform == nil then
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end

    return false
end

local isMobile = detectMobilePlatform()

local REPO_URL = "https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/"
local HUB_DIR = "Roblox-N3z/"          -- local executor workspace path
local HUB_URL = REPO_URL

local N3Z_VERSION = "v2.4.3"

-- ---------- module registry (mirror of the old project's registry) ----------
-- add a module: {id,name,version,game,placeIds?,gameIds?,file,envKey?,coreFile?,platformFiles?,visualOcclusion?}
local MODULES = {
    { id = "warzpvp", name = "WarZPVP", configName = "WarZ", version = "v1.7.0", game = "WarZPVP OPEN BETA",
      placeIds = { 135187059974536 }, file = "modules/warz_pvp.lua", envKey = "__RAVEN_WARZPVP",
      coreFile = "modules/warz_pvp/core.lua",
      platformFiles = {
          pc = "modules/warz_pvp/pc.lua",
          mobile = "modules/warz_pvp/mobile.lua",
      } },
    { id = "stealanegg", name = "Steal An Egg", version = "v1.2.8", game = "Steal An Egg",
      placeIds = { 107778070777162 }, file = "modules/steal_an_egg.lua" },
    { id = "illegalsoccer", name = "Illegal Soccer", version = "v1.4.4", game = "Illegal Soccer",
      placeIds = { 126987974021910 }, file = "modules/illegal_soccer.lua" },
    { id = "wanted", name = "Wanted", version = "v1.2.10", game = "Wanted",
      placeIds = { 14438406081 }, file = "modules/wanted.lua", visualOcclusion = true },
    { id = "wartycoon", name = "War Tycoon", version = "v1.1.1", game = "War Tycoon",
      placeIds = { 4639625707 }, file = "modules/war_tycoon.lua", visualOcclusion = true },
    { id = "frisbeefrenzy", name = "Frisbee Frenzy", version = "v1.1.1", game = "Frisbee Frenzy",
      placeIds = { 106986181033085 }, file = "modules/frisbee_frenzy.lua", visualOcclusion = true },
    { id = "danceavenue", name = "Dance Avenue", configName = "DanceAvenue", version = "v1.3.1", game = "Dance Avenue",
      placeIds = { 79341474117411 }, file = "modules/dance_avenue.lua", envKey = "__N3Z_DANCE_AVENUE",
      coreFile = "modules/dance_avenue/core.lua",
      platformFiles = {
          pc = "modules/dance_avenue/pc.lua",
          mobile = "modules/dance_avenue/mobile.lua",
      } },
    -- BEGIN AUTO-PORTED LIBRARY MODULES
    { id = "dream_car_collection", name = "Dream Car Collection", version = "v1.0.0", game = "Dream Car Collection",
      placeIds = { 76841016201110 },
      gameIds = { 10667357873 },
      file = "modules/dream_car_collection.lua", envKey = "__RAVEN_DREAM_CAR",
      legacyPlatform = true,
      coreFile = "modules/dream_car_collection/core.lua",
      platformFiles = {
          pc = "modules/dream_car_collection/pc.lua",
          mobile = "modules/dream_car_collection/mobile.lua",
      } },
    { id = "lumber_inc", name = "Lumber INC.", version = "v1.0.0", game = "Lumber INC.",
      placeIds = { 3344967357 },
      gameIds = { 1200145783 },
      file = "modules/lumber_inc.lua", envKey = "__RAVEN_LUMBER_INC",
      legacyPlatform = true,
      coreFile = "modules/lumber_inc/core.lua",
      platformFiles = {
          pc = "modules/lumber_inc/pc.lua",
          mobile = "modules/lumber_inc/mobile.lua",
      } },
    { id = "ouwland", name = "Ouwland", version = "v2.0.0", game = "Ouwland",
      placeIds = { 136406881576517 },
      gameIds = { 5595353122 },
      file = "modules/ouwland.lua", envKey = "__RAVEN_OUWLAND",
      legacyPlatform = true,
      coreFile = "modules/ouwland/core.lua",
      platformFiles = {
          pc = "modules/ouwland/pc.lua",
          mobile = "modules/ouwland/mobile.lua",
      } },
    { id = "steal_from_the_rich", name = "Steal From The Rich!", version = "v1.3.1", game = "Steal From The Rich!",
      placeIds = { 120475074479690 },
      gameIds = { 10753751277 },
      file = "modules/steal_from_the_rich.lua", envKey = "__RAVEN_STEAL_RICH",
      legacyPlatform = true,
      coreFile = "modules/steal_from_the_rich/core.lua",
      platformFiles = {
          pc = "modules/steal_from_the_rich/pc.lua",
          mobile = "modules/steal_from_the_rich/mobile.lua",
      } },
    { id = "fishing_chef", name = "Fishing Chef", version = "v1.0.0", game = "Fishing Chef",
      placeIds = { 88599461076137 },
      gameIds = { 8955905923 },
      file = "modules/fishing_chef.lua", envKey = "__RAVEN_FISHING_CHEF",
      legacyPlatform = true,
      coreFile = "modules/fishing_chef/core.lua",
      platformFiles = {
          pc = "modules/fishing_chef/pc.lua",
          mobile = "modules/fishing_chef/mobile.lua",
      } },
    { id = "anime_battlegrounds", name = "Anime Battlegrounds", version = "v1.1.0", game = "Anime Battlegrounds",
      placeIds = { 105692919293481, 108567435288296 },
      gameIds = { 10399136326 },
      file = "modules/anime_battlegrounds.lua", envKey = "__RAVEN_ANIME_BATTLEGROUNDS",
      legacyPlatform = true,
      coreFile = "modules/anime_battlegrounds/core.lua",
      platformFiles = {
          pc = "modules/anime_battlegrounds/pc.lua",
          mobile = "modules/anime_battlegrounds/mobile.lua",
      } },
    { id = "cordon", name = "Cordon", version = "v1.0.0", game = "Cordon",
      placeIds = { 112318794071351 },
      gameIds = { 10074335448 },
      file = "modules/cordon.lua",
      legacyPlatform = true,
      coreFile = "modules/cordon/core.lua",
      platformFiles = {
          pc = "modules/cordon/pc.lua",
          mobile = "modules/cordon/mobile.lua",
      } },
    { id = "infected_lands", name = "Infected Lands", version = "v0.1.0", game = "Infected Lands",
      placeIds = { 122789100578830 },
      gameIds = { 8468366390 },
      file = "modules/infected_lands.lua",
      legacyPlatform = true,
      coreFile = "modules/infected_lands/core.lua",
      platformFiles = {
          pc = "modules/infected_lands/pc.lua",
          mobile = "modules/infected_lands/mobile.lua",
      } },
    { id = "project_delta", name = "Project Delta", version = "v0.1.0", game = "Project Delta",
      placeIds = { 7336302630, 7353845952 },
      gameIds = { 2862098693 },
      file = "modules/project_delta.lua",
      legacyPlatform = true,
      coreFile = "modules/project_delta/core.lua",
      platformFiles = {
          pc = "modules/project_delta/pc.lua",
          mobile = "modules/project_delta/mobile.lua",
      } },
    { id = "dueling_grounds", name = "Dueling Grounds", version = "v2.0.0", game = "Dueling Grounds",
      placeIds = { 94217045453265 },
      gameIds = { 9051406594 },
      file = "modules/dueling_grounds.lua", envKey = "__RAVEN_DUELING_GROUNDS",
      legacyPlatform = true,
      coreFile = "modules/dueling_grounds/core.lua",
      platformFiles = {
          pc = "modules/dueling_grounds/pc.lua",
          mobile = "modules/dueling_grounds/mobile.lua",
      } },
    { id = "volleyball_legends", name = "Volleyball Legends", version = "v1.4.2", game = "Volleyball Legends",
      placeIds = { 74691681039273, 85395484560711 },
      gameIds = { 6931042565 },
      file = "modules/volleyball_legends.lua", envKey = "__RAVEN_VOLLEYBALL_LEGENDS",
      legacyPlatform = true,
      coreFile = "modules/volleyball_legends/core.lua",
      platformFiles = {
          pc = "modules/volleyball_legends/pc.lua",
          mobile = "modules/volleyball_legends/mobile.lua",
      } },
    { id = "basketball_zero", name = "Basketball: Zero", version = "v1.0.0", game = "Basketball: Zero",
      placeIds = { 70454767164205, 71683821699644, 72476829463897, 73708914208963, 90346996348563, 91733245171139, 95656979989750, 98118902024430, 129230994638464, 130739873848552, 140469311035169 },
      gameIds = { 7028566528 },
      file = "modules/basketball_zero.lua", envKey = "__RAVEN_BASKETBALL_ZERO",
      legacyPlatform = true,
      coreFile = "modules/basketball_zero/core.lua",
      platformFiles = {
          pc = "modules/basketball_zero/pc.lua",
          mobile = "modules/basketball_zero/mobile.lua",
      } },
    { id = "karinderya", name = "Karinderya", version = "v1.0.0", game = "Karinderya",
      placeIds = { 116497287371701 },
      gameIds = { 10648820673 },
      file = "modules/karinderya.lua", envKey = "__RAVEN_KARINDERYA",
      legacyPlatform = true,
      coreFile = "modules/karinderya/core.lua",
      platformFiles = {
          pc = "modules/karinderya/pc.lua",
          mobile = "modules/karinderya/mobile.lua",
      } },
    { id = "bloxstrike", name = "BloxStrike", version = "v1.1.0", game = "BloxStrike",
      placeIds = { 114234929420007, 108194354348181 },
      gameIds = { 7633926880 },
      file = "modules/bloxstrike.lua", envKey = "__RAVEN_BLOXSTRIKE",
      legacyPlatform = true,
      coreFile = "modules/bloxstrike/core.lua",
      platformFiles = {
          pc = "modules/bloxstrike/pc.lua",
          mobile = "modules/bloxstrike/mobile.lua",
      } },
    { id = "my_knife_farm", name = "My Knife Farm", version = "v0.4", game = "My Knife Farm",
      placeIds = {  },
      gameIds = { 125003919504672 },
      file = "modules/my_knife_farm.lua",
      legacyPlatform = true,
      coreFile = "modules/my_knife_farm/core.lua",
      platformFiles = {
          pc = "modules/my_knife_farm/pc.lua",
          mobile = "modules/my_knife_farm/mobile.lua",
      } },
    { id = "steal_fish_eggs", name = "Steal Fish Eggs", version = "v1.9.0", game = "Steal Fish Eggs",
      placeIds = { 99183404085821 },
      gameIds = { 10718240577 },
      file = "modules/steal_fish_eggs.lua", envKey = "__RAVEN_STEAL_FISH_EGGS",
      legacyPlatform = true,
      coreFile = "modules/steal_fish_eggs/core.lua",
      platformFiles = {
          pc = "modules/steal_fish_eggs/pc.lua",
          mobile = "modules/steal_fish_eggs/mobile.lua",
      } },
    { id = "slime_seas_anime_rpg", name = "Slime Seas ???????????????? Anime RPG", version = "v0.1", game = "Slime Seas ???????????????? Anime RPG",
      placeIds = { 99046552174353 },
      gameIds = { 99046552174353 },
      file = "modules/slime_seas_anime_rpg.lua",
      legacyPlatform = true,
      coreFile = "modules/slime_seas_anime_rpg/core.lua",
      platformFiles = {
          pc = "modules/slime_seas_anime_rpg/pc.lua",
          mobile = "modules/slime_seas_anime_rpg/mobile.lua",
      } },
    { id = "ultimate_mining_tycoon", name = "Ultimate Mining Tycoon", version = "v1.3.0", game = "Ultimate Mining Tycoon",
      placeIds = { 18680867089 },
      gameIds = { 18680867089, 6329693946 },
      file = "modules/ultimate_mining_tycoon.lua",
      legacyPlatform = true,
      dependencyFiles = {
          "modules/ultimate_mining_tycoon/umt/core/settings.lua",
          "modules/ultimate_mining_tycoon/umt/systems/esp.lua",
          "modules/ultimate_mining_tycoon/umt/systems/esp_runtime.lua",
          "modules/ultimate_mining_tycoon/umt/systems/auto_mine.lua",
          "modules/ultimate_mining_tycoon/umt/systems/sell.lua",
          "modules/ultimate_mining_tycoon/umt/core/safe_ui.lua",
          "modules/ultimate_mining_tycoon/umt/systems/player_util.lua",
          "modules/ultimate_mining_tycoon/umt/core/ore_resolver.lua",
          "modules/ultimate_mining_tycoon/umt/systems/auto_mine_loop.lua",
      },
      coreFile = "modules/ultimate_mining_tycoon/core.lua",
      platformFiles = {
          pc = "modules/ultimate_mining_tycoon/pc.lua",
          mobile = "modules/ultimate_mining_tycoon/mobile.lua",
      } },
    { id = "twdo3", name = "The Walking Dead Online 3", version = "v0.8", game = "The Walking Dead Online 3",
      placeIds = { 128039018996175 },
      gameIds = { 7208219743 },
      file = "modules/twdo3.lua",
      legacyPlatform = true,
      dependencyFiles = {
          "modules/twdo3/extras.lua",
          "modules/twdo3/combat.lua",
          "modules/twdo3/rage.lua",
      },
      coreFile = "modules/twdo3/core.lua",
      platformFiles = {
          pc = "modules/twdo3/pc.lua",
          mobile = "modules/twdo3/mobile.lua",
      } },
    { id = "magic_loot", name = "Magic Loot", version = "v2.4", game = "Magic Loot",
      placeIds = { 133188236593503 },
      gameIds = { 10506207587 },
      file = "modules/magic_loot.lua", envKey = "__RAVEN_MAGIC_LOOT_GROUNDS",
      legacyPlatform = true,
      coreFile = "modules/magic_loot/core.lua",
      platformFiles = {
          pc = "modules/magic_loot/pc.lua",
          mobile = "modules/magic_loot/mobile.lua",
      } },
    { id = "sniper_arena", name = "Sniper Arena", version = "v1.3", game = "Sniper Arena",
      placeIds = { 126042865144779, 122446657157717, 119661268047775 },
      gameIds = { 9534705677 },
      file = "modules/sniper_arena.lua",
      legacyPlatform = true,
      coreFile = "modules/sniper_arena/core.lua",
      platformFiles = {
          pc = "modules/sniper_arena/pc.lua",
          mobile = "modules/sniper_arena/mobile.lua",
      } },
    { id = "aqp_deadzone", name = "A Quiet Place: Deadzone", version = "v1.0", game = "A Quiet Place: Deadzone",
      placeIds = { 106920577206536 },
      gameIds = { 9889811676 },
      file = "modules/aqp_deadzone.lua",
      legacyPlatform = true,
      coreFile = "modules/aqp_deadzone/core.lua",
      platformFiles = {
          pc = "modules/aqp_deadzone/pc.lua",
          mobile = "modules/aqp_deadzone/mobile.lua",
      } },
    { id = "ar2", name = "Apocalypse Rising 2", version = "v1.0", game = "Apocalypse Rising 2",
      placeIds = { 863266079 },
      gameIds = { 358276974 },
      file = "modules/ar2.lua",
      legacyPlatform = true,
      coreFile = "modules/ar2/core.lua",
      platformFiles = {
          pc = "modules/ar2/pc.lua",
          mobile = "modules/ar2/mobile.lua",
      } },
    { id = "phantom_forces", name = "Phantom Forces", version = "v2.3.0", game = "Phantom Forces",
      placeIds = { 292439477 },
      gameIds = { 113491250 },
      file = "modules/phantom_forces.lua", envKey = "__RAVEN_PF",
      legacyPlatform = true,
      coreFile = "modules/phantom_forces/core.lua",
      platformFiles = {
          pc = "modules/phantom_forces/pc.lua",
          mobile = "modules/phantom_forces/mobile.lua",
      } },
    { id = "brm5_rage", name = "Blackhawk Rescue Mission 5", version = "v3.2", game = "Blackhawk Rescue Mission 5",
      placeIds = { 2916899287, 3701546109 },
      gameIds = { 1054526971 },
      file = "modules/brm5_rage.lua", envKey = "__RAVEN_CLEANUP",
      legacyPlatform = true,
      coreFile = "modules/brm5_rage/core.lua",
      platformFiles = {
          pc = "modules/brm5_rage/pc.lua",
          mobile = "modules/brm5_rage/mobile.lua",
      } },
    { id = "leaf_game", name = "\\xF0\\x9F\\x8D\\x82 Game", version = "v1.0", game = "\\xF0\\x9F\\x8D\\x82 Game",
      placeIds = { 100068273119174, 92637789841354 },
      gameIds = { 10539411000 },
      file = "modules/leaf_game.lua", envKey = "__RAVEN_LEAF_GAME",
      legacyPlatform = true,
      coreFile = "modules/leaf_game/core.lua",
      platformFiles = {
          pc = "modules/leaf_game/pc.lua",
          mobile = "modules/leaf_game/mobile.lua",
      } },
    { id = "roll_a_gnome", name = "Roll A Gnome", version = "v1.0.8", game = "Roll A Gnome",
      placeIds = { 117539213094671 },
      gameIds = { 10514280922 },
      file = "modules/roll_a_gnome.lua", envKey = "__RAVEN_ROLL_A_GNOME",
      legacyPlatform = true,
      coreFile = "modules/roll_a_gnome/core.lua",
      platformFiles = {
          pc = "modules/roll_a_gnome/pc.lua",
          mobile = "modules/roll_a_gnome/mobile.lua",
      } },
    { id = "the_wild_west", name = "The Wild West", version = "v0.1.20", game = "The Wild West",
      placeIds = { 2317712696 },
      gameIds = { 807930589 },
      file = "modules/the_wild_west.lua", envKey = "__RAVEN_THE_WILD_WEST",
      legacyPlatform = true,
      coreFile = "modules/the_wild_west/core.lua",
      platformFiles = {
          pc = "modules/the_wild_west/pc.lua",
          mobile = "modules/the_wild_west/mobile.lua",
      } },
    { id = "cold_war", name = "Cold War [MOUNTED MGs]", version = "v1.8.4", game = "Cold War [MOUNTED MGs]",
      placeIds = { 13687899540 },
      gameIds = { 4750561026 },
      file = "modules/cold_war.lua", envKey = "__RAVEN_COLD_WAR",
      legacyPlatform = true,
      coreFile = "modules/cold_war/core.lua",
      platformFiles = {
          pc = "modules/cold_war/pc.lua",
          mobile = "modules/cold_war/mobile.lua",
      } },
    { id = "ground_war", name = "Ground War (o)", version = "v0.1.0", game = "Ground War (o)",
      placeIds = { 76822114837453 },
      gameIds = { 6583326485 },
      file = "modules/ground_war.lua", envKey = "__RAVEN_GROUND_WAR",
      legacyPlatform = true,
      coreFile = "modules/ground_war/core.lua",
      platformFiles = {
          pc = "modules/ground_war/pc.lua",
          mobile = "modules/ground_war/mobile.lua",
      } },
    { id = "wood_carving_tycoon", name = "Wood Carving Tycoon", version = "v1.2.0", game = "Wood Carving Tycoon",
      placeIds = { 82712304391069, 122971261313361 },
      gameIds = { 10404519332, 7129528628 },
      file = "modules/wood_carving_tycoon.lua", envKey = "__RAVEN_WOOD_CARVING",
      legacyPlatform = true,
      coreFile = "modules/wood_carving_tycoon/core.lua",
      platformFiles = {
          pc = "modules/wood_carving_tycoon/pc.lua",
          mobile = "modules/wood_carving_tycoon/mobile.lua",
      } },
    { id = "iron_soul", name = "Iron Soul: Dungeon", version = "v1.7.2", game = "Iron Soul: Dungeon",
      placeIds = { 117533937949084, 116456628154258, 112316840155266 },
      gameIds = { 9910245722 },
      file = "modules/iron_soul.lua", envKey = "__RAVEN_IRON_SOUL",
      legacyPlatform = true,
      coreFile = "modules/iron_soul/core.lua",
      platformFiles = {
          pc = "modules/iron_soul/pc.lua",
          mobile = "modules/iron_soul/mobile.lua",
      } },
    { id = "dont_look_back", name = "DON'T LOOK BACK", version = "v1.0", game = "DON'T LOOK BACK",
      placeIds = { 127332613700317 },
      gameIds = { 10493730706 },
      file = "modules/dont_look_back.lua",
      legacyPlatform = true,
      coreFile = "modules/dont_look_back/core.lua",
      platformFiles = {
          pc = "modules/dont_look_back/pc.lua",
          mobile = "modules/dont_look_back/mobile.lua",
      } },
    { id = "mine_a_mountain", name = "Mine a Mountain", version = "v1.0", game = "Mine a Mountain",
      placeIds = { 125927821145949 },
      gameIds = { 10187294555 },
      file = "modules/mine_a_mountain.lua", envKey = "__RAVEN_MAM",
      legacyPlatform = true,
      coreFile = "modules/mine_a_mountain/core.lua",
      platformFiles = {
          pc = "modules/mine_a_mountain/pc.lua",
          mobile = "modules/mine_a_mountain/mobile.lua",
      } },
    { id = "build_and_crush", name = "Build and Crush", version = "v0.3.1", game = "Build and Crush",
      placeIds = { 123581964009368 },
      gameIds = { 8723526551 },
      file = "modules/build_and_crush.lua", envKey = "__RAVEN_BUILD_AND_CRUSH",
      legacyPlatform = true,
      coreFile = "modules/build_and_crush/core.lua",
      platformFiles = {
          pc = "modules/build_and_crush/pc.lua",
          mobile = "modules/build_and_crush/mobile.lua",
      } },
    { id = "drain_water", name = "+1 Drain Water Per Click", version = "v1.0.1", game = "+1 Drain Water Per Click",
      placeIds = { 103883942725157 },
      gameIds = { 10561352230 },
      file = "modules/drain_water.lua", envKey = "__RAVEN_DRAIN_WATER",
      legacyPlatform = true,
      coreFile = "modules/drain_water/core.lua",
      platformFiles = {
          pc = "modules/drain_water/pc.lua",
          mobile = "modules/drain_water/mobile.lua",
      } },
    { id = "gym_simulator", name = "Gym Star Simulator", version = "v1.0.0", game = "Gym Star Simulator",
      placeIds = { 70906625936847 },
      gameIds = { 6443367640 },
      file = "modules/gym_simulator.lua", envKey = "__RAVEN_GYM_SIM",
      legacyPlatform = true,
      coreFile = "modules/gym_simulator/core.lua",
      platformFiles = {
          pc = "modules/gym_simulator/pc.lua",
          mobile = "modules/gym_simulator/mobile.lua",
      } },
    { id = "load_the_truck", name = "[UPD] Load The Truck!", version = "v1.0.0", game = "[UPD] Load The Truck!",
      placeIds = { 120491560796071 },
      gameIds = { 10417812127 },
      file = "modules/load_the_truck.lua", envKey = "__RAVEN_LOAD_TRUCK",
      legacyPlatform = true,
      coreFile = "modules/load_the_truck/core.lua",
      platformFiles = {
          pc = "modules/load_the_truck/pc.lua",
          mobile = "modules/load_the_truck/mobile.lua",
      } },
    { id = "fish_anime_rng", name = "Fish an Anime RNG", version = "v1.0.0", game = "Fish an Anime RNG",
      placeIds = { 74729868188364 },
      gameIds = { 9582986239 },
      file = "modules/fish_anime_rng.lua", envKey = "__RAVEN_FISH_ANIME",
      legacyPlatform = true,
      coreFile = "modules/fish_anime_rng/core.lua",
      platformFiles = {
          pc = "modules/fish_anime_rng/pc.lua",
          mobile = "modules/fish_anime_rng/mobile.lua",
      } },
    { id = "train_your_fish", name = "Train Your Fish to Race", version = "v1.1.2", game = "Train Your Fish to Race",
      placeIds = { 119244328726647 },
      gameIds = { 9637959941 },
      file = "modules/train_your_fish.lua", envKey = "__RAVEN_TRAIN_YOUR_FISH",
      legacyPlatform = true,
      coreFile = "modules/train_your_fish/core.lua",
      platformFiles = {
          pc = "modules/train_your_fish/pc.lua",
          mobile = "modules/train_your_fish/mobile.lua",
      } },
    { id = "anime_card_farm", name = "Anime Card Farm", version = "v0.1.1", game = "Anime Card Farm",
      placeIds = { 125039473548047 },
      gameIds = { 10144587520 },
      file = "modules/anime_card_farm.lua", envKey = "__RAVEN_ANIME_CARD_FARM",
      legacyPlatform = true,
      coreFile = "modules/anime_card_farm/core.lua",
      platformFiles = {
          pc = "modules/anime_card_farm/pc.lua",
          mobile = "modules/anime_card_farm/mobile.lua",
      } },
    { id = "ttk_testing", name = "TTK Testing [MAP VOTING]", version = "v1.0.0", game = "TTK Testing [MAP VOTING]",
      placeIds = { 120189115846709 },
      gameIds = { 10090256806 },
      file = "modules/ttk_testing.lua", envKey = "__RAVEN_TTK",
      legacyPlatform = true,
      coreFile = "modules/ttk_testing/core.lua",
      platformFiles = {
          pc = "modules/ttk_testing/pc.lua",
          mobile = "modules/ttk_testing/mobile.lua",
      } },
    { id = "killstreak", name = "KILLSTREAK!", version = "v1.4", game = "KILLSTREAK!",
      placeIds = { 104856666707760 },
      gameIds = { 9705384247 },
      file = "modules/killstreak.lua", envKey = "__RAVEN_KILLSTREAK",
      legacyPlatform = true,
      coreFile = "modules/killstreak/core.lua",
      platformFiles = {
          pc = "modules/killstreak/pc.lua",
          mobile = "modules/killstreak/mobile.lua",
      } },
    { id = "operation_one", name = "[SEASON 3] Operation One", version = "v1.2", game = "[SEASON 3] Operation One",
      placeIds = { 72920620366355 },
      gameIds = { 8307114974 },
      file = "modules/operation_one.lua", envKey = "__RAVEN_OPERATION_ONE",
      legacyPlatform = true,
      coreFile = "modules/operation_one/core.lua",
      platformFiles = {
          pc = "modules/operation_one/pc.lua",
          mobile = "modules/operation_one/mobile.lua",
      } },
    { id = "ronopoly", name = "Ronopoly Game", version = "v1.0.0", game = "Ronopoly Game",
      placeIds = { 6875760739 },
      gameIds = { 2621511041 },
      file = "modules/ronopoly.lua", envKey = "__RAVEN_RONOPOLY",
      legacyPlatform = true,
      coreFile = "modules/ronopoly/core.lua",
      platformFiles = {
          pc = "modules/ronopoly/pc.lua",
          mobile = "modules/ronopoly/mobile.lua",
      } },
    { id = "guess_the_anime_color", name = "Guess the Anime Color", version = "v1.0.0", game = "Guess the Anime Color",
      placeIds = { 97506470800237 },
      gameIds = { 10667006841 },
      file = "modules/guess_the_anime_color.lua", envKey = "__RAVEN_GTC_CLEANUP",
      legacyPlatform = true,
      coreFile = "modules/guess_the_anime_color/core.lua",
      platformFiles = {
          pc = "modules/guess_the_anime_color/pc.lua",
          mobile = "modules/guess_the_anime_color/mobile.lua",
      } },
    { id = "the_sea", name = "The Sea", version = "v1.2.5", game = "The Sea",
      placeIds = { 139802517550914 },
      gameIds = { 9167377564 },
      file = "modules/the_sea.lua", envKey = "__RAVEN_THE_SEA",
      legacyPlatform = true,
      coreFile = "modules/the_sea/core.lua",
      platformFiles = {
          pc = "modules/the_sea/pc.lua",
          mobile = "modules/the_sea/mobile.lua",
      } },
    { id = "desolate_valley", name = "Desolate Valley", version = "v1.0", game = "Desolate Valley",
      placeIds = { 11574110446 },
      gameIds = { 3615728730 },
      file = "modules/desolate_valley.lua", envKey = "__RAVEN_INTERACT_MOD",
      legacyPlatform = true,
      coreFile = "modules/desolate_valley/core.lua",
      platformFiles = {
          pc = "modules/desolate_valley/pc.lua",
          mobile = "modules/desolate_valley/mobile.lua",
      } },
    { id = "pull_an_egg", name = "Pull An Egg", version = "v1.0.0", game = "Pull An Egg",
      placeIds = { 70640255604878 },
      gameIds = { 10649255304 },
      file = "modules/pull_an_egg.lua", envKey = "__RAVEN_PULL_AN_EGG",
      legacyPlatform = true,
      coreFile = "modules/pull_an_egg/core.lua",
      platformFiles = {
          pc = "modules/pull_an_egg/pc.lua",
          mobile = "modules/pull_an_egg/mobile.lua",
      } },
    { id = "aotr_family_roll", name = "Attack on Titan Revolution - Family Roll", version = "v1.0.1", game = "Attack on Titan Revolution - Family Roll",
      placeIds = { 13379208636 },
      gameIds = {  },
      file = "modules/aotr_family_roll.lua",
      legacyPlatform = true,
      coreFile = "modules/aotr_family_roll/core.lua",
      platformFiles = {
          pc = "modules/aotr_family_roll/pc.lua",
          mobile = "modules/aotr_family_roll/mobile.lua",
      } },
    { id = "shiganshina", name = "Shiganshina (AoT)", version = "v7.4", game = "Shiganshina (AoT)",
      placeIds = { 13379349730, 126678335159530 },
      gameIds = { 4658598196 },
      file = "modules/shiganshina.lua",
      legacyPlatform = true,
      coreFile = "modules/shiganshina/core.lua",
      platformFiles = {
          pc = "modules/shiganshina/pc.lua",
          mobile = "modules/shiganshina/mobile.lua",
      } },
    { id = "dungeonlootr", name = "Dungeon Lootr", version = "v3.6.6", game = "Dungeon Lootr",
      placeIds = { 132285059959516, 135245842886361, 106484206883664 },
      gameIds = { 9656201728, 8410525651 },
      file = "modules/dungeonlootr.lua",
      legacyPlatform = true,
      coreFile = "modules/dungeonlootr/core.lua",
      platformFiles = {
          pc = "modules/dungeonlootr/pc.lua",
          mobile = "modules/dungeonlootr/mobile.lua",
      } },
    { id = "greedy_growers", name = "Greedy Growers", version = "v4.2.0", game = "Greedy Growers",
      placeIds = { 74102906764176 },
      gameIds = { 10440833423 },
      file = "modules/greedy_growers.lua", envKey = "__RAVEN_GREEDY_GROWERS",
      legacyPlatform = true,
      coreFile = "modules/greedy_growers/core.lua",
      platformFiles = {
          pc = "modules/greedy_growers/pc.lua",
          mobile = "modules/greedy_growers/mobile.lua",
      } },
    { id = "beeconomy", name = "Beeconomy!", version = "v1.0.0", game = "Beeconomy!",
      placeIds = { 101558830312092 },
      gameIds = { 7000989941 },
      file = "modules/beeconomy.lua",
      legacyPlatform = true,
      coreFile = "modules/beeconomy/core.lua",
      platformFiles = {
          pc = "modules/beeconomy/pc.lua",
          mobile = "modules/beeconomy/mobile.lua",
      } },
    { id = "grand_blue", name = "Kronos", version = "v1.0.0", game = "Kronos",
      placeIds = { 118635363908336 },
      gameIds = { 6215986499 },
      file = "modules/grand_blue.lua", envKey = "__KRONOS_GRAND_BLUE",
      legacyPlatform = true,
      coreFile = "modules/grand_blue/core.lua",
      platformFiles = {
          pc = "modules/grand_blue/pc.lua",
          mobile = "modules/grand_blue/mobile.lua",
      } },
    { id = "zoo_hatchers", name = "Zoo Hatchers!", version = "v1.8.0", game = "Zoo Hatchers!",
      placeIds = { 127715053457585, 126870639873289 },
      gameIds = { 7181313677, 10690360998 },
      file = "modules/zoo_hatchers.lua", envKey = "__RAVEN_DROP_EGG_HOOKED",
      legacyPlatform = true,
      coreFile = "modules/zoo_hatchers/core.lua",
      platformFiles = {
          pc = "modules/zoo_hatchers/pc.lua",
          mobile = "modules/zoo_hatchers/mobile.lua",
      } },
    { id = "color_my_flag", name = "Color My Flag", version = "v1.0.0", game = "Color My Flag",
      placeIds = { 132173349090360 },
      gameIds = { 10630800860 },
      file = "modules/color_my_flag.lua", envKey = "__RAVEN_COLOR_MY_FLAG",
      legacyPlatform = true,
      coreFile = "modules/color_my_flag/core.lua",
      platformFiles = {
          pc = "modules/color_my_flag/pc.lua",
          mobile = "modules/color_my_flag/mobile.lua",
      } },
    { id = "guess_the_person", name = "Guess The Person", version = "v1.0.0", game = "Guess The Person",
      placeIds = { 88989028816809 },
      gameIds = { 10637759898 },
      file = "modules/guess_the_person.lua", envKey = "__RAVEN_GUESS_THE_PERSON",
      legacyPlatform = true,
      coreFile = "modules/guess_the_person/core.lua",
      platformFiles = {
          pc = "modules/guess_the_person/pc.lua",
          mobile = "modules/guess_the_person/mobile.lua",
      } },
    { id = "racket_rivals", name = "Racket Rivals", version = "v1.0.2", game = "Racket Rivals",
      placeIds = { 134933804107672, 90906407195271, 78912788107663 },
      gameIds = { 7883776681 },
      file = "modules/racket_rivals.lua", envKey = "__RAVEN_RACKET_RIVALS",
      legacyPlatform = true,
      coreFile = "modules/racket_rivals/core.lua",
      platformFiles = {
          pc = "modules/racket_rivals/pc.lua",
          mobile = "modules/racket_rivals/mobile.lua",
      } },
    { id = "rivals", name = "RIVALS", version = "v1.4.2", game = "RIVALS",
      placeIds = { 117398147513099 },
      gameIds = { 6035872082 },
      file = "modules/rivals.lua", envKey = "__RAVEN_RIVALS",
      legacyPlatform = true,
      coreFile = "modules/rivals/core.lua",
      platformFiles = {
          pc = "modules/rivals/pc.lua",
          mobile = "modules/rivals/mobile.lua",
      } },
    { id = "fight_fight_fight", name = "Fight, Fight, Fight!", version = "v1.1.0", game = "Fight, Fight, Fight!",
      placeIds = { 92949164250558, 101770480176177 },
      gameIds = { 10258991999 },
      file = "modules/fight_fight_fight.lua", envKey = "__RAVEN_FIGHT_FIGHT_FIGHT",
      legacyPlatform = true,
      coreFile = "modules/fight_fight_fight/core.lua",
      platformFiles = {
          pc = "modules/fight_fight_fight/pc.lua",
          mobile = "modules/fight_fight_fight/mobile.lua",
      } },
    { id = "ride_a_pet", name = "Ride A Pet", version = "v1.3.0", game = "Ride A Pet",
      placeIds = { 124216119978534 },
      gameIds = { 10035204815 },
      file = "modules/ride_a_pet.lua", envKey = "__RAVEN_RIDE_A_PET",
      legacyPlatform = true,
      coreFile = "modules/ride_a_pet/core.lua",
      platformFiles = {
          pc = "modules/ride_a_pet/pc.lua",
          mobile = "modules/ride_a_pet/mobile.lua",
      } },
    { id = "dig_into_secrets", name = "Dig Into Secrets", version = "v1.0", game = "Dig Into Secrets",
      placeIds = { 119409763193569, 86641960184547 },
      gameIds = { 10685312778 },
      file = "modules/dig_into_secrets.lua", envKey = "__RAVEN_DIS",
      legacyPlatform = true,
      coreFile = "modules/dig_into_secrets/core.lua",
      platformFiles = {
          pc = "modules/dig_into_secrets/pc.lua",
          mobile = "modules/dig_into_secrets/mobile.lua",
      } },
    { id = "shovel_it", name = "Shovel It!", version = "v1.0.0", game = "Shovel It!",
      placeIds = { 133832344745984 },
      gameIds = { 9226697658 },
      file = "modules/shovel_it.lua", envKey = "__RAVEN_SHOVEL_IT",
      legacyPlatform = true,
      coreFile = "modules/shovel_it/core.lua",
      platformFiles = {
          pc = "modules/shovel_it/pc.lua",
          mobile = "modules/shovel_it/mobile.lua",
      } },
    { id = "eight_ball_duels", name = "[GALAXY] 8 Ball Duels", version = "v1.0.4", game = "[GALAXY] 8 Ball Duels",
      placeIds = { 116921506811323 },
      gameIds = { 10526463655 },
      file = "modules/eight_ball_duels.lua", envKey = "__RAVEN_8BALL_DUELS",
      legacyPlatform = true,
      coreFile = "modules/eight_ball_duels/core.lua",
      platformFiles = {
          pc = "modules/eight_ball_duels/pc.lua",
          mobile = "modules/eight_ball_duels/mobile.lua",
      } },
    -- END AUTO-PORTED LIBRARY MODULES
}

-- ---------- source resolution ----------
-- Production/raw GitHub boot must use GitHub first so stale executor files
-- cannot silently override freshly pushed modules. For local development:
--     getgenv().__N3Z_DEV_LOCAL = true
local bootEnv = (type(getgenv) == "function" and getgenv()) or _G
local DEV_LOCAL = bootEnv.__N3Z_DEV_LOCAL == true

local function looksLikeLuaSource(content)
    if type(content) ~= "string" or #content <= 100 then
        return false
    end
    local head = string.lower(content:sub(1, 512))
    if string.find(head, "<!doctype", 1, true)
        or string.find(head, "<html", 1, true)
        or string.find(head, "<body", 1, true)
        or string.find(head, "bad gateway", 1, true)
        or string.find(head, "upstream connect error", 1, true)
        or string.find(head, "rate limit", 1, true)
        or string.find(head, "service unavailable", 1, true) then
        return false
    end
    return true
end

local function fetchGitHub(urlPath)
    local sep = string.find(urlPath, "?", 1, true) and "&" or "?"
    for attempt = 1, 3 do
        local cacheBust = tostring(os.time()) .. "-" .. tostring(attempt)
        local ok, content = pcall(function()
            return game:HttpGet(REPO_URL .. urlPath .. sep .. "_cb=" .. cacheBust)
        end)
        if ok and looksLikeLuaSource(content) then
            return content
        end
        if attempt < 3 then
            task.wait(0.18 * attempt)
        end
    end
    return nil
end

local function fetchLocal(localPath)
    if type(readfile) ~= "function" or type(isfile) ~= "function" then
        return nil
    end
    for _, path in ipairs({ HUB_DIR .. localPath, localPath }) do
        local ok, exists = pcall(isfile, path)
        if ok and exists then
            local ok2, content = pcall(readfile, path)
            if ok2 and type(content) == "string" and #content > 0 then
                return content
            end
        end
    end
    return nil
end

local function fetchDevHttp(localPath)
    for _, base in ipairs({
        "http://localhost:8999/N3z%20HUB/",
        "http://localhost:8999/",
    }) do
        local ok, content = pcall(function()
            return game:HttpGet(base .. localPath .. "?_cb=" .. tostring(os.time()))
        end)
        if ok and type(content) == "string" and #content > 100 then
            return content
        end
    end
    return nil
end

local function fetch(localPath, urlPath)
    if DEV_LOCAL then
        return fetchLocal(localPath)
            or fetchDevHttp(localPath)
            or fetchGitHub(urlPath)
            or error("N3Z: failed to fetch " .. tostring(urlPath))
    end
    return fetchGitHub(urlPath)
        or error("N3Z: GitHub fetch failed for " .. tostring(urlPath) .. " (no local fallback in production)")
end

local function fetchHub(name)
    return fetch(name, name)
end

local moduleFileCache = {}

local function loadModuleFile(path)
    assert(type(path) == "string" and path ~= "", "N3Z: module path is required")
    if moduleFileCache[path] ~= nil then
        return moduleFileCache[path]
    end

    local source = fetch(path, path)
    local chunk, loadErr = loadstring(source, "@" .. path)
    assert(chunk, "N3Z: failed to compile " .. path .. ": " .. tostring(loadErr))

    local ok, result = pcall(chunk)
    assert(ok, "N3Z: failed to prepare " .. path .. ": " .. tostring(result))
    moduleFileCache[path] = result
    return result
end

-- ---------- per-game executor-workspace config ----------
-- Relative paths resolve inside the executor workspace:
--   N3zHUB/<safe game name>/setting/config.json
local function safeFolderName(name, fallback)
    local value = tostring(name or "")
    value = value:gsub("[^%w%s_%-]", "")
    value = value:gsub("%s+", " ")
    value = value:match("^%s*(.-)%s*$") or ""
    if value == "" then value = tostring(fallback or "Game") end
    return value:sub(1, 64)
end

local function ensureFolderTree(path)
    if type(makefolder) ~= "function" then return false end
    local current = ""
    for part in tostring(path):gmatch("[^/]+") do
        current = (current == "") and part or (current .. "/" .. part)
        local exists = false
        if type(isfolder) == "function" then
            local ok, result = pcall(isfolder, current)
            exists = ok and result == true
        end
        if not exists then pcall(makefolder, current) end
    end
    return true
end

local function createConfigStore(folderName)
    folderName = safeFolderName(folderName, "Game" .. tostring(game.PlaceId))
    local dir = "N3zHUB/" .. folderName .. "/setting"
    local path = dir .. "/config.json"
    local values = {}
    local loaded = false

    if type(readfile) == "function" and type(isfile) == "function" then
        local okExists, exists = pcall(isfile, path)
        if okExists and exists then
            local okRead, rawConfig = pcall(readfile, path)
            if okRead and type(rawConfig) == "string" and rawConfig ~= "" then
                local okDecode, decoded = pcall(function()
                    return HttpService:JSONDecode(rawConfig)
                end)
                if okDecode and type(decoded) == "table" then
                    if type(decoded.values) == "table" then
                        values = decoded.values
                    else
                        values = decoded
                    end
                    loaded = true
                end
            end
        end
    end

    local store = {
        path = path,
        dir = dir,
        game = folderName,
        values = values,
        loaded = loaded,
        dirty = false,
        _saveToken = 0,
    }

    function store:Has(key)
        return type(key) == "string" and self.values[key] ~= nil
    end

    function store:Get(key, defaultValue)
        local value = self.values[key]
        if value == nil then return defaultValue end
        return value
    end

    function store:Ensure(key, value)
        if type(key) ~= "string" or key == "" then return value end
        if self.values[key] == nil then
            self.values[key] = value
            self.dirty = true
        end
        return self.values[key]
    end

    function store:Flush()
        if not self.dirty then return true end
        if type(writefile) ~= "function" then return false end
        ensureFolderTree(self.dir)
        local payload = {
            version = 1,
            game = self.game,
            placeId = game.PlaceId,
            values = self.values,
        }
        local okEncode, encoded = pcall(function()
            return HttpService:JSONEncode(payload)
        end)
        if not okEncode then return false end
        local okWrite = pcall(writefile, self.path, encoded)
        if okWrite then self.dirty = false end
        return okWrite
    end

    function store:ScheduleSave()
        self._saveToken += 1
        local token = self._saveToken
        task.delay(0.12, function()
            if token == self._saveToken then
                pcall(function() self:Flush() end)
            end
        end)
    end

    function store:Set(key, value)
        if type(key) ~= "string" or key == "" then return end
        if self.values[key] == value then return end
        self.values[key] = value
        self.dirty = true
        self:ScheduleSave()
    end

    return store
end

-- ---------- game detect + source preflight ----------
local placeId = game.PlaceId
local gameId = game.GameId
local activeMod = nil
for _, m in ipairs(MODULES) do
    for _, pid in ipairs(m.placeIds or {}) do
        if pid == placeId then
            activeMod = m
            break
        end
    end
    if not activeMod then
        for _, gid in ipairs(m.gameIds or {}) do
            if gid == gameId then
                activeMod = m
                break
            end
        end
    end
    if activeMod then break end
end

-- Fetch and compile everything before tearing down a working instance. This
-- prevents transient raw-GitHub failures from leaving only an empty dock.
local dockSrc = fetchHub(isMobile and "n3z-dock-mobile.lua" or "n3z-dock.lua")
local dockChunk, dockLoadErr = loadstring(dockSrc, "@n3z-dock")
assert(dockChunk, "N3Z: failed to compile dock: " .. tostring(dockLoadErr))
local Dock = dockChunk()
assert(type(Dock) == "table", "N3Z: dock source did not return a table")

local compatSrc = fetchHub("n3z-compat.lua")
local compatChunk, compatLoadErr = loadstring(compatSrc, "@n3z-compat")
assert(compatChunk, "N3Z: failed to compile compat: " .. tostring(compatLoadErr))
local makeWindow = compatChunk()
assert(type(makeWindow) == "function", "N3Z: compat source did not return a function")

local activeModuleFn = nil
if activeMod then
    local moduleSrc = fetch(activeMod.file, activeMod.file)
    local moduleChunk, moduleLoadErr = loadstring(moduleSrc, "@" .. activeMod.id)
    assert(moduleChunk, "N3Z: failed to compile module " .. activeMod.id .. ": " .. tostring(moduleLoadErr))

    local okFactory, factoryOrErr = pcall(moduleChunk)
    assert(okFactory, "N3Z: failed to prepare module " .. activeMod.id .. ": " .. tostring(factoryOrErr))
    assert(type(factoryOrErr) == "function", "N3Z: module did not return function(Window, ctx)")
    activeModuleFn = factoryOrErr

    if type(activeMod.coreFile) == "string" then
        loadModuleFile(activeMod.coreFile)
    end
    if type(activeMod.platformFiles) == "table" then
        local platformFile = activeMod.platformFiles[isMobile and "mobile" or "pc"]
        if type(platformFile) == "string" then
            loadModuleFile(platformFile)
        end
    end
    if activeMod.legacyPlatform == true then
        loadModuleFile("modules/_shared/legacy_platform.lua")
        loadModuleFile("modules/_shared/visual_occlusion.lua")
    elseif activeMod.visualOcclusion == true then
        loadModuleFile("modules/_shared/visual_occlusion.lua")
    end
    for _, dependencyFile in ipairs(activeMod.dependencyFiles or {}) do
        loadModuleFile(dependencyFile)
    end
end

-- ---------- env ----------
local env = (type(getgenv) == "function" and getgenv()) or _G

-- destroy previous instance (clean re-execute)
if type(env.__N3Z_WINDOW) == "table" and type(env.__N3Z_WINDOW.Destroy) == "function" then
    pcall(function() env.__N3Z_WINDOW:Destroy() end)
end
env.__N3Z_WINDOW = nil

-- sweep orphan N3zDock guis (covers case where __N3Z_WINDOW was lost)
pcall(function() Dock.destroyAllGuis() end)

-- ---------- build ----------
local dock = Dock.new({ menuKey = Enum.KeyCode.K })
local Window = makeWindow(dock)
env.__N3Z_WINDOW = Window
-- NOTE: __RAVEN_WINDOW alias is set AFTER the module loads (see below).
-- Old modules destroy getgenv().__RAVEN_WINDOW on load; setting it before
-- loadstring would make the module kill the window we just built.

local gameName = activeMod and activeMod.game or tostring(game.Name)
local modLine = (activeMod and activeMod.version or "no module")
local configFolderName = activeMod and (activeMod.configName or activeMod.name or activeMod.id)
    or ("Game" .. tostring(placeId))
local configStore = createConfigStore(configFolderName)
Window:SetConfigStore(configStore)

local savedBlockInput = configStore:Ensure("__hub.BlockGameInput", false)
dock:SetInputBlockEnabled(savedBlockInput == true)

local savedMenuKeyName = configStore:Ensure("__hub.MenuKey", "K")
local savedMenuKey = nil
if type(savedMenuKeyName) == "string" then
    pcall(function() savedMenuKey = Enum.KeyCode[savedMenuKeyName] end)
end
if typeof(savedMenuKey) ~= "EnumItem" then savedMenuKey = Enum.KeyCode.K end
dock:SetMenuKey(savedMenuKey)
dock:SetMenuKeyChangedCallback(function(keyCode)
    if typeof(keyCode) == "EnumItem" then
        configStore:Set("__hub.MenuKey", keyCode.Name)
    end
end)
dock:SetHeader(gameName, "place " .. tostring(placeId) .. " - " .. localPlayer.Name, modLine)
dock:SetMenuKeyName(isMobile and "TAP" or savedMenuKey.Name)

if isMobile then
    local toggleX = tonumber(configStore:Ensure("__hub.MobileToggleX", 0.92)) or 0.92
    local toggleY = tonumber(configStore:Ensure("__hub.MobileToggleY", 0.12)) or 0.12
    dock:SetMobileTogglePosition(toggleX, toggleY)
    dock:SetMobileToggleChangedCallback(function(x, y)
        x = math.floor((tonumber(x) or 0.92) * 10000 + 0.5) / 10000
        y = math.floor((tonumber(y) or 0.12) * 10000 + 0.5) / 10000
        configStore:Set("__hub.MobileToggleX", x)
        configStore:Set("__hub.MobileToggleY", y)
    end)
end

-- avatar (async, never blocks boot)
task.spawn(function()
    local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(
            localPlayer.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size100x100
        )
    end)
    if ok and type(content) == "string" and content ~= "" then
        dock:SetAvatar(content)
    end
end)

-- ---------- MODULES tab: cards from registry ----------
for _, m in ipairs(MODULES) do
    local isActive = (m == activeMod)
    dock:AddRow("modules", {
        kind = "modulecard",
        name = m.name,
        sub = m.version .. " - " .. (isActive and ("matched: " .. m.game) or "not in this game"),
        active = isActive,
    })
end

-- ---------- SETTINGS tab ----------
local profileName = configStore.path
if isMobile then
    dock:AddRow("settings", {
        kind = "action",
        name = "Mobile Menu",
        desc = "Use the floating N3Z button anywhere, or tap the active tab to collapse the panel",
        buttonText = "TOGGLE",
        onPress = function() dock:Toggle() end,
    })
    dock:AddRow("settings", {
        kind = "action",
        name = "Reset Mobile Button",
        desc = "Move the floating N3Z button back to its default position",
        buttonText = "RESET",
        onPress = function()
            dock:SetMobileTogglePosition(0.92, 0.12)
            configStore:Set("__hub.MobileToggleX", 0.92)
            configStore:Set("__hub.MobileToggleY", 0.12)
        end,
    })
else
    dock:AddRow("settings", {
        kind = "action", name = "Menu Toggle Key", desc = "Press this row, then press a key to change the menu hotkey",
        chip = savedMenuKey.Name, rebindKey = true,
    })
end
dock:AddRow("settings", {
    kind = "action", name = "Config Profile", desc = profileName,
    chip = "EDIT", clipboard = profileName,
})

dock:AddRow("settings", {
    kind = "toggle",
    name = "Block Game Input",
    desc = "Block mouse / touch input from reaching the game while a menu tab is open",
    value = dock:IsInputBlockEnabled(),
    onChange = function(v)
        dock:SetInputBlockEnabled(v)
        configStore:Set("__hub.BlockGameInput", v == true)
    end,
})

local moduleCleanups = {}
local moduleCleanupSet = {}

local function registerModuleCleanup(fn)
    if type(fn) ~= "function" or moduleCleanupSet[fn] then return end
    moduleCleanupSet[fn] = true
    moduleCleanups[#moduleCleanups + 1] = fn
end

local unloadAll
local unloadDone = false
unloadAll = function()
    if unloadDone then return end
    unloadDone = true

    -- Make the menu disappear before any module cleanup runs. Cleanup may
    -- yield/error internally, but the hub itself should already be gone.
    pcall(function() dock:SetVisible(false) end)

    local calledCleanups = {}
    local function runCleanup(fn)
        if type(fn) ~= "function" or calledCleanups[fn] then return end
        calledCleanups[fn] = true
        pcall(fn)
    end

    local moduleHandle = activeMod and activeMod.envKey and env[activeMod.envKey] or nil
    if type(moduleHandle) == "table" then
        runCleanup(moduleHandle.Destroy)
        runCleanup(moduleHandle.destroy)
    end
    for i = #moduleCleanups, 1, -1 do
        runCleanup(moduleCleanups[i])
    end
    table.clear(moduleCleanups)
    table.clear(moduleCleanupSet)

    env.__N3Z_WINDOW = nil
    env.__RAVEN_WINDOW = nil

    pcall(function() Window:Destroy() end)
    pcall(function() Dock.destroyAllGuis() end)

    -- One deferred sweep catches a GUI that was still inside its click event
    -- when the first destroy ran.
    task.defer(function()
        pcall(function() Dock.destroyAllGuis() end)
    end)
end

dock:AddRow("settings", {
    kind = "action", name = "Unload Module", desc = "Clean teardown of module & dock",
    buttonText = "UNLOAD", danger = true, onPress = unloadAll,
})
dock:SetTabInfo("modules", #MODULES .. " modules · " .. (activeMod and "1 ACTIVE" or "none in this game"))
dock:SetTabInfo("settings", "settings")

-- ---------- load the preflighted game module ----------
if activeMod then
    local ctx = {
        game = activeMod.game,
        placeId = placeId,
        gameId = gameId,
        module = activeMod,
        dock = dock,
        platform = isMobile and "mobile" or "pc",
        loadModuleFile = loadModuleFile,
        registerCleanup = registerModuleCleanup,
        hubUI = Window,
        hubRayfield = Window,
        hubSettingsTab = Window:GetTab("Settings"),
    }
    local ok, moduleResult = pcall(activeModuleFn, Window, ctx)
    local runErr = ok and nil or moduleResult
    if ok and type(moduleResult) == "table" then
        registerModuleCleanup(moduleResult.Destroy)
        registerModuleCleanup(moduleResult.destroy)
    end
    if not ok then
        local message = tostring(runErr or "unknown module error")
        warn("[N3Z] module error: " .. message)

        -- Never leave a half-built/blank module page behind. Clear any rows
        -- created before the exception and surface the failure in the dock.
        pcall(function()
            dock:ClearRows("combat")
            dock:ClearRows("visuals")

            local short = message:gsub("[%c]+", " ")
            if #short > 300 then
                short = short:sub(1, 300) .. "..."
            end

            dock:AddRow("combat", {
                kind = "label",
                text = "Module failed to start.\n" .. short,
            })
            dock:AddRow("visuals", {
                kind = "label",
                text = "Module failed to start. Check Combat for details.",
            })
            dock:SetTabInfo("combat", "module error")
            dock:SetTabInfo("visuals", "module error")
        end)
    end
else
    if isMobile then
        dock:AddRow("visuals", { kind = "label", text = "No module for this game yet." })
    else
        dock:AddRow("modules", { kind = "label", text = "No module for this game yet." })
    end
end

-- Desktop: drop primary tabs the module never filled (e.g. COMBAT/VISUALS in
-- a game that only registers its own tabs). Decided from real page content
-- after module init; error rows above count as content and are kept.
-- MODULES and SETTINGS always stay. Mobile tab bar is intentionally untouched.
if not isMobile then
    pcall(function() dock:PruneEmptyTabs({ "modules", "settings" }) end)
end

-- compat alias for old modules (set after load so the module's own
-- startup cleanup can't destroy the window we just built)
env.__RAVEN_WINDOW = Window

-- First run writes one complete per-game config. Later UI changes autosave.
pcall(function() configStore:Flush() end)


-- boot: dock bar only. The panel opens when the user picks a tab.
return Window
