pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharGacha, CharGachaData, Gacha, GachaData, GachaReqChar } from "@codegen/index.sol";
import { GachaType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { GachaUtils } from "@utils/GachaUtils.sol";

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

  function requestGacha(uint256 characterId, uint256 gachaId) public onlyAuthorizedWallet(characterId) {
    // Validate gacha
    GachaData memory gacha = Gacha.get(gachaId);
    if (gacha.itemIds.length == 0) {
      revert Errors.Gacha_NoItemLeft(gachaId);
    }

    if (block.timestamp < gacha.startTime || block.timestamp > gacha.endTime) {
      revert Errors.Gacha_InactiveGacha(gachaId);
    }

    // If gacha has only one item, directly give it to character
    if (gacha.itemIds.length == 1) {
      uint256 receivedItemId = gacha.itemIds[0];
      CharGacha.set(characterId, 0, 0, gachaId, receivedItemId, false, block.timestamp);
      GachaUtils.removeItem(gachaId, receivedItemId);
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
  }

  // This function is called by the VRF Coordinator when the random numbers are ready
  function rawFulfillRandomNumbers(uint256 requestId, uint256[] memory randomNumbers) external override {
    require(msg.sender == VRF_COORDINATOR, "Only VRF coordinator");

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
    GachaData memory gachaData = Gacha.get(charGacha.gachaId);

    // Use the random number to select an item from the gacha
    uint256 randomNumber = randomNumbers[0];
    uint256 randomIndex = (randomNumber * block.timestamp) % gachaData.itemIds.length; // ensure we use number > itemIds
      // length
    uint256 receivedItemId = gachaData.itemIds[randomIndex];

    // Update the CharGacha table with the received item and remove item from gacha
    charGacha.randomNumber = randomNumber;
    charGacha.gachaItemId = receivedItemId;
    charGacha.isPending = false;
    CharGacha.set(characterId, requestId, charGacha);
    GachaUtils.removeItem(charGacha.gachaId, receivedItemId);
    GachaReqChar.deleteRecord(requestId);
  }
}
