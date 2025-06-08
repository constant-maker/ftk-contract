pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { CharacterItemUtils } from "@utils/CharacterItemUtils.sol";
import { WelcomePackages, WelcomeConfig } from "@codegen/index.sol";
import { Errors } from "@common/index.sol";

contract WelcomeSystem is System {
  /// @dev Let player claims a welcome packages for a character
  function claimWelcomePackages(uint256 characterId) public {
    bool claimed = WelcomePackages.get(characterId);
    if (claimed) {
      revert Errors.Character_WelcomePackagesClaimed(characterId);
    }

    uint256[] memory beginnerItemDetailIds = WelcomeConfig.getItemDetailIds();
    for (uint256 i = 0; i < beginnerItemDetailIds.length; i++) {
      uint256 itemDetailId = beginnerItemDetailIds[i];
      CharacterItemUtils.addNewItem(characterId, itemDetailId, 1);
    }

    WelcomePackages.set(characterId, true);
  }
}
