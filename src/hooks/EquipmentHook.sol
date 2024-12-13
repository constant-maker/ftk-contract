pragma solidity >=0.8.24;

import { StoreHook } from "@latticexyz/store/src/StoreHook.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EncodedLengths } from "@latticexyz/store/src/EncodedLengths.sol";
import { FieldLayout } from "@latticexyz/store/src/FieldLayout.sol";
import { Equipment, EquipmentData } from "@codegen/index.sol";
import { InventoryEquipmentUtils } from "@utils/index.sol";

/// Hook only work when we set the whole fields data like Equipment.set(...)

contract EquipmentHook is StoreHook {
  function onAfterSetRecord(
    ResourceId tableId,
    bytes32[] memory keyTuple,
    bytes memory staticData,
    EncodedLengths encodedLengths,
    bytes memory dynamicData,
    FieldLayout fieldLayout
  )
    public
    override
  {
    EquipmentData memory equipment = Equipment.decode(staticData, encodedLengths, dynamicData);
    uint256 equipmentId = uint256(keyTuple[0]);
    uint256 characterId = equipment.characterId;
    if (InventoryEquipmentUtils.hasEquipment(characterId, equipmentId)) {
      return;
    }
    InventoryEquipmentUtils.addEquipment(characterId, equipmentId, true);
  }

  function onBeforeDeleteRecord(ResourceId tableId, bytes32[] memory keyTuple, FieldLayout fieldLayout) public override {
    uint256 equipmentId = uint256(keyTuple[0]);
    EquipmentData memory equipment = Equipment.get(equipmentId);
    InventoryEquipmentUtils.removeEquipment(equipment.characterId, equipmentId, true);
  }
}
