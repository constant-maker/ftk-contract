pragma solidity >=0.8.24;

import { PlatformRevenue } from "@codegen/index.sol";
import { Config, Errors } from "@common/index.sol";

library PlatformUtils {
  
  uint8 private constant BUCKET_ROOT_TEAM = 0;
  uint8 private constant BUCKET_ROOT_BACKER = 1;
  uint8 private constant BUCKET_ROOT_VAULT = 2;
  uint8 private constant BUCKET_APP_TEAM = 3;
  uint8 private constant BUCKET_APP_BACKER = 4;
  uint8 private constant BUCKET_APP_VAULT = 5;

  /// @dev Calculate the platform fee based on the given value
  function getPlatformFee(uint256 value) internal pure returns (uint256) {
    if (value == 0) return 0;
    return (value * Config.PLATFORM_FEE_PERCENTAGE + 99) / 100; // rounding up
  }

  /// @dev Update the total platform revenue, increase only
  function updateTotalRevenue(uint256 amount) internal {
    PlatformRevenue.setTotalRevenue(PlatformRevenue.getTotalRevenue() + amount);
  }

  /// @dev Update root team crystal
  function updateRootTeamCrystal(uint256 amount, bool isGained) internal {
    if (isGained) {
      (uint256 teamShare, uint256 backerShare) = _splitTeamAndBackerShare(amount);
      _updateCrystalBucket(
        teamShare,
        true,
        BUCKET_ROOT_TEAM,
        PlatformRevenue.getRootTeamCrystal,
        PlatformRevenue.setRootTeamCrystal
      );
      _updateCrystalBucket(
        backerShare,
        true,
        BUCKET_ROOT_BACKER,
        PlatformRevenue.getRootBackerCrystal,
        PlatformRevenue.setRootBackerCrystal
      );
      return;
    }

    _updateCrystalBucket(
      amount,
      false,
      BUCKET_ROOT_TEAM,
      PlatformRevenue.getRootTeamCrystal,
      PlatformRevenue.setRootTeamCrystal
    );
  }

  /// @dev Update root backer crystal
  function updateRootBackerCrystal(uint256 amount, bool isGained) internal {
    _updateCrystalBucket(
      amount,
      isGained,
      BUCKET_ROOT_BACKER,
      PlatformRevenue.getRootBackerCrystal,
      PlatformRevenue.setRootBackerCrystal
    );
  }

  /// @dev Update root vault crystal
  function updateRootVaultCrystal(uint256 amount, bool isGained) internal {
    _updateCrystalBucket(
      amount,
      isGained,
      BUCKET_ROOT_VAULT,
      PlatformRevenue.getRootVaultCrystal,
      PlatformRevenue.setRootVaultCrystal
    );
  }

  /// @dev Update app team crystal
  function updateAppTeamCrystal(uint256 amount, bool isGained) internal {
    if (isGained) {
      (uint256 teamShare, uint256 backerShare) = _splitTeamAndBackerShare(amount);
      _updateCrystalBucket(
        teamShare,
        true,
        BUCKET_APP_TEAM,
        PlatformRevenue.getAppTeamCrystal,
        PlatformRevenue.setAppTeamCrystal
      );
      _updateCrystalBucket(
        backerShare,
        true,
        BUCKET_APP_BACKER,
        PlatformRevenue.getAppBackerCrystal,
        PlatformRevenue.setAppBackerCrystal
      );
      return;
    }

    _updateCrystalBucket(
      amount,
      false,
      BUCKET_APP_TEAM,
      PlatformRevenue.getAppTeamCrystal,
      PlatformRevenue.setAppTeamCrystal
    );
  }

  /// @dev Update app backer crystal
  function updateAppBackerCrystal(uint256 amount, bool isGained) internal {
    _updateCrystalBucket(
      amount,
      isGained,
      BUCKET_APP_BACKER,
      PlatformRevenue.getAppBackerCrystal,
      PlatformRevenue.setAppBackerCrystal
    );
  }

  /// @dev Update app vault crystal
  function updateAppVaultCrystal(uint256 amount, bool isGained) internal {
    _updateCrystalBucket(
      amount,
      isGained,
      BUCKET_APP_VAULT,
      PlatformRevenue.getAppVaultCrystal,
      PlatformRevenue.setAppVaultCrystal
    );
  }

  /// @dev Shared bucket update logic to keep root/app crystal updates consistent.
  function _splitTeamAndBackerShare(uint256 amount) private pure returns (uint256 teamShare, uint256 backerShare) {
    backerShare = (amount * Config.FEE_PERCENT_SHARE_TO_BACKER) / 100;
    teamShare = amount - backerShare;
  }

  /// @dev Shared bucket update logic to keep root/app crystal updates consistent.
  function _updateCrystalBucket(
    uint256 amount,
    bool isGained,
    uint8 bucket,
    function() internal view returns (uint256) getCurrent,
    function(uint256) internal setCurrent
  ) private {
    uint256 current = getCurrent();

    if (isGained) {
      updateTotalRevenue(amount);
      setCurrent(current + amount);
      return;
    }

    if (current < amount) {
      revert Errors.InsufficientCrystalBalance(bucket, current, amount);
    }

    setCurrent(current - amount);
  }
}
