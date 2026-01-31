pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharSkin, SkinInfo } from "@codegen/index.sol";
import { SkinSlotType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { EquipSkinData } from "./SkinSystem.sol";

struct EquipSkinData {
  SkinSlotType slotType;
  uint256 itemId;
}

contract SkinSystem is System, CharacterAccessControl {
  function equipSkins(uint256 characterId, EquipSkinData[] calldata equipData) public onlyAuthorizedWallet(characterId) {
    for (uint256 i = 0; i < equipData.length; ++i) {
      _equipSkin(characterId, equipData[i]);
    }
  }

  function _equipSkin(uint256 characterId, EquipSkinData calldata equipSkinData) private {
    if (equipSkinData.itemId != 0 && SkinInfo.getSlotType(equipSkinData.itemId) != equipSkinData.slotType) {
      revert Errors.SkinSystem_SkinSlotTypeMismatch(equipSkinData.itemId, equipSkinData.slotType);
    }
    uint256 currentEquippedItemId = CharSkin.get(characterId, equipSkinData.slotType);
    if (equipSkinData.itemId == 0) {
      // unequip skin
      if (currentEquippedItemId > 0) {
        CharSkin.deleteRecord(characterId, equipSkinData.slotType);
        InventoryItemUtils.addItem(characterId, currentEquippedItemId, 1); // return skin to inventory
      }
      return;
    }
    if (currentEquippedItemId == 0) {
      InventoryItemUtils.removeItem(characterId, equipSkinData.itemId, 1); // remove skin from inventory
      CharSkin.set(characterId, equipSkinData.slotType, equipSkinData.itemId);
      return;
    }
    if (currentEquippedItemId == equipSkinData.itemId) {
      return; // same skin, do nothing
    }
    // swap skin
    InventoryItemUtils.removeItem(characterId, equipSkinData.itemId, 1); // remove new skin from inventory
    CharSkin.set(characterId, equipSkinData.slotType, equipSkinData.itemId); // equip new skin
    InventoryItemUtils.addItem(characterId, currentEquippedItemId, 1); // return old skin to inventory
  }
}
