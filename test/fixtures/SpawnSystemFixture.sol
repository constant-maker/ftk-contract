pragma solidity >=0.8.24;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC721Mintable } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";
import {
  CharPosition,
  CharPositionData,
  CharInfo,
  CharInfoData,
  KingdomV2,
  KingdomV2Data,
  CharState,
  CharStateData,
  ActiveChar,
  ActiveCharData,
  Contracts
} from "@codegen/index.sol";
import { CharacterStateType } from "@codegen/common.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystem } from "@systems/index.sol";
import { CharacterInfoMock } from "@mocks/index.sol";
import { SystemUtils } from "@utils/SystemUtils.sol";
import { CharacterStateUtils } from "@utils/CharacterStateUtils.sol";

abstract contract SpawnSystemFixture is WorldFixture {
  function setUp() public virtual override {
    WorldFixture.setUp();
  }

  function _expectCharacterNftOwner(uint256 _characterId, address _owner) internal {
    IERC721Mintable token = IERC721Mintable(Contracts.getErc721Token());
    address actualOwner = token.ownerOf(_characterId);
    assertEq(_owner, actualOwner);
  }

  function _createCharacter(
    address _player,
    CharInfoData memory characterInfoData
  )
    internal
    returns (uint256 _characterId)
  {
    vm.startPrank(_player);

    ResourceId spawnSystemResourceId = SystemUtils.getRootSystemId("SpawnSystem");
    bytes memory data = abi.encodeCall(SpawnSystem.createCharacter, characterInfoData);

    vm.recordLogs();
    world.call(spawnSystemResourceId, data);

    Vm.Log[] memory logs = vm.getRecordedLogs();
    bool gotCharacterCreated;

    for (uint256 i = 0; i < logs.length; i++) {
      if (logs[i].topics[0] == keccak256("CharacterCreated(uint256,address,uint256)")) {
        _characterId = uint256(logs[i].topics[1]);
        gotCharacterCreated = true;
        break;
      }
    }

    assertTrue(gotCharacterCreated);

    // validate character state
    CharStateData memory characterState = CharacterStateUtils.getCharacterStateData(_characterId);
    assertTrue(characterState.state == CharacterStateType.Standby);
    assertEq(characterState.lastUpdated, block.timestamp);

    // validate active character
    ActiveCharData memory activeCharacter = ActiveChar.get(_characterId);
    assertGt(activeCharacter.createdTime, 0);
    assertEq(activeCharacter.wallet, _player);

    vm.stopPrank();
    return _characterId;
  }

  function _createDefaultCharacter(address _player) internal returns (uint256 _characterId) {
    return _createCharacter(_player, CharacterInfoMock.getCharacterInfoData());
  }

  function _createCharacterWithName(address _player, string memory name) internal returns (uint256 _characterId) {
    return _createCharacter(_player, CharacterInfoMock.getCharacterInfoDataWithName(name));
  }

  function _createCharacterWithNameAndKingdomId(
    address _player,
    string memory name,
    uint8 kingdomId
  )
    internal
    returns (uint256 _characterId)
  {
    return _createCharacter(_player, CharacterInfoMock.getCharacterInfoDataWithNameAndKingdomId(name, kingdomId));
  }

  function _expectCreateCharacterReverted(address _player, CharInfoData memory characterInfoData) internal {
    vm.startPrank(_player);

    ResourceId spawnSystemResourceId = SystemUtils.getRootSystemId("SpawnSystem");
    bytes memory data = abi.encodeCall(SpawnSystem.createCharacter, characterInfoData);

    vm.expectRevert();
    world.call(spawnSystemResourceId, data);
    vm.stopPrank();
  }
}
