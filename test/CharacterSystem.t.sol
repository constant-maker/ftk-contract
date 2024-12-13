pragma solidity >=0.8.24;

import { console2 } from "forge-std/console2.sol";
import { WorldFixture, SpawnSystemFixture, WelcomeSystemFixture } from "./fixtures/index.sol";
import { IERC721 } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721.sol";
import { ActiveChar, Contracts } from "@codegen/index.sol";
import { SlotType } from "@codegen/common.sol";
import { CharacterUtils } from "@utils/CharacterUtils.sol";
import { SystemUtils } from "@utils/SystemUtils.sol";
import { EquipData } from "@systems/app/EquipmentSystem.sol";

contract CharacterSystemTest is WorldFixture, SpawnSystemFixture, WelcomeSystemFixture {
  address player = makeAddr("player");
  address newOwner = makeAddr("new owner");
  address sessionWallet = makeAddr("session wallet");
  address stranger = makeAddr("stranger");
  uint256 characterId;

  function setUp() public virtual override(WorldFixture, SpawnSystemFixture, WelcomeSystemFixture) {
    WorldFixture.setUp();

    characterId = _createDefaultCharacter(player);
    _claimWelcomePackages(player, characterId);
  }

  function test_TransferCharacterSuccessullfy() external {
    // console2.log("worldDeployer", worldDeployer);
    // console2.log("creator", creator);
    // console2.log("worldAddress", worldAddress);
    console2.log("current owner", player);
    // console2.log("newOwner", newOwner);

    address characterERC721 = Contracts.getErc721Token();
    vm.startPrank(player);
    IERC721(characterERC721).approve(SystemUtils.getSystemAddress("CharacterSystem"), characterId);
    world.app__linkMainAccount(characterId, newOwner);
    vm.stopPrank();
    console2.log("new owner", newOwner);
    CharacterUtils.checkCharacterOwner(characterId, newOwner);
    assertEq(ActiveChar.getWallet(characterId), newOwner);
    assertEq(ActiveChar.getSessionWallet(characterId), player);
  }

  function test_DelegateSessionWalletSuccessullfy() external {
    vm.startPrank(player);
    world.app__delegateSessionWallet(characterId, sessionWallet);
    vm.stopPrank();

    address boundSessionWallet = ActiveChar.getSessionWallet(characterId);
    assertEq(boundSessionWallet, sessionWallet);

    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });

    vm.startPrank(sessionWallet);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();

    // unequip equipment
    equipDatas[0].equipmentId = 0;
    vm.startPrank(player);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();
  }

  function test_Revert_SessionWalletDelegateToOtherWallet() external {
    vm.startPrank(player);
    world.app__delegateSessionWallet(characterId, sessionWallet);
    vm.stopPrank();

    address boundSessionWallet = ActiveChar.getSessionWallet(characterId);
    assertEq(boundSessionWallet, sessionWallet);

    vm.expectRevert();
    vm.startPrank(sessionWallet);
    world.app__delegateSessionWallet(characterId, sessionWallet);
    vm.stopPrank();
  }

  function test_Revert_SessionWalletIsRevoked() external {
    vm.startPrank(player);
    world.app__delegateSessionWallet(characterId, sessionWallet);
    vm.stopPrank();

    address boundSessionWallet = ActiveChar.getSessionWallet(characterId);
    assertEq(boundSessionWallet, sessionWallet);

    vm.startPrank(player);
    world.app__revokeSessionWallet(characterId);
    vm.stopPrank();

    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });

    vm.expectRevert();
    vm.startPrank(sessionWallet);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();
  }

  function test_Revert_UsingStrangerAddress() external {
    EquipData[] memory equipDatas = new EquipData[](1);
    equipDatas[0] = EquipData({ slotType: SlotType.Weapon, equipmentId: 1 });
    vm.expectRevert();
    vm.startPrank(stranger);
    world.app__gearUpEquipments(characterId, equipDatas);
    vm.stopPrank();
  }
}
