pragma solidity >=0.8.24;

import { Vm } from "forge-std/Vm.sol";
import { CharSkill, Skill, SkillData } from "@codegen/index.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";
import { console2 } from "forge-std/console2.sol";

contract SkillTest is WorldFixture, SpawnSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture) {
    WorldFixture.setUp();
    console2.log("set up done");
    characterId = _createDefaultCharacter(player);
    console2.log("create done");
  }

  function test_UpdateSkill() external {
    uint256[5] memory currentSkillIds = CharSkill.get(characterId);
    assertEq(currentSkillIds[0], 0);
    assertEq(currentSkillIds[1], 0);
    assertEq(currentSkillIds[2], 0);
    assertEq(currentSkillIds[3], 0);
    uint256[5] memory skillIds = [uint256(0), 1, 2, 3, 0];
    vm.prank(player);
    world.app__updateSkillOrder(characterId, skillIds);

    currentSkillIds = CharSkill.get(characterId);
    assertEq(currentSkillIds[0], 0);
    assertEq(currentSkillIds[1], 1);
    assertEq(currentSkillIds[2], 2);
    assertEq(currentSkillIds[3], 3);
  }

  function test_RevertUpdateSkill() external {
    uint256[5] memory skillIds = [uint256(0), 1, 1000, 3, 0]; // skill id 1000 is not exist
    vm.expectRevert();
    vm.prank(player);

    world.app__updateSkillOrder(characterId, skillIds);

    skillIds = [uint256(0), 0, 3, 3, 0]; // duplicate skill id 3
    vm.expectRevert();
    vm.prank(player);
    world.app__updateSkillOrder(characterId, skillIds);
  }
}
