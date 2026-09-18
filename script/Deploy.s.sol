// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {SimpleBank} from "../src/SimpleBank.sol";

/// @notice Broadcasts a fresh `SimpleBank` deployment.
contract DeploySimpleBank is Script {
    function run() external returns (SimpleBank bank) {
        vm.startBroadcast();
        bank = new SimpleBank();
        vm.stopBroadcast();
    }
}
