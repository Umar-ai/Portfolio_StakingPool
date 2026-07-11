//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";
import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address umar;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;
    uint256 private constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({umar: address(0), deployerKey: vm.envUint("PRIVATE_KEY")});
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.umar != address(0)) {
            return activeNetworkConfig;
        }
        ERC20Mock umarMock = new ERC20Mock("umar", "umar", msg.sender, 1000e8);
        return NetworkConfig({umar: address(umarMock), deployerKey: DEFAULT_ANVIL_KEY});
    }
}
