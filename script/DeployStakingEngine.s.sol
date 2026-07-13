//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;
import {HelperConfig} from "./HelperConfig.s.sol";
import {StakingEngine} from "../src/StakingEngine.sol";
import {UmarToken} from "../src/UmarToken.sol";
import {Script} from "forge-std/Script.sol";

contract DeployStakingEngine is Script {
    uint256 private constant STARTING_BALANCE = 100e18;

    function run() external returns (StakingEngine, UmarToken) {
        HelperConfig helperConfig = new HelperConfig();
        (, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        UmarToken umarToken = new UmarToken();
        StakingEngine stakingEngine = new StakingEngine(address(umarToken));
        umarToken.mint(umarToken.owner(), STARTING_BALANCE);
        umarToken.transferOwnership(address(stakingEngine));
        vm.stopBroadcast();
        return (stakingEngine, umarToken);
    }
}
