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

import { MonsterLocationHook } from "@hooks/index.sol";
import { MonsterLocation } from "@codegen/index.sol";

library HookDeployment {
  function registerHooks(address worldAddress) internal {
    IWorld world = IWorld(worldAddress);

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
