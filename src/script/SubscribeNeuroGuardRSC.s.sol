// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {NeuroGuardRSC} from "../insurance/NeuroGuardRSC.sol";

/// @dev Run after DeployRSC. Set NEUROGUARD_RSC_ADDR in .env to the deployed RSC address.
contract SubscribeNeuroGuardRSC is Script {
    function run() external {
        address payable rsc = payable(vm.envAddress("NEUROGUARD_RSC_ADDR"));
        vm.startBroadcast();
        NeuroGuardRSC(rsc).subscribeToOracleEvents();
        vm.stopBroadcast();
    }
}
