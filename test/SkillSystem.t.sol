pragma solidity >=0.8.24;

import { CharSkill, CharPerk } from "@codegen/index.sol";
import { ItemType } from "@codegen/common.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { Errors } from "@common/Errors.sol";
import { console2 } from "forge-std/console2.sol";

contract SkillTest is WorldFixture, SpawnSystemFixture {
  address player = makeAddr("player");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture) {
    WorldFixture.setUp();
    characterId = _createDefaultCharacter(player);
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
    vm.expectRevert(abi.encodeWithSelector(Errors.Skill_NotExist.selector, 1000));
    vm.prank(player);

    world.app__updateSkillOrder(characterId, skillIds);

    skillIds = [uint256(0), 0, 3, 3, 0]; // duplicate skill id 3
    vm.expectRevert(abi.encodeWithSelector(Errors.Skill_DuplicateSkillId.selector, 3));
    vm.prank(player);
    world.app__updateSkillOrder(characterId, skillIds);
  }

  function test_RevertNotEnoughPerkLevelForSkill() external {
    uint16 perkLevel = CharPerk.getLevel(characterId, ItemType.StoneHammer);
    assertEq(perkLevel, 0);
    console2.log("current perk level", perkLevel);

    uint256[5] memory skillIds = [uint256(0), 11, 0, 3, 0]; // skill id 11 requires perk level 2
    vm.expectRevert(abi.encodeWithSelector(Errors.Skill_PerkLevelIsNotEnough.selector, characterId, 1, 2));
    vm.startPrank(player);
    world.app__updateSkillOrder(characterId, skillIds);
    vm.stopPrank();

    vm.startPrank(worldDeployer);
    CharPerk.setLevel(characterId, ItemType.StoneHammer, 1);
    vm.stopPrank();

    vm.startPrank(player);
    world.app__updateSkillOrder(characterId, skillIds);
    vm.stopPrank();

    uint256[5] memory currentSkillIds = CharSkill.get(characterId);
    assertEq(currentSkillIds[0], 0);
    assertEq(currentSkillIds[1], 11);
    assertEq(currentSkillIds[2], 0);
    assertEq(currentSkillIds[3], 3);
    assertEq(currentSkillIds[4], 0);
  }
}
