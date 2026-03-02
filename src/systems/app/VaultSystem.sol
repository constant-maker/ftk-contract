pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharRole,
  City,
  CharInfo,
  CityVault,
  CityVault2V2,
  CVaultHistoryV4,
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
import { VaultActionParams } from "@common/Types.sol";

contract VaultSystem is System, CharacterAccessControl {
  function withdrawItemFromCity(
    uint256 characterId,
    uint256 cityId,
    VaultActionParams calldata params
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    uint8 kingdomId = City.getKingdomId(cityId);
    bool isKing = KingElection.getKingId(kingdomId) == characterId;

    _validateWithdrawInput(characterId, cityId, isKing, kingdomId, params);

    if (params.gold > 0) {
      CharacterFundUtils.increaseGold(characterId, params.gold);
      CityVault2V2.setGold(cityId, CityVault2V2.getGold(cityId) - params.gold);
    }

    if (params.crystal > 0) {
      CharacterFundUtils.increaseCrystal(characterId, uint32(params.crystal));
      CityVault2V2.setCrystal(cityId, CityVault2V2.getCrystal(cityId) - params.crystal);
    }

    uint32 totalWithdrawWeight;
    for (uint256 i = 0; i < params.itemIds.length; i++) {
      if (params.itemIds[i] == 0 || params.amounts[i] == 0) {
        revert Errors.VaultSystem_InvalidParamsValue(params.itemIds[i], params.amounts[i]);
      }
      uint32 currentVaultAmount = CityVault.getAmount(cityId, params.itemIds[i]);
      if (currentVaultAmount < params.amounts[i]) {
        revert Errors.VaultSystem_InsufficientVaultAmount(
          cityId, params.itemIds[i], currentVaultAmount, params.amounts[i]
        );
      }
      uint32 itemWeight = ItemV2.getWeight(params.itemIds[i]) * params.amounts[i];
      totalWithdrawWeight += itemWeight;
      uint32 newVaultAmount = currentVaultAmount - params.amounts[i];
      CityVault.setAmount(cityId, params.itemIds[i], newVaultAmount);
    }

    if (!isKing) {
      _checkAndSetWeightQuota(characterId, kingdomId, totalWithdrawWeight);
    }

    InventoryItemUtils.addItems(characterId, params.itemIds, params.amounts);
    CVaultHistoryV4.set(
      cityId,
      _getVaultHistoryId(cityId),
      characterId,
      params.gold,
      params.crystal,
      block.timestamp,
      false,
      params.itemIds,
      params.amounts
    );
  }

  function contributeItemToCity(
    uint256 characterId,
    uint256 cityId,
    VaultActionParams calldata params
  )
    public
    onlyAuthorizedWallet(characterId)
  {
    _validateInput(characterId, cityId, params.itemIds, params.amounts);

    if (params.gold > 0) {
      uint32 fame = CharStats2.getFame(characterId);
      if (fame < 1050) {
        revert Errors.VaultSystem_FameTooLow(characterId, fame);
      }
      CharacterFundUtils.decreaseGold(characterId, params.gold);
      CityVault2V2.setGold(cityId, CityVault2V2.getGold(cityId) + params.gold);
    }

    if (params.crystal > 0) {
      CharacterFundUtils.decreaseCrystal(characterId, uint32(params.crystal));
      CityVault2V2.setCrystal(cityId, CityVault2V2.getCrystal(cityId) + params.crystal);
    }

    // no need check character and city kingdom id, because it's free to contribute to any city
    for (uint256 i = 0; i < params.itemIds.length; i++) {
      uint256 itemId = params.itemIds[i];
      uint32 amount = params.amounts[i];
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
    InventoryItemUtils.removeItems(characterId, params.itemIds, params.amounts);
    CVaultHistoryV4.set(
      cityId,
      _getVaultHistoryId(cityId),
      characterId,
      params.gold,
      params.crystal,
      block.timestamp,
      true,
      params.itemIds,
      params.amounts
    );
  }

  function _getVaultHistoryId(uint256 cityId) private returns (uint256 id) {
    uint256 currentCounter = HistoryCounter.get(cityId);
    uint256 newCounter = currentCounter + 1;
    HistoryCounter.setCounter(cityId, newCounter);
    return newCounter % 100; // wrap around after 100 entries
  }

  function _checkAndSetWeightQuota(uint256 characterId, uint8 kingdomId, uint32 withdrawWeight) private {
    uint32 withdrawWeightLimit = KingSetting2.getWithdrawWeightLimit(kingdomId);
    if (withdrawWeightLimit == 0) return; // no limit

    CharVaultWithdrawData memory cvw = CharVaultWithdraw.get(characterId);

    uint256 nextResetTime = cvw.markTimestamp + 1 days;

    if (cvw.markTimestamp == 0 || nextResetTime <= block.timestamp) {
      cvw.weightQuota = withdrawWeightLimit; // reset daily limit
      CharVaultWithdraw.setMarkTimestamp(characterId, block.timestamp);
    }

    if (cvw.weightQuota < withdrawWeight) {
      revert Errors.VaultSystem_ExceedDailyWithdrawLimit(characterId, cvw.weightQuota, withdrawWeight, nextResetTime);
    }

    cvw.weightQuota -= withdrawWeight;
    CharVaultWithdraw.setWeightQuota(characterId, cvw.weightQuota);
  }

  function _validateWithdrawInput(
    uint256 characterId,
    uint256 cityId,
    bool isKing,
    uint8 kingdomId,
    VaultActionParams calldata params
  )
    private
    view
  {
    _validateInput(characterId, cityId, params.itemIds, params.amounts);

    uint8 charKingdomId = CharInfo.getKingdomId(characterId);
    if (kingdomId != charKingdomId) {
      revert Errors.VaultSystem_CharacterNotInSameKingdom(characterId, cityId);
    }

    if (isKing) {
      // check vault gold and crystal balance
      uint32 vaultGold = CityVault2V2.getGold(cityId);
      if (params.gold > vaultGold) {
        revert Errors.VaultSystem_InsufficientVaultGold(cityId, vaultGold, params.gold);
      }
      uint256 vaultCrystal = CityVault2V2.getCrystal(cityId);
      if (params.crystal > vaultCrystal) {
        revert Errors.VaultSystem_InsufficientVaultCrystal(cityId, vaultCrystal, params.crystal);
      }
      return;
    }

    // only king can withdraw gold/crystal
    if (params.gold > 0 || params.crystal > 0) {
      revert Errors.VaultSystem_OnlyKingCanWithdrawGoldOrCrystal(characterId);
    }

    if (CharRole.get(characterId) != RoleType.VaultKeeper) {
      revert Errors.VaultSystem_MustBeVaultKeeper(characterId);
    }

    for (uint256 i = 0; i < params.itemIds.length; i++) {
      if (VaultRestriction.getIsRestricted(kingdomId, params.itemIds[i])) {
        revert Errors.VaultSystem_WithdrawalRestricted(characterId, kingdomId, params.itemIds[i]);
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
