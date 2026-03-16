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
  GachaReqInfo,
  CharInventory,
  CharGachaReq,
  ItemV2,
  EPetStats,
  PetCpnInfo,
  PetCpn
} from "@codegen/index.sol";
import { Errors } from "@common/index.sol";
import {
  GachaIndexUtils, CharacterItemUtils, InventoryItemUtils, CharacterFundUtils, GachaUtils
} from "@utils/index.sol";
import { ItemCategoryType, PetComponentType, ItemType } from "@codegen/common.sol";

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
    GachaReqInfo.deleteRecord(existingRequestId); // remove old request mapping

    uint256 requestId = IVRFCoordinator(VRF_COORDINATOR).requestRandomNumbers(
      NUM_REQUEST_NUMBER, uint256(keccak256(abi.encode(characterId, block.timestamp, existingRequestId)))
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
      NUM_REQUEST_NUMBER, uint256(keccak256(abi.encode(characterId, block.timestamp, gachaId)))
    );

    // Store the gacha request info
    GachaUtils.storeCharGachaData(characterId, gachaId, requestId, false);
  }

  // This function is called by the VRF Coordinator when the random numbers are ready
  function rawFulfillRandomNumbers(uint256 requestId, uint256[] memory randomNumbers) external override {
    require(_msgSender() == VRF_COORDINATOR, "Only VRF coordinator");

    require(randomNumbers.length == uint256(NUM_REQUEST_NUMBER), "Invalid random numbers length");

    // Find the characterId associated with this requestId
    uint256 characterId = GachaReqInfo.getCharacterId(requestId);
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

    uint256 receivedItemId = _handleUnlimitedGacha(characterId, charGacha.gachaId, randomNumber);
    if (ItemV2.getCategory(receivedItemId) == ItemCategoryType.Equipment) {
      uint256 equipmentId =
        CharInventory.getItemEquipmentIds(characterId, CharInventory.lengthEquipmentIds(characterId) - 1);
      charGacha.gachaEquipmentId = equipmentId;
      if (ItemV2.getItemType(receivedItemId) == ItemType.Pet) {
        _handlePetData(receivedItemId, equipmentId, randomNumber);
      }
    }

    // Update the CharGachaV3 table with the received item and remove item from gacha
    charGacha.randomNumber = randomNumber;
    charGacha.gachaItemId = receivedItemId;
    charGacha.isPending = false;
    CharGachaV3.set(characterId, requestId, charGacha);
    GachaReqInfo.deleteRecord(requestId);
    CharGachaReq.set(characterId, 0);
  }

  function _handleUnlimitedGacha(uint256 characterId, uint256 gachaId, uint256 randomNumber) private returns (uint256) {
    GachaV5Data memory gachaData = GachaV5.get(gachaId);
    uint256 r = randomNumber % TOTAL_PERCENT;
    uint256 cumulativePercent;
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

  /// @dev Generate pet stats and components based on the received pet item and its associated equipment
  function _handlePetData(uint256 petItemId, uint256 petEquipmentId, uint256 randomNumber) private {
    // Generate pet stats (atk, def, agi) between 1 and 5
    // 1 2 3 are just seed, magic number
    uint256 atk = (uint256(keccak256(abi.encode(petEquipmentId, 1, randomNumber))) % 5) + 1;
    uint256 def = (uint256(keccak256(abi.encode(petEquipmentId, 2, randomNumber))) % 5) + 1;
    uint256 agi = (uint256(keccak256(abi.encode(petEquipmentId, 3, randomNumber))) % 5) + 1;

    // Store pet stats in EPetStats table
    EPetStats.set(petEquipmentId, uint16(atk), uint16(def), uint16(agi));

    // Generate pet components
    uint8 maxComponentType = uint8(PetComponentType.Weapon);
    uint8[] memory componentTypes = new  uint8[](maxComponentType + 1);
    uint16[] memory componentValues = new  uint16[](maxComponentType + 1);

    for (uint8 i = 0; i <= maxComponentType; i++) {
      componentTypes[i] = i;
      uint16[] memory componentRatios = PetCpnInfo.get(petItemId, PetComponentType(i));
      uint256 eR = uint256(keccak256(abi.encode(petEquipmentId, i, randomNumber))) % TOTAL_PERCENT;
      uint256 cumulativeRatio;
      uint256 ratioLen = componentRatios.length;
      for (uint16 j = 0; j < ratioLen; j++) {
        uint16 cRatio = componentRatios[j];
        if (cRatio == 0) {
          // skip if ratio is 0, not all pet items have all component types
          continue;
        }
        cumulativeRatio += cRatio;
        if (eR < cumulativeRatio) {
          componentValues[i] = j;
          break;
        }
      }
    }

    // Store pet components in PetCpn table
    PetCpn.set(petEquipmentId, componentTypes, componentValues);
  }
}
