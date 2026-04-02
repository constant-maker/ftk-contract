pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  Item,
  ResourceInfo,
  HealingItemInfo,
  CharDebuff,
  CharPositionData,
  BuffInfo,
  CharExpAmp,
  CharExpAmpData,
  BuffExp,
  BuffExpData,
  BuffStat,
  CharCurrentStats
} from "@codegen/index.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { CharacterStatsUtils } from "@utils/CharacterStatsUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { ConsumeUtils, TargetItemData } from "@utils/ConsumeUtils.sol";
import { CharacterStateUtils } from "@utils/CharacterStateUtils.sol";
import { Config, Errors } from "@common/index.sol";
import { ItemType, ResourceType, BuffType, CharacterStateType } from "@codegen/common.sol";

contract ConsumeSystem is System, CharacterAccessControl {
  /// @dev eat berries to heal
  function eatBerries(uint256 characterId, uint256 itemId, uint32 amount) public onlyAuthorizedWallet(characterId) {
    if (amount == 0) {
      revert Errors.ConsumeSystem_ItemAmountIsZero(characterId, itemId);
    }
    if (ResourceInfo.getResourceType(itemId) != ResourceType.Berry) {
      revert Errors.ConsumeSystem_MustBeBerry(characterId, itemId);
    }
    InventoryItemUtils.removeItem(characterId, itemId, amount);
    // berry can heal equal with its tier (e.g tier 1 ~ 1 hp)
    uint32 gainedHp = uint32(Item.getTier(itemId)) * amount;
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
    ItemType itemType = Item.getItemType(itemId);

    if (itemType == ItemType.BuffItem) {
      if (amount != 1) {
        revert Errors.ConsumeSystem_BuffItemAmountMustBeOne(characterId, itemId, amount);
      }
      if (targetData.targetPlayers.length == 0) {
        revert Errors.ConsumeSystem_EmptyTargets(itemId);
      }
      // ensure targetData is valid, e.g range, numTarget, duplicate target, self-cast only
      ConsumeUtils.validateTargetItemData(characterId, itemId, targetData);

      // apply buff to each target
      BuffType buffType = BuffInfo.getBuffType(itemId);
      if (buffType == BuffType.StatsModify) {
        _handleStatsBuffItem(characterId, itemId, targetData);
      } else if (buffType == BuffType.ExpAmplify) {
        _handleExpBuffItem(itemId, targetData);
      } else if (buffType == BuffType.InstantHeal) {
        // _healing(characterId, itemId, 1);
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
      // specific by itemId
      if (itemId == 435) {
        // gold bundle - unpack to get instant 2500 golds
        CharacterFundUtils.increaseGold(characterId, 2500 * amount);
      }
      return;
    }
    revert Errors.ConsumeSystem_ItemIsNotConsumable(itemId);
  }

  function _handleStatsBuffItem(uint256 characterId, uint256 itemId, TargetItemData memory targetData) private {
    bool needsCastCooldown = !BuffInfo.getIsBuff(itemId);
    uint32 itemDmg = _calculateBuffDmg(characterId, BuffStat.getDmg(itemId), BuffStat.getIsAbsDmg(itemId));
    if (itemDmg > 0 || needsCastCooldown) {
      ConsumeUtils.checkIsReadyToCast(characterId);
      CharDebuff.setLastCastTime(characterId, block.timestamp);
    }
    for (uint256 i = 0; i < targetData.targetPlayers.length; i++) {
      uint256 targetPlayer = targetData.targetPlayers[i];
      if (!_isTargetInPosition(targetPlayer, targetData.x, targetData.y)) {
        continue; // skip if target player not in position
      }
      ConsumeUtils.applyStatsBuff(itemId, targetPlayer);
      if (itemDmg > 0) {
        _applyDmgBuff(targetPlayer, itemDmg);
      }
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

  function _handleExpBuffItem(uint256 itemId, TargetItemData memory targetData) private {
    BuffExpData memory expBuffData = BuffExp.get(itemId);
    uint32 buffDuration = BuffInfo.getDuration(itemId);

    for (uint256 i = 0; i < targetData.targetPlayers.length; i++) {
      uint256 targetPlayer = targetData.targetPlayers[i];
      if (CharacterStateUtils.getCharacterState(targetPlayer) == CharacterStateType.Hunting) {
        revert Errors.ConsumeSystem_CannotApplyExpBuffToHunting(targetPlayer);
      }
      if (!_isTargetInPosition(targetPlayer, targetData.x, targetData.y)) {
        continue; // skip if target player not in position
      }
      CharExpAmpData memory charExpBuff = CharExpAmp.get(targetPlayer);

      if (expBuffData.farmingPerkAmp > 0) {
        charExpBuff.farmingPerkAmp = expBuffData.farmingPerkAmp;
        charExpBuff.farmingExpireTime = block.timestamp + buffDuration;
      }
      if (expBuffData.pveExpAmp > 0) {
        charExpBuff.pveExpAmp = expBuffData.pveExpAmp;
        charExpBuff.pveExpireTime = block.timestamp + buffDuration;
      }

      CharExpAmp.set(targetPlayer, charExpBuff);
    }
  }

  function _isTargetInPosition(uint256 targetPlayer, int32 x, int32 y) private view returns (bool) {
    CharPositionData memory targetPosition = CharacterPositionUtils.getCurrentPosition(targetPlayer);
    return targetPosition.x == x && targetPosition.y == y;
  }
}
