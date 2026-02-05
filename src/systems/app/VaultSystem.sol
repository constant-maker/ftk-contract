pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharRole,
  City,
  CharInfo,
  CityVault,
  CityVault2,
  CVaultHistoryV3,
  HistoryCounter,
  KingElection,
  CharStats2,
  ItemV2,
  CharVaultWithdraw,
  CharVaultWithdrawData,
  KingSetting2,
  VaultRestriction
} from "@codegen/index.sol";
import { RoleType } from "@codegen/common.sol";
import { CharacterPositionUtils, InventoryItemUtils, CharacterFundUtils, MapUtils } from "@utils/index.sol";
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
    uint8 kingdomId = City.getKingdomId(cityId);
    bool isKing = KingElection.getKingId(kingdomId) == characterId;

    _validateWithdrawInput(characterId, cityId, itemIds, amounts, isKing, kingdomId);

    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    if (kingdomId != charKingdomId) {
      revert Errors.VaultSystem_CharacterNotInSameKingdom(characterId, cityId);
    }
    if (!isKing && CharRole.get(characterId) != RoleType.VaultKeeper) {
      revert Errors.VaultSystem_MustBeVaultKeeper(characterId);
    }
    uint32 totalWithdrawWeight;
    for (uint256 i = 0; i < itemIds.length; i++) {
      if (itemIds[i] == 0 || amounts[i] == 0) {
        revert Errors.VaultSystem_InvalidParamsValue(itemIds[i], amounts[i]);
      }
      uint32 currentVaultAmount = CityVault.getAmount(cityId, itemIds[i]);
      if (currentVaultAmount < amounts[i]) {
        revert Errors.VaultSystem_InsufficientVaultAmount(cityId, itemIds[i], currentVaultAmount, amounts[i]);
      }
      uint32 itemWeight = ItemV2.getWeight(itemIds[i]) * amounts[i];
      totalWithdrawWeight += itemWeight;
      uint32 newVaultAmount = currentVaultAmount - amounts[i];
      CityVault.setAmount(cityId, itemIds[i], newVaultAmount);
    }
    uint32 withdrawWeightLimit = KingSetting2.getWithdrawWeightLimit(kingdomId);
    if (withdrawWeightLimit > 0 && !isKing) {
      // King has no limit
      // check daily withdraw limit
      CharVaultWithdrawData memory cvw = CharVaultWithdraw.get(characterId);
      uint256 nextResetTime = cvw.markTimestamp + 1 days;
      if (cvw.markTimestamp == 0 || nextResetTime < block.timestamp) {
        cvw.weightQuota = withdrawWeightLimit; // reset daily limit
        CharVaultWithdraw.setMarkTimestamp(characterId, block.timestamp);
      }
      if (cvw.weightQuota < totalWithdrawWeight) {
        revert Errors.VaultSystem_ExceedDailyWithdrawLimit(
          characterId, cvw.weightQuota, totalWithdrawWeight, nextResetTime
        );
      }
      cvw.weightQuota -= totalWithdrawWeight;
      CharVaultWithdraw.setWeightQuota(characterId, cvw.weightQuota);
    }
    InventoryItemUtils.addItems(characterId, itemIds, amounts);
    CVaultHistoryV3.set(cityId, _getVaultHistoryId(cityId), characterId, 0, block.timestamp, false, itemIds, amounts);
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
    _validateInput(characterId, cityId, itemIds, amounts);

    if (gold > 0) {
      uint32 fame = CharStats2.getFame(characterId);
      if (fame < 1050) {
        revert Errors.VaultSystem_FameTooLow(characterId, fame);
      }
      CharacterFundUtils.decreaseGold(characterId, gold);
      CityVault2.setGold(cityId, CityVault2.getGold(cityId) + gold);
    }
    // no need check character and city kingdom id, because it's free to contribute to any city
    for (uint256 i = 0; i < itemIds.length; i++) {
      uint256 itemId = itemIds[i];
      uint32 amount = amounts[i];
      if (itemId == 0 || amount == 0) {
        revert Errors.VaultSystem_InvalidParamsValue(itemId, amount);
      }
      bool isUntradeable = ItemV2.getIsUntradeable(itemId);
      if (isUntradeable) {
        revert Errors.VaultSystem_DepositUntradeableItem(itemId);
      }
      uint32 currentVaultAmount = CityVault.getAmount(cityId, itemId);
      uint32 newVaultAmount = currentVaultAmount + amount;
      CityVault.setAmount(cityId, itemId, newVaultAmount);
    }
    InventoryItemUtils.removeItems(characterId, itemIds, amounts);
    CVaultHistoryV3.set(cityId, _getVaultHistoryId(cityId), characterId, gold, block.timestamp, true, itemIds, amounts);
  }

  function _getVaultHistoryId(uint256 cityId) private returns (uint256 id) {
    uint256 currentCounter = HistoryCounter.get(cityId);
    uint256 newCounter = currentCounter + 1;
    HistoryCounter.setCounter(cityId, newCounter);
    return newCounter % 100; // wrap around after 100 entries
  }

  function _validateWithdrawInput(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory itemIds,
    uint32[] memory amounts,
    bool isKing,
    uint8 kingdomId
  )
    private
    view
  {
    _validateInput(characterId, cityId, itemIds, amounts);

    if (isKing) return;

    for (uint256 i = 0; i < itemIds.length; i++) {
      if (VaultRestriction.getIsRestricted(kingdomId, itemIds[i])) {
        revert Errors.VaultSystem_WithdrawalRestricted(characterId, kingdomId, itemIds[i]);
      }
    }
  }

  function _validateInput(
    uint256 characterId,
    uint256 cityId,
    uint256[] memory itemIds,
    uint32[] memory amounts
  )
    private
    view
  {
    CharacterPositionUtils.mustInCity(characterId, cityId);
    MapUtils.mustBeActiveCity(cityId);
    uint8 kingdomId = City.getKingdomId(cityId);
    if (kingdomId == 0) {
      revert Errors.InvalidCityId(cityId);
    }
    if (itemIds.length != amounts.length) {
      revert Errors.VaultSystem_InvalidParamsLen(itemIds.length, amounts.length);
    }
  }
}
