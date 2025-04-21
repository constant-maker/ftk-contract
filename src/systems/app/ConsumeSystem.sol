pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { Item, ResourceInfo, HealingItemInfo } from "@codegen/index.sol";
import { CharacterStatsUtils } from "@utils/CharacterStatsUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { Errors } from "@common/Errors.sol";
import { ItemType, ResourceType } from "@codegen/common.sol";

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
  function consumeItems(uint256 characterId, uint256 itemId, uint32 amount) public onlyAuthorizedWallet(characterId) {
    if (amount == 0) {
      revert Errors.ConsumeSystem_ItemAmountIsZero(characterId, itemId);
    }
    InventoryItemUtils.removeItem(characterId, itemId, amount);
    ItemType itemType = Item.getItemType(itemId);
    if (itemType == ItemType.HealingItem) {
      _healing(characterId, itemId, amount);
    } else if (itemType == ItemType.StatModifierItem) {
      // TODO: need to add character buff and debuff table
    } else {
      revert Errors.ConsumeSystem_ItemIsNotConsumable(characterId, itemId);
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
}
