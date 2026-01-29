// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import {
  GachaV5,
  GachaV5Data,
  GachaPet,
  GachaPetData,
  CharGachaV2,
  CharGachaV2Data,
  GachaReqChar,
  GachaCounter,
  CharOtherItem,
  CharInventory,
  Equipment,
  EquipmentPet,
  CharGachaReq
} from "@codegen/index.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { GachaSystem } from "@src/systems/GachaSystem.sol";
import { SystemUtils, GachaUtils, InventoryItemUtils } from "@utils/index.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { Balances } from "@latticexyz/world/src/codegen/tables/Balances.sol";
import { WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

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

  function test_LimitedGacha() public {
    uint256 gachaId = GachaCounter.get() + 1;

    GachaPetData memory gachaData = GachaPetData({
      startTime: block.timestamp,
      endTime: block.timestamp + 30 days,
      ticketValue: 0.001 ether,
      ticketItemId: 1,
      petIds: new uint256[](0)
    });

    assertEq(gachaId, 1);

    vm.startPrank(worldDeployer);
    GachaPet.set(gachaId, gachaData);
    GachaCounter.set(gachaId);

    for (uint256 i; i < 10; ++i) {
      uint256 itemId = i + 1;
      GachaUtils.addItem(gachaId, itemId);
    }

    vm.stopPrank();

    // ── simulate VRF request (normally called by gacha system)

    ResourceId gachaSystemResourceId = SystemUtils.getRootSystemId("GachaSystem");
    bytes memory data = abi.encodeCall(GachaSystem.requestPetGacha, (characterId, gachaId));

    vm.deal(player, 1 ether);

    vm.startPrank(player);
    world.call{ value: 0.001 ether }(gachaSystemResourceId, data);
    vm.stopPrank();

    assertTrue(CharGachaReq.get(characterId) == 1);

    uint256 requestId = 1; // first request

    uint256 worldBalance = Balances.getBalance(WorldResourceIdLib.encodeNamespace(""));
    assertEq(worldBalance, 0.0011 ether); // including spawn fee
    // assert player balance decreased
    assertEq(player.balance, 1 ether - 0.001 ether);

    // ── fulfill randomness
    CharGachaV2Data memory charGacha = CharGachaV2.get(characterId, requestId);
    assertEq(GachaReqChar.get(requestId), characterId);

    uint256[] memory randomNumbers = new uint256[](1);
    randomNumbers[0] = 123; // example random number
    MockVRFCoordinator(VRF_COORDINATOR).fulfill(requestId, randomNumbers);

    charGacha = CharGachaV2.get(characterId, requestId);
    assertFalse(charGacha.isPending);
    assertEq(charGacha.randomNumber, 123);
    assertEq(charGacha.gachaItemId, 4); // index 123 % 10 = 3 -> itemId = 4
    assertTrue(CharGachaReq.get(characterId) == 0);

    uint256[] memory equipmentIds = CharInventory.getEquipmentIds(characterId);
    uint256 lastEquipmentId = equipmentIds[equipmentIds.length - 1];
    assertTrue(EquipmentPet.getPetId(lastEquipmentId) == charGacha.gachaItemId); // itemId 4 is a pet id not a normal
      // item id
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

    GachaV5Data memory gachaData = GachaV5Data({
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
    GachaV5.set(gachaId, gachaData);
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
    CharGachaV2Data memory charGacha = CharGachaV2.get(characterId, requestId);
    assertEq(GachaReqChar.get(requestId), characterId);

    uint256[] memory randomNumbers = new uint256[](1);
    randomNumbers[0] = 123; // example random number
    MockVRFCoordinator(VRF_COORDINATOR).fulfill(requestId, randomNumbers);

    charGacha = CharGachaV2.get(characterId, requestId);
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

    GachaV5Data memory gachaData = GachaV5Data({
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
    GachaV5.set(gachaId, gachaData);
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
    CharGachaV2Data memory charGacha = CharGachaV2.get(characterId, requestId);
    assertEq(GachaReqChar.get(requestId), characterId);

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

    charGacha = CharGachaV2.get(characterId, requestId);
    assertTrue(charGacha.timestamp == block.timestamp);

    uint256[] memory randomNumbers = new uint256[](1);
    randomNumbers[0] = 123; // example random number
    MockVRFCoordinator(VRF_COORDINATOR).fulfill(requestId, randomNumbers);

    charGacha = CharGachaV2.get(characterId, requestId);
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
