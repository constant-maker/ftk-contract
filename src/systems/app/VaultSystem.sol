pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharRole,
  City,
  CharInfo,
  CityVault,
  CityVault2,
  CVaultHistoryV2,
  HistoryCounter,
  KingElection,
  CharStats2
} from "@codegen/index.sol";
import { RoleType } from "@codegen/common.sol";
import { CharacterPositionUtils, InventoryItemUtils, CharacterFundUtils } from "@utils/index.sol";
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
    CharacterPositionUtils.mustInCity(characterId, cityId);
    // check kingdom id
    uint8 kingdomId = City.getKingdomId(cityId);
    if (kingdomId == 0) {
      revert Errors.InvalidCityId(cityId);
    }
    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    if (kingdomId != charKingdomId) {
      revert Errors.VaultSystem_CharacterNotInSameKingdom(characterId, cityId);
    }
    if (KingElection.getKingId(kingdomId) != characterId && CharRole.get(characterId) != RoleType.VaultKeeper) {
      revert Errors.VaultSystem_MustBeVaultKeeper(characterId);
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
      CVaultHistoryV2.set(
        cityId, _getVaultHistoryId(cityId), characterId, itemIds[i], amounts[i], 0, block.timestamp, false
      );
    }
    InventoryItemUtils.addItems(characterId, itemIds, amounts);
  }

  function contributeItemToCity(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory itemIds,
    uint32[] memory amounts,
    uint32 gold
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    if (gold > 0) {
      uint32 fame = CharStats2.getFame(characterId);
      if (fame < 1050) {
        revert Errors.VaultSystem_FameTooLow(characterId, fame);
      }
      CharacterFundUtils.decreaseGold(characterId, gold);
      CityVault2.setGold(cityId, CityVault2.getGold(cityId) + gold);
    }
    // no need check character and city kingdom id, because it's free to contribute to any city
    if (itemIds.length != amounts.length) {
      revert Errors.VaultSystem_InvalidParamsLen(itemIds.length, amounts.length);
    }
    CharacterPositionUtils.mustInCity(characterId, cityId);
    InventoryItemUtils.removeItems(characterId, itemIds, amounts);
    for (uint256 i = 0; i < itemIds.length; i++) {
      if (itemIds[i] == 0 || amounts[i] == 0) {
        revert Errors.VaultSystem_InvalidParamsValue(itemIds[i], amounts[i]);
      }
      uint32 currentVaultAmount = CityVault.getAmount(cityId, itemIds[i]);
      uint32 newVaultAmount = currentVaultAmount + amounts[i];
      CityVault.setAmount(cityId, itemIds[i], newVaultAmount);
      CVaultHistoryV2.set(
        cityId, _getVaultHistoryId(cityId), characterId, itemIds[i], amounts[i], gold, block.timestamp, true
      );
    }
  }

  function _getVaultHistoryId(uint256 cityId) private returns (uint256 id) {
    uint256 currentCounter = HistoryCounter.get(cityId);
    uint256 newCounter = currentCounter + 1;
    HistoryCounter.setCounter(cityId, newCounter);
    return newCounter % 100; // wrap around after 100 entries
  }
}
