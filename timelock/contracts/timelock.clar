;; TimeLock Treasure - Decentralized Time-Locked Savings Account
;; Enhanced with compound interest and early deposit bonuses

(define-constant CONTRACT_OWNER tx-sender)
(define-constant REWARD_RATE u500) ;; 5% base APY (in basis points)
(define-constant MINIMUM_LOCK_PERIOD u2016) ;; minimum 2 weeks (in blocks)
(define-constant EARLY_WITHDRAWAL_PENALTY u1000) ;; 10% penalty (in basis points)
(define-constant BLOCKS_PER_YEAR u52560) ;; assuming 10 min/block
(define-constant COMPOUND_FREQUENCY u720) ;; compound every 5 days (in blocks)
(define-constant EARLY_DEPOSIT_BONUS u200) ;; 2% bonus for early deposits
(define-constant LAUNCH_PERIOD_END u10000) ;; Launch period end block

;; Data Maps
(define-map savings-accounts
    principal
    {
        balance: uint,
        lock-until: uint,
        start-block: uint,
        reward-rate: uint,
        last-compound: uint,
        compounding-enabled: bool
    }
)

(define-map total-stats
    bool
    {
        total-locked: uint,
        total-accounts: uint,
        total-compound-interest: uint
    }
)

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_INVALID_DURATION (err u402))
(define-constant ERR_NO_ACCOUNT (err u403))
(define-constant ERR_STILL_LOCKED (err u404))
(define-constant ERR_ZERO_DEPOSIT (err u405))
(define-constant ERR_COMPOUND_TOO_EARLY (err u406))
(define-constant ERR_EXISTING_LOCK (err u407))

;; Public functions

;; Create or update a savings account with compound interest option
(define-public (create-savings-account (lock-duration uint) (amount uint) (enable-compounding bool))
    (let (
        (current-block block-height)
        (lock-until (+ current-block lock-duration))
        (adjusted-rate (calculate-reward-rate lock-duration))
        (early-deposit-rate (if (< current-block LAUNCH_PERIOD_END)
            (+ adjusted-rate EARLY_DEPOSIT_BONUS)
            adjusted-rate))
        (existing-account (get-account tx-sender))
    )
        ;; Validate inputs
        (asserts! (> amount u0) ERR_ZERO_DEPOSIT)
        (asserts! (>= lock-duration MINIMUM_LOCK_PERIOD) ERR_INVALID_DURATION)
        
        ;; Check for existing locked account
        (match existing-account
            existing (asserts! (>= current-block (get lock-until existing)) ERR_EXISTING_LOCK)
            true
        )
        
        ;; Transfer funds to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Create new account state
        (map-set savings-accounts tx-sender
            {
                balance: amount,
                lock-until: lock-until,
                start-block: current-block,
                reward-rate: early-deposit-rate,
                last-compound: current-block,
                compounding-enabled: enable-compounding
            }
        )
        
        ;; Update statistics
        (update-total-stats amount (is-none existing-account) u0)
        (ok true)
    )
)

;; Add additional funds to existing account
(define-public (add-to-savings (amount uint))
    (let (
        (account (unwrap! (get-account tx-sender) ERR_NO_ACCOUNT))
        (current-block block-height)
        (current-balance (get balance account))
    )
        (asserts! (> amount u0) ERR_ZERO_DEPOSIT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update account with new balance
        (map-set savings-accounts tx-sender
            (merge account {
                balance: (+ current-balance amount)
            })
        )
        
        ;; Update statistics
        (update-total-stats amount false u0)
        (ok true)
    )
)

;; Trigger compound interest calculation and reinvestment
(define-public (compound-interest)
    (let (
        (account (unwrap! (get-account tx-sender) ERR_NO_ACCOUNT))
        (current-block block-height)
        (blocks-since-compound (- current-block (get last-compound account)))
    )
        (asserts! (get compounding-enabled account) ERR_NOT_AUTHORIZED)
        (asserts! (>= blocks-since-compound COMPOUND_FREQUENCY) ERR_COMPOUND_TOO_EARLY)
        
        (let (
            (rewards (calculate-compound-rewards account current-block))
            (new-balance (+ (get balance account) rewards))
        )
            (map-set savings-accounts tx-sender
                (merge account {
                    balance: new-balance,
                    last-compound: current-block
                })
            )
            (update-total-stats u0 false rewards)
            (ok rewards)
        )
    )
)

;; Toggle compound interest setting
(define-public (toggle-compounding (enable bool))
    (match (get-account tx-sender)
        account 
        (begin
            (map-set savings-accounts tx-sender
                (merge account {
                    compounding-enabled: enable,
                    last-compound: block-height
                })
            )
            (ok true)
        )
        (err ERR_NO_ACCOUNT)
    )
)

;; Withdraw funds with rewards
(define-public (withdraw)
    (let (
        (account (unwrap! (get-account tx-sender) ERR_NO_ACCOUNT))
        (current-block block-height)
        (final-rewards (if (get compounding-enabled account)
            (calculate-compound-rewards account current-block)
            (calculate-simple-rewards account current-block)))
    )
        (if (< current-block (get lock-until account))
            (withdraw-early account)
            (withdraw-mature account final-rewards)
        )
    )
)

;; Private functions

;; Calculate reward rate based on lock duration
(define-private (calculate-reward-rate (duration uint))
    (let (
        (duration-bonus (/ (* duration u100) BLOCKS_PER_YEAR))
    )
        (+ REWARD_RATE (* duration-bonus u50))
    )
)

;; Calculate compound interest rewards
(define-private (calculate-compound-rewards (account {balance: uint, lock-until: uint, start-block: uint, reward-rate: uint, last-compound: uint, compounding-enabled: bool}) (current-block uint))
    (let (
        (periods (/ (- current-block (get last-compound account)) COMPOUND_FREQUENCY))
        (period-rate (/ (* (get reward-rate account) COMPOUND_FREQUENCY) (* BLOCKS_PER_YEAR u10000)))
    )
        (let (
            (compound-multiplier (pow (+ u10000 period-rate) periods))
            (final-amount (/ (* (get balance account) compound-multiplier) u10000))
        )
            (- final-amount (get balance account))
        )
    )
)

;; Calculate simple interest rewards
(define-private (calculate-simple-rewards (account {balance: uint, lock-until: uint, start-block: uint, reward-rate: uint, last-compound: uint, compounding-enabled: bool}) (current-block uint))
    (let (
        (duration (- current-block (get start-block account)))
        (annual-rate (get reward-rate account))
        (balance (get balance account))
    )
        (/ (* (* balance annual-rate) duration) (* BLOCKS_PER_YEAR u10000))
    )
)

;; Handle early withdrawal with penalty
(define-private (withdraw-early (account {balance: uint, lock-until: uint, start-block: uint, reward-rate: uint, last-compound: uint, compounding-enabled: bool}))
    (let (
        (penalty (/ (* (get balance account) EARLY_WITHDRAWAL_PENALTY) u10000))
        (withdrawal-amount (- (get balance account) penalty))
    )
        (try! (as-contract (stx-transfer? withdrawal-amount (as-contract tx-sender) tx-sender)))
        (map-delete savings-accounts tx-sender)
        (update-total-stats (get balance account) false u0)
        (ok withdrawal-amount)
    )
)

;; Handle mature withdrawal with rewards
(define-private (withdraw-mature (account {balance: uint, lock-until: uint, start-block: uint, reward-rate: uint, last-compound: uint, compounding-enabled: bool}) (rewards uint))
    (let (
        (total-amount (+ (get balance account) rewards))
    )
        (try! (as-contract (stx-transfer? total-amount (as-contract tx-sender) tx-sender)))
        (map-delete savings-accounts tx-sender)
        (update-total-stats (get balance account) false u0)
        (ok total-amount)
    )
)

;; Update total statistics with compound interest
(define-private (update-total-stats (amount uint) (is-new-account bool) (compound-amount uint))
    (let (
        (current-stats (default-to
            {total-locked: u0, total-accounts: u0, total-compound-interest: u0}
            (map-get? total-stats true)
        ))
    )
        (map-set total-stats true
            {
                total-locked: (if (> amount u0)
                    (+ (get total-locked current-stats) amount)
                    (- (get total-locked current-stats) amount)
                ),
                total-accounts: (if is-new-account
                    (+ (get total-accounts current-stats) u1)
                    (if (is-eq amount u0)
                        (- (get total-accounts current-stats) u1)
                        (get total-accounts current-stats))
                ),
                total-compound-interest: (+ (get total-compound-interest current-stats) compound-amount)
            }
        )
    )
)

;; Read-only functions

;; Get account details
(define-read-only (get-account (account-owner principal))
    (map-get? savings-accounts account-owner)
)

;; Get compound schedule information
(define-read-only (get-compound-schedule (account-owner principal))
    (match (get-account account-owner)
        account (ok {
            compounding-enabled: (get compounding-enabled account),
            next-compound: (+ (get last-compound account) COMPOUND_FREQUENCY),
            current-balance: (get balance account)
        })
        (err ERR_NO_ACCOUNT)
    )
)

;; Check if we're in launch period
(define-read-only (is-launch-period)
    (< block-height LAUNCH_PERIOD_END)
)

;; Get early deposit bonus rate
(define-read-only (get-early-deposit-rate (duration uint))
    (+ (calculate-reward-rate duration) EARLY_DEPOSIT_BONUS)
)

;; Get total statistics
(define-read-only (get-total-stats)
    (default-to
        {total-locked: u0, total-accounts: u0, total-compound-interest: u0}
        (map-get? total-stats true)
    )
)

;; Get current reward rate for a duration
(define-read-only (get-current-reward-rate (duration uint))
    (calculate-reward-rate duration)
)

;; Get estimated rewards for an account
(define-read-only (get-estimated-rewards (account-owner principal))
    (match (get-account account-owner)
        account (ok (if (get compounding-enabled account)
            (calculate-compound-rewards account block-height)
            (calculate-simple-rewards account block-height)))
        (err ERR_NO_ACCOUNT)
    )
)