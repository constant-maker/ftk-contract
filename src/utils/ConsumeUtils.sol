pragma solidity >=0.8.24;

import {
  BuffItemInfoV3,
  BuffItemInfoV3Data,
  CharPositionData,
  CharBuff,
  CharBuffData,
  CharDebuff,
  CharDebuffData,
  CharDebuff2,
  ItemV2
} from "@codegen/index.sol";
import { CharacterPositionUtils } from "./CharacterPositionUtils.sol";
import { ZoneType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { TargetItemData } from "@systems/app/ConsumeSystem.sol";

library ConsumeUtils {
  uint16 constant DEBUFF_COOLDOWN = 10; // seconds

  function applyStatsBuff(uint256 characterId, uint256 itemId, uint256 targetPlayer) public {
    bool isGoodBuff = BuffItemInfoV3.getIsBuff(itemId);
    if (isGoodBuff) {
      applyStatsGoodBuff(targetPlayer, itemId);
    } else {
      checkIsReadyToCast(characterId);
      applyStatsBadBuff(targetPlayer, itemId);
      CharDebuff2.setLastCastTime(characterId, block.timestamp);
    }
  }

  function applyStatsGoodBuff(uint256 targetPlayer, uint256 itemId) public {
    CharBuffData memory currentBuff = CharBuff.get(targetPlayer);

    uint256 nowTs = block.timestamp;
    uint256 newExpire = nowTs + BuffItemInfoV3.getDuration(itemId);
    uint8 newTier = ItemV2.getTier(itemId);

    // 0. Refresh existing buff if same ID is already active
    if (currentBuff.buffIds[0] == itemId && currentBuff.expireTimes[0] >= nowTs) {
      currentBuff.expireTimes[0] = newExpire;
      CharBuff.set(targetPlayer, currentBuff);
      return;
    }

    if (currentBuff.buffIds[1] == itemId && currentBuff.expireTimes[1] >= nowTs) {
      // refresh and move to slot 0
      currentBuff.expireTimes[1] = newExpire;
      (currentBuff.buffIds[0], currentBuff.buffIds[1]) = (currentBuff.buffIds[1], currentBuff.buffIds[0]);
      (currentBuff.expireTimes[0], currentBuff.expireTimes[1]) =
        (currentBuff.expireTimes[1], currentBuff.expireTimes[0]);
      CharBuff.set(targetPlayer, currentBuff);
      return;
    }

    // 1. Try to use empty or expired slot
    if (currentBuff.buffIds[0] == 0 || currentBuff.expireTimes[0] < nowTs) {
      currentBuff.buffIds[0] = itemId;
      currentBuff.expireTimes[0] = newExpire;
      CharBuff.set(targetPlayer, currentBuff);
      return;
    }
    if (currentBuff.buffIds[1] == 0 || currentBuff.expireTimes[1] < nowTs) {
      currentBuff.buffIds[1] = itemId;
      currentBuff.expireTimes[1] = newExpire;
      // swap to keep new buff in slot 0
      (currentBuff.buffIds[0], currentBuff.buffIds[1]) = (currentBuff.buffIds[1], currentBuff.buffIds[0]);
      (currentBuff.expireTimes[0], currentBuff.expireTimes[1]) =
        (currentBuff.expireTimes[1], currentBuff.expireTimes[0]);
      CharBuff.set(targetPlayer, currentBuff);
      return;
    }

    // 2. No free slot → try to replace a lower-tier buff
    if (ItemV2.getTier(currentBuff.buffIds[0]) < newTier) {
      // replace slot 0
      currentBuff.buffIds[0] = itemId;
      currentBuff.expireTimes[0] = newExpire;
      CharBuff.set(targetPlayer, currentBuff);
      return;
    }

    if (ItemV2.getTier(currentBuff.buffIds[1]) < newTier) {
      // replace slot 1 and swap to keep new buff in slot 0
      currentBuff.buffIds[1] = itemId;
      currentBuff.expireTimes[1] = newExpire;
      (currentBuff.buffIds[0], currentBuff.buffIds[1]) = (currentBuff.buffIds[1], currentBuff.buffIds[0]);
      (currentBuff.expireTimes[0], currentBuff.expireTimes[1]) =
        (currentBuff.expireTimes[1], currentBuff.expireTimes[0]);
      CharBuff.set(targetPlayer, currentBuff);
      return;
    }
  }

  function applyStatsBadBuff(uint256 targetPlayer, uint256 itemId) public {
    CharDebuffData memory currentDebuff = CharDebuff.get(targetPlayer);

    uint256 nowTs = block.timestamp;
    uint256 newExpire = nowTs + BuffItemInfoV3.getDuration(itemId);
    uint8 newTier = ItemV2.getTier(itemId);

    // 0. Refresh existing debuff if same ID is already active
    if (currentDebuff.debuffIds[0] == itemId && currentDebuff.expireTimes[0] >= nowTs) {
      currentDebuff.expireTimes[0] = newExpire;
      CharDebuff.set(targetPlayer, currentDebuff);
      return;
    }

    if (currentDebuff.debuffIds[1] == itemId && currentDebuff.expireTimes[1] >= nowTs) {
      // refresh and move to slot 0
      currentDebuff.expireTimes[1] = newExpire;
      (currentDebuff.debuffIds[0], currentDebuff.debuffIds[1]) =
        (currentDebuff.debuffIds[1], currentDebuff.debuffIds[0]);
      (currentDebuff.expireTimes[0], currentDebuff.expireTimes[1]) =
        (currentDebuff.expireTimes[1], currentDebuff.expireTimes[0]);
      CharDebuff.set(targetPlayer, currentDebuff);
      return;
    }

    // 1. Try to use empty or expired slot
    if (currentDebuff.debuffIds[0] == 0 || currentDebuff.expireTimes[0] < nowTs) {
      currentDebuff.debuffIds[0] = uint32(itemId);
      currentDebuff.expireTimes[0] = newExpire;
      CharDebuff.set(targetPlayer, currentDebuff);
      return;
    }
    if (currentDebuff.debuffIds[1] == 0 || currentDebuff.expireTimes[1] < nowTs) {
      currentDebuff.debuffIds[1] = uint32(itemId);
      currentDebuff.expireTimes[1] = newExpire;
      // swap to keep new debuff in slot 0
      (currentDebuff.debuffIds[0], currentDebuff.debuffIds[1]) =
        (currentDebuff.debuffIds[1], currentDebuff.debuffIds[0]);
      (currentDebuff.expireTimes[0], currentDebuff.expireTimes[1]) =
        (currentDebuff.expireTimes[1], currentDebuff.expireTimes[0]);
      CharDebuff.set(targetPlayer, currentDebuff);
      return;
    }

    // 2. No free slot → try to replace a lower-tier debuff
    if (ItemV2.getTier(currentDebuff.debuffIds[0]) < newTier) {
      // replace slot 0
      currentDebuff.debuffIds[0] = uint32(itemId);
      currentDebuff.expireTimes[0] = newExpire;
      CharDebuff.set(targetPlayer, currentDebuff);
      return;
    }

    if (ItemV2.getTier(currentDebuff.debuffIds[1]) < newTier) {
      // replace slot 1 and swap to keep new debuff in slot 0
      currentDebuff.debuffIds[1] = uint32(itemId);
      currentDebuff.expireTimes[1] = newExpire;
      (currentDebuff.debuffIds[0], currentDebuff.debuffIds[1]) =
        (currentDebuff.debuffIds[1], currentDebuff.debuffIds[0]);
      (currentDebuff.expireTimes[0], currentDebuff.expireTimes[1]) =
        (currentDebuff.expireTimes[1], currentDebuff.expireTimes[0]);
      CharDebuff.set(targetPlayer, currentDebuff);
      return;
    }
  }

  function checkIsReadyToCast(uint256 characterId) public view {
    uint256 lastCastTime = CharDebuff2.getLastCastTime(characterId);
    uint256 nextCastTime = lastCastTime + DEBUFF_COOLDOWN;
    if (block.timestamp < nextCastTime) {
      revert Errors.ConsumeSystem_DebuffOnCooldown(characterId, nextCastTime);
    }
  }

  function validateTargetItemData(uint256 characterId, uint256 itemId, TargetItemData memory targetData) public view {
    BuffItemInfoV3Data memory buffItemInfo = BuffItemInfoV3.get(itemId);

    // if (RestrictLocV2.getIsRestricted(targetData.x, targetData.y) && !buffItemInfo.selfCastOnly) {
    //   revert Errors.ConsumeSystem_CannotTargetRestrictLocation();
    // }

    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(characterId);

    uint32 dx = _getAbsValue(charPosition.x - targetData.x);
    uint32 dy = _getAbsValue(charPosition.y - targetData.y);

    if (dx + dy > buffItemInfo.range) {
      revert Errors.ConsumeSystem_OutOfRange(charPosition.x, charPosition.y, targetData.x, targetData.y, itemId);
    }

    _validateTargetPlayers(targetData.targetPlayers, buffItemInfo.numTarget);

    if (buffItemInfo.selfCastOnly) {
      if (targetData.targetPlayers.length != 1 || targetData.targetPlayers[0] != characterId) {
        revert Errors.ConsumeSystem_SelfCastOnly(itemId);
      }
    }
  }

  /// @dev validate that targetPlayers has no duplicates
  function _validateTargetPlayers(uint256[] memory targetPlayers, uint8 maxNumTarget) private pure {
    if (maxNumTarget < targetPlayers.length) {
      revert Errors.ConsumeSystem_TooManyTargets(targetPlayers.length, maxNumTarget);
    }
    uint256 len = targetPlayers.length;
    for (uint256 i = 0; i < len; i++) {
      for (uint256 j = i + 1; j < len; j++) {
        if (targetPlayers[i] == targetPlayers[j]) {
          revert Errors.ConsumeSystem_DuplicateTarget();
        }
      }
    }
  }

  function _getAbsValue(int32 value) private pure returns (uint32) {
    return value < 0 ? uint32(-value) : uint32(value);
  }

  function _applyDebuff(uint256 characterId) private { }
}
