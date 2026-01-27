pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharGachaV2,
  CharGachaV2Data,
  GachaV5,
  GachaV5Data,
  GachaPet,
  GachaPetData,
  GachaReqChar,
  EquipmentPet,
  CharInventory,
  CharGachaReq
} from "@codegen/index.sol";
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
  uint256 constant MIN_DELAY_TIME = 60; // 60 seconds

  /// @dev Renews an existing gacha request if it is still pending. No new payment is required.
  function renewGachaRequest(uint256 characterId) public onlyAuthorizedWallet(characterId) {
    uint256 existingRequestId = CharGachaReq.get(characterId);
    if (existingRequestId == 0) {
      revert Errors.GachaSystem_NoPendingRequest(characterId);
    }
    CharGachaV2Data memory charGacha = CharGachaV2.get(characterId, existingRequestId);
    if (!charGacha.isPending) {
      revert Errors.GachaSystem_RequestAlreadyFulfilled(existingRequestId);
    }
    if (block.timestamp < charGacha.timestamp + MIN_DELAY_TIME) {
      revert Errors.GachaSystem_ExistingPendingRequest(characterId);
    }

    CharGachaV2.deleteRecord(characterId, existingRequestId); // remove old request
    GachaReqChar.deleteRecord(existingRequestId); // remove old request mapping

    uint256 requestId = IVRFCoordinator(VRF_COORDINATOR).requestRandomNumbers(
      NUM_REQUEST_NUMBER, uint256(keccak256(abi.encodePacked(characterId, block.timestamp, existingRequestId)))
    );

    _storeCharGachaData(characterId, charGacha.gachaId, requestId, charGacha.isLimitedGacha);
  }

  function requestGacha(uint256 characterId, uint256 gachaId) public payable onlyAuthorizedWallet(characterId) {
    _checkPendingRequest(characterId);

    // Validate gacha
    GachaV5Data memory gacha = GachaV5.get(gachaId);
    if (gacha.itemIds.length == 0) {
      revert Errors.Gacha_NoItemToGacha(gachaId);
    }

    if (block.timestamp < gacha.startTime) {
      revert Errors.Gacha_InactiveGacha(gachaId);
    }

    // Either pay with ETH or item
    _checkAndSpendTicket(characterId, gacha.ticketValue, gacha.ticketItemId);

    // Request one random number from the VRF Coordinator
    uint256 requestId = IVRFCoordinator(VRF_COORDINATOR).requestRandomNumbers(
      NUM_REQUEST_NUMBER, uint256(keccak256(abi.encodePacked(characterId, block.timestamp, gachaId)))
    );

    // Store the gacha request info
    _storeCharGachaData(characterId, gachaId, requestId, false);
  }

  function requestPetGacha(uint256 characterId, uint256 gachaId) public payable onlyAuthorizedWallet(characterId) {
    _checkPendingRequest(characterId);

    // Validate gacha
    GachaPetData memory gacha = GachaPet.get(gachaId);
    if (gacha.petIds.length == 0) {
      revert Errors.Gacha_NoItemToGacha(gachaId);
    }

    if (block.timestamp < gacha.startTime || block.timestamp > gacha.endTime) {
      revert Errors.Gacha_InactiveGacha(gachaId);
    }

    _checkAndSpendTicket(characterId, gacha.ticketValue, gacha.ticketItemId);

    // Request one random number from the VRF Coordinator
    uint256 requestId = IVRFCoordinator(VRF_COORDINATOR).requestRandomNumbers(
      NUM_REQUEST_NUMBER, uint256(keccak256(abi.encodePacked(characterId, block.timestamp, gachaId)))
    );

    // Store the gacha request info
    _storeCharGachaData(characterId, gachaId, requestId, true);
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

    // Get the CharGachaV2 record
    CharGachaV2Data memory charGacha = CharGachaV2.get(characterId, requestId);
    if (!charGacha.isPending) {
      revert Errors.GachaSystem_RequestAlreadyFulfilled(requestId);
    }

    // Use the random number to select an item from the gacha
    require(randomNumbers.length > 0, "No random numbers provided");
    uint256 randomNumber = randomNumbers[0];
    uint256 receivedItemId;

    if (charGacha.isLimitedGacha) {
      receivedItemId = _handleLimitedGacha(characterId, charGacha.gachaId, randomNumber);
    } else {
      receivedItemId = _handleUnlimitedGacha(characterId, charGacha.gachaId, randomNumber);
    }

    // Update the CharGachaV2 table with the received item and remove item from gacha
    charGacha.randomNumber = randomNumber;
    charGacha.gachaItemId = receivedItemId;
    charGacha.isPending = false;
    CharGachaV2.set(characterId, requestId, charGacha);
    GachaReqChar.deleteRecord(requestId);
    CharGachaReq.set(characterId, 0);
  }

  function _handleLimitedGacha(uint256 characterId, uint256 gachaId, uint256 randomNumber) private returns (uint256) {
    GachaPetData memory gachaData = GachaPet.get(gachaId);
    uint256 randomIndex = randomNumber % gachaData.petIds.length;
    uint256 receivedItemId = gachaData.petIds[randomIndex];

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

  function _handleUnlimitedGacha(uint256 characterId, uint256 gachaId, uint256 randomNumber) private returns (uint256) {
    GachaV5Data memory gachaData = GachaV5.get(gachaId);
    uint256 r = randomNumber % TOTAL_PERCENT;
    uint256 cumulativePercent = 0;
    uint256 len = gachaData.itemIds.length;
    for (uint256 i = 0; i < len; i++) {
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

  function _checkAndSpendTicket(uint256 characterId, uint256 ticketValue, uint256 ticketItemId) private {
    uint256 msgValue = _msgValue();
    if (msgValue > 0) {
      if (msgValue != ticketValue) {
        revert Errors.GachaSystem_InsufficientGachaFee(msgValue, ticketValue, ticketItemId);
      }
      return;
    }

    if (ticketItemId != 0) {
      InventoryItemUtils.removeItem(characterId, ticketItemId, 1);
      return;
    }

    // no payment provided
    revert Errors.GachaSystem_InsufficientGachaFee(msgValue, ticketValue, ticketItemId);
  }

  function _storeCharGachaData(uint256 characterId, uint256 gachaId, uint256 requestId, bool isLimitedGacha) private {
    CharGachaV2Data memory charGacha = CharGachaV2Data({
      randomNumber: 0, // will be set when fulfilled
      gachaId: gachaId,
      isLimitedGacha: isLimitedGacha,
      gachaItemId: 0, // will be set when fulfilled
      isPending: true,
      timestamp: block.timestamp
    });

    CharGachaV2.set(characterId, requestId, charGacha);
    GachaReqChar.set(requestId, characterId);
    CharGachaReq.set(characterId, requestId);
  }

  function _checkPendingRequest(uint256 characterId) private view {
    if (CharGachaReq.get(characterId) > 0) {
      revert Errors.GachaSystem_ExistingPendingRequest(characterId);
    }
  }
}
