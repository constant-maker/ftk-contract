pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharGachaV3,
  CharGachaV3Data,
  GachaV5,
  GachaV5Data,
  GachaPet,
  GachaPetData,
  GachaReqChar,
  EquipmentPet,
  CharInventory,
  CharGachaReq,
  ItemV2
} from "@codegen/index.sol";
import { Errors } from "@common/index.sol";
import {
  GachaIndexUtils, CharacterItemUtils, InventoryItemUtils, CharacterFundUtils, GachaUtils
} from "@utils/index.sol";
import { ItemCategoryType } from "@codegen/common.sol";

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
  address constant VRF_COORDINATOR = 0xc0d49A572cF25aC3e9ae21B939e8B619b39291Ea;
  uint32 constant NUM_REQUEST_NUMBER = 1;
  uint256 constant PET_ITEM_ID = 436;
  uint256 constant TOTAL_PERCENT = 10_000; // for probability calculation with 2 decimal places ~ 100.00%
  uint256 constant MIN_DELAY_TIME = 15; // 15 seconds

  /// @dev Renews an existing gacha request if it is still pending. No new payment is required.
  function renewGachaRequest(uint256 characterId) public onlyAuthorizedWallet(characterId) {
    uint256 existingRequestId = CharGachaReq.get(characterId);
    if (existingRequestId == 0) {
      revert Errors.GachaSystem_NoPendingRequest(characterId);
    }
    CharGachaV3Data memory charGacha = CharGachaV3.get(characterId, existingRequestId);
    if (!charGacha.isPending) {
      revert Errors.GachaSystem_RequestAlreadyFulfilled(existingRequestId);
    }
    if (block.timestamp < charGacha.timestamp + MIN_DELAY_TIME) {
      revert Errors.GachaSystem_ExistingPendingRequest(characterId);
    }

    CharGachaV3.deleteRecord(characterId, existingRequestId); // remove old request
    GachaReqChar.deleteRecord(existingRequestId); // remove old request mapping

    uint256 requestId = IVRFCoordinator(VRF_COORDINATOR).requestRandomNumbers(
      NUM_REQUEST_NUMBER, uint256(keccak256(abi.encodePacked(characterId, block.timestamp, existingRequestId)))
    );

    GachaUtils.storeCharGachaData(characterId, charGacha.gachaId, requestId, charGacha.isLimitedGacha);
  }

  function requestGacha(uint256 characterId, uint256 gachaId) public onlyAuthorizedWallet(characterId) {
    GachaUtils.checkPendingRequest(characterId);

    // Validate gacha
    GachaV5Data memory gacha = GachaV5.get(gachaId);
    if (gacha.itemIds.length == 0) {
      revert Errors.Gacha_NoItemToGacha(gachaId);
    }

    if (block.timestamp < gacha.startTime) {
      revert Errors.Gacha_InactiveGacha(gachaId);
    }

    // Either pay with crystal or ticket item
    GachaUtils.checkAndSpendTicket(characterId, gacha.ticketValue, gacha.ticketItemId);

    // Request one random number from the VRF Coordinator
    uint256 requestId = IVRFCoordinator(VRF_COORDINATOR).requestRandomNumbers(
      NUM_REQUEST_NUMBER, uint256(keccak256(abi.encodePacked(characterId, block.timestamp, gachaId)))
    );

    // Store the gacha request info
    GachaUtils.storeCharGachaData(characterId, gachaId, requestId, false);
  }

  function requestPetGacha(uint256 characterId, uint256 gachaId) public onlyAuthorizedWallet(characterId) {
    GachaUtils.checkPendingRequest(characterId);

    // Validate gacha
    GachaPetData memory gacha = GachaPet.get(gachaId);
    if (gacha.petIds.length == 0) {
      revert Errors.Gacha_NoItemToGacha(gachaId);
    }

    if (block.timestamp < gacha.startTime || block.timestamp > gacha.endTime) {
      revert Errors.Gacha_InactiveGacha(gachaId);
    }

    GachaUtils.checkAndSpendTicket(characterId, gacha.ticketValue, gacha.ticketItemId);

    // Request one random number from the VRF Coordinator
    uint256 requestId = IVRFCoordinator(VRF_COORDINATOR).requestRandomNumbers(
      NUM_REQUEST_NUMBER, uint256(keccak256(abi.encodePacked(characterId, block.timestamp, gachaId)))
    );

    // Store the gacha request info
    GachaUtils.storeCharGachaData(characterId, gachaId, requestId, true);
  }

  // This function is called by the VRF Coordinator when the random numbers are ready
  function rawFulfillRandomNumbers(uint256 requestId, uint256[] memory randomNumbers) external override {
    require(_msgSender() == VRF_COORDINATOR, "Only VRF coordinator");

    require(randomNumbers.length == uint256(NUM_REQUEST_NUMBER), "Invalid random numbers length");

    // Find the characterId associated with this requestId
    uint256 characterId = GachaReqChar.get(requestId);
    if (characterId == 0) {
      revert Errors.GachaSystem_InvalidRequestId(requestId);
    }

    // Get the CharGachaV3 record
    CharGachaV3Data memory charGacha = CharGachaV3.get(characterId, requestId);
    if (!charGacha.isPending) {
      revert Errors.GachaSystem_RequestAlreadyFulfilled(requestId);
    }

    // Use the random number to select an item from the gacha
    require(randomNumbers.length > 0, "No random numbers provided");
    uint256 randomNumber = randomNumbers[0];
    uint256 receivedItemId;

    if (charGacha.isLimitedGacha) {
      (receivedItemId, charGacha.gachaEquipmentId) = _handleLimitedGacha(characterId, charGacha.gachaId, randomNumber);
    } else {
      receivedItemId = _handleUnlimitedGacha(characterId, charGacha.gachaId, randomNumber);
      if (ItemV2.getCategory(receivedItemId) == ItemCategoryType.Equipment) {
        charGacha.gachaEquipmentId =
          CharInventory.getItemEquipmentIds(characterId, CharInventory.lengthEquipmentIds(characterId) - 1);
      }
    }

    // Update the CharGachaV3 table with the received item and remove item from gacha
    charGacha.randomNumber = randomNumber;
    charGacha.gachaItemId = receivedItemId;
    charGacha.isPending = false;
    CharGachaV3.set(characterId, requestId, charGacha);
    GachaReqChar.deleteRecord(requestId);
    CharGachaReq.set(characterId, 0);
  }

  // _handleLimitedGacha in this version return pet id and also the equipment id of the pet item added to inventory
  function _handleLimitedGacha(
    uint256 characterId,
    uint256 gachaId,
    uint256 randomNumber
  )
    private
    returns (uint256, uint256)
  {
    GachaPetData memory gachaData = GachaPet.get(gachaId);
    uint256 randomIndex = randomNumber % gachaData.petIds.length;
    uint256 receivedItemId = gachaData.petIds[randomIndex];

    // Remove the item from the gacha pool
    GachaIndexUtils.removeItem(gachaId, receivedItemId);
    // Current gacha is PET gacha
    // This logic is for PET gacha only

    // Pet gacha case
    CharacterItemUtils.addNewItem(characterId, PET_ITEM_ID, 1); // add pet item to inventory
    // Bind the equipmentId of the pet item to the petId (receivedItemId) for later use in pet system
    uint256 lastEquipmentId =
      CharInventory.getItemEquipmentIds(characterId, CharInventory.lengthEquipmentIds(characterId) - 1);
    EquipmentPet.set(lastEquipmentId, receivedItemId); // map equipmentId to petId

    return (receivedItemId, lastEquipmentId);
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
}
