PLUGIN.Title        = "Chat Handler"
PLUGIN.Description  = "Chat modification and moderation suite"
PLUGIN.Author       = "#Domestos"
PLUGIN.Version      = V(3, 0, 5)
PLUGIN.ResourceId   = 707

local debugMode = false

-- --------------------------------
-- declare some plugin wide vars
-- --------------------------------
local spamData = {}
local SpamList = "chathandler-spamlist"
local LogFile = "Log.ChatHandler.txt"
local AntiSpam, ChatHistory, AdminMode = {}, {}, {}
-- external plugin references
local eRanksAndTitles, eIgnoreAPI, eChatMute
-- --------------------------------
-- initialise all settings and data
-- --------------------------------
function PLUGIN:Init()
    self:LoadDefaultConfig()
    self:LoadChatCommands()
    self:LoadDataFiles()
    self:RegisterPermissions()
end
function PLUGIN:OnServerInitialized()
    eRanksAndTitles = plugins.Find("RanksAndTitles") or false
    eChatMute = plugins.Find("chatmute") or false
    eIgnoreAPI = plugins.Find("0ignoreAPI") or false
end
-- --------------------------------
-- debug reporting
-- --------------------------------
local function debug(msg)
    if not debugMode then return end
    --global.ServerConsole.PrintColoured(System.ConsoleColor.Yellow, msg)
    UnityEngine.Debug.Log.methodarray[0]:Invoke(nil, util.TableToArray({"[Debug] "..msg}))
end
-- --------------------------------
-- permission check
-- --------------------------------
local function HasPermission(player, perm)
    local steamID = rust.UserIDFromPlayer(player)
    if permission.UserHasPermission(steamID, "admin") then
        return true
    end
    if permission.UserHasPermission(steamID, perm) then
        return true
    end
    return false
end
-- --------------------------------
-- builds output messages by replacing wildcards
-- --------------------------------
local function buildOutput(str, tags, replacements)
    for i = 1, #tags do
        str = str:gsub(tags[i], replacements[i])
    end
    return str
end
-- --------------------------------
-- print functions
-- --------------------------------
local function printToConsole(msg)
    --global.ServerConsole.PrintColoured(System.ConsoleColor.Cyan, msg)
    UnityEngine.Debug.Log.methodarray[0]:Invoke(nil, util.TableToArray({msg}))
end
local function printToFile(msg)
    ConVar.Server.Log(LogFile, msg.."\n")
end
-- --------------------------------
-- splits chat messages longer than maxCharsPerLine characters into multilines
-- --------------------------------
local function splitLongMessages(msg, maxCharsPerLine)
    local length = msg:len()
    local msgTbl = {}
    if length > 128 then
        msg = msg:sub(1, 128)
    end
    if length > maxCharsPerLine then
        while length > maxCharsPerLine do
            local subStr = msg:sub(1, maxCharsPerLine)
            local first, last = string.find(subStr:reverse(), " ")
            if first then
                subStr = subStr:sub(1, -first)
            end
            table.insert(msgTbl, subStr)
            msg = msg:sub(subStr:len() + 1)
            length = msg:len()
        end
        table.insert(msgTbl, msg)
    else
        table.insert(msgTbl, msg)
    end
    return msgTbl
end
-- --------------------------------
-- generates default config
-- --------------------------------
function PLUGIN:LoadDefaultConfig() 
    self.Config.Settings                                = self.Config.Settings or {}
    -- General Settings
    self.Config.Settings.General                        = self.Config.Settings.General or {}
    self.Config.Settings.General.MaxCharsPerLine        = self.Config.Settings.General.MaxCharsPerLine or 64
    self.Config.Settings.General.BlockServerAds         = self.Config.Settings.General.BlockServerAds or "true"
    self.Config.Settings.General.AllowedIPsToPost       = self.Config.Settings.General.AllowedIPsToPost or {}
    self.Config.Settings.General.EnableChatHistory      = self.Config.Settings.General.EnableChatHistory or "true"
    self.Config.Settings.General.ChatHistoryMaxLines    = self.Config.Settings.General.ChatHistoryMaxLines or 10
    self.Config.Settings.General.EnableChatGroups       = self.Config.Settings.General.EnableChatGroups or "true"
    -- Wordfilter settings
    self.Config.Settings.Wordfilter                     = self.Config.Settings.Wordfilter or {}
    self.Config.Settings.Wordfilter.EnableWordfilter    = self.Config.Settings.Wordfilter.EnableWordfilter or "false"
    self.Config.Settings.Wordfilter.ReplaceFullWord     = self.Config.Settings.Wordfilter.ReplaceFullWord or "true"
    -- Chat commands
    self.Config.Settings.ChatCommands                   = self.Config.Settings.ChatCommands or {}
    self.Config.Settings.ChatCommands.AdminMode         = self.Config.Settings.ChatCommands.AdminMode or {"admin"}
    self.Config.Settings.ChatCommands.ChatHistory       = self.Config.Settings.ChatCommands.ChatHistory or {"history", "h"}
    self.Config.Settings.ChatCommands.Wordfilter        = self.Config.Settings.ChatCommands.Wordfilter or {"wordfilter"}
    -- command permissions
    self.Config.Settings.Permissions                    = self.Config.Settings.Permissions or {}
    self.Config.Settings.Permissions.AdminMode          = self.Config.Settings.Permissions.AdminMode or "canadminmode"
    self.Config.Settings.Permissions.EditWordFilter     = self.Config.Settings.Permissions.EditWordFilter or "caneditwordfilter"
    -- Logging settings
    self.Config.Settings.Logging                        = self.Config.Settings.Logging or {}
    self.Config.Settings.Logging.LogToConsole           = self.Config.Settings.Logging.LogToConsole or "true"
    self.Config.Settings.Logging.LogBlockedMessages     = self.Config.Settings.Logging.LogBlockedMessages or "true"
    self.Config.Settings.Logging.LogToFile              = self.Config.Settings.Logging.LogToFile or "false"
    -- Admin mode settings
    self.Config.Settings.AdminMode                      = self.Config.Settings.AdminMode or {}
    self.Config.Settings.AdminMode.ChatName             = self.Config.Settings.AdminMode.ChatName or "[Server Admin]"
    self.Config.Settings.AdminMode.NameColor            = self.Config.Settings.AdminMode.NameColor or "#ff8000"
    self.Config.Settings.AdminMode.TextColor            = self.Config.Settings.AdminMode.TextColor or "#ff8000"
    -- Antispam settings
    self.Config.Settings.AntiSpam                       = self.Config.Settings.AntiSpam or {}
    self.Config.Settings.AntiSpam.EnableAntiSpam        = self.Config.Settings.AntiSpam.EnableAntiSpam or "true"
    self.Config.Settings.AntiSpam.MaxLines              = self.Config.Settings.AntiSpam.MaxLines or 4
    self.Config.Settings.AntiSpam.TimeFrame             = self.Config.Settings.AntiSpam.TimeFrame or 6

    -- Chatgroups
    self.Config.ChatGroups = self.Config.ChatGroups or {
        ["Donator"] = {
            ["Permission"] = "donator",
            ["Prefix"] = "[$$$]",
            ["PrefixPosition"] = "left",
            ["PrefixColor"] = "#06DCFB",
            ["NameColor"] = "#5af",
            ["TextColor"] = "#ffffff",
            ["PriorityRank"] = 4,
            ["ShowPrefix"] = true
        },
        ["VIP"] = {
            ["Permission"] = "vip",
            ["Prefix"] = "[VIP]",
            ["PrefixPosition"] = "left",
            ["PrefixColor"] = "#59ff4a",
            ["NameColor"] = "#5af",
            ["TextColor"] = "#ffffff",
            ["PriorityRank"] = 3,
            ["ShowPrefix"] = true,
        },
        ["Admin"] = {
            ["Permission"] = "admin",
            ["Prefix"] = "[Admin]",
            ["PrefixPosition"] = "left",
            ["PrefixColor"] = "#FF7F50",
            ["NameColor"] = "#5af",
            ["TextColor"] = "#ffffff",
            ["PriorityRank"] = 5,
            ["ShowPrefix"] = true,
        },
        ["Moderator"] = {
            ["Permission"] = "moderator",
            ["Prefix"] = "[Mod]",
            ["PrefixPosition"] = "left",
            ["PrefixColor"] = "#FFA04A",
            ["NameColor"] = "#5af",
            ["TextColor"] = "#ffffff",
            ["PriorityRank"] = 2,
            ["ShowPrefix"] = true,
        },
        ["Player"] = {
            ["Permission"] = "player",
            ["Prefix"] = "[Player]",
            ["PrefixPosition"] = "left",
            ["PrefixColor"] = "#ffffff",
            ["NameColor"] = "#5af",
            ["TextColor"] = "#ffffff",
            ["PriorityRank"] = 1,
            ["ShowPrefix"] = false,
        }
    }
        -- Wordfilter
    self.Config.WordFilter = self.Config.WordFilter or {
        ["bitch"] = "sweety",
        ["fucking hell"] = "lovely heaven",
        ["cunt"] = "****"
    }
    -- Check wordfilter for conflicts
    if self.Config.Settings.Wordfilter.EnableWordfilter == "true" then
        for key, value in pairs(self.Config.WordFilter) do
            local first, _ = string.find(value:lower(), key:lower())
            if first then
                self.Config.WordFilter[key] = nil
                print("Config error in wordfilter: [\""..key.."\":\""..value.."\"] both contain the same word")
                print("[\""..key.."\":\""..value.."\"] was removed from word filter")
            end
        end
    end
    -- message settings
    self.Config.Messages                                             = self.Config.Messages or {}
    -- player messages
    self.Config.Messages.PlayerNotifications                         = self.Config.Messages.PlayerNotifications or {}
    self.Config.Messages.PlayerNotifications.AutoMuted               = self.Config.Messages.PlayerNotifications.AutoMuted or "You got {punishTime} auto muted for spam"
    self.Config.Messages.PlayerNotifications.SpamWarning             = self.Config.Messages.PlayerNotifications.SpamWarning or "If you keep spamming your punishment will raise"
    self.Config.Messages.PlayerNotifications.BroadcastAutoMutes      = self.Config.Messages.PlayerNotifications.BroadcastAutoMuted or "{name} got {punishTime} auto muted for spam"
    self.Config.Messages.PlayerNotifications.AdWarning               = self.Config.Messages.PlayerNotifications.AdWarning or "Its not allowed to advertise other servers"
    self.Config.Messages.PlayerNotifications.NoChatHistory           = self.Config.Messages.PlayerNotifications.NoChatHistory or "No chat history found"
    self.Config.Messages.PlayerNotifications.WordfilterList          = self.Config.Messages.PlayerNotifications.WordfilterList or "Blacklisted words: {wordFilterList}"
    -- admin messages
    self.Config.Messages.AdminNotifications                          = self.Config.Messages.AdminNotifications or {}
    self.Config.Messages.AdminNotifications.NoPermission             = self.Config.Messages.AdminNotifications.NoPermission or "You dont have permission to use this command"
    self.Config.Messages.AdminNotifications.AdminModeEnabled         = self.Config.Messages.AdminNotifications.AdminModeEnabled or "You are now in admin mode"
    self.Config.Messages.AdminNotifications.AdminModeDisabled        = self.Config.Messages.AdminNotifications.AdminModeDisabled or "Admin mode disabled"
    self.Config.Messages.AdminNotifications.WordfilterError          = self.Config.Messages.AdminNotifications.WordfilterError or "Error: {replacement} contains the word {word}"
    self.Config.Messages.AdminNotifications.WordfilterAdded          = self.Config.Messages.AdminNotifications.WordfilterAdded or "WordFilter added. {word} will now be replaced with {replacement}"
    self.Config.Messages.AdminNotifications.WordfilterRemoved        = self.Config.Messages.AdminNotifications.WordfilterRemoved or "successfully removed {word} from the wordfilter"
    self.Config.Messages.AdminNotifications.WordfilterNotFound       = self.Config.Messages.AdminNotifications.WordfilterNotFound or "No filter for {word} found to remove"
    -- helptext messages
    self.Config.Messages.Helptext                                    = self.Config.Messages.Helptext or {}
    self.Config.Messages.Helptext.Wordfilter                         = self.Config.Messages.Helptext.Wordfilter or "Use /wordfilter list to see blacklisted words"
    self.Config.Messages.Helptext.ChatHistory                        = self.Config.Messages.Helptext.ChatHistory or "Use /history or /h to view recent chat history"

    self:SaveConfig()
end
-- --------------------------------
-- load all chat commands, depending on settings
-- --------------------------------
function PLUGIN:LoadChatCommands()
    for _, cmd in pairs(self.Config.Settings.ChatCommands.AdminMode) do
        command.AddChatCommand(cmd, self.Object, "cmdAdminMode")
    end
    if self.Config.Settings.General.EnableChatHistory == "true" then
        for _, cmd in pairs(self.Config.Settings.ChatCommands.ChatHistory) do
            command.AddChatCommand(cmd, self.Object, "cmdHistory")
        end
    end
    if self.Config.Settings.Wordfilter.EnableWordfilter== "true" then
        for _, cmd in pairs(self.Config.Settings.ChatCommands.Wordfilter) do
            command.AddChatCommand(cmd, self.Object, "cmdEditWordFilter")
        end
    end
end
-- --------------------------------
-- handles all data files
-- --------------------------------
function PLUGIN:LoadDataFiles()
    spamData = datafile.GetDataTable(SpamList) or {}
end
-- --------------------------------
-- register all permissions
-- --------------------------------
function PLUGIN:RegisterPermissions()
    -- command permissions
    for _, perm in pairs(self.Config.Settings.Permissions) do
        if not permission.PermissionExists(perm) then
            permission.RegisterPermission(perm, self.Object)
        end
    end
    -- group permissions
    if self.Config.Settings.General.EnableChatGroups == "true" then
        for key, _ in pairs(self.Config.ChatGroups) do
            if not permission.PermissionExists(self.Config.ChatGroups[key].Permission) then
                permission.RegisterPermission(self.Config.ChatGroups[key].Permission, self.Object)
            end
        end
        -- grant default groups default permissions
        local defaultGroups = {"Player", "Moderator", "Admin"}
        for i = 1, 3, 1 do
            if not permission.GroupHasPermission(defaultGroups[i]:lower(), self.Config.ChatGroups[defaultGroups[i]].Permission) then
                permission.GrantGroupPermission(defaultGroups[i]:lower(), self.Config.ChatGroups[defaultGroups[i]].Permission, self.Object)
            end
        end
    end
end
-- --------------------------------
-- broadcasts chat messages
-- --------------------------------
function PLUGIN:BroadcastChat(player, name, msg)
    local senderSteamID = rust.UserIDFromPlayer(player)
    if AdminMode[senderSteamID] then
        senderSteamID = 0
        global.ConsoleSystem.Broadcast("chat.add", senderSteamID, name..msg)
        return
    end
    -- only send chat to people not ignoring sender
    if eIgnoreAPI then
        local enumPlayerList = global.BasePlayer.activePlayerList:GetEnumerator()
        while enumPlayerList:MoveNext() do
            local targetPlayer = enumPlayerList.Current
            local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
            local hasIgnored = eIgnoreAPI:Call("HasIgnored", targetSteamID, senderSteamID)
            if not hasIgnored then
                targetPlayer:SendConsoleCommand("chat.add", senderSteamID, name..msg)
            end
        end
        return
    end
    -- broadcast chat
    global.ConsoleSystem.Broadcast("chat.add", senderSteamID, name..msg)
end
-- --------------------------------
-- returns args as a table
-- --------------------------------
function PLUGIN:ArgsToTable(args, src)
    local argsTbl = {}
    if src == "chat" then
        local length = args.Length
        for i = 0, length - 1, 1 do
            argsTbl[i + 1] = args[i]
        end
        return argsTbl
    end
    if src == "console" then
        local i = 1
        while args:HasArgs(i) do
            argsTbl[i] = args:GetString(i - 1)
            i = i + 1
        end
        return argsTbl
    end
    return argsTbl
end
-- --------------------------------
-- handles chat command /admin
-- --------------------------------
function PLUGIN:cmdAdminMode(player)
    if not HasPermission(player, self.Config.Settings.Permissions.AdminMode) then
        rust.SendChatMessage(player, self.Config.Messages.AdminNotifications.NoPermission)
        return
    end
    local steamID = rust.UserIDFromPlayer(player)
    if AdminMode[steamID] then
        AdminMode[steamID] = nil
        rust.SendChatMessage(player, self.Config.Messages.AdminNotifications.AdminModeDisabled)
    else
        AdminMode[steamID] = true
        rust.SendChatMessage(player, self.Config.Messages.AdminNotifications.AdminModeEnabled)
    end
end
-- --------------------------------
-- handles chat messages
-- --------------------------------
function PLUGIN:OnPlayerChat(arg)
    local msg = arg:GetString(0, "text")
    local player = arg.connection.player
    if msg:sub(1, 1) == "/" or msg == "" then return end
    local steamID = rust.UserIDFromPlayer(player)
    if eChatMute then
        local isMuted = eChatMute:Call("IsMuted", player)
        -- if muted abort chat handling and let chatmute handle chat canceling
        if isMuted then return end
    end
    -- Spam prevention
    if eChatMute and self.Config.Settings.AntiSpam.EnableAntiSpam == "true" then
        local isSpam, punishTime = self:AntiSpamCheck(player)
        if isSpam then
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.PlayerNotifications.AutoMuted, {"{punishTime}"}, {punishTime}))
            timer.Once(4, function() rust.SendChatMessage(player, self.Config.Messages.PlayerNotifications.SpamWarning) end)
            if self.Config.Settings.General.BroadcastMutes == "true" then
                rust.BroadcastChat(buildOutput(self.Config.Messages.PlayerNotifications.BroadcastAutoMuted, {"{name}", "{punishTime}"}, {player.displayName, punishTime}))
            end
            if self.Config.Settings.Logging.LogToConsole == "true" then
                printToConsole("[ChatHandler] "..player.displayName.." got a "..punishTime.." auto mute for spam")
            end
            if self.Config.Settings.Logging.LogToFile == "true" then
                printToFile(player.displayName.." got a "..punishTime.." auto mute for spam")
            end
            return false
        end
    end
    -- Parse message to filter stuff and check if message should be blocked
    local canChat, msg, errorMsg, errorPrefix = self:ParseChat(player, msg)
    -- Chat is blocked
    if not canChat then
        if self.Config.Settings.Logging.LogBlockedMessages == "true" then
            if self.Config.Settings.Logging.LogToConsole == "true" then
                --global.ServerConsole.PrintColoured(System.ConsoleColor.Cyan, errorPrefix, System.ConsoleColor.DarkYellow, " "..player.displayName..": ", System.ConsoleColor.DarkGreen, msg)
                UnityEngine.Debug.Log.methodarray[0]:Invoke(nil, util.TableToArray({errorPrefix.." "..player.displayName..": "..msg}))
            end
            if self.Config.Settings.Logging.LogToFile == "true" then
                printToFile(errorPrefix.." "..steamID.."/"..player.displayName..": "..msg.."\n")
            end
        end
        rust.SendChatMessage(player, errorMsg)
        return false
    end
    -- Chat is ok and not blocked
    local maxCharsPerLine = tonumber(self.Config.Settings.General.MaxCharsPerLine)
    msg = splitLongMessages(msg, maxCharsPerLine) -- msg is a table now
    local i = 1
    while msg[i] do
        local username, message, logUsername, logMessage = self:BuildNameMessage(player, msg[i])
        self:SendChat(player, username, message, logUsername, logMessage)
        i = i + 1
    end
    return false
end
-- --------------------------------
-- checks for chat spam
-- returns (bool)IsSpam, (string)punishTime
-- --------------------------------
function PLUGIN:AntiSpamCheck(player)
    local steamID = rust.UserIDFromPlayer(player)
    local now = time.GetUnixTimestamp()
    if eChatMute:Call("muteData", steamID) then return false, false end
    if AdminMode[steamID] then return false, false end
    if AntiSpam[steamID] then
        local firstMsg = AntiSpam[steamID].timestamp
        local msgCount = AntiSpam[steamID].msgcount
        if msgCount < self.Config.Settings.AntiSpam.MaxLines then
            AntiSpam[steamID].msgcount = AntiSpam[steamID].msgcount + 1
            return false, false
        else
            if now - firstMsg <= self.Config.Settings.AntiSpam.TimeFrame then
                -- punish
                local punishCount = 1
                local expiration, punishTime, newEntry
                if spamData[steamID] then
                    newEntry = false
                    punishCount = spamData[steamID].punishcount + 1
                    spamData[steamID].punishcount = punishCount
                    datafile.SaveDataTable(SpamList)
                end
                if punishCount == 1 then
                    expiration =  now + 300
                    punishTime = "5 minutes"
                elseif punishCount == 2 then
                    expiration = now + 3600
                    punishTime = "1 hour"
                else
                    expiration = 0
                    punishTime = "permanent"
                end
                if newEntry ~= false then
                    spamData[steamID] = {}
                    spamData[steamID].steamID = steamID
                    spamData[steamID].punishcount = punishCount
                    table.insert(spamData, spamData[steamID])
                    datafile.SaveDataTable(SpamList)
                end
                local apimuted = eChatMute:Call("APIMute", steamID, expiration)
                AntiSpam[steamID] = nil
                return true, punishTime
            else
                AntiSpam[steamID].timestamp = now
                AntiSpam[steamID].msgcount = 1
                return false, false
            end
        end
    else
        AntiSpam[steamID] = {}
        AntiSpam[steamID].timestamp = now
        AntiSpam[steamID].msgcount = 1
        return false, false
    end
end
-- --------------------------------
-- parses the chat
-- returns (bool)canChat, (string)msg, (string)errorMsg, (string)errorPrefix
-- --------------------------------
function PLUGIN:ParseChat(player, msg)
    local msg = tostring(msg)
    local steamID = rust.UserIDFromPlayer(player)
    if AdminMode[steamID] then return true, msg, false, false end
    -- Check for server advertisements
    if self.Config.Settings.General.BlockServerAds == "true" then
        local ipCheck
        local ipString = ""
        local chunks = {msg:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
        if #chunks == 4 then
            for _, v in pairs(chunks) do
                if tonumber(v) < 0 or tonumber(v) > 255 then
                    ipCheck = false
                    break
                end
                ipString = ipString..v.."."
                ipCheck = true
            end
            -- remove the last dot
            if ipString:sub(-1) == "." then
                ipString = ipString:sub(1, -2)
            end
        else
            ipCheck = false
        end
        if ipCheck then
            local allowedIP = false
            for key, value in pairs(self.Config.Settings.General.AllowedIPsToPost) do
                if self.Config.Settings.General.AllowedIPsToPost[key]:match(ipString) then
                    allowedIP = true
                end
            end
            if not allowedIP then
                return false, msg, self.Config.Messages.PlayerNotifications.AdWarning, "[BLOCKED]"
            end
        end
    end
    -- Check for blacklisted words
    if self.Config.Settings.Wordfilter.EnableWordfilter== "true" then
        for key, value in pairs(self.Config.WordFilter) do
            local first, last = string.find(msg:lower(), key:lower(), nil, true)
            if first then
                while first do
                    local before = msg:sub(1, first - 1)
                    local after = msg:sub(last + 1)
                    -- replace whole word if parts are blacklisted
                    if self.Config.Settings.Wordfilter.ReplaceFullWord == "true" then
                        if before:sub(-1) ~= " " and before:len() > 0 then
                            local spaceStart, spaceEnd = string.find(before:reverse(), " ")
                            if spaceStart then
                                before = before:sub(spaceStart + 1):reverse()
                            else
                                before = ""
                            end
                        end
                        if after:sub(1, 1) ~= " " and after:len() > 0 then
                            local spaceStart, spaceEnd = after:find(" ")
                            if spaceStart then
                                after = after:sub(spaceStart)
                            else
                                after = ""
                            end
                        end
                    end
                    msg = before..value..after
                    first, last = string.find(msg:lower(), key:lower(), nil, true)
                end
            end
        end
    end
    -- show dem sneaky color tags
    msg = msg:gsub("<[cC][oO][lL][oO][rR]", "<\\color\\")
    msg = msg:gsub("[cC][oO][lL][oO][rR]>", "\\color\\>")
    return true, msg, false, false
end
-- --------------------------------
-- builds username and chatmessage
-- returns (string)username, (string)message, (string)logUsername, (string)logMessage
-- --------------------------------
function PLUGIN:BuildNameMessage(player, msg)
    local username, logUsername = player.displayName, player.displayName
    local message, logMessage = msg, msg
    local steamID = rust.UserIDFromPlayer(player)
    if AdminMode[steamID] then
        username = "<color="..self.Config.Settings.AdminMode.NameColor..">"..self.Config.Settings.AdminMode.ChatName.."</color>"
        message = "<color="..self.Config.Settings.AdminMode.TextColor..">: "..message.."</color>"
        logUsername = self.Config.Settings.AdminMode.ChatName..":"
        return username, message, logUsername, logMessage
    end
    if self.Config.Settings.General.EnableChatGroups == "true" then
        local priorityRank = 0
        local msgcolor, namecolor = "", ""
        for key, _ in pairs(self.Config.ChatGroups) do
            if permission.UserHasPermission(steamID, self.Config.ChatGroups[key].Permission) then
                if self.Config.ChatGroups[key].ShowPrefix then
                    if self.Config.ChatGroups[key].PrefixPosition == "left" then
                        username = "<color="..self.Config.ChatGroups[key].PrefixColor..">"..self.Config.ChatGroups[key].Prefix.."</color> "..username
                        logUsername = self.Config.ChatGroups[key].Prefix.." "..logUsername
                    else
                        username = username.." <color="..self.Config.ChatGroups[key].PrefixColor..">"..self.Config.ChatGroups[key].Prefix.."</color>"
                        logUsername = logUsername.." "..self.Config.ChatGroups[key].Prefix
                    end
                end
                if self.Config.ChatGroups[key].PriorityRank > priorityRank then
                    msgcolor = self.Config.ChatGroups[key].TextColor
                    namecolor = self.Config.ChatGroups[key].NameColor
                    priorityRank = self.Config.ChatGroups[key].PriorityRank
                end
            end
        end
        -- insert colors for name and message
        local first, last = username:find(player.displayName, 1, true)
        username = username:sub(1, first - 1).."<color="..namecolor..">"..player.displayName.."</color>"..username:sub(last + 1)
        message = "<color="..msgcolor..">: "..msg.."</color>"
    end
    -- Add title if plugin RanksAndTitles is installed
    if eRanksAndTitles then
        local title = eRanksAndTitles:Call("grabPlayerData", steamID, "Title")
        local hideTitle = eRanksAndTitles:Call("grabPlayerData", steamID, "hidden")
        local colorOn = eRanksAndTitles.Config.Settings.colorSupport
        local color = eRanksAndTitles:Call("getColor", steamID)
        if not hideTitle and title ~= "" and colorOn then
            username = username.."<color="..color.."> ["..title.."]</color>"
            logUsername = logUsername.." ["..title.."]"
        end
        if not hideTitle and title ~= "" and not colorOn then
            if username:sub(-8) == "</color>" then
                username = username:sub(1, -9).." ["..title.."]</color>"
                logUsername = logUsername.." ["..title.."]"
            else
                username = username.." ["..title.."]"
                logUsername = logUsername.." ["..title.."]"
            end
        end
    end
    return username, message, logUsername, logMessage
end
-- --------------------------------
-- sends and logs chat messages
-- --------------------------------
function PLUGIN:SendChat(player, name, msg, logName, logMsg)
    local steamID = rust.UserIDFromPlayer(player)
    -- Broadcast chat ingame
    self:BroadcastChat(player, name, msg)
    -- Log chat to console
    --global.ServerConsole.PrintColoured(System.ConsoleColor.DarkYellow, logName..": ", System.ConsoleColor.DarkGreen, logMsg)
    UnityEngine.Debug.Log.methodarray[0]:Invoke(nil, util.TableToArray({"[CHAT] "..logName..": "..logMsg}))
    -- Log chat to log file
    ConVar.Server.Log("Log.Chat.txt", steamID.."/"..logName..": "..logMsg.."\n")
    -- Log chat history
    if self.Config.Settings.General.EnableChatHistory == "true" then
        self:InsertHistory(name, steamID, msg)
    end
end
-- --------------------------------
-- remove data on disconnect
-- --------------------------------
function PLUGIN:OnPlayerDisconnected(player)
    local steamID = rust.UserIDFromPlayer(player)
    AntiSpam[steamID] = nil
    AdminMode[steamID] = nil
end
-- --------------------------------
-- handles chat command for chat history
-- --------------------------------
function PLUGIN:cmdHistory(player)
    if #ChatHistory > 0 then
        rust.SendChatMessage(player, "ChatHistory", "----------")
        local i = 1
        while ChatHistory[i] do
            rust.SendChatMessage(player, ChatHistory[i].name, ChatHistory[i].msg, ChatHistory[i].steamID)
            i = i + 1
        end
        rust.SendChatMessage(player, "ChatHistory", "----------")
    else
        rust.SendChatMessage(player, "ChatHistory", self.Config.Messages.PlayerNotifications.NoChatHistory)
    end
end
-- --------------------------------
-- inserts chat messages into history
-- --------------------------------
function PLUGIN:InsertHistory(name, steamID, msg)
    if #ChatHistory == self.Config.Settings.General.ChatHistoryMaxLines then
        table.remove(ChatHistory, 1)
    end
    table.insert(ChatHistory, {["name"] = name, ["steamID"] = steamID, ["msg"] = msg})
end
-- --------------------------------
-- handles chat command /wordfilter
-- --------------------------------
function PLUGIN:cmdEditWordFilter(player, cmd, args)
    local args = self:ArgsToTable(args, "chat")
    local func, word, replacement = args[1], args[2], args[3]
    if not func or func ~= "add" and func ~= "remove" and func ~= "list" then
        if not HasPermission(player, self.Config.Settings.Permissions.EditWordFilter) then
            rust.SendChatMessage(player, "Syntax /wordfilter list")
        else
            rust.SendChatMessage(player, "Syntax: /wordfilter add <word> <replacement> or /wordfilter remove <word>")
        end
        return
    end
    if func ~= "list" and not HasPermission(player, self.Config.Settings.Permissions.EditWordFilter) then
        rust.SendChatMessage(player, self.Config.Messages.AdminNotifications.NoPermission)
        return
    end
    if func == "add" then
        if not replacement then
            rust.SendChatMessage(player, "Syntax: /wordfilter add <word> <replacement>")
            return
        end
        local first, last = string.find(replacement:lower(), word:lower())
        if first then
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.AdminNotifications.WordfilterError, {"{replacement}", "{word}"}, {replacement, word}))
            return
        else
            self.Config.WordFilter[word] = replacement
            self:SaveConfig()
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.AdminNotifications.WordfilterAdded, {"{word}", "{replacement}"}, {word, replacement}))
        end
        return
    end
    if func == "remove" then
        if not word then
            rust.SendChatMessage(player, "Syntax: /wordfilter remove <word>")
            return
        end
        if self.Config.WordFilter[word] then
            self.Config.WordFilter[word] = nil
            self:SaveConfig()
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.AdminNotifications.WordfilterRemoved, {"{word}"}, {word}))
        else
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.AdminNotifications.WordfilterNotFound, {"{word}"}, {word}))
        end
        return
    end
    if func == "list" then
        local wordFilterList = ""
        for key, _ in pairs(self.Config.WordFilter) do
            wordFilterList = wordFilterList..key..", "
        end
        rust.SendChatMessage(player, buildOutput(self.Config.Messages.PlayerNotifications.WordfilterList, {"{wordFilterList}"}, {wordFilterList}))
    end
end
-- --------------------------------
-- handles chat command /help
-- --------------------------------
function PLUGIN:SendHelpText(player)
    if self.Config.Settings.General.EnableChatHistory == "true" then
        rust.SendChatMessage(player, self.Config.Messages.Helptext.ChatHistory)
    end
    if self.Config.Settings.Wordfilter.EnableWordfilter == "true" then
        rust.SendChatMessage(player, self.Config.Messages.Helptext.Wordfilter)
    end
end

