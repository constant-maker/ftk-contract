pragma solidity >=0.8.24;

import { console } from "forge-std/console.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { ERC721MetadataData } from "@latticexyz/world-modules/src/modules/erc721-puppet/tables/ERC721Metadata.sol";
import { IERC721Mintable } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";
import { registerERC721 } from "@latticexyz/world-modules/src/modules/erc721-puppet/registerERC721.sol";
import { MovementConfig, MovementConfigData } from "@codegen/index.sol";
import { Config } from "@common/Config.sol";
import { Contracts } from "@codegen/index.sol";
import { HookDeployment } from "./HookDeployment.sol";
import { _erc721SystemId } from "@latticexyz/world-modules/src/modules/erc721-puppet/utils.sol";
import { NFTTransferHook } from "@hooks/NFTTransferHook.sol";
import { AFTER_CALL_SYSTEM } from "@latticexyz/world/src/systemHookTypes.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
// import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { SpawnSystem } from "@src/systems/SpawnSystem.sol";
import { SystemUtils } from "@utils/SystemUtils.sol";
import { Script } from "forge-std/Script.sol";

contract WorldDeployment is Script {
  using WorldResourceIdInstance for ResourceId;

  function initialize(address worldAddress) internal {
    IWorld world = IWorld(worldAddress);

    _initializeMovementConfig();

    _registerCharacterNFT(worldAddress);

    // register SpawnSystem as root system
    _registerSpawnSystem(world);

    // register Hooks
    HookDeployment.registerHooks(worldAddress);

    // read post deploy calldata from post_deploy.txt
    string memory postDeployFile = "post_deploy_test.txt";
    string memory postDeployFileEnv = vm.envString("POST_DEPLOY_FILE");
    if (bytes(postDeployFileEnv).length != 0) {
      postDeployFile = postDeployFileEnv;
    }
    while (true) {
      string memory postDeployCalldata = vm.readLine(postDeployFile);
      if (bytes(postDeployCalldata).length == 0) {
        break;
      }
      (bool success,) = address(world).call(vm.parseBytes(postDeployCalldata));
      require(success, "Error send post deploy calldata");
    }
  }

  function _initializeMovementConfig() private {
    MovementConfigData memory data = MovementConfigData({
      baseMovementSpeed: Config.DEFAULT_MOVEMENT_SPEED,
      maxMovementSpeed: Config.MAX_MOVEMENT_SPEED,
      duration: Config.DEFAULT_MOVEMENT_DURATION
    });
    console.log("Base character movement speed %d", data.baseMovementSpeed);
    console.log("Max movement speed %d", data.maxMovementSpeed);
    console.log("Movement duration secs %d", data.duration);
    MovementConfig.set(data);
  }

  function _registerSpawnSystem(IWorld world) private {
    ResourceId systemId = SystemUtils.getRootSystemId("SpawnSystem");
    SpawnSystem spawnSystem = new SpawnSystem();

    world.registerSystem(systemId, spawnSystem, true);
    world.registerRootFunctionSelector(
      systemId, "createCharacter((uint8,uint8,uint16[3],string))", "createCharacter((uint8,uint8,uint16[3],string))"
    );
  }

  function _registerCharacterNFT(address worldAddress) private {
    IWorld world = IWorld(worldAddress);
    // install puppet module
    world.installModule(new PuppetModule(), new bytes(0));
    // register ERC721 module
    bytes14 characterNFT = bytes14("characterNFT");
    IERC721Mintable characterERC721 =
      registerERC721(world, characterNFT, ERC721MetadataData({ name: "Arcaris Citizen", symbol: "ARC", baseURI: "" }));
    // store token contract
    Contracts.setErc721Token(address(characterERC721));

    // register hook
    NFTTransferHook nftTransferHook = new NFTTransferHook();
    world.registerSystemHook(_erc721SystemId(characterNFT), nftTransferHook, AFTER_CALL_SYSTEM);

    // transfer ownership to world
    world.transferOwnership(WorldResourceIdLib.encodeNamespace(characterNFT), worldAddress);
  }
}
