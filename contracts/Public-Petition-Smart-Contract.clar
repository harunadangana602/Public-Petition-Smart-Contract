(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PETITION_NOT_FOUND (err u101))
(define-constant ERR_PETITION_EXPIRED (err u102))
(define-constant ERR_ALREADY_SIGNED (err u103))
(define-constant ERR_INVALID_DURATION (err u104))
(define-constant ERR_PETITION_INACTIVE (err u105))
(define-constant ERR_INVALID_TARGET (err u106))
(define-constant ERR_INSUFFICIENT_FUNDS (err u107))
(define-constant ERR_NO_REWARDS_AVAILABLE (err u108))
(define-constant ERR_REWARD_ALREADY_CLAIMED (err u109))
(define-constant MIN_DONATION u100000)

(define-data-var petition-counter uint u0)

(define-map petitions
  { petition-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    target-signatures: uint,
    current-signatures: uint,
    created-at: uint,
    expires-at: uint,
    is-active: bool,
    category: (string-ascii 50)
  }
)

(define-map petition-signatures
  { petition-id: uint, signer: principal }
  { signed-at: uint, verified: bool }
)

(define-map user-petition-count
  { user: principal }
  { count: uint }
)

(define-map petition-signers
  { petition-id: uint }
  { signers: (list 1000 principal) }
)

(define-read-only (get-petition (petition-id uint))
  (map-get? petitions { petition-id: petition-id })
)

(define-read-only (get-petition-signature (petition-id uint) (signer principal))
  (map-get? petition-signatures { petition-id: petition-id, signer: signer })
)

(define-read-only (get-user-petition-count (user principal))
  (default-to { count: u0 } (map-get? user-petition-count { user: user }))
)

(define-read-only (get-petition-signers (petition-id uint))
  (default-to { signers: (list) } (map-get? petition-signers { petition-id: petition-id }))
)

(define-read-only (get-total-petitions)
  (var-get petition-counter)
)

(define-read-only (is-petition-expired (petition-id uint))
  (match (get-petition petition-id)
    petition-data (> stacks-block-height (get expires-at petition-data))
    true
  )
)

(define-read-only (is-petition-successful (petition-id uint))
  (match (get-petition petition-id)
    petition-data (>= (get current-signatures petition-data) (get target-signatures petition-data))
    false
  )
)

(define-read-only (get-petition-status (petition-id uint))
  (match (get-petition petition-id)
    petition-data
    {
      is-active: (get is-active petition-data),
      is-expired: (is-petition-expired petition-id),
      is-successful: (is-petition-successful petition-id),
      progress: (/ (* (get current-signatures petition-data) u100) (get target-signatures petition-data))
    }
    {
      is-active: false,
      is-expired: true,
      is-successful: false,
      progress: u0
    }
  )
)

(define-public (create-petition 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (target-signatures uint)
  (duration-blocks uint)
  (category (string-ascii 50))
)
  (let
    (
      (petition-id (+ (var-get petition-counter) u1))
      (expires-at (+ stacks-block-height duration-blocks))
      (user-count (get count (get-user-petition-count tx-sender)))
    )
    (asserts! (> target-signatures u0) ERR_INVALID_TARGET)
    (asserts! (> duration-blocks u0) ERR_INVALID_DURATION)
    
    (map-set petitions
      { petition-id: petition-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        target-signatures: target-signatures,
        current-signatures: u0,
        created-at: stacks-block-height,
        expires-at: expires-at,
        is-active: true,
        category: category
      }
    )
    
    (map-set user-petition-count
      { user: tx-sender }
      { count: (+ user-count u1) }
    )
    
    (map-set petition-signers
      { petition-id: petition-id }
      { signers: (list) }
    )
    
    (var-set petition-counter petition-id)
    (ok petition-id)
  )
)

(define-public (sign-petition (petition-id uint))
  (let
    (
      (petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND))
      (current-signers (get signers (get-petition-signers petition-id)))
    )
    (asserts! (get is-active petition-data) ERR_PETITION_INACTIVE)
    (asserts! (<= stacks-block-height (get expires-at petition-data)) ERR_PETITION_EXPIRED)
    (asserts! (is-none (get-petition-signature petition-id tx-sender)) ERR_ALREADY_SIGNED)
    
    (map-set petition-signatures
      { petition-id: petition-id, signer: tx-sender }
      { signed-at: stacks-block-height, verified: true }
    )
    
    (map-set petitions
      { petition-id: petition-id }
      (merge petition-data { current-signatures: (+ (get current-signatures petition-data) u1) })
    )
    
    (map-set petition-signers
      { petition-id: petition-id }
      { signers: (unwrap! (as-max-len? (append current-signers tx-sender) u1000) ERR_UNAUTHORIZED) }
    )
    
    (ok true)
  )
)

(define-public (deactivate-petition (petition-id uint))
  (let
    (
      (petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator petition-data)) ERR_UNAUTHORIZED)
    (asserts! (get is-active petition-data) ERR_PETITION_INACTIVE)
    
    (map-set petitions
      { petition-id: petition-id }
      (merge petition-data { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (verify-signature (petition-id uint) (signer principal))
  (let
    (
      (petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND))
      (signature-data (unwrap! (get-petition-signature petition-id signer) ERR_PETITION_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set petition-signatures
      { petition-id: petition-id, signer: signer }
      (merge signature-data { verified: true })
    )
    
    (ok true)
  )
)

(define-read-only (get-active-petitions-count)
  (fold check-active-petition (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u0)
)

(define-private (check-active-petition (petition-id uint) (count uint))
  (match (get-petition petition-id)
    petition-data
    (if (get is-active petition-data)
      (+ count u1)
      count
    )
    count
  )
)

(define-read-only (has-user-signed (petition-id uint) (user principal))
  (is-some (get-petition-signature petition-id user))
)

(define-read-only (get-petition-progress (petition-id uint))
  (match (get-petition petition-id)
    petition-data
    {
      current: (get current-signatures petition-data),
      target: (get target-signatures petition-data),
      percentage: (/ (* (get current-signatures petition-data) u100) (get target-signatures petition-data)),
      remaining: (- (get target-signatures petition-data) (get current-signatures petition-data))
    }
    {
      current: u0,
      target: u0,
      percentage: u0,
      remaining: u0
    }
  )
)

(define-read-only (get-petition-time-remaining (petition-id uint))
  (match (get-petition petition-id)
    petition-data
    (if (> (get expires-at petition-data) stacks-block-height)
      (- (get expires-at petition-data) stacks-block-height)
      u0
    )
    u0
  )
)



(define-map petition-donations
  { petition-id: uint }
  { total-donated: uint, donor-count: uint }
)

(define-map user-donations
  { petition-id: uint, donor: principal }
  { amount: uint, donated-at: uint }
)

(define-map reward-claims
  { petition-id: uint, signer: principal }
  { claimed: bool, amount: uint }
)

(define-read-only (get-petition-donations (petition-id uint))
  (default-to { total-donated: u0, donor-count: u0 } 
    (map-get? petition-donations { petition-id: petition-id }))
)

(define-read-only (get-user-donation (petition-id uint) (donor principal))
  (map-get? user-donations { petition-id: petition-id, donor: donor })
)

(define-read-only (get-reward-amount (petition-id uint))
  (let ((donations (get-petition-donations petition-id)))
    (/ (get total-donated donations) u2))
)

(define-read-only (calculate-signer-reward (petition-id uint))
  (match (get-petition petition-id)
    petition-data
    (let ((reward-pool (get-reward-amount petition-id)))
      (if (> (get current-signatures petition-data) u0)
        (/ reward-pool (get current-signatures petition-data))
        u0))
    u0)
)

(define-public (donate-to-petition (petition-id uint) (amount uint))
  (let (
    (petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND))
    (current-donations (get-petition-donations petition-id))
    (existing-donation (get-user-donation petition-id tx-sender))
  )
    (asserts! (get is-active petition-data) ERR_PETITION_INACTIVE)
    (asserts! (>= amount MIN_DONATION) ERR_INSUFFICIENT_FUNDS)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set user-donations
      { petition-id: petition-id, donor: tx-sender }
      { amount: (+ amount (default-to u0 (get amount existing-donation))), 
        donated-at: stacks-block-height }
    )
    
    (map-set petition-donations
      { petition-id: petition-id }
      { total-donated: (+ (get total-donated current-donations) amount),
        donor-count: (if (is-none existing-donation) 
          (+ (get donor-count current-donations) u1) 
          (get donor-count current-donations)) }
    )
    
    (ok amount)
  )
)

(define-public (claim-reward (petition-id uint))
  (let (
    (petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND))
    (reward-per-signer (calculate-signer-reward petition-id))
    (existing-claim (map-get? reward-claims { petition-id: petition-id, signer: tx-sender }))
  )
    (asserts! (is-petition-successful petition-id) ERR_PETITION_INACTIVE)
    (asserts! (has-user-signed petition-id tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-none existing-claim) ERR_REWARD_ALREADY_CLAIMED)
    (asserts! (> reward-per-signer u0) ERR_NO_REWARDS_AVAILABLE)
    
    (try! (as-contract (stx-transfer? reward-per-signer tx-sender tx-sender)))
    
    (map-set reward-claims
      { petition-id: petition-id, signer: tx-sender }
      { claimed: true, amount: reward-per-signer }
    )
    
    (ok reward-per-signer)
  )
)
