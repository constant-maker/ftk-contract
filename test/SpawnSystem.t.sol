pragma solidity >=0.8.24;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC721Mintable } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";
import {
  CharPositionFull,
  CharPositionFullData,
  CharPositionData,
  CharInfo,
  CharInfoData,
  Kingdom,
  KingdomData,
  CharState,
  CharStateData,
  ActiveChar,
  ActiveCharData,
  Contracts,
  CrystalFee,
  CityVault2
} from "@codegen/index.sol";
import { CharacterStateType, CharacterType } from "@codegen/common.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { TestHelper } from "./index.sol";
import { WorldFixture } from "@fixtures/WorldFixture.sol";
import { SpawnSystem } from "@systems/index.sol";
import { CharacterInfoMock } from "@mocks/CharacterInfoMock.sol";
import { SystemUtils } from "@utils/SystemUtils.sol";
import { CharacterStateUtils } from "@utils/CharacterStateUtils.sol";
import { Balances } from "@latticexyz/world/src/codegen/tables/Balances.sol";
import { WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { Config } from "@common/index.sol";

abstract contract SpawnSystemFixture is WorldFixture {
  address player = makeAddr("player1");

  function setUp() public virtual override {
    WorldFixture.setUp();

    vm.label(player, "PLAYER_1");
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
    vm.deal(_player, 1 ether);

    vm.startPrank(_player);

    ResourceId spawnSystemResourceId = SystemUtils.getRootSystemId("SpawnSystem");
    bytes memory data = abi.encodeCall(SpawnSystem.createCharacter, characterInfoData);

    vm.recordLogs();
    world.call{ value: Config.CREATE_CHARACTER_FEE }(spawnSystemResourceId, data);

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

  function _expectCreateCharacterReverted(address _player, CharInfoData memory characterInfoData) internal {
    vm.startPrank(_player);

    ResourceId spawnSystemResourceId = SystemUtils.getRootSystemId("SpawnSystem");
    bytes memory data = abi.encodeCall(SpawnSystem.createCharacter, characterInfoData);

    vm.expectRevert();
    world.call(spawnSystemResourceId, data);
    vm.stopPrank();
  }
}

contract ValidCharacterName is SpawnSystemFixture {
  function setUp() public override {
    SpawnSystemFixture.setUp();
  }

  function isValidName(string memory name) internal view returns (bool) {
    bytes memory b = bytes(name);

    if (b.length < 3 || b.length > 20) {
      return false;
    }

    // no leading space
    if (b[0] == 0x20) return false;
    // no trailing space
    else if (b[b.length - 1] == 0x20) return false;

    bytes1 lastChar = b[0];

    for (uint256 i; i < b.length; i++) {
      bytes1 char = b[i];

      // Cannot contain continuous spaces
      if (char == 0x20 && lastChar == 0x20) return false;

      if (
        !(char >= 0x30 && char <= 0x39) //9-0
          && !(char >= 0x41 && char <= 0x5A) //A-Z
          && !(char >= 0x61 && char <= 0x7A) //a-z
          && !(char == 0x20) //space
      ) {
        return false;
      }

      lastChar = char;
    }

    return true;
  }

  function test_CharacterNameShouldBeInvalid_WithInvalidLength() external {
    assertFalse(isValidName("a"));
    assertFalse(isValidName("aa"));
    assertFalse(isValidName("abcdefghijklmnopqrstuaa"));
  }

  function test_CharacterNameShouldBeInvalid_WithLeadingSpace() external {
    assertFalse(isValidName(" "));
    assertFalse(isValidName(" test"));
  }

  function test_CharacterNameShouldBeInvalid_WithTrailingSpace() external {
    assertFalse(isValidName("test "));
  }

  function test_CharacterNameShouldBeInvalid_WithContinuousSpaces() external {
    assertFalse(isValidName("test  me"));
  }

  function test_CharacterNameShouldBeInvalid_WithNonAlphanumeric() external {
    assertFalse(isValidName("!@#"));
  }

  function test_ValidCharacterName() external {
    assertTrue(isValidName("my character"));
  }
}

contract CreateCharacter is SpawnSystemFixture {
  function setUp() public virtual override {
    SpawnSystemFixture.setUp();
  }

  function test_ShouldBeReverted_WhenAlreadyMintedOneCharacter() external {
    // create one character
    uint256 characterId = _createCharacter(player, CharacterInfoMock.getCharacterInfoData());

    // check position
    CharPositionFullData memory positionFull = CharPositionFull.get(characterId);
    assertEq(positionFull.x, 30);
    assertEq(positionFull.y, -36);
    assertEq(positionFull.nextX, 30);
    assertEq(positionFull.nextY, -36);

    // expect character nft is minted
    _expectCharacterNftOwner(characterId, player);

    // expect that user cannot create another character
    _expectCreateCharacterReverted(player, CharacterInfoMock.getCharacterInfoData());
  }

  function testFuzz_ShouldBeReverted_WithInvalidKingdomId(uint8 kingdomId) external {
    KingdomData memory kingdomData = Kingdom.get(kingdomId);
    vm.assume(kingdomId > 4);

    CharInfoData memory characterInfo = CharacterInfoMock.getCharacterInfoData();
    characterInfo.kingdomId = kingdomId;

    _expectCreateCharacterReverted(player, characterInfo);
  }

  function test_ShouldBeReverted_WhenCharacterNameExisted() external {
    // create one character
    CharInfoData memory characterInfo = CharacterInfoMock.getCharacterInfoData();
    uint256 characterId = _createCharacter(player, characterInfo);

    // expect character nft is minted
    _expectCharacterNftOwner(characterId, player);

    address bob = address(2);

    _expectCreateCharacterReverted(bob, characterInfo);
  }

  function test_ShouldBeReverted_CaseSensitiveName() external {
    // create one character
    CharInfoData memory characterInfo = CharacterInfoMock.getCharacterInfoData();
    uint256 characterId = _createCharacter(player, characterInfo);

    // expect character nft is minted
    _expectCharacterNftOwner(characterId, player);

    address bob = address(2);
    characterInfo.name = "ChAracTer";
    _expectCreateCharacterReverted(bob, characterInfo);
  }

  function test_ShouldBeOk_WithValidData() external {
    // create one character
    uint256 characterId = _createCharacter(player, CharacterInfoMock.getCharacterInfoData());
    console2.log("Kingdom Id: ", CharacterInfoMock.getCharacterInfoData().kingdomId);

    // expect character nft is minted
    _expectCharacterNftOwner(characterId, player);
  }

  function test_CreateCharacter_WithDirectCallToWorld() external {
    CharInfoData memory testData = CharInfoData(1, CharacterType.Male, [uint16(1), uint16(1), uint16(3)], "123");

    bytes memory data = abi.encodeWithSignature("createCharacter((uint8,uint8,uint16[3],string))", testData);

    address player = makeAddr("player");
    vm.deal(player, 1 ether);

    vm.startPrank(player);

    // (bool success, bytes memory result) = address(mockTest).call(data);
    (bool success, bytes memory result) = address(world).call{ value: Config.CREATE_CHARACTER_FEE }(data);
    assertTrue(success);

    vm.stopPrank();
  }

  function test_TransferNFT() external {
    uint256 characterId = _createCharacter(player, CharacterInfoMock.getCharacterInfoData());

    // expect character nft is minted
    _expectCharacterNftOwner(characterId, player);

    address bob = makeAddr("bob");

    // transfer NFT to bob
    IERC721Mintable token = IERC721Mintable(Contracts.getErc721Token());

    vm.startPrank(player);
    token.safeTransferFrom(player, bob, characterId);
    vm.stopPrank();

    // expect character nft is owned by bob
    _expectCharacterNftOwner(characterId, bob);

    // expect active char is updated
    ActiveCharData memory activeCharData = ActiveChar.get(characterId);
    assertEq(activeCharData.wallet, bob);
    assertEq(activeCharData.sessionWallet, address(0));
  }

  function test_TransferNFTWithData() external {
    uint8 feePercentage = 5;
    vm.startPrank(worldDeployer);
    CrystalFee.setFee(1, feePercentage);
    vm.stopPrank();

    uint256 characterId = _createCharacter(player, CharacterInfoMock.getCharacterInfoData());

    // expect character nft is minted
    _expectCharacterNftOwner(characterId, player);

    uint256 balance = Balances.getBalance(WorldResourceIdLib.encodeNamespace("")); // root space
    assertEq(balance, Config.CREATE_CHARACTER_FEE);

    uint256 vaultCrystal = CityVault2.getCrystal(1);

    uint256 ethFeeAmount = (Config.CREATE_CHARACTER_FEE * uint256(feePercentage)) / 100;
    console2.log("ethFeeAmount: ", ethFeeAmount);
    uint256 crystalAmount = ethFeeAmount / Config.CRYSTAL_UNIT_PRICE;
    console2.log("crystalAmount: ", crystalAmount);

    assertEq(vaultCrystal, crystalAmount);

    address bob = makeAddr("bob");

    // transfer NFT to bob
    IERC721Mintable token = IERC721Mintable(Contracts.getErc721Token());
    bytes memory data = abi.encodePacked("some data");
    vm.startPrank(player);
    token.safeTransferFrom(player, bob, characterId, data);
    vm.stopPrank();

    // expect character nft is owned by bob
    _expectCharacterNftOwner(characterId, bob);

    // expect active char is updated
    ActiveCharData memory activeCharData = ActiveChar.get(characterId);
    assertEq(activeCharData.wallet, bob);
    assertEq(activeCharData.sessionWallet, address(0));
  }
}
