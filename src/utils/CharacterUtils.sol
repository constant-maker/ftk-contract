pragma solidity >=0.8.24;

import { IERC721Mintable } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";
import {
  ActiveChar,
  ActiveCharData,
  CharSupply,
  CharStats,
  CharStatsData,
  CharCurrentStats,
  CharCurrentStatsData,
  CharBaseStats,
  CharBaseStatsData,
  Contracts
} from "@codegen/index.sol";
import { CharacterType, StatType } from "@codegen/common.sol";
import { Errors } from "@common/Errors.sol";
import { Config } from "@common/Config.sol";

library CharacterUtils {
  /// @dev Mint character ERC721. Caller must have permission to call ERC721Sytem
  function mintERC721(address owner) internal returns (uint256 characterId) {
    uint256 newSupply = CharSupply.get() + 1;
    IERC721Mintable token = IERC721Mintable(Contracts.getErc721Token());
    token.safeMint(owner, newSupply);
    CharSupply.set(newSupply);
    return newSupply;
  }

  /// @dev Check whether characterId is owned by wallet
  function checkCharacterOwner(uint256 characterId, address wallet) internal {
    IERC721Mintable token = IERC721Mintable(Contracts.getErc721Token());
    address actualOwner = token.ownerOf(characterId);
    if (wallet != actualOwner) {
      revert Errors.Character_NotCharacterOwner(characterId, wallet);
    }
  }

  /// @dev Check character authorized
  function checkCharacterAuthorized(uint256 characterId, address wallet) internal {
    address sessionWallet = ActiveChar.getSessionWallet(characterId);
    if (sessionWallet == wallet) return;
    checkCharacterOwner(characterId, wallet);
  }

  /// @dev Set character stats with traits
  function initCharacterStatsWithTraits(uint256 characterId, uint16[3] memory traits) internal {
    uint16 sumTraits = 0;
    for (uint256 i = 0; i < traits.length; i++) {
      sumTraits += traits[i];
    }
    if (sumTraits != 5) {
      revert Errors.SpawnSystem_InvalidTraitStats(sumTraits);
    }
    uint16 atk = 1 + traits[0];
    uint16 def = 1 + traits[1];
    uint16 agi = 1 + traits[2];

    // set base stats
    CharBaseStatsData memory baseStats = CharBaseStatsData({ atk: atk, def: def, agi: agi });
    CharBaseStats.set(characterId, baseStats);

    // set stats
    CharStatsData memory stats = CharStatsData({
      weight: Config.DEFAULT_WEIGHT,
      level: 1,
      hp: Config.DEFAULT_HP,
      statPoint: 0,
      sp: Config.DEFAULT_SKILL_POINT
    });
    CharStats.set(characterId, stats);

    // set current stats
    CharCurrentStatsData memory currentStats = CharCurrentStatsData({
      exp: 0,
      weight: 0,
      hp: Config.DEFAULT_HP,
      atk: atk,
      def: def,
      agi: agi,
      ms: uint16(Config.DEFAULT_MOVEMENT_SPEED)
    });
    CharCurrentStats.set(characterId, currentStats);
  }
}
