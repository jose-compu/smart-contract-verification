// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @title SimpleBank
/// @notice Minimal ETH vault used as the running example for tests and formal verification.
/// @dev Credits are stored per address. Withdrawals send ETH with `transfer`.
contract SimpleBank {
    /// @notice Credited ETH balance of each depositor, in wei.
    mapping(address => uint256) public balances;

    /// @notice Credit `msg.value` to the caller.
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /// @notice Debit `amount` from the caller and send that ETH to them.
    /// @param amount Wei to withdraw. Reverts if the caller's credit is insufficient.
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }
}
