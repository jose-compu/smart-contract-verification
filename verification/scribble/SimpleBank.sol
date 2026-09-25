// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

/// @notice Annotated copy of src/SimpleBank.sol. `totalCredits` is a ghost for P4.
///         Scribble turns the comments into runtime assertions. It does not prove them.
contract SimpleBank {
    mapping(address => uint256) public balances;
    uint256 internal totalCredits;

    /// #if_succeeds {:msg "P1 credit"} balances[msg.sender] == old(balances[msg.sender]) + msg.value;
    /// #if_succeeds {:msg "P1 reserves"} address(this).balance == old(address(this).balance);
    /// #if_succeeds {:msg "P4"} totalCredits == address(this).balance;
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalCredits += msg.value;
    }

    /// #if_succeeds {:msg "P3"} other == msg.sender || balances[other] == old(balances[other]);
    function depositWitness(address other) external payable {
        balances[msg.sender] += msg.value;
        totalCredits += msg.value;
    }

    /// #if_succeeds {:msg "P2 credit"} balances[msg.sender] == old(balances[msg.sender]) - amount;
    /// #if_succeeds {:msg "P2 reserves"} address(this).balance == old(address(this).balance) - amount;
    /// #if_succeeds {:msg "P4"} totalCredits == address(this).balance;
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        totalCredits -= amount;
        payable(msg.sender).transfer(amount);
    }

    /// #if_succeeds {:msg "P3"} other == msg.sender || balances[other] == old(balances[other]);
    function withdrawWitness(address other, uint256 amount) external {
        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        totalCredits -= amount;
        payable(msg.sender).transfer(amount);
    }
}
