# UmarToken Staking Engine

A Solidity-based staking platform that allows users to deposit **UmarToken (ERC-20)**, earn rewards over time, and withdraw their stake at any point. Reward distribution is automated on-chain via **Chainlink Automation (Upkeep)**.

---

## 📖 Overview

`StakingEngine` lets users:

- **Stake** UmarToken into the contract.
- **Earn rewards** automatically, distributed proportionally to their share of the total staked value.
- **Withdraw** part or all of their stake at any time.
- **Claim** accumulated rewards on demand.

The contract is built with security and gas-efficiency in mind, using OpenZeppelin's `SafeERC20` for all token transfers and custom errors instead of `require` strings.

---

## 🗂️ Project Structure

```
├── src/
│   ├── StakingEngine.sol      # Core staking, reward, and withdrawal logic
│   └── UmarToken.sol          # ERC-20 token used for staking and rewards
│
├── script/
│   ├── DeployStakingEngine.s.sol   # Deployment script for StakingEngine
│   └── HelperConfig.s.sol          # Network-specific configuration helper
│
└── test/
    ├── fuzz/
    │   └── failOnRevert/
    │       ├── StopOnRevertHandler.t.sol     # Handler contract for invariant testing
    │       └── StopOnRevertInvariant.t.sol   # Invariant test suite
    └── uint/
        └── TestStakingEngine.t.sol           # Unit tests for StakingEngine
```

- **`src/`** — Contains the core smart contracts of the protocol.
- **`script/`** — Foundry deployment and configuration scripts.
- **`test/`** — Unit and fuzz/invariant tests covering staking, withdrawal, and reward logic.

---

## ⚙️ How It Works

### 1. Staking (`deposit`)

- A user calls `deposit(amount)` to stake their UmarToken.
- Tokens are transferred from the user to the contract using `safeTransferFrom`.
- If it's the user's **first deposit**, a new `Stake` struct is created and their address is pushed into the `stakesParticipants` array (this array tracks everyone currently eligible for rewards).
- If the user has **already staked before**, their existing `stakedAmount` is simply increased.
- The contract's `totalValueInStakes` is updated to reflect the new total.

```solidity
function deposit(uint256 amount) public lessThanZero(amount) {
    // adds to stake, registers participant if new, transfers tokens in
}
```

### 2. Reward Distribution (`distributeRewards`)

- Reward distribution is **not manual** — it is triggered externally by a **Chainlink Automation Upkeep**, restricted via the `onlyChainLinkUpKeepCanCallIt` modifier so only the registered Chainlink Upkeep address can call it.
- On each valid call (gated by a timestamp check against `lastBlockTimeStamp`), the contract distributes a **fixed pool of `TOKEN_TO_DISTRIBUTE` (100 tokens)** among **all current participants**, proportional to how much each one has staked relative to `totalValueInStakes`:

```
userReward = (userStakedAmount * TOKEN_TO_DISTRIBUTE) / totalValueInStakes
```

- These rewards are **not paid out immediately** — they accumulate in each user's `unClaimedRewards` field until the user actively claims them.
- If there are no participants or nothing staked, the function simply returns without doing anything (no wasted gas).

### 3. Claiming Rewards (`claimReward`)

- A user calls `claimReward()` to withdraw their accumulated rewards.
- The contract **mints** new UmarToken equal to the user's `unClaimedRewards` and transfers them to the user.
- The user's `unClaimedRewards` is reset to zero, and an event is emitted.

### 4. Withdrawing Stake (`withDraw`) — and Participant Removal

Withdrawal is one of the most important mechanisms for keeping the rewards system fair and accurate:

- A user calls `withDraw(amount)` to unstake part or all of their tokens.
- The contract checks that the user has enough staked balance, then decreases their `stakedAmount` and the global `totalValueInStakes`.
- **If a user withdraws their entire stake (their `stakedAmount` becomes `0`)**, they are no longer entitled to future rewards, so they must be **removed from the `stakesParticipants` array**. This is handled by `removeParticipantFromTheStakesRecord`:

  1. `findIndex(participant)` scans the array and returns the participant's index (and whether they were found).
  2. To remove the participant **without leaving gaps** and **without expensive array shifting**, the contract uses the **swap-and-pop** pattern:
     - If the participant is the **last element**, it's simply popped off the array.
     - Otherwise, the **last element is moved into the removed participant's slot**, and then the array is popped, shrinking its length by one.
  3. This keeps the `stakesParticipants` array tightly packed and gas-efficient (O(1) removal instead of O(n) shifting), which matters since this array is iterated over on every `distributeRewards()` call.
- Finally, the withdrawn tokens are transferred back to the user via `safeTransfer`.

```solidity
function withDraw(uint256 amount) public lessThanZero(amount) {
    // decreases stake, removes participant if fully withdrawn, transfers tokens out
}
```

> ⚠️ Partial withdrawals do **not** remove the user from the participants array — they remain eligible for rewards proportional to their remaining staked balance.

---

## 📜 Contract Reference

### State Variables

| Variable | Description |
|---|---|
| `umarToken` | Immutable reference to the staking/reward ERC-20 token |
| `stakes` | Mapping of user address → `Stake` struct (`stakedAmount`, `unClaimedRewards`) |
| `stakesParticipants` | Array of addresses with an active (non-zero) stake |
| `totalValueInStakes` | Total amount of tokens currently staked across all users |
| `TOKEN_TO_DISTRIBUTE` | Fixed reward pool (100 tokens) distributed per distribution cycle |
| `lastBlockTimeStamp` | Timestamp of the last successful reward distribution |
| `CHAINLINK_UPKEEP_ADDRESS` | The only address authorized to call `distributeRewards` |

### Core Functions

| Function | Visibility | Description |
|---|---|---|
| `deposit(uint256 amount)` | `public` | Stakes tokens and registers the user as a participant |
| `withDraw(uint256 amount)` | `public` | Withdraws staked tokens; removes user from participants if fully withdrawn |
| `claimReward()` | `public` | Mints and transfers accumulated rewards to the caller |
| `distributeRewards()` | `external` | Chainlink-Automation-only function that distributes rewards to all participants |

### Getters

| Function | Description |
|---|---|
| `getParticipantArrayLength()` | Returns the number of active participants |
| `getTotalValueInStakes()` | Returns the total amount currently staked |
| `getParticipantAddress()` | Returns the full list of participant addresses |
| `getTotalBalance(address user)` | Returns a user's UmarToken balance |
| `getChainLinkUpKeepAddress()` | Returns the authorized Chainlink Upkeep address |

### Custom Errors

| Error | Thrown When |
|---|---|
| `StakingEngine__NotEnoughBalance` | User tries to deposit/withdraw more than they hold/staked |
| `StakingEngine__CannotBeLessThanZero` | An amount passed is zero (or invalid) |
| `StakingEngine__StakingFailed` | A staking operation fails |
| `StakingEngine__NoRewardsToClaim` | User has no unclaimed rewards to claim |
| `StakingEngine__CannotWithDrawSomethingWentWrong` | Participant removal fails unexpectedly during withdrawal |
| `StakingEngine__CannotBurnZero` | Attempting to burn tokens with a zero contract balance |
| `StakingEngine__OnlyChainLinkCanCallIt` | Caller of `distributeRewards` is not the Chainlink Upkeep address |

### Events

| Event | Emitted On |
|---|---|
| `amountStaked(address indexed depositor, uint256 indexed amount)` | Successful deposit |
| `stakedAmountWithDrawed(address indexed withDrawer, uint256 indexed amount)` | Successful withdrawal |
| `rewardsClaimed(address indexed claimer, uint256 indexed amount)` | Successful reward claim |

---

## 🔗 Automation

Reward distribution relies on **Chainlink Automation** to periodically call `distributeRewards()`. This keeps the reward cycle running trustlessly without requiring manual intervention or a centralized keeper, while the `onlyChainLinkUpKeepCanCallIt` modifier ensures only the registered Upkeep contract can trigger distribution.

---

## 🧪 Testing

The project includes both **unit tests** and **fuzz/invariant tests**:

- `test/uint/TestStakingEngine.t.sol` — Unit tests covering deposits, withdrawals, claims, and reward math.
- `test/fuzz/failOnRevert/` — Invariant-based fuzz tests (`StopOnRevertHandler.t.sol` + `StopOnRevertInvariant.t.sol`) that stress-test the protocol's core invariants (e.g., total staked value consistency, participant array integrity) across randomized sequences of actions.

Run tests with Foundry:

```bash
forge test
```

---

## 🚀 Deployment

Deployment is handled via Foundry scripts:

```bash
forge script script/DeployStakingEngine.s.sol --broadcast --rpc-url <YOUR_RPC_URL>
```

`HelperConfig.s.sol` supplies the correct network-specific configuration (e.g., token address, Chainlink Upkeep address) depending on the deployment target.

---

## 🛠️ Tech Stack

- **Solidity** `^0.8.34`
- **Foundry** (build, test, deploy)
- **OpenZeppelin Contracts** (`SafeERC20`)
- **Chainlink Automation** (reward distribution trigger)

---

## 📄 License

This project is licensed under the **MIT License**.
