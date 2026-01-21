pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharGacha,
  CharGachaData,
  GachaV4,
  GachaV4Data,
  GachaReqChar,
  EquipmentPet,
  CharInventory,
  CharGachaStatus
} from "@codegen/index.sol";
import { GachaType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { GachaUtils, CharacterItemUtils, InventoryItemUtils } from "@utils/index.sol";

// Interface for requesting random numbers
interface IVRFCoordinator {
  function requestRandomNumbers(
    uint32 numNumbers, // How many random numbers you need
    uint256 seed // Seed for randomness generation
  )
    external
    returns (uint256 requestId);
}

// Interface your contract must implement
interface IVRFConsumer {
  function rawFulfillRandomNumbers(uint256 requestId, uint256[] memory randomNumbers) external;
}

contract GachaSystem is System, CharacterAccessControl, IVRFConsumer {
  // RISE Testnet VRF Coordinator
  address constant VRF_COORDINATOR = 0x9d57aB4517ba97349551C876a01a7580B1338909;
  uint8 constant NUM_REQUEST_NUMBER = 1;
  uint256 constant PET_ITEM_ID = 436;
  uint256 constant TOTAL_PERCENT = 10_000; // for probability calculation with 2 decimal places ~ 100.00%

  function requestGacha(uint256 characterId, uint256 gachaId) public payable onlyAuthorizedWallet(characterId) {
    if (CharGachaStatus.get(characterId)) {
      revert Errors.GachaSystem_ExistingPendingRequest(characterId);
    }
    // Validate gacha
    GachaV4Data memory gacha = GachaV4.get(gachaId);
    if (gacha.itemIds.length == 0) {
      revert Errors.Gacha_NoItemToGacha(gachaId);
    }

    if (block.timestamp < gacha.startTime || block.timestamp > gacha.endTime) {
      revert Errors.Gacha_InactiveGacha(gachaId);
    }

    uint256 ticketValue = gacha.ticketValue;
    if (ticketValue > 0 && _msgValue() != ticketValue) {
      revert Errors.GachaSystem_InsufficientGachaFee(_msgValue(), ticketValue);
    }

    uint256 ticketItemId = gacha.ticketItemId;
    if (ticketItemId != 0) {
      InventoryItemUtils.removeItem(characterId, ticketItemId, 1);
    }

    // If gacha has only one item, directly give it to character
    if (gacha.itemIds.length == 1) {
      uint256 receivedItemId;
      if (gacha.gachaType == GachaType.Limited) {
        receivedItemId = _handleLimitedGacha(characterId, gachaId, gacha, 0);
      } else {
        receivedItemId = _handleUnlimitedGacha(characterId, gacha, 0);
      }
      CharGacha.set(characterId, 0, 0, gachaId, receivedItemId, false, block.timestamp);
      return;
    }

    // Request one random number from the VRF Coordinator
    uint256 requestId = IVRFCoordinator(VRF_COORDINATOR).requestRandomNumbers(
      NUM_REQUEST_NUMBER, uint256(keccak256(abi.encodePacked(characterId, block.timestamp, gachaId)))
    );

    // Store the gacha request info
    CharGachaData memory charGacha = CharGachaData({
      randomNumber: 0, // will be set when fulfilled
      gachaId: gachaId,
      gachaItemId: 0, // will be set when fulfilled
      isPending: true,
      timestamp: block.timestamp
    });

    CharGacha.set(characterId, requestId, charGacha);
    GachaReqChar.set(requestId, characterId);
    CharGachaStatus.set(characterId, true);
  }

  // This function is called by the VRF Coordinator when the random numbers are ready
  function rawFulfillRandomNumbers(uint256 requestId, uint256[] memory randomNumbers) external override {
    require(_msgSender() == VRF_COORDINATOR, "Only VRF coordinator");

    require(randomNumbers.length == NUM_REQUEST_NUMBER, "Invalid random numbers length");

    // Find the characterId associated with this requestId
    uint256 characterId = GachaReqChar.get(requestId);
    if (characterId == 0) {
      revert Errors.GachaSystem_InvalidRequestId(requestId);
    }

    // Get the CharGacha record
    CharGachaData memory charGacha = CharGacha.get(characterId, requestId);
    if (!charGacha.isPending) {
      revert Errors.GachaSystem_RequestAlreadyFulfilled(requestId);
    }

    // Get gacha data
    GachaV4Data memory gachaData = GachaV4.get(charGacha.gachaId);

    // Use the random number to select an item from the gacha
    require(randomNumbers.length > 0, "No random numbers provided");
    uint256 randomNumber = randomNumbers[0];
    uint256 receivedItemId;

    if (gachaData.gachaType == GachaType.Limited) {
      receivedItemId = _handleLimitedGacha(characterId, charGacha.gachaId, gachaData, randomNumber);
    } else {
      receivedItemId = _handleUnlimitedGacha(characterId, gachaData, randomNumber);
    }

    // receivedItemId is 100% guarantee to be set now (> 0)

    // Update the CharGacha table with the received item and remove item from gacha
    charGacha.randomNumber = randomNumber;
    charGacha.gachaItemId = receivedItemId;
    charGacha.isPending = false;
    CharGacha.set(characterId, requestId, charGacha);
    GachaReqChar.deleteRecord(requestId);
    CharGachaStatus.set(characterId, false);
  }

  function _handleLimitedGacha(
    uint256 characterId,
    uint256 gachaId,
    GachaV4Data memory gachaData,
    uint256 randomNumber
  )
    private
    returns (uint256)
  {
    uint256 randomIndex = randomNumber % gachaData.itemIds.length;
    uint256 receivedItemId = gachaData.itemIds[randomIndex];

    // Remove the item from the gacha pool
    GachaUtils.removeItem(gachaId, receivedItemId);
    // Current gacha is PET gacha
    // This logic is for PET gacha only

    // Pet gacha case
    CharacterItemUtils.addNewItem(characterId, PET_ITEM_ID, 1); // add pet item to inventory
    // Get last added equipmentId
    uint256 lastEquipmentId =
      CharInventory.getItemEquipmentIds(characterId, CharInventory.lengthEquipmentIds(characterId) - 1); // last added
      // equipmentId
    EquipmentPet.set(lastEquipmentId, receivedItemId); // map equipmentId to petId

    return receivedItemId;
  }

  function _handleUnlimitedGacha(
    uint256 characterId,
    GachaV4Data memory gachaData,
    uint256 randomNumber
  )
    private
    returns (uint256)
  {
    uint256 r = randomNumber % TOTAL_PERCENT;
    uint256 cumulativePercent = 0;
    for (uint256 i = 0; i < gachaData.itemIds.length; i++) {
      cumulativePercent += gachaData.percents[i];
      if (r < cumulativePercent) {
        uint256 receivedItemId = gachaData.itemIds[i];
        CharacterItemUtils.addNewItem(characterId, receivedItemId, gachaData.amounts[i]);
        return receivedItemId;
      }
    }
    // Fallback (should not reach here if percents sum to TOTAL_PERCENT)
    uint256 fallbackItemId = gachaData.itemIds[0];
    CharacterItemUtils.addNewItem(characterId, fallbackItemId, gachaData.amounts[0]);
    return fallbackItemId;
  }
}
