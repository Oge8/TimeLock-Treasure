;; TimeLock Treasure - Decentralized Time-Locked Savings Account
;; A smart contract for locking STX tokens with rewards based on duration

(define-constant CONTRACT_OWNER tx-sender)
(define-constant REWARD_RATE u500) ;; 5% base APY (in basis points)
(define-constant MINIMUM_LOCK_PERIOD u2016) ;; minimum 2 weeks (in blocks, assuming 10 min/block)
(define-constant EARLY_WITHDRAWAL_PENALTY u1000) ;; 10% penalty (in basis points)
(define-constant BLOCKS_PER_YEAR u52560) ;; assuming 10 min/block

;; Data Maps
(define-map savings-accounts
    principal
    {
        balance: uint,
        lock-until: uint,
        start-block: uint,
        reward-rate: uint
    }
)

(define-map total-stats
    bool
    {
        total-locked: uint,
        total-accounts: uint
    }
)

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_INVALID_DURATION (err u402))
(define-constant ERR_NO_ACCOUNT (err u403))
(define-constant ERR_STILL_LOCKED (err u404))
(define-constant ERR_ZERO_DEPOSIT (err u405))

;; Public functions

;; Create or update a savings account
(define-public (create-savings-account (lock-duration uint) (amount uint))
    (let (
        (current-block block-height)
        (lock-until (+ current-block lock-duration))
        (adjusted-rate (calculate-reward-rate lock-duration))
    )
        (asserts! (> amount u0) ERR_ZERO_DEPOSIT)
        (asserts! (>= lock-duration MINIMUM_LOCK_PERIOD) ERR_INVALID_DURATION)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set savings-accounts tx-sender
            {
                balance: amount,
                lock-until: lock-until,
                start-block: current-block,
                reward-rate: adjusted-rate
            }
        )
        (update-total-stats amount true)
        (ok true)
    )
)

;; Withdraw funds and rewards
(define-public (withdraw)
    (let (
        (account (unwrap! (get-account tx-sender) ERR_NO_ACCOUNT))
        (current-block block-height)
        (rewards (calculate-rewards account current-block))
    )
        (if (< current-block (get lock-until account))
            (withdraw-early account)
            (withdraw-mature account rewards)
        )
    )
)

;; Private functions

;; Calculate dynamic reward rate based on lock duration
(define-private (calculate-reward-rate (duration uint))
    (let (
        (duration-bonus (/ (* duration u100) BLOCKS_PER_YEAR))
    )
        (+ REWARD_RATE (* duration-bonus u50))
    )
)

;; Calculate rewards earned
(define-private (calculate-rewards (account {balance: uint, lock-until: uint, start-block: uint, reward-rate: uint}) (current-block uint))
    (let (
        (duration (- current-block (get start-block account)))
        (annual-rate (get reward-rate account))
        (balance (get balance account))
    )
        (/ (* (* balance annual-rate) duration) (* BLOCKS_PER_YEAR u10000))
    )
)

;; Handle early withdrawal with penalty
(define-private (withdraw-early (account {balance: uint, lock-until: uint, start-block: uint, reward-rate: uint}))
    (let (
        (penalty (/ (* (get balance account) EARLY_WITHDRAWAL_PENALTY) u10000))
        (withdrawal-amount (- (get balance account) penalty))
    )
        (try! (as-contract (stx-transfer? withdrawal-amount (as-contract tx-sender) tx-sender)))
        (map-delete savings-accounts tx-sender)
        (update-total-stats (get balance account) false)
        (ok withdrawal-amount)
    )
)

;; Handle mature withdrawal with rewards
(define-private (withdraw-mature (account {balance: uint, lock-until: uint, start-block: uint, reward-rate: uint}) (rewards uint))
    (let (
        (total-amount (+ (get balance account) rewards))
    )
        (try! (as-contract (stx-transfer? total-amount (as-contract tx-sender) tx-sender)))
        (map-delete savings-accounts tx-sender)
        (update-total-stats (get balance account) false)
        (ok total-amount)
    )
)

;; Helper functions

;; Get account details
(define-read-only (get-account (account-owner principal))
    (map-get? savings-accounts account-owner)
)

;; Update total statistics
(define-private (update-total-stats (amount uint) (is-deposit bool))
    (let (
        (current-stats (default-to
            {total-locked: u0, total-accounts: u0}
            (map-get? total-stats true)
        ))
    )
        (map-set total-stats true
            {
                total-locked: (if is-deposit
                    (+ (get total-locked current-stats) amount)
                    (- (get total-locked current-stats) amount)
                ),
                total-accounts: (if is-deposit
                    (+ (get total-accounts current-stats) u1)
                    (- (get total-accounts current-stats) u1)
                )
            }
        )
    )
)

;; Read-only functions for frontend integration

(define-read-only (get-total-stats)
    (default-to
        {total-locked: u0, total-accounts: u0}
        (map-get? total-stats true)
    )
)

(define-read-only (get-current-reward-rate (duration uint))
    (calculate-reward-rate duration)
)

(define-read-only (get-estimated-rewards (account-owner principal))
    (match (get-account account-owner)
        account (ok (calculate-rewards account block-height))
        (err ERR_NO_ACCOUNT)
    )
)