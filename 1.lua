local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}

BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}

BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = { UEnums.EPropertyClass.Object }
}

BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = { UEnums.EPropertyClass.Int }
}

BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = { UEnums.EPropertyClass.Int }
}

BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = { UEnums.EPropertyClass.Bool }
}

local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
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
      AttrName = { "bCanSelfRescue" }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    GameplayData.AddCharacter(self.Object)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then return end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
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
  if self.HandleOnLanded then self:HandleOnLanded(-1) end
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
  if Client then GameplayData.RemoveCharacter(self.Object) end
  pcall(function()
    if _G.AddOutfitTryFlushSave then _G.AddOutfitTryFlushSave() end
  end)
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:BPOnRespawned()
  if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
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
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then return end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then return end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then return end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then return end
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
  if not slua.isValid(Base) or not Base.GetOwner then return end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then return end
  if not Lifter.AddCharacter then return end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then return false end
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
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then return end
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then return end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then return end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  function loadLater() uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0) end
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt) end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID) self:SetAttrValue("AreaID", AreaID, -1) end
function BRPlayerCharacterBase:GetAreaID() return math.floor(self:GetAttrValue("AreaID") + 0.5) end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
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
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ==========================================================
-- ========== CONFIG & STATE ================================
-- ==========================================================

_G.LexusConfig = _G.LexusConfig or {
    FakeHWID = false,
    FakePlayerData = false,
    ModEmote = false,
    ModSkin = false,
    SkinDeadBox = false,
    SkinAttachment = false,
    KillMessage = false,
    KillCountUI = false,
    WallhackNew = false,
    BypassEnable = true,

    -- ==========================================================
    -- ==== ULTRA-SAFE AIMBOT (ANTI-BAN / LEGIT MODE) ===========
    -- ==========================================================
    AimTouchEnable   = false,  -- Toggle ON manually in menu
    AimbotMode       = 4,      -- 4 = Fire Only (safest)
    AimTouchBone     = 3,      -- 3 = Spine (subtle, not head)
    AimTouchSpeed    = 12,     -- Slow glide (8-15 = invisible)
    AimTouchFOV      = 2,      -- Tiny circle (must be aiming near)
    AimTouchMaxDist  = 60,     -- Short range only (60m)
    AimTouchIgKnock  = true,
    AimTouchIgBot    = true,
    AimTouchVisCheck = true,
}
-- ==========================================================
-- ========== LOCKED AIMBOT CONFIG (DO NOT EDIT) ============
-- ==========================================================
_G.LexusConfig.AimbotMode       = 1     -- Always On (visible)
_G.LexusConfig.AimTouchBone     = 2     -- Chest
_G.LexusConfig.AimTouchSpeed    = 25    -- Noticeable pull
_G.LexusConfig.AimTouchFOV      = 14    -- Medium circle
_G.LexusConfig.AimTouchMaxDist  = 100   -- 100m
_G.LexusConfig.AimTouchIgKnock  = true
_G.LexusConfig.AimTouchIgBot    = true
_G.LexusConfig.AimTouchVisCheck = true

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(5.0, function()
            local c = _G.LexusConfig
            if c then
                c.AimbotMode       = 1
                c.AimTouchBone     = 2
                c.AimTouchSpeed    = 25
                c.AimTouchFOV      = 2
                c.AimTouchMaxDist  = 100
                c.AimTouchIgKnock  = true
                c.AimTouchIgBot    = true
                c.AimTouchVisCheck = true
            end
        end, -1, 5.0)
    end
end)

_G.LexusState = _G.LexusState or {}
-- ===== SH-UI BRIDGE =====
_G.XthrlenConfig  = _G.LexusConfig
_G.XthrlenState   = _G.LexusState
_G.SHConfig       = _G.LexusConfig
_G.SHgamingConfig = _G.LexusConfig
_G.SHgamingState  = _G.LexusState
-- ==========================

-- ==========================================================
-- ========== EXPIRY DATE CHECK (ANTI-TAMPER) ===============
-- ==========================================================
local limitTime = os.time({ year = 2026, month = 11, day = 30, hour = 23, min = 59, sec = 0 })
local currentTime = os.time(os.date("!*t"))
local isExpired = false

pcall(function()
    local fileName = ".sys_time_cache"
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "../../ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName
    }

    if os and os.getenv then
        local homeDir = os.getenv("HOME")
        if homeDir and homeDir ~= "" then
            table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName)
            table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName)
        end
    end

    -- Anti device-clock-change: prefer server time
    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then
        local s, r = pcall(require, "client.logic.common.TimeManager")
        if s and r then tm = r end
    end
    if tm and type(tm.GetServerTime) == "function" then
        local serverTime = tm.GetServerTime()
        if serverTime and serverTime > 1700000000 then
            currentTime = serverTime
        end
    end

    -- Read all hidden save files (largest timestamp wins)
    local lastSeenTime = 0
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local savedTime = tonumber(data) or 0
            if savedTime > lastSeenTime then
                lastSeenTime = savedTime
            end
            file:close()
        end
    end

    if currentTime < lastSeenTime then
        currentTime = lastSeenTime
    else
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(tostring(currentTime))
                file:close()
            end
        end
    end
end)

isExpired = (currentTime > limitTime)
_G.LexusExpired = isExpired
if isExpired then
    -- Show renewal popup once
    pcall(function()
        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(2.0, function()
                local Msg = require("client.slua.logic.common.logic_common_msg_box")
                if Msg and Msg.Show then
                    Msg.Show(1, "MOD EXPIRED",
                        "YOUR MOD HAS EXPIRED.\nContact @OFFICAL_KASHMIRY1VIPMOD to renew.",
                        function()
                            local Web = require("client.slua.logic.url.logic_webview_sdk")
                            if Web and Web.OpenURL then
                                Web:OpenURL("https://t.me/O52NhuIADWM3MTc0")
                            end
                        end,
                        function() end, "CONTACT ADMIN", "CLOSE")
                end
            end)
        end
    end)

    -- Return bare class — game needs it, but no mod loads
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
        { BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
        { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
        { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" },
        { SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature" },
        { GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature" }
    }, "BRPlayerCharacterBase")
end
-- ==========================================================
-- ========== WALLHACK NEW (DrawDyeing + IdeaOutline) =======
-- ==========================================================
pcall(function()
    local _LC = nil
    local function GetLC()
        if not _LC then
            local ok, lc = pcall(import, "LinearColor")
            if ok then _LC = lc end
        end
        return _LC
    end

    local CONSOLE_READY = false
    local PROCESSED_PAWNS = {}
    local TICK_COUNT = 0
    local WH_TIMER = nil
    local retryCount = 0
    local TICK_INTERVAL = 0.3
    local MAX_PAWNS_PER_TICK = 20
    local RESET_PROCESSED_EVERY = 6
    local AVATAR_SLOTS = {0,1,2,3,4,5,6,7}

    local colors = nil
    local function EnsureColors()
        if colors then return colors end
        local LC = GetLC()
        if not LC then return nil end
        colors = {
            vis  = LC(0, 255, 0, 255),
            occ  = LC(255, 0, 0, 255),
            bVis = LC(0, 180, 0, 200),
            bOcc = LC(180, 0, 0, 200)
        }
        return colors
    end

    local function SetupConsole()
        if CONSOLE_READY then return end
        pcall(function()
            local KSL = import("KismetSystemLibrary")
            local world = slua.getWorld()
            if not KSL or not world then return end
            KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
            KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
            KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
            KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
            CONSOLE_READY = true
        end)
    end

    local function ApplyToMesh(mesh, visColor, occColor)
        if not mesh or not slua.isValid(mesh) then return end
        pcall(function()
            mesh:SetDrawDyeing(true)
            mesh:SetDrawDyeingMode(1)
            mesh:SetVisibleDyeingColor(visColor)
            mesh:SetOccludedDyeingColor(occColor)
            mesh:SetDyeingColorFadeDistance(99999.0)
            mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
            mesh:SetDrawHighlight(true)
            mesh:OverrideHighlightColor(visColor)
            mesh:SetHighlightCanBeOccluded(false)
            mesh:SetDrawIdeaOutline(true)
            mesh:SetIdeaOutlineNew(true)
            mesh:SetIdeaOutlineOcclusionHighlight(true)
            mesh:OverrideIdeaOutlineColor(visColor)
            mesh:SetIdeaOutlineOcclusionColor(occColor)
            mesh:OverrideIdeaOutlineThickness(20.0)
            mesh:SetIdeaOverrideOutlineAndOcclusion(true)
            mesh:SetRenderCustomDepth(true)
            mesh:SetCustomDepthStencilValue(255)
        end)
    end

    local function IsPawnAlive(pawn)
        if not slua.isValid(pawn) then return false end
        if pawn.Health and pawn.Health > 0 then return true end
        return false
    end

    local function PBCtick()
        pcall(function()
            local localPawn = GameplayData.GetPlayerCharacter()
            if not slua.isValid(localPawn) then return end
            SetupConsole()
            local cols = EnsureColors()
            if not cols then return end
            TICK_COUNT = TICK_COUNT + 1
            if TICK_COUNT % RESET_PROCESSED_EVERY == 0 then PROCESSED_PAWNS = {} end
            local myTeamId = localPawn.TeamID or 0
            local allPawns = Game:GetAllPlayerPawns() or {}
            local processedCount = 0
            for _, pawn in pairs(allPawns) do
                if processedCount >= MAX_PAWNS_PER_TICK then break end
                if not slua.isValid(pawn) or pawn == localPawn then goto continue end
                if pawn.PlayerKey and PROCESSED_PAWNS[pawn.PlayerKey] then goto continue end
                if IsPawnAlive(pawn) and pawn.TeamID and pawn.TeamID ~= myTeamId then
                    local isAI = false
                    pcall(function()
                        if type(Game.IsAI) == "function" then isAI = Game:IsAI(pawn) end
                    end)
                    local vis = isAI and cols.bVis or cols.vis
                    local occ = isAI and cols.bOcc or cols.occ
                    pcall(function()
                        if slua.isValid(pawn.Mesh) then ApplyToMesh(pawn.Mesh, vis, occ) end
                        local avatarComp = pawn.CharacterAvatarComp2_BP
                        if not avatarComp and type(pawn.getAvatarComponent2) == "function" then
                            avatarComp = pawn:getAvatarComponent2()
                        end
                        if avatarComp and avatarComp.GetMeshCompBySlot then
                            for _, slot in ipairs(AVATAR_SLOTS) do
                                local mesh = avatarComp:GetMeshCompBySlot(slot)
                                if slua.isValid(mesh) then ApplyToMesh(mesh, vis, occ) end
                            end
                        end
                        pcall(function()
                            local SMC = import("SkeletalMeshComponent")
                            if SMC then
                                local skComps = pawn:GetComponentsByClass(SMC)
                                if skComps then
                                    for i = 0, skComps:Num() - 1 do
                                        local comp = skComps:Get(i)
                                        if slua.isValid(comp) and comp ~= pawn.Mesh then ApplyToMesh(comp, vis, occ) end
                                    end
                                end
                            end
                        end)
                        pcall(function()
                            local STC = import("StaticMeshComponent")
                            if STC then
                                local stComps = pawn:GetComponentsByClass(STC)
                                if stComps then
                                    for i = 0, stComps:Num() - 1 do
                                        local comp = stComps:Get(i)
                                        if slua.isValid(comp) then ApplyToMesh(comp, vis, occ) end
                                    end
                                end
                            end
                        end)
                        local weapon = pawn:GetCurrentWeapon()
                        if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then ApplyToMesh(weapon.Mesh, vis, occ) end
                    end)
                    if pawn.PlayerKey then PROCESSED_PAWNS[pawn.PlayerKey] = true end
                    processedCount = processedCount + 1
                end
                ::continue::
            end
        end)
    end

    local function StartPBC()
        SetupConsole()
        if not EnsureColors() then return false end
        if WH_TIMER then
            pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH_TIMER) end end)
            WH_TIMER = nil
        end
        if _G.Game and _G.Game.AddGameTimer then
            WH_TIMER = _G.Game:AddGameTimer(TICK_INTERVAL, true, PBCtick)
            return true
        end
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) and pc.AddGameTimer then
            WH_TIMER = pc:AddGameTimer(TICK_INTERVAL, true, PBCtick)
            return true
        end
        return false
    end

    local function RetryStart()
        if retryCount >= 30 then retryCount = 0 return end
        retryCount = retryCount + 1
        if not StartPBC() then
            if _G.Game and _G.Game.AddGameTimer then
                _G.Game:AddGameTimer(1.0, false, RetryStart)
            end
        else
            retryCount = 0
        end
    end

    _G.StartNewWallhack = function()
        if WH_TIMER then return end
        retryCount = 0
        RetryStart()
    end

    _G.StopNewWallhack = function()
        if WH_TIMER then
            pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH_TIMER) end end)
            WH_TIMER = nil
        end
        PROCESSED_PAWNS = {}
        CONSOLE_READY = false
    end
end)
-- ==========================================================
-- ========== AIMBOT ENGINE (ROBUST) ========================
-- ==========================================================
-- ==========================================================
-- ========== AIMBOT ENGINE (ROBUST) ========================
-- ==========================================================
pcall(function()
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

        -- Safe team read
        local myTeam = 0
        pcall(function()
            if type(player.GetTeamID) == "function" then
                myTeam = tonumber(player:GetTeamID()) or 0
            elseif player.TeamID ~= nil then
                myTeam = tonumber(player.TeamID) or 0
            end
        end)

        -- Safe my-location for distance
        local myLoc = nil
        pcall(function() myLoc = player:K2_GetActorLocation() end)

        for _, actor in pairs(allCharacters) do
            if slua.isValid(actor) and actor ~= player then

                -- TEAM CHECK (safe — no method call that can crash)
                local tTeam = 0
                pcall(function()
                    if type(actor.GetTeamID) == "function" then
                        tTeam = tonumber(actor:GetTeamID()) or 0
                    elseif actor.TeamID ~= nil then
                        tTeam = tonumber(actor.TeamID) or 0
                    end
                end)

                if tTeam ~= myTeam then

                    -- ALIVE CHECK (safe across all PUBG API variants)
                    local alive = true
                    pcall(function()
                        if actor.Health ~= nil then
                            alive = tonumber(actor.Health) > 0
                        elseif type(actor.IsAlive) == "function" then
                            alive = actor:IsAlive()
                        elseif actor.bIsDead ~= nil then
                            alive = not actor.bIsDead
                        elseif actor.HealthStatus ~= nil then
                            alive = (tonumber(actor.HealthStatus) ~= 2)
                        end
                    end)

                    if alive then
                        -- DISTANCE CHECK (safe — no GetDistanceTo call)
                        local ok = true
                        if myLoc and radius and radius > 0 then
                            local aLoc = nil
                            pcall(function() aLoc = actor:K2_GetActorLocation() end)
                            if aLoc then
                                local dx = (aLoc.X or 0) - (myLoc.X or 0)
                                local dy = (aLoc.Y or 0) - (myLoc.Y or 0)
                                local dz = (aLoc.Z or 0) - (myLoc.Z or 0)
                                if math.sqrt(dx*dx + dy*dy + dz*dz) > radius then ok = false end
                            end
                        end
                        if ok then table.insert(result, actor) end
                    end
                end
            end
        end
        return result
    end
end)

_G.AimTouch = function()
    pcall(function()
        if not _G.LexusConfig.AimTouchEnable then return end
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then return end
        local mode = _G.LexusConfig.AimbotMode or 1
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        local isADS = player.bIsGunADS or false
        local isFiring = player.bIsWeaponFiring or false
        local hasWeapon = slua.isValid(weapon)
        if mode == 4 and not isFiring then return end
        if mode == 3 and not hasWeapon then return end
        if mode == 2 and not isADS then return end

        local isShotgun = false
        local isSniper = false
        local currentAmmo = 1
        if hasWeapon then
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

        if _G.LexusState.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.LexusState.IsAutoFiring = false
        end

        if isShotgun and currentAmmo <= 0 then return end

        local cond = 2
local prioMode = 1

-- ===== READ FROM CONFIG (so menu/config actually controls it) =====
local boneIdx       = tonumber(_G.LexusConfig.AimTouchBone)    or 2
local speedVal      = tonumber(_G.LexusConfig.AimTouchSpeed)   or 22
local fovVal        = tonumber(_G.LexusConfig.AimTouchFOV)     or 16
local maxDistMeters = tonumber(_G.LexusConfig.AimTouchMaxDist) or 120
local useVisCheck = false
local igKnock = false
local igBot = false
useVisCheck = _G.LexusConfig.AimTouchVisCheck
igKnock = _G.LexusConfig.AimTouchIgKnock
igBot = _G.LexusConfig.AimTouchIgBot

-- Per-weapon tweaks — only override bone+distance, keep speed/FOV from config
if isShotgun then
    cond = 2; prioMode = 1; boneIdx = 2; maxDistMeters = 30
elseif isADS then
    if isSniper then
        cond = 2; prioMode = 1; boneIdx = 1; maxDistMeters = 400
    else
        cond = 1; prioMode = 1; boneIdx = 2; maxDistMeters = 300
    end
else
    cond = 1; prioMode = 1; boneIdx = 1; maxDistMeters = 250
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
            if not slua.isValid(target) then goto continue end
            if igKnock and target.HealthStatus == 1 then goto continue end
            if igBot then
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.BotStatusCache = _G.BotStatusCache or {}
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
                            if pState.bIsABot or pState.bIsBot or pState.IsBot or pState.bIsAI or pState.bIsRobot or pState.bIsAiPlayer then cachedBot = true end
                            if not cachedBot and pState.PlayerAIType ~= nil and pState.PlayerAIType ~= 0 then cachedBot = true end
                        end
                    end
                    _G.BotStatusCache[tId] = cachedBot
                end
                if cachedBot then goto continue end
            end
            if useVisCheck then
                local curTime = os.clock()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then goto continue end
            end
            local tPos = target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 70
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then goto continue end
            local screen = FVector2D()
            local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if not success or screen.X <= 0 or screen.Y <= 0 then goto continue end
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            if distScreen > FOV_RADIUS then goto continue end
            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
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
            ::continue::
        end

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
        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")
    end)
end
    -- ← THIS LINE IS MISSING — closes the outer pcall(function()
-- ==========================================================
-- ========== BYPASS SYSTEM — CORE =========================
-- ==========================================================
local function _BP_nop() return true end
local function _BP_retFalse() return false end
local function _BP_retZero() return 0 end
local function _BP_retEmpty() return {} end
local function _BP_retNil() return nil end
local function _BP_retTrue() return true end
local function _BP_retEmptyString() return "" end

-- [1/28] SLUA signature bypass
local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = _BP_retTrue
            loader.checkIntegrity = _BP_retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = _BP_retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then
            slua_serialize.check = _BP_retTrue
            slua_serialize.verify = _BP_retTrue
        end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = _BP_retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = _BP_retTrue end
    end)
end

-- [2/28] MD5 / pak signature bypass
local function InitializeMD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = _BP_retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = _BP_retTrue
            FileHashChecker.VerifyAll = _BP_retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            TssSdk.GetFileMD5 = function() return "BYPASS" end
            TssSdk.VerifyFileSignature = _BP_retTrue
        end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then
            STExtra.CheckMD5 = _BP_retTrue
            STExtra.GetMD5 = function() return "BYPASS" end
            STExtra.VerifyFile = _BP_retTrue
        end
    end)
end

-- [3/28] Skin integrity bypass
local function InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then
            ptlog.ReportEvent = _BP_nop
            ptlog.ReportDownloadResult = _BP_nop
            ptlog.ReportODPTDError = _BP_nop
            ptlog.ReportSkinError = _BP_nop
        end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = _BP_retFalse
            AvatarUtils.IsValidAvatar = _BP_retTrue
            AvatarUtils.CheckAvatarIntegrity = _BP_retTrue
            AvatarUtils.ReportInvalidAvatar = _BP_nop
        end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then
            sub.StartCheck = _BP_nop
            sub.ReportAbnormalFile = _BP_nop
            sub.StopCheck = _BP_nop
        end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = _BP_nop eqEx.SendException = _BP_nop end
    end)
end

-- [4/28] Log blocker
local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then
            SMTD.MTDePicture = function() return "" end
            SMTD.ReMTDePicture = function() return "" end
            SMTD.HasCaptured = _BP_retTrue
            SMTD.TakeScreenshot = _BP_nop
        end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then
            TLog.Info = _BP_nop TLog.Warning = _BP_nop TLog.Error = _BP_nop TLog.Debug = _BP_nop
            TLog.Report = _BP_nop TLog.Send = _BP_nop TLog.Flush = _BP_nop
        end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then
            CrashSight.ReportException = _BP_nop
            CrashSight.SetCustomData = _BP_nop
            CrashSight.Log = _BP_nop
            CrashSight.SendCrash = _BP_nop
            CrashSight.ReportUserException = _BP_nop
        end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GRUtils then
            GRUtils.BugglyPostExceptionFull = _BP_retFalse
            GRUtils.CheckCanBugglyPostException = _BP_retFalse
            GRUtils.ReplayReportData = _BP_nop
            GRUtils.ReportGameException = _BP_nop
            GRUtils.PostException = _BP_nop
        end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then
            CTR.SendReport = _BP_nop
            CTR.SendException = _BP_nop
            CTR.UploadLog = _BP_nop
        end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "FacebookAnalytics", "GameAnalytics"}) do
            local s = _G[sdk]
            if s then
                s.logEvent = _BP_nop
                s.trackEvent = _BP_nop
                s.setEnabled = _BP_retFalse
                s.sendEvent = _BP_nop
                s.report = _BP_nop
            end
        end
    end)
end

-- [5/28] Scanner blocker
local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "AvatarExceptionSubsystem",
                "ShootVerifySubSystemClient", "MemoryCheckSubsystem", "SpeedCheckSubsystem",
                "WallCheckSubsystem", "FileCheckSubsystem", "BehaviorScoreSubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload")
                            or k:find("Verify") or k:find("Check") or k:find("Validate")
                            or k:find("Scan") or k:find("Detect")) then
                            pcall(function() sub[k] = _BP_nop end)
                        end
                    end
                    if sub.ReportPingDelayTimer then
                        sub:RemoveGameTimer(sub.ReportPingDelayTimer)
                        sub.ReportPingDelayTimer = nil
                    end
                    sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then
            AvaEx.CheckAvatarException = _BP_nop
            AvaEx.CheckAvatarExceptionOnce = _BP_nop
            AvaEx.ReportAvatarException = _BP_nop
            AvaEx.CheckSlotMeshVisible = _BP_retFalse
            AvaEx.CheckPawnVisible = _BP_retFalse
            AvaEx.CheckCanBugglyPostException = _BP_retFalse
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local origData = TssSdk.OnRecvData
            TssSdk.OnRecvData = function(data)
                if type(data) == "string" and (data:find("report", 1, true) or data:find("exception", 1, true)
                    or data:find("cheat", 1, true) or data:find("violation", 1, true)
                    or data:find("hack", 1, true) or data:find("verify", 1, true)) then return end
                if origData then origData(data) end
            end
            TssSdk.SendReportInfo = _BP_nop
            TssSdk.ScanMemory = _BP_retTrue
            TssSdk.IsEmulator = _BP_retFalse
            TssSdk.GetTssSdkReportInfo = _BP_retEmptyString
            TssSdk.CheckEnvironment = _BP_retTrue
            TssSdk.VerifyProcess = _BP_retTrue
        end
    end)
end

-- [6/28] Replay/telemetry blocker
local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({"GameReportSubsystem", "ReplaySubsystem"}) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Trace")
                            or k:find("Replay") or k:find("Record") or k:find("Save")) then
                            pcall(function() sub[k] = _BP_nop end)
                        end
                    end
                end
            end
        end
        local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logRep then
            logRep.ReportReplay = _BP_nop
            logRep.SendReportReq = _BP_nop
            logRep.UploadReplay = _BP_nop
        end
    end)
end
-- [7/28] Report flow blocker
local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow",
            "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior",
            "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick",
            "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow",
            "ReportSecTgameMovingFlow", "ReportParachuteData", "ReportEquipmentFlow",
            "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord",
            "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate",
            "ReportCircleFlow", "ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do
            if _G[f] then _G[f] = _BP_nop end
            if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = _BP_nop end
        end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}) do
            if _G[f] then _G[f] = _BP_retFalse end
            if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = _BP_retFalse end
        end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow", "IsEnableReportMrpcsInPartCircleFlow",
            "IsEnableReportMrpcsFlow", "IsEnableReportAttackFlow", "IsEnableReportHitFlow",
            "IsEnableReportCircleFlow"}) do
            if _G[f] then _G[f] = _BP_retFalse end
        end
    end)
end

-- [8/28] Player security bypass
local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector",
            "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then
                for k, v in pairs(_G[c]) do
                    if type(v) == "function" and (k:find("Report") or k:find("Collect")
                        or k:find("Send") or k:find("Upload") or k:find("Record")) then
                        _G[c][k] = _BP_nop
                    end
                end
            end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then
            SecSub.ReportData = _BP_nop
            SecSub.CheckCheat = _BP_retFalse
            SecSub.ValidatePlayer = _BP_retTrue
            SecSub.CollectData = _BP_nop
            SecSub.SendToServer = _BP_nop
        end
    end)
end

-- [9/28] Client flow bypass
local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData",
            "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then
                for k, v in pairs(sub) do
                    if type(v) == "function" and (k:find("Report") or k:find("Send")
                        or k:find("Flow") or k:find("Record") or k:find("Process")) then
                        pcall(function() sub[k] = _BP_nop end)
                    end
                end
            end
        end
    end)
end

-- [10/28] SwiftHawk bypass
local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}) do
            if _G[f] then _G[f] = _BP_nop end
            if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = _BP_nop end
        end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then
            sub.ReportData = _BP_nop
            sub.SendReport = _BP_nop
            sub.CollectTelemetry = _BP_nop
        end
    end)
end

-- [11/28] CoronaLab bypass
local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then
            _G.CoronaLab.ReportData = _BP_nop
            _G.CoronaLab.SendData = _BP_nop
            _G.CoronaLab.CollectData = _BP_nop
            _G.CoronaLab.Telemetry = _BP_nop
        end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then
            sub.ReportData = _BP_nop
            sub.SendToServer = _BP_nop
            sub.CollectTelemetry = _BP_nop
            sub.StopCollection = _BP_nop
        end
    end)
end

-- [12/28] Modifier exception bypass
local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then
            sub.ReportException = _BP_nop
            sub.CheckModifier = _BP_retTrue
            sub.ValidateModifier = _BP_retTrue
            sub.ReportModifierError = _BP_nop
        end
    end)
end

-- [13/28] Simulate character location bypass
local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then
            sub.ReportLocation = _BP_nop
            sub.SendLocationData = _BP_nop
            sub.VerifyLocation = _BP_retTrue
        end
    end)
end

-- [14/28] Shoot verification bypass
local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then
            sub.OnShootVerifyFailed = _BP_nop
            sub.SendVerifyData = _BP_nop
            sub.ReportBulletHit = _BP_nop
            sub.UploadHitInfo = _BP_nop
            sub.VerifyShot = _BP_retTrue
        end
        if _G.BulletHitInfoUploadData then
            _G.BulletHitInfoUploadData.Report = _BP_nop
            _G.BulletHitInfoUploadData.Send = _BP_nop
            _G.BulletHitInfoUploadData.Upload = _BP_nop
        end
    end)
end

-- [15/28] Network packet blocker
local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1,
                ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1, ["ReportPlayerBehavior"]=1,
                ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1,
                ["ReportSecVehicleMoveFlow"]=1, ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1,
                ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_net_saturate"]=1, ["report_speed_hack"]=1,
                ["report_wall_hack"]=1, ["report_aim_bot"]=1, ["report_esp_usage"]=1,
                ["report_modded_files"]=1, ["detect_cheat"]=1, ["ban_player"]=1, ["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CheckReportSecAttackFlow"]=1,
                ["CheckReportSecAttackFlowWithAttackFlow"]=1, ["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1, ["PlayerSecurityInfo"]=1,
                ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1, ["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1, ["IsEnableReportMrpcsInPartCircleFlow"]=1,
                ["bReportedModifierException"]=1, ["ReportModifierException"]=1,
                ["RPC_Server_ReportSimulateCharacterLocation"]=1, ["ReportSimulateCharacterLocation"]=1,
                ["RPC_Client_ShootVertifyRes"]=1, ["BulletHitInfoUploadData"]=1, ["ShootVerifyFailed"]=1,
                ["report_unrealnet_exception"]=1, ["tss_sdk_report"]=1, ["SwiftHawk"]=1,
                ["ClientSwiftHawk"]=1, ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1,
                ["SwiftHawkData"]=1, ["AntiCheatReport"]=1, ["CheatDetection"]=1,
                ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(packetName, ...)
                if blocked[packetName] then return nil end
                return orig(packetName, ...)
            end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk",
                "RPC_Server_ClientSwiftHawkWithParams", "RPC_Server_ReportSimulateCharacterLocation",
                "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...)
                for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end
                return origRPC(rpcName, ...)
            end
        end
    end)
end

-- [16/28] HiggsBoson bypass
local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "Tick", "OnTick", "MHActiveLogic",
                "TriggerAvatarCheck", "StartAvatarCheck", "ReportItemID", "ReceiveAnyDamage",
                "OnWeaponHitRecord", "ShowSecurityAlert", "ServerReportAvatar", "ClientReportNetAvatar",
                "SendHisarData", "ValidateSecurityData", "StaticShowSecurityAlertInDev",
                "RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation",
                "DisableHiggsBoson", "CheckMHActive", "ReportViolation",
                "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity"}) do
                if Higgs[m] then Higgs[m] = _BP_nop end
            end
            Higgs.GetNetAvatarItemIDs = _BP_retEmpty
            Higgs.GetCurWeaponSkinID = _BP_retZero
            Higgs.IsMHActive = _BP_retFalse
            Higgs.bMHActive = false
            Higgs.bCallPreReplication = false
            if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then
                pc.HiggsBoson.bMHActive = false
                pc.HiggsBoson.bCallPreReplication = false
                if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end
            end
            if pc.HiggsBosonComponent then
                pc.HiggsBosonComponent.bMHActive = false
                pc.HiggsBosonComponent.bCallPreReplication = false
                pc.HiggsBosonComponent:ControlMHActive(0)
            end
        end
    end)
end
-- [17/28] Anti-cheat hooks
local function InitializeAntiCheatHooks()
    pcall(function()
        local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HBC and HBC.StaticShowSecurityAlertInDev then HBC.StaticShowSecurityAlertInDev = _BP_nop end
    end)
    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = _BP_nop
        _G.AvatarCheckCallback.OnReportItemID = _BP_nop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
            if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then
                PlayerController.HiggsBosonComponent:ControlMHActive(0)
                PlayerController.HiggsBosonComponent.bMHActive = false
            end
        end
    end
end

-- [18/28] Anti-report
local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem",
            "Client.Security.ClientReportPlayerSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]
            if not sub then local s, r = pcall(require, path) if s and r then sub = r end end
            if sub then
                for k, v in pairs(sub) do
                    if type(v) == "function" and (k:find("Report") or k:find("Record")
                        or k:find("Send") or k:find("Upload") or k:find("Notify")) then
                        pcall(function() sub[k] = _BP_nop end)
                    end
                end
            end
        end
    end)
end

-- [19/28] Gameplay callbacks bypass
local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms",
            "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt",
            "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute",
            "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow",
            "ReportParachuteData", "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow",
            "ReportAimFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord",
            "OnDSConnectionSaturated", "ReportDSNetSaturation", "ReportNetContinuousSaturate",
            "ReportDSNetRate", "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow",
            "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams"}
        for _, f in ipairs(reports) do GC[f] = _BP_nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = _BP_retFalse
        GC.CheckReportSecAttackFlow = _BP_retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1,
                ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, ["kicked"]=1,
                ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1,
                ["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = _BP_nop
        GC.OnPlayerActorChannelError = _BP_nop
        GC.OnPlayerRPCValidateFailed = _BP_nop
        GC.OnPlayerSpectateException = _BP_nop
        GC.OnShutdownAfterError = _BP_nop
        GC.IsBypassed = true
    end)
end

-- [20/28] Kill all security subsystems
local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem",
            "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient",
            "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem",
            "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem",
            "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem",
            "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem",
            "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem",
            "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem",
            "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem",
            "MD5CheckSubsystem", "PakVerifySubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do
                    if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload")
                        or k:find("Verify") or k:find("Check") or k:find("Validate")
                        or k:find("Scan") or k:find("Detect") or k:find("Collect")
                        or k:find("Flow") or k:find("Heartbeat")) then
                        pcall(function() sub[k] = _BP_nop end)
                    end
                end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

-- [21/28] Operational stats bypass
local function InitializeOperationalStatsBypass()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        local OSS = (subMgr and subMgr:Get("OperationalStatsSubsystem")) or _G.OperationalStatsSubsystem
        if OSS then
            OSS.ReportOperationalStats = _BP_nop
            OSS.AddOperationalStats = _BP_nop
            OSS.HandleTouchBegin = _BP_nop
            OSS.HandleTouchEnd = _BP_nop
            OSS.OnInit = _BP_nop
            OSS.HandleEnterFighting = _BP_nop
            OSS.OnBattleResult = _BP_nop
            if OSS.TimerHandle then
                pcall(function() OSS:RemoveGameTimer(OSS.TimerHandle) end)
                OSS.TimerHandle = nil
            end
            OSS.StatsData = {}
        end
    end)
end

-- [22/28] Final protection
local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY",
            "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT",
            "ENABLE_PERFORMANCE_REPORT"}) do
            if _G[flag] then _G[flag] = false end
        end
        local origReq = require
        local blocked = {"HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem",
            "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient",
            "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem"}
        _G.require = function(m)
            for _, b in ipairs(blocked) do if m:find(b) then return {} end end
            return origReq(m)
        end
    end)
end

-- [23/28] Debug hook removal
local function InitializeDebugHookRemoval()
    pcall(function()
        if debug then
            if debug.sethook then debug.sethook() end
            if debug.setmetatable then
                local orig_setmt = debug.setmetatable
                debug.setmetatable = function(t, mt)
                    if t == _G then return end
                    return orig_setmt(t, mt)
                end
            end
        end
        if jit then
            pcall(function() jit.off() end)
            pcall(function() if jit.attach then jit.attach(function() end, "bc") end end)
        end
    end)
end

-- [24/28] DS state ban filter
local function InitializeDSStateBanFilter()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        local GC = _G.GameplayCallbacks
        local _origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = string.lower(tostring(State or ""))
            local blocked_states = {
                "cheatdetected", "banned", "kicked", "suspended",
                "violationdetected", "integrityfailure", "securityviolation",
                "hackdetected", "moddetected", "anticheat",
                "permanentban", "temporaryban", "10yearban", "1dayban",
                "punished", "penalized", "sanctioned", "restricted",
                "accountsuspended", "cheatingpenalty", "fairplaybanned"
            }
            for _, bs in ipairs(blocked_states) do
                if s:find(bs, 1, true) then return end
            end
            if _origState then pcall(_origState, UID, State, bPure, bSafe, Param) end
        end
        local ban_rpcs = {
            "OnPlayerBanned", "OnPlayerKicked", "OnPlayerSuspended",
            "OnCheatDetected", "OnViolationDetected", "OnSecurityBan",
            "OnFairPlayBan", "OnPermanentBan", "OnTemporaryBan",
            "OnAccountSuspended", "NotifyBanResult", "OnBanNotification",
            "OnPunishmentApplied", "OnPenaltyApplied", "OnSanctionApplied",
            "OnPlayerNetConnectionClosed", "OnPlayerActorChannelError",
            "OnPlayerRPCValidateFailed", "OnShutdownAfterError",
        }
        for _, rpc in ipairs(ban_rpcs) do GC[rpc] = function() end end
        for _, path in ipairs({
            "GameLua.Mod.BaseMod.Client.Security.BanNotificationSubsystem",
            "GameLua.Mod.BaseMod.Client.Security.PunishmentSubsystem",
            "GameLua.Mod.BaseMod.Client.Security.FairPlaySubsystem",
            "GameLua.Mod.BaseMod.Client.AntiCheat.BanProcessSubsystem",
        }) do
            if not package.loaded[path] then
                package.preload[path] = function()
                    return {
                        OnBanReceived = function() end,
                        ProcessBan = function() end,
                        NotifyBan = function() end,
                        ApplyPunishment = function() end,
                        StartBanTimer = function() end,
                    }
                end
            end
        end
    end)
end

-- [25/28] Ban packet absorber
local function InitializeBanPacketAbsorber()
    pcall(function()
        if not NetUtil or not NetUtil.SendPacket then return end
        if NetUtil._BanAbsorberActive then return end
        local orig = NetUtil.SendPacket
        local ban_packets = {
            ["BanPlayer"]=1, ["KickPlayer"]=1, ["SuspendPlayer"]=1,
            ["NotifyBan"]=1, ["ApplyPunishment"]=1, ["ReportCheatResult"]=1,
            ["ProcessBanRequest"]=1, ["FairPlayBan"]=1, ["SecurityBan"]=1,
            ["TemporaryBan"]=1, ["PermanentBan"]=1, ["AccountBan"]=1,
            ["CheatPenalty"]=1, ["ViolationPenalty"]=1, ["BanNotification"]=1,
            ["SendBanInfo"]=1, ["BanResultPacket"]=1, ["PunishmentPacket"]=1,
        }
        NetUtil.SendPacket = function(name, ...)
            if ban_packets[name] then return nil end
            return orig(name, ...)
        end
        NetUtil._BanAbsorberActive = true
    end)
end

-- [26/28] Print filter
local function InitializePrintFilter()
    pcall(function()
        if _G._PrintFilterActive then return end
        local orig_print = print
        print = function(...)
            local args = {...}
            for _, v in ipairs(args) do
                local s = tostring(v)
                if s:find("OFFICAL_KASHMIRY1VIPMOD🔥",1,true) or s:find("ESP",1,true)
                or s:find("Bypass",1,true) or s:find("Aimbot",1,true)
                or s:find("bypass",1,true) or s:find("BYPASS",1,true)
                or s:find("StartBypass",1,true) or s:find("VIP",1,true)
                then return end
            end
            orig_print(...)
        end
        _G._PrintFilterActive = true
    end)
end

-- [27/28] Metatable shield
local function InitializeMetatableShield()
    pcall(function()
        local orig_mt = getmetatable(_G) or {}
        local orig_index = orig_mt.__index
        orig_mt.__index = function(t, k)
            if k == "_OFFICAL_KASHMIRY1VIPMOD🔥_BYPASS_DONE" or k == "_bypass_active" then return nil end
            if orig_index then return orig_index(t, k) end
            return rawget(t, k)
        end
        setmetatable(_G, orig_mt)
    end)
end

-- [28/28] Subsystem timer killer
local function InitializeSubsystemTimerKiller()
    pcall(function()
        local subMgr
        pcall(function() subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr") end)
        if not subMgr then return end
        local timerSubs = {
            "CoronaLabSubsystem", "SwiftHawkSubsystem", "BehaviorScoreSubsystem",
            "ClientDataStatistcsSubsystem", "AFKReportorSubsystem",
            "AntiCheatSubsystem", "IntegrityCheckSubsystem",
            "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem",
            "GameReportSubsystem", "TelemetrySubsystem",
            "OperationalStatsSubsystem", "MD5CheckSubsystem",
        }
        for _, name in ipairs(timerSubs) do
            pcall(function()
                local sub = subMgr:Get(name)
                if not sub then return end
                for _, field in ipairs({
                    "TimerHandle","timer","heartbeatTimer","reportTimer",
                    "scanTimer","checkTimer","uploadTimer","sendTimer",
                    "collectTimer","telemetryTimer","statsTimer"
                }) do
                    if sub[field] then
                        pcall(function()
                            sub:RemoveGameTimer(sub[field])
                            sub[field] = nil
                        end)
                    end
                end
                if sub.OnInit then sub.OnInit = function() end end
                if sub.StartTimer then sub.StartTimer = function() end end
                if sub.RestartTimer then sub.RestartTimer = function() end end
            end)
        end
    end)
end

-- ==========================================================
-- ========== BYPASS RUNNER ================================
-- ==========================================================
_G.StartBypass_VIP_v3 = function()
    if not (_G.LexusConfig and _G.LexusConfig.BypassEnable) then return end
    pcall(function()
        InitializeSLUABypass()
        InitializeMD5Bypass()
        InitializeSkinBypass()
        InitializeLogBlocker()
        InitializeScannerBlocker()
        InitializeReplayTelemetryBlocker()
        InitializeReportFlowBlocker()
        InitializePlayerSecurityBypass()
        InitializeClientFlowBypass()
        InitializeSwiftHawkBypass()
        InitializeCoronaLabBypass()
        InitializeModifierExceptionBypass()
        InitializeSimulateCharacterLocationBypass()
        InitializeShootVerificationBypass()
        InitializeNetworkPacketBlock()
        InitializeHiggsBosonBypass()
        InitializeAntiCheatHooks()
        InitializeAntiReport()
        InitializeGameplayBypass()
        InitializeKillAllSubsystems()
        InitializeOperationalStatsBypass()
        InitializeFinalProtection()
        InitializeDebugHookRemoval()
        InitializeDSStateBanFilter()
        InitializeBanPacketAbsorber()
        InitializePrintFilter()
        InitializeMetatableShield()
        InitializeSubsystemTimerKiller()
    end)
end
-- ==========================================================
-- ========== HWID SPOOFER ==================================
-- ==========================================================

pcall(function()
    local SystemLib = import("KismetSystemLibrary")
    if SystemLib and not _G.FakeHWID_Hooked then
        _G.Original_GetDeviceId = SystemLib.GetDeviceId
        SystemLib.GetDeviceId = function(...)
            if _G.LexusConfig and _G.LexusConfig.FakeHWID then
                if not _G.FakeHWID_String then
                    local chars = "0123456789abcdef"
                    local hwid = ""
                    for i = 1, 32 do hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16)) end
                    _G.FakeHWID_String = hwid
                end
                return _G.FakeHWID_String
            end
            if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
            return "UNKNOWN"
        end
        _G.FakeHWID_Hooked = true
    end
end)

_G.GetOriginalHWID = function()
    if _G.Original_GetDeviceId then return tostring(_G.Original_GetDeviceId()) end
    local SystemLib = import("KismetSystemLibrary")
    if SystemLib and type(SystemLib.GetDeviceId) == "function" then return tostring(SystemLib.GetDeviceId()) end
    return "UNKNOWN_DEVICE"
end

-- ==========================================================
-- ========== STARTUP POPUP (@OFFICAL_KASHMIRY1VIPMOD) ===========
-- ==========================================================

local function ShowJasmeetPopup()
    if _G.JasmeetPopupShown then return end
    _G.JasmeetPopupShown = true
    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then
            Msg.Show(1, "@OFFICAL_KASHMIRY1VIPMOD",
                "This mod is made by @OFFICAL_KASHMIRY1VIPMOD\n\nThank you for using!",
                function() end, function() end, "OK", "")
        end
    end)
end

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then ticker.AddTimerOnce(3.0, ShowJasmeetPopup) end
end)

-- ==========================================================

-- ==========================================================
-- ========== ALL SKINS MODULE (FULL) =======================
-- ==========================================================
_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}

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
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0},
    [1101006098] = {1010060925,1010060926,1010060927,1010060919,0,1010060924,1010060918,1010060917,1010060916,1010060915,1010060914,1010060913,0,1010060930,1010060928,1010060929,1010060935,1010060934,1010060933,0,1010060936,0},
    [1101006106] = {1010061004,1010061005,1010061006,1010060999,1010061000,1010061003,1010060998,1010060997,1010060996,1010060995,1010060994,1010060993,0,1010061009,1010061007,1010061008,1010061014,1010061013,1010061010,0,1010061015,0},
}
local F = {}
local DEBUG = false  
function F.log(...)
    if DEBUG then print("[AddOutfit]", ...) end
end

local MATCH_CONFIG = {
    outfitRes = 0,        
    hatRes    = 0,        
    maskRes   = 0,
    glassRes  = 0,
    tshirtRes = 0,        
    pantsRes  = 0,        
    shoesRes  = 0,        
    bagRes    = 0,        
    helmetRes = 0,        
    weaponSkins = {},
}

-- Bảng ID các siêu xe (Thêm tự do nếu có ID mới)
local ITEMS = {
    -- ==============================================================================
    -- HỆ THỐNG GỐC CỦA V7.5 (KHÔNG ĐƯỢC XÓA DÒNG NÀY)
    -- ==============================================================================
    703029, 703044, 703046, 703048, 1400010, 1400062, 1400070, 1400083, 1400100, 1400106, 1400112, 1400117, 1400134, 1407917, 1400170, 
    1400172, 1400173, 1400174, 1400175, 1400177, 1400179, 1400180, 1400228, 1400231, 1400233, 1400236, 1400237, 1400238, 1400242, 1400244,
    202408070, 202408071, 202408072, 202408073, 202408074, 202408075,
    1407905, 1407906, 1407907, 1407908, 1407909, 1407910, 1407911, 1407912, 1407913, 1407914, 1407915, 1407916, 1410585,
    -- ==============================================================================
    -- 1. SÚNG NÂNG CẤP (CHỈ LẤY CẤP ĐỘ CAO NHẤT CỦA TỪNG KHẨU SÚNG)
    -- ==============================================================================
    -- [ M416 ]
    1101004163, -- Hoàng Gia Lộng Lẫy - M416 (Cấp 8)
    1101004201, -- Bạch Lân Nhả Ngọc - M416 (Cấp 8)
    1101004209, -- Thủy Triều Dậy Sóng - M416 (Cấp 8)
    1101004218, -- Ma Ảnh - M416 (Cấp 8)
    1101004226, -- Phong Ấn U Minh - M416 (Cấp 8)
    1101004236, -- Lam Sư Đoạt Mệnh - M416 (Cấp 8)
    1101004246, -- Hỏa Liên - M416 (Cấp 8)
    1101004046, -- Băng giá - M416 (Cấp 7)
    1101004062, -- Chú hề - M416 (Cấp 7)
    1101004078, -- Kẻ lang thang - M416 (Cấp 7)
    1101004086, -- Bò Sát Gầm Gừ - M416 (Cấp 7)
    1101004098, -- Tiếng Gọi Hoang Dã - M416 (Cấp 7)
    1101004138, -- Lõi Công Nghệ - M416 (Cấp 7)

    -- [ AKM ]
    1101001174, -- Bạo Chúa Bộ Lạc - AKM (Cấp 8)
    1101001213, -- Đô Đốc Hải Long Tinh - AKM (Cấp 8)
    1101001242, -- Ngày Phán Quyết - AKM (Cấp 8)
    1101001265, -- Thời Quang Khả Biến - AKM (Cấp 8)
    1101001276, -- Huyễn Thần - AKM (Cấp 8)
    1101001063, -- Huyền thoại Seven Seas - AKM (Cấp 7)
    1101001089, -- Băng giá - AKM (Cấp 7)
    1101001103, -- Hóa Thạch - AKM (Cấp 7)
    1101001116, -- Bí Ngô Kinh Dị - AKM (Cấp 7)
    1101001128, -- Long Vương - AKM (Cấp 7)
    1101001143, -- Hải Tặc Vàng - AKM (Cấp 7)
    1101001154, -- Người Giải Mã - AKM (Cấp 7)
    1101001231, -- Thỏ Tinh Nghịch - AKM (Cấp 7)
    1101001249, -- Thánh Quang (Trăng Thần) - AKM (Cấp 7)
    1101001256, -- Thánh Quang (Lông Vũ Hoàng Kim) - AKM (Cấp 7)
    1101001042, -- Ánh kim - AKM (Cấp 6)
    1101001068, -- Hổ gầm gừ - AKM (Cấp 5)
    
    -- súng M16A4
    1101002156,
    1101002149, -- Celadon Aether - M16A4 (Lv. 5)
    1101002142, -- PUBG MOBILE × G-DRAGON - M16A4 (Lv. 5)
    1101002133, -- Mechagodzilla - M16A4 (Lv. 5)
    1101002125, -- Veldora - M16A4(Lv.5)
    1101002110, -- Sweetheart Surge - M16A4 (Lv. 5)
    1101002117, -- Seraphic Beacon - M16A4 (Lv. 5)
    1101002103, -- Dracoguard - M16A4 (Lv. 5)
    1101002081, -- Skeletal Core - M16A4 (Lv. 7)
    1101002068, -- Radiant Edge - M16A4 (Lv. 5)
    1101002056, -- Aurora Pulse - M16A4 (Lv. 7)
    1101002029, -- Blood & Bones - M16A4 (Lv. 7)
    
    -- [ SCAR-L ]
    1101003146, -- Gai Tà Ác - SCAR-L (Cấp 8)
    1101003167, -- Ma Vương Huyết Hồn - SCAR-L (Cấp 8)
    1101003227, -- Thiên Điểu - SCAR-L (Cấp 8)
    1101003057, -- Súng nước - SCAR-L (Cấp 7)
    1101003070, -- Bí Ngô Ma Quái - SCAR-L (Cấp 7)
    1101003080, -- Chiến Dịch Vì Ngày Mai - SCAR-L (Cấp 7)
    1101003099, -- Drop Da Bass - SCAR-L (Cấp 7)
    1101003119, -- Tinh thể Hextech SCAR-L (Cấp 7)
    1101003188, -- Cái Ôm Của Chú Hề - SCAR-L (Cấp 7)
    1101003195, -- Thánh Nữ Huyền Ảo - SCAR-L (Cấp 7)
    1101003208, -- Vương Quốc Huyền Ảo - SCAR-L (Cấp 7)
    1101003219, -- Kính Pha Lê - SCAR-L (Cấp 7)
    1101003173, -- Ánh Sáng Hoàng Tộc - SCAR-L (Cấp 5)
    1101003212, -- Mèo Ăn Vặt - SCAR-L (Cấp 3)

    -- [ M762 ]
    1101008081, -- Vị Khách Nổi Loạn - M762 (Cấp 8)
    1101008104, -- Lõi Sao Huyền Ảo - M762 (Cấp 8)
    1101008146, -- Bạch Cốt U Minh - M762 (Cấp 8)
    1101008154, -- Khung Xương - M762 (Cấp 8)
    1101008051, -- Bản Nhạc Tình Yêu - M762 (Cấp 7)
    1101008061, -- Phát Bắn Chí Mạng - M762 (Cấp 7)
    1101008070, -- GACKT MOONSAGA - M762 (Cấp 7)
    1101008116, -- Biểu Tượng Bóng Đá Messi - M762 (Cấp 7)
    1101008126, -- Huyết Rồng - M762 (Cấp 7)
    1101008136, -- Tiên Linh Lưu Ly - M762 (Cấp 7)
    1101008163, -- Cổ Vật Hắc Ám - M762 (Cấp 7)
    1101008026, -- Pony Bé Nhỏ - M762 (Cấp 5)
    1101008036, -- Đóa Sen Phẫn Nộ - M762 (Cấp 5)

    -- [ AUG ]
    1101006062, -- Tinh Linh Băng Giá - AUG (Cấp 8)
    1101006085, -- Hoa Hồng Ma Mị - AUG (Cấp 8)
    1101006075, -- Hỏa Ca - AUG (Cấp 7)
    1101006033, -- Gánh Xiếc Rong - AUG (Cấp 5)
    1101006044, -- Evangelion Angel Thứ 4 - AUG (Cấp 5)
    1101006067, -- Ác Mộng Biển Sâu - AUG (Cấp 5)

    -- [ GROZA ]
    1101005038, -- Ryomen Sukuna - Groza (Cấp 7)
    1101005052, -- Lửa U Minh - Groza (Cấp 7)
    1101005098, -- Godzilla Bốc Lửa - Groza (Cấp 7)
    1101005019, -- Kỵ Binh Rừng Sâu - GROZA (Cấp 5)
    1101005025, -- Đêm Huyền Ảo - GROZA (Cấp 5)
    1101005043, -- Trận Chiến Sắc Màu - Groza (Cấp 5)
    1101005082, -- Lồng Đèn Bí Ngô - Groza (Cấp 5)
    1101005090, -- Di Tích Thượng Cổ - Groza (Cấp 5)
    1101005105, -- Singam Roar - Groza (Cấp 5)

    -- [ QBZ & Mk47 & G36C & Honey Badger & FAMAS & ASM Abakan & ACE32 ]
    1101007046, -- Công Chúa Hắc Ám - QBZ (Cấp 7)
    1101007062, -- Hoa Kiếm Chí Mạng - QBZ (Cấp 7)
    1101007071, -- Thiên Mệnh - QBZ (Cấp 7)
    1101007025, -- Ánh Dương - QBZ (Cấp 5)
    1101007036, -- Càn Quét - QBZ (Cấp 5)
    1101007079, -- Băng Quyền - QBZ (Cấp 5)
    1101009019, -- Thỏ Tinh Quái - Mk47 (Cấp 3)
    1101010029, -- Xung Nhịp Sân Cỏ - G36C (Cấp 5)
    1101012033, -- Cổ Mộc Chiến Khí - Honey Badger (Cấp 7)
    1101012009, -- Sắc Màu Huyền Ảo - Honey Badger (Cấp 5)
    1101012018, -- Thanh Âm Du Dương - Honey Badger (Cấp 5)
    1101012024, -- Honey Badger Mikey (Cấp 5)
    1101100012, -- Đế Vương Thần Vực - FAMAS (Cấp 8)
    1101100018, -- Ảo Ảnh Điện Tử - FAMAS (Cấp 5)
    1101101007, -- Uy Vũ Hắc Điểu - ASM Abakan (Cấp 7)
    1101102025, -- Thủy Quái - ACE32 (Cấp 8)
    1101102041, -- Tiên Tri Điềm Lành - ACE32 (Cấp 8)
    1101102049, -- Thì Thầm Cánh Bướm - ACE32 (Cấp 8)
    1101102007, -- Kamehameha - ACE32 (Cấp 7)
    1101102017, -- Ngọc Bích - ACE32 (Cấp 7)
    1101102032, -- Cáo Tinh Nghịch - ACE32 (Cấp 5)

    -- [ SMG (UZI, UMP45, Vector, Thompson, Bizon, MP5K, P90) ]
    1102001120, -- Băng Giá - UZI (Cấp 8)
    1102001130, -- Xiềng Xích Hỏa Ngục - UZI (Cấp 7)
    1102001024, -- Savagery - UZI (Cấp 6)
    1102001036, -- Vật Tổ Thần Bí - UZI (Cấp 5)
    1102004048, -- Lilac Finesse - Thompson SMG (Lv. 3)
    1102004034, -- Candy Cane - Thompson SMG (Lv. 5)
    1102004018, -- Candy Cane - Thompson SMG (Lv. 5)    
    1102001058, -- Khoảnh Khắc Bất Ngờ - UZI (Cấp 5)
    1102001069, -- UZI Quang Hóa (Cấp 5)
    1102001089, -- Ma Pháp - UZI (Cấp 5)
    1102001103, -- Cam Tươi Mát - UZI (Cấp 5)
    1102001102, -- Máy Ép Trái Cây - UZI (Cấp 5)
    1102002438, -- Song Tử Chiến - UMP45 (Cấp 8)
    1102002446, -- Song Tử Đỏ Thẫm - UMP45 (Cấp 8)
    1102002043, -- Hỏa long - UMP45 (Cấp 7)
    1102002061, -- Ảo Mộng Chết Chóc - UMP45 (Cấp 7)
    1102002136, -- Băng Giá - UMP45 (Cấp 7)
    1102002424, -- Thần Khí Anukhra - UMP45 (Cấp 7)
    1102002053, -- EMP - UMP45 (Cấp 5)
    1102002070, -- Đồ Tể Bạch Kim - UMP45 (Cấp 5)
    1102002090, -- Cuộc Chiến 8-Bit - UMP45 (Cấp 5)
    1102002112, -- Ngày Giáng Sinh - UMP45 (Cấp 5)
    1102002117, -- Ong Bắp Cày - UMP45 (Cấp 5)
    1102002129, -- Con Sóng Lễ Hội - UMP45 (Cấp 5)
    1102002143, -- PUBGM X NewJeans - UMP45 (Cấp 5)
    1102003080, -- Cánh Rồng - Vector (Cấp 7)
    1102003100, -- Tuyết Diệt Ảnh - Vector (Cấp 7)
    1102003020, -- Nanh Dơi Huyết Tộc - Vector (Cấp 5)
    1102003031, -- Hoa Hồng Đêm - Vector (Cấp 5)
    1102003039, -- Gấu Tinh Nghịch - Vector (Cấp 5)
    1102003052, -- Bá Tước Vàng - Vector (Cấp 5)
    1102003065, -- Lưỡi Liềm Vàng - Vector (Cấp 5)
    1102003072, -- Sát Thủ Tối Thượng - Vector (Cấp 5)
    1102003090, -- KMF Lancelot - Vector (Cấp 5)
    1102004018, -- Kẹo ngọt - Thompson (Cấp 5)
    1102004034, -- Máy Chạy Hơi Nước - Thompson (Cấp 5)
    1102004048, -- Tử Đằng - Thompson SMG (Cấp 3)
    1102005064, -- Quang Ảo Điện Tử - PP-19 Bizon (Cấp 7)
    1102005007, -- Tắc Kè - PP-19 Bizon (Cấp 5)
    1102005020, -- Skullcrusher - PP-19 Bizon (Cấp 5)
    1102005041, -- Thần Binh Võ Thuật - PP-19 Bizon (Cấp 5)
    1102005052, -- DP Quantum Quake - Bizon (Cấp 5)
    1102005057, -- Lân Sư - PP-19 Bizon (Cấp 5)
    1102005072, -- Huyết Tế - PP-19 Bizon (Cấp 5)
    1102005078, -- SAKAMOTO SHOP - PP-19 (Cấp 5)
    1102007019, -- PUBGM X QWER - MP5K (Cấp 5)
    1102007022, -- Pixel Cổ Điển - MP5K (Cấp 3)
    1102105012, -- Miêu Nữ Công Nghệ - P90 (Cấp 7)
    1102105028, -- Thiên Mã - P90 (Cấp 7)
    1102105018, -- Móng Vuốt Hoàng Kim - P90 (Cấp 5)

    -- [ SNIPER & MARKSMAN RIFLE (Kar98, M24, AWM, SKS, SLR, Mk14, etc.) ]
    1103001202, -- Băng Yêu - Kar98K (Cấp 8)
    1103001060, -- Dấu nanh Phẫn nộ - Kar98K (Cấp 7)
    1103001079, -- Kukulkan Cuồng Nộ - Kar98K (Cấp 7)
    1103001101, -- Ánh Trăng - Kar98K (Cấp 7)
    1103001129, -- Gackt Moon - Kar98K (Cấp 7)
    1103001146, -- Cá Mập Titan - Kar98K (Cấp 7)
    1103001154, -- Mật Mã Chết Chóc - Kar98K (Cấp 7)
    1103001179, -- Điện Cực Tím - Kar98K (Cấp 7)
    1103001191, -- Hồng Hỏa Diệm - Kar98K (Cấp 7)
    1103001085, -- Đêm Nhạc Rock - Kar98K (Cấp 5)
    1103001160, -- Thợ Săn Tinh Vân - Kar98K (Cấp 5)
    1103001183, -- Nhịp Điệu Mèo Con - Kar98K (Cấp 3)
    1103002030, -- Quyền Trượng Pharaoh - M24 (Cấp 7)
    1103002059, -- Tuần Hoàn Sự Sống - M24 (Cấp 7)
    1103002087, -- Nhịp Điệu Hoàn Mỹ - M24 (Cấp 7)
    1103002106, -- Minh Nguyệt Cấm Vực - M24 (Cấp 7)
    1103002156, -- Bình Minh Bóng Tối - M24 (Cấp 7)
    1103002049, -- Hồ Điệp Phu Nhân - M24 (Cấp 5)
    1103002047, -- Giai Điệu Chí Mạng - M24 (Cấp 5)
    1103002094, -- Công Nghệ Cao - M24 (Cấp 5)
    1103003022, -- Neon - AWM (Cấp 7)
    1103003030, -- Chỉ Huy Chiến Trường - AWM (Cấp 7)
    1103003042, -- Godzilla - AWM (Cấp 7)
    1103003051, -- Đại Long Cầu Vồng - AWM (Cấp 7)
    1103003062, -- Hỏa Phượng Hoàng - AWM (Cấp 7)
    1103003079, -- Huyết Hải Thiên Long - AWM (Cấp 7)
    1103003087, -- Thanh Hoa Xà - AWM (Cấp 7)
    1103003099, -- Hắc Khí - AWM (Cấp 7)
    1103003092, -- Hồng Hoang - AWM (Cấp 5)
    1103004037, -- Quý Bà Đỏ - SKS (Cấp 7)
    1103004046, -- Rừng Thép - SKS (Cấp 5)
    1103004058, -- Năng Lượng Băng Tuyết - SKS (Cấp 5)
    1103004080, -- Khiết Hoa Nở Rộ - SKS (Cấp 5)
    1103004087, -- Giai Điệu Tử Thần - SKS (Cấp 5)
    1103005024, -- Quạ Đen - VSS (Cấp 5)
    1103005048, -- Trinh Sát Tuyết Trắng - VSS (Cấp 3)
    1103009022, -- Mùa Hoa Đào - SLR (Cấp 5)
    1103009037, -- Ngọn Lửa Ma Thuật - SLR (Cấp 5)
    1103009051, -- Ma Mộng - SLR (Cấp 5)
    1103009042, -- Thanh Âm Hải Huyền - SLR (Cấp 3)
    1103006030, -- Sông Băng - Mini14 (Cấp 7)
    1103006046, -- Nét Đẹp Thuần Khiết - Mini14 (Cấp 5)
    1103006058, -- Mèo Chiêu Tài - Mini14 (Cấp 5)
    1103006063, -- Tay Đua Gan Dạ - Mini14 (Cấp 5)
    1103006075, -- Nhịp Chiến Nhanh - Mini14 (Cấp 5)
    1103007028, -- Vương Quốc Rồng - Mk14 (Cấp 8)
    1103007020, -- Sức Mạnh Ngân Hà - Mk14 (Cấp 5)
    1103007038, -- Rồng Sữa Mềm Mại - Mk14 (Cấp 5)
    1103007043, -- Hộp Quà May Mắn - Mk14 (Cấp 5)
    1103012010, -- Khủng Long Ephialtes - AMR (Cấp 8)
    1103012019, -- Hỏa Thần - AMR (Cấp 7)
    1103012031, -- Vô Âm Ly Biệt - AMR (Cấp 7)
    1103012039, -- Đại Chiến Huyễn Sắc - AMR (Cấp 7)
    1103012024, -- Tinh Thể Onyx - AMR (Cấp 5)
    1103100007, -- Thú Săn Mồi - Mk12 (Cấp 5)
    1103102007, -- Chiến Hạm Vũ Trụ - DSR (Cấp 7)
    1103103007, -- Vinh Quang Chiến Binh - M1 Garand (Cấp 7)

    -- [ SHOTGUN & MACHINE GUN (S12K, DBS, M249, DP-28, MG3...) ]
    1104001035, -- Độc Hồn - S686 (Cấp 5)
    1104002022, -- Chạng Vạng - S1897 (Cấp 5)
    1104002049, -- Xung Kích Sắc Màu - S1897 (Cấp 3)
    1104003026, -- S12K GACKT (Cấp 7)
    1104003037, -- Kích Hoạt Nguyên Tử - S12K (Cấp 5)
    1104003046, -- Trái Tim Cyber - S12K (Cấp 5)
    1104004035, -- Chiến Giáp Quái Thú - DBS (Cấp 5)
    1104004041, -- Sandsinger - DBS (Cấp 5)
    1104004051, -- Okarun - DBS (Cấp 5)
    1104004024, -- Báo Sắc Màu - DBS (Cấp 3)
    1104102004, -- Tàn Tích Hoàng Kim - NS2000 (Cấp 3)
    1105001034, -- Pháo Giáng Sinh - M249 (Cấp 7)
    1105001048, -- Nữ Đế Ánh Sáng - M249 (Cấp 7)
    1105001069, -- Vương Quyền Hắc Ám - M249 (Cấp 7)
    1105001020, -- Nữ Hoàng Băng Giá M249 V (Cấp 5)
    1105001054, -- Stargaze Fury - M249 (Cấp 5)
    1105001062, -- Graffiti Đường Phố - M249 (Cấp 5)
    1105001075, -- Cá Mập Thép - M249 (Cấp 4)
    1105002091, -- Huyết Họa - DP28 (Cấp 8)
    1105002018, -- Sát Thủ Bí Ẩn - DP-28 (Cấp 5)
    1105002035, -- Ngọc Long - DP-28 (Cấp 5)
    1105002058, -- Chiến Binh Hàng Hải - DP28 (Cấp 5)
    1105002063, -- Rồng Thần Shenron - DP-28 (Cấp 5)
    1105002071, -- Chiến Sĩ Thần Giáp - DP-28 (Cấp 5)
    1105002076, -- Mèo Số Hóa - DP-28 (Cấp 5)
    1105002083, -- DP-28 Frieren's Staff (Cấp 5)
    1105002096, -- Hồ Tộc - DP-28 (Cấp 3)
    1105010019, -- Chiến Thần Bầu Trời - MG3 (Cấp 7)
    1105010008, -- Thiên Khung - MG3 (Cấp 5)
    1105010026, -- Mina Ashiro - MG3 (Cấp 5)

    -- [ CẬN CHIẾN & VŨ KHÍ KHÁC (Skorpion, Nỏ, Chảo, Dao...) ]
    1106008013, -- Mật Mã Vàng - Skorpion (Cấp 5)
    1106008022, -- Bí Ẩn Tinh Tú - Skorpion (Cấp 3)
    1106011008, -- Rồng Rắn Lên Mây - MP7 Kép (Cấp 5)
    1106011003, -- Thợ Săn Kẹo - MP7 (Cấp 3)
    1107001018, -- Chúa Hề Thịnh Nộ - Nỏ (Cấp 3)
    1107098003, -- Rung Chấn Công Nghệ - MGL (Cấp 3)
    1108001057, -- Săn Rồng - Dao (Cấp 3)
    1108001064, -- Đoản Kiếm Yor SPY×FAMILY (Cấp 3)
    1108001069, -- Ki Sword (Cấp 3)
    1108001081, -- Rìu Godzilla Bốc Lửa (Cấp 3)
    1108001085, -- Kiếm Trung Đoàn Trinh Sát Cấp 3
    1108001098, -- Thương Đảo Ngược Thiên Đường - Dao (Cấp 3)
    1108001104, -- Xích Tay - Dao (Cấp 3)
    1108002059, -- Đinh Ba Thủy Triều Thịnh Nộ (Cấp 5)
    1108004125, -- Hũ Mật Ong - Chảo (Cấp 5)
    1108004160, -- Cá Sấu - Chảo (Cấp 5)
    1108004145, -- Đêm Nhạc Rock - Chảo (Cấp 5)
    1108004283, -- Vinh Quang - Chảo (Cấp 6)
    1108004337, -- Chảo Điện Nguyên Tử (Cấp 6)
    1108004356, -- Gà Rán - Chảo (Cấp 3)
    1108004365, -- Yokai Huyền Bí - Chảo (Cấp 3)
    1108004377, -- Chảo Cánh Cụt Vui Vẻ (Cấp 5)
    1108004416, -- Quạt Vũ Điệu Nóng Bỏng - Chảo (Cấp 3)
    1108005050, -- Rồng Băng Giá - Dao Găm (Cấp 3)

    -- ==============================================================================
    -- 2. FULL SIÊU XE (VIP VEHICLES)
    -- ==============================================================================
    -- [ McLaren ]
    1961007, -- McLaren 570S (Đen)
    1961010, -- McLaren 570S (Trắng)
    1961012, -- McLaren 570S (Hồng)
    1961013, -- McLaren 570S (Vàng Trắng)
    1961014, -- McLaren 570S (Vàng Đen)
    1961015, -- McLaren 570S (Ánh Kim)
    1961147, -- McLaren P1 (Trời Sao)
    1961148, -- McLaren P1 (Hồng Rực Rỡ)
    1961149, -- McLaren P1 (Vàng Núi Lửa)
    1907054, -- Xe Đua Đội McLaren F1 (Điện Tử)
    1907058, -- Xe Đua Đội McLaren F1
    1907059, -- Xe Đua Đội McLaren F1 (Chiến Thắng)

    -- [ Koenigsegg ]
    1961016, -- Koenigsegg Jesko (Xám Bạc)
    1961017, -- Koenigsegg Jesko (Cầu Vồng)
    1961018, -- Koenigsegg Jesko (Bình Minh)
    1961029, -- Koenigsegg One:1 Gilt
    1961030, -- Koenigsegg One:1 Cyber Nebula
    1961031, -- Koenigsegg One:1 Jade
    1961032, -- Koenigsegg One:1 Phoenix
    1903074, -- Koenigsegg Gemera (Xám Bạc)
    1903075, -- Koenigsegg Gemera (Cầu Vồng)
    1903076, -- Koenigsegg Gemera (Bình Minh)

    -- [ Lamborghini ]
    1961020, -- Lamborghini Aventador SVJ Verde Alceo
    1961021, -- Lamborghini Centenario Galassia
    1961024, -- Lamborghini Aventador SVJ Blue
    1961025, -- Lamborghini Centenario Carbon Fiber
    1961144, -- Lamborghini Invencible Rosso Efesto
    1961145, -- Lamborghini Invencible Nebula Drift
    1903079, -- Lamborghini Estoque Oro
    1903080, -- Lamborghini Estoque Metal Grey
    1908066, -- Lamborghini Urus Pink
    1908067, -- Lamborghini Urus Giallo Inti

    -- [ Bugatti ]
    1961041, -- Bugatti Veyron 16.4 (Sắc Màu)
    1961042, -- Bugatti Veyron 16.4 (Vàng)
    1961043, -- Bugatti Veyron 16.4
    1915099,
    1961044, -- Bugatti La Voiture Noire
    1961045, -- Bugatti La Voiture Noire (Hợp Kim)
    1961046, -- Bugatti La Voiture Noire (Chiến Binh)
    1961047, -- Bugatti La Voiture Noire (Tinh Vân)
    1961151, -- Bugatti Bolide (Lưỡi Gương)
    1961152, -- Bugatti Bolide (Bỉ Ngạn)
    1915017,
    1915018,
    1961153, -- Bugatti Bolide (Ảo Ảnh Hồ Băng)
    
    -- [ Aston Martin ]
    1961048, -- Aston Martin Valkyrie (Luminous Diamond)
    1961049, -- Aston Martin Valkyrie (Racing Green)
    1915005, -- Aston Martin DBS Volante (Deep Cosmos)
    1915006, -- Aston Martin DBS Volante (Celestial Pink)
    1915007, -- Aston Martin DBS Volante (Black-Bronze Satin)
    1908084, -- Aston Martin DBX707 (Neon Purple)
    1908085, -- Aston Martin DBX707 (Quasar Blue)

    -- [ Pagani ]
    1961051, -- Pagani Zonda R (Tricolore Carbon)
    1961052, -- Pagani Zonda R (Bianco Benny)
    1961053, -- Pagani Zonda R (Melodic Midnight)
    1961054, -- Pagani Imola (Grigio Montecarlo)
    1961055, -- Pagani Imola (Crystal Clear Carbon)
    1961056, -- Pagani Imola (Nebula Dream)
    1961057, -- Pagani Imola (Arctic Aegis)

    -- [ Bentley ]
    1961137, -- Bentley Batur (Kim Cương Lấp Lánh)
    1961138, -- Bentley Batur (Tận Cùng Thời Gian)
    1961139, -- Bentley Betayga Azure (Vương Quốc Huyền Ảo)
    1903200, -- Bentley Flying Spur Mulliner (Tinh Vân Xanh)
    1903201, -- Bentley Flying Spur Mulliner (Dòng Chảy Vịnh Hẹp)
    1908094, -- Bentley Betayga Azure (Mưa Hoa)
    1908095, -- Bentley Betayga Azure (Đêm Yên Tĩnh)
    1915008, -- Bentley Continental GTC Mulliner (Mộng Cảnh Lung Linh)
    1915009, -- Bentley Continental GTC Mulliner (Quý Tộc Áo Tím)

    -- [ Maserati ]
    1961038, -- Maserati MC20 Bianco Audace
    1961039, -- Maserati MC20 Rosso Vincente
    1961040, -- Maserati MC20 Sogni
    1908075, -- Maserati Levante Blu Emozione
    1908076, -- Maserati Luce Arancione
    1908077, -- Maserati Levante Neon Urbano
    1908078, -- Maserati Levante Firmamento

    -- [ Dodge / SRT ]
    1961036, -- Dodge Challenger SRT Hellcat - Blaze
    1961037, -- Dodge Challenger SRT Hellcat - Lime
    1961050, -- Dodge Challenger SRT Hellcat Jailbreak - Hellfire
    1961136, -- Dodge Challenger SRT Hellcat - Blaze
    1961150, -- Dodge Challenger SRT Hellcat Jailbreak - Hellfire
    1903088, -- Dodge Charger SRT Hellcat - Fuchsia
    1903089, -- Dodge Charger SRT Hellcat - Tuscan Torque
    1903090, -- Dodge Charger SRT Hellcat Jailbreak - Violet Venom
    1903189, -- Dodge Charger SRT Hellcat - Tuscan Torque
    1903190, -- Dodge Charger SRT Hellcat Jailbreak - Violet Venom
    1908086, -- Dodge Hornet - Scarlet Sting
    1908088, -- Dodge Hornet GLH Concept - Redline
    1908089, -- Dodge Hornet - Sunburst
    1908188, -- Dodge Hornet GLH Concept - Redline
    1908189, -- Dodge Hornet - Sunburst

    -- [ Porsche ]
    1961062, -- Porsche 918 Spyder (Dòng Nước)
    1961063, -- Porsche 918 Spyder (964 Bạc Ánh Kim)
    1961064, -- Porsche 918 Spyder (Hồng)
    1903218, -- Porsche Panamera Turbo S (Lam Ngọc)
    1903219, -- Porsche Panamera Turbo S (Xanh Viper)
    1908108, -- Porsche Cayenne Turbo GT (Đường Đua Rực Lửa)
    1908109, -- Porsche Cayenne Turbo GT (Cam Dung Nham)
    1915021, -- Porsche 911 Carrera 4 GTS Cabriolet (Ngàn Sao)
    1915022, -- Porsche 911 Carrera 4 GTS Cabriolet (Đỏ Ruby)

    -- [ Shelby / Ford ]
    1961058, -- Shelby 427 Cobra (Xanh & Trắng)
    1961059, -- Shelby 427 Cobra (Graffiti Phục Cổ)
    1903210, -- Shelby GT500 (Đen & Đỏ)
    1903211, -- Shelby GT500 (Người Ngoài Hành Tinh Cyber)
    1961068, -- Ford Mustang GTD (Huyền Thoại Xanh Tươi)
    1961069, -- Ford Mustang GTD (Tinh Thần Nước Mỹ)

    -- [ Lotus ]
    1961060, -- Lotus Emira (Rừng Sâu Thẫm)
    1961061, -- Lotus Emira (Lướt Sắc Xanh)

    -- [ Apollo ]
    1961065, -- Apollo EVO (Vàng Rực Rỡ)
    1961066, -- Apollo EVO (Hoàng Hôn)
    1961067, -- Apollo EVO (Băng Giá)
    1903220, -- Apollo Intensa Emozione (Hỏa Ngục Nóng Chảy)
    1903221, -- Apollo Intensa Emozione (Bóng Ma Tím)
    1903222, -- Apollo Intensa Emozione (Quyết Đấu)
    1903223, -- Apollo Intensa Emozione (Bão Tố)

    -- [ SSC Tuatara ]
    1961140, -- Ảo Ảnh Hoa Hồng SSC Tuatara
    1961141, -- Hạc Trời SSC Tuatara
    1961142, -- Đao Bình Minh SSC Tuatara Striker
    1961143, -- Màn Đêm Xanh SSC Tuatara Striker

    -- [ Tesla ]
    1903071, -- Tesla Roadster (Kim Cương)
    1903072, -- Tesla Roadster (Pha Lê Tím)
    1903073, -- Tesla Roadster (Xanh Biển Cả)

    -- [ Ducati / Motor VIP ]
    1901028, -- Daryls Motorcycle
    1901076, -- Ducati Panigale V4S Swift Mirage
    1901075, -- Ducati Panigale V4S Crimson Storm
    1901074, -- Ducati Panigale V4S Black Phantom
    1901073, -- DUCATI Panigale V4S  
    1901018, -- Skeleton Chariot (Lv. 3)    
    1901027, -- Roaring Tiger Motorcycle (Lv. 3)
    1901047, -- Phantom Motorcycle (Lv. 7)
    1901066, -- Evangelion Mark.06 Motorcycle
    1901089, -- Cosmic Jump Motorcycle (Lv. 4)
    1901092, -- Indian FTR R Carbon
    1901093, -- Indian Scout 101
    1901108, -- CVO™ Road Glide® ST (Limited)
    1901070, -- Nether Visage 2-Seat Motorcycle
    1901090, -- Night Ember 2-Seat Motorcycle

    -- ==============================================================================
    -- 3. FULL BAY DÙ (DÙ RƠI, TÀU LƯỢN, VÁN TRƯỢT BAY)
    -- ==============================================================================
    -- [ DÙ (Parachutes) ]
    1401000, -- New Years Blessing Parachute
    1401001, -- Happy New Year Parachute
    1401002, -- Dù Xương Đỏ
    1401003, -- Dù tiểu quỷ tinh nghịch
    1401005, -- Dù nhện biến hình
    1401006, -- Dù Mùa 5
    1401007, -- Dù sinh nhật
    1401008, -- Dù Sếu Vàng
    1401009, -- Dù Quỷ Đỏ
    1401010, -- Dù hoa bách thảo
    1401011, -- Dù anh đào
    1401012, -- Dù Campus Tournament
    1401013, -- Dù Joker
    1401014, -- Dù chú hề
    1401015, -- Carabao Parachute
    1401016, -- Orange Life Parachute
    1401017, -- Dù ưng vàng
    1401018, -- Dù Quán quân Mùa 8
    1401019, -- Dù Đội trưởng Ryan
    1401020, -- Dù kẻ lang thang
    1401021, -- Dù cung trăng
    1401022, -- OPPO F11 PRO SURVIVOURS PARACHUTE
    1401023, -- Dù lãnh chúa Sekigahara (Vuông)
    1401024, -- Dù Đồng Minh Loot Thính
    1401025, -- Dù Đêm Mê Hoặc (Vuông)
    1401026, -- Dù cát tường
    1401027, -- Dù PMCO
    1401028, -- Dù Quán quân Mùa 7
    1401029, -- Dù sinh nhật rực rỡ
    1401031, -- Dù Quán quân Mùa 6
    1401032, -- Dù Dao Găm Đỏ
    1401033, -- Dù WALKER
    1401034, -- Dù Phù Thủy Băng Giá
    1401035, -- Dù người thách đấu
    1401036, -- Dù BAPE X PUBGM CAMO
    1401037, -- Dù Godzilla (Trắng)
    1401038, -- Dù Godzilla (Vàng)
    1401039, -- Dù Godzilla (Xanh)
    1401040, -- Dù Monarch
    1401041, -- Dù Cà Ri
    1401043, -- Dù Người Gác Đêm
    1401044, -- Dù hoa hồng đen
    1401045, -- Dù Mèo May Mắn
    1401046, -- Dù Đêm u ám
    1401047, -- Dù Cá Voi Sát Thủ
    1401048, -- Dù thủy quái Kraken
    1401050, -- Dù giai điệu âm nhạc
    1401051, -- Dù OPPO Reno
    1401052, -- Dù OPPO VOOC
    1401053, -- Dù Đêm Mê Hoặc
    1401054, -- Dù Chú Heo Tinh Nghịch
    1401055, -- Dù Red (Dài)
    1401056, -- PMJC Parachute
    1401057, -- PMSC Parachute
    1401059, -- Dù Quán quân Draconian
    1401060, -- Dù lãnh chúa Sekigahara
    1401061, -- Dù Tiểu Quỷ
    1401062, -- Dù Quán quân Mùa 9
    1401063, -- Dù Quán quân Mùa 10
    1401064, -- Dù Mèo Đen
    1401065, -- Dù Gà trống
    1401066, -- Dù Mọt Sách Băng Giá
    1401067, -- Dù Người Giảm Đau #11
    1401068, -- Super Power Parachute
    1401071, -- Dù Luân Hồi Vô Tận
    1401072, -- Dù Chúa Tể Muôn Loài
    1401074, -- Dù Bí Ngô Kinh Dị
    1401085, -- Dù Gà Thơm Ngon
    1401086, -- Dù Quán quân Mùa 11
    1401087, -- Dù Hoa Sen Máu
    1401088, -- Dù Hành Tinh Trôi Dạt
    1401089, -- Dù Quán Quân Mùa 12
    1401090, -- Dù Ninja Sát Thủ
    1401091, -- Dù Neko Sakura
    1401092, -- Dù Người Tiên Phong
    1401094, -- Dù Fantasy Girl
    1401095, -- Dù Tranh Vẽ Chiến Trường
    1401096, -- Dù Người Phán Quyết
    1401097, -- Dù Africa Pride
    1401098, -- Dù Africa Unite
    1401100, -- Dù Cậu Vàng
    1401102, -- Dù đặc vụ PMSC World Cup
    1401103, -- Dù Quân Đoàn Thất Lạc
    1401104, -- Dù Giải Đấu PMCO
    1401106, -- Dù Trung Úy Vũ Trụ
    1401107, -- Dù Đầy Tớ Huyết Nha
    1401108, -- Dù Street Dancer 3
    1401109, -- Dù Unique KingCard
    1401111, -- Dù Bánh Ú
    1401112, -- Dù Gào Thét
    1401113, -- Dù Thủ Vệ Tự Do
    1401115, -- Dù Kẹo Ngọt
    1401117, -- Dù Cao Bồi Viễn Tây
    1401119, -- Dù Giáp Samurai
    1401122, -- Incredible Parachute
    1401124, -- Dù Warrior
    1401125, -- Dù Quý Cô Gothic
    1401127, -- Dù Thần Thoại Ả Rập
    1401128, -- Dù Nhà Vô Địch Arena
    1401129, -- Dù Quán Quân Mùa 13
    1401130, -- Dù Gorilla
    1401131, -- Dù PMGC
    1401133, -- Dù Mùa 15
    1401134, -- Dù Tulip
    1401135, -- Dù Ác Ma Cuồng Nộ
    1401137, -- Dù Mùa 14
    1401138, -- Dù Pro League (Vàng)
    1401139, -- Dù Pro League (Bạc)
    1401140, -- Dù Lạc Đà Bảnh Bao
    1401141, -- Dù Gà Rán
    1401142, -- Dù CLB Hoàng Gia
    1401145, -- Dù Bảy Sắc
    1401146, -- Dù Mountain Dew
    1401147, -- Dù Tư Tế Tối Cao
    1401148, -- Dù Idol
    1401149, -- Dù Dang Rộng Đôi Cánh
    1401150, -- Dù Chiến Binh Thép
    1401151, -- Dù Quán Quân Mùa 16
    1401152, -- Dù Liềm Tử Thần
    1401153, -- Dù emoji Thỏa Mãn
    1401154, -- Dù emoji
    1401155, -- Dù emoji Vui Nhộn
    1401156, -- Dù Qualcomm
    1401157, -- Dù Điểm Sơ Tán
    1401159, -- Dù Lãnh Chúa Độc Tài
    1401160, -- Dù Kẹp Hạt Dẻ Vui Vẻ
    1401161, -- Dù Long Vương
    1401163, -- Dù Giáp Chiến Thần
    1401164, -- Dù Giai Điệu Yêu Thương
    1401165, -- Dù Quán Quân Mùa 17
    1401167, -- Dù Ánh Trăng Huyền Bí
    1401168, -- Dù Tiệc Disco
    1401169, -- Dù Quán Quân Mùa 18
    1401170, -- Dù Tuyết Anh Đào
    1401171, -- Dù Tổ Ong
    1401174, -- Dù Quán Quân Mùa 19
    1401177, -- Dù Quán Quân C1S1
    1401178, -- Dù Băng Cát Sét
    1401179, -- Dù El Diablo
    1401181, -- Chúa Tể Băng Giá - Dù
    1401182, -- Dù Kẻ Săn Mồi Biển Xanh
    1401183, -- Dù Mộng Điệp
    1401184, -- Dù Bọ Cánh Cứng
    1401186, -- Dù Rùa và Thỏ
    1401187, -- Dù Nhịp Bước Mạnh Mẽ
    1401188, -- Dù PMPL Mùa Xuân 2021
    1401189, -- Dù GodzillaVsKong
    1401190, -- Dù Hành Trình Kỳ Diệu
    1401191, -- Dù Dấu Ấn Vũ Trụ
    1401192, -- Dù Đầu Bếp Gà
    1401193, -- Dù Nghệ Thuật Sắc Màu
    1401194, -- Dù Aerial Punk Rich Brian
    1401195, -- Dù OPPO
    1401196, -- Dù BUG
    1401197, -- Dù Chúa Tể Bánh Răng
    1401198, -- Dù Xiaomi
    1401200, -- Dù Đôi Mắt Biển Sâu
    1401201, -- Dù OnePlus
    1401204, -- Dù foodpanda
    1401205, -- Dù PMPL Mùa Thu 2021
    1401208, -- Dù Thành Phố Trên Không
    1401209, -- Dù Bóng Ma Tương Lai
    1401210, -- Dù Mật Thám Cơ Khí
    1401212, -- Dù Thành Phố Sắc Màu
    1401213, -- Dù Súng Hoa Hồng
    1401215, -- Dù Băng Giá
    1401216, -- Dù Bản Đồ Kho Báu
    1401217, -- Dù Cơn Sốt Giáng Sinh
    1401218, -- Dù Họa Tiết Vàng
    1401219, -- Dù Vương Quốc Vàng
    1401220, -- Dù Hoàng Hôn Rực Rỡ
    1401221, -- Dù Bồ Câu Trắng
    1401222, -- Dù Vòng Xoay Thời Gian
    1401223, -- Dù Zong
    1401224, -- Dù Quán Quân C1S2
    1401225, -- Dù Quán Quân C1S3
    1401227, -- Dù Đại Hạ Giá
    1401228, -- Dù Lãng Khách Thời Thượng
    1401231, -- Dù PMGC 2021
    1401232, -- Dù Liverpool FC
    1401233, -- Dù Đột Phá
    1401234, -- Dù Voi Sắc Màu
    1401235, -- Dù Hợp Tác Egor Kreed
    1401236, -- Gackt Moon Parachute
    1401237, -- Dù Dune
    1401238, -- Dù Guruh Gundala
    1401239, -- Dù C2S4
    1401240, -- Dù Baby Shark
    1401241, -- Dù JAPAN LEAGUE S2
    1401242, -- Dù Đầu Bếp Quái Thú
    1401243, -- Dù Bá Chủ Đại Dương
    1401244, -- Dù C2S5
    1401245, -- Dù Nữ Hoàng Điện Tử
    1401246, -- Dù Nhâm Dần
    1401247, -- Dù Sắc Xuân
    1401248, -- Dù Jujutsu Kaisen
    1401249, -- Dù Shiba Inu
    1401250, -- Dù Motorola
    1401252, -- Dù Trận Chiến Trendy
    1401254, -- Dù DJ Cá Tính
    1401255, -- Dù Chị Chị Em Em
    1401256, -- Dù Graffiti Neon
    1401257, -- Dù C2S6
    1401258, -- Dù Người Nhện: Không Còn Nhà
    1401259, -- Dù Sát Thủ Thời Không
    1401260, -- Dù Vùng Đất Hoang
    1401261, -- Dù Sắc Màu
    1401262, -- Dù Lễ Hội Sắc Màu
    1401263, -- Dù Rạp Xiếc Thần Kỳ
    1401264, -- Dù Thiếu Nữ Tóc Đỏ
    1401265, -- Dù Bộ Đôi Hoàn Hảo
    1401266, -- Dù Thiếu Nữ Song Sinh
    1401267, -- Dù Cánh Cổng Kỳ Dị
    1401268, -- Dù Thiếu Nữ Anime
    1401269, -- Dù Gà Chiến Đấu
    1401270, -- Dù Nến Xanh
    1401271, -- Dù Hồn Ma Nghịch Ngợm
    1401272, -- Dù Thiếu Nữ Cầu Nguyện
    1401273, -- Dù Ma Nữ Đáng Yêu
    1401274, -- Dù Evangelion NERV
    1401275, -- Dù Chị Em Song Sinh
    1401276, -- Dù PMPL Mùa Xuân 2022
    1401277, -- Dù Gấu Teddy GB
    1401278, -- Dù Sư Tử Thời Trang
    1401280, -- Dù Kỷ Niệm Tuổi Thơ
    1401281, -- Dù C3S7
    1401282, -- Dù Mèo Khổng Lồ
    1401283, -- Dù Butterfinger
    1401284, -- Siêu Dù Nhảy
    1401285, -- Dù Đồng Minh Mùa Hè
    1401286, -- Dù Sóc Chuột
    1401287, -- Dù Hỏa Diệm Ma Giáp
    1401289, -- Dù Heartrocker
    1401290, -- Dù Sư Tử Lưỡng Hà
    1401291, -- Dù realme
    1401292, -- Dù Lil Burger
    1401294, -- Dù Dòng Sông Mộng Mơ
    1401295, -- Dù C3S8
    1401296, -- Dù Đêm Của Phép Màu
    1401298, -- Dù Vinh Quang
    1401299, -- Dù Bản Đồ Sao
    1401300, -- Dù Chúa Tể Gai Độc
    1401301, -- Dù Bóng Ma Và Nàng
    1401302, -- Dù Gai Bé Bỏng
    1401303, -- Dù Uqabi
    1401308, -- Dù Phù Thủy Băng Giá
    1401309, -- Dù Tốc Độ Cực Hạn
    1401310, -- Dù PMWI 2022
    1401311, -- BGMI Esports Parachute
    1401312, -- PMJL SEASON3 Parachute
    1401313, -- PMPS 2022 Parachute
    1401314, -- Dù Chiến Binh Ngưu
    1401315, -- Dù Quyền Lực Tối Thượng
    1401316, -- Dù Đội Bóng Ả Rập
    1401317, -- Dù Ngàn Sao Rực Rỡ
    1401318, -- Dù Pháp Sư Thiên Văn
    1401319, -- Dù C3S9
    1401320, -- Dù BoBoiBoy
    1401323, -- Dù Đường Đua Hoang Dã
    1401324, -- Dù Tuần Lộc Trắng
    1401325, -- Dù Rìu Hoàng Kim
    1401326, -- Dù Vàng Huyền Bí
    1401330, -- Dù Du Hành Tinh Vân
    1401332, -- Dù Mèo Tuyết
    1401334, -- Dù KFC
    1401335, -- Dù Thủy Sư Cuồng Nộ
    1401336, -- Dù Sọ Nham Thạch
    1401337, -- Dù Bá Chủ Bầu Trời
    1401338, -- Dù Grubhub
    1401339, -- Dù AFA
    1401340, -- Dù Huyền Thoại Siêu Sao Messi
    1401343, -- Dù PMGC 2022
    1401345, -- Dù Bản Đồ Kho Báu
    1401346, -- Dù Nobru
    1401347, -- Dù Sony
    1401349, -- Dù Đột Kích Trên Không
    1401351, -- Dù Nữ Hiệp
    1401353, -- Dù Chú Hề Quỷ Quyệt
    1401355, -- Dù Lý Tiểu Long
    1401356, -- Dù Cặp Đôi Diễn Võ
    1401357, -- Dù Donkey King
    1401360, -- Dù Pro League
    1401361, -- Dù Kế Hoạch Đỏ Thẫm
    1401362, -- Dù C4S11
    1401363, -- Dù Bản Đồ Vũ Trụ
    1401364, -- Dù BE@RBRICK
    1401365, -- Dù Nguồn Sáng Vinh Quang
    1401366, -- Dù Ký Ức Xưa
    1401367, -- Dù Bugatti
    1401368, -- Dù Hóa Thạch Khủng Long
    1401369, -- Dù Trốn Thoát T-Rex
    1401370, -- Dù Dragon Ball Super
    1401371, -- Dù C4S12
    1401372, -- Dù Huyết Rồng
    1401373, -- UNIVERSTAR BT21 Parachute
    1401374, -- Dù HUAWEI AppGallery
    1401375, -- Dù PMWI 2023
    1401376, -- Dù C5S13
    1401377, -- Dù Thỏ Disco
    1401378, -- Dù Aston Martin
    1401379, -- Dù Mùa Hè Trên Bãi Biển
    1401380, -- Dù C5S14
    1401381, -- Dù C5S15
    1401382, -- Dù PMGC 2023
    1401383, -- Dù KFC
    1401385, -- Dù Yeti Khổng Lồ
    1401386, -- Dù Pagani
    1401387, -- Dù Báo Sắc Màu
    1401388, -- Dù Bé Sóc Đáng Yêu
    1401389, -- Dù Kỳ Giông Hồng
    1401390, -- RS Swagster Parachute
    1401391, -- Dù Gấu Trúc Ngọt Ngào
    1401392, -- Dù Chiến Binh Hoa Hồng
    1401393, -- Dù Cuộc Chiến Chính Nghĩa
    1401394, -- Dù LINE FRIENDS
    1401395, -- Dù Hồ Ly Thần Bí
    1401396, -- Dù Zanmang Loopy
    1401397, -- Hardik Sky Parachute
    1401398, -- Dù C6S16
    1401399, -- Dù Bóng Ma Quyến Rũ
    1401400, -- Dù Bảo Hộ Hoàng Gia
    1401401, -- Dù Bentley
    1401402, -- SPY×FAMILY Dù
    1401403, -- Dù Nhật Thực
    1401404, -- Dù Chiến Sĩ Thần Giáp
    1401405, -- Dù C6S17
    1401406, -- Dù Giai Điệu Mèo Con
    1401407, -- Dù Thành Phố Hỗn Loạn
    1401408, -- Dù Đôi Cánh Cận Vệ
    1401409, -- Dù Thiết Mã
    1401410, -- Dù Bay Lướt Vũ Trụ
    1401411, -- Dù C6 S18
    1401412, -- Dù Nữ Đế Hắc Ám
    1401413, -- Dù Hợp Tác Lamborghini
    1401416, -- Dù Tượng Đá Cổ Xưa
    1401417, -- Dù Đại Dương Xanh
    1401418, -- KAKAO FRIENDS Parachute
    1401419, -- Dù Infinix GT
    1401420, -- Dù Esports World Cup 2024
    1401421, -- Dù C7S19
    1401422, -- Dù Thỏ Tinh Quái
    1401423, -- Dù Hợp Tác VW
    1401424, -- Dù Miêu Linh Sắc Màu
    1401425, -- Dù Hắc Long Ma Nhãn
    1401426, -- Dù Âm Dương
    1401427, -- NieR:Automata Parachute
    1401428, -- Dù Đam Mê Esports
    1401429, -- Dù C7S20
    1401430, -- Dù Venom: Kèo Cuối
    1401431, -- Dù Bộ Tộc Ngân Hà
    1401432, -- Dù Tuần Lộc Hoàng Gia
    1401433, -- Dù McLaren
    1401434, -- Dù PMGC 2024
    1401435, -- Dù lượn Sói Tuyết
    1401436, -- Dù lượn Bóng Nước
    1401437, -- Dù lượn C7S21
    1401438, -- Dù Cá Koi Xuân Sắc
    1401439, -- Dù Đại Bàng
    1401440, -- Dù Hoa Hồng Bóng Đêm
    1401441, -- Opanchu Parachute
    1401442, -- Neon Drop BE 6 Parachute
    1401443, -- Dù C8S22
    1401444, -- Dù Lượn Hắc Cốt
    1401445, -- Dù Cực Quang Tinh Tú
    1401446, -- Godzilla vs. Dù Destoroyah
    1401447, -- Dù Thỏ Bồng Bềnh
    1401448, -- Parachute(Frieren&Fern)
    1401449, -- Dù C8S23
    1401450, -- Dù Lượn Mã Số Hóa 
    1401451, -- Dù Lượn Khuếch Đại Sắc Màu
    1401452, -- Dù Hợp Tác Shelby
    1401453, -- Dù Ráng Chiều Rực Cháy
    1401454, -- Dù Attack on Titan
    1401455, -- Dù Cơ Khí 
    1401456, -- Mountain Dew Neon Shard Parachute
    1401457, -- Dù C8S24
    1401458, -- Dù Vũ Trụ
    1401459, -- Dù Transformers
    1401460, -- Dù Thần Mệnh
    1401461, -- Dù Cún Yêu
    1401462, -- Bbangbbang's diary Parachute
    1401463, -- Realme Parachute
    1401464, -- Dù Infinix GT
    1401465, -- Dù C9S25
    1401466, -- Dù Ác Quỷ
    1401467, -- Dù Kaiju No. 8
    1401468, -- Dù TEAM SONIC
    1401469, -- Dù Hồ Điệp Lấp Lánh
    1401470, -- Dù Lotus
    1401471, -- Dù Bông Xù
    1401472, -- Dù Gen Hoàn Hảo
    1401473, -- Tokyo Revengers Parachute
    1401474, -- Sky Striker Parachute
    1401475, -- Dù C9S26
    1401476, -- Dù Lượn Gấu Ngọt Ngào
    1401477, -- Dù Balenciaga
    1401478, -- Dù Lượn Tuyết Hàn
    1401479, -- Dù Porsche
    1401480, -- Dù Hắc Linh
    1401481, -- Dù Chồn Chill
    1401482, -- TV Anime DAN DA DAN Parachute
    1401483, -- Dù C9S27
    1401484, -- Dù Lượn Shuriken
    1401485, -- Dù Bóng Ma Anh Quốc
    1401486, -- Dù The King of Fighters
    1401487, -- Dù Lượn Vũ Khúc
    1401488, -- Dù Bảo Thạch
    1401489, -- Dù Chuỗi Mùa Giải (2026H1)
    1401490, -- Dù S28
    1401491, -- Dù Trò Chơi Chúa Hề Lém Lĩnh
    1401492, -- Dù Apollo
    1401493, -- Dù Hacker Lạnh Lùng
    1401494, -- Dù Hội Tụ Đa Chiều
    1401495, -- Catch! Teenieping Parachute
    1401496, -- SAKAMOTO TARO Parachute
    1401497, -- Nakiri Ayame Parachute
    1401498, -- Dù S29
    1401499, -- Toxic Parachute
    1401500, -- Dù Red (Tròn)
    1401511, -- Dù Mèo Tinh Nghịch
    1401513, -- Dù San Martin FC
    1401515, -- Dù Mắt Quỷ
    1401516, -- Dù Sóng Đêm
    1401517, -- Dù Quả Quýt
    1401519, -- Dù Gấu Ngáy Ngủ
    1401520, -- Dù Hậu Duệ Đế Vương
    1401521, -- Dù Mây Cuộn
    1401526, -- Dù Hoa Văn Tráng Lệ
    1401527, -- Dù Trái Tim Biển Cả
    1401528, -- Dù Hành Tinh Mẹ
    1401529, -- Dù Hoàng Tử Ánh Kim
    1401530, -- Dù Giáp Gai
    1401531, -- Dù Vùng Nguy Hiểm
    1401532, -- Dù Ốc Biển
    1401534, -- Dù Vịt Vàng B.Duck
    1401538, -- Dù Thỏ Dịu Dàng
    1401540, -- Dù Yeti
    1401541, -- Dù Pixel Sắc Màu
    1401542, -- Dù Mỹ Vị
    1401543, -- Dù I Love Tao Kae Noi
    1401544, -- Dù Vẹt Baby
    1401545, -- Dù U.F.O
    1401546, -- Dù Baby Shark
    1401547, -- Dù Gấu Nhồi Bông
    1401548, -- Dù Mèo Nghiêm Túc
    1401549, -- Dù Vinh Quang Trường Tồn
    1401551, -- Dù Nữ Vương Khôi Giáp
    1401554, -- Dù Khủng Long Pixel
    1401555, -- Dù Cánh Bướm Hoàng Gia
    1401556, -- Dù Hành Trình Ngọt Ngào
    1401610, -- Dù Chúc Mừng Sinh Nhật
    1401611, -- Dù Sân Khấu Lấp Lánh
    1401613, -- Dù Thẩm Phán Anubis
    1401615, -- Dù Thần Horus
    1401616, -- Dù One Plus
    1401617, -- Dù Sư Tử Hống
    1401618, -- Dù Facebook
    1401619, -- Dù Bùa Hộ Mệnh Pharaoh
    1401620, -- Dù Pharaoh (Xanh)
    1401621, -- Dù Huyết Nha
    1401622, -- Dù LINE FRIENDS
    1401623, -- Dù PMNC 2021
    1401624, -- Dù Poseidon
    1401625, -- Dù Công Chúa Bộ Lạc
    1401628, -- Dù Phượng Hoàng Adarna Ảo Diệu
    1401629, -- Dù Thiếu Nữ Sáng Thế
    1401811, -- Giannis Parachute
    1401813, -- Dù Hành Trình Anh Hùng
    1401814, -- Dù Rock 'n' Roll
    1401815, -- Dù Chỉ Huy Chiến Trường
    1401816, -- Dù BURGER KING
    1401817, -- Dù Chiến Binh Huyết Ưng
    1401820, -- Dù Cá Chuồn
    1401822, -- Dù Quái Thú Đầm Lầy
    1401823, -- Dù Lãnh Chúa Phong
    1401824, -- Dù Hộp Quà
    1401826, -- Dù - Mối Tình Đầu
    1401827, -- Dù Nữ Hoàng Cà Phê
    1401828, -- Dù Vệ Binh Cổ Đại
    1401829, -- Dù Cơn Giận Của Thần
    1401832, -- Dù C4S10
    1401833, -- Dù Quái Thú Mê Cung
    1401835, -- Dù Poker Đối Kháng
    1401836, -- Dù Trò Chơi Chú Hề
    1401837, -- Dù Huyễn Ảnh
    1401838, -- Dù BLUE LOCK
    1401839, -- Dù Ford
    1401840, -- Dù Harley-Davidson®
    1401841, -- Dù Hoa Hồng Cốt
    1401842, -- Dù Song Tử
    1401843, -- Dù Lượn Vòng Nguyệt Quế
    1401844, -- Parachute(Pubniku)
    1401845, -- Dù S30
    1401846, -- Dù Sự Kiện Trial of Fire

    -- [ TÀU LƯỢN / VÁN TRƯỢT / THIẾT BỊ BAY (Gliders/Hoverboards) ]
    4151001, -- Dù (Xanh)
    4151002, -- Hiệu ứng nhảy dù (Vàng)
    4151003, -- Khói Lượn Dù (Hồng)
    4151004, -- Khói lượn xanh
    4151006, -- Khói lượn cầu vồng
    4151010, -- Thiết bị bay Bằng Chíu
    4151012, -- Ván Trượt Chu Kỳ
    4151013, -- Ván Trượt Tuyết
    4151014, -- Ván trượt CHU KỲ 2
    4151015, -- Khói Lượn Dù Chúc Mừng (3 màu)
    4151017, -- Ván trượt Trái Tim Rừng Xanh
    4151018, -- Ván trượt Sinh Nhật
    4151019, -- Tàu Lượn Chiến Thần Tình Yêu
    4151020, -- Ván Trượt Cảnh Vệ C3
    4151021, -- Tàu Lượn Sứ Giả Của Thần
    4151022, -- Tàu Lượn Cánh Vàng
    4151023, -- Ván Trượt Hợp Tác Messi
    4151024, -- Tàu Lượn Giáo Sĩ Đỏ Thẫm
    4151025, -- Tàu Lượn Diều Giấy
    4151026, -- Ván Trượt Đại Sư Võ Hồn
    4151027, -- Ván Trượt Cycle 4
    4151028, -- Ván Trượt Giọt Lệ Huyết
    4151029, -- Tàu Lượn Nữ Đế Ánh Sáng
    4151030, -- Tàu Lượn Ma Vương Huyết Hồn
    4151031, -- Tàu Lượn Khủng Long Túi Tiền
    4151032, -- Tàu Lượn Cánh Rồng Đỏ Thẫm
    4151034, -- Cân Đẩu Vân
    4151035, -- Tàu Lượn Giao Hưởng Gió
    4151036, -- Ván Trượt Máy Dập Sóng
    4151037, -- Ván Trượt CYCLE 5
    4151038, -- Dù Lượn Ngọc Trai Tuyệt Hảo
    4151040, -- Ván trượt Thợ Săn Điện Quang
    4151041, -- Dù Lượn Xương Xanh
    4151042, -- Tàu Lượn Công Chúa Công Nghệ
    4151043, -- Tàu Lượn Công Chúa Công Nghệ
    4151044, -- Ván Trượt Cá Mập
    4151045, -- Dù Lượn Mùa Đông Hoàng Gia
    4151046, -- Ván Trượt Lưỡi Dao Trời Xanh
    4151056, -- Dù Lượn Mùa Đông Hoàng Gia
    4151057, -- Ván Trượt Hỏa Hồ Ly
    4151058, -- Dù Lượn LINE FRIENDS
    4151059, -- Ván Trượt Xuyên Mây
    4151060, -- Dù Lượn Xà Kim
    4151061, -- Ván Trượt CYCLE 6
    4151062, -- Khói Lượn Dù Zanmang Loopy
    4151063, -- SPY×FAMILY Tàu Lượn Bond
    4151064, -- Dù Lượn Thiên Sứ
    4151065, -- Dù Lượn Thiên Sứ
    4151066, -- Dù Lượn Đế Vương Thần Vực
    4151067, -- Dù Lượn Kính Vạn Hoa
    4151068, -- Tàu Lượn Chúa Tể Gai Độc
    4151069, -- Tàu Lượn Tinh Vân Sấm Sét
    4151070, -- Tàu Lượn Kỵ Binh Thần Giáp
    4151071, -- Dù Lượn Vệ Thần Tình Ái
    4151072, -- Dù Lượn Ngao Du Vũ Trụ
    4151073, -- Dù Lượn Neon Huyền Bí
    4151074, -- PUBGM X NewJeans Glider
    4151075, -- Dù Lượn Vệ Thần Tình Ái
    4151076, -- Tàu Lượn Cửu Phong Thiên Tôn
    4151077, -- Máy Bay
    4151078, -- Tàu Lượn Hải Mã Sắt
    4151079, -- Tàu Lượn Đôi Cánh Thế Giới Ngầm
    4151080, -- Ván Trượt Cycle 7
    4151083, -- Dù Lượn Long Cốt
    4151084, -- Hồng Hỏa Diệm - Kar98 (Cấp 8)
    4151085, -- Dù Lượn Cánh Thép Xuyên Không
    4151086, -- DP Drift Parachute
    4151087, -- Dù Lượn Long Cốt
    4151089, -- Dù Lượn Hắc Điểu 
    4151090, -- Dù Lượn Giấc Mộng Ngọt Ngào
    4151091, -- Tàu Lượn Nhà Khám Phá Vũ Trụ
    4151092, -- Dù Lượn Lam Sư Tinh Hà
    4151093, -- Dù Lượn Ngọc Lang Thiên Giới
    4151094, -- Ván Trượt CYCLE 8
    4151095, -- Dù Lượn Đôi Cánh Anukhra
    4151096, -- Dù Lượn Đôi Cánh Pharaoh
    4151097, -- Tàu Lượn Siêu Thú Ghidorah
    4151098, -- Dù Lượn Thời Quang Khả Biến
    4151099, -- Dù Lượn Vương Quyền Hắc Ám
    4151103, -- Dù Lượn Chiến Xa Tinh Tú
    4151104, -- Tàu Lượn Thiết Bị ODM
    4151105, -- Dù Lượn Định Mệnh Huyết Chú
    4151106, -- Dù Lượn Quang Ảo Điện Từ 
    4151107, -- Dù Lượn Chiến Xa Tinh Tú
    4151108, -- Tàu Lượn Laserbreak
    4151109, -- Tàu Lượn Băng Thần
    4151110, -- Tàu Lượn Long Thánh
    4151111, -- Tàu Lượn Thợ Săn Phản Lực
    4151112, -- Tàu Lượn Tà Thần Mỹ Quang
    4151113, -- Ván Trượt CYCLE 9
    4151114, -- Tàu Lượn Long Thánh
    4151115, -- Tàu Lượn Băng Thần
    4151117, -- Tàu Lượn Preondactyl
    4151118, -- Dù Lượn Hồ Điệp Lấp Lánh
    4151119, -- Dù Lượn Chổi Phép Thuật
    4151120, -- Dù Lượn Long Kính
    4151121, -- Mikey Glider
    4151122, -- Dù Lượn Hồ Điệp Lấp Lánh
    4151123, -- Tàu Lượn Băng Linh Lưu Ly
    4151124, -- Tàu Lượn Huyết Dực Tử Thần
    4151125, -- Tàu Lượn Vệ Binh Ngân Hà
    4151126, -- Tàu Lượn Giải Trí
    4151127, -- Tàu Lượn Linh Mộc Vĩnh Cửu
    4151128, -- Tàu Lượn Thần Quang
    4151129, -- Ván Trượt Chuỗi Mùa Giải (2026H1)
    4151130, -- Tàu Lượn Nue
    4151131, -- Tàu Lượn Phượng Hoàng Đế Vương
    4151132, -- Tàu Lượn Huyết Dực Hắc Điểu
    4151133, -- Tàu Lượn Dịch Chuyển Không Gian
    4151134, -- Dù Lượn Đa Vũ Trụ
    4151135, -- SAKAMOTO TARO Glider
    4151138, -- Tàu Lượn Sấm Sét Đỏ
    4151139, -- Tàu Lượn Hư Không
    4151140, -- Tàu Lượn Song Tử
    4151141, -- Tàu Lượn Cerberus
    4151142, -- Tàu Lượn Ngọc Trai
    4151143, -- Tàu Lượn Song Tử
    202408087,
    202408061,
    1102001001,
    4152031, -- Tàu Lượn Ma Vương Huyết Hồn
    4152035, -- Cân Đẩu Vân
    4152036, -- Windborne Euphony Glider
    4152037, -- Ván Trượt Máy Dập Sóng
    4152038, -- Ván Trượt CYCLE 5
    4152039, -- Tàu Lượn Ngọc Trai Tuyệt Hảo
    4152041, -- Boxerbolt Hoverboard (Shop)
    4152042, -- Blueyonder Glider
    4152043, -- Agile Charmer Glider
    4152044, -- Agile Charmer Glider
    4152045, -- Chilly Perch Glider
    4152046, -- Foxy Flare Hoverboard
    4152058, -- LINE FRIENDS Glider (Shop)
    4152059, -- Cloud Piercer Hoverboard (Shop)
    4152060, -- Golden Wings Glider (Shop)
    4152061, -- CYCLE 6 Skateboard (Shop)
    4152063, -- Tàu Lượn Bond SPY×FAMILY (Cửa Hàng)
    4152066, -- Dù Lượn Đế Vương Thần Vực (Cửa Hàng)
    4152067, -- Tàu Lượn Kính Vạn Hoa (Cửa Hàng)
    4152068, -- Tàu Lượn Chúa Tể Gai Độc (Cửa Hàng)
    4152069, -- Tàu Lượn Tinh Vân Sấm Sét (Cửa Hàng)
    4152070, -- Tàu Lượn Kỵ Binh Thần Giáp (Cửa Hàng)
    4152076, -- Tàu Lượn Cửu Phong Thiên Tôn (Cửa Hàng)
    4152077, -- Tàu Lượn (Cửa Hàng)
    4152078, -- Tàu Lượn Hải Mã Sắt (Cửa Hàng)
    4152079, -- Tàu Lượn Đôi Cánh Thế Giới Ngầm (Cửa Hàng)
    4152080, -- Ván Trượt CYCLE 7 (Cửa Hàng)
    4152092, -- Tàu Lượn Lam Sư Tinh Hà (Cửa Hàng)
    4152093, -- Tàu Lượn Ngọc Lang Thiên Giới (Cửa Hàng)
    4152094, -- Ván Trượt CYCLE 8 (Cửa Hàng)
    4152095, -- Dù Lượn Đôi Cánh Anukhra
    4152096, -- Dù Lượn Đôi Cánh Pharaoh
    4152097, -- Tàu Lượn Siêu Thú Ghidorah
    4152098, -- Dù Lượn Thời Quang Khả Biến
    4152099, -- Dù Lượn Vương Quyền Hắc Ám
    4152116, -- Tàu Lượn Long Thánh (Sảnh Một Người)

    -- ==============================================================================
    -- 3. TRANG PHỤC (OUTFITS), X-SUIT & PHỤ KIỆN
    -- ==============================================================================
    -- [ X-SUIT ]
    1407895, -- X-Suit Quạ Huyết (7 Sao)
    1407856, -- X-Suit Phượng Hoàng (7 Sao)
    1405628, -- X-Suit Pharaoh Vàng (6 Sao)
    1406469, -- X-Suit Pharaoh Vàng (7 Sao)
    1405870, -- X-Suit Quạ Huyết (6 Sao)
    1407140, -- X-Suit Poseidon (7 Sao)
    1407142, -- X-Suit Silvanus (7 Sao)
    1407141, -- X-Suit Bão Tuyết (7 Sao)
    1407550, -- X-Suit Ánh Sáng Cầu Vồng (7 Sao)
    1406638, -- X-Suit Hề Bí Ẩn (6 Sao) [Đen]
    1406641, -- X-Suit Hề Bí Ẩn (6 Sao) [Trắng]
    1406872, -- X-Suit Chúa Tể Âm Ty (7 Sao)
    1406971, -- X-Suit Marmoris (7 Sao)
    1407103, -- X-Suit Fiore (7 Sao)
    1407219, -- X-Suit Ignis (7 Sao)
    1407366, -- X-Suit Galadria (7 Sao)
    1407512, -- X-Suit Anukhra (7 Sao)
    1407625, -- X-Suit Dravion (7 Sao) [Nam]
    1407667, -- X-Suit Dravion (7 Sao) [Nữ]

    -- [ OUTFITS ]
    1407870, -- Bộ Nữ Thần Không Gian
    1407871, -- Bộ Thám Tử Đa Vũ Trụ
    1407812, -- Bộ Vệ Binh Hoang Dã
    1407758, -- Bộ Tiên Nữ Mùa Đông
    1407286, -- Bộ Mèo Cyber Tinh Nghịch
    1407329, -- Bộ Ánh Sáng Tĩnh Lặng
    1407391, -- Bộ Nữ Bá Tước Ma Cà Rồng
    1407392, -- Bộ Kẻ Phá Hoại Man Rợ
    1407387, -- Bộ Tử Thần Tận Thế
    1407440, -- Bộ Kẻ Chinh Phục Bắc Cực
    1406985, -- Bộ Người Tình Bãi Biển
    1407470, -- Bộ Thiên Thần Nổi Loạn
    1407471, -- Bộ Cực Quang Nanh Ngọc
    1407522, -- Bộ Hậu Duệ Tiên Cát
    1407330, -- Bộ Đô Đốc Bóng Ma
    1407523, -- Bộ Uy Quyền Tà Ác
    1407558, -- Bộ Thái Dương Thăng Hoa
    1407559, -- Bộ Ánh Sáng Nguyệt Cung
    1407572, -- Bộ Huyết Dạ Hoàng Hôn
    1407682, -- Bộ Kén Ẩn Sĩ
    1407695, -- Bộ Lễ Tình Nhân Rùng Rợn
    1407696, -- Bộ Lăng Kính Thăng Hoa
    1407632, -- Bộ Hắc Dạ Tà Ác
    1407573, -- Bộ Bóng Ma Điện Tử
    1406398, -- Bộ Bóng Ma Rực Lửa
    1406399, -- Bộ Kỵ Binh Oai Vệ
    1406482, -- Bộ Chúa Tể Gai Góc
    1406483, -- Bộ Tinh Vân Sấm Sét
    1406555, -- Bộ Khuôn Mặt Địa Ngục
    1406573, -- Bộ Thiên Nga Bóng Ma
    1406574, -- Bộ Quan Tòa Vũ Trụ
    1406656, -- Bộ Trưa Đẫm Máu
    1406657, -- Bộ Đô Đốc Biển Sao
    1406742, -- Bộ Đạo Sư Bạc
    1406744, -- Bộ Hiệp Sĩ Thái Dương
    1406789, -- Bộ Bóng Ma Địa Ngục
    1406823, -- Bộ Giọt Nguyệt Bất Diệt
    1406824, -- Bộ Kẻ Thù Nhuốm Máu
    1406897, -- Bộ Ác Mộng Đỏ Thẫm
    1407277, -- Trang Phục Hỏa Thần Cổ Ngữ
    1406891, -- Trang Phục Linh Hồn Xác Ướp
    1405623, -- Bộ Xác Ướp Vàng
    1400687, -- Bộ Xác Ướp Trắng
    1407618, -- Bộ Thực Hồn Bắc Cực (Polar Spectrophage)

    -- [ Dragon Ball Super Collab ]
    1406937, -- Trang Phục Nhân Vật Super Saiyan Son Goku
    1406938, -- Trang Phục Nhân Vật Frieza
    1406939, -- Trang Phục Nhân Vật Son Goku
    1406947, -- Trang Phục Nhân Vật Vegeta
    1406948, -- Trang Phục Nhân Vật Super Saiyan Vegeta
    1406950, -- Trang Phục Beerus
    1406951, -- Trang Phục Ma Bư
    1406952, -- Trang Phục Quy Lão Kame
    1406953, -- Trang Phục Nhân Vật Gohan Siêu Cấp
    1406954, -- Trang Phục Nhân Vật Piccolo
    1407264, -- Trang Phục Nhân Vật Vegito
    1407265, -- Trang Phục Nhân Vật Vegito Siêu Saiyan
    1407266, -- Trang Phục Nhân Vật Vegito Siêu Saiyan Xanh
    1407267, -- Trang Phục Nhân Vật Son Goku Siêu Saiyan Xanh
    1407268, -- Trang Phục Nhân Vật Son Goku Siêu Saiyan Xanh (Bị Thương)
    1407269, -- Trang Phục Nhân Vật Vegeta Super Saiyan Xanh
    1407270, -- Trang Phục Nhân Vật Vegeta Siêu Saiyan Xanh (Bị Thương)
    1407271, -- Trang Phục Nhân Vật Bulma

    -- [ Evangelion Collab ]
    1406385, -- Plugsuit Evangelion Shinji
    1406386, -- Plugsuit Evangelion Rei
    1406387, -- Plugsuit Evangelion Asuka
    1406388, -- Plugsuit Evangelion Mari
    1406389, -- Plugsuit Evangelion Kaworu

    -- [ Attack on Titan Collab ]
    1407563, -- Trang Phục Nhân Vật Eren Jaeger
    1407565, -- Trang Phục Nhân Vật Mikasa Ackermann
    1407566, -- Trang Phục Nhân Vật Armin Arlelt
    1407567, -- Trang Phục Titan Khổng Lồ (Armin)
    1407568, -- Trang Phục Nhân Vật Levi
    1407569, -- Trang Phục Titan Bọc Thép

    -- [ Kaiju No. 8 Collab ]
    1407672, -- Trang Phục Nhân Vật Kafka Hibino
    1407673, -- Trang Phục Kaiju No. 8
    1407674, -- Trang Phục Nhân Vật Kikoru Shinomiya
    1407675, -- Trang Phục Kaiju No. 9
    1407676, -- Trang Phục Kaiju No. 10
    1407677, -- Trang Phục Nhân Vật Mina Ashiro
    1407678, -- Trang Phục Nhân Vật Reno Ichikawa
    1407679, -- Trang Phục Nhân Vật Soshiro Hoshina

    -- [ BlackPink & Kpop Collabs ]
    1406132, -- Trang phục DDU-DU DDU-DU ROSÉ
    1406133, -- Trang phục DDU-DU DDU-DU JENNIE
    1406134, -- Trang phục DDU-DU DDU-DU JISOO
    1406135, -- Trang phục DDU-DU DDU-DU LISA
    1406161, -- Trang phục How You Like That ROSÉ
    1406162, -- Trang phục How You Like That JENNIE
    1406163, -- Trang phục How You Like That JISOO 
    1406164, -- Trang phục How You Like That LISA
    1406178, -- Trang phục Lovesick Girls ROSÉ
    1406179, -- Trang phục Lovesick Girls JENNIE
    1406180, -- Trang phục Lovesick Girls JISOO
    1406181, -- Trang phục Lovesick Girls LISA
    1407346, -- PUBGM X NewJeans MINJI Set
    1407347, -- PUBGM X NewJeans HANNI Set
    1407348, -- PUBGM X NewJeans HAERIN Set
    1407349, -- PUBGM X NewJeans DANIELLE Set
    1407350, -- PUBGM X NewJeans HYEIN Set
    1407745, -- Trang Phục RAMI (Babymonster)
    1407746, -- Trang Phục ASA (Babymonster)
    1407747, -- Trang Phục AHYEON (Babymonster)
    1407748, -- Trang Phục RORA (Babymonster)
    1407749, -- Trang Phục CHIQUITA (Babymonster)
    1407750, -- Trang Phục PHARITA (Babymonster)
    1407751, -- Trang Phục RUKA (Babymonster)
    1407826, -- Trang Phục PUBG MOBILE × aespa KARINA
    1407827, -- Trang Phục PUBG MOBILE × aespa GISELLE
    1407828, -- Trang Phục PUBG MOBILE × aespa WINTER
    1407829, -- Trang Phục PUBG MOBILE × aespa NINGNING
    1407687, -- Trang Phục G-DRAGON PEACEMINUSONE
    1407688, -- Trang Phục Sân Khấu của G-DRAGON

    -- [ CÁC COLLAB NỔI BẬT KHÁC (Messi, Lý Tiểu Long, SPYxFAMILY...) ]
    1406648, -- Trang Phục Biểu Tượng Bóng Đá Messi
    1406649, -- Trang Phục Huyền Thoại Siêu Sao Messi
    1406728, -- Trang Phục Kung Fu Lý Tiểu Long
    1406729, -- Trang Phục Chuyên Gia Cận Chiến Lý Tiểu Long
    1406730, -- Trang Phục Rồng Gầm Lý Tiểu Long
    1406731, -- Trang Phục Võ Sĩ Lý Tiểu Long
    1407206, -- SPY×FAMILY Trang Phục Hoàng Hôn
    1407401, -- C.C. Set
    1407402, -- Kallen Kozuki Set
    1407404, -- Suzaku Kururugi Set
    1407405, -- ZERO Set
    1407408, -- Emperor Lelouch Set
    1407769, -- Okarun(transformed) Set
    1407770, -- Okarun Set
    1407771, -- Momo Set
    1407772, -- Jiji(transformed) Set
    1407773, -- Aira Set
    1407794, -- Trang Phục Nhân Vật John Shelby
    1407795, -- Trang Phục Nhân Vật Arthur Shelby
    1407796, -- Trang phục Thomas Shelby
    1407798, -- Trang Phục Nhân Vật Iori Yagami
    1407800, -- Trang Phục Nhân Vật Mai Shiranui
    1407801, -- Trang Phục Nhân Vật Nakoruru
    1407846, -- Trang Phục Nhân Vật Kimono Ryomen Sukuna
    1407848, -- Trang Phục Nhân Vật Suguru Geto
    1407901, -- Trang Phục Nhân Vật Isagi Yoichi
    1407902, -- Trang Phục Nhân Vật Bachira Meguru

    -- [ Set Đồ Đỏ Tự Nhiên & Siêu VIP của Game ]
    1405160, -- Huyền Thoại Godzilla
    1405161, -- Siêu Thú Ghidorah
    1405186, -- Bộ Đồ Godzilla
    1405662, -- Trang phục Giáp Samurai
    1405663, -- Trang phục Sát Thủ Bóng Đêm
    1406020, -- Trang phục Quái Thú
    1406398, -- Trang phục Hỏa Diệm Ma Giáp
    1406399, -- Trang phục Kỵ Binh Thần Giáp
    1406456, -- Trang Phục Anh Hùng Truyền Thuyết
    1406568, -- Trang Phục Nữ Hoàng Bóng Đêm
    1406569, -- Trang Phục Minh Vương Hành Quyết
    1406732, -- Trang Phục Nữ Đế Hoàng Kim
    1406733, -- Trang Phục Hoàng Đế Hoàng Kim
    1406764, -- Trang Phục Thiếu Nữ Đỏ Rực

    -- ==============================================================================
    -- 4. ÁO, QUẦN, GIÀY ĐẸP & TDM (PHONG CÁCH CỰC CHẤT)
    -- ==============================================================================
    -- [ BAPE & ALAN WALKER ]
    1400569, -- BAPE MIX CAMO HOODIE
    1400650, -- BAPE MIX CAMO SHORTS
    1400651, -- BAPE STA MID
    1404000, -- BAPE City Camo Hoodie
    1404002, -- BAPE City Camo Pants
    1404003, -- BAPE Sta Mid
    1404048, -- Áo BAPE X PUBGM CAMO
    1404049, -- Áo Hoodie cá mập BAPE X PUBGM CAMO
    1404050, -- Quần BAPE X PUBGM CAMO
    1404051, -- Giày BAPE X PUBGM CAMO
    1404016, -- Alan Walker T-shirt
    1404017, -- Alan Walker Hoodie
    1404042, -- Trang phục Alan Walker
    1404043, -- Áo Alan Walker
    1404044, -- Quần Alan Walker
    1404045, -- Giày Alan Walker
    1404340, -- Trang phục Alan Walker 2021
    1403038, -- Alan Walker Mask
    1403064, -- Khẩu trang Alan Walker

    -- [ Đồ TDM Phổ Biến (Khăn bịt mặt, Áo Lính, Áo Khoác Đen...) ]
    402001, -- Khăn rằn sinh tồn
    402037, -- Khăn quàng cao bồi
    402043, -- Khăn quàng PUBG (Đỏ-Đen)
    402045, -- Khăn quàng PUBG (Chiến thuật)
    1400158, -- Mặt Nạ Hockey
    1402005, -- Mysterious Leather Mask
    1403100, -- Mặt nạ người leo núi
    403010, -- Áo Ba Lỗ Bẩn (Trắng)
    403028, -- Áo Trench coat (Màu đen)
    403181, -- Áo lính sa mạc
    403182, -- Áo Hoodie săn mồi (Đen)
    403183, -- Áo Hoodie biệt kích (Trắng)
    403192, -- Áo khoác bomber
    404006, -- Quần Jeans (Nâu)
    404008, -- Quần lính (Ka-ki)
    404013, -- Quần lính (Rằn ri)
    404015, -- Quần Jeans Bó (Màu Lam)
    404026, -- Quần túi hộp (Màu be)
    404028, -- Quần túi hộp (Màu đen)
    404084, -- Quần thể thao ngắn (Đen)
    404100, -- Quần người ẩn nấp (Đen)
    405001, -- Giày đế mềm (Màu trắng)
    405002, -- Giày thể thao cổ cao
    405019, -- Giày lính chim ưng (Đen)
    405044, -- Giày đế mềm (Đen)
    1400013, -- Quần Jeans Mỹ

    -- [ CÁC ÁO LẺ VIP (Collab, Siêu Xe) ]
    1404142, -- Áo thun THE WALKING DEAD (Trắng)
    1404143, -- Áo thun THE WALKING DEAD (Đen)
    1404218, -- Áo Hoodie COVERNAT (Trắng)
    1404219, -- Áo Hoodie COVERNAT (Đen)
    1404326, -- Áo thun Xiaomi
    1404327, -- Áo thun OnePlus
    1404405, -- Áo Đấu Hợp Tác Messi × PUBG MOBILE
    1404406, -- Áo Thun Lý Tiểu Long
    1404411, -- Hoodie Ducati
    1404412, -- Giày Ducati Corse City C2
    1404413, -- Quần Ducati Sport C2
    1404414, -- Áo Khoác Ducati Speed Evo C2
    1404426, -- Áo PMGC 2023
    1404427, -- Quần Người Chinh Phục Pagani
    1404428, -- Giày Người Chinh Phục Pagani
    1404508, -- Áo Hoodie Mr.Beast
    1400324, -- áo b
    1400325, -- áo a
    452001, 452002, 452003, -- Găng Tay (Gloves)
    
        -- [ HÀNH ĐỘNG ]
    12201301, -- Hành động Sát thủ Gothic
    12216101, -- Hành động Võ sĩ Huyết Ưng
    12212201, -- Hành động Sát thủ Cực Ám
    12219207, -- Hành động Đại tướng Thiên Ngưu
    12209001, -- Hành động Võ sĩ (Samurai)
    12219561, -- Hành động Áo choàng Đỏ thẫm
    12210001, -- Hành động Cái chạm của Tử thần
    12219022, -- Hành động Thiết vệ Gai góc
    12208801, -- Hành động Dũng sĩ Bán thần
    12210801, -- Hành động Thợ săn Vỏ bạc
    12200701, -- Hành động Du hành Không thời gian
    12219242, -- Hành động Dạo bước Bầu trời
    12206001, -- Hành động Hoa linh Đồng xanh
    12205401, -- Hành động Vua của muôn thú
    12205201, -- Hành động Trái tim Cự thú
    12212601, -- Hành động Sát lục Thần bí
    12205601, -- Hành động Linh hồn Cự thú
    12219208, -- Hành động Hầu vương Cyber
    12212001, -- Hành động Võ thánh
    12206801, -- Hành động Hải long Thần bí
    12209801, -- Hành động Ngự linh sư
    12211401, -- Hành động Nữ phù thủy Băng tuyết
    12207001, -- Hành động Du hành Biển sao
    12211801, -- Hành động Chúa tể Trật tự
    12207901, -- Hành động Hải vương Quyến rũ
    12203401, -- Hành động Kỷ niệm Ảo ảnh
    12204001, -- Hành động Chú hề (Ngày Cá tháng Tư)
    12201801, -- Hành động Người bảo vệ Vùng tuyết
    12215601, -- Hành động Siêu nhân Hằng tinh
    12215532, -- Hành động Lãnh chúa Ngọn lửa
    12213201, -- Hành động Kế hoạch Ngày mai
    12215529, -- Hành động Kỵ sĩ Đua xe
    12219053, -- Hành động Nữ hoàng Trân bảo
    12204601, -- Hành động Thiên hạ Bố võ
    12215701, -- Hành động Hành tinh Vượn người
    12219003, -- Hành động Bóng tối Thần linh
    12219004, -- Hành động Ngân hồn Rực lửa
    12219009, -- Hành động Mê hoặc Rực lửa
    12219216, -- Hành động Tế tư Héo úa
    
    
    -- tóc mặt tùm lum
    1404198, 1410085, 1404366, 1403137, 1410480, 1403028, 1400158, 40605011, 1404323, 1406001, 1403002,

-- ==============================================================================
    -- MŨ GIÁP VIP (CHỈ LẤY CẤP 1 - GỌN GÀNG, DỄ ẨN NẤP)
    -- ==============================================================================
    1502001183, -- Godzilla Helmet (Lv. 1)
    1502001194, -- Mũ MECHAGODZILLA (Cấp 1)
    1502001093, -- Mũ Thẩm Phán Anubis (Cấp 1) - Pharaoh
    1502001305, -- Mũ Giáp Siêu Nhân Thép (Cấp 1)
    1502001320, -- Mũ Giáp Biểu Tượng Bóng Đá Messi (Cấp 1)
    1502001105, -- Mũ Tàng Hình (Cấp 1)
    1502001364, -- Mũ Giáp PMGC 2023 (Cấp 1)
    1502001373, -- Mũ Giáp LINE FRIENDS BROWN (Cấp 1)
    1502001402, -- APEACH Helmet (LV.1)
    1502001403, -- Bellygom Helmet (LV.1)
    1502001427, -- Opanchu Helmet (Lv.1)
    1502001443, -- Mũ Giáp Sóng Âm Cuồng Loạn (Cấp 1)
    1502001450, -- Mũ Giáp Cún Tinh Nghịch (Cấp 1)
    1502001471, -- Turbo Granny (Beckoning cat) Helmet (Lv. 1)
    1502001480, -- Mũ Giáp PUBG MOBILE × aespa (Cấp 1)
    1502001490, -- Nakiri Ayame Helmet (Lv.1)
    1502001495, -- Mũ BLUE LOCK (Cấp 1)
    1502001001, -- Mũ pizza nóng (Cấp 1)
    1502001004, -- Mũ Cyberpunk (Tím) (Cấp 1)
    1502001005, -- Mũ hộp sọ (Cấp 1)
    1502001046, -- Mũ Samurai - danh dự (Cấp 1)
    1502001058, -- Mũ bảo hiểm Monarch (Cấp 1)
    1502001064, -- Mũ bảo hiểm Thiên Sứ (Cấp 1)
    1502001073, -- Mũ Vệ Binh Robot (Cấp 1)
    1502001078, -- Mũ Ninja Sát Thủ (Cấp 1)
    1502001086, -- Mũ Chuột Tinh Nghịch (Cấp 1)
    1502001099, -- Mũ Corgi (Cấp 1)
    1502001115, -- Mũ Bọ Rùa (Cấp 1)
    1502001133, -- Mũ Bí Ngô Kinh Dị (Cấp 1)
    1502001145, -- Mũ Chú Lính Chì (Cấp 1)
    1502001154, -- Mũ Giáp Đại Bàng Tỏa Sáng (Cấp 1)
    1502001175, -- Mũ Vịt Vàng B.Duck (Cấp 1)
    1502001230, -- Mũ Rồng Công Nghệ (Cấp 1)
    1502001248, -- Mũ Người Mở Đường (Cấp 1)
    1502001264, -- Mũ Ét Ô Ét (Cấp 1)
    1502001276, -- Mũ Vũ Công Bí Ẩn (Cấp 1)
    1502001294, -- Mũ Giáp Ma Pháp Sư (Cấp 1)
    1502001301, -- Mũ Giáp Archon Lừng Lẫy (Cấp 1)
    1502001357, -- Mũ Giáp Son Goku (Cấp 1)
    1502001381, -- Mũ Giáp Hỏa Linh Chí Tôn (Cấp 1)
    1502001416, -- Mũ Giáp PMGC 2024 (Cấp 1)
    1502001453, -- 2025 Esports Helmet (Lv. 1)

    -- ==============================================================================
    -- BA LÔ VIP (CHỈ LẤY CẤP 1 - GỌN GÀNG, DỄ ẨN NẤP)
    -- ==============================================================================
    1501001174, -- Ba lô Pharaoh (Cấp 1)
    1501002174,
    1501003174,
    1501001045,
    1501002045,
    1501003045,
    
    
    
    
    
    
    1501001220, -- Ba lô Huyết Nha (Cấp 1)
    1501001265, -- Ba lô Poseidon (Cấp 1)
    1501001548, -- Balo Thần Thoại Viễn Cổ (Cấp 1)
    1501001559, -- Balo Thanh Hoa Xà (Cấp 1)
    1501001567, -- Ba Lô Hỏa Linh Chí Tôn (Cấp 1)
    1501001577, -- Balo Đôi Cánh Vệ Thần (Cấp 1)
    1501001607, -- Balo Dơi Bóng Đêm (Cấp 1)
    1501001061, -- Ba lô Godzilla (Cấp 1)
    1501001062, -- Ba Lô Siêu Thú Ghidorah (Cấp 1)
    1501001082, -- Ba lô Genbu (Cấp 1)
    1501001112, -- Ba lô Pig Ngốc Nghếch (Cấp 1)
    1501001133, -- Ba lô Joker Khát Máu (Cấp 1)
    1501001243, -- Ba Lô Vịt Vàng B.Duck (Cấp 1)
    1501001273, -- Ba lô MECHAGODZILLA (Cấp 1)
    1501001304, -- Ba lô Ma Vương (Cấp 1)
    1501001331, -- Ba lô của Jinx (Cấp 1)
    1501001340, -- Ba Lô Hải Cẩu Tuyết (Cấp 1)
    1501001376, -- Ba lô Máy Hát Cổ Điển (Cấp 1)
    1501001400, -- Ba lô Baby Shark (Cấp 1)
    1501001463, -- Ba Lô BoBoiBoy (Cấp 1)
    1501001476, -- Ba Lô Biểu Tượng Bóng Đá Messi (Cấp 1)
    1501001480, -- Ba Lô Mì Indomie (Cấp 1)
    1501001487, -- Ba Lô Con Mắt Chết Chóc (Cấp 1)
    1501001521, -- Ba Lô Quy Lão Kame (Cấp 1)
    1501001539, -- Ba Lô PMGC 2023 (Cấp 1)
    1501001540, -- Ba Lô Gà Rán KFC (Cấp 1)
    1501001554, -- Ba Lô LINE FRIENDS SALLY (Cấp 1)
    1501001587, -- Ba Lô Đại Úy Loạn Thế (Cấp 1)
    1501001597, -- Bellygom Backpack (LV.1)
    1501001632, -- Opanchu Backpack (Lv.1)
    1501001643, -- Frieren&Mimic Backbag (Lv.1)
    1501001650, -- Ba Lô Titan Khổng Lồ Cấp 1
    1501001683, -- Ba Lô Balenciaga (Cấp 1)
    1501001715, -- SAKAMOTO TARO Backpack (Lv.1)
    1501001720, -- Ba Lô BLUE LOCK (Cấp 1)
    
        -- [ BALO, MŨ & DÙ LƯỢN ]
    1501001024, -- Balo Bá Tước
    1501002024,
    1501003024,
    1501001742,
    1501002742,
    1501003742,
    1501001058,
    1501002058,
    1501003058,
    1501001726,
    1501002726,
    1501003726,
    1501001287,
    1501002287,
    1501003287,
    1501001640,
    1501002640,
    1501003640,
    1501001688,
    1501002688,
    1501003688,
    1501003051,
    1501002051,
    1501001051,
    1502001014, -- Mũ Đinh
    1502002014,
    1502003014,
    1502001439, -- mũ vương miện
    1502002439,
    1502003439,
    1502002069,
    1502001069, -- mũ cương thi
    1502003069,
    1502001031,
    1502002031,
    1502003031,
    1502001363,
    1502002363,
    1502003363,
    1502001023, -- mũ băng

    -- id bổ xung
    1400092, 1400101, 1400122, --tư lệnh
    1404191, -- quần bộ hành
    1405128, 1405129, 140224445, 140224445, -- crew
    1407961, 1407962, 1407963, 19080660, 1407964, 1407965, 1407966, 1407967, 1407968, 1407969, 1407970, 1407971, 1502001508, 1502002508, 1502003508, 1411134, 1411133, 1411135, 1403771, 1403770, 1407994, 1407993, 1101006106, 1101006098, 4151145, 1903230, 1903231, 1903232, 1908117, 1953011, 1953021,1953012, 1908118, 1908119, 19116002, 19116003, 19116004, 1961070, 1961071, 1961072, 1961073, 1408045, 1408038, 1407990,1407922, -- Trang Phục Nữ Thần Ái Tình
    1407704, -- Trang Phục Cô Dâu Tinh Quái
    1400782, -- Trang phục băng tuyết
    1407614, -- Trang Phục Optimus Prime Transformers
    1407276, -- Trang Phục Vệ Thần Tình Ái
    1410356, -- Mặt Nạ Ma Vương Huyết Hồn
    40605012, -- Tóc Hai Chùm
    401035, -- Mũ cao bồi (Trắng)
    1916004, --Tesla Cybertruck (Splendid-Silver)
   1916005, --Tesla Cybertruck (Dystopia Blue)
   1916006, --Tesla Cybertruck (Black-Quartz)
}

local INS_BASE = 2000000000
local PKG_SLOT = 3
local MELEE_ID = 108
local HAT_SUB = 401
local MASK_SUB = 402
local OUTFIT_SUB = 403
local PANTS_SUB = 404
local SHOES_SUB = 405
local GLASS_SUB = 407
local GLIDER_SUB = 415      
local GLOVES_SUB = 452
local GLIDER_SUBS = { [413] = true, [414] = true, [415] = true }

F.CUST_SLOT = {
    NONE = 0,
    HeadEquipemtSlot = 1,
    HairEquipemtSlot = 2,
    HatEquipemtSlot = 3,
    FaceEquipemtSlot = 4,
    ClothesEquipemtSlot = 5,
    PantsEquipemtSlot = 6,
    ShoesEquipemtSlot = 7,
    BackpackEquipemtSlot = 8,
    HelmetEquipemtSlot = 9,
    ArmorEquipemtSlot = 10,
    ParachuteEquipemtSlot = 11,
    GlassEquipemtSlot = 12,
    NightVisionEquipemtSlot = 13,
    BeardEquipemtSlot = 14,
    GlideEquipemtSlot = 15,
    HandEffectEquipemtSlot = 16,
    BackPack_PendantSlot = 17,
}
_G.CustSlotType = F.CUST_SLOT

local CHASSIS_LIGHT_SUB = 7302
local CHASSIS_LIGHT_IDS = { [7302001] = true, [7302002] = true }
local DEFAULT_CHASSIS_LIGHT = 7302002
local PARACHUTE_SUB = 701   
local DEFAULT_PARACHUTE_RES = 703001  
local TAB_SUIT = 10
local TAB_CLOTHES = 3
local PAGE_AVATAR = 1
local PAGE_VEHICLE = 6
local PAGE_PARACHUTE = 5
local HALL_THEME_TYPE = 202
local SUBTYPE_DEFAULT_TAB = {
    [401] = 1, [402] = 2, [403] = 10, [404] = 4, [405] = 5, [407] = 14,
    [501] = 15, [504] = 15, [502] = 16, [505] = 16,
}
local HAT_SUBS = { [401] = true }
local HELMET_SUBS = { [502] = true, [505] = true }
local HEAD_SUBS = { [401] = true } -- [FIX VIP] Đã xóa 502 và 505 để tách biệt hoàn toàn Mũ Bảo Hiểm khỏi Tóc/Mũ Thời Trang
local BAG_SUBS = { [501] = true, [504] = true }
local FACE_SUBS = { [402] = true, [407] = true }
local BODY_SUBS = { [404] = true, [405] = true, [501] = true, [504] = true, [502] = true, [505] = true }
local GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
local NET_OK = NetErrorCode_NONE or "ok"

local R = { insToRes = {}, resToIns = {}, byWeapon = {} }
local _matchApplied = false

_G.AddOutfitPersist = _G.AddOutfitPersist or { path = nil, dirty = false, scheduled = false, loaded = nil, lastWritten = nil, configVehicleSlots = nil, configWeapons = nil, configSlots = nil, lobbyVehicleSubType = nil, lobbyVehicleIns = nil, lobbyVehicleResID = nil, hallThemeResID = nil, hallThemeIns = nil, configChassisLight = nil, configChassisLightMap = nil }
local PERSIST = _G.AddOutfitPersist

F.persistMarkDirty = function() end

local PERF = {
    lobbySynced     = false,
    mappingsDirty   = true,
    desiredSkins    = nil,
    skinTarget      = {},
    matchActive     = false,
    lastBootstrapAt = 0,
    wearDoneThisMatch = false,  
}
local MATCH_TICK_SEC    = 3.0
local MATCH_MAX_SEC     = 45.0
local BOOTSTRAP_COOLDOWN = 2.0
local INJECT_RETRY_MAX  = 5
local INJECT_RETRY_SEC  = 3.0

function F.lobbyState()
    _G.AddOutfitLobbyState = _G.AddOutfitLobbyState or {
        wardrobeRefreshed = false,
        reapplyScheduled  = false,
        reapplyDone       = false,
        outfitResolved    = false,
        skinResolved      = false,
        cachedOutfit      = nil,
        cachedSkin        = nil,
        injectRefreshGen  = 0,
        lobbySynced       = false,
    }
    return _G.AddOutfitLobbyState
end

local LOBBY = setmetatable({}, {
    __index = function(_, k) return F.lobbyState()[k] end,
    __newindex = function(_, k, v) F.lobbyState()[k] = v end,
})

function F.invalidateLobbyResolved()
    LOBBY.outfitResolved = false
    LOBBY.skinResolved   = false
    LOBBY.cachedOutfit   = nil
    LOBBY.cachedSkin     = nil
end

function F.perfInvalidateLobby()
    LOBBY.lobbySynced   = false
    PERF.mappingsDirty = true
    PERF.desiredSkins  = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    F.invalidateLobbyResolved()
end

function F.cache()
    _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
        outfitRes = nil, outfitIns = nil,
        hatRes = nil, hatIns = nil,
        maskRes = nil, maskIns = nil,
        glassRes = nil, glassIns = nil,
        tshirtRes = nil, tshirtIns = nil,
        pantsRes = nil, pantsIns = nil,
        shoesRes = nil, shoesIns = nil,
        bagRes = nil, bagIns = nil,
        helmetRes = nil, helmetIns = nil,
        weapons = {},
        vehicleSlots = {},  
        hallThemeRes = nil, hallThemeIns = nil,
        parachuteRes = nil, parachuteIns = nil,
        gliderRes = nil, gliderIns = nil,
        glovesRes = nil, glovesIns = nil,
    }
    return _G.AddOutfitEquippedCache
end

function F.cfg(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    return CDataTable.GetTableData("Item", resID)
end

function F.subType(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

function F.wardrobeTab(resID)
    local c = F.cfg(resID)
    return c and tonumber(c.WardrobeTab) or 0
end

function F.depotResID(v)
    return v and tonumber(v.resID or v.res_id) or nil
end

function F.resToCustSlot(resID, st)
    resID, st = tonumber(resID), tonumber(st)
    if not resID or resID <= 0 then return nil end
    st = st or F.subType(F.cfg(resID))
    if st == HAT_SUB or HAT_SUBS[st] then return F.CUST_SLOT.HatEquipemtSlot end
    if st == OUTFIT_SUB then return F.CUST_SLOT.ClothesEquipemtSlot end
    if st == PANTS_SUB then return F.CUST_SLOT.PantsEquipemtSlot end
    if st == SHOES_SUB then return F.CUST_SLOT.ShoesEquipemtSlot end
    if st == MASK_SUB then return F.CUST_SLOT.FaceEquipemtSlot end
    if st == GLASS_SUB then return F.CUST_SLOT.GlassEquipemtSlot end
    if st == GLOVES_SUB then return F.CUST_SLOT.HandEffectEquipemtSlot end
    if BAG_SUBS[st] then return F.CUST_SLOT.BackpackEquipemtSlot end
    if HELMET_SUBS[st] then return F.CUST_SLOT.HelmetEquipemtSlot end
    if F.isParachuteRes(resID) or st == PARACHUTE_SUB then return F.CUST_SLOT.ParachuteEquipemtSlot end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then return F.CUST_SLOT.GlideEquipemtSlot end
    return nil
end

function F.isSuitRes(resID)
    if F.subType(F.cfg(resID)) ~= OUTFIT_SUB then return false end
    return F.wardrobeTab(resID) ~= TAB_CLOTHES
end

function F.isTshirtRes(resID)
    return F.subType(F.cfg(resID)) == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES
end

function F.weaponIdFromSkin(resID)
    local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
    if not m then return nil end
    return m.WeaponID or m.WeaponId
end

function F.isValidWeaponId(weaponID)
    weaponID = tonumber(weaponID)
    if not weaponID or weaponID <= 0 then return false end
    if weaponID == MELEE_ID then return true end
    return weaponID >= 101000 and weaponID < 108000
end

function F.isValidWeaponPersistEntry(weaponID, resID)
    weaponID, resID = tonumber(weaponID), tonumber(resID)
    if not F.isValidWeaponId(weaponID) or not resID or resID <= 0 then return false end
    if weaponID == resID then return false end
    if resID >= 1800000 and resID < 1810000 then return false end
    if resID >= 1900000 and resID < 2000000 then return false end
    if F.isInjectedRes(resID) then
        local wid = tonumber(F.weaponIdFromSkin(resID))
        return wid and wid == weaponID
    end
    local wid = tonumber(F.weaponIdFromSkin(resID))
    return wid and wid == weaponID
end

function F.sanitizeConfigWeapons(wmap)
    if type(wmap) ~= "table" then return {} end
    local clean = {}
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        if F.isValidWeaponPersistEntry(wid, res) then clean[wid] = res end
    end
    return clean
end

function F.indexWeaponSkin(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    if not (GUN_SUB[st] or st == MELEE_ID) then return end
    local wid = F.weaponIdFromSkin(resID)
    wid = tonumber(wid)
    if not wid or wid <= 0 then return end
    R.byWeapon[wid] = R.byWeapon[wid] or {}
    R.byWeapon[wid][resID] = insID
end

function F.isInjectedIns(ins)
    return ins and R.insToRes[tonumber(ins)] ~= nil
end

function F.isInjectedRes(res)
    return res and R.resToIns[tonumber(res)] ~= nil
end

function F.isWeaponSkinRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    return GUN_SUB[st] or st == MELEE_ID
end

function F.isWeaponSkinIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local res = R.insToRes[insID]
    return res and F.isWeaponSkinRes(res)
end

function F.cleanArmoryPollution()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if not Arm.rsp_list then return end
        if Arm.rsp_list.install_list then
            for wid, entry in pairs(Arm.rsp_list.install_list) do
                local ins = tonumber(entry and entry.skin_id)
                if ins and not F.isWeaponSkinIns(ins) then
                    Arm.rsp_list.install_list[wid] = nil
                end
            end
        end
        if Arm.rsp_list.skin_list then
            for wid, skins in pairs(Arm.rsp_list.skin_list) do
                if type(skins) == "table" then
                    for resID in pairs(skins) do
                        if not F.isWeaponSkinRes(tonumber(resID)) then
                            skins[resID] = nil
                        end
                    end
                end
            end
        end
    end)
end

function F.depotSubType(insID, resID)
    resID = tonumber(resID) or tonumber(R.insToRes[insID])
    local st = F.subType(F.cfg(resID))
    if st then return st end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    return d and tonumber(d.itemSubType)
end

function F.tryLocalWearByIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end -- Bỏ qua nếu tắt Mod Skin
    local resID = R.insToRes[insID]
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not resID and d then resID = tonumber(d.resID or d.res_id) end
    if not resID or resID <= 0 then return false end
    local st = F.depotSubType(insID, resID)

    local function mapLocal()
        if not R.insToRes[insID] then
            R.insToRes[insID] = resID
            R.resToIns[resID] = insID
        end
    end

    if st == GLOVES_SUB then mapLocal(); F.putOnGloves(insID) return true end
    F.clearItemExpire(d, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if F.isParachuteRes(resID) then mapLocal(); return F.putOnParachute(insID) end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then mapLocal(); return F.putOnGlider(insID) end

    if st == OUTFIT_SUB then
        mapLocal()
        if F.isSuitRes(resID) or F.wardrobeTab(resID) == TAB_SUIT then
            F.putOnOutfit(insID)
        else
            F.putOnRoleWear(insID)
        end
        return true
    end
    if st == HAT_SUB or HEAD_SUBS[st] then mapLocal(); F.putOnHat(insID) return true end
    if FACE_SUBS[st] then mapLocal(); F.putOnFaceAccessory(insID) return true end
    if BODY_SUBS[st] or HELMET_SUBS[st] then mapLocal(); F.putOnRoleWear(insID) return true end

    if not F.isInjectedIns(insID) then return false end
    if GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.equipWeaponSkin(wid, insID) end
        return true
    end
    if st == MELEE_ID then F.equipWeaponSkin(MELEE_ID, insID) return true end
    if F.isHallThemeRes(resID) and (F.isInjectedIns(insID) or F.isInjectedRes(resID)) then
        mapLocal()
        return F.putOnHallTheme(insID)
    end
    if F.isVehicleRes(resID) and (F.isInjectedIns(insID) or F.isInjectedRes(resID)) then
        mapLocal()
        return F.putOnVehicle(insID)
    end
    return false
end

function F.isHallThemeRes(resID)
    local c = F.cfg(tonumber(resID))
    if not c then return false end
    local t = c.ItemType or c.itemType
    return t == HALL_THEME_TYPE
end

function F.isResourcesReady(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if not F.isInjectedRes(resID) then return true end
    local ready = false
    pcall(function()
        local PufferConst = require("client.slua.logic.download.puffer_const")
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and mgr.GetStateByItemID then
            local st = mgr:GetStateByItemID(resID)
            ready = st == PufferConst.ENUM_DownloadState.Done
        end
    end)
    return ready
end

function F.requestResourceDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not F.isInjectedRes(resID) then return end
    if F.isResourcesReady(resID) then return end
    _G.AddOutfitDownloadQueued = _G.AddOutfitDownloadQueued or {}
    if _G.AddOutfitDownloadQueued[resID] then return end
    _G.AddOutfitDownloadQueued[resID] = true
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PM.Download(PufferConst.ENUM_DownloadType.ODPAK, { resID }, "AddOutfit", function()
            _G.AddOutfitDownloadQueued[resID] = nil
        end)
    end)
end

function F.ensureInjectedResources()
    for res in pairs(R.resToIns) do
        F.requestResourceDownload(tonumber(res))
    end
end

function F.restorePufferHooks()
    pcall(function()
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and _G.AddOutfitPufferOrig then
            mgr.GetStateByItemID = _G.AddOutfitPufferOrig
        end
    end)
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        if PM and _G.AddOutfitPufferGetStateOrig then
            PM.GetState = _G.AddOutfitPufferGetStateOrig
        end
    end)
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local vacImpl = VAC and VAC.__inner_impl
        if vacImpl and _G.AddOutfitVehOrigAssets then
            vacImpl.LuaIsAssetsAlreadyAvailable = _G.AddOutfitVehOrigAssets
        end
    end)
end

function F.invalidateSocialWearCache()
    local s = _G.AddOutfitSocialState
    if s then
        s.wearPatchKey, s.snapshotKey, s.fullSnapshot, s.lastHandSkin = nil, nil, nil, nil
    end
end

function F.clearWeaponEquippedMark(weaponID)
    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if weaponID then
        _G.AddOutfitWeaponEquipped[tonumber(weaponID)] = nil
    else
        for k in pairs(_G.AddOutfitWeaponEquipped) do _G.AddOutfitWeaponEquipped[k] = nil end
    end
end

function F.isWeaponVisuallyEquipped(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID then return false end
    return _G.AddOutfitWeaponEquipped and _G.AddOutfitWeaponEquipped[weaponID] == insID
end

function F.saveWeaponToCache(weaponID, resID, insID)
    F.clearWeaponEquippedMark(weaponID)
    weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
    if not F.isValidWeaponPersistEntry(weaponID, resID) then return end
    local cch = F.cache()
    cch.weapons[weaponID] = { resID = resID, insID = insID or 0 }
    PERSIST.configWeapons = PERSIST.configWeapons or {}
    PERSIST.configWeapons[weaponID] = resID
    _G.AddOutfitLastAppliedSkin = {}
    _matchApplied = false
    F.perfInvalidateLobby()
    F.invalidateSocialWearCache()
    F.persistMarkDirty()
    F.log("ذاكرة سكن", weaponID, "→", resID)
end

function F.cacheWeaponSkinFromIns(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or insID <= 0 then return end
    if F.isInjectedIns(insID) then
        F.saveWeaponToCache(weaponID, R.insToRes[insID], insID)
        return
    end
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        if d and d.resID and tonumber(d.resID) > 0 then
            F.saveWeaponToCache(weaponID, tonumber(d.resID), insID)
        end
    end)
end

function F.saveEquip(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = resID, insID
            _G.AddOutfitLastLobbyTshirtRes = resID
            F.persistRememberSlot("tshirt", resID)
        else
            cch.outfitRes, cch.outfitIns = resID, insID
            _G.AddOutfitLastLobbyOutfitRes = resID
            F.persistRememberSlot("outfit", resID)
            F.invalidateSocialWearCache()
        end
    elseif st == HAT_SUB then
        cch.hatRes, cch.hatIns = resID, insID
        _G.AddOutfitLastLobbyHatRes = resID
        F.persistRememberSlot("hat", resID)
    elseif st == MASK_SUB then
        cch.maskRes, cch.maskIns = resID, insID
        _G.AddOutfitLastLobbyMaskRes = resID
        F.persistRememberSlot("mask", resID)
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = resID, insID
        _G.AddOutfitLastLobbyGlassRes = resID
        F.persistRememberSlot("glass", resID)
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = resID, insID
        _G.AddOutfitLastLobbyPantsRes = resID
        F.persistRememberSlot("pants", resID)
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = resID, insID
        _G.AddOutfitLastLobbyShoesRes = resID
        F.persistRememberSlot("shoes", resID)
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = resID, insID
        _G.AddOutfitLastLobbyBagRes = resID
        F.persistRememberSlot("bag", resID)
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = resID, insID
        _G.AddOutfitLastLobbyHelmetRes = resID
        F.persistRememberSlot("helmet", resID)
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = resID, insID
        _G.AddOutfitLastLobbyParachuteRes = resID
        F.persistRememberSlot("parachute", resID)
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = resID, insID
        _G.AddOutfitLastLobbyGliderRes = resID
        F.persistRememberSlot("glider", resID)
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = resID, insID
        _G.AddOutfitLastLobbyGlovesRes = resID
        F.persistRememberSlot("gloves", resID)
    elseif GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.saveWeaponToCache(wid, resID, insID) end
    elseif st == MELEE_ID then
        F.saveWeaponToCache(MELEE_ID, resID, insID)
    end
    _matchApplied = false
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.findWornInsBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return nil end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    return ins, res
                end
            end
        end
    end
    return nil
end

function F.syncHatCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(HAT_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.hatRes, cch.hatIns = tonumber(res), ins
            return
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        local headIns = tonumber(bag and bag.head_show) or 0
        if headIns <= 0 then return end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(headIns) or wd:GetHallDepotItemDataByInsID(headIns)
        if not d or not d.resID or tonumber(d.resID) <= 0 then return end
        local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
        if HEAD_SUBS[st] then
            cch.hatRes, cch.hatIns = tonumber(d.resID), headIns
        end
    end)
end

function F.syncFaceCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(MASK_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.maskRes, cch.maskIns = tonumber(res), ins
            _G.AddOutfitLastLobbyMaskRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLASS_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.glassRes, cch.glassIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlassRes = tonumber(res)
        end
    end)
end

function F.syncBodyCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.wardrobeTab(r) == TAB_CLOTHES end)
        if ins and res and tonumber(res) > 0 then
            cch.tshirtRes, cch.tshirtIns = tonumber(res), ins
            _G.AddOutfitLastLobbyTshirtRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(PANTS_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.pantsRes, cch.pantsIns = tonumber(res), ins
            _G.AddOutfitLastLobbyPantsRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(SHOES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.shoesRes, cch.shoesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyShoesRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLOVES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.glovesRes, cch.glovesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlovesRes = tonumber(res)
        end
    end)
    pcall(function()
        for st in pairs(BAG_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
                cch.bagRes, cch.bagIns = tonumber(res), ins
                _G.AddOutfitLastLobbyBagRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        for st in pairs(HELMET_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
                cch.helmetRes, cch.helmetIns = tonumber(res), ins
                _G.AddOutfitLastLobbyHelmetRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        if ins and res and tonumber(res) > 0 then
            cch.outfitRes, cch.outfitIns = tonumber(res), ins
            _G.AddOutfitLastLobbyOutfitRes = tonumber(res)
        end
    end)
end

function F.syncAirborneCacheFromLobby(saveToConfig)
    local cch = F.cache()
    local cfgPara = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    local cfgGlide = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    local changed = false

    local function maybeSave(slotName, res)
        if not saveToConfig or not res or res <= 0 then return end
        if slotName == "parachute" and res == DEFAULT_PARACHUTE_RES
            and cfgPara and cfgPara > 0 and cfgPara ~= DEFAULT_PARACHUTE_RES then
            return
        end
        F.persistRememberSlot(slotName, res)
        changed = true
    end

    local function applyPara(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isParachuteRes(res) then return end
        if cfgPara and cfgPara > 0 and not saveToConfig then
            if res == cfgPara then cch.parachuteIns = ins end
            return
        end
        if res == DEFAULT_PARACHUTE_RES and not saveToConfig then return end
        if cch.parachuteRes ~= res or cch.parachuteIns ~= ins then
            cch.parachuteRes, cch.parachuteIns = res, ins
            _G.AddOutfitLastLobbyParachuteRes = res
            maybeSave("parachute", res)
        end
    end

    local function applyGlide(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isGlideRes(res) then return end
        if cfgGlide and cfgGlide > 0 and not saveToConfig then
            if res == cfgGlide then cch.gliderIns = ins end
            return
        end
        if cch.gliderRes ~= res or cch.gliderIns ~= ins then
            cch.gliderRes, cch.gliderIns = res, ins
            _G.AddOutfitLastLobbyGliderRes = res
            maybeSave("glider", res)
        end
    end

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local paraIns = tonumber(fbd.GetParachute and fbd:GetParachute()) or 0
        if paraIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(paraIns) or wd:GetHallDepotItemDataByInsID(paraIns)
            applyPara(d and tonumber(d.resID), paraIns)
        end
        local glideIns = tonumber(fbd.GetAircraftOrGliding and fbd:GetAircraftOrGliding()) or 0
        if glideIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(glideIns) or wd:GetHallDepotItemDataByInsID(glideIns)
            applyGlide(d and tonumber(d.resID), glideIns)
        end
    end)
    pcall(function()
        for st in pairs(GLIDER_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res then applyGlide(res, ins) break end
        end
        local ins, res = F.findWornInsBySubType(PARACHUTE_SUB)
        if ins and res then applyPara(res, ins) end
    end)
    if changed then F.persistMarkDirty() end
end

function F.syncWeaponCacheFromLobby(force)
    if LOBBY.lobbySynced and not force then return end
    LOBBY.lobbySynced = true
    PERF.mappingsDirty = true
    PERF.desiredSkins = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    local cch = F.cache()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.weapon_skin_list then
            for weaponID, entry in pairs(bag.weapon_skin_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and (entry.skin_id or entry.skinId)) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm.rsp_list and Arm.rsp_list.install_list then
            for weaponID, entry in pairs(Arm.rsp_list.install_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and entry.skin_id) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    F.syncHatCacheFromLobby()
    F.syncFaceCacheFromLobby()
    F.syncBodyCacheFromLobby()
end

function F.getCachedWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    if weaponID <= 0 then return nil end
    F.syncWeaponCacheFromLobby()
    local w = F.cache().weapons[weaponID]
    if w and w.resID and w.resID > 0 then return w.resID end
    return nil
end

function F.getMatchWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    local fromCache = F.getCachedWeaponSkin(weaponID)
    if fromCache then return fromCache end
    if MATCH_CONFIG.weaponSkins then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponID])
        if fixed and fixed > 0 then return fixed end
    end
    return nil
end

function F.removeRoleWearBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    AvatarData.RemoveRoleWearDataByValue(ins)
                end
            end
        end
    end
end

function F.syncFashionBagRolewear()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
    end)
end

local _ticker
pcall(function() _ticker = require("common.time_ticker") end)
function F.later(sec, fn)
    if _G.SetTimer then pcall(_G.SetTimer, sec, fn) return end
    if _ticker and _ticker.AddTimer then pcall(_ticker.AddTimer, sec, fn) end
end

function F.getPC()
    if slua_GameFrontendHUD then
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    local ok, gd = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if ok and gd then
        local pc = gd.GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    return nil
end

function F.syncVehicleSlotsToDataMgr()
    local cch = F.cache()
    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        local arr = DataMgr.VehicleSlotList[subType]
        if not arr then arr = {}; DataMgr.VehicleSlotList[subType] = arr end
        for k in pairs(arr) do arr[k] = nil end
        for idx, e in pairs(slots or {}) do
            if e and tonumber(e.insID) and tonumber(e.insID) > 0 then
                arr[tonumber(idx)] = tonumber(e.insID)
            end
        end
    end
end

function F.mergeInjectedIntoVehicleSlotList(serverList)
    serverList = serverList or {}
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            local arr = serverList[subType]
            if not arr then arr = {}; serverList[subType] = arr end
            for idx, e in pairs(slots) do
                idx = tonumber(idx)
                local insID = e and tonumber(e.insID)
                if idx and insID and insID > 0 and F.isInjectedIns(insID) then
                    arr[idx] = insID
                end
            end
        end
    end
    local cfg = PERSIST.configVehicleSlots
    if cfg then
        for subType, slotMap in pairs(cfg) do
            subType = tonumber(subType)
            if subType and type(slotMap) == "table" then
                local arr = serverList[subType]
                if not arr then arr = {}; serverList[subType] = arr end
                for idx, res in pairs(slotMap) do
                    idx, res = tonumber(idx), tonumber(res)
                    local ins = res and R.resToIns[res]
                    if idx and ins and F.isInjectedIns(ins) then
                        arr[idx] = ins
                    end
                end
            end
        end
    end
    return serverList
end

function F.applyVehicleSlotsFromConfigMap(slotMap)
    if not slotMap or not next(slotMap) then return false end
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local any = false
    for subType, slots in pairs(slotMap) do
        subType = tonumber(subType)
        if subType then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, res in pairs(slots) do
                idx, res = tonumber(idx), tonumber(res)
                local ins = res and R.resToIns[res]
                if idx and ins then
                    cch.vehicleSlots[subType][idx] = { resID = res, insID = ins }
                    any = true
                end
            end
        end
    end
    return any
end

function F.notifyVehicleSlotUI()
    pcall(function()
        local WRH = require("client.network.Protocol.WardrobeNewHandler")
        WRH.on_depot_modify_combat_vehicle_rsp(0, DataMgr.VehicleSlotList or {})
    end)
end

function F.mergeInjectedVehicleSkinTable(serverTable)
    serverTable = serverTable or {}
    local cfg = PERSIST.configVehicleSlots
    if not cfg then return serverTable end
    for subType, slotMap in pairs(cfg) do
        subType = tonumber(subType)
        if subType and type(slotMap) == "table" then
            local res = tonumber(slotMap[1] or slotMap["1"])
            local ins = res and R.resToIns[res]
            if ins and F.isInjectedIns(ins) then
                serverTable[subType] = ins
            end
        end
    end
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        local e = slots and (slots[1] or slots["1"])
        local insID = e and tonumber(e.insID)
        if subType and insID and insID > 0 and F.isInjectedIns(insID) then
            serverTable[subType] = insID
        end
    end
    return serverTable
end

function F.equipVehicleTypesFromConfig(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
    local subTypes = {}
    for st in pairs(slotMap) do
        local n = tonumber(st)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    local any, lobbyRes, lobbyIns = false, nil, nil
    for _, subType in ipairs(subTypes) do
        local slots = slotMap[subType] or slotMap[tostring(subType)]
        if type(slots) == "table" then
            local res = tonumber(slots[1] or slots["1"])
            local ins = res and R.resToIns[res]
            if ins and F.isInjectedIns(ins) then
                DataMgr.vehicleSkinInsIDTable[subType] = ins
                any = true
                if not lobbyIns then
                    lobbyRes, lobbyIns = res, ins
                end
            end
        end
    end
    if any then
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    return any, lobbyRes, lobbyIns
end

function F.applyLobbyVehicleDisplay(resID, insID, showVehicle)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or insID <= 0 then return end
    _G.AddOutfitApplyingConfig = true
    pcall(function() DataMgr.vst_skin = insID end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        HallThemeUtils.ProcPutOnVehicle({ res_id = resID, instid = insID }, showVehicle ~= false)
    end)
    pcall(F.applyVehicleSkinsToPC)
    _G.AddOutfitApplyingConfig = false
end

function F.setLobbyVehicleManual(subType, resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    subType = tonumber(subType)
    if not insID then return end
    if F.isChassisLightId(resID) or subType == CHASSIS_LIGHT_SUB then return end
    if resID and not F.isVehicleRes(resID) then return end
    if not F.isInjectedIns(insID) and not F.isVehicleRes(resID) then return end
    if not resID then resID = R.insToRes[insID] end
    if not subType and resID then subType = tonumber(F.vehicleSubType(resID)) end
    _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
    _G.AddOutfitLobbyVeh.manual = true
    _G.AddOutfitLobbyVeh.subType = subType
    _G.AddOutfitLobbyVeh.resID = resID
    _G.AddOutfitLobbyVeh.insID = insID
    PERSIST.lobbyVehicleSubType = subType
    PERSIST.lobbyVehicleIns = insID
    PERSIST.lobbyVehicleResID = resID
    F.persistMarkDirty()
end

function F.resolveLobbyVehicle(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    local L = _G.AddOutfitLobbyVeh or {}
    local st = tonumber(PERSIST.lobbyVehicleSubType) or tonumber(L.subType)
    local res = tonumber(PERSIST.lobbyVehicleResID) or tonumber(L.resID)
    if res and res > 0 then
        local ins = R.resToIns[res]
        if ins then
            if not st then st = tonumber(F.vehicleSubType(res)) end
            return res, ins, st
        end
    end
    local ins = tonumber(PERSIST.lobbyVehicleIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then
        res = R.insToRes[ins] or res
        if not st and res then st = tonumber(F.vehicleSubType(res)) end
        return res, ins, st
    end
    if st and slotMap then
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    local subTypes = {}
    for s in pairs(slotMap or {}) do
        local n = tonumber(s)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    if subTypes[1] then
        st = subTypes[1]
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    return nil, nil, nil
end

function F.syncLobbyVehicleResFromIns()
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0 then return end
    local ins = tonumber(PERSIST.lobbyVehicleIns)
    if ins and R.insToRes[ins] then
        PERSIST.lobbyVehicleResID = R.insToRes[ins]
        F.persistMarkDirty()
    end
end

function F.hasExplicitLobbyVehicle()
    local res = tonumber(PERSIST.lobbyVehicleResID)
    local st = tonumber(PERSIST.lobbyVehicleSubType)
    if F.isChassisLightId(res) or st == CHASSIS_LIGHT_SUB then return false end
    if res and res > 0 and not F.isVehicleRes(res) then return false end
    if res and res > 0 then return true end
    if (tonumber(PERSIST.lobbyVehicleIns) or 0) > 0 then return true end
    local L = _G.AddOutfitLobbyVeh
    if L and L.manual and ((tonumber(L.resID) or 0) > 0 or (tonumber(L.insID) or 0) > 0) then return true end
    return false
end

function F.shouldApplyLobbyFromConfig(silent)
    if not F.hasExplicitLobbyVehicle() then return false end
    local _, lobbyIns = F.resolveLobbyVehicle(PERSIST.configVehicleSlots)
    if not lobbyIns then return false end
    local cur = tonumber(DataMgr.vst_skin)
    if cur == lobbyIns then return false end
    return true
end

function F.reapplyVehicleSlotsFromConfig(silent)
    local slotMap = PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    if not F.applyVehicleSlotsFromConfigMap(slotMap) then return false end
    F.syncVehicleSlotsToDataMgr()
    F.notifyVehicleSlotUI()
    F.equipVehicleTypesFromConfig(slotMap)
    if F.shouldApplyLobbyFromConfig(silent) then
        local lobbyRes, lobbyIns = F.resolveLobbyVehicle(slotMap)
        if lobbyIns then
            F.applyLobbyVehicleDisplay(lobbyRes, lobbyIns, not silent)
        elseif not silent then
            pcall(F.applyVehicleSkinsToPC)
            F.perfInvalidateLobby()
        end
    end
    return true
end

function F.applyHallThemeDisplay(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not resID then return false end
    if not F.isInjectedIns(insID) then return false end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    _G.AddOutfitApplyingTheme = true
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        HT.ProcPutOnHallTheme({ res_id = resID, instid = insID }, nil)
    end)
    _G.AddOutfitApplyingTheme = false
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    return true
end

function F.setHallThemeManual(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not F.isInjectedIns(insID) then return end
    if not resID then resID = R.insToRes[insID] end
    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
    _G.AddOutfitLobbyTheme.manual = true
    _G.AddOutfitLobbyTheme.resID = resID
    _G.AddOutfitLobbyTheme.insID = insID
    PERSIST.hallThemeResID = resID
    PERSIST.hallThemeIns = insID
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    F.persistMarkDirty()
end

function F.resolveHallTheme()
    local L = _G.AddOutfitLobbyTheme or {}
    local res = tonumber(PERSIST.hallThemeResID) or tonumber(L.resID)
    if res and R.resToIns[res] then return res, R.resToIns[res] end
    local ins = tonumber(PERSIST.hallThemeIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then return R.insToRes[ins], ins end
    return nil, nil
end

function F.shouldApplyHallThemeFromConfig(silent)
    local _, ins = F.resolveHallTheme()
    if not ins then return false end
    local cur = nil
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        cur = tonumber(HT.GetThemeInstId())
    end)
    if cur == ins then return false end
    if _G.AddOutfitLobbyTheme and _G.AddOutfitLobbyTheme.manual then return true end
    if silent and cur and cur > 0 and F.isInjectedIns(cur) then return false end
    return true
end

function F.putOnHallTheme(insID)
    insID = tonumber(insID)
    if not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if F.applyHallThemeDisplay(resID, insID) then
        F.setHallThemeManual(resID, insID)
        return true
    end
    return false
end

function F.reapplyHallThemeFromConfig(silent)
    if not F.shouldApplyHallThemeFromConfig(silent) then return false end
    local res, ins = F.resolveHallTheme()
    if not res or not ins then return false end
    return F.applyHallThemeDisplay(res, ins)
end

function F.syncVehicleCacheFromDataMgr()
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, insID in pairs(slots) do
                idx, insID = tonumber(idx), tonumber(insID)
                if idx and insID and insID > 0 then
                    local res = R.insToRes[insID]
                    if not res then
                        pcall(function()
                            local d = wd:GetHallDepotItemDataByInsID(insID)
                            res = d and tonumber(d.resID)
                        end)
                    end
                    if res and res > 0 then
                        cch.vehicleSlots[subType][idx] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end
end

function F.vehicleSubType(resID)
    local c = F.cfg(resID)
    return c and (c.ItemSubType or c.itemSubType)
end

function F.modifyInjectedVehicleSlot(insID, slotIndex, equip)
    insID = tonumber(insID)
    slotIndex = tonumber(slotIndex)
    if not insID or not slotIndex then return false end
    local resID = R.insToRes[insID]
    if not resID and insID >= INS_BASE then
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            resID = d and tonumber(d.resID or d.res_id)
        end)
    end
    if not resID then return false end
    local st = F.vehicleSubType(resID)
    if not st or tonumber(st) < 900 then return false end
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    cch.vehicleSlots[st] = cch.vehicleSlots[st] or {}
    if equip then
        for _, slots in pairs(cch.vehicleSlots) do
            for i, e in pairs(slots) do
                if e and tonumber(e.insID) == insID then slots[i] = nil end
            end
        end
        cch.vehicleSlots[st][slotIndex] = { resID = resID, insID = insID }
        PERSIST.configVehicleSlots = PERSIST.configVehicleSlots or {}
        PERSIST.configVehicleSlots[st] = PERSIST.configVehicleSlots[st] or {}
        PERSIST.configVehicleSlots[st][slotIndex] = resID
    else
        local e = cch.vehicleSlots[st][slotIndex]
        if e and tonumber(e.insID) == insID then
            cch.vehicleSlots[st][slotIndex] = nil
            if PERSIST.configVehicleSlots and PERSIST.configVehicleSlots[st] then
                PERSIST.configVehicleSlots[st][slotIndex] = nil
            end
        end
    end
    F.syncVehicleSlotsToDataMgr()
    if equip and slotIndex == 1 then
        DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
        DataMgr.vehicleSkinInsIDTable[st] = insID
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    F.persistMarkDirty()
    F.notifyVehicleSlotUI()
    return true
end

function F.buildVstInBattleFromSlots()
    local vst = {}
    local function insToRes(insID)
        insID = tonumber(insID)
        if not insID or insID <= 0 then return nil end
        local res = R.insToRes[insID]
        if res and res > 0 then return res end
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            res = d and tonumber(d.resID)
        end)
        if res and res > 0 then return res end
        if insID >= 1000000 and F.cfg(insID) then return insID end
        return nil
    end
    local function fillFromSlots(subType, slots)
        subType = tonumber(subType)
        if not subType or type(slots) ~= "table" then return end
        local resList = {}
        for idx = 1, 8 do
            local val = slots[idx] or slots[tostring(idx)]
            local res = insToRes(val)
            if not res and type(val) == "table" then
                res = tonumber(val.resID or val.res_id)
            end
            if res and res > 0 then resList[#resList + 1] = res end
        end
        if #resList > 0 then vst[subType] = resList end
    end
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        fillFromSlots(subType, slots)
    end
    if not next(vst) then
        local cch = F.cache()
        for subType, slots in pairs(cch.vehicleSlots or {}) do
            local resList = {}
            for idx = 1, 8 do
                local e = slots[idx]
                local res = e and tonumber(e.resID)
                if res and res > 0 then resList[#resList + 1] = res end
            end
            if #resList > 0 then vst[tonumber(subType)] = resList end
        end
    end
    if not next(vst) then
        local bySub = {}
        for res, _ in pairs(R.resToIns) do
            res = tonumber(res)
            local c = F.cfg(res)
            local st = c and tonumber(F.subType(c))
            if res and st and st >= 900 then
                bySub[st] = bySub[st] or {}
                bySub[st][#bySub[st] + 1] = res
            end
        end
        for st, list in pairs(bySub) do
            table.sort(list)
            vst[st] = list
        end
    end
    return vst
end

function F.isVehicleSkinAllowed(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if F.isInjectedRes(skinId) then return true end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do
            if tonumber(res) == skinId then return true end
        end
    end
    if R.resToIns[skinId] then
        local c = F.cfg(skinId)
        local st = F.subType(c)
        if st and tonumber(st) >= 900 then return true end
    end
    return false
end

function F.isSkinInVehiclePCList(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    local pc = F.getPC()
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return false end
    local UAvatarUtils = import("AvatarUtils")
    local shape = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
    if shape and shape >= 0 then
        local entry = pc.VehicleAvatarSkinList:Get(shape)
        if entry and entry.SkinList then
            for _, id in pairs(entry.SkinList) do
                if tonumber(id) == skinId then return true end
            end
        end
    end
    return false
end

function F.shouldHandleVehicleSkinClick(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    return F.isVehicleSkinAllowed(resID) or F.isSkinInVehiclePCList(resID)
end

function F.getMatchVehicle()
    local found = nil
    pcall(function()
        local subs = SubsystemMgr:Get("VehicleControlUISubSystem")
        if subs and subs.GetVehicleUserComponent then
            local uuc = subs:GetVehicleUserComponent()
            if slua.isValid(uuc) and slua.isValid(uuc.Vehicle) then found = uuc.Vehicle end
        end
    end)
    if slua.isValid(found) then return found end
    local pc = F.getPC()
    if slua.isValid(pc) and pc.GetPlayerCharacterSafety then
        local char = pc:GetPlayerCharacterSafety()
        if slua.isValid(char) then
            if char.GetCurrentVehicle then
                local v = char:GetCurrentVehicle()
                if slua.isValid(v) then return v end
            end
            if char.CurrentVehicle and slua.isValid(char.CurrentVehicle) then
                return char.CurrentVehicle
            end
        end
    end
    return nil
end

function F.applyClientVehicleSkin(skinId, vehicle, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    vehicle = vehicle or F.getMatchVehicle()
    if not slua.isValid(vehicle) then return false end

    local UAvatarUtils = import("AvatarUtils")
    pcall(function()
        if slua.isValid(pc) then
            pc.ShowVehicleSkin = skinId
            local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
            if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
                pc.VehicleAvatarList:Add(shapeType, skinId)
            end
        end
    end)

    local applied = false
    local av = nil
    pcall(function()
        if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end
        if not slua.isValid(av) then av = vehicle.VehicleAvatarComponent_BP end
    end)

    if slua.isValid(av) then
        pcall(function() if av.bIsLobbyAvatar ~= nil then av.bIsLobbyAvatar = false end end)
        pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
        pcall(function()
            if slua.isValid(pc) and av.SetVehicleNetAvatarData then
                av:SetVehicleNetAvatarData(pc)
            end
        end)
        pcall(function()
            if av.ChangeItemAvatar then
                av:ChangeItemAvatar(skinId, false)
                applied = true
            elseif av.PreChangeVehicleAvatar then
                av:PreChangeVehicleAvatar(skinId)
                applied = true
            end
        end)
        pcall(function()
            if av.PostChangeItemAvatar then av:PostChangeItemAvatar(false) end
        end)
    end

    pcall(function()
        local battleCls = import("VehicleAvatarComponentBattleBase")
        local battleAv = vehicle:GetComponentByClass(battleCls)
        if slua.isValid(battleAv) then
            if battleAv.ChangeVehicleAvatar then
                battleAv:ChangeVehicleAvatar(skinId, false)
                applied = true
            end
            pcall(function()
                local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
                local uid = pc and pc.PlayerUID or 0
                local bTire = VehiclePlateLicenseUtil.NeedOpenHighTire(tonumber(uid), skinId)
                if battleAv.PreChangeHighTireLight then
                    battleAv:PreChangeHighTireLight(skinId, bTire)
                end
            end)
        end
    end)

    pcall(function()
        if vehicle.ChangeVehicleAvatar and slua.isValid(pc) then
            vehicle:ChangeVehicleAvatar(pc)
            applied = true
        end
    end)

    pcall(function() if vehicle.ForceNetUpdate then vehicle:ForceNetUpdate() end end)
    pcall(function() if slua.isValid(pc) and pc.ForceNetUpdate then pc:ForceNetUpdate() end end)
    return applied
end

function F.getVehicleSkinIds()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then
            seen[res] = true
            out[#out + 1] = res
        end
    end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do add(res) end
    end
    for res in pairs(R.resToIns) do
        local c = F.cfg(tonumber(res))
        local st = c and tonumber(F.subType(c))
        if st and st >= 900 then add(res) end
    end
    return out
end

function F.buildVehVst(skinIds)
    local bySub = {}
    for _, skinId in ipairs(skinIds or {}) do
        local subType = 961
        local ok, c = pcall(function() return CDataTable.GetTableData("Item", skinId) end)
        if ok and c and c.ItemSubType then subType = c.ItemSubType end
        bySub[subType] = bySub[subType] or {}
        bySub[subType][#bySub[subType] + 1] = skinId
    end
    return bySub
end

function F.directInjectVehicleSkinList(pc, skinIds)
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return end
    local UAvatarUtils = import("AvatarUtils")
    for _, skinId in ipairs(skinIds or {}) do
        local shapeType = nil
        pcall(function() shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId) end)
        if shapeType and shapeType >= 0 then
            pcall(function() pc.VehicleAvatarList:Add(shapeType, skinId) end)
            local entry = pc.VehicleAvatarSkinList:Get(shapeType)
            if entry and entry.SkinList then
                pcall(function() entry.SkinList:Add(skinId) end)
            end
        end
    end
end

function F.mergeVstIntoPlayerInfo(playerInfo)
    if not playerInfo then return end
    F.syncVehicleCacheFromDataMgr()
    local vst = F.buildVehVst(F.getVehicleSkinIds())
    if not next(vst) then return end
    playerInfo.vst_in_battle = playerInfo.vst_in_battle or {}
    for subType, list in pairs(vst) do
        playerInfo.vst_in_battle[subType] = list
    end
    local first
    for _, list in pairs(vst) do first = list[1]; break end
    if first and first > 0 then playerInfo.vst_skin = first end
end

function F.applyVehicleSkinsToPC(pc)
    -- [BẢO VỆ XE ĐỒNG ĐỘI] Từ chối ghi đè ID xe ảo vào bộ nhớ nhân vật nếu công tắc tắt!
    if not _G.LexusConfig.ModSkin then return false end
    
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end
    local skinIds = F.getVehicleSkinIds()
    if #skinIds == 0 then return false end
    local vst = F.buildVehVst(skinIds)
    local avatarList, avatarSkinList = {}, {}
    for _, skinList in pairs(vst) do
        local itemArray = {}
        for _, resid in ipairs(skinList) do
            if resid and resid > 0 then
                itemArray[#itemArray + 1] = { ItemTableID = resid, Count = 1 }
                avatarList[#avatarList + 1] = { ItemTableID = resid, Count = 1 }
            end
        end
        if #itemArray > 0 then
            avatarSkinList[#avatarSkinList + 1] = { Items = itemArray }
        end
    end
    pcall(function() pc.bEnableFuzzyAvatarOnClient = false end)
    pcall(function() pc.ShowVehicleSkin = skinIds[1] end)
    if #avatarList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarList = avatarList
            pc:InitVehicleAvatarList()
        end)
    end
    if #avatarSkinList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarSkinList = avatarSkinList
            pc:InitVehicleAvatarSkinList()
        end)
    end
    F.directInjectVehicleSkinList(pc, skinIds)
    return true
end

function F.serverChangeVehicleAvatar(skinId, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end

    F.applyVehicleSkinsToPC(pc)

    pcall(function()
        pc.ShowVehicleSkin = skinId
        local UAvatarUtils = import("AvatarUtils")
        local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
        if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
            pc.VehicleAvatarList:Add(shapeType, skinId)
        end
        F.directInjectVehicleSkinList(pc, { skinId })
    end)

    local ok = false
    pcall(function()
        if pc.ServerChangeVehicleAvatar then
            pc:ServerChangeVehicleAvatar(skinId)
            ok = true
        end
    end)

    pcall(function()
        if pc.PlayerState and slua.isValid(pc.PlayerState) then
            pc.PlayerState.nVst_skin = skinId
        end
    end)

    pcall(function() pc:ForceNetUpdate() end)
    return ok
end

_G.AddOutfitVehSel = _G.AddOutfitVehSel or { override = nil, overrideVehicle = nil, byShape = {} }
local VEHSEL = _G.AddOutfitVehSel
_G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or { manual = false, subType = nil, resID = nil, insID = nil }
local _vehTickLastApply = 0
local VEH_SWITCH_EFFECT_ID = 7303001

function F.prepVehicleSwitchEffect(av, vehicle)
    if not slua.isValid(av) then return end
    if not F.isInRealMatch() then
        pcall(function() av.curSwitchEffectId = 0 end)
        return
    end
    pcall(function()
        av.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
        local defaultId = 0
        pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
        local curId = 0
        if slua.isValid(vehicle) then
            pcall(function() curId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
            if curId <= 0 then
                pcall(function() curId = tonumber(vehicle.ClientUsedAvatarID) or 0 end)
            end
        end
        if curId <= 0 then curId = defaultId end
        if not av.lastEquipedAvatarId or av.lastEquipedAvatarId <= 0 then
            av.lastEquipedAvatarId = curId > 0 and curId or defaultId
        end
    end)
end

function F.isParachuteRes(resID)
    return F.subType(F.cfg(tonumber(resID))) == PARACHUTE_SUB
end

function F.isGlideRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    if GLIDER_SUBS[st] then return true end
    local ok, r = pcall(function()
        local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
        if MDH.IsGlideByItemID and MDH.IsGlideByItemID(resID) then return true end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        return wd.IsGlideType(st)
    end)
    return ok and r == true
end

function F.isVehicleRes(resID)
    resID = tonumber(resID)
    if not resID or F.isChassisLightId(resID) then return false end
    local st = tonumber(F.subType(F.cfg(resID)))
    return st and st >= 900 and st < 7000 and st ~= CHASSIS_LIGHT_SUB
end

function F.ensureInjectedItemAlive(entity, resID, insID)
    entity = entity or F.getEntity()
    insID = tonumber(insID) or (resID and R.resToIns[tonumber(resID)])
    resID = tonumber(resID) or (insID and R.insToRes[insID])
    if not entity or not insID then return end
    pcall(function()
        local d = entity:GetDataByInsID(insID)
        if d then
            d.expire_ts = 0
            d.expireTS = 0
            d.valid_hours = 0
        end
    end)
end

function F.sanitizeAllInjectedExpire()
    local entity = F.getEntity()
    if not entity then return end
    for res, ins in pairs(R.resToIns) do
        F.ensureInjectedItemAlive(entity, res, ins)
    end
end

function F.putOnVehicle(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local resID = R.insToRes[insID]
    if not resID or not F.isVehicleRes(resID) then return false end
    F.ensureInjectedItemAlive(nil, resID, insID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    local item = {
        res_id = resID, resID = resID,
        instid = insID, ins_id = insID, insID = insID,
        expire_ts = 0, expireTS = 0, count = 1,
    }
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    F.setLobbyVehicleManual(F.vehicleSubType(resID), resID, insID)
    pcall(function()
        local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
        TabSurveillance.VehicleChange()
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
        end
    end)
    return true
end

function F.isChassisLightId(id)
    return CHASSIS_LIGHT_IDS[tonumber(id)] == true
end

function F.getDesiredChassisLight(vehicleSkinId)
    vehicleSkinId = tonumber(vehicleSkinId)
    local map = PERSIST.configChassisLightMap
    if vehicleSkinId and map and map[vehicleSkinId] then
        local v = tonumber(map[vehicleSkinId])
        if F.isChassisLightId(v) then return v end
    end
    local def = tonumber(PERSIST.configChassisLight) or DEFAULT_CHASSIS_LIGHT
    return F.isChassisLightId(def) and def or DEFAULT_CHASSIS_LIGHT
end

function F.saveChassisLight(vehicleSkinId, lightId)
    vehicleSkinId = tonumber(vehicleSkinId)
    lightId = tonumber(lightId)
    if not F.isChassisLightId(lightId) then return end
    PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
    if vehicleSkinId and vehicleSkinId > 0 then
        PERSIST.configChassisLightMap[vehicleSkinId] = lightId
    else
        PERSIST.configChassisLight = lightId
    end
    F.requestResourceDownload(lightId)
    F.persistMarkDirty()
end

function F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local lic = nil
    pcall(function()
        if vehicle.GetLicenseComponent then lic = vehicle:GetLicenseComponent() end
    end)
    if slua.isValid(lic) then return lic end
    pcall(function() lic = vehicle.BP_Lobby_VehicleLicenseComponent end)
    if slua.isValid(lic) then return lic end
    pcall(function()
        local cls = import("VehicleLicenseNumberComponent")
        lic = vehicle:GetComponentByClass(cls)
    end)
    return slua.isValid(lic) and lic or nil
end

function F.applyVehicleChassisLight(vehicle, skinId, lightId)
    -- [FIX VIP] Nếu tắt Mod Skin thì bỏ qua không load đèn gầm
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end 
    
    skinId = tonumber(skinId)
    lightId = tonumber(lightId) or F.getDesiredChassisLight(skinId)
    if not F.isChassisLightId(lightId) then return false end
    if not slua.isValid(vehicle) then return false end
    if skinId and skinId > 0 then
        F.requestResourceDownload(skinId)
    end
    F.requestResourceDownload(lightId)
    local applied = false
    pcall(function()
        if vehicle.SetChassisLightShowData then
            vehicle:SetChassisLightShowData(lightId)
            applied = true
        end
    end)
    local lic = F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(lic) then return applied end
    pcall(function()
        local vid = skinId
        if not vid or vid <= 0 then
            pcall(function()
                if vehicle.GetAvatarId then vid = tonumber(vehicle:GetAvatarId()) end
            end)
        end
        if not vid or vid <= 0 then
            pcall(function() vid = tonumber(lic.LicensePlate and lic.LicensePlate.ItemID) end)
        end
        if vid and vid > 0 then
            lic.curVehicleAvatarId = vid
            if lic.ChangeNetData_ItemID then
                lic:ChangeNetData_ItemID(vid)
            elseif lic.LicensePlate then
                lic.LicensePlate.ItemID = vid
            end
        end
        if lic.LicensePlate then
            lic.LicensePlate.ChassisLightId = lightId
        end
        if lic.SetChassisLightData and vid and vid > 0 then
            lic:SetChassisLightData(vid, lightId)
        elseif lic.PreChangeChassisLight then
            lic:PreChangeChassisLight()
        end
        applied = true
    end)
    return applied
end

function F.scheduleChassisLightApply(vehicle, skinId)
    skinId = tonumber(skinId)
    local vref = slua.isValid(vehicle) and vehicle or nil
    local function try()
        local v = slua.isValid(vref) and vref or F.getCurrentVehicleForSkin()
        if slua.isValid(v) then
            F.applyVehicleChassisLight(v, skinId)
        end
    end
    F.later(0.4, try)
    F.later(1.1, try)
end

function F.getVehicleShape(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local shape = vehicle.VehicleShapeType
    if shape and tonumber(shape) >= 0 then return tonumber(shape) end
    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local defId = vehicle.AvatarDefaultCfg and vehicle.AvatarDefaultCfg.TypeSpecificID
        if defId and tonumber(defId) > 0 then
            shape = UAvatarUtils.GetVehicleShapeBySkinID(tonumber(defId))
        end
    end)
    return shape and tonumber(shape) >= 0 and tonumber(shape) or nil
end

function F.getDesiredVehicleSkinForShape(shape)
    shape = tonumber(shape)
    if not shape or shape < 0 then return nil end
    F.syncVehicleCacheFromDataMgr()
    local UAvatarUtils = import("AvatarUtils")
    local vst = F.buildVstInBattleFromSlots()
    for _, list in pairs(vst) do
        local skin = list and tonumber(list[1])
        if skin and skin > 0 then
            local s = UAvatarUtils.GetVehicleShapeBySkinID(skin)
            if s == shape then return skin end
        end
    end
    local pc = F.getPC()
    if slua.isValid(pc) and pc.VehicleAvatarList then
        local skin = tonumber(pc.VehicleAvatarList:Get(shape))
        if skin and skin > 0 then return skin end
    end
    return nil
end

function F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local av = nil
    pcall(function() av = vehicle.VehicleAvatar end)
    if slua.isValid(av) then return av end
    pcall(function() if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end end)
    if slua.isValid(av) then return av end
    pcall(function() av = vehicle.VehicleAvatarComponent_BP end)
    if slua.isValid(av) then return av end
    return nil
end

function F.getCurrentVehicleForSkin()
    local char = F.getLocalChar()
    if char and slua.isValid(char) then
        local v = nil
        pcall(function() v = char.CurrentVehicle end)
        if slua.isValid(v) then return v end
    end
    return F.getMatchVehicle()
end

function F.forceVehicleAvatar(skinId, vehicle)
    -- [CHỐT CHẶN 100%] Từ chối mọi lệnh load Skin Xe nếu công tắc tắt
    if not _G.LexusConfig.ModSkin then return false end
    
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if not F.isResourcesReady(skinId) then
        F.requestResourceDownload(skinId)
        return false
    end
    vehicle = slua.isValid(vehicle) and vehicle or F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return false end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return false end
    local applied = false
    F.prepVehicleSwitchEffect(av, vehicle)
    pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
    pcall(function()
        av:ChangeItemAvatar(skinId, true)
        applied = true
        _G.CurrentEquipVehicleID = skinId
    end)
    if applied then F.scheduleChassisLightApply(vehicle, skinId) end
    return applied
end

function F.vehicleAvatarTemper()
    local vehicle = F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return end

    local defaultId = 0
    pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
    if defaultId <= 0 then return end

    local shape = nil
    pcall(function() shape = tonumber(import("AvatarUtils").GetVehicleShapeBySkinID(defaultId)) end)

    local skinId = nil
    if VEHSEL.override and slua.isValid(VEHSEL.overrideVehicle) and VEHSEL.overrideVehicle == vehicle then
        skinId = VEHSEL.override
    end
    if not skinId and shape then skinId = VEHSEL.byShape[shape] end
    if not skinId then skinId = F.getDesiredVehicleSkinForShape(shape) end
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 or skinId == defaultId then return end

    local cur = 0
    pcall(function() cur = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
    if cur <= 0 then
        pcall(function() cur = tonumber(vehicle.GetVehicleSkinItemID and vehicle:GetVehicleSkinItemID()) or 0 end)
    end
    if cur == skinId then return end

    F.forceVehicleAvatar(skinId, vehicle)
end

function F.vehicleSkinTick()
    -- [FIX VIP] Nếu đã tắt Mod Skin thì chặn luôn vòng lặp ép xe và mặt nạ
    if not _G.LexusConfig.ModSkin then return end

    F.vehicleAvatarTemper()
    
    -- [FIX VIP] Ép hiển thị Kính & Mặt Nạ liên tục mỗi 1 giây (Bất chấp việc nhặt mũ bảo hiểm)
    pcall(function()
        local char = F.getLocalChar()
        if char then F.matchApplyFaceWear(char) end
    end)

    local now = os.clock()
    if now - _vehTickLastApply < 5.0 then return end
    _vehTickLastApply = now
    F.applyVehicleSkinsToPC()
end

function F.startVehicleSkinTicker()
    pcall(function()
        if not _ticker then return end
        if _G.AddOutfitVehTickerId then return end
        if _ticker.AddTimerLoop then
            _G.AddOutfitVehTickerId = _ticker.AddTimerLoop(1.0, function()
                local fn = _G.AddOutfit and _G.AddOutfit.vehicleSkinTick
                if fn then pcall(fn) end
            end, -1, 1.0)
        end
    end)
end

function F.matchApplyVehicleSkin(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end

    local vehicle = F.getCurrentVehicleForSkin()

    VEHSEL.override = skinId
    VEHSEL.overrideVehicle = slua.isValid(vehicle) and vehicle or nil

    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local shape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(skinId))
        if shape and shape >= 0 then VEHSEL.byShape[shape] = skinId end
        local av = F.getVehicleAvatarComp(vehicle)
        if slua.isValid(av) then
            local defaultId = tonumber(av:GetDefaultAvatarID()) or 0
            if defaultId > 0 then
                local defShape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(defaultId))
                if defShape and defShape >= 0 then VEHSEL.byShape[defShape] = skinId end
            end
        end
    end)

    F.applyVehicleSkinsToPC(F.getPC())
    local ok = F.forceVehicleAvatar(skinId, vehicle)
    F.startVehicleSkinTicker()
    return ok
end

function F.autoApplyVehicleSkinOnEnter(vehicle)
    -- [FIX VIP] Chặn không cho tự đổi skin khi bấm nút "Lái xe / Lên xe"
    if not _G.LexusConfig.ModSkin then return end
    
    if not slua.isValid(vehicle) then return end
    F.syncVehicleCacheFromDataMgr()
    F.applyVehicleSkinsToPC(F.getPC())
    F.startVehicleSkinTicker()
    F.later(0.35, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.9, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.5, function()
        local skinId = nil
        pcall(function() skinId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) end)
        F.scheduleChassisLightApply(vehicle, skinId)
    end)
end

local function GetOutfitConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
            end
        end
    end)
    return paths
end

local CONFIG_PATHS = GetOutfitConfigPaths("RLFLYv13_outfit.json")

local PERSIST_SLOTS = {
    { "outfit", "outfitRes", "outfitIns", "AddOutfitLastLobbyOutfitRes" },
    { "tshirt", "tshirtRes", "tshirtIns", "AddOutfitLastLobbyTshirtRes" },
    { "pants",  "pantsRes",  "pantsIns",  "AddOutfitLastLobbyPantsRes"  },
    { "shoes",  "shoesRes",  "shoesIns",  "AddOutfitLastLobbyShoesRes"  },
    { "hat",    "hatRes",    "hatIns",    "AddOutfitLastLobbyHatRes"    },
    { "mask",   "maskRes",   "maskIns",   "AddOutfitLastLobbyMaskRes"   },
    { "glass",  "glassRes",  "glassIns",  "AddOutfitLastLobbyGlassRes"  },
    { "bag",    "bagRes",    "bagIns",    "AddOutfitLastLobbyBagRes"    },
    { "helmet", "helmetRes", "helmetIns", "AddOutfitLastLobbyHelmetRes" },
    { "parachute", "parachuteRes", "parachuteIns", "AddOutfitLastLobbyParachuteRes" },
    { "glider", "gliderRes", "gliderIns", "AddOutfitLastLobbyGliderRes" },
    { "gloves", "glovesRes", "glovesIns", "AddOutfitLastLobbyGlovesRes" },
}

function F.isPersistableWearRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if F.isInjectedRes(resID) then return true end
    if F.isParachuteRes(resID) or F.isGlideRes(resID) then return true end
    if PERSIST.configSlots then
        for _, v in pairs(PERSIST.configSlots) do
            if tonumber(v) == resID then return true end
        end
    end
    return false
end

function F.persistRememberSlot(slotName, resID)
    slotName = slotName and tostring(slotName)
    resID = tonumber(resID)
    if not slotName or not resID or resID <= 0 then return end
    PERSIST.configSlots = PERSIST.configSlots or {}
    PERSIST.configSlots[slotName] = resID
end

function F.persistForgetSlot(slotName)
    if PERSIST.configSlots and slotName then
        PERSIST.configSlots[tostring(slotName)] = nil
    end
end

function F.persistLoadSlotsFromSaved(saved)
    if type(saved) ~= "table" then return end
    PERSIST.configSlots = PERSIST.configSlots or {}
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]])
        if res and res > 0 then PERSIST.configSlots[s[1]] = res end
    end
    F.applyPersistSlotsToCache()
end

function F.resolveInsForRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end
    if R.resToIns[resID] then return R.resToIns[resID] end
    local ins
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local list = wd.GetHallDepotItemListByResID and wd:GetHallDepotItemListByResID(resID)
        if list then
            for _, v in pairs(list) do
                local id = tonumber(v.insID or v.instid or v.ins_id)
                if id and id > 0 then ins = id break end
            end
        end
        if not ins then
            local d = wd.GetValidHallDepotItemDataByInsID and wd:GetValidHallDepotItemDataByInsID(resID)
            if not d and wd.GetHallDepotItemDataByResID then
                d = wd:GetHallDepotItemDataByResID(resID)
            end
            if d then ins = tonumber(d.insID or d.instid or d.ins_id) end
        end
    end)
    return ins
end

function F.applyPersistSlotsToCache()
    if not PERSIST.configSlots then return end
    local cch = F.cache()
    for _, s in ipairs(PERSIST_SLOTS) do
        local slotName, cacheResKey, cacheInsKey, globalKey = s[1], s[2], s[3], s[4]
        local res = tonumber(PERSIST.configSlots[slotName])
        if res and res > 0 then
            cch[cacheResKey] = res
            _G[globalKey] = res
            local ins = F.resolveInsForRes(res)
            if ins and ins > 0 then cch[cacheInsKey] = ins end
        end
    end
end

function F.getDesiredGliderRes()
    F.applyPersistSlotsToCache()
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("gliderRes", "gliderRes", "AddOutfitLastLobbyGliderRes")
end

function F.getDesiredParachuteRes()
    F.applyPersistSlotsToCache()
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("parachuteRes", "parachuteRes", "AddOutfitLastLobbyParachuteRes")
end

function F.getAvatarComp2(char)
    if not char or not slua.isValid(char) then return nil end
    local comp
    pcall(function()
        if char.getAvatarComponent2 then
            comp = char:getAvatarComponent2()
        end
        if (not comp or not slua.isValid(comp)) and char.AvatarComponent2 then
            comp = char.AvatarComponent2
        end
        if (not comp or not slua.isValid(comp)) and char.CharacterAvatarComp2_BP then
            comp = char.CharacterAvatarComp2_BP
        end
    end)
    return comp
end

function F.isCharacterAirborne(char)
    if not char or not slua.isValid(char) then return false end
    local ok, r = pcall(function()
        local EParachuteState = import("EParachuteState")
        local st = char.ParachuteState
        return st and st ~= EParachuteState.PS_None
    end)
    return ok and r == true
end

function F.reapplyWeaponsFromConfig()
    local wmap = F.sanitizeConfigWeapons(PERSIST.configWeapons)
    local dropped = false
    for k in pairs(PERSIST.configWeapons or {}) do
        if not wmap[tonumber(k) or k] then dropped = true break end
    end
    PERSIST.configWeapons = wmap
    if dropped then F.persistMarkDirty() end
    if not next(wmap) then return false end
    local cch = F.cache()
    local any = false
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        local ins = res and R.resToIns[res]
        if wid and ins and F.isInjectedIns(ins) then
            cch.weapons[wid] = { resID = res, insID = ins }
            if F.equipWeaponSkin(wid, ins) then
                any = true
            else
                F.syncWeaponArmorySilent(wid, ins)
            end
        end
    end
    return any
end

function F.persistEncode()
    local cch = F.cache()
    local parts = {}
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
            or tonumber(cch[s[2]])
        if res and res > 0 and F.isPersistableWearRes(res) then
            parts[#parts + 1] = string.format('  "%s": %d', s[1], res)
        end
    end
    local wparts = {}
    local wmap = {}
    for wid, res in pairs(F.sanitizeConfigWeapons(PERSIST.configWeapons)) do
        wmap[wid] = res
    end
    for wid, w in pairs(cch.weapons or {}) do
        local res = w and tonumber(w.resID)
        wid = tonumber(wid)
        if F.isValidWeaponPersistEntry(wid, res) then wmap[wid] = res end
    end
    for wid, res in pairs(wmap) do
        wparts[#wparts + 1] = string.format('    "%d": %d', wid, res)
    end
    table.sort(wparts)
    parts[#parts + 1] = '  "weapons": {\n' .. table.concat(wparts, ",\n") .. "\n  }"
    local vparts = {}
    local function appendVehicleSlots(src)
        for subType, slots in pairs(src or {}) do
            local sparts = {}
            if type(slots) == "table" then
                for idx, val in pairs(slots) do
                    local res = type(val) == "table" and tonumber(val.resID) or tonumber(val)
                    if res and res > 0 then
                        sparts[#sparts + 1] = string.format('      "%d": %d', tonumber(idx), res)
                    end
                end
            end
            table.sort(sparts)
            if #sparts > 0 then
                vparts[#vparts + 1] = string.format('    "%d": {\n%s\n    }', tonumber(subType), table.concat(sparts, ",\n"))
            end
        end
    end
    local hasCacheSlots = false
    for _ in pairs(cch.vehicleSlots or {}) do hasCacheSlots = true; break end
    if hasCacheSlots then
        appendVehicleSlots(cch.vehicleSlots)
    elseif PERSIST.configVehicleSlots then
        appendVehicleSlots(PERSIST.configVehicleSlots)
    end
    local mparts = {}
    if DataMgr and DataMgr.MotionSlotList then
        for i, ins in ipairs(DataMgr.MotionSlotList) do
            ins = tonumber(ins)
            if ins and ins > 0 and F.isInjectedIns(ins) then
                local res = R.insToRes[ins]
                if res then mparts[#mparts+1] = string.format('      "%d": %d', i, res) end
            end
        end
    end
    if #mparts > 0 then
        parts[#parts + 1] = '  "motions": {\n' .. table.concat(mparts, ",\n") .. "\n  }"
    end
    if PERSIST.lobbyVehicleSubType and PERSIST.lobbyVehicleSubType > 0
        and PERSIST.lobbyVehicleSubType ~= CHASSIS_LIGHT_SUB
        and not F.isChassisLightId(PERSIST.lobbyVehicleResID)
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleSubType": %d', PERSIST.lobbyVehicleSubType)
    end
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleResID": %d', PERSIST.lobbyVehicleResID)
    end
    if PERSIST.lobbyVehicleIns and PERSIST.lobbyVehicleIns > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID or R.insToRes[PERSIST.lobbyVehicleIns]) then
        parts[#parts + 1] = string.format('  "lobbyVehicleIns": %d', PERSIST.lobbyVehicleIns)
    end
    local hres = tonumber(cch.hallThemeRes) or tonumber(PERSIST.hallThemeResID)
    if hres and hres > 0 and F.isInjectedRes(hres) then
        parts[#parts + 1] = string.format('  "hallTheme": %d', hres)
    end
    local cl = tonumber(PERSIST.configChassisLight)
    if F.isChassisLightId(cl) then
        parts[#parts + 1] = string.format('  "chassisLight": %d', cl)
    end
    local cmap = PERSIST.configChassisLightMap
    if cmap and next(cmap) then
        local cparts = {}
        for vid, lid in pairs(cmap) do
            vid, lid = tonumber(vid), tonumber(lid)
            if vid and vid > 0 and F.isChassisLightId(lid) then
                cparts[#cparts + 1] = string.format('    "%d": %d', vid, lid)
            end
        end
        table.sort(cparts)
        if #cparts > 0 then
            parts[#parts + 1] = '  "chassisLightMap": {\n' .. table.concat(cparts, ",\n") .. "\n  }"
        end
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n}\n"
end

function F.persistWrite(txt)
    if not (io and io.open) then return false end
    if PERSIST.path then
        local f
        pcall(function() f = io.open(PERSIST.path, "w") end)
        if f then f:write(txt) f:close() return true end
        PERSIST.path = nil
    end
    for _, p in ipairs(CONFIG_PATHS) do
        local f
        pcall(function() f = io.open(p, "w") end)
        if not f then
            pcall(function()
                local dir = p:match("^(.*)/[^/]+$")
                if dir and os and os.execute then os.execute('mkdir -p "' .. dir .. '"') end
            end)
            pcall(function() f = io.open(p, "w") end)
        end
        if f then
            f:write(txt) f:close()
            PERSIST.path = p
            return true
        end
    end
    return false
end

function F.persistFlush()
    if not PERSIST.dirty then return end
    PERSIST.dirty = false
    pcall(function()
        local txt = F.persistEncode()
        if txt == PERSIST.lastWritten then return end
        if F.persistWrite(txt) then
            PERSIST.lastWritten = txt
        end
    end)
end

F.persistMarkDirty = function()
    PERSIST.dirty = true
    if PERSIST.scheduled then return end
    PERSIST.scheduled = true
    F.later(2.0, function()
        PERSIST.scheduled = false
        F.persistFlush()
    end)
end

function F.persistParse(txt)
    if not txt or #txt == 0 then return nil end
    local out = { weapons = {}, vehicleSlots = {} }
    local parsed = false
    pcall(function()
        local t = json and json.decode and json.decode(txt)
        if type(t) == "table" then
            for k, v in pairs(t) do
                if k == "weapons" and type(v) == "table" then
                    for wk, wv in pairs(v) do
                        local wid, res = tonumber(wk), tonumber(wv)
                        if F.isValidWeaponPersistEntry(wid, res) then out.weapons[wid] = res end
                    end
                elseif k == "vehicleSlots" and type(v) == "table" then
                    for stk, slotMap in pairs(v) do
                        local st = tonumber(stk)
                        if st then
                            out.vehicleSlots[st] = out.vehicleSlots[st] or {}
                            for idxStr, res in pairs(slotMap) do
                                local idx, r = tonumber(idxStr), tonumber(res)
                                if idx and r and r > 0 then out.vehicleSlots[st][idx] = r end
                            end
                        end
                    end
                elseif k == "motions" and type(v) == "table" then
                    out.motions = {}
                    for mk, mv in pairs(v) do
                        local slot = tonumber(mk)
                        local res = tonumber(mv)
                        if slot and res and res > 0 then out.motions[slot] = res end
                    end
                else
                    local n = tonumber(v)
                    if n and n > 0 then out[k] = n end
                end
            end
            parsed = true
        end
    end)
    if not parsed then
        for k, v in txt:gmatch('"([%w_]+)"%s*:%s*(%d+)') do
            local n = tonumber(v)
            if n and n > 0 then
                local wid = tonumber(k)
                if wid and F.isValidWeaponPersistEntry(wid, n) then
                    out.weapons[wid] = n
                elseif not wid then
                    out[k] = n
                end
            end
        end
    end
    return out
end

function F.persistLoadFromDisk()
    if not (io and io.open) then return end
    pcall(function()
        for _, p in ipairs(CONFIG_PATHS) do
            local f
            pcall(function() f = io.open(p, "r") end)
            if f then
                local txt = f:read("*a")
                f:close()
                PERSIST.path = p
                PERSIST.lastWritten = txt
                PERSIST.loaded = F.persistParse(txt)
                F.persistLoadSlotsFromSaved(PERSIST.loaded)
                if PERSIST.loaded and PERSIST.loaded.vehicleSlots then
                    PERSIST.configVehicleSlots = PERSIST.loaded.vehicleSlots
                end
                if PERSIST.loaded and PERSIST.loaded.weapons then
                    local raw = PERSIST.loaded.weapons
                    PERSIST.configWeapons = F.sanitizeConfigWeapons(raw)
                    if next(raw) and not next(PERSIST.configWeapons) then
                        F.persistMarkDirty()
                    elseif next(raw) then
                        for wid, res in pairs(raw) do
                            if not F.isValidWeaponPersistEntry(tonumber(wid), tonumber(res)) then
                                F.persistMarkDirty()
                                break
                            end
                        end
                    end
                end
                PERSIST.lobbyVehicleSubType = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleSubType)
                PERSIST.lobbyVehicleResID = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleResID)
                PERSIST.lobbyVehicleIns = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleIns)
                if PERSIST.lobbyVehicleSubType or PERSIST.lobbyVehicleIns or PERSIST.lobbyVehicleResID then
                    if F.isChassisLightId(PERSIST.lobbyVehicleResID)
                        or PERSIST.lobbyVehicleSubType == CHASSIS_LIGHT_SUB
                        or not F.isVehicleRes(PERSIST.lobbyVehicleResID) then
                        PERSIST.lobbyVehicleSubType = nil
                        PERSIST.lobbyVehicleResID = nil
                        PERSIST.lobbyVehicleIns = nil
                    else
                        _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
                        _G.AddOutfitLobbyVeh.manual = true
                        _G.AddOutfitLobbyVeh.subType = PERSIST.lobbyVehicleSubType
                        _G.AddOutfitLobbyVeh.resID = PERSIST.lobbyVehicleResID
                        _G.AddOutfitLobbyVeh.insID = PERSIST.lobbyVehicleIns
                    end
                end
                PERSIST.hallThemeResID = tonumber(PERSIST.loaded and PERSIST.loaded.hallTheme)
                PERSIST.hallThemeIns = nil
                if PERSIST.hallThemeResID then
                    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
                    _G.AddOutfitLobbyTheme.manual = true
                    _G.AddOutfitLobbyTheme.resID = PERSIST.hallThemeResID
                end
                PERSIST.configChassisLight = tonumber(PERSIST.loaded and PERSIST.loaded.chassisLight)
                if PERSIST.loaded and PERSIST.loaded.chassisLightMap then
                    PERSIST.configChassisLightMap = PERSIST.loaded.chassisLightMap
                end
                return
            end
        end
    end)
end

function F.persistApplyLoaded()
    local saved = PERSIST.loaded
    if not saved then return end
    PERSIST.loaded = nil
    local cch = F.cache()
    local any = false
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]]) or tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
        if res and res > 0 and not cch[s[2]] then
            local ins = R.resToIns[res]
            if ins then
                cch[s[2]], cch[s[3]] = res, ins
                _G[s[4]] = res
                any = true
            end
        end
    end
    PERSIST.configWeapons = F.sanitizeConfigWeapons(saved.weapons or PERSIST.configWeapons)
    if saved.weapons and F.reapplyWeaponsFromConfig() then
        any = true
    end
    if saved.vehicleSlots then
        PERSIST.configVehicleSlots = saved.vehicleSlots
        if F.reapplyVehicleSlotsFromConfig(true) then
            any = true
        end
    end
    if saved.hallTheme then
        PERSIST.hallThemeResID = tonumber(saved.hallTheme)
        if PERSIST.hallThemeResID and F.reapplyHallThemeFromConfig(true) then
            any = true
        end
    end
    if saved.chassisLight then
        PERSIST.configChassisLight = tonumber(saved.chassisLight)
    end
    if saved.chassisLightMap then
        PERSIST.configChassisLightMap = saved.chassisLightMap
    end
    
    if saved.motions then
        PERSIST.configMotions = saved.motions
        DataMgr.MotionSlotList = DataMgr.MotionSlotList or {}
        for slot, res in pairs(saved.motions) do
            local ins = R.resToIns[res]
            if ins then DataMgr.MotionSlotList[slot] = ins end
        end
        if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
            EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
        end
    end
    if any then
        _matchApplied = false
        F.perfInvalidateLobby()
    end
end

function F.getEntity()
    local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
    if not ok or not dc then return nil end
    local ok2, e = pcall(dc.GetWardrobeData)
    return ok2 and e or nil
end

function F.firstInsForRes(entity, resID)
    local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if not arr then return nil end
    for _, idx in pairs(arr) do
        local d = entity._data[idx]
        if d and d.count and d.count > 0 then return d.insID end
    end
    return nil
end

function F.injectOne(entity, resID, insID)
    local ownedIns = F.firstInsForRes(entity, resID)
    if ownedIns then
        F.ensureInjectedItemAlive(entity, resID, ownedIns)
        R.resToIns[resID] = ownedIns
        R.insToRes[ownedIns] = resID
        F.indexWeaponSkin(resID, ownedIns)
        return true
    end
    local row = {
        instid = insID,
        res_id = resID,
        count = 1,
        lock_cnt = 0,
        isnew = 0,
        valid_hours = 0,
        expire_ts = 0,
    }
    entity:AddData(row)
    pcall(function()
        if entity.LoadConfigForData and CDataTable and CDataTable.GetTableData then
            local idx = entity._DataCount
            if idx and entity._data[idx] then
                entity:LoadConfigForData(entity._data[idx], CDataTable.GetTableData)
            end
        end
    end)
    R.insToRes[insID] = resID
    R.resToIns[resID] = insID
    F.indexWeaponSkin(resID, insID)
    return true
end

function F.reviveExpiredOwned(entity)
    entity = entity or F.getEntity()
    if not entity or not entity.bInit or not entity._data then return end
    local now = 0
    pcall(function()
        local TimeUtil = require("client.common.time_util")
        now = tonumber(TimeUtil.GetServerTimeInSec()) or 0
    end)
    if now <= 0 then return end
    _G.AddOutfitRevived = _G.AddOutfitRevived or {}
    local n = 0
    for i = 1, (entity._DataCount or #entity._data) do
        local d = entity._data[i]
        if d then
            local exp = tonumber(d.expire_ts or d.expireTS) or 0
            local res = tonumber(d.res_id or d.resID)
            local ins = tonumber(d.instid or d.insID)
            if exp > 0 and exp <= now and res and ins and (tonumber(d.count) or 0) > 0 then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
                _G.AddOutfitRevived[res] = ins
                n = n + 1
            end
        end
    end
end

function F.mergeRevivedIntoMaps()
    for res, ins in pairs(_G.AddOutfitRevived or {}) do
        if not R.resToIns[res] then
            R.resToIns[res] = ins
            R.insToRes[ins] = res
            F.indexWeaponSkin(res, ins)
        end
    end
end

function F.injectArmory(resID, insID)
    local wid = F.weaponIdFromSkin(resID)
    if not wid then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
    Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
    Arm.WardrobeInsList = Arm.WardrobeInsList or {}
    Arm.WardrobeInsList[resID] = insID
end

function F.mergeInjectedArmorySkins()
    for _, skins in pairs(R.byWeapon) do
        for resID, insID in pairs(skins) do
            F.injectArmory(resID, insID)
        end
    end
end

function F.injectAll(entity)
     -- Bỏ qua nếu tắt Mod Skin
    entity = entity or F.getEntity()
    if not entity or not entity.bInit then return false end
    local n, nNew = 0, 0
    
    -- [FIX VIP] TỰ ĐỘNG TẠO THÊM ID MŨ/BALO CẤP 2 VÀ CẤP 3 ĐỂ CHỮA LỖI UI NỐT NHẠC
    local expandedItems = {}
    for _, resID in ipairs(ITEMS) do
        table.insert(expandedItems, resID)
        local resNum = tonumber(resID)
        if resNum then
            -- Nhận diện dải ID của Balo (1501...) và Mũ (1502..., 1505...)
            local isBag = (resNum >= 1501000000 and resNum <= 1501999999)
            local isHelmet = (resNum >= 1502000000 and resNum <= 1502999999) or (resNum >= 1505000000 and resNum <= 1505999999)
            
            if isBag or isHelmet then
                table.insert(expandedItems, resNum + 1000) -- Bơm thêm Cấp 2 vào tủ đồ
                table.insert(expandedItems, resNum + 2000) -- Bơm thêm Cấp 3 vào tủ đồ
            end
        end
    end

    -- Đọc danh sách đã được nhân bản
    for i, resID in ipairs(expandedItems) do
        local insID = INS_BASE + i
        local had = R.resToIns[resID] ~= nil
        if F.injectOne(entity, resID, insID) then
            n = n + 1
            if not had then nNew = nNew + 1 end
            local c = F.cfg(resID)
            if GUN_SUB[F.subType(c)] or F.subType(c) == MELEE_ID then
                F.injectArmory(resID, insID)
            end
        end
    end

    if not _G.AddOutfitUnexpireDone then
        _G.AddOutfitUnexpireDone = true
        pcall(F.reviveExpiredOwned, entity)
    end
    F.mergeRevivedIntoMaps()
    F.sanitizeAllInjectedExpire()
    F.ensureInjectedResources()
    return n > 0
end

function F.refreshWardrobe()
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_GUN_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
            end
        end
    end)
end

function F.refreshWardrobeOnce()
    if LOBBY.wardrobeRefreshed then return end
    LOBBY.wardrobeRefreshed = true
    F.refreshWardrobe()
end

function F.scheduleInjectRefresh()
    LOBBY.injectRefreshGen = (LOBBY.injectRefreshGen or 0) + 1
    local gen = LOBBY.injectRefreshGen
    F.later(0.4, function()
        if gen ~= LOBBY.injectRefreshGen then return end
        F.refreshWardrobe()
    end)
end

function F.putOnOutfit(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    if not F.isSuitRes(resID) then
        if F.isTshirtRes(resID) then return F.putOnRoleWear(insID) end
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local suitFilter = function(r) return F.isSuitRes(r) end
    local oldIns, oldRes = F.findWornInsBySubType(OUTFIT_SUB, suitFilter)
    F.removeRoleWearBySubType(OUTFIT_SUB, suitFilter)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(OUTFIT_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        av:AddToWearInfo(OUTFIT_SUB, insID, resID, 0, 0)
        F.syncFashionBagRolewear()
    end)
end

function F.putOnHat(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or HAT_SUB

    local oldIns, oldRes = F.findWornInsBySubType(st)
    if not oldIns and st ~= HAT_SUB then
        oldIns, oldRes = F.findWornInsBySubType(HAT_SUB)
    end
    F.removeRoleWearBySubType(st)
    if st ~= HAT_SUB then F.removeRoleWearBySubType(HAT_SUB) end
    F.saveEquip(resID, insID)

    local slot = 1
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SetHeadShow(insID)
        F.syncFashionBagRolewear()
    end)
    F.invalidateSocialWearCache()
end

function F.putOnFaceAccessory(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not FACE_SUBS[st] then return end

    local oldIns, oldRes = F.findWornInsBySubType(st)
    F.removeRoleWearBySubType(st)
    F.saveEquip(resID, insID)

    local slot = (st == MASK_SUB) and 2 or 6
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
end

function F.canRoleWear(resID, st)
    st = st or F.subType(F.cfg(resID))
    if FACE_SUBS[st] or BODY_SUBS[st] then return true end
    if st == GLOVES_SUB then return true end
    if st == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES then return true end
    return false
end

F.putOnRoleWear = function(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not F.canRoleWear(resID, st) then return end

    local filterFn
    if st == OUTFIT_SUB then
        filterFn = function(r) return F.wardrobeTab(r) == TAB_CLOTHES end
    end
    local oldIns, oldRes = F.findWornInsBySubType(st, filterFn)
    F.removeRoleWearBySubType(st, filterFn)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            DataMgr.equipmentSkinInsIDTable = DataMgr.equipmentSkinInsIDTable or {}
            DataMgr.equipmentSkinInsIDTable[st] = insID
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if st == 504 or st == 501 then
                    DataMgr.equipmentSkinInsIDTable[504] = insID
                    bag.bag_skin = insID
                    -- [FIX VIP] Ép hiển thị Balo 3D ngoài sảnh
                    local HT = require("client.logic.lobby.hall_theme_utils")
                    if HT and HT.PutOnBag then HT.PutOnBag(fbd:GetFashionBagUseIndex()) end
                elseif st == 505 or st == 502 then
                    DataMgr.equipmentSkinInsIDTable[505] = insID
                    bag.helmet_skin = insID
                    -- [FIX VIP] Ép hiển thị Mũ 3D ngoài sảnh
                    fbd:SetHeadShow(insID)
                    local WRH = require("client.network.Protocol.WardRobeHandler")
                    if WRH and WRH.send_depot_set_head_show_req then 
                        WRH.send_depot_set_head_show_req(insID) 
                    end
                end
            end
            
            -- [FIX VIP] Ép Load Mô hình 3D lên nhân vật
            local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
            if lav and lav.AvatarChange then
                lav:AvatarChange(resID, true, 0, 0)
            end
        end)
    end

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
end

function F.putOnGloves(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local oldIns, oldRes = F.findWornInsBySubType(GLOVES_SUB)
    F.removeRoleWearBySubType(GLOVES_SUB)
    F.saveEquip(resID, insID)

    local slot = 8
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(GLOVES_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern, expire_ts = 0 }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local logic_wardrobe_avatar = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        logic_wardrobe_avatar:AddToWearInfo(GLOVES_SUB, insID, resID, d.color or 0, d.pattern or 0)
        DataMgr.UpdateRoleWearData(insID, oldIns or 0)
        logic_wardrobe_avatar:AvatarChange(resID, true, d.color, d.pattern)
    end)
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl.SetClickItemInsId then wl:SetClickItemInsId(insID) end
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
        end
    end)
    F.invalidateSocialWearCache()
end

function F.ensureDepotItemValid(insID, resID)
    insID = tonumber(insID)
    if not insID then return end
    pcall(function()
        local entity = F.getEntity()
        if entity and entity.GetDataByInsID then
            local d = entity:GetDataByInsID(insID)
            if d then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
            end
        end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local hd = wd:GetHallDepotItemDataByInsID(insID)
        if hd then
            hd.expire_ts = 0
            if hd.expireTS ~= nil then hd.expireTS = 0 end
            if hd.valid_hours ~= nil then hd.valid_hours = 0 end
        end
    end)
end

function F.clearItemExpire(itemData, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if type(itemData) == "table" then
        itemData.expireTS = 0
        itemData.expire_ts = 0
        itemData.expireTs = 0
    end
end

function F.onGlideClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    local isGlide = resID and F.isGlideRes(resID)
    if not isGlide and itemData.itemSubType then
        isGlide = GLIDER_SUBS[tonumber(itemData.itemSubType)] == true
    end
    if insID and resID and isGlide then
        F.saveEquip(resID, insID)
        if F.putOnGlider(insID) then
            pcall(function()
                if self.ShowGlide then self:ShowGlide(resID) end
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitGlideClickOrig then
        F.clearItemExpire(itemData, insID, resID)
        return _G.AddOutfitGlideClickOrig(self, itemData)
    end
end

function F.onParachuteClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    if insID and resID and F.isParachuteRes(resID) then
        F.saveEquip(resID, insID)
        if F.putOnParachute(insID) then
            pcall(function()
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitParaClickOrig then
        return _G.AddOutfitParaClickOrig(self, itemData)
    end
end

function F.hookAirborneClick()
    pcall(function()
        local WG = require("client.slua.umg.Wardrobe.subtab_gliding")
        if WG then
            if not WG._AddOutfitGlideWrapped then
                WG._AddOutfitGlideWrapped = true
                _G.AddOutfitGlideClickOrig = WG.ClickItem
            end
            WG.ClickItem = function(self, itemData)
                return F.onGlideClick(self, itemData)
            end
        end
        local WP = require("client.slua.umg.Wardrobe.subtab_parachute")
        if WP then
            if not WP._AddOutfitParaWrapped then
                WP._AddOutfitParaWrapped = true
                _G.AddOutfitParaClickOrig = WP.ClickItem
            end
            WP.ClickItem = function(self, itemData)
                return F.onParachuteClick(self, itemData)
            end
        end
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd and not fbd._AddOutfitAirborneFBHooked then
            fbd._AddOutfitAirborneFBHooked = true
            local oG = fbd.UpdateAircraftOrGliding
            fbd.UpdateAircraftOrGliding = function(self, putOnID, bAircraft)
                local r = oG(self, putOnID, bAircraft)
                local ins = tonumber(putOnID)
                if ins and ins > 0 then
                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                    local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                    local res = d and tonumber(d.resID)
                    if res and F.isGlideRes(res) then F.saveEquip(res, ins) end
                end
                return r
            end
            local oP = fbd.UpdateParachute
            if oP then
                fbd.UpdateParachute = function(self, insID)
                    local r = oP(self, insID)
                    local ins = tonumber(insID)
                    if ins and ins > 0 then
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                        local res = d and tonumber(d.resID)
                        if res and F.isParachuteRes(res) then F.saveEquip(res, ins) end
                    end
                    return r
                end
            end
        end
    end)
    pcall(function()
        if not ModuleManager or not ModuleManager.GetModule then return end
        local FB = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.FashionBagEditUtils)
        if FB and not FB._AddOutfitFBBagHooked then
            FB._AddOutfitFBBagHooked = true
            local o = FB.PutOnFashionBagItem
            FB.PutOnFashionBagItem = function(self, itemData)
                if itemData then
                    F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
                end
                local r = o(self, itemData)
                if itemData then
                    local res = tonumber(itemData.res_id)
                    local ins = tonumber(itemData.ins_id)
                    if res and ins and (F.isGlideRes(res) or F.isParachuteRes(res)) then
                        F.saveEquip(res, ins)
                    end
                end
                return r
            end
        end
    end)
end

function F.putOnParachute(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or not F.isParachuteRes(resID) then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.SetParachute then fbd:SetParachute(insID) end
        if fbd.UpdateParachute then fbd:UpdateParachute(insID) end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.putOnGlider(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or resID <= 0 then return false end
    local st = F.depotSubType(insID, resID)
    if not F.isGlideRes(resID) and not GLIDER_SUBS[st] then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    local bAircraft = false
    pcall(function()
        local ModelDisplayTypeHelper = require("client.logic.avatar.ModelDisplayTypeHelper")
        local st = F.subType(F.cfg(resID))
        bAircraft = ModelDisplayTypeHelper.IsGlideSmoke(st)
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateAircraftOrGliding then
            fbd:UpdateAircraftOrGliding(insID, bAircraft)
        elseif fbd.SetGliding then
            fbd:SetGliding(insID)
            if DataMgr.UpdateEffect then DataMgr.UpdateEffect(insID) end
        end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.syncAirborneToDataMgr()
    F.applyPersistSlotsToCache()
    local cch = F.cache()
    local paraRes = F.getDesiredParachuteRes()
    local gliderRes = F.getDesiredGliderRes()
    if paraRes and paraRes > 0 and not cch.parachuteIns then
        cch.parachuteIns = F.resolveInsForRes(paraRes)
        cch.parachuteRes = paraRes
    end
    if gliderRes and gliderRes > 0 and not cch.gliderIns then
        cch.gliderIns = F.resolveInsForRes(gliderRes)
        cch.gliderRes = gliderRes
    end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if cch.parachuteIns and tonumber(cch.parachuteIns) > 0 then
            if fbd.SetParachute then fbd:SetParachute(cch.parachuteIns) end
            if DataMgr.roleData then DataMgr.roleData.parachute = tostring(cch.parachuteIns) end
        end
        if cch.gliderIns and tonumber(cch.gliderIns) > 0 then
            local bAircraft = false
            if cch.gliderRes then
                pcall(function()
                    local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
                    bAircraft = not MDH.IsGlideSmoke(F.subType(F.cfg(cch.gliderRes)))
                end)
            end
            if fbd.UpdateAircraftOrGliding then
                fbd:UpdateAircraftOrGliding(cch.gliderIns, bAircraft)
            elseif fbd.SetGliding then
                fbd:SetGliding(cch.gliderIns)
                if DataMgr.UpdateEffect then DataMgr.UpdateEffect(cch.gliderIns) end
            end
            if DataMgr.roleData then
                if bAircraft then
                    DataMgr.roleData.aircraft_put_id = tostring(cch.gliderIns)
                    DataMgr.gliding = cch.gliderIns
                else
                    DataMgr.roleData.gliding = tostring(cch.gliderIns)
                end
            end
        end
    end)
end

function F.putOnGenericInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    F.saveEquip(resID, insID)
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0)
end

function F.clearEquipCache(resID)
    local st = F.subType(F.cfg(resID))
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = nil, nil
            _G.AddOutfitLastLobbyTshirtRes = nil
            F.persistForgetSlot("tshirt")
        else
            cch.outfitRes, cch.outfitIns = nil, nil
            _G.AddOutfitLastLobbyOutfitRes = nil
            F.persistForgetSlot("outfit")
        end
    elseif st == HAT_SUB or HEAD_SUBS[st] then
        cch.hatRes, cch.hatIns = nil, nil
        _G.AddOutfitLastLobbyHatRes = nil
        F.persistForgetSlot("hat")
    elseif st == MASK_SUB then
        cch.maskRes, cch.maskIns = nil, nil
        _G.AddOutfitLastLobbyMaskRes = nil
        F.persistForgetSlot("mask")
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = nil, nil
        _G.AddOutfitLastLobbyGlassRes = nil
        F.persistForgetSlot("glass")
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = nil, nil
        _G.AddOutfitLastLobbyPantsRes = nil
        F.persistForgetSlot("pants")
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = nil, nil
        _G.AddOutfitLastLobbyShoesRes = nil
        F.persistForgetSlot("shoes")
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = nil, nil
        _G.AddOutfitLastLobbyBagRes = nil
        F.persistForgetSlot("bag")
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = nil, nil
        _G.AddOutfitLastLobbyHelmetRes = nil
        F.persistForgetSlot("helmet")
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = nil, nil
        _G.AddOutfitLastLobbyParachuteRes = nil
        F.persistForgetSlot("parachute")
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = nil, nil
        _G.AddOutfitLastLobbyGliderRes = nil
        F.persistForgetSlot("glider")
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = nil, nil
        _G.AddOutfitLastLobbyGlovesRes = nil
        F.persistForgetSlot("gloves")
    end
    _matchApplied = false
    F.invalidateSocialWearCache()
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.takeOffInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    local st = F.subType(F.cfg(resID))

    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_down_rsp(NET_OK, { res_id = resID, count = 1 }, insID)
    end)

    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        AvatarData.RemoveRoleWearDataByValue(insID)
    end)
    if st == HAT_SUB or HEAD_SUBS[st] then
        pcall(function()
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag and tonumber(bag.head_show) == insID then fbd:SetHeadShow(0) end
        end)
    end
    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            local t = DataMgr.equipmentSkinInsIDTable
            if t then
                for _, k in ipairs({ st, 504, 505 }) do
                    if tonumber(t[k]) == insID then t[k] = 0 end
                end
            end
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if tonumber(bag.bag_skin) == insID then bag.bag_skin = 0 end
                if tonumber(bag.helmet_skin) == insID then bag.helmet_skin = 0 end
            end
        end)
    end

    F.clearEquipCache(resID)
    pcall(function() F.syncFashionBagRolewear() end)
end

function F.syncWeaponArmorySilent(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return end
    local resID = R.insToRes[insID]
    if not resID then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateCurrentFashionBagWeaponSkin then
            fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
        end
    end)
end

function F.equipWeaponSkin(weaponID, insID, forceVisual)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if not resID then return false end

    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if not forceVisual and F.isWeaponVisuallyEquipped(weaponID, insID) then
        F.syncWeaponArmorySilent(weaponID, insID)
        return false
    end
    F.saveEquip(resID, insID)

    local Arm = require("client.logic.armory.logic_armory")
    local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
    local HT = require("client.logic.lobby.hall_theme_utils")
    local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")

    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    if fbd.UpdateCurrentFashionBagWeaponSkin then
        fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
    end

    local bagIdx = fbd:GetFashionBagUseIndex()
    HT.proc_skin_list_chg("weapon_skin", weaponID, insID, bagIdx, {})

    wgl:SetGunID(weaponID)
    wgl:UpdateCurrentGunAvatar(weaponID, insID)

    if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
        EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
    end
    if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
    end
    _G.AddOutfitWeaponEquipped[weaponID] = insID
    return true
end

local SOCIAL = _G.AddOutfitSocialState or {}
_G.AddOutfitSocialState = SOCIAL
SOCIAL.debGen = SOCIAL.debGen or 0
SOCIAL.wearPatchKey = SOCIAL.wearPatchKey or nil
SOCIAL.snapshotKey = SOCIAL.snapshotKey or nil
SOCIAL.fullSnapshot = SOCIAL.fullSnapshot or nil

function F.socialDebounce(sec, fn)
    SOCIAL.debGen = (SOCIAL.debGen or 0) + 1
    local gen = SOCIAL.debGen
    F.later(sec, function()
        if gen ~= SOCIAL.debGen then return end
        pcall(fn)
    end)
end

function F.getLobbyCurPage()
    local p = nil
    pcall(function()
        local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
        if LMC.GetCurPage then p = LMC.GetCurPage() end
    end)
    return p
end

function F.isLobbyLeftPage()
    return ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left
end

function F.getWeaponSkinResFast()
    local cch = F.cache()
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local w = wid > 0 and cch.weapons[wid] or nil
    if w and w.resID and w.resID > 0 then return w.resID end
    for _, ww in pairs(cch.weapons) do
        if ww.resID and ww.resID > 0 then return ww.resID end
    end
    return nil
end

function F.resolveLobbyWeaponSkinRes()
    if LOBBY.skinResolved then return LOBBY.cachedSkin end
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local skin = F.getWeaponSkinResFast()
    if skin and skin > 0 then return skin end

    if wid > 0 then
        local fromMatch = F.getMatchWeaponSkin(wid)
        if fromMatch and fromMatch > 0 then return fromMatch end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, s in pairs(MATCH_CONFIG.weaponSkins) do
            s = tonumber(s)
            if s and s > 0 then return s end
        end
    end

    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local entry = Arm.rsp_list and Arm.rsp_list.install_list
            and Arm.rsp_list.install_list[wid > 0 and wid or 101004]
        local insID = tonumber(entry and entry.skin_id) or 0
        if insID > 0 and F.isInjectedIns(insID) then
            skin = tonumber(R.insToRes[insID])
        elseif insID > 0 then
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            if d and d.resID then skin = tonumber(d.resID) end
        end
    end)
    if skin and skin > 0 then return skin end

    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl.GetSkinIdByWeaponID and wid > 0 then
            local insID = tonumber(wgl:GetSkinIdByWeaponID(wid)) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                skin = tonumber(R.insToRes[insID])
            end
        end
    end)
    LOBBY.skinResolved = true
    LOBBY.cachedSkin = (skin and skin > 0) and skin or nil
    return LOBBY.cachedSkin
end

function F.resolveLobbyOutfitRes()
    if LOBBY.outfitResolved then return LOBBY.cachedOutfit end
    local cch = F.cache()
    local outfitRes = tonumber(cch.outfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    outfitRes = tonumber(_G.AddOutfitLastLobbyOutfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = tonumber(MATCH_CONFIG.outfitRes)
        return LOBBY.cachedOutfit
    end

    local injectedRes, anyRes
    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local function resFromIns(ins)
            ins = tonumber(ins)
            if not ins or ins <= 0 then return nil end
            if F.isInjectedIns(ins) then return tonumber(R.insToRes[ins]) end
            local d = wd:GetHallDepotItemDataByInsID(ins)
            return d and tonumber(d.resID) or nil
        end
        for _, ins in pairs(AvatarData.GetRoleWear()) do
            local res = resFromIns(ins)
            if res and F.isSuitRes(res) then
                if F.isInjectedRes(res) then injectedRes = res end
                anyRes = anyRes or res
            end
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.rolewear_list then
            for _, ins in pairs(bag.rolewear_list) do
                local res = resFromIns(ins)
                if res and F.isSuitRes(res) then
                    if F.isInjectedRes(res) then injectedRes = res end
                    anyRes = anyRes or res
                end
            end
        end
    end)
    if injectedRes and injectedRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = injectedRes
        return injectedRes
    end
    if anyRes and anyRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = anyRes
        return anyRes
    end
    LOBBY.outfitResolved = true
    LOBBY.cachedOutfit = nil
    return nil
end

function F.rememberLobbyOutfitRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not F.isSuitRes(resID) then return end
    _G.AddOutfitLastLobbyOutfitRes = resID
    F.invalidateLobbyResolved()
    local cch = F.cache()
    if not cch.outfitRes or cch.outfitRes <= 0 then
        cch.outfitRes = resID
        if F.isInjectedRes(resID) then cch.outfitIns = R.resToIns[resID] end
    end
end

function F.wearPatchKey()
    local outfit = F.resolveLobbyOutfitRes() or 0
    local skin = F.resolveLobbyWeaponSkinRes() or 0
    local openGun = 1
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then openGun = lds.data.OpenGun and 1 or 0 end
    end)
    return outfit .. "_" .. skin .. "_" .. openGun
end

function F.syncDepotShowWeaponFlags(depot)
    depot = depot or {}
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data then
            if lds.data.OpenGun ~= nil then depot.weapon = lds.data.OpenGun end
            if lds.data.OpenSocialWeapon ~= nil then depot.social_weapon = lds.data.OpenSocialWeapon end
        end
    end)
    return depot
end

function F.applyInjectedPspace(roleData)
    if not roleData then return end
    roleData.bshow = true
    roleData.pspace_wear_ext = roleData.pspace_wear_ext or {}
    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 }
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { skinRes, 0, 0 }
        roleData.depot_show_info = roleData.depot_show_info or {}
        if roleData.depot_show_info.weapon == nil then
            roleData.depot_show_info.weapon = true
        end
    end
    roleData.depot_show_info = F.syncDepotShowWeaponFlags(roleData.depot_show_info)
end

function F.patchSelfWearCache(force)
    local key = F.wearPatchKey()
    if not force and SOCIAL.wearPatchKey == key then return false end
    SOCIAL.wearPatchKey = key
    SOCIAL.snapshotKey = nil
    SOCIAL.fullSnapshot = nil

    local myUid = tonumber(DataMgr.roleData.uid)
    if not myUid then return false end

    local changed = false
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local d = BD:GetCacheData(myUid)
        if not d then
            BD:OnHandleMsgDataAndCallback(myUid, F.buildLocalRoleDataForCoupleAvatar())
            return true
        end
        local oldCloth = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local oldSkin = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        F.applyInjectedPspace(d)
        local nc = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local ns = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        if oldCloth ~= nc or oldSkin ~= ns or not d.bshow then changed = true end
    end)
    return force or changed
end

function F.requestSocialAvatarRefresh()
    pcall(function()
        if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR then
            EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR)
        end
    end)
end

function F.onSocialWearDirty(forceRefresh)
    SOCIAL.lastHandSkin = nil
    if F.patchSelfWearCache(forceRefresh) then
        F.requestSocialAvatarRefresh()
    end
end

function F.buildLocalRoleDataForCoupleAvatar()
    local key = F.wearPatchKey()
    if SOCIAL.fullSnapshot and SOCIAL.snapshotKey == key then
        return SOCIAL.fullSnapshot
    end
    F.syncWeaponCacheFromLobby()
    local cch = F.cache()
    local ad = DataMgr.avatarData or {}
    local gender = tonumber(ad.gamegender) or 2
    if gender < 1 then gender = 2 end

    local data = {
        uid = DataMgr.roleData.uid,
        gender = gender,
        bshow = true,
        pspace_wear_ext = {
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HEAD] = { tonumber(ad.headid) or 401993, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HAIR] = { tonumber(ad.hairid) or 40601001, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { 0, 0, 0 },
        },
        depot_show_info = {
            weapon = true, social_weapon = true, idle = true,
            helmet = true, bag = true, vehicle = true, hand = true,
        },
    }

    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end

    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON][1] = 0
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN][1] = skinRes
    end
    data.depot_show_info = F.syncDepotShowWeaponFlags(data.depot_show_info)
    SOCIAL.fullSnapshot = data
    SOCIAL.snapshotKey = F.wearPatchKey()
    return data
end

local _myUidCached
function F.isMyWearData(wearData)
    if not wearData then return false end
    if not _myUidCached then
        pcall(function() _myUidCached = tonumber(DataMgr.roleData.uid) end)
    end
    return _myUidCached and tonumber(wearData.uid) == _myUidCached
end

function F.mergeInjectedWeaponIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    wearData.depot_show_info = F.syncDepotShowWeaponFlags(wearData.depot_show_info)
    if not skinRes or skinRes <= 0 then return end
    wearData.mainWeaponInfo = wearData.mainWeaponInfo or {
        weaponResId = 0, weaponSkinId = 0,
        diyInfo = { diyWeaponId = 0, diyDefaultScheme = false, diyScheme = nil },
    }
    if wearData.mainWeaponInfo.weaponSkinId == skinRes
        and (tonumber(wearData.mainWeaponInfo.weaponResId) or 0) == 0 then
        return
    end
    wearData.mainWeaponInfo.weaponSkinId = skinRes
    wearData.mainWeaponInfo.weaponResId = 0
end

function F.equipSocialHandWeapon(avatar, skinRes)
    if not avatar or not skinRes or skinRes <= 0 then return end
    if SOCIAL.lastHandSkin == skinRes then return end
    SOCIAL.lastHandSkin = skinRes
    pcall(function()
        avatar:PutonEquipment(skinRes, nil, { bIsUse = true })
    end)
end

function F.shouldShowHandWeapon()
    local show = true
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then
            show = lds.data.OpenGun ~= false
        end
    end)
    return show
end

function F.mergeInjectedOutfitIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local outfitRes = F.resolveLobbyOutfitRes()
    if not outfitRes or outfitRes <= 0 then return end
    F.rememberLobbyOutfitRes(outfitRes)
    local AvatarData = require("client.logic.data.AvatarData")
    local converted = AvatarData.ConvertToAvatarCustom({ outfitRes, 0, 0 })
    if not converted then return end
    wearData.WearInfoList = wearData.WearInfoList or {}
    local replaced = false
    for i, e in ipairs(wearData.WearInfoList) do
        if e and e.ItemID and F.isSuitRes(e.ItemID) then
            wearData.WearInfoList[i] = converted
            replaced = true
            break
        end
    end
    if not replaced then
        table.insert(wearData.WearInfoList, converted)
    end
end

function F.mergeInjectedIntoWearData(wearData)
    if not wearData then return end
    F.mergeInjectedWeaponIntoWearData(wearData)
    F.mergeInjectedOutfitIntoWearData(wearData)
end

function F.reapplyLobbyEquipped()
    -- [FIX VIP] Chặn không cho sảnh đắp lại skin ảo khi bạn đã tắt công tắc
    if not _G.LexusConfig.ModSkin then return end
    
    if not GameStatus or not GameStatus.IsInLobbyOrMainCity or not GameStatus.IsInLobbyOrMainCity() then
        return
    end
    F.syncWeaponCacheFromLobby()
    F.applyPersistSlotsToCache()
    local curPage = F.getLobbyCurPage()

    if ENUM_LobbyPageType and curPage == ENUM_LobbyPageType.Left then
        F.onSocialWearDirty(true)
        return
    end

    local cch = F.cache()
    if cch.outfitIns and F.isInjectedIns(cch.outfitIns) then
        F.putOnOutfit(cch.outfitIns)
    end
    if cch.hatIns and F.isInjectedIns(cch.hatIns) then
        F.putOnHat(cch.hatIns)
    end
    if cch.maskIns and F.isInjectedIns(cch.maskIns) then
        F.putOnRoleWear(cch.maskIns)
    end
    if cch.glassIns and F.isInjectedIns(cch.glassIns) then
        F.putOnRoleWear(cch.glassIns)
    end
    if cch.tshirtIns and F.isInjectedIns(cch.tshirtIns) then
        F.putOnRoleWear(cch.tshirtIns)
    end
    if cch.pantsIns and F.isInjectedIns(cch.pantsIns) then
        F.putOnRoleWear(cch.pantsIns)
    end
    if cch.shoesIns and F.isInjectedIns(cch.shoesIns) then
        F.putOnRoleWear(cch.shoesIns)
    end
    if cch.bagIns and F.isInjectedIns(cch.bagIns) then
        F.putOnRoleWear(cch.bagIns)
    end
    if cch.helmetIns and F.isInjectedIns(cch.helmetIns) then
        F.putOnRoleWear(cch.helmetIns)
    end
    if cch.parachuteIns then
        F.putOnParachute(cch.parachuteIns)
    end
    if cch.gliderIns then
        F.putOnGlider(cch.gliderIns)
    end
    if cch.glovesIns and F.isInjectedIns(cch.glovesIns) then
        F.putOnGloves(cch.glovesIns)
    end

    local mainWid = tonumber(DataMgr.Weapon_ID) or 0
    local w = mainWid > 0 and cch.weapons[mainWid] or nil
    if w and w.resID and w.resID > 0 then
        if w.insID and F.isInjectedIns(w.insID) then
            F.equipWeaponSkin(mainWid, w.insID)
        else
            pcall(function() DataMgr.InitWeaponData(mainWid, w.resID, w.insID or 0) end)
        end
    end

    pcall(function()
        local uid = tostring(DataMgr.roleData.uid)
        local LAM = require("client.logic.avatar.LobbyAvatarManager")
        local TAM = require("client.logic.avatar.logic_team_avatar_manager")
        if w and w.resID and w.resID > 0 and TAM.GetAvatarByUid(uid) then
            LAM.EquipWeapon(uid, { weaponId = mainWid, skinId = w.resID }, nil, true)
        end
    end)

    F.reapplyVehicleSlotsFromConfig(true)
    F.reapplyHallThemeFromConfig(true)
    F.reapplyWeaponsFromConfig()
    pcall(F.applyVehicleSkinsToPC)
end

F.scheduleLobbyReapplyOnce = function()
    if LOBBY.reapplyDone or LOBBY.reapplyScheduled then return end
    LOBBY.reapplyScheduled = true
    F.later(2.0, function()
        LOBBY.reapplyScheduled = false
        if LOBBY.reapplyDone then return end
        LOBBY.reapplyDone = true
        F.reapplyLobbyEquipped()
    end)
end

function F.hookLobbySwipePersistence()
    if _G.AddOutfitLobbySwipeHooked then return end
    _G.AddOutfitLobbySwipeHooked = true
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local oRsp = BD.on_get_avatar_show_rsp
        BD.on_get_avatar_show_rsp = function(self, res, target_uid, data)
            oRsp(self, res, target_uid, data)
                if tonumber(target_uid) == tonumber(DataMgr.roleData.uid) then
                F.patchSelfWearCache(true)
                SOCIAL.forceAvatarRedraw = true
                SOCIAL.lastHandSkin = nil
                if ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    F.requestSocialAvatarRefresh()
                end
            end
        end
    end)

    pcall(function()
        local AC = require("client.slua.logic.avatar.avatar_common")
        local oGetWear = AC.GetWearDataFromRoleData
        AC.GetWearDataFromRoleData = function(roleData)
            local wearData = oGetWear(roleData)
            if wearData and roleData and tonumber(roleData.uid) == tonumber(DataMgr.roleData.uid)
                and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            return wearData
        end
        local oUp = AC.UpdateAvatar
        AC.UpdateAvatar = function(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            local showGun = isShowWeapon and F.shouldShowHandWeapon()
            if wearData and wearData.depot_show_info then
                showGun = showGun and wearData.depot_show_info.weapon ~= false
            end
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                for _, e in ipairs(wearData.WearInfoList or {}) do
                    if e and e.ItemID and F.isInjectedRes(e.ItemID) and F.isSuitRes(e.ItemID) then
                        F.rememberLobbyOutfitRes(e.ItemID)
                        break
                    end
                end
            end
            local ret = oUp(avatar, wearData, showGun, isShowHelmet, isShowBag)
            if showGun and F.isMyWearData(wearData) and avatar and F.isLobbyLeftPage() then
                local skin = tonumber(wearData.mainWeaponInfo and wearData.mainWeaponInfo.weaponSkinId) or 0
                if skin <= 0 then skin = F.resolveLobbyWeaponSkinRes() or 0 end
                if skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
            end
            return ret
        end
    end)

    pcall(function()
        local CA = require("client.logic.avatar.CoupleAvatar")
        local Cfg = require("client.slua.logic.lobby.Left.CoupleAvatarConfig")
        local oMulti = CA._UpdateMultiAvatar
        if oMulti then
            CA._UpdateMultiAvatar = function(self, avatar, avatarType)
                local isSelf = avatarType == Cfg.AvatarType.Self
                    and self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
                if isSelf and F.isLobbyLeftPage() then
                    pcall(function()
                        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
                        local d = BD:GetCacheData(tonumber(self.SelfUID))
                        if d then F.applyInjectedPspace(d) end
                    end)
                    if SOCIAL.forceAvatarRedraw then
                        self.CompareDataCache[avatarType] = nil
                        SOCIAL.forceAvatarRedraw = nil
                    end
                end
                oMulti(self, avatar, avatarType)
                if isSelf and F.isLobbyLeftPage() and self.isShowWeapon ~= false and F.shouldShowHandWeapon() then
                    local skin = F.resolveLobbyWeaponSkinRes()
                    if skin and skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
                end
            end
        end
        local oHideCheck = CA.CheckSelfIsHideAvatar
        CA.CheckSelfIsHideAvatar = function(self, nSelfUId, tRoleData)
            if F.isLobbyLeftPage() and tostring(nSelfUId) == tostring(DataMgr.roleData.uid) then
                return false
            end
            return oHideCheck(self, nSelfUId, tRoleData)
        end

        local oUpdate = CA.Update
        CA.Update = function(self)
            if not F.isLobbyLeftPage() then
                return oUpdate(self)
            end
            local isSelf = self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
            local oHide = CA.HideAvatars
            if isSelf then
                CA.HideAvatars = function() end
            end
            local ok, err = pcall(oUpdate, self)
            CA.HideAvatars = oHide
        end

        local oRecv = CA.OnReceiveData
        CA.OnReceiveData = function(self, uid, data)
            if F.isLobbyLeftPage() and uid == self.SelfUID and tostring(uid) == tostring(DataMgr.roleData.uid) then
                if data then
                    F.applyInjectedPspace(data)
                else
                    data = F.buildLocalRoleDataForCoupleAvatar()
                end
            end
            return oRecv(self, uid, data)
        end
    end)

    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_START then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_START, function(_, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    local o = F.resolveLobbyOutfitRes()
                    if o then F.rememberLobbyOutfitRes(o) end
                    F.patchSelfWearCache(true)
                    SOCIAL.forceAvatarRedraw = true
                end
            end)
        end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_END then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_END, function(_, _, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    F.socialDebounce(0.45, function()
                        F.onSocialWearDirty(true)
                    end)
                elseif ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Mid then
                    SOCIAL.wearPatchKey = nil
                    F.invalidateLobbyResolved()
                    if not LOBBY.reapplyDone then
                        F.socialDebounce(0.5, F.scheduleLobbyReapplyOnce)
                    end
                end
            end)
        end
        if EVENTTYPE_LOBBY_SOCIAL and EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA then
            EventSystem:registEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA, function(_, _, nUId)
                if tonumber(nUId) == tonumber(DataMgr.roleData.uid) then
                    F.socialDebounce(0.2, function() F.patchSelfWearCache(false) end)
                end
            end)
        end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function()
                SOCIAL.wearPatchKey = nil
                SOCIAL.snapshotKey = nil
                F.syncWeaponCacheFromLobby()
                
                local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
                if curPage == ENUM_LobbyPageType.Left then
                    F.socialDebounce(0.25, function() F.onSocialWearDirty(true) end)
                end
                
                -- [FIX LỖI VIP] Tự động đắp lại Skin Mod khi game có dấu hiệu update súng ở sảnh
                F.socialDebounce(0.3, function()
                    if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
                end)
            end)
        end
    end)

    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        local oSwitch = lds.SwitchGun
        lds.SwitchGun = function(...)
            local r = oSwitch(...)
            SOCIAL.wearPatchKey = nil
            
            local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
            if curPage == ENUM_LobbyPageType.Left then
                F.socialDebounce(0.2, function() F.onSocialWearDirty(true) end)
            end
            
            -- [FIX LỖI VIP] Khi Click vào ô vũ khí ở Sảnh, đợi game đổi súng gốc xong thì 0.3s sau đắp skin Mod lên lại
            F.socialDebounce(0.3, function()
                if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
            end)
            
            return r
        end
    end)
end

function F.hookDepotInit()
    pcall(function()
        local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
        if WDE._AddOutfitInitHooked then return end
        WDE._AddOutfitInitHooked = true
        local orig = WDE.InitData
        WDE.InitData = function(self, pkg)
            orig(self, pkg)
            _G.AddOutfitUnexpireDone = false
            pcall(function()
                if F.injectAll(self) then
                    F.scheduleInjectRefresh()
                    LOBBY.reapplyDone = false
                    LOBBY.reapplyScheduled = false
                    F.scheduleLobbyReapplyOnce()
                end
            end)
        end
    end)
end

function F.hookWardrobeData()
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        if wd._AddOutfitDataHooked then return end
        wd._AddOutfitDataHooked = true
        local function wrapGet(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, insID, ...)
                insID = tonumber(insID)
                local r
                if F.isInjectedIns(insID) then
                    local e = F.getEntity()
                    if e then r = e:GetDataByInsID(insID) end
                else
                    r = o(self, insID, ...)
                end
                if r and (F.isInjectedIns(insID) or F.isInjectedRes(r.resID or r.res_id)) then
                    r.expire_ts = 0
                    r.expireTS = 0
                    r.valid_hours = 0
                end
                return r
            end
        end
        wrapGet("GetHallDepotItemDataByInsID")
        wrapGet("GetValidHallDepotItemDataByInsID")
        local function wrapBool(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, id, ...)
                if F.isInjectedRes(tonumber(id)) or F.isInjectedIns(tonumber(id)) then return true end
                return o(self, id, ...)
            end
        end
        wrapBool("HasItem")
        wrapBool("HasValidItem")
        wrapBool("CheckHasPermanentItem")
    end)
end

function F.hookPageFilter()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPageFilterHooked then return end
        wl._AddOutfitPageFilterHooked = true
        local o1 = wl.IsValidCurrentPageItem
        wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
            if v and F.isInjectedRes(v.resID) then
                local itemTab = tonumber(v.subTabType) or F.wardrobeTab(v.resID)
                if itemTab and itemTab == subTab then
                    if mainTab == PAGE_AVATAR or mainTab == PAGE_VEHICLE then return true end
                    if mainTab == PAGE_PARACHUTE and F.isHallThemeRes(v.resID) then return true end
                end
            end
            return o1(self, mainTab, subTab, v, t)
        end
        local o2 = wl.IsCanUse
        wl.IsCanUse = function(self, resId)
            if F.isInjectedRes(resId) then return true end
            return o2(self, resId)
        end
        local o3 = wl.IsCharacterUse
        wl.IsCharacterUse = function(self, resId)
            if F.isInjectedRes(resId) then return true end
            return o3(self, resId)
        end
        local o4 = wl.GetWardrobeInsIdByResId
        wl.GetWardrobeInsIdByResId = function(self, resid)
            resid = tonumber(resid)
            if F.isInjectedRes(resid) then return R.resToIns[resid] end
            return o4(self, resid)
        end
    end)
end

function F.hookArmory()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm._AddOutfitArmoryHooked then return end
        Arm._AddOutfitArmoryHooked = true
        local oa = Arm.get_weapon_skin_list_rsp
        Arm.get_weapon_skin_list_rsp = function(a, b, c, d)
            oa(a, b, c, d)
            F.mergeInjectedArmorySkins()
        end
        local oi = Arm.install_weapon_skin
        Arm.install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return oi(cd, wid, ins)
        end
    end)
    pcall(function()
        local AH = require("client.network.Protocol.ArmoryHandler")
        if AH._AddOutfitArmorySendHooked then return end
        AH._AddOutfitArmorySendHooked = true
        local o = AH.send_install_weapon_skin
        AH.send_install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return o(cd, wid, ins)
        end
    end)
end

function F.hookGunSkinId()
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl._AddOutfitGunSkinHooked then return end
        wgl._AddOutfitGunSkinHooked = true
        local o = wgl.GetSkinIdByWeaponID
        wgl.GetSkinIdByWeaponID = function(self, wid)
            local c = F.cache()
            local w = c.weapons[wid]
            if w and F.isWeaponSkinIns(w.insID) then return w.insID end
            local Arm = require("client.logic.armory.logic_armory")
            if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                local sid = Arm.rsp_list.install_list[wid].skin_id
                if sid and F.isWeaponSkinIns(sid) then return sid end
            end
            return o(self, wid)
        end
    end)
end

function F.hookPutOn()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutOnHooked then return end
        WRH._AddOutfitPutOnHooked = true
        local o = WRH.send_depot_put_on_req
        WRH.send_depot_put_on_req = function(insID, extra)
            insID = tonumber(insID)
            if F.tryLocalWearByIns(insID) then return end
            return o(insID, extra)
        end
    end)
end

function F.hookPutDown()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutDownHooked then return end
        WRH._AddOutfitPutDownHooked = true
        local o = WRH.send_depot_put_down_req
        WRH.send_depot_put_down_req = function(insID)
            if F.isInjectedIns(tonumber(insID)) then
                F.takeOffInjected(insID)
                return
            end
            return o(insID)
        end
        local ob = WRH.send_depot_batch_put_down_req
        WRH.send_depot_batch_put_down_req = function(instid_list)
            local rest = {}
            for _, id in ipairs(instid_list or {}) do
                if F.isInjectedIns(tonumber(id)) then
                    F.takeOffInjected(id)
                else
                    rest[#rest + 1] = id
                end
            end
            if #rest > 0 then return ob(rest) end
        end
    end)
end

function F.hookVehicleSwitchEffect()
    if _G.AddOutfitVehSwitchHooked then return end
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local impl = VAC and VAC.__inner_impl
        if not impl or impl._AddOutfitVehSwitchHooked then return end
        impl._AddOutfitVehSwitchHooked = true

        if not _G.AddOutfitVehOrigCanSwitch then
            _G.AddOutfitVehOrigCanSwitch = impl.CheckCanPlaySkinSwitchEffect
        end
        impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId)
            -- [BẢO VỆ XE ĐỒNG ĐỘI] Trả lại lệnh check hiệu ứng cho game gốc khi tắt công tắc
            if not _G.LexusConfig.ModSkin then 
                if _G.AddOutfitVehOrigCanSwitch then return _G.AddOutfitVehOrigCanSwitch(self, curVehicleId, lastVehicleId) end
                return false
            end
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            return true
        end

        if not _G.AddOutfitVehOrigShowSwitch then
            _G.AddOutfitVehOrigShowSwitch = impl.ShowVehicleSwitchEffect
        end
        impl.ShowVehicleSwitchEffect = function(self)
            -- [BẢO VỆ XE ĐỒNG ĐỘI] Trả lại hiệu ứng đổi xe cho game gốc khi tắt công tắc
            if not _G.LexusConfig.ModSkin then 
                if _G.AddOutfitVehOrigShowSwitch then return _G.AddOutfitVehOrigShowSwitch(self) end
                return false
            end
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then
                self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
            end
            local vehicleActor = self:GetOwner()
            if not slua.isValid(vehicleActor) then return false end
            if self.uSwitchEffectActor then
                self:StopSkinSwitchEffect()
                pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                self.uSwitchEffectActor = nil
            end
            if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
                local defId = 0
                pcall(function() defId = self:GetDefaultAvatarID() or 0 end)
                self.lastEquipedAvatarId = vehicleActor.ClientUsedAvatarID or defId or 0
            end
            local currentAvatarID = vehicleActor.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
            local bIsLobbyActor = self:IsLobbyActor()
            local world = slua_GameFrontendHUD:GetWorld()
            local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
            local SkinSwitchEffectActorPath = VehiclePlateLicenseUtil.GetSwitchEffectActorPath()
            local BP_DissolveVehicleClass = import(SkinSwitchEffectActorPath)
            self.uSwitchEffectActor = world:SpawnActor(BP_DissolveVehicleClass, nil, nil, nil)
            if not slua.isValid(self.uSwitchEffectActor) then
                self.uSwitchEffectActor = nil
                return false
            end
            self.uSwitchEffectActor:K2_AttachToActor(vehicleActor, "None", 1, 1, 1, false)
            self.uSwitchEffectActor:K2_SetActorRelativeLocation(FVector(0, 0, 0), false, nil, false)
            self.uSwitchEffectActor:K2_SetActorRelativeRotation(FRotator(0, 0, 0), false, nil, false)
            pcall(function() self:HideParticles() end)
            self:ChangeFakeSwitchVehicleAvatar(self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId)
            self.uSwitchEffectActor:SetAnimInsAndAnimState(self.uOldVehicleMeshAnimClass, vehicleActor)
            self.uSwitchEffectActor:StartVehicleSwitchEffect(
                vehicleActor, self.curSwitchEffectId, self.lastEquipedAvatarId, currentAvatarID, bIsLobbyActor)
            self.uOldVehicleMeshAnimClass = nil
            return true
        end

        if not _G.AddOutfitVehOrigBeginPlay then
            _G.AddOutfitVehOrigBeginPlay = impl.ReceiveBeginPlay
        end
        local oBegin = _G.AddOutfitVehOrigBeginPlay
        impl.ReceiveBeginPlay = function(self)
            oBegin(self)
            pcall(function()
                if self.uSwitchEffectActor then
                    self:StopSkinSwitchEffect()
                    pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                    self.uSwitchEffectActor = nil
                end
                self.lastEquipedAvatarId = 0
                if self.IsLobbyActor and self:IsLobbyActor() then
                    self.curSwitchEffectId = 0
                elseif F.isInRealMatch() then
                    self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
                else
                    self.curSwitchEffectId = 0
                end
            end)
        end

        if impl.LuaIsAssetsAlreadyAvailable and not _G.AddOutfitVehOrigAssets then
            _G.AddOutfitVehOrigAssets = impl.LuaIsAssetsAlreadyAvailable
            impl.LuaIsAssetsAlreadyAvailable = function(self, avatarId)
                if _G.LexusConfig.ModSkin and F.isVehicleSkinAllowed(tonumber(avatarId)) then return true end
                return _G.AddOutfitVehOrigAssets(self, avatarId)
            end
        end

        _G.AddOutfitVehSwitchHooked = true
    end)
end

function F.hookVehicleChassisLight()
    if _G.AddOutfitVehChassisHooked then return end
    pcall(function()
        local LIC = require("GameLua.Activity.Commercialize.Actor.ActorComponent.BP_VehicleLicenseComponentBase")
        if LIC and LIC.CheckHasVehicleDownloaded and not _G.AddOutfitVehOrigLicDownload then
            _G.AddOutfitVehOrigLicDownload = LIC.CheckHasVehicleDownloaded
            LIC.CheckHasVehicleDownloaded = function(self, itemID)
                local id = tonumber(itemID)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return _G.AddOutfitVehOrigLicDownload(self, itemID)
            end
        end
    end)
    pcall(function()
        local LVF = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicVehicleExtendedFeature)
        if not LVF or LVF._AddOutfitChassisHooked then return end
        LVF._AddOutfitChassisHooked = true

        if not _G.AddOutfitVehOrigGetFeature then
            _G.AddOutfitVehOrigGetFeature = LVF.CheckHasGetFeatureItem
        end
        LVF.CheckHasGetFeatureItem = function(self, featureId)
            if F.isChassisLightId(featureId) then return true end
            return _G.AddOutfitVehOrigGetFeature(self, featureId)
        end

        if not _G.AddOutfitVehOrigEquippedFeature then
            _G.AddOutfitVehOrigEquippedFeature = LVF.CheckHasEquippedItem
        end
        LVF.CheckHasEquippedItem = function(self, featureId, vehicleId)
            -- [FIX VIP] Bổ sung check điều kiện ModSkin
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                if F.isChassisLightId(featureId) then
                    return F.getDesiredChassisLight(vehicleId) == tonumber(featureId)
                end
            end
            return _G.AddOutfitVehOrigEquippedFeature(self, featureId, vehicleId)
        end

        if not _G.AddOutfitVehOrigEquipChassisData then
            _G.AddOutfitVehOrigEquipChassisData = LVF.GetEquipedChassisLightData
        end
        LVF.GetEquipedChassisLightData = function(self, vehicleId, source)
            -- [FIX VIP] Bổ sung check điều kiện ModSkin
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                local our = F.getDesiredChassisLight(vehicleId)
                if our then return our end
            end
            return _G.AddOutfitVehOrigEquipChassisData(self, vehicleId, source)
        end

        if not _G.AddOutfitVehOrigChassisLightData then
            _G.AddOutfitVehOrigChassisLightData = LVF.GetVehicleChassisLightData
        end
        LVF.GetVehicleChassisLightData = function(self, uid, vehicleId, position, source)
            -- [FIX VIP] Bổ sung check điều kiện ModSkin
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                if uid and DataMgr and DataMgr.roleData and tonumber(uid) == tonumber(DataMgr.roleData.uid) then
                    local our = F.getDesiredChassisLight(vehicleId)
                    if our then return our end
                end
            end
            return _G.AddOutfitVehOrigChassisLightData(self, uid, vehicleId, position, source)
        end

        if not _G.AddOutfitVehOrigPutOnFeature then
            _G.AddOutfitVehOrigPutOnFeature = LVF.PutOnVehicleFeature
        end
        LVF.PutOnVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                F.saveChassisLight(vehicleId, featureId)
                self.equip_chassis_light = self.equip_chassis_light or {}
                if vehicleId and vehicleId > 0 then
                    self.equip_chassis_light[vehicleId] = featureId
                end
                return
            end
            return _G.AddOutfitVehOrigPutOnFeature(self, featureId, vehicleId)
        end

        if not _G.AddOutfitVehOrigPutOffFeature then
            _G.AddOutfitVehOrigPutOffFeature = LVF.PutOffVehicleFeature
        end
        LVF.PutOffVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
                if vehicleId and vehicleId > 0 then
                    PERSIST.configChassisLightMap[vehicleId] = nil
                end
                if self.equip_chassis_light and vehicleId then
                    self.equip_chassis_light[vehicleId] = nil
                end
                F.persistMarkDirty()
                return
            end
            return _G.AddOutfitVehOrigPutOffFeature(self, featureId, vehicleId)
        end
    end)
    _G.AddOutfitVehChassisHooked = true
end

function F.hookVehicles()
    F.hookVehicleSwitchEffect()
    F.hookVehicleChassisLight()
    pcall(function()
        local WV = require("client.slua.umg.Wardrobe.subtab_vehicles")
        if not WV or WV._AddOutfitVehClickHooked then return end
        WV._AddOutfitVehClickHooked = true
        local oClick = WV.ClickItem
        WV.ClickItem = function(self, vehicleSkin, bForceUsing)
            if vehicleSkin and F.isInjectedRes(vehicleSkin.res_id) then
                vehicleSkin.expireTS = 0
                vehicleSkin.expire_ts = 0
            end
            return oClick(self, vehicleSkin, bForceUsing)
        end
        local oDrop = WV.OnVehicleSlotDrop
        if oDrop then
            WV.OnVehicleSlotDrop = function(self, DragWidget, Index, DragDropData)
                pcall(function()
                    local ins = DragDropData and DragDropData.ins_id
                    if F.isInjectedIns(tonumber(ins)) then
                        F.ensureInjectedItemAlive(nil, nil, ins)
                    end
                end)
                return oDrop(self, DragWidget, Index, DragDropData)
            end
        end
    end)
    pcall(function()
        local WNH = require("client.network.Protocol.WardrobeNewHandler")
        if WNH._AddOutfitVehicleHooked then return end
        WNH._AddOutfitVehicleHooked = true
        local oMod = WNH.send_depot_modify_combat_vehicle_req
        WNH.send_depot_modify_combat_vehicle_req = function(instid, slot_index, ope_type)
            if F.modifyInjectedVehicleSlot(instid, slot_index, ope_type == true) then return end
            return oMod(instid, slot_index, ope_type)
        end
        local oRsp = WNH.on_depot_modify_combat_vehicle_rsp
        WNH.on_depot_modify_combat_vehicle_rsp = function(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                knapsack_vst = F.mergeInjectedIntoVehicleSlotList(knapsack_vst)
            end
            oRsp(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                F.syncVehicleSlotsToDataMgr()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
                if not (_G.AddOutfitLobbyVeh and _G.AddOutfitLobbyVeh.manual) then
                    pcall(F.applyVehicleSkinsToPC)
                end
                F.persistMarkDirty()
            end
        end
    end)
    pcall(function()
        local gsm = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.golden_suit_module)
        if gsm and gsm.VehicleNeedClothes and not gsm._AddOutfitVehClothesHooked then
            gsm._AddOutfitVehClothesHooked = true
            local o = gsm.VehicleNeedClothes
            gsm.VehicleNeedClothes = function(self, vehicleId)
                vehicleId = tonumber(vehicleId)
                if vehicleId and F.isInjectedRes(vehicleId) then return 0 end
                return o(self, vehicleId)
            end
        end
    end)
    pcall(function()
        local mod = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
        if mod._FillVehicleSkinList then
            if not _G.AddOutfitVehFillOrig then
                _G.AddOutfitVehFillOrig = mod._FillVehicleSkinList
            end
            local o = _G.AddOutfitVehFillOrig
            mod._FillVehicleSkinList = function(self, playerInfo, uPlayerController)
                F.mergeVstIntoPlayerInfo(playerInfo)
                return o(self, playerInfo, uPlayerController)
            end
            mod._AddOutfitFillVehHooked = true
        end
    end)
    pcall(function()
        local classMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinItem")
        if not classMod or not classMod.__inner_impl then return end
        local impl = classMod.__inner_impl
        if not _G.AddOutfitVehOrigClick then
            _G.AddOutfitVehOrigClick = impl.OnClickSkinButton
        end
        local oClick = _G.AddOutfitVehOrigClick
        impl.OnClickSkinButton = function(self)
            -- [SỬA LỖI SKIN REAL] Nếu công tắc Mod đang TẮT, bỏ qua xử lý của Mod và trả thẳng về Nút bấm gốc của Game!
            if not _G.LexusConfig.ModSkin then
                if oClick then return oClick(self) end
                return
            end

            local resID = tonumber(self.resID)
            if resID and resID > 0 then
                if F.matchApplyVehicleSkin(resID) then
                    pcall(function()
                        if EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL and EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK then
                            EventSystem:postEvent(EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL, EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK)
                        end
                    end)
                end
                return
            end
            return oClick(self)
        end
        if not _G.AddOutfitVehOrigRefresh then
            _G.AddOutfitVehOrigRefresh = impl.OnRefresh
        end
        local oRefresh = _G.AddOutfitVehOrigRefresh
        impl.OnRefresh = function(self, resID, selectIndex)
            oRefresh(self, resID, selectIndex)
            if self.resID and tonumber(self.resID) and tonumber(self.resID) > 0 then
                if F.isResourcesReady(self.resID) then
                    pcall(function()
                        local PufferConst = require("client.slua.logic.download.puffer_const")
                        self.dowloadState = PufferConst.ENUM_DownloadState.Done
                        self.UIRoot.Image_Download:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                        self:SetWidgetVisible(self.UIRoot.Image_Mask, false)
                    end)
                else
                    F.requestResourceDownload(self.resID)
                end
            end
        end
        classMod._AddOutfitSkinClickHooked = true
    end)
    pcall(function()
        local utilMod = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
        if utilMod.CheckHasUnLockFeature and not utilMod._AddOutfitVehPlateHooked then
            utilMod._AddOutfitVehPlateHooked = true
            local orig = utilMod.CheckHasUnLockFeature
            utilMod.CheckHasUnLockFeature = function(ft, uid, itemId)
                local id = tonumber(itemId)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return orig(ft, uid, itemId)
            end
        end
    end)
    pcall(function()
        local panelMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinAndMusicPanel")
        if panelMod and panelMod.__inner_impl and not panelMod._AddOutfitInitSkinHooked then
            panelMod._AddOutfitInitSkinHooked = true
            local o = panelMod.__inner_impl.InitSkinList
            panelMod.__inner_impl.InitSkinList = function(self)
                F.applyVehicleSkinsToPC(F.getPC())
                return o(self)
            end
        end
    end)
    pcall(function()
        local VUC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleUserComponent")
        if not VUC then return end
        if not _G.AddOutfitVehOrigEnter then
            _G.AddOutfitVehOrigEnter = VUC.SendUIMsgWhenEnterVehicleCompleted
        end
        local oEnter = _G.AddOutfitVehOrigEnter
        VUC.SendUIMsgWhenEnterVehicleCompleted = function(self)
            oEnter(self)
            pcall(function()
                if slua.isValid(self.Vehicle) then
                    F.autoApplyVehicleSkinOnEnter(self.Vehicle)
                end
            end)
        end
        VUC._AddOutfitEnterVehHooked = true
    end)
end

function F.hookWeaponWear()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        local o = HT.IsWeaponWear
        HT.IsWeaponWear = function(insId)
            insId = tonumber(insId)
            if F.isInjectedIns(insId) then
                local c = F.cache()
                local Arm = require("client.logic.armory.logic_armory")
                for wid, w in pairs(c.weapons) do
                    if tonumber(w.insID) == insId then
                        if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                            return tonumber(Arm.rsp_list.install_list[wid].skin_id) == insId
                        end
                        return true
                    end
                end
            end
            return o(insId)
        end
    end)
end

function F.hookNotice()
    pcall(function()
        if DataMgr and not DataMgr._AddOutfitExpireHooked then
            DataMgr._AddOutfitExpireHooked = true
            local oValid = DataMgr.IsValidTime
            DataMgr.IsValidTime = function(expireTS)
                if expireTS == nil or tonumber(expireTS) == 0 then return true end
                if oValid and oValid(expireTS) then return true end
                local inMatch = false
                pcall(function()
                    inMatch = GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
                end)
                if not inMatch then return true end
                return false
            end
        end
    end)
end

function F.wrapWardrobeClick(classMod, key)
    if not classMod or not classMod[key] or classMod["_AddOutfitWrap_" .. key] then return end
    classMod["_AddOutfitWrap_" .. key] = true
    local orig = classMod[key]
    classMod[key] = function(self, widget, index)
        local itemData = self.LoopScrollGrid_Normal and self.LoopScrollGrid_Normal:GetItemData(index)
        if itemData then
            F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
            F.ensureDepotItemValid(itemData.ins_id, itemData.res_id)
        end
        return orig(self, widget, index)
    end
end

function F.hookWardrobeWearClicks()
    if _G.AddOutfitWearClickHooked then return end
    _G.AddOutfitWearClickHooked = true
    F.hookNotice()
    pcall(function()
        local avatarClass = require("client.slua.umg.Wardrobe.subtab_avatar")
        F.wrapWardrobeClick(avatarClass, "OnClickItem")
        F.wrapWardrobeClick(avatarClass, "ClickAvatarItem")
    end)
    pcall(function()
        local suitClass = require("client.slua.umg.Wardrobe.subtab_suit")
        F.wrapWardrobeClick(suitClass, "OnClickItem")
    end)
    pcall(function()
        local bagClass = require("client.slua.umg.Wardrobe.subtab_bag")
        F.wrapWardrobeClick(bagClass, "OnClickItem")
    end)
end

function F.hookAvatarValid()
    pcall(function()
        local path = "GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent"
        local comp = require(path)
        if comp and comp.CheckItemValid then
            local o = comp.CheckItemValid
            comp.CheckItemValid = function(self, resID)
                if F.isInjectedRes(resID) then return true end
                return o(self, resID)
            end
        end
    end)
end

function F.isInRealMatch()
    local ok, r = pcall(function()
        return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
    end)
    return ok and r == true
end

function F.getLocalChar()
    local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GD then return nil end
    local char = GD.GetPlayerCharacter()
    if char and slua.isValid(char) then return char end
    return nil
end

function F.getWAC(char)
    local w = char and char.GetCurrentWeapon and char:GetCurrentWeapon()
    if slua.isValid(w) and slua.isValid(w.WeaponAvatarComponent) then
        return w.WeaponAvatarComponent
    end
    return nil
end

function F.notify(msg)
    if not DEBUG then return end
    pcall(function() if ShowNotice then ShowNotice("[AddOutfit] " .. tostring(msg)) end end)
end

function F.getDesiredOutfit()
    if MATCH_CONFIG.outfitRes and MATCH_CONFIG.outfitRes > 0 then
        return MATCH_CONFIG.outfitRes
    end
    local wornSuitRes
    pcall(function()
        local _, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        wornSuitRes = tonumber(res)
    end)
    if wornSuitRes and wornSuitRes > 0 then return wornSuitRes end
    local tshirtWorn = false
    pcall(function()
        local ins = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isTshirtRes(r) end)
        tshirtWorn = ins ~= nil
    end)
    if tshirtWorn then return nil end
    F.syncBodyCacheFromLobby()
    local c = F.cache()
    return c.outfitRes
end

function F.matchApplyOutfit(char)
    local outfitRes = F.getDesiredOutfit()
    if not outfitRes then return true end
    if not F.isResourcesReady(outfitRes) then
        F.requestResourceDownload(outfitRes)
        return false
    end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local ok = F.setMakeSkin(comp, outfitRes, F.CUST_SLOT.ClothesEquipemtSlot, { allowPutOn = true })
    return ok
end

function F.getDesiredHat()
    if MATCH_CONFIG.hatRes and tonumber(MATCH_CONFIG.hatRes) > 0 then
        return tonumber(MATCH_CONFIG.hatRes)
    end
    F.syncHatCacheFromLobby()
    local h = F.cache().hatRes
    if h and tonumber(h) > 0 then return tonumber(h) end
    return tonumber(_G.AddOutfitLastLobbyHatRes) or nil
end

function F.ensureSkinDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return end
    _G.skinIdCache = _G.skinIdCache or {}
    if not _G.skinIdCache[resID] then
        F.requestResourceDownload(resID)
        _G.skinIdCache[resID] = true
    end
end

function F.syncGlobalWearSkins()
    _G.CustSlotType = F.CUST_SLOT
    _G.skinIdCache = _G.skinIdCache or {}
    _G.HatSkin = tonumber(F.getDesiredHat()) or 0
    local outfit = F.getDesiredOutfit()
    _G.SuitSkin = tonumber(outfit)
        or tonumber(F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby))
        or 0
    _G.PantsSkin = tonumber(F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby)) or 0
    _G.ShoesSkin = tonumber(F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby)) or 0
    _G.GlovesSkin = tonumber(F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby)) or 0
    _G.MaskSkin = tonumber(F.getDesiredMask()) or 0
    _G.GlassSkin = tonumber(F.getDesiredGlass()) or 0
    _G.GliderSkin = tonumber(F.getDesiredGliderRes()) or 0
    _G.ParachuteSkin = tonumber(F.getDesiredParachuteRes()) or 0
end

function F.setMakeSkinAtIndex(comp, applyIdx, resID, slotID)
    resID = tonumber(resID)
    slotID = tonumber(slotID)
    applyIdx = tonumber(applyIdx)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotID or applyIdx == nil then
        return false
    end
    local changed = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local equipment = applyData:Get(applyIdx)
        if equipment and equipment.SlotID == slotID then
            local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
            if cur ~= resID then
                F.ensureSkinDownload(resID)
                equipment.ItemId = resID
                if equipment.ItemID ~= nil then equipment.ItemID = resID end
                applyData:Set(applyIdx, equipment)
                changed = true
            end
        end
    end)
    return changed
end

function F.applySlotSkinBatch(comp, entries, opts)
    opts = opts or {}
    if not comp or not slua.isValid(comp) or not entries then return false end
    local changed, anyOk = false, false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for _, e in ipairs(entries) do
            local itemId, slotId = tonumber(e[1]), tonumber(e[2])
            if itemId and itemId > 0 and slotId then
                F.ensureSkinDownload(itemId)
                for i = 0, num - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotId then
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur == itemId then
                            anyOk = true
                        elseif cur ~= itemId then
                            equipment.ItemId = itemId
                            if equipment.ItemID ~= nil then equipment.ItemID = itemId end
                            applyData:Set(i, equipment)
                            changed = true
                            anyOk = true
                        end
                        break
                    end
                end
            end
        end
        if (changed or opts.forceRep) and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return anyOk or changed
end

function F.setMakeSkin(comp, resID, slotID, opts)
    -- [CHỐT CHẶN 100%] Từ chối vẽ Skin VIP (>1000000) lên cơ thể nếu công tắc tắt
    if not _G.LexusConfig.ModSkin and tonumber(resID) and tonumber(resID) > 1000000 then return false end

    opts = opts or {}
    slotID, resID = tonumber(slotID), tonumber(resID)
    if not comp or not slua.isValid(comp) or not slotID or not resID or resID <= 0 then return false end
    local changed = false
    local already = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for i = 0, num - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur == resID then
                    already = true
                elseif cur ~= resID then
                    F.ensureSkinDownload(resID)
                    equipment.ItemId = resID
                    if equipment.ItemID ~= nil then equipment.ItemID = resID end
                    applyData:Set(i, equipment)
                    changed = true
                end
                break
            end
        end
        if changed and not opts.skipRep and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
        if opts.inAir and comp.PutOnCustomEquipmentByID then
            comp:PutOnCustomEquipmentByID(resID)
        end
    end)
    if already or changed then return true end
    if opts.allowPutOn and comp.PutOnCustomEquipmentByID then
        pcall(function() comp:PutOnCustomEquipmentByID(resID) end)
        return true
    end
    return false
end
F.setSlotSkin = F.setMakeSkin

_G.setMakeSkin = function(applyIdx, itemId, applyEquipSlot)
    local char = F.getLocalChar()
    if not char then return end
    local comp = F.getAvatarComp2(char)
    if not comp then return end
    if F.setMakeSkinAtIndex(comp, applyIdx, itemId, applyEquipSlot) then
        pcall(function()
            if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
        end)
    end
end

function F.patchWearNetAvatar(comp, resID, slotName, noForceShow)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotName then return false end
    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local slot = EAvatarSlotType[slotName]
        if not slot then return end
        local sync = comp.GetSlotSyncData and comp:GetSlotSyncData(slot)
        if sync then
            sync.ItemID = resID
            if sync.FakeItemID ~= nil then sync.FakeItemID = resID end
            sync.OperationType = ESyncOperation.PutOn
            if comp.ChangeSlotSyncData then
                comp:ChangeSlotSyncData(sync)
                ok = true
            end
        end
        if not noForceShow and comp.SetAvatarVisibility then
            comp:SetAvatarVisibility(slot, true, true)
        end
    end)
    return ok
end

function F.patchHatNetAvatar(comp, hatRes)
    return F.patchWearNetAvatar(comp, hatRes, "EAvatarSlotType_HatEquipemtSlot")
end

function F.matchApplyWearItem(char, resID, slotID, label, opts)
    if not resID or resID <= 0 then return true end
    slotID = slotID or F.resToCustSlot(resID)
    if not slotID then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    opts = opts or {}
    opts.allowPutOn = true
    local ok = F.setMakeSkin(comp, resID, slotID, opts)
    return ok
end

function F.getDesiredMask()
    if MATCH_CONFIG.maskRes and tonumber(MATCH_CONFIG.maskRes) > 0 then
        return tonumber(MATCH_CONFIG.maskRes)
    end
    F.syncFaceCacheFromLobby()
    local m = F.cache().maskRes
    if m and tonumber(m) > 0 then return tonumber(m) end
    return tonumber(_G.AddOutfitLastLobbyMaskRes) or nil
end

function F.getDesiredGlass()
    if MATCH_CONFIG.glassRes and tonumber(MATCH_CONFIG.glassRes) > 0 then
        return tonumber(MATCH_CONFIG.glassRes)
    end
    F.syncFaceCacheFromLobby()
    local g = F.cache().glassRes
    if g and tonumber(g) > 0 then return tonumber(g) end
    return tonumber(_G.AddOutfitLastLobbyGlassRes) or nil
end

function F.matchApplyFaceWear(char)
    local maskRes = F.getDesiredMask()
    local glassRes = F.getDesiredGlass()
    if (not maskRes or maskRes <= 0) and (not glassRes or glassRes <= 0) then
        return true
    end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local net = comp.NetAvatarData
        local applyData = net and net.SlotSyncData

        local function forceApplySlot(resID, slotID, slotNameStr)
            if not resID or resID <= 0 then return end
            
            local slotEnum = EAvatarSlotType and EAvatarSlotType[slotNameStr]
            local needRep = false
            
            -- 1. GHI ĐÈ DATA MẠNG (Chống lỗi không đồng bộ)
            if applyData and slua.isValid(applyData) then
                local found = false
                for i = 0, applyData:Num() - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotID then
                        found = true
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur ~= resID then
                            F.ensureSkinDownload(resID)
                            equipment.ItemId = resID
                            if equipment.ItemID ~= nil then equipment.ItemID = resID end
                            if equipment.FakeItemID ~= nil then equipment.FakeItemID = resID end
                            applyData:Set(i, equipment)
                            needRep = true
                        end
                        break
                    end
                end
                
                if not found then
                    F.ensureSkinDownload(resID)
                    local entry = import("AvatarSyncData")()
                    entry.SlotID = slotID
                    entry.ItemId = resID
                    entry.ItemID = resID
                    entry.FakeItemID = resID
                    entry.OperationType = ESyncOperation.PutOn
                    applyData:Add(entry)
                    needRep = true
                end
            end

            -- [LOGIC NGỦ ĐÔNG] - TỐI ƯU FPS TUYỆT ĐỐI
            _G.FaceWearStateCache = _G.FaceWearStateCache or {}
            -- Tạo ID định danh riêng biệt cho nhân vật hiện tại tránh trùng lặp
            local cacheKey = tostring(comp) .. "_" .. tostring(slotID)

            if needRep or _G.FaceWearStateCache[cacheKey] ~= resID then
                -- Lần đầu tiên ép hiển thị / Hoặc ID Skin bị thay đổi -> Chạy Full C++
                if slotEnum then
                    if comp.CancelHideAvatarBySlot then comp:CancelHideAvatarBySlot(slotEnum) end
                    if comp.SetAvatarVisibility then comp:SetAvatarVisibility(slotEnum, true, true) end
                end
                if comp.PutOnCustomEquipmentByID then
                    comp:PutOnCustomEquipmentByID(resID)
                end
                
                -- Cập nhật Cache để vòng lặp sau đi vào Ngủ Đông
                _G.FaceWearStateCache[cacheKey] = resID
                ok = true -- Bật cờ để gọi OnRep_BodySlotStateChanged (vẽ lại Mesh)
            else
                -- TRẠNG THÁI NGỦ ĐÔNG: Data đã đúng, Mesh 3D đã được render.
                -- Chỉ chạy hàm cực nhẹ CancelHide để chống Game tự ẩn khi nhặt Mũ bảo hiểm (1,2,3).
                -- BỎ QUA việc Render lại Mesh để tránh Drop FPS.
                if slotEnum and comp.CancelHideAvatarBySlot then 
                    comp:CancelHideAvatarBySlot(slotEnum) 
                end
            end
        end

        -- Gọi lệnh ép cho Mặt nạ (Mask)
        forceApplySlot(maskRes, F.CUST_SLOT.FaceEquipemtSlot, "EAvatarSlotType_FaceEquipemtSlot")
        -- Gọi lệnh ép cho Mắt kính (Glass)
        forceApplySlot(glassRes, F.CUST_SLOT.GlassEquipemtSlot, "EAvatarSlotType_GlassEquipemtSlot")
        
        -- Cập nhật hình ảnh 3D CHỈ KHI THOÁT KHỎI NGỦ ĐÔNG (Khi cần thiết)
        if ok and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return ok
end

function F.getDesiredWear(configKey, cacheResKey, globalKey, syncFn)
    local fixed = MATCH_CONFIG[configKey] and tonumber(MATCH_CONFIG[configKey])
    if fixed and fixed > 0 then return fixed end
    local persistKey = cacheResKey and cacheResKey:gsub("Res$", "")
    if persistKey and PERSIST.configSlots then
        local pr = tonumber(PERSIST.configSlots[persistKey])
        if pr and pr > 0 then return pr end
    end
    if syncFn then syncFn() end
    local v = F.cache()[cacheResKey]
    if v and tonumber(v) > 0 then return tonumber(v) end
    return tonumber(_G[globalKey]) or nil
end

-- ==========================================================
    -- HỆ THỐNG MŨ/BALO VIP (AUTO LEVEL 1, 2, 3 + SYNC INGAME)
    -- ==========================================================
    local GAME_HELMET_LEVEL = {
        [502001] = 1, [502004] = 1, [502002] = 2, [502005] = 2, [502003] = 3,
    }
    local GAME_BAG_LEVEL = {
        [501001] = 1, [501004] = 1, [501002] = 2, [501005] = 2, [501003] = 3,
    }
    local EQUIP_LEVEL_SETS = {}
    local _equipLevelByRes = {}

    function F.registerEquipLevelSet(catalog, lv1, lv2, lv3, slot)
        catalog = tonumber(catalog)
        if not catalog then return end
        local set = { catalog = catalog, lv1 = tonumber(lv1) or 0, lv2 = tonumber(lv2) or 0, lv3 = tonumber(lv3) or 0, slot = slot or "helmet" }
        EQUIP_LEVEL_SETS[catalog] = set
        for _, rid in ipairs({ catalog, set.lv1, set.lv2, set.lv3 }) do
            if rid and rid > 0 then _equipLevelByRes[rid] = set end
        end
    end

    local EQUIP_LEVEL_RANGES = {
        { base = 1502000000, slot = "helmet" },
        { base = 1501000000, slot = "bag"    },
    }

    function F.findEquipLevelRange(resID)
        resID = tonumber(resID)
        if not resID then return nil end
        for _, r in ipairs(EQUIP_LEVEL_RANGES) do
            if resID >= r.base and resID < r.base + 1000000 then return r end
        end
        return nil
    end

    function F.detectLevelFromPattern(resID)
        resID = tonumber(resID)
        if not resID then return nil, nil end
        local r = F.findEquipLevelRange(resID)
        if not r then return nil, nil end
        if resID < r.base + 1000 or resID >= r.base + 4000 then return nil, nil end
        local tail = resID - r.base
        local levelDigit = math.floor(tail / 1000)
        if levelDigit >= 1 and levelDigit <= 3 then
            return levelDigit, r.base + (tail - levelDigit * 1000)
        end
        return nil, nil
    end

    function F.buildPatternLevelSet(catalog)
        catalog = tonumber(catalog)
        if not catalog then return nil end
        local r = F.findEquipLevelRange(catalog)
        if not r then return nil end
        local tail = catalog - r.base
        if tail < 0 or tail >= 1000 then return nil end
        return { catalog = catalog, lv1 = catalog + 1000, lv2 = catalog + 2000, lv3 = catalog + 3000, slot = r.slot }
    end

    function F.getEquipLevelSet(resID)
        resID = tonumber(resID)
        if not resID then return nil end
        local set = _equipLevelByRes[resID]
        if set then return set end
        local level, catalog = F.detectLevelFromPattern(resID)
        if catalog then
            if EQUIP_LEVEL_SETS[catalog] then return EQUIP_LEVEL_SETS[catalog] end
            if level then return F.buildPatternLevelSet(catalog) end
        end
        local direct = F.buildPatternLevelSet(resID)
        if direct then
            _equipLevelByRes[resID] = direct
            if direct.lv1 > 0 then _equipLevelByRes[direct.lv1] = direct end
            if direct.lv2 > 0 then _equipLevelByRes[direct.lv2] = direct end
            if direct.lv3 > 0 then _equipLevelByRes[direct.lv3] = direct end
        end
        return direct
    end

    function F.normalizeEquipCatalogRes(resID)
        resID = tonumber(resID)
        if not resID or resID <= 0 then return 0 end
        local set = F.getEquipLevelSet(resID)
        if set then return set.catalog end
        return resID
    end

    function F.detectLevelFromEquipRes(resID)
        resID = tonumber(resID)
        if not resID then return nil end
        local set = F.getEquipLevelSet(resID)
        if set then
            if resID == set.lv1 then return 1
            elseif resID == set.lv2 then return 2
            elseif resID == set.lv3 then return 3 end
        end
        return F.detectLevelFromPattern(resID)
    end

    function F.mapEquipLevelSet(set, level)
        if not set then return 0 end
        level = tonumber(level) or 3
        if level == 1 then return set.lv1 or 0
        elseif level == 2 then return set.lv2 or 0 end
        return set.lv3 or 0
    end

    function F.mapEquipSkinRes(resID, level)
        resID, level = tonumber(resID), tonumber(level) or 3
        if not resID or resID <= 0 then return 0 end
        local catalogRes = F.normalizeEquipCatalogRes(resID)
        local set = F.getEquipLevelSet(catalogRes)
        if set then
            local mapped = F.mapEquipLevelSet(set, level)
            if mapped > 0 then return mapped end
        end
        local mapped = 0
        pcall(function()
            local itemMappingCfg = CDataTable.GetTableData("BackpackMapping", catalogRes)
            if itemMappingCfg then
                if level == 1 then mapped = tonumber(itemMappingCfg.SkinItemIDLv1) or 0
                elseif level == 2 then mapped = tonumber(itemMappingCfg.SkinItemIDLv2) or 0
                else mapped = tonumber(itemMappingCfg.SkinItemIDLv3) or 0 end
            end
        end)
        if mapped > 0 then return mapped end
        if F.isInjectedRes(catalogRes) then return catalogRes end
        return 0
    end

    function F.buildEquipSkinLists(resID)
        resID = F.normalizeEquipCatalogRes(resID)
        return { F.mapEquipSkinRes(resID, 1), F.mapEquipSkinRes(resID, 2), F.mapEquipSkinRes(resID, 3) }
    end

    function F.detectEquipLevelFromBaseId(baseId, catalogResID)
        baseId, catalogResID = tonumber(baseId), tonumber(catalogResID)
        if not baseId or baseId <= 0 then return nil end
        local level
        pcall(function()
            catalogResID = catalogResID and F.normalizeEquipCatalogRes(catalogResID) or catalogResID
            if catalogResID then
                local set = F.getEquipLevelSet(catalogResID)
                if set then
                    if baseId == set.lv1 then level = 1
                    elseif baseId == set.lv2 then level = 2
                    elseif baseId == set.lv3 then level = 3 end
                end
                if not level then
                    local m = CDataTable.GetTableData("BackpackMapping", catalogResID)
                    if m then
                        if tonumber(m.SkinItemIDLv1) == baseId then level = 1
                        elseif tonumber(m.SkinItemIDLv2) == baseId then level = 2
                        elseif tonumber(m.SkinItemIDLv3) == baseId then level = 3 end
                    end
                end
            end
            if not level then
                local patLevel, patCatalog = F.detectLevelFromPattern(baseId)
                if patLevel and (not catalogResID or patCatalog == catalogResID) then level = patLevel end
            end
            if not level then level = GAME_HELMET_LEVEL[baseId] or GAME_BAG_LEVEL[baseId] end
            if not level and baseId >= 1505000001 and baseId <= 1505000003 then level = baseId - 1505000000 end
            if not level then
                local BU = import("BackpackUtils")
                if BU and BU.GetEquipmentHelmetLevel then
                    local hl = BU.GetEquipmentHelmetLevel(baseId)
                    if hl and hl >= 1 and hl <= 3 then level = hl end
                end
                if not level and BU and BU.GetEquipmentBagLevel then
                    local bl = BU.GetEquipmentBagLevel(baseId)
                    if bl and bl >= 1 and bl <= 3 then level = bl end
                end
            end
        end)
        return level
    end

    function F.isBaseEquipItemId(itemId)
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 then return false end
        if GAME_HELMET_LEVEL[itemId] or GAME_BAG_LEVEL[itemId] then return true end
        if itemId >= 1505000001 and itemId <= 1505000100 then return true end
        if itemId >= 1501000000 and itemId < 1502000000 then return true end
        if itemId >= 502001 and itemId <= 502999 then return true end
        if itemId >= 501001 and itemId <= 501999 then return true end
        return false
    end

    function F.resolveMatchEquipSkin(catalogResID, baseItemID)
        catalogResID = F.normalizeEquipCatalogRes(catalogResID)
        if not catalogResID or catalogResID <= 0 then return 0 end
        local level = F.detectEquipLevelFromBaseId(baseItemID, catalogResID) or 3
        return F.mapEquipSkinRes(catalogResID, level)
    end

    function F.getCharEquipLevel(char, slotID)
        local found = nil
        pcall(function()
            local comp = char and char.CharacterAvatarComp2_BP
            if not slua.isValid(comp) then return end
            local NetAvatarData = slua.IndexReference(comp, "NetAvatarData")
            if not NetAvatarData then return end
            local TempSlotSyncData = slua.IndexReference(NetAvatarData, "SlotSyncData")
            if not TempSlotSyncData then return end
            local n = TempSlotSyncData:Num()
            for i = 0, n - 1 do
                local AvatarSynData = TempSlotSyncData:Get(i)
                if AvatarSynData and AvatarSynData.SlotID == slotID and AvatarSynData.ItemID and AvatarSynData.ItemID > 0 then
                    found = AvatarSynData.ItemID
                    return
                end
            end
        end)
        return found
    end

    function F.isWearingEquip(char, slot)
        local slotID = (slot == "helmet") and 9 or (slot == "bag") and 8 or nil
        if not slotID then return false end
        local itemID = F.getCharEquipLevel(char, slotID)
        if itemID and itemID > 0 then return true end
        local wearing = false
        pcall(function()
            local pc = F.getPC()
            if not pc or not slua.isValid(pc) then return end
            if pc.PlayerState and pc.PlayerState.MetroPlayerStateAvatarFeature then
                local psEquip = pc.PlayerState.MetroPlayerStateAvatarFeature.EquipmentAvatarData
                if psEquip then
                    if slot == "helmet" and psEquip.HelmetAvatar and psEquip.HelmetAvatar > 0 then wearing = true
                    elseif slot == "bag" and psEquip.BagAvatar and psEquip.BagAvatar > 0 then wearing = true end
                end
            end
        end)
        return wearing
    end

    local EQUIP_APPLY = { lastBagWrite = 0, lastHelmetWrite = 0 }

function F.levelSkinID(baseSkin, level)
    level = tonumber(level) or 1
    if level < 1 then level = 1 end
    local mapped = 0
    pcall(function()
        local t = CDataTable.GetTableData("BackpackMapping", baseSkin)
        if t then
            if level <= 1 then mapped = tonumber(t.SkinItemIDLv1) or 0
            elseif level == 2 then mapped = tonumber(t.SkinItemIDLv2) or 0
            else mapped = tonumber(t.SkinItemIDLv3) or 0 end
        end
    end)
    if mapped > 0 then return mapped end
    return baseSkin + (level - 1) * 1000
end

function F.applyEquipSkinToComp(comp, bagRes, helmetRes)
    local applied, found = false, false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local BackpackUtils = import("BackpackUtils")
        local function doSlot(slotEnum, res, levelFn, lastKey)
            res = tonumber(res) or 0
            if res <= 0 or not slotEnum then return end
            local sync = comp.GetSlotSyncData and comp:GetSlotSyncData(slotEnum)
            if not sync then return end
            local cur = tonumber(sync.ItemID) or 0
            local addID = tonumber(sync.AdditionalItemID) or 0
            if cur <= 0 and addID <= 0 then return end
            found = true
            local lvl = 1
            pcall(function()
                if levelFn then lvl = levelFn(addID > 0 and addID or cur) or 1 end
            end)
            if lvl < 1 then lvl = 1 end
            local target = F.levelSkinID(res, lvl)
            if target > 0 and cur ~= target then
                sync.ItemID = target
                comp:ChangeSlotSyncData(sync)
                applied = true
                EQUIP_APPLY[lastKey] = target
            end
        end
        doSlot(EAvatarSlotType.EAvatarSlotType_BackpackEquipemtSlot, bagRes,
               BackpackUtils.GetEquipmentBagLevel, "lastBagWrite")
        doSlot(EAvatarSlotType.EAvatarSlotType_HelmetEquipemtSlot, helmetRes,
               BackpackUtils.GetEquipmentHelmetLevel, "lastHelmetWrite")
    end)
    return applied, found
end

function F.matchApplyEquipmentSkin(char, bagRes, helmetRes)
    bagRes = tonumber(bagRes) or 0
    helmetRes = tonumber(helmetRes) or 0
    if bagRes <= 0 and helmetRes <= 0 then return true end
    local comp = char.CharacterAvatarComp2_BP
    if not slua.isValid(comp) then return false end

    local applied, found = F.applyEquipSkinToComp(comp, bagRes, helmetRes)

    if applied then
        pcall(function()
            if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
        end)
        return true
    end
    return found
end

function F.hookEquipmentRectify()
    _G.AddOutfitEquipRectifyFn = function(self)
        pcall(function()
            if self.IsLobbyActor and self:IsLobbyActor() then return end
            if not (self.IsSelf and self:IsSelf()) then return end
            local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
            local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
            if (tonumber(bagRes) or 0) <= 0 and (tonumber(helmetRes) or 0) <= 0 then return end
            F.applyEquipSkinToComp(self, bagRes, helmetRes)
        end)
    end
    pcall(function()
        local MCAC = require("GameLua.Mod.TPlan.Component.MetroCharacterAvatarComponent")
        if MCAC._AddOutfitRectifyHooked then return end
        MCAC._AddOutfitRectifyHooked = true
        local o = MCAC.ProcessClientAvatarRectify
        MCAC.ProcessClientAvatarRectify = function(self)
            o(self)
            if _G.AddOutfitEquipRectifyFn then _G.AddOutfitEquipRectifyFn(self) end
        end
    end)
end

function F.hookBackpackValid()
    if _G.DEV_WARDROBE_BP_HOOKED then return end
    _G.DEV_WARDROBE_BP_HOOKED = true
    pcall(function()
        local BU = import("BackpackUtils")
        if BU and BU.GetBPIDByResID then
            local orig = BU.GetBPIDByResID
            BU.GetBPIDByResID = function(resID)
                resID = tonumber(resID)
                if resID and F.isInjectedRes(resID) then
                    local bp = orig(resID)
                    if bp and bp > 0 then return bp end
                    return resID
                end
                return orig(resID)
            end
        end
    end)
    pcall(function()
        local AU = import("AvatarUtils")
        if AU and AU.GetBPIDByResID then
            local orig = AU.GetBPIDByResID
            AU.GetBPIDByResID = function(resID, ...)
                resID = tonumber(resID)
                if resID and F.isInjectedRes(resID) then
                    local bp = orig(resID, ...)
                    if bp and bp > 0 then return bp end
                    return resID
                end
                return orig(resID, ...)
            end
        end
    end)
end



    function F.hookEquipMapping()
        pcall(function()
            if DataMgr and not DataMgr._lava_equip_map_hooked then
                DataMgr._lava_equip_map_hooked = true
                local orig = DataMgr.GetEquipmentItemIDByResID
                DataMgr.GetEquipmentItemIDByResID = function(level, itemResID)
                    -- [SỬA LỖI SKIN REAL] Nếu công tắc TẮT, ép game dùng hàm gốc để giữ lại Skin Mũ/Balo thật!
                    if not _G.LexusConfig.ModSkin then
                        if orig then return orig(level, itemResID) end
                        return 0
                    end

                    level, itemResID = tonumber(level) or 3, tonumber(itemResID)
                    local catalogRes = F.normalizeEquipCatalogRes(itemResID)
                    local r = orig(level, catalogRes)
                    if r and r > 0 then return r end
                    
                    if F.isInjectedIns(itemResID) then
                        local resID = R.insToRes[itemResID]
                        if resID then return F.levelSkinID(resID, level) end
                    end
                    if F.isInjectedRes(itemResID) then
                        return F.levelSkinID(itemResID, level)
                    end
                    return r or 0
                end
            end
        end)
        pcall(function()
            local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
            if CAC._lava_equip_skin_hooked then return end
            CAC._lava_equip_skin_hooked = true
            local orig3 = CAC.GetEquipmentSkinItemID
            CAC.GetEquipmentSkinItemID = function(self, InItemID)
                if self.IsSelf and not self:IsSelf() then return orig3(self, InItemID) end
                
                -- [SỬA LỖI SKIN REAL] Trả về Skin thật của Game nếu ModSkin tắt
                if not _G.LexusConfig.ModSkin then return orig3(self, InItemID) end

                local cch = F.cache()
                InItemID = tonumber(InItemID) or 0

                local function tryGetSkin(catalogRes)
                    if not catalogRes or catalogRes <= 0 then return 0 end
                    catalogRes = F.normalizeEquipCatalogRes(catalogRes)
                    local skin = F.resolveMatchEquipSkin(catalogRes, InItemID)
                    if skin > 0 then return skin end
                    for lvl = 1, 3 do
                        local s = F.mapEquipSkinRes(catalogRes, lvl)
                        if s > 0 then return s end
                    end
                    return 0
                end

                local origResult = orig3(self, InItemID)
                if origResult and origResult > 0 and origResult ~= InItemID then return origResult end

                local isHelmetQuery = GAME_HELMET_LEVEL[InItemID] ~= nil or (InItemID >= 502001 and InItemID <= 502999)
                local isBagQuery = GAME_BAG_LEVEL[InItemID] ~= nil or (InItemID >= 501001 and InItemID <= 501999)
                local char = F.getLocalChar()

                if isHelmetQuery and cch.helmetRes and cch.helmetRes > 0 then
                    if char and F.isWearingEquip(char, "helmet") then
                        local skin = tryGetSkin(cch.helmetRes)
                        if skin > 0 then return skin end
                    end
                end
                if isBagQuery and cch.bagRes and cch.bagRes > 0 then
                    if char and F.isWearingEquip(char, "bag") then
                        local skin = tryGetSkin(cch.bagRes)
                        if skin > 0 then return skin end
                    end
                end
                return origResult
            end
            
            local origEquipFinish = CAC.OnAvatarEquipFinish
            CAC.OnAvatarEquipFinish = function(self, slotType, isEquipped, itemID)
                if origEquipFinish then origEquipFinish(self, slotType, isEquipped, itemID) end
                if not isEquipped then return end
                if not self.IsSelf or not self:IsSelf() then return end
                
                if not _G.LexusConfig.ModSkin then return end -- Ngừng load giao diện Mod nếu tắt

                pcall(function()
                    if self.IsLobbyActor and self:IsLobbyActor() then return end
                    local EAvatarSlotType = import("EAvatarSlotType")
                    local cch = F.cache()
                    local isHelmet = slotType == EAvatarSlotType.EAvatarSlotType_HelmetEquipemtSlot
                    local isBag = slotType == EAvatarSlotType.EAvatarSlotType_BackpackEquipemtSlot
                    if (isHelmet and cch.helmetRes and cch.helmetRes > 0)
                        or (isBag and cch.bagRes and cch.bagRes > 0) then
                        local owner = self.GetOwner and self:GetOwner()
                        if owner and slua.isValid(owner) and owner.AddGameTimer then
                            owner:AddGameTimer(0.25, false, function()
                                if slua.isValid(owner) then F.matchApplyEquipSkins(owner) end
                            end)
                        end
                    end
                    F.applyMatchEquipAvatarToController()
                end)
            end
        end)
    end

function F.applyAirborneSlots(char, forceInAir)
    local comp = F.getAvatarComp2(char)
    if not comp or not slua.isValid(comp) then return false end
    pcall(function() F.syncAirborneToDataMgr() end)
    local inAir = forceInAir == true or F.isCharacterAirborne(char)
    local any = false
    local paraRes = F.getDesiredParachuteRes()
    if paraRes and paraRes > 0 then
        any = true
        if not F.isResourcesReady(paraRes) then F.requestResourceDownload(paraRes) end
        F.setMakeSkin(comp, paraRes, F.CUST_SLOT.ParachuteEquipemtSlot, { inAir = inAir })
    end
    local gliderRes = F.getDesiredGliderRes()
    if gliderRes and gliderRes > 0 then
        any = true
        if not F.isResourcesReady(gliderRes) then F.requestResourceDownload(gliderRes) end
        F.setMakeSkin(comp, gliderRes, F.CUST_SLOT.GlideEquipemtSlot, { inAir = inAir })
    end
    return any
end

function F.matchApplyBodyWear(char)
    local pieces = {}
    if not F.getDesiredOutfit() then
        pieces[#pieces + 1] = {
            F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby),
            F.CUST_SLOT.ClothesEquipemtSlot, "تيشرت",
        }
    end
    pieces[#pieces + 1] = { F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.PantsEquipemtSlot, "سروال" }
    pieces[#pieces + 1] = { F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.ShoesEquipemtSlot, "حذاء" }
    pieces[#pieces + 1] = { F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.HandEffectEquipemtSlot, "قفازات" }
    local any, okAll = false, true
    for _, p in ipairs(pieces) do
        local res, slot, label = p[1], p[2], p[3]
        if res and res > 0 then
            any = true
            okAll = F.matchApplyWearItem(char, res, slot, label) and okAll
        end
    end
    local anyAir = F.applyAirborneSlots(char, false)
    if anyAir then any = true end
    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        any = true
        okAll = F.matchApplyEquipmentSkin(char, bagRes, helmetRes) and okAll
    end
    return not any or okAll
end

function F.matchApplyAllSlots(char)
    if not char then return false end
    F.syncGlobalWearSkins()
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local entries = {}
    local function add(skin, slot)
        skin = tonumber(skin)
        if skin and skin > 0 and slot then entries[#entries + 1] = { skin, slot } end
    end
    add(_G.HatSkin, F.CUST_SLOT.HatEquipemtSlot)
    add(_G.SuitSkin, F.CUST_SLOT.ClothesEquipemtSlot)
    add(_G.PantsSkin, F.CUST_SLOT.PantsEquipemtSlot)
    add(_G.ShoesSkin, F.CUST_SLOT.ShoesEquipemtSlot)
    add(_G.GlovesSkin, F.CUST_SLOT.HandEffectEquipemtSlot)
    add(_G.MaskSkin, F.CUST_SLOT.FaceEquipemtSlot)
    add(_G.GlassSkin, F.CUST_SLOT.GlassEquipemtSlot)

    local ok = false
    if #entries > 0 then
        ok = F.applySlotSkinBatch(comp, entries, { forceRep = true })
        if not ok then
            for _, e in ipairs(entries) do
                if F.setMakeSkin(comp, e[1], e[2], { allowPutOn = true }) then ok = true end
            end
        end
    end

    F.applyAirborneSlots(char, false)

    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        ok = F.matchApplyEquipmentSkin(char, bagRes, helmetRes) or ok
    end

    return ok or #entries == 0
end

function F.matchApplyHat(char)
    local hatRes = tonumber(F.getDesiredHat())
    if not hatRes or hatRes <= 0 then return true end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local slotID = F.CUST_SLOT.HatEquipemtSlot
    local ok = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local found = false
        for i = 0, applyData:Num() - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                found = true
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur ~= hatRes then
                    F.ensureSkinDownload(hatRes)
                    equipment.ItemId = hatRes
                    if equipment.ItemID ~= nil then equipment.ItemID = hatRes end
                    if equipment.FakeItemID ~= nil then equipment.FakeItemID = hatRes end
                    applyData:Set(i, equipment)
                end
                ok = true
                break
            end
        end
        if not found then
            F.ensureSkinDownload(hatRes)
            local ESyncOperation = import("ESyncOperation")
            local entry = import("AvatarSyncData")()
            entry.SlotID = slotID
            entry.ItemId = hatRes
            entry.ItemID = hatRes
            entry.FakeItemID = hatRes
            entry.OperationType = ESyncOperation.PutOn
            applyData:Add(entry)
            ok = true
        end
        
    end)
    return ok
end

local _avatarItemsRegistered = false

function F.getDesiredWeaponSkins()
    if PERF.desiredSkins then return PERF.desiredSkins end
    F.syncWeaponCacheFromLobby()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then seen[res] = true; out[#out+1] = res end
    end
    for wid, w in pairs(F.cache().weapons) do
        if wid ~= MELEE_ID and w.resID then add(w.resID) end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, res in pairs(MATCH_CONFIG.weaponSkins) do add(res) end
    end
    PERF.desiredSkins = out
    return out
end

function F._cacheSkinTarget(weaponResID, skin)
    if skin and skin > 0 then PERF.skinTarget[weaponResID] = skin else PERF.skinTarget[weaponResID] = 0 end
    return skin
end

local GUN_MASTER_SYN_SLOT = 7

function F.findSkinSlotInSynData(weapon)
    if not slua.isValid(weapon) then return GUN_MASTER_SYN_SLOT, 0 end
    local arr = weapon.synData
    if not arr or not slua.isValid(arr) then return GUN_MASTER_SYN_SLOT, 0 end
    local count = 0
    pcall(function() count = arr:Num() end)
    for i = 0, math.min(count - 1, 15) do
        local ok2, att = pcall(function() return arr:Get(i) end)
        if ok2 and att then
            local ok3, defRef = pcall(slua.IndexReference, att, "defineID")
            if ok3 and defRef then
                local tid = 0
                pcall(function() tid = tonumber(defRef.TypeSpecificID) or 0 end)
                if tid >= 1000000 then
                    return i, tid
                end
            end
        end
    end
    return GUN_MASTER_SYN_SLOT, 0
end

function F.resolveWeaponTypeID(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return 0 end
    local found = 0
    pcall(function()
        local wc = CDataTable.GetTableData("WeaponConfig", weaponResID)
        if wc then found = tonumber(wc.WeaponID or wc.WeaponId or wc.weaponID or 0) end
    end)
    if found > 0 then return found end
    pcall(function()
        local ic = CDataTable.GetTableData("Item", weaponResID)
        if ic then found = tonumber(ic.WeaponID or ic.weaponId or 0) end
    end)
    return found > 0 and found or weaponResID
end

function F.findTargetSkinForWeaponRes(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return nil end
    local cached = PERF.skinTarget[weaponResID]
    if cached ~= nil then return cached == 0 and nil or cached end

    local memSkin = F.getMatchWeaponSkin(weaponResID)
    if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        memSkin = F.getMatchWeaponSkin(typeID)
        if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    end

    if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[weaponResID] then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponResID])
        if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
    end

    for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
        local wid = F.weaponIdFromSkin(skinRes)
        if wid and tonumber(wid) == weaponResID then return F._cacheSkinTarget(weaponResID, skinRes) end
    end

    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[typeID] then
            local fixed = tonumber(MATCH_CONFIG.weaponSkins[typeID])
            if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
        end
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local wid = F.weaponIdFromSkin(skinRes)
            if wid and tonumber(wid) == typeID then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    local avatarMatch = nil
    pcall(function()
        local AU = import("AvatarUtils")
        local weaponBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(weaponResID), false)
        if not weaponBase or weaponBase <= 0 then return end
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local skinBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(skinRes), false)
            if skinBase and skinBase > 0 and skinBase == weaponBase then
                avatarMatch = skinRes
                return
            end
        end
    end)
    if avatarMatch then return F._cacheSkinTarget(weaponResID, avatarMatch) end

    local c = F.cfg(weaponResID)
    local st = F.subType(c)
    if st and GUN_SUB[st] and MATCH_CONFIG.weaponSkins then
        for _, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            local skinWid = F.weaponIdFromSkin(skinRes)
            if skinWid then
                local sc = F.cfg(tonumber(skinWid))
                if sc and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
            end
            local sc = F.cfg(skinRes)
            if sc and GUN_SUB[F.subType(sc)] and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    PERF.skinTarget[weaponResID] = 0
    return nil
end

function F.getSynMasterSkinID(weapon)
    if not slua.isValid(weapon) then return 0 end
    local id = 0
    pcall(function()
        local slot, tid = F.findSkinSlotInSynData(weapon)
        id = tid
        if id == 0 then
            local arr = weapon.synData
            if not arr or not slua.isValid(arr) then return end
            local att = arr:Get(GUN_MASTER_SYN_SLOT)
            if not att then return end
            id = slua.IndexReference(att, "defineID").TypeSpecificID or 0
        end
    end)
    return id
end

_G.AddOutfitSkinIdMappings = _G.AddOutfitSkinIdMappings or {}
_G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}

function F.buildSkinMappings()
    if not PERF.mappingsDirty then return end
    F.syncWeaponCacheFromLobby()
    PERF.mappingsDirty = false
    local m = _G.AddOutfitSkinIdMappings
    for k in pairs(m) do m[k] = nil end
    for wid, w in pairs(F.cache().weapons) do
        wid = tonumber(wid)
        if wid and w.resID and w.resID > 0 then
            m[wid] = { tonumber(w.resID) }
        end
    end
    if MATCH_CONFIG.weaponSkins then
        for weaponKey, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            weaponKey = tonumber(weaponKey)
            skinRes = tonumber(skinRes)
            if weaponKey and skinRes and skinRes > 0 and not m[weaponKey] then
                m[weaponKey] = { skinRes }
            end
        end
    end
end

function F.get_skin_id(currentGunId, maxIt)
    currentGunId = tonumber(currentGunId) or 0
    maxIt = tonumber(maxIt) or 0
    if currentGunId <= 0 and maxIt <= 0 then return 0 end
    F.buildSkinMappings()
    if maxIt > 0 then
        local fromMem = F.getMatchWeaponSkin(maxIt)
        if fromMem then return fromMem end
    end
    local fromMem2 = F.getMatchWeaponSkin(F.resolveWeaponTypeID(currentGunId))
    if fromMem2 then return fromMem2 end
    local m = _G.AddOutfitSkinIdMappings
    if maxIt > 0 and m[maxIt] and m[maxIt][1] then return tonumber(m[maxIt][1]) end
    local list = m[currentGunId]
    if list and list[1] then return tonumber(list[1]) end
    local typeId = F.resolveWeaponTypeID(currentGunId)
    if typeId > 0 and m[typeId] and m[typeId][1] then return tonumber(m[typeId][1]) end
    local target = F.findTargetSkinForWeaponRes(maxIt > 0 and maxIt or currentGunId)
    if target then return target end
    return currentGunId
end

function F.applySkinToWeaponRef(CurWeapon)
    -- [CHỐT CHẶN 100%] Từ chối mọi yêu cầu vẽ Skin Súng nếu công tắc tắt
    if not _G.LexusConfig.ModSkin then return false end
    
    if not slua.isValid(CurWeapon) then return false end
    local AttachmentArray = CurWeapon.synData
    if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end

    local AttachmentData = AttachmentArray:Get(GUN_MASTER_SYN_SLOT)
    if not AttachmentData then return false end

    local current_gunid = 0
    pcall(function() current_gunid = slua.IndexReference(AttachmentData, "defineID").TypeSpecificID or 0 end)
    if not current_gunid or current_gunid <= 0 then return false end

    local MaxIt = 0
    pcall(function()
        if CurWeapon.GetWeaponID then MaxIt = CurWeapon:GetWeaponID() end
        if MaxIt <= 0 then MaxIt = CurWeapon:GetItemDefineID().TypeSpecificID end
    end)
    MaxIt = tonumber(MaxIt) or 0
    local tmp_id = F.get_skin_id(current_gunid, MaxIt)
    tmp_id = tonumber(tmp_id) or 0
    if tmp_id <= 0 or MaxIt <= 0 then return false end
    
    local changedAny = false

    -- LOGIC 1: LẤY ID HÌNH ẢNH ĐANG HIỂN THỊ THỰC TẾ
    local wac = CurWeapon.WeaponAvatarComponent
    local currentVisualID = 0
    if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end

    -- NẾU SÚNG CHÍNH CHƯA PHẢI LÀ SKIN VIP -> THAY ĐỔI DATA
    if currentVisualID ~= tmp_id then
        changedAny = true
        pcall(function()
            local defRef = slua.IndexReference(AttachmentData, "defineID")
            defRef.TypeSpecificID = tmp_id
            local c0 = F.cfg(tmp_id)
            if c0 and c0.ItemType and defRef.Type ~= nil then defRef.Type = c0.ItemType end
            AttachmentData.operationType = 0
            AttachmentArray:Set(GUN_MASTER_SYN_SLOT, AttachmentData)
        end)
    end

    -- LOGIC 2: XỬ LÝ PHỤ KIỆN (ATTACHMENTS)
    if _G.LexusConfig.SkinAttachment and tmp_id >= 1000000 then
        local dynamicAttachMap = nil
        pcall(function() dynamicAttachMap = F.getDynamicAttachmentSkinMap(tmp_id) end)
        local attachSkinConfig = (_G.VIP_Attachments and _G.VIP_Attachments[tmp_id]) or nil
        local baseAttachMap = _G.BaseAttachToIndex

        if dynamicAttachMap or attachSkinConfig then
            -- Quét tới slot 9 để bao gồm cả khiên súng DP28, M249...
            for AttachIdx = 0, 9 do
                if AttachIdx ~= 7 then -- Bỏ qua slot 7 vì là thân súng (Master Gun)
                    pcall(function()
                        local attachData = AttachmentArray:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local baseAttId = attachmentId
                                    if baseAttId > 1000000 then
                                        local strId = tostring(baseAttId)
                                        if #strId >= 9 then baseAttId = tonumber(string.sub(strId, 2, 7)) or baseAttId end
                                    end

                                    local targetAttachId = 0
                                    if dynamicAttachMap then
                                        targetAttachId = dynamicAttachMap[baseAttId] or 0
                                    end
                                    if (not targetAttachId or targetAttachId <= 0) and attachSkinConfig and baseAttachMap then
                                        local mapIndex = baseAttachMap[baseAttId]
                                        if mapIndex then
                                            targetAttachId = attachSkinConfig[mapIndex] or 0
                                        end
                                    end

                                    if targetAttachId and targetAttachId > 0 and targetAttachId ~= attachmentId then
                                        defineIDRef.TypeSpecificID = targetAttachId
                                        attachData.defineID = defineIDRef
                                        AttachmentArray:Set(AttachIdx, attachData)
                                        changedAny = true
                                        
                                        -- Xóa cache Phụ kiện cũ để game Load phụ kiện VIP
                                        if slua.isValid(wac) then
                                            if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(AttachIdx) end
                                            if wac.ClearMeshBySlot then wac:ClearMeshBySlot(AttachIdx, true, true) end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end
    end

    -- [FIX VIP] LUÔN GHI NHỚ SKIN ĐANG ÁP (KỂ CẢ KHI MESH ĐÃ ĐÚNG) ĐỂ BALO ĐỒNG BỘ
    if tmp_id > 1000000 and MaxIt > 0 then
        _G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}
        _G.AddOutfitLastAppliedSkin[MaxIt] = tmp_id
    end

    -- LOGIC 3: LỆNH THẦN THÁNH ÉP GAME VẼ LẠI MESH NGAY TRÊN TAY
    if changedAny then
        pcall(function()
            if slua.isValid(wac) then
                -- Nếu là súng mới nhặt, xóa cái vỏ súng cũ kĩ đi
                if currentVisualID ~= tmp_id then
                    if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(0) end
                    if wac.ClearMeshBySlot then wac:ClearMeshBySlot(0, true, true) end
                end
                
                if CurWeapon.DelayHandleAvatarMeshChanged then
                    CurWeapon:DelayHandleAvatarMeshChanged()
                end
                if wac.ReloadAllEquippedAvatar then
                    wac:ReloadAllEquippedAvatar(1) 
                end
            end
        end)
        _G.AddOutfitLastAppliedSkin[MaxIt] = tmp_id
        return true
    end
    
    return false
end

function _G.equip_weapon_avatar(uCharacter)
    if not uCharacter or not slua.isValid(uCharacter) then return false end
    F.buildSkinMappings()
    local WeaponManager = uCharacter:GetWeaponManager()
    if not WeaponManager or not slua.isValid(WeaponManager) then return false end
    local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
    if not uWeaponList or not slua.isValid(uWeaponList) then return false end

    local appliedAny = false
    for i = 0, uWeaponList:Num() - 1 do
        local CurWeapon = uWeaponList:Get(i)
        if slua.isValid(CurWeapon) and F.applySkinToWeaponRef(CurWeapon) then
            appliedAny = true
        end
    end
    return appliedAny
end

function F.equipWeaponAvatarSynData(char)
    return _G.equip_weapon_avatar(char)
end

F.applySkinToWeapon = F.applySkinToWeaponRef

function F.registerWeaponAvatarItems(char)
    local pc = char.GetPlayerControllerSafety and char:GetPlayerControllerSafety()
    if not slua.isValid(pc) then return false end
    local AU = import("AvatarUtils")
    local BU = import("BackpackUtils")
    local addedCount = 0

    for _, resID in ipairs(F.getDesiredWeaponSkins()) do
        local doneDirect = false
        pcall(function()
            if pc.AddWeaponAvatarItem then
                pc:AddWeaponAvatarItem(tonumber(resID))
                doneDirect = true
                addedCount = addedCount + 1
            end
        end)
        if not doneDirect then
            pcall(function()
                local skinBPID = BU.GetBPIDByResID(tonumber(resID))
                local arr = slua.Array(UEnums.EPropertyClass.Int)
                local parents = AU.GetWeaponAvatarParentIDList(skinBPID, arr, false)
                if parents and parents.Num and parents:Num() > 0 and pc.WeaponAvatarItemList then
                    for _, parentID in pairs(parents) do
                        pc.WeaponAvatarItemList:Add(parentID, skinBPID)
                    end
                    addedCount = addedCount + 1
                end
            end)
        end
    end

    if addedCount == 0 then return false end

    pcall(function() if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end end)
    pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
    return true
end

function F.reloadCurrentWeaponAvatar(char)
    pcall(function()
        local weapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
        if not slua.isValid(weapon) then return end
        local wac = weapon.WeaponAvatarComponent
        if slua.isValid(wac) then
            local ES = import("EWeaponAttachmentSocketType")
            pcall(function() wac:ClearMeshPathCacheBySlot(ES.MasterGun) end)
            pcall(function() wac:ClearMeshBySlot(ES.MasterGun, true, true) end)
        end
        if weapon.DelayHandleAvatarMeshChanged then
            weapon:DelayHandleAvatarMeshChanged()
        elseif slua.isValid(wac) and wac.ReloadAllEquippedAvatar then
            local ESlotDescDiff = import("ESlotDescDiff")
            wac:ReloadAllEquippedAvatar(ESlotDescDiff.MeshDiff)
        end
    end)
end

local _weaponDiagDone = false
local _weaponApplied = false
local _lastWeaponResID = 0
local _weaponSpawnHooked = false

function F.onWeaponLuaInit(_, _, weapon)
    -- [FIX VIP] Ngăn không cho súng load Skin khi vừa cầm lên nếu đã tắt
    if not _G.LexusConfig.ModSkin then return end
    
    if not weapon or not slua.isValid(weapon) then return end
    local char = F.getLocalChar()
    if not char then return end
    local owner = nil
    pcall(function()
        if weapon.GetOwnerPawn then owner = weapon:GetOwnerPawn() end
    end)
    if not slua.isValid(owner) or owner ~= char then return end
    pcall(function()
        char:AddGameTimer(0.15, false, function()
            local c = F.getLocalChar()
            if c and slua.isValid(weapon) then
                F.applySkinToWeapon(weapon)
                _weaponApplied = false
            end
        end)
    end)
end

function F.hookWeaponSpawn()
    if _weaponSpawnHooked then return end
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_PLAYEREVENT_WEAPON and EVENTID_PLAYEREVENT_WEAPON_LUA_INIT then
            EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_LUA_INIT, onWeaponLuaInit)
            _weaponSpawnHooked = true
        end
    end)
end

function F.matchApplyWeaponSkin(char)
    if not _avatarItemsRegistered then
        _avatarItemsRegistered = F.registerWeaponAvatarItems(char)
    end

    local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
    if not slua.isValid(curWeapon) then return false end

    local currentVisualID = 0
    pcall(function()
        local wac = curWeapon.WeaponAvatarComponent
        if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end
    end)

    local curWeaponResID = 0
    pcall(function() curWeaponResID = curWeapon:GetItemDefineID().TypeSpecificID end)
    local targetSkin = F.findTargetSkinForWeaponRes(curWeaponResID) or curWeaponResID

    local isVisualMatched = false
    if currentVisualID > 0 and currentVisualID == targetSkin then
        isVisualMatched = true
    end

    -- [HỆ THỐNG SMART WATCHER V3] Quét toàn bộ Súng trên tay & Súng trong Balo
    if not _G.SmartWeaponWatcherActive then
        _G.SmartWeaponWatcherActive = true
        pcall(function()
            local ticker = require("common.time_ticker")
            if ticker and ticker.AddTimerLoop then
                ticker.AddTimerLoop(0, function()
                    if not _G.LexusConfig.ModSkin then return end
                    
                    -- [CỜ NGỦ ĐÔNG IN-GAME]: Nếu đã ra Sảnh -> Ngủ luôn, không chạy gì hết!
                    if _G.AddOutfit and not _G.AddOutfit.isInRealMatch() then return end
                    
                    local pController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                    if not pController or not slua.isValid(pController) then return end
                    local pChar = pController:GetPlayerCharacterSafety()
                    if not pChar or not slua.isValid(pChar) then return end
                    
                    -- Thay vì chỉ lấy súng trên tay, lấy luôn KHO VŨ KHÍ (Weapon Manager)
                    local WeaponManager = pChar:GetWeaponManager()
                    if not WeaponManager or not slua.isValid(WeaponManager) then return end
                    local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
                    if not uWeaponList or not slua.isValid(uWeaponList) then return end
                    
                    local count = uWeaponList:Num()
                    -- Lặp qua từng khẩu súng bạn đang sở hữu (Súng 1, Súng 2, Lục, Dao)
                    for i = 0, count - 1 do
                        local wep = uWeaponList:Get(i)
                        if slua.isValid(wep) then
                            -- Kiểm tra data (synData) của súng xem đã là Data VIP chưa
                            local synSkinID = F.getSynMasterSkinID(wep)
                            local baseID = 0
                            pcall(function() baseID = wep:GetItemDefineID().TypeSpecificID end)
                            local tSkin = F.findTargetSkinForWeaponRes(baseID) or baseID
                            
                            -- NẾU DATA CHƯA PHẢI LÀ VIP -> Vừa lụm thẳng vào Balo -> Bắn lệnh Load ngầm!
                            -- HOẶC bật Skin Phụ Kiện -> Kiểm tra phụ kiện
                            if synSkinID ~= tSkin or _G.LexusConfig.SkinAttachment then
                                if _G.AddOutfit and _G.AddOutfit.applySkinToWeapon then
                                    _G.AddOutfit.applySkinToWeapon(wep)
                                end
                            end
                        end
                    end
                end, -1, 0.4) 
            end
        end)
    end

    -- BÁO CÁO HOÀN THÀNH: Nếu súng cầm trên tay đã xong xuôi thì khóa luồng gốc của Engine
    if isVisualMatched and not _G.LexusConfig.SkinAttachment then
        _weaponApplied = true
        return true
    end

    F.buildSkinMappings()
    local okSyn = F.applySkinToWeapon(curWeapon)

    return okSyn
end

local _matchTimer = nil
local _matchWearDone = false

function F.startMatchWatcher(char)
    if _matchTimer or PERF.matchActive then return end
    PERF.matchActive = true
    local skipWear = PERF.wearDoneThisMatch
    _matchWearDone = skipWear
    _avatarItemsRegistered = false
    _weaponDiagDone = false
    _weaponApplied = false
    _lastWeaponResID = 0
    local elapsed = 0

    _matchTimer = char:AddGameTimer(MATCH_TICK_SEC, true, function()
        -- [FIX VIP] Nếu tắt Mod Skin thì dừng việc ép skin vào trận
        if not _G.LexusConfig.ModSkin then return end
        
        elapsed = elapsed + MATCH_TICK_SEC
        local cur = F.getLocalChar()
        if not cur or not slua.isValid(cur) then return end

        if not _matchWearDone then
            _matchWearDone = F.matchApplyAllSlots(cur)
        end
        F.matchApplyHat(cur)
        F.matchApplyFaceWear(cur) -- [FIX VIP] Bổ sung lệnh gọi ép Kính & Mặt Nạ chạy liên tục giống Mũ
        if not _weaponApplied then
            F.matchApplyWeaponSkin(cur)
        end
        if F.isCharacterAirborne(cur) then
            F.applyAirborneSlots(cur, true)
        end

        if (_matchWearDone and _weaponApplied) or elapsed >= MATCH_MAX_SEC then
            if _matchWearDone then
                PERF.wearDoneThisMatch = true
            end
            if _matchTimer and cur.RemoveGameTimer then
                pcall(function() cur:RemoveGameTimer(_matchTimer) end)
            end
            _matchTimer = nil
            PERF.matchActive = false
        end
    end)
end

function F.stopMatchWatcher()
    if _matchTimer then
        pcall(function()
            local char = F.getLocalChar()
            if char and char.RemoveGameTimer then char:RemoveGameTimer(_matchTimer) end
        end)
        _matchTimer = nil
    end
    PERF.matchActive = false
    PERF.wearDoneThisMatch = false
    _matchWearDone = false
    _avatarItemsRegistered = false
    _weaponApplied = false
    _weaponDiagDone = false
    _lastWeaponResID = 0
end

function F.hookAirborneCache()
    if _G.AddOutfitAirborneHooked then return end
    _G.AddOutfitAirborneHooked = true
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST, function()
                F.syncAirborneCacheFromLobby()
            end)
        end
    end)
end

function F.hookPutOnRsp()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.on_puton_rsp
        wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
            o(self, res, item, olditem, index, extra)
            if not item or not item.instid then return end
            local resID = tonumber(item.res_id)
            local insID = tonumber(item.instid)
            if not resID or not insID then return end
            local c = F.cfg(resID)
            local st = F.subType(c)
            if st == OUTFIT_SUB then
                F.saveEquip(resID, insID)
            elseif st == HAT_SUB or FACE_SUBS[st] or BODY_SUBS[st] or HELMET_SUBS[st]
                or st == PARACHUTE_SUB or F.isGlideRes(resID) or st == GLOVES_SUB then
                F.saveEquip(resID, insID)
            elseif F.isParachuteRes(resID) or F.isGlideRes(resID) then
                F.saveEquip(resID, insID)
            elseif HEAD_SUBS[st] then
                F.saveEquip(resID, insID)
            elseif GUN_SUB[st] then
                local wid = F.weaponIdFromSkin(resID)
                if wid then F.cacheWeaponSkinFromIns(wid, insID) end
            elseif st == MELEE_ID then
                F.cacheWeaponSkinFromIns(MELEE_ID, insID)
            elseif F.isInjectedIns(insID) then
                F.saveEquip(resID, insID)
            end
        end
    end)
end

function F.hookLobbyWeaponCache()
    if _G.AddOutfitLobbyWeaponCacheHooked then return end
    _G.AddOutfitLobbyWeaponCacheHooked = true
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local oRsp = Arm.install_weapon_skin_rsp
        Arm.install_weapon_skin_rsp = function(client_data, errorCode, weapon_id, instanceID)
            oRsp(client_data, errorCode, weapon_id, instanceID)
            if (errorCode == 0 or errorCode == NET_OK) and F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
        local oH = Arm.HandleWeaponSkinChange
        Arm.HandleWeaponSkinChange = function(client_data, weapon_id, instanceID)
            oH(client_data, weapon_id, instanceID)
            if F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        local o = wgl.on_put_on_weapon_wear_rsp
        wgl.on_put_on_weapon_wear_rsp = function(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            o(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            if res == 0 or res == NET_OK then
                F.cacheWeaponSkinFromIns(weapon_id, new_skin_id)
            end
        end
    end)
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function(_, _, resOrFlag, weapon_id)
                weapon_id = tonumber(weapon_id)
                if weapon_id and weapon_id > 0 then
                    pcall(function()
                        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                        local insID = tonumber(wgl:GetSkinIdByWeaponID(weapon_id)) or 0
                        if insID > 0 then F.cacheWeaponSkinFromIns(weapon_id, insID) end
                    end)
                elseif tonumber(resOrFlag) and tonumber(resOrFlag) > 100000 then
                    pcall(function()
                        local wid = F.weaponIdFromSkin(resOrFlag)
                        if wid then
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local ins = wd.GetWardrobeInsIdByResId and wd:GetWardrobeInsIdByResId(resOrFlag)
                            if ins and ins > 0 then F.cacheWeaponSkinFromIns(wid, ins) end
                        end
                    end)
                end
            end)
        end
    end)
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local oHeadReq = WRH.send_depot_set_head_show_req
        WRH.send_depot_set_head_show_req = function(insID)
            insID = tonumber(insID) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetHallDepotItemDataByInsID(insID)
                if d and d.resID then
                    F.saveEquip(tonumber(d.resID), insID)
                end
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:SetHeadShow(insID)
                WRH.on_depot_set_head_show_rsp(NET_OK, insID)
                return
            end
            return oHeadReq(insID)
        end
        local oHead = WRH.on_depot_set_head_show_rsp
        WRH.on_depot_set_head_show_rsp = function(err_code, id)
            oHead(err_code, id)
            if err_code ~= 0 and err_code ~= NET_OK then return end
            id = tonumber(id) or 0
            if id <= 0 then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(id)
            if d and d.resID then
                local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
                if st == HAT_SUB or HELMET_SUBS[st] then
                    F.saveEquip(tonumber(d.resID), id)
                end
            end
        end
    end)
end

function F.hookWardrobePutOnReq()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPutOnReqHooked then return end
        wl._AddOutfitPutOnReqHooked = true
        local oReq = wl.wardrobe_puton_req
        wl.wardrobe_puton_req = function(self, insID, extra)
            insID = tonumber(insID)
            F.ensureDepotItemValid(insID)
            if F.tryLocalWearByIns(insID) then return end
            return oReq(self, insID, extra)
        end
        if not wl._AddOutfitPutOnDataHooked then
            wl._AddOutfitPutOnDataHooked = true
            local oData = wl.wardrobe_puton_data_req
            wl.wardrobe_puton_data_req = function(self, itemData)
                if itemData then
                    local insID = tonumber(itemData.ins_id or itemData.insID)
                    local resID = tonumber(itemData.res_id or itemData.resID)
                    F.clearItemExpire(itemData, insID, resID)
                    F.ensureDepotItemValid(insID, resID)
                end
                return oData(self, itemData)
            end
        end
    end)
end

local _bootstrapNotified = false

function F.bootstrapMatch(char)
    char = char or F.getLocalChar()
    if not char or not slua.isValid(char) then return false end
    if PERF.matchActive then return true end
    local now = os.clock()
    if (now - PERF.lastBootstrapAt) < BOOTSTRAP_COOLDOWN then return false end
    PERF.lastBootstrapAt = now
    F.syncWeaponCacheFromLobby(true)
    F.applyPersistSlotsToCache()
    F.cleanArmoryPollution()
    F.syncGlobalWearSkins()
    F.syncAirborneToDataMgr()
    pcall(function() F.applyAirborneSlots(char, F.isCharacterAirborne(char)) end)
    F.syncVehicleCacheFromDataMgr()
    F.syncVehicleSlotsToDataMgr()
    pcall(function() F.applyVehicleSkinsToPC(F.getPC()) end)
    F.startVehicleSkinTicker()
    pcall(function()
        local v = F.getMatchVehicle()
        if slua.isValid(v) then F.autoApplyVehicleSkinOnEnter(v) end
    end)
    _weaponApplied = false
    _weaponDiagDone = false
    _matchApplied = false
    if not _bootstrapNotified then
        _bootstrapNotified = true
    end
    F.startMatchWatcher(char)
    return true
end

function F.hookMatchAvatar()
    pcall(function()
        local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
        local o = CAC.OnAvatarAllMeshLoadedLua
        CAC.OnAvatarAllMeshLoadedLua = function(self)
            o(self)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                if PERF.wearDoneThisMatch or PERF.matchActive then return end
                local char = F.getLocalChar()
                if char and char.AddGameTimer then
                    char:AddGameTimer(0.5, false, function() F.bootstrapMatch(char) end)
                end
            end)
        end
    end)
    pcall(function()
        local WAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.WeaponAvatarComponent")
        local oLoad = WAC.OnWeaponAvatarLoadedLua
        WAC.OnWeaponAvatarLoadedLua = function(self, slotID, definedID)
            oLoad(self, slotID, definedID)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                local char = F.getLocalChar()
                if not char then return end
                _weaponApplied = false
                if not PERF.matchActive then F.bootstrapMatch(char)
                elseif char.AddGameTimer then
                    char:AddGameTimer(0.25, false, function()
                        local c = F.getLocalChar()
                        if c then F.matchApplyWeaponSkin(c) end
                    end)
                end
            end)
        end
    end)
end

function F.hookVehicleInfoInit()
    pcall(function()
        if DataMgr._AddOutfitVehInfoHooked then return end
        DataMgr._AddOutfitVehInfoHooked = true
        local orig = DataMgr.InitVehicleInfo
        DataMgr.InitVehicleInfo = function(vehicle_info, vst_skin)
            vehicle_info = F.mergeInjectedIntoVehicleSlotList(vehicle_info)
            orig(vehicle_info, vst_skin)
            F.later(0.15, function()
                F.reapplyVehicleSlotsFromConfig()
                F.reapplyHallThemeFromConfig()
                LOBBY.reapplyDone = false
                LOBBY.reapplyScheduled = false
                F.scheduleLobbyReapplyOnce()
            end)
        end
    end)
end

function F.hookVehicleSkinDataInit()
    pcall(function()
        if DataMgr._AddOutfitVehSkinDataHooked then return end
        DataMgr._AddOutfitVehSkinDataHooked = true
        local origInit = DataMgr.InitVehicleSkinData
        DataMgr.InitVehicleSkinData = function(data)
            data = F.mergeInjectedVehicleSkinTable(data)
            origInit(data)
            F.later(0.1, function()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
            end)
        end
        local origUpd = DataMgr.UpdateVehicleSkin
        DataMgr.UpdateVehicleSkin = function(itemSubType, putOnId)
            origUpd(itemSubType, putOnId)
            if not _G.AddOutfitApplyingConfig and F.isInjectedIns(putOnId) then
                F.setLobbyVehicleManual(itemSubType, R.insToRes[putOnId], putOnId)
            end
        end
    end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        if HallThemeUtils._AddOutfitLobbyVehHooked then return end
        HallThemeUtils._AddOutfitLobbyVehHooked = true
        local orig = HallThemeUtils.ProcPutOnVehicle
        HallThemeUtils.ProcPutOnVehicle = function(putOnItem, bShowVehicle)
            orig(putOnItem, bShowVehicle)
            if not _G.AddOutfitApplyingConfig and putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and F.isInjectedIns(ins) then
                    F.setLobbyVehicleManual(F.vehicleSubType(res or R.insToRes[ins]), res or R.insToRes[ins], ins)
                end
            end
        end
    end)
end

function F.hookHallTheme()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        if HT._AddOutfitHallThemeHooked then return end
        HT._AddOutfitHallThemeHooked = true
        local orig = HT.ProcPutOnHallTheme
        HT.ProcPutOnHallTheme = function(putOnItem, putOffItem)
            orig(putOnItem, putOffItem)
            if not _G.AddOutfitApplyingTheme and putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and F.isInjectedIns(ins) then
                    F.setHallThemeManual(res or R.insToRes[ins], ins)
                end
            end
        end
    end)
end

function F.hookGarageTheme()
    pcall(function()
        local TeamupHandler = require("client.network.Protocol.TeamupHandler")
        local ModuleManager = require("client.module_framework.ModuleManager")
        if not TeamupHandler then return end
        
        -- Hook: Update Từng Slot Xe ở sảnh
        local o_send_update = TeamupHandler.send_update_car_main_page_slot_req
        if o_send_update and not TeamupHandler._AddOutfitGarageUpdateHooked then
            TeamupHandler._AddOutfitGarageUpdateHooked = true
            TeamupHandler.send_update_car_main_page_slot_req = function(slot_id, item_inst_id)
                
                -- [TỐI ƯU FPS - NGỦ ĐÔNG] Nếu đang trong trận thực sự -> Bỏ qua toàn bộ logic Gara Sảnh, trả về game gốc ngay lập tức!
                if F.isInRealMatch() then 
                    return o_send_update(slot_id, item_inst_id) 
                end

                if F.isInjectedIns(tonumber(item_inst_id)) then
                    local resID = R.insToRes[tonumber(item_inst_id)]
                    local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                    if not GarageThemeSystem then return end

                    GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                        inst_id = tonumber(item_inst_id),
                        res_id = resID
                    }

                    for k, v in pairs(GarageThemeSystem.GarageVehicleInfo) do
                        if k ~= slot_id and v.inst_id == tonumber(item_inst_id) then
                            GarageThemeSystem.GarageVehicleInfo[k] = nil
                        end
                    end

                    pcall(function() GarageThemeSystem:ReportSpecialEffectTlog() end)
                    if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                        EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                    end

                    local itemCfg = F.cfg(resID)
                    if itemCfg and DataMgr and DataMgr.UpdateVehicleSkin then
                        local subType = itemCfg.ItemSubType or itemCfg.itemSubType
                        DataMgr.UpdateVehicleSkin(subType, tonumber(item_inst_id))
                    end
                    if DataMgr then DataMgr.vst_skin = tonumber(item_inst_id) end
                    
                    pcall(function()
                        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
                        if HallThemeUtils then
                            if HallThemeUtils.UpdateThemeVehicleShow then HallThemeUtils.UpdateThemeVehicleShow() end
                            if HallThemeUtils.ShowThemeVehicle then HallThemeUtils.ShowThemeVehicle() end
                        end
                    end)
                    return
                end
                return o_send_update(slot_id, item_inst_id)
            end
        end

        -- Hook: Update Hàng loạt xe ở sảnh
        local o_send_batch = TeamupHandler.send_batch_put_on_sportscar_req
        if o_send_batch and not TeamupHandler._AddOutfitGarageBatchHooked then
            TeamupHandler._AddOutfitGarageBatchHooked = true
            TeamupHandler.send_batch_put_on_sportscar_req = function(instid_list)
                
                -- [TỐI ƯU FPS - NGỦ ĐÔNG] Tương tự, chặn đứng khi đang trong trận
                if F.isInRealMatch() then 
                    return o_send_batch(instid_list) 
                end

                if type(instid_list) ~= "table" then
                    return o_send_batch(instid_list)
                end

                local hasInjected = false
                for slot_id, item_inst_id in pairs(instid_list) do
                    if F.isInjectedIns(tonumber(item_inst_id)) then
                        hasInjected = true
                        break
                    end
                end

                if not hasInjected then
                    return o_send_batch(instid_list)
                end

                local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if not GarageThemeSystem then return end

                for slot_id, item_inst_id in pairs(instid_list) do
                    local insID = tonumber(item_inst_id)
                    if F.isInjectedIns(insID) then
                        local resID = R.insToRes[insID]
                        if insID ~= 0 and resID then
                            GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                                inst_id = insID,
                                res_id = resID
                            }
                        else
                            GarageThemeSystem.GarageVehicleInfo[slot_id] = nil
                        end
                    end
                end

                pcall(function() GarageThemeSystem:ReportSpecialEffectTlog() end)
                if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                end

                local nonInjected = {}
                for slot_id, item_inst_id in pairs(instid_list) do
                    if not F.isInjectedIns(tonumber(item_inst_id)) then
                        nonInjected[slot_id] = item_inst_id
                    end
                end
                if next(nonInjected) then
                    return o_send_batch(nonInjected)
                end
            end
        end
    end)
end

function F.hookEnterGame()
    if _G.AddOutfitEnterGameHooked then return end
    _G.AddOutfitEnterGameHooked = true
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_ENTER_GAME_BEGIN then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, function()
                F.perfInvalidateLobby()
                F.syncWeaponCacheFromLobby(true)
                F.reapplyVehicleSlotsFromConfig(true)
                F.reapplyHallThemeFromConfig(true)
                pcall(F.applyVehicleSkinsToPC)
                F.stopMatchWatcher()
                _bootstrapNotified = false
            end)
        end
    end)
end

function F.afterInjectApply(firstTime)
    F.mergeInjectedArmorySkins()
    F.cleanArmoryPollution()
    if firstTime then
        F.refreshWardrobeOnce()
        F.persistApplyLoaded()
        F.hookGarageTheme()
        F.syncLobbyVehicleResFromIns()
        F.reapplyVehicleSlotsFromConfig(true)
        F.reapplyHallThemeFromConfig(true)
        F.reapplyWeaponsFromConfig()
        F.scheduleLobbyReapplyOnce()
    else
        F.reapplyWeaponsFromConfig()
    end
end

-- ==============================================================================
-- [FIX VIP] HỆ THỐNG ĐỒNG BỘ SKIN BALO + KILL COUNTER (V2)
-- Đọc skin THẬT đang gắn trên súng (synData slot 7) của nhân vật local.
-- ==============================================================================
local EquippedSkinScan = { skins = {}, lastScan = 0 }

function F.getAppliedWeaponSkinByBase(baseWeaponID)
    baseWeaponID = tonumber(baseWeaponID) or 0
    if baseWeaponID <= 0 then return nil end
    local now = os.clock()
    if not EquippedSkinScan.skins or (now - (EquippedSkinScan.lastScan or 0)) > 2.0 then
        EquippedSkinScan.lastScan = now
        local fresh = {}
        pcall(function()
            local char = F.getLocalChar()
            if not char or not slua.isValid(char) then return end
            local WeaponManager = nil
            pcall(function() if char.GetWeaponManager then WeaponManager = char:GetWeaponManager() end end)
            if not slua.isValid(WeaponManager) then return end
            local uWeaponList = nil
            pcall(function() if WeaponManager.GetAllInventoryWeaponList then uWeaponList = WeaponManager:GetAllInventoryWeaponList(false) end end)
            if not slua.isValid(uWeaponList) then return end
            local count = 0
            pcall(function() if type(uWeaponList.Num) == "function" then count = uWeaponList:Num() end end)
            for i = 0, count - 1 do
                local wep = nil
                pcall(function() if type(uWeaponList.Get) == "function" then wep = uWeaponList:Get(i) end end)
                if slua.isValid(wep) then
                    local baseID = 0
                    pcall(function()
                        if wep.GetWeaponID then baseID = tonumber(wep:GetWeaponID()) or 0 end
                        if baseID <= 0 then
                            local did = nil
                            if wep.GetItemDefineID then did = wep:GetItemDefineID() end
                            if did and slua.isValid(did) then baseID = tonumber(did.TypeSpecificID) or 0 end
                        end
                    end)
                    local skinID = tonumber(F.getSynMasterSkinID(wep)) or 0
                    if baseID > 0 and skinID > 1000000 then
                        fresh[baseID] = skinID
                    end
                end
            end
        end)
        EquippedSkinScan.skins = fresh
    end
    return EquippedSkinScan.skins[baseWeaponID]
end

function F.baseWeaponIDFromAny(skinOrBaseID)
    skinOrBaseID = tonumber(skinOrBaseID) or 0
    if skinOrBaseID <= 0 then return 0 end
    if skinOrBaseID < 1000000 then return skinOrBaseID end
    local s = tostring(skinOrBaseID)
    if #s >= 9 then
        local base = tonumber(string.sub(s, 2, 7))
        if base and base > 100000 then return base end
    end
    local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", skinOrBaseID)
    if m and m.WeaponID then
        local wid = tonumber(m.WeaponID)
        if wid and wid > 0 then return wid end
    end
    return skinOrBaseID
end

-- ==============================================================================
-- [THÊM MỚI] SKIN PHỤ KIỆN TRONG BALO: quét súng đang cầm
-- ==============================================================================
function F.getModSkinForWeapon(wid)
    local lookupID = F.baseWeaponIDFromAny(wid)
    local skinID = 0
    pcall(function()
        if _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[lookupID] then
            skinID = tonumber(_G.AddOutfitLastAppliedSkin[lookupID]) or 0
        end
    end)
    if not skinID or skinID <= 0 then
        pcall(function() skinID = tonumber(F.getAppliedWeaponSkinByBase(lookupID)) or 0 end)
    end
    if not skinID or skinID <= 0 then
        pcall(function() skinID = tonumber(F.findTargetSkinForWeaponRes(lookupID)) or 0 end)
    end
    return tonumber(skinID) or 0
end

-- ==============================================================================
-- BẢNG PHỤ KIỆN ĐỘNG LẤY TỪ CHÍNH GAME (TỰ ĐỘNG TƯƠNG THÍCH MỌI SÚNG)
-- ==============================================================================
local DynamicAttachMapCache = {}

function F.getDynamicAttachmentSkinMap(skinID)
    skinID = tonumber(skinID) or 0
    if skinID <= 0 then return nil end
    if DynamicAttachMapCache[skinID] ~= nil then
        return DynamicAttachMapCache[skinID] 
    end
    local result = nil
    pcall(function()
        local rawList = nil
        local itemCfg = CDataTable.GetTableData("Item", skinID)
        if itemCfg and itemCfg.BPID then
            local bpCfg = CDataTable.GetTableData("WeaponAttrBPTable", itemCfg.BPID)
            if bpCfg then rawList = bpCfg.AttachmentSkinIDList end
        end
        if (not rawList or rawList == "") then
            local mapCfg = CDataTable.GetTableData("WeaponSkinMapping", skinID)
            if mapCfg then rawList = mapCfg.AttachmentSkinIDList end
        end
        if rawList and rawList ~= "" then
            local StringUtil = require("common.string_util")
            result = {}
            for _, v in pairs(StringUtil.Split(rawList, "|")) do
                local parts = StringUtil.Split(v, "-")
                local baseId = tonumber(parts[1]) or 0
                local attachSkinId = tonumber(parts[2]) or 0
                if baseId > 0 and attachSkinId > 0 then
                    result[baseId] = attachSkinId
                end
            end
            if not next(result) then result = nil end
        end
    end)
    DynamicAttachMapCache[skinID] = result
    return result
end

local AttachSkinScan = { last = 0, map = nil }

function F.getAttachmentSkinForBase(baseAttachID, specificWeaponSkinID)
    baseAttachID = tonumber(baseAttachID) or 0
    if baseAttachID <= 0 then return nil end
    if not (_G.LexusConfig and _G.LexusConfig.ModSkin == true) then return nil end
    
    if specificWeaponSkinID and specificWeaponSkinID > 1000000 then
        local dyn = nil
        pcall(function() dyn = F.getDynamicAttachmentSkinMap(specificWeaponSkinID) end)
        if dyn and dyn[baseAttachID] then
            local s = tonumber(dyn[baseAttachID])
            if s and s > 0 then return s end
        end
        local cfg = _G.VIP_Attachments and _G.VIP_Attachments[specificWeaponSkinID]
        if cfg then
            for base, idx in pairs(_G.BaseAttachToIndex or {}) do
                if tonumber(base) == baseAttachID then
                    local s = tonumber(cfg[idx])
                    if s and s > 0 then return s end
                end
            end
        end
    end

    local now = os.clock()
    if not AttachSkinScan.map or (now - (AttachSkinScan.last or 0)) > 2.0 then
        AttachSkinScan.last = now
        local fresh = {}
        pcall(function()
            local char = F.getLocalChar()
            if not char or not slua.isValid(char) then return end
            local WeaponManager = nil
            pcall(function() if char.GetWeaponManager then WeaponManager = char:GetWeaponManager() end end)
            if not slua.isValid(WeaponManager) then return end
            local uWeaponList = nil
            pcall(function() if WeaponManager.GetAllInventoryWeaponList then uWeaponList = WeaponManager:GetAllInventoryWeaponList(false) end end)
            if not slua.isValid(uWeaponList) then return end
            local count = 0
            pcall(function() if type(uWeaponList.Num) == "function" then count = uWeaponList:Num() end end)
            for i = 0, count - 1 do
                local wep = nil
                pcall(function() if type(uWeaponList.Get) == "function" then wep = uWeaponList:Get(i) end end)
                if slua.isValid(wep) then
                    local rawID = tonumber(F.getSynMasterSkinID(wep)) or 0
                    local skinID = 0
                    if rawID > 0 then
                        skinID = F.getModSkinForWeapon(rawID)
                        if not skinID or skinID <= 0 then skinID = rawID end
                    end
                    
                    if skinID > 1000000 then
                        local dyn = nil
                        pcall(function() dyn = F.getDynamicAttachmentSkinMap(skinID) end)
                        if dyn then
                            for base, skin in pairs(dyn) do
                                base = tonumber(base)
                                skin = tonumber(skin)
                                if base and skin and base > 0 and skin > 0 then fresh[base] = skin end
                            end
                        end
                        local cfg = _G.VIP_Attachments and _G.VIP_Attachments[skinID]
                        if cfg then
                            for base, idx in pairs(_G.BaseAttachToIndex or {}) do
                                local v = tonumber(cfg[idx]) or 0
                                if v > 0 then fresh[base] = v end
                            end
                        end
                    end
                end
            end
        end)
        AttachSkinScan.map = fresh
    end
    return AttachSkinScan.map[baseAttachID]
end

-- ==============================================================================
    -- ================= HỆ THỐNG MOD EMOTE VIP (SẢNH + TRONG TRẬN) =================
    -- ==============================================================================
    function F.hookMotionEquip()
        pcall(function()
            local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
            if wl._lava_hooked_motion then return end
            wl._lava_hooked_motion = true

            local origEquip = wl.EquipMotion
            wl.EquipMotion = function(self, instid, dst_slot)
                instid = tonumber(instid)
                if instid and F.isInjectedIns(instid) then
                    local insSlot = 0
                    for i, v in ipairs(DataMgr.MotionSlotList) do
                        if v == instid then insSlot = i; break end
                    end
                    if insSlot > 0 then
                        local curIns = DataMgr.MotionSlotList[dst_slot]
                        if curIns == instid then return end
                        DataMgr.MotionSlotList[insSlot] = curIns or 0
                        DataMgr.MotionSlotList[dst_slot] = instid
                    else
                        while #DataMgr.MotionSlotList < dst_slot do
                            table.insert(DataMgr.MotionSlotList, 0)
                        end
                        DataMgr.MotionSlotList[dst_slot] = instid
                    end
                    if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                        EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                    end
                    pcall(F.persistMarkDirty)
                    return
                end
                return origEquip(self, instid, dst_slot)
            end

            local origUnequip = wl.unequip_motion_req
            wl.unequip_motion_req = function(self, instid, slot)
                instid = tonumber(instid)
                if instid and F.isInjectedIns(instid) then
                    for i, v in ipairs(DataMgr.MotionSlotList) do
                        if v == instid then
                            table.remove(DataMgr.MotionSlotList, i)
                            break
                        end
                    end
                    if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                        EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                    end
                    pcall(F.persistMarkDirty)
                    return
                end
                return origUnequip(self, instid, slot)
            end
        end)
    end

    local _emoteSlotKey = nil
    local _emoteSlotCache = {}
    function F.getInjectedEmotes()
        local slotList = DataMgr and DataMgr.MotionSlotList or {}
        local key = table.concat(slotList, ",")
        if key == _emoteSlotKey then return _emoteSlotCache end
        _emoteSlotKey = key
        _emoteSlotCache = {}
        for _, insID in ipairs(slotList) do
            insID = tonumber(insID)
            if insID and insID > 0 and F.isInjectedIns(insID) then
                local resID = R.insToRes[insID]
                if resID then
                    local c = F.cfg(resID)
                    if c and tonumber(c.ItemType or c.itemType) == 22 then
                        _emoteSlotCache[#_emoteSlotCache + 1] = {
                            resID = resID,
                            name = c.ItemName or "",
                            icon = c.ItemSmallIcon or c.ItemIcon or ""
                        }
                    end
                end
            end
        end
        return _emoteSlotCache
    end

    function F.hookIngameEmote()
        pcall(function()
            local QEU = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpressionUtils")
            if QEU._lava_hooked_emote then return end
            QEU._lava_hooked_emote = true

            local origGetList = QEU.GetShowExpressionList
            QEU.GetShowExpressionList = function()
                local tShowEmoteList, nWeaponEmoteId = origGetList()
                tShowEmoteList = tShowEmoteList or {}
                
                if _G.LexusConfig and _G.LexusConfig.ModEmote then
                    local emotes = F.getInjectedEmotes()
                    if #emotes > 0 then
                        local existingIDs = {}
                        for _, existing in pairs(tShowEmoteList) do
                            if existing.DefineID then
                                existingIDs[tonumber(existing.DefineID.TypeSpecificID) or 0] = true
                            end
                        end
                        for _, em in ipairs(emotes) do
                            if not existingIDs[em.resID] then
                                tShowEmoteList[#tShowEmoteList + 1] = {
                                    DefineID = {TypeSpecificID = em.resID},
                                    Name = em.name
                                }
                            end
                        end
                    end
                end
                return tShowEmoteList, nWeaponEmoteId
            end
        end)

        pcall(function()
            local QE = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpression")
            if QE._lava_hooked_emote_img then return end
            QE._lava_hooked_emote_img = true

            local origGetImg = QE.GetEmoteImagePalthMap
            QE.GetEmoteImagePalthMap = function(self, ...)
                origGetImg(self, ...)
                if _G.LexusConfig and _G.LexusConfig.ModEmote then
                    local emotes = F.getInjectedEmotes()
                    for _, em in ipairs(emotes) do
                        if em.icon ~= "" then
                            self.ItemIDToImagePathMap[em.resID] = em.icon
                        end
                    end
                end
            end
        end)

        pcall(function()
            local le = require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
            if le._lava_hooked_emote_exist then return end
            le._lava_hooked_emote_exist = true

            local origExist = le.IsEmoteExist
            le.IsEmoteExist = function(EmoteID)
                if _G.LexusConfig and _G.LexusConfig.ModEmote and F.isInjectedRes(tonumber(EmoteID)) then return true end
                return origExist(EmoteID)
            end

            local origDownloaded = le.CheckEmoteDownloaded
            if origDownloaded then
                le.CheckEmoteDownloaded = function(EmoteID, bUseCache, bLobby, bForeceLobby)
                    if _G.LexusConfig and _G.LexusConfig.ModEmote and F.isInjectedRes(tonumber(EmoteID)) then return true end
                    return origDownloaded(EmoteID, bUseCache, bLobby, bForeceLobby)
                end
            end
        end)
    end

function F.start()
    F.restorePufferHooks()
    F.buildSkinMappings()
    if not _G.AddOutfitPersistLoaded then
        _G.AddOutfitPersistLoaded = true
        F.persistLoadFromDisk()
    end
    F.applyPersistSlotsToCache()
    F.syncGlobalWearSkins()
    
    _G.apply_vehicle_skin = F.matchApplyVehicleSkin
    _G.skinIdMappings = _G.AddOutfitSkinIdMappings
    
    F.hookDepotInit()
    F.hookWardrobeData()
    F.hookPageFilter()
    F.hookArmory()
    F.hookGunSkinId()
    F.hookPutOn()
    F.hookPutDown()
    F.hookVehicles()
    F.hookAirborneClick()
    F.hookVehicleInfoInit()
    F.hookVehicleSkinDataInit()
    F.hookHallTheme()
    F.hookWeaponWear()
    F.hookNotice()
    F.hookAvatarValid()
    F.hookPutOnRsp()
    F.hookAirborneCache()
    F.hookLobbyWeaponCache()
    F.hookLobbySwipePersistence()
    F.hookWardrobePutOnReq()
    F.hookWardrobeWearClicks()
    F.hookMatchAvatar()
    F.hookBackpackValid()
    F.hookEquipMapping()
    F.hookWeaponSpawn()
    F.hookMotionEquip()
    F.hookIngameEmote()
    
    -- Hook backpack avatar skin to show VIP skin in balo (V2 - live synData scan, đồng bộ 100% với súng trên tay)
    pcall(function()
        local BPL = require("GameLua.Mod.BaseMod.Client.Backpack.BackPackFunctionLibrary")
        if BPL and type(BPL.GetWeaponAvatarRes) == "function" and not BPL._lex_hooked_avatar_v2 then
            BPL._lex_hooked_avatar_v2 = true
            local _origGetRes = BPL.GetWeaponAvatarRes
            BPL.GetWeaponAvatarRes = function(WeaponID, AdditionalDataArray)
                local origID, origDIY = nil, nil
                pcall(function() origID, origDIY = _origGetRes(WeaponID, AdditionalDataArray) end)
                local wid = tonumber(WeaponID) or 0
                if wid > 0 and _G.LexusConfig and _G.LexusConfig.ModSkin == true then
                    local skinID = F.getModSkinForWeapon(wid)
                    if skinID > 1000000 and skinID ~= wid and F.cfg(skinID) then
                        return skinID, origDIY
                    end
                end
                return origID, origDIY
            end
        end
    end)

    -- [THÊM MỚI] Hook icon phụ kiện trong Balo -> đè bằng icon skin VIP.
    -- Hook đúng theo cách cũ đã chạy được: MyFittingSlotItemUI.__inner_impl.UpdateSlotItem.
    pcall(function()
        local function lexDbg(msg)
            pcall(function()
                if Client and type(Client.SaveStringToFile) == "function" then
                    Client.SaveStringToFile(tostring(msg or ""), "SaveGames/lex_attach_debug.txt")
                end
            end)
        end

        local MyMainWeaponInfoItemUI = require("GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI")
        local MyFittingSlotItemUI = nil
        pcall(function() MyFittingSlotItemUI = require("GameLua.Mod.BaseMod.Client.Backpack.FittingSlotItemUI") end)

        -- (1) Ô súng: ghi nhớ base weapon + skin (để ô phụ kiện con biết skin của súng cha)
        if MyMainWeaponInfoItemUI and MyMainWeaponInfoItemUI.__inner_impl and MyMainWeaponInfoItemUI.__inner_impl.UpdateWeaponAppearanceInfo then
            if not MyMainWeaponInfoItemUI.__inner_impl._lex_appearance_v3 then
                MyMainWeaponInfoItemUI.__inner_impl._lex_appearance_v3 = true
                local orig = MyMainWeaponInfoItemUI.__inner_impl.UpdateWeaponAppearanceInfo
                MyMainWeaponInfoItemUI.__inner_impl.UpdateWeaponAppearanceInfo = function(self, TypeSpecificID, BattleData, DragOrigin)
                    pcall(function()
                        local baseID = F.baseWeaponIDFromAny(TypeSpecificID)
                        local skinID = F.getModSkinForWeapon(TypeSpecificID)
                        self.NVHWeaponBaseID = baseID
                        self.NVHWeaponSkinID = skinID
                        _G.LexusCurrentBackpackWeaponSkin = skinID
                    end)
                    return orig(self, TypeSpecificID, BattleData, DragOrigin)
                end
                lexDbg("hook appearance OK")
            end
        end

        -- (2) Ô phụ kiện: thay icon gốc bằng icon skin VIP
        if MyFittingSlotItemUI and MyFittingSlotItemUI.__inner_impl and MyFittingSlotItemUI.__inner_impl.UpdateSlotItem then
            if not MyFittingSlotItemUI.__inner_impl._lex_slot_v3 then
                MyFittingSlotItemUI.__inner_impl._lex_slot_v3 = true
                local orig = MyFittingSlotItemUI.__inner_impl.UpdateSlotItem
                MyFittingSlotItemUI.__inner_impl.UpdateSlotItem = function(self, resID, defineID, dragOrigin, additionalDataType)
                    local renderID = resID
                    local patchedDefineID = defineID
                    if _G.LexusConfig.SkinAttachment then -- Check công tắc phụ kiện
                        pcall(function()
                            local baseID = tonumber(resID) or 0
                            if baseID > 0 and baseID < 1000000 then
                                local weaponSkinID = _G.LexusCurrentBackpackWeaponSkin
                                pcall(function()
                                    if self and self.parentWeaponInfo and self.parentWeaponInfo.NVHWeaponSkinID then
                                        weaponSkinID = tonumber(self.parentWeaponInfo.NVHWeaponSkinID) or weaponSkinID
                                    end
                                end)
                                
                                local skinID = F.getAttachmentSkinForBase(baseID, weaponSkinID)
                                if skinID then
                                    renderID = skinID
                                    lexDbg("slot res=" .. tostring(resID) .. " -> skin=" .. tostring(skinID))
                                    
                                    -- Mấu chốt: Phải thay đổi cả defineID.TypeSpecificID vì UI vẽ dựa vào nó!
                                    pcall(function()
                                        if defineID and defineID.clone then
                                            patchedDefineID = defineID:clone()
                                        end
                                        if not patchedDefineID then patchedDefineID = defineID end
                                        patchedDefineID.TypeSpecificID = renderID
                                    end)
                                end
                            end
                        end)
                    end
                    return orig(self, renderID, patchedDefineID, dragOrigin, additionalDataType)
                end
                lexDbg("hook slot OK")
            end
        end
    end)

    F.hookEnterGame()

-- ==============================================================================
-- [THÊM MỚI] LOGIC KILL MESSENGER, DEADBOX, BỘ ĐẾM KILL & ICON TỪ CODE MẪU
-- ==============================================================================
local function decodeExpand(expandContent)
    local ok, exp = pcall(function() return slua.LuaArchiverDecode(LuaStateWrapper, expandContent) or {} end)
    return ok and exp or {}
end

local function encodeExpand(exp)
    return slua.LuaArchiverEncode(LuaStateWrapper, exp or {})
end

local _cachedMyName = nil
local function isMyKill(data)
    if not data then return false end
    if data.bIamCauser then return true end
    -- Tối ưu: Chỉ lấy tên 1 lần duy nhất, tránh gọi C++ SLUA hàng ngàn lần
    if not _cachedMyName then
        local hud = slua_GameFrontendHUD
        if hud then
            local pc = hud:GetPlayerController()
            if slua.isValid(pc) then
                local ch = pc:GetPlayerCharacterSafety()
                if slua.isValid(ch) then _cachedMyName = ch:GetPlayerNameSafety() end
            end
        end
    end
    if not _cachedMyName or _cachedMyName == "" then return false end
    return data.Causer == _cachedMyName or data.CauserRealPlayerName == _cachedMyName or data.CauserPlayerName == _cachedMyName
end

local function getCurrentWeaponSkinID()
    -- [ĐÃ FIX] Lấy chính xác Skin ID của cây súng ĐANG CẦM TRÊN TAY để tránh hiện nhầm Kill Message
    local hud = slua_GameFrontendHUD
    if not hud then return 0 end
    local pc = hud:GetPlayerController()
    if not slua.isValid(pc) then return 0 end
    local ch = pc:GetPlayerCharacterSafety()
    if not slua.isValid(ch) then return 0 end
    
    local currWeapon = ch:GetCurrentWeapon()
    if slua.isValid(currWeapon) and currWeapon.synData then
        local currentSkinID = 0
        pcall(function()
            local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
            local skinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
            
            -- Chỉ xuất Kill Message nếu súng trên tay thực sự là súng VIP (ID > 1000000)
            if skinID > 1000000 then 
                currentSkinID = skinID
            end
        end)
        return currentSkinID
    end
    return 0
end

local _downloadedAssetsCache = {}
local function downloadTeamAssets(skinID)
    if not skinID or skinID == 0 or skinID == 69 then return end
    -- Tối ưu: Chỉ tải 1 lần duy nhất mỗi skin, tránh spam băng thông và CPU
    if _downloadedAssetsCache[skinID] then return end
    _downloadedAssetsCache[skinID] = true

    pcall(function()
        local PufferManager = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {skinID})
        
        local cfg = CDataTable.GetTableData("TeamKillBroadcast", skinID)
        if cfg then
            if cfg.EffectPath and cfg.EffectPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.EffectPath})
            end
            if cfg.BgPath and cfg.BgPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.BgPath})
            end
        end
    end)
end

local function patchTeamKill(messageData)
    if not _G.LexusConfig.KillMessage then return messageData end -- [CHẶN NẾU TẮT CÔNG TẮC]
    if not messageData or not isMyKill(messageData) then return messageData end
    local currentSkinID = getCurrentWeaponSkinID()
    if not currentSkinID or currentSkinID == 0 or currentSkinID == 69 then return messageData end
    local broadcastCfg = CDataTable.GetTableData("TeamKillBroadcast", currentSkinID)
    if not broadcastCfg or (not broadcastCfg.BgPath and not broadcastCfg.EffectPath) then return messageData end
    pcall(function()
        local exp = decodeExpand(messageData.ExpandDataContent)
        exp.CauserWeaponAvatarID = currentSkinID
        messageData.ExpandDataContent = encodeExpand(exp)
        messageData.bShowBottomBothSidesKillInfo = true
        messageData.bIamCauser = true
        downloadTeamAssets(currentSkinID)
    end)
    return messageData
end

local function installTeamBroadcastHooks()
    local function wrapCopy(mod, tag)
        if not mod then return end
        local impl2 = mod.__inner_impl or mod
        if not impl2 or not impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable then return end
        local key = "__teamKillCopy_" .. tag
        if not impl2[key] then impl2[key] = impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable end
        local O_Copy = impl2[key]
        impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
            local copied = O_Copy(self, messageData)
            
            -- [TỐI ƯU TUYỆT ĐỐI] Nếu tắt Kill Message -> Bỏ qua toàn bộ logic bên dưới, trả về nguyên bản của game luôn.
            if not _G.LexusConfig.KillMessage then return copied end
            
            local ok2, result = pcall(function() return patchTeamKill(copied) end)
            if ok2 then return result end
            return copied
        end
    end
    pcall(function() wrapCopy(require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "base") end)
    pcall(function() wrapCopy(require("GameLua.Mod.SingleTraining.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "training") end)
end

-- Khởi tạo hệ thống Kill Count
_G.killCountInfo = {
    [101001] = 0000, [101004] = 0000, [101003] = 0000, [103001] = 0000,
    [102001] = 0000, [105001] = 0000, [102002] = 0000, [103002] = 0000
}

function _G.saveKillCountToFile()
    -- Đã làm rỗng hàm lưu file để chống Drop FPS
end

function _G.loadKillCountFromFile()
    -- Đã làm rỗng hàm đọc file để chống Drop FPS
end

function _G.addKill(weaponID, count)
    if not weaponID or not count then return end
    _G.killCountInfo[weaponID] = (_G.killCountInfo[weaponID] or 0) + count
    _G.saveKillCountToFile()
end

function _G.getKills(weaponID) return weaponID and _G.killCountInfo[weaponID] or 0 end

-- Hook Deadbox (Tạo Hòm Xác) và KillInfo
pcall(function()
    local SKillInfo = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
    local SKillInfoModuleManager = require("client.module_framework.ModuleManager")
    local UEnums = _ENV.UEnums
    local ECharacterHealthStatus = import("ECharacterHealthStatus")
    
    if SKillInfo and SKillInfo.__inner_impl and SKillInfo.__inner_impl.FileItem then
        local O_FileItem = SKillInfo.__inner_impl.FileItem
        SKillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
            if not self or not DamageRecordData then return end

            -- [TỐI ƯU TUYỆT ĐỐI] Tắt cả 3 chức năng -> Trả về game gốc ngay lập tức, siêu nhẹ
            if not _G.LexusConfig.SkinDeadBox and not _G.LexusConfig.KillCountUI and not _G.LexusConfig.KillMessage then
                return O_FileItem(self, DamageRecordData)
            end

            local LogicKillCounter = SKillInfoModuleManager.GetModule(SKillInfoModuleManager.CommonModuleConfig.LogicKillCounter)
            if not LogicKillCounter then return O_FileItem(self, DamageRecordData) end

            local uCharacter = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() and slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            if not uCharacter or not slua.isValid(uCharacter) then return O_FileItem(self, DamageRecordData) end

            local SelfName = uCharacter:GetPlayerNameSafety()
            local bIsCauser = DamageRecordData.Causer == SelfName

            if bIsCauser then
                if DamageRecordData.DamageType == UEnums.DamageType.VehicleDamage then
                    if _G.LexusConfig.SkinDeadBox or _G.LexusConfig.KillMessage then 
                        local carSkinID = _G.CurrentEquipVehicleID or 0
                        if carSkinID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            ExpandData.CauserVehicleSkinID = carSkinID
                            if _G.LexusConfig.KillMessage then -- CHỈ BẬT MỚI ÉP SKIN LÊN KILL FEED
                                self:ChangeInfoBgByWeaponAvatarIDLua(carSkinID)
                                DamageRecordData.CauserWeaponAvatarID = carSkinID
                                DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                            end
                            DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                        end
                    end
                elseif DamageRecordData.CauserWeaponAvatarID ~= 69 and DamageRecordData.CauserClothAvatarID ~= 69 then
                    local currWeapon = uCharacter:GetCurrentWeapon()
                    if currWeapon and slua.isValid(currWeapon) then
                        local defineID = currWeapon:GetItemDefineID()
                        local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                        if DefineID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            local hasChanged = false

                            local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                            if SupportKillCounter and DamageRecordData.ResultHealthStatus == ECharacterHealthStatus.FinishedLastBreath then
                                local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
                                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                                
                                -- [TỐI ƯU FPS] Súng Mod luôn có ID lớn hơn 1.000.000 (Ví dụ M4 Băng: 1101004046)
                                if SkinID > 1000000 then 
                                    if _G.LexusConfig.KillCountUI then 
                                        ExpandData.KillCounterItemId = DefineID
                                        ExpandData.KillCounterNum = (ExpandData.KillCounterNum or 0) + 1
                                        _G.addKill(DefineID, 1)
                                        hasChanged = true
                                    end
                                    if _G.LexusConfig.SkinDeadBox then 
                                        _G.NeedCheckDeadBoxTimer = 5 
                                        hasChanged = true
                                    end
                                end
                            end

                            if hasChanged or _G.LexusConfig.KillMessage then
                                _G.UpdateMyKillCounter = true
                                if _G.LexusConfig.KillMessage then -- CHỈ BẬT MỚI THAY ĐỔI GÓI TIN ĐỂ HIỆN TRÊN TOP
                                    local synData = currWeapon.synData
                                    if synData and slua.isValid(synData) then
                                        local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                                        if weaponDefineID and slua.isValid(weaponDefineID) then
                                            DamageRecordData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                                        end
                                    end
                                    DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                                end
                                DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                            end
                        end
                    end
                end
            end
            O_FileItem(self, DamageRecordData)
        end
    end
end)

-- Hook UI Kill Counter (Cập nhật số đếm & Icon trên màn hình)
pcall(function()
    local MyMainKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainKillCounter")
    local MyKillCountSubSystem = require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
    local MyMainWeaponInfoItemUI = require("GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI")
    local MyMainWeaponKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainWeaponKillCounter")
    local SlotBase = require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
    local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    local UIManager = require("client.slua_ui_framework.manager")
    local ModuleManager = require("client.module_framework.ModuleManager")

    if MyKillCountSubSystem and MyKillCountSubSystem.__inner_impl then
        _G.OurkillCountSystem = MyKillCountSubSystem.__inner_impl
        
        local o_OnRefreshUI = MyMainKillCounter.__inner_impl.OnRefreshUI
        MyMainKillCounter.__inner_impl.OnRefreshUI = function(self, _, _, UID)
            if not _G.LexusConfig.KillCountUI then return end -- CHẶN KHI TẮT
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, self.WeaponID)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self.KillCounterItem:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), SkinID)
            end
        end

        MyKillCountSubSystem.__inner_impl.CheckSupportKCUI = function(self) return _G.LexusConfig.KillCountUI end

        local o_UpdateMainKillCounterUI = MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
            -- [TỐI ƯU TUYỆT ĐỐI] Bóp nghẹt ngay lệnh gọi UI của Game nếu đang tắt, CHỐNG CHỚP (FLASH)
            if not _G.LexusConfig.KillCountUI then
                o_UpdateMainKillCounterUI(self, false, WeaponID, AvatarID) -- Ép tham số False
                local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
                return
            end

            o_UpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID)
            local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
         
            if not bShow and MainKillCounter then
                UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
            elseif bShow and currweapon ~= nil then
                local DefineID = currweapon:GetItemDefineID().TypeSpecificID
                local currentEquipAvatrid = slua.IndexReference(currweapon.synData:Get(7), "defineID").TypeSpecificID
                local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                
                local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, currentEquipAvatrid)
                
                -- [TỐI ƯU FPS] NHẬN DIỆN SÚNG MOD: Súng thường ID < 1.000.000, Súng Mod ID > 1.000.000
                local isModdedSkin = (currentEquipAvatrid and currentEquipAvatrid > 1000000)
                
                -- Đóng UI nếu là súng lục, dao, CHẢO hoặc SÚNG THƯỜNG KHÔNG CÓ SKIN
                if (SupportKillCounter == nil or not isModdedSkin) then
                    if MainKillCounter then
                        UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
                    end
                else
                    -- Hiện UI nếu là súng Mod (Dù curEquipedKillCounter có trả về nil do server không nhận diện được)
                    if not MainKillCounter then
                        UIManager.ShowUI(UIManager.UI_Config_InGame.MainKillCounter, DefineID, currentEquipAvatrid)
                        MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                        if MainKillCounter then
                            MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                        end
                    else
                        MainKillCounter:UpdateWeaponID(DefineID, currentEquipAvatrid)
                        MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                    end
                end
            end
        end

        local o_CheckNeedMainKillCounterUI = MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI = function(self, Weapon, PlayerID)
            if not _G.LexusConfig.KillCountUI then return end -- CHẶN KHI TẮT
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self:UpdateMainKillCounterUI(true, DefineID, SkinID)
            end
        end
    end
end)

-- Vòng lặp Updater (Đã tối ưu Cache: Chỉ Update UI khi đổi súng hoặc có mạng Kill)
local _lastKCWeaponID = 0
local _lastKCSkinID = 0

_G.GameAvatarHandlerkillcounter = function()
    local UIManager = require("client.slua_ui_framework.manager")
    
    if not _G.LexusConfig.KillCountUI then
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
        return 
    end

    local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not PlayerController or not slua.isValid(PlayerController) then return end
    
    local uCharacter = PlayerController:GetPlayerCharacterSafety()
    if not uCharacter or not slua.isValid(uCharacter) then return end
    
    local currweapon = uCharacter:GetCurrentWeapon()
    if currweapon and slua.isValid(currweapon) then
        -- Lấy DefineID an toàn, không tạo rác RAM
        local defineIDObj = currweapon:GetItemDefineID()
        local currentWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
        
        -- Lấy Skin ID từ Cache của hệ thống Skin V7.5 (Cực nhẹ, không gọi SLUA)
        local currentSkinID = 0
        if _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[currentWeaponID] then
            currentSkinID = _G.AddOutfitLastAppliedSkin[currentWeaponID]
        end

        -- TỐI ƯU CỰC ĐỘ: Chỉ gửi lệnh cập nhật UI nếu MỚI ĐỔI SÚNG hoặc MỚI GIẾT NGƯỜI
        if _G.UpdateMyKillCounter or currentWeaponID ~= _lastKCWeaponID or currentSkinID ~= _lastKCSkinID then
            _lastKCWeaponID = currentWeaponID
            _lastKCSkinID = currentSkinID
            _G.UpdateMyKillCounter = false
            
            if _G.OurkillCountSystem then
                _G.OurkillCountSystem:UpdateMainKillCounterUI(true, currentWeaponID, currentSkinID)
            end
        end
    else
        _lastKCWeaponID = 0
        _lastKCSkinID = 0
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
    end
end

local function LobbyTickSetup()
    if not _G.CounterUpdated then
        _G.CounterUpdated = true
        _G.loadKillCountFromFile()
    end
    -- ĐÃ XÓA LOGIC QUÉT FILE translateec.conf LIÊN TỤC GÂY LAG
end

-- Kích hoạt Hooks và Loop
pcall(function()
    installTeamBroadcastHooks()
    LobbyTickSetup() -- Chỉ gọi đọc file 1 lần duy nhất khi vào game, không lặp lại nữa
    
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, _G.GameAvatarHandlerkillcounter, -1, 0.5)
        -- ĐÃ XÓA VÒNG LẶP ĐỌC FILE 0.4 GIÂY ĐỂ TRÁNH DROP FPS
    end
end)
-- ==============================================================================

    F.startVehicleSkinTicker()
    if not _G.AddOutfitVehInitTimers then
        _G.AddOutfitVehInitTimers = true
        F.later(1.5, function() pcall(F.applyVehicleSkinsToPC) end)
        F.later(4.0, function() pcall(F.applyVehicleSkinsToPC) end)
    end

    pcall(function()
        if F.isInRealMatch() then
            local char = F.getLocalChar()
            if char then
                F.bootstrapMatch(char)
            end
        end
    end)

    local firstLobby = not _G.AddOutfitLobbyInitDone
    if F.injectAll() then
        if firstLobby then _G.AddOutfitLobbyInitDone = true end
        F.afterInjectApply(firstLobby)
        return
    end
    local tries = 0
    local function retry()
        tries = tries + 1
        if F.injectAll() then
            local ft = not _G.AddOutfitLobbyInitDone
            if ft then _G.AddOutfitLobbyInitDone = true end
            F.afterInjectApply(ft)
            return
        end
        if tries < INJECT_RETRY_MAX then F.later(INJECT_RETRY_SEC, retry) end
    end
    F.later(INJECT_RETRY_SEC, retry)
end

_G.AddOutfit = F
F.start()
-- ==========================================================
-- [FIX] FORCE REAPPLY SKIN IN MATCH (safety net)
-- ==========================================================
pcall(function()
    local ticker = require("common.time_ticker")
    if not (ticker and ticker.AddTimerLoop) then return end
    ticker.AddTimerLoop(0, function()
        if not _G.LexusConfig or not _G.LexusConfig.ModSkin then return end
        if not _G.AddOutfit then return end
        -- Only work in real match (not lobby)
        if not _G.AddOutfit.isInRealMatch() then return end
        local char = _G.AddOutfit.getLocalChar and _G.AddOutfit.getLocalChar()
        if not char or not slua.isValid(char) then return end
        -- If the watcher never started, start it
        if not _G.AddOutfitReadyForMatch then
            _G.AddOutfitReadyForMatch = true
            pcall(function() _G.AddOutfit.bootstrapMatch(char) end)
        else
            -- Nudge it repeatedly in case the first apply was too early
            pcall(function()
                if _G.AddOutfit.matchApplyAllSlots then _G.AddOutfit.matchApplyAllSlots(char) end
                if _G.AddOutfit.matchApplyHat then _G.AddOutfit.matchApplyHat(char) end
                if _G.AddOutfit.matchApplyWeaponSkin then _G.AddOutfit.matchApplyWeaponSkin(char) end
            end)
        end
    end, -1, 2.0)
end)

-- Reset flag when leaving match back to lobby
pcall(function()
    if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_ENTER_GAME_BEGIN then
        EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, function()
            _G.AddOutfitReadyForMatch = false
        end)
    end
end)
local function AutoRestoreLobbySkin()
    if _G.AddOutfitLobbyRestored then return end
    
    -- [FIX VIP] Chặn không cho tự load skin khi vừa mở game nếu công tắc đang tắt
    if not _G.LexusConfig.ModSkin then return end
    
    -- [CỜ NGỦ ĐÔNG LOBBY]: Nếu đã leo lên máy bay vào trận -> Ngủ luôn, không đọc file Sảnh nữa!
    if _G.AddOutfit and _G.AddOutfit.isInRealMatch() then return end
    
    pcall(function()
        if GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() then
            -- Chờ DataMgr tải xong UID của nhân vật (Tránh lỗi load sớm quá bị tịt)
            if DataMgr and DataMgr.roleData and DataMgr.roleData.uid then
                local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
                if LMC and LMC.GetCurPage then
                    if _G.AddOutfit and _G.AddOutfit.reapplyLobbyEquipped then
                        -- Bắn liên hoàn lệnh: Đọc File -> Gán Data -> Vẽ lên nhân vật
                        _G.AddOutfit.persistLoadFromDisk() 
                        _G.AddOutfit.persistApplyLoaded() 
                        _G.AddOutfit.reapplyLobbyEquipped() 
                        
                        -- Chốt cờ đã hoàn thành
                        _G.AddOutfitLobbyRestored = true
                    end
                end
            end
        end
    end)
end

-- Chạy ngầm 1 giây / lần lúc vừa vô game, load xong là tự động ngưng
pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, AutoRestoreLobbySkin, -1, 1.0)
    end
end)

-- ==========================================================
-- ========== MENU SYSTEM ===================================
-- ==========================================================

local function T(vnText, enText)
    return enText or vnText
end

local function InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true

    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end

    local FakeTextMap = {
        [999000] = T(" @OFFICAL_KASHMIRY1VIPMOD", "@OFFICAL_KASHMIRY1VIPMOD"),
        [999004] = T("OFFICAL_KASHMIRY1VIPMOD", "OFFICAL_KASHMIRY1VIPMOD"),
[999005] = "ALL SKINS",
[999006] = T("ESP (VISUALS)", "ESP (VISUALS)"),
[999001] = T("WALLHACK", "WALLHACK"),
[999003] = T("AIMBOT ROYAL", "AIMBOT"),
    }

    if LocUtil and not LocUtil._IsModMenuHooked_V2 then
        local hookFuncs = {"GetLocalizeResStr", "GetText", "GetTextByID", "GetLocalText", "GetLocalizeStr"}
        for _, funcName in ipairs(hookFuncs) do
            if LocUtil[funcName] then
                local old_func = LocUtil[funcName]
                LocUtil[funcName] = function(id)
                    if FakeTextMap[id] then return FakeTextMap[id] end
                    if type(id) == "string" and not tonumber(id) then return id end
                    if old_func then return old_func(id) end
                    return ""
                end
            end
        end
        LocUtil._IsModMenuHooked_V2 = true
    end

    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")

        if not SettingPageDefine.ModMenu then
        local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")

        local StackCombat = {
    { Key = "ModMenu_FakeHWID", UI = AliasMap.Switcher,
      Text = T("🛡️ Fake HWID (Anti-Ban)", "🛡️ Fake HWID (Anti-Ban)"),
      GetFunc = function() return _G.LexusConfig.FakeHWID end,
      SetFunc = function(c,v) _G.LexusConfig.FakeHWID = v; return true end },

    { Key = "ModMenu_FakePlayerData", UI = AliasMap.Switcher,
      Text = T("👑 Unlimited UC & Conq Frame", "👑 Unlimited UC & Conq Frame"),
      GetFunc = function() return _G.LexusConfig.FakePlayerData end,
      SetFunc = function(c,v)
          _G.LexusConfig.FakePlayerData = v
          if v and _G.InitFakePlayerData then pcall(_G.InitFakePlayerData) end
          return true
      end },

    { Key = "ModMenu_WallhackNew", UI = AliasMap.Switcher,
      Text = T("🔴 Wallhack NEW (DrawDyeing)", "Wallhack NEW"),
      GetFunc = function() return _G.LexusConfig.WallhackNew end,
      SetFunc = function(c,v)
          _G.LexusConfig.WallhackNew = v
          if v then
              if _G.StartNewWallhack then pcall(_G.StartNewWallhack) end
          else
              if _G.StopNewWallhack then pcall(_G.StopNewWallhack) end
          end
          return true
      end },

    { Key = "ModMenu_BypassEnable", UI = AliasMap.Switcher,
      Text = T("🛡️ Bypass System (Restart Match)", "Bypass System"),
      GetFunc = function() return _G.LexusConfig.BypassEnable end,
      SetFunc = function(c,v)
          _G.LexusConfig.BypassEnable = v
          if v and _G.StartBypass_VIP_v3 then pcall(_G.StartBypass_VIP_v3) end
          return true
      end },
{ Key = "ModMenu_Aimbot_Enable", UI = AliasMap.Switcher,
  Text = T("🎯 AIMBOT (Locked Config)", "🎯 AIMBOT (Locked Config)"),
  GetFunc = function() return _G.LexusConfig.AimTouchEnable end,
  SetFunc = function(c,v) _G.LexusConfig.AimTouchEnable = v; return true end },
}
local StackSkin = {
            
            { Key = "ModMenu_ModEmote", UI = AliasMap.Switcher, Text = T("Mở Khóa Full Hành Động VIP (Emotes)", "Unlock All VIP Emotes"), GetFunc = function() return _G.LexusConfig.ModEmote end, SetFunc = function(c,v) _G.LexusConfig.ModEmote = v return true end },
            { Key = "ModMenu_ModSkin", UI = AliasMap.Switcher, Text = T("Hệ Thống Mod Skin VIP (Mở túi đồ chọn)", "VIP Mod Skin System (Open inventory)"), GetFunc = function() return _G.LexusConfig.ModSkin end, SetFunc = function(c,v) _G.LexusConfig.ModSkin = v; if v and _G.AddOutfit then pcall(function() _G.AddOutfit.injectAll(); _G.AddOutfit.refreshWardrobe(); _G.AddOutfit.reapplyLobbyEquipped() end) end; return true end },
            { Key = "ModMenu_SkinDeadBox", UI = AliasMap.Switcher, Text = T("Skin Hòm Xác (Ăn theo skin Súng/Xe)", "Deadbox Skin (Sync with Weapon)"), GetFunc = function() return _G.LexusConfig.SkinDeadBox end, SetFunc = function(c,v) _G.LexusConfig.SkinDeadBox = v return true end },
            { Key = "ModMenu_SkinAttachment", UI = AliasMap.Switcher, Text = T("Skin Phụ Kiện Súng (Nòng, Tay cầm...)", "Weapon Attachment Skin"), GetFunc = function() return _G.LexusConfig.SkinAttachment end, SetFunc = function(c,v) _G.LexusConfig.SkinAttachment = v return true end },
            { Key = "ModMenu_KillMessage", UI = AliasMap.Switcher, Text = T("Kill Messenger VIP", "VIP Kill Messenger"), GetFunc = function() return _G.LexusConfig.KillMessage end, SetFunc = function(c,v) _G.LexusConfig.KillMessage = v return true end },
            { Key = "ModMenu_KillCountUI", UI = AliasMap.Switcher, Text = T("Bộ Đếm Kill (Hiển thị số Kill vũ khí)", "Kill Counter UI"), GetFunc = function() return _G.LexusConfig.KillCountUI end, SetFunc = function(c,v) _G.LexusConfig.KillCountUI = v return true end }
     }       
        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text = 999000,
            UIKey = "Setting_Page_Privacy",
            Category = {{ Key = "Cat_Skin", Text = 999005, Stack = StackSkin },
                { Key = "Cat_Combat", Text = 999004, Stack = StackCombat },
            }
        }

        table.insert(SettingCatalog, 1, SettingPageDefine.ModMenu)
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...)
            if config and config.keyName then
                local lowerKeyName = string.lower(config.keyName)
                if string.find(lowerKeyName, "setting_main") and not string.find(lowerKeyName, "custom") then
                    local catalog = args[1]
                    if type(catalog) == "table" and catalog[1] and type(catalog[1]) == "table" and catalog[1].Key then
                        local hasModMenu = false
                        for _, page in ipairs(catalog) do
                            if type(page) == "table" and page.Key == "ModMenu" then
                                hasModMenu = true
                                break
                            end
                        end
                        if not hasModMenu then table.insert(catalog, 1, SettingPageDefine.ModMenu) end
                    end
                end
            end
            local table_unpack = table.unpack or unpack
            return old_ShowUI(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end
end

-- ==========================================================
-- ========== EXPIRY POPUP + LOCK ===========================
-- ==========================================================
local function ShowExpiredPopup()
    if _G.LexusExpiredPopupShown then return end
    _G.LexusExpiredPopupShown = true
    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then
            Msg.Show(1, "MOD BYPASS EXPIRED",
                "YOUR BYPASS  HAS EXPIRED!\nPLEASE CONTACT ADMIN TO UPDATE IT RENEW.\nInbox Tele @OFFICAL_KASHMIRY1VIPMOD",
                function()
                    local Web = require("client.slua.logic.url.logic_webview_sdk")
                    if Web and Web.OpenURL then Web:OpenURL("https://t.me/O52NhuIADWM3MTc0") end
                end,
                function() end, "CONTACT ADMIN", "CLOSE")
        end
    end)
end

if isExpired then
    -- Block everything when expired
    pcall(function()
        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(2.0, ShowExpiredPopup)
        end
    end)
   
end
-- Auto-start bypass a few seconds after load (lets subsystems initialize first)
pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(2.5, function()
            if _G.StartBypass_VIP_v3 then pcall(_G.StartBypass_VIP_v3) end
        end)
        -- Re-run once more after lobby load (some subsystems register late)
        ticker.AddTimerOnce(8.0, function()
            if _G.StartBypass_VIP_v3 then pcall(_G.StartBypass_VIP_v3) end
        end)
    end
end)
-- Aimbot loop runner
pcall(function()
    _G.LexusState = _G.LexusState or {}
    _G.LexusState.AimbotLoopToken = (_G.LexusState.AimbotLoopToken or 0) + 1
    local myAimbotToken = _G.LexusState.AimbotLoopToken

    local function FastAimbotTick()
    -- if _G.LexusExpired then return end   -- [DISABLED — was killing aimbot]
    if myAimbotToken ~= _G.LexusState.AimbotLoopToken then return end
        pcall(function()
            if _G.LexusConfig.AimTouchEnable and type(_G.AimTouch) == "function" then
                _G.AimTouch()
            end
        end)
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(0.033, FastAimbotTick) -- ~30 FPS
        end
    end

    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.5, FastAimbotTick)
    end
end)

pcall(function()
    InitModMenuTab()
    Notify("@OFFICAL_KASHMIRY1VIPMOD Loaded! Open Settings -> @@OFFICAL_KASHMIRY1VIPMOD")
end)

-- ==========================================================
-- ========== AUTO-INIT =====================================
-- ==========================================================

pcall(function()
    if _G.LexusConfig and _G.LexusConfig.FakePlayerData and _G.InitFakePlayerData then
        _G.InitFakePlayerData()
    end
end)



-- ==========================================================
-- ========== END OF FILE ===================================
-- ==========================================================
local function TSSPacketFilter(playerId, tssData)
    if not playerId or playerId == "" then
        return false, nil
    end

    -- Agar data empty hai toh skip
    if not tssData or tssData == "" then
        return false, nil
    end

    local blacklist = {
        "hook",
        "inject",
        "cheat",
        "mod",
        "detect",
        "ban",
        "violation",
        "tamper",
        "memory",
        "debug",
        "FuckSmartHooks",
        "libanogs",
        "libtersafe",
        "TSSHeartBeat",
        "tss_heart_beat"
    }
    if type(tssData) == "string" then
        for _, pattern in ipairs(blacklist) do
            if string.find(tssData, pattern, 1, true) then
                print("[WARN] Blocked suspicious TSS data")
                return true, "BLOCKED" 
            end
        end
    end

    local dataSize = 0
    if type(tssData) == "string" then
        dataSize = #tssData
    elseif type(tssData) == "table" then
        dataSize = #tssData
    end

    if dataSize > 1024 then
        print("[WARN] TSS data too large, truncating")
        if type(tssData) == "string" then
            tssData = string.sub(tssData, 1, 1024)
        end
    end

    return true, "MOCK_SUCCESS_STUB"
end

-- Main handler function
function MockServer_HandleTssPacket(playerId, tssData)
    return TSSPacketFilter(playerId, tssData)
end
-- ============================================================
-- PURPLE VIP MENU (TRIMMED — only working features)
-- ============================================================
pcall(function()

local log = function(msg) print("[SH Menu] " .. tostring(msg)) end
log("Trimmed menu loading")

_G.SHConfig        = _G.SHConfig        or _G.LexusConfig
_G.XthrlenConfig   = _G.XthrlenConfig   or _G.LexusConfig
_G.SHgamingConfig  = _G.SHgamingConfig  or _G.LexusConfig
_G.SHgamingState   = _G.SHgamingState   or _G.LexusState
_G.XthrlenState    = _G.XthrlenState    or _G.LexusState
_G.SHgamingState.CustomTextData = _G.SHgamingState.CustomTextData or {}
_G.XthrlenState.CustomTextData  = _G.XthrlenState.CustomTextData  or _G.SHgamingState.CustomTextData
_G.SHgamingState.CustomTextData = _G.XthrlenState.CustomTextData

-- Ensure LexusConfig keys exist as SH-style toggles (0/1) so UI can read them
local function EnsureKey(key)
    if _G.LexusConfig[key] == nil then _G.LexusConfig[key] = false end
    _G.SHConfig[key] = _G.LexusConfig[key] and 1 or 0
end
EnsureKey("ModSkin"); EnsureKey("ModEmote"); EnsureKey("SkinDeadBox"); EnsureKey("SkinAttachment")
EnsureKey("KillMessage"); EnsureKey("KillCountUI")
EnsureKey("FakeHWID"); EnsureKey("FakePlayerData"); EnsureKey("WallhackNew"); EnsureKey("BypassEnable")
EnsureKey("AimTouchEnable")

local function ReadKeyValue(key, fallback)
    if _G.SHConfig[key] ~= nil then return _G.SHConfig[key] end
    if _G.LexusConfig[key] ~= nil then return _G.LexusConfig[key] and 1 or 0 end
    return fallback
end

local function WriteKeyValue(key, value, isToggle)
    _G.SHConfig[key] = value
    if isToggle then
        _G.LexusConfig[key] = (value == 1)
    else
        _G.LexusConfig[key] = value
    end
end

_G.SHMenuSave = function() end

-- Save/Load to XThrlen_settings.txt (only for the keys we use)
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
            end
        end
    end)
    return paths
end

local CONFIG_FILE = "@OFFICAL_KASHMIRY1_settings.txt"
local SAVED_KEYS = {"ModSkin","ModEmote","SkinDeadBox","SkinAttachment","KillMessage","KillCountUI",
                    "FakeHWID","FakePlayerData","WallhackNew","BypassEnable","AimTouchEnable"}

pcall(function()
    for _, path in ipairs(GetConfigPaths(CONFIG_FILE)) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*a") f:close()
            if content and #content > 0 then
                local func = load(content)
                if func then
                    local saved = func()
                    if saved and type(saved) == "table" then
                        local src = saved.XthrlenConfig or saved.SHConfig
                        if src then
                            for _, k in ipairs(SAVED_KEYS) do
                                if src[k] ~= nil then
                                    local b = (src[k] == true) or (src[k] == 1)
                                    _G.LexusConfig[k] = b
                                    _G.SHConfig[k] = b and 1 or 0
                                end
                            end
                        end
                    end
                end
            end
            break
        end
    end
end)

local _lastSaveStr = ""
_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\n@OFFICAL_KASHMIRY1Config = {\n"
        for _, k in ipairs(SAVED_KEYS) do
            local b = _G.LexusConfig[k] and true or false
            data = data .. "  [\"" .. k .. "\"] = " .. tostring(b) .. ",\n"
        end
        data = data .. "}\n}\n"
        if data == _lastSaveStr then return end
        _lastSaveStr = data
        for _, path in ipairs(GetConfigPaths(CONFIG_FILE)) do
            local f = io.open(path, "w")
            if f then f:write(data) f:close() break end
        end
    end)
end

local _savePending = false
local function ScheduleSave()
    if _savePending then return end
    _savePending = true
    pcall(function()
        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(0.5, function() _savePending = false _G.SaveModSettings() end)
        end
    end)
end
_G.SHMenuSave = ScheduleSave

-- ============================================================
-- UI HELPERS
-- ============================================================
local function SafeImport(name, fallbackPath)
    local ok, v = pcall(import, name)
    if ok and v ~= nil then return v end
    if fallbackPath then local ok2, v2 = pcall(import, fallbackPath) if ok2 and v2 ~= nil then return v2 end end
    if _G and _G[name] ~= nil then return _G[name] end
    return nil
end
local FLinearColor = SafeImport("LinearColor") or _G.FLinearColor
local FVector2D    = SafeImport("Vector2D") or _G.FVector2D
local FSlateColor  = SafeImport("SlateColor", "/Script/SlateCore.SlateColor")
local FMargin      = SafeImport("Margin", "/Script/SlateCore.Margin")
if not FLinearColor then
    FLinearColor = function(r,g,b,a) return {R=r or 1, G=g or 1, B=b or 1, A=a or 1, r=r or 1, g=g or 1, b=b or 1, a=a or 1} end
end
if not FVector2D then
    FVector2D = function(x,y) return {X=x or 0, Y=y or 0, x=x or 0, y=y or 0} end
end

local function IsValid(obj)
    return obj and slua and slua.isValid and slua.isValid(obj)
end

local C = {
    obsidian          = FLinearColor(0.05, 0.02, 0.03, 0.98),   -- Dark burgundy
    obsidian_deep     = FLinearColor(0.02, 0.01, 0.01, 1.00),   -- Near black red
    obsidian_row      = FLinearColor(0.10, 0.04, 0.05, 0.88),   -- Wine row
    obsidian_header   = FLinearColor(0.06, 0.02, 0.03, 0.98),   -- Deep maroon header
    gold              = FLinearColor(1.00, 0.75, 0.15, 1.00),   -- Royal gold
    gold_bright       = FLinearColor(1.00, 0.90, 0.40, 1.00),   -- Bright gold
    gold_dim          = FLinearColor(0.60, 0.40, 0.05, 1.00),   -- Dark gold
    gold_glow         = FLinearColor(1.00, 0.75, 0.15, 0.50),   -- Gold glow
    gold_glow_soft    = FLinearColor(1.00, 0.75, 0.15, 0.22),   -- Soft gold glow
    gold_trace        = FLinearColor(1.00, 0.75, 0.15, 0.08),   -- Gold trace
    purple_aura       = FLinearColor(0.60, 0.05, 0.10, 0.35),   -- Crimson aura
    purple_aura_soft  = FLinearColor(0.40, 0.03, 0.08, 0.18),   -- Soft crimson
    text_white        = FLinearColor(1.00, 0.98, 0.95, 1.00),   -- Warm white
    text_gold         = FLinearColor(1.00, 0.85, 0.45, 1.00),   -- Gold text
    text_dim          = FLinearColor(0.65, 0.55, 0.50, 1.00),   -- Dim warm grey
    toggle_on         = FLinearColor(1.00, 0.75, 0.15, 1.00),   -- Gold ON
    toggle_off        = FLinearColor(0.15, 0.08, 0.08, 1.00),   -- Dark wine OFF
    toggle_knob       = FLinearColor(0.90, 0.85, 0.80, 1.00),   -- Cream knob
    toggle_knob_gold  = FLinearColor(1.00, 0.98, 0.90, 1.00),   -- Bright cream
    white             = FLinearColor(1, 1, 1, 1.0),
    transparent       = FLinearColor(0, 0, 0, 0.01),
    shadow            = FLinearColor(0, 0, 0, 0.98),
    close_red         = FLinearColor(0.85, 0.15, 0.20, 1.00),   -- Bright red
    close_red_glow    = FLinearColor(0.85, 0.15, 0.20, 0.50),   -- Red glow
    online_dot        = FLinearColor(1.00, 0.85, 0.30, 1.00),   -- Gold dot
}
local M_W, M_H = 620, 460
local HEADER_H = 70
local ROW_H = 45
local COL_W = M_W - 40

local parentCanvas, bgPanel = nil, nil
local floatItem = nil
local isMenuOpen, menuBuilt = false, false
local allWidgets = {}

local function NewObject(path, parent)
    local obj = nil
    pcall(function() if CGame and CGame.NewObjectFromPath then obj = CGame:NewObjectFromPath(path, parent) end end)
    return obj
end

local function Layer(parent, x, y, w, h, color, z)
    local b = NewObject("/Script/UMG.Border", parent)
    if IsValid(b) then
        pcall(function() b:SetBrushColor(color) end)
        pcall(function() b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        local slot = parent:AddChildToCanvas(b)
        if slot then
            slot:SetAutoSize(false); slot:SetPosition(FVector2D(x, y)); slot:SetSize(FVector2D(w, h)); slot:SetZOrder(z or 0)
        end
    end
    table.insert(allWidgets, b)
    return b
end

local function Text(parent, txt, x, y, size, color, z, alignX, alignY)
    local t = NewObject("/Script/UMG.TextBlock", parent)
    if IsValid(t) then
        pcall(function() t:SetText(txt) end)
        pcall(function() if FSlateColor then t:SetColorAndOpacity(FSlateColor(color)) else t:SetColorAndOpacity(color) end end)
        pcall(function() if t.Font then local f = t.Font; f.Size = size; t.Font = f end end)
        pcall(function() t:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        local slot = parent:AddChildToCanvas(t)
        if slot then
            slot:SetAutoSize(true); slot:SetAlignment(FVector2D(alignX or 0.5, alignY or 0.5)); slot:SetPosition(FVector2D(x, y)); slot:SetZOrder(z or 100)
        end
    end
    table.insert(allWidgets, t)
    return t
end

local function MakeBtn(parent, x, y, w, h, z, onClick)
    local btn = NewObject("/Script/UMG.Button", parent)
    if IsValid(btn) then
        pcall(function() btn:SetColorAndOpacity(C.transparent) end)
        pcall(function() btn:SetBackgroundColor(C.transparent) end)
        pcall(function() btn:SetWidgetVisibility(UEnums.ESlateVisibility.Visible) end)
        local slot = parent:AddChildToCanvas(btn)
        if slot then
            slot:SetAutoSize(false); slot:SetPosition(FVector2D(x, y)); slot:SetSize(FVector2D(w, h)); slot:SetZOrder(z or 900)
        end
        if onClick then pcall(function() if btn.OnClicked then btn.OnClicked:Add(function() pcall(onClick) end) end end) end
    end
    table.insert(allWidgets, btn)
    return btn
end

local function GetCanvas()
    if IsValid(parentCanvas) then return parentCanvas end
    parentCanvas = nil
    pcall(function()
        local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        local MainUI = InGameUITools.GetMainControlBaseUI()
        if not MainUI or not Game:IsValid(MainUI) then return end
        if MainUI.CanvasPanel_0 and Game:IsValid(MainUI.CanvasPanel_0) then parentCanvas = MainUI.CanvasPanel_0
        elseif MainUI.CanvasPanel_42 and Game:IsValid(MainUI.CanvasPanel_42) then parentCanvas = MainUI.CanvasPanel_42 end
    end)
    return parentCanvas
end

local function ShowMenu() if IsValid(bgPanel) then pcall(function() bgPanel:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end) end end
local function HideMenu() if IsValid(bgPanel) then pcall(function() bgPanel:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) end end

-- Toggle switch with custom callback (for extra actions like InitFakePlayerData / Bypass)
local function MakeToggleInline(parent, x, y, w, label, key, onAfterChange)
    local h = ROW_H
    Layer(parent, x, y, w, h, C.obsidian_row, 200)
    Layer(parent, x, y, 4, h, C.gold, 201)
    Text(parent, label, x + 22, y + h * 0.5, 14, C.text_white, 300, 0, 0.5)

    local tW, tH = 56, 24
    local tX = x + w - tW - 15
    local tY = y + h * 0.5 - tH * 0.5
    local state = (ReadKeyValue(key, 0) == 1)

    if state then
        Layer(parent, tX - 8, tY - 8, tW + 16, tH + 16, C.gold_trace, 296)
        Layer(parent, tX - 5, tY - 5, tW + 10, tH + 10, C.gold_glow_soft, 297)
        Layer(parent, tX - 3, tY - 3, tW + 6, tH + 6, C.gold_glow, 298)
    end

    local track = Layer(parent, tX, tY, tW, tH, state and C.toggle_on or C.toggle_off, 300)
    pcall(function()
        if track.Brush then track.Brush.DrawAs = 1; track.Brush.Margin = FMargin(0.5, 0.5, 0.5, 0.5) end
    end)
    Layer(parent, tX, tY, tW, 1, C.gold_dim, 301)
    Layer(parent, tX, tY + tH - 1, tW, 1, C.gold_dim, 301)

    local kSize = tH - 4
    local kX = state and (tX + tW - kSize - 2) or (tX + 2)
    if state then Layer(parent, kX - 2, tY, kSize + 4, kSize + 4, C.gold_glow, 301) end

    local knob = Layer(parent, kX, tY + 2, kSize, kSize, state and C.toggle_knob_gold or C.toggle_knob, 302)
    pcall(function()
        if knob.Brush then knob.Brush.DrawAs = 1; knob.Brush.Margin = FMargin(0.5, 0.5, 0.5, 0.5) end
    end)

    local stateText = Text(parent, state and "ON" or "OFF", state and (tX + 8) or (tX + tW - 8), y + h * 0.5, 10, state and C.text_gold or C.text_dim, 400, state and 0 or 1, 0.5)

    MakeBtn(parent, x, y, w, h, 900, function()
        local cur = ReadKeyValue(key, 0)
        local newVal = (cur == 1) and 0 or 1
        WriteKeyValue(key, newVal, true)
        state = (newVal == 1)
        pcall(function()
            stateText:SetText(state and "ON" or "OFF")
            local SC = import("SlateColor")
            local newColor = state and C.text_gold or C.text_dim
            if SC then stateText:SetColorAndOpacity(SC(newColor)) else stateText:SetColorAndOpacity(newColor) end
            local sSlot = stateText.Slot
            if sSlot then
                sSlot:SetPosition(FVector2D(state and (tX + 8) or (tX + tW - 8), y + h * 0.5))
                sSlot:SetAlignment(FVector2D(state and 0 or 1, 0.5))
            end
        end)
        pcall(function() track:SetBrushColor(state and C.toggle_on or C.toggle_off) end)
        pcall(function() knob:SetBrushColor(state and C.toggle_knob_gold or C.toggle_knob) end)
        local slot = knob.Slot
        if slot then
            local nkX = state and (tX + tW - kSize - 2) or (tX + 2)
            slot:SetPosition(FVector2D(nkX, tY + 2))
        end
        if onAfterChange then pcall(onAfterChange, state) end
        ScheduleSave()
    end)
end

local function MakeSectionHeader(parent, x, y, w, label)
    local h = 35
    Layer(parent, x, y, w, h, C.obsidian_header, 200)
    Layer(parent, x, y, w, 1, C.gold_trace, 201)
    Layer(parent, x, y + h - 1, w, 1, C.gold_dim, 201)
    Layer(parent, x + 12, y + h * 0.5 - 3, 6, 6, C.gold, 202)
    Layer(parent, x + w - 18, y + h * 0.5 - 3, 6, 6, C.gold, 202)
    Text(parent, "◆ " .. label .. " ◆", x + w * 0.5, y + h * 0.5, 13, C.text_gold, 300, 0.5, 0.5)
    return h
end

-- ============================================================
-- STACKS — only working features
-- ============================================================
local StackSkin = {
    {section = true, label = "SKIN & EMOTE"},
    {label = "Mod Skin VIP", key = "ModSkin",
        after = function(v)
            if v and _G.AddOutfit then
                pcall(function() _G.AddOutfit.injectAll() end)
                pcall(function() _G.AddOutfit.refreshWardrobe() end)
                pcall(function() _G.AddOutfit.reapplyLobbyEquipped() end)
            end
        end},
    {label = "Mod Emote",         key = "ModEmote"},
    {label = "Skin DeadBox",      key = "SkinDeadBox"},
    {label = "Skin Attachment",   key = "SkinAttachment"},
    {label = "Kill Message VIP",  key = "KillMessage"},
    {label = "Kill Counter UI",   key = "KillCountUI"},
}

local StackCombat = {
    {section = true, label = "PROTECTION"},
    {label = "Fake HWID",         key = "FakeHWID"},
    {label = "Unlimited UC",      key = "FakePlayerData",
        after = function(v)
            if v and _G.InitFakePlayerData then pcall(_G.InitFakePlayerData) end
        end},
    {section = true, label = "WALLHACK & BYPASS"},
    {label = "Wallhack NEW",      key = "WallhackNew",
        after = function(v)
            if v then
                if _G.StartNewWallhack then pcall(_G.StartNewWallhack) end
            else
                if _G.StopNewWallhack then pcall(_G.StopNewWallhack) end
            end
        end},
    {label = "Bypass System",     key = "BypassEnable",
        after = function(v)
            if v and _G.StartBypass_VIP_v3 then pcall(_G.StartBypass_VIP_v3) end
        end},
    {section = true, label = "AIMBOT"},
    {label = "Aimbot (Locked)",   key = "AimTouchEnable"},
}

local TOP_TABS = {
    { name = "SKINS",  data = { StackSkin } },
    { name = "COMBAT", data = { StackCombat } },
}

local function BuildColumn(scrollBox, stack)
    local contentPanel = nil
    pcall(function() contentPanel = NewObject("/Script/UMG.VerticalBox", scrollBox); if IsValid(contentPanel) then scrollBox:AddChild(contentPanel) end end)
    if not IsValid(contentPanel) then return end
    local w = COL_W - 15
    for _, opt in ipairs(stack) do
        if opt.section then
            local rowBox = NewObject("/Script/UMG.SizeBox", contentPanel)
            if IsValid(rowBox) then
                rowBox:SetHeightOverride(35); contentPanel:AddChildToVerticalBox(rowBox)
                local rowPanel = NewObject("/Script/UMG.CanvasPanel", rowBox)
                if IsValid(rowPanel) then rowBox:AddChild(rowPanel); MakeSectionHeader(rowPanel, 0, 0, w, opt.label) end
            end
        else
            local rowBox = NewObject("/Script/UMG.SizeBox", contentPanel)
            if IsValid(rowBox) then
                rowBox:SetHeightOverride(ROW_H)
                local slot = contentPanel:AddChildToVerticalBox(rowBox)
                if slot then pcall(function() slot:SetPadding(FMargin(0, 2, 0, 2)) end) end
                local rowPanel = NewObject("/Script/UMG.CanvasPanel", rowBox)
                if IsValid(rowPanel) then
                    rowBox:AddChild(rowPanel)
                    MakeToggleInline(rowPanel, 0, 0, w, opt.label, opt.key, opt.after)
                end
            end
        end
    end
end

local currentTab = 1

local function BuildMenu()
    if menuBuilt and IsValid(bgPanel) then ShowMenu() return end
    local canvas = GetCanvas()
    if not canvas then return end
    bgPanel = NewObject("/Script/UMG.CanvasPanel", canvas)
    if not IsValid(bgPanel) then return end
    local slot = canvas:AddChildToCanvas(bgPanel)
    if slot then
        slot:SetAutoSize(false); slot:SetZOrder(10000)
        local cx, cy = 0, 0
        pcall(function()
            local ui_util = require("client.common.ui_util")
            if ui_util and ui_util.GetViewportSize then
                local vp = ui_util.GetViewportSize()
                if vp and vp.X > 0 then cx = (vp.X - M_W) * 0.5; cy = (vp.Y - M_H) * 0.5 end
            end
        end)
        slot:SetPosition(FVector2D(cx, cy)); slot:SetSize(FVector2D(M_W, M_H))
    end

    -- Purple aura + frame
    Layer(bgPanel, -30, -30, M_W + 60, M_H + 60, C.purple_aura_soft, 0)
    Layer(bgPanel, -15, -15, M_W + 30, M_H + 30, C.purple_aura, 1)
    Layer(bgPanel, 6, 6, M_W, M_H, C.shadow, 1)
    Layer(bgPanel, -6, -6, M_W + 12, M_H + 12, C.gold_trace, 1)
    Layer(bgPanel, -4, -4, M_W + 8, M_H + 8, C.gold_glow_soft, 2)
    Layer(bgPanel, -2, -2, M_W + 4, M_H + 4, C.gold_glow, 2)
    Layer(bgPanel, -1, -1, M_W + 2, M_H + 2, C.gold, 2)

    local mainPanel = Layer(bgPanel, 0, 0, M_W, M_H, C.obsidian, 3)
    pcall(function()
        if mainPanel.Brush then mainPanel.Brush.DrawAs = 1; mainPanel.Brush.Margin = FMargin(0.8, 0.8, 0.8, 0.8) end
    end)

    -- Header
    Layer(bgPanel, 0, 0, M_W, HEADER_H, C.obsidian_header, 5)
    Layer(bgPanel, 0, HEADER_H - 1, M_W, 1, C.gold_dim, 6)

    -- Star decorations
    Text(bgPanel, "✦", 14, 14, 22, C.gold_bright, 7, 0, 0)
    Text(bgPanel, "✧", 34, 22, 14, C.gold, 7, 0, 0)
    Text(bgPanel, "✦", M_W - 36, 14, 22, C.gold_bright, 7, 0, 0)
    Text(bgPanel, "✧", M_W - 56, 22, 14, C.gold, 7, 0, 0)
    Text(bgPanel, "✦", 14, M_H - 36, 22, C.gold_dim, 7, 0, 0)
    Text(bgPanel, "✦", M_W - 36, M_H - 36, 22, C.gold_dim, 7, 0, 0)
    Text(bgPanel, "✦  ✧  ★  ✧  ✦", M_W * 0.5, 20, 10, C.gold_glow, 8, 0.5, 0.5)
    Text(bgPanel, "✦  ✧  ★  ✧  ✦", M_W * 0.5, 64, 10, C.gold_glow, 8, 0.5, 0.5)
    Text(bgPanel, "◆  *  ◆", M_W * 0.5, 12, 10, C.gold_dim, 6, 0.5, 0.5)

    -- Title
    Text(bgPanel, "@OFFICAL_KASHMIRY1", M_W * 0.5, 32, 20, C.text_gold, 8, 0.5, 0.5)
    Text(bgPanel, "◆ POWER  ◆  CONTROL  ◆  VICTORY ◆", M_W * 0.5, 52, 9, C.gold_dim, 8, 0.5, 0.5)

    -- Close button
    local closeX, closeY = M_W - 40, 15
    Text(bgPanel, "✧", closeX - 15, closeY - 15, 10, C.gold, 9, 0.5, 0.5)
    Layer(bgPanel, closeX - 3, closeY - 3, 32, 32, C.close_red_glow, 7)
    Layer(bgPanel, closeX, closeY, 26, 26, C.close_red, 8)
    Text(bgPanel, "X", closeX + 13, closeY + 13, 14, C.white, 400, 0.5, 0.5)
    MakeBtn(bgPanel, closeX, closeY, 26, 26, 900, function() isMenuOpen = false; HideMenu() end)

    -- Tab bar
    local tabY = HEADER_H
    local tabH = 52
    local tabW = M_W / #TOP_TABS
    for i, tab in ipairs(TOP_TABS) do
        local tabX = (i - 1) * tabW
        local isSelected = (currentTab == i)
        if isSelected then
            Layer(bgPanel, tabX, tabY, tabW, tabH, C.obsidian_deep, 10)
            Layer(bgPanel, tabX + 4, tabY + tabH - 4, tabW - 8, 4, C.gold, 11)
            Layer(bgPanel, tabX + 4, tabY + tabH - 6, tabW - 8, 2, C.gold_glow, 11)
        else
            Layer(bgPanel, tabX, tabY, tabW, tabH, C.obsidian_header, 10)
        end
        if i > 1 then Layer(bgPanel, tabX - 1, tabY + 8, 1, tabH - 16, C.gold_trace, 11) end

        Text(bgPanel, tab.name, tabX + tabW * 0.5, tabY + tabH * 0.5 - 2, 14,
            isSelected and C.text_gold or C.text_dim, 13, 0.5, 0.5)

        MakeBtn(bgPanel, tabX, tabY, tabW, tabH, 900, function()
            currentTab = i; menuBuilt = false
            pcall(function() bgPanel:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            BuildMenu()
        end)
    end

    -- Content area
    local contentY = HEADER_H + tabH + 10
    local contentH = M_H - contentY - 24
    local contentW = M_W - 40
    local contentX = 20

    local scrollBox = nil
    pcall(function()
        scrollBox = NewObject("/Script/UMG.ScrollBox", bgPanel)
        if IsValid(scrollBox) then
            local sSlot = bgPanel:AddChildToCanvas(scrollBox)
            if sSlot then
                sSlot:SetAutoSize(false)
                sSlot:SetPosition(FVector2D(contentX, contentY))
                sSlot:SetSize(FVector2D(contentW, contentH))
                sSlot:SetZOrder(20)
            end
            scrollBox:SetScrollBarVisibility(UEnums.ESlateVisibility.Visible)
            scrollBox:SetConsumeMouseWheel(true)
        end
    end)

    if IsValid(scrollBox) then
        local activeData = TOP_TABS[currentTab].data
        local combinedStack = {}
        for _, stack in ipairs(activeData) do
            for _, item in ipairs(stack) do table.insert(combinedStack, item) end
        end
        BuildColumn(scrollBox, combinedStack)
    end

    -- Footer
    Layer(bgPanel, 0, M_H - 20, M_W, 20, C.obsidian_deep, 22)
    Layer(bgPanel, 0, M_H - 20, M_W, 1, C.gold_trace, 23)
    Text(bgPanel, "◆ POWER  ◆  CONTROL  ◆  VICTORY  ◆", M_W * 0.5, M_H - 10, 10, C.gold_dim, 24, 0.5, 0.5)

    menuBuilt = true; isMenuOpen = true
end

local function CreateFloat()
    if floatItem and IsValid(floatItem.btn) then return end
    floatItem = nil
    local canvas = GetCanvas()
    if not canvas then return end
    floatItem = {}

    local fX, fY, fW, fH = 750, 15, 140, 50
    Layer(canvas, fX - 12, fY - 12, fW + 24, fH + 24, C.purple_aura_soft, 11895)
    Layer(canvas, fX - 8, fY - 8, fW + 16, fH + 16, C.purple_aura, 11896)
    Layer(canvas, fX - 5, fY - 5, fW + 10, fH + 10, C.gold_trace, 11897)
    Layer(canvas, fX - 3, fY - 3, fW + 6, fH + 6, C.gold_glow_soft, 11898)
    Layer(canvas, fX - 2, fY - 2, fW + 4, fH + 4, C.gold_glow, 11899)
    Layer(canvas, fX - 1, fY - 1, fW + 2, fH + 2, C.gold, 11900)
    Layer(canvas, fX, fY, fW, fH, C.obsidian, 11901)
    Layer(canvas, fX, fY, fW, 3, C.gold, 11902)
    Text(canvas, "◆", fX + 10, fY + 12, 10, C.gold, 11903, 0, 0)
    Text(canvas, "◆", fX + fW - 20, fY + 12, 10, C.gold, 11903, 0, 0)
    Text(canvas, "@OFFICAL_KASHMIRY1", fX + fW * 0.5, fY + fH * 0.5 - 7, 13, C.text_gold, 12001, 0.5, 0.5)
    Text(canvas, "OFFICIAL", fX + fW * 0.5, fY + fH * 0.5 + 9, 9, C.gold_dim, 12001, 0.5, 0.5)
    Layer(canvas, fX + fW - 14, fY + 8, 6, 6, C.online_dot, 11905)

    floatItem.btn = MakeBtn(canvas, fX, fY, fW, fH, 12002, function()
        isMenuOpen = not isMenuOpen
        if isMenuOpen then
            if menuBuilt and IsValid(bgPanel) then ShowMenu() else BuildMenu() end
        else
            HideMenu()
        end
    end)
end

local _initDone = false
local _retry = 0
local function TryInit()
    if _initDone then return end
    _retry = _retry + 1
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not IsValid(pc) then return end
    local canvas = GetCanvas()
    if not canvas then return end
    CreateFloat()
    if floatItem and IsValid(floatItem.btn) then
        _initDone = true
        log("Init done retry " .. _retry)
    end
end

pcall(function()
    local okT, ticker = pcall(require, "common.time_ticker")
    if okT and ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(1.0, function()
            if not _initDone then pcall(TryInit) end
        end, 0, 1.0)
        if ticker.AddTimerOnce then
            ticker.AddTimerOnce(0.5, function() pcall(TryInit) end)
        end
    end
end)

_G.SHOpenMenu = function()
    pcall(function()
        if menuBuilt and IsValid(bgPanel) then ShowMenu() else BuildMenu() end
    end)
end
_G.SHTryInit = TryInit
log("Trimmed menu ready")

end)
-- ============================================================
-- END TRIMMED MENU
-- ============================================================
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
  },
  {
    SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  }
}, "BRPlayerCharacterBase")