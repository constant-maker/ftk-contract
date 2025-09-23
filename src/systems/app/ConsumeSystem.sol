pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  Item,
  ResourceInfo,
  HealingItemInfo,
  CharBuff,
  CharBuffData,
  CharPositionData,
  BuffItemInfo,
  CharExpAmp,
  CharExpAmpData,
  BuffExp,
  BuffExpData,
  SkillItemInfo,
  SkillItemInfoData,
  CharCurrentStats,
  RestrictLocV2
} from "@codegen/index.sol";
import { CharacterStatsUtils } from "@utils/CharacterStatsUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { Errors } from "@common/Errors.sol";
import { ItemType, ResourceType, BuffType } from "@codegen/common.sol";

contract ConsumeSystem is System, CharacterAccessControl {
  /// @dev eat berries to heal
  function eatBerries(uint256 characterId, uint256 itemId, uint32 amount) public onlyAuthorizedWallet(characterId) {
    if (ResourceInfo.getResourceType(itemId) != ResourceType.Berry) {
      revert Errors.ConsumeSystem_MustBeBerry(characterId, itemId);
    }
    InventoryItemUtils.removeItem(characterId, itemId, amount);
    // berry can heal equal with its tier (e.g tier 1 ~ 1 hp)
    uint32 gainedHp = uint32(Item.getTier(itemId)) * amount;
    CharacterStatsUtils.restoreHp(characterId, gainedHp);
  }

  /// @dev consume items to restore hp, gain atk, def, ...
  function consumeItems(
    uint256 characterId,
    uint256 itemId,
    uint32 amount,
    uint256 targetPlayer
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    if (amount == 0) {
      revert Errors.ConsumeSystem_ItemAmountIsZero(characterId, itemId);
    }
    InventoryItemUtils.removeItem(characterId, itemId, amount);
    ItemType itemType = Item.getItemType(itemId);
    if (itemType == ItemType.HealingItem) {
      _healing(characterId, itemId, amount);
      return;
    }
    if (itemType == ItemType.BuffItem) {
      if (amount != 1) {
        revert Errors.ConsumeSystem_BuffItemAmountMustBeOne(characterId, itemId, amount);
      }
      BuffType buffType = BuffItemInfo.getBuffType(itemId);
      if (buffType == BuffType.StatsModify) {
        _handleStatsBuffItem(characterId, itemId, targetPlayer);
      } else if (buffType == BuffType.ExpAmplify) {
        _handleExpBuffItem(characterId, itemId);
      }
    } else {
      revert Errors.ConsumeSystem_ItemIsNotConsumable(itemId);
    }
  }

  function castSkillItem(
    uint256 characterId,
    uint256 itemId,
    int32 x,
    int32 y,
    uint256[] calldata targetPlayers
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    if (RestrictLocV2.getIsRestricted(x, y)) {
      revert Errors.ConsumeSystem_CannotTargetRestrictLocation();
    }
    InventoryItemUtils.removeItem(characterId, itemId, 1);
    ItemType itemType = Item.getItemType(itemId);
    if (itemType != ItemType.SkillItem) {
      revert Errors.ConsumeSystem_ItemIsNotSkillItem(itemId);
    }
    if (targetPlayers.length == 0) {
      return;
    }
    SkillItemInfoData memory skillItemInfo = SkillItemInfo.get(itemId);
    _validateTargetPlayers(targetPlayers, skillItemInfo.numTarget);
    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(characterId);
    uint32 rangeX = _getAbsValue(charPosition.x - x);
    uint32 rangeY = _getAbsValue(charPosition.y - y);
    if (rangeX > skillItemInfo.range && rangeY > skillItemInfo.range) {
      revert Errors.ConsumeSystem_OutOfRange(charPosition.x, charPosition.y, x, y, itemId);
    }
    uint32 itemDmg = _calculateSkillItemDmg(characterId, skillItemInfo);
    if (itemDmg == 0) {
      return;
    }
    for (uint256 i = 0; i < targetPlayers.length; i++) {
      uint256 targetPlayer = targetPlayers[i];
      CharPositionData memory targetPosition = CharacterPositionUtils.currentPosition(targetPlayer);
      if (targetPosition.x != x || targetPosition.y != y) {
        revert Errors.ConsumeSystem_TargetNotInPosition(targetPlayer, targetPosition.x, targetPosition.y);
      }
      _applySkillItemDmg(targetPlayer, itemDmg);
    }
  }

  function _applySkillItemDmg(uint256 characterId, uint32 itemDmg) private {
    uint32 charHp = CharCurrentStats.getHp(characterId);
    if (itemDmg >= charHp) {
      CharCurrentStats.setHp(characterId, 1); // min 1 hp
    } else {
      CharCurrentStats.setHp(characterId, charHp - itemDmg);
    }
  }

  function _calculateSkillItemDmg(
    uint256 characterId,
    SkillItemInfoData memory skillItemInfo
  )
    private
    view
    returns (uint32)
  {
    uint32 itemDmg = skillItemInfo.dmg;
    bool isAbsDmg = skillItemInfo.isAbsDmg;
    if (isAbsDmg) {
      return itemDmg;
    }
    // itemDmg is percent of character's atk
    uint16 charAtk = CharCurrentStats.getAtk(characterId);
    uint32 calcDmg = (uint32(charAtk) * itemDmg) / 100;
    return calcDmg;
  }

  /// @dev validate that targetPlayers has no duplicates
  function _validateTargetPlayers(uint256[] calldata targetPlayers, uint8 numTarget) private pure {
    if (numTarget < targetPlayers.length) {
      revert Errors.ConsumeSystem_TooManyTargets(targetPlayers.length, numTarget);
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

  function _healing(uint256 characterId, uint256 itemId, uint32 amount) private {
    uint32 hpPerItem = HealingItemInfo.getHpRestore(itemId);
    uint256 gainedHp = uint256(hpPerItem) * amount;
    if (gainedHp > type(uint32).max) {
      revert Errors.ConsumeSystem_Overflow(characterId, gainedHp);
    }
    CharacterStatsUtils.restoreHp(characterId, uint32(gainedHp));
  }

  function _handleStatsBuffItem(uint256 characterId, uint256 itemId, uint256 targetPlayer) private {
    CharBuffData memory currentBuff = CharBuff.get(targetPlayer);
    CharPositionData memory charPosition = CharacterPositionUtils.currentPosition(characterId);
    CharPositionData memory targetPosition = CharacterPositionUtils.currentPosition(targetPlayer);
    uint32 rangeX = _getAbsValue(charPosition.x - targetPosition.x);
    uint32 rangeY = _getAbsValue(charPosition.y - targetPosition.y);
    uint16 itemRange = BuffItemInfo.getRange(itemId);
    if (rangeX > itemRange && rangeY > itemRange) {
      revert Errors.ConsumeSystem_OutOfRange(charPosition.x, charPosition.y, targetPosition.x, targetPosition.y, itemId);
    }
    uint256 newExpire = block.timestamp + BuffItemInfo.getDuration(itemId);
    if (currentBuff.buffIds[0] == itemId && currentBuff.expireTimes[0] >= block.timestamp) {
      currentBuff.expireTimes[0] = newExpire; // refresh duration
    } else if (currentBuff.buffIds[1] == itemId && currentBuff.expireTimes[1] >= block.timestamp) {
      currentBuff.expireTimes[1] = newExpire; // refresh duration
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

  function _handleExpBuffItem(uint256 characterId, uint256 itemId) private {
    BuffExpData memory expBuffData = BuffExp.get(itemId);
    CharExpAmpData memory expBuff = CharExpAmpData({
      farmingPerkAmp: expBuffData.farmingPerkAmp,
      pveExpAmp: expBuffData.pveExpAmp,
      pvePerkAmp: expBuffData.pvePerkAmp,
      expireTime: block.timestamp + BuffItemInfo.getDuration(itemId)
    });
    CharExpAmp.set(characterId, expBuff);
  }

  function _getAbsValue(int32 value) private pure returns (uint32) {
    return value < 0 ? uint32(-value) : uint32(value);
  }
}
