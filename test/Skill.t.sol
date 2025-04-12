pragma solidity >=0.8.24;

import { SkillV2, SkillV2Data, SkillEffect, SkillEffectData } from "@codegen/index.sol";
import { ItemType, EffectType } from "@codegen/common.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystemFixture } from "@fixtures/SpawnSystemFixture.sol";
import { TestHelper } from "./TestHelper.sol";

contract SkillTest is WorldFixture, SpawnSystemFixture {
  function setUp() public virtual override(WorldFixture, SpawnSystemFixture) {
    WorldFixture.setUp();
  }

  function testFuzz_UserShouldNotAbleToSetSkill(address user) external {
    vm.assume(user != worldDeployer);
    vm.assume(user != creator);
    vm.assume(user != address(0));
    uint256 characterId = _createDefaultCharacter(user);
    vm.startPrank(user);
    bytes memory accessDeniedError = TestHelper.getAccessDeniedError(user, SkillV2._tableId);
    vm.expectRevert(accessDeniedError);
    uint8[] memory perkItemTypes = new uint8[](1);
    perkItemTypes[0] = uint8(ItemType.Axe);
    uint8[] memory perkLevels = new uint8[](1);
    perkLevels[0] = 1;
    SkillV2.set(1, 2, 3, false, "123", perkItemTypes, perkLevels);
    vm.stopPrank();
  }

  function test_HaveData() external {
    SkillV2Data memory skill = SkillV2.get(0);
    assertEq(skill.damage, 100);
    assertEq(skill.sp, 0);

    skill = SkillV2.get(11);
    assertTrue(skill.hasEffect);
    assertEq(skill.damage, 150);
    assertEq(skill.requiredPerkLevels.length, 1);
    SkillEffectData memory skillEffect = SkillEffect.get(11);
    assertEq(skillEffect.damage, 25);
    assertEq(skillEffect.turns, 2);
    assertTrue(skillEffect.effect == EffectType.Burn);

    skill = SkillV2.get(12);
    assertTrue(skill.hasEffect);
    assertEq(skill.damage, 150);
    assertEq(skill.requiredPerkLevels[0], 1);
    skillEffect = SkillEffect.get(12);
    assertEq(skillEffect.damage, 0);
    assertEq(skillEffect.turns, 1);
    assertTrue(skillEffect.effect == EffectType.Stun);
  }
}
