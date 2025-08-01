pragma solidity >=0.8.24;

import {
  TileInfo3,
  CharInfo,
  DropResource,
  CharPositionData,
  CharInventory,
  CharState,
  PvEAfk,
  PvEAfkData
} from "@codegen/index.sol";
import { ZoneType, CharacterStateType } from "@codegen/common.sol";
import { CharacterEquipmentUtils } from "./CharacterEquipmentUtils.sol";
import { TileInventoryUtils } from "./TileInventoryUtils.sol";
import { InventoryItemUtils } from "./InventoryItemUtils.sol";
import { InventoryEquipmentUtils } from "./InventoryEquipmentUtils.sol";
import { CharacterPositionUtils } from "./CharacterPositionUtils.sol";
import { CharacterStateUtils } from "./CharacterStateUtils.sol";
import { BattlePvEUtils2 } from "./BattlePvEUtils2.sol";

library BattleUtils2 {
  /// @dev apply loss to character, move back to capital and reset character state
  /// @param characterId character id
  /// @param position character position
  /// @notice This function is used when character lost in battle, it will reset character state
  /// and move character back to capital. It will also drop all resources and equipments in inventory
  /// to the tile where character lost.
  function applyLoss(uint256 characterId, CharPositionData memory position) public {
    // check if inventory should be dropped
    int32 x = position.x;
    int32 y = position.y;
    ZoneType zoneType = TileInfo3.getZoneType(x, y);
    uint8 tileKingdomId = TileInfo3.getKingdomId(x, y);
    uint8 characterKingdomId = CharInfo.getKingdomId(characterId);
    if (zoneType == ZoneType.Black && tileKingdomId == characterKingdomId) {
      zoneType = ZoneType.Red;
    } else if (zoneType != ZoneType.Black) {
      zoneType = (characterKingdomId == tileKingdomId) ? ZoneType.Green : ZoneType.Red;
    }
    if (zoneType == ZoneType.Red || zoneType == ZoneType.Black) {
      // drop resource in inventory
      uint256[] memory rawResourceIds = DropResource.getResourceIds();
      (uint256[] memory resourceIds, uint32[] memory resourceAmounts) =
        InventoryItemUtils.dropAllResource(characterId, rawResourceIds);
      TileInventoryUtils.addItems(x, y, resourceIds, resourceAmounts);
    }
    if (zoneType == ZoneType.Black) {
      // drop equipment in inventory
      CharacterEquipmentUtils.unequipAllEquipment(characterId);
      uint256[] memory equipmentIds = CharInventory.getEquipmentIds(characterId);
      InventoryEquipmentUtils.removeEquipments(characterId, equipmentIds, true);
      TileInventoryUtils.addEquipments(x, y, equipmentIds);
    }

    // move back to city and reset character state to standby
    CharacterPositionUtils.moveToCapital(characterId);
    CharState.setState(characterId, CharacterStateType.Standby);
  }

  /// @dev check if character is in a state that can be forced to stop AFK
  function checkAndForceStopAFK(uint256 characterId, CharPositionData memory position) public {
    if (CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Hunting) {
      // force stop AFK
      PvEAfkData memory afkData = PvEAfk.get(characterId);
      BattlePvEUtils2.stopPvEAFK(characterId, afkData, position);
    }
  }
}
