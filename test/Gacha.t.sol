// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Gacha, GachaData, CharGacha, CharGachaData, GachaReqChar, GachaCounter } from "@codegen/index.sol";
import { GachaType } from "@codegen/common.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { GachaSystem } from "@src/systems/GachaSystem.sol";
import { SystemUtils, GachaUtils } from "@utils/index.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

// ─────────────────────────────────────────────────────────────
// VRF interfaces
// ─────────────────────────────────────────────────────────────

interface IVRFCoordinator {
  function requestRandomNumbers(uint32 numNumbers, uint256 seed) external returns (uint256 requestId);
}

interface IVRFConsumer {
  function rawFulfillRandomNumbers(uint256 requestId, uint256[] memory randomNumbers) external;
}

// ─────────────────────────────────────────────────────────────
// Mock VRF Coordinator
// ─────────────────────────────────────────────────────────────

contract MockVRFCoordinator is IVRFCoordinator {
  // requestId => consumer
  mapping(uint256 => address) public consumers;

  function requestRandomNumbers(uint32, uint256) external returns (uint256 requestId) {
    requestId = 1; // always return 1 for simplicity
    consumers[1] = msg.sender;
    console2.log("MockVRFCoordinator: requestRandomNumbers caller", msg.sender);
    return requestId;
  }

  function fulfill(uint256 requestId, uint256[] memory randomNumbers) external {
    address consumer = consumers[requestId];
    require(consumer != address(0), "invalid request");

    IVRFConsumer(consumer).rawFulfillRandomNumbers(requestId, randomNumbers);
  }
}

// ─────────────────────────────────────────────────────────────
// Test
// ─────────────────────────────────────────────────────────────

contract GachaTest is Test, WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address constant VRF_COORDINATOR = 0x9d57aB4517ba97349551C876a01a7580B1338909;

  address player = makeAddr("player");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    // ── mock VRF coordinator at fixed address
    MockVRFCoordinator mock = new MockVRFCoordinator();
    vm.etch(VRF_COORDINATOR, address(mock).code);

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_Gacha() public {
    uint256 gachaId = GachaCounter.get() + 1;

    GachaData memory gachaData = GachaData({
      gachaType: GachaType.Pet,
      startTime: block.timestamp,
      endTime: block.timestamp + 30 days,
      itemIds: new uint256[](0)
    });

    assertEq(gachaId, 1);

    vm.startPrank(worldDeployer);
    Gacha.set(gachaId, gachaData);
    GachaCounter.set(gachaId);

    for (uint256 i; i < 10; ++i) {
      uint256 itemId = i + 1;
      GachaUtils.addItem(gachaId, itemId);
    }

    vm.stopPrank();

    // ── simulate VRF request (normally called by gacha system)

    ResourceId gachaSystemResourceId = SystemUtils.getRootSystemId("GachaSystem");
    bytes memory data = abi.encodeCall(GachaSystem.requestGacha, (characterId, gachaId));

    vm.startPrank(player);
    world.call(gachaSystemResourceId, data);
    vm.stopPrank();

    uint256 requestId = 1; // first request

    // ── fulfill randomness
    CharGachaData memory charGacha = CharGacha.get(characterId, requestId);
    assertEq(GachaReqChar.get(requestId), characterId);

    uint256[] memory randomNumbers = new uint256[](1);
    randomNumbers[0] = 123; // example random number
    MockVRFCoordinator(VRF_COORDINATOR).fulfill(requestId, randomNumbers);

    charGacha = CharGacha.get(characterId, requestId);
    assertFalse(charGacha.isPending);
    assertEq(charGacha.randomNumber, 123);
    assertEq(charGacha.gachaItemId, 4); // index 123 % 10 = 3 -> itemId = 4
  }
}
