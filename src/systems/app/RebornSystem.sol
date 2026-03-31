pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { CharStats, CharStatsData } from "@codegen/tables/CharStats.sol";
import {
  CharCurrentStats,
  CharCurrentStatsData,
  CharBaseStats,
  CharReborn,
  CharInfo
} from "@codegen/index.sol";
import { CharAchievementUtils } from "@utils/CharAchievementUtils.sol";
import { CharacterBuffUtils } from "@utils/CharacterBuffUtils.sol";
import { InventoryItemUtils } from "@utils/InventoryItemUtils.sol";
import { CharacterEquipmentUtils } from "@utils/CharacterEquipmentUtils.sol";
import { Errors, Config } from "@common/index.sol";
import { CharacterStateType } from "@codegen/common.sol";

contract RebornSystem is System, CharacterAccessControl {
  uint16 constant MAX_REBORN = 10; // Current reborn limit

  /// @dev reborn character to level 1 with extra stat points
  function reborn(uint256 characterId) public mustInState(characterId, CharacterStateType.Standby) onlyAuthorizedWallet(characterId) {
    // require character level 99
    uint16 currentLevel = CharStats.getLevel(characterId);
    if (currentLevel < Config.MAX_LEVEL) {
      revert Errors.RebornSystem_MustBeMaxLevel(characterId);
    }
    uint16 rebornNum = CharReborn.get(characterId) + 1;
    if (rebornNum > MAX_REBORN) {
      revert Errors.RebornSystem_ExceedMaxReborn(rebornNum);
    }
    (uint256[] memory itemIds, uint32[] memory amounts) = _requiredResources(rebornNum);
    InventoryItemUtils.removeItems(characterId, itemIds, amounts);
    // clear all temporary buffs/debuffs before removing equipment stats
    CharacterBuffUtils.dispelAllBuff(characterId);
    // unequip all equipment
    CharacterEquipmentUtils.unequipAllEquipment(characterId);

    // reset stat and gain extra points
    // update current stats
    CharCurrentStatsData memory charCurrentStats = _getRebornCurrentStats(characterId);
    CharCurrentStats.set(characterId, charCurrentStats);
    // reset character stats
    CharStatsData memory charStats = CharStats.get(characterId);
    charStats.level = 1;
    charStats.hp = charCurrentStats.hp;
    charStats.statPoint = 20 * rebornNum;
    CharStats.set(characterId, charStats);

    // add all achievement stats to character
    CharAchievementUtils.addAllAchievementStats(characterId);

    // reset base stats
    CharBaseStats.set(characterId, 0, 0, 0);

    // update reborn counter
    CharReborn.set(characterId, rebornNum);

    // add achievement
    CharAchievementUtils.addAchievement(characterId, 9); // Ascended Soul
  }

  function _getRebornCurrentStats(uint256 characterId) private view returns (CharCurrentStatsData memory) {
    (uint16 oAtk, uint16 oDef, uint16 oAgi) = _getCharacterOriginalStats(characterId);
    return CharCurrentStatsData({
      exp: 0,
      weight: CharCurrentStats.getWeight(characterId),
      hp: Config.DEFAULT_HP,
      barrier: 0,
      atk: oAtk,
      def: oDef,
      agi: oAgi,
      ms: uint16(Config.DEFAULT_MOVEMENT_SPEED)
    });
  }

  function _getCharacterOriginalStats(uint256 characterId) private view returns (uint16 atk, uint16 def, uint16 agi) {
    uint16[3] memory traits = CharInfo.getTraits(characterId);
    atk = 1 + traits[0];
    def = 1 + traits[1];
    agi = 1 + traits[2];
    return (atk, def, agi);
  }

  function _requiredResources(uint16 rebornNum)
    private
    pure
    returns (uint256[] memory itemIds, uint32[] memory amounts)
  {
    uint256 len = 4;
    itemIds = new uint256[](len);
    itemIds[0] = 258;
    itemIds[1] = 259;
    itemIds[2] = 260;
    itemIds[3] = 261;
    amounts = new uint32[](len);
    for (uint256 i = 0; i < len; i++) {
      amounts[i] = rebornNum;
    }
    return (itemIds, amounts);
  }
}
