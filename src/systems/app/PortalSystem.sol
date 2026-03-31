pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharFund,
  CrystalFee,
  CharInfo,
  SellCrystalCounter,
  SellCrystalReq,
  SellCrystalReqData
} from "@codegen/index.sol";
import { CharacterFundUtils, CityVaultUtils } from "@utils/index.sol";
import { UWorldUtils } from "@utils/UWorldUtils.sol";
import { PlatformUtils } from "@utils/PlatformUtils.sol";
import { Config, Errors } from "@common/index.sol";

contract PortalSystem is CharacterAccessControl, System {
  function buyCrystal(uint256 characterId, uint256 amount) public payable onlyAuthorizedWallet(characterId) {
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
    uint256 amount
  )
    public
    onlyAuthorizedWallet(fromCharacterId)
  {
    if (fromCharacterId == toCharacterId) {
      revert Errors.PortalSystem_CannotTransferToSelf(fromCharacterId);
    }
    _validateCrystalAmount(amount);
    // decreaseCrystal will revert if fromCharacterId has insufficient crystal balance
    CharacterFundUtils.decreaseCrystal(fromCharacterId, amount);

    // charge fee and transfer net amount to recipient
    uint256 platformFeeCrystal = PlatformUtils.getPlatformFee(amount);
    uint256 remainAmount = amount - platformFeeCrystal;
    uint8 kingdomId = CharInfo.getKingdomId(fromCharacterId);
    uint8 kingdomFeePercentage = CrystalFee.getFee(kingdomId);
    uint256 kingdomFeeCrystal = (remainAmount * uint256(kingdomFeePercentage)) / 100;
    uint256 netAmount = remainAmount - kingdomFeeCrystal;

    if (platformFeeCrystal > 0) {
      PlatformUtils.updateAppTeamCrystal(platformFeeCrystal, true);
    }
    if (kingdomFeeCrystal > 0) {
      CityVaultUtils.updateVaultCrystalByKingdomId(kingdomId, kingdomFeeCrystal, true);
      PlatformUtils.updateAppVaultCrystal(kingdomFeeCrystal, true);
    }

    CharacterFundUtils.increaseCrystal(toCharacterId, netAmount);
  }

  function requestSellCrystal(uint256 characterId, uint256 amount) public onlyAuthorizedWallet(characterId) {
    _validateCrystalAmount(amount);
    if (amount < Config.MIN_SELL_CRYSTAL) {
      revert Errors.PortalSystem_CrystalAmountTooSmall(amount, Config.MIN_SELL_CRYSTAL);
    }
    uint256 crystalBalance = CharFund.getCrystal(characterId);
    if (crystalBalance < amount) {
      revert Errors.InsufficientCrystal(crystalBalance, amount);
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
    uint256 amount = reqData.amount;
    uint8 kingdomId = CharInfo.getKingdomId(characterId);
    uint256 platformFeeCrystal = PlatformUtils.getPlatformFee(amount);
    uint256 remainAmount = amount - platformFeeCrystal;
    uint8 kingdomFeePercentage = CrystalFee.getFee(kingdomId);
    uint256 kingdomFeeCrystal = (remainAmount * uint256(kingdomFeePercentage)) / 100;
    uint256 netAmount = remainAmount - kingdomFeeCrystal;

    if (platformFeeCrystal > 0) {
      PlatformUtils.updateAppTeamCrystal(platformFeeCrystal, true);
    }

    // set done before external transfer to avoid reentrancy replay on the same request
    SellCrystalReq.setIsDone(characterId, reqId, true);

    uint256 receivedEth = netAmount * Config.CRYSTAL_UNIT_PRICE;
    UWorldUtils.transferTo(_msgSender(), receivedEth);

    // kingdom fee will be sent to city vault
    if (kingdomFeeCrystal > 0) {
      CityVaultUtils.updateVaultCrystalByKingdomId(kingdomId, kingdomFeeCrystal, true);
      PlatformUtils.updateAppVaultCrystal(kingdomFeeCrystal, true);
    }
  }

  function _validateSellCrystalRequest(uint256 reqId, SellCrystalReqData memory reqData) private pure {
    if (reqData.amount == 0 || reqData.requestedAt == 0 || reqData.isDone) {
      revert Errors.PortalSystem_SellRequestNotFound(reqId);
    }
  }

  function _validateCrystalAmount(uint256 amount) private pure {
    if (amount < Config.MIN_CRYSTALS_PER_PURCHASE) {
      revert Errors.PortalSystem_CrystalAmountTooSmall(amount, Config.MIN_CRYSTALS_PER_PURCHASE);
    }
    if (amount % Config.MIN_CRYSTALS_PER_PURCHASE != 0) {
      revert Errors.InvalidCrystalAmount(amount, Config.MIN_CRYSTALS_PER_PURCHASE);
    }
  }
}
