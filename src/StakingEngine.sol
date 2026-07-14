//SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

import {UmarToken} from "./UmarToken.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingEngine {
    using SafeERC20 for IERC20;

    ///////////////////////////////////
    ////////////Errors////////////////
    /////////////////////////////////
    error StakingEngine__NotEnoughBalance();
    error StakingEngine__CannotBeLessThanZero();
    error StakingEngine__StakingFailed();
    error StakingEngine__NoRewardsToClaim();
    error StakingEngine__CannotWithDrawSomethingWentWrong();

    ///////////////////////////////////
    ////////////Events////////////////
    /////////////////////////////////

    event amountStaked(address indexed depositor, uint256 indexed amount);
    event stakedAmountWithDrawed(address withDrawer, uint256 amount);
    event rewardsClaimed(address claimer, uint256 amount);

    struct Stake {
        uint256 stakedAmount;
        uint256 unClaimedRewards;
    }

    //mint before giving reward

    IERC20 private immutable umarToken;

    mapping(address => Stake) public stakes;
    address[] public stakesParticipants;
    uint256 private totalValueInStakes;
    uint256 private constant TOKEN_TO_DISTRIBUTE = 100e18;
    uint256 private constant DISTRIBUTION_PRECISION = 100e18;

    constructor(address umartoken) {
        umarToken = UmarToken(umartoken);
    }

    //TODO: remove someone from the participants array if his stakedAmount reaches to zero;

    function depsosit(uint256 amount) public lessThanZero(amount) {
        if (umarToken.balanceOf(msg.sender) < amount) {
            revert StakingEngine__NotEnoughBalance();
        }
        if (stakes[msg.sender].stakedAmount == 0 && stakes[msg.sender].unClaimedRewards == 0) {
            Stake memory stake = Stake({stakedAmount: amount, unClaimedRewards: 0});
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

    function claimPendingReward() public {
        if (stakes[msg.sender].unClaimedRewards == 0) {
            revert StakingEngine__NoRewardsToClaim();
        }
        uint256 unClaimedRewards = stakes[msg.sender].unClaimedRewards;
        stakes[msg.sender].unClaimedRewards = 0;
        umarToken.safeTransfer(msg.sender, unClaimedRewards);
        emit rewardsClaimed(msg.sender, unClaimedRewards);
    }

    function distributeRewards() internal {
        for (uint256 i = 0; i < stakesParticipants.length; i++) {
            address participantAddress = stakesParticipants[i];
            uint256 participantStakedAmount = stakes[participantAddress].stakedAmount;
            uint256 totalReward = (participantStakedAmount * TOKEN_TO_DISTRIBUTE) / totalValueInStakes;
            stakes[participantAddress].unClaimedRewards += totalReward;
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
        for (uint256 i = 0; i <= stakesParticipants.length; i++) {
            if (stakesParticipants[i] == participant) {
                return (i, true);
            }
        }
        return (0, false);
    }

    modifier lessThanZero(uint256 amount) {
        if (amount < 0) {
            revert StakingEngine__CannotBeLessThanZero();
        }
        _;
    }

    /////////////////////////////////////////////////Getters//////////////////////////////////////////////////////

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
