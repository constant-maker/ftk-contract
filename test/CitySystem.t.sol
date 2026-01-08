pragma solidity >=0.8.24;

import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { WelcomeSystemFixture } from "@fixtures/WelcomeSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";
import { console2 } from "forge-std/console2.sol";
import {
  KingElection,
  CharInfo,
  CharStats,
  CharStats2,
  CharCurrentStats,
  CharCurrentStatsData,
  CharRole,
  CharRoleCounter,
  CResourceRequire,
  CityVault,
  RestrictLocV2,
  TileInfo3,
  CityCounter,
  City,
  CityData,
  CharFund,
  CVaultHistoryV3,
  CVaultHistoryV3Data,
  CharOtherItem,
  CharFund,
  CityVault2,
  CharPositionV2,
  CharPositionV2Data,
  CharPosition,
  CharPositionData,
  CharNextPosition,
  CharNextPositionData,
  CityMoveHistory,
  CharVaultWithdraw,
  CharVaultWithdrawData,
  KingSetting2
} from "@codegen/index.sol";
import { RoleType } from "@codegen/common.sol";
import { CharacterPositionUtils, InventoryItemUtils } from "@utils/index.sol";

contract CitySystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address candidate = makeAddr("candidate");
  uint256 candidateId;

  address voter = makeAddr("voter");
  uint256 voterId;

  address voter2 = makeAddr("voter2");
  uint256 voter2Id;

  uint32 constant KING_MIN_FAME_REQUIRE = 2000;
  uint32 constant VOTER_MIN_FAME_REQUIRE = 1050;
  uint32 constant TERM_DURATION = 1_209_600; // 14 days in seconds
  uint32 constant OFFSET_DURATION = 172_800; // 2 days in seconds
  uint256 constant KING_ACHIEVEMENT_ID = 10;

  uint256 cityId = 1;
  int32 newCityX = -10;
  int32 newCityY = -5;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    candidateId = _createDefaultCharacter(candidate);
    _claimWelcomePackages(candidate, candidateId);

    voterId = _createCharacterWithName(voter, "abc");
    _claimWelcomePackages(voter, voterId);

    voter2Id = _createCharacterWithNameAndKingdomId(voter2, "123", 2);
    _claimWelcomePackages(voter2, voter2Id);
  }

  function test_CitySystem() external {
    vm.warp(10_000_000);
    // test revert set city place
    vm.expectRevert(); // must be in city
    vm.startPrank(candidate);
    world.app__setNewCity(candidateId, newCityX, newCityY, "New City");
    vm.stopPrank();

    uint256[] memory candidateIds;
    uint32[] memory votesReceived;

    vm.startPrank(worldDeployer);
    CityCounter.setCounter(4);
    KingElection.set(1, candidateId, block.timestamp + 10_000, candidateIds, votesReceived);
    CityVault.setAmount(cityId, 1, 1000);
    CityVault.setAmount(cityId, 2, 1000);
    CityVault.setAmount(cityId, 3, 1000);
    uint256[] memory resourceIds = new uint256[](3);
    resourceIds[0] = 1;
    resourceIds[1] = 2;
    resourceIds[2] = 3;
    uint32[] memory amounts = new uint32[](3);
    amounts[0] = 100;
    amounts[1] = 200;
    amounts[2] = 10;
    CResourceRequire.set(1, resourceIds, amounts);
    CResourceRequire.set(2, resourceIds, amounts);
    CResourceRequire.set(3, resourceIds, amounts);
    vm.stopPrank();

    uint32[] memory withdrawAmounts = new uint32[](3);
    withdrawAmounts[0] = 300;
    withdrawAmounts[1] = 600;
    withdrawAmounts[2] = 33;

    // test withdraw resource from city vault
    // revert - not the keeper
    vm.expectRevert();
    vm.startPrank(voter);
    world.app__withdrawItemFromCity(voterId, cityId, resourceIds, withdrawAmounts);
    vm.stopPrank();

    vm.startPrank(candidate);
    world.app__setRole(candidateId, voterId, RoleType.None);
    vm.stopPrank();

    RoleType voterRole = CharRole.getRoleType(voterId);
    assertEq(uint8(voterRole), uint8(RoleType.None));

    vm.startPrank(worldDeployer);
    CharStats.setLevel(voterId, 80);
    vm.stopPrank();

    CharCurrentStatsData memory prevVoterCurrentStats = CharCurrentStats.get(voterId);
    vm.startPrank(candidate);
    world.app__setRole(candidateId, voterId, RoleType.VaultKeeper);
    vm.stopPrank();

    // achievement give each attribute 1 point
    assertEq(CharCurrentStats.getAtk(voterId), prevVoterCurrentStats.atk + 1);
    assertEq(CharRoleCounter.getCount(1, RoleType.VaultKeeper), 1);
    assertEq(uint8(CharRole.getRoleType(voterId)), uint8(RoleType.VaultKeeper));

    // withdraw resource
    vm.startPrank(voter);
    world.app__withdrawItemFromCity(voterId, cityId, resourceIds, withdrawAmounts);
    vm.stopPrank();
    console2.log("test vault history 1");
    CVaultHistoryV3Data memory history = CVaultHistoryV3.get(cityId, 1);
    assertEq(history.itemIds[0], 1);
    assertEq(history.amounts[0], 300);
    assertFalse(history.isContributed);
    assertEq(history.itemIds[2], 3);
    assertEq(history.amounts[2], 33);
    console2.log("test vault history 2");

    assertEq(CharOtherItem.getAmount(voterId, 1), 300);
    assertEq(CharOtherItem.getAmount(voterId, 3), 33);
    assertEq(CityVault.getAmount(cityId, 1), 700);

    // test set new city
    vm.expectRevert(); // the coordinates must belong to the kingdom
    vm.startPrank(candidate);
    world.app__setNewCity(candidateId, newCityX, newCityY - 1, "New City");
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    TileInfo3.setKingdomId(newCityX, newCityY, 1);
    TileInfo3.setKingdomId(newCityX, newCityY + 1, 1);
    RestrictLocV2.set(newCityX, newCityY - 1, 0, true);
    vm.stopPrank();

    vm.expectRevert(); // the coordinates must be valid
    vm.startPrank(candidate);
    world.app__setNewCity(candidateId, newCityX, newCityY - 1, "New City");
    vm.stopPrank();

    vm.startPrank(candidate);
    world.app__setNewCity(candidateId, newCityX, newCityY, "New City");
    vm.stopPrank();
    assertEq(CityCounter.getCounter(), 5);
    uint256 newCityId = 5;
    CityData memory city = City.get(newCityId);
    assertEq(city.x, newCityX);
    assertEq(city.y, newCityY);
    assertEq(city.level, 0);

    console2.log("place new city but revert because this place already had a city");
    vm.expectRevert();
    vm.startPrank(candidate);
    world.app__setNewCity(candidateId, newCityX, newCityY, "New City");
    vm.stopPrank();

    console2.log("test healing");
    vm.startPrank(worldDeployer);
    CharStats.setHp(voterId, 500);
    CharCurrentStats.setHp(voterId, 500 - 102);
    CharFund.setGold(voterId, 100_200);
    vm.stopPrank();
    // vm.expectRevert(); // city level too low
    vm.startPrank(voter);
    world.app__cityHealing(voterId, cityId);
    vm.stopPrank();

    console2.log("test upgrade city");
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(candidateId, newCityX, newCityY);
    CharacterPositionUtils.moveToLocation(voterId, newCityX, newCityY);
    CharStats2.setFame(voterId, 1050);
    City.setLevel(cityId, 3);
    TileInfo3.setKingdomId(newCityX, newCityY + 5, CharInfo.getKingdomId(candidateId));
    vm.stopPrank();
    vm.startPrank(voter);
    world.app__contributeItemToCity(voterId, newCityId, resourceIds, withdrawAmounts, 100_000);
    vm.stopPrank();
    history = CVaultHistoryV3.get(newCityId, 1);
    assertTrue(history.isContributed);
    assertEq(history.itemIds[0], 1);
    assertEq(history.amounts[0], 300);
    assertEq(history.gold, 100_000);

    console2.log("move city");
    vm.startPrank(candidate);
    world.app__moveCity(candidateId, newCityX, newCityY + 5, newCityId);
    vm.stopPrank();

    console2.log("move city back old place");
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(candidateId, newCityX, newCityY + 5);
    vm.stopPrank();

    vm.expectRevert(); // must wait for cooldown
    vm.startPrank(candidate);
    world.app__moveCity(candidateId, newCityX, newCityY, newCityId);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CityMoveHistory.deleteRecord(newCityId);
    vm.stopPrank();

    vm.startPrank(candidate);
    world.app__moveCity(candidateId, newCityX, newCityY, newCityId);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(candidateId, newCityX, newCityY);
    vm.stopPrank();

    assertEq(CityVault2.getGold(newCityId), 96_000);

    console2.log("upgrade city to level 1");
    vm.startPrank(candidate);
    world.app__upgradeCity(candidateId, newCityId);
    vm.stopPrank();
    city = City.get(newCityId);
    assertEq(city.level, 1);
    assertEq(CityVault.getAmount(newCityId, 1), 200);
    assertEq(CityVault.getAmount(newCityId, 2), 400);
    assertEq(CityVault.getAmount(newCityId, 3), 23);

    console2.log("re-test healing");
    vm.startPrank(voter);
    world.app__cityHealing(voterId, newCityId);
    vm.stopPrank();

    assertEq(CharCurrentStats.getHp(voterId), 500);
    assertEq(CharFund.getGold(voterId), 197);

    vm.startPrank(candidate);
    world.app__upgradeCity(candidateId, newCityId);
    world.app__upgradeCity(candidateId, newCityId);
    vm.stopPrank();
    city = City.get(newCityId);
    assertEq(city.level, 3);
    assertEq(CityVault.getAmount(newCityId, 3), 3);

    console2.log("test teleport");
    uint32 currentCapitalGold = CityVault2.getGold(cityId);
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToCapital(voterId);
    vm.stopPrank();
    CharPositionV2Data memory posV2 = CharPositionV2.get(voterId);
    CharPositionData memory pos = CharPosition.get(voterId);
    CharNextPositionData memory nextPos = CharNextPosition.get(voterId);
    assertEq(pos.x, posV2.x);
    assertEq(pos.y, posV2.y);
    assertEq(nextPos.x, posV2.nextX);
    assertEq(nextPos.y, posV2.nextY);
    assertEq(nextPos.arriveTimestamp, posV2.arriveTimestamp);
    vm.startPrank(voter);
    world.app__cityTeleport(voterId, cityId, newCityId);
    vm.stopPrank();
    assertEq(CharFund.getGold(voterId), 182);
    CharPositionData memory position = CharacterPositionUtils.currentPosition(voterId);
    assertEq(position.x, newCityX);
    assertEq(position.y, newCityY);
    assertEq(CityVault2.getGold(cityId), currentCapitalGold + 15);

    console2.log("test save point");
    vm.startPrank(voter);
    world.app__citySavePoint(voterId, newCityId);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(candidateId, newCityX, newCityY + 1);
    CharacterPositionUtils.moveToLocation(voterId, newCityX, newCityY + 1);
    CharCurrentStats.setAgi(candidateId, 1000);
    CharCurrentStats.setAtk(candidateId, 1000);
    vm.stopPrank();
    vm.warp(block.timestamp + 100);
    vm.startPrank(candidate);
    world.app__battlePvP(candidateId, voterId);
    vm.stopPrank();

    position = CharacterPositionUtils.currentPosition(voterId);
    assertEq(position.x, newCityX);
    assertEq(position.y, newCityY);

    CityData memory capital = City.get(cityId);
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(voterId, capital.x, capital.y);
    vm.stopPrank();
    vm.startPrank(voter);
    world.app__citySavePoint(voterId, cityId);
    vm.stopPrank();
    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(voterId, newCityX, newCityY);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharacterPositionUtils.moveToLocation(candidateId, newCityX, newCityY + 1);
    CharacterPositionUtils.moveToLocation(voterId, newCityX, newCityY + 1);
    vm.stopPrank();
    vm.warp(block.timestamp + 100);
    vm.startPrank(candidate);
    world.app__battlePvP(candidateId, voterId);
    vm.stopPrank();
    city = City.get(cityId);
    position = CharacterPositionUtils.currentPosition(voterId);
    assertEq(position.x, city.x);
    assertEq(position.y, city.y);
  }

  function test_WithdrawLimit() external {
    uint256[] memory candidateIds;
    uint32[] memory votesReceived;

    vm.startPrank(worldDeployer);
    KingElection.set(1, candidateId, block.timestamp + 10_000, candidateIds, votesReceived);
    CityVault.setAmount(cityId, 1, 1000);
    CityVault.setAmount(cityId, 2, 1000);
    CityVault.setAmount(cityId, 3, 1000);
    CharStats.setLevel(voterId, 80);
    KingSetting2.setWithdrawWeightLimit(1, 2000);
    vm.stopPrank();

    vm.startPrank(candidate);
    world.app__setRole(candidateId, voterId, RoleType.VaultKeeper);
    vm.stopPrank();

    uint256[] memory resourceIds = new uint256[](3);
    resourceIds[0] = 1;
    resourceIds[1] = 2;
    resourceIds[2] = 3;

    uint32[] memory withdrawAmounts = new uint32[](3);
    withdrawAmounts[0] = 1000;
    withdrawAmounts[1] = 1000;
    withdrawAmounts[2] = 1000;

    vm.expectRevert(); // exceed daily withdraw limit
    vm.startPrank(voter);
    world.app__withdrawItemFromCity(voterId, cityId, resourceIds, withdrawAmounts);
    vm.stopPrank();

    withdrawAmounts[0] = 100;
    withdrawAmounts[1] = 100;
    withdrawAmounts[2] = 100;

    vm.startPrank(voter);
    world.app__withdrawItemFromCity(voterId, cityId, resourceIds, withdrawAmounts);
    vm.stopPrank();

    CharVaultWithdrawData memory cvw = CharVaultWithdraw.get(voterId);
    assertEq(cvw.weightQuota, 1700); // 2000 - (100*1 + 100*1 + 100*1) = 1700
    uint256 ts = cvw.markTimestamp;

    vm.warp(ts + 1 days + 1);
    withdrawAmounts[0] = 10;
    withdrawAmounts[1] = 10;
    withdrawAmounts[2] = 10;
    vm.startPrank(voter);
    world.app__withdrawItemFromCity(voterId, cityId, resourceIds, withdrawAmounts);
    vm.stopPrank();
    cvw = CharVaultWithdraw.get(voterId);
    assertEq(cvw.weightQuota, 1970); // reset to 2000 - (10*1 + 10*1 + 10*1) = 1970
    assertEq(cvw.markTimestamp, ts + 1 days + 1);

    vm.warp(ts + 1);
    vm.startPrank(voter);
    world.app__withdrawItemFromCity(voterId, cityId, resourceIds, withdrawAmounts);
    vm.stopPrank();
    cvw = CharVaultWithdraw.get(voterId);
    assertEq(cvw.weightQuota, 1940); // 1970 - (10*1 + 10*1 + 10*1) = 1940
    assertEq(cvw.markTimestamp, ts + 1 days + 1); // no change
  }
}
