//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import { DeployStakingEngine } from "../../script/DeployStakingEngine.s.sol";
import { StakingEngine } from "../../src/StakingEngine.sol";
import { UmarToken } from "../../src/UmarToken.sol";
import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";

contract StakingEngineHarness is StakingEngine {
    // We expose the internal function as an external one
    // UmarToken umarToken;

    constructor(address umarToken) StakingEngine(umarToken) { }

    function exposed_distributesRewards() external {
        onlyForTestDistributeRewards();
    }

    function exposed_burnFunction(uint256 amount) external {
        burnUmarToken(amount);
    }
}

contract TestStakingEngine is Test {
    event amountStaked(address indexed depositor, uint256 indexed amount);
    event stakedAmountWithDrawed(address indexed withDrawer, uint256 indexed amount);
    event rewardsClaimed(address indexed claimer, uint256 indexed amount);

    StakingEngineHarness public harness;
    StakingEngine public stakingEngine;
    UmarToken public umarToken;
    address userOne;
    address tokenAddress;

    uint256 private constant AMOUNT_TO_DEPOSIT = 2e18;
    uint256 private constant AMOUNT_TO_WITHDRAW = 2e18;
    uint256 private constant INITIAL_BALANCE = 10e18;
    uint256 private constant TOTAL_REWARD_TO_DISTRIBUTE = 100e18;

    function setUp() external {
        DeployStakingEngine deployStakingEngine = new DeployStakingEngine();
        (stakingEngine, umarToken) = deployStakingEngine.run();
        userOne = makeAddr("userOne");
        harness = new StakingEngineHarness(address(umarToken));
        address currentTokenOwner = umarToken.owner();
        vm.prank(currentTokenOwner);
        umarToken.transferOwnership(address(harness));
        // umarToken.mint(own)
    }

    function testDepositBalanceOfDepsitorMustBeGreateThanTheAmount() public {
        vm.prank(userOne);
        vm.expectRevert(StakingEngine.StakingEngine__NotEnoughBalance.selector);
        harness.deposit(AMOUNT_TO_DEPOSIT);
    }

    function testStakerAddedSuccessFullyAddedInTheStakersMapping() public harnessDeposit {
        (uint256 stakedAmount, uint256 unClaimedReward) = harness.stakes(userOne);
        assertEq(stakedAmount, AMOUNT_TO_DEPOSIT);
        assertEq(unClaimedReward, 0);
    }

    function testExistingStakerMappingSuccessfullyUpdated() public harnessDepositTwice {
        (uint256 stakedAmount, uint256 unClaimedReward) = harness.stakes(userOne);
        assertEq(stakedAmount, AMOUNT_TO_DEPOSIT + AMOUNT_TO_DEPOSIT);
        assertEq(unClaimedReward, 0);
    }

    function testDepositEventEmittedSuccessfully() public {
        deal(address(umarToken), userOne, INITIAL_BALANCE);
        vm.startPrank(userOne);
        umarToken.approve(address(harness), AMOUNT_TO_DEPOSIT);
        vm.expectEmit(true, true, false, false, address(harness));
        emit amountStaked(userOne, AMOUNT_TO_DEPOSIT);
        harness.deposit(AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
    }

    function testWithDrawRevertWhenUserTryToWithDrawMoreThanBalance() public harnessDeposit {
        vm.expectRevert(StakingEngine.StakingEngine__NotEnoughBalance.selector);
        vm.prank(userOne);
        harness.withDraw(AMOUNT_TO_DEPOSIT + 1e18);
    }

    function testWithDrawUpdatesTheStakersMapping() public harnessDeposit {
        vm.prank(userOne);
        harness.withDraw(AMOUNT_TO_WITHDRAW);
        (uint256 depositedAmount,) = harness.stakes(userOne);
        assertEq(depositedAmount, 0);
    }

    function testWithDrawWhenUserWithDrawAllTokensShouldBeRemoveFromTheParitcipantsArray() public harnessDeposit {
        vm.prank(userOne);
        harness.withDraw(AMOUNT_TO_WITHDRAW);
        (uint256 depositedAmount,) = harness.stakes(userOne);
        assertEq(depositedAmount, 0);
        uint256 lengthOfStakeParticipantsArray = harness.getParticipantArrayLength();
        assertEq(lengthOfStakeParticipantsArray, 0);
    }

    function testWithDrawEventEmittedSuccessfully() public {
        deal(address(umarToken), userOne, INITIAL_BALANCE);
        vm.startPrank(userOne);
        umarToken.approve(address(harness), AMOUNT_TO_DEPOSIT);
        harness.deposit(AMOUNT_TO_DEPOSIT);
        vm.expectEmit(true, true, false, false, address(harness));
        emit stakedAmountWithDrawed(userOne, AMOUNT_TO_DEPOSIT);
        harness.withDraw(AMOUNT_TO_WITHDRAW);
        vm.stopPrank();
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
        harness.deposit(AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
    }

    function testClaimRewardsRevertsWhenNoRewardToClaim() public {
        harness.exposed_distributesRewards();
        vm.expectRevert(StakingEngine.StakingEngine__NoRewardsToClaim.selector);
        vm.prank(userOne);
        harness.claimReward();
    }

    function testClaimRewardWorkCorrectly() public harnessDeposit {
        harness.exposed_distributesRewards();
        (, uint256 unClaimedReward) = harness.stakes(userOne);
        assertEq(unClaimedReward, 100e18);
        uint256 startingBalance = umarToken.balanceOf(userOne);
        vm.prank(userOne);
        harness.claimReward();
        uint256 endingBalance = umarToken.balanceOf(userOne);
        assertEq(startingBalance + unClaimedReward, endingBalance);
    }

    function testClaimRewardEventEmittedSuccessfully() public {
        deal(address(umarToken), userOne, INITIAL_BALANCE);
        vm.startPrank(userOne);
        umarToken.approve(address(harness), AMOUNT_TO_DEPOSIT);
        harness.deposit(AMOUNT_TO_DEPOSIT);
        harness.exposed_distributesRewards();
        vm.expectEmit(true, true, false, false, address(harness));
        emit rewardsClaimed(userOne, TOTAL_REWARD_TO_DISTRIBUTE);
        harness.claimReward();
        vm.stopPrank();
    }

    function testDistributeRewardReturnsWhenParticipantsArrayLenghtIsZero() public {
        harness.exposed_distributesRewards();
    }

    function testBurnWorkCorrectly() public {
        deal(address(umarToken), address(harness), INITIAL_BALANCE);
        harness.exposed_burnFunction(INITIAL_BALANCE);
        uint256 actualBalanceOfHarnessContract = umarToken.balanceOf(address(harness));
        uint256 expectedBalanceOfHarnessContract = 0;
        assertEq(actualBalanceOfHarnessContract, expectedBalanceOfHarnessContract);
    }

    //////////////////////////////////////////////////////////

    modifier harnessDeposit() {
        deal(address(umarToken), userOne, INITIAL_BALANCE);
        vm.startPrank(userOne);
        umarToken.approve(address(harness), AMOUNT_TO_DEPOSIT);
        harness.deposit(AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
        _;
    }
    modifier harnessDepositTwice() {
        deal(address(umarToken), userOne, INITIAL_BALANCE);
        vm.startPrank(userOne);
        umarToken.approve(address(harness), INITIAL_BALANCE);
        harness.deposit(AMOUNT_TO_DEPOSIT);
        harness.deposit(AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
        _;
    }
}
