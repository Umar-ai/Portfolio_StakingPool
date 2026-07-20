//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import { StakingEngine } from "../../../src/StakingEngine.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { UmarToken } from "../../../src/UmarToken.sol";
import { Test, console } from "forge-std/Test.sol";

contract StopOnRevertHandler is Test {
    using EnumerableSet for EnumerableSet.AddressSet;
    StakingEngine stakingEngine;
    UmarToken umarToken;
    uint256 public ghost_totalValueInStakes;
    address[] public actors;
    uint256 private constant MAXIMUM_DEPOSIT = type(uint96).max;

    constructor(StakingEngine _stakingEngine, UmarToken _umarToken) {
        stakingEngine = _stakingEngine;
        umarToken = _umarToken;
        vm.prank(address(stakingEngine));
        umarToken.transferOwnership(address(stakingEngine));
        for (uint256 i = 0; i < 5; i++) {
            // Generates distinct, valid addresses (e.g., User 0, User 1...)
            actors.push(makeAddr(string(abi.encodePacked("user", i))));
        }
    }

    function handlerDeposit(uint256 actorIndex, uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1, MAXIMUM_DEPOSIT);
        address actorAddress = actors[actorIndex % actors.length];
        vm.prank(address(stakingEngine));
        umarToken.mint(actorAddress, amountToDeposit);
        vm.startPrank(actorAddress);
        umarToken.approve(address(stakingEngine), amountToDeposit);
        stakingEngine.deposit(amountToDeposit);
        vm.stopPrank();
        ghost_totalValueInStakes += amountToDeposit;
    }

    function handlerWithDraw(uint256 actorIndex, uint256 amountToWithDraw) public {
        address actorAddress = actors[actorIndex % actors.length];
        (uint256 actorDepositedAmount,) = stakingEngine.stakes(actorAddress);
        amountToWithDraw = bound(amountToWithDraw, 0, actorDepositedAmount);
        if (amountToWithDraw == 0) {
            return;
        }
        vm.prank(actorAddress);
        stakingEngine.withDraw(amountToWithDraw);
        ghost_totalValueInStakes -= amountToWithDraw;
    }

    function handlerDistributeRewards() public {
        stakingEngine.distributeRewards();
    }

    function handlerClaimReward(uint256 actorIndex) public {
        address actorAddress = actors[actorIndex % actors.length];
        (, uint256 userUnclaimedRewards) = stakingEngine.stakes(actorAddress);
        if (userUnclaimedRewards == 0) {
            return;
        }
        vm.prank(actorAddress);
        stakingEngine.claimReward();
    }
}
