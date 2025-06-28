pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharStorage } from "@codegen/index.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { InventoryToolUtils } from "@utils/InventoryToolUtils.sol";
import { InventoryEquipmentUtils } from "@utils/InventoryEquipmentUtils.sol";
import { StorageToolUtils } from "@utils/StorageToolUtils.sol";
import { StorageEquipmentUtils } from "@utils/StorageEquipmentUtils.sol";
import { StorageItemUtils } from "@utils/StorageItemUtils.sol";
import { CharacterFundUtils } from "@utils/CharacterFundUtils.sol";
import { CharacterPositionUtils } from "@utils/CharacterPositionUtils.sol";
import { ItemsActionData } from "@common/Types.sol";
import { Config } from "@common/Config.sol";

contract StorageSystem is System, CharacterAccessControl {
  /// @dev upgrade storage to increase max weight
  function upgradeStorage(uint256 characterId, uint256 cityId) public onlyAuthorizedWallet(characterId) {
    uint32 maxWeight = CharStorage.getMaxWeight(characterId, cityId);
    if (maxWeight == 0) maxWeight = Config.INIT_STORAGE_MAX_WEIGHT;
    uint32 multiplier = (maxWeight - Config.INIT_STORAGE_MAX_WEIGHT) / Config.STORAGE_MAX_WEIGHT_INCREMENT;

    CharacterFundUtils.decreaseGold(characterId, Config.UPGRADE_STORAGE_COST * (multiplier + 1));
    CharStorage.setMaxWeight(characterId, cityId, maxWeight + Config.STORAGE_MAX_WEIGHT_INCREMENT);
  }

  /// @dev deposit and withdraw item
  function updateStorage(
    uint256 characterId,
    uint256 cityId,
    ItemsActionData calldata transferIn,
    ItemsActionData calldata transferOut
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    CharacterPositionUtils.MustInCity(characterId, cityId);

    // set default max weight for storage
    uint32 maxWeight = CharStorage.getMaxWeight(characterId, cityId);
    if (maxWeight == 0) CharStorage.setMaxWeight(characterId, cityId, Config.INIT_STORAGE_MAX_WEIGHT);

    _withdrawItemsFromStorage(characterId, cityId, transferOut);
    _depositItemsToStorage(characterId, cityId, transferIn);
  }

  /// @dev deposit items from inventory into storage
  function _depositItemsToStorage(uint256 characterId, uint256 cityId, ItemsActionData calldata data) private {
    // transfer in equipments
    uint256[] memory equipmentIds = data.equipmentIds;
    if (equipmentIds.length > 0) {
      StorageEquipmentUtils.addEquipments(characterId, cityId, equipmentIds, true);
      InventoryEquipmentUtils.removeEquipments(characterId, equipmentIds, true);
    }

    // transfer in tools
    uint256[] memory toolIds = data.toolIds;
    if (toolIds.length > 0) {
      StorageToolUtils.addTools(characterId, cityId, toolIds);
      InventoryToolUtils.removeTools(characterId, toolIds);
    }

    // transfer in items
    uint256[] memory itemIds = data.itemIds;
    uint32[] memory itemAmounts = data.itemAmounts;
    if (itemIds.length > 0 && itemAmounts.length > 0) {
      StorageItemUtils.addItems(characterId, cityId, itemIds, itemAmounts, true);
      InventoryItemUtils.removeItems(characterId, itemIds, itemAmounts);
    }
  }

  /// @dev withdraw items from storage into inventory
  function _withdrawItemsFromStorage(uint256 characterId, uint256 cityId, ItemsActionData calldata data) private {
    // transfer out equipments
    uint256[] memory equipmentIds = data.equipmentIds;
    if (equipmentIds.length > 0) {
      StorageEquipmentUtils.removeEquipments(characterId, cityId, equipmentIds);
      InventoryEquipmentUtils.addEquipments(characterId, equipmentIds, true);
    }

    // transfer out tools
    uint256[] memory toolIds = data.toolIds;
    if (toolIds.length > 0) {
      StorageToolUtils.removeTools(characterId, cityId, toolIds);
      InventoryToolUtils.addTools(characterId, toolIds);
    }

    // transfer out items
    uint256[] memory itemIds = data.itemIds;
    uint32[] memory itemAmounts = data.itemAmounts;
    if (itemIds.length > 0 && itemAmounts.length > 0) {
      StorageItemUtils.removeItems(characterId, cityId, itemIds, itemAmounts);
      InventoryItemUtils.addItems(characterId, itemIds, itemAmounts);
    }
  }
}
