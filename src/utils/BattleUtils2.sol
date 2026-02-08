pragma solidity >=0.8.24;

import {
  TileInfo3,
  CharInfo,
  DropResource,
  CharPositionData,
  CharInventory,
  CharState,
  PvEAfk,
  PvEAfkData,
  ItemV2,
  Equipment
} from "@codegen/index.sol";
import { ZoneType, CharacterStateType } from "@codegen/common.sol";
import { CharacterEquipmentUtils } from "./CharacterEquipmentUtils.sol";
import { TileInventoryUtils } from "./TileInventoryUtils.sol";
import { InventoryItemUtils } from "./InventoryItemUtils.sol";
import { InventoryEquipmentUtils } from "./InventoryEquipmentUtils.sol";
import { CharacterPositionUtils } from "./CharacterPositionUtils.sol";
import { CharacterStateUtils } from "./CharacterStateUtils.sol";
import { BattlePvEUtils2 } from "./BattlePvEUtils2.sol";
import { CharacterBuffUtils } from "./CharacterBuffUtils.sol";

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
      uint256[] memory dropEquipmentIds = _getDropEquipment(characterId);
      InventoryEquipmentUtils.removeEquipments(characterId, dropEquipmentIds, true);
      TileInventoryUtils.addEquipments(x, y, dropEquipmentIds);
    }

    // move character back to saved point (if saved point is empty, move to capital)
    CharacterPositionUtils.moveToSavedPoint(characterId);
    CharState.set(characterId, CharacterStateType.Standby, block.timestamp);
    // character is dead, remove all buffs
    CharacterBuffUtils.dispelAllBuff(characterId);
  }

  /// @dev check if character is in a state that can be forced to stop AFK
  function checkAndForceStopAFK(uint256 characterId, CharPositionData memory position) public {
    if (CharacterStateUtils.getCharacterState(characterId) == CharacterStateType.Hunting) {
      // force stop AFK
      PvEAfkData memory afkData = PvEAfk.get(characterId);
      BattlePvEUtils2.stopPvEAFK(characterId, afkData, position);
    }
  }

  /// @dev get up to 2 equipments that can be dropped when character lost
  function _getDropEquipment(uint256 characterId) private view returns (uint256[] memory) {
    uint256[] memory equipmentIds = CharInventory.getEquipmentIds(characterId);
    uint256 len = equipmentIds.length;

    if (len <= 2) return equipmentIds;

    (uint8[] memory tiers, uint8 highest, uint8 second) = _scanTiers(equipmentIds);

    (uint256[] memory high, uint256[] memory sec) = _collectCandidates(equipmentIds, tiers, highest, second);

    return _pickResult(characterId, high, sec);
  }

  /// @dev compute tiers array, highest and second highest tier
  function _scanTiers(uint256[] memory equipmentIds)
    private
    view
    returns (uint8[] memory tiers, uint8 highest, uint8 second)
  {
    uint256 len = equipmentIds.length;
    tiers = new uint8[](len);
    highest = 0;
    second = 0;

    for (uint256 i = 0; i < len; i++) {
      uint8 tier = ItemV2.getTier(Equipment.getItemId(equipmentIds[i]));
      tiers[i] = tier;
      if (tier > highest) {
        second = highest;
        highest = tier;
      } else if (tier > second && tier < highest) {
        second = tier;
      }
    }
  }

  /// @dev partition items into highest tier and second tier candidates
  function _collectCandidates(
    uint256[] memory equipmentIds,
    uint8[] memory tiers,
    uint8 highest,
    uint8 second
  )
    private
    pure
    returns (uint256[] memory high, uint256[] memory sec)
  {
    uint256 len = equipmentIds.length;
    uint256[] memory tmpHigh = new uint256[](len);
    uint256[] memory tmpSec = new uint256[](len);
    uint256 highCount = 0;
    uint256 secCount = 0;

    for (uint256 i = 0; i < len; i++) {
      if (tiers[i] == highest) {
        tmpHigh[highCount++] = equipmentIds[i];
      } else if (tiers[i] == second) {
        tmpSec[secCount++] = equipmentIds[i];
      }
    }

    // Trim to exact counts
    high = new uint256[](highCount);
    for (uint256 i = 0; i < highCount; i++) {
      high[i] = tmpHigh[i];
    }

    sec = new uint256[](secCount);
    for (uint256 i = 0; i < secCount; i++) {
      sec[i] = tmpSec[i];
    }
  }

  /// @dev choose result based on counts; pseudo-random shuffle and slice
  function _pickResult(
    uint256 characterId,
    uint256[] memory high,
    uint256[] memory sec
  )
    private
    view
    returns (uint256[] memory)
  {
    uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1), characterId)));

    uint256 highCount = high.length;
    uint256 secCount = sec.length;
    if (highCount >= 2) {
      _shuffle(high, seed);
      uint256[] memory res = new uint256[](2);
      res[0] = high[0];
      res[1] = high[1];
      return res;
    }

    if (highCount == 1 && secCount > 0) {
      _shuffle(sec, seed);
      uint256[] memory res = new uint256[](2);
      res[0] = high[0];
      res[1] = sec[0];
      return res;
    }

    uint256[] memory onlyOne = new uint256[](1);
    onlyOne[0] = high[0];
    return onlyOne;
  }

  /// @dev Fisher–Yates shuffle for the whole array
  function _shuffle(uint256[] memory arr, uint256 seed) private pure {
    uint256 n = arr.length;
    for (uint256 i = 0; i < n; i++) {
      uint256 j = i + (seed % (n - i));
      (arr[i], arr[j]) = (arr[j], arr[i]);
      seed >>= 1; // advance seed
    }
  }
}
