pragma solidity >=0.8.24;

import { CharInfoData } from "@codegen/index.sol";
import { CharacterType } from "@codegen/common.sol";

library CharacterInfoMock {
  function getCharacterInfoData() internal pure returns (CharInfoData memory) {
    uint16[3] memory traits = [uint16(1), uint16(1), uint16(3)];
    return CharInfoData({ kingdomId: 1, characterType: CharacterType.Male, name: "character", traits: traits });
  }

  function getCharacterInfoDataWithName(string memory name) internal pure returns (CharInfoData memory) {
    uint16[3] memory traits = [uint16(1), uint16(1), uint16(3)];
    return CharInfoData({ kingdomId: 1, characterType: CharacterType.Male, name: name, traits: traits });
  }

  function getCharacterInfoDataWithNameAndKingdomId(
    string memory name,
    uint8 kingdomId
  )
    internal
    pure
    returns (CharInfoData memory)
  {
    uint16[3] memory traits = [uint16(1), uint16(1), uint16(3)];
    return CharInfoData({ kingdomId: kingdomId, characterType: CharacterType.Male, name: name, traits: traits });
  }
}
