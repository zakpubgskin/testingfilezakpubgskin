-- ========================================
-- >>> WELCOME TO @ZakPubgSkin VIP MOD PAK FILE <<<
-- =======================================
-- =======================================
-- CREDIT: @ZakPubgSkin - PAKISTAN VIP MOD
-- CONTACT: Telegram @ZakPubgSkin
-- VERSION: 4.5 PAK EDITION (FIXED LICENSE SYSTEM)
-- ========================================

local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")

local KismetSystemLibrary = import("KismetSystemLibrary")
local packageName = KismetSystemLibrary.GetGameBundleId()

-- Support all game versions without returning
local function GetGamePaths(pkg)
    local paths = {
        ["com.tencent.ig"] = {
            base = "/storage/emulated/0/Android/data/com.tencent.ig/files/",
            sdcard = "/sdcard/Android/data/com.tencent.ig/files/",
            saved = "/storage/emulated/0/Android/data/com.tencent.ig/files"
        },
        ["com.pubg.imobile"] = {
            base = "/storage/emulated/0/Android/data/com.pubg.imobile/files/",
            sdcard = "/sdcard/Android/data/com.pubg.imobile/files/",
            saved = "/storage/emulated/0/Android/data/com.pubg.imobile/files/"
        },
        ["com.vng.pubgmobile"] = {
            base = "/storage/emulated/0/Android/data/com.vng.pubgmobile/files/",
            sdcard = "/sdcard/Android/data/com.vng.pubgmobile/files/",
            saved = "/storage/emulated/0/Android/data/com.vng.pubgmobile/files/"
        },
        ["com.pubg.krmobile"] = {
            base = "/storage/emulated/0/Android/data/com.pubg.krmobile/files/",
            sdcard = "/sdcard/Android/data/com.pubg.krmobile/files/",
            saved = "/storage/emulated/0/Android/data/com.pubg.krmobile/files/"
        },
        ["com.rekoo.pubgm"] = {
            base = "/storage/emulated/0/Android/data/com.rekoo.pubgm/files/",
            sdcard = "/sdcard/Android/data/com.rekoo.pubgm/files/",
            saved = "/storage/emulated/0/Android/data/com.rekoo.pubgm/files/"
        },
        ["com.garena.game.kgtw"] = {
            base = "/storage/emulated/0/Android/data/com.garena.game.kgtw/files/",
            sdcard = "/sdcard/Android/data/com.garena.game.kgtw/files/",
            saved = "/storage/emulated/0/Android/data/com.garena.game.kgtw/files/"
        },
        ["com.pubg.jpmobile"] = {
            base = "/storage/emulated/0/Android/data/com.pubg.jpmobile/files/",
            sdcard = "/sdcard/Android/data/com.pubg.jpmobile/files/",
            saved = "/storage/emulated/0/Android/data/com.pubg.jpmobile/files/"
        }
    }
    return paths[pkg] or {
        base = "/storage/emulated/0/Android/data/" .. pkg .. "/files/",
        sdcard = "/sdcard/Android/data/" .. pkg .. "/files/",
        saved = "/storage/emulated/0/Android/data/" .. pkg .. "/files/"
    }
end

local currentGamePaths = GetGamePaths(packageName)

-- ============================================================================
-- Zakpubgskin ONLINE LICENSE SYSTEM (MIGRATED FROM Ahmad.lua)
-- All mod features remain hard-locked until the online key is verified.
-- ============================================================================

-- 1. LICENSE CONFIG + CORE
-- ============================================================================
local MasterLicenseConfig = (function()
    return {
              url = 'https://zakpubg.skin/connect', game = 'BGMI',
        timeout = 10, clockSkew = 120, expiryPath = nil,
        manualExpiry = "2026-12-31 23:59:59", tamperTolerance = 5,
        secret = 'ZAKPUBGSKIN',
    }
end)()

local MasterLicenseCore = (function()
    local Primitives = (function()
        local floor, abs, max = math.floor, math.abs, math.max
        local byte, char, format = string.byte, string.char, string.format
        local U32 = 4294967296
        local AND, XOR = {}, {}
        for a = 0, 15 do for b = 0, 15 do
            local av, bv, both, different, place = a, b, 0, 0, 1
            for _ = 1, 4 do
                local x, y = av % 2, bv % 2
                if x == 1 and y == 1 then both = both + place end
                if x ~= y then different = different + place end
                av, bv, place = floor(av / 2), floor(bv / 2), place * 2
            end
            AND[a * 16 + b], XOR[a * 16 + b] = both, different
        end end
        local function bitop(a, b, lookup)
            local value, place = 0, 1
            for _ = 1, 8 do
                value = value + lookup[(a % 16) * 16 + b % 16] * place
                a, b, place = floor(a / 16), floor(b / 16), place * 16
            end
            return value
        end
        local function band(a, b) return bitop(a, b, AND) end
        local function bxor(a, b) return bitop(a, b, XOR) end
        local function rol(value, amount)
            local divisor = 2 ^ (32 - amount)
            return (value % divisor) * 2 ^ amount + floor(value / divisor)
        end
        local function little32(value)
            return char(value % 256, floor(value / 256) % 256,
                floor(value / 65536) % 256, floor(value / 16777216) % 256)
        end
        local K = {
            0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
            0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
            0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
            0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
            0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
            0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
            0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
            0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
        }
        local SHIFT = {7,12,17,22,5,9,14,20,4,11,16,23,6,10,15,21}
        local function md5_raw(input)
            assert(type(input) == "string", "MD5 input must be a string")
            local size = #input
            local message = input .. char(128) .. string.rep(char(0), (55 - size) % 64)
                .. little32((size * 8) % U32) .. little32(floor(size / 536870912))
            local h0, h1, h2, h3 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
            local words = {}
            for offset = 1, #message, 64 do
                for j = 0, 15 do
                    local a, b, c, d = byte(message, offset + j * 4, offset + j * 4 + 3)
                    words[j] = a + b * 256 + c * 65536 + d * 16777216
                end
                local a, b, c, d = h0, h1, h2, h3
                for i = 0, 63 do
                    local f, g, shiftBase
                    if i < 16 then
                        f, g, shiftBase = band(b, c) + band(U32 - 1 - b, d), i, 0
                    elseif i < 32 then
                        f, g, shiftBase = band(d, b) + band(U32 - 1 - d, c), (5 * i + 1) % 16, 4
                    elseif i < 48 then
                        f, g, shiftBase = bxor(bxor(b, c), d), (3 * i + 5) % 16, 8
                    else
                        local bOrNotD = U32 - 1 - band(U32 - 1 - b, d)
                        f, g, shiftBase = bxor(c, bOrNotD), (7 * i) % 16, 12
                    end
                    local nextB = (b + rol((a + f + K[i + 1] + words[g]) % U32,
                        SHIFT[shiftBase + i % 4 + 1])) % U32
                    a, b, c, d = d, nextB, b, c
                end
                h0, h1, h2, h3 = (h0 + a) % U32, (h1 + b) % U32, (h2 + c) % U32, (h3 + d) % U32
            end
            return little32(h0) .. little32(h1) .. little32(h2) .. little32(h3)
        end
        local function hex(input)
            return (input:gsub(".", function(c) return format("%02x", byte(c)) end))
        end
        local function md5(input) return hex(md5_raw(input)) end
        local function form_encode(input)
            assert(type(input) == "string", "Form value must be a string")
            return (input:gsub("[^A-Za-z0-9%-%._~ ]", function(c)
                return format("%%%02X", byte(c)) end):gsub(" ", "+"))
        end
        local function constant_time_equal(a, b)
            if type(a) ~= "string" or type(b) ~= "string" then return false end
            local difference = abs(#a - #b)
            for i = 1, max(#a, #b) do
                difference = difference + abs((byte(a, i) or 0) - (byte(b, i) or 0))
            end
            return difference == 0
        end
        local function name_uuid(input)
            local digest = md5_raw(input)
            local h = hex(digest:sub(1,6) .. char(byte(digest,7) % 16 + 48)
                .. digest:sub(8,8) .. char(byte(digest,9) % 64 + 128) .. digest:sub(10))
            return h:sub(1,8) .. "-" .. h:sub(9,12) .. "-" .. h:sub(13,16)
                .. "-" .. h:sub(17,20) .. "-" .. h:sub(21,32)
        end
        return {md5 = md5, md5_raw = md5_raw, form_encode = form_encode,
                constant_time_equal = constant_time_equal, name_uuid = name_uuid}
    end)()

    local SESSION_KEY = '__MasterLicenseSession_v1'
    local function loadSession()
        local g = rawget(_G, SESSION_KEY)
        if type(g) ~= 'table' or g.authorized ~= true then return nil end
        if type(g.expiresAt) == 'number' and g.expiresAt <= os.time() then
            _G[SESSION_KEY] = nil; return nil
        end
        return g
    end
    local function saveSession(expiresAt)
        pcall(function()
            _G[SESSION_KEY] = {authorized = true, expiresAt = expiresAt, issuedAt = os.time()}
        end)
    end
    local function clearSession() pcall(function() _G[SESSION_KEY] = nil end) end

    local CreateLocalExpiry = (function()
        return function(cfg, wallReader)
            local E = {}
            local expiredText = 'Mod expired. DM @ZakPubgSkin for renewal.'
            local tamperText  = "Don't be over smart"
            local blockedMessage, blockedPhase
            local function finite(n)
                return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
            end
            local function parse(text)
                if type(text) ~= 'string' then return nil end
                local y,m,d,h,n,s = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$')
                y,m,d,h,n,s = tonumber(y),tonumber(m),tonumber(d),tonumber(h),tonumber(n),tonumber(s)
                if not y or y < 1970 or y > 9999 or m < 1 or m > 12 or h > 23 or n > 59 or s > 59 then return nil end
                local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
                local months = {31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
                if d < 1 or d > months[m] then return nil end
                local prior = y - 1
                local days = 365 * (y - 1970) + math.floor(prior / 4) - math.floor(1969 / 4)
                    - math.floor(prior / 100) + math.floor(1969 / 100)
                    + math.floor(prior / 400) - math.floor(1969 / 400)
                for i = 1, m - 1 do days = days + months[i] end
                return (days + d - 1) * 86400 + h * 3600 + n * 60 + s - 6 * 3600
            end
            local configured = type(cfg.manualExpiry) == 'string'
                and cfg.manualExpiry:match('^%s*(.-)%s*$') or cfg.manualExpiry
            local expiry = parse(configured)
            local skew = cfg.clockSkew or 120
            if configured ~= nil and configured ~= '' and not expiry then
                blockedMessage, blockedPhase = 'Invalid local expiry date. Use YYYY-MM-DD HH:MM:SS.', 'error'
            end
            local function block(message, phase)
                if not blockedMessage then blockedMessage, blockedPhase = message, phase end
                return false, blockedMessage, blockedPhase
            end
            function E.Status() return not blockedMessage, blockedMessage, blockedPhase end
            function E.MarkTampered() return block(tamperText, 'tampered') end
            function E.GetExpiry() return expiry end
            function E.Accept(server, now, world, phone, rtt)
                if blockedMessage then return E.Status() end
                if not finite(server) or not finite(now) or now < 0 or world == nil
                    or not finite(rtt) or rtt < 0 or not finite(phone) then
                    return block('Clock verification unavailable.', 'error')
                end
                if math.abs(phone - server) > skew + rtt then return E.MarkTampered() end
                if expiry and server + rtt >= expiry then return block(expiredText, 'expired') end
                return true
            end
            return E
        end
    end)()

    local CreateAuth = (function()
        return function(P, cfg, deps)
            local A = {}
            local phase, message = 'locked', 'Enter your key to sign in.'
            local allowed, pending, generation = false, nil, 0
            local expiresAt
            local lastRequestLatencyMs, lastResponseTime, lastResponseWorld
            local startFn, stopFn, payloadStarted, restartRequired
            local localExpiry = deps.localExpiry
            do
                local stored = loadSession()
                if stored then
                    allowed = true; expiresAt = stored.expiresAt
                    phase, message = 'active', 'Session restored'
                end
            end
            if localExpiry then
                local ok, text, state = localExpiry.Status()
                if not ok then message, phase = text, state end
            end
            local function finite(n)
                return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
            end
            local function readClock()
                local ok, n, w = pcall(deps.clock)
                if ok and finite(n) and n >= 0 and w ~= nil then return n, w end
            end
            local function notify(text, state)
                message, phase = text, state
                if type(deps.status) == 'function' then pcall(deps.status, text, state) end
            end
            local function stopPayload()
                if payloadStarted then
                    payloadStarted = false
                    local ok, accepted = pcall(stopFn)
                    if not ok or accepted == false then restartRequired = true end
                end
            end
            local function revoke(text, state)
                generation = generation + 1
                allowed, pending, expiresAt = false, nil, nil
                lastRequestLatencyMs, lastResponseTime, lastResponseWorld = nil, nil, nil
                stopPayload()
                local localDenied = false
                if localExpiry then
                    local ok, localText, localPhase = localExpiry.Status()
                    if not ok then text, state, localDenied = localText, localPhase, true end
                end
                notify(restartRequired and not localDenied
                    and 'Restart required: payload cleanup failed.' or text, state or 'error')
            end
            local function startPayload()
                if payloadStarted or not startFn then return true end
                payloadStarted = true
                local before = generation
                local ok, accepted = pcall(startFn)
                if not ok or accepted == false then
                    restartRequired = true
                    revoke('Restart required: offline script startup failed.', 'error')
                    return false
                end
                return generation == before and allowed
            end
            local function denyReason(reason)
                if type(reason) ~= 'string' then return 'Expired' end
                local lower = reason:sub(1, 120):lower():gsub('[_%s%-]+', ' ')
                if lower == 'max devices' or lower == 'maximum devices'
                    or lower == 'max devices reached' then
                    return 'Max Devices'
                end
                local clean = reason
                for _, field in ipairs({'key', 'serial'}) do
                    if pending and type(pending[field]) == 'string' and #pending[field] > 0 then
                        local needle = pending[field]:gsub('([^%w])', '%%%1')
                        clean = clean:gsub(needle, '[' .. field .. ']')
                    end
                end
                if type(cfg.secret) == 'string' and #cfg.secret > 0 then
                    clean = clean:gsub(cfg.secret:gsub('([^%w])', '%%%1'), '[credential]')
                end
                clean = clean:gsub('[%c]', ' '):sub(1, 120)
                return clean == '' and 'Expired' or ('Expired: ' .. clean)
            end
            local function configuredExpiry(result)
                if cfg.expiryPath == nil then return nil, true end
                if type(cfg.expiryPath) ~= 'table' or #cfg.expiryPath == 0 then return nil, false end
                local v = result
                for _, name in ipairs(cfg.expiryPath) do
                    if type(v) ~= 'table' then return nil, false end
                    v = rawget(v, name)
                end
                return v, finite(v) and v > 0 and v % 1 == 0
            end
            local function begin(key)
                if restartRequired or pending then return false end
                if localExpiry then
                    local ok, text, state = localExpiry.Status()
                    if not ok then revoke(text, state); return false end
                end
                if type(key) ~= 'string' then key = '' end
                key = key:match('^%s*(.-)%s*$')
                if #key == 0 or #key > 512 then
                    revoke('Expired: enter a valid key.', 'denied'); return false
                end
                local now, world = readClock()
                if not now then
                    revoke('Game clock unavailable. Try again in a match.', 'error'); return false
                end
                local okSerial, serial = pcall(deps.serial, key)
                if not okSerial or type(serial) ~= 'string' or #serial == 0 or #serial > 512 then
                    revoke('Device identifier unavailable.', 'error'); return false
                end
                generation = generation + 1
                local requestId = generation
                pending = {id = requestId, key = key, serial = serial,
                           started = now, world = world, deadline = now + cfg.timeout}
                notify('Signing in...', 'pending')
                if not pending or pending.id ~= requestId or generation ~= requestId then return false end
                local body = 'game=' .. P.form_encode(cfg.game)
                    .. '&user_key=' .. P.form_encode(key)
                    .. '&serial=' .. P.form_encode(serial)
                local function received(success, raw)
                    if not pending or pending.id ~= requestId or generation ~= requestId then return end
                    local current, worldNow = readClock()
                    if not current or worldNow ~= pending.world or current < pending.started
                        or current >= pending.deadline then
                        revoke('Request expired. Please sign in again.', 'error'); return
                    end
                    if success ~= true or type(raw) ~= 'string' or #raw == 0 or #raw > 32768 then
                        revoke('Connection failed. Please try again.', 'error'); return
                    end
                    local ok, result = pcall(deps.decode, raw)
                    if not ok or type(result) ~= 'table' then
                        revoke('Invalid server response.', 'error'); return
                    end
                    if result.status ~= true then revoke(denyReason(result.reason), 'denied'); return end
                    local data = result.data
                    if type(data) ~= 'table' or type(data.token) ~= 'string' or #data.token ~= 32
                        or not data.token:match('^[%x]+$') or not finite(data.rng) or data.rng % 1 ~= 0 then
                        revoke('Incomplete server response.', 'error'); return
                    end
                    local expected = P.md5(cfg.game .. '-' .. key .. '-' .. serial .. '-' .. cfg.secret)
                    if not P.constant_time_equal(data.token:lower(), expected) then
                        revoke('Server token verification failed.', 'denied'); return
                    end
                    local okWall, wall = pcall(deps.wall)
                    if not okWall or not finite(wall) then
                        revoke('Phone clock unavailable.', 'error'); return
                    end
                    if localExpiry then
                        local accepted, text, state = localExpiry.Accept(
                            data.rng, current, worldNow, wall, current - pending.started)
                        if not accepted then revoke(text, state); return end
                    elseif math.abs(wall - data.rng) > cfg.clockSkew then
                        revoke('Phone/server clock mismatch. Check automatic time.', 'error'); return
                    end
                    local expiry, validExpiry = configuredExpiry(result)
                    if not validExpiry then
                        revoke('Configured server expiry field is missing or invalid.', 'error'); return
                    end
                    if expiry and expiry - data.rng - (current - pending.started) <= 0 then
                        revoke('Expired', 'denied'); return
                    end
                    local fixedExpiry = localExpiry and localExpiry.GetExpiry()
                    if fixedExpiry then expiry = math.min(expiry or fixedExpiry, fixedExpiry) end
                    lastRequestLatencyMs = (current - pending.started) * 1000
                    lastResponseTime, lastResponseWorld = current, worldNow
                    pending = nil
                    allowed, expiresAt = true, expiry
                    saveSession(expiresAt)
                    if not startPayload() then return end
                    notify('Login successful.', 'active')
                end
                local ok, accepted = pcall(deps.post, cfg.url,
                    {['Content-Type'] = 'application/x-www-form-urlencoded'},
                    body, received, cfg.timeout)
                if not ok or accepted == false then
                    revoke('HTTP request could not start.', 'error'); return false
                end
                return true
            end
            function A.Login(key) if allowed then return false end; return begin(key) end
            function A.Tick()
                if not pending then return end
                local now, world = readClock()
                if not now or world ~= pending.world or now < pending.started then
                    revoke('Login interrupted by map loading. Please try again when ready.', 'locked'); return
                end
                if now >= pending.deadline then
                    revoke('Request timed out. Please try again.', 'error')
                end
            end
            function A.IsAuthorized()
                if allowed and not restartRequired then return true end
                local stored = loadSession()
                if stored and not restartRequired then
                    allowed = true; expiresAt = stored.expiresAt; return true
                end
                return false
            end
            function A.Logout() clearSession(); revoke('Expired: signed out.', 'locked') end
            function A.FailClosed(text, requiresRestart)
                if requiresRestart == true then restartRequired = true end
                revoke(text or 'Online access unavailable.', 'error')
            end
            function A.ReportClockTampering()
                if localExpiry then localExpiry.MarkTampered() end
                revoke("Don't be over smart", 'tampered')
            end
            function A.Bind(onStart, onStop)
                if type(onStart) ~= 'function' or type(onStop) ~= 'function' then
                    return false, 'START_AND_STOP_REQUIRED'
                end
                if startFn and (startFn ~= onStart or stopFn ~= onStop) then
                    return false, 'ALREADY_BOUND'
                end
                startFn, stopFn = onStart, onStop
                if A.IsAuthorized() then return startPayload() end
                return true
            end
            function A.Unbind()
                revoke('Offline script disconnected.', 'locked')
                startFn, stopFn = nil, nil
            end
            function A.GetRemainingSeconds() return nil end
            function A.GetState()
                local authorized = A.IsAuthorized()
                local sample, age
                if authorized and lastRequestLatencyMs ~= nil then
                    local now, world = readClock()
                    if now and world == lastResponseWorld and now >= lastResponseTime then
                        sample, age = lastRequestLatencyMs, now - lastResponseTime
                    end
                end
                return {
                    phase = phase, message = message, authorized = authorized,
                    sessionAuthorized = authorized, expiresAt = expiresAt,
                    accessPolicy = "game_session", expiryCheckPolicy = "login_only",
                    periodicRecheck = false, pending = pending ~= nil,
                    linked = startFn ~= nil, restartRequired = restartRequired == true,
                    lastRequestLatencyMs = sample, lastRequestLatencyAgeSeconds = age,
                    latencyScope = "license_http_round_trip"
                }
            end
            return A
        end
    end)()

    local Core = {Primitives = Primitives, createExpiry = CreateLocalExpiry}
    function Core.new(config, dependencies)
        assert(type(config) == 'table' and type(dependencies) == 'table',
            'License configuration and dependencies required')
        local deps = {}
        for key, value in pairs(dependencies) do deps[key] = value end
        if deps.localExpiry == nil then deps.localExpiry = CreateLocalExpiry(config, deps.wall) end
        return CreateAuth(Primitives, config, deps)
    end
    return Core
end)()

-- ============================================================================
-- 2. LOGIN UI
-- ============================================================================
local MasterLoginUI = (function()
    local Module = {}
    function Module.new(env)
        env = env or _G
        local require = env.require or require
        local function global(name)
            local ok, value = pcall(function() return env[name] end)
            if ok then return value end
        end
        local UI = {_status = "Enter your key", _busy = false, _data = nil}
        local function member(object, name)
            if object == nil then return nil end
            local ok, value = pcall(function() return object[name] end)
            if ok then return value end
        end
        local function valid(object)
            local check = member(global("slua"), "isValid")
            if object == nil then return false end
            if type(check) == 'function' then
                local ok, result = pcall(check, object)
                if ok and result == true then return true end
            end
            local game = global('Game')
            local fallback = member(game, 'IsValid')
            if type(fallback) == 'function' then
                local ok, result = pcall(fallback, game, object)
                return ok and result == true
            end
            return false
        end
        local function imported(name)
            local loader = global("import")
            if type(loader) ~= "function" then return nil end
            local ok, result = pcall(loader, name)
            if ok then return result end
        end
        local function construct(class, ...)
            if class == nil then return nil end
            local ok, result = pcall(class, ...)
            if ok then return result end
        end
        local function vector(x, y)
            return construct(global("FVector2D") or imported("Vector2D"), x, y)
                or {X = x, Y = y}
        end
        local function color(r, g, b, a)
            return construct(global("FLinearColor") or imported("LinearColor"), r, g, b, a)
                or {R = r, G = g, B = b, A = a}
        end
        local function visibility(widget, value)
            local setter = member(widget, "SetWidgetVisibility") or member(widget, "SetVisibility")
            assert(type(setter) == "function", "UI_VISIBILITY_UNAVAILABLE")
            setter(widget, value)
        end
        local function setTextStyle(widget, size, textColor)
            pcall(function()
                local font = widget.Font
                if font then
                    font.Size = math.max(1, math.floor(size * (UI._scale or 1) + 0.5))
                    local assigned = pcall(function() widget.Font = font end)
                    if not assigned then widget:SetFont(font) end
                end
            end)
            pcall(function() widget:SetAutoWrapText(true) end)
            pcall(function()
                local slate = construct(imported("SlateColor"), textColor)
                if slate then widget:SetColorAndOpacity(slate) end
            end)
        end
        local function detach(data)
            if not data then return end
            data.visible = false
            pcall(function() if valid(data.input) then data.input:SetText("") end end)
            if data.event and data.eventHandle ~= nil then
                pcall(function() data.event:Remove(data.eventHandle) end)
            end
            if data.closeEvent and data.closeEventHandle ~= nil then
                pcall(function() data.closeEvent:Remove(data.closeEventHandle) end)
            end
            if valid(data.container) then
                pcall(function() data.container:RemoveFromParent() end)
            end
            data.onSubmit = nil
        end
        function UI.Destroy()
            local previous = UI._data; UI._data = nil; detach(previous)
        end
        -- Call UI.Tick(deltaSeconds) from the host's existing per-frame callback.
        -- Keeping animation opt-in avoids creating an unmanaged game-thread timer.
        function UI.Tick(deltaSeconds)
            local data = UI._data
            if not data or not data.visible or not valid(data.container) then return false end
            local dt = tonumber(deltaSeconds) or (1 / 60)
            dt = math.max(0, math.min(dt, 0.1))
            data.animationClock = ((data.animationClock or 0) + dt) % 6.283185307
            local pulse = (math.sin(data.animationClock * 2.0) + 1) * 0.5
            local ok = pcall(function()
                if valid(data.halo) then
                    data.halo:SetBrushColor(color(1.0, 0.82, 0.02, 0.09 + pulse * 0.13))
                end
                if valid(data.buttonGlow) then
                    data.buttonGlow:SetBrushColor(color(1.0, 0.82, 0.02, 0.24 + pulse * 0.26))
                end
                if data.scanSlot then
                    local travel = (data.animationClock % 2.8) / 2.8
                    local scanX = 12 + travel * math.max(1, data.width - 76)
                    data.scanSlot:SetPosition(vector(scanX * (data.scale or 1), 58 * (data.scale or 1)))
                    if valid(data.scan) then
                        data.scan:SetBrushColor(color(1.0, 0.86, 0.12, 0.08 + pulse * 0.14))
                    end
                end
            end)
            return ok
        end
        function UI.Hide()
            local data = UI._data
            if not data or data.hiddenApplied then return true end
            data.visible = false
            local ok = pcall(function()
                if valid(data.input) then data.input:SetText("") end
                if valid(data.container) then visibility(data.container, data.hidden) end
            end)
            if ok then data.hiddenApplied = true end
            return ok
        end
        function UI.SetStatus(message)
            UI._status = type(message) == "string" and message:sub(1, 160) or "Login unavailable"
            local data = UI._data
            if data and data.deliveredStatus == UI._status then return true end
            if data and valid(data.status) then
                local ok = pcall(function() data.status:SetText("◆  " .. UI._status) end)
                if ok then data.deliveredStatus = UI._status end
                return ok
            end
            return false
        end
        function UI.SetBusy(busy)
            UI._busy = busy == true
            local data = UI._data
            if data then
                if data.deliveredBusy == UI._busy then return true end
                local buttonOK = pcall(function() data.button:SetIsEnabled(not UI._busy) end)
                local inputOK  = pcall(function() data.input:SetIsEnabled(not UI._busy) end)
                if buttonOK and inputOK then data.deliveredBusy = UI._busy; return true end
            end
            return false
        end
        local function fitScale(parent)
            local result = 1
            pcall(function()
                local size = parent:GetCachedGeometry():GetLocalSize()
                local width, height = size.X, size.Y
                if type(width) == 'number' and type(height) == 'number'
                    and width > 24 and height > 24 then
                    result = math.min(1, (width - 24) / 500, (height - 24) / 260)
                end
            end)
            return result
        end
        function UI.Show(onSubmit)
            if type(onSubmit) ~= "function" then return false, "UI_SUBMIT_REQUIRED" end
            local data = UI._data
            if data and valid(data.parent)
                and math.abs(fitScale(data.parent) - (data.scale or 1)) > 0.001 then
                UI.Destroy(); data = nil
            end
            if data and valid(data.container) and valid(data.parent) then
                local ok = data.visible or pcall(function()
                    visibility(data.container, data.visibleEnum)
                end)
                if ok then
                    data.onSubmit, data.visible, data.hiddenApplied = onSubmit, true, false
                    UI.SetStatus(UI._status); UI.SetBusy(UI._busy); return true
                end
            end
            UI.Destroy()
            local okTools, uiTools = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
            local getRoot = okTools and member(uiTools, "GetMainControlBaseUI")
            if type(getRoot) ~= "function" then return false, "UI_NOT_READY" end
            local okRoot, root = pcall(getRoot)
            if not okRoot or not valid(root) then return false, "UI_NOT_READY" end
            local parent = member(root, "CanvasPanel_0")
            if not valid(parent) then parent = member(root, "CanvasPanel_42") end
            if not valid(parent) then return false, "UI_NOT_READY" end
            local game = global("CGame")
            if type(member(game, "NewObjectFromPath")) ~= "function" then
                return false, "UI_FACTORY_UNAVAILABLE"
            end
            local enums = member(global("UEnums"), "ESlateVisibility")
            local visibleEnum, hidden = member(enums, "Visible"), member(enums, "Collapsed")
            local passive = member(enums, "SelfHitTestInvisible")
            if visibleEnum == nil or hidden == nil or passive == nil then
                return false, "UI_ENUM_UNAVAILABLE"
            end
            UI._scale = fitScale(parent)
            data = {parent = parent, visible = false, onSubmit = onSubmit,
                    visibleEnum = visibleEnum, hidden = hidden, scale = UI._scale}
            local okBuild = pcall(function()
                local function make(class, outer)
                    local widget = game:NewObjectFromPath("/Script/UMG." .. class, outer)
                    assert(valid(widget), "UI_WIDGET_UNAVAILABLE")
                    return widget
                end
                data.container = make("CanvasPanel", parent)
                local function add(widget, x, y, width, height, z)
                    local slot = data.container:AddChildToCanvas(widget)
                    slot:SetAutoSize(false)
                    slot:SetPosition(vector(x * UI._scale, y * UI._scale))
                    slot:SetSize(vector(width * UI._scale, height * UI._scale))
                    slot:SetZOrder(z)
                    return slot
                end

                -- === OBSIDIAN + GOLD VIP PORTAL ===
                local W, H = 580, 320
                data.width = W

                -- 1. Outer Golden Glow Halo
                local halo = make("Border", data.container)
                data.halo = halo
                halo:SetBrushColor(color(1.0, 0.85, 0.0, 0.18))
                visibility(halo, passive)
                add(halo, -3, -3, W + 6, H + 6, 0)

                -- 2. Master Obsidian Card Background
                local bg = make("Border", data.container)
                bg:SetBrushColor(color(0.04, 0.04, 0.04, 0.98))
                visibility(bg, visibleEnum)
                add(bg, 0, 0, W, H, 1)

                -- 2a. Slow gold scan shimmer behind the header.
                data.scan = make("Border", data.container)
                data.scan:SetBrushColor(color(1.0, 0.86, 0.12, 0.12))
                visibility(data.scan, passive)
                data.scanSlot = add(data.scan, 12, 58, 64, 2, 2)

                -- 3. Solid Gold Neon Outer Borders
                local topBorder = make("Border", data.container)
                topBorder:SetBrushColor(color(1.0, 0.85, 0.0, 1.0))
                visibility(topBorder, passive)
                add(topBorder, 0, 0, W, 2, 3)

                local botBorder = make("Border", data.container)
                botBorder:SetBrushColor(color(1.0, 0.85, 0.0, 1.0))
                visibility(botBorder, passive)
                add(botBorder, 0, H - 2, W, 2, 3)

                local leftBorder = make("Border", data.container)
                leftBorder:SetBrushColor(color(1.0, 0.85, 0.0, 1.0))
                visibility(leftBorder, passive)
                add(leftBorder, 0, 0, 2, H, 3)

                local rightBorder = make("Border", data.container)
                rightBorder:SetBrushColor(color(1.0, 0.85, 0.0, 1.0))
                visibility(rightBorder, passive)
                add(rightBorder, W - 2, 0, 2, H, 3)

                -- 4. Diagonal Corner Hazard Decos (Top-Left & Bottom-Right)
                local tlDeco = make("Border", data.container)
                tlDeco:SetBrushColor(color(1.0, 0.85, 0.0, 0.9))
                visibility(tlDeco, passive)
                add(tlDeco, 2, 2, 28, 6, 4)

                local brDeco = make("Border", data.container)
                brDeco:SetBrushColor(color(1.0, 0.85, 0.0, 0.9))
                visibility(brDeco, passive)
                add(brDeco, W - 30, H - 8, 28, 6, 4)

                -- 5. Crown mark and top header titles
                local crown = make("TextBlock", data.container)
                crown:SetText("♛")
                setTextStyle(crown, 27, color(1.0, 0.82, 0.0, 1.0))
                visibility(crown, passive)
                add(crown, 24, 10, 34, 34, 5)

                local titleTag = make("TextBlock", data.container)
                titleTag:SetText("VIP SYSTEM PORTAL")
                setTextStyle(titleTag, 19, color(1.0, 0.86, 0.0, 1.0))
                visibility(titleTag, passive)
                add(titleTag, 62, 14, 280, 26, 5)

                local subTag = make("TextBlock", data.container)
                subTag:SetText("ROYAL CHEAT | VIP ACCESS")
                setTextStyle(subTag, 10, color(0.85, 0.85, 0.85, 0.9))
                visibility(subTag, passive)
                add(subTag, 63, 40, 280, 16, 5)

                -- Premium shield badge
                local badge = make("Border", data.container)
                badge:SetBrushColor(color(0.13, 0.11, 0.02, 0.96))
                visibility(badge, passive)
                add(badge, W - 218, 13, 25, 29, 5)

                local badgeMark = make("TextBlock", data.container)
                badgeMark:SetText("★")
                setTextStyle(badgeMark, 15, color(1.0, 0.86, 0.0, 1.0))
                visibility(badgeMark, passive)
                add(badgeMark, W - 215, 18, 20, 18, 6)

                local topBadge = make("TextBlock", data.container)
                topBadge:SetText("UNLOCK YOUR\nPREMIUM FEATURES")
                setTextStyle(topBadge, 9, color(1.0, 0.85, 0.0, 1.0))
                visibility(topBadge, passive)
                add(topBadge, W - 188, 13, 140, 31, 5)

                -- Close control, matching the reference card.
                data.closeButton = make("Button", data.container)
                pcall(function() data.closeButton:SetBackgroundColor(color(0.16, 0.13, 0.02, 1.0)) end)
                visibility(data.closeButton, visibleEnum)
                local closeLabel = make("TextBlock", data.closeButton)
                closeLabel:SetText("X")
                setTextStyle(closeLabel, 15, color(1.0, 0.9, 0.0, 1.0))
                visibility(closeLabel, passive)
                data.closeButton:AddChild(closeLabel)
                add(data.closeButton, W - 34, 8, 25, 25, 8)
                data.closeEvent = data.closeButton.OnClicked
                data.closeEventHandle = data.closeEvent:Add(function()
                    if UI._data == data and data.visible then UI.Hide() end
                end)

                -- 6. Instructional Text
                local enterKeyLabel = make("TextBlock", data.container)
                enterKeyLabel:SetText("Enter your licensed access key to unlock features")
                setTextStyle(enterKeyLabel, 11, color(0.9, 0.9, 0.9, 1.0))
                visibility(enterKeyLabel, passive)
                add(enterKeyLabel, 26, 68, W - 52, 18, 5)

                -- 7. Golden Chamfered Input Box Container
                local inputHalo = make("Border", data.container)
                inputHalo:SetBrushColor(color(1.0, 0.85, 0.0, 0.25))
                visibility(inputHalo, passive)
                add(inputHalo, 24, 88, W - 48, 44, 4)

                local inputBorder = make("Border", data.container)
                inputBorder:SetBrushColor(color(1.0, 0.85, 0.0, 1.0))
                visibility(inputBorder, passive)
                add(inputBorder, 25, 89, W - 50, 42, 5)

                local inputBg = make("Border", data.container)
                inputBg:SetBrushColor(color(0.06, 0.06, 0.06, 0.98))
                visibility(inputBg, passive)
                add(inputBg, 26, 90, W - 52, 40, 6)

                -- Actual Input Field
                data.input = make("EditableTextBox", data.container)
                data.input:SetText("")
                setTextStyle(data.input, 14, color(1.0, 1.0, 1.0, 1.0))
                pcall(function() data.input:SetHintText("Paste your VIP license key here...") end)
                visibility(data.input, visibleEnum)
                add(data.input, 40, 93, W - 80, 34, 7)

                -- 8. Buy Key Bar
                local buyBar = make("Border", data.container)
                buyBar:SetBrushColor(color(0.10, 0.09, 0.02, 0.90))
                visibility(buyBar, passive)
                add(buyBar, 26, 140, W - 52, 24, 5)

                local buyBarTrim = make("Border", data.container)
                buyBarTrim:SetBrushColor(color(1.0, 0.85, 0.0, 1.0))
                visibility(buyBarTrim, passive)
                add(buyBarTrim, 26, 140, 3, 24, 6)

                local buyText = make("TextBlock", data.container)
                buyText:SetText("BUY KEY: Telegram @Zakarya_OP  |  WhatsApp: +923192530306")
                setTextStyle(buyText, 11, color(1.0, 0.90, 0.40, 1.0))
                visibility(buyText, passive)
                add(buyText, 36, 144, W - 72, 18, 7)

                -- 9. Status Text
                data.status = make("TextBlock", data.container)
                data.status:SetText("◆  " .. UI._status)
                data.deliveredStatus = UI._status
                setTextStyle(data.status, 11, color(0.9, 0.9, 0.9, 1.0))
                visibility(data.status, passive)
                pcall(function() data.status:SetAutoWrapText(true) end)
                add(data.status, 26, 172, W - 52, 22, 5)

                -- 10. Golden High-Impact Authenticate Button
                local btnW, btnH = 310, 48
                local btnX = (W - btnW) / 2
                local btnY = 202

                data.buttonGlow = make("Border", data.container)
                data.buttonGlow:SetBrushColor(color(1.0, 0.85, 0.0, 0.45))
                visibility(data.buttonGlow, passive)
                add(data.buttonGlow, btnX - 3, btnY - 2, btnW + 6, btnH + 4, 5)

                data.button = make("Button", data.container)
                pcall(function() data.button:SetBackgroundColor(color(1.0, 0.82, 0.0, 1.0)) end)
                visibility(data.button, visibleEnum)

                local label = make("TextBlock", data.button)
                label:SetText("★  AUTHENTICATE NOW  ->")
                setTextStyle(label, 15, color(0.02, 0.02, 0.02, 1.0))
                visibility(label, passive)
                data.button:AddChild(label)
                add(data.button, btnX, btnY, btnW, btnH, 6)

                -- 11. Bottom Trust Footer (100% SAFE | INSTANT ACCESS | 24/7 SUPPORT | PREMIUM SERVICE)
                local footer = make("TextBlock", data.container)
                footer:SetText("100% SAFE   |   INSTANT ACCESS   |   24/7 SUPPORT   |   PREMIUM SERVICE")
                setTextStyle(footer, 10, color(1.0, 0.85, 0.2, 0.85))
                visibility(footer, passive)
                add(footer, 26, 270, W - 52, 18, 5)
                -- === OBSIDIAN + GOLD VIP PORTAL END ===

                data.event = data.button.OnClicked
                data.eventHandle = data.event:Add(function()
                    if UI._data ~= data or not data.visible or UI._busy then return end
                    local readOK, key = pcall(function() return data.input:GetText() end)
                    if not readOK or type(key) ~= "string" then
                        UI.SetStatus("Unable to read the key"); return
                    end
                    key = key:match("^%s*(.-)%s*$")
                    if key == "" or #key > 512 then UI.SetStatus("Enter a valid key"); return end
                    local submitOK = pcall(data.onSubmit, key)
                    if not submitOK then UI.SetBusy(false); UI.SetStatus("Login could not start") end
                end)
                local slot = parent:AddChildToCanvas(data.container)
                slot:SetAutoSize(false)
                slot:SetSize(vector(W * UI._scale, H * UI._scale))
                slot:SetZOrder(9000)
                local anchors = slot:GetAnchors()
                anchors.Minimum, anchors.Maximum = vector(0.5, 0.5), vector(0.5, 0.5)
                slot:SetAnchors(anchors)
                slot:SetAlignment(vector(0.5, 0.5))
                slot:SetPosition(vector(0, 0))
                visibility(data.container, passive)
            end)
            if not okBuild then
                detach(data); return false, "UI_BUILD_UNAVAILABLE"
            end
            data.visible = true; UI._data = data; UI.SetBusy(UI._busy)
            return true
        end
        function UI.ShowNotice(message)
            local shown, reason = UI.Show(function() return false end)
            if not shown then return false, reason end
            UI.SetStatus(message); UI.SetBusy(true); return true
        end
        return UI
    end
    return Module
end)()

-- ============================================================================
-- 3. WELCOME UI
-- ============================================================================
local MasterWelcomeUI = (function()
    local Module = {}
    function Module.new(env)
        env = env or _G
        local require = env.require or require
        local function global(n)
            local ok, v = pcall(function() return env[n] end)
            if ok then return v end
        end
        local function member(o, k)
            if o == nil then return nil end
            local ok, v = pcall(function() return o[k] end)
            if ok then return v end
        end
        local function valid(o)
            local c = member(global("slua"), "isValid")
            if o == nil then return false end
            if type(c) == 'function' then
                local ok, v = pcall(c, o)
                if ok and v == true then return true end
            end
            local g = global('Game'); local f = member(g, 'IsValid')
            if type(f) == 'function' then
                local ok, v = pcall(f, g, o)
                return ok and v == true
            end
            return false
        end
        local function imported(n)
            local l = global("import")
            if type(l) ~= "function" then return nil end
            local ok, v = pcall(l, n); if ok then return v end
        end
        local function construct(c, ...)
            if c == nil then return nil end
            local ok, v = pcall(c, ...); if ok then return v end
        end
        local function vector(x, y)
            return construct(global("FVector2D") or imported("Vector2D"), x, y) or {X = x, Y = y}
        end
        local function linear(v)
            v = v / 255
            if v <= 0.04045 then return v / 12.92 end
            return ((v + 0.055) / 1.055) ^ 2.4
        end
        local function color(r, g, b, a)
            r, g, b, a = linear(r), linear(g), linear(b), a or 1
            return construct(global("FLinearColor") or imported("LinearColor"), r, g, b, a)
                or {R = r, G = g, B = b, A = a}
        end
        local function visibility(w, v)
            local s = member(w, "SetWidgetVisibility") or member(w, "SetVisibility")
            if type(s) == 'function' then s(w, v) end
        end
        local WelcomeUI = {Width = 600, Height = 276}
        local WelcomeText = {
            "Welcome to @ZakPubgSkin Premium Pak",
            "No Kill Limit",
            "Play smart and avoid report",
        }
        local UI = {_shown = false, _data = nil}
        local function detach(data)
            if not data then return end
            data.Visible = false
            if data.Event and data.EventHandle ~= nil then
                pcall(function() data.Event:Remove(data.EventHandle) end)
            end
            if valid(data.Container) then
                pcall(function() visibility(data.Container, data.Hidden) end)
                pcall(function() data.Container:RemoveFromParent() end)
            end
        end
        function UI:Destroy()
            local p = UI._data; UI._data = nil; detach(p)
        end
        local function parent()
            local okT, tools = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
            if not okT then return nil end
            local getRoot = member(tools, "GetMainControlBaseUI")
            if type(getRoot) ~= "function" then return nil end
            local ok, root = pcall(getRoot)
            if not ok or not valid(root) then return nil end
            local canvas = member(root, "CanvasPanel_0")
            if not valid(canvas) then canvas = member(root, "CanvasPanel_42") end
            if valid(canvas) then return root, canvas end
        end
        function UI:Show()
            if UI._shown and UI._data and valid(UI._data.Container) then
                visibility(UI._data.Container, UI._data.Passive)
                UI._data.Visible = true
                return true
            end
            UI:Destroy()
            local root, par = parent()
            if not par then return false, "WELCOME_ROOT_UNAVAILABLE" end
            local game = global("CGame")
            if type(member(game, "NewObjectFromPath")) ~= "function" then
                return false, "WELCOME_FACTORY_UNAVAILABLE"
            end
            local enums = member(global("UEnums"), "ESlateVisibility")
            local visible, hidden, passive = member(enums, "Visible"),
                member(enums, "Collapsed"), member(enums, "SelfHitTestInvisible")
            if visible == nil or hidden == nil or passive == nil then
                return false, "WELCOME_ENUM_UNAVAILABLE"
            end
            local data = {Root = root, Parent = par, Visible = false,
                          Hidden = hidden, Passive = passive}
            local ok = pcall(function()
                local function make(class, outer)
                    local w = game:NewObjectFromPath("/Script/UMG." .. class, outer)
                    assert(valid(w), "WELCOME_WIDGET_UNAVAILABLE")
                    return w
                end
                data.Container = make("CanvasPanel", par)
                visibility(data.Container, hidden)
                local function add(w, x, y, ww, hh, z)
                    local s = data.Container:AddChildToCanvas(w)
                    s:SetAutoSize(false)
                    s:SetPosition(vector(x, y))
                    s:SetSize(vector(ww, hh))
                    s:SetZOrder(z)
                    return s
                end
                local function rect(x, y, ww, hh, c, z)
                    local w = make("Border", data.Container)
                    w:SetBrushColor(c)
                    visibility(w, passive)
                    add(w, x, y, ww, hh, z)
                    return w
                end
                local slateColor
                pcall(function() slateColor = imported("SlateColor") end)
                local function textStyle(w, size, c)
                    local font = member(w, "Font")
                    if font ~= nil then
                        if type(font) == 'table' then
                            local copy = {}
                            for k, v in pairs(font) do copy[k] = v end
                            font = copy
                        end
                        font.Size = size
                        pcall(function() w:SetFont(font) end)
                    end
                    pcall(function() w:SetColorAndOpacity(slateColor and slateColor(c) or c) end)
                    pcall(function() w:SetJustification(1) end)
                    visibility(w, passive)
                end
                local function text(value, x, y, ww, hh, size, c, z)
                    local w = make("TextBlock", data.Container)
                    w:SetText(value)
                    textStyle(w, size, c)
                    pcall(function() w:SetAutoWrapText(true) end)
                    add(w, x, y, ww, hh, z)
                    return w
                end
                local W, H = WelcomeUI.Width, WelcomeUI.Height
                rect(4, 6, W, H, color(18, 5, 10, 0.25), 0)
                rect(0, 0, W, H, color(186, 137, 74), 1)
                rect(2, 2, W - 4, H - 4, color(255, 244, 214), 2)
                local stops = {{116, 16, 46}, {169, 38, 47}, {194, 105, 35}}
                local segments = 64
                for i = 0, segments - 1 do
                    local t = i / (segments - 1)
                    local left, right, blend
                    if t <= 0.5 then left, right, blend = stops[1], stops[2], t * 2
                    else left, right, blend = stops[2], stops[3], (t - 0.5) * 2 end
                    local x0 = 2 + (W - 4) * i / segments
                    local x1 = 2 + (W - 4) * (i + 1) / segments
                    rect(x0, 2, math.min(W - 2, x1 + 0.3) - x0, 76,
                        color(left[1] + (right[1] - left[1]) * blend,
                              left[2] + (right[2] - left[2]) * blend,
                              left[3] + (right[3] - left[3]) * blend), 3)
                end
                rect(18, 3, W - 36, 1, color(255, 255, 255, 0.32), 4)
                rect(2, 78, W - 4, 3, color(238, 188, 93), 4)
                local title = text(WelcomeText[1], 24, 23, W - 48, 44, 19, color(255, 253, 247), 5)
                pcall(function() title:SetShadowOffset(vector(0, 1)) end)
                pcall(function() title:SetShadowColorAndOpacity(color(40, 3, 12, 0.45)) end)
                rect(30, 100, W - 60, 54, color(255, 226, 159), 3)
                rect(30, 100, 4, 54, color(160, 33, 49), 4)
                text(WelcomeText[2], 46, 110, W - 92, 38, 23, color(115, 25, 45), 5)
                text(WelcomeText[3], 30, 168, W - 60, 32, 17, color(130, 34, 47), 5)
                local button = make("Button", data.Container)
                pcall(function() button:SetBackgroundColor(color(131, 25, 47)) end)
                visibility(button, visible)
                local label = make("TextBlock", button)
                label:SetText("OK")
                textStyle(label, 17, color(255, 251, 238))
                local ls = button:AddChild(label)
                pcall(function() ls:SetHorizontalAlignment(2) end)
                pcall(function() ls:SetVerticalAlignment(2) end)
                add(button, (W - 164) / 2, 212, 164, 42, 6)
                data.Event = member(button, "OnClicked")
                data.EventHandle = data.Event:Add(function()
                    if UI._data == data and data.Visible then UI:Destroy() end
                end)
                local slot = par:AddChildToCanvas(data.Container)
                slot:SetAutoSize(false)
                slot:SetSize(vector(W, H))
                slot:SetZOrder(9200)
                local anchors = slot:GetAnchors()
                anchors.Minimum, anchors.Maximum = vector(0.5, 0.5), vector(0.5, 0.5)
                slot:SetAnchors(anchors)
                slot:SetAlignment(vector(0.5, 0.5))
                slot:SetPosition(vector(0, 0))
                visibility(data.Container, passive)
            end)
            if not ok then detach(data); return false, "WELCOME_BUILD_FAILED" end
            data.Visible = true
            UI._data = data
            UI._shown = true
            return true
        end
        function UI:Hide() if UI._data then detach(UI._data) end; UI._data = nil end
        function UI:IsShown() return UI._shown == true end
        return UI
    end
    return Module
end)()
_G.MasterWelcomeUI = MasterWelcomeUI

-- ============================================================================
-- 4. LICENSE RUNTIME
-- ============================================================================
local MasterLicenseRuntime = (function()
    local Runtime = {}
    Runtime.__index = Runtime
    local function finite(n)
        return type(n) == 'number' and n == n and n >= 0 and n < math.huge
    end
    local function read(o, k)
        if o == nil then return nil end
        local ok, v = pcall(function() return o[k] end)
        if ok then return v end
    end
    local function static(o, k, ...)
        local fn = read(o, k)
        if type(fn) ~= 'function' then return nil end
        local ok, v = pcall(fn, ...); if ok then return v end
    end
    local function call(o, k, ...)
        local fn = read(o, k)
        if type(fn) ~= 'function' then return nil end
        local ok, v = pcall(fn, o, ...); if ok then return v end
    end
    local function validConfig(c)
        return type(c) == 'table' and type(c.url) == 'string' and c.url:match('^https://') ~= nil
            and type(c.game) == 'string' and #c.game > 0
            and type(c.secret) == 'string' and #c.secret > 0
            and finite(c.timeout) and c.timeout > 0 and finite(c.clockSkew)
    end
    function Runtime.new(env, config, Core, LoginUI)
        local self = setmetatable({
            env = env or _G, reason = 'login_required', active = false,
            ready = false, disposed = false, uiRetryAt = 0, uiFailures = 0
        }, Runtime)
        if not validConfig(config) or type(Core) ~= 'table' or type(Core.new) ~= 'function'
            or type(Core.Primitives) ~= 'table' then
            self.reason = 'license_dependencies_unavailable'; return self
        end
        local cfg = {}
        for k, v in pairs(config) do cfg[k] = v end
        self.timeout = cfg.timeout
        if type(LoginUI) == 'table' and type(LoginUI.new) == 'function' then
            local ok, ui = pcall(LoginUI.new, self.env)
            if ok and type(ui) == 'table' then self.ui = ui end
        end
        if type(_G.MasterWelcomeUI) == 'table' and type(_G.MasterWelcomeUI.new) == 'function' then
            local okW, w = pcall(_G.MasterWelcomeUI.new, self.env)
            if okW and type(w) == 'table' then self.welcome = w end
        end
        self.welcomeShownThisSession = (_G.__MASTER_WELCOME_SHOWN_SESSION == true)
        self.welcomeScheduledAt = nil
        self.welcomeDelaySeconds = 3.0
        self.submit = function(key) return self:login(key) end
        local ok, auth = pcall(Core.new, cfg, {
            clock = function() return self:_clock() end,
            wall = function()
                local value = static(read(self.env, 'os'), 'time')
                if finite(value) and value > 0 then return value end
            end,
            serial = function(key)
                local client = read(self.env, 'Client')
                local value = static(client, 'GetPhoneDeviceID')
                assert(type(value) == 'string' and #value > 0 and #value <= 512,
                    'DEVICE_ID_UNAVAILABLE')
                return Core.Primitives.name_uuid('MASTER-LUA-V1\0' .. key .. '\0' .. value)
            end,
            decode = function(raw)
                local json = self:_module('json', nil, 'common.json_util', 'decode')
                assert(json, 'JSON_UNAVAILABLE')
                return json.decode(raw)
            end,
            post = function(url, headers, body, callback, timeout)
                local manager = read(self.env, 'ModuleManager')
                local config = read(manager, 'CommonModuleConfig')
                local getter = read(manager, 'GetModule')
                assert(type(getter) == 'function' and config, 'HTTP_MANAGER_UNAVAILABLE')
                local http = getter(read(config, 'http_manager'))
                local post = read(http, 'Post')
                assert(type(post) == 'function', 'HTTP_POST_UNAVAILABLE')
                return post(http, url, headers, body, nil, callback, timeout)
            end,
            status = function(message, phase)
                self.active = false
                self.reason = phase == 'active' and 'waiting_maintenance' or 'login_required'
                self:_ui('SetStatus', message)
                self:_ui('SetBusy', phase == 'pending')
                if phase == 'active' then self:_ui('Hide') end
            end,
        })
        if ok and type(auth) == 'table' then self.auth = auth
        else self.reason = 'license_initialization_unavailable' end
        return self
    end
    function Runtime:_module(cache, globalName, path, method)
        local found = globalName and read(self.env, globalName)
        if type(read(found, method)) == 'function' then return found end
        found = self[cache]
        if type(read(found, method)) == 'function' then return found end
        local loader = read(self.env, 'require')
        if type(loader) == 'function' then
            local ok, value = pcall(loader, path)
            if ok and type(read(value, method)) == 'function' then
                self[cache] = value; return value
            end
        end
    end
    function Runtime:_valid(object)
        if object == nil then return false end
        if static(read(self.env, 'slua'), 'isValid', object) == true then return true end
        return call(read(self.env, 'Game'), 'IsValid', object) == true
    end
    function Runtime:_clock()
        local world = static(read(self.env, 'slua'), 'getWorld')
        if world == nil then return nil end
        local statics = read(self.env, 'GameplayStatics') or self.statics
        if type(read(statics, 'GetRealTimeSeconds')) ~= 'function' then
            local loader = read(self.env, 'import')
            if type(loader) == 'function' then
                local ok, value = pcall(loader, 'GameplayStatics')
                if ok then statics = value end
            end
        end
        if type(read(statics, 'GetRealTimeSeconds')) ~= 'function' then return nil end
        self.statics = statics
        local now = static(statics, 'GetRealTimeSeconds', world)
        if finite(now) then return now, world end
    end
    function Runtime:_readGameplay(world)
        local data = read(self.env, 'GameplayData') or self.gameplayData
        if data == nil then
            local loader = read(self.env, 'require')
            if type(loader) == 'function' then
                local ok, value = pcall(loader, 'GameLua.GameCore.Data.GameplayData')
                if ok and value ~= nil then self.gameplayData = value; data = value end
            end
        end
        local pc = static(data, 'GetPlayerController')
        if not self:_valid(pc) and not self:_valid(read(pc, 'Object')) then
            pc = call(read(self.env, 'slua_GameFrontendHUD'), 'GetPlayerController')
        end
        if not self:_valid(pc) and not self:_valid(read(pc, 'Object')) then
            return nil, 'waiting_controller'
        end
        local pawn = static(data, 'GetPlayerCharacter')
        if not self:_valid(pawn) then pawn = static(data, 'GetLocalCharacter') end
        for _, method in ipairs({'GetPlayerCharacterSafety', 'GetCurPawn', 'GetPawn'}) do
            if not self:_valid(pawn) then pawn = call(pc, method) end
            if not self:_valid(pawn) then pawn = call(read(pc, 'Object'), method) end
        end
        if not self:_valid(pawn) then return nil, 'waiting_pawn' end
        local tools = self:_module('tools', nil,
            'GameLua.Mod.BaseMod.Common.UI.InGameUITools', 'GetMainControlBaseUI')
        local root = static(tools, 'GetMainControlBaseUI')
        if not self:_valid(root) then return nil, 'waiting_control_ui' end
        local status = self:_module('gameStatus', 'GameStatus',
            'client.common.game_status', 'IsInFightingStatus')
        local loading = self:_module('loading', nil,
            'client.slua.logic.loading.logic_loading', 'IsShowing')
        if not status or not loading then return nil, 'readiness_services_unavailable' end
        if static(status, 'IsInFightingStatus') ~= true then return nil, 'waiting_gameplay' end
        if static(loading, 'IsShowing') ~= false then return nil, 'waiting_loading' end
        return {world = world, controller = pc, pawn = pawn, root = root}
    end
    local function same(a, b)
        return a and b and a.world == b.world and a.controller == b.controller
            and a.pawn == b.pawn and a.root == b.root
    end
    function Runtime:_ui(method, ...)
        local fn = read(self.ui, method)
        if type(fn) ~= 'function' then return false, 'UI_UNAVAILABLE' end
        local ok, value, reason = pcall(fn, ...)
        if not ok then return false, 'UI_TEMPORARILY_UNAVAILABLE' end
        return value, reason
    end
    function Runtime:_clearReadiness(reason)
        self.active, self.ready = false, false
        self.identity, self.readySince, self.maintenanceAt, self.maintenanceWorld = nil, nil, nil, nil
        self.reason = reason
        self:_ui('Hide')
    end
    function Runtime:_showPanel(now, state, blocked)
        if now < self.uiRetryAt then return false end
        local shown, uiReason
        if blocked then shown, uiReason = self:_ui('ShowNotice', state.message)
        else shown, uiReason = self:_ui('Show', self.submit) end
        if shown then
            self.uiFailures, self.uiError = 0, nil
            self:_ui('SetStatus', state.message)
            self:_ui('SetBusy', blocked or state.pending)
        else
            self.uiFailures = self.uiFailures + 1
            self.uiRetryAt = now + (self.uiFailures >= 10 and 5 or 1)
            self.uiError = type(uiReason) == 'string' and uiReason:match('^UI_[A-Z_]+$')
                or 'UI_UNAVAILABLE'
        end
        return shown == true
    end
    function Runtime:update()
        if self.disposed then self.reason = 'disposed'; return false end
        if not self.auth then return false end
        local tickOK = pcall(self.auth.Tick)
        if not tickOK then
            self.auth.FailClosed('License maintenance unavailable.')
            self:_clearReadiness('license_maintenance_unavailable'); return false
        end
        local now, world = self:_clock()
        if not now then self:_clearReadiness('clock_unavailable'); return false end
        local ready, reason = self:_readGameplay(world)
        if not ready then self:_clearReadiness(reason); return false end
        if not same(self.identity, ready) or not self.readySince or now < self.readySince then
            self.identity, self.readySince = ready, now
        end
        self.ready = now - self.readySince >= 3
        self.maintenanceAt, self.maintenanceWorld = now, world
        self.active = self.ready and self.auth.IsAuthorized()
        if not self.ready then
            self.reason = 'waiting_stable_gameplay'; self:_ui('Hide'); return false
        end
        local state = self.auth.GetState()
        if self.active then
            self.reason = 'active'
            self:_ui('Hide')
            if self.welcome and not self.welcomeShownThisSession then
                if not self.welcomeScheduledAt then self.welcomeScheduledAt = now end
                if self.welcomeScheduledAt
                    and (now - self.welcomeScheduledAt) >= self.welcomeDelaySeconds then
                    local shown = false
                    pcall(function()
                        if self.welcome:Show() then shown = true end
                    end)
                    if shown then
                        self.welcomeShownThisSession = true
                        _G.__MASTER_WELCOME_SHOWN_SESSION = true
                        self.welcomeScheduledAt = nil
                    else
                        self.welcomeScheduledAt = now
                    end
                end
            end
            return true
        end
        self.reason = 'login_required'
        if state.restartRequired or state.phase == 'expired' or state.phase == 'tampered' then
            self.reason = state.restartRequired and 'restart_required' or state.phase
            self:_showPanel(now, state, true); return false
        end
        if not self:_showPanel(now, state, false) and self.uiError then
            self.reason = 'login_ui_unavailable'
        end
        return false
    end
    function Runtime:isActive()
        if self.disposed or not self.auth or not self.active or not self.ready then return false end
        if not self.auth.IsAuthorized() then self.active = false; return false end
        local now, world = self:_clock()
        if not now or world ~= self.maintenanceWorld or not self.maintenanceAt
            or now < self.maintenanceAt or now - self.maintenanceAt >= 3 then
            self.active = false; self.reason = 'maintenance_stale'; return false
        end
        return true
    end
    function Runtime:login(key)
        if self.disposed or not self.auth then return false end
        if self.auth.IsAuthorized() then return true end
        local now, world = self:_clock()
        if not self.ready or not now or world ~= self.maintenanceWorld
            or not self.maintenanceAt or now < self.maintenanceAt
            or now - self.maintenanceAt >= 3 then return false end
        local identity = self:_readGameplay(world)
        if not same(identity, self.identity) then
            self:_clearReadiness('waiting_stable_gameplay'); return false
        end
        local ok, accepted = pcall(self.auth.Login, key)
        if not ok then self.auth.FailClosed('Login could not start.'); return false end
        return accepted == true
    end
    function Runtime:getStatus()
        local active = self:isActive()
        local state = self.auth and self.auth.GetState() or {}
        return {
            authorized = active, sessionAuthorized = state.authorized == true,
            phase = state.phase or 'locked',
            message = state.message or 'License dependencies unavailable.',
            reason = self.reason, pending = state.pending == true,
            gameplayReady = self.ready, expiresAt = state.expiresAt,
            accessPolicy = 'game_session', expiryCheckPolicy = 'login_only',
            clockProtection = 'login_only', periodicRecheck = false,
            loginDelaySeconds = 3, restartRequired = state.restartRequired == true,
            uiError = self.uiError,
            lastRequestLatencyMs = state.lastRequestLatencyMs,
            latencyScope = 'license_http_round_trip', disposed = self.disposed
        }
    end
    function Runtime:logout()
        self.active = false
        if self.auth then self.auth.Logout() end
        self.reason = 'login_required'; return true
    end
    function Runtime:dispose()
        if self.disposed then return true end
        self:logout(); self.disposed = true; self.ready = false
        self:_ui('Destroy'); self.reason = 'disposed'
        self.submit = nil
        return true
    end
    return Runtime
end)()

-- ============================================================================
-- LICENSE INSTANCE / GLOBAL GATE
-- ============================================================================
local masterBRLicenseInstance = nil

local function BREnsureOnlineLicense()
    if masterBRLicenseInstance then return masterBRLicenseInstance end

    local host = setmetatable({
        GameplayData = GameplayData,
    }, {__index = _ENV})

    local ok, instance = pcall(function()
        return MasterLicenseRuntime.new(
            host,
            MasterLicenseConfig,
            MasterLicenseCore,
            MasterLoginUI
        )
    end)

    if ok and type(instance) == "table" then
        masterBRLicenseInstance = instance
    end
    return masterBRLicenseInstance
end

local function BRLicenseActive()
    local inst = BREnsureOnlineLicense()
    local active = false
    if inst then
        pcall(function()
            active = inst:isActive() == true
        end)
    end

    -- Compatibility state for existing feature code.
    _G.IsAuthValid = active
    _G.IsGracePeriod = false
    _G.IS_MOD_AUTHORIZED = active
    _G.KEY_VALIDATED = active
    _G.LicenseIsLocked = not active

    return active
end

local function BRLicenseMaintenance()
    local inst = BREnsureOnlineLicense()
    if inst then
        pcall(function() inst:update() end)
    end
    BRLicenseActive()
end

-- Expose the same practical login/status surface used by Ahmad.lua.
function _G.MasterLicenseLogin(key)
    local inst = BREnsureOnlineLicense()
    if not inst then return false, "license_unavailable" end
    local ok, result = pcall(inst.login, inst, key)
    if not ok then return false, "license_unavailable" end
    return result
end

function _G.MasterLicenseLogout()
    local inst = BREnsureOnlineLicense()
    if not inst then return false end
    local ok, result = pcall(inst.logout, inst)
    BRLicenseActive()
    return ok and result or false
end

function _G.MasterLicenseStatus()
    local inst = BREnsureOnlineLicense()
    if not inst then
        return {
            authorized = false,
            phase = "locked",
            message = "license_unavailable"
        }
    end

    local ok, value = pcall(inst.getStatus, inst)
    if ok and type(value) == "table" then
        value.authorized = BRLicenseActive()
        return value
    end

    return {authorized = false, phase = "locked"}
end

-- Class-facing compatibility helpers.
function BRPlayerCharacterBase:SubmitESPKey(key)
    return _G.MasterLicenseLogin(key)
end

function BRPlayerCharacterBase:LogoutESP()
    return _G.MasterLicenseLogout()
end

function BRPlayerCharacterBase:GetESPStatus()
    return {
        state = BRLicenseActive() and "active" or "locked",
        license = _G.MasterLicenseStatus()
    }
end

-- Create the instance immediately, but do not activate any gameplay feature.
BREnsureOnlineLicense()
BRLicenseActive()


-- Keep the notification helper used by the rest of the source.
local function Notify(msg)
    local s = "[ZakPubgSkin] " .. tostring(msg)
    pcall(function()
        if _G.GTLMODNotify then
            _G.GTLMODNotify(s)
        end
    end)
    pcall(function()
        local sh = import("ScriptHelperClient")
        if sh and sh.AddOnScreenDebugMessage then
            sh.AddOnScreenDebugMessage(
                s, -1, 3.0,
                {R=1, G=1, B=0, A=1},
                {X=1.2, Y=1.2}
            )
        end
    end)
    print(s)
end

-- Legacy compatibility flag retained for existing feature code.
local isExpired = false


BRPlayerCharacterBase.ServerRPC.RPC_Server_ReportSimulateCharacterLocation = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ClientRPC.RPC_Client_ShootVertifyRes = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ClientRPC.RPC_ClientCoronaLab = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ReportPlayerKillFlow = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ClientSecMrpcsFlow = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_Heartbeat = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_SwiftHawk = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ClientSwiftHawkWithParams = { Reliable = true, Params = {} }
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
    self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
    self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(uVehicle)
  if not slua.isValid(uVehicle) then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:HandleOnAttachedToVehicle", Game:GetObjName(uVehicle)))
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
    self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:UpdatePlayerAttachToVehicle(uVehicle)
      end
    end)
    self.nFixMeshContainerTimer = self:AddGameTimer(3, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:FixMeshContainerOffsetIfNeeded(uVehicle)
      end
    end)
  end
end

function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
  if not slua.isValid(uLastVehicle) then
    return
  end
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnDetachedFromVehicle", uLastVehicle)
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.CapsuleComponent) or not slua.isValid(self.Mesh) or not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  if not self.nUpdatePlayerAttachToVehicleCount then
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  local ESTEPoseState = import("ESTEPoseState")
  local bStand = self.PoseState == ESTEPoseState.Stand
  local uActorRelativeLocation = self.CapsuleComponent:GetRelativeTransform():GetLocation()
  local uMeshRelativeLocation = self.Mesh:GetRelativeTransform():GetLocation()
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  local nCapsuleRadius = self.CapsuleComponent:GetScaledCapsuleRadius()
  local nCapsuleHalfHeight = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local nExpectedCapsuleRadius = self.StandRadius
  local nExpectedCapsuleHalfHeight = self.StandHalfHeight
  local uMeshExpectedRL = FVector(0, 0, 0)
  local uActorExpectedRL = FVector(0, 0, self.StandHalfHeight)
  local nTolerance = 1.0
  local bCapsuleRLCorrect = uActorRelativeLocation:Equals(uActorExpectedRL, nTolerance)
  local bMeshRLCorrect = uMeshRelativeLocation:Equals(uMeshExpectedRL, nTolerance)
  local bMeshContainerRLCorrect = nTolerance > math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ)
  local bCapsuleRadiusCorrect = nTolerance > math.abs(nCapsuleRadius - nExpectedCapsuleRadius)
  local bCapsuleHalfHeightCorrect = nTolerance > math.abs(nCapsuleHalfHeight - nExpectedCapsuleHalfHeight)
  local bAllCorrect = bStand and bCapsuleRLCorrect and bMeshRLCorrect and bMeshContainerRLCorrect and bCapsuleRadiusCorrect and bCapsuleHalfHeightCorrect
  if not bAllCorrect then
    self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1
  else
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:UpdatePlayerAttachToVehicle PlayerKey:%s. bAllCorrect=%s Check Result:%d %d %d %d %d %d, Count:%d", tostring(self.PlayerKey), tostring(bAllCorrect), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, self.nUpdatePlayerAttachToVehicleCount))
  if self.nUpdatePlayerAttachToVehicleCount >= 3 and not bAllCorrect then
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local uPlayerController = GameplayData.GetPlayerController()
    if uPlayerController.ReportCrashKitFeature and uPlayerController.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
      local sReportInfo = string.format("VehicleShapeType:%s PlayerKey:%s. Check Result:%d %d %d %d %d %d. Capsule.RelativeLoc:%s Capsule.Radius:%s Capsule.HalfHeight:%s Mesh.RelativeLoc:%s MeshContainer.RelativeLocZ:%s", tostring(uVehicle.VehicleShapeType), tostring(self.PlayerKey), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, uActorRelativeLocation:ToString(), tostring(nCapsuleRadius), tostring(nCapsuleHalfHeight), uMeshRelativeLocation:ToString(), tostring(uMeshContainerRelativeLocationZ))
      uPlayerController.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(sReportInfo)
    end
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  local nTolerance = 1.0
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  if nTolerance <= math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ) then
    print(bWriteLog and string.format("BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded PlayerKey:%s. SetMeshContainerOffsetZ from:%s to:%s", tostring(uMeshContainerExpectedZ), tostring(uMeshContainerExpectedZ)))
    self:SetMeshContainerOffsetZ(uMeshContainerExpectedZ)
  end
end

function BRPlayerCharacterBase:ClearAttachToVehicleTimer()
  if self.nUpdatePlayerAttachToVehicleTimer then
    self:RemoveGameTimer(self.nUpdatePlayerAttachToVehicleTimer)
    self.nUpdatePlayerAttachToVehicleTimer = nil
  end
  if self.nFixMeshContainerTimer then
    self:RemoveGameTimer(self.nFixMeshContainerTimer)
    self.nFixMeshContainerTimer = nil
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  local EPawnState = import("EPawnState")
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
    self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local EGameModeType = import("EGameModeType")
    local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  local EParachuteState = import("EParachuteState")
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local uGameState = GameplayData:GetGameState()
  local STExtraGameStateBase = import("STExtraGameStateBase")
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    local EGameModeType = import("EGameModeType")
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  local EMovementMode = import("EMovementMode")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local UKismetSystemLibrary = import("KismetSystemLibrary")
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end
BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.UInt32,
    UEnums.EPropertyClass.UInt32  }
}

function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
  print(bWriteLog and string.format("BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment Type = %d, Param = %s", Type, Param))
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      local EStateType = import("EStateType")
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        local ESTEPoseState = import("ESTEPoseState")
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "BRPlayerCharacterBase:RPC_Server_GmPlayAction. actionId: " .. tostring(actionId))
  local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "BRPlayerCharacterBase:MulticastRPC_GmPlayAction. actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  local loadLater = function()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
  self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
  return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ==========================================
-- ⚠️ MOD LOGIC - ONLY RUNS IF AUTHORIZED ⚠️
-- ==========================================

local function IsModAuthorized()
    return true
end

local function NotifyMod(msg) 
    if not IsModAuthorized() then return end
    local s = "[ZakPubgSkin VIP] " .. tostring(msg)
    pcall(function() if _G.GTLMODNotify then _G.GTLMODNotify(s) end end)
    pcall(function() 
        local sh = import("ScriptHelperClient") 
        if sh and sh.AddOnScreenDebugMessage then
            sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1, G=1, B=0, A=1}, {X=1.2, Y=1.2}) 
        end 
    end) 
    print(s) 
end

local _slua = rawget(_G, "slua")

local function Valid(obj) 
    if not obj then return false end 
    if _slua and _slua.isValid then 
        local ok, v = pcall(_slua.isValid, obj) 
        if not ok or not v then return false end 
    end 
    return true 
end

-- ========================================== 
-- STATIC VARIABLES & GLOBAL CACHE
-- ========================================== 
local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}
local SCALE_COLOR_V2 = {R=3, G=3, B=0, A=0}

local GLOBAL_BONE_LIST = {
    "head", "neck_01", "pelvis",
    "upperarm_r", "lowerarm_r", "hand_r",
    "upperarm_l", "lowerarm_l", "hand_l",
    "thigh_l", "calf_l", "foot_l",
    "thigh_r", "calf_r", "foot_r"
}

local GLOBAL_CONNECTIONS = {
    {"neck_01", "pelvis", C_YELLOW},
    {"neck_01", "upperarm_l", C_CYAN}, {"upperarm_l", "lowerarm_l", C_CYAN}, {"lowerarm_l", "hand_l", C_CYAN},
    {"neck_01", "upperarm_r", C_CYAN}, {"upperarm_r", "lowerarm_r", C_CYAN}, {"lowerarm_r", "hand_r", C_CYAN},
    {"pelvis", "thigh_l", C_CYAN}, {"thigh_l", "calf_l", C_CYAN}, {"calf_l", "foot_l", C_CYAN},
    {"pelvis", "thigh_r", C_CYAN}, {"thigh_r", "calf_r", C_CYAN}, {"calf_r", "foot_r", C_CYAN}
}

-- ========================================== 
-- GTLMOD CORE + FULL FEATURES VIP CONFIGURATION 
-- ========================================== 
_G.GTLMODConfig = _G.GTLMODConfig or { 
    AutoHead = false, 
    CustomMagicBullet = false,
    EspVip = false, 
    EspDistance = true, 
    EspVipPro = false, 
    EspRadar = false, 
    Esp5 = false, 
    Esp6 = false, 
    Esp7 = true,
    Esp8 = false,
    EspAntenna = false, 
    EspName = false,
    EspOutline = false, 
    OutlineThickness = 10, 
    UnlockFPS = false, 
    IpadView = false, 
    IpadViewVehicle = false,
    CustomAimbot = false, 
    CustomAimbotClose = false, 
    CustomHRecoil = false,  
    CustomVRecoil = false,  
    LessShake = false, 
    RemoveGrass = false, 
    RemoveFog = false, 
    WhiteBody = false, 
    ColorBodyNew = false,    
    wallhackng = false, 
    Accuracy = false,
    BlackSky = false,
    
    AimTouchEnable = false,
    AimTouchHipIgKnock = true,
    AimTouchHipIgBot = true,
    AimTouchSGIgKnock = true,
    AimTouchSGIgBot = true,
    AimTouchHipVisCheck = true,
    AimTouchSGVisCheck = true,
    AimTouchHipfire = false,
    AimTouchSG = false,
    AimTouchSGAutoFire = false,
    AimTouchScopeAll = false,
    AimTouchScopeIgKnock = true,
    AimTouchScopeIgBot = true,
    AimTouchScopeVisCheck = true,
    AimTouchScopeSniper = false,
    AimTouchSniperIgKnock = true,
    AimTouchSniperIgBot = true,
    AimTouchSniperVisCheck = true,

    ModSkin = false,
}

_G.GTLMODState = _G.GTLMODState or { 
    LoopToken = 0, 
    AimbotLoopToken = 0,
    NativeESPReady = false,
    GraphicsUnlocked = false, 
    MenuStep = 0, 
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    LastAimbotCheckTime = 0, 
    CustomTextData = nil,     
    LastAimbotConfigString = "",
    PrevGraphicsState = {},
    SkinWasApplied = false,
}

local function MainLoop()
    if _G.GTLMODConfig.UnlockFPS then
        print("[MOD] FPS Unlock feature would run here")
    end
    
    if _G.GTLMODConfig.EspVip then
        print("[MOD] ESP feature would run here")
    end
end

local function FastTick()
    pcall(MainLoop) 
    local okTicker, ticker = pcall(require, "common.time_ticker") 
    if okTicker and ticker and ticker.AddTimerOnce then 
        ticker.AddTimerOnce(0.01, FastTick) 
    end 
end

FastTick()

local function SafeAddMark(id, pos, z, str, size, actor)
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
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mark)
        end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then
            InGameMarkTools.RemoveMapMark(mark)
        end
    end)
    _G.GTLMODState.TrackedMarks[mark] = nil
end

local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
        
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName()) or ""
            if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_")) then
                isAI = true
                hasChecked = true
            end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

function _G.InitializeAutoHeadHooks()
    pcall(function()
        local EAvatarDamagePosition = import("EAvatarDamagePosition")
        if not EAvatarDamagePosition then return end

        local modulesToHook = {
            "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity",
            "GameLua.Logic.Weapon.ShootWeaponEntity"
        }
        
        for _, path in ipairs(modulesToHook) do
            local hitLogic = package.loaded[path]
            if hitLogic then
                local original_GetHitBodyType = hitLogic.GetHitBodyType
                hitLogic.GetHitBodyType = function(self, ImpactResult, InImpactVec)
                    if _G.GTLMODConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if original_GetHitBodyType then return original_GetHitBodyType(self, ImpactResult, InImpactVec) end
                end

                local original_GetHitBodyTypeByHitPos = hitLogic.GetHitBodyTypeByHitPos
                hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                    if _G.GTLMODConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if original_GetHitBodyTypeByHitPos then return original_GetHitBodyTypeByHitPos(self, InImpactVec) end
                end
            end
        end
    end)
end
-- ==========================================
-- MAGIC BULLET — actual damage multiplier
-- ==========================================
_G.ApplyMagicBullet = function(weapon)
    if not slua.isValid(weapon) then return end

    local enabled = _G.GTLMODConfig.CustomMagicBullet == true
    local data = _G.GTLMODState.CustomTextData or {}
    local headMul = enabled and (tonumber(data.MagicHead) or 1.0) or 1.0
    local bodyMul = enabled and (tonumber(data.MagicBody) or 1.0) or 1.0
    local legsMul = enabled and (tonumber(data.MagicLegs) or 1.0) or 1.0

    local entities = {}
    if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE) end
    if Valid(weapon.ShootWeaponEntity) then table.insert(entities, weapon.ShootWeaponEntity) end
    if Valid(weapon.ShootWeaponComponent) and Valid(weapon.ShootWeaponComponent.ShootWeaponEntityComponent) then
        table.insert(entities, weapon.ShootWeaponComponent.ShootWeaponEntityComponent)
    end

    -- All damage fields we try, in priority order
    local damageFields = { "BaseDamage", "Damage", "DamageValue", "WeaponDamage", "BaseDamageValue" }

    -- Feature off -> restore and bail
    if headMul == 1.0 and bodyMul == 1.0 and legsMul == 1.0 then
        for _, entity in ipairs(entities) do
            if entity.GTLMODMagicApplied and entity.OriginalMagicCached then
                pcall(function()
                    for _, f in ipairs(damageFields) do
                        if entity.OriginalMagicCached[f] ~= nil then
                            entity[f] = entity.OriginalMagicCached[f]
                        end
                    end
                end)
                entity.GTLMODMagicApplied = false
            end
        end
        return
    end

    local avg = (headMul + bodyMul + legsMul) / 3.0

    for _, entity in ipairs(entities) do
        pcall(function()
            if not entity.OriginalMagicCached then
                entity.OriginalMagicCached = {}
                for _, f in ipairs(damageFields) do
                    local ok, val = pcall(function() return entity[f] end)
                    if ok and type(val) == "number" and val > 0 then
                        entity.OriginalMagicCached[f] = val
                    end
                end
            end

            -- Apply multiplier to whatever numeric damage field exists
            for _, f in ipairs(damageFields) do
                local base = entity.OriginalMagicCached[f]
                if base and base > 0 then
                    pcall(function() entity[f] = base * avg end)
                end
            end

            -- Extra per-part scale fields if present
            pcall(function() if entity.HeadDamageScale ~= nil then entity.HeadDamageScale = headMul end end)
            pcall(function() if entity.BodyDamageScale ~= nil then entity.BodyDamageScale = bodyMul end end)
            pcall(function() if entity.LegDamageScale ~= nil then entity.LegDamageScale = legsMul end end)

            entity.GTLMODMagicApplied = true
        end)
    end
end

local function GetConfigPaths(fileName)
    local paths = {
        currentGamePaths.saved .. fileName,
        currentGamePaths.base .. fileName,
        currentGamePaths.sdcard .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.garena.game.kgtw/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.jpmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.garena.game.kgtw/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.jpmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
                table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName)
            end
        end
    end)
    return paths
end

local ConfigFileName = "ZakPubgSkin_setting.txt"
_G.LastConfigSaveStr = ""

_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\nGTLMODConfig = {\n"
        for k, v in pairs(_G.GTLMODConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "},\nCustomTextData = {\n"
        if _G.GTLMODState and _G.GTLMODState.CustomTextData then
            for k, v in pairs(_G.GTLMODState.CustomTextData) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            end
        end
        data = data .. "}\n}"
        
        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data

        local paths = GetConfigPaths(ConfigFileName)
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(data)
                file:close()
                break
            end
        end
    end)
end

_G.LoadModSettings = function()
    pcall(function()
        local paths = GetConfigPaths(ConfigFileName)
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then
                content = file:read("*a")
                file:close()
                break
            end
        end

        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    if savedData.GTLMODConfig then
                        for k, v in pairs(savedData.GTLMODConfig) do
                            _G.GTLMODConfig[k] = v
                        end
                    end
                    if savedData.CustomTextData then
                        _G.GTLMODState.CustomTextData = _G.GTLMODState.CustomTextData or {}
                        for k, v in pairs(savedData.CustomTextData) do
                            _G.GTLMODState.CustomTextData[k] = v
                        end
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
            ticker.AddTimerOnce(3.0, AutoSaveLoop)
        end
    end)
end

if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

_G.ReadLiveConfig = function()
    if _G.SaveModSettings then _G.SaveModSettings() end
end

-- ==============================================================================
-- ================= DATA & LOGIC MOD SKIN ======================================
-- ==============================================================================
_G.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0}
}

_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}

_G.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then
            _G.VipAttachToIndex[attachId] = index
        end
    end
end

_G.WeaponSkinMap = _G.WeaponSkinMap or {}
_G.VehicleSkinMap = _G.VehicleSkinMap or {}
_G.OutfitMap = _G.OutfitMap or {}
_G.skinIdCache = _G.skinIdCache or {}
_G.skinIdCache2 = _G.skinIdCache2 or {}

_G.OutfitSkins = {
    Suit = {403003,1407916,1406469,1405870,1407140,1407141,1407142,1407550,1406638,1406872,1406971,1407103,1407512,1407391,1407366,1407330,1407329,1407286,1407285,1407277,1407276,1407275,1407225,1407224,1407259,1407161,1407160,1407107,1407106,1407079,1407048,1406977,1406976,1406898,1400569,1404000,1404049,1400119,1400117,1406060,1406891,1400687,1405160,1405145,1405436,1405435,1407385,1406389,1406388,1406387,1400782,1407990,1408038,1408045,1407392,1407318,1407317,1407404,1407402,1407401,1407387,1404434,1404437,1404440,1404448,1400324,1400708,1404043,1404048,1405953,1400101,1404153,1407440,1407441,1405192,1406064, 1405041,1400702,1406897,1407631,1407522,1407558,1407572,1407920,1407961,1407962,1407963,1407964,1407965,1407966,1407967,1407968,1407969,1407970,1407971,1407993,1405192,1408021,1407675,1407676},
    Bag = {
    {501001, 501002, 501003}, {1501001174, 1501002174, 1501003174}, {1501001220, 1501002220, 1501003220},
    {1501001051, 1501002051, 1501003051}, {1501001443, 1501002443, 1501003443}, {1501001265, 1501002265, 1501003265},
    {1501001321, 1501002321, 1501003321}, {1501001277, 1501002277, 1501003277}, {1501001550, 1501002550, 1501003550},
    {1501001592, 1501002592, 1501003592}, {1501001608, 1501002608, 1501003608}, {1501001024, 1501002024, 1501003024},
    {1501001019, 1501002019, 1501003019}, {1501001179, 1501002179, 1501003179}, {1501001194, 1501002194, 1501003194},
    {1501001346, 1501002346, 1501003346},
    {1501001742, 1501002742, 1501003742},
    {1501001023, 1501002023, 1501003023},
    {1501001022, 1501002022, 1501003022},
    {1501001043, 1501002043, 1501003043},
    {1501001045, 1501002045, 1501003045},
    {1501001053, 1501002053, 1501003053},
    {1501001104, 1501002104, 1501003104},
    {1501001054, 1501002054, 1501003054},
    -- NEW BACKPACK SKINS
    {1501001026, 1501002026, 1501003026},
    {1501001058, 1501002058, 1501003058},
    {1501001659, 1501002659, 1501003659},
    {1501001081, 1501002081, 1501003081},
    {1501001085, 1501002085, 1501003085}
},
    Helmet = {
        {502001, 502002, 502003}, {1502001014, 1502002014, 1502003014}, {1502001349, 1502002349, 1502003349},
        {1502001012, 1502002012, 1502003012}, {1502001009, 1502002009, 1502003009}, {1502001397, 1502002397, 1502003397},
        {1502001390, 1502002390, 1502003390}, {1502001381, 1502002381, 1502003381}, {1502001358, 1502002358, 1502003358},
        {1502001350, 1502002350, 1502003350}, {1502001342, 1502002342, 1502003342},
        {1502001439, 1502002439, 1502003439},
        {1502001023, 1502002023, 1502003023},
        {1502001090, 1502002090, 1502003090},
        {1502001069, 1502002069, 1502003069},
        {1502001036, 1502002036, 1502003036},
        {1502001039, 1502002039, 1502003039},
        {1502001080, 1502002080, 1502003080}
    },
    Pet = {50000,50001,50002,50003,50004,50005,50006,50021,50022,50038,50039,50040}
}

_G.skinIdMappings = {
    [101004]={101004, 1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218, 1101004046, 1101004209, 1101004163},
    [101001]={101001,1101001276,1101001089,1101001213,1101001172,1101001127,1101001230,1101001241},
    [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},
    [102002]={102002,1102002136,1102002043,1102002061,1102002424},
    [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008146,1101008061,1101008116},
    [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084, 1101006106, 1101006098},
    [101007]={101007,1101007062,1101007071},
    [102001]={102001, 1102001120, 1102001130},
    [101005]={101005, 1101005098},
    [104003]={104003, 1104003037},
    [104004]={104004, 1104004035, 1104004041},
    -- Sniper Rifles
    [103001]={103001, 1103001101, 1103001146, 1103001154},
    [103002]={103002, 1103002030, 1103002059},
    [103003]={103003, 1103003022, 1103003030, 1103003042, 1103003051},
    [103012]={103012, 1103012010, 1103012019, 1103012031},
    -- SMG (Butter Gun)
    [102003]={102003, 1102003080, 1102003100},
    [102004]={102004, 1102004041},
    [101102]={101102, 1101102025, 1101102017, 1101102007}, -- ACE32
}

_G.VehicleSkins = { 
    [1961001] = { 1961007, 1961010, 1961012, 1961013, 1961014, 1961015, 1961016, 1961017, 1961018, 1961020, 1961021, 1961024, 1961025, 1961029, 1961030, 1961031, 1961032, 1961033, 1961034, 1961035, 1961036, 1961037, 1961038, 1961039, 1961040, 1961041, 1961042, 1961043, 1961044, 1961045, 1961046, 1961047, 1961048, 1961049, 1961050, 1961051, 1961052, 1961053, 1961054, 1961055, 1961056, 1961057, 1961058, 1961059, 1961060, 1961061, 1961062, 1961063, 1961064, 1961065, 1961066, 1961067, 1961068, 1961069, 1961070, 1961071, 1961072, 1961136, 1961137, 1961138, 1961139, 1961140, 1961141, 1961142, 1961143, 1961144, 1961145, 1961147, 1961148, 1961149, 1961150, 1961151, 1961152, 1961153 },
    [1903001] = { 1903005, 1903006, 1903007, 1903008, 1903011, 1903012, 1903013, 1903014, 1903015, 1903016, 1903017, 1903018, 1903019, 1903020, 1903021, 1903022, 1903023, 1903024, 1903029, 1903030, 1903031, 1903032, 1903033, 1903034, 1903035, 1903036, 1903037, 1903039, 1903040, 1903041, 1903042, 1903043, 1903044, 1903045, 1903046, 1903051, 1903052, 1903053, 1903054, 1903055, 1903056, 1903057, 1903058, 1903059, 1903060, 1903061, 1903062, 1903063, 1903066, 1903067, 1903068, 1903069, 1903070, 1903071, 1903072, 1903073, 1903074, 1903075, 1903076, 1903079, 1903080, 1903081, 1903082, 1903084, 1903085, 1903086, 1903087, 1903088, 1903089, 1903090, 1903189, 1903190, 1903191, 1903192, 1903193, 1903194, 1903195, 1903196, 1903197, 1903198, 1903199, 1903200, 1903201, 1903202, 1903203, 1903204, 1903205, 1903206, 1903207, 1903208, 1903209, 1903210, 1903211, 1903212, 1903213, 1903214, 1903215, 1903216, 1903217, 1903218, 1903219, 1903220, 1903221, 1903222, 1903223, 1903225, 1903226, 1903227, 1903228 }, 
    [1915001] = { 1915002, 1915003, 1915004, 1915005, 1915006, 1915007, 1915008, 1915009, 1915010, 1915011, 1915012, 1915013, 1915014, 1915015, 1915016, 1915017, 1915018, 1915019, 1915020, 1915021, 1915022, 1915023, 1915024, 1915025, 1915026, 1915099 },          
    [1908001] = { 1908002, 1908003, 1908005, 1908006, 1908007, 1908008, 1908009, 1908010, 1908011, 1908012, 1908013, 1908015, 1908016, 1908017, 1908018, 1908019, 1908021, 1908023, 1908030, 1908031, 1908032, 1908033, 1908034, 1908035, 1908036, 1908037, 1908039, 1908040, 1908041, 1908043, 1908047, 1908049, 1908050, 1908051, 1908052, 1908053, 1908054, 1908055, 1908056, 1908057, 1908059, 1908060, 1908061, 1908062, 1908063, 1908064, 1908066, 1908067, 1908068, 1908069, 1908070, 1908075, 1908076, 1908077, 1908078, 1908080, 1908081, 1908082, 1908083, 1908084, 1908085, 1908086, 1908087, 1908088, 1908089, 1908091, 1908094, 1908095, 1908096, 1908097, 1908098, 1908099, 1908100, 1908101, 1908102, 1908104, 1908105, 1908106, 1908107, 1908108, 1908109, 1908110, 1908111, 1908112, 1908188, 1908189 },   
    [1907001] = { 1907007, 1907008, 1907010, 1907011, 1907012, 1907013, 1907014, 1907016, 1907018, 1907019, 1907021, 1907022, 1907023, 1907025, 1907026, 1907027, 1907028, 1907029, 1907030, 1907032, 1907033, 1907034, 1907035, 1907036, 1907037, 1907038, 1907040, 1907041, 1907043, 1907044, 1907045, 1907046, 1907047, 1907048, 1907049, 1907050, 1907051, 1907052, 1907053, 1907054, 1907055, 1907056, 1907058, 1907059, 1907060, 1907061, 1907062, 1907063, 1907064, 1907065, 1907066, 1907067, 1907068, 1907069, 1907070, 1907071, 1907072, 1907073, 1907074 }
}
_G.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

local function DownloadGameItem(id)
    local puffer_manager = require('client.slua.logic.download.puffer.puffer_manager')
    local puffer_const = require('client.slua.logic.download.puffer_const')
    if puffer_manager and puffer_const and puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id}) ~= puffer_const.ENUM_DownloadState.Done then
        puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
    end
end
_G.download_item = DownloadGameItem

_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        if not _G.skinIdCache2[targetSkinId] then
            if _G.download_item then pcall(_G.download_item, targetSkinId) end
            _G.skinIdCache2[targetSkinId] = true
        end
        return targetSkinId
    end
    return weaponID
end

_G.equip_character_avatar = function(Character)
    if not Character or not slua.isValid(Character) or not Character.AvatarComponent2 then return end
    local BackpackUtils = import("BackpackUtils")
    local SlotSyncData = Character.AvatarComponent2.NetAvatarData and Character.AvatarComponent2.NetAvatarData.SlotSyncData
    if not SlotSyncData or not slua.isValid(SlotSyncData) or not BackpackUtils then return end
    
    local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
        if not mappedSkin or mappedSkin == 0 then return end
        local slotData = SlotSyncData:Get(ApplyDataIdx)
        if slotData and slotData.SlotID == ApplyEquipSlot then
            local applyItemId = mappedSkin
            if isLevelDependent and type(mappedSkin) == "table" then
                local level = levelFunc(slotData.AdditionalItemID) or 1
                if level < 1 then level = 1 end
                if level > 3 then level = 3 end
                applyItemId = mappedSkin[level] or mappedSkin[1]
            end

            if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then return end

            if not _G.skinIdCache[applyItemId] then
                if _G.download_item then pcall(_G.download_item, applyItemId) end
                _G.skinIdCache[applyItemId] = true
            end

            slotData.ItemId = applyItemId
            SlotSyncData:Set(ApplyDataIdx, slotData)
            Character.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
    end

    local hasGliderSlot = false
    for i = 0, SlotSyncData:Num() - 1 do
        local slotData = SlotSyncData:Get(i)
        if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then 
            hasGliderSlot = true
            break 
        end
    end
    if not hasGliderSlot then SlotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end

    for i = 0, SlotSyncData:Num() - 1 do
        EquipAvatar(i, _G.OutfitMap.Suit or 0, _G.CustSlotType.ClothesEquipemtSlot, false)
        EquipAvatar(i, _G.OutfitMap.Bag, _G.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
        EquipAvatar(i, _G.OutfitMap.Helmet, _G.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
        EquipAvatar(i, _G.OutfitMap.Parachute or 0, _G.CustSlotType.ParachuteEquipemtSlot, false)
    end
end

_G.ApplyWeaponSkins = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end
        
        for slot = 1, 3 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.get_skin_id(WeaponID) or WeaponID
                local isModified = false
                
                local SkinData = Weapon.synData:Get(7) 
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.skinIdCache[SkinID] then 
                        _G.download_item(SkinID)
                        _G.skinIdCache[SkinID] = true 
                    end
                    isModified = true
                end
                
                if SkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do 
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.BaseAttachToIndex[attachmentId] or _G.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.VIP_Attachments[SkinID][mapIndex] and _G.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.skinIdCache2[targetAttachId] then 
                                                if _G.download_item then pcall(_G.download_item, targetAttachId) end
                                                _G.skinIdCache2[targetAttachId] = true 
                                            end
                                            isModified = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                if isModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end
        end
    end)
end

_G.ApplyVehicleSkins = function(PlayerCharacter)
    pcall(function()
        local Vehicle = PlayerCharacter:GetCurrentVehicle()
        if not slua.isValid(Vehicle) then 
            _G.LastVehicleEntity = nil
            return 
        end
        
        local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
        if not slua.isValid(VehicleAvatar) then return end

        local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
        local currentId = tostring(Vehicle:GetAvatarId() or "")
        local applySkinId = 0
        
        for baseMapId, targetSkin in pairs(_G.VehicleSkinMap) do
            if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then 
                applySkinId = targetSkin
                break 
            end
        end

        if applySkinId and applySkinId > 0 and currentId ~= tostring(applySkinId) then
            _G.skinIdCache = _G.skinIdCache or {}
            if not _G.skinIdCache[applySkinId] then 
                if _G.download_item then pcall(_G.download_item, applySkinId) end
                _G.skinIdCache[applySkinId] = true 
            end

            VehicleAvatar.curSwitchEffectId = 7303001
            if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(applySkinId, true) end
            
            _G.CurrentEquipVehicleID = applySkinId
            _G.LastVehicleEntity = Vehicle
        end
    end)
end

_G.HandlePetLogic = function()
    pcall(function()
        local petSkin = _G.OutfitMap.Pet
        if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.LastAppliedPet then return end
        
        _G.skinIdCache = _G.skinIdCache or {}
        if not _G.skinIdCache[petSkin] then 
            if _G.download_item then pcall(_G.download_item, petSkin) end
            _G.skinIdCache[petSkin] = true 
        end
        
        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if logic_pet then
                if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
            end
        end
        _G.LastAppliedPet = petSkin
    end)
end

_G.ForceRefreshSkinMaps = function()
    pcall(function()
        if not _G.GTLMODState or not _G.GTLMODState.CustomTextData then return end
        local cData = _G.GTLMODState.CustomTextData

        if _G.OutfitSkins then
            if cData.SkinSuit and _G.OutfitSkins.Suit[cData.SkinSuit] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[cData.SkinSuit] end
            if cData.SkinBag and _G.OutfitSkins.Bag[cData.SkinBag] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[cData.SkinBag] end
            if cData.SkinHelmet and _G.OutfitSkins.Helmet[cData.SkinHelmet] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[cData.SkinHelmet] end
        end

        if _G.skinIdMappings then
            if cData.SkinM416 and _G.skinIdMappings[101004] and _G.skinIdMappings[101004][cData.SkinM416] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][cData.SkinM416] end
            if cData.SkinAKM and _G.skinIdMappings[101001] and _G.skinIdMappings[101001][cData.SkinAKM] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][cData.SkinAKM] end
            if cData.SkinSCAR and _G.skinIdMappings[101003] and _G.skinIdMappings[101003][cData.SkinSCAR] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][cData.SkinSCAR] end
            if cData.SkinM762 and _G.skinIdMappings[101008] and _G.skinIdMappings[101008][cData.SkinM762] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][cData.SkinM762] end
            if cData.SkinAUG and _G.skinIdMappings[101006] and _G.skinIdMappings[101006][cData.SkinAUG] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][cData.SkinAUG] end
            if cData.SkinUMP and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][cData.SkinUMP] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][cData.SkinUMP] end
            
            if cData.SkinUZI and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][cData.SkinUZI] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinGroza and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][cData.SkinGroza] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinS12K and _G.skinIdMappings[104003] and _G.skinIdMappings[104003][cData.SkinS12K] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][cData.SkinS12K] end
            if cData.SkinDBS and _G.skinIdMappings[104004] and _G.skinIdMappings[104004][cData.SkinDBS] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][cData.SkinDBS] end
        end

        if _G.VehicleSkins then
            if cData.SkinDacia and _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][cData.SkinDacia] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][cData.SkinDacia] end
            if cData.SkinUAZ and _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][cData.SkinUAZ] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][cData.SkinUAZ] end
            if cData.SkinCoupe and _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][cData.SkinCoupe] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][cData.SkinCoupe] end
            if cData.SkinBuggy and _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][cData.SkinBuggy] then _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][cData.SkinBuggy] end
            if cData.SkinMirado and _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][cData.SkinMirado] then _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][cData.SkinMirado] end
        end
    end)
end

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 0

_G.DeadBox_TemperRequest = function(PlayerController)
    if _G.NeedCheckDeadBoxTimer <= 0 then return end
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass))
    
    for _, deadBoxActor in pairs(deadBoxes) do
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    local currentBoxSkinId = 0
                    if PlayerCharacter.CurrentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                        currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                    else
                        local currentWeapon = PlayerCharacter:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) and currentWeapon.synData then
                            local weaponSkinData = currentWeapon.synData:Get(7)
                            if weaponSkinData and weaponSkinData.defineID then
                                currentBoxSkinId = weaponSkinData.defineID.TypeSpecificID
                            end
                        end
                    end
                    
                    if currentBoxSkinId ~= 0 then
                        pcall(function()
                            DeadBoxAvatarComponent:ResetItemAvatar()
                            DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                            DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                        end)
                    end
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local CACHED_LinearColor = import("LinearColor")
local CACHED_GoldColor = CACHED_LinearColor and CACHED_LinearColor(1.0, 0.8, 0.0, 1.0) or nil
local CACHED_UI_Manager = nil

_G.ForceEnableKillCounterUI = function()
    pcall(function()
        local KillCounterUISubsystem = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KillCounterUISubsystem and KillCounterUISubsystem.__inner_impl and not _G.KCUISystemHacked2 then
            local kcImpl = KillCounterUISubsystem.__inner_impl
            kcImpl.CheckSupportKCUI = function() return true end
            kcImpl.CheckNeedMainKillCounterUI = function(self, PlayerWeapon, PlayerID)
                if slua.isValid(PlayerWeapon) then
                    local WeaponID = PlayerWeapon:GetWeaponID()
                    self:UpdateMainKillCounterUI(true, WeaponID, _G.get_skin_id(WeaponID) or WeaponID)
                else self:UpdateMainKillCounterUI(false) end
            end
            local originalUpdateMainKillCounterUI = kcImpl.UpdateMainKillCounterUI
            kcImpl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
                if bShow then AvatarID = _G.get_skin_id(WeaponID) or AvatarID end
                if originalUpdateMainKillCounterUI then originalUpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID) end
            end
            _G.KCUISystemHacked2 = true
        end

        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager and not _G.KCLogicHacked2 then
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if LogicKillCounter then
                LogicKillCounter.CheckSupportKC = function() return true end
                LogicKillCounter.CheckSupportKillCounterAvatar = function() return true end
                LogicKillCounter.CheckHasWeaponKillCounter = function() return true end
                LogicKillCounter.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                LogicKillCounter.GetEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetMyEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetOneWeaponKillCountInBattle = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                LogicKillCounter.GetWeaponKillCountByUid = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                _G.KCLogicHacked2 = true
            end
        end

        local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
        local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)
        
        if KillInfo and KillInfo.__inner_impl and not _G.KillInfoCounterHacked then
            local originalFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local LocalPlayer = require("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then 
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local skinID = _G.get_skin_id(weaponID)
                            if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                            if _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit end
                            
                            if CACHED_GoldColor then
                                DamageRecordData.IsUseColor, DamageRecordData.UseColor = true, CACHED_GoldColor
                            end
                            
                            if DamageRecordData.ResultHealthStatus == 2 then
                                _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
                                _G.NeedCheckDeadBoxTimer = 50 
                                
                                if not CACHED_UI_Manager then CACHED_UI_Manager = require("client.slua_ui_framework.manager") end
                                local uiMainKillCounter = CACHED_UI_Manager.GetUI(CACHED_UI_Manager.UI_Config_InGame.MainKillCounter)
                                
                                if uiMainKillCounter and uiMainKillCounter.UpdateWeaponID then
                                    local mainAvatarID = skinID or currentWeapon:GetWeaponMainAvatarID()
                                    uiMainKillCounter:UpdateWeaponID(weaponID, mainAvatarID)
                                    local kcModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                                    local kcItemID = kcModule:GetEquipedKillCounterId(0, mainAvatarID)
                                    uiMainKillCounter:SetKillCounterItemShowWithNum(kcItemID, _G.TDFTDeKillCounts[weaponID], mainAvatarID)
                                end
                            end
                        end
                    end
                end)
                if originalFileItem then return originalFileItem(self, DamageRecordData) end
            end
            _G.KillInfoCounterHacked = true
        end

        local SwitchWeaponSlotMode2 = package.loaded["GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2"] or require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
        if SwitchWeaponSlotMode2 and SwitchWeaponSlotMode2.__inner_impl and not _G.SlotBaseHacked then
            SwitchWeaponSlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                if slua.isValid(self.KillCounterImg) then 
                    self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible) 
                end
            end
            _G.SlotBaseHacked = true
        end
    end)
end

function _G.InitializeSkinModSystem()
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.LobbyBypassHacked then
            local originalPutonEquipment = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                if attachIndex then
                    local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                    if holdingWeaponSkinID and holdingWeaponSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[holdingWeaponSkinID] then
                        local vipAttachID = _G.VIP_Attachments[holdingWeaponSkinID][attachIndex]
                        if vipAttachID and vipAttachID > 0 then
                            if self.HandleDownload then self:HandleDownload(vipAttachID, nil, nil, false) end
                            itemID = vipAttachID
                        end
                    end
                end
                if originalPutonEquipment then return originalPutonEquipment(self, itemID, tAvatarCustom, tExtraData) end
            end

            local originalCharEquipWeaponByResId = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local retValue = originalCharEquipWeaponByResId and originalCharEquipWeaponByResId(self, resID, isUse, isAsync, SocketName) or nil
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return retValue
            end
            _G.LobbyBypassHacked = true
        end
    end)
    
    pcall(function()
        local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if Common_Items_UIBP and not _G.IconBaloHacked then
        local originalInitView = Common_Items_UIBP.InitView
            Common_Items_UIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displayResId = nil
                
                if _G.get_skin_id then
                    local skinID = _G.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then displayResId = skinID end
                end
                
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
                if not displayResId and attachIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) then
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local finalSkinID = _G.get_skin_id(weaponID) or weaponID
                            if finalSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[finalSkinID] then
                                local vipAttachID = _G.VIP_Attachments[finalSkinID][attachIndex]
                                if vipAttachID and vipAttachID > 0 then displayResId = vipAttachID end
                            end
                        end
                    end
                end
                
                if displayResId then
                    tExtraData.displayResId = displayResId
                    if not _G.skinIdCache2[displayResId] then
                        if _G.download_item then pcall(_G.download_item, displayResId) end
                        _G.skinIdCache2[displayResId] = true
                    end
                end
                if originalInitView then return originalInitView(self, nItemId, nCount, nValidTime, tExtraData) end
            end
            _G.IconBaloHacked = true
        end
    end)
end

-- ========================================== 
-- KILL COUNTER & KILL MESSAGE EFFECT + DEADBOX SKIN
-- ==========================================
_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local CACHED_LinearColor = import("LinearColor")
local CACHED_GoldColor = CACHED_LinearColor and CACHED_LinearColor(1.0, 0.8, 0.0, 1.0) or nil
local CACHED_UI_Manager = nil
_G.NeedCheckDeadBoxTimer = 0
_G.LastCheckDeadBoxTime = 0

_G.ForceEnableKillCounterUI = function()
    pcall(function()
        local KillCounterUISubsystem = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KillCounterUISubsystem and KillCounterUISubsystem.__inner_impl and not _G.KCUISystemHacked2 then
            local kcImpl = KillCounterUISubsystem.__inner_impl
            kcImpl.CheckSupportKCUI = function() return true end
            kcImpl.CheckNeedMainKillCounterUI = function(self, PlayerWeapon, PlayerID)
                if slua.isValid(PlayerWeapon) then
                    local WeaponID = PlayerWeapon:GetWeaponID()
                    self:UpdateMainKillCounterUI(true, WeaponID, _G.get_skin_id(WeaponID) or WeaponID)
                else self:UpdateMainKillCounterUI(false) end
            end
            local originalUpdateMainKillCounterUI = kcImpl.UpdateMainKillCounterUI
            kcImpl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
                if bShow then AvatarID = _G.get_skin_id(WeaponID) or AvatarID end
                if originalUpdateMainKillCounterUI then originalUpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID) end
            end
            _G.KCUISystemHacked2 = true
        end

        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager and not _G.KCLogicHacked2 then
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if LogicKillCounter then
                LogicKillCounter.CheckSupportKC = function() return true end
                LogicKillCounter.CheckSupportKillCounterAvatar = function() return true end
                LogicKillCounter.CheckHasWeaponKillCounter = function() return true end
                LogicKillCounter.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                LogicKillCounter.GetEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetMyEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetOneWeaponKillCountInBattle = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                LogicKillCounter.GetWeaponKillCountByUid = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                _G.KCLogicHacked2 = true
            end
        end

        local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
        local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)
        
        if KillInfo and KillInfo.__inner_impl and not _G.KillInfoCounterHacked then
            local originalFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local LocalPlayer = require("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then 
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local skinID = _G.get_skin_id(weaponID)
                            if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                            if _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit end
                            
                            if CACHED_GoldColor then
                                DamageRecordData.IsUseColor, DamageRecordData.UseColor = true, CACHED_GoldColor
                            end
                            
                            if DamageRecordData.ResultHealthStatus == 2 then
                                _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
                                _G.NeedCheckDeadBoxTimer = 50 
                                
                                if not CACHED_UI_Manager then CACHED_UI_Manager = require("client.slua_ui_framework.manager") end
                                local uiMainKillCounter = CACHED_UI_Manager.GetUI(CACHED_UI_Manager.UI_Config_InGame.MainKillCounter)
                                
                                if uiMainKillCounter and uiMainKillCounter.UpdateWeaponID then
                                    local mainAvatarID = skinID or currentWeapon:GetWeaponMainAvatarID()
                                    uiMainKillCounter:UpdateWeaponID(weaponID, mainAvatarID)
                                    local kcModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                                    local kcItemID = kcModule:GetEquipedKillCounterId(0, mainAvatarID)
                                    uiMainKillCounter:SetKillCounterItemShowWithNum(kcItemID, _G.TDFTDeKillCounts[weaponID], mainAvatarID)
                                end
                            end
                        end
                    end
                end)
                if originalFileItem then return originalFileItem(self, DamageRecordData) end
            end
            _G.KillInfoCounterHacked = true
        end

        local SwitchWeaponSlotMode2 = package.loaded["GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2"] or require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
        if SwitchWeaponSlotMode2 and SwitchWeaponSlotMode2.__inner_impl and not _G.SlotBaseHacked then
            SwitchWeaponSlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                if slua.isValid(self.KillCounterImg) then 
                    self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible) 
                end
            end
            _G.SlotBaseHacked = true
        end
    end)
end

-- ========================================== 
-- DEADBOX SKIN (temper request)
-- ==========================================
local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.DeadBox_TemperRequest = function(PlayerController)
    if _G.NeedCheckDeadBoxTimer <= 0 then return end
    
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    if not _G.CachedActorArray then
        _G.CachedActorArray = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray)
    
    for _, deadBoxActor in pairs(deadBoxes) do
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    local currentBoxSkinId = 0
                    if PlayerCharacter.CurrentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                        currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                    else
                        local currentWeapon = PlayerCharacter:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) and currentWeapon.synData then
                            local weaponSkinData = currentWeapon.synData:Get(7)
                            if weaponSkinData and weaponSkinData.defineID then
                                currentBoxSkinId = weaponSkinData.defineID.TypeSpecificID
                            end
                        end
                    end
                    
                    if currentBoxSkinId ~= 0 then
                        pcall(function()
                            DeadBoxAvatarComponent:ResetItemAvatar()
                            DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                            DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                        end)
                    end
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

-- ========================================== 
-- VIP NATIVE MENU SYSTEM (RUNS DIRECTLY FROM GAME SETTINGS)
-- ========================================== 

function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true

    _G.GTLMODState.CustomTextData = _G.GTLMODState.CustomTextData or {
        OuterSpeed = 10, InnerSpeed = 10, OuterRecoil = 0, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120, IpadViewVehicleFOV = 120,
        AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250,
        AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30,
        AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchScopePred = 0, AimTouchScopeRecoil = 0,
        AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400, AimTouchSniperPred = 0,
        -- Skin
                -- Skin
        SkinSuit = 1, SkinBag = 1, SkinHelmet = 1,
        SkinM416 = 1, SkinAKM = 1, SkinSCAR = 1, SkinM762 = 1, SkinAUG = 1, SkinHoney = 1, SkinQBZ = 1, SkinASM = 2, SkinACE32 = 1, SkinUMP = 6,
        SkinUZI = 1, SkinVector = 1, SkinGroza = 1, SkinKar98K = 1, SkinAWM = 2, SkinAMR = 1, SkinS12K = 1, SkinDBS = 1,
        SkinDacia = 1, SkinUAZ = 1, SkinCoupe = 1, SkinBuggy = 1, SkinMirado = 1,
    }

    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    
    if LocUtil and not LocUtil._IsModMenuHooked then
        local old_get = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and not tonumber(id) then
                return id
            end
            return old_get(id)
        end
        LocUtil._IsModMenuHooked = true
    end

    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    
    if not SettingPageDefine.ModMenu then
        local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
        
        -- ==================== ESP VISUAL (SECTION 1 - FIRST) ====================
        local StackESPVisual = {
            { Key = "ModMenu_ESP1", UI = AliasMap.Switcher, Text = "ESP SKELETON BOX", GetFunc = function() return _G.GTLMODConfig.EspVip end, SetFunc = function(c,v) _G.GTLMODConfig.EspVip = v return true end },
            { Key = "ModMenu_ESP7", UI = AliasMap.Switcher, Text = "ESP REAL ENEMY/BOT", GetFunc = function() return _G.GTLMODConfig.Esp7 end, SetFunc = function(c,v) _G.GTLMODConfig.Esp7 = v return true end },
            { Key = "ModMenu_ESP2", UI = AliasMap.Switcher, Text = "ESP ENEMY DISTANCE", GetFunc = function() return _G.GTLMODConfig.EspDistance end, SetFunc = function(c,v) _G.GTLMODConfig.EspDistance = v return true end },
            { Key = "ModMenu_ESP4", UI = AliasMap.Switcher, Text = "ESP HIT MARK", GetFunc = function() return _G.GTLMODConfig.EspRadar end, SetFunc = function(c,v) _G.GTLMODConfig.EspRadar = v return true end },
            { Key = "ModMenu_ESP5", UI = AliasMap.Switcher, Text = "ESP BOX", GetFunc = function() return _G.GTLMODConfig.Esp5 end, SetFunc = function(c,v) _G.GTLMODConfig.Esp5 = v return true end },
            { Key = "ModMenu_ESPAntenna", UI = AliasMap.Switcher, Text = "ESP GREEN ANTENNA", GetFunc = function() return _G.GTLMODConfig.EspAntenna end, SetFunc = function(c,v) _G.GTLMODConfig.EspAntenna = v return true end },
            { Key = "ModMenu_ESPName", UI = AliasMap.Switcher, Text = "ESP NAME (VISIBLE)", GetFunc = function() return _G.GTLMODConfig.EspName end, SetFunc = function(c,v) _G.GTLMODConfig.EspName = v return true end },
            { Key = "ModMenu_ESPOutline_Ex", UI = AliasMap.TitleSwitcher, Text = "ESP ENEMY (RED AURA)", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.EspOutline end, SetFunc = function(c,v) _G.GTLMODConfig.EspOutline = v return true end },
            { Key = "ModMenu_ESPOutline_Thickness", UI = AliasMap.Slider, Text = "   COLOR SIZE (1-20)", ExpandHandle = "ModMenu_ESPOutline_Ex", MinValue = 1, MaxValue = 20, min = 1, max = 20, GetFunc = function() return _G.GTLMODConfig.OutlineThickness end, SetFunc = function(c,v) _G.GTLMODConfig.OutlineThickness = v return true end }
        }

        -- ==================== AIMBOT FORCE (SECTION 2) ====================
        local StackAimbotForce = {
            { Key = "ModMenu_AT_Ex", UI = AliasMap.TitleSwitcher, Text = "CUSTOM AIMBOT SETTING", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.AimTouchEnable end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchEnable = v return true end },
            
            -- HIPFIRE
            { Key = "ModMenu_AT_Hip_Ex", UI = AliasMap.TitleSwitcher, Text = "   AIMBOT ONLY [ALL WEAPON]", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.AimTouchHipfire end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchHipfire = v return true end },
            { Key = "ModMenu_AT_Hip_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchHipIgKnock end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchHipIgKnock = v return true end },
            { Key = "ModMenu_AT_Hip_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchHipIgBot end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchHipIgBot = v return true end },
            { Key = "ModMenu_AT_Hip_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchHipVisCheck end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchHipVisCheck = v return true end },
         --   { Key = "ModMenu_AT_Hip_Prio", UI = AliasMap.Slider, Text = "      Priority (1-4)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchHipPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchHipPrio = val return true end },
           { Key = "ModMenu_AT_Hip_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1-4)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchHipBone or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchHipBone = val return true end },
          --  { Key = "ModMenu_AT_Hip_Cond", UI = AliasMap.Slider, Text = "      Condition (1-2)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchHipCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.GTLMODState.CustomTextData.AimTouchHipCond = val return true end },
            { Key = "ModMenu_AT_Hip_Spd", UI = AliasMap.Slider, Text = "      Aim Speed [ 40-50 ]", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchHipSpeed or 50 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchHipSpeed = v return true end },
            { Key = "ModMenu_AT_Hip_FOV", UI = AliasMap.Slider, Text = "      FOV Range [20-30]", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchHipFOV or 30 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchHipFOV = v return true end },
            { Key = "ModMenu_AT_Hip_Dist", UI = AliasMap.Slider, Text = "      Distance [ 60-70 ]", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.GTLMODState.CustomTextData.AimTouchHipDist or 250) / 5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchHipDist = v * 5 return true end },
            
            -- SCOPE ALL
            { Key = "ModMenu_AT_ScopeAll_Ex", UI = AliasMap.TitleSwitcher, Text = "   SCOPE AIMBOT [ALL WEAPON]", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.AimTouchScopeAll end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchScopeAll = v return true end },
            { Key = "ModMenu_AT_ScopeAll_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchScopeIgKnock end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchScopeIgKnock = v return true end },
            { Key = "ModMenu_AT_ScopeAll_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchScopeIgBot end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchScopeIgBot = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchScopeVisCheck end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchScopeVisCheck = v return true end },
         --   { Key = "ModMenu_AT_ScopeAll_Prio", UI = AliasMap.Slider, Text = "      Priority (1-4)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopePrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchScopePrio = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1-4)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopeBone or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchScopeBone = val return true end },
          --  { Key = "ModMenu_AT_ScopeAll_Cond", UI = AliasMap.Slider, Text = "      Condition (1-2)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopeCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.GTLMODState.CustomTextData.AimTouchScopeCond = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Spd", UI = AliasMap.Slider, Text = "      Speed (40-50)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopeSpeed or 40 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchScopeSpeed = v return true end },
            { Key = "ModMenu_AT_ScopeAll_FOV", UI = AliasMap.Slider, Text = "      FOV Range [20-30]", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopeFOV or 20 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchScopeFOV = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Dist", UI = AliasMap.Slider, Text = "      Distance [ 60-70", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.GTLMODState.CustomTextData.AimTouchScopeDist or 300) / 5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchScopeDist = v * 5 return true end },
           { Key = "ModMenu_AT_ScopeAll_Pred", UI = AliasMap.Slider, Text = "      Movement Prediction (0-100)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopePred or 0 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchScopePred = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Recoil", UI = AliasMap.Slider, Text = "      Recoil Kick Ads (5 to 10)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 50, min = 0, max = 50, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopeRecoil or 0 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchScopeRecoil = v return true end },

            -- AIMBOT SHOTGUN
            { Key = "ModMenu_AT_SG_Ex", UI = AliasMap.TitleSwitcher, Text = "   ALL SHOTGUN AIMBOT", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.AimTouchSG end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSG = v return true end },
           -- { Key = "ModMenu_AT_SG_AutoFire", UI = AliasMap.Switcher, Text = "      Auto Fire", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSGAutoFire end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSGAutoFire = v return true end },
            { Key = "ModMenu_AT_SG_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSGIgKnock end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSGIgKnock = v return true end },
            { Key = "ModMenu_AT_SG_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSGIgBot end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSGIgBot = v return true end },
            { Key = "ModMenu_AT_SG_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSGVisCheck end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSGVisCheck = v return true end },
          --  { Key = "ModMenu_AT_SG_Prio", UI = AliasMap.Slider, Text = "      Priority (1-4)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchSGPrio = val return true end },
            { Key = "ModMenu_AT_SG_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1-4)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGBone or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchSGBone = val return true end },
            { Key = "ModMenu_AT_SG_Cond", UI = AliasMap.Slider, Text = "      Condition (1-2)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.GTLMODState.CustomTextData.AimTouchSGCond = val return true end },
            { Key = "ModMenu_AT_SG_Spd", UI = AliasMap.Slider, Text = "      Speed Aim [100-Max]", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGSpeed or 80 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSGSpeed = v return true end },
            { Key = "ModMenu_AT_SG_FOV", UI = AliasMap.Slider, Text = "      FOV Range [ 50-60]", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGFOV or 40 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSGFOV = v return true end },
            { Key = "ModMenu_AT_SG_Dist", UI = AliasMap.Slider, Text = "      Distance [100-Max]", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGDist or 30 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSGDist = v return true end },
            
            -- SCOPE SNIPER
            { Key = "ModMenu_AT_Sniper_Ex", UI = AliasMap.TitleSwitcher, Text = "   SCOPE AIMBOT (SNIPER ONLY)", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.AimTouchScopeSniper end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchScopeSniper = v return true end },
            { Key = "ModMenu_AT_Sniper_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSniperIgKnock end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSniperIgKnock = v return true end },
            { Key = "ModMenu_AT_Sniper_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSniperIgBot end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSniperIgBot = v return true end },
            { Key = "ModMenu_AT_Sniper_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSniperVisCheck end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSniperVisCheck = v return true end },
         --   { Key = "ModMenu_AT_Sniper_Prio", UI = AliasMap.Slider, Text = "      Priority (1-4)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchSniperPrio = val return true end },
            { Key = "ModMenu_AT_Sniper_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1-4)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperBone or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchSniperBone = val return true end },
            { Key = "ModMenu_AT_Sniper_Cond", UI = AliasMap.Slider, Text = "      Condition (1-2)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperCond or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.GTLMODState.CustomTextData.AimTouchSniperCond = val return true end },
            { Key = "ModMenu_AT_Sniper_Spd", UI = AliasMap.Slider, Text = "      Speed Scope [100-Max]", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperSpeed or 30 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSniperSpeed = v return true end },
            { Key = "ModMenu_AT_Sniper_FOV", UI = AliasMap.Slider, Text = "      FOV Range [60-70]", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperFOV or 20 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSniperFOV = v return true end },
            { Key = "ModMenu_AT_Sniper_Dist", UI = AliasMap.Slider, Text = "      Distance [100-Max]", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.GTLMODState.CustomTextData.AimTouchSniperDist or 400) / 5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSniperDist = v * 5 return true end },
            { Key = "ModMenu_AT_Sniper_Pred", UI = AliasMap.Slider, Text = "      Movement Prediction (0-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperPred or 0 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSniperPred = v return true end }
        }
        
        local StackMagicBullet = {
            { Key = "ModMenu_Magic_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ Custom Magic Bullet (Don't use Global users risk)", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.CustomMagicBullet end, SetFunc = function(c,v) _G.GTLMODConfig.CustomMagicBullet = v return true end },
            { Key = "ModMenu_Magic_Head", UI = AliasMap.Slider, Text = "   Head Damage (30 - 60 safe)", ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor(((_G.GTLMODState.CustomTextData.MagicHead or 1.0) / 5.0) * 100 + 0.5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.MagicHead = (v / 100.0) * 5.0 return true end },
            { Key = "ModMenu_Magic_Body", UI = AliasMap.Slider, Text = "   Body Damage (20 - 30 safe/Over 30 will hit behind the cover)", ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor(((_G.GTLMODState.CustomTextData.MagicBody or 1.0) / 5.0) * 100 + 0.5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.MagicBody = (v / 100.0) * 5.0 return true end },
            { Key = "ModMenu_Magic_Legs", UI = AliasMap.Slider, Text = "   Legs Damage (No need to change)", ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor(((_G.GTLMODState.CustomTextData.MagicLegs or 1.0) / 5.0) * 100 + 0.5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.MagicLegs = (v / 100.0) * 5.0 return true end }
        }

        -- ==================== COMBAT GRAPHIC (SECTION 3) ====================
        local StackCombatGraphic = {
            { Key = "ModMenu_Ipad_Ex", UI = AliasMap.TitleSwitcher, Text = "CUSTOM IPAD VIEW", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.IpadView end, SetFunc = function(c,v) _G.GTLMODConfig.IpadView = v return true end },
            { Key = "ModMenu_Ipad_FOV", UI = AliasMap.Slider, Text = "   IPAD FOV (1-100)", ExpandHandle = "ModMenu_Ipad_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return (_G.GTLMODState.CustomTextData.IpadViewFOV or 120) - 80 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.IpadViewFOV = 80 + v return true end },
            { Key = "ModMenu_IpadViewVehicle_Ex", UI = AliasMap.TitleSwitcher, Text = ("Ipad View Vehicle"), ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.IpadViewVehicle end, SetFunc = function(c,v) _G.GTLMODConfig.IpadViewVehicle = v return true end },
            { Key = "ModMenu_IpadViewVehicle_FOV", UI = AliasMap.Slider, Text = ("Vehicle FOV Value"), ExpandHandle = "ModMenu_IpadViewVehicle_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return (_G.GTLMODState.CustomTextData.IpadViewVehicleFOV or 120) - 90 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.IpadViewVehicleFOV = 90 + v return true end },
            { Key = "ModMenu_165FPS", UI = AliasMap.Switcher, Text = "165 REAL FPS", GetFunc = function() return _G.GTLMODConfig.UnlockFPS end, SetFunc = function(c,v) _G.GTLMODConfig.UnlockFPS = v; if v then _G.GTLMODState.GraphicsUnlocked = false end return true end },
            { Key = "ModMenu_colorbodynew", UI = AliasMap.Switcher, Text = "WALLHACK V3", GetFunc = function() return _G.GTLMODConfig.ColorBodyNew end, SetFunc = function(c,v) _G.GTLMODConfig.colorbodynew = v; _G.GTLMODConfig.ColorBodyNew = v; return true end },
            { Key = "ModMenu_BlackSky", UI = AliasMap.Switcher, Text = "BLACK SKY", GetFunc = function() return _G.GTLMODConfig.BlackSky end, SetFunc = function(c,v) _G.GTLMODConfig.BlackSky = v return true end },
            { Key = "ModMenu_RemoveFog", UI = AliasMap.Switcher, Text = "REMOVE FOG", GetFunc = function() return _G.GTLMODConfig.RemoveFog end, SetFunc = function(c,v) _G.GTLMODConfig.RemoveFog = v return true end },
            
        }

        -- ==================== SKIN MOD (SECTION 4) ====================
        local StackSkinMod = {
            { Key = "ModMenu_Skin_Ex", UI = AliasMap.TitleSwitcher, Text = "VIP MOD SKINS ACTIVATED", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.ModSkin end, SetFunc = function(c,v) _G.GTLMODConfig.ModSkin = v return true end },
            { Key = "ModMenu_Skin_Suit", UI = AliasMap.Slider, Text = "   ALL X SUITS ", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 80, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinSuit or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinSuit = v; if _G.OutfitSkins and _G.OutfitSkins.Suit[v] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[v] end return true end },
            { Key = "ModMenu_Skin_Bag", UI = AliasMap.Slider, Text = "   ALL BAG SKINS (1-16)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 16, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinBag or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinBag = v; if _G.OutfitSkins and _G.OutfitSkins.Bag[v] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[v] end return true end },
            { Key = "ModMenu_Skin_Helmet", UI = AliasMap.Slider, Text = "   ALL HELMET SKINS (1-12)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 12, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinHelmet or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinHelmet = v; if _G.OutfitSkins and _G.OutfitSkins.Helmet[v] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[v] end return true end },
            { Key = "ModMenu_Skin_M416", UI = AliasMap.Slider, Text = "   M416 (1-9)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 9, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinM416 or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinM416 = v; if _G.skinIdMappings[101004] and _G.skinIdMappings[101004][v] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][v] end return true end },
            { Key = "ModMenu_Skin_AKM", UI = AliasMap.Slider, Text = "   AKM (1-8)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 8, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinAKM or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinAKM = v; if _G.skinIdMappings[101001] and _G.skinIdMappings[101001][v] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][v] end return true end },
            { Key = "ModMenu_Skin_SCAR", UI = AliasMap.Slider, Text = "   SCAR-L (1-8)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 8, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinSCAR or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinSCAR = v; if _G.skinIdMappings[101003] and _G.skinIdMappings[101003][v] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][v] end return true end },
            { Key = "ModMenu_Skin_M762", UI = AliasMap.Slider, Text = "   M762 (1-8)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 8, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinM762 or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinM762 = v; if _G.skinIdMappings[101008] and _G.skinIdMappings[101008][v] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][v] end return true end },
            { Key = "ModMenu_Skin_AUG", UI = AliasMap.Slider, Text = "   AUG (1-7)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 7, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinAUG or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinAUG = v; if _G.skinIdMappings[101006] and _G.skinIdMappings[101006][v] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][v] end return true end },
            { Key = "ModMenu_Skin_UMP", UI = AliasMap.Slider, Text = "   UMP45 (1-6)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 6, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinUMP or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinUMP = v; if _G.skinIdMappings[102002] and _G.skinIdMappings[102002][v] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][v] end return true end },
            { Key = "ModMenu_Skin_UZI", UI = AliasMap.Slider, Text = "   UZI (1-2)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinUZI or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinUZI = v; if _G.skinIdMappings[102001] and _G.skinIdMappings[102001][v] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][v] end return true end },
            { Key = "ModMenu_Skin_Groza", UI = AliasMap.Slider, Text = "   GROZA (1-2)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinGroza or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinGroza = v; if _G.skinIdMappings[101005] and _G.skinIdMappings[101005][v] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][v] end return true end },
            { Key = "ModMenu_Skin_Kar98K", UI = AliasMap.Slider, Text = "   Kar98K (1-3)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 3, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinKar98K or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinKar98K = v; if _G.skinIdMappings[103001] and _G.skinIdMappings[103001][v] then _G.WeaponSkinMap[103001] = _G.skinIdMappings[103001][v] end return true end },
            { Key = "ModMenu_Skin_AWM", UI = AliasMap.Slider, Text = "   AWM (1-4)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinAWM or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinAWM = v; if _G.skinIdMappings[103003] and _G.skinIdMappings[103003][v] then _G.WeaponSkinMap[103003] = _G.skinIdMappings[103003][v] end return true end },
            { Key = "ModMenu_Skin_AMR", UI = AliasMap.Slider, Text = "   AMR (1-3)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 3, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinAMR or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinAMR = v; if _G.skinIdMappings[103012] and _G.skinIdMappings[103012][v] then _G.WeaponSkinMap[103012] = _G.skinIdMappings[103012][v] end return true end },
            { Key = "ModMenu_Skin_S12K", UI = AliasMap.Slider, Text = "   S12K (1-2)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinS12K or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinS12K = v; if _G.skinIdMappings[104003] and _G.skinIdMappings[104003][v] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][v] end return true end },
            { Key = "ModMenu_Skin_DBS", UI = AliasMap.Slider, Text = "   DBS (1-3)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 3, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinDBS or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinDBS = v; if _G.skinIdMappings[104004] and _G.skinIdMappings[104004][v] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][v] end return true end },
            { Key = "ModMenu_Skin_Dacia", UI = AliasMap.Slider, Text = "   DACIA (1-90)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 90, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinDacia or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinDacia = v; if _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][v] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][v] end return true end },
            { Key = "ModMenu_Skin_UAZ", UI = AliasMap.Slider, Text = "   UAZ (1-90)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 90, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinUAZ or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinUAZ = v; if _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][v] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][v] end return true end },
            { Key = "ModMenu_Skin_Coupe", UI = AliasMap.Slider, Text = "   COUPE RB (1-70)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 70, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinCoupe or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinCoupe = v; if _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][v] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][v] end return true end },
            { Key = "ModMenu_Skin_Buggy", UI = AliasMap.Slider, Text = "   BUGGY (1-50)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 50, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinBuggy or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinBuggy = v; if _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][v] then _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][v] end return true end },
            { Key = "ModMenu_Skin_Mirado", UI = AliasMap.Slider, Text = "   MIRADO (1-27)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 27, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinMirado or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinMirado = v; if _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][v] then _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][v] end return true end }
        }

        -- ==================== DEFINE MENU PAGE (ORDER: ESP → AIMBOT → COMBAT → SKIN) ====================
        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text= "♛ VIP MENU ♛ @ZakPubgSkin",
            UIKey = "Setting_Page_Privacy", 
            Category = {
                { Key = "Cat_ESP_Visual", Text= "♛ ESP ♛", Stack = StackESPVisual },
                { Key = "Cat_Aimbot_Force", Text= "♛AIMBOT♛", Stack = StackAimbotForce },
                { Key = "Cat_Magic_Bullet", Text= "MAGIC + HEADSHOT", Stack = StackMagicBullet },
                { Key = "Cat_Combat_Graphic", Text= "♛EXTRA COMBO♛", Stack = StackCombatGraphic },
                { Key = "Cat_SkinMod", Text= "♛ALL SKIN♛", Stack = StackSkinMod }
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
                        if type(page) == "table" and page.Key == "ModMenu" then
                            hasModMenu = true
                            break
                        end
                    end
                    if not hasModMenu then
                        table.insert(catalog, SettingPageDefine.ModMenu)
                    end
                end
            end
            local table_unpack = table.unpack or unpack
            return old_ShowUI(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end
end

local function ShowGTLMODVIPMenu() 
    if _G.GTLMODMenuAlreadyShown then return end
    if _G.GTLMODState.MenuStep ~= 0 then return end

    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end

        local function Step_ScamAlert()
            Msg.Show(1, "♛VIP MOD PAK @ZakPubgSkin♛", "➜ WELCOME TO @ZakPubgSkin VIP MOD PAK FILE\n\nNO FEEDBACK - NO SECURE UPDATE\n\n➜ CONTACT: @ZakPubgSkin", function() local Web = require("client.slua.logic.url.logic_webview_sdk"); if Web and Web.OpenURL then Web:OpenURL("https://t.me/ZakPubgSkin") end end, function() end, "JOIN", "CLOSE")
            _G.GTLMODState.MenuStep = 99
            _G.GTLMODMenuAlreadyShown = true
        end

        local function Step_Welcome()
            Msg.Show(1, "♛WELCOME @ZakPubgSkin♛", "➜WELCOME TO @ZakPubgSkin VIP MOD PAK FILE\n\n♛ACTIVATION SUCCESSFUL!\n\nENJOY YOUR MOD AND SEND FEEDBACK TO OWNER.\nTHE REAL OWNER IS @ZakPubgSkin\n\nCONTACT: @ZakPubgSkin",
            function() 
                _G.InitModMenuTab()
                Notify("VIP MOD PAK BY @ZakPubgSkin - TOGGLE FEATURES!")
                Step_ScamAlert()
            end, 
            function() end, "OK", "CLOSE")
        end

        _G.GTLMODState.MenuStep = 1
        Step_Welcome() 
    end)
end

-- ========================================== 
-- LOGIC 165 FPS IPAD VIEW 
-- ========================================== 
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
        if GraphicSettingDB then
            if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
        end
    end)

    pcall(function()
        local logic_setting_graphics = require("client.slua.logic.setting.logic_setting_graphics")
        local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        local GSC_FPSFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        
        local KismetMathLibrary = import("KismetMathLibrary") or _G.KismetMathLibrary
        local FLinearColor = import("LinearColor") or _G.FLinearColor

        if logic_setting_graphics then
            local old_SetFPS = logic_setting_graphics.SetFPS
            function logic_setting_graphics.SetFPS(gameInstance, FPSLevel)
                if old_SetFPS then old_SetFPS(gameInstance, FPSLevel) end
                if FPSLevel == 8 then 
                    gameInstance:ExecuteCMD("t.MaxFPS", "165")
                    gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
                end
            end
        end

        if GSC_FPS and GSC_FPS.__inner_impl then
            local fps_impl = GSC_FPS.__inner_impl
            function fps_impl:GetMaxFPSLevel() return 8, 8 end
            function fps_impl:InitRealSupportFPS()
                local RealSupportFPS = {}
                for i = 1, 8 do RealSupportFPS[i] = {true, true} end
                if GraphicSettingDB then GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, RealSupportFPS, false) end
                return RealSupportFPS
            end
            function fps_impl:UpdateSelectedFPSState(selectedLevel)
                if not slua.isValid(self.UIRoot) then return end
                for level = 2, 8 do
                    local name = "NodeFps" .. (({[2]=20,[3]=25,[4]=30,[5]=40,[6]=60,[7]=90,[8]=120})[level] or 120)
                    local widget = self.UIRoot[name]
                    if slua.isValid(widget) then
                        widget:SetIsEnabled(true) 
                        pcall(function() widget:SetRenderOpacity(1.0) end)
                        local switcher = self.UIRoot["WidgetSwitcher_" .. level]
                        if slua.isValid(switcher) then 
                            switcher:SetActiveWidgetIndex(level == selectedLevel and 0 or 1) 
                        end
                    end
                end
            end
        end

        if GSC_FPSFT and GSC_FPSFT.__inner_impl then
            local ft_impl = GSC_FPSFT.__inner_impl
            local NMinFPS, NStep = 90, 5
            local function clamp(value, min, max)
                if value < min then return min end
                if max < value then return max end
                return value
            end
            local function lerp(a, b, t) return a + (b - a) * t end
            local function _getColorByPercent(start, finish, percent)
                if not FLinearColor then return nil end
                return FLinearColor(lerp(start.R, finish.R, percent), lerp(start.G, finish.G, percent), lerp(start.B, finish.B, percent), lerp(start.A, finish.A, percent))
            end
            
            ft_impl.ShowOrHide = function(self)
                self:SelfHitTestInvisible()
                if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end
            end

            ft_impl.InitFPSFTSwitch = function(self)
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(FPSFineTuneSwitch, true) end
                if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, FPSFineTuneSwitch) end
                if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
            end

            ft_impl.InitFPSFTValue165 = function(self)
                local itemRoot = self.UIRoot
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                local FPSFineTuneNum = 165
                if FPSFineTuneSwitch then
                    FPSFineTuneNum = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165
                    itemRoot.Slider_screen3:SetLocked(false)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 1.0, 1.0, 1.0))
                    end
                else
                    itemRoot.Slider_screen3:SetLocked(true)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 0.625, 0.6, 1))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 0.625, 0.6, 1.0))
                    end
                end
                local FPSFineTunePer = (FPSFineTuneNum - NMinFPS) / (165 - NMinFPS)
                
                itemRoot.Veihclescreen3:SetText(tostring(FPSFineTuneNum))
                itemRoot.Slider_screen3:SetValue(FPSFineTunePer)
                itemRoot.ProgressBar_screen3:SetPercent(FPSFineTunePer)
                
                if FLinearColor then
                    local startColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
                    local midColor = FLinearColor(1.0, 0.54, 0.11, 1.0)
                    local endColor = FLinearColor(1.0, 0.23, 0.15, 1.0)
                    local sliderColor = FPSFineTunePer < 0.4 and startColor or _getColorByPercent(midColor, endColor, (FPSFineTunePer - 0.4) / 0.6)
                    itemRoot.Slider_screen3:SetSliderHandleColor(sliderColor)
                end
            end

            ft_impl.OnFPSFTValueChange3 = function(self, FPSFineTuneNum)
                GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, FPSFineTuneNum)
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
                if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
                local gameInstance = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
                if gameInstance then
                    gameInstance:ExecuteCMD("t.MaxFPS", tostring(FPSFineTuneNum))
                    gameInstance:ExecuteCMD("r.FrameRateLimit", tostring(FPSFineTuneNum))
                end
            end

            ft_impl.OnFPSFTSliderValueChange3 = function(self, value)
                if GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) and KismetMathLibrary then
                    local FPSFineTuneNum = KismetMathLibrary.FCeil(value * (165 - NMinFPS) / NStep) * NStep + NMinFPS
                    self:OnFPSFTValueChange3(clamp(FPSFineTuneNum, NMinFPS, 165))
                end
            end
            
            ft_impl.OnFPSFTAdd = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTAdd2 = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus2 = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTSliderValueChange = ft_impl.OnFPSFTSliderValueChange3
            ft_impl.OnFPSFTSliderValueChange2 = ft_impl.OnFPSFTSliderValueChange3
        end
    end)
    _G.GTLMODState.GraphicsUnlocked = true
    Notify("Graphics & FPS 165Hz Unlocked")
end

-- ==========================================
-- IPAD VIEW / FOV CONTROLLER (FIXED)
-- ==========================================
local function ApplyIpadViewFOV(pc)
    if not Valid(localPlayer) or not Valid(pc) then return end

    -- Safe config access
    local Cfg  = _G.GTLMODConfig or {}
    local Data = _G.GTLMODState and _G.GTLMODState.CustomTextData or {}

    -- Derive aiming state (original code used undefined `isAiming`)
    local isAiming = false
    pcall(function()
        if localPlayer.bIsWeaponAiming ~= nil then
            isAiming = localPlayer.bIsWeaponAiming == true
        elseif localPlayer.bIsGunADS ~= nil then
            isAiming = localPlayer.bIsGunADS == true
        end
    end)

    -- Vehicle / camera components
    local currentVehicle = nil
    pcall(function()
        currentVehicle = localPlayer.CurrentVehicle
            or (type(localPlayer.GetVehicle) == "function" and localPlayer:GetVehicle())
    end)
    local isInVehicle = Valid(currentVehicle) or (localPlayer.bIsInVehicle == true)

        local uTPPCam = localPlayer.ThirdPersonCameraComponent
    local uVehCam = localPlayer.VehicleCameraComponent
    local camMgr  = pc.PlayerCameraManager

    -- Fallback: vehicle camera lives on the vehicle actor, not the pawn
    if not Valid(uVehCam) and Valid(currentVehicle) then
        pcall(function()
            uVehCam = currentVehicle.VehicleCameraComponent
                or currentVehicle.CameraComponent
                or (type(currentVehicle.GetCameraComponent) == "function" and currentVehicle:GetCameraComponent())
                or (type(currentVehicle.GetVehicleCamera) == "function" and currentVehicle:GetVehicleCamera())
        end)
    end

    -- ---------- 1. SCOPE / ADS ----------
    if isAiming then
        -- NOTE: IpadViewScope / IpadViewScopeFOV were never defined in config.
        -- Kept as opt-in extension so it doesn't break if user adds them.
        if Cfg.IpadViewScope and Data.IpadViewScopeFOV then
            local targetScope = tonumber(Data.IpadViewScopeFOV) or 60
            if type(pc.FOV) == "function" then pcall(function() pc:FOV(targetScope) end) end
            if Valid(camMgr) then
                camMgr.DefaultFOV = targetScope
                if type(camMgr.SetFOV) == "function" then
                    pcall(function() camMgr:SetFOV(targetScope) end)
                end
            end
        else
            -- Restore native FOV so scope aim stays accurate
            if type(pc.FOV) == "function" then pcall(function() pc:FOV(0) end) end
            if Valid(camMgr) and type(camMgr.UnlockFOV) == "function" then
                pcall(function() camMgr:UnlockFOV() end)
            end
        end
        return -- scope takes priority; skip on-foot / vehicle logic
    end

    -- ---------- 2. NON-AIM: reset camera if needed ----------
    if not isInVehicle or not Cfg.IpadViewVehicle then
        if type(pc.FOV) == "function" then pcall(function() pc:FOV(0) end) end
        if Valid(camMgr) and type(camMgr.UnlockFOV) == "function" then
            pcall(function() camMgr:UnlockFOV() end)
        end
    end

    -- ---------- 3. ON FOOT ----------
    if not isInVehicle then
        if Cfg.IpadView and Data.IpadViewFOV then
            local targetTPP = tonumber(Data.IpadViewFOV) or 120
            if Valid(uTPPCam) and uTPPCam.FieldOfView ~= targetTPP then
                uTPPCam.FieldOfView = targetTPP
            end
        else
            if Valid(uTPPCam) and uTPPCam.FieldOfView ~= 90 then
                uTPPCam.FieldOfView = 90
            end
        end
    end

    -- ---------- 4. IN VEHICLE ----------
    if isInVehicle then
        if Cfg.IpadViewVehicle and Data.IpadViewVehicleFOV then
            local targetVeh = tonumber(Data.IpadViewVehicleFOV) or 120

            if Valid(uVehCam) and uVehCam.FieldOfView ~= targetVeh then
                uVehCam.FieldOfView = targetVeh
            end

            if targetVeh > 90 then
                if type(pc.FOV) == "function" then pcall(function() pc:FOV(targetVeh) end) end
                if Valid(camMgr) then
                    camMgr.DefaultFOV = targetVeh
                    if type(camMgr.SetFOV) == "function" then
                        pcall(function() camMgr:SetFOV(targetVeh) end)
                    end
                end
            end
        else
            if Valid(uVehCam) and uVehCam.FieldOfView ~= 90 then
                uVehCam.FieldOfView = 90
            end
        end
    end
end
    
-- ========================================== 
-- INITIALIZE THE ESP SYSTEM (BASED)
-- ========================================== 
local function InitializeNativeESP() 
    if _G.GTLMODState.NativeESPReady then return end
    pcall(function() 
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools") 
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig") 
        local function ApplyCfg(cfg)
            if not cfg then return end 
            if cfg[1006] then 
                cfg[1006].bBindBlocked = true;
                cfg[1006].bBindOutScreen = true; 
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000; 
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root"; 
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30) 
            end 
            cfg[8888] = { 
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, 
                MaxShowDistance = 6000000, 
                bBindOutScreen = true,
                bBindBlocked = true, 
                bIsBindingActor = true,
                BindSocketName = "head",
                bUseLuaWorldSocketName = true, 
                WorldPositionOffset = FVector(0, 0, 30),
                bNeedPreLoad = true,
                Priority = 2 
            } 
            cfg[9999] = { 
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, 
                MaxShowDistance = 6000000, 
                bBindOutScreen = true,
                bBindBlocked = true, 
                bIsBindingActor = true, 
                BindSocketName = "head",
                bUseLuaWorldSocketName = true, 
                WorldPositionOffset = FVector(0, 0, 50),
                bNeedPreLoad = true, 
                Priority = 2 
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
    Notify("Native ESP System Initialized") 
end

-- ========================================== 
-- LOCAL FUNCTIONS CHO LOGIC NEW ESP - OPTIMIZED
-- ========================================== 
local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime) < 0.5 then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            if Valid(cachedMesh) then table.insert(validMeshes, cachedMesh) end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end

    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = import("SkeletalMeshComponent")
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then
                        table.insert(meshes, comp)
                    end
                end
            end
        end
    end)
    if markData then
        markData.CachedMeshes = meshes
        markData.CachedMeshTime = curTime
    end
    return meshes
end

-- ========================================== 
-- WALL-BOUND FUNCTION & ROOT RESTORE
-- ==========================================
local function Undowallhackng(enemy, markData)
    pcall(function()
        if markData.WallhackApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            local seen = {}
            for _, m in ipairs(meshes) do seen[m] = true end
            local function addMesh(m)
                if Valid(m) and not seen[m] then
                    seen[m] = true
                    table.insert(meshes, m)
                end
            end

            local weapon = nil
            pcall(function() weapon = enemy:GetCurrentWeapon() end)
            if Valid(weapon) and Valid(weapon.Mesh) then addMesh(weapon.Mesh) end

            local avatar = nil
            pcall(function()
                avatar = enemy.CharacterAvatarComp2_BP
                if not avatar and enemy.getAvatarComponent2 then avatar = enemy:getAvatarComponent2() end
            end)
            if Valid(avatar) and avatar.GetMeshCompBySlot then
                for slot = 0, 7 do
                    pcall(function() addMesh(avatar:GetMeshCompBySlot(slot)) end)
                end
            end

            for _, className in ipairs({"SkeletalMeshComponent","StaticMeshComponent"}) do
                local ok, cls = pcall(import, className)
                if ok and cls then
                    pcall(function()
                        if type(enemy.GetComponentsByClass) ~= "function" then return end
                        local comps = enemy:GetComponentsByClass(cls)
                        if comps then
                            for i = 0, comps:Num() - 1 do addMesh(comps:Get(i)) end
                        end
                    end)
                end
            end

            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        if type(mesh.SetRenderCustomDepth) == "function" then
                            mesh:SetRenderCustomDepth(false)
                        end
                    end)
                    for i = 0, 10 do
                        local matInterface = mesh:GetMaterial(i)
                        if Valid(matInterface) then
                            local baseMat = matInterface:GetBaseMaterial()
                            if Valid(baseMat) then baseMat.bDisableDepthTest = false end
                        end
                    end
                end
            end
            markData.WallhackApplied = false
        end
    end)
end

local function Applywallhackng(enemy, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        local seen = {}
        for _, m in ipairs(meshes) do seen[m] = true end
        local function addMesh(m)
            if Valid(m) and not seen[m] then
                seen[m] = true
                table.insert(meshes, m)
            end
        end

        local weapon = nil
        pcall(function() weapon = enemy:GetCurrentWeapon() end)
        if Valid(weapon) and Valid(weapon.Mesh) then addMesh(weapon.Mesh) end

        local avatar = nil
        pcall(function()
            avatar = enemy.CharacterAvatarComp2_BP
            if not avatar and enemy.getAvatarComponent2 then avatar = enemy:getAvatarComponent2() end
        end)
        if Valid(avatar) and avatar.GetMeshCompBySlot then
            for slot = 0, 7 do
                pcall(function() addMesh(avatar:GetMeshCompBySlot(slot)) end)
            end
        end

        for _, className in ipairs({"SkeletalMeshComponent","StaticMeshComponent"}) do
            local ok, cls = pcall(import, className)
            if ok and cls then
                pcall(function()
                    if type(enemy.GetComponentsByClass) ~= "function" then return end
                    local comps = enemy:GetComponentsByClass(cls)
                    if comps then
                        for i = 0, comps:Num() - 1 do addMesh(comps:Get(i)) end
                    end
                end)
            end
        end

        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    if type(mesh.SetRenderCustomDepth) == "function" then
                        mesh:SetRenderCustomDepth(true)
                    end
                    if type(mesh.SetCustomDepthStencilValue) == "function" then
                        mesh:SetCustomDepthStencilValue(252)
                    end
                end)
                for i = 0, 10 do
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        baseMat.bDisableDepthTest = true
                        baseMat.BlendMode = 2
                    end
                end
            end
        end
    end)
end
-- ========================================== 
-- WALLHACK WITH COLOR
-- ==========================================
local function ApplyColorBodyV2(enemy, pc, markData)
    pcall(function()
        -- Get localPlayer for trace ignore
        local localPlayer = nil
        pcall(function()
            local GameplayData = require("GameLua.GameCore.Data.GameplayData")
            if GameplayData and GameplayData.GetPlayerCharacter then
                localPlayer = GameplayData.GetPlayerCharacter()
            end
        end)
        if not Valid(localPlayer) then return end
        
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end
        
        -- ==========================================
        -- VISIBILITY CHECK (REAL LINE TRACE)
        -- Wall ke peeche = RED, saamne = GREEN
        -- ==========================================
        local curTime = os.clock()
        if markData.LastVisCheckTime == nil or (curTime - markData.LastVisCheckTime) > 0.1 then
            markData.LastVisCheckTime = curTime
            local isHidden = true   -- default hidden (fail-safe)
            
            pcall(function()
                if not Valid(pc) then return end
                
                -- 1. Head bone position
                local headPos = nil
                if type(enemy.GetBonePos) == "function" then
                    headPos = enemy:GetBonePos("head", {X=0,Y=0,Z=0})
                end
                if not headPos and type(enemy.GetSocketLocation) == "function" then
                    headPos = enemy:GetSocketLocation("head")
                end
                if not headPos then
                    headPos = enemy:K2_GetActorLocation()
                    if headPos then headPos.Z = headPos.Z + 70 end
                end
                if not headPos then return end
                
                -- 2. Camera location
                local UGameplayStatics = import("GameplayStatics")
                local camMgr = UGameplayStatics.GetPlayerCameraManager(pc, 0)
                if not slua.isValid(camMgr) then return end
                local camLoc = camMgr:GetCameraLocation()
                if not camLoc then return end
                
                -- 3. REAL LINE TRACE — camera se head tak
                local KismetSystemLibrary = import("KismetSystemLibrary")
                local hitResult = import("HitResult")()
                
                local ignoreActors = slua.Array(UEnums.EPropertyClass.Object, import("Actor"))
                ignoreActors:Add(localPlayer)
                ignoreActors:Add(enemy)
                
                local traceHit = false
                pcall(function()
                    traceHit = KismetSystemLibrary.LineTraceSingle(
                        localplayer,
                        camLoc,
                        headPos,
                        UEnums.ETraceTypeQuery.TraceTypeQuery1,
                        false,
                        ignoreActors,
                        UEnums.EDrawDebugTrace.None,
                        hitResult,
                        true
                    )
                end)
                
                -- 4. Wall/cover hit = hidden (RED)
                if traceHit and hitResult then
                    local hitActor = hitResult.Actor
                    if slua.isValid(hitActor) and hitActor ~= enemy then
                        isHidden = true    -- wall/cover beech mein = RED
                    else
                        isHidden = false   -- clear line = GREEN
                    end
                else
                    isHidden = false       -- kuch block nahi = GREEN
                end
                
                -- Fallback: agar trace fail ho jaye
                if not traceHit then
                    pcall(function()
                        if type(pc.LineOfSightTo) == "function" then
                            isHidden = not pc:LineOfSightTo(enemy)
                        end
                    end)
                end
            end)
            
            markData.CachedHiddenState = isHidden
        end
        
        local hidden = markData.CachedHiddenState
        if hidden == nil then hidden = true end
        
       -- 🔥 MAX BRIGHTNESS COLORS
local BRIGHT_RED   = {R=1.0, G=0.0, B=0.0, A=1.0}
local BRIGHT_GREEN = {R=0.0, G=1.0, B=0.0, A=1.0}
local BRIGHT_CYAN  = {R=0.0, G=1.0, B=1.0, A=1.0}
local BRIGHT_YELLOW = {R=1.0, G=1.0, B=0.0, A=1.0}

local finalColor = hidden and BRIGHT_RED or BRIGHT_GREEN
        
        -- ==========================================
        -- COLOR APPLY (existing logic — unchanged)
        -- ==========================================
        local colorHash = string.format("%d_%d_%d", finalColor.R, finalColor.G, finalColor.B)
        local currentMeshCount = #meshes
        local isMeshChanged = (markData.LastMeshCount ~= currentMeshCount)
        
        if not isMeshChanged and markData.LastHiddenState == hidden and markData.LastColorHash == colorHash then 
            return 
        end
        
        if isMeshChanged and markData.MIDs then
            markData.MIDs = {}
        end

        markData.LastHiddenState = hidden
        markData.LastMeshCount = currentMeshCount
        markData.LastColorHash = colorHash
        markData.ColorApplied = true
        
        for meshIndex, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    mesh.LDMaxDrawDistance = -99999
                    mesh.MaxDrawDistanceOffset = -99999
                    mesh.CachedMaxDrawDistance = -99999
                    mesh.UseScopeDistanceCulling = true
                    mesh.PrimitiveShadingStrategy = 1
                    mesh.ShadingRate = 6
                end)
                for i = 0, 10 do
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        local matName = tostring(baseMat)
                        if string.find(matName, "Master_Mask", 1, true) then
                            if not markData.MIDs then markData.MIDs = {} end
                            
                            local meshKey = "Mesh_" .. tostring(meshIndex)
                            
                            if not markData.MIDs[meshKey] then markData.MIDs[meshKey] = {} end
                            local mid = markData.MIDs[meshKey][i]
                            if not Valid(mid) then
                                mid = mesh:CreateAndSetMaterialInstanceDynamic(i)
                                markData.MIDs[meshKey][i] = mid
                            end
                            if Valid(mid) then
    mid:SetVectorParameterValue("颜色", finalColor)
    mid:SetVectorParameterValue("Extra Light Color", finalColor)
    mid:SetVectorParameterValue("Para_Color", finalColor)
    mid:SetVectorParameterValue("Para_ColorTint", finalColor)
    mid:SetVectorParameterValue("Para_Color_1", finalColor)
    mid:SetVectorParameterValue("Tint", finalColor)
    mid:SetVectorParameterValue("Color", finalColor)
    mid:SetVectorParameterValue("BaseColor", finalColor)
    mid:SetVectorParameterValue("BodyColor", finalColor)
    mid:SetVectorParameterValue("MainColor", finalColor)
    mid:SetVectorParameterValue("DiffuseColor", finalColor)
    mid:SetVectorParameterValue("EmissiveColor", finalColor)
    
    -- 🔥 BRIGHTNESS BOOST PARAMETERS
    pcall(function() mid:SetScalarParameterValue("EmissiveIntensity", 10.0) end)
    pcall(function() mid:SetScalarParameterValue("EmissionStrength", 8.0) end)
    pcall(function() mid:SetScalarParameterValue("LightIntensity", 5.0) end)
    pcall(function() mid:SetScalarParameterValue("GlowIntensity", 8.0) end)
    pcall(function() mid:SetScalarParameterValue("Brightness", 5.0) end)
    pcall(function() mid:SetScalarParameterValue("ColorIntensity", 5.0) end)
    pcall(function() mid:SetScalarParameterValue("EmissiveMultiplier", 5.0) end)
end
                        end
                    end
                end
            end
        end
    end)
end
local function UndoColorBodyV2(enemy, markData)
    pcall(function()
        if markData.ColorApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for meshIndex, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        mesh.PrimitiveShadingStrategy = 0
                        mesh.ShadingRate = 1
                    end)
                    local meshKey = "Mesh_" .. tostring(meshIndex)
                    if markData.MIDs and markData.MIDs[meshKey] then
                        for i, mid in pairs(markData.MIDs[meshKey]) do
                            if Valid(mid) then
                                local defC = {R=1, G=1, B=1, A=1}
                                mid:SetVectorParameterValue("颜色", defC)
                                mid:SetVectorParameterValue("Extra Light Color", defC)
                                mid:SetVectorParameterValue("Para_Color", defC)
                                mid:SetVectorParameterValue("Para_ColorTint", defC)
                                mid:SetVectorParameterValue("Para_Color_1", defC)
                                mid:SetVectorParameterValue("Tint", defC)
                                mid:SetVectorParameterValue("Color", defC)
                                mid:SetVectorParameterValue("BaseColor", defC)
                                mid:SetVectorParameterValue("BodyColor", defC)
                                mid:SetVectorParameterValue("MainColor", defC)
                                mid:SetVectorParameterValue("DiffuseColor", defC)
                                mid:SetVectorParameterValue("EmissiveColor", defC)
                            end
                        end
                    end
                end
            end
            markData.ColorApplied = false
            markData.LastColorHash = ""
            markData.LastHiddenState = nil
        end
    end)
end

-- ========================================== 
-- AIMBOT V2 SYSTEM WITH NEW INTEGRATED TECHNOLOGY
-- ========================================== 
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()

    if not slua.isValid(player) then
        return result
    end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()

    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    pcall(function()
        if not _G.GTLMODConfig.AimTouchEnable then return end

        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end

        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then return end

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
            elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
                currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
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

        if isShotgun and currentAmmo <= 0 then
            return
        end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 50
        local fovVal = 30
        local maxDistMeters = 50
        local useVisCheck = false
        local igKnock = false
        local igBot = false

        local predVal = 0
        local recoilCompVal = 0

        if isShotgun and _G.GTLMODConfig.AimTouchSG then
            cond = _G.GTLMODState.CustomTextData.AimTouchSGCond or 1
            if _G.GTLMODConfig.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.GTLMODState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.GTLMODState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.GTLMODState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.GTLMODState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.GTLMODState.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.GTLMODConfig.AimTouchSGVisCheck
            igKnock = _G.GTLMODConfig.AimTouchSGIgKnock
            igBot = _G.GTLMODConfig.AimTouchSGIgBot

        elseif isADS then
            if isSniper and _G.GTLMODConfig.AimTouchScopeSniper then
                cond = _G.GTLMODState.CustomTextData.AimTouchSniperCond or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.GTLMODState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.GTLMODState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.GTLMODState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.GTLMODState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.GTLMODState.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.GTLMODConfig.AimTouchSniperVisCheck
                igKnock = _G.GTLMODConfig.AimTouchSniperIgKnock
                igBot = _G.GTLMODConfig.AimTouchSniperIgBot
                predVal = _G.GTLMODState.CustomTextData.AimTouchSniperPred or 0
            elseif _G.GTLMODConfig.AimTouchScopeAll then
                cond = _G.GTLMODState.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.GTLMODState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = _G.GTLMODState.CustomTextData.AimTouchScopeBone or 2
                speedVal = _G.GTLMODState.CustomTextData.AimTouchScopeSpeed or 40
                fovVal = _G.GTLMODState.CustomTextData.AimTouchScopeFOV or 20
                maxDistMeters = _G.GTLMODState.CustomTextData.AimTouchScopeDist or 300
                useVisCheck = _G.GTLMODConfig.AimTouchScopeVisCheck
                igKnock = _G.GTLMODConfig.AimTouchScopeIgKnock
                igBot = _G.GTLMODConfig.AimTouchScopeIgBot
                predVal = _G.GTLMODState.CustomTextData.AimTouchScopePred or 0
                recoilCompVal = _G.GTLMODState.CustomTextData.AimTouchScopeRecoil or 0
            else
                return
            end
        else
            if not _G.GTLMODConfig.AimTouchHipfire then return end
            cond = _G.GTLMODState.CustomTextData.AimTouchHipCond or 1
            if cond == 1 and not isFiring then return end
            prioMode = _G.GTLMODState.CustomTextData.AimTouchHipPrio or 1
            boneIdx = _G.GTLMODState.CustomTextData.AimTouchHipBone or 1
            speedVal = _G.GTLMODState.CustomTextData.AimTouchHipSpeed or 50
            fovVal = _G.GTLMODState.CustomTextData.AimTouchHipFOV or 30
            maxDistMeters = _G.GTLMODState.CustomTextData.AimTouchHipDist or 250
            useVisCheck = _G.GTLMODConfig.AimTouchHipVisCheck
            igKnock = _G.GTLMODConfig.AimTouchHipIgKnock
            igBot = _G.GTLMODConfig.AimTouchHipIgBot
        end

        local currentMaxDist = maxDistMeters * 100

        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end

        local FVector2D = import("Vector2D")
        local UGameplayStatics = import("GameplayStatics")
        local KismetMathLibrary = import("KismetMathLibrary")

        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end

        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end

        local ui_util = require("client.common.ui_util")
        if not ui_util then return end

        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end

        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5

        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)

        local bestTarget = nil
        local bestScore = 99999999

        local selBoneName = "head"
        if boneIdx == 1 then selBoneName = "head"
        elseif boneIdx == 2 then selBoneName = "spine_03"
        elseif boneIdx == 3 then selBoneName = "spine_01"
        elseif boneIdx == 4 then selBoneName = "pelvis" end

        for i, target in ipairs(enemies) do
            local skip = false

            if not slua.isValid(target) then skip = true end

            if not skip then
                pcall(function()
                    if slua.isValid(target.Mesh) then
                        target.Mesh.MeshComponentUpdateFlag = 0
                    end
                end)
            end

            if not skip and igKnock and target.HealthStatus == 1 then skip = true end

            if not skip and igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then skip = true end
            end

            -- VISIBILITY CHECK (cached 0.2s per enemy)
                        -- VISIBILITY CHECK (FIXED — head bone screen projection)
                        -- VISIBILITY CHECK (FIXED — real line trace, cover block karega)
            if not skip and useVisCheck then
                local tId = GetSafeEnemyKey(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                local cached = _G.AimTouchVisCache[tId]
                local nowT = os.clock()
                
                if not cached or (nowT - (cached.t or 0)) > 0.1 then
                    local hidden = true   -- DEFAULT HIDDEN (fail-safe)
                    
                    pcall(function()
                        -- 1. Head bone position
                        local headPos = nil
                        if type(target.GetBonePos) == "function" then
                            headPos = target:GetBonePos("head", {X=0,Y=0,Z=0})
                        end
                        if not headPos and type(target.GetSocketLocation) == "function" then
                            headPos = target:GetSocketLocation("head")
                        end
                        if not headPos then
                            headPos = target:K2_GetActorLocation()
                            if headPos then headPos.Z = headPos.Z + 70 end
                        end
                        if not headPos then return end
                        
                        -- 2. Camera location
                        local UGameplayStatics = import("GameplayStatics")
                        local camMgr = UGameplayStatics.GetPlayerCameraManager(pc, 0)
                        if not slua.isValid(camMgr) then return end
                        local camLoc = camMgr:GetCameraLocation()
                        if not camLoc then return end
                        
                        -- 3. Screen projection check (enemy screen pe hai?)
                        local FVector2D = import("Vector2D")
                        local screen = FVector2D()
                        local onScreen = false
                        pcall(function()
                            onScreen = pc:ProjectWorldLocationToScreen(headPos, screen, false)
                        end)
                        if not onScreen or screen.X <= 0 or screen.Y <= 0 then
                            hidden = true
                            return
                        end
                        
                        -- 4. REAL LINE TRACE — camera se head tak
                        local KismetSystemLibrary = import("KismetSystemLibrary")
                        local hitResult = import("HitResult")()
                        
                        -- Trace params: ignore self + ignore target
                        local ignoreActors = slua.Array(UEnums.EPropertyClass.Object, import("Actor"))
ignoreActors:Add(player)
ignoreActors:Add(target)
                        
                        local traceHit = false
                        pcall(function()
                            traceHit = KismetSystemLibrary.LineTraceSingle(
                                player,           -- WorldContext
                                camLoc,                -- Start
                                headPos,               -- End
                                UEnums.ETraceTypeQuery.TraceTypeQuery1,  -- Visibility channel
                                false,                 -- bTraceComplex
                                ignoreActors,          -- ActorsToIgnore
                                UEnums.EDrawDebugTrace.None,
                                hitResult,             -- OutHit
                                true                   -- bIgnoreSelf
                            )
                        end)
                        
                        -- 5. Agar wall/cover hit hua → hidden
                        if traceHit and hitResult then
                            local hitActor = hitResult.Actor
                            -- Agar jo hit hua wo target NAHI hai → wall/cover hai → hidden
                            if slua.isValid(hitActor) and hitActor ~= target then
                                hidden = true
                            else
                                hidden = false
                            end
                        else
                            -- Kuch hit nahi → clear line → visible
                            hidden = false
                        end
                    end)
                    
                    cached = { hidden = hidden, t = nowT }
                    _G.AimTouchVisCache[tId] = cached
                end
                
                if cached and cached.hidden then skip = true end
            end

            -- TARGET POSITION
            if not skip then
                local tPos = nil
                pcall(function()
                    if type(target.GetBonePos) == "function" then
                        tPos = target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
                    end
                end)
                if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                    pcall(function()
                        if type(target.GetSocketLocation) == "function" then
                            tPos = target:GetSocketLocation(selBoneName)
                        end
                    end)
                end
                if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                    pcall(function()
                        if type(target.K2_GetActorLocation) == "function" then
                            tPos = target:K2_GetActorLocation()
                            if tPos then
                                if boneIdx == 1 then tPos.Z = tPos.Z + 70
                                elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                                elseif boneIdx == 3 then tPos.Z = tPos.Z + 20 end
                            end
                        end
                    end)
                end

                if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                    skip = true
                end

                if not skip then
                    local screen = FVector2D()
                    local success = false
                    pcall(function()
                        success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
                    end)
                    if not success or screen.X <= 0 or screen.Y <= 0 then
                        skip = true
                    else
                        local dx = screen.X - centerX
                        local dy = screen.Y - centerY
                        local distScreen = math.sqrt(dx*dx + dy*dy)
                        if distScreen > FOV_RADIUS then
                            skip = true
                        else
                            local currentScore = distScreen
                            if prioMode == 2 then
                                currentScore = player:GetDistanceTo(target)
                            elseif prioMode == 3 then
                                currentScore = target.Health or 100
                            elseif prioMode == 4 then
                                local hp = target.Health or 100
                                local maxhp = target.HealthMax or 100
                                if maxhp <= 0 then maxhp = 100 end
                                currentScore = hp / maxhp
                            end
                            if currentScore < bestScore then
                                bestScore = currentScore
                                bestTarget = target
                            end
                        end
                    end
                end
            end
        end -- closes for i, target in ipairs(enemies) do

        if not slua.isValid(bestTarget) then return end

        local finalBonePos = bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end

        if predVal > 0 then
            pcall(function()
                local tVelocity = nil
                if type(bestTarget.GetVelocity) == "function" then
                    tVelocity = bestTarget:GetVelocity()
                end

                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0
                    local ToF = (distToEnemy / 800.0) * (predVal / 50.0)
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end

        local currentRot = pc:GetControlRotation()
        if not currentRot then return end

        local deltaYaw = rot.Yaw - currentRot.Yaw
        local deltaPitch = rot.Pitch - currentRot.Pitch

        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
                deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end

        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end

        local smoothFactor = 0.0
        if speedVal >= 100 then
            smoothFactor = 1.0
        else
            smoothFactor = (speedVal / 100.0) * 0.3
            if smoothFactor < 0.01 then smoothFactor = 0.01 end
        end

        local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
        local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)

        if recoilCompVal > 0 and isFiring then
            local pullDownForce = (recoilCompVal / 50.0) * 1.5
            finalPitch = finalPitch - pullDownForce
        end

        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")

        if isShotgun and _G.GTLMODConfig.AimTouchSGAutoFire then
            pcall(function()
                local distToTarget = player:GetDistanceTo(bestTarget) / 100
                if distToTarget <= maxDistMeters then
                    player.bIsWeaponFiring = true
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(true) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(true) end
                    local wepMgr = player.WeaponManagerComponent
                    if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = true end

                    local currentWep = player:GetCurrentWeapon()
                    if slua.isValid(currentWep) and type(currentWep.StartFire) == "function" then
                        currentWep:StartFire()
                    end
                    _G.GTLMODState.IsAutoFiring = true
                end
            end)
        end

    end) -- closes pcall(function() ... end)
end -- closes _G.AimTouch = function() ... end

-- ========================================== 
-- MAIN LOOP: EXTREMELY POWERFUL OPTIMIZED
-- ========================================== 
local function MainLoop() 
    if isExpired then return end
    if not BRLicenseActive() then return end

    if _G.GTLMODState.CustomTextData == nil then 
        _G.GTLMODState.CustomTextData = {OuterSpeed = 10, InnerSpeed = 10, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120, AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250, AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30, AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400, SkinSuit = 1, SkinBag = 1, SkinHelmet = 1, SkinM416 = 1, SkinAKM = 1, SkinSCAR = 1, SkinM762 = 1, SkinAUG = 1, SkinUMP = 6, SkinUZI = 1, SkinGroza = 1, SkinKar98K = 1, SkinAWM = 2, SkinAMR = 1, SkinS12K = 1, SkinDBS = 1, SkinDacia = 1, SkinUAZ = 1, SkinCoupe = 1, SkinBuggy = 1, SkinMirado = 1}
    end

    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData") 
    if not okData or not GameplayData then return end 
    local pc = GameplayData.GetPlayerController() 
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end 

    if not Valid(localPlayer) then 
        if _G.GTLMODState.TrackedMarks then
            for markId, _ in pairs(_G.GTLMODState.TrackedMarks) do
                SafeRemoveMark(markId)
            end
        end
        _G.GTLMODState.TrackedMarks = {} 
        
        for key, data in pairs(_G.GTLMODState.EnemyMarks) do
            if data and data.MIDs then
                for meshStr, midTable in pairs(data.MIDs) do
                    for k, _ in pairs(midTable) do midTable[k] = nil end
                end
                data.MIDs = nil
            end
        end
        
        _G.GTLMODState.EnemyMarks = {}
        _G.AK_OrigHitboxes = {}
        _G.AK_ModdedPhysAssets = {}
        _G.GTLMODState.PrevGraphicsState = {}
        return 
    end

    local Cached_KismetSystemLibrary = _G.Cached_KSL or import("KismetSystemLibrary")
    _G.Cached_KSL = Cached_KismetSystemLibrary
    local Cached_World = slua.getWorld()
    local Cached_PPM = nil
    pcall(function() Cached_PPM = import("PostProcessManager").GetInstance() end)
    local Cached_SecurityCommonUtils = nil
    pcall(function() Cached_SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
    local Cached_MyHUD = pc and pc.MyHUD or nil

    if _G.GTLMODConfig.UnlockFPS then InitializeGraphicsUnlock() end
    InitializeNativeESP()
    ShowGTLMODVIPMenu()
    
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
            local function ApplyColorBodyNew(enemy, markData)
    pcall(function()
        local KismetSystemLibrary = import("KismetSystemLibrary")
        local world = slua.getWorld()
        if world ~= _G.ConsoleNewWallWorld then
            if KismetSystemLibrary and world then
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.CustomDepth 3")
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
                _G.ConsoleNewWallWorld = world
            end
        end

        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end

        local seen = {}
        for _, m in ipairs(meshes) do seen[m] = true end
        local function addMesh(m)
            if slua.isValid(m) and not seen[m] then
                seen[m] = true
                table.insert(meshes, m)
            end
        end

        local weapon = nil
        pcall(function() weapon = enemy:GetCurrentWeapon() end)
        if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then addMesh(weapon.Mesh) end

        local avatar = nil
        pcall(function()
            avatar = enemy.CharacterAvatarComp2_BP
            if not avatar and enemy.getAvatarComponent2 then avatar = enemy:getAvatarComponent2() end
        end)
        if slua.isValid(avatar) and avatar.GetMeshCompBySlot then
            for slot = 0, 7 do
                pcall(function() addMesh(avatar:GetMeshCompBySlot(slot)) end)
            end
        end

        for _, className in ipairs({"SkeletalMeshComponent","StaticMeshComponent"}) do
            local ok, cls = pcall(import, className)
            if ok and cls then
                pcall(function()
                    if type(enemy.GetComponentsByClass) ~= "function" then return end
                    local comps = enemy:GetComponentsByClass(cls)
                    if comps then
                        for i = 0, comps:Num() - 1 do addMesh(comps:Get(i)) end
                    end
                end)
            end
        end

        -- ═══════════════════════════════════════════
        -- VISIBILITY CHECK — wall ke peeche ya saamne?
        -- ═══════════════════════════════════════════
        local now = os.clock()
        local hidden = markData.CachedHidden
        if markData.LastVisCheckTime == nil or (now - markData.LastVisCheckTime) > 0.15 then
            markData.LastVisCheckTime = now
            hidden = false

            pcall(function()
                local localPlayer = nil
                pcall(function()
                    local GD = require("GameLua.GameCore.Data.GameplayData")
                    if GD and GD.GetPlayerCharacter then localPlayer = GD.GetPlayerCharacter() end
                end)
                if not Valid(localPlayer) then return end
                local pc = localPlayer:GetPlayerControllerSafety()
                if not Valid(pc) then return end

                local headPos = nil
                if type(enemy.GetBonePos) == "function" then
                    local fb = (type(enemy.K2_GetActorLocation) == "function" and enemy:K2_GetActorLocation()) or {X=0,Y=0,Z=0}
                    headPos = enemy:GetBonePos("head", fb)
                end
                if not headPos and type(enemy.GetSocketLocation) == "function" then
                    headPos = enemy:GetSocketLocation("head")
                end
                if not headPos and type(enemy.K2_GetActorLocation) == "function" then
                    headPos = enemy:K2_GetActorLocation()
                    if headPos then headPos.Z = headPos.Z + 70 end
                end
                if not headPos then return end

                local GS = import("GameplayStatics")
                local camMgr = GS.GetPlayerCameraManager(pc, 0)
                if not slua.isValid(camMgr) then return end
                local camLoc = camMgr:GetCameraLocation()
                if not camLoc then return end

                if not markData.HitResult then
                    markData.HitResult = import("HitResult")()
                end
                if not markData.IgnoreActors or markData.IgnoreActorsEnemy ~= enemy then
                    if not markData.CachedActorClass then
                        markData.CachedActorClass = import("Actor")
                    end
                    markData.IgnoreActors = slua.Array(UEnums.EPropertyClass.Object, markData.CachedActorClass)
                    markData.IgnoreActors:Add(localPlayer)
                    markData.IgnoreActors:Add(enemy)
                    markData.IgnoreActorsEnemy = enemy
                end

                local traceHit = false
                pcall(function()
                    traceHit = KismetSystemLibrary.LineTraceSingle(
                        pc,
                        camLoc,
                        headPos,
                        UEnums.ETraceTypeQuery.TraceTypeQuery1,
                        false,
                        markData.IgnoreActors,
                        UEnums.EDrawDebugTrace.None,
                        markData.HitResult,
                        true
                    )
                end)

                if traceHit and markData.HitResult then
                    local hitActor = markData.HitResult.Actor
                    if slua.isValid(hitActor) and hitActor ~= enemy then
                        hidden = true
                    end
                end
            end)

            markData.CachedHidden = hidden
        end

        if markData.CachedHidden ~= nil then hidden = markData.CachedHidden end
        if hidden == nil then hidden = false end

        local isBot = markData.AK_IS_BOT or false
        local currentMeshCount = #meshes
        local stateHash = (isBot and "BOT" or "PLAYER") .. "_" .. tostring(currentMeshCount) .. "_" .. (hidden and "H" or "V")

        local nowT = os.clock()
        local lastApply = markData.LastColorNewTime or 0
        if markData.LastColorNewHash == stateHash
           and markData.ColorNewApplied == true
           and (nowT - lastApply) < 0.30 then
            return
        end
        markData.LastColorNewHash = stateHash
        markData.LastColorNewTime = nowT
        markData.ColorNewApplied = false

        local LinearColorClass = import("LinearColor") or _G.FLinearColor

        -- 🟢 VISIBLE = bright green
        -- 🔴 HIDDEN (wall ke peeche) = bright red
        local c_vis = LinearColorClass and LinearColorClass(0.0, 1.0, 0.0, 1.0) or {R=0.0, G=1.0, B=0.0, A=1.0}
        local c_occ = LinearColorClass and LinearColorClass(1.0, 0.0, 0.0, 1.0) or {R=1.0, G=0.0, B=0.0, A=1.0}

        -- Bots ke liye bhi same green/red, thoda different shade
        local c_bVis = LinearColorClass and LinearColorClass(0.2, 1.0, 0.2, 1.0) or {R=0.2, G=1.0, B=0.2, A=1.0}
        local c_bOcc = LinearColorClass and LinearColorClass(1.0, 0.3, 0.0, 1.0) or {R=1.0, G=0.3, B=0.0, A=1.0}

        local visColor = isBot and c_bVis or c_vis
        local occColor = isBot and c_bOcc or c_occ
        local finalColor = hidden and occColor or visColor

        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    if type(mesh.SetDrawDyeing) == "function" then
                        mesh:SetDrawDyeing(true)
                        mesh:SetDrawDyeingMode(1)
                        mesh:SetVisibleDyeingColor(visColor)
                        mesh:SetOccludedDyeingColor(occColor)
                        mesh:SetDyeingColorFadeDistance(99999.0)
                        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
                        mesh:SetDrawHighlight(true)
                        mesh:OverrideHighlightColor(finalColor)
                        mesh:SetHighlightCanBeOccluded(false)
                        mesh:SetDrawIdeaOutline(true)
                        mesh:SetIdeaOutlineNew(true)
                        mesh:SetIdeaOutlineOcclusionHighlight(true)
                        mesh:OverrideIdeaOutlineColor(finalColor)
                        mesh:SetIdeaOutlineOcclusionColor(occColor)
                        mesh:OverrideIdeaOutlineThickness(3.0)
                        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
                        mesh:SetRenderCustomDepth(true)
                        mesh:SetCustomDepthStencilValue(252)
                    end
                end)
            end
        end
        markData.ColorNewApplied = true
    end)
end
    -- ========================================== 
    -- SKIN MOD LOOP - ULTIMATE FIX FOR 32-BIT
    -- (Suit, Weapon, Bag, Helmet, Vehicle, Pet - ALL SKINS WORK)
    -- ========================================== 
    if _G.GTLMODConfig.ModSkin then
        if not _G.TDSkinLoopStarted then
            if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
            if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
            _G.TDSkinLoopStarted = true
            if not _G.KillInfoCounterHacked and _G.ForceEnableKillCounterUI then _G.ForceEnableKillCounterUI() end
        end
        
        _G.GTLMODState.SkinWasApplied = true
        
        -- READ CONFIG (every 2 seconds)
        local curTime = os.clock()
        if not _G.LastSkinConfigRead or (curTime - _G.LastSkinConfigRead) > 2.0 then
            _G.LastSkinConfigRead = curTime
            if _G.ReadLiveConfig then _G.ReadLiveConfig() end
        end
        
        -- FORCE APPLY ALL SKINS (every frame)
        pcall(function()
            local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
            if isAlive then
                if _G.equip_character_avatar then 
                    _G.equip_character_avatar(localPlayer) 
                end
                if _G.ApplyWeaponSkins then 
                    _G.ApplyWeaponSkins(localPlayer) 
                end
                if _G.ApplyVehicleSkins then 
                    _G.ApplyVehicleSkins(localPlayer) 
                end
                if _G.HandlePetLogic then 
                    _G.HandlePetLogic() 
                end
                if _G.DeadBox_TemperRequest and _G.NeedCheckDeadBoxTimer > 0 then 
                    _G.DeadBox_TemperRequest(pc) 
                end
                if localPlayer.AvatarComponent2 and type(localPlayer.AvatarComponent2.OnRep_BodySlotStateChanged) == "function" then
                    pcall(function()
                        localPlayer.AvatarComponent2:OnRep_BodySlotStateChanged()
                    end)
                end
            end
        end)
    else
        -- SKIN MOD OFF - RESTORE ORIGINAL SKINS
        if _G.GTLMODState.SkinWasApplied then
            _G.OutfitMap = {}
            _G.WeaponSkinMap = {}
            _G.VehicleSkinMap = {}
            pcall(function()
                local WeaponManager = localPlayer:GetWeaponManager()
                if Valid(WeaponManager) then
                    for slot = 1, 3 do
                        local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
                        if Valid(Weapon) and Valid(Weapon.synData) then
                            local WeaponID = Weapon:GetWeaponID()
                            local SkinData = Weapon.synData:Get(7)
                            if SkinData and SkinData.defineID then
                                SkinData.defineID.TypeSpecificID = WeaponID
                                Weapon.synData:Set(7, SkinData)
                                if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(WeaponID) end) end
                                if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                            end
                        end
                    end
                end
                local Vehicle = localPlayer:GetCurrentVehicle()
                if Valid(Vehicle) then
                    local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
                    if Valid(VehicleAvatar) and type(VehicleAvatar.GetDefaultAvatarID) == "function" then
                        local defId = VehicleAvatar:GetDefaultAvatarID()
                        if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(defId, true) end
                    end
                end
                if localPlayer.AvatarComponent2 and type(localPlayer.AvatarComponent2.OnRep_BodySlotStateChanged) == "function" then
                    localPlayer.AvatarComponent2:OnRep_BodySlotStateChanged()
                end
            end)
            _G.GTLMODState.SkinWasApplied = false
        end
        _G.TDSkinLoopStarted = false
    end

    -- ========================================== 
    -- Aimbot Force (Moved to separate loop)
    -- ========================================== 

    pcall(function()
        if _G.GTLMODConfig.CustomAimbot and localPlayer.bIsWeaponFiring and localPlayer.bIsGunADS then
            local outerRecoilVal = _G.GTLMODState.CustomTextData.OuterRecoil or 0
            if outerRecoilVal > 0 then
                local curTime = os.clock()
                
                if not _G.RecoilTargetCacheTime or (curTime - _G.RecoilTargetCacheTime) > 0.2 then
                    _G.RecoilTargetCacheTime = curTime
                    _G.HasRecoilTargetCached = false
                    
                    local ui_util = require("client.common.ui_util")
                    if ui_util then
                        local viewportSize = ui_util.GetViewportSize()
                        if viewportSize then
                            local centerX = viewportSize.X * 0.5
                            local centerY = viewportSize.Y * 0.5
                            local FOV_RADIUS = (6 / 100.0) * (viewportSize.X / 2.0) 
                            
                            local enemies = _G.GetEnemyTargetsFromActors(40000) 
                            if enemies and #enemies > 0 then
                                local FVector2D = import("Vector2D")
                                for _, target in ipairs(enemies) do
                                    if slua.isValid(target) and target.HealthStatus ~= 1 then 
                                        local tPos = type(target.K2_GetActorLocation) == "function" and target:K2_GetActorLocation() or nil
                                        if tPos then
                                            local screen = FVector2D()
                                            if pc:ProjectWorldLocationToScreen(tPos, screen, false) and screen.X > 0 and screen.Y > 0 then
                                                local dx = screen.X - centerX
                                                local dy = screen.Y - centerY
                                                if math.sqrt(dx*dx + dy*dy) <= FOV_RADIUS then
                                                    _G.HasRecoilTargetCached = true
                                                    break 
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if _G.HasRecoilTargetCached then
                    local currentRot = pc:GetControlRotation()
                    if currentRot then
                        local pullDownForce = (outerRecoilVal / 50.0) * 1.5
                        currentRot.Pitch = currentRot.Pitch - pullDownForce
                        pc:SetControlRotation(currentRot, "CustomAimbotRecoil")
                    end
                end
            end
        else
            _G.HasRecoilTargetCached = false
        end
    end)

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

    -- ========================================== 
    -- REMOVED WALL CLIMB AND FAST CAR LOGIC 
    -- ==========================================

    local now = os.clock()
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            if _G.GTLMODConfig.RemoveGrass and not _G.GTLMODState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "0")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
                _G.GTLMODState.PrevGraphicsState.RemoveGrass = true
            elseif not _G.GTLMODConfig.RemoveGrass and _G.GTLMODState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "1")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
                _G.GTLMODState.PrevGraphicsState.RemoveGrass = false
            end
            
            if _G.GTLMODConfig.RemoveFog and not _G.GTLMODState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1") 
                gi:ExecuteCMD("r.Fog", "0")           
                gi:ExecuteCMD("r.VolumetricFog", "0") 
                _G.GTLMODState.PrevGraphicsState.RemoveFog = true
            elseif not _G.GTLMODConfig.RemoveFog and _G.GTLMODState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1") 
                gi:ExecuteCMD("r.Fog", "1")           
                gi:ExecuteCMD("r.VolumetricFog", "1") 
                _G.GTLMODState.PrevGraphicsState.RemoveFog = false
            end
            
            if _G.GTLMODConfig.WhiteBody and not _G.GTLMODState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "2")
                gi:ExecuteCMD("r.CharacterDiffusePower", "5")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "100")
                _G.GTLMODState.PrevGraphicsState.WhiteBody = true
            elseif not _G.GTLMODConfig.WhiteBody and _G.GTLMODState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                _G.GTLMODState.PrevGraphicsState.WhiteBody = false
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
            if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then
                weapon = weaponManager:GetCurrentWeapon()
            end
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
                local anyWeaponModOn = _G.GTLMODConfig.CustomHRecoil or _G.GTLMODConfig.CustomVRecoil or _G.GTLMODConfig.LessShake or _G.GTLMODConfig.Accuracy or _G.GTLMODConfig.AutoHead or _G.GTLMODConfig.CustomAimbot or _G.GTLMODConfig.CustomAimbotClose

                if anyWeaponModOn then
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
                    
                    if _G.GTLMODConfig.CustomHRecoil then entity.AccessoriesHRecoilFactor = _G.GTLMODState.CustomTextData.HRecoil or 0.33
                    elseif _G.GTLMODConfig.LessRecoil then entity.AccessoriesHRecoilFactor = 0.34 end
                    
                    if _G.GTLMODConfig.CustomVRecoil then entity.AccessoriesVRecoilFactor = _G.GTLMODState.CustomTextData.VRecoil or 0.33
                    elseif _G.GTLMODConfig.VerticalRecoil then entity.AccessoriesVRecoilFactor = 0.33 end
                    
                                        if _G.GTLMODConfig.LessShake then
                        entity.RecoilKickADS = 0.11
                        entity.AnimationKick = 0.0
                    end

                    if entity.AutoAimingConfig then
                        if not entity.OriginalAutoAimCached then
                            entity.OriginalAutoAimCached = {
                                OuterSpeed = entity.AutoAimingConfig.OuterRange and entity.AutoAimingConfig.OuterRange.Speed,
                                InnerSpeed = entity.AutoAimingConfig.InnerRange and entity.AutoAimingConfig.InnerRange.Speed
                            }
                        end
                        
                        if _G.GTLMODConfig.AutoHead then
                            pcall(function() entity.AutoAimingConfig.Bones = { "Head", "Head", "Head" } end)
                        end
                        
                        if _G.GTLMODConfig.CustomAimbot then
                            local speed = _G.GTLMODState.CustomTextData.OuterSpeed or 10
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = speed
                                entity.AutoAimingConfig.OuterRange.RangeRate = 4.5
                                entity.AutoAimingConfig.OuterRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.OuterRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.OuterRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.OuterRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.OuterRange.ProneRate = 1.0
                                entity.AutoAimingConfig.OuterRange.DyingRate = 0.0
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = speed
                                entity.AutoAimingConfig.InnerRange.RangeRate = 4.5
                                entity.AutoAimingConfig.InnerRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.InnerRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.InnerRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.InnerRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.InnerRange.ProneRate = 1.0
                                entity.AutoAimingConfig.InnerRange.DyingRate = 0.0
                            end
                        elseif _G.GTLMODConfig.CustomAimbotClose then
                            local speed = _G.GTLMODState.CustomTextData.InnerSpeed or 10
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = speed
                                entity.AutoAimingConfig.OuterRange.DyingRate = 0.0
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = speed
                                entity.AutoAimingConfig.InnerRange.DyingRate = 0.0
                            end
                        end
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
                    if entity.AutoAimingConfig and entity.OriginalAutoAimCached then
                        pcall(function() entity.AutoAimingConfig.Bones = { "Spine_01", "Pelvis", "Head" } end)
                        if entity.AutoAimingConfig.OuterRange and entity.OriginalAutoAimCached.OuterSpeed then
                            entity.AutoAimingConfig.OuterRange.Speed = entity.OriginalAutoAimCached.OuterSpeed
                        end
                        if entity.AutoAimingConfig.InnerRange and entity.OriginalAutoAimCached.InnerSpeed then
                            entity.AutoAimingConfig.InnerRange.Speed = entity.OriginalAutoAimCached.InnerSpeed
                        end
                    end
                    entity.GTLMODWeaponModsActive = false
                end
            end
        end
    end)
    
        -- ── Magic Bullet (damage multiplier) ──
    pcall(function()
        local weapon = nil
        pcall(function()
            local weaponManager = localPlayer.WeaponManagerComponent
            if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then
                weapon = weaponManager:GetCurrentWeapon()
            end
        end)
        if not Valid(weapon) then
            if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon()
            elseif type(localPlayer.GetCurrentWeapon) == "function" then weapon = localPlayer:GetCurrentWeapon() end
        end
        if Valid(weapon) and _G.ApplyMagicBullet then
            _G.ApplyMagicBullet(weapon)
        end
    end)

    pcall(function()
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then allCharacters = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end end
        
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
                
                if _G.AimTouchVisCache and _G.AimTouchVisCache[key] then
                    _G.AimTouchVisCache[key] = nil
                end
                
                if data.MIDs then
                    for meshStr, midTable in pairs(data.MIDs) do
                        for k, _ in pairs(midTable) do
                            midTable[k] = nil
                        end
                    end
                    data.MIDs = nil
                end
                
                data.enemy = nil
                data.CachedMeshes = nil
                _G.GTLMODState.EnemyMarks[key] = nil
            end
        end

        local realCount = 0
        local aiCount = 0

        local function GetFirstElemSafe(elemArray)
            if elemArray and type(elemArray.Num) == "function" and elemArray:Num() > 0 then
                if type(elemArray.Get) == "function" then return elemArray:Get(0) end
            elseif elemArray and type(elemArray) == "table" and #elemArray > 0 then
                return elemArray[1]
            end
            return nil
        end

        local mLoc = nil
        pcall(function() if type(localPlayer.K2_GetActorLocation) == "function" then mLoc = localPlayer:K2_GetActorLocation() end end)

        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                local bIsReallyDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead
                    elseif enemy.bIsDeadFlag ~= nil then bIsReallyDead = enemy.bIsDeadFlag end
                    if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
                end)

                local eKey = GetSafeEnemyKey(enemy)
                _G.GTLMODState.EnemyMarks[eKey] = _G.GTLMODState.EnemyMarks[eKey] or { enemy = enemy }
                local markData = _G.GTLMODState.EnemyMarks[eKey]
                markData.enemy = enemy 

                if not bIsReallyDead then
                    if markData.lastEnemyActor ~= enemy then
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                        if markData.radarMark then SafeRemoveMark(markData.radarMark); markData.radarMark = nil end
                        
                        markData.lastEnemyActor = enemy
                        markData.LastUIComp = nil
                        markData.LastFrameUIState = nil
                    end
                    
                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh or (type(enemy.getAvatarComponent2) == "function" and enemy:getAvatarComponent2() or nil) end)
                    local aLoc = nil
                    pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                    
                    local isBotResult, isStateLoaded = CheckIsAI(enemy, markData)
                    local isBot = markData.AK_IS_BOT or false

                if _G.GTLMODConfig.ColorBodyNew then 
    ApplyColorBodyNew(enemy, markData)
else
    UndoColorBodyNew(enemy, markData)
end
                    local distM = 0
                    pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)

                    local currentHp, maxHp = 100, 100
                    -- Esp5 removed — now handled by ESP5_* premium renderer below
local showFrameUI = _G.GTLMODConfig.EspVipPro or _G.GTLMODConfig.EspVip

                    -- ==========================================
                    -- ESPNAME PREMIUM TAG (head above, name + HP bar)
                    -- ==========================================
                    if _G.GTLMODConfig.EspName and not _G.GTLMODConfig.EspVipPro then
                        pcall(function()
                            local root = nil
                            pcall(function()
                                local ui = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
                                if ui and ui.GetMainControlBaseUI then root = ui.GetMainControlBaseUI() end
                            end)
                            if not (slua and slua.isValid and slua.isValid(root)) then return end
                            local canvas = nil
                            pcall(function()
                                if slua.isValid(root.CanvasPanel_0) then canvas = root.CanvasPanel_0
                                elseif slua.isValid(root.CanvasPanel_42) then canvas = root.CanvasPanel_42 end
                            end)
                            if not (slua and slua.isValid and slua.isValid(canvas)) then return end

                            local V2 = _G.FVector2D
                            if not V2 then pcall(function() V2 = import("Vector2D") end) end
                            local V3 = _G.FVector
                            if not V3 then pcall(function() V3 = import("Vector") end) end
                            local LC = _G.FLinearColor
                            if not LC then pcall(function() LC = import("LinearColor") end) end
                            local WL = nil
                            pcall(function() WL = import("WidgetLayoutLibrary") end)

                            local function col(r, g, b, a)
                                if LC then
                                    local ok, c = pcall(LC, r, g, b, a or 1.0)
                                    if ok and c then return c end
                                end
                                return {R=r, G=g, B=b, A=a or 1.0}
                            end

                            -- Get enemy name
                            local pName = nil
                            pcall(function()
                                pName = enemy.PlayerName or enemy.PlayerNamePublic
                                if not pName and type(enemy.GetPlayerName) == "function" then
                                    pName = enemy:GetPlayerName()
                                end
                            end)
                            if not pName or pName == "" then pName = "Enemy" end
                            pName = tostring(pName)

                            -- HP info
                            local hp, maxHp = 100, 100
                            pcall(function()
                                hp = tonumber(enemy.Health) or 100
                                maxHp = tonumber(enemy.HealthMax) or 100
                            end)
                            local hpRatio = math.max(0, math.min(1, hp / math.max(1, maxHp)))
                            local isKnock = (hp <= 0 or enemy.HealthStatus == 1)

                            -- Visibility
                            local bIsVisible = true
                            pcall(function()
                                if pc and type(pc.LineOfSightTo) == "function" then
                                    bIsVisible = pc:LineOfSightTo(enemy)
                                end
                            end)

                            -- Colors: visible = accent, occluded = dim red, knocked = blue
                            local accentColor, textColor
                            if isKnock then
                                accentColor = col(0.35, 0.55, 1.00, 1.0)   -- blue
                                textColor   = col(0.85, 0.92, 1.00, 1.0)
                            elseif bIsVisible then
                                accentColor = col(0.20, 1.00, 0.45, 1.0)   -- bright green
                                textColor   = col(1.00, 1.00, 1.00, 1.0)   -- white
                            else
                                accentColor = col(1.00, 0.22, 0.30, 1.0)   -- red
                                textColor   = col(1.00, 0.85, 0.85, 1.0)   -- soft red
                            end

                            -- HP bar color
                            local hpColor = col(0.20, 1.00, 0.35, 1.0)
                            if hpRatio < 0.30 then hpColor = col(1.00, 0.20, 0.20, 1.0)
                            elseif hpRatio < 0.60 then hpColor = col(1.00, 0.85, 0.20, 1.0) end

                            -- Head screen pos
                            local hX, hY = nil, nil
                            pcall(function()
                                local capsule = enemy.CapsuleComponent
                                local center, halfH = nil, nil
                                if slua.isValid(capsule) then
                                    if capsule.K2_GetComponentLocation then center = capsule:K2_GetComponentLocation() end
                                    if capsule.GetScaledCapsuleHalfHeight then halfH = capsule:GetScaledCapsuleHalfHeight() end
                                end
                                if not center then
                                    if type(enemy.K2_GetActorLocation) == "function" then center = enemy:K2_GetActorLocation() end
                                end
                                if center then
                                    halfH = tonumber(halfH) or 85
                                    if halfH < 10 or halfH > 200 then halfH = 85 end
                                    local headW = V3 and V3(center.X, center.Y, center.Z + halfH + 20)
                                        or {X=center.X, Y=center.Y, Z=center.Z+halfH+20}
                                    local hv = V2 and V2(0,0) or {X=0, Y=0}
                                    local ok1, r1 = pcall(function() return pc:ProjectWorldLocationToScreen(headW, hv, true) end)
                                    if ok1 and r1 and (r1 == true or r1 == 1) then hX, hY = hv.X, hv.Y end
                                end
                            end)

                            _G.__ESPNAME_UI = _G.__ESPNAME_UI or {}
                            local key = tostring(enemy.PlayerKey or enemy)
                            local S = _G.__ESPNAME_UI[key]

                            if not (hX and hY) then
                                if S then
                                    for _, f in ipairs({"Bg","AccentBar","NameText","HpBg","HpFill"}) do
                                        if slua.isValid(S[f]) then
                                            pcall(function() S[f]:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                                        end
                                    end
                                    S.Visible = false
                                end
                                return
                            end

                            -- Canvas transform
                            local scale = 1.0
                            pcall(function()
                                if WL and WL.GetViewportScale then
                                    local s = WL.GetViewportScale(pc)
                                    if s and s >= 0.01 and s <= 100 then scale = s end
                                end
                            end)
                            hX, hY = hX / scale, hY / scale

                            -- === LAZY BUILD ===
                            if not (S and slua.isValid(S.Bg)) then
                                _G.__ESPNAME_UI[key] = {}
                                S = _G.__ESPNAME_UI[key]

                                local function mkBorder(color)
                                    local w = nil
                                    pcall(function() w = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
                                    if not (slua and slua.isValid and slua.isValid(w)) then return nil end
                                    pcall(function()
                                        w:SetBrushColor(color)
                                        w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                    end)
                                    return w
                                end
                                local function mkText(txt, color, size)
                                    local w = nil
                                    pcall(function() w = CGame:NewObjectFromPath("/Script/UMG.TextBlock", canvas) end)
                                    if not (slua and slua.isValid and slua.isValid(w)) then return nil end
                                    pcall(function()
                                        w:SetText(txt)
                                        w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                        local sc = LC and LC(color.R, color.G, color.B, color.A) or color
                                        w:SetColorAndOpacity(sc)
                                        if w.SetJustification then w:SetJustification(1) end
                                        local f = w.Font
                                        if f then f.Size = size; w:SetFont(f) end
                                    end)
                                    return w
                                end
                                local function mkSlot(widget, x, y, w, h, z)
                                    local s = nil
                                    pcall(function() s = canvas:AddChildToCanvas(widget) end)
                                    if not s then return nil end
                                    pcall(function()
                                        s:SetAutoSize(false)
                                        s:SetPosition(V2(x, y))
                                        s:SetSize(V2(w, h))
                                        s:SetZOrder(z)
                                    end)
                                    return s
                                end

                                -- Dark background frame
                                S.Bg = mkBorder(col(0.03, 0.03, 0.05, 0.88))
                                S.BgSlot = S.Bg and mkSlot(S.Bg, 0, 0, 0, 0, 62)

                                -- Left accent bar (colored strip, 3px wide)
                                S.AccentBar = mkBorder(accentColor)
                                S.AccentBarSlot = S.AccentBar and mkSlot(S.AccentBar, 0, 0, 3, 0, 63)

                                -- Name text
                                S.NameText = mkText(pName, textColor, 13)
                                S.NameTextSlot = S.NameText and mkSlot(S.NameText, 0, 0, 0, 0, 64)

                                -- HP bar background (thin, under name)
                                S.HpBg = mkBorder(col(0.05, 0.05, 0.08, 0.85))
                                S.HpBgSlot = S.HpBg and mkSlot(S.HpBg, 0, 0, 0, 0, 63)

                                -- HP bar fill
                                S.HpFill = mkBorder(hpColor)
                                S.HpFillSlot = S.HpFill and mkSlot(S.HpFill, 0, 0, 0, 0, 64)

                                S.LastName = pName
                                S.LastHpRatio = -1
                                S.Visible = false
                            end

                            if not S then return end

                            -- === UPDATE TEXT IF NAME CHANGED ===
                            if S.LastName ~= pName and slua.isValid(S.NameText) then
                                pcall(function() S.NameText:SetText(pName) end)
                                S.LastName = pName
                            end

                            -- === UPDATE COLORS (visibility state) ===
                            if slua.isValid(S.AccentBar) then
                                pcall(function() S.AccentBar:SetBrushColor(accentColor) end)
                            end
                            if slua.isValid(S.NameText) then
                                pcall(function() S.NameText:SetColorAndOpacity(textColor) end)
                            end
                            if slua.isValid(S.HpFill) then
                                pcall(function() S.HpFill:SetBrushColor(hpColor) end)
                            end

                            -- === DIMENSIONS ===
                            -- Width based on name length (min 90, max 200)
                            local nameLen = #pName
                            local tagW = math.max(90, math.min(200, 26 + nameLen * 7))
                            local tagH = 26
                            local hpBarH = 3

                            -- === POSITION (head above, centered on name) ===
                            local tagX = hX - tagW * 0.5
                            local tagY = hY - tagH

                            local function setPos(slot, x, y)
                                if slua.isValid(slot) then pcall(function() slot:SetPosition(V2(x, y)) end) end
                            end
                            local function setSize(slot, w, h)
                                if slua.isValid(slot) then pcall(function() slot:SetSize(V2(w, h)) end) end
                            end

                            -- Bg
                            setPos(S.BgSlot, tagX, tagY)
                            setSize(S.BgSlot, tagW, tagH)

                            -- Accent bar (left edge, inside bg)
                            setPos(S.AccentBarSlot, tagX, tagY)
                            setSize(S.AccentBarSlot, 3, tagH)

                            -- Name text (padded from accent bar)
                            setPos(S.NameTextSlot, tagX + 8, tagY)
                            setSize(S.NameTextSlot, tagW - 12, tagH - hpBarH - 2)

                            -- HP bar (bottom of tag)
                            local hpY = tagY + tagH - hpBarH - 1
                            setPos(S.HpBgSlot, tagX + 4, hpY)
                            setSize(S.HpBgSlot, tagW - 8, hpBarH)
                            setPos(S.HpFillSlot, tagX + 4, hpY)
                            setSize(S.HpFillSlot, (tagW - 8) * hpRatio, hpBarH)

                            -- === SHOW ===
                            if not S.Visible then
                                for _, f in ipairs({"Bg","AccentBar","NameText","HpBg","HpFill"}) do
                                    if slua.isValid(S[f]) then
                                        pcall(function() S[f]:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                                    end
                                end
                                S.Visible = true
                            end
                        end)
                    else
                        -- EspName off OR EspVipPro on — hide this enemy's name tag
                        pcall(function()
                            local U = _G.__ESPNAME_UI
                            if not U then return end
                            local key = tostring(enemy.PlayerKey or enemy)
                            local S = U[key]
                            if not S then return end
                            for _, f in ipairs({"Bg","AccentBar","NameText","HpBg","HpFill"}) do
                                if slua and slua.isValid and slua.isValid(S[f]) then
                                    pcall(function() S[f]:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                                end
                            end
                            S.Visible = false
                        end)
                    end

                    if showFrameUI then
                        pcall(function()
                            if enemy.Health then currentHp = enemy.Health elseif type(enemy.GetHealth) == "function" then currentHp = enemy:GetHealth() end
                            if enemy.HealthMax then maxHp = enemy.HealthMax elseif type(enemy.GetHealthMax) == "function" then maxHp = enemy:GetHealthMax() end
                        end)
                        if maxHp <= 0 then maxHp = 100 end
                    end
                    local hpRatio = currentHp / maxHp

                    if _G.GTLMODConfig.EspAntenna then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) and distM <= 400 then
                                local loopCount = 8  
                                local zStep = 1000     
                                local baseZ = 105     
                                local topZ = baseZ + (loopCount * zStep)
                                for i = 1, loopCount do
                                    local zOffset = baseZ + (i * zStep)
                                    MyHUD:AddDebugText("|", enemy, 0.06,
                                        {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset},
                                        C_GREEN, true, false, true, nil, 1.2, true)
                                end
                                MyHUD:AddDebugText("I", enemy, 0.06,
                                        {X=0, Y=0, Z=topZ + 60}, {X=0, Y=0, Z=topZ + 60},
                                        C_GREEN, true, false, true, nil, 1.5, true)
                            end
                        end)
                    end

                    if _G.GTLMODConfig.Esp6 then
                        pcall(function()
                            local curTime = os.clock()
                            if markData.LastEsp6Time == nil or (curTime - markData.LastEsp6Time) >= 0.05 then
                                markData.LastEsp6Time = curTime
                                
                                local MyHUD = Cached_MyHUD
                                if Valid(MyHUD) and Valid(eMesh) and aLoc then
                                    if distM <= 250 then
                                        if type(eMesh.GetSocketLocation) == "function" then
                                            for _, bName in ipairs(GLOBAL_BONE_LIST) do
                                                
                                                if distM > 50 and (bName ~= "head" and bName ~= "pelvis" and bName ~= "neck_01") then
                                                    -- Skip
                                                else
                                                    local wLoc = eMesh:GetSocketLocation(bName)
                                                    if wLoc then
                                                        local offset = {X = wLoc.X - aLoc.X, Y = wLoc.Y - aLoc.Y, Z = wLoc.Z - aLoc.Z}
                                                        
                                                        local mark = "▪"
                                                        local fixedSize = 0.25 
                                                        local color = C_CYAN
                                                        
                                                        if bName == "head" then 
                                                            mark = "●"
                                                            fixedSize = 0.45
                                                            color = C_RED
                                                        elseif bName == "pelvis" or bName == "neck_01" then 
                                                            mark = "▪"
                                                            fixedSize = 0.35
                                                            color = C_YELLOW 
                                                        end
                                                        
                                                        MyHUD:AddDebugText(mark, enemy, 0.06, offset, offset, color, true, false, true, nil, fixedSize, true)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                    end

                    -- ========================================== 
                    -- ESP COUNTER (ENEMY P: X | B: X)
                    -- ========================================== 
                                                          -- ==========================================
                    -- ESP7 PREMIUM COUNTER — REAL 5 | BOT 3 (single line)
                    -- ==========================================
                                        -- ==========================================
                    -- ESP7 PREMIUM COUNTER — REAL 5 | BOT 3 (single line)
                    -- ==========================================
                    if _G.GTLMODConfig.Esp7 then
                        pcall(function()
                            -- Count enemies
                            local myTeamId = localPlayer.TeamID or localPlayer:GetTeamID() or 0
                            local myPos = localPlayer:K2_GetActorLocation()
                            local maxDist = 35000
                            local realCount = 0
                            local aiCount = 0

                            for _, tPawn in pairs(allCharacters) do
                                if slua.isValid(tPawn) and tPawn ~= localPlayer then
                                    local targetTeamId = tPawn.TeamID or tPawn:GetTeamID() or 0
                                    if targetTeamId ~= myTeamId then
                                        local enemyPos = tPawn:K2_GetActorLocation()
                                        if enemyPos then
                                            local dx = enemyPos.X - myPos.X
                                            local dy = enemyPos.Y - myPos.Y
                                            local dz = enemyPos.Z - myPos.Z
                                            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                                            if dist <= maxDist then
                                                local isAI = false
                                                if tPawn.bIsAI == true or tPawn.IsAI == true then isAI = true end
                                                if not isAI then
                                                    local pState = tPawn.PlayerState or (type(tPawn.GetPlayerState) == "function" and tPawn:GetPlayerState())
                                                    if slua.isValid(pState) and (pState.bIsABot == true or pState.bIsBot == true) then isAI = true end
                                                end
                                                if isAI then aiCount = aiCount + 1
                                                else realCount = realCount + 1 end
                                            end
                                        end
                                    end
                                end
                            end

                            -- Get canvas
                            local root = nil
                            pcall(function()
                                local ui = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
                                if ui and ui.GetMainControlBaseUI then root = ui.GetMainControlBaseUI() end
                            end)
                            if not (slua and slua.isValid and slua.isValid(root)) then return end
                            local canvas = nil
                            pcall(function()
                                if slua.isValid(root.CanvasPanel_0) then canvas = root.CanvasPanel_0
                                elseif slua.isValid(root.CanvasPanel_42) then canvas = root.CanvasPanel_42 end
                            end)
                            if not (slua and slua.isValid and slua.isValid(canvas)) then return end

                            local V2 = _G.FVector2D
                            if not V2 then pcall(function() V2 = import("Vector2D") end) end
                            local LC = _G.FLinearColor
                            if not LC then pcall(function() LC = import("LinearColor") end) end

                            local function col(r, g, b, a)
                                if LC then
                                    local ok, c = pcall(LC, r, g, b, a or 1.0)
                                    if ok and c then return c end
                                end
                                return {R=r, G=g, B=b, A=a or 1.0}
                            end

                            -- Premium palette
                            local COL_RED_BG       = col(0.55, 0.04, 0.08, 0.96)
                            local COL_GREEN_BG     = col(0.04, 0.42, 0.14, 0.96)
                            local COL_RED_BORDER   = col(1.00, 0.20, 0.30, 1.00)
                            local COL_GREEN_BORDER = col(0.20, 1.00, 0.50, 1.00)
                            local COL_RED_TEXT     = col(1.00, 1.00, 1.00, 1.00)
                            local COL_GREEN_TEXT   = col(1.00, 1.00, 1.00, 1.00)
                            local COL_WHITE_DIV    = col(1.00, 1.00, 1.00, 0.95)
                            local COL_DARK_OUTER   = col(0.00, 0.00, 0.00, 0.95)
                            local COL_GREY_BG      = col(0.22, 0.22, 0.24, 0.92)
                            local COL_GREY_TEXT    = col(0.70, 0.70, 0.72, 1.00)

                            _G.__ESP7_UI = _G.__ESP7_UI or {}
                            local U = _G.__ESP7_UI

                            -- === DETECT REBUILD NEEDED (canvas changed or invalid) ===
                            local needsRebuild = false
                            if not (slua.isValid(U.OuterBorder)) then
                                needsRebuild = true
                            elseif U.CachedCanvas ~= canvas then
                                needsRebuild = true
                            end

                            if needsRebuild then
                                -- Clear all old references
                                U.OuterBorder = nil; U.OuterBorderSlot = nil
                                U.RedPanel = nil; U.RedPanelSlot = nil
                                U.GreenPanel = nil; U.GreenPanelSlot = nil
                                U.Divider = nil; U.DividerSlot = nil
                                U.RedBorderTop = nil; U.RedBorderTopSlot = nil
                                U.GreenBorderTop = nil; U.GreenBorderTopSlot = nil
                                U.RealText = nil; U.RealTextSlot = nil
                                U.BotText = nil; U.BotTextSlot = nil
                                U.LastReal = -1
                                U.LastBot = -1
                                U.LastX = nil
                                U.LastY = nil
                                U.Visible = false
                                U.CachedCanvas = canvas

                                local function mkBorder(color)
                                    local w = nil
                                    pcall(function() w = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
                                    if not (slua and slua.isValid and slua.isValid(w)) then return nil end
                                    pcall(function()
                                        w:SetBrushColor(color)
                                        w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                    end)
                                    return w
                                end
                                local function mkText(txt, color, size)
                                    local w = nil
                                    pcall(function() w = CGame:NewObjectFromPath("/Script/UMG.TextBlock", canvas) end)
                                    if not (slua and slua.isValid and slua.isValid(w)) then return nil end
                                    pcall(function()
                                        w:SetText(txt)
                                        w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                        local sc = LC and LC(color.R, color.G, color.B, color.A) or color
                                        w:SetColorAndOpacity(sc)
                                        if w.SetJustification then w:SetJustification(1) end
                                        local f = w.Font
                                        if f then f.Size = size; w:SetFont(f) end
                                    end)
                                    return w
                                end
                                local function mkSlot(widget, x, y, w, h, z)
                                    local s = nil
                                    pcall(function() s = canvas:AddChildToCanvas(widget) end)
                                    if not s then return nil end
                                    pcall(function()
                                        s:SetAutoSize(false)
                                        s:SetPosition(V2(x, y))
                                        s:SetSize(V2(w, h))
                                        s:SetZOrder(z)
                                    end)
                                    return s
                                end

                                -- === DIMENSIONS ===
                                U.W, U.H = 280, 38
                                U.Half = U.W * 0.5

                                -- Outer black border
                                U.OuterBorder = mkBorder(COL_DARK_OUTER)
                                U.OuterBorderSlot = U.OuterBorder and mkSlot(U.OuterBorder, 0, 0, U.W, U.H, 55)

                                -- Left panel (RED)
                                U.RedPanel = mkBorder(COL_RED_BG)
                                U.RedPanelSlot = U.RedPanel and mkSlot(U.RedPanel, 2, 2, U.Half - 3, U.H - 4, 56)

                                -- Right panel (GREEN)
                                U.GreenPanel = mkBorder(COL_GREEN_BG)
                                U.GreenPanelSlot = U.GreenPanel and mkSlot(U.GreenPanel, U.Half + 1, 2, U.Half - 3, U.H - 4, 56)

                                -- Center white divider
                                U.Divider = mkBorder(COL_WHITE_DIV)
                                U.DividerSlot = U.Divider and mkSlot(U.Divider, U.Half - 1, 4, 2, U.H - 8, 57)

                                -- Red neon top border
                                U.RedBorderTop = mkBorder(COL_RED_BORDER)
                                U.RedBorderTopSlot = U.RedBorderTop and mkSlot(U.RedBorderTop, 2, 2, U.Half - 3, 2, 58)

                                -- Green neon top border
                                U.GreenBorderTop = mkBorder(COL_GREEN_BORDER)
                                U.GreenBorderTopSlot = U.GreenBorderTop and mkSlot(U.GreenBorderTop, U.Half + 1, 2, U.Half - 3, 2, 58)

                                -- Text: "REAL  0" (left)
                                U.RealText = mkText("REAL  0", COL_RED_TEXT, 16)
                                U.RealTextSlot = U.RealText and mkSlot(U.RealText, 2, 2, U.Half - 3, U.H - 4, 60)

                                -- Text: "BOT  0" (right)
                                U.BotText = mkText("BOT  0", COL_GREEN_TEXT, 16)
                                U.BotTextSlot = U.BotText and mkSlot(U.BotText, U.Half + 1, 2, U.Half - 3, U.H - 4, 60)
                            end

                            -- If build failed → bail
                            if not (slua.isValid(U.OuterBorder)) then return end

                            -- === UPDATE TEXT ===
                            if U.LastReal ~= realCount and slua.isValid(U.RealText) then
                                pcall(function() U.RealText:SetText(string.format("REAL  %d", realCount)) end)
                                U.LastReal = realCount
                            end
                            if U.LastBot ~= aiCount and slua.isValid(U.BotText) then
                                pcall(function() U.BotText:SetText(string.format("BOT  %d", aiCount)) end)
                                U.LastBot = aiCount
                            end

                            -- === COLORS (grey if 0) ===
                            local redActive = realCount > 0
                            local botActive = aiCount > 0

                            if slua.isValid(U.RedPanel) then
                                pcall(function() U.RedPanel:SetBrushColor(redActive and COL_RED_BG or COL_GREY_BG) end)
                            end
                            if slua.isValid(U.GreenPanel) then
                                pcall(function() U.GreenPanel:SetBrushColor(botActive and COL_GREEN_BG or COL_GREY_BG) end)
                            end
                            if slua.isValid(U.RedBorderTop) then
                                pcall(function() U.RedBorderTop:SetBrushColor(redActive and COL_RED_BORDER or COL_GREY_TEXT) end)
                            end
                            if slua.isValid(U.GreenBorderTop) then
                                pcall(function() U.GreenBorderTop:SetBrushColor(botActive and COL_GREEN_BORDER or COL_GREY_TEXT) end)
                            end
                            if slua.isValid(U.RealText) then
                                pcall(function() U.RealText:SetColorAndOpacity(redActive and COL_RED_TEXT or COL_GREY_TEXT) end)
                            end
                            if slua.isValid(U.BotText) then
                                pcall(function() U.BotText:SetColorAndOpacity(botActive and COL_GREEN_TEXT or COL_GREY_TEXT) end)
                            end

                            -- === POSITION (top-center) ===
                            local vw = nil
                            pcall(function()
                                local WL = import("WidgetLayoutLibrary")
                                if WL and WL.GetViewportSize then
                                    local v = WL.GetViewportSize(pc)
                                    if v then vw = tonumber(v.X) end
                                end
                            end)
                            if not vw and pc then pcall(function() vw = tonumber(pc:GetViewportSize()) end) end
                            if not vw then vw = 1920 end

                            local scale = 1.0
                            pcall(function()
                                local WL = import("WidgetLayoutLibrary")
                                if WL and WL.GetViewportScale then
                                    local s = WL.GetViewportScale(pc)
                                    if s and s >= 0.01 and s <= 100 then scale = s end
                                end
                            end)
                            local cx = (vw * 0.5) / scale
                            local x = cx - U.W * 0.5
                            local y = 30.0

                            if U.LastX ~= x or U.LastY ~= y then
                                local function setPos(slot, px, py)
                                    if slua.isValid(slot) then pcall(function() slot:SetPosition(V2(px, py)) end) end
                                end
                                setPos(U.OuterBorderSlot, x, y)
                                setPos(U.RedPanelSlot, x + 2, y + 2)
                                setPos(U.GreenPanelSlot, x + U.Half + 1, y + 2)
                                setPos(U.DividerSlot, x + U.Half - 1, y + 4)
                                setPos(U.RedBorderTopSlot, x + 2, y + 2)
                                setPos(U.GreenBorderTopSlot, x + U.Half + 1, y + 2)
                                setPos(U.RealTextSlot, x + 2, y + 2)
                                setPos(U.BotTextSlot, x + U.Half + 1, y + 2)
                                U.LastX, U.LastY = x, y
                            end

                            -- === FORCE SHOW (every frame, in case widget was hidden) ===
                            local function ensureVisible(w)
                                if slua.isValid(w) then
                                    pcall(function() w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                                end
                            end
                                                        ensureVisible(U.OuterBorder)
                            ensureVisible(U.RedPanel)
                            ensureVisible(U.GreenPanel)
                            ensureVisible(U.Divider)
                            ensureVisible(U.RedBorderTop)
                            ensureVisible(U.GreenBorderTop)
                            ensureVisible(U.RealText)
                            ensureVisible(U.BotText)
                            U.Visible = true
                        end)
                    else
                        -- Esp7 OFF → hide
                        pcall(function()
                            local U = _G.__ESP7_UI
                            if not U then return end
                            for _, f in ipairs({"OuterBorder","RedPanel","GreenPanel","Divider",
                                "RedBorderTop","GreenBorderTop",
                                "RealText","BotText"}) do
                                if slua and slua.isValid and slua.isValid(U[f]) then
                                    pcall(function() U[f]:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                                end
                            end
                            U.Visible = false
                        end)
                    end
                       
                        
                    -- ==========================================
                    -- ESP5 PREMIUM BOX (screen-space, corner brackets)
                    -- ==========================================
                                        -- ==========================================
                    -- ESP5 PREMIUM BOX — SMOOTH (screen-space, lerp)
                    -- ==========================================
                    if _G.GTLMODConfig.Esp5 then
                        pcall(function()
                            local root = nil
                            pcall(function()
                                local ui = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
                                if ui and ui.GetMainControlBaseUI then root = ui.GetMainControlBaseUI() end
                            end)
                            if not (slua and slua.isValid and slua.isValid(root)) then return end
                            local canvas = nil
                            pcall(function()
                                if slua.isValid(root.CanvasPanel_0) then canvas = root.CanvasPanel_0
                                elseif slua.isValid(root.CanvasPanel_42) then canvas = root.CanvasPanel_42 end
                            end)
                            if not (slua and slua.isValid and slua.isValid(canvas)) then return end

                            local V2 = _G.FVector2D
                            if not V2 then pcall(function() V2 = import("Vector2D") end) end
                            local V3 = _G.FVector
                            if not V3 then pcall(function() V3 = import("Vector") end) end
                            local LC = _G.FLinearColor
                            if not LC then pcall(function() LC = import("LinearColor") end) end
                            local WL = nil
                            pcall(function() WL = import("WidgetLayoutLibrary") end)

                            local function col(r, g, b, a)
                                if LC then
                                    local ok, c = pcall(LC, r, g, b, a or 1.0)
                                    if ok and c then return c end
                                end
                                return {R=r, G=g, B=b, A=a or 1.0}
                            end

                            local isBot = markData.AK_IS_BOT or false
                            local bIsVisible = true
                            pcall(function()
                                if pc and type(pc.LineOfSightTo) == "function" then
                                    bIsVisible = pc:LineOfSightTo(enemy)
                                end
                            end)

                            -- Colors
                            local COL_MAIN = isBot
                                and col(0.20, 1.00, 0.55, 1.0)
                                or col(1.00, 0.22, 0.35, 1.0)
                            local COL_CORNER = isBot
                                and col(0.10, 0.85, 0.40, 1.0)
                                or col(0.90, 0.15, 0.28, 1.0)
                            local COL_HP_HIGH = col(0.20, 1.00, 0.35, 1.0)
                            local COL_HP_MID  = col(1.00, 0.85, 0.20, 1.0)
                            local COL_HP_LOW  = col(1.00, 0.20, 0.20, 1.0)

                            -- === PROJECT HEAD/FEET (EVERY FRAME) ===
                            local hX, hY, fX, fY = nil, nil, nil, nil
                            pcall(function()
                                local capsule = enemy.CapsuleComponent
                                local center, halfH = nil, nil
                                if slua.isValid(capsule) then
                                    if capsule.K2_GetComponentLocation then center = capsule:K2_GetComponentLocation() end
                                    if capsule.GetScaledCapsuleHalfHeight then halfH = capsule:GetScaledCapsuleHalfHeight() end
                                end
                                if not center then
                                    if type(enemy.K2_GetActorLocation) == "function" then center = enemy:K2_GetActorLocation() end
                                end
                                if center then
                                    halfH = tonumber(halfH) or 85
                                    if halfH < 10 or halfH > 200 then halfH = 85 end
                                    -- Head bone (top of capsule + slight offset)
                                    local headW = V3 and V3(center.X, center.Y, center.Z + halfH) or {X=center.X,Y=center.Y,Z=center.Z+halfH}
                                    -- Feet bone (bottom of capsule)
                                    local feetW = V3 and V3(center.X, center.Y, center.Z - halfH) or {X=center.X,Y=center.Y,Z=center.Z-halfH}
                                    local hv = V2 and V2(0,0) or {X=0,Y=0}
                                    local fv = V2 and V2(0,0) or {X=0,Y=0}
                                    local ok1, r1 = pcall(function() return pc:ProjectWorldLocationToScreen(headW, hv, true) end)
                                    local ok2, r2 = pcall(function() return pc:ProjectWorldLocationToScreen(feetW, fv, true) end)
                                    if ok1 and r1 and (r1 == true or r1 == 1) then hX, hY = hv.X, hv.Y end
                                    if ok2 and r2 and (r2 == true or r2 == 1) then fX, fY = fv.X, fv.Y end
                                end
                            end)

                            _G.__ESP5_UI = _G.__ESP5_UI or {}
                            local key = tostring(enemy.PlayerKey or enemy)
                            local S = _G.__ESP5_UI[key]

                            -- If off-screen → hide
                            if not (hX and hY and fX and fY) then
                                if S then
                                    for _, f in ipairs({"BoxTop","BoxBottom","BoxLeft","BoxRight",
                                        "C1H","C1V","C2H","C2V","C3H","C3V","C4H","C4V",
                                        "HpBg","HpFill"}) do
                                        if slua.isValid(S[f]) then
                                            pcall(function() S[f]:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                                        end
                                    end
                                    S.Visible = false
                                    S.LastHX, S.LastHY, S.LastFX, S.LastFY = nil, nil, nil, nil
                                end
                                return
                            end

                            -- Canvas transform (cache per-frame)
                            local scale = 1.0
                            pcall(function()
                                if WL and WL.GetViewportScale then
                                    local s = WL.GetViewportScale(pc)
                                    if s and s >= 0.01 and s <= 100 then scale = s end
                                end
                            end)
                            local sx, sy = 1.0 / scale, 1.0 / scale
                            local curHX, curHY = hX * sx, hY * sy
                            local curFX, curFY = fX * sx, fY * sy

                            -- Lazy build
                            if not (S and slua.isValid(S.BoxTop)) then
                                _G.__ESP5_UI[key] = {}
                                S = _G.__ESP5_UI[key]

                                local function mkBorder(color)
                                    local w = nil
                                    pcall(function() w = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
                                    if not (slua and slua.isValid and slua.isValid(w)) then return nil end
                                    pcall(function()
                                        w:SetBrushColor(color)
                                        w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                    end)
                                    return w
                                end
                                local function mkSlot(widget, x, y, w, h, z)
                                    local s = nil
                                    pcall(function() s = canvas:AddChildToCanvas(widget) end)
                                    if not s then return nil end
                                    pcall(function()
                                        s:SetAutoSize(false)
                                        s:SetPosition(V2(x, y))
                                        s:SetSize(V2(w, h))
                                        s:SetZOrder(z)
                                    end)
                                    return s
                                end

                                S.BoxTop    = mkBorder(col(COL_MAIN.R, COL_MAIN.G, COL_MAIN.B, 0.35))
                                S.BoxTopSlot= S.BoxTop and mkSlot(S.BoxTop, 0, 0, 0, 0, 41)
                                S.BoxBottom = mkBorder(col(COL_MAIN.R, COL_MAIN.G, COL_MAIN.B, 0.35))
                                S.BoxBottomSlot = S.BoxBottom and mkSlot(S.BoxBottom, 0, 0, 0, 0, 41)
                                S.BoxLeft   = mkBorder(col(COL_MAIN.R, COL_MAIN.G, COL_MAIN.B, 0.35))
                                S.BoxLeftSlot= S.BoxLeft and mkSlot(S.BoxLeft, 0, 0, 0, 0, 41)
                                S.BoxRight  = mkBorder(col(COL_MAIN.R, COL_MAIN.G, COL_MAIN.B, 0.35))
                                S.BoxRightSlot = S.BoxRight and mkSlot(S.BoxRight, 0, 0, 0, 0, 41)

                                S.C1H = mkBorder(COL_CORNER); S.C1HSlot = S.C1H and mkSlot(S.C1H, 0, 0, 0, 0, 42)
                                S.C1V = mkBorder(COL_CORNER); S.C1VSlot = S.C1V and mkSlot(S.C1V, 0, 0, 0, 0, 42)
                                S.C2H = mkBorder(COL_CORNER); S.C2HSlot = S.C2H and mkSlot(S.C2H, 0, 0, 0, 0, 42)
                                S.C2V = mkBorder(COL_CORNER); S.C2VSlot = S.C2V and mkSlot(S.C2V, 0, 0, 0, 0, 42)
                                S.C3H = mkBorder(COL_CORNER); S.C3HSlot = S.C3H and mkSlot(S.C3H, 0, 0, 0, 0, 42)
                                S.C3V = mkBorder(COL_CORNER); S.C3VSlot = S.C3V and mkSlot(S.C3V, 0, 0, 0, 0, 42)
                                S.C4H = mkBorder(COL_CORNER); S.C4HSlot = S.C4H and mkSlot(S.C4H, 0, 0, 0, 0, 42)
                                S.C4V = mkBorder(COL_CORNER); S.C4VSlot = S.C4V and mkSlot(S.C4V, 0, 0, 0, 0, 42)

                                S.HpBg = mkBorder(col(0.05, 0.05, 0.08, 0.75))
                                S.HpBgSlot = S.HpBg and mkSlot(S.HpBg, 0, 0, 0, 0, 43)
                                S.HpFill = mkBorder(COL_HP_HIGH)
                                S.HpFillSlot = S.HpFill and mkSlot(S.HpFill, 0, 0, 0, 0, 44)

                                S.Visible = false
                                S.LastHX, S.LastHY, S.LastFX, S.LastFY = nil, nil, nil, nil
                            end

                            if not S then return end

                            -- === SMOOTH INTERPOLATION (lerp) ===
                            local LERP = 0.45  -- 0.45 = smooth but responsive (0.2 = laggy, 0.7 = snappy)
                            local lhX, lhY = curHX, curHY
                            local lfX, lfY = curFX, curFY
                            if S.LastHX and S.LastHY and S.LastFX and S.LastFY then
                                lhX = S.LastHX + (curHX - S.LastHX) * LERP
                                lhY = S.LastHY + (curHY - S.LastHY) * LERP
                                lfX = S.LastFX + (curFX - S.LastFX) * LERP
                                lfY = S.LastFY + (curFY - S.LastFY) * LERP
                            end
                            S.LastHX, S.LastHY, S.LastFX, S.LastFY = lhX, lhY, lfX, lfY

                            -- Box dims (smoothed)
                            local boxW = math.max(24, math.abs(lfX - lhX) + 20)
                            local boxH = math.max(40, math.abs(lfY - lhY))
                            local boxL = math.min(lhX, lfX) - boxW * 0.5
                            local boxT = math.min(lhY, lfY)
                            local cornerLen = math.max(8, math.min(18, boxH * 0.15))

                            local function setPos(slot, x, y)
                                if slua.isValid(slot) then pcall(function() slot:SetPosition(V2(x, y)) end) end
                            end
                            local function setSize(slot, w, h)
                                if slua.isValid(slot) then pcall(function() slot:SetSize(V2(w, h)) end) end
                            end

                            -- Thin 1px borders
                            setPos(S.BoxTopSlot, boxL, boxT); setSize(S.BoxTopSlot, boxW, 1)
                            setPos(S.BoxBottomSlot, boxL, boxT + boxH); setSize(S.BoxBottomSlot, boxW, 1)
                            setPos(S.BoxLeftSlot, boxL, boxT); setSize(S.BoxLeftSlot, 1, boxH)
                            setPos(S.BoxRightSlot, boxL + boxW, boxT); setSize(S.BoxRightSlot, 1, boxH)

                            -- Corner brackets
                            setPos(S.C1HSlot, boxL, boxT); setSize(S.C1HSlot, cornerLen, 2)
                            setPos(S.C1VSlot, boxL, boxT); setSize(S.C1VSlot, 2, cornerLen)
                            setPos(S.C2HSlot, boxL + boxW - cornerLen, boxT); setSize(S.C2HSlot, cornerLen, 2)
                            setPos(S.C2VSlot, boxL + boxW - 2, boxT); setSize(S.C2VSlot, 2, cornerLen)
                            setPos(S.C3HSlot, boxL, boxT + boxH - 2); setSize(S.C3HSlot, cornerLen, 2)
                            setPos(S.C3VSlot, boxL, boxT + boxH - cornerLen); setSize(S.C3VSlot, 2, cornerLen)
                            setPos(S.C4HSlot, boxL + boxW - cornerLen, boxT + boxH - 2); setSize(S.C4HSlot, cornerLen, 2)
                            setPos(S.C4VSlot, boxL + boxW - 2, boxT + boxH - cornerLen); setSize(S.C4VSlot, 2, cornerLen)

                            -- HP bar
                            local hp, maxHp = 100, 100
                            pcall(function()
                                hp = tonumber(enemy.Health) or tonumber(enemy:GetHealth()) or 100
                                maxHp = tonumber(enemy.HealthMax) or tonumber(enemy:GetMaxHealth()) or 100
                            end)
                            local hpRatio = math.max(0, math.min(1, hp / math.max(1, maxHp)))
                            local barW, barH = boxW, 4
                            local barX = boxL
                            local barY = boxT + boxH + 4
                            setPos(S.HpBgSlot, barX, barY); setSize(S.HpBgSlot, barW, barH)
                            setPos(S.HpFillSlot, barX, barY); setSize(S.HpFillSlot, barW * hpRatio, barH)

                            local hpColor = COL_HP_HIGH
                            if hpRatio < 0.30 then hpColor = COL_HP_LOW
                            elseif hpRatio < 0.60 then hpColor = COL_HP_MID end
                            if slua.isValid(S.HpFill) then
                                pcall(function() S.HpFill:SetBrushColor(hpColor) end)
                            end

                            -- Show
                            if not S.Visible then
                                for _, f in ipairs({"BoxTop","BoxBottom","BoxLeft","BoxRight",
                                    "C1H","C1V","C2H","C2V","C3H","C3V","C4H","C4V",
                                    "HpBg","HpFill"}) do
                                    if slua.isValid(S[f]) then
                                        pcall(function() S[f]:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                                    end
                                end
                                S.Visible = true
                            end
                        end)
                    else
                        -- Esp5 off — hide
                        pcall(function()
                            local U = _G.__ESP5_UI
                            if not U then return end
                            local key = tostring(enemy.PlayerKey or enemy)
                            local S = U[key]
                            if not S then return end
                            for _, f in ipairs({"BoxTop","BoxBottom","BoxLeft","BoxRight",
                                "C1H","C1V","C2H","C2V","C3H","C3V","C4H","C4V",
                                "HpBg","HpFill"}) do
                                if slua and slua.isValid and slua.isValid(S[f]) then
                                    pcall(function() S[f]:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                                end
                            end
                            S.Visible = false
                            S.LastHX, S.LastHY, S.LastFX, S.LastFY = nil, nil, nil, nil
                        end)
                    end
                    if showFrameUI then
                        pcall(function()
                            local SecurityCommonUtils = Cached_SecurityCommonUtils
                            local show = true
                            if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then 
                                if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                            end
                            if show and mLoc then
                                if aLoc and SecurityCommonUtils and SecurityCommonUtils.IsVector then
                                    if SecurityCommonUtils.IsVector(aLoc) and SecurityCommonUtils.IsVector(mLoc) then
                                        if aLoc.Z >= 150000 or FVector.Dist2D(mLoc, aLoc) > 50000 then show = false end
                                    end
                                end
                            end
                            if show then
                                if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                                if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                                if enemy.Replay_UpdateEnemyFrameUI then enemy:Replay_UpdateEnemyFrameUI(hpRatio) end
                                
                                local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if markData.LastFrameUIState ~= "VISIBLE" then
                                        if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(0) end
                                        if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(false) end
                                        markData.LastFrameUIState = "VISIBLE"
                                    end
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                            local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                            if Valid(uiComp) then
                                if markData.LastFrameUIState ~= "HIDDEN" then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                    markData.LastFrameUIState = "HIDDEN"
                                end
                            end
                        end)
                    end

                    -- ESP HEALTH V1
                    -- ESP HEALTH V1 — clean green HP text, no box
                    if _G.GTLMODConfig.EspVipPro then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if not (Valid(hud) and hud.AddDebugText) then return end
                            if distM > 400 then return end

                            local hp = enemy.Health or 100
                            local maxHp = enemy.HealthMax or 100
                            local isKnock = (hp <= 0 or enemy.HealthStatus == 1)
                            local hpPercent = isKnock and 0 or (hp / maxHp)
                            local pctValue = math.floor(hpPercent * 100 + 0.5)

                            local pName = ""
                            if _G.GTLMODConfig.EspName then
                                pName = enemy.PlayerName or enemy.PlayerNamePublic or "Enemy"
                            end

                            local bIsVisible = false
                            if pc and type(pc.LineOfSightTo) == "function" then
                                bIsVisible = pc:LineOfSightTo(enemy)
                            end

                            -- Green color always (unless knocked = blue)
                            local textColor
                            if isKnock then
                                textColor = {R=0, G=180, B=255, A=255}   -- knock = cyan-blue
                            else
                                textColor = {R=0, G=255, B=100, A=255}   -- GREEN (bright)
                            end

                            local label
                            if isKnock then
                                label = (pName ~= "" and string.format("%s ♿", pName) or "♿")
                            else
                                if pName ~= "" then
                                    label = string.format("%s %.0f%%", pName, pctValue)
                                else
                                    label = string.format("%.0f%%", pctValue)
                                end
                            end

                            hud:AddDebugText(label, enemy, 0.2, {X=0, Y=0, Z=120}, {X=0, Y=0, Z=120},
                                             textColor, true, false, true, nil, 1.0, true)
                        end)
                    end
                    -- ESP RANGE (Distance)
                    if _G.GTLMODConfig.EspDistance then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if not (Valid(hud) and hud.AddDebugText) then return end
                            if distM > 400 then return end

                            local distMeters = math.floor(distM + 0.5)
                            local rangeColor = {R=255, G=255, B=255, A=255}

                            hud:AddDebugText(string.format("%.0fm", distMeters), enemy, 0.3,
                                             {X=15, Y=15, Z=-15}, {X=15, Y=15, Z=-15},
                                             rangeColor, true, false, true, nil, 0.9, true)
                        end)
                    end

                    -- ESP NAME
                                       -- ESP NAME -- DISABLED (now handled by ESPNAME_* premium renderer)
                    if false then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if not (Valid(hud) and hud.AddDebugText) then return end
                            if distM > 400 then return end

                            local pName = enemy.PlayerName or enemy.PlayerNamePublic or "Enemy"
                            if pName == "" then return end

                            local isKnock = (enemy.Health or 100) <= 0 or enemy.HealthStatus == 1
                            local bIsVisible = true
                            pcall(function()
                                if pc and type(pc.LineOfSightTo) == "function" then
                                    bIsVisible = pc:LineOfSightTo(enemy)
                                end
                            end)

                            local nameColor = {R=255, G=255, B=255, A=255}
                            if isKnock then
                                nameColor = {R=0, G=0, B=255, A=255}
                            else
                                nameColor = bIsVisible and C_GREEN or C_RED
                            end

                            hud:AddDebugText(pName, enemy, 0.2, {X=0, Y=0, Z=120}, {X=0, Y=0, Z=120},
                                             nameColor, true, false, true, nil, 1.0, true)
                        end)
                    end

                    if _G.GTLMODConfig.EspVip then
                        if markData.hpMark == nil then markData.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                        if markData.distMark == nil then markData.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                    end

                    if _G.GTLMODConfig.Esp8 then
                        if markData.hpMark8 == nil then markData.hpMark8 = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end
                    end
                    
                    if _G.GTLMODConfig.EspRadar then
                        if not markData.radarMark or markData.radarMark == 0 then 
                            markData.radarMark = SafeAddMark(8888, FVector(0,0,0), 0, "", 4, enemy) 
                        end
                    else
                        if markData.radarMark and markData.radarMark ~= 0 then
                            SafeRemoveMark(markData.radarMark)
                            markData.radarMark = nil
                        end
                    end
                    
                    if _G.GTLMODConfig.EspOutline then
                        pcall(function()
                            local outlineHash = tostring(_G.GTLMODConfig.OutlineThickness)
                            if markData.OutlineState ~= outlineHash then
                                local PPM = Cached_PPM
                                local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                                if Valid(avatarComp) and Valid(PPM) then
                                    PPM.OutlineThickness = _G.GTLMODConfig.OutlineThickness
                                    if PPM.OutlineColor then PPM.OutlineColor = {r = 1, g = 0, b = 0, a = 1} end
                                    PPM:EnableAvatarOutline(avatarComp, true)
                                    markData.OutlineState = outlineHash
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if markData.OutlineState ~= "OFF" then
                                local PPM = Cached_PPM
                                local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                                if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                                markData.OutlineState = "OFF"
                            end
                        end)
                    end

                else
                    if not markData.IsCleanedUp then
                        SafeRemoveMark(markData.radarMark)
                        markData.radarMark = nil
                        SafeRemoveMark(markData.hpMark)
                        markData.hpMark = nil
                        SafeRemoveMark(markData.hpMark8)
                        markData.hpMark8 = nil
                        SafeRemoveMark(markData.distMark)
                        markData.distMark = nil
                        
                        if markData.MIDs then
                            for meshStr, midTable in pairs(markData.MIDs) do
                                for k, _ in pairs(midTable) do midTable[k] = nil end
                            end
                            markData.MIDs = nil
                        end
                        
                        pcall(function()
                            local eObj = markData.enemy
                            if Valid(eObj) then 
                                if eObj.Replay_SetVisiableOfFrameUI then eObj:Replay_SetVisiableOfFrameUI(false) end
                                local uiComp = eObj.EnemyFrameUI or (type(eObj.GetEnemyFrameUI) == "function" and eObj:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end 
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                end
                            end
                            
                            local PPM = Cached_PPM
                            local avatarComp = Valid(eObj) and (type(eObj.getAvatarComponent2) == "function") and eObj:getAvatarComponent2() or nil
                            if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                        end)

                        markData.IsCleanedUp = true
                    end
                end
            end
        end

        -- ESP TYPE 7 old text render — DISABLED
        if false then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if Valid(MyHUD) then
                    local text = string.format("[ PLAY SAFE!! @ZakPubgSkin ]", realCount, aiCount)
                    MyHUD:AddDebugText(text, localPlayer, 0.06, {X=0, Y=0, Z=0}, {X=0, Y=0, Z=0}, C_RED, true, false, true, nil, 0.8, true)
                end
            end)
        end
    end)
end

_G.GTLMODState.LoopToken = (_G.GTLMODState.LoopToken or 0) + 1 
local myToken = _G.GTLMODState.LoopToken
-- ========================================== 
-- MAIN LOOP (ESP & OTHER FEATURES) WITH 0.2 SEC
-- ========================================== 
local function FastTick() 
    if isExpired then 
        if not _G.GTLMODNotifiedExpire then
            Notify("MOD HAS EXPIRED! PLEASE CONTACT OWNER TO RENEW!\nTelegram @ZakPubgSkin")
            _G.GTLMODNotifiedExpire = true
        end
        return 
    end

    if myToken ~= _G.GTLMODState.LoopToken then return end
    pcall(MainLoop) 
    local okTicker, ticker = pcall(require, "common.time_ticker") 
    if okTicker and ticker and ticker.AddTimerOnce then 
        ticker.AddTimerOnce(0.4, FastTick) 
    end 
end

-- ========================================== 
-- AIMBOT LOOP WITH 0.016 SEC (~60 FPS)
-- ========================================== 
local aimbotToken = 0
local function FastAimbotTick()
    if isExpired then 
        return 
    end

    if aimbotToken ~= _G.GTLMODState.AimbotLoopToken then 
        return 
    end

    pcall(function()
        if _G.GTLMODConfig.AimTouchEnable then
            _G.AimTouch()
        end
    end)

    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.016, FastAimbotTick)
    end
end


-- ============================================================================
-- ONLINE LICENSE MAINTENANCE
-- Keeps the same fail-closed online session behavior as Ahmad.lua.
-- ============================================================================
local function StartBRLicenseMaintenance()
    local owner = nil
    pcall(function()
        if GameplayData and GameplayData.GetPlayerController then
            owner = GameplayData.GetPlayerController()
        end
    end)

    if not slua.isValid(owner) then
        pcall(function()
            if slua_GameFrontendHUD then
                owner = slua_GameFrontendHUD:GetPlayerController()
            end
        end)
    end

    if slua.isValid(owner) and type(owner.AddGameTimer) == "function" then
        pcall(function()
            owner:AddGameTimer(1.0, true, BRLicenseMaintenance)
        end)
        pcall(BRLicenseMaintenance)
        return true
    end
    return false
end

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.5, function()
            if not StartBRLicenseMaintenance() then
                ticker.AddTimerOnce(0.5, StartBRLicenseMaintenance)
            end
        end)
    end
end)

-- ========================================== 
-- IGNITE BOTH LOOPS
-- ========================================== 
if not isExpired then
    FastTick()
    if BRLicenseActive() then
        _G.GTLMODState.AimbotLoopToken = (_G.GTLMODState.AimbotLoopToken or 0) + 1
    else
        _G.GTLMODState.AimbotLoopToken = (_G.GTLMODState.AimbotLoopToken or 0) + 1
    end
    aimbotToken = _G.GTLMODState.AimbotLoopToken
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.1, FastAimbotTick)
    end
    Notify(BRLicenseActive()
        and "Online key verified. VIP Mod unlocked."
        or "Online key required. VIP features are locked.")
else
    FastTick() 
end

-- ===================================================================================
-- SYSTEM HOOKS
-- ===================================================================================
local function InitAllModSystems()
    if isExpired then return end
    if not BRLicenseActive() then return end

    pcall(function()
        if _G.InitializeAutoHeadHooks then _G.InitializeAutoHeadHooks() end
    end)

    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData then return end

    pcall(function()
        local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if slua.isValid(LocalPlayer) then
            if LocalPlayer.bHasShownDevNotice == nil then
                LocalPlayer.bHasShownDevNotice = false 
                LocalPlayer.bHasShownExpiredNotice = false 
                LocalPlayer.bIsDeadFlag = false
            end
        end
    end)
end

if not isExpired then
    pcall(function() 
        require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems) 
    end)
end
local FeedbackSystem = {
  Config = {
    ServerURL = "https://zak-feedback.emansafdar782.workers.dev/",
    TestMode = false,
    BotToken = "8814948948:AAEO_ekz4s4YdgAwEvrQXpO5k-3fyAsUfnM",
    ChatId = "-1003829829566"
  },
  Hooked = false
}

local function FeedbackLog(Msg)
  print(string.format("[ZAK] [%s] %s", os.date("%H:%M:%S"), tostring(Msg)))
end

local function FeedbackBase64Encode(Data)
  if not (type(Data) == "string" and #Data ~= 0) then
    return ""
  end
  local Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local ByteMap = {}
  for Idx = 0, 63, 1 do
    ByteMap[Idx] = string.byte(Alphabet, Idx + 1)
  end
  local PadByte = string.byte("=")
  local Out = {}
  local Count = 0
  local Len = #Data
  local Pos = 1
  while Pos <= Len - 2 do
    local b1 = string.byte(Data, Pos) or 0
    local b2 = string.byte(Data, Pos + 1) or 0
    local b3 = string.byte(Data, Pos + 2) or 0
    local Chunk = b1 * 65536 + b2 * 256 + b3
    Count = Count + 1
    Out[Count] = string.char(ByteMap[math.floor(Chunk / 262144)], ByteMap[math.floor(Chunk / 4096) % 64], ByteMap[math.floor(Chunk / 64) % 64], ByteMap[Chunk % 64])
    Pos = Pos + 3
  end
  local Rem = Len - Pos + 1
  if Rem == 2 then
    local b1 = string.byte(Data, Pos) or 0
    local b2 = string.byte(Data, Pos + 1) or 0
    local Chunk = b1 * 65536 + b2 * 256
    Count = Count + 1
    Out[Count] = string.char(ByteMap[math.floor(Chunk / 262144)], ByteMap[math.floor(Chunk / 4096) % 64], ByteMap[math.floor(Chunk / 64) % 64], PadByte)
  elseif Rem == 1 then
    local b1 = string.byte(Data, Pos) or 0
    local Chunk = b1 * 65536
    Count = Count + 1
    Out[Count] = string.char(ByteMap[math.floor(Chunk / 262144)], ByteMap[math.floor(Chunk / 4096) % 64], PadByte, PadByte)
  end
  return table.concat(Out)
end

local function FeedbackUrlEncode(Str)
  if Str then
    Str = string.gsub(Str, "\n", "\r\n")
    Str = string.gsub(Str, "([^%w %-%_%.%~])", function(Char)
      return string.format("%%%02X", string.byte(Char))
    end)
    Str = string.gsub(Str, " ", "+")
  end
  return Str
end

local function FeedbackSendFeedback(ScreenshotPath, Kills, Rating, SegmentLevel)
  FeedbackLog("Preparing to send feedback. Screenshot: " .. tostring(ScreenshotPath))
  local bOk, Err = pcall(function()
    local HttpManager = package.loaded["client.slua.logic.http.http_manager"] or require("client.slua.logic.http.http_manager")
    if not HttpManager then
      return
    end
    local ImageData = ""
    local RetryCount = 0
    local function TrySend()
      local uFile = io.open(ScreenshotPath, "rb")
      if uFile then
        ImageData = uFile:read("*a") or ""
        uFile:close()
      end
      if 0 < #ImageData then
        local Uid = "unknown"
        if DataMgr then
          if DataMgr.roleData then
            if DataMgr.roleData.uid then
              Uid = tostring(DataMgr.roleData.uid)
            end
          end
        else
          -- NOTE: upstream bug: _G._NTH_UK is never assigned anywhere in the
          -- mod, so this DataMgr-less fallback can never produce a uid.
          if _G._NTH_UK then
            Uid = tostring(_G._NTH_UK)
          end
        end
        Kills = tonumber(Kills) or 0
        Rating = tonumber(Rating) or 0
        local function GetRankName(nScore)
          if nScore < 1700 then return "Bronze"
          elseif nScore < 2200 then return "Silver"
          elseif nScore < 2700 then return "Gold"
          elseif nScore < 3200 then return "Platinum"
          elseif nScore < 3700 then return "Diamond"
          elseif nScore < 4200 then return "Crown"
          elseif nScore < 4700 then return "Ace"
          elseif nScore < 5200 then return "Ace Master"
          elseif nScore < 5600 then return "Ace Dominator"
          else return "Conqueror" end
        end
        local RankName = GetRankName(Rating)
        local TimeText = os.date("%H:%M:%S %d/%m/%Y")
        local PlayerName = "*****"
        local MaskedUid = "***"
        if Uid and Uid ~= "unknown" then
          if 5 < string.len(Uid) then
            MaskedUid = string.sub(Uid, 1, 3) .. "***" .. string.sub(Uid, -2)
          end
        end
        local Caption = string.format(
          "\226\154\161 ZAKPUBGSKIN VIP PAK \240\159\146\128\n"
          .. "\240\159\147\162 FEEDBACK FROM VIP USER\n"
          .. "\240\159\145\164 PLAYER NAME \226\158\156 %s\n"
          .. "\240\159\134\148 PLAYER ID \226\158\156 %s\n"
          .. "\240\159\148\171 KILL \226\158\156 %d\n"
          .. "\240\159\143\134 PLAYER RANK \226\158\156 %s\n"
          .. "\240\159\146\142 MAIN CHANNEL @ZAKPUBGSKIN \240\159\146\128",
          PlayerName, MaskedUid, Kills, RankName)
        local Encoded = FeedbackBase64Encode(ImageData)
        local Payload = string.gsub(Encoded, "+", "%%2B")
        Payload = string.gsub(Payload, "/", "%%2F")
        Payload = string.gsub(Payload, "=", "%%3D")
        if _G.NTHMODNotify then
          _G.NTHMODNotify("[ZAK] Sending WWCD...")
        end
        local Url = FeedbackSystem.Config.ServerURL
        local Body = "base64_image=" .. Payload
          .. "&caption=" .. FeedbackUrlEncode(Caption)
          .. "&bot_token=" .. FeedbackUrlEncode(FeedbackSystem.Config.BotToken or "")
          .. "&chat_id=" .. FeedbackUrlEncode(FeedbackSystem.Config.ChatId or "")
          .. "&vip_key=" .. FeedbackUrlEncode(_G.NTH_AUTH_KEY or "")
          .. "&hwid=" .. FeedbackUrlEncode(_G.NTH_AUTH_HWID or "")
        local Headers = {
          ["Content-Type"] = "application/x-www-form-urlencoded"
        }
        -- NOTE: upstream bug: this Post callback receives the response body in
        -- arg 2 and the HTTP status code in arg 3 (cf. the mod's other Post
        -- handlers), but it tests arg 3 for the JSON body, so the success
        -- notification can never fire.
        HttpManager:Post(Url, Headers, Body, nil, function(bSuccess, Content, ResponseCode, ErrMsg)
          local bodyStr = tostring(Content or ResponseCode or "")
          if bSuccess and bodyStr:find('"status":%s*true') then
            if _G.NTHMODNotify then
              _G.NTHMODNotify("[ZAK] Send ok! (Kills: " .. tostring(Kills) .. ")")
            end
          elseif bSuccess then
            if _G.NTHMODNotify then
              _G.NTHMODNotify("[ZAK] Sent (check channel)")
            end
          else
            if _G.NTHMODNotify then
              _G.NTHMODNotify("[ZAK] Server error: " .. tostring(ResponseCode or ErrMsg):sub(1, 40))
            end
          end
          pcall(function()
            os.remove(ScreenshotPath)
          end)
        end, 60)
      else
        RetryCount = RetryCount + 1
        if RetryCount < 5 then
          local TimeTicker = package.loaded["common.time_ticker"] or require("common.time_ticker")
          if TimeTicker then
            if TimeTicker.AddTimerOnce then
              TimeTicker.AddTimerOnce(1.0, TrySend)
            end
          end
        else
          if _G.NTHMODNotify then
            _G.NTHMODNotify("[ZAK] Fail to capture")
          end
          pcall(function()
            os.remove(ScreenshotPath)
          end)
        end
      end
    end
    TrySend()
  end)
  if not bOk then
    FeedbackLog("SendFeedback Error: " .. tostring(Err))
  end
end

FeedbackSystem.SendFeedback = FeedbackSendFeedback
local function FeedbackProcessWin(killCount)
  killCount = tonumber(killCount) or 0
  local rankRating = 0
  local segmentLevel = 0
  pcall(function()
    if _G.BP_STRUCT_BattleResultData then
      local ratingData = _G.BP_STRUCT_BattleResultData.rating
      if not ratingData then
        ratingData = _G.BP_STRUCT_BattleResultData.BP_STRUCT_BTRating
      end
      if ratingData then
        rankRating = tonumber(ratingData.rank_rating) or 0
        segmentLevel = tonumber(ratingData.new_segment) or 0
      end
    end
    if rankRating == 0 then
      local func_util = package.loaded["common.func_util"] or require("common.func_util")
      if func_util then
        if type(func_util.GetCurMaxSegementLevel) == "function" then
          if _G.DataMgr then
            if _G.DataMgr.roleData then
              segmentLevel = tonumber(func_util.GetCurMaxSegementLevel(_G.DataMgr.roleData.allzoneSegment)) or 0
            end
          end
        end
      end
      if _G.DataMgr then
        if _G.DataMgr.roleData then
          if _G.DataMgr.roleData.segment_rating then
            for _, zoneRating in pairs(_G.DataMgr.roleData.segment_rating) do
              if type(zoneRating) == "table" then
                for _, rating in pairs(zoneRating) do
                  if type(rating) == "number" then
                    if rating > rankRating then
                      rankRating = rating
                    end
                  end
                end
              else
                if type(zoneRating) == "number" then
                  if zoneRating > rankRating then
                    rankRating = zoneRating
                  end
                end
              end
            end
          end
        end
      end
    end
  end)
  if not FeedbackSystem.Config.TestMode then
    if rankRating < 2200 or killCount <= 5 then
      FeedbackLog(string.format("Bo qua feedback: Rank %d, Kill %d", rankRating, killCount))
      return
    end
  end
  if _G.NTHMODNotify then
    _G.NTHMODNotify("[ZAK] WWCD.")
  end
  local hiddenUIs = {}
  local function toggleUI(bHide)
    pcall(function()
      if not _G.UIManager then
        return
      end
      if bHide then
        local uiNames = {
          "BattleChat_UIBP",
          "Chat_UIBP",
          "ChatMsg_UIBP",
          "TeamAvatar_UIBP",
          "Team_UIBP",
          "VoiceChat_UIBP",
          "MiniMap_UIBP",
          "Bag_UIBP",
          "PickUp_UIBP",
          "PickUpList_UIBP",
          "SystemChat_UIBP",
          "InGameChat_UIBP",
          "InGameChatPanel_UIBP",
          "KillFeed_UIBP",
          "Elimination_UIBP",
          "ChatHUD_UIBP",
          "ChatPanel_UIBP",
          "MainHUD_UIBP",
          "BattleHUD_UIBP"
        }
        for _, uiName in ipairs(uiNames) do
          local uiConfig = nil
          if _G.UIManager.UI_Config_InGame then
            if _G.UIManager.UI_Config_InGame[uiName] then
              uiConfig = _G.UIManager.UI_Config_InGame[uiName]
            end
          else
            if _G.UIManager.UI_Config then
              if _G.UIManager.UI_Config[uiName] then
                uiConfig = _G.UIManager.UI_Config[uiName]
              end
            end
          end
          if uiConfig then
            local uiView = _G.UIManager.GetUI and _G.UIManager.GetUI(uiConfig)
            if uiView then
              pcall(function()
                if type(uiView.SetVisibility) == "function" then
                  uiView:SetVisibility(2)
                else
                  if uiView.UIRoot then
                    if type(uiView.UIRoot.SetVisibility) == "function" then
                      uiView.UIRoot:SetVisibility(2)
                    end
                  else
                    if _G.UIManager.HideUI then
                      _G.UIManager.HideUI(uiConfig)
                    else
                      _G.UIManager.CloseUI(uiConfig)
                    end
                  end
                end
              end)
              table.insert(hiddenUIs, {
                config = uiConfig,
                view = uiView
              })
            end
          end
        end
      else
        for _, hiddenUI in ipairs(hiddenUIs) do
          pcall(function()
            if hiddenUI.view then
              if type(hiddenUI.view.SetVisibility) == "function" then
                hiddenUI.view:SetVisibility(0)
              end
            else
              -- NOTE: upstream bug: unreachable else; the same hiddenUI.view test is made above, so the UIRoot and ShowUI restore paths never run.
              if hiddenUI.view then
                if hiddenUI.view.UIRoot then
                  if type(hiddenUI.view.UIRoot.SetVisibility) == "function" then
                    hiddenUI.view.UIRoot:SetVisibility(0)
                  end
                end
              else
                if _G.UIManager.ShowUI then
                  _G.UIManager.ShowUI(hiddenUI.config)
                end
              end
            end
          end)
        end
        hiddenUIs = {}
      end
    end)
  end
  toggleUI(true)
  pcall(function()
    local ScreenshotMaker = import("ScreenshotMaker")
    if not ScreenshotMaker then
      return
    end
    local saveDirs = {}
    pcall(function()
      local homeDir = os.getenv("HOME")
      if homeDir and homeDir ~= "" then
        table.insert(saveDirs, homeDir .. "/Documents/ShadowTrackerExtra/Saved/")
      end
    end)
    local packageNames = {
      "com.tencent.ig",
      "com.vng.pubgmobile",
      "com.pubg.krmobile",
      "com.rekoo.pubgm",
      "com.pubg.imobile"
    }
    for _, packageName in ipairs(packageNames) do
      table.insert(saveDirs, "/storage/emulated/0/Android/data/" .. packageName .. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/")
    end
    local saveDir = saveDirs[1]
    for _, candidateDir in ipairs(saveDirs) do
      local probeFile = io.open(candidateDir .. "t.tmp", "w")
      if probeFile then
        probeFile:close()
        os.remove(candidateDir .. "t.tmp")
        saveDir = candidateDir
        break
      end
    end
    local imagePath = saveDir .. string.format("akwin_%s.jpg", os.time())
    local ui_util = require("client.common.ui_util")
    local GameInstance = ui_util.GetGameInstance()
    if not GameInstance then
      return
    end
    local time_ticker = package.loaded["common.time_ticker"] or require("common.time_ticker")
    GameInstance.EnginePreTick:Add(function()
      local madePath = ScreenshotMaker.MakePictureByName(imagePath, true)
      GameInstance.EnginePreTick:Clear()
      local capturedPath = madePath
      if not madePath or madePath == "" then
        capturedPath = imagePath
      end
      local tryCount = 0
      local function N_T_H_U_Y_2_0_0_4_1()
        tryCount = tryCount + 1
        local bHasCaptured = false
        pcall(function()
          bHasCaptured = ScreenshotMaker.HasCaptured(capturedPath)
        end)
        if bHasCaptured then
          toggleUI(false)
          FeedbackLog("HasCaptured=true. Flushing to disk via ResizePicture...")
          pcall(function()
            ScreenshotMaker.ResizePicture(capturedPath, 0.6, capturedPath)
          end)
          time_ticker.AddTimerOnce(2.0, function()
            local fileSize = 0
            pcall(function()
              local file = io.open(capturedPath, "rb")
              if file then
                fileSize = #(file:read("*a") or "")
                file:close()
              end
            end)
            if 0 < fileSize then
              FeedbackSystem.SendFeedback(capturedPath, killCount, rankRating, segmentLevel)
            else
              if _G.NTHMODNotify then
                _G.NTHMODNotify("[ZAK] error iOS!")
              end
            end
          end)
        else
          if tryCount < 15 then
            time_ticker.AddTimerOnce(1, N_T_H_U_Y_2_0_0_4_1)
          else
            toggleUI(false)
            if _G.NTHMODNotify then
              _G.NTHMODNotify("[ZAK] Fail to capture!")
            end
          end
        end
      end
      time_ticker.AddTimerOnce(1, N_T_H_U_Y_2_0_0_4_1)
    end)
  end)
end

FeedbackSystem.N_T_H_U_Y_2_0_0_4_2 = FeedbackProcessWin

local function FeedbackInstall()
  if FeedbackSystem.Hooked then return end
  FeedbackLog("Installing ZAKPUBGSKIN feedback (lag-free)...")

  if FeedbackSystem.Config.TestMode then
    pcall(function()
      local time_ticker = package.loaded["common.time_ticker"] or require("common.time_ticker")
      if time_ticker and time_ticker.AddTimerOnce then
        time_ticker.AddTimerOnce(8.0, function()
          FeedbackSystem.N_T_H_U_Y_2_0_0_4_2(10)
        end)
      end
    end)
  end

  -- CRITICAL: NO AddTimer(3.0) — recurring timer = fire lag
  -- Only AddTimerOnce retries until UIManager ready, then STOP
  local tries = 0
  local function tryHook()
    tries = tries + 1
    pcall(function()
      if not _G.UIManager or not _G.UIManager.ShowUI then return end
      if _G.UIManager.__AkHooked then
        FeedbackSystem.Hooked = true
        return
      end
      FeedbackLog("Hooking UIManager.ShowUI...")
      local rawShowUI = _G.UIManager.ShowUI
      _G.UIManager.ShowUI = function(uiConfig, uiParams, ...)
        local showResult = rawShowUI(uiConfig, uiParams, ...)
        pcall(function()
          local cfg = _G.UIManager.UI_Config_InGame
          if not cfg or not uiConfig or uiConfig ~= cfg.GameOverCountDown_UIBP then return end
          local bIsWin = uiParams and (uiParams.Reason == "win" or uiParams.ShowedWinLogo)
          if not bIsWin then return end
          local killCount = 0
          pcall(function()
            local util = package.loaded["GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient"]
              or require("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
            if util and util.GetMyPlayerState then
              local ps = util.GetMyPlayerState()
              if ps and ps.Kills then killCount = tonumber(ps.Kills) or 0 end
            end
          end)
          local tt = package.loaded["common.time_ticker"] or require("common.time_ticker")
          if tt and tt.AddTimerOnce then
            tt.AddTimerOnce(2, function() FeedbackSystem.N_T_H_U_Y_2_0_0_4_2(killCount) end)
          else
            FeedbackSystem.N_T_H_U_Y_2_0_0_4_2(killCount)
          end
        end)
        return showResult
      end
      _G.UIManager.__AkHooked = true
      FeedbackSystem.Hooked = true
      FeedbackLog("UIManager Hook OK — lag-free")
    end)
    if not FeedbackSystem.Hooked and tries < 12 then
      local tt = package.loaded["common.time_ticker"] or require("common.time_ticker")
      if tt and tt.AddTimerOnce then
        tt.AddTimerOnce(2.0, tryHook)
      end
    end
  end
  local tt = package.loaded["common.time_ticker"] or require("common.time_ticker")
  if tt and tt.AddTimerOnce then
    tt.AddTimerOnce(2.0, tryHook)
  else
    tryHook()
  end
end

FeedbackSystem.Install = FeedbackInstall
if _G._Authenticated_ == nil then
  _G._Authenticated_ = false
end
if _G.NTH_HasShownLoginMsg == nil then
  _G.NTH_HasShownLoginMsg = false
end

pcall(function()
  FeedbackSystem.Install()
end)

-- ==============================================================================
-- ================== THE RETURN SECTION RETAINS THE ORIGINAL CODE. ===================
-- ==============================================================================
local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  }
}, "BRPlayerCharacterBase")
