
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

if packageName ~= "com.pubg.imobile" then
    return
end

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
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
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
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

-- ================== HANDLE MOVEMENT (NO WALL CLIMB) ==================
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

BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.UInt32,
    UEnums.EPropertyClass.UInt32
  }
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
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
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
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
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

-- ==============================================================================
-- ============================ START FULL LOGIC MOD ==========================
-- ==============================================================================

local function Notify(msg) local s = "[GTLMOD VIP New] " .. tostring(msg)
pcall(function() if _G.GTLMODNotify then _G.GTLMODNotify(s) end end)
pcall(function() local sh = import("ScriptHelperClient") if sh and
sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1,
G=1, B=0, A=1}, {X=1.2, Y=1.2}) end end) print(s) end

local _slua = rawget(_G, "slua")

local function Valid(obj) if not obj then return false end if _slua and
_slua.isValid then local ok, v = pcall(_slua.isValid, obj) if not ok or not v
then return false end end return true end

-- ========================================== 
-- STATIC VARIABLES & GLOBAL CACHE OPTIMIZED (LAG-FREE)
-- ========================================== 
local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_BLUE = {R=0, G=0, B=255, A=255}
local C_PINK = {R=255, G=105, B=180, A=255}
local C_ORANGE = {R=255, G=165, B=0, A=255}
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

-- ========================================== 
-- GTLMOD CORE + FULL FEATURES VIP CONFIGURATION 
-- ========================================== 
_G.GTLMODConfig = _G.GTLMODConfig or { 
    CustomMagicBullet = false,
    AutoHead = false, 
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
    
    -- New Configuration for Aimbot V2 (Aim Touch)
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

    -- Skin Mod
    ModSkin = false,
}

-- CONTAINS FULLY OPTIMIZED SYSTEM STATE WITH FREE RAM
_G.GTLMODState = _G.GTLMODState or { 
    LoopToken = 0, 
    AimbotLoopToken = 0,   -- token untuk loop aimbot force
    NativeESPReady = false,
    GraphicsUnlocked = false, 
    MenuStep = 0, 
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    LastAimbotCheckTime = 0, 
    CustomTextData = nil,     
    LastAimbotConfigString = "",
    MagicUpdateVersion = 1,
    LastMagicConfigHash = "",
    PrevGraphicsState = {},
    SkinWasApplied = false,
}

local limitTime = os.time({ year = 2028, month = 9, day = 1, hour = 23, min = 59, sec = 0 })
local currentTime = os.time(os.date("!*t"))
local isExpired = false

pcall(function()
    local fileName = ".sys_time_cache"
    -- HANYA path untuk Global dan Korea (Android)
    local paths = {
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        -- fallback (tanpa iOS)
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
        if serverTime and serverTime > 1700000000 then 
            currentTime = serverTime
        end
    end

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

-- ==============================================================================
-- ================== INITIALIZE AND LOAD THE FIRST BYPASS ==========================
-- ==============================================================================

-- ============================================================================
-- ULTIMATE MERGED BYPASS v3.0 - COMPLETE SECURITY DISABLEMENT
-- ============================================================================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

local function InitializeSLUABypass()
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
    end)
end

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
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue; FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then TssSdk.GetFileMD5 = function() return "BYPASS" end; TssSdk.VerifyFileSignature = retTrue end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then STExtra.CheckMD5 = retTrue; STExtra.GetMD5 = function() return "BYPASS" end; STExtra.VerifyFile = retTrue end
    end)
end
local function InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then sub.StartCheck = nop; sub.ReportAbnormalFile = nop; sub.StopCheck = nop end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)
end
local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then SMTD.MTDePicture = function() return "" end; SMTD.ReMTDePicture = function() return "" end; SMTD.HasCaptured = retTrue; SMTD.TakeScreenshot = nop end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop; TLog.Send = nop; TLog.Flush = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop; CrashSight.Log = nop; CrashSight.SendCrash = nop; CrashSight.ReportUserException = nop end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GRUtils then GRUtils.BugglyPostExceptionFull = retFalse; GRUtils.CheckCanBugglyPostException = retFalse; GRUtils.ReplayReportData = nop; GRUtils.ReportGameException = nop; GRUtils.PostException = nop end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then CTR.SendReport = nop; CTR.SendException = nop; CTR.UploadLog = nop end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "FacebookAnalytics", "GameAnalytics"}) do
            local s = _G[sdk]; if s then s.logEvent = nop; s.trackEvent = nop; s.setEnabled = retFalse; s.sendEvent = nop; s.report = nop end
        end
    end)
end

local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "AvatarExceptionSubsystem", "ShootVerifySubSystemClient", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "FileCheckSubsystem", "BehaviorScoreSubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then pcall(function() sub[k] = nop end) end
                    end
                    if sub.ReportPingDelayTimer then sub:RemoveGameTimer(sub.ReportPingDelayTimer); sub.ReportPingDelayTimer = nil end; sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then AvaEx.CheckAvatarException = nop; AvaEx.CheckAvatarExceptionOnce = nop; AvaEx.ReportAvatarException = nop; AvaEx.CheckSlotMeshVisible = retFalse; AvaEx.CheckPawnVisible = retFalse; AvaEx.CheckCanBugglyPostException = retFalse end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local origData = TssSdk.OnRecvData
            TssSdk.OnRecvData = function(data) if type(data) == "string" and (data:find("report", 1, true) or data:find("exception", 1, true) or data:find("cheat", 1, true) or data:find("violation", 1, true) or data:find("hack", 1, true) or data:find("verify", 1, true)) then return end; if origData then origData(data) end end
            TssSdk.SendReportInfo = nop; TssSdk.ScanMemory = retTrue; TssSdk.IsEmulator = retFalse; TssSdk.GetTssSdkReportInfo = retEmptyString; TssSdk.CheckEnvironment = retTrue; TssSdk.VerifyProcess = retTrue
        end
    end)
end

local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({"GameReportSubsystem", "ReplaySubsystem"}) do
                local sub = SubMgr:Get(name)
                if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then pcall(function() sub[k] = nop end) end end end
            end
        end
        local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logRep then logRep.ReportReplay = nop; logRep.SendReportReq = nop; logRep.UploadReplay = nop end
    end)
end

local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "ReportEquipmentFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow", "ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}) do if _G[f] then _G[f] = retFalse end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow", "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow", "IsEnableReportAttackFlow", "IsEnableReportHitFlow", "IsEnableReportCircleFlow"}) do if _G[f] then _G[f] = retFalse end end
    end)
end

local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector", "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then for k, v in pairs(_G[c]) do if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then _G[c][k] = nop end end end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then SecSub.ReportData = nop; SecSub.CheckCheat = retFalse; SecSub.ValidatePlayer = retTrue; SecSub.CollectData = nop; SecSub.SendToServer = nop end
    end)
end

local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData", "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then sub.ReportData = nop; sub.SendReport = nop; sub.CollectTelemetry = nop end
    end)
end

local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop; _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then sub.ReportData = nop; sub.SendToServer = nop; sub.CollectTelemetry = nop; sub.StopCollection = nop end
    end)
end

local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then sub.ReportException = nop; sub.CheckModifier = retTrue; sub.ValidateModifier = retTrue; sub.ReportModifierError = nop end
    end)
end

local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then sub.ReportLocation = nop; sub.SendLocationData = nop; sub.VerifyLocation = retTrue end
    end)
end

local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then sub.OnShootVerifyFailed = nop; sub.SendVerifyData = nop; sub.ReportBulletHit = nop; sub.UploadHitInfo = nop; sub.VerifyShot = retTrue end
        if _G.BulletHitInfoUploadData then _G.BulletHitInfoUploadData.Report = nop; _G.BulletHitInfoUploadData.Send = nop; _G.BulletHitInfoUploadData.Upload = nop end
    end)
end

local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1, ["ReportSecVehicleMoveFlow"]=1,
                ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1, ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_net_saturate"]=1, ["report_speed_hack"]=1, ["report_wall_hack"]=1, ["report_aim_bot"]=1, ["report_esp_usage"]=1,
                ["report_modded_files"]=1, ["detect_cheat"]=1, ["ban_player"]=1, ["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CheckReportSecAttackFlow"]=1, ["CheckReportSecAttackFlowWithAttackFlow"]=1, ["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1, ["PlayerSecurityInfo"]=1, ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1, ["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1, ["IsEnableReportMrpcsInPartCircleFlow"]=1, ["bReportedModifierException"]=1,
                ["ReportModifierException"]=1, ["RPC_Server_ReportSimulateCharacterLocation"]=1, ["ReportSimulateCharacterLocation"]=1, ["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1, ["ShootVerifyFailed"]=1, ["report_unrealnet_exception"]=1, ["tss_sdk_report"]=1, ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1, ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1, ["SwiftHawkData"]=1,
                ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(packetName, ...) if blocked[packetName] then return nil end; return orig(packetName, ...) end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams", "RPC_Server_ReportSimulateCharacterLocation", "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...) for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end; return origRPC(rpcName, ...) end
        end
    end)
end

local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "Tick", "OnTick", "MHActiveLogic", "TriggerAvatarCheck", "StartAvatarCheck", "ReportItemID", "ReceiveAnyDamage", "OnWeaponHitRecord", "ShowSecurityAlert", "ServerReportAvatar", "ClientReportNetAvatar", "SendHisarData", "ValidateSecurityData", "StaticShowSecurityAlertInDev", "RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation", "DisableHiggsBoson", "CheckMHActive", "ReportViolation", "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty; Higgs.GetCurWeaponSkinID = retZero; Higgs.IsMHActive = retFalse; Higgs.bMHActive = false; Higgs.bCallPreReplication = false
            if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false; if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false; pc.HiggsBosonComponent:ControlMHActive(0) end
        end
    end)
end

local function InitializeAntiCheatHooks()
    pcall(function()
        local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HBC and HBC.StaticShowSecurityAlertInDev then HBC.StaticShowSecurityAlertInDev = nop end
    end)
    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = nop; _G.AvatarCheckCallback.OnReportItemID = nop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
            if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then PlayerController.HiggsBosonComponent:ControlMHActive(0); PlayerController.HiggsBosonComponent.bMHActive = false end
        end
    end
end

local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]; if not sub then local s, r = pcall(require, path); if s and r then sub = r end end
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "OnDSConnectionSaturated", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow", "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams"}
        for _, f in ipairs(reports) do GC[f] = nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse; GC.CheckReportSecAttackFlow = retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1, ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, ["kicked"]=1, ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1, ["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = nop; GC.OnPlayerActorChannelError = nop; GC.OnPlayerRPCValidateFailed = nop; GC.OnPlayerSpectateException = nop; GC.OnShutdownAfterError = nop; GC.IsBypassed = true
    end)
end

local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient", "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem", "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem", "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem", "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem", "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem", "MD5CheckSubsystem", "PakVerifySubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then pcall(function() sub[k] = nop end) end end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY", "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT", "ENABLE_PERFORMANCE_REPORT"}) do if _G[flag] then _G[flag] = false end end
        local origReq = require
        local blocked = {"HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem"}
        _G.require = function(m) for _, b in ipairs(blocked) do if m:find(b) then return {} end end; return origReq(m) end
    end)
end

_G.StartBypass_VIP_v3 = function()
    pcall(function()
        print("[ULTIMATE BYPASS] Starting initialization...")
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
        InitializeFinalProtection()
        print("[ULTIMATE BYPASS] Complete - All Security Systems Disabled")
    end)
end

-- ========================================== 
-- MAP MARK CLEANUP MANAGEMENT FUNCTION (ANTI-LAG/FAKE DISPLAY WHEN ENEMY DIES)
-- ========================================== 
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

-- ========================================== 
-- CREATE A UNIQUE AND PERMANENT ID FOR EACH ENEMY (FIXED LAG ISSUES WHEN SLUA CREATES NEW WRAPPERS)
-- ==========================================
local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

-- ========================================== 
-- AI (BOT) / REAL PLAYER - OPTIMIZED TEST
-- ==========================================
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

-- ========================================== 
-- INITIALIZES AUTO HEAD HOOKS FOR DAMAGE
-- ==========================================
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
-- COLOR CONFIGURATION FOR ESP HEALTH, ESP NAME, AND WALLHACK
-- ==========================================
if _G.ColorConfig == nil then
    _G.ColorConfig = {
        VisibleColor = 4,   -- default Green
        InvisibleColor = 3, -- default Yellow
        Brightness = 25,
        Glow = 3.0,
    }
end

local COLOR_MAP = {
    [1] = {R=255, G=255, B=0},
    [2] = {R=255, G=255, B=255},
    [3] = {R=255, G=255, B=0},
    [4] = {R=0,   G=255, B=0},
    [5] = {R=0,   G=255, B=255},
    [6] = {R=0,   G=0,   B=255},
    [7] = {R=255, G=0,   B=255}
}

local function GetAppliedColor(colorIdx, brightness)
    local base = COLOR_MAP[colorIdx] or COLOR_MAP[4]
    local b = brightness or _G.ColorConfig.Brightness or 25
    return {
        R = math.min(255, (base.R or 0) * b / 25),
        G = math.min(255, (base.G or 0) * b / 25),
        B = math.min(255, (base.B or 0) * b / 25),
        A = 255
    }
end

-- ========================================== 
-- AUTOMATIC VIP MENU STORAGE AND LOADING SYSTEM
-- ========================================== 
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
    return paths
end

local ConfigFileName = "GTLMOD_settings.txt"
_G.LastConfigSaveStr = ""

-- DOWNLOAD CONFIG (plus ColorConfig and Skin)
_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\nGTLConfig = {\n"
        for k, v in pairs(_G.GTLMODConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "},\nCustomTextData = {\n"
        if _G.GTLMODState and _G.GTLMODState.CustomTextData then
            for k, v in pairs(_G.GTLMODState.CustomTextData) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            end
        end
        data = data .. "},\nColorConfig = {\n"
        for k, v in pairs(_G.ColorConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
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

-- LOAD (READ) CONFIG (ditambah ColorConfig) FUNCTION
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
                    if savedData.ColorConfig then
                        for k, v in pairs(savedData.ColorConfig) do
                            _G.ColorConfig[k] = v
                        end
                    end
                    _G.ColorConfig.InvisibleColor = 3 -- always yellow for hidden/crouched
                    _G.ColorConfig.VisibleColor = 4 -- always green for visible enemy
                end
            end
        end
        _G.SaveModSettings() 
    end)
end

-- A VERIFICATION LOOP FOR LIGHTWEIGHT UNDERGROUND RUNNING.
local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker") 
        if okTicker and ticker and ticker.AddTimerOnce then 
            ticker.AddTimerOnce(3.0, AutoSaveLoop)
        end
    end)
end

-- FIRST LAUNCH
if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

-- EXCESSIVE TO AVOID YOUR OLD LOOP ERRORS
_G.ReadLiveConfig = function()
    if _G.SaveModSettings then _G.SaveModSettings() end
end

-- ========================================== 
-- SKIN MOD SYSTEM (FULL)
-- ==========================================
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
    Suit = {403003,1407906,1407921,1406388,1406387,1406386,1407142,1407550,1406638,1406872,1406971,1407103,1407512,1407391,1407285,1407330,1407329,1407286,1407285,1407277,1407276,1407275,1407225,1407224,1407259,1407161,1407160,1407107,1407106,1407079,1407048,1406977,1406976,1406898,1400569,1404000,1404049,1400119,1400117,1406060,1406891,1400687,1405160,1405145,1405436,1405435,1405434,1405064,1405207,1406398,1407812,1405132,1407856,1405121,1406889,1407278,1407279,1407381,1407380,1407916,1406469,1405870,1407140,1407141,1406385,1406140,1400782,1407392,1407318,1407317,1407404,1407402,1407401,1407387,1404434,1404437,1404440,1404448,1400324,1400708,1404043,1404048,1405953,1400101,1404153,1407440,1407441,1407522},
    Bag = {
        {501001, 501002, 501003}, {1501001174, 1501002174, 1501003174}, {1501001220, 1501002220, 1501003220},
        {1501001051, 1501002051, 1501003051}, {1501001443, 1501002443, 1501003443}, {1501001265, 1501002265, 1501003265},
        {1501001321, 1501002321, 1501003321}, {1501001277, 1501002277, 1501003277}, {1501001550, 1501002550, 1501003550},
        {1501001592, 1501002592, 1501003592}, {1501001608, 1501002608, 1501003608}, {1501001024, 1501002024, 1501003024},
        {1501001019, 1501002019, 1501003019}, {1501001179, 1501002179, 1501003179}, {1501001194, 1501002194, 1501003194},
        {1501001346, 1501002346, 1501003346}, {1501001057, 1501002057, 1501003057}
    },
    Helmet = {
        {502001, 502002, 502003}, {1502001014, 1502002014, 1502003014}, {1502001349, 1502002349, 1502003349},
        {1502001012, 1502002012, 1502003012}, {1502001009, 1502002009, 1502003009}, {1502001397, 1502002397, 1502003397},
        {1502001390, 1502002390, 1502003390}, {1502001381, 1502002381, 1502003381}, {1502001358, 1502002358, 1502003358},
        {1502001350, 1502002350, 1502003350}, {1502001342, 1502002342, 1502003342},
 {1502001058, 1502002058, 1502003058}
        
    },
    Pet = {50000,50001,50002,50003,50004,50005,50006,50021,50022,50038,50039,50040}
}

_G.skinIdMappings = {
    [101004]={101004, 1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218,1101004046},
    [101001]={101001,1101001276,1101001265,1101001213,1101001172,1101001127,1101001230,1101001241},                    
    [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},                                             
    [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008146,1101008061,1101008116},                    
    [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084},
    [101012]={101012,1101012033},
    [101007]={101007,1101007062,1101007071},
    [102002]={102002,1102002136,1102002043,1102002061,1102002424,1102002438},      
    [101101]={101101, 1101101007},
    [101102]={101102, 1101102041},
    [102001]={102001, 1102001120},
    [102003]={102003, 1102003100},
    [101005]={101005, 1101005098},
    [103001]={103001, 1103001202,1103001191},
    [103002]={103002, 1103002106},
    [103003]={103003, 1103003042,1103003062,1103003099},
    [103012]={103012, 1103012039,1103012010},
    [104003]={104003, 1104003037},
    [104004]={104004, 1104004035, 1104004041}
}

_G.VehicleSkins = { 
    [1961001] = { 1961007, 1961149, 1961069, 1961013, 1961014, 1961015, 1961016, 1961017, 1961018, 1961020, 1961021, 1961024, 1961025, 1961029, 1961030, 1961031, 1961032, 1961033, 1961034, 1961035, 1961036, 1961037, 1961038, 1961039, 1961040, 1961041, 1961042, 1961043, 1961044, 1961045, 1961046, 1961047, 1961048, 1961049, 1961050, 1961051, 1961052, 1961053, 1961054, 1961055, 1961056, 1961057, 1961058, 1961059, 1961060, 1961061, 1961062, 1961063, 1961064, 1961065, 1961066, 1961067, 1961068,1961136, 1961137, 1961138, 1961139, 1961140, 1961141, 1961142, 1961143, 1961144, 1961145, 1961147, 1961148, 1961010, 1961150, 1961151, 1961152, 1961153 },
    [1903001] = { 1903005, 1903006, 1903007, 1903008, 1903011, 1903012, 1903013, 1903014, 1903015, 1903016, 1903017, 1903018, 1903019, 1903020, 1903021, 1903022, 1903023, 1903024, 1903029, 1903030, 1903031, 1903032, 1903033, 1903034, 1903035, 1903036, 1903037, 1903039, 1903040, 1903041, 1903042, 1903043, 1903044, 1903045, 1903046, 1903051, 1903052, 1903053, 1903054, 1903055, 1903056, 1903057, 1903058, 1903059, 1903060, 1903061, 1903062, 1903063, 1903066, 1903067, 1903068, 1903069, 1903070, 1903071, 1903072, 1903073, 1903074, 1903075, 1903076, 1903079, 1903080, 1903081, 1903082, 1903084, 1903085, 1903086, 1903087, 1903088, 1903089, 1903090, 1903189, 1903190, 1903191, 1903192, 1903193, 1903194, 1903195, 1903196, 1903197, 1903198, 1903199, 1903200, 1903201, 1903202, 1903203, 1903204, 1903205, 1903206, 1903207, 1903208, 1903209, 1903210, 1903211, 1903212, 1903213, 1903214, 1903215, 1903216, 1903217, 1903218, 1903219, 1903220, 1903221, 1903222, 1903223, 1903225, 1903226, 1903227, 1903228 }, 
    [1915001] = { 1915002, 1915003, 1915007, 1915005, 1915006, 1915008, 1915009, 1915010, 1915011, 1915012, 1915013, 1915014, 1915015, 1915016, 1915017, 1915018, 1915019, 1915020, 1915021, 1915022, 1915023, 1915024, 1915025, 1915026, 1915027, 1915099 },          
    [1908001] = { 1908002, 1908003, 1908094, 1908006, 1908007, 1908008, 1908009, 1908010, 1908011, 1908012, 1908013, 1908015, 1908016, 1908017, 1908018, 1908019, 1908021, 1908023, 1908030, 1908031, 1908032, 1908033, 1908034, 1908035, 1908036, 1908037, 1908039, 1908040, 1908041, 1908043, 1908047, 1908049, 1908050, 1908051, 1908052, 1908053, 1908054, 1908055, 1908056, 1908057, 1908059, 1908060, 1908061, 1908062, 1908063, 1908064, 1908066, 1908067, 1908068, 1908069, 1908070, 1908075, 1908076, 1908077, 1908078, 1908080, 1908081, 1908082, 1908083, 1908084, 1908085, 1908086, 1908087, 1908088, 1908089, 1908091, 1908095, 1908096, 1908097, 1908098, 1908099, 1908100, 1908101, 1908102, 1908104, 1908105, 1908106, 1908107, 1908108, 1908109, 1908110, 1908111, 1908112, 1908188, 1908189 },   
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
        
        if _G.LastVehicleEntity == Vehicle and _G.CurrentEquipVehicleID ~= nil then
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

        if applySkinId and applySkinId > 0 then
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
            if cData.SkinHoney and _G.skinIdMappings[101012] and _G.skinIdMappings[101012][cData.SkinHoney] then _G.WeaponSkinMap[101012] = _G.skinIdMappings[101012][cData.SkinHoney] end
            if cData.SkinQBZ and _G.skinIdMappings[101007] and _G.skinIdMappings[101007][cData.SkinQBZ] then _G.WeaponSkinMap[101007] = _G.skinIdMappings[101007][cData.SkinQBZ] end
            if cData.SkinASM and _G.skinIdMappings[101101] and _G.skinIdMappings[101101][cData.SkinASM] then _G.WeaponSkinMap[101101] = _G.skinIdMappings[101101][cData.SkinASM] end
            if cData.SkinACE32 and _G.skinIdMappings[101102] and _G.skinIdMappings[101102][cData.SkinACE32] then _G.WeaponSkinMap[101102] = _G.skinIdMappings[101102][cData.SkinACE32] end
            if cData.SkinUMP and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][cData.SkinUMP] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][cData.SkinUMP] end
            if cData.SkinUZI and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][cData.SkinUZI] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinVector and _G.skinIdMappings[102003] and _G.skinIdMappings[102003][cData.SkinVector] then _G.WeaponSkinMap[102003] = _G.skinIdMappings[102003][cData.SkinVector] end
            if cData.SkinGroza and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][cData.SkinGroza] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinKar98K and _G.skinIdMappings[103001] and _G.skinIdMappings[103001][cData.SkinKar98K] then _G.WeaponSkinMap[103001] = _G.skinIdMappings[103001][cData.SkinKar98K] end
            if cData.SkinM24 and _G.skinIdMappings[103002] and _G.skinIdMappings[103002][cData.SkinM24] then _G.WeaponSkinMap[103002] = _G.skinIdMappings[103002][cData.SkinM24] end
            if cData.SkinAWM and _G.skinIdMappings[103003] and _G.skinIdMappings[103003][cData.SkinAWM] then _G.WeaponSkinMap[103003] = _G.skinIdMappings[103003][cData.SkinAWM] end
            if cData.SkinAMR and _G.skinIdMappings[103012] and _G.skinIdMappings[103012][cData.SkinAMR] then _G.WeaponSkinMap[103012] = _G.skinIdMappings[103012][cData.SkinAMR] end
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

_G.InitializeSkinModSystem = function()
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
        OuterSpeed = 10, InnerSpeed = 10, OuterRecoil = 0, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120,
        AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250,
        AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30,
        AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchScopePred = 0, AimTouchScopeRecoil = 0,
        AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400, AimTouchSniperPred = 0,
        -- Skin
        SkinSuit = 0, SkinBag = 0, SkinHelmet = 0,
        SkinM416 = 0, SkinAKM = 0, SkinSCAR = 0, SkinM762 = 0, SkinAUG = 0, SkinHoney =0, SkinQBZ = 0, SkinASM = 2, SkinACE32 = 0, SkinUMP = 6,
        SkinUZI = 0, SkinVector = 0, SkinGroza = 0, SkinKar98K = 0, SkinAWM = 2, SkinAMR = 0, SkinS12K = 0, SkinDBS = 0,
        SkinDacia = 0, SkinUAZ = 0, SkinCoupe = 0, SkinBuggy = 0, SkinMirado = 0,
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
        
        -- ==================== ESP VISUAL ====================
        local StackESPVisual = {
            { Key = "ModMenu_ESP1", UI = AliasMap.Switcher, Text = "ESP (AUTO SETUP) TELEGRAM KING", GetFunc = function() return _G.GTLMODConfig.EspVip end, SetFunc = function(c,v) _G.GTLMODConfig.EspVip = v return true end },
            { Key = "ModMenu_ESP7", UI = AliasMap.Switcher, Text = "ESP WARNING & COUNT", GetFunc = function() return _G.GTLMODConfig.Esp7 end, SetFunc = function(c,v) _G.GTLMODConfig.Esp7 = v return true end },
            { Key = "ModMenu_ESP2", UI = AliasMap.Switcher, Text = "ESP RANGE", GetFunc = function() return _G.GTLMODConfig.EspDistance end, SetFunc = function(c,v) _G.GTLMODConfig.EspDistance = v return true end },
            { Key = "ModMenu_ESP4", UI = AliasMap.Switcher, Text = "ESP MARK - 360 Radar", GetFunc = function() return _G.GTLMODConfig.EspRadar end, SetFunc = function(c,v) _G.GTLMODConfig.EspRadar = v return true end },
            { Key = "ModMenu_ESP5", UI = AliasMap.Switcher, Text = "ESP BOX FRAME", GetFunc = function() return _G.GTLMODConfig.Esp5 end, SetFunc = function(c,v) _G.GTLMODConfig.Esp5 = v return true end },
            { Key = "ModMenu_ESPAntenna", UI = AliasMap.Switcher, Text = "ESP LINE ANTENA", GetFunc = function() return _G.GTLMODConfig.EspAntenna end, SetFunc = function(c,v) _G.GTLMODConfig.EspAntenna = v return true end },
            { Key = "ModMenu_ESPName", UI = AliasMap.Switcher, Text = "ESP NAME TEST(VISIBLE)", GetFunc = function() return _G.GTLMODConfig.EspName end, SetFunc = function(c,v) _G.GTLMODConfig.EspName = v return true end },
            { Key = "ModMenu_ESPOutline_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ ESP OUTLINE", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.EspOutline end, SetFunc = function(c,v) _G.GTLMODConfig.EspOutline = v return true end },
            { Key = "ModMenu_ESPOutline_Thickness", UI = AliasMap.Slider, Text = "   Outline Thickness (1% is perfect)", ExpandHandle = "ModMenu_ESPOutline_Ex", MinValue = 1, MaxValue = 20, min = 1, max = 20, GetFunc = function() return _G.GTLMODConfig.OutlineThickness end, SetFunc = function(c,v) _G.GTLMODConfig.OutlineThickness = v return true end }
        }

        -- ==================== AIMBOT ORIGINAL (Legacy, tanpa GodMode & Magic Bullet) ====================
        local StackAimbotOriginal = {
        }

        -- ==================== AIMBOT FORCE (Royal Aimbot) ====================
        local StackAimbotForce = {
            { Key = "ModMenu_AT_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ UR/SCRIM PLAYER - TOUCH AIM", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.AimTouchEnable end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchEnable = v return true end },
            
            -- HIPFIRE
            { Key = "ModMenu_AT_Hip_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Hipfire Aimbot", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.AimTouchHipfire end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchHipfire = v return true end },
            { Key = "ModMenu_AT_Hip_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked Enemies", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchHipIgKnock end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchHipIgKnock = v return true end },
            { Key = "ModMenu_AT_Hip_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchHipIgBot end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchHipIgBot = v return true end },
            { Key = "ModMenu_AT_Hip_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchHipVisCheck end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchHipVisCheck = v return true end },
            { Key = "ModMenu_AT_Hip_Prio", UI = AliasMap.Slider, Text = "      Aim Terget (1: Near Crosshair 2: Near Enemy 3:HP 4:HP%)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchHipPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchHipPrio = val return true end },
            { Key = "ModMenu_AT_Hip_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1:Head 2:Chest 3:Stomach 4:Pelvis)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchHipBone or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchHipBone = val return true end },
            { Key = "ModMenu_AT_Hip_Cond", UI = AliasMap.Slider, Text = "      Condition (1:Aim when firing 2:Always aim)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchHipCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.GTLMODState.CustomTextData.AimTouchHipCond = val return true end },
            { Key = "ModMenu_AT_Hip_Spd", UI = AliasMap.Slider, Text = "      Aim / Speed Smooth (1-62% perfect)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchHipSpeed or 50 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchHipSpeed = v return true end },
            { Key = "ModMenu_AT_Hip_FOV", UI = AliasMap.Slider, Text = "      FOV Range (1-30% perfect)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchHipFOV or 30 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchHipFOV = v return true end },
            { Key = "ModMenu_AT_Hip_Dist", UI = AliasMap.Slider, Text = "      Distance (1-40% safe)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.GTLMODState.CustomTextData.AimTouchHipDist or 250) / 5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchHipDist = v * 5 return true end },
            
            -- SCOPE ALL
            { Key = "ModMenu_AT_ScopeAll_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Scoped Aimbot (All Weapons - Set up, toggle scope off/on)", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.AimTouchScopeAll end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchScopeAll = v return true end },
            { Key = "ModMenu_AT_ScopeAll_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked Enemies", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchScopeIgKnock end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchScopeIgKnock = v return true end },
            { Key = "ModMenu_AT_ScopeAll_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchScopeIgBot end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchScopeIgBot = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchScopeVisCheck end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchScopeVisCheck = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Prio", UI = AliasMap.Slider, Text = "      Scope Terget (1: Near Crosshair 2: Near Enemy 3:HP 4:HP%)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopePrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchScopePrio = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1:Head 2:Chest 3:Stomach 4:Pelvis)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopeBone or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchScopeBone = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Cond", UI = AliasMap.Slider, Text = "      Condition (1:Aim when firing 2:Always aim)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopeCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.GTLMODState.CustomTextData.AimTouchScopeCond = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Spd", UI = AliasMap.Slider, Text = "      Scope Aim/Smooth Speed (1-57% safe)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopeSpeed or 40 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchScopeSpeed = v return true end },
            { Key = "ModMenu_AT_ScopeAll_FOV", UI = AliasMap.Slider, Text = "      FOV Range (FOV - 1-20% perfect)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopeFOV or 20 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchScopeFOV = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Dist", UI = AliasMap.Slider, Text = "      Distance (1-45% safe)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.GTLMODState.CustomTextData.AimTouchScopeDist or 300) / 5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchScopeDist = v * 5 return true end },
            { Key = "ModMenu_AT_ScopeAll_Pred", UI = AliasMap.Slider, Text = "      Movement Prediction", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopePred or 0 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchScopePred = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Recoil", UI = AliasMap.Slider, Text = "      Auto Recoil Compensation (set 3-4% for smooth)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 50, min = 0, max = 50, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchScopeRecoil or 0 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchScopeRecoil = v return true end },

            -- AIMBOT SHOTGUN
            { Key = "ModMenu_AT_SG_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Shotgun Aimbot", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.AimTouchSG end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSG = v return true end },
            { Key = "ModMenu_AT_SG_AutoFire", UI = AliasMap.Switcher, Text = "      Auto Fire (may cause damage bug if not firing manually)", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSGAutoFire end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSGAutoFire = v return true end },
            { Key = "ModMenu_AT_SG_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked Enemies", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSGIgKnock end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSGIgKnock = v return true end },
            { Key = "ModMenu_AT_SG_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSGIgBot end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSGIgBot = v return true end },
            { Key = "ModMenu_AT_SG_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSGVisCheck end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSGVisCheck = v return true end },
            { Key = "ModMenu_AT_SG_Prio", UI = AliasMap.Slider, Text = "      Priority (1:Center 2:Distance 3:HP 4:HP%)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchSGPrio = val return true end },
            { Key = "ModMenu_AT_SG_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1:Head 2:Chest 3:Stomach 4:Pelvis)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGBone or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchSGBone = val return true end },
            { Key = "ModMenu_AT_SG_Cond", UI = AliasMap.Slider, Text = "      Condition (1:Aim when firing 2:Always aim)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.GTLMODState.CustomTextData.AimTouchSGCond = val return true end },
            { Key = "ModMenu_AT_SG_Spd", UI = AliasMap.Slider, Text = "      Smoothing / Speed (1-100)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGSpeed or 80 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSGSpeed = v return true end },
            { Key = "ModMenu_AT_SG_FOV", UI = AliasMap.Slider, Text = "      FOV Range (FOV - 1-100)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGFOV or 40 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSGFOV = v return true end },
            { Key = "ModMenu_AT_SG_Dist", UI = AliasMap.Slider, Text = "      Distance (Jarak - 1-100m)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSGDist or 30 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSGDist = v return true end },
            
            -- SCOPE SNIPER
            { Key = "ModMenu_AT_Sniper_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Scoped Aimbot (Sniper Rifles Only)", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.AimTouchScopeSniper end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchScopeSniper = v return true end },
            { Key = "ModMenu_AT_Sniper_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked Enemies", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSniperIgKnock end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSniperIgKnock = v return true end },
            { Key = "ModMenu_AT_Sniper_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSniperIgBot end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSniperIgBot = v return true end },
            { Key = "ModMenu_AT_Sniper_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.GTLMODConfig.AimTouchSniperVisCheck end, SetFunc = function(c,v) _G.GTLMODConfig.AimTouchSniperVisCheck = v return true end },
            { Key = "ModMenu_AT_Sniper_Prio", UI = AliasMap.Slider, Text = "      Priority (1:Center 2:Distance 3:HP 4:HP%)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchSniperPrio = val return true end },
            { Key = "ModMenu_AT_Sniper_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1:Head 2:Chest 3:Stomach 4:Pelvis)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperBone or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.GTLMODState.CustomTextData.AimTouchSniperBone = val return true end },
            { Key = "ModMenu_AT_Sniper_Cond", UI = AliasMap.Slider, Text = "      Condition (1:Aim when firing 2:Always aim)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperCond or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.GTLMODState.CustomTextData.AimTouchSniperCond = val return true end },
            { Key = "ModMenu_AT_Sniper_Spd", UI = AliasMap.Slider, Text = "      Smoothing / Speed (1-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperSpeed or 30 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSniperSpeed = v return true end },
            { Key = "ModMenu_AT_Sniper_FOV", UI = AliasMap.Slider, Text = "      FOV Range (1-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperFOV or 20 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSniperFOV = v return true end },
            { Key = "ModMenu_AT_Sniper_Dist", UI = AliasMap.Slider, Text = "      Distance (1-500m)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.GTLMODState.CustomTextData.AimTouchSniperDist or 400) / 5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSniperDist = v * 5 return true end },
            { Key = "ModMenu_AT_Sniper_Pred", UI = AliasMap.Slider, Text = "      Movement Prediction (0-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.GTLMODState.CustomTextData.AimTouchSniperPred or 0 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.AimTouchSniperPred = v return true end }
        }

        -- ==================== MAGIC BULLET (Kategori Khusus) ====================
        local StackMagicBullet = {
            { Key = "ModMenu_Magic_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ Custom Magic Bullet (Don't use Global users risk)", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.CustomMagicBullet end, SetFunc = function(c,v) _G.GTLMODConfig.CustomMagicBullet = v return true end },
            { Key = "ModMenu_Magic_Head", UI = AliasMap.Slider, Text = "   Head Damage (30 - 60 safe) TELEGRAM @TG_KINGOWNER", ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor(((_G.GTLMODState.CustomTextData.MagicHead or 1.0) / 5.0) * 100 + 0.5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.MagicHead = (v / 100.0) * 5.0 return true end },
            { Key = "ModMenu_Magic_Body", UI = AliasMap.Slider, Text = "   Body Damage (20 - 30 safe/Over 30 will hit behind the cover)", ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor(((_G.GTLMODState.CustomTextData.MagicBody or 1.0) / 5.0) * 100 + 0.5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.MagicBody = (v / 100.0) * 5.0 return true end },
            { Key = "ModMenu_Magic_Legs", UI = AliasMap.Slider, Text = "   Legs Damage (No need to change) TELEGRAM KING OWNER", ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor(((_G.GTLMODState.CustomTextData.MagicLegs or 1.0) / 5.0) * 100 + 0.5) end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.MagicLegs = (v / 100.0) * 5.0 return true end }
        }

        -- ==================== COMBAT GRAPHIC (hanya God Mode dan graphics) ====================
        local StackCombatGraphic = {
            { Key = "ModMenu_Ipad_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ iPad View (Tampilan iPad)", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.IpadView end, SetFunc = function(c,v) _G.GTLMODConfig.IpadView = v return true end },
            { Key = "ModMenu_Ipad_FOV", UI = AliasMap.Slider, Text = "   FOV Angle (Sudut Pandang)", ExpandHandle = "ModMenu_Ipad_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return (_G.GTLMODState.CustomTextData.IpadViewFOV or 120) - 80 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.IpadViewFOV = 80 + v return true end },
            { Key = "ModMenu_165FPS", UI = AliasMap.Switcher, Text = "Unlock 165 FPS (If turning off, will take effect next match)", GetFunc = function() return _G.GTLMODConfig.UnlockFPS end, SetFunc = function(c,v) _G.GTLMODConfig.UnlockFPS = v; if v then _G.GTLMODState.GraphicsUnlocked = false end return true end },
            { Key = "ModMenu_WallColor", UI = AliasMap.Switcher, Text = "Wallhack & Color (Green & Red)", GetFunc = function() return _G.GTLMODConfig.wallhackng end, SetFunc = function(c,v) _G.GTLMODConfig.wallhackng = v; _G.GTLMODConfig.ColorBodyV2 = v return true end },
            { Key = "ModMenu_BlackSky", UI = AliasMap.Switcher, Text = "Black Sky (Langit Hitam)", GetFunc = function() return _G.GTLMODConfig.BlackSky end, SetFunc = function(c,v) _G.GTLMODConfig.BlackSky = v return true end },
            { Key = "ModMenu_RemoveFog", UI = AliasMap.Switcher, Text = "Remove Fog (Hilangkan Kabut - If turning off, will take effect next match)", GetFunc = function() return _G.GTLMODConfig.RemoveFog end, SetFunc = function(c,v) _G.GTLMODConfig.RemoveFog = v return true end },
        }

        -- ==================== SKIN MOD (BARU) ====================
        local StackSkinMod = {
            { Key = "ModMenu_Skin_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ SKIN MOD MENU (TELEGRAM @TG_KINGOWNER)", ExpandIndex = 0, GetFunc = function() return _G.GTLMODConfig.ModSkin end, SetFunc = function(c,v) _G.GTLMODConfig.ModSkin = v return true end },
            { Key = "ModMenu_Skin_Suit", UI = AliasMap.Slider, Text = "   Outfit (1 to 87 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 80, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinSuit or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinSuit = v; if _G.OutfitSkins and _G.OutfitSkins.Suit[v] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[v] end return true end },
            { Key = "ModMenu_Skin_Bag", UI = AliasMap.Slider, Text = "   Bag (Backpack)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 16, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinBag or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinBag = v; if _G.OutfitSkins and _G.OutfitSkins.Bag[v] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[v] end return true end },
            { Key = "ModMenu_Skin_Helmet", UI = AliasMap.Slider, Text = "   Helmet", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 12, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinHelmet or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinHelmet = v; if _G.OutfitSkins and _G.OutfitSkins.Helmet[v] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[v] end return true end },
            { Key = "ModMenu_Skin_M416", UI = AliasMap.Slider, Text = "   M416 Skin (1 to 10 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 9, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinM416 or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinM416 = v; if _G.skinIdMappings[101004] and _G.skinIdMappings[101004][v] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][v] end return true end },
            { Key = "ModMenu_Skin_AKM", UI = AliasMap.Slider, Text = "   AKM Skin (1 to 8 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 8, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinAKM or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinAKM = v; if _G.skinIdMappings[101001] and _G.skinIdMappings[101001][v] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][v] end return true end },
            { Key = "ModMenu_Skin_SCAR", UI = AliasMap.Slider, Text = "   SCAR-L Skin (1 to 8 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 8, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinSCAR or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinSCAR = v; if _G.skinIdMappings[101003] and _G.skinIdMappings[101003][v] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][v] end return true end },
            { Key = "ModMenu_Skin_M762", UI = AliasMap.Slider, Text = "   Beryl M762 Skin (1 to 9 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 8, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinM762 or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinM762 = v; if _G.skinIdMappings[101008] and _G.skinIdMappings[101008][v] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][v] end return true end },
            { Key = "ModMenu_Skin_AUG", UI = AliasMap.Slider, Text = "   AUG Skin", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 7, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinAUG or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinAUG = v; if _G.skinIdMappings[101006] and _G.skinIdMappings[101006][v] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][v] end return true end },
            { Key = "ModMenu_Skin_Honey", UI = AliasMap.Slider, Text = "   Honey Badger Skin", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinHoney or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinHoney = v; if _G.skinIdMappings[101012] and _G.skinIdMappings[101012][v] then _G.WeaponSkinMap[101012] = _G.skinIdMappings[101012][v] end return true end },
            { Key = "ModMenu_Skin_QBZ", UI = AliasMap.Slider, Text = "   QBZ Skin ( 1 to 3)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 3, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinQBZ or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinQBZ = v; if _G.skinIdMappings[101007] and _G.skinIdMappings[101007][v] then _G.WeaponSkinMap[101007] = _G.skinIdMappings[101007][v] end return true end },
            { Key = "ModMenu_Skin_ASM", UI = AliasMap.Slider, Text = "   ASM Abakan Skin ( 1 to 2)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinASM or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinASM = v; if _G.skinIdMappings[101101] and _G.skinIdMappings[101101][v] then _G.WeaponSkinMap[101101] = _G.skinIdMappings[101101][v] end return true end },
            { Key = "ModMenu_Skin_ACE32", UI = AliasMap.Slider, Text = "   ACE32 Skin ( 1 to 2)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinACE32 or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinACE32 = v; if _G.skinIdMappings[101102] and _G.skinIdMappings[101102][v] then _G.WeaponSkinMap[101102] = _G.skinIdMappings[101102][v] end return true end },
            { Key = "ModMenu_Skin_UMP", UI = AliasMap.Slider, Text = "   UMP45 Skin (1 to 6 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 6, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinUMP or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinUMP = v; if _G.skinIdMappings[102002] and _G.skinIdMappings[102002][v] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][v] end return true end },
            { Key = "ModMenu_Skin_UZI", UI = AliasMap.Slider, Text = "   UZI Skin (1 to 2 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinUZI or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinUZI = v; if _G.skinIdMappings[102001] and _G.skinIdMappings[102001][v] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][v] end return true end },
            { Key = "ModMenu_Skin_Vector", UI = AliasMap.Slider, Text = "   Vector Skin (1 to 2 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinVector or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinVector = v; if _G.skinIdMappings[102003] and _G.skinIdMappings[102003][v] then _G.WeaponSkinMap[102003] = _G.skinIdMappings[102003][v] end return true end },
            { Key = "ModMenu_Skin_Groza", UI = AliasMap.Slider, Text = "   Groza Skin (1 to 2 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinGroza or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinGroza = v; if _G.skinIdMappings[101005] and _G.skinIdMappings[101005][v] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][v] end return true end },
            { Key = "ModMenu_Skin_Kar98K", UI = AliasMap.Slider, Text = "   Kar98K Skin (1 to 3 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 3, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinKar98K or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinKar98K = v; if _G.skinIdMappings[103001] and _G.skinIdMappings[103001][v] then _G.WeaponSkinMap[103001] = _G.skinIdMappings[103001][v] end return true end },
            { Key = "ModMenu_Skin_M24", UI = AliasMap.Slider, Text = "   M24 Skin (1 to 2 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinM24 or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinM24 = v; if _G.skinIdMappings[103002] and _G.skinIdMappings[103002][v] then _G.WeaponSkinMap[103002] = _G.skinIdMappings[103002][v] end return true end },
            { Key = "ModMenu_Skin_AWM", UI = AliasMap.Slider, Text = "   AWM Skin (1 to 4 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 4, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinAWM or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinAWM = v; if _G.skinIdMappings[103003] and _G.skinIdMappings[103003][v] then _G.WeaponSkinMap[103003] = _G.skinIdMappings[103003][v] end return true end },
            { Key = "ModMenu_Skin_AMR", UI = AliasMap.Slider, Text = "   AMR Skin (1 to 3 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 3, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinAMR or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinAMR = v; if _G.skinIdMappings[103012] and _G.skinIdMappings[103012][v] then _G.WeaponSkinMap[103012] = _G.skinIdMappings[103012][v] end return true end },
            { Key = "ModMenu_Skin_S12K", UI = AliasMap.Slider, Text = "   S12K Skin (1 to 2 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinS12K or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinS12K = v; if _G.skinIdMappings[104003] and _G.skinIdMappings[104003][v] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][v] end return true end },
            { Key = "ModMenu_Skin_DBS", UI = AliasMap.Slider, Text = "   DBS Skin (1 to 3 custom)", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 3, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinDBS or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinDBS = v; if _G.skinIdMappings[104004] and _G.skinIdMappings[104004][v] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][v] end return true end },
            { Key = "ModMenu_Skin_Dacia", UI = AliasMap.Slider, Text = "   Dacia (Car) Skin", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 90, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinDacia or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinDacia = v; if _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][v] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][v] end return true end },
            { Key = "ModMenu_Skin_UAZ", UI = AliasMap.Slider, Text = "   UAZ (Jeep) Skin", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 90, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinUAZ or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinUAZ = v; if _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][v] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][v] end return true end },
            { Key = "ModMenu_Skin_Coupe", UI = AliasMap.Slider, Text = "   Coupe RB (Sports) Skin", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 70, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinCoupe or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinCoupe = v; if _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][v] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][v] end return true end },
            { Key = "ModMenu_Skin_Buggy", UI = AliasMap.Slider, Text = "   Buggy Skin", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 50, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinBuggy or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinBuggy = v; if _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][v] then _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][v] end return true end },
            { Key = "ModMenu_Skin_Mirado", UI = AliasMap.Slider, Text = "   Mirado (Convertible) Skin", ExpandHandle = "ModMenu_Skin_Ex", MinValue = 1, MaxValue = 27, GetFunc = function() return _G.GTLMODState.CustomTextData.SkinMirado or 1 end, SetFunc = function(c,v) _G.GTLMODState.CustomTextData.SkinMirado = v; if _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][v] then _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][v] end return true end }
        }

        -- ==================== COLOR MOD (Warna untuk ESP dan Wallhack) ====================
        local StackColorMod = {
            { Key = "COLOR_Visible", UI = AliasMap.Switcher, Text = "Visible Color (ESP & WH)",
              SwitcherText = {"Red","White","Yellow","Green","Cyan","Blue","Purple"},
              SwitcherValue = {1,2,3,4,5,6,7},
              GetFunc = function() return _G.ColorConfig.VisibleColor end,
              SetFunc = function(_, v) _G.ColorConfig.VisibleColor = v; _G.SaveModSettings(); return true end },
            { Key = "COLOR_Invisible", UI = AliasMap.Switcher, Text = "Invisible Color (ESP & WH)",
              SwitcherText = {"Red","White","Yellow","Green","Cyan","Blue","Purple"},
              SwitcherValue = {1,2,3,4,5,6,7},
              GetFunc = function() return _G.ColorConfig.InvisibleColor end,
              SetFunc = function(_, v) _G.ColorConfig.InvisibleColor = v; _G.SaveModSettings(); return true end },
            { Key = "COLOR_Brightness", UI = AliasMap.Slider, Text = "Brightness (1-50)", Min = 1, Max = 50, Step = 1,
              GetFunc = function() return _G.ColorConfig.Brightness end,
              SetFunc = function(_, v) _G.ColorConfig.Brightness = v; _G.SaveModSettings(); return true end },
            { Key = "COLOR_Glow", UI = AliasMap.Slider, Text = "Glow Intensity (0-10) (WH)", Min = 0, Max = 10, Step = 0.5,
              GetFunc = function() return _G.ColorConfig.Glow end,
              SetFunc = function(_, v) _G.ColorConfig.Glow = v; _G.SaveModSettings(); return true end }
        }

        -- ==================== DEFINE MENU PAGE ====================
        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text= "KING MENU",
            UIKey = "Setting_Page_Privacy", 
            Category = {
                { Key = "Cat_SkinMod", Text= "SKIN CUSTOM", Stack = StackSkinMod },
                { Key = "Cat_Aimbot_Force", Text= "UR/ROOM-TOUCH AIM", Stack = StackAimbotForce },
                { Key = "Cat_ESP_Visual", Text= "ESP PLAYER", Stack = StackESPVisual },
                { Key = "Cat_Magic_Bullet", Text= "MAGIC + HEADSHOT", Stack = StackMagicBullet },
                { Key = "Cat_Combat_Graphic", Text= "WALLHACK/FPS", Stack = StackCombatGraphic },
                { Key = "Cat_ColorMod", Text= "COLOR CUSTOM", Stack = StackColorMod }
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
            Msg.Show(1, "KING VIP PAK", "DON'T PLAY LIKE A CHEATER \nAVOID FROM REPORT!!\n\nBYPASS ADDED - SEND FEEDBACK ", function() local Web = require("client.slua.logic.url.logic_webview_sdk"); if Web and Web.OpenURL then Web:OpenURL("https://t.me/TG_KINGOWNER") end end, function() end, "JOIN", "CLOSE")
            _G.GTLMODState.MenuStep = 99
            _G.GTLMODMenuAlreadyShown = true
        end

        local function Step_Welcome()
            Msg.Show(1, "KING VIP PAK", "ACTIVATION SUCCESSFUL!\n\nBEWARE OF THE SCAMMER CHECK THE USERNAME.\nTHE REAL OWNER IS KING",
            function() 
                _G.InitModMenuTab()
                Notify("VIP MOD MENU BY KING OWNER to toggle features!")
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
    if _G.GTLMODState.GraphicsUnlocked or currentTime > limitTime then return end

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
    Notify("Graphics & FPS 165Hz Unlocked (Upgraded Version)")
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
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime) < 3.0 then
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
-- WALL-BOUND FUNCTION & ROOT RESTORE (menggunakan ColorConfig)
-- ==========================================
local function Undowallhackng(enemy, markData)
    pcall(function()
        if markData.WallhackApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function() if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(false) end end)
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
-- WALLHACK WITH COLOR FROM COLORCONFIG
-- ==========================================
local function ApplyColorBodyV2(enemy, pc, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end
        
        local curTime = os.clock()
        if markData.LastVisCheckTime == nil or (curTime - markData.LastVisCheckTime) > 0.3 then
            markData.LastVisCheckTime = curTime
            local isHidden = true
            pcall(function()
                if Valid(pc) and type(pc.LineOfSightTo) == "function" then
                    if pc:LineOfSightTo(enemy) then isHidden = false else isHidden = true end
                end
            end)
            markData.CachedHiddenState = isHidden
        end
        
        local hidden = markData.CachedHiddenState
        if hidden == nil then hidden = true end
        
        -- Ambil warna dari ColorConfig
        local visibleColor = GetAppliedColor(_G.ColorConfig.VisibleColor or 4, _G.ColorConfig.Brightness)
        local invisibleColor = GetAppliedColor(_G.ColorConfig.InvisibleColor or 3, _G.ColorConfig.Brightness)
        local finalColor = hidden and invisibleColor or visibleColor
        
        local colorHash = string.format("%d_%d_%d_%d", finalColor.R, finalColor.G, finalColor.B, finalColor.A)
        local currentMeshCount = #meshes
        local isMeshChanged = (markData.LastMeshCount ~= currentMeshCount)
        
        if not isMeshChanged and markData.LastHiddenState == hidden and markData.LastColorHash == colorHash then return end
        
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
                                mid:SetVectorParameterValue("ParaScaleOffset", SCALE_COLOR_V2)
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
-- AIMBOT V2 SYSTEM WITH NEW INTEGRATED TECHNOLOGY (KISSMET SMOOTH UPDATE)
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
            if not slua.isValid(target) then goto continue end
            
            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)
            
            if igKnock and target.HealthStatus == 1 then goto continue end
            
            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then goto continue end
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

    end)
end

-- ========================================== 
-- MAIN LOOP: EXTREMELY POWERFUL OPTIMIZED
-- ========================================== 
local function MainLoop() 
    if isExpired then return end

    if _G.GTLMODState.CustomTextData == nil then 
        _G.GTLMODState.CustomTextData = {OuterSpeed = 10, InnerSpeed = 10, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120, AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250, AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30, AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400}
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

    -- ========================================== 
    -- SKIN MOD LOOP + KILL COUNTER + DEADBOX
    -- ========================================== 
    if _G.GTLMODConfig.ModSkin then
        if not _G.TDSkinLoopStarted then
            if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
            if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
            _G.TDSkinLoopStarted = true
            -- Aktifkan Kill Counter & Effect
            if not _G.KillInfoCounterHacked and _G.ForceEnableKillCounterUI then _G.ForceEnableKillCounterUI() end
        end
        
        _G.GTLMODState.SkinWasApplied = true
        local curTime = os.clock()
        if not _G.LastSkinUpdateTime or (curTime - _G.LastSkinUpdateTime) > 1.5 then
            _G.LastSkinUpdateTime = curTime
            pcall(function()
                local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
                if isAlive then
                    if _G.ReadLiveConfig then _G.ReadLiveConfig() end
                    if _G.equip_character_avatar then _G.equip_character_avatar(localPlayer) end
                    if _G.ApplyWeaponSkins then _G.ApplyWeaponSkins(localPlayer) end
                    if _G.ApplyVehicleSkins then _G.ApplyVehicleSkins(localPlayer) end
                    if _G.HandlePetLogic then _G.HandlePetLogic() end
                    -- DeadBox skin
                    if _G.DeadBox_TemperRequest and _G.NeedCheckDeadBoxTimer > 0 then _G.DeadBox_TemperRequest(pc) end
                end
            end)
        end
    else
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
    -- Aimbot Force dipindahkan ke loop terpisah
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
            
            if _G.GTLMODConfig.WhiteBody then
                _G.GTLMODState.PrevGraphicsState.WhiteBody = true
            elseif not _G.GTLMODConfig.WhiteBody and _G.GTLMODState.PrevGraphicsState.WhiteBody then
                _G.GTLMODState.PrevGraphicsState.WhiteBody = false
            end
            
            if _G.GTLMODConfig.ColorBodyV2 then
                _G.GTLMODState.PrevGraphicsState.ColorBodyV2 = true
            elseif not _G.GTLMODConfig.ColorBodyV2 and _G.GTLMODState.PrevGraphicsState.ColorBodyV2 then
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
                local anyWeaponModOn = _G.GTLMODConfig.CustomHRecoil or _G.GTLMODConfig.CustomVRecoil or _G.GTLMODConfig.LessShake or _G.GTLMODConfig.Accuracy or _G.GTLMODConfig.Crosshair or _G.GTLMODConfig.GodMode or _G.GTLMODConfig.AutoHead or _G.GTLMODConfig.CustomAimbot or _G.GTLMODConfig.CustomAimbotClose or _G.GTLMODConfig.CustomMagicBullet

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
                    
                    if _G.GTLMODConfig.CustomHRecoil then entity.AccessoriesHRecoilFactor = _G.GTLMODState.CustomTextData.HRecoil or 0.3 
                    elseif _G.GTLMODConfig.LessRecoil then entity.AccessoriesHRecoilFactor = 0.3 end
                    
                    if _G.GTLMODConfig.CustomVRecoil then entity.AccessoriesVRecoilFactor = _G.GTLMODState.CustomTextData.VRecoil or 0.3
                    elseif _G.GTLMODConfig.VerticalRecoil then entity.AccessoriesVRecoilFactor = 0.3 end
                    
                    if _G.GTLMODConfig.LessShake then entity.RecoilKickADS = 0.0; entity.RecoilKickADS = 0.0; entity.RecoilKickADS = 0.0 end
                    if _G.GTLMODConfig.Accuracy then entity.GameDeviationAccuracy = 0.0 end
                    if _G.GTLMODConfig.Crosshair then entity.GameDeviationFactor = 0.0 end
                    if _G.GTLMODConfig.GodMode then entity.BulletFireSpeed = 500000.0; entity.ShootInterval = 0.001; entity.BaseDamage = 60000.0 end
                    if _G.GTLMODConfig.CustomMagicBullet then
                        entity.BaseDamage = entity.BaseDamage * (_G.GTLMODState.CustomTextData.MagicHead or 1.0)
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

    local mHead_Global, mBody_Global, mLegs_Global = 1.0, 1.0, 1.0
    local runInject_Global = false
    
    pcall(function()
        if _G.GTLMODConfig.CustomMagicBullet then
            runInject_Global = true
            mHead_Global = 1.0; mBody_Global = 1.0; mLegs_Global = 1.0
            if _G.GTLMODState.CustomTextData then
                local cData = _G.GTLMODState.CustomTextData
                if cData.MagicHead ~= nil then mHead_Global = tonumber(cData.MagicHead) or mHead_Global end
                if cData.MagicBody ~= nil then mBody_Global = tonumber(cData.MagicBody) or mBody_Global end
                if cData.MagicLegs ~= nil then mLegs_Global = tonumber(cData.MagicLegs) or mLegs_Global end
            end
        elseif _G.GTLMODConfig.MagicBullet then
            runInject_Global = true
            mHead_Global = 1.05; mBody_Global = 1.0; mLegs_Global = 1.0
        end

        if runInject_Global then
            local currentMagicHash = "M_"..tostring(mHead_Global).."_"..tostring(mBody_Global).."_"..tostring(mLegs_Global)
            if _G.GTLMODState.LastMagicConfigHash ~= currentMagicHash then
                _G.GTLMODState.MagicUpdateVersion = (_G.GTLMODState.MagicUpdateVersion or 0) + 1
                _G.GTLMODState.LastMagicConfigHash = currentMagicHash
            end
        else
            if _G.GTLMODState.LastMagicConfigHash ~= "OFF" then
                _G.GTLMODState.MagicUpdateVersion = (_G.GTLMODState.MagicUpdateVersion or 0) + 1
                _G.GTLMODState.LastMagicConfigHash = "OFF"
            end
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

        local BoneScaleMap = {
            ["head"] = mHead_Global, ["neck_01"] = mHead_Global,
            ["pelvis"] = mBody_Global, ["spine_01"] = mBody_Global, ["spine_02"] = mBody_Global, ["spine_03"] = mBody_Global,
            ["thigh_l"] = mLegs_Global, ["thigh_r"] = mLegs_Global, 
            ["calf_l"] = mLegs_Global, ["calf_r"] = mLegs_Global,   
            ["foot_l"] = mLegs_Global, ["foot_r"] = mLegs_Global    
        }
        
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

                    local currentMeshCount = 0
                    if Valid(eMesh) then
                        local tempMeshes = GetAllSkeletalMeshes(enemy, markData)
                        currentMeshCount = #tempMeshes
                    end
                    local isMeshChanged = (markData.LastMeshCountWall ~= currentMeshCount)

                    if _G.GTLMODConfig.wallhackng then
                        if isMeshChanged or not markData.WallhackApplied then
                            Applywallhackng(enemy, markData)
                            markData.WallhackApplied = true
                            markData.LastMeshCountWall = currentMeshCount
                        end
                    else
                        Undowallhackng(enemy, markData)
                    end

                    if _G.GTLMODConfig.ColorBodyV2 then 
                        ApplyColorBodyV2(enemy, pc, markData) 
                    else
                        UndoColorBodyV2(enemy, markData)
                    end

                    pcall(function()
                        local EnemyMesh = eMesh
                        if slua.isValid(EnemyMesh) then
                            local uniqueID = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)
                            
                            if markData.MagicBulletHash == _G.GTLMODState.LastMagicConfigHash and markData.MagicTargetID == uniqueID then
                                return 
                            end

                            local PhysicsAsset = EnemyMesh.PhysicsAssetOverride
                            if not slua.isValid(PhysicsAsset) and EnemyMesh.SkeletalMesh then PhysicsAsset = EnemyMesh.SkeletalMesh.PhysicsAsset end

                            if slua.isValid(PhysicsAsset) and PhysicsAsset.SkeletalBodySetups then
                                if not _G.AK_ModdedPhysAssets then _G.AK_ModdedPhysAssets = {} end
                                local PhysAssetName = "DefaultPhys"
                                pcall(function() PhysAssetName = PhysicsAsset:GetName() end)
                                
                                if _G.AK_ModdedPhysAssets[PhysAssetName] ~= _G.GTLMODState.LastMagicConfigHash then
                                    
                                    if not _G.AK_OrigHitboxes then _G.AK_OrigHitboxes = {} end
                                    if not _G.AK_OrigHitboxes[PhysAssetName] then _G.AK_OrigHitboxes[PhysAssetName] = {} end
                                    local OrigHitboxData = _G.AK_OrigHitboxes[PhysAssetName]

                                    local SkeletalBodySetups = PhysicsAsset.SkeletalBodySetups
                                    local numSetups = type(SkeletalBodySetups.Num) == "function" and SkeletalBodySetups:Num() or #SkeletalBodySetups
                                    local limit = numSetups > 50 and 50 or numSetups

                                    for i = 1, limit do 
                                        local BodySetup = type(SkeletalBodySetups.Get) == "function" and SkeletalBodySetups:Get(i-1) or SkeletalBodySetups[i]
                                        if slua.isValid(BodySetup) then
                                            local LowerBoneName = string.lower(tostring(BodySetup.BoneName))
                                            local MatchedBoneKey = nil
                                            for k, _ in pairs(BoneScaleMap) do
                                                if string.find(LowerBoneName, k, 1, true) then MatchedBoneKey = k break end
                                            end

                                            if MatchedBoneKey then
                                                local TargetScale = 1.0 
                                                if runInject_Global then TargetScale = BoneScaleMap[MatchedBoneKey] end
                                                
                                                local AggGeom = BodySetup.AggGeom
                                                
                                                local BoxElems = AggGeom and AggGeom.BoxElems or BodySetup.BoxElems
                                                local SphereElems = AggGeom and AggGeom.SphereElems or BodySetup.SphereElems
                                                local SphylElems = AggGeom and AggGeom.SphylElems or BodySetup.SphylElems

                                                local BoxElem = GetFirstElemSafe(BoxElems)
                                                local SphereElem = GetFirstElemSafe(SphereElems)
                                                local SphylElem = GetFirstElemSafe(SphylElems)

                                                if not OrigHitboxData[MatchedBoneKey] then
                                                    OrigHitboxData[MatchedBoneKey] = { Box = nil, Sphere = nil, Sphyl = nil }
                                                    if BoxElem then OrigHitboxData[MatchedBoneKey].Box = { X = BoxElem.X, Y = BoxElem.Y, Z = BoxElem.Z } end
                                                    if SphereElem then OrigHitboxData[MatchedBoneKey].Sphere = { Radius = SphereElem.Radius } end
                                                    if SphylElem then OrigHitboxData[MatchedBoneKey].Sphyl = { Radius = SphylElem.Radius, Length = SphylElem.Length } end
                                                end

                                                local OrigElemData = OrigHitboxData[MatchedBoneKey]

                                                if OrigElemData.Box and BoxElem then
                                                    BoxElem.X = OrigElemData.Box.X * TargetScale
                                                    BoxElem.Y = OrigElemData.Box.Y * TargetScale
                                                    BoxElem.Z = OrigElemData.Box.Z * TargetScale
                                                    if type(BoxElems.Set) == "function" then BoxElems:Set(0, BoxElem) else BoxElems[1] = BoxElem end
                                                    if AggGeom then AggGeom.BoxElems = BoxElems; BodySetup.AggGeom = AggGeom else BodySetup.BoxElems = BoxElems end
                                                end

                                                if OrigElemData.Sphere and SphereElem then
                                                    SphereElem.Radius = OrigElemData.Sphere.Radius * TargetScale
                                                    if type(SphereElems.Set) == "function" then SphereElems:Set(0, SphereElem) else SphereElems[1] = SphereElem end
                                                    if AggGeom then AggGeom.SphereElems = SphereElems; BodySetup.AggGeom = AggGeom else BodySetup.SphereElems = SphereElems end
                                                end

                                                if OrigElemData.Sphyl and SphylElem then
                                                    SphylElem.Radius = OrigElemData.Sphyl.Radius * TargetScale
                                                    SphylElem.Length = OrigElemData.Sphyl.Length * TargetScale
                                                    if type(SphylElems.Set) == "function" then SphylElems:Set(0, SphylElem) else SphylElems[1] = SphylElem end
                                                    if AggGeom then AggGeom.SphylElems = SphylElems; BodySetup.AggGeom = AggGeom else BodySetup.SphylElems = SphylElems end
                                                end
                                            end
                                        end
                                    end
                                    _G.AK_ModdedPhysAssets[PhysAssetName] = _G.GTLMODState.LastMagicConfigHash
                                end
                                
                                if EnemyMesh.SetPhysicsAsset then EnemyMesh:SetPhysicsAsset(PhysicsAsset) end
                                EnemyMesh.PhysicsAssetOverride = PhysicsAsset
                                
                                markData.MagicBulletHash = _G.GTLMODState.LastMagicConfigHash
                                markData.MagicTargetID = uniqueID
                            end
                        end
                    end)

                    local distM = 0
                    pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)

                    local currentHp, maxHp = 100, 100
                    local showFrameUI = _G.GTLMODConfig.Esp5 or _G.GTLMODConfig.EspVipPro or _G.GTLMODConfig.EspVip
                    
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
                            if Valid(MyHUD) then
                                local loopCount = 100
                                local zStep = 200
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
                                                            color = C_YELLOW
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
if _G.GTLMODConfig.Esp7 then
    pcall(function()
        local MyHUD = Cached_MyHUD
        if not Valid(MyHUD) then return end

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
                            if tPawn.bIsAI == true or tPawn.IsAI == true then
                                isAI = true
                            end
                            if not isAI then
                                local pState = tPawn.PlayerState or (type(tPawn.GetPlayerState) == "function" and tPawn:GetPlayerState())
                                if slua.isValid(pState) and (pState.bIsABot == true or pState.bIsBot == true) then
                                    isAI = true
                                end
                            end
                            if isAI then
                                aiCount = aiCount + 1
                            else
                                realCount = realCount + 1
                            end
                        end
                    end
                end
            end
        end

        local totalEnemy = realCount + aiCount
        if totalEnemy > 0 then
            local text = string.format("ENEMY (P: %d | B: %d)", realCount, aiCount)
            MyHUD:AddDebugText(text, localPlayer, 1.2, {X=0, Y=0, Z=150}, {X=0, Y=0, Z=150}, {R=255, G=255, B=255, A=255}, true, false, true, nil, 1.0, true)
        else
            MyHUD:AddDebugText("( CLEAR ENEMY VIP KING)", localPlayer, 1.2, {X=0, Y=0, Z=150}, {X=0, Y=0, Z=150}, {R=0, G=255, B=0, A=255}, true, false, true, nil, 1.0, true)
        end
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

                    -- =================== ESP HEALTH V1 (Warna berdasarkan ColorConfig) ===================
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

                            -- Refresh visibility check setiap frame
                            local bIsVisible = false
                            if pc and type(pc.LineOfSightTo) == "function" then
                                bIsVisible = pc:LineOfSightTo(enemy)
                            end

                            -- Ambil warna dari ColorConfig
                            local visibleCol = GetAppliedColor(_G.ColorConfig.VisibleColor or 4, _G.ColorConfig.Brightness)
                            local invisibleCol = GetAppliedColor(_G.ColorConfig.InvisibleColor or 3, _G.ColorConfig.Brightness)
                            
                            local textColor = {R=255, G=255, B=255, A=255}
                            if isKnock then
                                textColor = {R=0, G=0, B=255, A=255}      -- Biru
                            else
                                textColor = bIsVisible and visibleCol or invisibleCol
                            end

                            local prefix = bIsVisible and "▶" or "▶"
                            local label = ""
                            if isKnock then
                                label = (pName ~= "" and string.format("%s [♿]", pName) or "♿")
                            else
                                if pName ~= "" then
                                    label = string.format("%s %s %.0f%%", pName, prefix, pctValue)
                                else
                                    label = string.format("%s %.0f%%", prefix, pctValue)
                                end
                            end

                            hud:AddDebugText(label, enemy, 0.2, {X=0, Y=0, Z=120}, {X=0, Y=0, Z=120},
                                             textColor, true, false, true, nil, 1.0, true)
                        end)
                    end

                    -- =================== ESP RANGE V1 (Jarak dalam meter) ===================
                    if _G.GTLMODConfig.EspDistance then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if not (Valid(hud) and hud.AddDebugText) then return end
                            if distM > 400 then return end

                            local distMeters = math.floor(distM + 0.5)
                            local rangeColor = {R=255, G=255, B=255, A=255} -- putih

                            hud:AddDebugText(string.format("%.0fm", distMeters), enemy, 0.3,
                                             {X=15, Y=15, Z=-15}, {X=15, Y=15, Z=-15},
                                             rangeColor, true, false, true, nil, 0.9, true)
                        end)
                    end

-- =================== ESP NAME V1 (Nama dengan warna dari ColorConfig) ===================
if _G.GTLMODConfig.EspName and not _G.GTLMODConfig.EspVipPro then
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

        local visibleCol = GetAppliedColor(_G.ColorConfig.VisibleColor or 4, _G.ColorConfig.Brightness)
        local invisibleCol = GetAppliedColor(_G.ColorConfig.InvisibleColor or 3, _G.ColorConfig.Brightness)
        
        local nameColor = {R=255, G=255, B=255, A=255}
        if isKnock then
            nameColor = {R=0, G=0, B=255, A=255}
        else
            nameColor = bIsVisible and visibleCol or invisibleCol
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
                                    if PPM.OutlineColor then PPM.OutlineColor = {r = 0, g = 1, b = 0, a = 1} end
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

        -- ========================================== 
        -- ESP TYPE 7: ENEMY COUNTER FORMAT BARU "P: X B: X"
        -- ========================================== 
        if _G.GTLMODConfig.Esp7 then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if Valid(MyHUD) then
                    local text = string.format("[ PLAY SAFE!! KING OWMER ]", realCount, aiCount)
                    MyHUD:AddDebugText(text, localPlayer, 0.06, {X=0, Y=0, Z=0}, {X=0, Y=0, Z=0}, C_RED, true, false, true, nil, 0.8, true)
                end
            end)
        end
    end)
end

_G.GTLMODState.LoopToken = (_G.GTLMODState.LoopToken or 0) + 1 
local myToken = _G.GTLMODState.LoopToken

-- ========================================== 
-- LOOP UTAMA (ESP & FITUR LAIN) DENGAN 0.2 DETIK
-- ========================================== 
local function FastTick() 
    if isExpired then 
        if not _G.GTLMODNotifiedExpire then
            Notify("MOD HAS EXPIRED! PLEASE CONTACT ADMIN TO RENEW!\nTelegram KING ")
            _G.GTLMODNotifiedExpire = true
            ExpiredTick() 
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
-- LOOP KHUSUS AIMBOT FORCE DENGAN 0.016 DETIK (~60 FPS)
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

-- ========================================== 
-- IGNITE BOTH LOOPS
-- ========================================== 
if not isExpired then
    FastTick() 
    _G.GTLMODState.AimbotLoopToken = (_G.GTLMODState.AimbotLoopToken or 0) + 1
    aimbotToken = _G.GTLMODState.AimbotLoopToken
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.1, FastAimbotTick) -- mulai dengan jeda kecil
    end
    Notify("You are using VIP Mod v1. If you don't have a key, inbox Telegram : @TG_KINGOWMER")
else
    FastTick() 
end

-- ===================================================================================
-- SYSTEM HOOKS BYPASS
-- ===================================================================================
local function InitAllModSystems()
    if isExpired then return end 

    pcall(function()
        if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end
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

-- ==============================================================================
-- ================== THE RETURN SECTION RETAINS THE ORIGINAL CODE. ===================
-- ==============================================================================
-- ============================================================================
-- POLO FEATURES LAYER (ported from the decompiled POLO mod)
-- Isko WORKING lua ke andar append kiya gaya hai. Sab features auto-ON hain.
-- Har public entry pcall-wrapped hai taaki koi bhi error mod ko na tode.
-- ============================================================================

_G.Polo = _G.Polo or {}
local Polo = _G.Polo

Polo.CONFIG = {
    AutoHead = true,
    EspVip = false,
    EspDistance = true,
    EspVipPro = false,
    EspRadar = false,
    EspLoai5 = true,
    EspLoai6 = false,
    EspLoai7 = false,
    EspAntenna = true,
    EspOutline = true,
    UnlockFPS = false,
    IpadView = true,
    CustomAimbot = true,
    CustomAimbotClose = true,
    LessShake = true,
    RemoveGrass = true,
    RemoveFog = true,
    WhiteBody = true,
    ColorBodyV2 = true,
    WallXuyenTuong = true,
    Crosshair = true,
    Accuracy = true,
    GodMode = true,
    BlackSky = true,
    AimTouchEnable = false,
    AimTouchHipIgKnock = true,
    AimTouchHipIgBot = true,
    AimTouchHipVisCheck = true,
    AimTouchHipfire = true,
    AimTouchSG = false,
    AimTouchSGAutoFire = false,
    AimTouchScopeAll = false,
    AimTouchScopeSniper = false,
    ModSkin = true,
}

Polo.CTX = {
    OuterSpeed = 10,
    InnerSpeed = 10,
    AimTouchHipSpeed = 50,
    AimTouchHipFOV = 30,
    AimTouchHipDist = 250,
    AimTouchSGSpeed = 80,
    AimTouchSGFOV = 40,
    AimTouchSGDist = 30,
    AimTouchScopeSpeed = 40,
    AimTouchScopeFOV = 20,
    AimTouchScopeDist = 300,
    AimTouchSniperSpeed = 30,
    AimTouchSniperFOV = 20,
    AimTouchSniperDist = 400,
    KillCounter = true,
}

-- ============================ HELPER ============================
local function getPlayerChar()
    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"]
        or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData then return nil end
    return GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
end

local function enemyAlive(enemy)
    local dead = false
    pcall(function()
        if enemy.bIsDead ~= nil then dead = enemy.bIsDead
        elseif enemy.bIsDeadFlag ~= nil then dead = enemy.bIsDeadFlag
        elseif type(enemy.IsDead) == "function" then dead = enemy:IsDead()
        end
        if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then dead = true end
    end)
    return not dead
end

local function enemyIsBot(enemy)
    local bot = false
    pcall(function()
        local ps = enemy.PlayerState
        if slua.isValid(ps) then
            if ps.bIsABot then bot = true
            elseif ps.bIsBot then bot = true
            end
        end
        if enemy.bIsBot then bot = true end
    end)
    return bot
end

local function getBoneWorldPos(enemy, boneName)
    local p = nil
    pcall(function()
        local out = { X = 0, Y = 0, Z = 0 }
        local ok, r = pcall(function() return enemy:GetBonePos(boneName, out) end)
        if ok and r and r.X and r.X ~= 0 then p = r
        else
            p = out
        end
        if p and p.X == 0 and p.Y == 0 and p.Z == 0 and type(enemy.GetSocketLocation) == "function" then
            local s = enemy:GetSocketLocation(boneName)
            if s then p = s end
        end
        if p and p.X == 0 and p.Y == 0 and p.Z == 0 and type(enemy.K2_GetActorLocation) == "function" then
            local s = enemy:K2_GetActorLocation()
            if s then p = s end
        end
    end)
    return p
end

-- ============================ WEAPON MODS ============================
-- LessShake / Crosshair(no-spread) / Accuracy / Aimbot speed tuning
-- (GodMode + AutoHead already working base me hain)
Polo.WeaponMods = function()
    if not (Polo.CONFIG.LessShake or Polo.CONFIG.Crosshair or Polo.CONFIG.Accuracy
        or Polo.CONFIG.CustomAimbot or Polo.CONFIG.CustomAimbotClose) then return end
    pcall(function()
        local char = getPlayerChar()
        if not slua.isValid(char) then return end
        local wmc = char.WeaponManagerComponent
        local weapon = nil
        if slua.isValid(wmc) and type(wmc.GetCurrentWeapon) == "function" then
            weapon = wmc:GetCurrentWeapon()
        end
        if not slua.isValid(weapon) then
            if type(char.GetCurrentShootWeapon) == "function" then weapon = char:GetCurrentShootWeapon()
            elseif type(char.GetCurrentWeapon) == "function" then weapon = char:GetCurrentWeapon()
            end
        end
        if not slua.isValid(weapon) then return end
        local ent = weapon.ShootWeaponEntityComp or weapon.ShootWeaponEntityComponent or weapon.ShootWeaponEntity
        if not slua.isValid(ent) then return end
        if not ent.OriginalStatsCached then
            ent.OriginalStatsCached = {
                GameDeviationFactor = ent.GameDeviationFactor,
                GameDeviationAccuracy = ent.GameDeviationAccuracy,
                RecoilKick = ent.RecoilKick,
                RecoilKickADS = ent.RecoilKickADS,
                AnimationKick = ent.AnimationKick,
            }
        end
        if Polo.CONFIG.LessShake then
            ent.RecoilKick = 0.22
            ent.RecoilKickADS = 0.11
            ent.AnimationKick = 0.23
        end
        if Polo.CONFIG.Crosshair then
            ent.GameDeviationFactor = 0.1
        end
        if Polo.CONFIG.Accuracy then
            ent.GameDeviationAccuracy = 0.1
        end
        if ent.AutoAimingConfig then
            local speed = Polo.CTX.OuterSpeed or 10
            if Polo.CONFIG.CustomAimbotClose then speed = Polo.CTX.InnerSpeed or 10 end
            local function tune(range)
                if not range then return end
                range.Speed = speed
                range.RangeRate = 3.0
                range.SpeedRate = 1.3
                range.RangeRateSight = 1.8
                range.SpeedRateSight = 2.2
                range.CrouchRate = 1.1
                range.ProneRate = 1.0
                range.DyingRate = 0.0
            end
            tune(ent.AutoAimingConfig.OuterRange)
            tune(ent.AutoAimingConfig.InnerRange)
            if Polo.CONFIG.AutoHead then
                ent.AutoAimingConfig.Bones = { "Head", "Head" }
            end
        end
    end)
end

-- ============================ AIMTOUCH ============================
local function isShotgunWeapon(wid, wname)
    if wid and wid >= 1030000 and wid < 1040000 then
        if wname and (wname:find("S686") or wname:find("S1897") or wname:find("S12")
            or wname:find("DBS") or wname:find("M1014")) then return true end
    end
    return false
end

local function isSniperWeapon(wname)
    if not wname then return false end
    return wname:find("Kar98") or wname:find("M24") or wname:find("AWM") or wname:find("Mosin")
        or wname:find("Win94") or wname:find("AMR") or wname:find("SKS") or wname:find("SLR")
        or wname:find("Mini") or wname:find("Mk14") or wname:find("QBU") or wname:find("Mk12")
        or wname:find("VSS")
end

Polo.GetEnemyTargets = function(maxDist)
    local list = {}
    local selfPc = getPlayerChar()
    if not slua.isValid(selfPc) then return list end
    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"]
        or require("GameLua.GameCore.Data.GameplayData")
    local chars = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
    local selfTeam = selfPc:GetTeamID()
    for _, c in pairs(chars) do
        if slua.isValid(c) and c ~= selfPc and c:IsAlive() and c:GetTeamID() ~= selfTeam then
            local d = selfPc:GetDistanceTo(c)
            if d <= maxDist then table.insert(list, c) end
        end
    end
    return list
end

Polo.AimTouch = function()
    if not Polo.CONFIG.AimTouchEnable then return end
    pcall(function()
        local pc = getPlayerChar()
        if not slua.isValid(pc) then return end
        local pctrl = pc:GetPlayerControllerSafety()
        if not slua.isValid(pctrl) then return end
        local isFiring = pc.bIsWeaponFiring or false
        local wmc = pc.WeaponManagerComponent
        local weapon = wmc and wmc.CurrentWeaponReplicated
        if not slua.isValid(weapon) and type(pc.GetCurrentShootWeapon) == "function" then
            weapon = pc:GetCurrentShootWeapon()
        end
        local wid = 0
        local wname = ""
        if slua.isValid(weapon) then
            if type(weapon.GetWeaponID) == "function" then wid = weapon:GetWeaponID() or 0 end
            if type(weapon.GetWeaponName) == "function" then wname = weapon:GetWeaponName() or "" end
        end
        local isSG = isShotgunWeapon(wid, wname)
        local isSniper = isSniperWeapon(wname)

        -- SCOPE GLITCH FIX: scoped (ADS) rahte waqt control-rotation likhna game ki
        -- scope/ADS se fight karta hai -> scope fast on/off flicker. Isliye scoped
        -- hone par aim-assist rotation chhodd dete hain (hip-fire mode hi rotation use karta hai).
        if pc.bIsGunADS then return end

        -- mode params
        local speed, fov, maxDist, boneName
        local hipMode = false
        local sgMode = false
        if isSG and Polo.CONFIG.AimTouchSG then
            sgMode = true
            speed = Polo.CTX.AimTouchSGSpeed or 80
            fov = Polo.CTX.AimTouchSGFOV or 40
            maxDist = (Polo.CTX.AimTouchSGDist or 30) * 100
            boneName = "pelvis"
        elseif pc.bIsGunADS then
            if isSniper and Polo.CONFIG.AimTouchScopeSniper then
                speed = Polo.CTX.AimTouchSniperSpeed or 30
                fov = Polo.CTX.AimTouchSniperFOV or 20
                maxDist = (Polo.CTX.AimTouchSniperDist or 400) * 100
                boneName = "head"
            elseif Polo.CONFIG.AimTouchScopeAll then
                speed = Polo.CTX.AimTouchScopeSpeed or 40
                fov = Polo.CTX.AimTouchScopeFOV or 20
                maxDist = (Polo.CTX.AimTouchScopeDist or 300) * 100
                boneName = "pelvis"
            else
                return
            end
        elseif Polo.CONFIG.AimTouchHipfire then
            hipMode = true
            speed = Polo.CTX.AimTouchHipSpeed or 50
            fov = Polo.CTX.AimTouchHipFOV or 30
            maxDist = (Polo.CTX.AimTouchHipDist or 250) * 100
            boneName = "head"
        else
            return
        end

        local ui_util = require("client.common.ui_util")
        if not ui_util then return end
        local viewport = ui_util.GetViewportSize()
        if not viewport then return end

        local targets = Polo.GetEnemyTargets(maxDist)
        if not targets or #targets == 0 then return end

        local camMgr = import("GameplayStatics").GetPlayerCameraManager(pctrl, 0)
        if not slua.isValid(camMgr) then return end
        local camLoc = camMgr:GetCameraLocation()
        if not camLoc then return end

        local bestTarget, bestBonePos, bestScore
        for _, t in ipairs(targets) do
            local skip = false
            if slua.isValid(t) then
                if Polo.CONFIG.AimTouchHipIgKnock then
                    if t.HealthStatus and t.HealthStatus == 1 then skip = true end
                end
                if (not skip) and Polo.CONFIG.AimTouchHipIgBot then
                    if enemyIsBot(t) then skip = true end
                end
                if (not skip) then
                    local bonePos = getBoneWorldPos(t, boneName)
                    if bonePos then
                        if Polo.CONFIG.AimTouchHipVisCheck then
                            local vis = false
                            pcall(function() vis = pctrl:LineOfSightTo(t) end)
                            if not vis then skip = true end
                        end
                        if (not skip) then
                            local screen = { X = 0, Y = 0 }
                            local ok = pcall(function()
                                return pctrl:ProjectWorldLocationToScreen(bonePos, screen, false)
                            end)
                            if ok and screen then
                                local cx = viewport.X * 0.5
                                local cy = viewport.Y * 0.5
                                local score = math.sqrt(((screen.X - cx) * (screen.X - cx)) + ((screen.Y - cy) * (screen.Y - cy)))
                                local fovLimit = ((fov or 30) / 100.0) * (viewport.X / 2.0)
                                if score <= fovLimit then
                                    if not bestScore or score < bestScore then
                                        bestScore = score
                                        bestTarget = t
                                        bestBonePos = bonePos
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if not bestTarget or not bestBonePos then
            if sgMode and Polo.CONFIG.AimTouchSGAutoFire then
                pcall(function()
                    pc.bIsWeaponFiring = false
                    if type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                    if wmc then wmc.bIsWeaponFiring = false end
                end)
            end
            return
        end

        local lookRot = import("KismetMathLibrary").FindLookAtRotation(camLoc, bestBonePos)
        if not lookRot then return end
        local cur = pctrl:GetControlRotation()
        if not cur then return end
        local spd = (speed or 50) / 100.0
        local alpha = spd * 0.3
        local newPitch = cur.Pitch + ((lookRot.Pitch - cur.Pitch) * alpha)
        local newYaw = cur.Yaw + ((lookRot.Yaw - cur.Yaw) * alpha)
        local newRoll = cur.Roll or 0
        pctrl:SetControlRotation({ Pitch = newPitch, Yaw = newYaw, Roll = newRoll }, "AimTouch")

        if sgMode and Polo.CONFIG.AimTouchSGAutoFire then
            local dist = pc:GetDistanceTo(bestTarget) / 100
            if dist <= (Polo.CTX.AimTouchSGDist or 30) then
                pcall(function()
                    pc.bIsWeaponFiring = true
                    if type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(true) end
                    if wmc then wmc.bIsWeaponFiring = true end
                    if type(pc.GetCurrentWeapon) == "function" then
                        local w = pc:GetCurrentWeapon()
                        if slua.isValid(w) and type(w.StartFire) == "function" then w:StartFire() end
                    end
                end)
            else
                pcall(function()
                    pc.bIsWeaponFiring = false
                    if type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                    if wmc then wmc.bIsWeaponFiring = false end
                end)
            end
        end
    end)
end

-- ============================ ESP EXTRAS ============================
Polo.SkeletonBones = {
    { "neck_01", "pelvis" }, { "neck_01", "upperarm_l" }, { "upperarm_l", "lowerarm_l" },
    { "lowerarm_l", "hand_l" }, { "neck_01", "upperarm_r" }, { "upperarm_r", "lowerarm_r" },
    { "lowerarm_r", "hand_r" }, { "pelvis", "thigh_l" }, { "thigh_l", "calf_l" },
    { "calf_l", "foot_l" }, { "pelvis", "thigh_r" }, { "thigh_r", "calf_r" },
}

Polo.ESP_Enemy = function(enemy, localPlayer, pc, hud)
    pcall(function()
        if not hud and pc then
            pcall(function() hud = pc:GetHUD() end)
        end
        if not slua.isValid(hud) then return end
        local dist = localPlayer:GetDistanceTo(enemy) / 100
        local actorLoc = enemy.K2_GetActorLocation and enemy:K2_GetActorLocation()
        if not actorLoc then return end
        local mesh = enemy.Mesh

        -- Skeleton / bone ESP (EspLoai6)
        if Polo.CONFIG.EspLoai6 and dist <= 100 then
            local boneMap = {}
            local okAll = true
            for _, b in ipairs({ "head", "neck_01", "pelvis", "upperarm_l", "lowerarm_l", "hand_l",
                "upperarm_r", "lowerarm_r", "hand_r", "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r" }) do
                local p = nil
                pcall(function()
                    if mesh and type(mesh.GetSocketLocation) == "function" then
                        p = mesh:GetSocketLocation(b)
                    end
                    if (not p or (p.X == 0 and p.Y == 0 and p.Z == 0)) and type(enemy.GetBonePos) == "function" then
                        local o = { X = 0, Y = 0, Z = 0 }
                        local r = enemy:GetBonePos(b, o)
                        p = r or o
                    end
                end)
                if p and p.X and not (p.X == 0 and p.Y == 0 and p.Z == 0) then
                    boneMap[b] = { X = p.X - actorLoc.X, Y = p.Y - actorLoc.Y, Z = p.Z - actorLoc.Z }
                else
                    okAll = false
                end
            end
            if okAll and slua.isValid(hud) and type(hud.AddDebugText) == "function" then
                local col = { R = 255, G = 0, B = 0, A = 255 }
                for _, pair in ipairs(Polo.SkeletonBones) do
                    local a = boneMap[pair[1]]
                    local b = boneMap[pair[2]]
                    if a and b then
                        for step = 1, 2 do
                            local t = step / 3
                            local mid = { X = a.X + ((b.X - a.X) * t), Y = a.Y + ((b.Y - a.Y) * t), Z = a.Z + ((b.Z - a.Z) * t) }
                            hud:AddDebugText("|", enemy, 2.0, mid, mid, col, true, false, true, nil, 0.35, true)
                        end
                    end
                end
            end
        end

        -- VIP / VipPro ESP: name + knock + health bar + %% (EspVipPro)
        if Polo.CONFIG.EspVipPro and dist <= 400 then
            pcall(function()
                local name = "Enemy"
                if enemy.PlayerName then name = enemy.PlayerName
                elseif type(enemy.GetPlayerName) == "function" then name = enemy:GetPlayerName() or "Enemy"
                end
                local hp = enemy.Health
                if (not hp or hp == 0) and type(enemy.GetHealth) == "function" then hp = enemy:GetHealth() end
                local hpMax = enemy.HealthMax
                if (not hpMax or hpMax == 0) and type(enemy.GetHealthMax) == "function" then hpMax = enemy:GetHealthMax() end
                if slua.isValid(hud) and type(hud.AddDebugText) == "function" then
                    local isKnocked = enemy.HealthStatus and enemy.HealthStatus == 1
                    local offName = { X = 0, Y = 0, Z = -370 }
                    local col = { R = 255, G = 80, B = 80, A = 255 }
                    hud:AddDebugText(isKnocked and ("KNOCK: " .. name) or name, enemy, 2.0, offName, offName, col, true, false, true, nil, 1.0, true)
                    if hp and hpMax and hpMax > 0 then
                        local pct = hp / hpMax
                        local offH = { X = 0, Y = 0, Z = -115 }
                        if isKnocked then
                            hud:AddDebugText("DOWN", enemy, 2.0, offH, offH, { R = 255, G = 80, B = 0, A = 255 }, true, false, true, nil, 0.9, true)
                        else
                            local segs = math.max(1, math.floor((pct * 6) + 0.5))
                            hud:AddDebugText(string.rep("|", segs), enemy, 2.0, offH, offH, { R = 80, G = 255, B = 80, A = 255 }, true, false, true, nil, 0.9, true)
                            local offPct = { X = 0, Y = 0, Z = -60 }
                            hud:AddDebugText(string.format("%d%%", math.floor(pct * 100)), enemy, 2.0, offPct, offPct, col, true, false, true, nil, 0.8, true)
                        end
                    end
                end
            end)
        end

        -- Pose + weapon label + REAL/BOT (EspLoai7)
        if Polo.CONFIG.EspLoai7 and dist <= 400 then
            pcall(function()
                if slua.isValid(hud) and type(hud.AddDebugText) == "function" then
                    local pose = "Stand"
                    if enemy.PoseState then
                        pose = enemy.PoseState
                    elseif type(enemy.GetPoseState) == "function" then
                        local ps = enemy:GetPoseState()
                        if ps == 1 then pose = "Crouch"
                        elseif ps == 2 then pose = "Prone"
                        else pose = "Stand"
                        end
                    end
                    local wep = "Weapon"
                    local wm = enemy.WeaponManagerComponent
                    local cw = wm and wm.CurrentWeaponReplicated
                    if cw and type(cw.GetWeaponName) == "function" then wep = cw:GetWeaponName() or wep end
                    local isBot = enemyIsBot(enemy)
                    local label = (isBot and "BOT" or "REAL") .. " | " .. pose .. " - " .. wep
                    local col = isBot and { R = 255, G = 255, B = 0, A = 255 } or { R = 0, G = 255, B = 0, A = 255 }
                    local off = { X = 0, Y = 0, Z = -160 }
                    hud:AddDebugText(label, enemy, 2.0, off, off, col, true, false, true, nil, 0.8, true)
                end
            end)
        end

        -- Radar map mark (EspRadar)
        if Polo.CONFIG.EspRadar and type(enemy.GetHeadLocation) == "function" then
            pcall(function()
                local now = os.clock()
                if (Polo.LastRadarUpdate or 0) + 0.5 > now then return end
                Polo.LastRadarUpdate = now
                local head = enemy:GetHeadLocation(false)
                if not head then return end
                local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
                if not InGameMarkTools then return end
                if Polo.radarMark and type(InGameMarkTools.HideMapMark) == "function" then
                    InGameMarkTools.HideMapMark(Polo.radarMark)
                end
                if type(InGameMarkTools.ClientAddMapMark) == "function" then
                    Polo.radarMark = InGameMarkTools.ClientAddMapMark(1003, head, 0, "", 4, nil)
                end
            end)
        end
    end)
end

-- ============================ 165 FPS ============================
Polo.Enable165FPS = function()
    pcall(function()
        local gfxInst = require("client.slua.logic.setting.logic_setting_graphics").GetGameInstance()
        if not gfxInst then return end
        if type(gfxInst.ExecuteCMD) == "function" then
            gfxInst:ExecuteCMD("r.MaxFPS", "165")
            gfxInst:ExecuteCMD("t.MaxFPS", "165")
        end
    end)
end

-- ============================ KILL COUNTER ============================
Polo.KillCounterApplied = false
Polo.EnableKillCounter = function()
    if Polo.KillCounterApplied then return end
    pcall(function()
        local mod = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
            or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if mod and type(mod.CheckNeedMainKillCounterUI) == "function" then
            local orig = mod.CheckNeedMainKillCounterUI
            mod.CheckNeedMainKillCounterUI = function(self, ...)
                return true, 1
            end
            local upd = mod.UpdateMainKillCounterUI
            if upd then
                mod.UpdateMainKillCounterUI = function(self, show, ...)
                    if show == false then show = true end
                    return upd(self, show, ...)
                end
            end
            Polo.KillCounterApplied = true
        end
    end)
end

-- ============================ SKIN SYSTEM ============================
Polo.skinIdMappings = {
    [101004] = { 101004, 1101004246, 1101004226, 1101004236, 1101004062, 1101004078, 1101004086, 1101004201 },
    [101001] = { 101001, 1101001276, 1101001089, 1101001213, 1101001172, 1101001127, 1101001230 },
    [101003] = { 101003, 1101003227, 1103003208, 1101003195, 1101003187, 1101003098, 1101003166 },
    [102002] = { 102002, 1102002136, 1102002043, 1102002061 },
    [101008] = { 101008, 1101008146, 1101008154, 1101008079, 1101008126, 1101008104, 1101008061 },
    [101006] = { 101006, 1101006085, 1101006061, 1101006074, 1101006043, 1101006032 },
    [102001] = { 102001 },
    [101005] = { 101005 },
    [104003] = { 104003 },
    [104004] = { 104004, 1104004035 },
}
Polo.WeaponSkinMap = {}
Polo.VehicleSkinMap = {}
Polo.OutfitMap = {}
Polo.skinIdCache = {}
Polo.skinIdCache2 = {}
Polo.LastAppliedPet = nil
Polo.LastVehicleEntity = nil
Polo.LastRadarUpdate = 0
Polo.radarMark = nil

Polo.VIP_Attachments = { [1101004236] = { 1010042307, 1010042306, 1010042308, 1010042304, 1010042300, 1010042305, 1010042299, 1010042298, 1010042297, 1010042296, 1010042295, 1010042294, 0, 1010042314, 1010042309, 1010042316, 1010042317, 1010042318, 1010042310, 1010042315, 1010042319 }, [1101001116] = { 1010011106, 1010011107, 1010011108, 0, 1010011109, 1010011112, 1010011105, 1010011104, 1010011103, 0, 1010011102, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, [1101001128] = { 1010011232, 1010011233, 1010011234, 1010011228, 1010011227, 1010011229, 1010011226, 1010011225, 1010011224, 1010011223, 1010011222, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, [1101001154] = { 1010011487, 1010011488, 1010011489, 1010011493, 1010011490, 1010011494, 1010011486, 1010011485, 1010011484, 1010011483, 1010011482, 1010011497, 0, 0, 0, 0, 0, 0, 0, 0, 1010011498 }, [1101001174] = { 1010011667, 1010011668, 1010011669, 1010011673, 1010011670, 1010011674, 1010011666, 1010011665, 1010011664, 1010011663, 1010011662, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, [1101001213] = { 1010012067, 1010012068, 1010012069, 1010012072, 1010012070, 1010012073, 1010012066, 1010012065, 1010012064, 1010012063, 1010012062, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1010012074 }, [1101001231] = { 1010012267, 1010012268, 1010012269, 1010012273, 1010012272, 1010012274, 1010012266, 1010012265, 1010012264, 1010012263, 1010012262, 1010012075, 0, 0, 0, 0, 0, 0, 0, 0, 1010012275 }, [1101001242] = { 1010012357, 1010012358, 1010012359, 1010012363, 1010012362, 1010012364, 1010012356, 1010012355, 1010012354, 1010012353, 1010012352, 1010012276, 0, 0, 0, 0, 0, 0, 0, 0, 1010012365 }, [1101001249] = { 1010012437, 1010012438, 1010012439, 1010012443, 1010012442, 1010012444, 1010012436, 1010012435, 1010012434, 1010012433, 1010012432, 1010012366, 0, 0, 0, 0, 0, 0, 0, 0, 1010012445 }, [1101001256] = { 1010012588, 1010012589, 1010012590, 1010012593, 1010012592, 1010012594, 1010012587, 1010012586, 1010012585, 1010012584, 1010012583, 1010012582, 0, 0, 0, 0, 0, 0, 0, 0, 1010012595 }, [1101001265] = { 1010012698, 1010012699, 1010012700, 1010012703, 1010012702, 1010012704, 1010012697, 1010012696, 1010012695, 1010012694, 1010012693, 1010012692, 0, 0, 0, 0, 0, 0, 0, 0, 1010012705 }, [1101001276] = { 1010012698, 1010012699, 1010012700, 1010012703, 1010012702, 1010012704, 1010012697, 1010012696, 1010012695, 1010012694, 1010012693, 1010012692, 0, 0, 0, 0, 0, 0, 0, 0, 1010012705 }, [1101002029] = { 1010020249, 1010020250, 1010020255, 1010020247, 1010020246, 1010020248, 1010020240, 1010020239, 1010020238, 1010020237, 1010020236, 1010020235, 0, 0, 0, 0, 0, 0, 0, 1010020257, 1010020256 }, [1101002056] = { 1010020519, 0, 0, 1010020517, 1010020516, 1010020518, 1010020500, 1010020509, 1010020508, 1010020507, 1010020506, 1010020505, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, [1101002081] = { 1010020768, 1010020769, 1010020770, 1010020766, 1010020760, 1010020767, 1010020759, 1010020758, 1010020757, 1010020756, 1010020755, 1010020776, 0, 0, 0, 0, 0, 0, 0, 1010020775, 1010020777 }, [1101003070] = { 1010030654, 1010030653, 1010030655, 1010030649, 1010030648, 1010030650, 1010030647, 1010030646, 1010030645, 1010030644, 1010030643, 1010030642, 0, 1010030658, 1010030656, 1010030660, 1010030662, 1010030659, 1010030657, 0, 1010030663 }, [1101003080] = { 1010030754, 1010030753, 1010030755, 1010030749, 1010030748, 1010030750, 1010030747, 1010030746, 1010030745, 1010030744, 1010030743, 1010030742, 0, 1010030758, 1010030756, 1010030760, 1010030762, 1010030759, 1010030757, 0, 1010030763 }, [1101003099] = { 1010030943, 1010030944, 1010030945, 1010030939, 1010030938, 1010030942, 1010030937, 1010030936, 1010030935, 1010030934, 1010030933, 1010030932, 0, 1010030947, 1010030946, 1010030948, 1010030949, 1010030953, 1010030952, 0, 1010030955 }, [1101003119] = { 1010031139, 1010031140, 1010031142, 1010031138, 1010031137, 1010031146, 1010031136, 1010031135, 1010031134, 1010031133, 1010031132, 0, 0, 1010031144, 1010031143, 0, 0, 0, 1010031145, 0, 0 }, [1101003146] = { 1010031229, 1010031230, 1010031237, 1010031228, 1010031227, 1010031242, 1010031226, 1010031225, 1010031224, 1010031223, 1010031222, 0, 0, 1010031239, 1010031238, 0, 0, 0, 1010031240, 0, 0 }, [1101003167] = { 1010031609, 1010031610, 1010031613, 1010031608, 1010031607, 1010031617, 1010031606, 1010031605, 1010031604, 1010031603, 1010031602, 1010031618, 0, 1010031615, 1010031614, 1010031620, 1010031622, 1010031619, 1010031616, 0, 1010031623 }, [1101003181] = { 1010031765, 1010031764, 1010031766, 1010031759, 1010031758, 1010031763, 1010031757, 1010031756, 1010031755, 1010031754, 1010031753, 1010031752, 0, 1010031769, 1010031767, 1010031773, 1010031774, 1010031772, 1010031768, 0, 1010031775 }, [1101003195] = { 1010031912, 1010031911, 1010031913, 1010031908, 1010031907, 1010031909, 1010031906, 1010031905, 1010031904, 1010031903, 1010031902, 1010031901, 0, 1010031916, 1010031914, 1010031918, 1010031919, 1010031917, 1010031915, 0, 1010031921 }, [1101003208] = { 1010032034, 1010032033, 1010032045, 1010032029, 1010032028, 1010032032, 1010032027, 1010032026, 1010032025, 1010032024, 1010032023, 1010032022, 0, 1010032038, 1010032036, 1010032042, 1010032043, 1010032039, 1010032037, 0, 1010032044 }, [1101004046] = { 1010040474, 1010040475, 1010040476, 1010040472, 1010040471, 1010040473, 1010040470, 1010040469, 1010040468, 1010040467, 1010040466, 1010040481, 0, 1010040479, 1010040477, 1010040482, 1010040483, 1010040484, 1010040478, 1010040480, 1010040485 }, [1101004062] = { 1010040578, 1010040577, 1010040579, 1010040575, 1010040570, 1010040576, 1010040569, 1010040568, 1010040567, 1010040566, 1010040565, 1010040564, 0, 1010040585, 1010040580, 1010040587, 1010040588, 1010040589, 1010040584, 1010040586, 1010040590 }, [1101004098] = { 1010040924, 1010040926, 1010040925, 0, 1010040937, 1010040938, 1010040935, 1010040934, 1010040929, 1010040928, 1010040927, 0, 0, 1010040939, 1010040945, 0, 0, 0, 1010040944, 1010040936, 0 }, [1101004138] = { 1010041136, 1010041137, 1010041138, 1010041134, 1010041129, 1010041135, 1010041128, 1010041127, 1010041126, 1010041125, 1010041124, 0, 0, 1010041145, 1010041139, 0, 0, 0, 1010041144, 1010041146, 0 }, [1101004163] = { 1010041570, 1010041574, 1010041575, 1010041568, 1010041567, 1010041569, 1010041566, 1010041565, 1010041564, 1010041560, 1010041554, 0, 0, 1010041578, 1010041576, 0, 0, 0, 1010041577, 1010041579, 0 }, [1101004201] = { 1010041956, 1010041957, 1010041958, 1010041950, 1010041949, 1010041955, 1010041948, 1010041947, 1010041946, 1010041945, 1010041944, 1010041967, 0, 1010041965, 1010041959, 0, 0, 0, 1010041960, 1010041966, 0 }, [1101004209] = { 1010042038, 1010042037, 1010042039, 1010042035, 1010042034, 1010042036, 1010042029, 1010042028, 1010042027, 1010042026, 1010042025, 1010042024, 0, 1010042046, 1010042044, 1010042048, 1010042049, 1010042054, 1010042045, 1010042047, 1010042055 }, [1101004218] = { 1010042128, 1010042127, 1010042129, 1010042125, 1010042124, 1010042126, 1010042119, 1010042118, 1010042117, 1010042116, 1010042115, 1010042114, 0, 1010042136, 1010042134, 1010042138, 1010042139, 1010042144, 1010042135, 1010042137, 1010042145 }, [1101004226] = { 1010042238, 1010042237, 1010042239, 1010042235, 1010042234, 1010042236, 1010042233, 1010042232, 1010042231, 1010042219, 1010042218, 1010042217, 0, 1010042243, 1010042241, 1010042245, 1010042246, 1010042247, 1010042242, 1010042244, 1010042248 }, [1101004246] = { 1010042406, 1010042407, 1010042408, 1010042404, 1010042400, 1010042405, 1010042399, 1010042398, 1010042397, 1010042396, 1010042395, 1010042394, 0, 1010042414, 1010042409, 1010042416, 1010042417, 1010042418, 1010042410, 1010042415, 1010042419 }, [1101005038] = { 0, 0, 1010050327, 1010050329, 1010050328, 1010050330, 1010050326, 1010050325, 1010050324, 1010050323, 1010050322, 1010050334, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, [1101005052] = { 0, 0, 1010050467, 1010050469, 1010050468, 1010050470, 1010050466, 1010050465, 1010050464, 1010050463, 1010050462, 1010050473, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, [1101005098] = { 0, 0, 1010050928, 1010050930, 1010050929, 1010050932, 1010050927, 1010050926, 1010050925, 1010050924, 1010050923, 1010050922, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, [1101006062] = { 1010060573, 1010060572, 1010060574, 1010060564, 1010060563, 1010060571, 1010060562, 1010060561, 1010060554, 1010060553, 1010060552, 1010060551, 0, 1010060583, 1010060581, 1010060591, 1010060592, 1010060584, 1010060582, 0, 1010060593 }, [1101006075] = { 1010060702, 1010060701, 1010060703, 1010060698, 1010060697, 1010060699, 1010060696, 1010060695, 1010060694, 1010060693, 1010060692, 1010060691, 0, 1010060706, 1010060704, 1010060708, 1010060709, 1010060707, 1010060705, 0, 1010060711 }, [1101006085] = { 1010060796, 1010060795, 1010060797, 1010060793, 1010060789, 1010060794, 1010060788, 1010060787, 1010060786, 1010060785, 1010060784, 1010060783, 0, 1010060800, 1010060798, 1010060804, 1010060805, 1010060803, 1010060799, 0, 1010060806 }, [1101007046] = { 1010070410, 1010070413, 1010070414, 1010070408, 1010070407, 1010070409, 1010070406, 1010070405, 1010070404, 1010070403, 1010070402, 1010070418, 0, 1010070417, 1010070415, 1010070420, 1010070422, 1010070419, 1010070416, 0, 1010070423 }, [1101007062] = { 1010070579, 1010070578, 1010070581, 1010070576, 1010070575, 1010070577, 1010070574, 1010070573, 1010070572, 1010070571, 1010070569, 1010070568, 0, 1010070584, 1010070582, 1010070585, 1010070586, 1010070587, 1010070583, 0, 1010070588 }, [1101007071] = { 1010070663, 1010070662, 1010070664, 1010070659, 1010070658, 1010070660, 1010070657, 1010070656, 1010070655, 1010070654, 1010070653, 1010070652, 0, 1010070667, 1010070665, 1010070668, 1010070669, 1010070670, 1010070666, 0, 1010070672 }, [1101008051] = { 1010080463, 1010080464, 1010080465, 1010080459, 1010080458, 1010080462, 1010080457, 1010080456, 1010080455, 1010080454, 1010080453, 1010080452, 0, 1010080467, 1010080466, 1010080468, 1010080469, 1010080473, 1010080472, 0, 1010080475 }, [1101008061] = { 1010080563, 1010080564, 1010080565, 1010080559, 1010080558, 1010080562, 1010080557, 1010080556, 1010080555, 1010080554, 1010080553, 0, 0, 1010080567, 1010080566, 0, 0, 0, 1010080572, 0, 0 }, [1101008070] = { 1010080609, 1010080612, 1010080613, 1010080608, 1010080607, 1010080617, 1010080606, 1010080605, 1010080604, 1010080603, 1010080602, 0, 0, 1010080615, 1010080614, 0, 0, 0, 1010080616, 0, 0 }, [1101008081] = { 1010080740, 1010080743, 1010080745, 1010080738, 1010080737, 1010080739, 1010080736, 1010080735, 1010080734, 1010080733, 1010080732, 1010080748, 0, 1010080747, 1010080746, 1010080750, 1010080752, 1010080749, 1010080744, 0, 1010080753 }, [1101008104] = { 1010080980, 1010080982, 1010080984, 1010080978, 1010080977, 1010080979, 1010080976, 1010080975, 1010080974, 1010080973, 1010080972, 1010080992, 0, 1010080986, 1010080985, 1010080989, 1010080987, 1010080993, 1010080983, 0, 1010080988 }, [1101008116] = { 1010081110, 1010081112, 1010081114, 1010081108, 1010081107, 1010081109, 1010081106, 1010081105, 1010081104, 1010081103, 1010081102, 0, 0, 1010081116, 1010081115, 0, 0, 0, 1010081113, 0, 0 }, [1101008126] = { 1010081210, 1010081225, 1010081226, 1010081208, 1010081207, 1010081209, 1010081206, 1010081205, 1010081204, 1010081203, 1010081202, 1010081218, 0, 1010081217, 1010081216, 1010081219, 1010081220, 1010081222, 1010081214, 1010081228, 1010081227 }, [1101008136] = { 1010081314, 1010081315, 1010081316, 1010081312, 1010081308, 1010081313, 1010081307, 1010081306, 1010081305, 1010081304, 1010081303, 1010081302, 0, 1010081318, 1010081317, 1010081322, 1010081323, 1010081325, 1010081324, 0, 1010081326 }, [1101008146] = { 1010081401, 1010081402, 1010081403, 1010081398, 1010081397, 1010081399, 1010081396, 1010081395, 1010081394, 1010081393, 1010081392, 1010081391, 0, 1010081405, 1010081404, 1010081406, 1010081407, 1010081409, 1010081408, 0, 1010081411 }, [1101008154] = { 1010081531, 1010081532, 1010081533, 1010081528, 1010081527, 1010081529, 1010081526, 1010081525, 1010081524, 1010081523, 1010081522, 1010081521, 0, 1010081541, 1010081534, 1010081542, 1010081543, 1010081545, 1010081544, 0, 1010081546 }, [1101008163] = { 1010081582, 1010081583, 1010081584, 1010081579, 1010081578, 1010081580, 1010081577, 1010081576, 1010081575, 1010081574, 1010081573, 1010081572, 0, 1010081586, 1010081585, 1010081587, 1010081588, 1010081590, 1010081589, 0, 1010081592 }, [1101012033] = { 1010120284, 1010120285, 1010120286, 1010120280, 1010120279, 1010120283, 1010120278, 1010120277, 1010120276, 1010120275, 1010120274, 1010120273, 0, 0, 0, 0, 0, 0, 0, 0, 1010120287 }, [1101100012] = { 1011000066, 1011000067, 1011000068, 0, 0, 0, 1011000058, 1011000057, 1011000056, 1011000055, 1011000054, 1011000053, 0, 0, 0, 0, 0, 0, 0, 0, 1011000073 }, [1101102007] = { 1011010025, 1011010024, 1011010026, 1011010020, 1011010019, 1011010023, 1011010018, 1011010017, 1011010016, 1011010015, 1011010014, 1011010013, 0, 0, 0, 0, 0, 0, 0, 0, 1011010027 }, [1101102017] = { 1011020027, 1011020028, 1011020029, 1011020025, 1011020024, 1011020026, 1011020019, 1011020018, 1011020017, 1011020016, 1011020015, 1011020014, 0, 1011020036, 1011020034, 1011020038, 1011020039, 1011020044, 1011020035, 1011020037, 1011020045 }, [1101102025] = { 1011020127, 1011020128, 1011020129, 1011020125, 1011020124, 1011020126, 1011020119, 1011020118, 1011020117, 1011020116, 1011020115, 1011020114, 0, 1011020136, 1011020134, 1011020138, 1011020139, 1011020144, 1011020135, 1011020137, 1011020145 }, [1101102041] = { 1011020214, 1011020215, 1011020216, 1011020212, 1011020211, 1011020213, 1011020209, 1011020208, 1011020207, 1011020206, 1011020205, 1011020204, 0, 1011020219, 1011020217, 1011020222, 1011020223, 1011020224, 1011020218, 1011020221, 1011020225 }, [1101102049] = { 1011020356, 1011020357, 1011020358, 1011020354, 1011020350, 1011020355, 1011020349, 1011020348, 1011020347, 1011020346, 1011020345, 1011020344, 0, 1011020364, 1011020359, 1011020366, 1011020367, 1011020368, 1011020360, 1011020365, 1011020369 }, [1101101007] = { 1011020436, 1011020437, 1011020438, 1011020434, 1011020430, 1011020435, 1011020429, 1011020428, 1011020427, 1011020426, 1011020425, 1011020424, 0, 1011020444, 1011020439, 1011020446, 1011020447, 1011020448, 1011020440, 1011020445, 1011020449 }, [1102001120] = { 1020011137, 1020011138, 1020011139, 1020011135, 1020011134, 1020011136, 1020011133, 1020011132, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1020011142, 0 }, [1102001130] = { 1020011247, 1020011248, 1020011249, 1020011245, 1020011244, 1020011246, 1020011243, 1020011242, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1020011250, 0 }, [1102002043] = { 1020020372, 1020020374, 1020020373, 1020020383, 1020020380, 1020020384, 1020020379, 1020020378, 1020020377, 1020020376, 1020020375, 1020020388, 0, 1020020385, 1020020387, 0, 0, 0, 1020020386, 0, 0 }, [1102002061] = { 1020020552, 1020020554, 1020020553, 1020020563, 1020020562, 1020020564, 1020020559, 1020020558, 1020020557, 1020020556, 1020020555, 1020020578, 0, 1020020565, 1020020567, 1020020573, 1020020574, 1020020572, 1020020566, 0, 1020020569 }, [1102002136] = { 1020021314, 1020021313, 1020021315, 1020021309, 1020021308, 1020021312, 1020021307, 1020021306, 1020021305, 1020021304, 1020021303, 1020021302, 0, 1020021318, 1020021316, 1020021323, 1020021324, 1020021322, 1020021317, 0, 1020021325 }, [1102002424] = { 1020024193, 1020024192, 1020024194, 1020024189, 1020024188, 1020024190, 1020024187, 1020024186, 1020024185, 1020024184, 1020024183, 1020024182, 0, 1020024197, 1020024195, 1020024199, 1020024200, 1020024198, 1020024196, 0, 1020024202 }, [1102003080] = { 1020030755, 1020030756, 1020030758, 0, 1020030749, 1020030754, 1020030748, 1020030747, 1020030746, 1020030745, 1020030744, 1020030764, 0, 1020030760, 0, 1020030759, 1020030757, 0, 0, 1020030765, 0 }, [1102003100] = { 1020030956, 1020030957, 1020030958, 1020030954, 1020030950, 1020030955, 1020030949, 1020030948, 1020030947, 1020030946, 1020030945, 1020030944, 0, 1020030964, 0, 1020030960, 1020030959, 1020030965, 0, 1020030967, 1020030966 }, [1102005064] = { 1020050588, 1020050589, 1020050590, 0, 0, 0, 1020050587, 1020050586, 1020050585, 1020050584, 1020050583, 1020050582, 0, 0, 0, 0, 0, 0, 0, 0, 1020050592 }, [1103001101] = { 1030010954, 1030010955, 1030010956, 0, 0, 0, 0, 0, 0, 0, 1030010953, 1030010952, 1030010951, 0, 0, 0, 0, 0, 0, 1030010957, 0 }, [1103001146] = { 1030011344, 1030011345, 1030011346, 0, 0, 0, 0, 0, 0, 0, 1030011343, 1030011342, 1030011341, 0, 0, 0, 0, 0, 0, 1030011347, 0 }, [1103001154] = { 1030011484, 1030011485, 1030011486, 0, 0, 0, 0, 0, 0, 0, 1030011483, 1030011482, 1030011481, 0, 0, 0, 0, 0, 0, 1030011487, 0 }, [1103001179] = { 1030011738, 1030011739, 1030011741, 0, 0, 0, 1030011737, 1030011736, 1030011735, 1030011734, 1030011733, 1030011732, 1030011731, 0, 0, 0, 0, 0, 0, 1030011742, 1030011743 }, [1103001191] = { 1030011858, 1030011859, 1030011861, 0, 0, 0, 1030011857, 1030011856, 1030011855, 1030011854, 1030011853, 1030011852, 1030011851, 0, 0, 0, 0, 0, 0, 1030011862, 1030011863 }, [1103001202] = { 1030011948, 1030011949, 1030011950, 0, 0, 0, 1030011947, 1030011946, 1030011945, 1030011944, 1030011943, 1030011942, 1030011941, 0, 0, 0, 0, 0, 0, 1030011951, 1030011952 }, [1103002030] = { 1030020245, 1030020246, 1030020247, 1030020252, 1030020249, 1030020253, 1030020258, 1030020257, 1030020256, 1030020255, 1030020244, 1030020243, 1030020242, 0, 0, 0, 0, 0, 0, 1030020248, 0 }, [1103002059] = { 1030020544, 1030020545, 1030020546, 1030020542, 1030020539, 1030020543, 1030020538, 1030020537, 1030020536, 1030020535, 1030020534, 1030020533, 1030020532, 0, 0, 0, 0, 0, 0, 1030020547, 1030020548 }, [1103002087] = { 1030020824, 1030020825, 1030020826, 0, 0, 0, 1030020818, 1030020817, 1030020816, 1030020815, 1030020814, 1030020813, 1030020812, 0, 0, 0, 0, 0, 0, 1030020827, 1030020828 }, [1103002106] = { 1030021009, 1030021010, 1030021012, 1030021015, 1030021014, 1030021016, 1030021008, 1030021007, 1030021006, 1030021005, 1030021004, 1030021003, 1030021002, 0, 0, 0, 0, 0, 0, 1030021013, 1030021017 }, [1103002113] = { 1030021079, 1030021080, 1030021082, 1030021085, 1030021084, 1030021086, 1030021078, 1030021077, 1030021076, 1030021075, 1030021074, 1030021073, 1030021072, 0, 0, 0, 0, 0, 0, 1030021083, 1030021087 }, [1103003022] = { 1030030165, 1030030166, 1030030167, 1030030172, 1030030169, 1030030173, 0, 0, 0, 0, 1030030164, 1030030163, 1030030162, 0, 0, 0, 0, 0, 0, 0, 0 }, [1103003030] = { 1030030256, 1030030257, 1030030258, 1030030254, 1030030253, 1030030255, 1030030248, 1030030247, 1030030246, 1030030245, 1030030244, 1030030243, 1030030242, 0, 0, 0, 0, 0, 0, 1030030259, 1030030249 }, [1103003042] = { 1030030374, 1030030375, 1030030376, 1030030372, 1030030369, 1030030373, 0, 0, 0, 0, 1030030364, 1030030363, 1030030362, 0, 0, 0, 0, 0, 0, 1030030377, 0 }, [1103003051] = { 1030030458, 1030030459, 1030030460, 1030030456, 1030030455, 1030030457, 0, 0, 0, 0, 1030030454, 1030030453, 1030030452, 0, 0, 0, 0, 0, 0, 1030030463, 0 }, [1103003062] = { 1030030568, 1030030569, 1030030570, 1030030566, 1030030565, 1030030567, 0, 0, 0, 0, 1030030564, 1030030563, 1030030562, 0, 0, 0, 0, 0, 0, 1030030572, 0 }, [1103003079] = { 1030030744, 1030030745, 1030030746, 1030030742, 1030030740, 1030030743, 1030030738, 1030030737, 1030030736, 1030030735, 1030030734, 1030030733, 1030030732, 0, 0, 0, 0, 0, 0, 1030030747, 1030030739 }, [1103003087] = { 1030030825, 1030030826, 1030030827, 1030030823, 1030030824, 1030030824, 1030030818, 1030030817, 1030030816, 1030030815, 1030030814, 1030030813, 1030030812, 0, 0, 0, 0, 0, 0, 1030030828, 1030030819 }, [1103004037] = { 1030040315, 1030040316, 1030040317, 1030040325, 1030040324, 1030040323, 0, 0, 0, 0, 1030040314, 1030040313, 1030040312, 1030040327, 1030040326, 0, 0, 0, 1030040328, 1030040329, 0 }, [1103006030] = { 1030060245, 1030060246, 1030060247, 0, 1030060253, 1030060252, 0, 0, 0, 0, 1030060244, 1030060243, 1030060242, 0, 0, 0, 0, 0, 0, 0, 0 }, [1103007028] = { 1030070233, 1030070234, 1030070235, 1030070226, 1030070225, 1030070227, 1030070218, 1030070217, 1030070216, 1030070215, 1030070214, 1030070213, 1030070212, 0, 0, 0, 0, 0, 0, 1030070236, 1030070219 }, [1103012010] = { 0, 0, 0, 0, 0, 0, 1030120038, 1030120037, 1030120036, 1030120035, 1030120034, 1030120033, 1030120032, 0, 0, 0, 0, 0, 0, 0, 0 }, [1103012019] = { 0, 0, 0, 0, 0, 0, 1030120138, 1030120137, 1030120136, 1030120135, 1030120134, 1030120133, 1030120132, 0, 0, 0, 0, 0, 0, 0, 0 }, [1103012031] = { 0, 0, 0, 0, 0, 0, 1030120258, 1030120257, 1030120256, 1030120255, 1030120254, 1030120253, 1030120252, 0, 0, 0, 0, 0, 0, 0, 0 }, [1103012039] = { 0, 0, 0, 0, 0, 0, 1030120339, 1030120338, 1030120337, 1030120336, 1030120335, 1030120334, 1030120333, 0, 0, 0, 0, 0, 0, 0, 0 }, [1103102007] = { 1031020026, 1031020027, 1031020028, 1031020024, 1031020023, 1031020025, 1031020019, 1031020018, 1031020017, 1031020016, 1031020015, 1031020014, 1031020013, 0, 0, 0, 0, 0, 0, 1031020029, 0 }, [1105001034] = { 0, 0, 0, 0, 1050010287, 1050010289, 1050010286, 1050010285, 1050010284, 1050010283, 1050010282, 0, 0, 0, 0, 0, 0, 0, 0, 1050010292, 0 }, [1105001048] = { 0, 0, 0, 1050010429, 1050010428, 1050010434, 1050010427, 1050010426, 1050010425, 1050010424, 1050010423, 0, 0, 0, 0, 0, 0, 0, 0, 1050010435, 0 }, [1105001069] = { 0, 0, 0, 1050010639, 1050010638, 1050010640, 1050010637, 1050010636, 1050010635, 1050010634, 1050010633, 1050010645, 0, 0, 0, 0, 0, 0, 0, 1050010643, 1050010646 }, [1105002091] = { 0, 0, 0, 0, 0, 0, 1050020847, 1050020846, 1050020845, 1050020844, 1050020843, 1050020842, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, [1105010019] = { 0, 0, 0, 0, 0, 0, 1050100144, 1050100143, 1050100142, 1050100141, 1050100139, 1050100138, 0, 0, 0, 0, 0, 0, 0, 0, 0 } }
Polo.BaseAttachToIndex = { [201010] = 1, [201005] = 1, [201004] = 1, [201009] = 2, [201003] = 2, [201002] = 2, [201011] = 3, [201007] = 3, [201006] = 3, [204012] = 4, [204005] = 4, [204008] = 4, [204011] = 5, [204004] = 5, [204007] = 5, [204013] = 6, [204006] = 6, [204009] = 6, [203001] = 7, [203002] = 8, [203003] = 9, [203014] = 10, [203004] = 11, [203015] = 12, [203005] = 13, [202002] = 14, [202001] = 15, [202004] = 16, [202005] = 17, [202007] = 18, [202006] = 19, [205002] = 20, [205003] = 20, [205001] = 20, [203018] = 21, [204014] = 22 }
Polo.VipAttachToIndex = {}
for vipSkinId, attList in pairs(Polo.VIP_Attachments) do
    for slotIdx, attId in ipairs(attList) do
        if attId and attId > 0 then
            Polo.VipAttachToIndex[attId] = slotIdx
        end
    end
end

Polo.WeaponSkinFor = function(weaponId)
    local s = Polo.WeaponSkinMap[weaponId]
    if s and s > 0 then
        Polo.DownloadSkinItem(s)
        return s
    end
    return weaponId
end

Polo.DownloadSkinItem = function(skinId)
    if Polo.skinIdCache2[skinId] then return end
    pcall(function()
        local pm = require("client.slua.logic.download.puffer.puffer_manager")
        local pc_ = require("client.slua.logic.download.puffer_const")
        if pm and pc_ then
            local st = {}
            if pm.GetState and pm.GetState(pc_.ENUM_DownloadType.ODPTD, st) ~= pc_.ENUM_DownloadState.Done then
                if pm.Download then pm.Download(pc_.ENUM_DownloadType.ODPTD, {}) end
            end
        end
    end)
    Polo.skinIdCache2[skinId] = true
end

Polo.ApplyWeaponSkins = function(char)
    pcall(function()
        if not slua.isValid(char) then return end
        local wm = char:GetWeaponManager()
        if not slua.isValid(wm) then return end
        for slot = 1, 3 do
            local w = wm:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(w) and w.synData and type(w.GetWeaponID) == "function" then
                local wid = w:GetWeaponID()
                local skinId = Polo.WeaponSkinFor(wid)
                local slotData = w.synData:Get(7)
                if slotData and slotData.defineID and slotData.defineID.TypeSpecificID ~= skinId then
                    slotData.defineID.TypeSpecificID = skinId
                    w.synData:Set(7, slotData)
                    pcall(function() w:SetWeaponAvatarID(skinId) end)
                    Polo.DownloadSkinItem(skinId)
                end
                if skinId >= 10000000 and Polo.VIP_Attachments and Polo.VIP_Attachments[skinId] then
                    for idx = 0, 5 do
                        local ad = w.synData:Get(idx)
                        if ad and ad.defineID then
                            local attId = ad.defineID.TypeSpecificID
                            if attId and attId > 0 then
                                local mapIdx = Polo.BaseAttachToIndex[attId] or Polo.VipAttachToIndex[attId]
                                local vipAtt = mapIdx and Polo.VIP_Attachments[skinId][mapIdx]
                                if vipAtt and vipAtt > 0 and vipAtt ~= attId then
                                    ad.defineID.TypeSpecificID = vipAtt
                                    w.synData:Set(idx, ad)
                                    Polo.DownloadSkinItem(vipAtt)
                                end
                            end
                        end
                    end
                end
                pcall(function() w:DelayHandleAvatarMeshChanged() end)
                pcall(function() w:OnRep_synData() end)
            end
        end
    end)
end

Polo.ApplyVehicleSkins = function(char)
    pcall(function()
        if not slua.isValid(char) then return end
        local veh = char:GetCurrentVehicle()
        if not slua.isValid(veh) then Polo.LastVehicleEntity = nil return end
        local av = veh.VehicleAvatar or veh.VehicleAvatarComponent_BP or (veh.GetAvatarComponent and veh:GetAvatarComponent())
        if not slua.isValid(av) then return end
        local cur = veh:GetAvatarId() or ""
        local skinId = nil
        for base, sid in pairs(Polo.VehicleSkinMap) do
            if tostring(cur):find(tostring(base), 1, true) then skinId = sid break end
        end
        if skinId and skinId > 0 and cur ~= tostring(skinId) then
            Polo.DownloadSkinItem(skinId)
            if av.curSwitchEffectId == nil then av.curSwitchEffectId = 7303001 end
            pcall(function() av:ChangeItemAvatar(skinId, true) end)
            Polo.LastVehicleEntity = veh
        end
    end)
end

Polo.HandlePet = function()
    pcall(function()
        local petId = Polo.OutfitMap.Pet
        if not petId or petId == 0 or petId == 50000 or petId == Polo.LastAppliedPet then return end
        Polo.DownloadSkinItem(petId)
        local mm = require("client.module_framework.ModuleManager")
        if mm then
            local mod = mm.GetModule and mm.GetModule(mm.CommonModuleConfig.logic_pet)
            if mod then
                if mod.SetCurPetID then mod:SetCurPetID(petId) end
                if mod.EquipPet then mod:EquipPet(petId) end
            end
        end
        Polo.LastAppliedPet = petId
    end)
end

Polo.InitSkins = function()
    pcall(function()
        -- weapon skin defaults: first skin (index 2) of each weapon
        for baseId, list in pairs(Polo.skinIdMappings) do
            if list and list[2] and list[2] ~= baseId then
                Polo.WeaponSkinMap[baseId] = list[2]
            end
        end
        -- vehicle skin defaults
        Polo.VehicleSkinMap = {
            [1961001] = 1961007, [1903001] = 1903005, [1915001] = 1915002,
            [1908001] = 1908002, [1907001] = 1907007,
        }
        -- outfit defaults (suit only; bag/helmet optional)
        Polo.OutfitMap = { Suit = 403003, Bag = 501001, Helmet = 501001, Pet = 0 }
    end)
end

Polo.SkinTick = function()
    if not Polo.CONFIG.ModSkin then return end
    pcall(function()
        local char = getPlayerChar()
        if not slua.isValid(char) then return end
        Polo.ApplyWeaponSkins(char)
        Polo.ApplyVehicleSkins(char)
        Polo.HandlePet()
    end)
end

-- ============================ MASTER TICK ============================
Polo.MasterTick = function()
    if not _G.PoloMasterReady then
        _G.PoloMasterReady = true
        Polo.InitSkins()
        if Polo.CONFIG.UnlockFPS then Polo.Enable165FPS() end
        if Polo.CONFIG.KillCounter then Polo.EnableKillCounter() end
    end
    if Polo.CONFIG.AimTouchEnable then
        pcall(Polo.AimTouch)
    end
    if Polo.CONFIG.ModSkin then
        Polo.SkinTick()
    end
end


-- ============================ POLO LAYER WIRING ============================
-- (polo systems base ke tick se chalte hain)

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