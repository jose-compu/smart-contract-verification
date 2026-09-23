// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @title SimpleBank assertions for the SMTChecker
/// @notice Same credit update and `transfer` as `src/SimpleBank.sol`, plus `assert`s.
/// @dev `specDepositPreservesOther` and `specWithdrawPreservesOther` are witness
///      transactions for P3. They apply `_credit` / `_debit` and do not add another
///      way for ETH to enter. The CHC engine may call them.
contract SimpleBank {
    /// @notice Credited ETH balance of each depositor, in wei.
    mapping(address => uint256) public balances;

    function _credit(uint256 value) internal {
        balances[msg.sender] += value;
    }

    function _debit(uint256 amount) internal {
        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount;
    }

    /// @notice Credit `msg.value` to the caller.
    function deposit() external payable {
        uint256 creditBefore = balances[msg.sender];
        uint256 reservesBefore = address(this).balance - msg.value;
        _credit(msg.value);
        assert(balances[msg.sender] == creditBefore + msg.value);
        assert(address(this).balance == reservesBefore + msg.value);
    }

    /// @notice Debit `amount` from the caller and send that ETH to them.
    /// @param amount Wei to withdraw. Reverts if the caller's credit is insufficient.
    function withdraw(uint256 amount) external {
        uint256 creditBefore = balances[msg.sender];
        _debit(amount);
        assert(balances[msg.sender] == creditBefore - amount);
        payable(msg.sender).transfer(amount);
    }

    /// @notice P3 witness for `deposit`. `other` is not part of `src/SimpleBank.sol`.
    function specDepositPreservesOther(address other) external payable {
        uint256 otherBefore = balances[other];
        uint256 creditBefore = balances[msg.sender];
        uint256 reservesBefore = address(this).balance - msg.value;
        _credit(msg.value);
        assert(other == msg.sender || balances[other] == otherBefore);
        assert(balances[msg.sender] == creditBefore + msg.value);
        assert(address(this).balance == reservesBefore + msg.value);
    }

    /// @notice P3 witness for `withdraw`, checked before `transfer`.
    function specWithdrawPreservesOther(address other, uint256 amount) external {
        uint256 otherBefore = balances[other];
        uint256 creditBefore = balances[msg.sender];
        _debit(amount);
        assert(other == msg.sender || balances[other] == otherBefore);
        assert(balances[msg.sender] == creditBefore - amount);
        payable(msg.sender).transfer(amount);
    }
}
