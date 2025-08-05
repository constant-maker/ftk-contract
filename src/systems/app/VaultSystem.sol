pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharRole, City, CharInfo, CityVault } from "@codegen/index.sol";
import { RoleType } from "@codegen/common.sol";
import { CharacterPositionUtils, InventoryItemUtils } from "@utils/index.sol";
import { Errors } from "@common/Errors.sol";

contract VaultSystem is System, CharacterAccessControl {
  function withdrawItemFromCity(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory itemIds,
    uint32[] memory amounts
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    CharacterPositionUtils.MustInCity(characterId, cityId);
    if (CharRole.get(characterId) != RoleType.VaultKeeper) {
      revert Errors.VaultSystem_MustBeVaultKeeper(characterId);
    }
    // check kingdom id
    uint8 kingdomId = City.getKingdomId(cityId);
    if (kingdomId == 0) {
      revert Errors.InvalidCityId(cityId);
    }
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    if (kingdomId != charKingdomId) {
      revert Errors.VaultSystem_CharacterNotInSameKingdom(characterId, cityId);
    }
    if (itemIds.length != amounts.length) {
      revert Errors.VaultSystem_InvalidParamsLen(itemIds.length, amounts.length);
    }
    for (uint256 i = 0; i < itemIds.length; i++) {
      if (itemIds[i] == 0 || amounts[i] == 0) {
        revert Errors.VaultSystem_InvalidParamsValue(itemIds[i], amounts[i]);
      }
      uint32 currentVaultAmount = CityVault.getAmount(cityId, itemIds[i]);
      if (currentVaultAmount < amounts[i]) {
        revert Errors.VaultSystem_InsufficientVaultAmount(cityId, itemIds[i], currentVaultAmount, amounts[i]);
      }
      uint32 newVaultAmount = currentVaultAmount - amounts[i];
      CityVault.setAmount(cityId, itemIds[i], newVaultAmount);
    }
    InventoryItemUtils.addItems(characterId, itemIds, amounts);
  }

  function contributeItemToCity(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory itemIds,
    uint32[] memory amounts
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    // no need check character and city kingdom id, because it's free to contribute to any city
    if (itemIds.length != amounts.length) {
      revert Errors.VaultSystem_InvalidParamsLen(itemIds.length, amounts.length);
    }
    CharacterPositionUtils.MustInCity(characterId, cityId);
    InventoryItemUtils.removeItems(characterId, itemIds, amounts);
    for (uint256 i = 0; i < itemIds.length; i++) {
      if (itemIds[i] == 0 || amounts[i] == 0) {
        revert Errors.VaultSystem_InvalidParamsValue(itemIds[i], amounts[i]);
      }
      uint32 currentVaultAmount = CityVault.getAmount(cityId, itemIds[i]);
      uint32 newVaultAmount = currentVaultAmount + amounts[i];
      CityVault.setAmount(cityId, itemIds[i], newVaultAmount);
    }
  }
}
