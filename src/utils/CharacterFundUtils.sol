pragma solidity >=0.8.24;

import { CharFund } from "@codegen/index.sol";
import { Errors } from "@common/Errors.sol";

library CharacterFundUtils {
  function increaseGold(uint256 characterId, uint32 amount) internal {
    uint32 newAmount = CharFund.getGold(characterId) + amount;
    CharFund.setGold(characterId, newAmount);
  }

  function decreaseGold(uint256 characterId, uint32 amount) internal {
    uint32 _balance = CharFund.getGold(characterId);
    if (_balance < amount) {
      revert Errors.CharacterFund_NotEnoughGold(_balance, amount);
    }
    CharFund.setGold(characterId, _balance - amount);
  }

  function mustEnoughGold(uint256 characterId, uint32 requireAmount) internal view {
    uint32 _balance = CharFund.getGold(characterId);
    if (_balance < requireAmount) {
      revert Errors.CharacterFund_NotEnoughGold(_balance, requireAmount);
    }
  }

  function increaseCrystal(uint256 characterId, uint32 amount) internal {
    uint32 newAmount = CharFund.getCrystal(characterId) + amount;
    CharFund.setCrystal(characterId, newAmount);
  }

  function decreaseCrystal(uint256 characterId, uint32 amount) internal {
    uint32 _balance = CharFund.getCrystal(characterId);
    if (_balance < amount) {
      revert Errors.CharacterFund_NotEnoughCrystal(_balance, amount);
    }
    CharFund.setCrystal(characterId, _balance - amount);
  }

  function mustEnoughCrystal(uint256 characterId, uint32 requireAmount) internal {
    uint32 _balance = CharFund.getCrystal(characterId);
    if (_balance < requireAmount) {
      revert Errors.CharacterFund_NotEnoughCrystal(_balance, requireAmount);
    }
  }
}
