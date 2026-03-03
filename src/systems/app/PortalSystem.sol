pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
import {
  SalePackageV2,
  SalePackageV2Data,
  CharTotalSpend,
  CharFund,
  CrystalFee,
  CharInfo,
  Kingdom,
  CityVault2V2,
  SellCrystalCounter,
  SellCrystalReq,
  SellCrystalReqData
} from "@codegen/index.sol";
import { CharAchievementUtils, CharacterFundUtils, InventoryItemUtils } from "@utils/index.sol";
import { UWorldUtils } from "@utils/UWorldUtils.sol";
import { Config, Errors } from "@common/index.sol";

contract PortalSystem is CharacterAccessControl, System {
  function buyCrystal(uint256 characterId, uint32 amount) public payable onlyAuthorizedWallet(characterId) {
    _validateCrystalAmount(amount);
    uint256 value = _msgValue();
    uint256 requiredPayment = amount * Config.CRYSTAL_UNIT_PRICE;
    if (value != requiredPayment) {
      revert Errors.InsufficientPayment(value, requiredPayment);
    }
    CharacterFundUtils.increaseCrystal(characterId, amount);
  }

  function transferCrystal(
    uint256 fromCharacterId,
    uint256 toCharacterId,
    uint32 amount
  )
    public
    onlyAuthorizedWallet(fromCharacterId)
  {
    _validateCrystalAmount(amount);
    // decreaseCrystal will revert if fromCharacterId has insufficient crystal balance
    CharacterFundUtils.decreaseCrystal(fromCharacterId, amount);

    // charge fee and transfer net amount to recipient
    uint32 platformFeeCrystal = (amount * uint32(Config.PLATFORM_FEE_PERCENTAGE) + 99) / 100; // TODO: move to lib
    uint32 remainAmount = amount - platformFeeCrystal;
    uint8 kingdomId = CharInfo.getKingdomId(fromCharacterId); // TODO: move to lib
    uint8 kingdomFeePercentage = CrystalFee.getFee(kingdomId);
    uint32 kingdomFeeCrystal = (remainAmount * uint32(kingdomFeePercentage)) / 100;
    uint32 netAmount = remainAmount - kingdomFeeCrystal;

    CharacterFundUtils.increaseCrystal(toCharacterId, netAmount);
  }

  function requestSellCrystal(uint256 characterId, uint32 amount) public onlyAuthorizedWallet(characterId) {
    _validateCrystalAmount(amount);
    if (amount < Config.MIN_SELL_CRYSTAL) {
      revert Errors.PortalSystem_CrystalAmountTooSmall(amount, Config.MIN_SELL_CRYSTAL);
    }
    uint32 crystalBalance = CharFund.getCrystal(characterId);
    if (crystalBalance < amount) {
      revert Errors.PortalSystem_InsufficientCrystal(crystalBalance, amount);
    }
    CharacterFundUtils.decreaseCrystal(characterId, amount); // lock fund
    uint256 reqId = SellCrystalCounter.getCount() + 1;
    SellCrystalCounter.setCount(reqId);
    SellCrystalReq.set(characterId, reqId, amount, false, block.timestamp);
  }

  function cancelSellCrystal(uint256 characterId, uint256 reqId) public onlyAuthorizedWallet(characterId) {
    SellCrystalReqData memory reqData = SellCrystalReq.get(characterId, reqId);
    _validateSellCrystalRequest(reqId, reqData);
    CharacterFundUtils.increaseCrystal(characterId, reqData.amount); // unlock fund
    SellCrystalReq.deleteRecord(characterId, reqId);
  }

  function executeSellCrystal(uint256 characterId, uint256 reqId) public onlyAuthorizedWallet(characterId) {
    SellCrystalReqData memory reqData = SellCrystalReq.get(characterId, reqId);
    _validateSellCrystalRequest(reqId, reqData);
    if (block.timestamp < reqData.requestedAt + Config.SELL_CRYSTAL_PROCESSING_TIME) {
      revert Errors.PortalSystem_SellRequestProcessing(reqId);
    }
    uint32 amount = reqData.amount;
    uint8 kingdomId = CharInfo.getKingdomId(characterId);
    uint32 platformFeeCrystal = (amount * uint32(Config.PLATFORM_FEE_PERCENTAGE) + 99) / 100;
    uint32 remainAmount = amount - platformFeeCrystal;
    uint8 kingdomFeePercentage = CrystalFee.getFee(kingdomId);
    uint32 kingdomFeeCrystal = (remainAmount * uint32(kingdomFeePercentage)) / 100;
    uint32 netAmount = remainAmount - kingdomFeeCrystal;

    uint256 platformFeeEth = platformFeeCrystal * Config.CRYSTAL_UNIT_PRICE;
    uint256 receivedEth = netAmount * Config.CRYSTAL_UNIT_PRICE;
    UWorldUtils.transferTo(_msgSender(), receivedEth);
    UWorldUtils.transferToTeam(platformFeeEth);

    // kingdom fee will be sent to city vault
    if (kingdomFeeCrystal > 0) {
      uint256 capitalId = Kingdom.getCapitalId(kingdomId);
      uint256 currentVaultCrystal = CityVault2V2.getCrystal(capitalId);
      CityVault2V2.setCrystal(capitalId, currentVaultCrystal + uint256(kingdomFeeCrystal));
    }

    // update request status
    SellCrystalReq.setIsDone(characterId, reqId, true);
  }

  function _validateSellCrystalRequest(uint256 reqId, SellCrystalReqData memory reqData) private pure {
    if (reqData.amount == 0 || reqData.requestedAt == 0 || reqData.isDone) {
      revert Errors.PortalSystem_SellRequestNotFound(reqId);
    }
  }

  function _validateCrystalAmount(uint32 amount) private pure {
    if (amount < Config.MIN_CRYSTALS_PER_PURCHASE) {
      revert Errors.PortalSystem_CrystalAmountTooSmall(amount, Config.MIN_CRYSTALS_PER_PURCHASE);
    }
    if (amount % Config.MIN_CRYSTALS_PER_PURCHASE != 0) {
      revert Errors.InvalidCrystalAmount(amount, Config.MIN_CRYSTALS_PER_PURCHASE);
    }
  }
}
