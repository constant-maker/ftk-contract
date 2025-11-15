pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  ItemV2,
  ResourceInfo,
  HealingItemInfo,
  CharBuff,
  CharBuffData,
  CharDebuff,
  CharDebuffData,
  CharPositionData,
  BuffItemInfoV3,
  BuffItemInfoV3Data,
  CharExpAmp,
  CharExpAmpData,
  BuffExp,
  BuffExpData,
  BuffDmg,
  BuffDmgData,
  CharCurrentStats,
  RestrictLocV2
} from "@codegen/index.sol";
import { CharacterStatsUtils } from "@utils/CharacterStatsUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { Errors } from "@common/Errors.sol";
import { ItemType, ResourceType, BuffType } from "@codegen/common.sol";
import { TargetItemData } from "./ConsumeSystem.sol";

struct TargetItemData {
  int32 x;
  int32 y;
  uint256[] targetPlayers;
}

contract ConsumeSystem is System, CharacterAccessControl {
  /// @dev eat berries to heal
  function eatBerries(uint256 characterId, uint256 itemId, uint32 amount) public onlyAuthorizedWallet(characterId) {
    if (ResourceInfo.getResourceType(itemId) != ResourceType.Berry) {
      revert Errors.ConsumeSystem_MustBeBerry(characterId, itemId);
    }
    InventoryItemUtils.removeItem(characterId, itemId, amount);
    // berry can heal equal with its tier (e.g tier 1 ~ 1 hp)
    uint32 gainedHp = uint32(ItemV2.getTier(itemId)) * amount;
    CharacterStatsUtils.restoreHp(characterId, gainedHp);
  }

  function consumeItem(
    uint256 characterId,
    uint256 itemId,
    uint32 amount,
    TargetItemData calldata targetData
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    if (amount == 0) {
      revert Errors.ConsumeSystem_ItemAmountIsZero(characterId, itemId);
    }
    // remove item from inventory
    InventoryItemUtils.removeItem(characterId, itemId, amount);

    // determine item type and apply effect
    ItemType itemType = ItemV2.getItemType(itemId);
    if (itemType == ItemType.HealingItem) {
      _healing(characterId, itemId, amount);
      return;
    }

    // target item
    if (itemType == ItemType.BuffItem) {
      if (amount != 1) {
        revert Errors.ConsumeSystem_BuffItemAmountMustBeOne(characterId, itemId, amount);
      }
      if (targetData.targetPlayers.length == 0) {
        return;
      }
      // ensure targetData is valid, e.g range, numTarget, duplicate target, self-cast only
      _validateTargetItemData(characterId, itemId, targetData);

      // apply buff to each target
      BuffType buffType = BuffItemInfoV3.getBuffType(itemId);
      if (buffType == BuffType.StatsModify) {
        _handleStatsBuffItem(characterId, itemId, targetData);
      } else if (buffType == BuffType.ExpAmplify) {
        _handleExpBuffItem(characterId, itemId, targetData);
      } else if (buffType == BuffType.InstantHeal) {
        // _healing(characterId, itemId, 1);
      } else if (buffType == BuffType.InstantDamage) {
        _handleInstantDamageBuffItem(characterId, itemId, targetData);
      } else {
        revert Errors.ConsumeSystem_ItemIsNotConsumable(itemId);
      }
    } else {
      revert Errors.ConsumeSystem_ItemIsNotConsumable(itemId);
    }
  }

  function _handleInstantDamageBuffItem(
    uint256 characterId,
    uint256 itemId,
    TargetItemData calldata targetData
  )
    private
  {
    BuffDmgData memory buffDmg = BuffDmg.get(itemId);
    uint32 itemDmg = _calculateBuffDmg(characterId, buffDmg);
    if (itemDmg == 0) {
      return;
    }
    for (uint256 i = 0; i < targetData.targetPlayers.length; i++) {
      uint256 targetPlayer = targetData.targetPlayers[i];
      CharPositionData memory targetPosition = CharacterPositionUtils.currentPosition(targetPlayer);
      if (targetPosition.x != targetData.x || targetPosition.y != targetData.y) {
        continue; // skip if target player not in position
      }
      _applyDmgBuff(targetPlayer, itemDmg);
    }
  }

  function _applyDmgBuff(uint256 characterId, uint32 itemDmg) private {
    uint32 charHp = CharCurrentStats.getHp(characterId);
    if (itemDmg >= charHp) {
      CharCurrentStats.setHp(characterId, 1); // min 1 hp
    } else {
      CharCurrentStats.setHp(characterId, charHp - itemDmg);
    }
  }

  function _calculateBuffDmg(uint256 characterId, BuffDmgData memory buffDmg) private view returns (uint32) {
    uint32 itemDmg = buffDmg.dmg;
    bool isAbsDmg = buffDmg.isAbsDmg;
    if (isAbsDmg) {
      return itemDmg;
    }
    // itemDmg is percent of character's atk
    uint16 charAtk = CharCurrentStats.getAtk(characterId);
    uint32 calcDmg = (uint32(charAtk) * itemDmg) / 100;
    return calcDmg;
  }

  function _healing(uint256 characterId, uint256 itemId, uint32 amount) private {
    uint32 hpPerItem = HealingItemInfo.getHpRestore(itemId);
    uint256 gainedHp = uint256(hpPerItem) * amount;
    if (gainedHp > type(uint32).max) {
      revert Errors.ConsumeSystem_Overflow(characterId, gainedHp);
    }
    CharacterStatsUtils.restoreHp(characterId, uint32(gainedHp));
  }

  function _handleStatsBuffItem(uint256 characterId, uint256 itemId, TargetItemData memory targetData) private {
    for (uint256 i = 0; i < targetData.targetPlayers.length; i++) {
      uint256 targetPlayer = targetData.targetPlayers[i];
      _applyStatsBuff(characterId, itemId, targetPlayer, targetData.x, targetData.y);
    }
  }

  function _applyStatsBuff(uint256 characterId, uint256 itemId, uint256 targetPlayer, int32 x, int32 y) private {
    CharPositionData memory targetPosition = CharacterPositionUtils.currentPosition(targetPlayer);
    if (targetPosition.x != x || targetPosition.y != y) {
      return; // skip if target player not in position
    }
    bool isGoodBuff = BuffItemInfoV3.getIsBuff(itemId);
    if (isGoodBuff) {
      CharBuffData memory currentBuff = CharBuff.get(targetPlayer);
      _applyStatsGoodBuff(currentBuff, itemId, targetPlayer);
    } else {
      CharDebuffData memory currentDebuff = CharDebuff.get(targetPlayer);
      _applyStatsBadBuff(currentDebuff, itemId, targetPlayer);
    }
  }

  function _applyStatsGoodBuff(CharBuffData memory currentBuff, uint256 itemId, uint256 targetPlayer) private {
    uint256 newExpire = block.timestamp + BuffItemInfoV3.getDuration(itemId);
    if (currentBuff.buffIds[0] == itemId && currentBuff.expireTimes[0] >= block.timestamp) {
      currentBuff.expireTimes[0] = newExpire; // refresh duration
    } else if (currentBuff.buffIds[1] == itemId && currentBuff.expireTimes[1] >= block.timestamp) {
      currentBuff.expireTimes[1] = newExpire; // refresh duration
      // swap to first slot
      (currentBuff.buffIds[0], currentBuff.buffIds[1]) = (currentBuff.buffIds[1], currentBuff.buffIds[0]);
      (currentBuff.expireTimes[0], currentBuff.expireTimes[1]) =
        (currentBuff.expireTimes[1], currentBuff.expireTimes[0]);
    } else {
      if (
        currentBuff.buffIds[1] == 0 || currentBuff.expireTimes[1] < block.timestamp
          || currentBuff.expireTimes[0] >= block.timestamp
      ) {
        currentBuff.buffIds[1] = currentBuff.buffIds[0];
        currentBuff.expireTimes[1] = currentBuff.expireTimes[0];
      }

      currentBuff.buffIds[0] = uint32(itemId);
      currentBuff.expireTimes[0] = newExpire;
    }
    // set new buff data
    CharBuff.set(targetPlayer, currentBuff);
  }

  function _applyStatsBadBuff(CharDebuffData memory currentDebuff, uint256 itemId, uint256 targetPlayer) private {
    uint256 newExpire = block.timestamp + BuffItemInfoV3.getDuration(itemId);
    if (currentDebuff.debuffIds[0] == itemId && currentDebuff.expireTimes[0] >= block.timestamp) {
      currentDebuff.expireTimes[0] = newExpire; // refresh duration
    } else if (currentDebuff.debuffIds[1] == itemId && currentDebuff.expireTimes[1] >= block.timestamp) {
      currentDebuff.expireTimes[1] = newExpire; // refresh duration
      // swap to first slot
      (currentDebuff.debuffIds[0], currentDebuff.debuffIds[1]) =
        (currentDebuff.debuffIds[1], currentDebuff.debuffIds[0]);
      (currentDebuff.expireTimes[0], currentDebuff.expireTimes[1]) =
        (currentDebuff.expireTimes[1], currentDebuff.expireTimes[0]);
    } else {
      if (
        currentDebuff.debuffIds[1] == 0 || currentDebuff.expireTimes[1] < block.timestamp
          || currentDebuff.expireTimes[0] >= block.timestamp
      ) {
        currentDebuff.debuffIds[1] = currentDebuff.debuffIds[0];
        currentDebuff.expireTimes[1] = currentDebuff.expireTimes[0];
      }

      currentDebuff.debuffIds[0] = uint32(itemId);
      currentDebuff.expireTimes[0] = newExpire;
    }
    // set new buff data
    CharDebuff.set(targetPlayer, currentDebuff);
  }

  function _handleExpBuffItem(uint256 characterId, uint256 itemId, TargetItemData memory targetData) private {
    for (uint256 i = 0; i < targetData.targetPlayers.length; i++) {
      uint256 targetPlayer = targetData.targetPlayers[i];
      CharPositionData memory targetPosition = CharacterPositionUtils.currentPosition(targetPlayer);
      if (targetPosition.x != targetData.x || targetPosition.y != targetData.y) {
        continue; // skip if target player not in position
      }
      BuffExpData memory expBuffData = BuffExp.get(itemId);
      CharExpAmpData memory expBuff = CharExpAmpData({
        farmingPerkAmp: expBuffData.farmingPerkAmp,
        pveExpAmp: expBuffData.pveExpAmp,
        pvePerkAmp: expBuffData.pveExpAmp,
        expireTime: block.timestamp + BuffItemInfoV3.getDuration(itemId)
      });
      CharExpAmp.set(targetPlayer, expBuff);
    }
  }

  function _validateTargetItemData(uint256 characterId, uint256 itemId, TargetItemData memory targetData) private view {
    if (RestrictLocV2.getIsRestricted(targetData.x, targetData.y)) {
      revert Errors.ConsumeSystem_CannotTargetRestrictLocation();
    }

    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(characterId);
    BuffItemInfoV3Data memory buffItemInfo = BuffItemInfoV3.get(itemId);

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
}
