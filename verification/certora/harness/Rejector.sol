// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @notice Receiver whose `receive` always reverts. Used as `msg.sender` for P5.
contract Rejector {
    receive() external payable {
        revert("reject");
    }

    fallback() external payable {
        revert("reject");
    }
}
