// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import {NeuroGuardRSC} from "../insurance/NeuroGuardRSC.sol";
contract DeployRSC is Script {
    function run() external {
        address service = vm.envAddress("SYSTEM_CONTRACT_ADDR");
        address oracle  = vm.envAddress("ORACLE_ADDR");
        address payout  = vm.envAddress("PAYOUT_ADDR");
        vm.startBroadcast();
        new NeuroGuardRSC(service, oracle, payout);
        vm.stopBroadcast();
    }
}