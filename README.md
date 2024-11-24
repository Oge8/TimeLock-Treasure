# TimeLock Treasure 🔒💎

A decentralized time-locked savings protocol built on the Stacks blockchain that enables users to earn rewards through locked deposits, compound interest, and early deposit bonuses.

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Technical Architecture](#technical-architecture)
- [Smart Contract Functions](#smart-contract-functions)
- [Deployment Guide](#deployment-guide)
- [Integration Guide](#integration-guide)
- [Security Considerations](#security-considerations)
- [Testing Guide](#testing-guide)
- [Examples](#examples)

## Overview

TimeLock Treasure is a decentralized savings protocol that incentivizes long-term saving behavior through:
- Time-locked deposits with dynamic reward rates
- Compound interest mechanisms
- Early deposit bonuses
- Flexible withdrawal options

### Key Metrics
- Base APY: 5%
- Minimum Lock Period: 2 weeks
- Early Withdrawal Penalty: 10%
- Compound Frequency: Every 5 days
- Early Deposit Bonus: 2%

## Features

### 1. Time-Locked Savings
- Customizable lock periods (minimum 2 weeks)
- Dynamic reward rates based on lock duration
- Early withdrawal available with penalty
- Secure fund management

### 2. Compound Interest System
- Optional automated compounding
- User-controllable compounding settings
- Compound interest calculation every 5 days
- Reinvestment of earned rewards

### 3. Early Deposit Bonus
- Additional 2% APY for early adopters
- Automatic bonus application during launch period
- Stackable with regular duration-based rewards

### 4. Flexible Account Management
- Add funds to existing accounts
- Toggle compound settings
- View real-time rewards and statistics
- Early withdrawal options

## Technical Architecture

### Constants
```clarity
REWARD_RATE: 5% base APY (500 basis points)
MINIMUM_LOCK_PERIOD: 2016 blocks (~2 weeks)
EARLY_WITHDRAWAL_PENALTY: 10% (1000 basis points)
COMPOUND_FREQUENCY: 720 blocks (~5 days)
EARLY_DEPOSIT_BONUS: 2% (200 basis points)
```

### Data Structures

#### Savings Account
```clarity
{
    balance: uint,
    lock-until: uint,
    start-block: uint,
    reward-rate: uint,
    last-compound: uint,
    compounding-enabled: bool
}
```

#### Statistics
```clarity
{
    total-locked: uint,
    total-accounts: uint,
    total-compound-interest: uint
}
```

## Smart Contract Functions

### Public Functions

#### Account Management
```clarity
(create-savings-account (lock-duration uint) (amount uint) (enable-compounding bool))
(add-to-savings (amount uint))
(toggle-compounding (enable bool))
(withdraw)
(compound-interest)
```

#### Read-Only Functions
```clarity
(get-account (account-owner principal))
(get-compound-schedule (account-owner principal))
(get-estimated-rewards (account-owner principal))
(get-current-reward-rate (duration uint))
(get-total-stats)
(is-launch-period)
```

## Deployment Guide

1. **Prerequisites**
   - Clarinet installed
   - Stacks wallet with sufficient STX
   - Access to Stacks network (testnet/mainnet)

2. **Deployment Steps**
   ```bash
   # Build contract
   clarinet build

   # Test contract
   clarinet test

   # Deploy contract
   clarinet deploy --network testnet
   ```

3. **Post-Deployment Setup**
   - Verify contract deployment
   - Set initial parameters if needed
   - Monitor for successful activation

## Integration Guide

### Frontend Integration

1. **Connect to Contract**
   ```javascript
   const contract = new Contract('ST...', 'timelock-treasure');
   ```

2. **Create Savings Account**
   ```javascript
   async function createAccount(duration, amount, enableCompounding) {
     const tx = await contract.createSavingsAccount(duration, amount, enableCompounding);
     await tx.confirmation();
   }
   ```

3. **Monitor Account Status**
   ```javascript
   async function getAccountStatus(address) {
     const account = await contract.getAccount(address);
     const schedule = await contract.getCompoundSchedule(address);
     const rewards = await contract.getEstimatedRewards(address);
     return { account, schedule, rewards };
   }
   ```

### Error Handling

```javascript
const ERROR_CODES = {
  u401: "Not authorized",
  u402: "Invalid duration",
  u403: "No account found",
  u404: "Still locked",
  u405: "Zero deposit",
  u406: "Compound too early",
  u407: "Existing lock"
};
```

## Security Considerations

1. **Lock Period Safety**
   - Minimum lock period enforced
   - Early withdrawal penalties
   - Secure fund management

2. **Compound Interest Safety**
   - Integer arithmetic for calculations
   - Safe compound frequency limits
   - Protected compound triggers

3. **Fund Security**
   - Principal-based account management
   - Protected withdrawal mechanisms
   - Safe arithmetic operations

4. **Best Practices**
   - Regular audits recommended
   - Monitor contract activity
   - Set up alerts for large withdrawals

## Testing Guide

1. **Unit Tests**
   ```clarity
   ;; Account creation tests
   (test-create-account)
   (test-invalid-duration)
   (test-early-withdrawal)

   ;; Compound interest tests
   (test-compound-calculation)
   (test-compound-frequency)

   ;; Integration tests
   (test-full-lifecycle)
   ```

2. **Test Scenarios**
   - Account creation and management
   - Compound interest calculations
   - Early deposit bonus application
   - Withdrawal scenarios
   - Statistics tracking

## Examples

### Creating a Savings Account
```clarity
(contract-call? .timelock-treasure create-savings-account
    u4032  ;; 4-week lock
    u1000000000  ;; 1000 STX
    true  ;; Enable compounding
)
```

### Managing Compound Interest
```clarity
;; Enable compounding
(contract-call? .timelock-treasure toggle-compounding true)

;; Trigger compound
(contract-call? .timelock-treasure compound-interest)
```

### Withdrawal Examples
```clarity
;; Normal withdrawal
(contract-call? .timelock-treasure withdraw)

;; Check rewards before withdrawal
(contract-call? .timelock-treasure get-estimated-rewards tx-sender)
```

---


