pragma solidity >=0.8.24;

import {
  CharOtherItem,
  CharInfo,
  CrystalFee,
  CharGachaReq,
  GachaReqInfo,
  CharGacha,
  CharGachaData,
  CharTotalSpend
} from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";
import { InventoryItemUtils } from "./InventoryItemUtils.sol";
import { CharacterFundUtils } from "./CharacterFundUtils.sol";
import { PlatformUtils } from "./PlatformUtils.sol";
import { CityVaultUtils } from "./CityVaultUtils.sol";

library GachaUtils {
  function checkAndSpendTicket(uint256 characterId, uint256 ticketValue, uint256 ticketItemId) public {
    if (CharOtherItem.getAmount(characterId, ticketItemId) > 0) {
      // Has ticket item, use it
      InventoryItemUtils.removeItem(characterId, ticketItemId, 1);
      return;
    }

    // No ticket item, try to pay with crystal
    if (ticketValue > 0) {
      CharacterFundUtils.decreaseCrystal(characterId, ticketValue);
      // account total spent
      uint256 totalSpend = CharTotalSpend.get(characterId);
      totalSpend += ticketValue;
      CharTotalSpend.set(characterId, totalSpend);
      // share the fee to city vault
      uint8 kingdomId = CharInfo.getKingdomId(characterId);
      uint8 kingdomFeePercentage = CrystalFee.get(kingdomId);
      uint256 shareValue = (ticketValue * uint256(kingdomFeePercentage)) / 100;
      CityVaultUtils.updateVaultCrystalByKingdomId(kingdomId, shareValue, true);

      // account platform revenue: vault share + remaining team share
      if (shareValue > 0) {
        PlatformUtils.updateRootVaultCrystal(shareValue, true);
      }

      uint256 teamValue = ticketValue - shareValue;
      if (teamValue > 0) {
        PlatformUtils.updateRootTeamCrystal(teamValue, true);
      }
      return;
    }

    // Either ticket item or crystal is required, but user has neither
    revert Errors.GachaSystem_InsufficientPayment(characterId);
  }

  function storeCharGachaData(uint256 characterId, uint256 gachaId, uint256 requestId, bool isLimitedGacha) public {
    CharGachaData memory charGacha = CharGachaData({
      randomNumbers: new uint256[](0), // will be set when fulfilled
      gachaId: gachaId,
      isLimitedGacha: isLimitedGacha,
      gachaItemId: 0, // will be set when fulfilled
      gachaEquipmentId: 0, // will be set when fulfilled if it's equipment
      isPending: true,
      timestamp: block.timestamp
    });

    CharGacha.set(characterId, requestId, charGacha);
    GachaReqInfo.setCharacterId(requestId, characterId);
    CharGachaReq.set(characterId, requestId);
  }

  function checkPendingRequest(uint256 characterId) public view {
    if (CharGachaReq.get(characterId) > 0) {
      revert Errors.GachaSystem_ExistingPendingRequest(characterId);
    }
  }
}
