// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {InsurancePayout} from "src/insurance/InsurancePayout.sol";

contract DeployInsurancePayout is Script {
    function run() external {
        address callbackSender = vm.envAddress("CALLBACK_SENDER_ADDR");
        vm.startBroadcast();
        new InsurancePayout(callbackSender);
        vm.stopBroadcast();
    }
}
