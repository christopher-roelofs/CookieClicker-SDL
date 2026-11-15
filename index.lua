-- Cookie Clicker SDL Port (from Vita version)
-- Gamepad controls optimized for 640x480 resolution
-- Converted from Vita touch controls to gamepad navigation

-- Save encryption configuration (set to true to encrypt save files)
local ENCRYPT_SAVE = false

Graphics.init()

-- Load CryptLib for save encryption support
dofile("libs/CryptLib.lua")

-- Initialize game controllers for SDL gamepad support
if Controls.init then
    Controls.init()
end

-- Target 640x480 resolution with responsive scaling
local screenW, screenH = 640, 480

-- Try to set window size if the function exists (native SDL mode only)
if Graphics.setMode then
    Graphics.setMode(screenW, screenH)
elseif Window and Window.setSize then
    Window.setSize(screenW, screenH)
elseif Screen and Screen.setMode then
    Screen.setMode(screenW, screenH)
end

-- If none of the above work, check for actual screen size
if Screen and Screen.getWidth then
    local actualW = Screen.getWidth()
    local actualH = Screen.getHeight()
    if actualW and actualW > 0 then
        screenW = actualW
        screenH = actualH
    end
end

-- Calculate scale factor for responsive design (640x480 as base resolution)
local BASE_WIDTH = 640
local BASE_HEIGHT = 480
local scaleX = screenW / BASE_WIDTH
local scaleY = screenH / BASE_HEIGHT
local scale = math.min(scaleX, scaleY) -- Use smaller scale to maintain aspect ratio

-- Apply reasonable scaling limits
scaleX = math.max(0.5, math.min(4.0, scaleX))
scaleY = math.max(0.5, math.min(4.0, scaleY))
scale = math.max(0.5, math.min(4.0, scale))

-- Debug: Print scaling information
print(string.format("Cookie Clicker SDL Scaling: %dx%d -> scaleX=%.2f, scaleY=%.2f, scale=%.2f", 
                   screenW, screenH, scaleX, scaleY, scale))

-- Large number formatting from Vita version
local NAMEOMBTQ={"Million", "Billion", "Trillion", "Quadrillion", "Quintillion", "Sextillion", "Septillion", "Octillion", "Nonillion", "Decillion", "Undecillion", "Duodecillion", "Tredecillion", "Quattuordecillion", "Quindecillion", "Sexdecillion", "Septendecillion", "Octodecillion", "Novemdecillion", "Vigintillion"}

-- Colors (from Vita version)
local white = Color.new(255,255,255)
local black = Color.new(0,0,0)
local gray = Color.new(128,128,128)
local blue = Color.new(80,80,255)
local red = Color.new(255,80,80)
local transred = Color.new(255,80,80,80)
local trans150red = Color.new(255,80,80,150)
local green = Color.new(80,255,80)
local transwhite = Color.new(255,255,255,150)
local trans100white = Color.new(255,255,255,100)

-- UI Layout for 640x480 (2-panel design like 3DS version)
-- Left panel: Buildings (60% of screen)
-- Right panel: Cookie + Store (40% of screen)
local BASE_LEFT_WIDTH = 384  -- Buildings panel (60% of 640)
local BASE_RIGHT_WIDTH = 256  -- Cookie + Store panel (40% of 640)

-- Apply scaling with minimum sizes
local PANEL_LEFT_WIDTH = math.max(320, math.floor(BASE_LEFT_WIDTH * scaleX))
local PANEL_RIGHT_WIDTH = screenW - PANEL_LEFT_WIDTH

-- Ensure right panel has minimum width for usability
if PANEL_RIGHT_WIDTH < 220 then
    PANEL_LEFT_WIDTH = screenW - 220
    PANEL_RIGHT_WIDTH = 220
end

-- Panel positions
local PANEL_LEFT_X = 0
local PANEL_RIGHT_X = PANEL_LEFT_WIDTH

-- Right panel subdivisions  
local COOKIE_AREA_HEIGHT = math.floor(screenH * 0.40)  -- Reduced to 40% for cookie
local STORE_AREA_HEIGHT = screenH - COOKIE_AREA_HEIGHT  -- Bottom 60% for store + upgrades

-- Cookie position (centered in right panel top area)
local CENTER_OF_COOKIE_X = PANEL_RIGHT_X + PANEL_RIGHT_WIDTH / 2
local CENTER_OF_COOKIE_Y = math.floor(COOKIE_AREA_HEIGHT / 2) + math.floor(20 * scaleY)

-- Header and store positioning
local HEADER_HEIGHT = math.floor(30 * scaleY)
local UPGRADE_HEIGHT = math.floor(70 * scaleY)  -- Reduced space for upgrade frames
local STORE_START_Y = COOKIE_AREA_HEIGHT + HEADER_HEIGHT + UPGRADE_HEIGHT

-- Game state variables
local gameState = "Title"  -- "Title", "Game", "Controls", "Settings", "About", "Statistics"
local version = "version 1.0"

-- Menu state
local MenuState = {
    selectedIndex = 1,
    options = {"Start", "Settings", "Controls", "Statistics", "About", "Exit"},
    optionCount = 6
}

-- Check if save file exists and update menu
if System.doesFileExist("data/ccsave.sav") then
    MenuState.options[1] = "Continue"
end

-- Game objects (converted from Vita structure)
local Building = {}
local Button = {}
local Cookie = {
    shower = {}
}
local CookiePerSecond = {}
local Cursor = {}
local Panel = {}
local Price = {}
local ScreenB = {}
local Shine = {}
local SpdOf = {}
local Texture = {}
local Upgrade = {
    Now = {}
}
local Game = {}
local Milk = {}

-- Game session statistics
Game.startTime = 0
Game.totalPlayTime = 0
Game.sessionStart = 0
Game.longestSession = 0
Game.totalBuildings = 0
Game.totalUpgrades = 0

-- Audio settings
local AudioSettings = {
    bgMusicEnabled = true,
    bgMusicVolume = 0.7,  -- 0.0 to 1.0
    sfxEnabled = true,
    sfxVolume = 0.8,      -- 0.0 to 1.0
    isPlaying = false
}

-- Visual settings
local VisualSettings = {
    cookieShowerEnabled = true,
    milkAnimationEnabled = true
}

-- Control settings
local ControlSettings = {
    mode = "Keyboard",  -- "Keyboard" or "Gamepad"
    gamepadEnabled = false
}

-- Settings navigation
local SettingsState = {
    selectedIndex = 1,
    options = {"Background Music", "Music Volume", "Sound Effects", "Effects Volume",
               "Cookie Shower", "Milk Animation", "Reset Game"},
    optionCount = 7
}

-- SDL Control state (simplified for 2-panel layout)
local GamepadState = {
    currentPanel = "Store",  -- "Store", "Buildings"
    selectedIndex = 1,
    purchaseQuantity = 1,    -- 1, 10, 100
    buyMode = true,          -- true = buy, false = sell
    scrollOffset = 0
}

-- Scaled UI positions for 2-panel layout
Button.default = STORE_START_Y + math.floor(10 * scaleY)
Button.tmp = 0
Button.quantity = 2
Button.x = PANEL_RIGHT_X + math.floor(10 * scaleX)  -- Store panel position
Button.y = Button.default
Button.defaulttemp = Button.default

Building.default = HEADER_HEIGHT + math.floor(10 * scaleY)
Building.x = PANEL_LEFT_X + math.floor(10 * scaleX)   -- Buildings panel position
Building.y = Building.default

Cookie.count = 0
Cookie.total = 0
Cookie.size = 0
Cookie.tmp = 0
Cookie.speed = 0.1
Cookie.shower.speed = 1

-- New statistics tracking
Cookie.clicked = 0          -- Total cookies earned from clicks
Cookie.clickCount = 0       -- Total number of clicks made
Cookie.maxCpS = 0          -- Maximum CpS achieved
Cookie.totalSpent = 0      -- Total cookies spent on buildings/upgrades
Cookie.shower.y = 0

Cursor.rot = 0
Cursor.speed = -0.0025
Cursor.max = 30

Panel.kolvo = 1
Panel.state = "Buy"
Panel.tmp = 0

Shine.rot = 0
Shine.speed = 0.008

SpdOf.framerate = 60
SpdOf.tmp = 0
SpdOf.cmn = 0

Upgrade.default = Button.default
Upgrade.tmp = 0
Upgrade.mode = 1

Milk.y = math.floor(464 * scaleY)
Milk.x = 0
Milk.speed = 0.8

Game.state = "Normal"

local pi = math.pi
local oldpad = Controls.read()  -- Initialize with proper Controls value instead of 0
-- Gamepad state tracking for edge detection
local gamepadState = {
    A_prev = false,
    X_prev = false,
    B_prev = false,
    Y_prev = false,
    L_prev = false,
    R_prev = false,
    Start_prev = false,
    DPadUp_prev = false,
    DPadDown_prev = false,
    DPadLeft_prev = false,
    DPadRight_prev = false
}

-- Timer setup
local timer = Timer.new()
local navTimer = Timer.new()
local buttonTimer = Timer.new()
local cookieTimer = Timer.new()
local autosaveTimer = Timer.new()
local AUTOSAVE_DELAY = 30000  -- milliseconds between autosaves while playing
local NAV_DELAY = 150  -- milliseconds between navigation inputs
local BUTTON_DELAY = 100  -- milliseconds between button presses
local COOKIE_DELAY = 50   -- milliseconds between cookie clicks (faster for better feel)

-- Load images (adjusted paths for SDL structure)
if System.currentDirectory() == "/" then
    System.currentDirectory("romfs:/")
end

local assetPath = System.currentDirectory().."/assets/"

-- Essential images
local Cookie_img = Graphics.loadImage(assetPath.."cookie.png")
local Shine_img = Graphics.loadImage(assetPath.."shine.png")
local Icons_img = Graphics.loadImage(assetPath.."icons.png")
local Cursor_img = Graphics.loadImage(assetPath.."cursor.png")
local Background_img = Graphics.loadImage(assetPath.."background.png")
local Darkback_img = Graphics.loadImage(assetPath.."darkback.png")
local ShadedBorders_img = Graphics.loadImage(assetPath.."shadedBorders.png")
local Milk_img = Graphics.loadImage(assetPath.."milk.png")

-- Building and UI images
local BLDBacks_img = Graphics.loadImage(assetPath.."BLDBacks.png")
local BLDIcons_img = Graphics.loadImage(assetPath.."BLDIcons.png")
local StoreTile_img = Graphics.loadImage(assetPath.."storeTile.jpg")
local PressedTile_img = Graphics.loadImage(assetPath.."pressedTile.png")
local UpgradeFrame_img = Graphics.loadImage(assetPath.."upgradeFrame.png")

-- Cookie shower effects
local CookieShower1_img = Graphics.loadImage(assetPath.."cookieShower1.png")
local CookieShower2_img = Graphics.loadImage(assetPath.."cookieShower2.png")
local CookieShower3_img = Graphics.loadImage(assetPath.."cookieShower3.png")

-- Panel separator images
local PanelVertical_img = Graphics.loadImage(assetPath.."panelVertical.png")
local PanelHorizontal_img = Graphics.loadImage(assetPath.."panelHorizontal.png")

-- Gradient images for polish
local PanelGradientLeft_img = Graphics.loadImage(assetPath.."panelGradientLeft.png")
local PanelGradientRight_img = Graphics.loadImage(assetPath.."panelGradientRight.png")
local PanelGradientTop_img = Graphics.loadImage(assetPath.."panelGradientTop.png")
local PanelGradientBottom_img = Graphics.loadImage(assetPath.."panelGradientBottom.png")

-- Store button images
local Buildings_img = Graphics.loadImage(assetPath.."buildings.png")
local Favicon_img = Graphics.loadImage(assetPath.."favicon.png")

-- Title screen images
local Banner_img = Graphics.loadImage(assetPath.."banner.png")
local LppSDL_img = Graphics.loadImage(assetPath.."lppsdl.png")

-- Initialize audio subsystem
Sound.init()

-- Audio files
local bgMusic = nil
if System.doesFileExist(assetPath.."bgm.ogg") then
    bgMusic = Sound.open(assetPath.."bgm.ogg")
end

-- Sound effects (made by tools/make_sfx.py)
local Sfx = {}
for _, name in ipairs({"click1", "click2", "click3", "buy", "sell", "upgrade", "denied",
                       "nav", "select", "back"}) do
    local path = assetPath.."sfx_"..name..".wav"
    if System.doesFileExist(path) then
        Sfx[name] = Sound.open(path)
    end
end
local clickVariant = 0

function playSfx(name)
    if not AudioSettings.sfxEnabled then return end
    -- Rotate through the click variants so fast clicking overlaps instead of cutting off
    if name == "click" then
        clickVariant = clickVariant % 3 + 1
        name = "click" .. clickVariant
    end
    if Sfx[name] then
        Sound.play(Sfx[name], false)
    end
end

function updateSfxVolume()
    local volume = math.floor(AudioSettings.sfxVolume * 32767)
    for _, sound in pairs(Sfx) do
        Sound.setVolume(sound, volume)
    end
end

-- Store textures in table for easy access
Texture = {
    ["BLDBacks"] = BLDBacks_img,
    ["BLDIcons"] = BLDIcons_img,
    ["Cookie"] = Cookie_img,
    ["Shine"] = Shine_img,
    ["Icons"] = Icons_img,
    ["Cursor"] = Cursor_img,
    ["Background"] = Background_img,
    ["Darkback"] = Darkback_img,
    ["ShadedBorders"] = ShadedBorders_img,
    ["Milk"] = Milk_img,
    ["StoreTile"] = StoreTile_img,
    ["PressedTile"] = PressedTile_img,
    ["UpgradeFrame"] = UpgradeFrame_img,
    ["CookieShower1"] = CookieShower1_img,
    ["CookieShower2"] = CookieShower2_img,
    ["CookieShower3"] = CookieShower3_img,
    ["panelVertical"] = PanelVertical_img,
    ["panelHorizontal"] = PanelHorizontal_img,
    ["panelGradientLeft"] = PanelGradientLeft_img,
    ["panelGradientRight"] = PanelGradientRight_img,
    ["panelGradientTop"] = PanelGradientTop_img,
    ["panelGradientBottom"] = PanelGradientBottom_img,
    ["Buildings"] = Buildings_img,
    ["Favicon"] = Favicon_img,
    ["Banner"] = Banner_img,
    ["LppSDL"] = LppSDL_img
}

-- Font system (inline from Vita libs/Font.lua)
local glyph_l = {}
local glyph_r = {}
local glyph_w = {}

function g_init(char, l, r)
    glyph_l[char] = l
    glyph_r[char] = r
    glyph_w[char] = r-l+1
end

-- Initialize font glyphs
g_init('0',414,430)
g_init('1',431,439)
g_init('2',440,454)
g_init('3',455,468)
g_init('4',469,483)
g_init('5',484,497)
g_init('6',498,512)
g_init('7',512,525)
g_init('8',526,540)
g_init('9',541,554)
g_init('A',1,19)
g_init('B',20,35)
g_init('C',36,52)
g_init('D',53,70)
g_init('E',71,84)
g_init('F',85,98)
g_init('G',99,116)
g_init('H',117,133)
g_init('I',134,139)
g_init('J',140,148)
g_init('K',149,164)
g_init('L',165,177)
g_init('M',178,196)
g_init('N',197,213)
g_init('O',214,232)
g_init('P',233,248)
g_init('Q',249,268)
g_init('R',269,284)
g_init('S',285,296)
g_init('T',297,310)
g_init('U',311,327)
g_init('V',328,344)
g_init('W',345,367)
g_init('X',368,383)
g_init('Y',384,399)
g_init('Z',400,413)
g_init('.',562,568)
g_init(' ',580,581)
g_init(':',555,561)
g_init('-',569,580)

-- Load fonts
local defaultFont = Font.load()
local smallFont = Font.load()
local titleFont = Font.load()

-- Set font sizes
-- Sizes follow the screen (16/12/32 px at 640x480), with a floor so text
-- stays legible on small screens
local FONT_SIZE = math.max(11, math.floor(16 * scale + 0.5))
local SMALL_FONT_SIZE = math.max(9, math.floor(12 * scale + 0.5))
local TITLE_FONT_SIZE = math.max(20, math.floor(32 * scale + 0.5))
if Font.setPixelSizes then
    Font.setPixelSizes(titleFont, TITLE_FONT_SIZE)
    Font.setPixelSizes(defaultFont, FONT_SIZE)
    Font.setPixelSizes(smallFont, SMALL_FONT_SIZE)
end

-- Use default LPP-SDL fonts instead of PNG fonts
function drawText(x, y, text, color)
    Font.print(defaultFont, x, y, text, color)
end

-- Small text function for prices
function drawSmallText(x, y, text, color)
    Font.print(smallFont, x, y, text, color)
end

-- Title text function for large text
function drawTitleText(x, y, text, color)
    Font.print(titleFont, x, y, text, color)
end

-- UI colours
local gold = Color.new(255, 210, 90)
local grey = Color.new(170, 170, 170)
local menuIdle = Color.new(185, 205, 220)
local selectBar = Color.new(0, 0, 0, 110)

-- Smooth scroll positions for the two lists
BuildingView = { scroll = 0 }
StoreView = { scroll = 0 }

function textWidth(font, text)
    if Font.getTextWidth then
        return Font.getTextWidth(font, text)
    end
    return string.len(text) * 8
end

function drawCentered(font, y, text, color)
    Font.print(font, math.floor((screenW - textWidth(font, text)) / 2), y, text, color)
end

-- Outline a rectangle with a border of the given thickness
function drawFrame(x, y, w, h, t, color)
    Graphics.fillRect(x, x + w, y, y + t, color)
    Graphics.fillRect(x, x + w, y + h - t, y + h, color)
    Graphics.fillRect(x, x + t, y, y + h, color)
    Graphics.fillRect(x + w - t, x + w, y, y + h, color)
end

-- Button hints along the bottom of the screen: {{"A", "Select"}, {"B", "Back"}}
function drawHints(hints)
    local gap = math.floor(18 * scaleX)
    local parts = {}
    local total = 0
    for i, hint in ipairs(hints) do
        local keyW = textWidth(smallFont, hint[1])
        local labelW = textWidth(smallFont, hint[2])
        parts[i] = {keyW, labelW}
        total = total + keyW + 6 + labelW + (i > 1 and gap or 0)
    end
    local x = math.floor((screenW - total) / 2)
    local y = screenH - math.floor(22 * scaleY)
    for i, hint in ipairs(hints) do
        if i > 1 then x = x + gap end
        drawSmallText(x, y, hint[1], gold)
        x = x + parts[i][1] + 6
        drawSmallText(x, y, hint[2], white)
        x = x + parts[i][2]
    end
end

-- Centred vertical menu with a bar behind the selected entry
function drawMenuList(state, top, spacing)
    local widest = 0
    for i = 1, state.optionCount do
        widest = math.max(widest, textWidth(defaultFont, state.options[i]))
    end
    local barHalf = math.floor(widest / 2) + math.floor(24 * scaleX)
    for i = 1, state.optionCount do
        local option = state.options[i]
        local y = top + (i - 1) * spacing
        if i == state.selectedIndex then
            Graphics.fillRect(screenW/2 - barHalf, screenW/2 + barHalf, y - 3, y + spacing - 5, selectBar)
            drawCentered(defaultFont, y, option, white)
        else
            drawCentered(defaultFont, y, option, menuIdle)
        end
    end
end

-- Number formatting for cookie counts (whole numbers, no abbreviations)
-- Short-scale number with 3 significant digits: 1.17 T, 16.4 Qa, 199 Sx
local SHORT_SUFFIX = {"K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
                      "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg"}
function shortNumber(num)
    if num < 1000 then
        return string.format("%d", math.floor(num))
    end
    local tier = math.min(math.floor(math.log10(num) / 3), #SHORT_SUFFIX)
    local scaled = num / 10 ^ (tier * 3)
    local text
    if scaled >= 100 then
        text = string.format("%d", math.floor(scaled))
    elseif scaled >= 10 then
        text = string.format("%.1f", math.floor(scaled * 10) / 10)
    else
        text = string.format("%.2f", math.floor(scaled * 100) / 100)
    end
    if text:find("%.") then
        text = text:gsub("0+$", ""):gsub("%.$", "")
    end
    return text .. " " .. SHORT_SUFFIX[tier]
end

function formatCookieCount(num)
    num = math.floor(num)
    if num < 1000000 then
        return string.format("%d", num)
    end
    return shortNumber(num)
end

-- Number formatting function for CPS (keeps decimal precision)
function formatCPS(num)
    if num < 1000 then
        return string.format("%.1f", num)
    end
    return shortNumber(num)
end

-- Number formatting function for other values (prices, etc.)
function formatNumber(num)
    return shortNumber(math.ceil(num))
end

-- Time formatting function (converts seconds to readable format)
function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%d:%02d", minutes, secs)
    end
end

-- Audio management functions
function startBackgroundMusic()
    if bgMusic and AudioSettings.bgMusicEnabled and not AudioSettings.isPlaying then
        -- Convert 0.0-1.0 volume to 0-32767 range for LPP-SDL
        local lppVolume = math.floor(AudioSettings.bgMusicVolume * 32767)
        Sound.setVolume(bgMusic, lppVolume)
        
        -- Always start fresh to ensure looping works
        Sound.play(bgMusic, true)  -- true for looping
        AudioSettings.isPlaying = true
    end
end

function stopBackgroundMusic()
    if bgMusic and AudioSettings.isPlaying then
        Sound.pause(bgMusic)
        AudioSettings.isPlaying = false
    end
end

function updateMusicVolume()
    if bgMusic and AudioSettings.isPlaying then
        -- Convert 0.0-1.0 volume to 0-32767 range for LPP-SDL
        local lppVolume = math.floor(AudioSettings.bgMusicVolume * 32767)
        Sound.setVolume(bgMusic, lppVolume)
    end
end

function toggleBackgroundMusic()
    AudioSettings.bgMusicEnabled = not AudioSettings.bgMusicEnabled
    if AudioSettings.bgMusicEnabled then
        startBackgroundMusic()
    else
        stopBackgroundMusic()
    end
end

function checkMusicLoop()
    -- Check if music should be playing but has stopped, restart it
    if bgMusic and AudioSettings.bgMusicEnabled and AudioSettings.isPlaying then
        if not Sound.isPlaying(bgMusic) then
            -- Music stopped, restart it
            AudioSettings.isPlaying = false
            startBackgroundMusic()
        end
    end
end

-- Button creation system (from Vita version)
function Button.make(name, fprice, id, cps)
    Button[name.."id"] = id
    Button[name.."fprice"] = fprice
    Button[name.."price"] = fprice
    Button[name.."count"] = 0
    Button[name.."cps"] = cps
    Button[name.."A"] = 0
    Button[name.."total"] = 0          -- Total ever purchased
    Button[name.."produced"] = 0       -- Total cookies produced by this building type
    Button[name.."spent"] = 0          -- Total spent on this building type
    Button[#Button + 1] = name
end

-- Upgrade system (from Vita version)
function Upgrade.make(name, id, count, price, column, row)
    local upgradeName = name..id
    Upgrade[upgradeName.."id"] = id
    Upgrade[upgradeName.."name"] = name
    Upgrade[upgradeName.."count"] = count
    Upgrade[upgradeName.."price"] = price
    Upgrade[upgradeName.."column"] = column
    Upgrade[upgradeName.."row"] = row
    Upgrade[upgradeName.."a"] = 0
    Upgrade[name.."Quan"] = 1
    Upgrade[#Upgrade + 1] = upgradeName
end

-- Initialize all buildings (from Vita version)
Button.make("Cursor", 15, 1, 0.1)
Button.make("Grandma", 100, 2, 1)
Button.make("Farm", 1000, 4, 8)
Button.make("Mine", 12000, 5, 47)
Button.make("Factory", 130000, 6, 260)
Button.make("Bank", 1400000, 7, 1400)
Button.make("Temple", 20000000, 8, 7800)
Button.make("WizardTower", 330000000, 9, 44000)
Button.make("Shipment", 5100000000, 10, 260000)
Button.make("AlchemyLab", 75000000000, 11, 1600000)
Button.make("Portal", 1000000000000, 12, 10000000)
Button.make("TimeMachine", 14000000000000, 13, 65000000)
Button.make("AntimatterCondenser", 170000000000000, 14, 430000000)
Button.make("Prism", 2100000000000000, 15, 2900000000)

-- Initialize Building list (for display order)
Building[1] = "Cursor"
Building[2] = "Grandma"
Building[3] = "Farm"
Building[4] = "Mine"
Building[5] = "Factory"
Building[6] = "Bank"
Building[7] = "Temple"
Building[8] = "WizardTower"
Building[9] = "Shipment"
Building[10] = "AlchemyLab"
Building[11] = "Portal"
Building[12] = "TimeMachine"
Building[13] = "AntimatterCondenser"
Building[14] = "Prism"

-- Save game function (plain text for easy testing)
function saveGame()
    -- Create save string with all game data
    local saveData = {}
    
    -- Save cookie data
    table.insert(saveData, tostring(Cookie.count))
    table.insert(saveData, tostring(Cookie.total))
    
    -- Save building counts
    for i = 1, #Building do
        local building = Building[i]
        table.insert(saveData, tostring(Button[building.."count"] or 0))
    end
    
    -- Save upgrade states
    for i = 1, #Upgrade do
        table.insert(saveData, tostring(Upgrade[Upgrade[i].."a"] or 0))
    end
    
    -- Save statistics
    table.insert(saveData, tostring(Cookie.clicked))
    table.insert(saveData, tostring(Cookie.clickCount))
    table.insert(saveData, tostring(Cookie.maxCpS))
    table.insert(saveData, tostring(Cookie.totalSpent))
    table.insert(saveData, tostring(Game.totalPlayTime))
    table.insert(saveData, tostring(Game.longestSession))
    table.insert(saveData, tostring(Game.totalBuildings))
    table.insert(saveData, tostring(Game.totalUpgrades))
    
    -- Save building production and spending stats
    for i = 1, #Building do
        local building = Building[i]
        table.insert(saveData, tostring(Button[building.."total"] or 0))
        table.insert(saveData, tostring(Button[building.."produced"] or 0))
        table.insert(saveData, tostring(Button[building.."spent"] or 0))
    end
    
    -- Save audio settings
    table.insert(saveData, tostring(AudioSettings.bgMusicEnabled and 1 or 0))
    table.insert(saveData, tostring(AudioSettings.bgMusicVolume))
    
    -- Save visual settings
    table.insert(saveData, tostring(VisualSettings.cookieShowerEnabled and 1 or 0))
    table.insert(saveData, tostring(VisualSettings.milkAnimationEnabled and 1 or 0))
    
    -- Save control settings
    table.insert(saveData, tostring(ControlSettings.gamepadEnabled and 1 or 0))

    -- Save sound effect settings
    table.insert(saveData, tostring(AudioSettings.sfxEnabled and 1 or 0))
    table.insert(saveData, tostring(AudioSettings.sfxVolume))
    
    -- Join with # delimiter like Vita version
    local saveString = table.concat(saveData, "#")
    
    -- Encrypt if enabled
    if ENCRYPT_SAVE then
        saveString = Encrypt(saveString, "cookieclickerkey")
    end
    
    -- Use LPP-SDL file I/O
    local savefile = io.open("data/ccsave.sav", FCREATE)
    if savefile then
        local saveStringLen = string.len(saveString)
        io.write(savefile, 0, saveString, saveStringLen)
        io.close(savefile)
        print("Game saved" .. (ENCRYPT_SAVE and " (encrypted)" or "") .. "!")
        return true
    end
    return false
end

-- Load game function
function loadGame()
    -- Check if save file exists first
    if not System.doesFileExist("data/ccsave.sav") then
        return false
    end
    
    -- Use LPP-SDL file I/O
    local savefile = io.open("data/ccsave.sav", FREAD)
    if savefile then
        local size = io.size(savefile)
        local saveString = io.read(savefile, 0, size)
        io.close(savefile)
        
        -- Try to decrypt if it looks encrypted (doesn't contain # delimiter)
        local isEncrypted = not string.find(saveString, "#")
        if isEncrypted or ENCRYPT_SAVE then
            local decrypted = Decrypt(saveString, "cookieclickerkey")
            -- Check if decryption was successful (should contain # delimiter)
            if decrypted and string.find(decrypted, "#") then
                saveString = decrypted
                print("Save file decrypted successfully")
            elseif isEncrypted then
                -- File appears encrypted but couldn't decrypt - delete corrupt save
                print("Could not decrypt save file - removing corrupt save")
                System.deleteFile("data/ccsave.sav")
                return false
            end
        end
        
        -- Split save string by # delimiter
        local saveData = {}
        for value in string.gmatch(saveString, "([^#]+)") do
            table.insert(saveData, value)
        end
        
        if #saveData >= 2 then
            -- Load cookie data
            Cookie.count = tonumber(saveData[1]) or 0
            Cookie.total = tonumber(saveData[2]) or 0
            
            -- Load building data
            local index = 3
            for i = 1, #Building do
                if saveData[index] then
                    local building = Building[i]
                    Button[building.."count"] = tonumber(saveData[index]) or 0
                    -- Update price based on count
                    if Button[building.."count"] > 0 then
                        Button[building.."price"] = math.floor(Button[building.."fprice"] * (1.15 ^ Button[building.."count"]))
                    end
                    index = index + 1
                end
            end
            
            -- Load upgrade states
            for i = 1, #Upgrade do
                if saveData[index] then
                    Upgrade[Upgrade[i].."a"] = tonumber(saveData[index]) or 0
                    index = index + 1
                end
            end
            
            -- Load statistics (if available in save file)
            if saveData[index] then Cookie.clicked = tonumber(saveData[index]) or 0; index = index + 1 end
            if saveData[index] then Cookie.clickCount = tonumber(saveData[index]) or 0; index = index + 1 end
            if saveData[index] then Cookie.maxCpS = tonumber(saveData[index]) or 0; index = index + 1 end
            if saveData[index] then Cookie.totalSpent = tonumber(saveData[index]) or 0; index = index + 1 end
            if saveData[index] then Game.totalPlayTime = tonumber(saveData[index]) or 0; index = index + 1 end
            if saveData[index] then Game.longestSession = tonumber(saveData[index]) or 0; index = index + 1 end
            if saveData[index] then Game.totalBuildings = tonumber(saveData[index]) or 0; index = index + 1 end
            if saveData[index] then Game.totalUpgrades = tonumber(saveData[index]) or 0; index = index + 1 end
            
            -- Load building production and spending stats (if available)
            for i = 1, #Building do
                local building = Building[i]
                if saveData[index] then Button[building.."total"] = tonumber(saveData[index]) or 0; index = index + 1 end
                if saveData[index] then Button[building.."produced"] = tonumber(saveData[index]) or 0; index = index + 1 end
                if saveData[index] then Button[building.."spent"] = tonumber(saveData[index]) or 0; index = index + 1 end
            end
            
            -- Load audio settings (if available)
            if saveData[index] then AudioSettings.bgMusicEnabled = (tonumber(saveData[index]) or 1) == 1; index = index + 1 end
            if saveData[index] then AudioSettings.bgMusicVolume = tonumber(saveData[index]) or 0.7; index = index + 1 end
            
            -- Load visual settings (if available)
            if saveData[index] then VisualSettings.cookieShowerEnabled = (tonumber(saveData[index]) or 1) == 1; index = index + 1 end
            if saveData[index] then VisualSettings.milkAnimationEnabled = (tonumber(saveData[index]) or 1) == 1; index = index + 1 end
            
            -- Load control settings (if available)
            if saveData[index] then 
                ControlSettings.gamepadEnabled = (tonumber(saveData[index]) or 0) == 1
                ControlSettings.mode = ControlSettings.gamepadEnabled and "Gamepad" or "Keyboard"
                index = index + 1 
            end

            -- Load sound effect settings (if available)
            if saveData[index] then AudioSettings.sfxEnabled = (tonumber(saveData[index]) or 1) == 1; index = index + 1 end
            if saveData[index] then AudioSettings.sfxVolume = tonumber(saveData[index]) or 0.8; index = index + 1 end
            
            print("Game loaded!")
            return true
        end
    end
    return false
end

-- Reset game function
function resetGame()
    -- Delete save file if it exists
    if System.doesFileExist("data/ccsave.sav") then
        System.deleteFile("data/ccsave.sav")
    end
    
    -- Reset all game variables to initial state
    Cookie.count = 0
    Cookie.total = 0
    Cookie.clicked = 0
    Cookie.clickCount = 0
    Cookie.maxCpS = 0
    Cookie.totalSpent = 0
    
    -- Reset building counts and prices
    for i = 1, #Building do
        local building = Building[i]
        Button[building.."count"] = 0
        Button[building.."price"] = Button[building.."fprice"]
        Button[building.."total"] = 0
        Button[building.."produced"] = 0
        Button[building.."spent"] = 0
    end
    
    -- Reset upgrade states
    for i = 1, #Upgrade do
        Upgrade[Upgrade[i].."a"] = 0
    end
    
    -- Reset game statistics
    Game.totalPlayTime = 0
    Game.longestSession = 0
    Game.totalBuildings = 0
    Game.totalUpgrades = 0
    
    -- Reset audio and visual settings to defaults
    AudioSettings.bgMusicEnabled = true
    AudioSettings.bgMusicVolume = 0.7
    AudioSettings.sfxEnabled = true
    AudioSettings.sfxVolume = 0.8
    updateSfxVolume()
    AudioSettings.isPlaying = false
    VisualSettings.cookieShowerEnabled = true
    VisualSettings.milkAnimationEnabled = true
    
    -- Stop music if playing
    if bgMusic and AudioSettings.isPlaying then
        Sound.pause(bgMusic)
        AudioSettings.isPlaying = false
    end
    
    -- Update menu to show "Start" instead of "Continue"
    MenuState.options[1] = "Start"
    
    -- Return to title screen
    gameState = "Title"
    MenuState.selectedIndex = 1
    
    print("Game reset!")
end

-- Initialize upgrades (from Vita version)
Upgrade.make("Cursor",  1,   1,    100,           1,  1)
Upgrade.make("Cursor",  2,   1,    500,           1,  2)
Upgrade.make("Cursor",  3,   10,   10000,         1,  3)
Upgrade.make("Cursor",  4,   25,   100000,        1,  4)
Upgrade.make("Grandma", 1,   1,    1000,          2,  1)
Upgrade.make("Grandma", 2,   5,    5000,          2,  2)
Upgrade.make("Grandma", 3,   25,   50000,         2,  3)
Upgrade.make("Grandma", 4,   50,   5000000,       2,  4)
Upgrade.make("Farm",    1,   1,    11000,         4,  1)
Upgrade.make("Farm",    2,   5,    55000,         4,  2)
Upgrade.make("Farm",    3,   25,   550000,        4,  3)
Upgrade.make("Farm",    4,   50,   55000000,      4,  4)
Upgrade.make("Mine",    1,   1,    120000,        5,  1)
Upgrade.make("Mine",    2,   5,    600000,        5,  2)
Upgrade.make("Mine",    3,   25,   6000000,       5,  3)
Upgrade.make("Mine",    4,   50,   600000000,     5,  4)
Upgrade.make("Factory", 1,   1,    1300000,       6,  1)
Upgrade.make("Factory", 2,   5,    6500000,       6,  2)
Upgrade.make("Factory", 3,   25,   65000000,      6,  3)
Upgrade.make("Factory", 4,   50,   6500000000,    6,  4)
Upgrade.make("Bank",    1,   1,    14000000,      7,  1)
Upgrade.make("Bank",    2,   5,    70000000,      7,  2)
Upgrade.make("Bank",    3,   25,   700000000,     7,  3)
Upgrade.make("Bank",    4,   50,   70000000000,   7,  4)
Upgrade.make("Temple",  1,   1,    200000000,     8,  1)
Upgrade.make("Temple",  2,   5,    1000000000,    8,  2)
Upgrade.make("Temple",  3,   25,   10000000000,   8,  3)
Upgrade.make("Temple",  4,   50,   1000000000000, 8,  4)

-- SDL Input handling
--
-- Every action reads the keyboard, the gamepad and the left stick together.
-- Input.update runs once per frame and works out pressed/repeat for every
-- action, so asking about the same action twice in a frame is safe.
local Input = {
    held = {}, prev = {}, rep = {}, nextRepeat = {}, blocked = {},
    clock = Timer.new(),
    REPEAT_DELAY = 350,  -- ms before a held direction starts repeating
    REPEAT_RATE = 90,    -- ms between repeats
    now = 0
}

local ACTIONS = {
    up      = { keys = {SDLK_UP},        buttons = {SDL_CONTROLLER_BUTTON_DPAD_UP},    stick = "up" },
    down    = { keys = {SDLK_DOWN},      buttons = {SDL_CONTROLLER_BUTTON_DPAD_DOWN},  stick = "down" },
    left    = { keys = {SDLK_LEFT},      buttons = {SDL_CONTROLLER_BUTTON_DPAD_LEFT},  stick = "left" },
    right   = { keys = {SDLK_RIGHT},     buttons = {SDL_CONTROLLER_BUTTON_DPAD_RIGHT}, stick = "right" },
    confirm = { keys = {SDLK_RETURN, SDLK_SPACE}, buttons = {SDL_CONTROLLER_BUTTON_A} },
    back    = { keys = {SDLK_BACKSPACE}, buttons = {SDL_CONTROLLER_BUTTON_B} },
    pause   = { keys = {SDLK_BACKSPACE}, buttons = {SDL_CONTROLLER_BUTTON_START} },
    click   = { keys = {SDLK_X},         buttons = {SDL_CONTROLLER_BUTTON_B} },
    upgrade = { keys = {SDLK_Y},         buttons = {SDL_CONTROLLER_BUTTON_Y} },
    mode    = { keys = {SDLK_T},         buttons = {SDL_CONTROLLER_BUTTON_LEFTSHOULDER, SDL_CONTROLLER_BUTTON_RIGHTSHOULDER} },
    quit    = { keys = {SDLK_ESCAPE} }
}

function Input.update(pad)
    local now = Timer.getTime(Input.clock)
    Input.now = now

    -- Left stick as a d-pad (Vita range 0..255, centre 128)
    local stick = {}
    if Controls.readLeftAnalog then
        local sx, sy = Controls.readLeftAnalog()
        sx, sy = sx or 128, sy or 128
        stick.up, stick.down = sy < 64, sy > 192
        stick.left, stick.right = sx < 64, sx > 192
    end

    for name, action in pairs(ACTIONS) do
        local down = false
        for _, key in ipairs(action.keys or {}) do
            if Controls.check(pad, key) then down = true end
        end
        if not down and Controls.checkGamepadButton then
            for _, button in ipairs(action.buttons or {}) do
                if Controls.checkGamepadButton(button) then down = true end
            end
        end
        if not down and action.stick then
            down = stick[action.stick] or false
        end

        -- A button held across a screen change stays ignored until released
        if Input.blocked[name] then
            if down then down = false else Input.blocked[name] = nil end
        end

        Input.prev[name] = Input.held[name] or false
        Input.held[name] = down
        Input.rep[name] = false
        if down and not Input.prev[name] then
            Input.rep[name] = true
            Input.nextRepeat[name] = now + Input.REPEAT_DELAY
        elseif down and now >= (Input.nextRepeat[name] or 0) then
            Input.rep[name] = true
            Input.nextRepeat[name] = now + Input.REPEAT_RATE
        end
    end
end

-- True on the frame the action goes down
function Input.pressed(name)
    return Input.held[name] and not Input.prev[name]
end

-- True on the first frame, then repeatedly while held
function Input.repeated(name)
    return Input.rep[name]
end

-- Ignore everything currently held until it is released
function Input.block()
    for name, down in pairs(Input.held) do
        if down then Input.blocked[name] = true end
        Input.held[name] = false
        Input.rep[name] = false
    end
end

function setGameState(state)
    gameState = state
    Input.block()
end

-- Move a menu selection up/down with wrap-around
local function navigateMenu(state)
    if Input.repeated("up") then
        state.selectedIndex = state.selectedIndex - 1
        if state.selectedIndex < 1 then state.selectedIndex = state.optionCount end
        playSfx("nav")
        return true
    end
    if Input.repeated("down") then
        state.selectedIndex = state.selectedIndex + 1
        if state.selectedIndex > state.optionCount then state.selectedIndex = 1 end
        playSfx("nav")
        return true
    end
    return false
end

-- Add the current session to the play-time statistics
local function recordSession()
    local sessionTime = (Timer.getTime(timer) - Game.sessionStart) / 1000
    Game.totalPlayTime = Game.totalPlayTime + sessionTime
    if sessionTime > Game.longestSession then
        Game.longestSession = sessionTime
    end
    Game.sessionStart = Timer.getTime(timer)
end

-- Store pricing: each building costs 15% more than the last
function buildingUnitPrice(building, count)
    return math.floor(Button[building.."fprice"] * (1.15 ^ count))
end

function buildingBatchCost(building, quantity)
    local count = Button[building.."count"]
    local total = 0
    for k = 0, quantity - 1 do
        total = total + buildingUnitPrice(building, count + k)
    end
    return total
end

-- Selling refunds half of what each building would cost now
function buildingBatchRefund(building, quantity)
    local count = Button[building.."count"]
    local total = 0
    for k = 1, math.min(quantity, count) do
        total = total + math.floor(buildingUnitPrice(building, count - k) * 0.5)
    end
    return total
end

-- The cheapest upgrade that is unlocked but not bought yet
function nextUpgradeFor(building)
    for i = 1, #Upgrade.Now do
        local upgradeName = Upgrade.Now[i]
        if Upgrade[upgradeName.."name"] == building then
            return upgradeName
        end
    end
    return nil
end

-- Purchases save shortly afterwards instead of on every press, so holding A
-- to buy in bulk doesn't write the save file ten times a second
local SAVE_DEBOUNCE = 1500
local saveDue = nil
local function requestSave()
    saveDue = Timer.getTime(Input.clock) + SAVE_DEBOUNCE
end

function flushPendingSave(force)
    if saveDue and (force or Timer.getTime(Input.clock) >= saveDue) then
        saveDue = nil
        saveGame()
    end
end

local function buySelected()
    local building = Button[GamepadState.selectedIndex]
    if not building then return false end
    local quantity = GamepadState.purchaseQuantity

    if GamepadState.buyMode then
        local cost = buildingBatchCost(building, quantity)
        if Cookie.count < cost then return false end
        Cookie.count = Cookie.count - cost
        Cookie.totalSpent = Cookie.totalSpent + cost
        Button[building.."count"] = Button[building.."count"] + quantity
        Button[building.."total"] = Button[building.."total"] + quantity
        Button[building.."spent"] = Button[building.."spent"] + cost
        Game.totalBuildings = Game.totalBuildings + quantity
        playSfx("buy")
    else
        local sold = math.min(quantity, Button[building.."count"])
        if sold == 0 then return false end
        Cookie.count = Cookie.count + buildingBatchRefund(building, sold)
        Button[building.."count"] = Button[building.."count"] - sold
        playSfx("sell")
    end

    Button[building.."price"] = buildingUnitPrice(building, Button[building.."count"])
    Upgrade.update()
    Upgrade.cps()
    requestSave()
    return true
end

local function buySelectedUpgrade()
    local building = Button[GamepadState.selectedIndex]
    local upgradeName = building and nextUpgradeFor(building)
    if not upgradeName then return false end
    local price = Upgrade[upgradeName.."price"]
    if Cookie.count < price then return false end
    Cookie.count = Cookie.count - price
    Cookie.totalSpent = Cookie.totalSpent + price
    Game.totalUpgrades = Game.totalUpgrades + 1
    Upgrade[upgradeName.."a"] = 2
    Upgrade.update()
    Upgrade.cps()
    requestSave()
    playSfx("upgrade")
    return true
end

local QUANTITIES = {1, 10, 100}
local function stepQuantity(step)
    local index = 1
    for i, q in ipairs(QUANTITIES) do
        if q == GamepadState.purchaseQuantity then index = i end
    end
    index = math.max(1, math.min(#QUANTITIES, index + step))
    GamepadState.purchaseQuantity = QUANTITIES[index]
end

function handleInput(pad)
    Input.update(pad)

    -- Global exit - ESC key
    if Input.pressed("quit") then
        if gameState == "Game" then
            recordSession()
            saveDue = nil
            saveGame()
        end
        -- Stop music before exiting the program completely
        stopBackgroundMusic()
        System.exit()
    end

    if gameState == "Title" then
        handleTitleInput()
    elseif gameState == "Game" then
        handleGameInput()
    elseif gameState == "Settings" then
        handleSettingsInput()
    else
        -- Controls, Statistics and About are read-only pages
        handlePageInput()
    end
end

-- Title screen input handling
function handleTitleInput()
    navigateMenu(MenuState)

    if Input.pressed("confirm") then
        local selectedOption = MenuState.options[MenuState.selectedIndex]
        playSfx("select")
        if selectedOption == "Start" or selectedOption == "Continue" then
            Game.sessionStart = Timer.getTime(timer)
            setGameState("Game")
        elseif selectedOption == "Exit" then
            stopBackgroundMusic()
            System.exit()
        else
            SettingsState.confirmReset = false
            setGameState(selectedOption)
        end
    end
end

-- Controls, Statistics and About: any of A / B / Start returns to the menu
function handlePageInput()
    if Input.pressed("back") or Input.pressed("confirm") or Input.pressed("pause") then
        playSfx("back")
        setGameState("Title")
    end
end

-- Settings screen input handling
function handleSettingsInput()
    if navigateMenu(SettingsState) then
        SettingsState.confirmReset = false
    end

    if Input.pressed("back") or Input.pressed("pause") then
        SettingsState.confirmReset = false
        playSfx("back")
        setGameState("Title")
        return
    end

    local selectedOption = SettingsState.options[SettingsState.selectedIndex]
    local function toggle()
        if selectedOption == "Background Music" then
            toggleBackgroundMusic()
        elseif selectedOption == "Sound Effects" then
            AudioSettings.sfxEnabled = not AudioSettings.sfxEnabled
        elseif selectedOption == "Cookie Shower" then
            VisualSettings.cookieShowerEnabled = not VisualSettings.cookieShowerEnabled
        elseif selectedOption == "Milk Animation" then
            VisualSettings.milkAnimationEnabled = not VisualSettings.milkAnimationEnabled
        else
            return  -- volume rows have nothing to toggle
        end
        playSfx("select")  -- silent when sound effects were just turned off
    end

    if Input.pressed("confirm") then
        if selectedOption == "Reset Game" then
            -- Ask twice: this wipes the save
            if SettingsState.confirmReset then
                SettingsState.confirmReset = false
                resetGame()
                playSfx("back")
                Input.block()
            else
                SettingsState.confirmReset = true
                playSfx("denied")  -- a warning before the second press
            end
        else
            toggle()
        end
    end

    local left, right = Input.repeated("left"), Input.repeated("right")
    if left or right then
        if selectedOption == "Music Volume" then
            local step = right and 0.1 or -0.1
            AudioSettings.bgMusicVolume = math.max(0.0, math.min(1.0, AudioSettings.bgMusicVolume + step))
            AudioSettings.bgMusicVolume = math.floor(AudioSettings.bgMusicVolume * 10 + 0.5) / 10
            updateMusicVolume()
            playSfx("nav")
        elseif selectedOption == "Effects Volume" then
            local step = right and 0.1 or -0.1
            AudioSettings.sfxVolume = math.max(0.0, math.min(1.0, AudioSettings.sfxVolume + step))
            AudioSettings.sfxVolume = math.floor(AudioSettings.sfxVolume * 10 + 0.5) / 10
            updateSfxVolume()
            playSfx("click")  -- preview the new level
        elseif Input.pressed("left") or Input.pressed("right") then
            toggle()
        end
    end
end

-- Game input handling
--
-- One focus: the store list. The buildings view on the left follows the
-- store selection, so there is no panel to switch to.
function handleGameInput()
    if Input.pressed("pause") then
        recordSession()
        saveDue = nil
        saveGame()
        MenuState.options[1] = "Continue"
        playSfx("back")
        setGameState("Title")
        return
    end

    -- Click the cookie
    if Input.pressed("click") then
        local cookiesEarned = 1 * Upgrade["CursorQuan"]
        Cookie.count = Cookie.count + cookiesEarned
        Cookie.total = Cookie.total + cookiesEarned
        Cookie.clicked = Cookie.clicked + cookiesEarned
        Cookie.clickCount = Cookie.clickCount + 1
        Cookie.tmp = 1
        playSfx("click")
    end

    -- Move through the store; a fresh press wraps around, holding stops at the ends
    local count = #Button
    local before = GamepadState.selectedIndex
    if Input.repeated("up") then
        if GamepadState.selectedIndex > 1 then
            GamepadState.selectedIndex = GamepadState.selectedIndex - 1
        elseif Input.pressed("up") then
            GamepadState.selectedIndex = count
        end
    end
    if Input.repeated("down") then
        if GamepadState.selectedIndex < count then
            GamepadState.selectedIndex = GamepadState.selectedIndex + 1
        elseif Input.pressed("down") then
            GamepadState.selectedIndex = 1
        end
    end

    -- Buy amount: left/right step through 1/10/100
    local quantityBefore = GamepadState.purchaseQuantity
    if Input.pressed("left") then stepQuantity(-1) end
    if Input.pressed("right") then stepQuantity(1) end

    -- Buy/sell toggle (L or R)
    if Input.pressed("mode") then
        GamepadState.buyMode = not GamepadState.buyMode
        playSfx("select")
    end

    -- Tick when the selection or amount actually changes (not when stuck at an end)
    if GamepadState.selectedIndex ~= before or GamepadState.purchaseQuantity ~= quantityBefore then
        playSfx("nav")
    end

    -- Buy or sell; holding A keeps buying
    if Input.repeated("confirm") then
        -- Only a fresh press complains, not every repeat while A is held
        if not buySelected() and Input.pressed("confirm") then
            playSfx("denied")
        end
    end

    -- Buy the next upgrade for the selected building
    if Input.pressed("upgrade") then
        if not buySelectedUpgrade() then
            playSfx("denied")
        end
    end
end

-- Panel drawing functions (2-panel layout)

-- Button hints in the buildings header, right-aligned
function drawGameHints()
    local hints = {
        {"B", "Click"},
        {"A", GamepadState.buyMode and "Buy" or "Sell"},
        {"Y", "Upgrade"},
        {"L/R", GamepadState.buyMode and "Sell" or "Buy"},
        {"Start", "Menu"},
    }
    local gap = math.floor(10 * scaleX)
    local total = 0
    for i, hint in ipairs(hints) do
        total = total + textWidth(smallFont, hint[1]) + 4 + textWidth(smallFont, hint[2]) + (i > 1 and gap or 0)
    end
    local labelEnd = PANEL_LEFT_X + math.floor(10 * scaleX) + textWidth(defaultFont, "BUILDINGS") + math.floor(14 * scaleX)
    local right = PANEL_LEFT_X + PANEL_LEFT_WIDTH - math.floor(10 * scaleX)
    while #hints > 0 and right - total < labelEnd do
        local last = hints[#hints]
        total = total - textWidth(smallFont, last[1]) - 4 - textWidth(smallFont, last[2]) - (#hints > 1 and gap or 0)
        hints[#hints] = nil
    end
    local x = right - total
    local y = math.floor(7 * scaleY) - 2
    for i, hint in ipairs(hints) do
        if i > 1 then x = x + gap end
        drawSmallText(x, y, hint[1], gold)
        x = x + textWidth(smallFont, hint[1]) + 4
        drawSmallText(x, y, hint[2], white)
        x = x + textWidth(smallFont, hint[2])
    end
end
function drawPanels()
    -- Draw vertical panel separator between buildings and cookie/store
    if Texture["panelVertical"] then
        local verticalW = Graphics.getImageWidth(Texture["panelVertical"]) or 8
        local verticalH = Graphics.getImageHeight(Texture["panelVertical"]) or 32
        local verticalScaleX = math.floor(8 * scaleX) / verticalW
        local verticalScaleY = screenH / verticalH
        
        Graphics.drawImageExtended(PANEL_RIGHT_X, screenH/2, 0, 0, verticalW, verticalH, 0, verticalScaleX, verticalScaleY, Texture["panelVertical"])
    end
    
    -- Draw horizontal separators in right panel (solid first, then gradients on top)
    if Texture["panelHorizontal"] then
        local solidW = Graphics.getImageWidth(Texture["panelHorizontal"]) or 32
        local solidH = Graphics.getImageHeight(Texture["panelHorizontal"]) or 8
        local solidScaleX = PANEL_RIGHT_WIDTH / solidW
        local solidScaleY = math.floor(8 * scaleY) / solidH
        
        -- Draw solid dividers first
        Graphics.drawImageExtended(PANEL_RIGHT_X + PANEL_RIGHT_WIDTH/2, COOKIE_AREA_HEIGHT + math.floor(25 * scaleY), 0, 0, solidW, solidH, 0, solidScaleX, solidScaleY, Texture["panelHorizontal"])
        local storeHeaderY = COOKIE_AREA_HEIGHT + math.floor(60 * scaleY) - 4
        Graphics.drawImageExtended(PANEL_RIGHT_X + PANEL_RIGHT_WIDTH/2, storeHeaderY, 0, 0, solidW, solidH, 0, solidScaleX, solidScaleY, Texture["panelHorizontal"])
        local upgradeBottomY = COOKIE_AREA_HEIGHT + HEADER_HEIGHT + UPGRADE_HEIGHT + math.floor(10 * scaleY) - 4
        Graphics.drawImageExtended(PANEL_RIGHT_X + PANEL_RIGHT_WIDTH/2, upgradeBottomY, 0, 0, solidW, solidH, 0, solidScaleX, solidScaleY, Texture["panelHorizontal"])
        
        -- Draw gradients on top
        local gradientW = Graphics.getImageWidth(Texture["panelGradientTop"])
        local gradientH = Graphics.getImageHeight(Texture["panelGradientTop"])
        local gradientScaleX = PANEL_RIGHT_WIDTH / gradientW
        local gradientScaleY = math.floor(8 * scaleY) / gradientH
        
        Graphics.drawImageExtended(PANEL_RIGHT_X + PANEL_RIGHT_WIDTH/2, COOKIE_AREA_HEIGHT + math.floor(25 * scaleY), 0, 0, gradientW, gradientH, 0, gradientScaleX, gradientScaleY, Texture["panelGradientTop"])
        Graphics.drawImageExtended(PANEL_RIGHT_X + PANEL_RIGHT_WIDTH/2, storeHeaderY, 0, 0, gradientW, gradientH, 0, gradientScaleX, gradientScaleY, Texture["panelGradientTop"])
        Graphics.drawImageExtended(PANEL_RIGHT_X + PANEL_RIGHT_WIDTH/2, upgradeBottomY, 0, 0, gradientW, gradientH, 0, gradientScaleX, gradientScaleY, Texture["panelGradientTop"])
    end
    
    -- Draw background overlay over buildings header area to mask scrolling buildings
    if Texture["Background"] then
        local headerMaskHeight = math.floor(30 * scaleY)  -- Height of header area to mask
        local bgW = Graphics.getImageWidth(Texture["Background"]) or 960
        local bgH = Graphics.getImageHeight(Texture["Background"]) or 544
        
        -- Use left portion of background that corresponds to left panel
        local srcX = 0
        local srcY = 0
        local srcW = (PANEL_LEFT_WIDTH / screenW) * bgW
        local srcH = (headerMaskHeight / screenH) * bgH
        
        -- Draw background section over header area
        Graphics.drawImageExtended(PANEL_LEFT_WIDTH/2, headerMaskHeight/2, 
                                 srcX, srcY, srcW, srcH, 0, 
                                 PANEL_LEFT_WIDTH/srcW, headerMaskHeight/srcH, Texture["Background"])
    end
    
    -- Draw dark overlay filter over buildings header area
    if Texture["Darkback"] then
        local headerMaskHeight = math.floor(30 * scaleY)  -- Height of header area to mask
        local darkW = Graphics.getImageWidth(Texture["Darkback"]) or 960
        local darkH = Graphics.getImageHeight(Texture["Darkback"]) or 544
        
        -- Use left portion of darkback that corresponds to left panel
        local srcX = 0
        local srcY = 0
        local srcW = (PANEL_LEFT_WIDTH / screenW) * darkW
        local srcH = (headerMaskHeight / screenH) * darkH
        
        -- Draw darkback section over header area
        Graphics.drawImageExtended(PANEL_LEFT_WIDTH/2, headerMaskHeight/2, 
                                 srcX, srcY, srcW, srcH, 0, 
                                 PANEL_LEFT_WIDTH/srcW, headerMaskHeight/srcH, Texture["Darkback"])
    end
    
    -- Draw panel headers (after background overlay so they appear on top)
    drawText(PANEL_LEFT_X + math.floor(10 * scaleX), math.floor(5 * scaleY) - 3, "BUILDINGS", white)
    drawGameHints()
    
    -- Draw horizontal divider below BUILDINGS header (solid first, then gradient on top)
    if Texture["panelHorizontal"] then
        local horizontalY = math.floor(25 * scaleY) + 1  -- Position below header text, lowered by 1 pixel
        
        -- Draw solid divider first
        local solidW = Graphics.getImageWidth(Texture["panelHorizontal"]) or 1
        local solidH = Graphics.getImageHeight(Texture["panelHorizontal"]) or 1
        local solidScaleX = PANEL_LEFT_WIDTH / solidW
        local solidScaleY = math.floor(8 * scaleY) / solidH
        Graphics.drawImageExtended(PANEL_LEFT_X + PANEL_LEFT_WIDTH/2, horizontalY, 0, 0, solidW, solidH, 0, solidScaleX, solidScaleY, Texture["panelHorizontal"])
        
        -- Draw gradient on top
        local gradientW = Graphics.getImageWidth(Texture["panelGradientTop"])
        local gradientH = Graphics.getImageHeight(Texture["panelGradientTop"])
        local gradientScaleX = PANEL_LEFT_WIDTH / gradientW
        local gradientScaleY = math.floor(8 * scaleY) / gradientH
        Graphics.drawImageExtended(PANEL_LEFT_X + PANEL_LEFT_WIDTH/2, horizontalY, 0, 0, gradientW, gradientH, 0, gradientScaleX, gradientScaleY, Texture["panelGradientTop"])
    end
    
    -- Store header: STORE  BUY  1 10 100, spaced by measured text width
    local headerY = COOKIE_AREA_HEIGHT + math.floor(35 * scaleY) - 3
    local headerX = PANEL_RIGHT_X + math.floor(10 * scaleX)
    local gap = math.floor(14 * scale)
    drawText(headerX, headerY, "STORE", white)
    headerX = headerX + textWidth(defaultFont, "STORE") + gap
    drawText(headerX, headerY, GamepadState.buyMode and "BUY" or "SELL", GamepadState.buyMode and green or red)
    headerX = headerX + textWidth(defaultFont, "SELL") + gap
    local dim = Color.new(110, 110, 110)
    for _, q in ipairs({1, 10, 100}) do
        local label = tostring(q)
        drawText(headerX, headerY, label, GamepadState.purchaseQuantity == q and white or dim)
        headerX = headerX + textWidth(defaultFont, label) + math.floor(gap * 0.7)
    end
end

function drawBuildings()
    -- Only owned buildings get a row (Cursor has no row; its cursors circle the cookie)
    local rows = {}
    local selectedRow = 1
    local selectedBuilding = Button[GamepadState.selectedIndex]
    for i = 1, #Button do
        local building = Button[i]
        if (Button[building.."id"] or 1) >= 2 and Button[building.."count"] > 0 then
            rows[#rows + 1] = building
        end
        -- Follow the store selection; an unowned building shows the nearest row before it
        if i <= GamepadState.selectedIndex and #rows > 0 then
            selectedRow = #rows
        end
    end
    if #rows == 0 then
        return
    end

    local backW = Graphics.getImageWidth(Texture["BLDBacks"]) or 332
    local backH = 144  -- Each slice is 144px tall
    local frameWidth = PANEL_LEFT_WIDTH - math.floor(10 * scaleX)
    local rowScale = frameWidth / backW
    local rowHeight = math.floor(backH * rowScale)
    local top = math.floor(30 * scaleY)
    local visibleHeight = screenH - top

    -- Centre the selected row, ease towards it
    local target = (selectedRow - 1) * rowHeight - (visibleHeight - rowHeight) / 2
    target = math.max(0, math.min(target, #rows * rowHeight - visibleHeight))
    BuildingView.scroll = BuildingView.scroll + (target - BuildingView.scroll) * 0.25
    if math.abs(target - BuildingView.scroll) < 1 then
        BuildingView.scroll = target
    end

    local x = PANEL_LEFT_X + math.floor(5 * scaleX)
    for k, building in ipairs(rows) do
        local y = math.floor(top + (k - 1) * rowHeight - BuildingView.scroll)
        if y + rowHeight > 0 and y < screenH then
            local buildingId = Button[building.."id"]
            local backSliceY = (buildingId - 2) * 144
            Graphics.drawImageExtended(x + frameWidth/2, y + rowHeight/2 - 1,
                0, backSliceY, backW, backH, 0, rowScale * 1.006, rowScale, Texture["BLDBacks"])

            if Texture["BLDIcons"] then
                local iconSliceX = 64 * (buildingId - 2) + 1  -- 1px in to skip the border
                local maxIconsPerRow = math.floor(frameWidth / (25 * rowScale))
                local iconsToShow = math.min(Button[building.."count"], maxIconsPerRow * 2)
                local iconSpacing = math.floor(25 * rowScale)
                local rowSpacing = math.floor(30 * rowScale)
                local iconSize = 62 * rowScale
                for iconNum = 1, iconsToShow do
                    local row = math.floor((iconNum - 1) / maxIconsPerRow)
                    local col = (iconNum - 1) % maxIconsPerRow
                    local iconX = x + math.floor(30 * scaleX) + col * iconSpacing
                    local iconY = y + math.floor(60 * scaleY) + row * rowSpacing
                    if iconX + iconSize/2 <= x + frameWidth then
                        Graphics.drawImageExtended(iconX, iconY, iconSliceX, 0, 62, 64, 0, rowScale, rowScale, Texture["BLDIcons"])
                    end
                end
            end

            -- Tie the row to the store selection
            if building == selectedBuilding then
                drawFrame(x, y, frameWidth, rowHeight, 2, gold)
            end
        end
    end
end

function drawCookie()
    if Texture["Cookie"] then
        local cookieX = CENTER_OF_COOKIE_X
        local cookieY = CENTER_OF_COOKIE_Y
        
        -- Use smaller cookie size to make room for upgrades
        local cookieScale = 0.45 * scale
        
        -- Add click animation
        if Cookie.tmp > 0 then
            cookieScale = cookieScale * 1.2
        end
        
        -- Draw shine effect first (behind cookie)
        if Texture["Shine"] then
            local shineScale = cookieScale * 0.8  -- Shine scale relative to cookie
            
            -- Get shine image dimensions
            local shineW = Graphics.getImageWidth(Texture["Shine"]) or 128
            local shineH = Graphics.getImageHeight(Texture["Shine"]) or 128
            
            -- Draw rotating shine effects
            Graphics.drawImageExtended(cookieX, cookieY, 0, 0, shineW, shineH, Shine.rot, shineScale, shineScale, Texture["Shine"])
            Graphics.drawImageExtended(cookieX, cookieY, 0, 0, shineW, shineH, -Shine.rot, shineScale, shineScale, Texture["Shine"])
        end
        
        -- Draw cookie on top
        local cookieW = Graphics.getImageWidth(Texture["Cookie"]) or 128
        local cookieH = Graphics.getImageHeight(Texture["Cookie"]) or 128
        Graphics.drawImageExtended(cookieX, cookieY, 0, 0, cookieW, cookieH, 0, cookieScale, cookieScale, Texture["Cookie"])
        
        -- Draw rotating cursors around the cookie
        drawCursors(cookieX, cookieY, cookieScale)
        
        -- Decay click effect
        if Cookie.tmp > 0 then
            Cookie.tmp = Cookie.tmp - 0.25
            if Cookie.tmp < 0 then Cookie.tmp = 0 end
        end
    end
end

function drawMilk()
    -- Only draw if milk animation is enabled
    if not VisualSettings.milkAnimationEnabled then
        return
    end
    
    -- Draw milk animation exactly like Vita version (simple horizontal scrolling)
    if Texture["Milk"] then
        local milkHeight = math.floor(25 * scaleY)  -- Height of milk animation
        local milkY = COOKIE_AREA_HEIGHT + math.floor(15 * scaleY)  -- Position lower in store area
        local milkW = Graphics.getImageWidth(Texture["Milk"]) or 480
        local milkH = Graphics.getImageHeight(Texture["Milk"]) or 80
        
        -- Scale milk to fit right panel width
        local milkScaleX = PANEL_RIGHT_WIDTH / milkW
        local milkScaleY = milkHeight / milkH
        
        -- Simple left-to-right scrolling like Vita version
        local scaledMilkWidth = milkW * milkScaleX
        
        -- Draw two milk images for seamless looping (like original Vita code)
        Graphics.drawImageExtended(PANEL_RIGHT_X + Milk.x + scaledMilkWidth/2, milkY, 0, 0, milkW, milkH, 0, milkScaleX, milkScaleY, Texture["Milk"])
        Graphics.drawImageExtended(PANEL_RIGHT_X + Milk.x - scaledMilkWidth + scaledMilkWidth/2, milkY, 0, 0, milkW, milkH, 0, milkScaleX, milkScaleY, Texture["Milk"])
        
        -- Update position and loop when needed (like Vita version)
        if Milk.x >= scaledMilkWidth then
            Milk.x = Milk.x - scaledMilkWidth
        end
        Milk.x = Milk.x + Milk.speed
    end
end

function drawCookieShower()
    -- Only draw if cookie shower is enabled
    if not VisualSettings.cookieShowerEnabled then
        return
    end
    
    -- Draw cookie shower animation in right panel (cookie section) only
    if Texture["CookieShower1"] then
        -- Calculate current CPS to determine shower intensity
        local cps = 0
        for i = 1, #Button do
            local building = Button[i]
            if building then
                local quan = Upgrade[building.."Quan"] or 1
                cps = cps + Button[building.."count"] * Button[building.."cps"] * quan
            end
        end
        
        -- Determine which shower to show based on CPS (like Vita version)
        local showerType = 0
        if cps >= 200 and cps < 500 then
            showerType = 1
        elseif cps >= 500 and cps < 1000 then
            showerType = 2
        elseif cps >= 1000 then
            showerType = 3
        end
        
        -- Only draw if we have enough CPS
        if showerType > 0 then
            local showerTexture = Texture["CookieShower"..showerType]
            local showerW = Graphics.getImageWidth(showerTexture) or 300
            local showerH = Graphics.getImageHeight(showerTexture) or 544
            
            -- Scale shower to fit right panel width while maintaining aspect ratio
            local showerScale = PANEL_RIGHT_WIDTH / showerW  -- Use same scale for both X and Y
            local scaledShowerHeight = showerH * showerScale
            
            -- Position shower in center of right panel
            local showerX = PANEL_RIGHT_X + PANEL_RIGHT_WIDTH/2
            
            -- Simple vertical scrolling like Vita version - just two images, only draw if in cookie area
            local img1Y = Cookie.shower.y
            local img2Y = Cookie.shower.y - scaledShowerHeight
            
            -- Simple vertical scrolling like Vita version - just two images
            Graphics.drawImageExtended(showerX, img1Y, 0, 0, showerW, showerH, 0, showerScale, showerScale, showerTexture)
            Graphics.drawImageExtended(showerX, img2Y, 0, 0, showerW, showerH, 0, showerScale, showerScale, showerTexture)
            
            -- Update animation position (pure vertical movement)
            Cookie.shower.y = Cookie.shower.y + Cookie.shower.speed
            if Cookie.shower.y >= scaledShowerHeight then
                Cookie.shower.y = Cookie.shower.y - scaledShowerHeight
            end
        end
    end
end

function drawBuildingsBackground()
    -- Draw background overlay over buildings section to mask milk animation
    if Texture["Background"] then
        local buildingsY = 0
        local buildingsHeight = screenH
        
        -- Calculate which part of background.png to use for buildings area
        local bgW = Graphics.getImageWidth(Texture["Background"]) or 960
        local bgH = Graphics.getImageHeight(Texture["Background"]) or 544
        
        -- Use left portion of background that corresponds to left panel
        local srcX = 0
        local srcY = 0
        local srcW = (PANEL_LEFT_WIDTH / screenW) * bgW
        local srcH = bgH
        
        -- Draw background section over buildings area
        Graphics.drawImageExtended(PANEL_LEFT_WIDTH/2, screenH/2, 
                                 srcX, srcY, srcW, srcH, 0, 
                                 PANEL_LEFT_WIDTH/srcW, screenH/srcH, Texture["Background"])
    end
end

function drawStoreBackground()
    -- Draw background overlay over store section to mask cookie shower (start at store header)
    if Texture["Background"] then
        local storeY = COOKIE_AREA_HEIGHT + HEADER_HEIGHT - math.floor(2 * scaleY)  -- Start slightly higher
        local storeHeight = screenH - storeY
        
        -- Calculate which part of background.png to use for store area
        local bgW = Graphics.getImageWidth(Texture["Background"]) or 960
        local bgH = Graphics.getImageHeight(Texture["Background"]) or 544
        
        -- Use right portion of background that corresponds to right panel
        local srcX = (PANEL_RIGHT_X / screenW) * bgW
        local srcY = (storeY / screenH) * bgH
        local srcW = (PANEL_RIGHT_WIDTH / screenW) * bgW
        local srcH = (storeHeight / screenH) * bgH
        
        -- Draw background section over store area
        Graphics.drawImageExtended(PANEL_RIGHT_X + PANEL_RIGHT_WIDTH/2, storeY + storeHeight/2, 
                                 srcX, srcY, srcW, srcH, 0, 
                                 PANEL_RIGHT_WIDTH/srcW, storeHeight/srcH, Texture["Background"])
    end
    
    -- Draw dark overlay filter over store section
    if Texture["Darkback"] then
        local storeY = COOKIE_AREA_HEIGHT + HEADER_HEIGHT - math.floor(2 * scaleY)  -- Start slightly higher
        local storeHeight = screenH - storeY
        
        -- Calculate which part of darkback.png to use for store area
        local darkW = Graphics.getImageWidth(Texture["Darkback"]) or 960
        local darkH = Graphics.getImageHeight(Texture["Darkback"]) or 544
        
        -- Use right portion of darkback that corresponds to right panel
        local srcX = (PANEL_RIGHT_X / screenW) * darkW
        local srcY = (storeY / screenH) * darkH
        local srcW = (PANEL_RIGHT_WIDTH / screenW) * darkW
        local srcH = (storeHeight / screenH) * darkH
        
        -- Draw darkback section over store area
        Graphics.drawImageExtended(PANEL_RIGHT_X + PANEL_RIGHT_WIDTH/2, storeY + storeHeight/2, 
                                 srcX, srcY, srcW, srcH, 0, 
                                 PANEL_RIGHT_WIDTH/srcW, storeHeight/srcH, Texture["Darkback"])
    end
end

function drawStore()
    local itemHeight = math.floor(50 * scaleY)
    local listTop = COOKIE_AREA_HEIGHT + HEADER_HEIGHT + UPGRADE_HEIGHT + math.floor(10 * scaleY)
    local visibleHeight = screenH - listTop

    -- Keep the selection in the middle of the list where possible, eased
    local target = (GamepadState.selectedIndex - 1) * itemHeight - (visibleHeight - itemHeight) / 2
    target = math.max(0, math.min(target, #Button * itemHeight - visibleHeight))
    StoreView.scroll = StoreView.scroll + (target - StoreView.scroll) * 0.3
    if math.abs(target - StoreView.scroll) < 1 then
        StoreView.scroll = target
    end

    local x = PANEL_RIGHT_X
    local frameWidth = PANEL_RIGHT_WIDTH
    local quantity = GamepadState.purchaseQuantity

    for i = 1, #Button do
        local building = Button[i]
        local y = math.floor(listTop + (i - 1) * itemHeight - StoreView.scroll)
        -- Rows that slide under the upgrade bar are covered by drawStoreMask()
        if y + itemHeight > listTop and y < screenH then
            local selected = GamepadState.selectedIndex == i

            if Texture["StoreTile"] then
                local tileW = Graphics.getImageWidth(Texture["StoreTile"]) or 64
                local tileH = Graphics.getImageHeight(Texture["StoreTile"]) or 64
                Graphics.drawImageExtended(x + frameWidth/2, y + itemHeight/2, 0, 0, tileW, tileH, 0, frameWidth / tileW, itemHeight / tileH, Texture["StoreTile"])
            else
                Graphics.fillRect(x, x + frameWidth, y, y + itemHeight, Color.new(100, 100, 100))
            end

            -- Unselected rows look pressed in
            if not selected and Texture["PressedTile"] then
                local pressedW = Graphics.getImageWidth(Texture["PressedTile"]) or 64
                local pressedH = Graphics.getImageHeight(Texture["PressedTile"]) or 64
                Graphics.drawImageExtended(x + frameWidth/2, y + itemHeight/2, 0, 0, pressedW, pressedH, 0, frameWidth / pressedW, itemHeight / pressedH, Texture["PressedTile"])
            end

            if Texture["Buildings"] then
                local buildingId = Button[building.."id"] or 1
                local iconSliceX = Button[building.."count"] > 0 and 0 or 64  -- locked icons are the right column
                local iconSize = math.floor(40 * scale)
                Graphics.drawImageExtended(x + math.floor(25 * scaleX), y + itemHeight/2, iconSliceX + 1, 64 * (buildingId - 1), 62, 64, 0, iconSize/62, iconSize/64, Texture["Buildings"])
            end

            local textX = x + math.floor(55 * scaleX)
            local ownText = tostring(Button[building.."count"])
            local ownX = x + frameWidth - textWidth(defaultFont, ownText) - math.floor(12 * scaleX)
            -- Long names (AntimatterCondenser) drop to the small font so they clear the count
            if textX + textWidth(defaultFont, building) > ownX - 6 then
                drawSmallText(textX, y + 7, building, white)
            else
                drawText(textX, y + 5, building, white)
            end

            -- Price of the whole batch (buy) or what selling it returns (sell)
            if Texture["Favicon"] then
                local cookieIconSize = math.floor(12 * scale)
                local cookieY = y + math.floor(35 * scaleY)
                Graphics.drawImageExtended(textX, cookieY, 0, 0, 16, 16, 0, cookieIconSize/16, cookieIconSize/16, Texture["Favicon"])

                local priceText, priceColor
                if GamepadState.buyMode then
                    local cost = buildingBatchCost(building, quantity)
                    priceText = formatCookieCount(cost)
                    priceColor = Cookie.count >= cost and green or red
                else
                    local refund = buildingBatchRefund(building, quantity)
                    priceText = "+" .. formatCookieCount(refund)
                    priceColor = refund > 0 and gold or grey
                end
                drawSmallText(textX + cookieIconSize + 3, cookieY - math.floor(SMALL_FONT_SIZE * 0.8), priceText, priceColor)
            end

            -- Owned count, right-aligned so 4+ digits fit
            drawText(ownX, y + itemHeight/2 - math.floor(FONT_SIZE * 0.6), ownText, white)

            if selected then
                drawFrame(x + 2, y, frameWidth - 4, itemHeight, 2, gold)
            end
        end
    end
end

-- Repaint the strip between the store header and the list so scrolled rows
-- disappear under it instead of popping out
function drawStoreMask()
    local maskTop = COOKIE_AREA_HEIGHT + HEADER_HEIGHT - math.floor(2 * scaleY)
    local maskBottom = COOKIE_AREA_HEIGHT + HEADER_HEIGHT + UPGRADE_HEIGHT + math.floor(10 * scaleY)
    local maskHeight = maskBottom - maskTop
    for _, name in ipairs({"Background", "Darkback"}) do
        local tex = Texture[name]
        if tex then
            local texW = Graphics.getImageWidth(tex) or 960
            local texH = Graphics.getImageHeight(tex) or 544
            local srcX = (PANEL_RIGHT_X / screenW) * texW
            local srcY = (maskTop / screenH) * texH
            local srcW = (PANEL_RIGHT_WIDTH / screenW) * texW
            local srcH = (maskHeight / screenH) * texH
            Graphics.drawImageExtended(PANEL_RIGHT_X + PANEL_RIGHT_WIDTH/2, maskTop + maskHeight/2,
                srcX, srcY, srcW, srcH, 0, PANEL_RIGHT_WIDTH/srcW, maskHeight/srcH, tex)
        end
    end
end

function drawCursors(cookieX, cookieY, cookieScale)
    -- Draw cursors rotating around the cookie
    local cursorCount = Button["Cursorcount"] or 0
    if cursorCount > 0 then
        local pi = 3.14159
        
        -- Find the highest cursor upgrade the player owns
        local highestCursorUpgrade = 0  -- 0 = no upgrades, use basic cursor
        for i = 4, 1, -1 do  -- Check from highest to lowest upgrade
            local upgradeName = "Cursor" .. i
            if Upgrade[upgradeName.."a"] == 2 then  -- Status 2 = purchased
                highestCursorUpgrade = i
                break
            end
        end
        
        -- Calculate radius to position cursors around the cookie
        local cookieVisualRadius = 64 * cookieScale  -- Actual visual radius of the cookie
        local cursorSize = 32 * scale  -- Approximate cursor size
        local cursorDistance = math.floor(40 * scale)   -- Closer positioning
        local radius = cookieVisualRadius + cursorDistance
        
        -- Draw up to 8 cursors around the cookie
        local cursorsToShow = math.min(cursorCount, 8)
        
        for i = 1, cursorsToShow do
            local angle = Cursor.rot + (pi * 2 * i / cursorsToShow)
            local x = cookieX + math.cos(angle) * radius
            local y = cookieY + math.sin(angle) * radius
            
            -- Rotate cursor to point toward the center of the cookie
            local rotationAngle = angle + pi + pi/2
            
            if highestCursorUpgrade == 0 and Texture["Cursor"] then
                -- Use basic cursor from cursor.png (first sprite at bottom)
                local cursorW = Graphics.getImageWidth(Texture["Cursor"]) or 32
                local cursorH = Graphics.getImageHeight(Texture["Cursor"]) or 128
                
                -- Adjust cropping to include the full cursor with fingertip
                -- Use the full width and adjust height to capture complete cursor
                local spriteHeight = math.min(cursorW * 1.2, cursorH)  -- Slightly taller to include fingertip
                local sourceY = math.max(0, cursorH - spriteHeight)  -- Start from bottom, but ensure we don't go negative
                
                local cursorScale = math.max(0.3, math.min(1.0, scale * 0.8))
                Graphics.drawImageExtended(x, y, 0, sourceY, cursorW, spriteHeight, rotationAngle, cursorScale, cursorScale, Texture["Cursor"])
                
            elseif highestCursorUpgrade > 0 and Texture["Icons"] then
                -- Use upgraded cursor from icons.png
                local iconColumn = 1
                local iconRow = highestCursorUpgrade
                local iconX = (iconColumn - 1) * 48
                local iconY = (iconRow - 1) * 48
                
                local cursorIconScale = math.max(0.25, math.min(0.6, scale * 0.5))
                Graphics.drawImageExtended(x, y, iconX, iconY, 48, 48, rotationAngle, cursorIconScale, cursorIconScale, Texture["Icons"])
            end
        end
    end
end

function drawUpgrades()
    local selectedBuilding = Button[GamepadState.selectedIndex]
    if not selectedBuilding then
        return
    end
    local nextUpgrade = nextUpgradeFor(selectedBuilding)

    local upgradeAreaTop = COOKIE_AREA_HEIGHT + HEADER_HEIGHT
    local upgradeY = upgradeAreaTop + UPGRADE_HEIGHT * 0.48 + math.floor(2 * scaleY) - 4
    local upgradeX = PANEL_RIGHT_X + math.floor(6 * scaleX)
    local frameSize = math.floor(40 * scale)

    for i = 1, 4 do
        local upgradeName = selectedBuilding .. i
        local frameX = upgradeX + (i - 1) * math.floor(42 * scaleX)

        if Upgrade[upgradeName.."price"] and Texture["UpgradeFrame"] then
            local upgradeStatus = Upgrade[upgradeName.."a"] or 0
            local upgradePrice = Upgrade[upgradeName.."price"]
            local upgradeCount = Upgrade[upgradeName.."count"]  -- buildings needed to unlock

            if Button[selectedBuilding.."count"] >= upgradeCount then
                local frameSliceX = 60  -- right slice = unaffordable
                if upgradeStatus == 2 or Cookie.count >= upgradePrice then
                    frameSliceX = 0
                end
                Graphics.drawImageExtended(frameX + frameSize/2, upgradeY + frameSize/2,
                    frameSliceX, 0, 60, 60, 0, frameSize/60, frameSize/60, Texture["UpgradeFrame"])

                if Texture["Icons"] then
                    local iconX = ((Upgrade[upgradeName.."column"] or 1) - 1) * 48
                    local iconY = ((Upgrade[upgradeName.."row"] or 1) - 1) * 48
                    local iconSize = math.floor(32 * scale)
                    Graphics.drawImageExtended(frameX + frameSize/2, upgradeY + frameSize/2,
                        iconX, iconY, 48, 48, 0, iconSize/48, iconSize/48, Texture["Icons"])
                end

                if upgradeStatus == 2 then
                    -- Bought: dim it
                    Graphics.fillRect(frameX, frameX + frameSize, upgradeY, upgradeY + frameSize, Color.new(0, 0, 0, 140))
                else
                    local priceColor = Cookie.count >= upgradePrice and green or red
                    Font.print(smallFont, frameX + math.floor(2 * scaleX), upgradeY + frameSize - math.floor(15 * scaleY), formatNumber(upgradePrice), priceColor)
                end

                -- The one Y buys
                if upgradeName == nextUpgrade then
                    drawFrame(frameX - 1, upgradeY - 1, frameSize + 2, frameSize + 2, 2, gold)
                end
            else
                -- Locked: show how many buildings unlock it
                Graphics.drawImageExtended(frameX + frameSize/2, upgradeY + frameSize/2,
                    60, 0, 60, 60, 0, frameSize/60, frameSize/60, Texture["UpgradeFrame"])
                Graphics.fillRect(frameX, frameX + frameSize, upgradeY, upgradeY + frameSize, Color.new(0, 0, 0, 180))
                local lockText = tostring(upgradeCount)
                drawSmallText(frameX + (frameSize - textWidth(smallFont, lockText)) / 2, upgradeY + frameSize/2 - 8, lockText, white)
            end
        end
    end
end

-- Title Screen drawing
function drawTitleScreen()
    if Texture["Background"] then
        Graphics.drawImageExtended(screenW/2, screenH/2, 0, 0, 960, 544, 0, scaleX, scaleY, Texture["Background"])
    end

    drawCentered(titleFont, math.floor(40 * scaleY), "COOKIE CLICKER", white)

    -- Cookie
    local cookieY = screenH/2 - math.floor(70 * scaleY)
    if Texture["Cookie"] then
        local cookieScale = 0.55 * scale
        local cookieW = Graphics.getImageWidth(Texture["Cookie"]) or 128
        local cookieH = Graphics.getImageHeight(Texture["Cookie"]) or 128
        if Texture["Shine"] then
            local shineW = Graphics.getImageWidth(Texture["Shine"]) or 128
            local shineH = Graphics.getImageHeight(Texture["Shine"]) or 128
            local shineScale = cookieScale * 0.8
            Graphics.drawImageExtended(screenW/2, cookieY, 0, 0, shineW, shineH, Shine.rot, shineScale, shineScale, Texture["Shine"])
            Graphics.drawImageExtended(screenW/2, cookieY, 0, 0, shineW, shineH, -Shine.rot, shineScale, shineScale, Texture["Shine"])
        end
        Graphics.drawImageExtended(screenW/2, cookieY, 0, 0, cookieW, cookieH, 0, cookieScale, cookieScale, Texture["Cookie"])
    end

    -- Menu
    local spacing = math.floor(26 * scaleY)
    local menuTop = screenH/2 + math.floor(55 * scaleY)
    drawMenuList(MenuState, menuTop, spacing)

    drawSmallText(screenW - textWidth(smallFont, version) - 10, screenH - math.floor(22 * scaleY), version, grey)
    drawHints({{"A", "Select"}, {"Esc", "Quit"}})
end

-- Controls Screen drawing
function drawControlsScreen()
    if Texture["Background"] then
        Graphics.drawImageExtended(screenW/2, screenH/2, 0, 0, 960, 544, 0, scaleX, scaleY, Texture["Background"])
    end

    drawCentered(defaultFont, math.floor(30 * scaleY), "CONTROLS", white)

    local rows = {
        {"Click the cookie",  "B",               "X"},
        {"Move in the store", "D-pad up/down",   "Up/Down"},
        {"Buy amount",        "D-pad left/right", "Left/Right"},
        {"Buy / sell",        "A (hold to repeat)", "Enter"},
        {"Buy upgrade",       "Y",               "Y"},
        {"Buy / sell mode",   "L or R",          "T"},
        {"Menu (saves)",      "Start",           "Backspace"},
        {"Back",              "B",               "Backspace"},
        {"Quit",              "Select + Start",  "Esc"},
    }

    local colX = {math.floor(screenW * 0.06), math.floor(screenW * 0.38), math.floor(screenW * 0.74)}
    local y = math.floor(70 * scaleY)
    local lineHeight = math.floor(30 * scaleY)

    drawText(colX[1], y, "Action", grey)
    drawText(colX[2], y, "Gamepad", grey)
    drawText(colX[3], y, "Keyboard", grey)
    y = y + lineHeight
    for _, row in ipairs(rows) do
        drawText(colX[1], y, row[1], white)
        drawText(colX[2], y, row[2], gold)
        drawText(colX[3], y, row[3], white)
        y = y + lineHeight
    end

    drawHints({{"B", "Back"}})
end

-- Settings Screen drawing
function drawSettingsScreen()
    if Texture["Background"] then
        Graphics.drawImageExtended(screenW/2, screenH/2, 0, 0, 960, 544, 0, scaleX, scaleY, Texture["Background"])
    end

    drawCentered(defaultFont, math.floor(30 * scaleY), "SETTINGS", white)

    local top = math.floor(90 * scaleY)
    local lineHeight = math.floor(40 * scaleY)
    local barLeft = math.floor(screenW * 0.15)
    local barRight = math.floor(screenW * 0.85)

    for i = 1, SettingsState.optionCount do
        local option = SettingsState.options[i]
        local y = top + (i - 1) * lineHeight
        local selected = i == SettingsState.selectedIndex
        local valueText, valueColor = "", white

        if option == "Background Music" then
            valueText = AudioSettings.bgMusicEnabled and "ON" or "OFF"
            valueColor = AudioSettings.bgMusicEnabled and green or red
        elseif option == "Music Volume" then
            valueText = math.floor(AudioSettings.bgMusicVolume * 100 + 0.5) .. "%"
            if selected then valueText = "< " .. valueText .. " >" end
        elseif option == "Sound Effects" then
            valueText = AudioSettings.sfxEnabled and "ON" or "OFF"
            valueColor = AudioSettings.sfxEnabled and green or red
        elseif option == "Effects Volume" then
            valueText = math.floor(AudioSettings.sfxVolume * 100 + 0.5) .. "%"
            if selected then valueText = "< " .. valueText .. " >" end
        elseif option == "Cookie Shower" then
            valueText = VisualSettings.cookieShowerEnabled and "ON" or "OFF"
            valueColor = VisualSettings.cookieShowerEnabled and green or red
        elseif option == "Milk Animation" then
            valueText = VisualSettings.milkAnimationEnabled and "ON" or "OFF"
            valueColor = VisualSettings.milkAnimationEnabled and green or red
        elseif option == "Reset Game" then
            valueText = SettingsState.confirmReset and "Press A again to erase" or ""
            valueColor = red
        end

        if selected then
            Graphics.fillRect(barLeft, barRight, y - math.floor(8 * scaleY), y + math.floor(26 * scaleY), selectBar)
        end
        drawText(barLeft + math.floor(16 * scaleX), y, option, selected and white or menuIdle)
        drawText(barRight - math.floor(16 * scaleX) - textWidth(defaultFont, valueText), y, valueText, valueColor)
    end

    local selectedOption = SettingsState.options[SettingsState.selectedIndex]
    if selectedOption == "Music Volume" or selectedOption == "Effects Volume" then
        drawHints({{"Left/Right", "Adjust"}, {"B", "Back"}})
    else
        drawHints({{"A", "Select"}, {"B", "Back"}})
    end
end

-- Statistics Screen drawing
function drawStatisticsScreen()
    -- Draw background
    if Texture["Background"] then
        Graphics.drawImageExtended(screenW/2, screenH/2, 0, 0, 960, 544, 0, scaleX, scaleY, Texture["Background"])
    end
    
    -- Draw title
    drawCentered(defaultFont, math.floor(30 * scaleY), "STATISTICS", white)
    
    -- Calculate play time
    local currentTime = Timer.getTime(timer)
    local sessionTime = (currentTime - Game.sessionStart) / 1000
    local totalTime = Game.totalPlayTime + sessionTime
    
    -- Column setup
    local leftX = math.floor(20 * scaleX)
    local rightX = math.floor(320 * scaleX)
    local startY = math.floor(80 * scaleY)
    local lineHeight = math.floor(25 * scaleY)
    local currentY = startY
    
    -- Cookie Statistics (Left Column)
    drawText(leftX, currentY, "COOKIE STATISTICS", white)
    currentY = currentY + lineHeight
    
    drawText(leftX, currentY, "Total Cookies: " .. formatNumber(Cookie.total), white)
    currentY = currentY + lineHeight
    
    drawText(leftX, currentY, "Current Cookies: " .. formatNumber(Cookie.count), white)
    currentY = currentY + lineHeight
    
    drawText(leftX, currentY, "Cookies Clicked: " .. formatNumber(Cookie.clicked), white)
    currentY = currentY + lineHeight
    
    drawText(leftX, currentY, "Total Clicks: " .. formatNumber(Cookie.clickCount), white)
    currentY = currentY + lineHeight
    
    drawText(leftX, currentY, "Max CpS: " .. formatCPS(Cookie.maxCpS), white)
    currentY = currentY + lineHeight
    
    drawText(leftX, currentY, "Total Spent: " .. formatNumber(Cookie.totalSpent), white)
    currentY = currentY + lineHeight + 10
    
    -- Session Statistics
    drawText(leftX, currentY, "SESSION STATISTICS", white)
    currentY = currentY + lineHeight
    
    drawText(leftX, currentY, "Session Time: " .. formatTime(sessionTime), white)
    currentY = currentY + lineHeight
    
    drawText(leftX, currentY, "Total Time: " .. formatTime(totalTime), white)
    currentY = currentY + lineHeight
    
    -- Building Statistics (Right Column)
    currentY = startY
    drawText(rightX, currentY, "BUILDING STATISTICS", white)
    currentY = currentY + lineHeight
    
    drawText(rightX, currentY, "Total Buildings: " .. formatNumber(Game.totalBuildings), white)
    currentY = currentY + lineHeight
    
    drawText(rightX, currentY, "Total Upgrades: " .. formatNumber(Game.totalUpgrades), white)
    currentY = currentY + lineHeight + 10
    
    -- Top building producers
    drawText(rightX, currentY, "TOP PRODUCERS", white)
    currentY = currentY + lineHeight
    
    -- Find top 3 producing buildings
    local buildingStats = {}
    for i = 1, #Button do
        local building = Button[i]
        if building and Button[building.."count"] > 0 then
            table.insert(buildingStats, {
                name = building,
                produced = Button[building.."produced"],
                count = Button[building.."count"]
            })
        end
    end
    
    -- Sort by production
    table.sort(buildingStats, function(a, b) return a.produced > b.produced end)
    
    -- Display top 3
    for i = 1, math.min(3, #buildingStats) do
        local stat = buildingStats[i]
        drawText(rightX, currentY, stat.name .. ": " .. formatNumber(stat.produced), white)
        currentY = currentY + lineHeight
    end
    
    drawHints({{"B", "Back"}})
end

-- About Screen drawing
function drawAboutScreen()
    -- Draw background
    if Texture["Background"] then
        Graphics.drawImageExtended(screenW/2, screenH/2, 0, 0, 960, 544, 0, scaleX, scaleY, Texture["Background"])
    end
    
    -- Draw title
    local titleText = "ABOUT"
    local titleWidth = string.len(titleText) * 20  -- Approximate width for title font
    drawTitleText(screenW/2 - titleWidth/2, math.floor(30 * scaleY), titleText, white)
    
    -- Draw cookie image (smaller)
    if Texture["Cookie"] then
        local cookieScale = 0.3 * scale
        local cookieX = screenW/2
        local cookieY = math.floor(120 * scaleY)
        
        local cookieW = Graphics.getImageWidth(Texture["Cookie"]) or 128
        local cookieH = Graphics.getImageHeight(Texture["Cookie"]) or 128
        
        Graphics.drawImageExtended(cookieX, cookieY, 0, 0, cookieW, cookieH, 0, cookieScale, cookieScale, Texture["Cookie"])
    end
    
    -- Draw about info
    local aboutY = math.floor(180 * scaleY)
    local lineHeight = math.floor(25 * scaleY)
    
    local gameTitle = "Cookie Clicker SDL"  
    local gameTitleWidth = string.len(gameTitle) * 8
    drawText(screenW/2 - gameTitleWidth/2, aboutY, gameTitle, white)
    aboutY = aboutY + lineHeight
    
    local desc1 = "A port of Cookie Clicker"
    local desc1Width = string.len(desc1) * 6  -- Small font width
    drawSmallText(screenW/2 - desc1Width/2, aboutY, desc1, white)
    aboutY = aboutY + lineHeight
    
    local desc2 = "for LPP-SDL Platform"
    local desc2Width = string.len(desc2) * 6
    drawSmallText(screenW/2 - desc2Width/2, aboutY, desc2, white)
    aboutY = aboutY + lineHeight * 2
    
    local creditsText = "CREDITS"
    local creditsWidth = string.len(creditsText) * 8
    drawText(screenW/2 - creditsWidth/2, aboutY, creditsText, white)
    aboutY = aboutY + lineHeight
    
    local credit1 = "Original Vita Version by Creckeryop"
    local credit1Width = string.len(credit1) * 6
    drawSmallText(screenW/2 - credit1Width/2, aboutY, credit1, white)
    aboutY = aboutY + lineHeight
    
    local credit2 = "Thanks to Rinnegatamante for Lua Player Plus Vita"
    local credit2Width = string.len(credit2) * 6
    drawSmallText(screenW/2 - credit2Width/2, aboutY, credit2, white)
    aboutY = aboutY + lineHeight
    
    local credit3 = "Cookie Clicker by Orteil/DashNet"
    local credit3Width = string.len(credit3) * 6
    drawSmallText(screenW/2 - credit3Width/2, aboutY, credit3, white)
    
    -- Draw LPP-SDL logo at bottom
    if Texture["LppSDL"] then
        local logoW = Graphics.getImageWidth(Texture["LppSDL"]) or 200
        local logoH = Graphics.getImageHeight(Texture["LppSDL"]) or 50
        local logoScale = math.min(screenW / logoW * 0.3, screenH / logoH * 0.2)  -- Scale to fit nicely
        local logoX = screenW/2
        local logoY = screenH - math.floor(60 * scaleY)  -- Position above instructions
        
        Graphics.drawImageExtended(logoX, logoY, 0, 0, logoW, logoH, 0, logoScale, logoScale, Texture["LppSDL"])
    end
    
    drawHints({{"B", "Back"}})
end

function drawUI()
    -- Draw panels
    drawPanels()
    
    -- Draw cookie counter in right panel (above cookie)
    local cookieCountX = PANEL_RIGHT_X + math.floor(10 * scaleX)
    local cookieCountY = math.floor(3 * scaleY)
    drawText(cookieCountX, cookieCountY, "COOKIES: " .. formatCookieCount(Cookie.count), white)
    
    -- Draw CPS below cookie counter
    local cps = 0
    for i = 1, #Button do
        local building = Button[i]
        if building then
            local quan = Upgrade[building.."Quan"] or 1
            cps = cps + Button[building.."count"] * Button[building.."cps"] * quan
        end
    end
    drawText(cookieCountX, cookieCountY + math.floor(20 * scaleY), "CPS: " .. formatCPS(cps), white)
    
    -- Draw vertical dividers (solid first, then gradients on top)
    if Texture["panelVertical"] then
        local verticalW = Graphics.getImageWidth(Texture["panelVertical"]) or 8
        local verticalH = Graphics.getImageHeight(Texture["panelVertical"]) or 1
        local verticalScaleX = math.floor(8 * scaleX) / verticalW
        local verticalScaleY = screenH / verticalH
        
        -- Draw solid dividers first
        Graphics.drawImageExtended(0, screenH/2, 0, 0, verticalW, verticalH, 0, verticalScaleX, verticalScaleY, Texture["panelVertical"])
        Graphics.drawImageExtended(PANEL_LEFT_WIDTH, screenH/2, 0, 0, verticalW, verticalH, 0, verticalScaleX, verticalScaleY, Texture["panelVertical"])
        Graphics.drawImageExtended(screenW, screenH/2, 0, 0, verticalW, verticalH, 0, verticalScaleX, verticalScaleY, Texture["panelVertical"])
        
        -- Draw gradients on top
        local leftW = Graphics.getImageWidth(Texture["panelGradientLeft"])
        local leftH = Graphics.getImageHeight(Texture["panelGradientLeft"])
        local gradientScaleX = math.floor(8 * scaleX) / leftW
        local gradientScaleY = screenH / leftH
        
        Graphics.drawImageExtended(0, screenH/2, 0, 0, leftW, leftH, 0, gradientScaleX, gradientScaleY, Texture["panelGradientLeft"])
        Graphics.drawImageExtended(PANEL_LEFT_WIDTH, screenH/2, 0, 0, leftW, leftH, 0, gradientScaleX, gradientScaleY, Texture["panelGradientLeft"])
        Graphics.drawImageExtended(screenW, screenH/2, 0, 0, leftW, leftH, 0, gradientScaleX, gradientScaleY, Texture["panelGradientRight"])
    end
end

-- Initialize timers
Timer.resume(timer)
Timer.resume(navTimer)
Timer.resume(buttonTimer)
Timer.resume(cookieTimer)
Timer.resume(autosaveTimer)

-- Initialize upgrade quantities for all buildings
Upgrade["CursorQuan"] = 1
Upgrade["GrandmaQuan"] = 1
Upgrade["FarmQuan"] = 1
Upgrade["MineQuan"] = 1
Upgrade["FactoryQuan"] = 1
Upgrade["BankQuan"] = 1
Upgrade["TempleQuan"] = 1
Upgrade["WizardTowerQuan"] = 1
Upgrade["ShipmentQuan"] = 1
Upgrade["AlchemyLabQuan"] = 1
Upgrade["PortalQuan"] = 1
Upgrade["TimeMachineQuan"] = 1
Upgrade["AntimatterCondenserQuan"] = 1
Upgrade["PrismQuan"] = 1

-- Initialize upgrade system
Upgrade.Now = {}

-- Upgrade management functions (from Vita version)
function Upgrade.update()
    -- Reset any upgrades that were marked as available but not purchased
    for i = 1, #Upgrade do
        if Upgrade[Upgrade[i].."a"] == 1 then
            Upgrade[Upgrade[i].."a"] = 0
        end
    end
    
    -- Clear current available upgrades
    for i = 1, #Upgrade.Now do
        table.remove(Upgrade.Now, 1)
    end
    
    -- Check which upgrades should be available (like Vita version)
    for i = 1, #Upgrade do
        local upgradeName = Upgrade[i]
        if Upgrade[upgradeName.."count"] <= Button[Upgrade[upgradeName.."name"].."count"] and Upgrade[upgradeName.."a"] == 0 then
            Upgrade[upgradeName.."a"] = 1
        end
        if Upgrade[upgradeName.."a"] == 1 then
            Upgrade.Now[#Upgrade.Now + 1] = upgradeName
        end
    end
end

function Upgrade.cps()
    -- Reset all upgrade quantities
    for i = 1, #Upgrade do
        Upgrade[Upgrade[Upgrade[i].."name"].."Quan"] = 1
    end
    -- Apply purchased upgrades (double CPS)
    for i = 1, #Upgrade do
        if Upgrade[Upgrade[i].."a"] == 2 then
            Upgrade[Upgrade[Upgrade[i].."name"].."Quan"] = Upgrade[Upgrade[Upgrade[i].."name"].."Quan"] * 2
        end
    end
end

-- Try to load saved game
loadGame()
updateSfxVolume()

-- Start background music for all screens if enabled
if AudioSettings.bgMusicEnabled then
    startBackgroundMusic()
end

-- Initialize upgrade system
Upgrade.update()
Upgrade.cps()


-- Main game loop
while true do
    -- Read controls once per frame
    local pad = Controls.read()
    
    
    handleInput(pad)
    
    -- Update shine rotation for all states (used in title screen and game)
    Shine.rot = Shine.rot + Shine.speed
    if Shine.rot >= 2 * pi then
        Shine.rot = Shine.rot - 2 * pi
    end
    
    -- Update cursor rotation (only used in game)
    if gameState == "Game" then
        Cursor.rot = Cursor.rot + Cursor.speed
        if Cursor.rot >= 2 * pi then
            Cursor.rot = Cursor.rot - 2 * pi
        end
    end
    
    -- Check music looping (in all states)
    checkMusicLoop()
    
    -- Passive cookie generation and upgrade updates (only in game)
    if gameState == "Game" and Timer.getTime(timer) >= 40 then
        local cps = 0
        for i = 1, #Button do
            local building = Button[i]
            if building then
                local quan = Upgrade[building.."Quan"] or 1
                cps = cps + Button[building.."count"] * Button[building.."cps"] * quan
            end
        end
        local cookiesFromBuildings = cps / 25
        Cookie.count = Cookie.count + cookiesFromBuildings
        Cookie.total = Cookie.total + cookiesFromBuildings
        
        -- Track max CpS achieved
        if cps > Cookie.maxCpS then
            Cookie.maxCpS = cps
        end
        
        -- Track production per building type
        for i = 1, #Button do
            local building = Button[i]
            if building then
                local quan = Upgrade[building.."Quan"] or 1
                local buildingCps = Button[building.."count"] * Button[building.."cps"] * quan
                Button[building.."produced"] = Button[building.."produced"] + buildingCps / 25
            end
        end
        
        -- Update available upgrades
        Upgrade.update()
        Upgrade.cps()
        
        Timer.reset(timer)
    end

    -- Autosave, so quitting with the system hotkey keeps recent progress
    if gameState == "Game" and Timer.getTime(autosaveTimer) >= AUTOSAVE_DELAY then
        saveGame()
        Timer.reset(autosaveTimer)
    end
    flushPendingSave()
    
    -- Render
    Graphics.initBlend()
    Screen.clear()
    
    -- Draw based on current game state
    if gameState == "Title" then
        drawTitleScreen()
    elseif gameState == "Game" then
        -- Draw background if available
        if Texture["Background"] then
            Graphics.drawImageExtended(screenW/2, screenH/2, 0, 0, 960, 544, 0, scaleX, scaleY, Texture["Background"])
        end
        
        -- Draw shaded borders over cookie section (like Vita version)
        if Texture["ShadedBorders"] then
            -- Cover the right panel (cookie area) - extend down to cover gap above milk
            local cookieAreaWidth = PANEL_RIGHT_WIDTH
            local cookieAreaHeight = screenH  -- Extend to full height to cover gap
            
            -- Scale the shadedBorders to cover the cookie area
            local borderW = Graphics.getImageWidth(Texture["ShadedBorders"]) or 256
            local borderH = Graphics.getImageHeight(Texture["ShadedBorders"]) or 256
            
            Graphics.drawImageExtended(PANEL_RIGHT_X + cookieAreaWidth/2, cookieAreaHeight/2, 
                                     0, 0, borderW, borderH, 0, 
                                     cookieAreaWidth/borderW, cookieAreaHeight/borderH, Texture["ShadedBorders"])
        end
        
        -- Draw all game UI components
        drawCookieShower()
        drawStoreBackground()
        drawMilk()
        drawBuildingsBackground()
        drawBuildings()
        drawCookie()
        drawStore()
        drawStoreMask()
        drawUpgrades()
        drawUI()
    elseif gameState == "Controls" then
        drawControlsScreen()
    elseif gameState == "Settings" then
        drawSettingsScreen()
    elseif gameState == "Statistics" then
        drawStatisticsScreen()
    elseif gameState == "About" then
        drawAboutScreen()
    end
    
    Graphics.termBlend()
    Screen.flip()
    Screen.waitVblankStart()
    
    -- Update oldpad at the very end of each frame
    oldpad = pad
end