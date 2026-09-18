// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleBank} from "../../src/SimpleBank.sol";
import {SimpleBankHandler} from "./SimpleBankHandler.sol";

contract SimpleBankHandlerTest is Test {
    SimpleBankHandler internal handler;

    function setUp() public {
        handler = new SimpleBankHandler(new SimpleBank());
    }

    function test_ActorCountIsThree() public {
        assertEq(handler.actorCount(), 3);
        assertEq(handler.actors(0), makeAddr("handler-alice"));
        assertEq(handler.actors(1), makeAddr("handler-bob"));
        assertEq(handler.actors(2), makeAddr("handler-carol"));
    }

    function test_WithdrawReturnsEarlyWhenActorHasNoCredit() public {
        handler.withdraw(0, 1 ether);
        assertEq(handler.ghostWithdrawn(), 0);
        assertEq(handler.ghostBalances(handler.actors(0)), 0);
    }

    function test_DepositThenWithdrawUpdatesGhostAccounting() public {
        handler.deposit(0, 1 ether);
        assertEq(handler.ghostDeposited(), 1 ether);

        handler.withdraw(0, 1 ether);
        assertEq(handler.ghostWithdrawn(), 1 ether);
        assertEq(handler.ghostBalances(handler.actors(0)), 0);
        assertEq(address(handler.BANK()).balance, 0);
    }
}
