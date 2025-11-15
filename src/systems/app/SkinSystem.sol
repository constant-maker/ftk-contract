pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import {
  CharEquipment, CharGrindSlot, Equipment, EquipmentData, EquipmentInfo, ItemV2, CharStats
} from "@codegen/index.sol";
import { SkinSlotType } from "@codegen/common.sol";
import { Errors } from "@common/index.sol";
import { EquipSkinData } from "./SkinSystem.sol";

struct EquipSkinData {
  SkinSlotType slotType;
  uint256 itemId;
}

contract SkinSystem is System, CharacterAccessControl { }
