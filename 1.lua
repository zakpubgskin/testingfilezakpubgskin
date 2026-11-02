-- =========================================================================

-- =========================================================================

-- =========================================================================
-- 0 — Package detection & paths
-- =========================================================================
local SUPPORTED_PACKAGES = {
    ["com.tencent.ig"]        = "Global",
    ["com.pubg.krmobile"]     = "Korea",
    ["com.vng.pubgmobile"]    = "Vietnam",
    ["com.rekoo.pubgm"]       = "Taiwan",
    ["com.pubg.imobile"]      = "BGMI",
    ["com.pubg.krmobile.ig"]  = "Korea-Alt",
    ["com.tencent.tmgp.pubgmhd"] = "CN",
    ["com.tencent.tmgp.pubgm"] = "CN-Alt",
}

local packageName = nil
local gameRegion = "Unknown"

pcall(function()
    local KSL = import("KismetSystemLibrary")
    if KSL and KSL.GetGameBundleId then
        packageName = KSL:GetGameBundleId()
    end
end)

if not packageName then
    local probes = {
        "com.tencent.ig", "com.pubg.krmobile", "com.vng.pubgmobile",
        "com.rekoo.pubgm", "com.pubg.imobile", "com.tencent.tmgp.pubgmhd",
        "com.tencent.tmgp.pubgm"
    }
    for _, pkg in ipairs(probes) do
        local f = io.open("//storage/emulated/0/Android/data/" .. pkg .. "/", "r")
        if f then f:close() packageName = pkg break end
    end
end

if not packageName then
    packageName = "com.tencent.ig"
end

gameRegion = SUPPORTED_PACKAGES[packageName] or "Unknown"
print("[PSYCO MOD] Package: " .. packageName .. " (" .. gameRegion .. ")")

local PATHS = {
    PubgData  = "//storage/emulated/0/Android/data/" .. packageName .. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/",
    Paks      = nil,
    SaveGames = nil,
    Cache     = nil,
}
PATHS.Paks      = PATHS.PubgData .. "Paks/"
PATHS.SaveGames = PATHS.PubgData .. "SaveGames/"
PATHS.Cache     = PATHS.PubgData .. "image_download_mgr/temporary/Daliy/imgdownload_20713/"

-- =========================================================================
-- 1 — RPC registry
-- =========================================================================
local BRPlayerCharacterBase = { ServerRPC = {}, ClientRPC = {}, MulticastRPC = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = { Reliable = true, Params = { UEnums.EPropertyClass.Object } }
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = { Reliable = true, Params = { UEnums.EPropertyClass.Bool } }
BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = { Reliable = true, Params = { UEnums.EPropertyClass.UInt32, UEnums.EPropertyClass.UInt32 } }

local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")

local GameplayData = nil
pcall(function() GameplayData = require("GameLua.GameCore.Data.GameplayData") end)
if not GameplayData then
    pcall(function() GameplayData = require("GameLua.GameCore.Data.GameplayData") end)
end

local GamePlayTools = nil
pcall(function() GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools") end)
if not GamePlayTools then
    pcall(function() GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools") end)
end

-- =========================================================================
-- 2 — Safe helpers
-- =========================================================================
local function safeRequire(...)
    local ok, result = pcall(require, ...)
    if ok and result then return result end
    return nil
end

local function safeTryModule(paths)
    for _, p in ipairs(paths) do
        local m = safeRequire(p)
        if m then return m, p end
    end
    return nil, nil
end

local function safeImport(name)
    local ok, result = pcall(import, name)
    if ok and result then return result end
    return nil
end

local IS_32BIT = false
pcall(function()
    if jit and jit.arch then
        IS_32BIT = (jit.arch == "x86" or jit.arch == "arm")
    else
        local probe = collectgarbage("count")
        IS_32BIT = (probe > 0 and tostring(2^31) ~= "2147483648")
    end
end)

local LIMITS = {
    MAX_BOT_CACHE       = IS_32BIT and 200 or 800,
    MAX_VIS_CACHE       = IS_32BIT and 60  or 200,
    MAX_MID_CACHE       = IS_32BIT and 120 or 500,
    MAX_ENEMY_MARKS     = IS_32BIT and 40  or 100,
    MAX_TRACKED_MARKS   = IS_32BIT and 80  or 250,
    ESP_MAX_DISTANCE    = IS_32BIT and 250 or 400,
    BONE_ESP_MAX_DIST   = IS_32BIT and 100 or 250,
    AIMBOT_TICK         = IS_32BIT and 0.033 or 0.016,
    MAIN_TICK           = IS_32BIT and 0.4   or 0.3,
    CONFIG_SAVE_INTERVAL= IS_32BIT and 10    or 3,
    AUTO_HEAD_DEFAULT   = not IS_32BIT,
    ESP6_DEFAULT        = not IS_32BIT,
    ESPVIPPRO_DEFAULT   = not IS_32BIT,
    MAX_ESP_LINES       = IS_32BIT and 15  or 40,
    ESP_LINE_UPDATE     = IS_32BIT and 0.033 or 0.016,
    ESP_LINE_THICKNESS  = 0.8,
    ESP_LINE_MAX_DIST   = IS_32BIT and 300 or 600,
    ESP_LINE_SMOOTH     = 0.35,
    VIS_CACHE_TIME      = 0.15,
}

-- =========================================================================
-- 3 — Expiry gate (fail-open)
-- =========================================================================
local limitTime = os.time({ year = 2027, month = 12, day = 31, hour = 23, min = 59, sec = 0 })
local currentTime = os.time(os.date("!*t"))
local isExpired = false

pcall(function()
    local fileName = ".sys_time_cache"
    local paths = {
        PATHS.SaveGames .. fileName,
        PATHS.Cache .. fileName,
        "ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "../../ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
    }
    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then
        local s, r = pcall(require, "client.logic.common.TimeManager")
        if s and r then tm = r end
    end
    if tm and type(tm.GetServerTime) == "function" then
        local serverTime = tm.GetServerTime()
        if serverTime and serverTime > 1700000000 then currentTime = serverTime end
    end
    local lastSeenTime = 0
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local savedTime = tonumber(data) or 0
            if savedTime > lastSeenTime then lastSeenTime = savedTime end
            file:close()
        end
    end
    if currentTime < lastSeenTime then
        currentTime = lastSeenTime
    else
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then file:write(tostring(currentTime)); file:close() end
        end
    end
end)

-- PSYCO PATCH: fail-open
if not currentTime or currentTime <= 0 then
    isExpired = false
else
    isExpired = (currentTime > limitTime)
end

-- =========================================================================
-- 4 — Universal bypass — layers 1..20
-- =========================================================================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retTrue() return true end
local function retEmptyStr() return "" end
local function retNil() return nil end

-- -------------------------------------------------------------------------
-- PSYCO PATCH: SAFE_KEYWORDS — expanded
-- -------------------------------------------------------------------------
local SAFE_KEYWORDS = {
    "bat", "twilight", "transform", "vampire", "hunter", "bloodline",
    "chakra", "jutsu", "naruto", "spider", "kurama", "hero", "suit",
    "skill", "ability", "emote", "item", "use", "pickup", "trigger",
    "character", "pawn", "player", "controller", "feature",
    "revive", "respawn", "death", "damage", "health", "rescue", "giveup",
    "near", "state", "movement", "pose", "anim", "skeletal", "mesh",
    "attach", "detach", "carry", "deadbox", "tomb",
    "vehicle", "weapon", "camera",
    "chat", "message", "input", "key", "button",
    "parachute", "landing", "recycle", "recycled", "spawn",
    "replication", "replicate", "flar", "flare",
    "simulate", "modifier",
}

local function isSafeName(name)
    if not name then return false end
    local lower = string.lower(tostring(name))
    for _, kw in ipairs(SAFE_KEYWORDS) do
        if string.find(lower, kw, 1, true) then
            return true
        end
    end
    return false
end

_G.RJ_IsSafeName = isSafeName

-- -------------------------------------------------------------------------
-- PSYCO PATCH: HARD_EXCLUDE — subsystems/features that must NEVER be touched.
-- This is the character-stuck fix. Checked BEFORE the keyword filter runs.
-- -------------------------------------------------------------------------
local HARD_EXCLUDE = {
    ["SimulateCharacterSubsystem"]     = true,
    ["ModifierExceptionSubsystem"]     = true,
    ["CarryDeadBoxFeature"]            = true,
    ["SpecialSuitFeature"]             = true,
    ["TeleportPawnFeature"]            = true,
    ["LifterControl"]                  = true,
    ["FinalKillEffect"]                = true,
    ["CampFeature"]                    = true,
    ["BuildAircraftVehicleFeature"]    = true,
    ["UnifiedBuildVehicleFeature"]     = true,
    ["CommonBornlandTransformFeature"] = true,
    ["ParachuteFormation"]             = true,
    ["ParachuteSprint"]                = true,
    ["GeneralShowSpotFeature"]         = true,
    ["FPPAnimMonitor"]                 = true,
    ["SkyTransition"]                  = true,
    ["CharacterLifterControlFeature"]  = true,
    ["PlayerCharacterFinalKillEffectFeature"] = true,
    ["PlayerCharacterCampFeature"]     = true,
    ["PlayerCharacterBuildVehicleFeature"] = true,
    ["ParachuteFormationFeature"]      = true,
}

local function isHardExcluded(name)
    if not name then return false end
    local s = tostring(name)
    if HARD_EXCLUDE[s] then return true end
    for k, _ in pairs(HARD_EXCLUDE) do
        if string.find(s, k, 1, true) then return true end
    end
    return false
end

local function patchModule(module, funcs, replacement)
    if not module then return 0 end
    local count = 0
    pcall(function()
        for _, fn in ipairs(funcs) do
            if type(module[fn]) == "function" then
                if isHardExcluded(fn) then goto skip_fn end
                if isSafeName(fn) then goto skip_fn end
                module[fn] = replacement or nop
                count = count + 1
                ::skip_fn::
            end
        end
    end)
    return count
end

-- -------------------------------------------------------------------------
-- 4.1 — Core Higgs / TSS / ACE bypass
-- -------------------------------------------------------------------------
local function InitializeCoreBypass()
    pcall(function()
        local TssSdk = _G.TssSdk or package.loaded["TssSdk"]
        if TssSdk then
            for _, k in ipairs({"OnRecvData","SendReportInfo","ReportException","ReportData","UploadLog","SendAntiData","ReportGameStart","ReportGameEnd","ReportCrash","ReportViolation","ReportSuspicious","ReportBan","ReportKick","ReportWarning","ReportInfo","ReportDebug","ReportError","ReportFatal","ReportMemory","ReportProcess","ReportModule","ReportThread","ReportFile","ReportNetwork","ReportDevice","ReportSystem","ReportGame","ReportUser","ReportAccount","ReportSession","ReportPerformance","ReportBattery","ReportTemperature","ReportFPS","ReportPing","ReportPacket","ReportCheat","ReportHack","ReportMod","ReportInject","ReportDebugger","ReportEmulator","ReportRoot","ReportJailbreak","ReportVM","ReportHook","ReportPatch","ReportTamper","ReportCorrupt","ReportInvalid","ReportSpoof","ReportFake","ReportClone","ReportDuplicate","ReportConflict","ReportOverlap","ReportMismatch","ReportInconsistent","ReportUnexpected","ReportUnknown"}) do
                pcall(function() TssSdk[k] = nop end)
            end
            TssSdk.ScanMemory = retTrue
            TssSdk.IsEmulator = retFalse
            TssSdk.GetTssSdkReportInfo = retEmptyStr
            TssSdk.CheckIntegrity = retTrue
            TssSdk.VerifySignature = retTrue
            TssSdk.CollectEvidence = retNil
            TssSdk.GetModuleHash = function() return "82918E1FE1BE4186CFD2F1286951B2A0" end
            TssSdk.VerifyModule = retTrue
            TssSdk.ScanProcess = retEmpty
        end

        local ace = _G.ace or package.loaded["libace.so"]
        if ace then
            patchModule(ace, {"ReportData","ReportViolation","KickPlayer","BanPlayer","SendReport","ReportCheat","ReportHack","ReportMod","ReportInject","ReportHook","ReportPatch","ReportTamper","ReportCorrupt","ReportInvalid","ReportSpoof","ReportFake"})
            ace.CheckIntegrity = retTrue; ace.ScanMemory = retFalse
            ace.VerifyProcess = retTrue; ace.CheckModule = retTrue
            ace.CollectInfo = retEmpty; ace.ValidateClient = retTrue
            ace.CheckDebugger = retFalse; ace.CheckEmulator = retFalse; ace.CheckRoot = retFalse
        end

        local XignCode = _G.XignCode or package.loaded["xigncode"]
        if XignCode then
            patchModule(XignCode, {"SendReport","ReportException","KickPlayer","BanPlayer","ReportCheat","ReportHack","ReportMod","ReportInject","ReportHook","ReportPatch","ReportTamper"})
            XignCode.CheckProcess = retTrue; XignCode.VerifyIntegrity = retTrue
            XignCode.ScanModules = retEmpty; XignCode.ValidateMemory = retTrue
            XignCode.CheckDebugger = retFalse
            XignCode.EncryptData = function(d) return d end
            XignCode.DecryptData = function(d) return d end
        end

        local higgsPaths = {
            "GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent",
            "GameLua.Mod.BaseMod.Common.Security.HiggsBoson",
            "GameLua.Mod.BaseMod.Client.Security.HiggsBosonComponent",
            "Mod.BaseMod.Common.Security.HiggsBosonComponent",
        }
        for _, path in ipairs(higgsPaths) do
            local Higgs = package.loaded[path]
            if not Higgs then
                local ok, m = pcall(require, path)
                if ok then Higgs = m end
            end
            if Higgs then
                Higgs.bIsEnable = false; Higgs.bMHActive = false; Higgs.bCallPreReplication = false
                Higgs.StaticShowSecurityAlertInDev = nop
                Higgs.CheckClientConfig = retFalse
                Higgs.GetSecurityInfo = retEmpty
                Higgs.ReportSecurityAlert = nop
                Higgs.ValidateClient = retTrue
                Higgs.CheckIntegrity = retTrue
                Higgs.IsMHActive = retFalse
                Higgs.ControlMHActive = nop
                Higgs.CheckMHActive = retFalse
                Higgs.ShouldRunMH = retFalse
                if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
                break
            end
        end
        _G.BlackList = {}
    end)
end

-- -------------------------------------------------------------------------
-- 4.2 — SLUA / MD5 / signature bypass
-- -------------------------------------------------------------------------
local function InitializeSLUA_MD5()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then slua_serialize.check = retTrue; slua_serialize.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end

        local console = safeImport("KismetSystemLibrary")
        if console then
            pcall(function() console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1") end)
            pcall(function() console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0") end)
            pcall(function() console.ExecuteConsoleCommand(nil, "s.VerifyPak 0") end)
            pcall(function() console.ExecuteConsoleCommand(nil, "sig.Check 0") end)
            pcall(function() console.ExecuteConsoleCommand(nil, "security.DisableChecks 1") end)
        end
        local CMode = safeImport("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
            CMode.VerifyContent = retTrue
            CMode.ValidateContent = retTrue
            CMode.CheckContent = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        if _G.SHA256 then _G.SHA256 = function() return "BYPASSED_SHA256" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue
            FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local STExtra = safeImport("STExtraBlueprintFunctionLibrary")
        if STExtra then
            STExtra.CheckMD5 = retTrue
            STExtra.GetMD5 = function() return "BYPASS" end
            STExtra.VerifyFile = retTrue
            STExtra.IsDevelopment = retFalse
            STExtra.CheckFileIntegrity = retTrue
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.3 — Log / screenshot / crash bypass
-- -------------------------------------------------------------------------
local function InitializeLogBlocker()
    pcall(function()
        local SMTD = safeImport("ScreenshotMTDer")
        if SMTD then
            SMTD.MTDePicture = retEmptyStr
            SMTD.ReMTDePicture = retEmptyStr
            SMTD.HasCaptured = retTrue
            SMTD.TakeScreenshot = nop
        end
        local SM = safeImport("ScreenshotMaker")
        if SM then
            SM.MakePicture = retEmptyStr
            SM.ReMakePicture = retEmptyStr
            SM.HasCaptured = retTrue
            SM.TakeScreenshot = nop
            SM.SaveScreenshot = nop
            SM.CaptureScreen = nop
            SM.RecordScreen = nop
        end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then
            patchModule(TLog, {"Info","Warning","Error","Debug","Report","Send","Flush","Log","LogWarning","LogError","LogVerbose","SetLogLevel"})
        end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then
            patchModule(CrashSight, {"ReportException","SetCustomData","Log","SendCrash","ReportUserException","UploadLog","SendReport","ReportCrash","ReportError","ReportFatal","ReportWarning","ReportInfo","ReportDebug","ReportMemory","ReportPerformance"})
            CrashSight.CollectInfo = retEmpty
        end

        local grPaths = {
            "GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils",
            "GameLua.Mod.BaseMod.Gameplay.GameReport.GameReportUtils",
        }
        local GRUtils = safeTryModule(grPaths)
        if GRUtils then
            GRUtils.BugglyPostExceptionFull = retFalse
            GRUtils.CheckCanBugglyPostException = retFalse
            GRUtils.ReplayReportData = nop
            GRUtils.ReportGameException = nop
            GRUtils.PostException = nop
        end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then CTR.SendReport = nop; CTR.SendException = nop; CTR.UploadLog = nop end
        local tlog = package.loaded["client.slua.config.tlog.tlog_report_utils"]
        if tlog then tlog.ReportTLogEvent = nop end

        local Logging = safeImport("Logging")
        if Logging then
            patchModule(Logging, {"Log","LogWarning","LogError","LogVerbose","SetLogLevel","LogInfo","LogDebug","LogTrace","LogFatal","LogPanic"})
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.4 — Subsystem scanner blocker (HARD-EXCLUDE protected)
-- -------------------------------------------------------------------------
local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not SubMgr then return end

        local toKill = {
            "AFKReportorSubsystem","ClientDataStatistcsSubsystem","AvatarExceptionSubsystem",
            "ShootVerifySubSystemClient","MemoryCheckSubsystem","SpeedCheckSubsystem",
            "WallCheckSubsystem","FileCheckSubsystem","BehaviorScoreSubsystem",
            "CoronaLabSubsystem","PlayerSecurityInfoSubsystem","ClientCircleFlowSubsystem",
            "ClientReportPlayerSubsystem","DSReportPlayerSubsystem",
            "ClientHawkEyePatrolSubsystem","DSHawkEyePatrolSubsystem",
            "GameReportSubsystem","ClientSecMrpcsFlowSubsystem","MrpcsFlowSubsystem",
            "CircleFlowSubsystem","SwiftHawkSubsystem","AntiCheatSubsystem",
            "IntegrityCheckSubsystem","SignatureVerifySubsystem","MD5CheckSubsystem",
            "PakVerifySubsystem","ClientKernelCheckSubsystem","ClientMemoryGuardSubsystem",
            "ClientWallhackDetectionSubsystem","ClientESPDetectionSubsystem",
            "ClientAimTrackingSubsystem","ClientRenderCheckSubsystem",
            "TssSdkSubsystem","AnogsSubsystem","ACEAntiCheatSubsystem",
            "MemoryProtectSubsystem","AntiDebugSubsystem","SafeGuardSubsystem",
            "ReportSystemSubsystem","PlayerBehaviorSubsystem",
        }

        for _, name in ipairs(toKill) do
            -- PSYCO PATCH: hard-exclude check runs FIRST
            if not isHardExcluded(name) and not isSafeName(name) then
                pcall(function()
                    local sub = SubMgr:Get(name)
                    if sub then
                        for k, v in pairs(sub) do
                            if not isHardExcluded(k) and not isSafeName(k) then
                                if type(v) == "function" then
                                    pcall(function() sub[k] = nop end)
                                elseif type(v) == "number" then
                                    pcall(function() sub[k] = 0 end)
                                elseif type(v) == "boolean" then
                                    pcall(function() sub[k] = false end)
                                end
                            end
                        end
                        if sub.ReportPingDelayTimer then
                            pcall(function() sub:RemoveGameTimer(sub.ReportPingDelayTimer) end)
                            sub.ReportPingDelayTimer = nil
                        end
                    end
                end)
            end
        end

        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then
            AvaEx.CheckAvatarException = nop
            AvaEx.CheckAvatarExceptionOnce = nop
            AvaEx.ReportAvatarException = nop
            AvaEx.CheckSlotMeshVisible = retFalse
            AvaEx.CheckPawnVisible = retFalse
            AvaEx.CheckCanBugglyPostException = retFalse
        end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = retFalse
            AvatarUtils.IsValidAvatar = retTrue
            AvatarUtils.CheckAvatarIntegrity = retTrue
            AvatarUtils.ReportInvalidAvatar = nop
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.5 — Report blocker
-- -------------------------------------------------------------------------
local function InitializeReportBlocker()
    pcall(function()
        local reportPaths = {
            "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem",
            "client.slua.logic.report.EquipmentExceptionReport",
            "client.slua.logic.report.ClientToolsReport",
            "GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils",
            "client.slua.logic.download.report.puffer_tlog",
            "GameLua.Mod.BaseMod.Client.Security.ClientGlueHiaSystem",
            "GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils",
            "GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature",
            "client.slua.logic.ban.ClientBanLogic",
            "client.slua.logic.login.logic_tt_ban",
            "GameLua.Mod.PlanBT.Gameplay.Subsystem.DSActiveSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSAITLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSFightTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSCommonTLogSubsystem",
            "GameLua.Mod.BaseMod.Client.Security.InspectionSystemReportClientLogicSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.InspectionSystemReportDSLogicSubsystem",
            "GameLua.Mod.BaseMod.Common.Subsystem.SpectateAndReplaySubsystem",
            "GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem",
            "GameLua.Mod.Escape.Gameplay.Subsystem.BehaviorScoreSubsystem",
            "GameLua.ExtraModule.MLAI.Client.AIReplaySubsystem",
            "GameLua.Mod.BaseMod.GamePlay.AI.AITrackingLogSubsystem",
            "GameLua.Mod.TDM.Gameplay.Subsystem.TDMAFKReportorSubsystem",
        }
        local blockFuncs = {
            "Report","SendReport","ReportEvent","ReportException","ReportData","ReportTLogEvent",
            "OnInit","_OnPlayerKilledOtherPlayer","_RecordFatalDamager","_OnBattleResult",
            "_OnShowQuickReportMutualExclusiveUI","_AddEnemyMapToBattleResult","_AddKnockDownerToBattleResult",
            "_AddKillerToBattleResult","_AddTeammateMurderToBattleResult","_AddFatalDamagerMapToBattleResult",
            "_AddMLKillerUIDToBattleResult","_SaveHistoricalTeammateInfo","_RecordTeammateMurderer",
            "_OnNearDeathOrRescued","_OnCharacterDied","_OnTeammateDamage","_OnPlayerSettlementStart",
            "_OnHawkSync","_OnHawkReportSuccess","_StartExitGameTimer","OnHandleBehaviorScore","AIPerceptionScore",
            "ReportAllPlayerInfo","AddRecordMLAIInfo","ReportAI","RealLogoutTimer","SendAFKTips",
            "OnHandleLostConnection","ClientRPC_SyncBanID","ClientRPC_StrongTips","ClientRPC_NormalTips",
            "Notify","OnSyncBanInfo","OnVoiceBanNotify","DelayKickOutPlayer","ActiveKickNotify",
            "_UpdateTTKRecords","_UpdateOperatingFrequency","_OnReportServerJumpFlow","HandleKillTlog",
            "AskForInspector","ReportEnemy","KickOutOneTeam","ServerKickOutOneTeamByPlayerImplementation",
            "AddReportedCount","RequestGotoSpectatingImp","RequestGotoSpectating"
        }
        for _, path in ipairs(reportPaths) do
            local module = package.loaded[path]
            if not module then
                local ok, r = pcall(require, path)
                if ok then module = r end
            end
            if module then
                patchModule(module, blockFuncs)
                if module.GetCarrierInfo then module.GetCarrierInfo = function() return "[{\"mcc\":\"000\"}]" end end
                if module.CheckIfCanCreateRole then module.CheckIfCanCreateRole = retTrue end
                if module.GetSimpleFightData then module.GetSimpleFightData = retEmpty end
                if module.LogQueue then module.LogQueue = {} end
            end
        end

        if NetUtil and NetUtil.SendPacket then
            local originalSend = NetUtil.SendPacket
            local blocked = {}
            for _, p in ipairs({
                "ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms","ReportVerifyInfoFlow","ReportMrpcsFlow",
                "ReportPlayerBehavior","ReportTeammatHurt","ReportTeammateKillConfirmFlow","ReportForbiddenPickupFlow",
                "ReportPlayerMoveRoute","ReportPlayerPosition","ReportSecVehicleMoveFlow","ReportSecTgameMovingFlow",
                "report_parachute_data","on_tss_sdk_anti_data","report_unrealnet_exception","ReportPlayerEquipmentInfo",
                "ReportAimFlow","ReportHitFlow","log_shooting_miss","report_heavy_weapon_box_activation_flow",
                "report_heavy_weapon_box_item_flow","ReportCircleFlow","report_ds_player_circle_flow","ReportJumpFlow",
                "ReportGameStartFlow","ReportGameEndFlow","report_players_ping","report_player_ip","report_player_frame_ping_record",
                "report_net_saturate","report_ds_netsaturate","report_ds_net_continuous_saturate","report_ds_netrate",
                "report_unrealnet_clientstats","report_serverstat_avgtickdelta","report_all_players_address",
                "report_ai_strategyinfo","ReportAIActionFlow","ReportGenerateMonsterFlow","report_ds_match_room_data",
                "SendSpectatingLog","ReportIDCardProduceFlow","ReportIDCardPickUpFlow","ReportIDCardDestroyFlow",
                "ReportRevivalFlow","ReportGameSetting","ReportGameSettingNew","ReportAntsVoiceTeamCreate","ReportAntsVoiceTeamQuit",
                "report_common_info","report_common_battle_info","report_client_scan_result","tss_sdk_report",
                "report_memory_exception","report_avatar_exception","report_ui_state","report_hit_reg_fail",
                "report_character_state","report_vehicle_exception","report_camera_exception",
                "ReportPlayerControllerStateChanged","ReportAvatarFlow","ReportSecurityAlert","ReportAntiCheat",
                "ReportSuspiciousActivity","ReportViolation","ReportBan","ReportKick","ReportCheat","ReportHack",
                "ReportMod","ReportInject","ReportHook","ReportPatch","ReportTamper","ReportCorrupt","ReportInvalid",
                "ReportSpoof","ReportFake","ReportClone","ReportDuplicate","ReportConflict","ReportOverlap",
                "ReportMismatch","ReportInconsistent","ReportUnexpected","ReportUnknown",
                "ClientSecMrpcsFlow","MrpcsData","CheckReportSecAttackFlow","CheckReportSecAttackFlowWithAttackFlow",
                "RPC_ClientCoronaLab","CoronaLabReport","CoronaLabData","PlayerSecurityInfo","ReportSecurityInfo",
                "SendSecurityData","ClientCircleFlow","BulletHitInfoUploadData","ShootVerifyFailed","SwiftHawk",
                "ClientSwiftHawk","ClientSwiftHawkWithParams","SwiftHawkReport","SwiftHawkData",
                "AntiCheatReport","CheatDetection","ViolationReport","SecurityViolation","IntegrityCheck","SignatureVerify"
            }) do blocked[p] = true end
            NetUtil.SendPacket = function(packetName, ...)
                if blocked[packetName] then return nil end
                return originalSend(packetName, ...)
            end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow","RPC_Server_SwiftHawk","RPC_Server_ClientSwiftHawkWithParams","RPC_Server_ReportSimulateCharacterLocation","RPC_Client_ShootVertifyRes","RPC_Client_CoronaLab"}
            _G.SendRPC = function(rpcName, ...)
                for _, b in ipairs(blockedRPC) do
                    if rpcName == b then return nil end
                end
                return origRPC(rpcName, ...)
            end
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.6 — Gameplay callbacks bypass
-- -------------------------------------------------------------------------
local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {
            "ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms","ReportVerifyInfoFlow",
            "ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt","ReportMisKillByTeammate","ReportForbitPick",
            "ReportPlayerMoveRoute","ReportPlayerPosition","ReportVehicleMoveFlow","ReportSecTgameMovingFlow",
            "ReportParachuteData","SendTssSdkAntiDataToLobby","SendDSErrorLogToLobby","SendDSErrorLogToLobbyOnece",
            "SendDSHawkEyePatrolLogToLobby","ReportEquipmentFlow","ReportAimFlow","ReportHitFlow",
            "ReportHeavyWeaponBoxSpawnFlow","ReportHeavyWeaponBoxActivationFlow","ReportHeavyWeaponBoxOpenPlayerFlow",
            "ReportHeavyWeaponBoxItemFlow","ReportPlayersPing","ReportPlayerIP","ReportPlayerFramePingRecord",
            "OnDSConnectionSaturated","ReportDSNetSaturation","ReportNetContinuousSaturate","ReportDSNetRate",
            "SendClientStats","SendServerAvgTickDelta","ReportCircleFlow","ReportDSCircleFlow","ReportJumpFlow",
            "ReportAIStrategyInfo","SendAIDeliveryInfo","ReportDailyTaskInfo","ReportMatchRoomData",
            "SendPlayerSpectatingLog","ReportIDCardProduceFlow","ReportIDCardPickUpFlow","ReportIDCardDestroyFlow",
            "ReportRevivalFlow","ReportGameSetting","ReportGameSettingNew","ReportAntsVoiceTeamCreate",
            "ReportAntsVoiceTeamQuit","ReportCommonInfo","ReportLightweightStat","SendSecTLog",
            "SendDataMiningTLog","SendActivityTLog","OnPlayerNetConnectionClosed","OnPlayerActorChannelError",
            "OnPlayerRPCValidateFailed","OnPlayerSpectateException","OnShutdownAfterError",
            "ClientSecMrpcsFlow","SwiftHawk","ClientSwiftHawk","ClientSwiftHawkWithParams"
        }
        for _, f in ipairs(reports) do
            if not isSafeName(f) then
                GC[f] = nop
            end
        end
        GC.GetWeaponReport = retEmpty
        GC.GetOneWeaponReport = retEmpty
        GC.GetGeneralTLogData = retEmpty
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse
        GC.CheckReportSecAttackFlow = retFalse
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1,["connectionlost"]=1,["connectiontimeout"]=1,["connectionexception"]=1,
                            ["netdrivererror"]=1,["banned"]=1,["kicked"]=1,["suspended"]=1,
                            ["violationdetected"]=1,["integrityfailure"]=1,["securityviolation"]=1}
            if blocked[s] then return end
        end
        GC.IsBypassed = true
    end)
end

-- -------------------------------------------------------------------------
-- 4.7 — Memory patcher
-- -------------------------------------------------------------------------
local function AntiCheatKillerUniversal()
    pcall(function()
        if not Memory or not Memory.FindBase or not Memory.NopCode then return end
        local OffsetSets = {
            { lib = "libUE4.so", offs = {0x4A3B000, 0x4A3B010, 0x4A3B020}, size = 8 },
            { lib = "libanogs.so", offs = {0x1A3C0, 0x1A3D0, 0x1A400}, size = 16 },
            { lib = "libtdata.so", offs = {0x2F000, 0x2F010}, size = 16 },
            { lib = "libUE4.so", offs = {0x4B3C000, 0x4B3C010}, size = 8 },
            { lib = "libanogs.so", offs = {0x1B3C0, 0x1B3D0}, size = 16 },
            { lib = "libUE4.so", offs = {0x4C3D000, 0x4C3D010}, size = 8 },
            { lib = "libanogs.so", offs = {0x1C3C0, 0x1C3D0}, size = 16 },
        }
        for _, entry in ipairs(OffsetSets) do
            pcall(function()
                local lib = Memory.FindBase(entry.lib)
                if lib and lib > 0 then
                    for _, off in ipairs(entry.offs) do
                        pcall(function() Memory.NopCode(lib + off, entry.size) end)
                    end
                end
            end)
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.8 — TFLite / NeuralNet bypass
-- -------------------------------------------------------------------------
local function TFLiteAIBypass()
    pcall(function()
        if _G.tflite then
            _G.tflite.Invoke = retEmpty
            _G.tflite.RunModel = retTrue
            _G.tflite.LoadModel = retTrue
        end
        if _G.NeuralNet then
            _G.NeuralNet.Predict = retZero
            _G.NeuralNet.Analyze = retEmpty
            _G.NeuralNet.Detect = retFalse
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.9 — Behavioral analyser bypass
-- -------------------------------------------------------------------------
local function BehavioralBypass()
    pcall(function()
        if _G.AimPatternAnalyzer then
            _G.AimPatternAnalyzer.Analyze = retEmpty
            _G.AimPatternAnalyzer.DetectAimbot = retFalse
            _G.AimPatternAnalyzer.GetPatternScore = retZero
        end
        if _G.MovementAnalyzer then
            _G.MovementAnalyzer.Analyze = retEmpty
            _G.MovementAnalyzer.DetectSpeedHack = retFalse
            _G.MovementAnalyzer.DetectTeleport = retFalse
        end
        if _G.ShootPatternAnalyzer then
            _G.ShootPatternAnalyzer.Analyze = retEmpty
            _G.ShootPatternAnalyzer.DetectRecoil = retFalse
            _G.ShootPatternAnalyzer.DetectNoRecoil = retFalse
        end
        if _G.KillPatternAnalyzer then
            _G.KillPatternAnalyzer.Analyze = retEmpty
            _G.KillPatternAnalyzer.DetectHeadshotRatio = retZero
            _G.KillPatternAnalyzer.DetectSuspiciousKills = retFalse
        end
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.BehaviorScore then pc.BehaviorScore = 100 end
            if pc.AimScore then pc.AimScore = 100 end
            if pc.MovementScore then pc.MovementScore = 100 end
            if pc.ShootScore then pc.ShootScore = 100 end
            if pc.KillScore then pc.KillScore = 100 end
            if pc.SuspicionScore then pc.SuspicionScore = 0 end
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.10 — Server validation bypass
-- -------------------------------------------------------------------------
local function ServerValidationBypass()
    pcall(function()
        for _, name in ipairs({"ServerPosValidator","ServerDamageValidator","ServerShootValidator","ServerMoveValidator","RPCValidator"}) do
            local v = _G[name]
            if v then
                v.Validate = retTrue
                v.Check = retTrue
                v.Report = nop
            end
        end
        if NetUtil and NetUtil.ValidatePacket then NetUtil.ValidatePacket = retTrue end
    end)
end

-- -------------------------------------------------------------------------
-- 4.11 — ML model bypass
-- -------------------------------------------------------------------------
local function MLBypass()
    pcall(function()
        for _, m in ipairs({"AimbotDetectionModel","ESPDDetectionModel","SpeedHackDetectionModel","WallHackDetectionModel","MagicBulletDetectionModel","NoRecoilDetectionModel","TeleportDetectionModel","FlyHackDetectionModel"}) do
            local model = _G[m]
            if model then
                model.Predict = retZero
                model.Analyze = retEmpty
                model.Detect = retFalse
                model.Load = retTrue
                model.Run = retEmpty
            end
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.12 — Memory integrity bypass
-- -------------------------------------------------------------------------
local function MemoryIntegrityBypass()
    pcall(function()
        if _G.MemoryHash then
            _G.MemoryHash.Calculate = function() return "BYPASSED" end
            _G.MemoryHash.Verify = retTrue
            _G.MemoryHash.Check = retTrue
        end
        if _G.MemoryDumpDetector then
            _G.MemoryDumpDetector.Detect = retFalse
            _G.MemoryDumpDetector.Check = retFalse
            _G.MemoryDumpDetector.Report = nop
        end
        if _G.MemoryScanDetector then
            _G.MemoryScanDetector.Detect = retFalse
            _G.MemoryScanDetector.Check = retFalse
            _G.MemoryScanDetector.Report = nop
        end
        if _G.MemoryModDetector then
            _G.MemoryModDetector.Detect = retFalse
            _G.MemoryModDetector.Check = retFalse
            _G.MemoryModDetector.Report = nop
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.13 — Cloud AI / analytics bypass
-- -------------------------------------------------------------------------
local function CloudAIBypass()
    pcall(function()
        for _, name in ipairs({"CloudUpload","CloudAnalyzer","DataCollector","Telemetry"}) do
            local v = _G[name]
            if v then
                for k, val in pairs(v) do
                    if type(val) == "function" then v[k] = nop end
                end
            end
        end
        if _G.Firebase then
            _G.Firebase.logEvent = nop
            _G.Firebase.setUserProperty = nop
            _G.Firebase.setAnalyticsCollectionEnabled = nop
        end
        for _, sdk in ipairs({"Adjust","AppsFlyer","FacebookAnalytics","GameAnalytics","GoogleAnalytics"}) do
            local s = _G[sdk]
            if s then
                for k, val in pairs(s) do
                    if type(val) == "function" then
                        pcall(function() s[k] = nop end)
                    end
                end
            end
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.14 — Packet encryption bypass
-- -------------------------------------------------------------------------
local function PacketEncryptionBypass()
    pcall(function()
        for _, name in ipairs({"AES","RSA","ECC","ChaCha20","PacketEncrypt"}) do
            local v = _G[name]
            if v then
                v.Encrypt = function(d) return d end
                v.Decrypt = function(d) return d end
                if v.GenerateKey then v.GenerateKey = function() return "BYPASSED" end end
            end
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.15 — Kernel / hardware / quantum bypass
-- -------------------------------------------------------------------------
local function AdvancedBypasses()
    pcall(function()
        for _, name in ipairs({"KernelModuleDetector","PtraceDetector","SeccompDetector"}) do
            local v = _G[name]
            if v then
                v.Detect = retFalse
                v.Check = retFalse
            end
        end
        if _G.SyscallHook then _G.SyscallHook.Detect = retFalse; _G.SyscallHook.Check = retTrue end

        for _, name in ipairs({"CPUSerial","GPUSerial","DiskSerial"}) do
            local v = _G[name]
            if v then
                v.Get = function() return "BYPASSED" end
                v.Read = function() return "BYPASSED" end
            end
        end
        if _G.NetworkInterface then
            _G.NetworkInterface.GetMAC = function() return "00:00:00:00:00:00" end
            _G.NetworkInterface.GetIP = function() return "127.0.0.1" end
        end
        if _G.TEEDetector then _G.TEEDetector.Detect = retFalse; _G.TEEDetector.Check = retFalse end
        if _G.SecureBoot then _G.SecureBoot.Check = retTrue; _G.SecureBoot.Get = retTrue end
        if _G.HardwareAttestation then
            _G.HardwareAttestation.Attest = function() return "BYPASSED" end
            _G.HardwareAttestation.Verify = retTrue
        end

        for _, m in ipairs({"AimbotNN","ESPNN","WallHackNN","SpeedHackNN","MagicBulletNN","NoRecoilNN"}) do
            local v = _G[m]
            if v then
                v.Predict = retZero
                v.Analyze = retEmpty
                v.Detect = retFalse
            end
        end

        for _, name in ipairs({"Kyber","Dilithium","Falcon","SPHINCS","LatticeCrypto","HashBasedSignature"}) do
            local v = _G[name]
            if v then
                v.Encapsulate = function() return {}, {} end
                v.Decapsulate = retEmpty
                v.Sign = function() return {} end
                v.Verify = retTrue
                v.Encrypt = function(d) return d end
                v.Decrypt = function(d) return d end
            end
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.16 — Device spoof
-- -------------------------------------------------------------------------
local function AntiBanSpoof()
    pcall(function()
        local SystemInfo = safeImport("SystemInfo")
        if SystemInfo then
            SystemInfo.GetDeviceModel = function() return "iPhone14,5" end
            SystemInfo.GetDeviceBrand = function() return "Apple" end
            SystemInfo.GetAndroidVersion = function() return "13" end
            SystemInfo.GetEMUIVersion = retEmptyStr
            SystemInfo.IsEmulator = retFalse
            SystemInfo.IsRooted = retFalse
            SystemInfo.IsDebugged = retFalse
            SystemInfo.GetKernelVersion = function() return "Linux version 4.14.116" end
            SystemInfo.CheckKernelIntegrity = retTrue
            SystemInfo.GetDeviceID = function() return "00000000-0000-0000-0000-000000000000" end
        end
        local DeviceID = safeImport("DeviceID")
        if DeviceID then
            DeviceID.GetDeviceID = function() return "BYPASSED_DEVICE" end
            DeviceID.GetAndroidID = function() return "BYPASSED_ANDROID_ID" end
            DeviceID.GetIMEI = function() return "BYPASSED_IMEI" end
            DeviceID.GetMACAddress = function() return "BYPASSED_MAC" end
            DeviceID.GetUniqueDeviceID = function() return "BYPASSED_UNIQUE" end
            DeviceID.GetDeviceName = function() return "BYPASSED_NAME" end
            DeviceID.GetDeviceModel = function() return "BYPASSED_MODEL" end
            DeviceID.GetDeviceBrand = function() return "BYPASSED_BRAND" end
            DeviceID.GetDeviceManufacturer = function() return "BYPASSED_MANUF" end
            DeviceID.GetDeviceSerial = function() return "BYPASSED_SERIAL" end
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.17 — Material evasion
-- -------------------------------------------------------------------------
local function MaterialEvasionBypass()
    pcall(function()
        local UMaterial = safeImport("Material")
        local UMaterialInstance = safeImport("MaterialInstance")
        local UMaterialInstanceDynamic = safeImport("MaterialInstanceDynamic")
        local UPrimitiveComponent = safeImport("PrimitiveComponent")
        local UMeshComponent = safeImport("MeshComponent")

        if UMaterial then
            UMaterial.GetDisableDepthTest = retFalse
            UMaterial.GetBlendMode = retZero
            UMaterial.GetMaterialHash = function() return "FAKE_HASH" end
            UMaterial.VerifyMaterial = retTrue
        end
        if UMaterialInstance then
            UMaterialInstance.GetDisableDepthTest = retFalse
            UMaterialInstance.GetBlendMode = retZero
            UMaterialInstance.GetBaseMaterial = retNil
        end
        if UMaterialInstanceDynamic then
            local oldVec = UMaterialInstanceDynamic.K2_GetVectorParameterValue
            UMaterialInstanceDynamic.K2_GetVectorParameterValue = function(self, name)
                local n = tostring(name)
                if n:find("Color") or n:find("Emissive") then return {R=0,G=255,B=255,A=255} end
                return oldVec(self, name)
            end
            local oldScal = UMaterialInstanceDynamic.K2_GetScalarParameterValue
            UMaterialInstanceDynamic.K2_GetScalarParameterValue = function(self, name)
                if tostring(name):find("Emissive") then return 0.0 end
                return oldScal(self, name)
            end
            UMaterialInstanceDynamic.GetFullName = function() return "DefaultMaterial" end
        end
        if UPrimitiveComponent then
            UPrimitiveComponent.IsRenderedOnCustomDepth = retFalse
            UPrimitiveComponent.GetRenderCustomDepth = retFalse
            UPrimitiveComponent.GetCustomDepthStencilValue = retZero
            UPrimitiveComponent.GetCustomDepthStencilWriteMask = retZero
            UPrimitiveComponent.GetVisibleFlag = retTrue
        end
        if UMeshComponent then
            UMeshComponent.ShouldRender = retTrue
            UMeshComponent.GetShouldRender = retTrue
            UMeshComponent.IsVisible = retTrue
        end
        local UObject = safeImport("Object")
        if UObject and UObject.GetObjectsOfClass then
            local oldGet = UObject.GetObjectsOfClass
            UObject.GetObjectsOfClass = function(Class, IncludeDerived)
                if Class and tostring(Class):find("MaterialInstanceDynamic") then return {} end
                return oldGet(Class, IncludeDerived)
            end
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.18 — Aimbot detection bypass
-- -------------------------------------------------------------------------
local function AimbotDetectionBypass()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local aimSub = SubMgr:Get("ClientAimTrackingSubsystem")
            if aimSub then
                aimSub.GetAimData = function(self)
                    return {
                        accuracy = math.random(40, 60),
                        headshotRate = math.random(10, 25),
                        trackingTime = math.random(100, 300),
                        aimLockCount = 0
                    }
                end
                for _, fn in ipairs({"ReportAimData","SendAimStats","UploadAimInfo"}) do
                    if aimSub[fn] then aimSub[fn] = nop end
                end
            end
        end

        local PlayerController = safeImport("PlayerController")
        if PlayerController then
            local origAddYaw = PlayerController.AddYawInput
            if origAddYaw then
                PlayerController.AddYawInput = function(self, Val)
                    if self == slua_GameFrontendHUD:GetPlayerController() then
                        Val = Val + (math.random() - 0.5) * 0.5
                    end
                    return origAddYaw(self, Val)
                end
            end
            local origAddPitch = PlayerController.AddPitchInput
            if origAddPitch then
                PlayerController.AddPitchInput = function(self, Val)
                    if self == slua_GameFrontendHUD:GetPlayerController() then
                        Val = Val + (math.random() - 0.5) * 0.5
                    end
                    return origAddPitch(self, Val)
                end
            end
        end

        local Actor = safeImport("Actor")
        if Actor and Actor.GetBoneName then
            local origGetBone = Actor.GetBoneName
            Actor.GetBoneName = function(self, index)
                local name = origGetBone(self, index)
                if tostring(name):find("neck") then
                    local rand = math.random(1,3)
                    if rand == 1 then return "head_01"
                    elseif rand == 2 then return "spine_02"
                    end
                end
                return name
            end
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.19 — Runtime signature masking
-- -------------------------------------------------------------------------
local function RuntimeSignatureMasking()
    pcall(function()
        local localPlayer = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() and slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
        if slua.isValid(localPlayer) and slua.isValid(localPlayer.AutoAimComp) then
            local autoAim = localPlayer.AutoAimComp
            if autoAim.AimAssistConfig then
                local temp = autoAim.AimAssistConfig.HeadPriority
                autoAim.AimAssistConfig.HeadPriority = autoAim.AimAssistConfig.ChestPriority
                autoAim.AimAssistConfig.ChestPriority = temp
            end
            local fakeBones = {"Head", "Spine_01", "Pelvis"}
            if autoAim.HeadBoneName then
                local oldBone = autoAim.HeadBoneName
                local newBone = fakeBones[math.random(1,3)]
                autoAim.HeadBoneName = newBone
                pcall(function() autoAim.Bones = {newBone, oldBone} end)
            end
            if autoAim.InnerRange then autoAim.InnerRange.Speed = math.random(2, 15) end
            if autoAim.OuterRange then autoAim.OuterRange.Speed = math.random(2, 15) end
        end
    end)
end

-- -------------------------------------------------------------------------
-- 4.20 — Aggressive dynamic reset (safe zone applied)
-- -------------------------------------------------------------------------
local function AggressiveReset()
    pcall(function()
        local CHiggs = _G.CHiggsBosonComponent
        if CHiggs then
            CHiggs.bMHActive = false
            CHiggs.bCallPreReplication = false
            CHiggs.bSkipAlertServer = true
            CHiggs._ProcessReportChatRobotQueue = nop
            CHiggs.RPC_Client_ShowSecurityAlertWindow = nop
            CHiggs.RPC_Server_TellServerName = nop
            if CHiggs.ControlMHActive then
                CHiggs.ControlMHActive = function(self) self.bMHActive = false end
            end
        end

        if _G.PlayerSecurityInfoCollector then
            _G.PlayerSecurityInfoCollector.ReportData = nop
            _G.PlayerSecurityInfoCollector.SendToServer = nop
            _G.PlayerSecurityInfoCollector.CollectData = nop
        end

        if _G.ClientHawkEyePatrolSubsystem then
            _G.ClientHawkEyePatrolSubsystem._bHasReported = true
            _G.ClientHawkEyePatrolSubsystem._bHasInitialized = true
            _G.ClientHawkEyePatrolSubsystem.ReportCheat = nop
            _G.ClientHawkEyePatrolSubsystem.RequestImprison = nop
            _G.ClientHawkEyePatrolSubsystem.IsDuringHawkEyePatrol = retFalse
        end

        if _G.ClientBanLogic then
            _G.ClientBanLogic.ReqBanInfo = nop
            _G.ClientBanLogic.IsVoiceReportEnable = retFalse
            _G.ClientBanLogic.bEnableVoiceReport = false
        end

        if _G.RealTimeBan then
            _G.RealTimeBan.tOnRankInspectorUIDSet = {}
            _G.RealTimeBan.tInspectorRankUIDSet = {}
            _G.RealTimeBan.tInspectorBroadcastCountUIDSet = {}
            _G.RealTimeBan.is_onrank_inspector = false
        end

        if _G.tlog_report_utils then
            _G.tlog_report_utils.ReportTLogEvent = nop
            _G.tlog_report_utils.SendTLogReportImmediate = nop
            _G.tlog_report_utils.IsCanReportLobbyEvent = retFalse
            _G.tlog_report_utils.IsBusinessReport = retFalse
        end

        if _G.STExtraBlueprintFunctionLibrary then
            _G.STExtraBlueprintFunctionLibrary.CheckMD5 = retTrue
            _G.STExtraBlueprintFunctionLibrary.VerifyFile = retTrue
        end

        if _G.CoronaLab then
            _G.CoronaLab.ReportData = nop
            _G.CoronaLab.SendData = nop
            _G.CoronaLab.CollectData = nop
            _G.CoronaLab.Telemetry = nop
        end

        if _G.GokubaLogic then
            _G.GokubaLogic.ForwardFeature = nop
            _G.GokubaLogic.InitGokubaLogic = nop
        end

        if _G.SwiftHawk then _G.SwiftHawk = nop end
        if _G.ClientSwiftHawk then _G.ClientSwiftHawk = nop end
        if _G.ClientSwiftHawkWithParams then _G.ClientSwiftHawkWithParams = nop end
    end)
end

-- -------------------------------------------------------------------------
-- 4.21 — Master bypass runner
-- -------------------------------------------------------------------------
_G.StartBypass_VIP_v3 = function()
    pcall(function()
        InitializeCoreBypass()
        InitializeSLUA_MD5()
        InitializeLogBlocker()
        InitializeScannerBlocker()
        InitializeReportBlocker()
        InitializeGameplayBypass()
        AntiCheatKillerUniversal()
        TFLiteAIBypass()
        BehavioralBypass()
        ServerValidationBypass()
        MLBypass()
        MemoryIntegrityBypass()
        CloudAIBypass()
        PacketEncryptionBypass()
        AdvancedBypasses()
        AntiBanSpoof()
        MaterialEvasionBypass()
        AimbotDetectionBypass()
        AggressiveReset()
    end)
end

_G.StartBypass_VIP_v3()

if not isExpired then
    pcall(function()
        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(0.5, _G.StartBypass_VIP_v3)
            ticker.AddTimerOnce(2.0, _G.StartBypass_VIP_v3)
            ticker.AddTimerOnce(5.0, _G.StartBypass_VIP_v3)
        end
    end)
    pcall(function()
        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerOnce then
            local function maskLoop()
                pcall(RuntimeSignatureMasking)
                ticker.AddTimerOnce(0.5, maskLoop)
            end
            ticker.AddTimerOnce(1.0, maskLoop)
        end
    end)
end

-- =========================================================================
-- 5 — Config / state / save-load
-- =========================================================================
local _slua = rawget(_G, "slua")
local function Valid(obj)
    if not obj then return false end
    if _slua and _slua.isValid then
        local ok, v = pcall(_slua.isValid, obj)
        if not ok or not v then return false end
    end
    return true
end

local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_BLUE = {R=0, G=0, B=255, A=255}

_G.GTLMODConfig = _G.GTLMODConfig or {
    AutoHead = LIMITS.AUTO_HEAD_DEFAULT,
    EspVip = false,
    EspDistance = true,
    EspVipPro = LIMITS.ESPVIPPRO_DEFAULT,
    EspRadar = false,
    Esp5 = false,
    Esp6 = LIMITS.ESP6_DEFAULT,
    Esp7 = true,
    Esp8 = false,
    EspAntenna = false,
    EspName = false,
    EspOutline = false,
    OutlineThickness = 10,
    UnlockFPS = false,
    IpadView = false,
    CustomAimbot = false,
    CustomAimbotClose = false,
    CustomHRecoil = false,
    CustomVRecoil = false,
    LessShake = false,
    RemoveGrass = false,
    RemoveFog = false,
    WhiteBody = false,
    ColorBodyV2 = false,
    wallhackng = false,
    Crosshair = false,
    Accuracy = false,
    GodMode = false,
    BlackSky = false,
    AimTouchEnable = false,
    AimTouchIgKnock = true,
    AimTouchIgBot = true,
    AimTouchVisCheck = true,
    CounterEnabled = true,
    EspLine = true,
    AimDebug = false,
    WallhackSmart = true,
    WallhackThickness = 2.5,
}

_G.GTLMODState = _G.GTLMODState or {
    LoopToken = 0,
    NativeESPReady = false,
    GraphicsUnlocked = false,
    MenuStep = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    CustomTextData = nil,
    PrevGraphicsState = {},
    MidCacheCount = 0,
    AimLastFail = "",
    BatStateEnteredAt = 0,
    LastUnstickAt = 0,
}

local function GetConfigPaths(fileName)
    return {
        PATHS.Paks .. fileName,
        PATHS.SaveGames .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
end
local ConfigFileName = "RJ_settings.txt"
_G.LastConfigSaveStr = ""
_G.LastConfigSaveTime = 0

_G.SaveModSettings = function()
    local now = os.time()
    if now - (_G.LastConfigSaveTime or 0) < LIMITS.CONFIG_SAVE_INTERVAL then return end
    _G.LastConfigSaveTime = now
    pcall(function()
        local buf = { "return {\nGTLConfig = {\n" }
        for k, v in pairs(_G.GTLMODConfig or {}) do
            buf[#buf+1] = "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        buf[#buf+1] = "}\n}"
        local data = table.concat(buf)
        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data
        for _, path in ipairs(GetConfigPaths(ConfigFileName)) do
            local file = io.open(path, "w")
            if file then file:write(data); file:close(); break end
        end
    end)
end

_G.LoadModSettings = function()
    pcall(function()
        local content = nil
        for _, path in ipairs(GetConfigPaths(ConfigFileName)) do
            local file = io.open(path, "r")
            if file then content = file:read("*a"); file:close(); break end
        end
        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    if savedData.GTLConfig then
                        for k, v in pairs(savedData.GTLConfig) do _G.GTLMODConfig[k] = v end
                    end
                end
            end
        end
        _G.SaveModSettings()
    end)
end

local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(LIMITS.CONFIG_SAVE_INTERVAL, AutoSaveLoop)
        end
    end)
end

if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

-- =========================================================================
-- 6 — ESP engine (esplook SRC BY @SRC_HUB / @XThrlen)
-- =========================================================================
local ESP_Enabled = true

local FVector2D = _G.FVector2D or import("Vector2D")
local FLinearColor = _G.FLinearColor or import("LinearColor")
local SlateBlueprintLibrary = nil
local WidgetLayoutLibrary = nil
local SlateColor = nil
local GameplayStaticsESP = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)
pcall(function() SlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor") end)
pcall(function() GameplayStaticsESP = import("GameplayStatics") end)
local KismetSystemLibraryESP = nil
local HitResultClassESP = nil
pcall(function() KismetSystemLibraryESP = import("KismetSystemLibrary") end)
pcall(function() HitResultClassESP = import("HitResult") end)
local TraceStartPos = { X = 0, Y = 0, Z = 0 }
local CachedHitResult = nil
pcall(function()
  if HitResultClassESP then CachedHitResult = HitResultClassESP()
  else CachedHitResult = {} end
end)

local function ESPValid(obj)
  if obj == nil then return false end
  local ok, v = pcall(function() return slua.isValid(obj) end)
  return ok and v == true
end

local function ESPV2(x, y)
  if FVector2D then return FVector2D(x, y) end
  return { X = x, Y = y }
end

local function ESPMKC(r, g, b, a)
  if FLinearColor then return FLinearColor(r, g, b, a) end
  return { R = r, G = g, B = b, A = a }
end

local CFG = {
  MaxDistance = 40000,
  MaxTracked = 16,
  ScreenMargin = 220,
  TopTextY = 6.0,
  SnapOriginY = 0.0,
  SnapThickness = 1.8,
  CornerThickness = 2.2,
  CornerLen = 0.28,
  CornerMin = 6,
  CornerMax = 28,
  BoxMinWidth = 22,
  BoxMaxWidth = 320,
  BoxMinHeight = 14,
  BoxWidthFactor = 0.62,
  WidthScale = 1.22,
  HeadExtra = 0.06,
  FootExtra = 0.02,
  SideBarWidth = 3.5,
  SideBarGap = 5.0,
  SideBgAlpha = 0.55,
  MarkGap = 8.0,
  MarkW = 15.0,
  MarkH = 10.0,
  MarkGapV = 6.0,
  MarkThickness = 2.4,
  NameFontSize = 15,
  DistFontSize = 13,
  StateFontSize = 13,
  TextGap = 1.0,
  CounterFontSize = 17,
  CounterW = 300.0,
  CounterH = 28.0,
  DeadZone = 0.5,
  VisInterval = 0.15,
  SizeHyst = 2.0,
}

local EC_WHITE  = ESPMKC(1.0, 1.0, 1.0, 1.0)
local EC_BLACK  = ESPMKC(0.0, 0.0, 0.0, 1.0)
local EC_GREEN  = ESPMKC(0.12, 1.0, 0.25, 1.0)
local EC_RED    = ESPMKC(1.0, 0.15, 0.15, 1.0)
local EC_YELLOW = ESPMKC(1.0, 0.90, 0.30, 1.0)
local EC_BLUE   = ESPMKC(0.38, 0.72, 1.0, 1.0)

local function RND(v)
  if v ~= v then return 0 end
  return math.floor(v + 0.5)
end

local function Lerp(a, b, t) return a + (b - a) * t end

local function HealthColor(pct)
  pct = tonumber(pct) or 1.0
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  local r, g, b
  if pct >= 0.7 then
    local t = (pct - 0.7) / 0.3
    r = Lerp(0.75, 0.12, t)
    g = 1.0
    b = Lerp(0.15, 0.25, t)
  elseif pct >= 0.4 then
    local t = (pct - 0.4) / 0.3
    r = 1.0
    g = Lerp(0.45, 0.95, t)
    b = Lerp(0.45, 0.20, t)
  else
    local t = pct / 0.4
    r = 1.0
    g = Lerp(0.15, 0.45, t)
    b = Lerp(0.15, 0.45, t)
  end
  return ESPMKC(r, g, b, 1.0)
end

local ESP = {}
ESP.Canvas = nil
ESP.Lines = {}
ESP.Corners = {}
ESP.HealthBg = {}
ESP.HealthFill = {}
ESP.Marks = {}
ESP.Infos = {}
ESP.Counter = nil
ESP.EnemyCache = {}
ESP.VisCache = {}
ESP.ScaleX = 1.0
ESP.ScaleY = 1.0
ESP.OffsetX = 0.0
ESP.OffsetY = 0.0
ESP.ViewW = 1920
ESP.ViewH = 1080
ESP.ScanInterval = 0.35
ESP.LightInterval = 0.033
ESP.TransformInterval = 0.50
ESP.LastScan = -999.0
ESP.LastTransform = -999.0
ESP.LastWorld = nil
ESP.bActive = false

function ESP.GetGameplayData()
  if ESP._GDP then return ESP._GDP end
  local ok, GDP = pcall(function() return require("GameLua.GameCore.Data.GameplayData") end)
  if ok and GDP then ESP._GDP = GDP return GDP end
  return nil
end

function ESP.GetController()
  local pc = nil
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP and GDP.GetPlayerController then pc = GDP.GetPlayerController() end
  end)
  if not ESPValid(pc) then
    pcall(function()
      if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end
    end)
  end
  return ESPValid(pc) and pc or nil
end

function ESP.GetLocalCharacter()
  local c = nil
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP then
      if GDP.GetPlayerCharacter then c = GDP.GetPlayerCharacter() end
      if not ESPValid(c) and GDP.GetLocalCharacter then c = GDP.GetLocalCharacter() end
    end
  end)
  if not ESPValid(c) then
    local pc = ESP.GetController()
    pcall(function() if pc and pc.GetPawn then c = pc:GetPawn() end end)
  end
  return ESPValid(c) and c or nil
end

function ESP.GetAllCharacters()
  local AllChars = {}
  pcall(function()
    local Pawns = Game:GetAllPlayerPawns()
    if Pawns then
      for _, Pawn in pairs(Pawns) do
        if Pawn and slua.isValid(Pawn) then
          local pKey = nil
          if Pawn.GetPlayerKey then pcall(function() pKey = Pawn:GetPlayerKey() end) end
          if not pKey and Pawn.PlayerKey then pKey = Pawn.PlayerKey end
          if not pKey and Pawn.PlayerState and Pawn.PlayerState.PlayerKey then pKey = Pawn.PlayerState.PlayerKey end
          if pKey then AllChars[pKey] = Pawn end
        end
      end
    end
  end)
  if not next(AllChars) then
    pcall(function()
      local GS = require("GameLua.GameCore.Data.CGameState")
      if GS and GS.GetAllCharacters then AllChars = GS:GetAllCharacters() end
    end)
  end
  return AllChars
end

function ESP.GetMyPlayerKey()
  local pc = ESP.GetController()
  if not ESPValid(pc) then return nil end
  local k = nil
  pcall(function()
    if pc.GetPlayerKey then k = pc:GetPlayerKey()
    elseif pc.PlayerState and pc.PlayerState.PlayerKey then k = pc.PlayerState.PlayerKey end
  end)
  return k
end

function ESP.IsMe(Character, PlayerKey, MyKey)
  local me = false
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP and GDP.GetLocalCharacter then
      local mc = GDP.GetLocalCharacter()
      if mc and Character == mc then me = true return end
    end
    local pc = ESP.GetController()
    if pc and pc.GetPawn then
      local p = pc:GetPawn()
      if p and Character == p then me = true return end
    end
  end)
  if not me and MyKey ~= nil and PlayerKey ~= nil then
    me = (tostring(PlayerKey) == tostring(MyKey))
  end
  return me
end

function ESP.GetTeamID(Character)
  if not ESPValid(Character) then return nil end
  local id = nil
  pcall(function() if Character.GetTeamID then id = Character:GetTeamID() end end)
  if id == nil then pcall(function() id = Character.TeamID end) end
  if id == nil then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then ps = Character:GetPlayerState() end
    end)
    if not ESPValid(ps) then pcall(function() ps = Character.PlayerState end) end
    if ESPValid(ps) then
      pcall(function() if ps.GetTeamID then id = ps:GetTeamID() end end)
      if id == nil then pcall(function() id = ps.TeamID end) end
    end
  end
  return id
end

function ESP.IsAlive(Character)
  if not ESPValid(Character) then return false end
  local alive = nil
  pcall(function() if Character.IsAlive then alive = Character:IsAlive() end end)
  if type(alive) == "boolean" then return alive end
  local hp = nil
  pcall(function() hp = Character.Health end)
  if type(hp) ~= "number" then pcall(function() hp = Character.HP end) end
  if type(hp) == "number" then return hp > 0 end
  return true
end

function ESP.IsKnocked(Character)
  if not ESPValid(Character) then return false end
  local k = false
  pcall(function()
    if Character.HealthStatus == 1 then k = true end
  end)
  if not k then pcall(function()
    if Character.IsNearDeath and Character:IsNearDeath() then k = true end
  end) end
  return k
end

function ESP.IsBot(Character)
  if not ESPValid(Character) then return false end
  local bAI = false
  pcall(function()
    if Game and Game.IsAI then bAI = Game:IsAI(Character) end
    if not bAI and Character then
      if Character.bEnsure == true or Character.bMEnsure == true then bAI = true
      elseif Character.PlayerState and Character.PlayerState.bPSEnsure == true then bAI = true
      elseif Character.Controller then
        if Character.Controller.IsMLAI == true or Character.Controller.FakePlayerBornType == 1 then bAI = true end
      end
    end
  end)
  if not bAI then
    pcall(function()
      if Character.bIsAI == true then bAI = true end
    end)
  end
  if not bAI then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety() end
    end)
    if ESPValid(ps) then
      pcall(function()
        if ps.bIsABot == true or ps.bIsBot == true or ps.bIsAI == true then bAI = true end
      end)
    end
  end
  return bAI
end

function ESP.GetPlayerKey(Character)
  local key = nil
  pcall(function() if Character.GetPlayerKey then key = Character:GetPlayerKey() end end)
  if key == nil then pcall(function() key = Character.PlayerKey end) end
  return tostring(key or Character)
end

function ESP.GetHealthPct(Character)
  if not ESPValid(Character) then return 1.0 end
  local hp, maxhp = nil, nil
  pcall(function() hp = Character.Health end)
  if type(hp) ~= "number" then pcall(function() hp = Character.HP end) end
  pcall(function() maxhp = Character.MaxHealth end)
  if type(maxhp) ~= "number" then pcall(function() maxhp = Character.MaxHP end) end
  if type(hp) ~= "number" then return 1.0 end
  if type(maxhp) ~= "number" or maxhp <= 0 then maxhp = 100 end
  local pct = hp / maxhp
  if pct ~= pct then return 1.0 end
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  return pct
end

local function NormalizeName(v)
  if v == nil or v == false then return nil end
  local ok, t = pcall(tostring, v)
  if not ok or not t then return nil end
  t = t:gsub("^%s+", ""):gsub("%s+$", "")
  if t == "" or t == "nil" or t == "None" or t == "NULL" or t == "Unknown" then return nil end
  return t
end

function ESP.ResolveName(Character, isBot)
  if isBot then return "Bot" end
  local name = nil
  local function take(v)
    if not name then name = NormalizeName(v) end
  end
  pcall(function() if Character.GetPlayerNameSafety then take(Character:GetPlayerNameSafety()) end end)
  pcall(function() if not name and Character.GetPlayerName then take(Character:GetPlayerName()) end end)
  pcall(function() if not name then take(Character.PlayerName) end end)
  pcall(function() if not name then take(Character.NickName) end end)
  if not name then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then ps = Character:GetPlayerState() end
    end)
    if not ESPValid(ps) then pcall(function() ps = Character.PlayerState end) end
    if ESPValid(ps) then
      pcall(function() if ps.GetPlayerName then take(ps:GetPlayerName()) end end)
      pcall(function() if not name then take(ps.PlayerName) end end)
      pcall(function() if not name then take(ps.PlayerNamePrivate) end end)
      pcall(function() if not name then take(ps.NickName) end end)
    end
  end
  return name or "Player"
end

function ESP.GetBonePos(Character, boneName)
  if not ESPValid(Character) or not boneName then return nil end
  local pos = nil
  pcall(function()
    if type(Character.GetBonePos) == "function" then
      pos = Character:GetBonePos(boneName, { X = 0, Y = 0, Z = 0 })
    end
    if not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then
      if type(Character.GetSocketLocation) == "function" then
        pos = Character:GetSocketLocation(boneName)
      end
    end
    if (not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0)) and ESPValid(Character.Mesh) then
      local mesh = Character.Mesh
      if mesh and mesh.GetSocketLocation then
        local mp = mesh:GetSocketLocation(boneName)
        if mp and not (mp.X == 0 and mp.Y == 0 and mp.Z == 0) then pos = mp end
      end
    end
  end)
  return pos
end

function ESP.GetCamLoc(pc)
  local loc = nil
  pcall(function()
    if GameplayStaticsESP and GameplayStaticsESP.GetPlayerCameraManager then
      local mgr = GameplayStaticsESP.GetPlayerCameraManager(pc, 0)
      if ESPValid(mgr) and mgr.GetCameraLocation then loc = mgr:GetCameraLocation() end
    end
  end)
  if not loc then
    pcall(function()
      if pc and pc.GetPawn then
        local p = pc:GetPawn()
        if ESPValid(p) and p.K2_GetActorLocation then loc = p:K2_GetActorLocation() end
      end
    end)
  end
  return loc
end

function ESP.IsBoneVisible(pc, camLoc, target, bonePos)
  if not ESPValid(pc) or not ESPValid(target) or not bonePos or not camLoc then return false end
  if not KismetSystemLibraryESP or not KismetSystemLibraryESP.LineTraceSingle then return true end
  local dx = bonePos.X - camLoc.X
  local dy = bonePos.Y - camLoc.Y
  local dz = bonePos.Z - camLoc.Z
  local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
  if dist < 50 then return true end
  TraceStartPos.X = camLoc.X + (dx / dist) * 60
  TraceStartPos.Y = camLoc.Y + (dy / dist) * 60
  TraceStartPos.Z = camLoc.Z + (dz / dist) * 60
  local bVis = false
  pcall(function()
    local bHit = KismetSystemLibraryESP.LineTraceSingle(
      pc, TraceStartPos, bonePos, 0, false, nil, 0, CachedHitResult, true)
    if bHit then
      local hitActor = nil
      if CachedHitResult then
        if type(CachedHitResult.GetActor) == "function" then
          hitActor = CachedHitResult:GetActor()
        elseif CachedHitResult.Actor then
          hitActor = CachedHitResult.Actor
        end
      end
      if ESPValid(hitActor) then
        if hitActor == target then bVis = true end
      end
    else
      bVis = true
    end
  end)
  return bVis
end

function ESP.IsVisible(key, pc, camLoc, Character)
  local now = ESP.Now()
  local cached = ESP.VisCache[key]
  if cached and (now - (cached.t or 0)) < (CFG.VisInterval or 0.15) then
    return cached.b
  end
  local bVis = false
  if ESPValid(Character) and ESPValid(pc) and camLoc then
    local bones = { "head", "spine_03", "pelvis" }
    for _, bn in ipairs(bones) do
      local bp = ESP.GetBonePos(Character, bn)
      if bp and (bp.X ~= 0 or bp.Y ~= 0 or bp.Z ~= 0) then
        if ESP.IsBoneVisible(pc, camLoc, Character, bp) then bVis = true break end
      end
    end
  else
    bVis = true
  end
  ESP.VisCache[key] = { b = bVis, t = now }
  return bVis
end

function ESP.ActorLocation(Character)
  local loc = nil
  if not ESPValid(Character) then return nil end
  pcall(function()
    if Character.K2_GetActorLocation then loc = Character:K2_GetActorLocation()
    elseif Game and Game.GetActorLocation then loc = Game:GetActorLocation(Character) end
  end)
  return loc
end

function ESP.DistMeters(a, b)
  if not a or not b then return math.huge end
  local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
  return math.sqrt(dx * dx + dy * dy + dz * dz) / 100.0
end

function ESP.GetVerticalBounds(Character)
  if not ESPValid(Character) then return nil, nil end
  local center, halfHeight = nil, nil
  local capsule = nil
  pcall(function()
    if Character.GetCapsuleComponent then capsule = Character:GetCapsuleComponent()
    elseif Character.CapsuleComponent then capsule = Character.CapsuleComponent end
  end)
  if capsule and ESPValid(capsule) then
    pcall(function()
      if capsule.K2_GetComponentLocation then center = capsule:K2_GetComponentLocation()
      elseif capsule.GetComponentLocation then center = capsule:GetComponentLocation() end
      if capsule.GetScaledCapsuleHalfHeight then halfHeight = capsule:GetScaledCapsuleHalfHeight()
      elseif capsule.GetUnscaledCapsuleHalfHeight then halfHeight = capsule:GetUnscaledCapsuleHalfHeight()
      elseif capsule.CapsuleHalfHeight then halfHeight = capsule.CapsuleHalfHeight end
    end)
  end
  if not center then
    pcall(function() if Character.K2_GetActorLocation then center = Character:K2_GetActorLocation() end end)
  end
  if not center then
    pcall(function() if Game and Game.GetActorLocation then center = Game:GetActorLocation(Character) end end)
  end
  if not center then return nil, nil end
  if not halfHeight or halfHeight < 10 or halfHeight > 200 then
    halfHeight = 85
    pcall(function()
      if Character.bIsCrouched then halfHeight = 60 end
      if Character.IsProne and Character:IsProne() then halfHeight = 25 end
    end)
  end
  return center, halfHeight
end

function ESP.GetHeadFeet(Character)
  local center, half = ESP.GetVerticalBounds(Character)
  if not center or not half then return nil, nil end
  local head = { X = center.X, Y = center.Y, Z = center.Z + half }
  local feet = { X = center.X, Y = center.Y, Z = center.Z - half }
  return head, feet
end

function ESP.Now()
  local t = nil
  pcall(function()
    local w = (slua and slua.getWorld and slua.getWorld()) or nil
    if GameplayStaticsESP and w and GameplayStaticsESP.GetRealTimeSeconds then
      t = GameplayStaticsESP.GetRealTimeSeconds(w)
    end
  end)
  if tonumber(t) then return tonumber(t) end
  pcall(function() if os and os.clock then t = os.clock() end end)
  return tonumber(t) or 0.0
end

function ESP.World()
  local w = nil
  pcall(function() if slua and slua.getWorld then w = slua.getWorld() end end)
  return w
end

function ESP.GetCanvas()
  if ESPValid(ESP.Canvas) then return ESP.Canvas end
  local root = nil
  pcall(function()
    local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
    if InGameUITools and InGameUITools.GetMainControlBaseUI then root = InGameUITools.GetMainControlBaseUI() end
  end)
  if not ESPValid(root) then return nil end
  local canvas = nil
  pcall(function()
    if ESPValid(root.CanvasPanel_0) then canvas = root.CanvasPanel_0
    elseif ESPValid(root.CanvasPanel_42) then canvas = root.CanvasPanel_42 end
  end)
  if ESPValid(canvas) then ESP.Canvas = canvas return canvas end
  return nil
end

function ESP.UpdateCanvasTransform(pc)
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return false end
  local calibrated = false
  pcall(function()
    if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
      local geo = canvas:GetCachedGeometry()
      if geo then
        local p0 = SlateBlueprintLibrary.AbsoluteToLocal(geo, ESPV2(0, 0))
        local p1 = SlateBlueprintLibrary.AbsoluteToLocal(geo, ESPV2(100, 100))
        if p0 and p1 and tonumber(p0.X) and tonumber(p1.X) and p1.X ~= p0.X and p1.Y ~= p0.Y then
          ESP.ScaleX = (p1.X - p0.X) / 100.0
          ESP.ScaleY = (p1.Y - p0.Y) / 100.0
          ESP.OffsetX = p0.X
          ESP.OffsetY = p0.Y
          calibrated = true
        end
      end
    end
  end)
  if not calibrated then
    local scale = 1.0
    pcall(function()
      if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
        local s = WidgetLayoutLibrary.GetViewportScale(pc)
        if tonumber(s) and s > 0 then scale = s end
      end
    end)
    ESP.ScaleX = 1.0 / scale
    ESP.ScaleY = 1.0 / scale
    ESP.OffsetX = 0.0
    ESP.OffsetY = 0.0
  end
  return true
end

function ESP.Viewport(pc)
  local w, h = 1920.0, 1080.0
  pcall(function()
    if pc and pc.GetViewportSize then
      local v = ESPV2(0, 0)
      pc:GetViewportSize(v)
      if v and tonumber(v.X) and v.X > 200 then w, h = v.X, v.Y end
    end
  end)
  return w, h
end

function ESP.Project(pc, worldLoc)
  if not pc or not worldLoc then return nil end
  local pix = ESPV2(0, 0)
  local ok = false
  pcall(function()
    local res = pc:ProjectWorldLocationToScreen(worldLoc, pix, true)
    ok = (res == true or res == 1 or (pix and (pix.X ~= 0 or pix.Y ~= 0)))
  end)
  if not ok then return nil end
  return ESPV2(pix.X * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0),
               pix.Y * (ESP.ScaleY or 1.0) + (ESP.OffsetY or 0.0)), pix
end

function ESP.SnapOrigin(pc, viewW)
  local cw = nil
  pcall(function()
    local canvas = ESP.GetCanvas()
    if ESPValid(canvas) then
      local geo = canvas:GetCachedGeometry()
      if geo and geo.GetLocalSize then
        local s = geo:GetLocalSize()
        if s and tonumber(s.X) and s.X > 1 then cw = tonumber(s.X) end
      end
    end
  end)
  local cx = nil
  if tonumber(cw) and cw > 1 then cx = cw * 0.5
  else cx = (viewW * 0.5) * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0) end
  return ESPV2(cx, (CFG.SnapOriginY or 0.0))
end

function ESP.SetFont(w, size)
  if not ESPValid(w) then return end
  pcall(function()
    local f = w.Font
    if f then
      f.Size = size
      if f.OutlineSettings then
        pcall(function() f.OutlineSettings.OutlineSize = 1 end)
        pcall(function() f.OutlineSettings.OutlineColor = EC_BLACK end)
      end
      w:SetFont(f)
    end
    if w.SetShadowOffset then w:SetShadowOffset(ESPV2(1.0, 1.0)) end
    if w.SetShadowColorAndOpacity then w:SetShadowColorAndOpacity(EC_BLACK) end
  end)
end

function ESP.SetTextColor(w, color)
  if not ESPValid(w) then return end
  pcall(function()
    if SlateColor then w:SetColorAndOpacity(SlateColor(color))
    else w:SetColorAndOpacity(color) end
  end)
end

function ESP.NewLine(color, z)
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local border = nil
  pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
  if not ESPValid(border) then return nil end
  pcall(function()
    border:SetBrushColor(color)
    border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    border:SetRenderTransformPivot(ESPV2(0.0, 0.5))
  end)
  local slot = nil
  pcall(function() slot = canvas:AddChildToCanvas(border) end)
  if not slot then
    pcall(function() border:RemoveFromParent() end)
    return nil
  end
  pcall(function() slot:SetAutoSize(false) slot:SetZOrder(z or 30) end)
  return { Widget = border, Slot = slot }
end

function ESP.DrawLine(data, x1, y1, x2, y2, thickness)
  if not data or not ESPValid(data.Widget) or not data.Slot then return false end
  if x1 ~= x1 or y1 ~= y1 or x2 ~= x2 or y2 ~= y2 then return false end
  x1, y1, x2, y2 = RND(x1), RND(y1), RND(x2), RND(y2)
  local dz = CFG.DeadZone or 0.5
  if data.lx1 and data.th == thickness then
    if math.abs((data.lx1 or 0) - x1) < dz and math.abs((data.ly1 or 0) - y1) < dz
    and math.abs((data.lx2 or 0) - x2) < dz and math.abs((data.ly2 or 0) - y2) < dz then
      if data.hidden ~= true then return true end
    end
  end
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then
    ESP.Hide(data)
    return false
  end
  local angle = ((math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)) * 180.0 / math.pi
  angle = math.floor(angle * 10 + 0.5) / 10
  len = RND(len)
  if data.lx1 == x1 and data.ly1 == y1 and data.lx2 == x2 and data.ly2 == y2 and data.th == thickness then
    if data.hidden == true then
      pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
      data.hidden = false
    end
    return true
  end
  local ok = pcall(function()
    data.Slot:SetPosition(ESPV2(x1, y1 - thickness * 0.5))
    data.Slot:SetSize(ESPV2(len, thickness))
    data.Widget:SetRenderAngle(angle)
    data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
  end)
  if ok then
    data.lx1, data.ly1, data.lx2, data.ly2, data.th = x1, y1, x2, y2, thickness
    data.hidden = false
  end
  return true
end

function ESP.DrawVBar(data, x, top, h, thickness)
  if not data or not ESPValid(data.Widget) or not data.Slot then return false end
  if h ~= h or h < 1 then ESP.Hide(data) return false end
  x, top, h = RND(x), RND(top), RND(h)
  local dz = CFG.DeadZone or 0.5
  if data.bx ~= nil then
    if math.abs(data.bx - x) < dz and math.abs(data.bt - top) < dz and math.abs(data.bh - h) < dz then
      if data.hidden ~= true then return true end
    end
  end
  if data.bx == x and data.bt == top and data.bh == h then
    if data.hidden == true then
      pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
      data.hidden = false
    end
    return true
  end
  local ok = pcall(function()
    data.Slot:SetPosition(ESPV2(x, top))
    data.Slot:SetSize(ESPV2(thickness, h))
    data.Widget:SetRenderAngle(0)
    data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
  end)
  if ok then data.bx, data.bt, data.bh = x, top, h data.hidden = false end
  return true
end

function ESP.Hide(data)
  if data and ESPValid(data.Widget) and data.hidden ~= true then
    pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    data.hidden = true
    data.lx1, data.ly1, data.lx2, data.ly2, data.th = nil, nil, nil, nil, nil
    data.bx, data.bt, data.bh = nil, nil, nil
  end
end

function ESP.SetBrush(data, color, colorKey)
  if not data or not ESPValid(data.Widget) then return end
  if colorKey and data.colorKey == colorKey then return end
  pcall(function() data.Widget:SetBrushColor(color) end)
  if colorKey then data.colorKey = colorKey end
end

function ESP.Destroy(data)
  if not data then return end
  local w = data.Widget or data.Container
  if ESPValid(w) then
    pcall(function() w:RemoveFromParent() end)
    pcall(function() w:ConditionalBeginDestroy() end)
  end
end

function ESP.CreateCounter()
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local container = nil
  pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
  if not ESPValid(container) then return nil end
  local txt = nil
  pcall(function() txt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  if not ESPValid(txt) then ESP.Destroy({ Widget = container }) return nil end
  pcall(function()
    txt:SetText("Players: 0 | Bots: 0")
    txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    if txt.SetJustification then txt:SetJustification(1) end
  end)
  ESP.SetTextColor(txt, EC_WHITE)
  ESP.SetFont(txt, CFG.CounterFontSize)
  local tSlot, mSlot = nil, nil
  pcall(function() tSlot = container:AddChildToCanvas(txt) end)
  pcall(function() mSlot = canvas:AddChildToCanvas(container) end)
  if not tSlot or not mSlot then ESP.Destroy({ Widget = container }) return nil end
  local W, H = CFG.CounterW or 300.0, CFG.CounterH or 28.0
  pcall(function()
    tSlot:SetAutoSize(true)
    tSlot:SetAlignment(ESPV2(0.5, 0.5))
    tSlot:SetPosition(ESPV2(W * 0.5, H * 0.5))
    tSlot:SetZOrder(5)
    mSlot:SetAutoSize(false)
    mSlot:SetAlignment(ESPV2(0.5, 0.0))
    mSlot:SetSize(ESPV2(W, H))
    mSlot:SetZOrder(60)
  end)
  return { Container = container, Text = txt, Slot = mSlot, W = W, H = H }
end

function ESP.CanvasCenterX(viewW)
  local cw = nil
  pcall(function()
    local canvas = ESP.GetCanvas()
    if ESPValid(canvas) then
      local geo = canvas:GetCachedGeometry()
      if geo and geo.GetLocalSize then
        local s = geo:GetLocalSize()
        if s and tonumber(s.X) and s.X > 1 then cw = tonumber(s.X) end
      end
    end
  end)
  if tonumber(cw) and cw > 1 then return cw * 0.5 end
  return (viewW * 0.5) * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0)
end

function ESP.UpdateCounter(nPlayers, nBots, pc, viewW)
  local d = ESP.Counter
  if not d or not ESPValid(d.Container) then
    ESP.Destroy(d)
    d = ESP.CreateCounter()
    ESP.Counter = d
  end
  if not d then return nil end
  local label = string.format("Players: %d | Bots: %d", nPlayers or 0, nBots or 0)
  pcall(function()
    if d.Last ~= label then d.Text:SetText(label) d.Last = label end
  end)
  local cx = ESP.CanvasCenterX(viewW)
  if cx then
    cx = RND(cx)
    if d.px == nil or math.abs(d.px - cx) >= 1.0 then
      d.px = cx
      pcall(function()
        d.Slot:SetPosition(ESPV2(cx, CFG.TopTextY))
        d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
    else
      pcall(function()
        d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
    end
  end
  return ESPV2(cx, (CFG.SnapOriginY or 0.0))
end

function ESP.CreateInfo()
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local container, tName, tDist, tState = nil, nil, nil, nil
  pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
  if not ESPValid(container) then return nil end
  pcall(function() tName = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tDist = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tState = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  if not ESPValid(tName) or not ESPValid(tDist) or not ESPValid(tState) then
    ESP.Destroy({ Widget = container })
    return nil
  end
  pcall(function()
    tName:SetText("Bot")
    tDist:SetText("0m")
    tState:SetText("Open")
    tName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tDist:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tState:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    if tName.SetJustification then tName:SetJustification(1) end
    if tDist.SetJustification then tDist:SetJustification(1) end
    if tState.SetJustification then tState:SetJustification(1) end
  end)
  ESP.SetTextColor(tName, EC_BLUE)
  ESP.SetTextColor(tDist, EC_WHITE)
  ESP.SetTextColor(tState, EC_GREEN)
  ESP.SetFont(tName, CFG.NameFontSize)
  ESP.SetFont(tDist, CFG.DistFontSize)
  ESP.SetFont(tState, CFG.StateFontSize)
  local s1, s2, s3, ms = nil, nil, nil, nil
  pcall(function() s1 = container:AddChildToCanvas(tName) end)
  pcall(function() s2 = container:AddChildToCanvas(tDist) end)
  pcall(function() s3 = container:AddChildToCanvas(tState) end)
  pcall(function() ms = canvas:AddChildToCanvas(container) end)
  if not s1 or not s2 or not s3 or not ms then
    ESP.Destroy({ Widget = container })
    return nil
  end
  pcall(function()
    s1:SetAutoSize(true) s1:SetAlignment(ESPV2(0.5, 0.5)) s1:SetZOrder(36)
    s2:SetAutoSize(true) s2:SetAlignment(ESPV2(0.5, 0.5)) s2:SetZOrder(36)
    s3:SetAutoSize(true) s3:SetAlignment(ESPV2(0.5, 0.5)) s3:SetZOrder(36)
    ms:SetAutoSize(false) ms:SetZOrder(35)
  end)
  return { Container = container, Name = tName, Dist = tDist, State = tState,
           S1 = s1, S2 = s2, S3 = s3, Slot = ms }
end

function ESP.UpdateInfo(key, Character, isBot, distM, bVisible, footX, footY)
  local d = ESP.Infos[key]
  if not d or not ESPValid(d.Container) then
    ESP.Destroy(d)
    d = ESP.CreateInfo()
    ESP.Infos[key] = d
  end
  if not d then return end
  local name = d.CachedName
  if not name then
    name = ESP.ResolveName(Character, isBot)
    d.CachedName = name
  end
  if isBot then
    name = "Bot"
    d.CachedName = "Bot"
  end
  local dl = string.format("%dm", math.max(0, math.floor((tonumber(distM) or 0) + 0.5)))
  local st = bVisible and "Open" or "Close"
  local stKey = bVisible and "open" or "close"
  pcall(function()
    if d.LastN ~= name then
      d.Name:SetText(name) d.LastN = name
      if isBot then ESP.SetTextColor(d.Name, EC_BLUE)
      else ESP.SetTextColor(d.Name, EC_WHITE) end
    end
    if d.LastD ~= dl then d.Dist:SetText(dl) d.LastD = dl end
    if d.LastS ~= st then
      d.State:SetText(st) d.LastS = st
      if bVisible then ESP.SetTextColor(d.State, EC_GREEN)
      else ESP.SetTextColor(d.State, EC_RED) end
    end
    if d.LastK ~= stKey then d.LastK = stKey end
  end)
  local w = 120.0
  local h1, h2, h3 = 20.0, 17.0, 17.0
  local x = RND(footX - w * 0.5)
  local y = RND(footY + 4.0)
  if d.ix == nil or math.abs(d.ix - x) >= 1.0 or math.abs((d.iy or 0) - y) >= 1.0 then
    d.ix, d.iy = x, y
    pcall(function()
      d.Slot:SetPosition(ESPV2(x, y))
      d.Slot:SetSize(ESPV2(w, h1 + h2 + h3 + 6.0))
      d.S1:SetPosition(ESPV2(w * 0.5, h1 * 0.5))
      d.S2:SetPosition(ESPV2(w * 0.5, h1 + h2 * 0.5 + CFG.TextGap))
      d.S3:SetPosition(ESPV2(w * 0.5, h1 + h2 + h3 * 0.5 + CFG.TextGap * 2.0))
      d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
  else
    pcall(function()
      d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
  end
end

function ESP.EnsureCorner(key, idx, color)
  local t = ESP.Corners[key]
  if not t then t = {} ESP.Corners[key] = t end
  local d = t[idx]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(color or EC_WHITE, 32)
  t[idx] = d
  return d
end

function ESP.EnsureHealthBg(key)
  local d = ESP.HealthBg[key]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(ESPMKC(0.0, 0.0, 0.0, CFG.SideBgAlpha or 0.55), 31)
  ESP.HealthBg[key] = d
  return d
end

function ESP.EnsureHealthFill(key)
  local d = ESP.HealthFill[key]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(EC_GREEN, 32)
  ESP.HealthFill[key] = d
  return d
end

function ESP.UpdateHealthBar(key, pct, x, top, h)
  local bg = ESP.EnsureHealthBg(key)
  local fill = ESP.EnsureHealthFill(key)
  if not bg or not fill then return end
  local w = CFG.SideBarWidth or 3.5
  ESP.DrawVBar(bg, x, top, h, w)
  pct = tonumber(pct) or 1.0
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  local bucket
  if pct >= 0.7 then bucket = "g_" .. math.floor(pct * 20 + 0.5)
  elseif pct >= 0.4 then bucket = "y_" .. math.floor(pct * 20 + 0.5)
  else bucket = "r_" .. math.floor(pct * 20 + 0.5) end
  ESP.SetBrush(fill, HealthColor(pct), bucket)
  local fh = h * pct
  if fh < 1 then
    ESP.Hide(fill)
    return
  end
  ESP.DrawVBar(fill, x, top + (h - fh), fh, w)
end

function ESP.EnsureMark(key, idx)
  local t = ESP.Marks[key]
  if not t then t = {} ESP.Marks[key] = t end
  local d = t[idx]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(EC_YELLOW, 33)
  t[idx] = d
  return d
end

function ESP.EnsureSnap(key)
  local d = ESP.Lines[key]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(EC_GREEN, 30)
  ESP.Lines[key] = d
  return d
end

function ESP.HideTarget(key)
  local c = ESP.Corners[key]
  if c then for i = 1, 8 do ESP.Hide(c[i]) end end
  ESP.Hide(ESP.HealthBg[key])
  ESP.Hide(ESP.HealthFill[key])
  local m = ESP.Marks[key]
  if m then for i = 1, 4 do ESP.Hide(m[i]) end end
  ESP.Hide(ESP.Lines[key])
  local inf = ESP.Infos[key]
  if inf and ESPValid(inf.Container) then
    pcall(function() inf.Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
  end
end

function ESP.ReleaseTarget(key)
  local c = ESP.Corners[key]
  if c then for i = 1, 8 do ESP.Destroy(c[i]) end end
  ESP.Corners[key] = nil
  ESP.Destroy(ESP.HealthBg[key])
  ESP.HealthBg[key] = nil
  ESP.Destroy(ESP.HealthFill[key])
  ESP.HealthFill[key] = nil
  local m = ESP.Marks[key]
  if m then for i = 1, 4 do ESP.Destroy(m[i]) end end
  ESP.Marks[key] = nil
  ESP.Destroy(ESP.Lines[key])
  ESP.Lines[key] = nil
  ESP.Destroy(ESP.Infos[key])
  ESP.Infos[key] = nil
  ESP.VisCache[key] = nil
end

function ESP.ResetWidgets()
  for _, d in pairs(ESP.Lines) do ESP.Destroy(d) end
  for _, t in pairs(ESP.Corners) do for _, d in pairs(t) do ESP.Destroy(d) end end
  for _, d in pairs(ESP.HealthBg) do ESP.Destroy(d) end
  for _, d in pairs(ESP.HealthFill) do ESP.Destroy(d) end
  for _, t in pairs(ESP.Marks) do for _, d in pairs(t) do ESP.Destroy(d) end end
  for _, d in pairs(ESP.Infos) do ESP.Destroy(d) end
  ESP.Lines = {}
  ESP.Corners = {}
  ESP.HealthBg = {}
  ESP.HealthFill = {}
  ESP.Marks = {}
  ESP.Infos = {}
  ESP.VisCache = {}
  if ESP.Counter then ESP.Destroy(ESP.Counter) end
  ESP.Counter = nil
  ESP.Canvas = nil
  ESP.EnemyCache = {}
end

function ESP.Scan()
  local pc = ESP.GetController()
  local me = ESP.GetLocalCharacter()
  if not pc or not me then ESP.EnemyCache = {} return pc, 0, 0 end
  local myLoc = ESP.ActorLocation(me)
  if not myLoc then ESP.EnemyCache = {} return pc, 0, 0 end
  local myTeam = ESP.GetTeamID(me)
  local list = {}
  local nReal, nBot = 0, 0
  local pawns = nil
  pcall(function() if Game and Game.GetAllPlayerPawns then pawns = Game:GetAllPlayerPawns() end end)
  if pawns then
    for _, ch in pairs(pawns) do
      if ESPValid(ch) and ch ~= me and ESP.IsAlive(ch) then
        local team = ESP.GetTeamID(ch)
        if myTeam == nil or team == nil or tostring(team) ~= tostring(myTeam) then
          local loc = ESP.ActorLocation(ch)
          local dm = ESP.DistMeters(myLoc, loc)
          if dm * 100.0 <= (CFG.MaxDistance or 40000) then
            local isBot = ESP.IsBot(ch)
            if isBot then nBot = nBot + 1 else nReal = nReal + 1 end
            list[#list + 1] = { Character = ch, Key = ESP.GetPlayerKey(ch),
                                IsBot = isBot, Distance = dm }
          end
        end
      end
    end
  end
  table.sort(list, function(a, b) return (a.Distance or 99999) < (b.Distance or 99999) end)
  local trimmed = {}
  local maxR = CFG.MaxTracked or 16
  for i, it in ipairs(list) do
    if i > maxR then break end
    trimmed[#trimmed + 1] = it
  end
  ESP.EnemyCache = trimmed
  return pc, nReal, nBot
end

function ESP.Update()
  if not ESP_Enabled then ESP.ResetWidgets() return end
  local world = ESP.World()
  if world ~= ESP.LastWorld then
    ESP.ResetWidgets()
    ESP.LastWorld = world
    ESP.LastScan = -999.0
    ESP.LastTransform = -999.0
  end
  local canvas = ESP.GetCanvas()
  if not canvas then return end
  local now = ESP.Now()
  local pc = ESP.GetController()
  if (now - ESP.LastScan) >= (ESP.ScanInterval or 0.35) then
    local r, b
    pc, r, b = ESP.Scan()
    ESP.LastScan = now
    ESP.RealCount, ESP.BotCount = r or 0, b or 0
  end
  pc = pc or ESP.GetController()
  if not pc then return end
  if (now - (ESP.LastTransform or -999.0)) >= (ESP.TransformInterval or 0.50) then
    ESP.UpdateCanvasTransform(pc)
    ESP.LastTransform = now
  end
  local vw, vh = ESP.Viewport(pc)
  local hyst = CFG.SizeHyst or 2.0
  if math.abs(vw - (ESP.ViewW or 0)) > hyst or math.abs(vh - (ESP.ViewH or 0)) > hyst then
    ESP.ViewW, ESP.ViewH = vw, vh
  else
    vw, vh = ESP.ViewW, ESP.ViewH
  end
  local origin = ESP.UpdateCounter(ESP.RealCount or 0, ESP.BotCount or 0, pc, vw)
  if not origin then return end
  local camLoc = ESP.GetCamLoc(pc)

  local active = {}
  for _, item in ipairs(ESP.EnemyCache) do
    local c = item.Character
    local key = item.Key
    if ESPValid(c) and ESP.IsAlive(c) then
      local head, feet = ESP.GetHeadFeet(c)
      if head and feet then
        local headS, headPix = ESP.Project(pc, head)
        local feetS, feetPix = ESP.Project(pc, feet)
        if headS and feetS and headPix and feetPix then
          local m = CFG.ScreenMargin or 220
          local on = headPix.X > -m and headPix.X < vw + m
            and headPix.Y > -m and headPix.Y < vh + m
            and feetPix.X > -m and feetPix.X < vw + m
            and feetPix.Y > -m and feetPix.Y < vh + m
          if on then
            local H = feetS.Y - headS.Y
            if H >= (CFG.BoxMinHeight or 14) and H <= vh * 1.5 then
              active[key] = true
              local W = H * (CFG.BoxWidthFactor or 0.62)
              W = math.max(CFG.BoxMinWidth or 22, math.min(CFG.BoxMaxWidth or 320, W))
              local padT = H * (CFG.HeadExtra or 0)
              local padB = H * (CFG.FootExtra or 0)
              local cx = (headS.X + feetS.X) * 0.5
              local L = cx - W * 0.5
              local R = cx + W * 0.5
              local T = headS.Y - padT
              local B = feetS.Y + padB

              local arm = math.min(R - L, B - T) * (CFG.CornerLen or 0.28)
              arm = math.max(CFG.CornerMin or 6, math.min(CFG.CornerMax or 28, arm))
              local th = CFG.CornerThickness or 2.2
              ESP.DrawLine(ESP.EnsureCorner(key, 1, EC_WHITE), L, T, L + arm, T, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 2, EC_WHITE), L, T, L, T + arm, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 3, EC_WHITE), R, T, R - arm, T, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 4, EC_WHITE), R, T, R, T + arm, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 5, EC_WHITE), L, B, L + arm, B, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 6, EC_WHITE), L, B, L, B - arm, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 7, EC_WHITE), R, B, R - arm, B, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 8, EC_WHITE), R, B, R, B - arm, th)

              local pct = ESP.GetHealthPct(c)
              local sbX = L - (CFG.SideBarGap or 5.0)
              ESP.UpdateHealthBar(key, pct, sbX, T, B - T)

              local ccx = (L + R) * 0.5
              local mw = CFG.MarkW or 15.0
              local mh = CFG.MarkH or 10.0
              local gv = CFG.MarkGapV or 6.0
              local gp = CFG.MarkGap or 8.0
              local mt = CFG.MarkThickness or 2.4
              local y2 = T - gp
              local y1 = y2 - mh - gv
              ESP.DrawLine(ESP.EnsureMark(key, 1), ccx - mw, y1, ccx, y1 + mh, mt)
              ESP.DrawLine(ESP.EnsureMark(key, 2), ccx + mw, y1, ccx, y1 + mh, mt)
              ESP.DrawLine(ESP.EnsureMark(key, 3), ccx - mw, y2 - mh, ccx, y2, mt)
              ESP.DrawLine(ESP.EnsureMark(key, 4), ccx + mw, y2 - mh, ccx, y2, mt)

              ESP.DrawLine(ESP.EnsureSnap(key), origin.X, origin.Y, headS.X, headS.Y,
                           CFG.SnapThickness or 1.8)

              local bVis = ESP.IsVisible(key, pc, camLoc, c)
              ESP.UpdateInfo(key, c, item.IsBot, item.Distance, bVis, cx, B)
            else
              ESP.HideTarget(key)
            end
          else
            ESP.HideTarget(key)
          end
        else
          ESP.HideTarget(key)
        end
      else
        ESP.HideTarget(key)
      end
    end
  end
  local seenCache = {}
  for _, it in ipairs(ESP.EnemyCache) do seenCache[it.Key] = true end
  local function stillActive(k)
    return active[k] == true
  end
  for k, _ in pairs(ESP.Lines) do if not stillActive(k) then ESP.HideTarget(k) end end
  for k, _ in pairs(ESP.Infos) do if not stillActive(k) then ESP.HideTarget(k) end end
  for k, _ in pairs(ESP.Corners) do
    if not stillActive(k) and not seenCache[k] then ESP.ReleaseTarget(k) end
  end
  for k, _ in pairs(ESP.HealthBg) do
    if not seenCache[k] and not stillActive(k) then ESP.ReleaseTarget(k) end
  end
end

function ESP.Tick()
  pcall(ESP.Update)
end

function ESP.AttachTimers()
  pcall(function()
    local pc = ESP.GetController()
    if ESPValid(pc) and pc.AddGameTimer then
      if ESP._TimerPC == pc and ESP._TimerHooked then return end
      ESP._TimerPC = pc
      ESP._TimerHooked = true
      pc:AddGameTimer(ESP.LightInterval or 0.033, true, function()
        if ESP.bActive then pcall(ESP.Tick) end
      end)
    else
      pcall(function()
        require("timer").SetGameTimer(1.0, false, function()
          ESP._TimerHooked = false
          ESP.AttachTimers()
        end)
      end)
    end
    pcall(function() require("timer").SetGameTimer(5.0, false, function() ESP.AttachTimers() end) end)
  end)
end

function ESP.Start()
  if ESP.bActive then return end
  ESP.bActive = true
  pcall(ESP.Update)
  ESP.AttachTimers()
end

function ESP.Stop()
  ESP.bActive = false
  ESP.ResetWidgets()
end

_G.ESP = ESP
_G.PlayerMapMarker = ESP

local function ESPLater(sec, fn)
  local tk = nil
  pcall(function() tk = require("common.time_ticker") end)
  if tk and tk.AddTimerOnce then pcall(function() tk.AddTimerOnce(sec, fn) end) return end
  pcall(function() require("timer").SetGameTimer(sec, false, fn) end)
end

local _ESPStartedPC = nil
local function ESPStartAll()
  pcall(function()
    local pc = nil
    if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end
    if not ESPValid(pc) then pc = ESP.GetController() end
    if ESPValid(pc) then
      if pc ~= _ESPStartedPC then
        _ESPStartedPC = pc
        ESP._TimerHooked = false
        ESP._TimerPC = nil
        ESP.Start()
      else
        ESP.AttachTimers()
      end
    end
  end)
end

pcall(function()
  ESPStartAll()
  ESPLater(1.0, ESPStartAll)
end)
if not _G.__ESPLookTickStarted then
  _G.__ESPLookTickStarted = true
  ESP.bActive = true
  ESP.AttachTimers()
end

-- =========================================================================
-- 7 — New Wallhack
-- =========================================================================
local NewWallhack = {
    Active = false,
    WH_TIMER = nil,
    PROCESSED_PAWNS = {},
    TICK_COUNT = 0,
    CONSOLE_READY = false,
    TICK_INTERVAL = 0.3,
    MAX_PAWNS_PER_TICK = 20,
    RESET_PROCESSED_EVERY = 6,
    AVATAR_SLOTS = {0,1,2,3,4,5,6,7},
    colors = { vis = nil, occ = nil, bVis = nil, bOcc = nil }
}

pcall(function()
    local LC = safeImport("LinearColor")
    if LC then
        NewWallhack.colors.vis = LC(0.0, 1.0, 0.0, 0.4)
        NewWallhack.colors.occ = LC(1.0, 0.0, 0.0, 0.4)
        NewWallhack.colors.bVis = LC(0.0, 0.8, 0.0, 0.4)
        NewWallhack.colors.bOcc = LC(0.8, 0.0, 0.0, 0.4)
    end
end)

local function SetupConsole()
    if NewWallhack.CONSOLE_READY then return end
    pcall(function()
        local KSL = safeImport("KismetSystemLibrary")
        local world = slua.getWorld()
        if not KSL or not world then return end
        KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
        NewWallhack.CONSOLE_READY = true
    end)
end

local function ApplyToMesh(mesh, visColor, occColor)
    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        if mesh.SetDrawDyeing then mesh:SetDrawDyeing(true) end
        if mesh.SetDrawDyeingMode then mesh:SetDrawDyeingMode(1) end
        if mesh.SetVisibleDyeingColor then mesh:SetVisibleDyeingColor(visColor) end
        if mesh.SetOccludedDyeingColor then mesh:SetOccludedDyeingColor(occColor) end
        if mesh.SetDyeingColorFadeDistance then mesh:SetDyeingColorFadeDistance(99999.0) end
        if mesh.SetDyeingColorMinMaxDistance then mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0) end
        if mesh.SetDrawHighlight then mesh:SetDrawHighlight(true) end
        if mesh.OverrideHighlightColor then mesh:OverrideHighlightColor(visColor) end
        if mesh.SetHighlightCanBeOccluded then mesh:SetHighlightCanBeOccluded(false) end
        if mesh.SetDrawIdeaOutline then mesh:SetDrawIdeaOutline(true) end
        if mesh.SetIdeaOutlineNew then mesh:SetIdeaOutlineNew(true) end
        if mesh.SetIdeaOutlineOcclusionHighlight then mesh:SetIdeaOutlineOcclusionHighlight(true) end
        if mesh.OverrideIdeaOutlineColor then mesh:OverrideIdeaOutlineColor(visColor) end
        if mesh.SetIdeaOutlineOcclusionColor then mesh:SetIdeaOutlineOcclusionColor(occColor) end
        if mesh.OverrideIdeaOutlineThickness then mesh:OverrideIdeaOutlineThickness(20.0) end
        if mesh.SetIdeaOverrideOutlineAndOcclusion then mesh:SetIdeaOverrideOutlineAndOcclusion(true) end
        if mesh.SetRenderCustomDepth then mesh:SetRenderCustomDepth(true) end
        if mesh.SetCustomDepthStencilValue then mesh:SetCustomDepthStencilValue(255) end
    end)
end

local function IsPawnAlive(pawn)
    if not slua.isValid(pawn) then return false end
    if pawn.Health and pawn.Health > 0 then return true end
    return false
end

local function NewWallhackTick()
    pcall(function()
        local localPawn = GameplayData and GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if not slua.isValid(localPawn) then return end
        SetupConsole()
        if not NewWallhack.colors.vis then return end
        NewWallhack.TICK_COUNT = NewWallhack.TICK_COUNT + 1
        if NewWallhack.TICK_COUNT % NewWallhack.RESET_PROCESSED_EVERY == 0 then
            NewWallhack.PROCESSED_PAWNS = {}
        end
        local myTeamId = localPawn.TeamID or 0
        local allPawns = Game:GetAllPlayerPawns() or {}
        local processedCount = 0
        for _, pawn in pairs(allPawns) do
            if processedCount >= NewWallhack.MAX_PAWNS_PER_TICK then break end
            if not slua.isValid(pawn) or pawn == localPawn then goto continue end
            if pawn.PlayerKey and NewWallhack.PROCESSED_PAWNS[pawn.PlayerKey] then goto continue end
            if IsPawnAlive(pawn) and pawn.TeamID and pawn.TeamID ~= myTeamId then
                local isAI = pcall(Game.IsAI, pawn) and true or false
                local vis = isAI and NewWallhack.colors.bVis or NewWallhack.colors.vis
                local occ = isAI and NewWallhack.colors.bOcc or NewWallhack.colors.occ
                pcall(function()
                    if slua.isValid(pawn.Mesh) then ApplyToMesh(pawn.Mesh, vis, occ) end
                    local avatarComp = pawn.CharacterAvatarComp2_BP or (pawn.getAvatarComponent2 and pawn:getAvatarComponent2())
                    if avatarComp and avatarComp.GetMeshCompBySlot then
                        for _, slot in ipairs(NewWallhack.AVATAR_SLOTS) do
                            local mesh = avatarComp:GetMeshCompBySlot(slot)
                            if slua.isValid(mesh) then ApplyToMesh(mesh, vis, occ) end
                        end
                    end
                    pcall(function()
                        local SkeletalMeshComponent = safeImport("SkeletalMeshComponent")
                        if SkeletalMeshComponent and pawn.GetComponentsByClass then
                            local skComps = pawn:GetComponentsByClass(SkeletalMeshComponent)
                            if skComps then
                                for i = 0, skComps:Num() - 1 do
                                    local comp = skComps:Get(i)
                                    if slua.isValid(comp) and comp ~= pawn.Mesh then
                                        ApplyToMesh(comp, vis, occ)
                                    end
                                end
                            end
                        end
                    end)
                    pcall(function()
                        local StaticMeshComponent = safeImport("StaticMeshComponent")
                        if StaticMeshComponent and pawn.GetComponentsByClass then
                            local stComps = pawn:GetComponentsByClass(StaticMeshComponent)
                            if stComps then
                                for i = 0, stComps:Num() - 1 do
                                    local comp = stComps:Get(i)
                                    if slua.isValid(comp) then ApplyToMesh(comp, vis, occ) end
                                end
                            end
                        end
                    end)
                    if pawn.GetCurrentWeapon then
                        local weapon = pawn:GetCurrentWeapon()
                        if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
                            ApplyToMesh(weapon.Mesh, vis, occ)
                        end
                    end
                end)
                if pawn.PlayerKey then NewWallhack.PROCESSED_PAWNS[pawn.PlayerKey] = true end
                processedCount = processedCount + 1
            end
            ::continue::
        end
    end)
end

function _G.StartNewWallhack()
    if NewWallhack.WH_TIMER then return end
    SetupConsole()
    if not NewWallhack.colors.vis then return false end
    if _G.Game and _G.Game.AddGameTimer then
        NewWallhack.WH_TIMER = _G.Game:AddGameTimer(NewWallhack.TICK_INTERVAL, true, NewWallhackTick)
        NewWallhack.Active = true
        return true
    end
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) and pc.AddGameTimer then
        NewWallhack.WH_TIMER = pc:AddGameTimer(NewWallhack.TICK_INTERVAL, true, NewWallhackTick)
        NewWallhack.Active = true
        return true
    end
    return false
end

function _G.StopNewWallhack()
    if NewWallhack.WH_TIMER then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(NewWallhack.WH_TIMER) end
        end)
        NewWallhack.WH_TIMER = nil
    end
    NewWallhack.PROCESSED_PAWNS = {}
    NewWallhack.Active = false
end

pcall(function()
    local ticker = package.loaded["common.time_ticker"] or require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(4.0, function()
            if _G.StartNewWallhack then _G.StartNewWallhack() end
        end)
    end
end)

-- =========================================================================
-- 8 — Menu injection
-- =========================================================================
function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true

    _G.GTLMODState.CustomTextData = _G.GTLMODState.CustomTextData or {
        OuterSpeed = 10, InnerSpeed = 10, OuterRecoil = 0,
        HRecoil = 0.3, VRecoil = 0.3, IpadViewFOV = 120,
    }

    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    if LocUtil and not LocUtil._IsModMenuHooked then
        local old_get = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and not tonumber(id) then return id end
            return old_get(id)
        end
        LocUtil._IsModMenuHooked = true
    end

    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")

    if not SettingPageDefine.ModMenu then
        local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")

        local StackESPVisual = {
            { Key = "ModMenu_ESP1", UI = AliasMap.Switcher, Text = "ESP (AUTO SETUP) TELEGRAM PSYCO", GetFunc = function() return _G.GTLMODConfig.EspVip end, SetFunc = function(c,v) _G.GTLMODConfig.EspVip = v return true end },
            { Key = "ModMenu_ESP7", UI = AliasMap.Switcher, Text = "ESP WARNING & COUNT", GetFunc = function() return _G.GTLMODConfig.Esp7 end, SetFunc = function(c,v) _G.GTLMODConfig.Esp7 = v return true end },
            { Key = "ModMenu_ESP2", UI = AliasMap.Switcher, Text = "ESP RANGE", GetFunc = function() return _G.GTLMODConfig.EspDistance end, SetFunc = function(c,v) _G.GTLMODConfig.EspDistance = v return true end },
            { Key = "ModMenu_ESP4", UI = AliasMap.Switcher, Text = "ESP MARK - 360 Radar", GetFunc = function() return _G.GTLMODConfig.EspRadar end, SetFunc = function(c,v) _G.GTLMODConfig.EspRadar = v return true end },
            { Key = "ModMenu_ESP5", UI = AliasMap.Switcher, Text = "ESP BOX FRAME", GetFunc = function() return _G.GTLMODConfig.Esp5 end, SetFunc = function(c,v) _G.GTLMODConfig.Esp5 = v return true end },
            { Key = "ModMenu_ESPAntenna", UI = AliasMap.Switcher, Text = "ESP LINE ANTENA", GetFunc = function() return _G.GTLMODConfig.EspAntenna end, SetFunc = function(c,v) _G.GTLMODConfig.EspAntenna = v return true end },
            { Key = "ModMenu_ESPName", UI = AliasMap.Switcher, Text = "ESP NAME (VISIBLE)", GetFunc = function() return _G.GTLMODConfig.EspName end, SetFunc = function(c,v) _G.GTLMODConfig.EspName = v return true end },
            { Key = "ModMenu_ESPLine", UI = AliasMap.Switcher, Text = "ESP LOOK (NEW ENGINE)", GetFunc = function() return _G.GTLMODConfig.EspLine end, SetFunc = function(c,v)
                _G.GTLMODConfig.EspLine = v
                ESP_Enabled = v
                if _G.ESP then
                    if v then _G.ESP.Start() else _G.ESP.Stop() end
                end
                return true
            end },
            { Key = "ModMenu_ESPOutline_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ ESP OUTLINE", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.EspOutline end, SetFunc = function(c,v) _G.GTLMODConfig.EspOutline = v return true end },
            { Key = "ModMenu_ESPOutline_Thickness", UI = AliasMap.Slider, Text = "   Outline Thickness", ExpandHandle = "ModMenu_ESPOutline_Ex", MinValue = 1, MaxValue = 20, min = 1, max = 20, GetFunc = function() return _G.GTLMODConfig.OutlineThickness end, SetFunc = function(c,v) _G.GTLMODConfig.OutlineThickness = v return true end },
            { Key = "ModMenu_Counter", UI = AliasMap.Switcher, Text = "PLAYER/BOT COUNTER (ESP)", GetFunc = function() return _G.GTLMODConfig.CounterEnabled end, SetFunc = function(c,v) _G.GTLMODConfig.CounterEnabled = v return true end },
        }

        local StackWallhack = {
            { Key = "ModMenu_NewWallhack", UI = AliasMap.Switcher, Text = "NEW WALLHACK (GREEN/RED)", GetFunc = function() return _G.GTLMODConfig.WallhackSmart end, SetFunc = function(c,v)
                _G.GTLMODConfig.WallhackSmart = v
                if v then
                    if _G.StartNewWallhack then _G.StartNewWallhack() end
                else
                    if _G.StopNewWallhack then _G.StopNewWallhack() end
                end
                return true
            end },
            { Key = "ModMenu_WallColor", UI = AliasMap.Switcher, Text = "Wallhack & Color (OLD)", GetFunc = function() return _G.GTLMODConfig.wallhackng end, SetFunc = function(c,v) _G.GTLMODConfig.wallhackng = v; _G.GTLMODConfig.ColorBodyV2 = v return true end },
        }

        local StackAimbotForce = {
            { Key = "ModMenu_AT_Enable", UI = AliasMap.Switcher, Text = "Aimbot (UR/Room Touch)", GetFunc = function() return _G.GTLMODConfig.AimTouchEnable end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchEnable = v return true end },
            { Key = "ModMenu_AT_IgKnock", UI = AliasMap.Switcher, Text = "Ignore Knocked", GetFunc = function() return _G.GTLMODConfig.AimTouchIgKnock end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchIgKnock = v return true end },
            { Key = "ModMenu_AT_IgBot", UI = AliasMap.Switcher, Text = "Ignore Bots", GetFunc = function() return _G.GTLMODConfig.AimTouchIgBot end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchIgBot = v return true end },
            { Key = "ModMenu_AT_Vis", UI = AliasMap.Switcher, Text = "Visibility Check", GetFunc = function() return _G.GTLMODConfig.AimTouchVisCheck end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchVisCheck = v return true end },
            { Key = "ModMenu_AT_Debug", UI = AliasMap.Switcher, Text = "Aim Debug Text (for fixing)", GetFunc = function() return _G.GTLMODConfig.AimDebug end, SetFunc = function(c,v) _G.GTLMODConfig.AimDebug = v return true end },
        }

        local StackCombatGraphic = {
            { Key = "ModMenu_Ipad_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ iPad View", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.IpadView end, SetFunc = function(c,v) _G.GTLMODConfig.IpadView = v return true end },
            { Key = "ModMenu_Ipad_FOV", UI = AliasMap.Slider, Text = "   FOV Angle", ExpandHandle = "ModMenu_Ipad_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return (_G.GTLMODState.CustomTextData.IpadViewFOV or 120) - 80 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.IpadViewFOV = 80 + v return true end },
            { Key = "ModMenu_165FPS", UI = AliasMap.Switcher, Text = "Unlock 165 FPS", GetFunc = function() return _G.GTLMODConfig.UnlockFPS end, SetFunc = function(c,v) _G.GTLMODConfig.UnlockFPS = v; if v then _G.GTLMODState.GraphicsUnlocked = false end return true end },
            { Key = "ModMenu_BlackSky", UI = AliasMap.Switcher, Text = "Black Sky", GetFunc = function() return _G.GTLMODConfig.BlackSky end, SetFunc = function(c,v) _G.GTLMODConfig.BlackSky = v return true end },
            { Key = "ModMenu_RemoveFog", UI = AliasMap.Switcher, Text = "Remove Fog", GetFunc = function() return _G.GTLMODConfig.RemoveFog end, SetFunc = function(c,v) _G.GTLMODConfig.RemoveFog = v return true end },
        }

        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text = "PSYCO MENU",
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "Cat_Aimbot_Force", Text = "UR/ROOM-TOUCH AIM", Stack = StackAimbotForce },
                { Key = "Cat_ESP_Visual", Text = "ESP PLAYER", Stack = StackESPVisual },
                { Key = "Cat_Wallhack", Text = "WALLHACK SETTINGS", Stack = StackWallhack },
                { Key = "Cat_Combat_Graphic", Text = "WALLHACK/FPS", Stack = StackCombatGraphic }
            }
        }
        table.insert(SettingCatalog, SettingPageDefine.ModMenu)
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...)
            if config and config.keyName and (string.find(string.lower(config.keyName), "setting_main") or string.find(string.lower(config.keyName), "setting")) then
                local catalog = args[1]
                if type(catalog) == "table" then
                    local hasModMenu = false
                    for _, page in ipairs(catalog) do
                        if type(page) == "table" and page.Key == "ModMenu" then hasModMenu = true; break end
                    end
                    if not hasModMenu then table.insert(catalog, SettingPageDefine.ModMenu) end
                end
            end
            local table_unpack = table.unpack or unpack
            return old_ShowUI(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end
end

local function Notify(msg)
    local s = "[PSYCO MOD] " .. tostring(msg)
    pcall(function()
        local sh = safeImport("ScriptHelperClient")
        if sh and sh.AddOnScreenDebugMessage then
            sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1,G=1,B=0,A=1}, {X=1.2, Y=1.2})
        end
    end)
end

-- =========================================================================
-- 9 — Native ESP
-- =========================================================================
local function InitializeGraphicsUnlock()
    if isExpired then return end
    if _G.GTLMODState.GraphicsUnlocked then return end
    pcall(function()
        local SettingCfg = require("client.logic.setting.setting_config")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        if SettingCfg then
            if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
            if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
        end
        if GraphicSettingDB and GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
    end)
    _G.GTLMODState.GraphicsUnlocked = true
end

local function InitializeNativeESP()
    if _G.GTLMODState.NativeESPReady then return end
    pcall(function()
        local currentMarkCfg = GamePlayTools and GamePlayTools.GetCurrentConfig and GamePlayTools.GetCurrentConfig("ScreenMarkConfig")
        local function ApplyCfg(cfg)
            if not cfg then return end
            if cfg[1006] then
                cfg[1006].bBindBlocked = true
                cfg[1006].bBindOutScreen = true
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root"
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30)
            end
            cfg[8888] = {
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, MaxShowDistance = 6000000,
                bBindOutScreen = true, bBindBlocked = true, bIsBindingActor = true,
                BindSocketName = "head", bUseLuaWorldSocketName = true,
                WorldPositionOffset = FVector(0, 0, 30), bNeedPreLoad = true, Priority = 2
            }
            cfg[9999] = {
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, MaxShowDistance = 6000000,
                bBindOutScreen = true, bBindBlocked = true, bIsBindingActor = true,
                BindSocketName = "head", bUseLuaWorldSocketName = true,
                WorldPositionOffset = FVector(0, 0, 50), bNeedPreLoad = true, Priority = 2
            }
        end
        ApplyCfg(currentMarkCfg)
        for k, cfg in pairs(package.loaded) do
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then
                ApplyCfg(cfg)
            end
        end
    end)
    _G.GTLMODState.NativeESPReady = true
end

local function SafeAddMark(id, pos, z, str, size, actor)
    if not _G.GTLMODState.TrackedMarks then _G.GTLMODState.TrackedMarks = {} end
    local count = 0
    for _ in pairs(_G.GTLMODState.TrackedMarks) do count = count + 1 end
    if count >= LIMITS.MAX_TRACKED_MARKS then return nil end
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.GTLMODState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(mark) end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then InGameMarkTools.RemoveMapMark(mark) end
    end)
    if _G.GTLMODState.TrackedMarks then _G.GTLMODState.TrackedMarks[mark] = nil end
end

local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

-- =========================================================================
-- 10 — Aimbot (AimTouch)
-- =========================================================================
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()
    if not slua.isValid(player) then return result end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = 0
    pcall(function() myTeam = player:GetTeamID() or player.TeamID or 0 end)

    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player then
            local isAlive = true
            pcall(function()
                if type(actor.IsAlive) == "function" then
                    isAlive = actor:IsAlive()
                elseif actor.HealthStatus ~= nil then
                    isAlive = (actor.HealthStatus ~= 2)
                elseif actor.bIsDead ~= nil then
                    isAlive = not actor.bIsDead
                end
            end)
            if isAlive then
                local teamId = -1
                pcall(function()
                    if type(actor.GetTeamID) == "function" then teamId = actor:GetTeamID()
                    elseif actor.TeamID ~= nil then teamId = actor.TeamID end
                end)
                if teamId ~= myTeam then
                    local dist = 999999
                    pcall(function() dist = player:GetDistanceTo(actor) end)
                    if dist <= radius then table.insert(result, actor) end
                end
            end
        end
    end
    return result
end

local function GetTargetBonePos(target, boneName, fallbackZ)
    local pos = nil
    if type(target.GetBonePos) == "function" then
        pcall(function() pos = target:GetBonePos(boneName, {X=0, Y=0, Z=0}) end)
    end
    if not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then
        pcall(function()
            if slua.isValid(target.Mesh) and type(target.Mesh.GetSocketLocation) == "function" then
                pos = target.Mesh:GetSocketLocation(boneName)
            end
        end)
    end
    if not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then
        pcall(function()
            if type(target.GetSocketLocation) == "function" then
                pos = target:GetSocketLocation(boneName)
            end
        end)
    end
    if not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then
        pcall(function()
            if type(target.K2_GetActorLocation) == "function" then
                pos = target:K2_GetActorLocation()
                if pos then pos.Z = pos.Z + (fallbackZ or 70) end
            end
        end)
    end
    return pos
end

local function TrimCache(cache, maxSize, now)
    if not cache then return end
    local count = 0
    for _ in pairs(cache) do count = count + 1 end
    if count <= maxSize then return end
    local toRemove = {}
    for k, v in pairs(cache) do
        if type(v) == "table" and v.time and (now - v.time) > 30 then
            table.insert(toRemove, k)
        end
    end
    for _, k in ipairs(toRemove) do cache[k] = nil end
    count = 0
    for _ in pairs(cache) do count = count + 1 end
    if count > maxSize then
        for k in pairs(cache) do cache[k] = nil end
    end
end

_G.AimTouch = function()
    if not _G.GTLMODConfig.AimTouchEnable then return end
    if not _G.GTLMODState.AimDebugErr then _G.GTLMODState.AimDebugErr = "starting" end

    local player = GameplayData.GetPlayerCharacter()
    if not slua.isValid(player) then _G.GTLMODState.AimLastFail = "no player"; return end

    local pc = player:GetPlayerControllerSafety()
    if not slua.isValid(pc) then _G.GTLMODState.AimLastFail = "no pc"; return end

    local isFiring = player.bIsWeaponFiring
    local isADS = player.bIsGunADS

    local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
    if not weapon and type(player.GetCurrentShootWeapon) == "function" then
        weapon = player:GetCurrentShootWeapon()
    end

    local isShotgun = false
    local isSniper = false
    local currentAmmo = 1

    if slua.isValid(weapon) then
        local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
        local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
        if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then
            isShotgun = true
        end
        if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
            isSniper = true
        end
        if type(weapon.GetCurrentAmmo) == "function" then
            currentAmmo = weapon:GetCurrentAmmo()
        elseif weapon.CurrentAmmo ~= nil then
            currentAmmo = weapon.CurrentAmmo
        end
    end

    if _G.GTLMODState.IsAutoFiring then
        pcall(function()
            player.bIsWeaponFiring = false
            if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
            if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
            local wepMgr = player.WeaponManagerComponent
            if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
        end)
        _G.GTLMODState.IsAutoFiring = false
    end

    if isShotgun and currentAmmo <= 0 then _G.GTLMODState.AimLastFail = "shotgun no ammo"; return end

    local cond = 2
    local boneIdx = 1
    local speedVal = 50
    local fovVal = 30
    local maxDistMeters = 50
    local useVisCheck = _G.GTLMODConfig.AimTouchVisCheck
    local igKnock = _G.GTLMODConfig.AimTouchIgKnock
    local igBot = _G.GTLMODConfig.AimTouchIgBot

    if isShotgun then
        cond = 2; boneIdx = 2; speedVal = 90; fovVal = 32; maxDistMeters = 30
    elseif isADS then
        if isSniper then
            cond = 2; boneIdx = 1; speedVal = 85; fovVal = 28; maxDistMeters = 400
        else
            cond = 1; boneIdx = 2; speedVal = 85; fovVal = 28; maxDistMeters = 300
        end
    else
        cond = 1; boneIdx = 1; speedVal = 85; fovVal = 28; maxDistMeters = 250
    end

    if cond == 1 and not isFiring then _G.GTLMODState.AimLastFail = "not firing"; return end

    local currentMaxDist = maxDistMeters * 100
    local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
    if not enemies or #enemies == 0 then _G.GTLMODState.AimLastFail = "no enemies"; return end

    local FVector2D = safeImport("Vector2D")
    local UGameplayStatics = safeImport("GameplayStatics")
    local KismetMathLibrary = safeImport("KismetMathLibrary")
    if not FVector2D or not UGameplayStatics or not KismetMathLibrary then return end

    local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
    if not slua.isValid(camManager) then _G.GTLMODState.AimLastFail = "no camManager"; return end
    local camLoc = camManager:GetCameraLocation()
    if not camLoc then _G.GTLMODState.AimLastFail = "no camLoc"; return end

    local ui_util = require("client.common.ui_util")
    if not ui_util then _G.GTLMODState.AimLastFail = "no ui_util"; return end
    local viewportSize = ui_util.GetViewportSize()
    if not viewportSize then _G.GTLMODState.AimLastFail = "no viewport"; return end

    local centerX = viewportSize.X * 0.5
    local centerY = viewportSize.Y * 0.5
    local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)

    local bestTarget = nil
    local bestScore = 99999999
    local selBoneName = "head"
    if boneIdx == 2 then selBoneName = "spine_03"
    elseif boneIdx == 3 then selBoneName = "spine_01"
    elseif boneIdx == 4 then selBoneName = "pelvis" end

    local now = os.clock()
    _G.BotStatusCache = _G.BotStatusCache or {}
    _G.AimTouchVisCache = _G.AimTouchVisCache or {}
    if not _G.LastCacheTrim or (now - _G.LastCacheTrim) > 15 then
        _G.LastCacheTrim = now
        TrimCache(_G.BotStatusCache, LIMITS.MAX_BOT_CACHE, now)
        TrimCache(_G.AimTouchVisCache, LIMITS.MAX_VIS_CACHE, now)
    end

    for i, target in ipairs(enemies) do
        if slua.isValid(target) then
            pcall(function()
                if slua.isValid(target.Mesh) then target.Mesh.MeshComponentUpdateFlag = 0 end
            end)

            local skip = false
            if igKnock and target.HealthStatus == 1 then skip = true end

            if not skip and igBot then
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                local cachedBot = _G.BotStatusCache[tId]
                if cachedBot == nil then
                    cachedBot = false
                    if target.bIsAI == true or target.IsAI == true or target.bIsAi == true then cachedBot = true end
                    if not cachedBot then
                        if target.AIData ~= nil or target.AIController ~= nil or target.bIsAIActor == true then cachedBot = true end
                        if not cachedBot and target.PlayerAIType ~= nil and target.PlayerAIType ~= 0 then cachedBot = true end
                    end
                    if not cachedBot then
                        local pState = target.PlayerState
                        if slua.isValid(pState) then
                            if pState.bIsABot or pState.bIsBot or pState.IsBot or pState.bIsAI then cachedBot = true end
                            if not cachedBot then
                                local uid = pState.Uid or pState.UID or pState.PlayerId or pState.PlayerID
                                if uid ~= nil and (uid == 0 or uid == "0") then cachedBot = true end
                            end
                        end
                    end
                    if not cachedBot and type(target.IsBot) == "function" then
                        local ok, r = pcall(function() return target:IsBot() end)
                        if ok and r then cachedBot = true end
                    end
                    _G.BotStatusCache[tId] = cachedBot
                end
                if cachedBot then skip = true end
            end

            if not skip and useVisCheck then
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                local cacheEntry = _G.AimTouchVisCache[tId]
                if not cacheEntry or (now - cacheEntry.time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = now }
                    cacheEntry = _G.AimTouchVisCache[tId]
                end
                if cacheEntry.hidden then skip = true end
            end

            if not skip then
                local fallbackZ = (boneIdx == 1) and 70 or (boneIdx == 2) and 40 or (boneIdx == 3) and 20 or 0
                local tPos = GetTargetBonePos(target, selBoneName, fallbackZ)
                if tPos and (tPos.X ~= 0 or tPos.Y ~= 0) then
                    local screen = FVector2D()
                    local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
                    if success and screen.X > 0 and screen.Y > 0 then
                        local dx = screen.X - centerX
                        local dy = screen.Y - centerY
                        local distScreen = math.sqrt(dx*dx + dy*dy)
                        if distScreen <= FOV_RADIUS then
                            if distScreen < bestScore then
                                bestScore = distScreen
                                bestTarget = target
                            end
                        end
                    end
                end
            end
        end
    end

    if not slua.isValid(bestTarget) then _G.GTLMODState.AimLastFail = "no best target in FOV"; return end

    local fallbackZ2 = (boneIdx == 1) and 70 or (boneIdx == 2) and 40 or (boneIdx == 3) and 20 or 0
    local finalBonePos = GetTargetBonePos(bestTarget, selBoneName, fallbackZ2)
    if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0) then _G.GTLMODState.AimLastFail = "no final bone pos"; return end

    local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
    if not rot then _G.GTLMODState.AimLastFail = "no rot"; return end

    local currentRot = pc:GetControlRotation()
    if not currentRot then _G.GTLMODState.AimLastFail = "no currentRot"; return end

    local deltaYaw = rot.Yaw - currentRot.Yaw
    local deltaPitch = rot.Pitch - currentRot.Pitch

    if isADS then
        local camRot = nil
        if type(camManager.GetCameraRotation) == "function" then camRot = camManager:GetCameraRotation() end
        if camRot then
            deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
            deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
        end
    end

    if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
    if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
    if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
    if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end

    local smoothFactor = (speedVal >= 100) and 1.0 or math.max(0.01, (speedVal / 100.0) * 0.35)

    local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
    local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
    local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }

    local okRot = pcall(function() pc:SetControlRotation(finalRot, "AimTouch") end)
    if not okRot then
        pcall(function() pc:SetControlRotation(finalRot) end)
    end

    _G.GTLMODState.AimLastFail = "OK"

    if isShotgun then
        pcall(function()
            local distToTarget = player:GetDistanceTo(bestTarget) / 100
            if distToTarget <= maxDistMeters then
                player.bIsWeaponFiring = true
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(true) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(true) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = true end
                local currentWep = player:GetCurrentWeapon()
                if slua.isValid(currentWep) and type(currentWep.StartFire) == "function" then currentWep:StartFire() end
                _G.GTLMODState.IsAutoFiring = true
            end
        end)
    end
end

-- =========================================================================
-- 11 — Main loop + aimbot loop + bypass refresh
-- =========================================================================
local function MainLoop()
    if isExpired then return end

    if _G.GTLMODState.CustomTextData == nil then
        _G.GTLMODState.CustomTextData = { OuterSpeed = 10, InnerSpeed = 10, HRecoil = 0.3, VRecoil = 0.3, IpadViewFOV = 120 }
    end

    local pc = GameplayData.GetPlayerController()
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end

    if not Valid(localPlayer) then
        if _G.GTLMODState.TrackedMarks then
            for markId, _ in pairs(_G.GTLMODState.TrackedMarks) do SafeRemoveMark(markId) end
        end
        _G.GTLMODState.TrackedMarks = {}
        for key, data in pairs(_G.GTLMODState.EnemyMarks) do
            if data and data.MIDs then
                for meshStr, midTable in pairs(data.MIDs) do
                    for k in pairs(midTable) do midTable[k] = nil end
                end
                data.MIDs = nil
            end
        end
        _G.GTLMODState.EnemyMarks = {}
        _G.GTLMODState.PrevGraphicsState = {}
        _G.BotStatusCache = {}
        _G.AimTouchVisCache = {}
        _G.GTLMODState.MidCacheCount = 0
        return
    end

    local Cached_MyHUD = pc and pc.MyHUD or nil

    if _G.GTLMODConfig.UnlockFPS then InitializeGraphicsUnlock() end
    InitializeNativeESP()

    -- PSYCO PATCH: force bat→character conversion every tick
    pcall(_G.ForceBatToCharacter)

    if _G.GTLMODConfig.IpadView and _G.GTLMODState.CustomTextData then
        pcall(function()
            local targetTPP = _G.GTLMODState.CustomTextData.IpadViewFOV or 120
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= targetTPP then uTPPCam.FieldOfView = targetTPP end
            end
        end)
    else
        pcall(function()
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= 80 then uTPPCam.FieldOfView = 80 end
            end
        end)
    end

    pcall(function()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)

    pcall(function()
        local autoComp = localPlayer.AutoAimComp
        if Valid(autoComp) then
            if not _G.GTLMODState.OrigAutoAimCompCached then
                _G.GTLMODState.OrigAutoAimCompCached = {
                    bOnlyHitHead = autoComp.bOnlyHitHead,
                    HeadBoneName = autoComp.HeadBoneName,
                    Bones = autoComp.Bones,
                    ChestBoneName = autoComp.ChestBoneName,
                    PelvisBoneName = autoComp.PelvisBoneName,
                    HeadPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.HeadPriority,
                    ChestPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.ChestPriority,
                    PelvisPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.PelvisPriority
                }
            end
            if _G.GTLMODConfig.AutoHead then
                autoComp.bOnlyHitHead = true
                autoComp.HeadBoneName = "Head"
                pcall(function() autoComp.Bones = {"Head"} end)
                autoComp.ChestBoneName = "Head"
                autoComp.PelvisBoneName = "Head"
                if autoComp.AimAssistConfig then
                    autoComp.AimAssistConfig.HeadPriority = 100
                    autoComp.AimAssistConfig.ChestPriority = 100
                    autoComp.AimAssistConfig.PelvisPriority = 100
                end
            else
                local orig = _G.GTLMODState.OrigAutoAimCompCached
                autoComp.bOnlyHitHead = orig.bOnlyHitHead
                autoComp.HeadBoneName = orig.HeadBoneName
                pcall(function() autoComp.Bones = orig.Bones or {"Spine_01", "Pelvis", "Head"} end)
                autoComp.ChestBoneName = orig.ChestBoneName
                autoComp.PelvisBoneName = orig.PelvisBoneName
                if autoComp.AimAssistConfig then
                    autoComp.AimAssistConfig.HeadPriority = orig.HeadPriority or 1
                    autoComp.AimAssistConfig.ChestPriority = orig.ChestPriority or 1
                    autoComp.AimAssistConfig.PelvisPriority = orig.PelvisPriority or 1
                end
            end
        end
    end)

    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            if _G.GTLMODConfig.RemoveGrass and not _G.GTLMODState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "0"); gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
                _G.GTLMODState.PrevGraphicsState.RemoveGrass = true
            elseif not _G.GTLMODConfig.RemoveGrass and _G.GTLMODState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "1"); gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
                _G.GTLMODState.PrevGraphicsState.RemoveGrass = false
            end
            if _G.GTLMODConfig.RemoveFog and not _G.GTLMODState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1"); gi:ExecuteCMD("r.Fog", "0"); gi:ExecuteCMD("r.VolumetricFog", "0")
                _G.GTLMODState.PrevGraphicsState.RemoveFog = true
            elseif not _G.GTLMODConfig.RemoveFog and _G.GTLMODState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1"); gi:ExecuteCMD("r.Fog", "1"); gi:ExecuteCMD("r.VolumetricFog", "1")
                _G.GTLMODState.PrevGraphicsState.RemoveFog = false
            end
            if _G.GTLMODConfig.ColorBodyV2 and not _G.GTLMODState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "4")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "200")
                gi:ExecuteCMD("r.CharacterDiffusePower", "200")
                _G.GTLMODState.PrevGraphicsState.ColorBodyV2 = true
            elseif not _G.GTLMODConfig.ColorBodyV2 and _G.GTLMODState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                _G.GTLMODState.PrevGraphicsState.ColorBodyV2 = false
            end
            if _G.GTLMODConfig.BlackSky and not _G.GTLMODState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
                _G.GTLMODState.PrevGraphicsState.BlackSky = true
            elseif not _G.GTLMODConfig.BlackSky and _G.GTLMODState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
                _G.GTLMODState.PrevGraphicsState.BlackSky = false
            end
        end
    end)

    pcall(function()
        local weapon = nil
        pcall(function()
            local weaponManager = localPlayer.WeaponManagerComponent
            if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then weapon = weaponManager:GetCurrentWeapon() end
        end)
        if not Valid(weapon) then
            if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon()
            elseif type(localPlayer.GetCurrentWeapon) == "function" then weapon = localPlayer:GetCurrentWeapon() end
        end
        if Valid(weapon) then
            local entities = {}
            if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE) end
            if Valid(weapon.ShootWeaponEntity) then table.insert(entities, weapon.ShootWeaponEntity) end
            if Valid(weapon.ShootWeaponComponent) and Valid(weapon.ShootWeaponComponent.ShootWeaponEntityComponent) then
                table.insert(entities, weapon.ShootWeaponComponent.ShootWeaponEntityComponent)
            end
            for _, entity in ipairs(entities) do
                local anyModOn = _G.GTLMODConfig.CustomHRecoil or _G.GTLMODConfig.CustomVRecoil or _G.GTLMODConfig.LessShake or _G.GTLMODConfig.Accuracy or _G.GTLMODConfig.Crosshair or _G.GTLMODConfig.GodMode
                if anyModOn then
                    if not entity.OriginalStatsCached then
                        entity.OriginalStatsCached = {
                            GameDeviationFactor = entity.GameDeviationFactor,
                            GameDeviationAccuracy = entity.GameDeviationAccuracy,
                            BulletFireSpeed = entity.BulletFireSpeed,
                            ShootInterval = entity.ShootInterval,
                            BaseDamage = entity.BaseDamage,
                            AccessoriesHRecoilFactor = entity.AccessoriesHRecoilFactor,
                            AccessoriesVRecoilFactor = entity.AccessoriesVRecoilFactor,
                            RecoilKick = entity.RecoilKick,
                            RecoilKickADS = entity.RecoilKickADS,
                            AnimationKick = entity.AnimationKick
                        }
                    end
                    if _G.GTLMODConfig.CustomHRecoil then entity.AccessoriesHRecoilFactor = _G.GTLMODState.CustomTextData.HRecoil or 0.3 end
                    if _G.GTLMODConfig.CustomVRecoil then entity.AccessoriesVRecoilFactor = _G.GTLMODState.CustomTextData.VRecoil or 0.3 end
                    if _G.GTLMODConfig.LessShake then entity.RecoilKickADS = 0.0 end
                    if _G.GTLMODConfig.Accuracy then entity.GameDeviationAccuracy = 0.0 end
                    if _G.GTLMODConfig.Crosshair then entity.GameDeviationFactor = 0.0 end
                    if _G.GTLMODConfig.GodMode then
                        entity.BulletFireSpeed = 500000.0
                        entity.ShootInterval = 0.001
                        entity.BaseDamage = 60000.0
                    end
                    entity.GTLMODWeaponModsActive = true
                elseif entity.GTLMODWeaponModsActive then
                    if entity.OriginalStatsCached then
                        local orig = entity.OriginalStatsCached
                        entity.GameDeviationFactor = orig.GameDeviationFactor
                        entity.GameDeviationAccuracy = orig.GameDeviationAccuracy
                        entity.BulletFireSpeed = orig.BulletFireSpeed
                        entity.ShootInterval = orig.ShootInterval
                        entity.BaseDamage = orig.BaseDamage
                        entity.AccessoriesHRecoilFactor = orig.AccessoriesHRecoilFactor
                        entity.AccessoriesVRecoilFactor = orig.AccessoriesVRecoilFactor
                        entity.RecoilKick = orig.RecoilKick
                        entity.RecoilKickADS = orig.RecoilKickADS
                        entity.AnimationKick = orig.AnimationKick
                    end
                    entity.GTLMODWeaponModsActive = false
                end
            end
        end
    end)

    pcall(function()
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then
            allCharacters = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then
            for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
        end

        local currentValidKeys = {}
        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer then
                currentValidKeys[GetSafeEnemyKey(enemy)] = true
            end
        end
        for key, data in pairs(_G.GTLMODState.EnemyMarks) do
            if not currentValidKeys[key] then
                SafeRemoveMark(data.radarMark)
                SafeRemoveMark(data.hpMark)
                SafeRemoveMark(data.distMark)
                SafeRemoveMark(data.hpMark8)
                if _G.AimTouchVisCache and _G.AimTouchVisCache[key] then _G.AimTouchVisCache[key] = nil end
                if _G.BotStatusCache and _G.BotStatusCache[key] then _G.BotStatusCache[key] = nil end
                if data.MIDs then
                    for meshStr, midTable in pairs(data.MIDs) do
                        for k in pairs(midTable) do midTable[k] = nil end
                    end
                    data.MIDs = nil
                end
                data.enemy = nil
                data.CachedMeshes = nil
                _G.GTLMODState.EnemyMarks[key] = nil
            end
        end

        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                local eKey = GetSafeEnemyKey(enemy)
                _G.GTLMODState.EnemyMarks[eKey] = _G.GTLMODState.EnemyMarks[eKey] or { enemy = enemy }
                local markData = _G.GTLMODState.EnemyMarks[eKey]
                markData.enemy = enemy

                local bIsReallyDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead
                    elseif enemy.bIsDeadFlag ~= nil then bIsReallyDead = enemy.bIsDeadFlag end
                    if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
                end)

                if not bIsReallyDead then
                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh end)
                    local aLoc = nil
                    pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                    local distM = 0
                    pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)

                    local MyHUD = Cached_MyHUD
                    if Valid(MyHUD) then
                        if _G.GTLMODConfig.EspAntenna and distM <= 400 then
                            pcall(function()
                                local loopCount = IS_32BIT and 4 or 8
                                local zStep = 1000
                                for i = 1, loopCount do
                                    local zOffset = 105 + (i * zStep)
                                    MyHUD:AddDebugText("|", enemy, 0.06, {X=0,Y=0,Z=zOffset}, {X=0,Y=0,Z=zOffset}, C_GREEN, true, false, true, nil, 1.2, true)
                                end
                            end)
                        end
                        if _G.GTLMODConfig.EspDistance and distM <= LIMITS.ESP_MAX_DISTANCE then
                            pcall(function()
                                MyHUD:AddDebugText(string.format("%.0fm", math.floor(distM+0.5)), enemy, 0.3, {X=15,Y=15,Z=-15}, {X=15,Y=15,Z=-15}, C_WHITE, true, false, true, nil, 0.9, true)
                            end)
                        end
                        if _G.GTLMODConfig.EspName and distM <= LIMITS.ESP_MAX_DISTANCE then
                            pcall(function()
                                local pName = enemy.PlayerName or "Enemy"
                                local isKnock = (enemy.Health or 100) <= 0 or enemy.HealthStatus == 1
                                local bVis = true
                                pcall(function() if pc and type(pc.LineOfSightTo) == "function" then bVis = pc:LineOfSightTo(enemy) end end)
                                local color = isKnock and C_BLUE or (bVis and C_GREEN or C_RED)
                                MyHUD:AddDebugText(pName, enemy, 0.2, {X=0,Y=0,Z=120}, {X=0,Y=0,Z=120}, color, true, false, true, nil, 1.0, true)
                            end)
                        end
                    end

                    if _G.GTLMODConfig.EspVip then
                        if markData.hpMark == nil then markData.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                        if markData.distMark == nil then markData.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                    end
                    if _G.GTLMODConfig.EspRadar then
                        if not markData.radarMark or markData.radarMark == 0 then
                            markData.radarMark = SafeAddMark(8888, FVector(0,0,0), 0, "", 4, enemy)
                        end
                    else
                        if markData.radarMark and markData.radarMark ~= 0 then
                            SafeRemoveMark(markData.radarMark); markData.radarMark = nil
                        end
                    end
                end
            end
        end
    end)

    if _G.GTLMODConfig.AimDebug and Valid(Cached_MyHUD) then
        pcall(function()
            local status = _G.GTLMODState.AimLastFail or "?"
            local enemies = _G.GetEnemyTargetsFromActors(25000)
            local cnt = enemies and #enemies or 0
            local txt = string.format("[AIM] %s | Enemies: %d", status, cnt)
            Cached_MyHUD:AddDebugText(txt, localPlayer, 0.1, {X=0,Y=0,Z=200}, {X=0,Y=0,Z=200}, C_YELLOW, true, false, true, nil, 1.0, true)
        end)
    end
end

-- =========================================================================
-- 12 — Bat→Character force (PSYCO PATCH)
-- =========================================================================
-- PSYCO NOTE: The bat form (SpecialSuit) never converted back because nothing
-- called DoModChangeToBT. This block forces the conversion:
--   1. Detects bat/suit state on the local character.
--   2. Fires TriggerEntrySkillWithID(4301101) to transform.
--   3. Falls back to RemoveState(SpecialSuit) + SwitchPoseState(Stand).
--   4. Timestamps entry so the unstick watchdog can force-clear if it hangs.

function _G.ForceBatToCharacter()
    pcall(function()
        if isExpired then return end

        local me = GameplayData.GetPlayerCharacter()
        if not slua.isValid(me) then return end

        local isBat = false
        pcall(function()
            if me.HasState and type(me.HasState) == "function" then
                isBat = me:HasState(EPawnState.SpecialSuit)
            end
            if not isBat and me.PawnState ~= nil then
                isBat = (me.PawnState == EPawnState.SpecialSuit)
            end
            if not isBat and me.bIsBatForm ~= nil then
                isBat = me.bIsBatForm == true
            end
        end)

        if not isBat then
            _G.GTLMODState.BatStateEnteredAt = 0
            return
        end

        -- timestamp first entry
        if (_G.GTLMODState.BatStateEnteredAt or 0) == 0 then
            _G.GTLMODState.BatStateEnteredAt = os.time()
        end

        -- primary path: entry skill
        local ok = pcall(function()
            if me.TriggerEntrySkillWithID then
                me:TriggerEntrySkillWithID(4301101, true)
            end
        end)

        -- fallback: pose reset + state clear
        if not ok then
            pcall(function()
                local ESTEPoseState = import("ESTEPoseState")
                if me.SwitchPoseState then
                    me:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
                end
                if me.RemoveState and EPawnState.SpecialSuit then
                    me:RemoveState(EPawnState.SpecialSuit)
                end
            end)
        end
    end)
end

-- =========================================================================
-- 13 — Character unstick watchdog (PSYCO PATCH)
-- =========================================================================
function _G.UnstickCharacter()
    pcall(function()
        if isExpired then return end

        local me = GameplayData.GetPlayerCharacter()
        if not slua.isValid(me) then return end

        local now = os.time()
        if now - (_G.GTLMODState.LastUnstickAt or 0) < 3 then return end

        local frozen = false
        local reason = ""

        -- condition A: stuck in SpecialSuit > 10s
        if (_G.GTLMODState.BatStateEnteredAt or 0) > 0 then
            if now - _G.GTLMODState.BatStateEnteredAt > 10 then
                frozen = true
                reason = "SpecialSuit timeout"
            end
        end

        -- condition B: AttachToOther > 10s
        pcall(function()
            if not frozen and me.HasState and type(me.HasState) == "function" then
                if me:HasState(EPawnState.AttachToOther) then
                    if (_G.GTLMODState.AttachStateEnteredAt or 0) == 0 then
                        _G.GTLMODState.AttachStateEnteredAt = now
                    elseif now - _G.GTLMODState.AttachStateEnteredAt > 10 then
                        frozen = true
                        reason = "AttachToOther timeout"
                    end
                else
                    _G.GTLMODState.AttachStateEnteredAt = 0
                end
            end
        end)

        -- condition C: no movement mode, alive, not in any valid state
        pcall(function()
            if not frozen and slua.isValid(me.STCharacterMovement) then
                local mm = me.STCharacterMovement.MovementMode
                if mm == nil then
                    frozen = true
                    reason = "nil movement mode"
                end
            end
        end)

        if not frozen then return end

        _G.GTLMODState.LastUnstickAt = now

        pcall(function()
            local ESTEPoseState = import("ESTEPoseState")
            if me.SwitchPoseState then
                me:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
            end
            if me.RemoveState then
                if EPawnState.SpecialSuit then me:RemoveState(EPawnState.SpecialSuit) end
                if EPawnState.AttachToOther then me:RemoveState(EPawnState.AttachToOther) end
            end
            if slua.isValid(me.STCharacterMovement) and me.STCharacterMovement.SetMovementMode then
                local EMovementMode = import("EMovementMode")
                if EMovementMode and EMovementMode.MOVE_Walking then
                    me.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_Walking, 0)
                end
            end
        end)

        _G.GTLMODState.BatStateEnteredAt = 0
        _G.GTLMODState.AttachStateEnteredAt = 0

        pcall(function()
            local sh = safeImport("ScriptHelperClient")
            if sh and sh.AddOnScreenDebugMessage then
                sh.AddOnScreenDebugMessage("[PSYCO] Unstick: " .. reason, -1, 3.0, {R=1,G=1,B=0,A=1}, {X=1.2, Y=1.2})
            end
        end)
    end)
end

-- =========================================================================
-- Loops
-- =========================================================================
_G.GTLMODState.LoopToken = (_G.GTLMODState.LoopToken or 0) + 1
local myToken = _G.GTLMODState.LoopToken

local function MainTick()
    if isExpired then
        if not _G.GTLMODNotifiedExpire then
            Notify("MOD HAS EXPIRED!")
            _G.GTLMODNotifiedExpire = true
        end
        return
    end
    if myToken ~= _G.GTLMODState.LoopToken then return end
    pcall(MainLoop)
    pcall(_G.UnstickCharacter)
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(LIMITS.MAIN_TICK, MainTick)
    end
end

local function AimbotTick()
    if isExpired then return end
    if myToken ~= _G.GTLMODState.LoopToken then return end
    if _G.GTLMODConfig.AimTouchEnable then
        pcall(_G.AimTouch)
    end
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(LIMITS.AIMBOT_TICK, AimbotTick)
    end
end

-- PSYCO PATCH: refresh only the report layer, NOT the subsystem sweep.
-- Re-running InitializeScannerBlocker every 5s caused the character wedge.
local function BypassRefreshLoop()
    if isExpired then return end
    if myToken ~= _G.GTLMODState.LoopToken then return end
    pcall(InitializeCoreBypass)
    pcall(InitializeLogBlocker)
    pcall(InitializeReportBlocker)
    pcall(InitializeGameplayBypass)
    pcall(AggressiveReset)
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(5.0, BypassRefreshLoop)
    end
end

if not isExpired then
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.2, MainTick)
        ticker.AddTimerOnce(0.2, AimbotTick)
        ticker.AddTimerOnce(5.0, BypassRefreshLoop)
    end
    Notify("PSYCO MOD v3501 loaded | " .. gameRegion .. " (" .. packageName .. ")")
else
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.2, MainTick)
    end
end

-- =========================================================================
-- 14 — Auto-head hooks
-- =========================================================================
_G.InitializeAutoHeadHooks = function()
    pcall(function()
        local EAvatarDamagePosition = safeImport("EAvatarDamagePosition")
        if not EAvatarDamagePosition then return end
        for _, path in ipairs({"GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity", "GameLua.Logic.Weapon.ShootWeaponEntity"}) do
            local hitLogic = package.loaded[path]
            if hitLogic then
                local orig1 = hitLogic.GetHitBodyType
                hitLogic.GetHitBodyType = function(self, ImpactResult, InImpactVec)
                    if _G.GTLMODConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if orig1 then return orig1(self, ImpactResult, InImpactVec) end
                end
                local orig2 = hitLogic.GetHitBodyTypeByHitPos
                hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                    if _G.GTLMODConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if orig2 then return orig2(self, InImpactVec) end
                end
            end
        end
    end)
end
pcall(_G.InitializeAutoHeadHooks)

-- =========================================================================
-- 15 — Welcome menu
-- =========================================================================
local function ShowGTLMODVIPMenu()
    if _G.GTLMODMenuAlreadyShown then return end
    if _G.GTLMODState.MenuStep ~= 0 then return end
    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end
        local function Step_Final()
            Msg.Show(1, "PSYCO 5.0 PAK", "PLAY SAFE AVOID REPORT",
                function() end, function() end, "OK", "CLOSE")
            _G.GTLMODState.MenuStep = 99
            _G.GTLMODMenuAlreadyShown = true
        end
        local function Step_Welcome()
            Msg.Show(1, "5.0 PSYCO MOD", "PSYCO MOD LOADED",
                function()
                    _G.InitModMenuTab()
                    Notify("VIP MOD MENU BY PSYCO")
                    Step_Final()
                end, function() end, "OK", "CLOSE")
        end
        _G.GTLMODState.MenuStep = 1
        Step_Welcome()
    end)
end

local function MenuTrigger()
    if isExpired then return end
    if _G.GTLMODState.MenuStep == 0 then
        pcall(ShowGTLMODVIPMenu)
    end
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce and not _G.GTLMODState.MenuShown then
        if _G.GTLMODState.MenuStep ~= 0 then _G.GTLMODState.MenuShown = true; return end
        ticker.AddTimerOnce(2.0, MenuTrigger)
    end
end
if not isExpired then
    pcall(function()
        require("common.time_ticker").AddTimerOnce(1.5, MenuTrigger)
    end)
end

-- =========================================================================
-- 16 — Init all
-- =========================================================================
local function InitAllModSystems()
    if isExpired then return end
    pcall(function()
        if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end
        if _G.InitializeAutoHeadHooks then _G.InitializeAutoHeadHooks() end
        if _G.InitModMenuTab then _G.InitModMenuTab() end
        if _G.ESP and _G.GTLMODConfig.EspLine then _G.ESP.Start() end
        if _G.GTLMODConfig.WallhackSmart and _G.StartNewWallhack then _G.StartNewWallhack() end
    end)
end
if not isExpired then
    pcall(function()
        require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems)
    end)
end

-- =========================================================================
-- Public ESP API
-- =========================================================================
function BRPlayerCharacterBase:ESP_Start()
    if _G.ESP then _G.ESP.Start() end
end

function BRPlayerCharacterBase:ESP_Stop()
    if _G.ESP then _G.ESP.Stop() end
end

function BRPlayerCharacterBase:ESP_Toggle()
    if _G.ESP then
        if _G.ESP.bActive then _G.ESP.Stop() else _G.ESP.Start() end
        return _G.ESP.bActive
    end
    return false
end

function BRPlayerCharacterBase:ESP_IsEnabled()
    return _G.GTLMODConfig.EspLine or false
end

function BRPlayerCharacterBase:ESP_IsRunning()
    return _G.ESP and _G.ESP.bActive or false
end

-- =========================================================================
-- 17 — Class methods (BRPlayerCharacterBase)
-- =========================================================================
function BRPlayerCharacterBase:ctor() end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = safeImport("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then self.STCharacterMovement.bPositiveBlowUp = true end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", { AttrName = { "bCanSelfRescue" } }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    GameplayData.AddCharacter(self.Object)
    self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
    self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, { [1] = "FinishedState" }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(uVehicle) if slua.isValid(uVehicle) then self:ClearAttachToVehicleTimer() end end
function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle) if slua.isValid(uLastVehicle) then self:ClearAttachToVehicleTimer() end end
function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle() end
function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded() end
function BRPlayerCharacterBase:ClearAttachToVehicleTimer()
  if self.nUpdatePlayerAttachToVehicleTimer then
    self:RemoveGameTimer(self.nUpdatePlayerAttachToVehicleTimer)
    self.nUpdatePlayerAttachToVehicleTimer = nil  end
  if self.nFixMeshContainerTimer then
    self:RemoveGameTimer(self.nFixMeshContainerTimer)
    self.nFixMeshContainerTimer = nil
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then return end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local pc = self:GetPlayerControllerSafety()
    if slua.isValid(pc) then pc:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "") end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  local EPS = import("EPawnState")
  if PawnState == EPS.SwitchPP then
    local pc = self:GetPlayerControllerSafety()
    if slua.isValid(pc) then pc:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "") end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
    self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent() return false end
function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
end
function BRPlayerCharacterBase:OnLanded()
  if self.HandleOnLanded then self:HandleOnLanded(-1) end
end
function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then GameplayData.RemoveCharacter(self.Object) end
end
function BRPlayerCharacterBase:IsWarGameMode() return false end
function BRPlayerCharacterBase:BPOnRecycled() if Client then self:ResetMeshRelativeLocationAndRotation() end end
function BRPlayerCharacterBase:BPOnRespawned() if Client then self:ResetMeshRelativeLocationAndRotation() end end
function BRPlayerCharacterBase:ReceiveOnRecycle() if Client then self:ResetMeshRelativeLocationAndRotation(); GameplayData.RemoveCharacter(self.Object) end end
function BRPlayerCharacterBase:ReceiveOnSpawn() if Client then self:ResetMeshRelativeLocationAndRotation(); GameplayData.AddCharacter(self.Object) end end
function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local rot = FRotator(0, -90, 0)
    if self.Mesh.K2_SetRelativeRotation then self.Mesh:K2_SetRelativeRotation(rot, false, nil, false) end
    self:CacheInitialMeshOffset(FVector(0, 0, 0), rot)
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  local EMovementMode = import("EMovementMode")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    self.CharacterMovement:SetBase(nil, "", true)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord() end
function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end
function BRPlayerCharacterBase:ParachuteJump()
  local pc = self:GetControllerSafety()
  if slua.isValid(pc) and not self:GetEnsure() then
    local EStateType = import("EStateType")
    if pc:GetCurrentStateType() ~= EStateType.State_ParachuteJump and pc:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
      local EPS = import("ESTEPoseState")
      self:SwitchPoseState(EPS.Stand, true, true, true, false)
      pc:ReInitParachuteItem()
      pc:ServerChangeStatePC(EStateType.State_ParachuteJump)
    end
  end
end
function BRPlayerCharacterBase:CheckForbidFlaregun()
  local ps = self:GetPlayerStateSafety()
  if not slua.isValid(ps) then return false end
  return not ps.CanUseFlaregun
end
function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue() self:HandleNearDeathGiveupRescue() end
function BRPlayerCharacterBase:HandleNearDeathGiveupRescue() end
function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId) end
function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId) end
function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(b) if slua.isValid(self.ParachuteComponent) then self.ParachuteComponent.bServerSyncShouldCheckPassWall = b end end
function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState() self.Super:OnPlayerEnterCarryBoxState(); if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end end
function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(b) self.Super:OnPlayerLeaveCarryBoxState(b); if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(b) end end
function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(u)
  if slua.isValid(u) and Game:IsClassOf(u, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(u)
  end
end
function BRPlayerCharacterBase:SetAreaID(a) self:SetAttrValue("AreaID", a, -1) end
function BRPlayerCharacterBase:GetAreaID() return math.floor(self:GetAttrValue("AreaID") + 0.5) end
function BRPlayerCharacterBase:CannotChangeIntoPetSpectator() return self.bCannotChangeIntoPetSpectator end
function BRPlayerCharacterBase:DoModChangeToBT() if self:HasState(EPawnState.SpecialSuit) then self:TriggerEntrySkillWithID(4301101, true) end end
function BRPlayerCharacterBase:SwitchCameraToParachuteOpening() self.Super:SwitchCameraToParachuteOpening() end
function BRPlayerCharacterBase:SwitchCameraToParachuteFalling() self.Super:SwitchCameraToParachuteFalling() end
function BRPlayerCharacterBase:SwitchCameraToNormal() self.Super:SwitchCameraToNormal() end
function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState) return self.Super:SwitchWeaponCheck(Slot, IgnoreState) end

-- =========================================================================
-- 18 — Return / DeclareFeature
-- =========================================================================
local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)

return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
  { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
  { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
  { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
  { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
  { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
  { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
  { BuildAircraftVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
  { UnifiedBuildVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.UnifiedBuildVehicleFeature" },
  { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
  { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" },
  { ParachuteSprint = "GameLua.Mod.BaseMod.GamePlay.Feature.Parachute.ParachuteSprintFeature" },
  { GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature" },
  { FPPAnimMonitor = "GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature" }
}, "BRPlayerCharacterBase")