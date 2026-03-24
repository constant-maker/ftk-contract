// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import {
  Gacha,
  GachaData,
  CharGacha,
  CharGachaData,
  GachaReqInfo,
  GachaCounter,
  CharOtherItem,
  CharInventory,
  Equipment,
  CharGachaReq,
  CharFund,
  CrystalFee,
  PetCpnInfo,
  PetCpn,
  EPetStats,
  EPetStatsData
} from "@codegen/index.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { GachaSystem } from "@src/systems/GachaSystem.sol";
import { SystemUtils, InventoryItemUtils } from "@utils/index.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { Balances } from "@latticexyz/world/src/codegen/tables/Balances.sol";
import { WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { PetComponentType } from "@codegen/common.sol";

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
  address constant VRF_COORDINATOR = 0xc0d49A572cF25aC3e9ae21B939e8B619b39291Ea;

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

  function test_UnlimitedGacha() public {
    uint256 gachaId = GachaCounter.get() + 1;

    uint256[] memory itemIds = new uint256[](2);
    itemIds[0] = 361;
    itemIds[1] = 362;

    uint32[] memory amounts = new uint32[](2);
    amounts[0] = 2;
    amounts[1] = 2;

    uint16[] memory percents = new uint16[](2);
    percents[0] = 5000; // 50%
    percents[1] = 5000; // 50%

    GachaData memory gachaData = GachaData({
      startTime: block.timestamp,
      ticketValue: 0,
      ticketItemId: 1,
      itemIds: itemIds,
      amounts: amounts,
      percents: percents
    });

    assertEq(gachaId, 1);

    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, 1, 1);
    Gacha.set(gachaId, gachaData);
    GachaCounter.set(gachaId);

    vm.stopPrank();

    // ── simulate VRF request (normally called by gacha system)

    ResourceId gachaSystemResourceId = SystemUtils.getRootSystemId("GachaSystem");
    bytes memory data = abi.encodeCall(GachaSystem.requestGacha, (characterId, gachaId));

    vm.startPrank(player);
    world.call(gachaSystemResourceId, data);
    vm.stopPrank();

    assertTrue(CharGachaReq.get(characterId) > 0);

    uint256 requestId = CharGachaReq.get(characterId);

    // ── fulfill randomness
    CharGachaData memory charGacha = CharGacha.get(characterId, requestId);
    assertEq(GachaReqInfo.getCharacterId(requestId), characterId);

    uint256[] memory randomNumbers = new uint256[](1);
    randomNumbers[0] = 123; // example random number
    MockVRFCoordinator(VRF_COORDINATOR).fulfill(requestId, randomNumbers);

    charGacha = CharGacha.get(characterId, requestId);
    assertFalse(charGacha.isPending);
    assertEq(charGacha.randomNumber, 123);
    assertTrue(charGacha.gachaItemId == 361 || charGacha.gachaItemId == 362);
    assertEq(CharOtherItem.getAmount(characterId, 1), 0);
    assertTrue(CharGachaReq.get(characterId) == 0);
    uint256[] memory equipmentIds = CharInventory.getEquipmentIds(characterId);
    uint256 lastEquipmentId = equipmentIds[equipmentIds.length - 1];
    assertTrue(Equipment.getItemId(lastEquipmentId) == charGacha.gachaItemId);
    uint256 prevLastEquipmentId = equipmentIds[equipmentIds.length - 2];
    assertTrue(Equipment.getItemId(prevLastEquipmentId) == charGacha.gachaItemId);
  }

  function test_PetGacha() public {
    console2.log("Verify data onchain");
    // assert data
    uint16[] memory componentRatios = PetCpnInfo.get(436, PetComponentType.Bag);
    assertEq(componentRatios.length, 1);
    assertEq(componentRatios[0], 10_000);

    componentRatios = PetCpnInfo.get(436, PetComponentType.Eye);
    assertEq(componentRatios.length, 35);
    assertEq(componentRatios[0], 0);
    assertEq(componentRatios[1], 294);

    componentRatios = PetCpnInfo.get(464, PetComponentType.Bag);
    assertEq(componentRatios.length, 5);
    assertEq(componentRatios[0], 9000);
    assertEq(componentRatios[1], 250);

    console2.log("Setup gacha data and make gacha request");

    uint256 gachaId = GachaCounter.get() + 1;

    uint256[] memory itemIds = new uint256[](3);
    itemIds[0] = 436;
    itemIds[1] = 464;
    itemIds[2] = 465;

    uint32[] memory amounts = new uint32[](3);
    amounts[0] = 1;
    amounts[1] = 1;
    amounts[2] = 1;

    uint16[] memory percents = new uint16[](3);
    percents[0] = 5000; // 50%
    percents[1] = 3000; // 30%
    percents[2] = 2000; // 20%

    GachaData memory gachaData = GachaData({
      startTime: block.timestamp,
      ticketValue: 0,
      ticketItemId: 437,
      itemIds: itemIds,
      amounts: amounts,
      percents: percents
    });

    console2.log("Assert gachaId");
    assertEq(gachaId, 1);

    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, 437, 1);
    Gacha.set(gachaId, gachaData);
    GachaCounter.set(gachaId);

    vm.stopPrank();

    // ── simulate VRF request (normally called by gacha system)

    ResourceId gachaSystemResourceId = SystemUtils.getRootSystemId("GachaSystem");
    bytes memory data = abi.encodeCall(GachaSystem.requestGacha, (characterId, gachaId));

    vm.startPrank(player);
    world.call(gachaSystemResourceId, data);
    vm.stopPrank();

    assertTrue(CharGachaReq.get(characterId) > 0);

    uint256 requestId = CharGachaReq.get(characterId);

    // ── fulfill randomness
    CharGachaData memory charGacha = CharGacha.get(characterId, requestId);
    assertEq(GachaReqInfo.getCharacterId(requestId), characterId);

    uint256[] memory randomNumbers = new uint256[](1);
    randomNumbers[0] = 123; // example random number
    MockVRFCoordinator(VRF_COORDINATOR).fulfill(requestId, randomNumbers);

    console2.log("Assert data after gacha fulfillment");
    charGacha = CharGacha.get(characterId, requestId);
    assertFalse(charGacha.isPending);
    assertEq(charGacha.randomNumber, 123);
    assertTrue(charGacha.gachaItemId == 436 || charGacha.gachaItemId == 464 || charGacha.gachaItemId == 465);
    assertEq(CharOtherItem.getAmount(characterId, 1), 0);
    assertTrue(CharGachaReq.get(characterId) == 0);
    uint256[] memory equipmentIds = CharInventory.getEquipmentIds(characterId);
    uint256 lastEquipmentId = equipmentIds[equipmentIds.length - 1];
    assertTrue(Equipment.getItemId(lastEquipmentId) == charGacha.gachaItemId);

    console2.log("Assert pet equipment data");
    uint16[] memory componentValues = PetCpn.get(lastEquipmentId);
    for (uint256 i = 0; i < componentValues.length; i++) {
      console2.log("componentValues", componentValues[i]);
    }
    assertGt(componentValues[1], 0);
    assertEq(componentValues.length, 9);
    EPetStatsData memory petStats = EPetStats.get(lastEquipmentId);
    assertTrue(petStats.atk >= 1 && petStats.atk <= 5);
    assertTrue(petStats.def >= 1 && petStats.def <= 5);
    assertTrue(petStats.agi >= 1 && petStats.agi <= 5);
  }

  function test_VRF_DoesNotResponseInACertainTime() public {
    uint256 gachaId = GachaCounter.get() + 1;

    uint256[] memory itemIds = new uint256[](2);
    itemIds[0] = 361;
    itemIds[1] = 362;

    uint32[] memory amounts = new uint32[](2);
    amounts[0] = 2;
    amounts[1] = 2;

    uint16[] memory percents = new uint16[](2);
    percents[0] = 5000; // 50%
    percents[1] = 5000; // 50%

    GachaData memory gachaData = GachaData({
      startTime: block.timestamp,
      ticketValue: 0,
      ticketItemId: 1,
      itemIds: itemIds,
      amounts: amounts,
      percents: percents
    });

    assertEq(gachaId, 1);

    vm.startPrank(worldDeployer);
    InventoryItemUtils.addItem(characterId, 1, 1);
    Gacha.set(gachaId, gachaData);
    GachaCounter.set(gachaId);

    vm.stopPrank();

    // ── simulate VRF request (normally called by gacha system)

    ResourceId gachaSystemResourceId = SystemUtils.getRootSystemId("GachaSystem");
    bytes memory data = abi.encodeCall(GachaSystem.requestGacha, (characterId, gachaId));

    vm.startPrank(player);
    world.call(gachaSystemResourceId, data);
    vm.stopPrank();

    assertTrue(CharGachaReq.get(characterId) > 0);

    uint256 requestId = CharGachaReq.get(characterId);

    // ── fulfill randomness
    CharGachaData memory charGacha = CharGacha.get(characterId, requestId);
    assertEq(GachaReqInfo.getCharacterId(requestId), characterId);

    vm.warp(block.timestamp + 14 seconds);
    // retry gacha request
    data = abi.encodeCall(GachaSystem.renewGachaRequest, (characterId));

    vm.expectRevert();
    vm.startPrank(player);
    world.call(gachaSystemResourceId, data);
    vm.stopPrank();

    vm.warp(block.timestamp + 2 seconds); // warp time to exceed VRF response time limit

    vm.startPrank(player);
    world.call(gachaSystemResourceId, data);
    vm.stopPrank();

    charGacha = CharGacha.get(characterId, requestId);
    assertTrue(charGacha.timestamp == block.timestamp);

    uint256[] memory randomNumbers = new uint256[](1);
    randomNumbers[0] = 123; // example random number
    MockVRFCoordinator(VRF_COORDINATOR).fulfill(requestId, randomNumbers);

    charGacha = CharGacha.get(characterId, requestId);
    assertFalse(charGacha.isPending);
    assertEq(charGacha.randomNumber, 123);
    assertTrue(charGacha.gachaItemId == 361 || charGacha.gachaItemId == 362);
    assertEq(CharOtherItem.getAmount(characterId, 1), 0);
    assertTrue(CharGachaReq.get(characterId) == 0);
    uint256[] memory equipmentIds = CharInventory.getEquipmentIds(characterId);
    uint256 lastEquipmentId = equipmentIds[equipmentIds.length - 1];
    assertTrue(Equipment.getItemId(lastEquipmentId) == charGacha.gachaItemId);
    uint256 prevLastEquipmentId = equipmentIds[equipmentIds.length - 2];
    assertTrue(Equipment.getItemId(prevLastEquipmentId) == charGacha.gachaItemId);

    // retry again should fail since already fulfilled
    data = abi.encodeCall(GachaSystem.renewGachaRequest, (characterId));
    vm.expectRevert();
    vm.startPrank(player);
    world.call(gachaSystemResourceId, data);
    vm.stopPrank();
  }
}
