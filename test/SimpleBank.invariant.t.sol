// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleBank} from "../src/SimpleBank.sol";
import {SimpleBankHandler} from "./handlers/SimpleBankHandler.sol";

/// @notice Stateful fuzzing over deposit/withdraw sequences.
/// @dev Invariants assume ETH only enters through `deposit` (no `receive`/`fallback`).
contract SimpleBankInvariantTest is Test {
    SimpleBank internal bank;
    SimpleBankHandler internal handler;

    function setUp() public {
        bank = new SimpleBank();
        handler = new SimpleBankHandler(bank);

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = SimpleBankHandler.deposit.selector;
        selectors[1] = SimpleBankHandler.withdraw.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_ReservesMatchNetDeposits() public view {
        assertEq(address(bank).balance, handler.ghostDeposited() - handler.ghostWithdrawn());
    }

    function invariant_SumOfCreditsEqualsReserves() public view {
        uint256 sum;
        uint256 count = handler.actorCount();
        for (uint256 i = 0; i < count; ++i) {
            address actor = handler.actors(i);
            uint256 credit = bank.balances(actor);
            assertEq(credit, handler.ghostBalances(actor));
            sum += credit;
        }
        assertEq(sum, address(bank).balance);
    }

    function invariant_NoActorCreditExceedsReserves() public view {
        uint256 reserves = address(bank).balance;
        uint256 count = handler.actorCount();
        for (uint256 i = 0; i < count; ++i) {
            assertLe(bank.balances(handler.actors(i)), reserves);
        }
    }
}
