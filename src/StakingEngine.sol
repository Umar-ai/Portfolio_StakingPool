// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import { UmarToken } from "./UmarToken.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console.sol";

contract StakingEngine {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error StakingEngine__NotEnoughBalance();
    error StakingEngine__CannotBeLessThanZero();
    error StakingEngine__StakingFailed();
    error StakingEngine__NoRewardsToClaim();
    error StakingEngine__CannotWithDrawSomethingWentWrong();
    error StakingEngine__CannotBurnZero();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 private immutable umarToken;

    mapping(address => Stake) public stakes;
    address[] public stakesParticipants;
    uint256 private totalValueInStakes;
    uint256 private constant TOKEN_TO_DISTRIBUTE = 100e18;
    uint256 private constant DISTRIBUTION_PRECISION = 100e18;
    uint256 private lastBlockTimeStamp;

    struct Stake {
        uint256 stakedAmount;
        uint256 unClaimedRewards;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event amountStaked(address indexed depositor, uint256 indexed amount);
    event stakedAmountWithDrawed(address indexed withDrawer, uint256 indexed amount);
    event rewardsClaimed(address indexed claimer, uint256 indexed amount);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier lessThanZero(uint256 amount) {
        if (amount <= 0) {
            revert StakingEngine__CannotBeLessThanZero();
        }
        _;
    }

    constructor(address umartoken) {
        umarToken = UmarToken(umartoken);
    }

    function deposit(uint256 amount) public lessThanZero(amount) {
        if (umarToken.balanceOf(msg.sender) < amount) {
            revert StakingEngine__NotEnoughBalance();
        }
        if (stakes[msg.sender].stakedAmount == 0) {
            Stake memory stake = Stake({ stakedAmount: amount, unClaimedRewards: stakes[msg.sender].unClaimedRewards });
            stakes[msg.sender] = stake;
            stakesParticipants.push(msg.sender);
        } else {
            stakes[msg.sender].stakedAmount += amount;
        }

        totalValueInStakes += amount;
        umarToken.safeTransferFrom(msg.sender, address(this), amount);
        emit amountStaked(msg.sender, amount);
    }

    function withDraw(uint256 amount) public lessThanZero(amount) {
        if (stakes[msg.sender].stakedAmount < amount) {
            revert StakingEngine__NotEnoughBalance();
        } else {
            stakes[msg.sender].stakedAmount -= amount;
            if (stakes[msg.sender].stakedAmount == 0) {
                removeParticipantFromTheStakesRecord(msg.sender);
            }
        }
        totalValueInStakes -= amount;
        umarToken.safeTransfer(msg.sender, amount);
        emit stakedAmountWithDrawed(msg.sender, amount);
    }

    function claimReward() public {
        if (stakes[msg.sender].unClaimedRewards == 0) {
            revert StakingEngine__NoRewardsToClaim();
        }
        uint256 unClaimedRewards = stakes[msg.sender].unClaimedRewards;
        stakes[msg.sender].unClaimedRewards = 0;
        UmarToken(address(umarToken)).mint(address(this), unClaimedRewards);
        umarToken.safeTransfer(msg.sender, unClaimedRewards);
        emit rewardsClaimed(msg.sender, unClaimedRewards);
    }

    function distributeRewards() public {
        if (block.timestamp < lastBlockTimeStamp + 1) {
            return;
        }
        lastBlockTimeStamp = block.timestamp;
        if (stakesParticipants.length == 0 || totalValueInStakes == 0) {
            return;
        }
        for (uint256 i = 0; i < stakesParticipants.length; i++) {
            address participantAddress = stakesParticipants[i];
            uint256 participantStakedAmount = stakes[participantAddress].stakedAmount;
            uint256 totalReward = (participantStakedAmount * TOKEN_TO_DISTRIBUTE) / totalValueInStakes;
            stakes[participantAddress].unClaimedRewards += totalReward;
            console.log("participants unclaimed reward after reward", stakes[participantAddress].unClaimedRewards);
            console.log("participants balance reward after reward", stakes[participantAddress].stakedAmount);
            console.log("lenght of stakes participant", stakesParticipants.length);
        }
    }

    function removeParticipantFromTheStakesRecord(address participant) internal {
        (uint256 indexOfTheElementToRemove, bool found) = findIndex(participant);
        if (!found) {
            revert StakingEngine__CannotWithDrawSomethingWentWrong();
        }
        uint256 arrayLength = stakesParticipants.length - 1;
        if (arrayLength == indexOfTheElementToRemove) {
            stakesParticipants.pop();
        } else {
            stakesParticipants[indexOfTheElementToRemove] = stakesParticipants[arrayLength];
            stakesParticipants.pop();
        }
    }

    function findIndex(address participant) internal view returns (uint256, bool) {
        for (uint256 i = 0; i < stakesParticipants.length; i++) {
            if (stakesParticipants[i] == participant) {
                return (i, true);
            }
        }
        return (0, false);
    }

    function burnUmarToken(uint256 amount) internal {
        if (umarToken.balanceOf(address(this)) == 0) {
            revert StakingEngine__CannotBurnZero();
        }
        UmarToken(address(umarToken)).burn(amount);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getParticipantArrayLength() external view returns (uint256) {
        return stakesParticipants.length;
    }

    function getTotalValueInStakes() external view returns (uint256) {
        return totalValueInStakes;
    }

    function getParticipantAddress() external view returns (address[] memory) {
        return stakesParticipants;
    }
}
