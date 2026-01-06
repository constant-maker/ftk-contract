pragma solidity >=0.8.24;

import { AllianceV2, AllianceV2Data, CharInfo, TileInfo3 } from "@codegen/index.sol";
import { ZoneType } from "@codegen/common.sol";

struct ZoneInfo {
  uint8 tileKingdomId;
  uint8 attackerKingdomId;
  uint8 defenderKingdomId;
  ZoneType attackerZoneType;
  ZoneType defenderZoneType;
  ZoneType tileZoneType;
}

library KingdomUtils {
  function getIsAlliance(uint8 kingdomA, uint8 kingdomB) public view returns (bool) {
    AllianceV2Data memory allianceData = AllianceV2.get(kingdomA, kingdomB);
    bool isAlliance = allianceData.isAlliance && allianceData.isApproved;
    if (isAlliance) return true;
    allianceData = AllianceV2.get(kingdomB, kingdomA);
    isAlliance = allianceData.isAlliance && allianceData.isApproved;
    return isAlliance;
  }

  // getZoneTypeFull return zone type + kingdom id data based on defender and attacker kingdom id
  function getZoneTypeFull(
    int32 x,
    int32 y,
    uint256 attackerId,
    uint256 defenderId
  )
    public
    view
    returns (ZoneInfo memory zoneInfo)
  {
    uint8 attackerKingdomId = CharInfo.getKingdomId(attackerId);
    uint8 defenderKingdomId = CharInfo.getKingdomId(defenderId);
    uint8 tileKingdomId = TileInfo3.getKingdomId(x, y);
    ZoneType tileZoneType = TileInfo3.getZoneType(x, y);
    ZoneType defenderZoneType = ZoneType.Black;
    ZoneType attackerZoneType = ZoneType.Black;
    bool isBlackTile = tileZoneType == ZoneType.Black;
    if (isBlackTile && defenderKingdomId == tileKingdomId) {
      defenderZoneType = ZoneType.Red;
    } else if (!isBlackTile) {
      defenderZoneType = (defenderKingdomId == tileKingdomId) ? ZoneType.Green : ZoneType.Red;
    }
    if (isBlackTile && attackerKingdomId == tileKingdomId) {
      attackerZoneType = ZoneType.Red;
    } else if (!isBlackTile) {
      attackerZoneType = (attackerKingdomId == tileKingdomId) ? ZoneType.Green : ZoneType.Red;
    }
    return ZoneInfo({
      tileKingdomId: tileKingdomId,
      attackerKingdomId: attackerKingdomId,
      defenderKingdomId: defenderKingdomId,
      attackerZoneType: attackerZoneType,
      defenderZoneType: defenderZoneType,
      tileZoneType: tileZoneType
    });
  }

  // getZoneType return zone type
  function getZoneType(
    int32 x,
    int32 y,
    uint256 attackerId,
    uint256 defenderId
  )
    public
    view
    returns (ZoneType zoneType)
  {
    uint8 attackerKingdomId = CharInfo.getKingdomId(attackerId);
    uint8 defenderKingdomId = CharInfo.getKingdomId(defenderId);
    uint8 tileKingdomId = TileInfo3.getKingdomId(x, y);
    ZoneType zoneType = TileInfo3.getZoneType(x, y); // for defender
    if (zoneType == ZoneType.Black && defenderKingdomId == tileKingdomId) {
      zoneType = ZoneType.Red;
    } else if (zoneType != ZoneType.Black) {
      zoneType = (defenderKingdomId == tileKingdomId) ? ZoneType.Green : ZoneType.Red;
    }
    return zoneType;
  }
}
