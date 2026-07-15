//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";
import { StakingEngine } from "../../../src/StakingEngine.sol";
import { UmarToken } from "../../../src/UmarToken.sol";
import { DeployStakingEngine } from "../../../script/DeployStakingEngine.s.sol";
import { StopOnRevertHandler } from "./StopOnRevertHandler.t.sol";

contract StopOnRevertInvariant is StdInvariant, Test {
    // if participant deposited amount is zero he must not be in the participants array

    StakingEngine public stakingEngine;
    UmarToken public umarToken;
    StopOnRevertHandler public handler;

    //total stakes is equal to the deposited stakes by each user;
    //total Balance of the stakingEngine must be greater or equal to totalTokenDeposited

    function setUp() public {
        DeployStakingEngine deployStakingEngine = new DeployStakingEngine();
        (stakingEngine, umarToken) = deployStakingEngine.run();
        handler = new StopOnRevertHandler(stakingEngine, umarToken);
        targetContract(address(handler));
    }

    function invariant_protocolTotalValueInTheStakingPoolMustBeEqualToDepositedAmountByEachStaker() public view {
        uint256 totalValueInTheStakingPool = stakingEngine.getTotalValueInStakes();
        uint256 totalAmountDepositedByEachUserInTheStakingPool = handler.ghost_totalValueInStakes();
        assert(totalValueInTheStakingPool == totalAmountDepositedByEachUserInTheStakingPool);
    }

    function invariant_protocolTotalBalanceMustBeGreaterOrEqualToTotalValueInStakes() public view {
        uint256 totalValueInTheStakingPool = stakingEngine.getTotalValueInStakes();
        uint256 stakingEngineTotalBalance = umarToken.balanceOf(address(stakingEngine));
        assert(stakingEngineTotalBalance >= totalValueInTheStakingPool);
    }
}
