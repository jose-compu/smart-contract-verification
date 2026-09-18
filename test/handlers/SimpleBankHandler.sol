// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleBank} from "../../src/SimpleBank.sol";

/// @notice Bounded caller used by invariant tests. Tracks ghost accounting so
///         the suite can assert solvency without reading storage layouts.
contract SimpleBankHandler is Test {
    SimpleBank public immutable BANK;

    address[] public actors;
    mapping(address => uint256) public ghostBalances;

    uint256 public ghostDeposited;
    uint256 public ghostWithdrawn;

    constructor(SimpleBank bank_) {
        BANK = bank_;
        actors.push(makeAddr("handler-alice"));
        actors.push(makeAddr("handler-bob"));
        actors.push(makeAddr("handler-carol"));
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function deposit(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 0, 50 ether);

        vm.deal(actor, actor.balance + amount);
        vm.prank(actor);
        BANK.deposit{value: amount}();

        ghostBalances[actor] += amount;
        ghostDeposited += amount;
    }

    function withdraw(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        uint256 credit = BANK.balances(actor);
        if (credit == 0) {
            return;
        }

        amount = bound(amount, 0, credit);

        uint256 actorBefore = actor.balance;
        vm.prank(actor);
        BANK.withdraw(amount);

        ghostBalances[actor] -= amount;
        ghostWithdrawn += amount;
        assertEq(actor.balance, actorBefore + amount);
    }
}
