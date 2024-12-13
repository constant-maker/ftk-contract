pragma solidity >=0.8.24;

import {
  Monster,
  MonsterData,
  MonsterStats,
  MonsterStatsData,
  TileInfo3,
  TileInfo3Data,
  MonsterLocation,
  MonsterLocationData
} from "@codegen/index.sol";
import { AdvantageType } from "@codegen/common.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";

contract MonsterTest is WorldFixture {
  function setUp() public virtual override(WorldFixture) {
    WorldFixture.setUp();
  }

  function test_HaveData() external {
    MonsterData memory monsterData = Monster.get(1);
    assertEq(monsterData.name, "Moonhowler");
    assertEq(monsterData.itemIds.length, 1);
    assertEq(monsterData.itemIds[0], 16);
    assertEq(monsterData.itemAmounts.length, 1);
    assertEq(monsterData.itemAmounts[0], 1);

    MonsterStatsData memory monsterStatsData = MonsterStats.get(1);
    assertEq(monsterStatsData.sp, 3);

    monsterData = Monster.get(2);
    assertEq(monsterData.name, "Grizzlor");
    assertEq(monsterData.itemIds.length, 2);
    assertEq(monsterData.itemIds[0], 16);
    assertEq(monsterData.itemIds[1], 17);
    assertEq(monsterData.skillIds[1], 4);
    assertEq(monsterData.itemAmounts.length, 2);
    assertEq(monsterData.itemAmounts[0], 1);
    assertEq(monsterData.itemAmounts[1], 1);

    TileInfo3Data memory tileInfo = TileInfo3.get(30, -35);
    assertEq(tileInfo.monsterIds.length, 2);
    assertEq(tileInfo.monsterIds[1], 2);

    MonsterLocationData memory monsterLocation = MonsterLocation.get(30, -35, 2);
    assertEq(monsterLocation.level, 2);
    assertTrue(monsterLocation.advantageType == AdvantageType.Green);
  }
}
