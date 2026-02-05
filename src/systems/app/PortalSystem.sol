pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterAccessControl } from "@abstracts/CharacterAccessControl.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IWorld } from "@codegen/world/IWorld.sol";
import {
  SalePackage, SalePackageData, CharTotalSpend, CharFund
} from "@codegen/index.sol";
import { CharAchievementUtils, CharacterFundUtils, InventoryItemUtils, WorldUtils } from "@utils/index.sol";
import { Config, Errors } from "@common/index.sol";

contract PortalSystem is CharacterAccessControl, System {

  uint256 constant MIN_CRYSTALS_PER_PURCHASE = 100; // Minimum crystals per purchase
  uint256 constant SELL_CRYSTAL_FEE_PERCENTAGE = 5; // 5% fee when selling crystals

  function buyCrystal(uint256 characterId, uint32 amount) public payable onlyCharacterOwner(characterId) {
    uint256 value = _msgValue();
    if (amount < MIN_CRYSTALS_PER_PURCHASE) {
      revert Errors.PortalSystem_CrystalAmountTooSmall(amount, MIN_CRYSTALS_PER_PURCHASE);
    }
    uint256 requiredPayment = amount * Config.CRYSTAL_UNIT_PRICE;
    if (value < requiredPayment) {
      revert Errors.InsufficientPayment(value, requiredPayment);
    }
    CharacterFundUtils.increaseCrystal(characterId, amount);
  }

  function sellCrystal(uint256 characterId, uint32 amount) public onlyCharacterOwner(characterId) {
    uint32 currentCrystals = CharFund.getCrystal(characterId);
    if (currentCrystals < amount) {
      revert Errors.PortalSystem_InsufficientCrystal(currentCrystals, amount);
    }
    if (amount < MIN_CRYSTALS_PER_PURCHASE) {
      revert Errors.PortalSystem_CrystalAmountTooSmall(amount, MIN_CRYSTALS_PER_PURCHASE);
    }
    CharacterFundUtils.decreaseCrystal(characterId, amount);
    uint256 rawPayment = amount * CRYSTAL_UNIT_PRICE;
    uint256 fee = (rawPayment * SELL_CRYSTAL_FEE_PERCENTAGE) / 100;
    uint256 paymentAmount = rawPayment - fee;
    IWorld world = IWorld(_world());
    world.transferBalanceToAddress(WorldResourceIdLib.encodeNamespace(""), _msgSender(), paymentAmount);
    WorldUtils.transferToTeam(world, fee);
  }
}
