pragma solidity >=0.8.24;

import {
  CityVault2V2,
  CharOtherItem,
  CharInfo,
  Kingdom,
  CrystalFee,
  CharGachaReq,
  GachaReqInfo,
  CharGachaV3,
  CharGachaV3Data,
  CharTotalSpend
} from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";
import { InventoryItemUtils } from "./InventoryItemUtils.sol";
import { CharacterFundUtils } from "./CharacterFundUtils.sol";

library GachaUtils {
  function checkAndSpendTicket(uint256 characterId, uint256 ticketValue, uint256 ticketItemId) public {
    if (CharOtherItem.getAmount(characterId, ticketItemId) > 0) {
      // Has ticket item, use it
      InventoryItemUtils.removeItem(characterId, ticketItemId, 1);
      return;
    }

    // No ticket item, try to pay with crystal
    if (ticketValue > 0) {
      CharacterFundUtils.decreaseCrystal(characterId, uint32(ticketValue));
      // account total spent
      uint256 totalSpend = CharTotalSpend.get(characterId);
      totalSpend += ticketValue;
      CharTotalSpend.set(characterId, totalSpend);
      // share the fee to city vault
      uint8 kingdomId = CharInfo.getKingdomId(characterId); // TODO: create an utility function to do this
      uint256 capitalId = Kingdom.getCapitalId(kingdomId);
      uint8 kingdomFeePercentage = CrystalFee.get(kingdomId);
      uint256 shareValue = (ticketValue * uint256(kingdomFeePercentage)) / 100;
      uint256 currentVaultCrystal = CityVault2V2.getCrystal(capitalId);
      CityVault2V2.setCrystal(capitalId, currentVaultCrystal + shareValue);
      return;
    }

    // Either ticket item or crystal is required, but user has neither
    revert Errors.GachaSystem_InsufficientPayment(characterId);
  }

  function storeCharGachaData(uint256 characterId, uint256 gachaId, uint256 requestId, bool isLimitedGacha) public {
    CharGachaV3Data memory charGacha = CharGachaV3Data({
      randomNumber: 0, // will be set when fulfilled
      gachaId: gachaId,
      isLimitedGacha: isLimitedGacha,
      gachaItemId: 0, // will be set when fulfilled
      gachaEquipmentId: 0, // will be set when fulfilled if it's equipment
      isPending: true,
      timestamp: block.timestamp
    });

    CharGachaV3.set(characterId, requestId, charGacha);
    GachaReqInfo.setCharacterId(requestId, characterId);
    CharGachaReq.set(characterId, requestId);
  }

  function checkPendingRequest(uint256 characterId) public view {
    if (CharGachaReq.get(characterId) > 0) {
      revert Errors.GachaSystem_ExistingPendingRequest(characterId);
    }
  }
}
