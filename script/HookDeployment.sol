pragma solidity >=0.8.24;

import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IWorld } from "@codegen/world/IWorld.sol";

import {
  BEFORE_SET_RECORD,
  AFTER_SET_RECORD,
  BEFORE_SPLICE_STATIC_DATA,
  AFTER_SPLICE_STATIC_DATA,
  BEFORE_SPLICE_DYNAMIC_DATA,
  AFTER_SPLICE_DYNAMIC_DATA,
  BEFORE_DELETE_RECORD,
  AFTER_DELETE_RECORD
} from "@latticexyz/store/src/storeHookTypes.sol";

import { ToolHook, EquipmentHook, MonsterLocationHook } from "@hooks/index.sol";
import { Tool2, Equipment, MonsterLocation } from "@codegen/index.sol";

library HookDeployment {
  function registerHooks(address worldAddress) internal {
    IWorld world = IWorld(worldAddress);

    // register ToolHook
    ToolHook toolHook = new ToolHook();
    world.registerStoreHook({
      tableId: Tool2._tableId,
      hookAddress: toolHook,
      enabledHooksBitmap: AFTER_SET_RECORD | BEFORE_DELETE_RECORD
    });
    world.grantAccess(WorldResourceIdLib.encodeNamespace("app"), address(toolHook));

    // register EquipmentHook
    EquipmentHook equipmentHook = new EquipmentHook();
    world.registerStoreHook({
      tableId: Equipment._tableId,
      hookAddress: equipmentHook,
      enabledHooksBitmap: AFTER_SET_RECORD | BEFORE_DELETE_RECORD
    });
    world.grantAccess(WorldResourceIdLib.encodeNamespace("app"), address(equipmentHook));

    // register MonsterLocationHook
    MonsterLocationHook monsterLocationHook = new MonsterLocationHook();
    world.registerStoreHook({
      tableId: MonsterLocation._tableId,
      hookAddress: monsterLocationHook,
      enabledHooksBitmap: AFTER_SET_RECORD | AFTER_DELETE_RECORD
    });
    world.grantAccess(WorldResourceIdLib.encodeNamespace("app"), address(monsterLocationHook));
  }
}
