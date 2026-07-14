//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import {DeployStakingEngine} from "../script/DeployStakingEngine.s.sol";
import {StakingEngine} from "../src/StakingEngine.sol";
import {UmarToken} from "../src/UmarToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";

contract StakingEngineHarness is StakingEngine {
    // We expose the internal function as an external one
    // UmarToken umarToken;

    constructor(address umarToken) StakingEngine(umarToken) {}

    function exposed_distributesRewards() external {
        distributeRewards();
    }
}

contract TestStakingEngine is Test {
    event amountStaked(address indexed depositor, uint256 indexed amount);

    StakingEngineHarness public harness;
    StakingEngine public stakingEngine;
    UmarToken public umarToken;
    address userOne;
    address tokenAddress;

    uint256 private constant AMOUNT_TO_DEPOSIT = 2e18;
    uint256 private constant AMOUNT_TO_WITHDRAW = 2e18;
    uint256 private constant INITIAL_BALANCE = 10e18;

    function setUp() external {
        DeployStakingEngine deployStakingEngine = new DeployStakingEngine();
        (stakingEngine, umarToken) = deployStakingEngine.run();
        userOne = makeAddr("userOne");
        harness = new StakingEngineHarness(address(umarToken));
        // umarToken.mint(own)
    }

    function testDepositBalanceOfDepsitorMustBeGreateThanTheAmount() public {
        vm.prank(userOne);
        vm.expectRevert(StakingEngine.StakingEngine__NotEnoughBalance.selector);
        stakingEngine.depsosit(AMOUNT_TO_DEPOSIT);
    }

    function testStakerAddedSuccessFullyAddedInTheStakersMapping() public deposit {
        (uint256 stakedAmount, uint256 unClaimedReward) = stakingEngine.stakes(userOne);
        assertEq(stakedAmount, AMOUNT_TO_DEPOSIT);
        assertEq(unClaimedReward, 0);
    }

    function testExistingStakerMappingSuccessfullyUpdated() public depositTwice {
        (uint256 stakedAmount, uint256 unClaimedReward) = stakingEngine.stakes(userOne);
        assertEq(stakedAmount, AMOUNT_TO_DEPOSIT + AMOUNT_TO_DEPOSIT);
        assertEq(unClaimedReward, 0);
    }

    function testDepositEventEmittedSuccessfully() public {
        deal(address(umarToken), userOne, INITIAL_BALANCE);
        vm.startPrank(userOne);
        umarToken.approve(address(stakingEngine), AMOUNT_TO_DEPOSIT);
        vm.expectEmit(true, true, false, false, address(stakingEngine));
        emit amountStaked(userOne, AMOUNT_TO_DEPOSIT);
        stakingEngine.depsosit(AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
    }

    function testWithDrawRevertWhenUserTryToWithDrawMoreThanBalance() public deposit {
        vm.expectRevert(StakingEngine.StakingEngine__NotEnoughBalance.selector);
        vm.prank(userOne);
        stakingEngine.withDraw(AMOUNT_TO_DEPOSIT + 1e18);
    }

    function testWithDrawUpdatesTheStakersMapping() public deposit {
        // vm.prank(userOne);
        // umarToken.approve(userOne,AMOUNT_TO_DEPOSIT);
        vm.prank(userOne);
        stakingEngine.withDraw(AMOUNT_TO_WITHDRAW);
        (uint256 depositedAmount,) = stakingEngine.stakes(userOne);
        assertEq(depositedAmount, 0);
    }

    function testWithDrawWhenUserWithDrawAllTokensShouldBeRemoveFromTheParitcipantsArray() public deposit {
        vm.prank(userOne);
        stakingEngine.withDraw(AMOUNT_TO_WITHDRAW);
        (uint256 depositedAmount,) = stakingEngine.stakes(userOne);
        assertEq(depositedAmount, 0);
        uint256 lengthOfStakeParticipantsArray = stakingEngine.getParticipantArrayLength();
        assertEq(lengthOfStakeParticipantsArray, 0);
    }

    function testDistributeGiveAllTokenToOneAndOnlyParticipant() public harnessDeposit {
        uint256 totalValuesInStakes = harness.getTotalValueInStakes();
        assertEq(totalValuesInStakes, AMOUNT_TO_DEPOSIT);
        harness.exposed_distributesRewards();
        (, uint256 unClaimedReward) = harness.stakes(userOne);
        uint256 actualUserOneUnClaimedReward = unClaimedReward;
        uint256 expectedUserOneUnClaimedRewards = 100e18;
        assertEq(actualUserOneUnClaimedReward, expectedUserOneUnClaimedRewards);
    }

    function testDistributeGiveTokensCorrectly() public {
        address testUserOne = makeAddr("testUserOne");
        address testUserTwo = makeAddr("testUserTwo");
        address testUserThree = makeAddr("testUserThree");
        address testUserFour = makeAddr("testUserFour");

        harnessDepositByAddress(testUserOne);
        harnessDepositByAddress(testUserTwo);
        harnessDepositByAddress(testUserThree);
        harnessDepositByAddress(testUserFour);

        uint256 totalValuesInStakes = harness.getTotalValueInStakes();
        assertEq(totalValuesInStakes, AMOUNT_TO_DEPOSIT * 4);
        harness.exposed_distributesRewards();

        (, uint256 unClaimedRewardOfUserOne) = harness.stakes(testUserOne);
        (, uint256 unClaimedRewardOfUserTwo) = harness.stakes(testUserTwo);
        (, uint256 unClaimedRewardOfUserThree) = harness.stakes(testUserThree);
        (, uint256 unClaimedRewardOfUserFour) = harness.stakes(testUserFour);

        uint256 expectedUnClaimedRewards = 25e18;
        assertEq(unClaimedRewardOfUserOne, expectedUnClaimedRewards);
        assertEq(unClaimedRewardOfUserTwo, expectedUnClaimedRewards);
        assertEq(unClaimedRewardOfUserThree, expectedUnClaimedRewards);
        assertEq(unClaimedRewardOfUserFour, expectedUnClaimedRewards);
    }

    function harnessDepositByAddress(address user) public {
        deal(address(umarToken), user, INITIAL_BALANCE);
        vm.startPrank(user);
        umarToken.approve(address(harness), AMOUNT_TO_DEPOSIT);
        harness.depsosit(AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////

    modifier harnessDeposit() {
        deal(address(umarToken), userOne, INITIAL_BALANCE);
        vm.startPrank(userOne);
        umarToken.approve(address(harness), AMOUNT_TO_DEPOSIT);
        harness.depsosit(AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
        _;
    }
    modifier deposit() {
        deal(address(umarToken), userOne, INITIAL_BALANCE);
        vm.startPrank(userOne);
        umarToken.approve(address(stakingEngine), AMOUNT_TO_DEPOSIT);
        stakingEngine.depsosit(AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
        _;
    }
    modifier depositTwice() {
        deal(address(umarToken), userOne, INITIAL_BALANCE);
        vm.startPrank(userOne);
        umarToken.approve(address(stakingEngine), INITIAL_BALANCE);
        stakingEngine.depsosit(AMOUNT_TO_DEPOSIT);
        stakingEngine.depsosit(AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
        _;
    }
}
