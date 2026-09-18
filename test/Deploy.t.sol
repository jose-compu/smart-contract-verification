// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeploySimpleBank} from "../script/Deploy.s.sol";
import {SimpleBank} from "../src/SimpleBank.sol";

contract DeploySimpleBankTest is Test {
    function test_RunDeploysAFreshBank() public {
        DeploySimpleBank deployer = new DeploySimpleBank();
        SimpleBank bank = deployer.run();

        assertTrue(address(bank).code.length > 0);
        assertEq(bank.balances(address(this)), 0);
        assertEq(address(bank).balance, 0);
    }
}
