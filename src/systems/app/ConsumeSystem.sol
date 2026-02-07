pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  ItemV2,
  ResourceInfo,
  HealingItemInfo,
  CharDebuff2,
  CharPositionData,
  BuffItemInfoV3,
  CharExpAmp,
  CharExpAmpData,
  BuffExp,
  BuffExpData,
  BuffDmg,
  BuffDmgData,
  BuffStatV4,
  CharCurrentStats
} from "@codegen/index.sol";
import {
  CharacterStatsUtils,
  InventoryItemUtils,
  CharacterPositionUtils,
  ConsumeUtils,
  CharacterStateUtils,
  CharacterFundUtils
} from "@utils/index.sol";
import { Config, Errors } from "@common/index.sol";
import { ItemType, ResourceType, BuffType, CharacterStateType } from "@codegen/common.sol";
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

    if (itemType == ItemType.BuffItem) {
      if (amount != 1) {
        revert Errors.ConsumeSystem_BuffItemAmountMustBeOne(characterId, itemId, amount);
      }
      if (targetData.targetPlayers.length == 0) {
        return;
      }
      // ensure targetData is valid, e.g range, numTarget, duplicate target, self-cast only
      ConsumeUtils.validateTargetItemData(characterId, itemId, targetData);

      // apply buff to each target
      BuffType buffType = BuffItemInfoV3.getBuffType(itemId);
      if (buffType == BuffType.StatsModify) {
        _handleStatsBuffItem(characterId, itemId, targetData);
      } else if (buffType == BuffType.ExpAmplify) {
        _handleExpBuffItem(characterId, itemId, targetData);
      } else if (buffType == BuffType.InstantHeal) {
        // _healing(characterId, itemId, 1);
      } else if (buffType == BuffType.InstantDamage) {
        ConsumeUtils.checkIsReadyToCast(characterId);
        _handleInstantDamageBuffItem(characterId, itemId, targetData);
      } else {
        revert Errors.ConsumeSystem_ItemIsNotConsumable(itemId);
      }
    } else {
      _handleByItemType(characterId, itemId, amount, itemType);
    }
  }

  function _handleByItemType(uint256 characterId, uint256 itemId, uint32 amount, ItemType itemType) private {
    if (itemType == ItemType.HealingItem) {
      _healing(characterId, itemId, amount);
      return;
    }
    if (itemType == ItemType.Teleport) {
      CharacterStateUtils.mustInState(characterId, CharacterStateType.Standby);
      CharacterPositionUtils.moveToSavedPointWithArriveTime(characterId, block.timestamp + Config.TELEPORT_DURATION);
      return;
    }
    if (itemType == ItemType.Bundle) {
      if (itemId == 435) {
        // gold bundle - unpack to get instant 5000 golds
        CharacterFundUtils.increaseGold(characterId, 5000 * amount);
        return;
      }
      return;
    }
    revert Errors.ConsumeSystem_ItemIsNotConsumable(itemId);
  }

  function _handleStatsBuffItem(uint256 characterId, uint256 itemId, TargetItemData memory targetData) private {
    uint32 itemDmg = _calculateBuffDmg(characterId, BuffStatV4.getDmg(itemId), BuffStatV4.getIsAbsDmg(itemId));
    for (uint256 i = 0; i < targetData.targetPlayers.length; i++) {
      uint256 targetPlayer = targetData.targetPlayers[i];
      CharPositionData memory targetPosition = CharacterPositionUtils.currentPosition(targetPlayer);
      if (targetPosition.x != targetData.x || targetPosition.y != targetData.y) {
        continue; // skip if target player not in position
      }
      ConsumeUtils.applyStatsBuff(characterId, itemId, targetPlayer);
      if (itemDmg > 0) {
        _applyDmgBuff(targetPlayer, itemDmg);
      }
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
    uint32 itemDmg = _calculateBuffDmg(characterId, buffDmg.dmg, buffDmg.isAbsDmg);
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
    CharDebuff2.setLastCastTime(characterId, block.timestamp);
  }

  function _applyDmgBuff(uint256 characterId, uint32 itemDmg) private {
    uint32 charHp = CharCurrentStats.getHp(characterId);
    if (itemDmg >= charHp) {
      CharCurrentStats.setHp(characterId, 1); // min 1 hp
    } else {
      CharCurrentStats.setHp(characterId, charHp - itemDmg);
    }
  }

  function _calculateBuffDmg(uint256 characterId, uint32 itemDmg, bool isAbsDmg) private view returns (uint32) {
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
}
