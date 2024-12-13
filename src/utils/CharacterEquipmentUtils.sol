pragma solidity >=0.8.24;

import { Equipment, EquipmentInfo, Item, CharCurrentStats, CharEquipment } from "@codegen/index.sol";
import { AdvantageType, SlotType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";

library CharacterEquipmentUtils {
  function getCharacterAdvantageType(uint256 characterId) internal view returns (AdvantageType characterAdvantageType) {
    uint256 weaponId = getCharacterWeaponId(characterId);
    return _getWeaponAdvantageType(weaponId);
  }

  function getCharacterWeaponId(uint256 characterId) internal view returns (uint256 weaponId) {
    return CharEquipment.getEquipmentId(characterId, SlotType.Weapon);
  }

  function _getWeaponAdvantageType(uint256 weaponId) private view returns (AdvantageType) {
    if (weaponId == 0) {
      return AdvantageType.Grey;
    }
    uint256 itemId = Equipment.getItemId(weaponId);
    if (itemId == 0) {
      revert Errors.Equipment_NotExisted(weaponId);
    }
    return EquipmentInfo.getAdvantageType(itemId);
  }
}
