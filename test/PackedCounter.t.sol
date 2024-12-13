pragma solidity >=0.8.24;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { EncodedLengths, EncodedLengthsLib, EncodedLengthsInstance } from "@latticexyz/store/src/EncodedLengths.sol";

contract EncodedLengthsTest is Test {
  function test_ShouldPackSingleField() external {
    uint256 value = 10;

    EncodedLengths encodedLengths = EncodedLengthsLib.pack(value);

    bytes32 packedValue = EncodedLengthsInstance.unwrap(encodedLengths);
    console.logBytes32(packedValue);
  }
}
