// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Oracle.sol";

contract DeployOracle is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        
        Oracle oracle = new Oracle();

        vm.stopBroadcast();
    }
}