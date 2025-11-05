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

(define-constant ERR_TEMPLATE_NOT_FOUND (err u110))
(define-constant ERR_TEMPLATE_EXISTS (err u111))

(define-constant ERR_UPDATE_TOO_LONG (err u112))

(define-constant ERR_ALREADY_ENDORSED (err u113))
(define-constant ERR_INVALID_RATING (err u114))

(define-data-var template-counter uint u0)

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


(define-map petition-templates
  { template-id: uint }
  {
    creator: principal,
    name: (string-ascii 50),
    title-template: (string-ascii 100),
    description-template: (string-ascii 500),
    suggested-target: uint,
    suggested-duration: uint,
    category: (string-ascii 50),
    usage-count: uint,
    is-verified: bool,
    created-at: uint
  }
)

(define-map template-usage
  { template-id: uint }
  { petitions-created: (list 100 uint) }
)

(define-read-only (get-template (template-id uint))
  (map-get? petition-templates { template-id: template-id })
)

(define-read-only (get-template-usage (template-id uint))
  (default-to { petitions-created: (list) } 
    (map-get? template-usage { template-id: template-id }))
)

(define-read-only (get-total-templates)
  (var-get template-counter)
)

(define-read-only (get-popular-templates)
  (fold check-template-popularity (list u1 u2 u3 u4 u5) (list))
)

(define-private (check-template-popularity (template-id uint) (popular-list (list 5 uint)))
  (match (get-template template-id)
    template-data
    (if (> (get usage-count template-data) u2)
      (unwrap! (as-max-len? (append popular-list template-id) u5) popular-list)
      popular-list)
    popular-list)
)

(define-public (create-template
  (name (string-ascii 50))
  (title-template (string-ascii 100))
  (description-template (string-ascii 500))
  (suggested-target uint)
  (suggested-duration uint)
  (category (string-ascii 50))
)
  (let ((template-id (+ (var-get template-counter) u1)))
    (map-set petition-templates
      { template-id: template-id }
      {
        creator: tx-sender,
        name: name,
        title-template: title-template,
        description-template: description-template,
        suggested-target: suggested-target,
        suggested-duration: suggested-duration,
        category: category,
        usage-count: u0,
        is-verified: false,
        created-at: stacks-block-height
      }
    )
    
    (map-set template-usage
      { template-id: template-id }
      { petitions-created: (list) }
    )
    
    (var-set template-counter template-id)
    (ok template-id)
  )
)

(define-public (create-petition-from-template
  (template-id uint)
  (custom-title (optional (string-ascii 100)))
  (custom-description (optional (string-ascii 500)))
  (custom-target (optional uint))
  (custom-duration (optional uint))
)
  (let (
    (template-data (unwrap! (get-template template-id) ERR_TEMPLATE_NOT_FOUND))
    (final-title (default-to (get title-template template-data) custom-title))
    (final-description (default-to (get description-template template-data) custom-description))
    (final-target (default-to (get suggested-target template-data) custom-target))
    (final-duration (default-to (get suggested-duration template-data) custom-duration))
    (petition-id (+ (var-get petition-counter) u1))
    (current-usage (get-template-usage template-id))
  )
    (asserts! (> final-target u0) ERR_INVALID_TARGET)
    (asserts! (> final-duration u0) ERR_INVALID_DURATION)
    
    (try! (create-petition final-title final-description final-target final-duration (get category template-data)))
    
    (map-set petition-templates
      { template-id: template-id }
      (merge template-data { usage-count: (+ (get usage-count template-data) u1) })
    )
    
    (map-set template-usage
      { template-id: template-id }
      { petitions-created: (unwrap! (as-max-len? (append (get petitions-created current-usage) petition-id) u100) ERR_UNAUTHORIZED) }
    )
    
    (ok petition-id)
  )
)

(define-public (verify-template (template-id uint))
  (let ((template-data (unwrap! (get-template template-id) ERR_TEMPLATE_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set petition-templates
      { template-id: template-id }
      (merge template-data { is-verified: true })
    )
    
    (ok true)
  )
)


(define-map petition-updates
  { petition-id: uint, update-id: uint }
  {
    creator: principal,
    message: (string-ascii 300),
    posted-at: uint,
    update-type: (string-ascii 20)
  }
)

(define-map petition-update-count
  { petition-id: uint }
  { count: uint }
)

(define-read-only (get-petition-update (petition-id uint) (update-id uint))
  (map-get? petition-updates { petition-id: petition-id, update-id: update-id })
)

(define-read-only (get-petition-update-count (petition-id uint))
  (default-to { count: u0 } (map-get? petition-update-count { petition-id: petition-id }))
)

(define-read-only (get-latest-update (petition-id uint))
  (let ((update-count (get count (get-petition-update-count petition-id))))
    (if (> update-count u0)
      (get-petition-update petition-id update-count)
      none))
)

(define-public (post-petition-update 
  (petition-id uint) 
  (message (string-ascii 300)) 
  (update-type (string-ascii 20))
)
  (let (
    (petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND))
    (current-count (get count (get-petition-update-count petition-id)))
    (new-update-id (+ current-count u1))
  )
    (asserts! (is-eq tx-sender (get creator petition-data)) ERR_UNAUTHORIZED)
    (asserts! (get is-active petition-data) ERR_PETITION_INACTIVE)
    (asserts! (> (len message) u0) ERR_UPDATE_TOO_LONG)
    
    (map-set petition-updates
      { petition-id: petition-id, update-id: new-update-id }
      {
        creator: tx-sender,
        message: message,
        posted-at: stacks-block-height,
        update-type: update-type
      }
    )
    
    (map-set petition-update-count
      { petition-id: petition-id }
      { count: new-update-id }
    )
    
    (ok new-update-id)
  )
)

(define-read-only (get-recent-updates (petition-id uint))
  (let ((update-count (get count (get-petition-update-count petition-id))))
    (if (> update-count u0)
      (if (> update-count u2)
        (list (- update-count u1) update-count)
        (list update-count))
      (list))
  )
)

(define-map petition-endorsements
  { petition-id: uint, endorser: principal }
  {
    rating: uint,
    comment: (optional (string-ascii 200)),
    endorsed-at: uint,
    endorser-reputation: uint
  }
)

(define-map petition-endorsement-stats
  { petition-id: uint }
  {
    total-endorsements: uint,
    average-rating: uint,
    total-rating-points: uint
  }
)

(define-map endorser-stats
  { endorser: principal }
  {
    total-endorsements: uint,
    reputation-score: uint
  }
)

(define-read-only (get-petition-endorsements (petition-id uint))
  (default-to 
    { total-endorsements: u0, average-rating: u0, total-rating-points: u0 }
    (map-get? petition-endorsement-stats { petition-id: petition-id }))
)

(define-read-only (get-endorsement (petition-id uint) (endorser principal))
  (map-get? petition-endorsements { petition-id: petition-id, endorser: endorser })
)

(define-read-only (get-endorser-stats (endorser principal))
  (default-to { total-endorsements: u0, reputation-score: u0 }
    (map-get? endorser-stats { endorser: endorser }))
)

(define-read-only (has-endorsed (petition-id uint) (endorser principal))
  (is-some (get-endorsement petition-id endorser))
)

(define-public (endorse-petition 
  (petition-id uint) 
  (rating uint)
  (comment (optional (string-ascii 200)))
)
  (let (
    (petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND))
    (current-stats (get-petition-endorsements petition-id))
    (endorser-data (get-endorser-stats tx-sender))
    (new-total (+ (get total-endorsements current-stats) u1))
    (new-rating-points (+ (get total-rating-points current-stats) rating))
  )
    (asserts! (get is-active petition-data) ERR_PETITION_INACTIVE)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (is-none (get-endorsement petition-id tx-sender)) ERR_ALREADY_ENDORSED)
    
    (map-set petition-endorsements
      { petition-id: petition-id, endorser: tx-sender }
      { rating: rating, comment: comment, endorsed-at: stacks-block-height, endorser-reputation: (get reputation-score endorser-data) }
    )
    
    (map-set petition-endorsement-stats
      { petition-id: petition-id }
      { total-endorsements: new-total, average-rating: (/ new-rating-points new-total), total-rating-points: new-rating-points }
    )
    
    (map-set endorser-stats
      { endorser: tx-sender }
      { total-endorsements: (+ (get total-endorsements endorser-data) u1), reputation-score: (+ (get reputation-score endorser-data) u1) }
    )
    
    (ok true)
  )
)


(define-constant ERR_MILESTONE_EXISTS (err u115))

(define-map petition-milestones
  { petition-id: uint }
  {
    milestone-25-reached: bool,
    milestone-25-block: uint,
    milestone-50-reached: bool,
    milestone-50-block: uint,
    milestone-75-reached: bool,
    milestone-75-block: uint,
    milestone-100-reached: bool,
    milestone-100-block: uint
  }
)

(define-map milestone-events
  { petition-id: uint, milestone-type: uint }
  { unlocked-at: uint, signatures-at-unlock: uint, momentum-score: uint }
)

(define-map petition-momentum
  { petition-id: uint }
  { velocity-score: uint, acceleration: uint, last-calculated: uint }
)

(define-read-only (get-petition-milestones (petition-id uint))
  (default-to 
    { milestone-25-reached: false, milestone-25-block: u0, milestone-50-reached: false, milestone-50-block: u0, milestone-75-reached: false, milestone-75-block: u0, milestone-100-reached: false, milestone-100-block: u0 }
    (map-get? petition-milestones { petition-id: petition-id }))
)

(define-read-only (get-milestone-event (petition-id uint) (milestone-type uint))
  (map-get? milestone-events { petition-id: petition-id, milestone-type: milestone-type })
)

(define-read-only (check-milestone-unlocked (petition-id uint) (milestone-type uint))
  (let ((milestones (get-petition-milestones petition-id)))
    (if (is-eq milestone-type u25) (get milestone-25-reached milestones)
      (if (is-eq milestone-type u50) (get milestone-50-reached milestones)
        (if (is-eq milestone-type u75) (get milestone-75-reached milestones)
          (if (is-eq milestone-type u100) (get milestone-100-reached milestones) false)))))
)

(define-read-only (calculate-momentum-score (petition-id uint))
  (match (get-petition petition-id)
    petition-data
    (let (
      (milestones (get-petition-milestones petition-id))
      (blocks-elapsed (- stacks-block-height (get created-at petition-data)))
      (signature-rate (if (> blocks-elapsed u0) (/ (* (get current-signatures petition-data) u1000) blocks-elapsed) u0))
    )
      { current-signatures: (get current-signatures petition-data), signature-rate: signature-rate, blocks-active: blocks-elapsed }
    )
    { current-signatures: u0, signature-rate: u0, blocks-active: u0 }
  )
)

(define-private (record-milestone (petition-id uint) (current-sigs uint) (target-sigs uint))
  (let (
    (progress-pct (/ (* current-sigs u100) target-sigs))
    (milestones (get-petition-milestones petition-id))
    (momentum (calculate-momentum-score petition-id))
  )
    (if (and (>= progress-pct u25) (not (get milestone-25-reached milestones)))
      (begin
        (map-set petition-milestones { petition-id: petition-id } (merge milestones { milestone-25-reached: true, milestone-25-block: stacks-block-height }))
        (map-set milestone-events { petition-id: petition-id, milestone-type: u25 } { unlocked-at: stacks-block-height, signatures-at-unlock: current-sigs, momentum-score: (get signature-rate momentum) })
      )
      (if (and (>= progress-pct u50) (not (get milestone-50-reached milestones)))
        (begin
          (map-set petition-milestones { petition-id: petition-id } (merge milestones { milestone-50-reached: true, milestone-50-block: stacks-block-height }))
          (map-set milestone-events { petition-id: petition-id, milestone-type: u50 } { unlocked-at: stacks-block-height, signatures-at-unlock: current-sigs, momentum-score: (get signature-rate momentum) })
        )
        (if (and (>= progress-pct u75) (not (get milestone-75-reached milestones)))
          (begin
            (map-set petition-milestones { petition-id: petition-id } (merge milestones { milestone-75-reached: true, milestone-75-block: stacks-block-height }))
            (map-set milestone-events { petition-id: petition-id, milestone-type: u75 } { unlocked-at: stacks-block-height, signatures-at-unlock: current-sigs, momentum-score: (get signature-rate momentum) })
          )
          (if (and (>= progress-pct u100) (not (get milestone-100-reached milestones)))
            (begin
              (map-set petition-milestones { petition-id: petition-id } (merge milestones { milestone-100-reached: true, milestone-100-block: stacks-block-height }))
              (map-set milestone-events { petition-id: petition-id, milestone-type: u100 } { unlocked-at: stacks-block-height, signatures-at-unlock: current-sigs, momentum-score: (get signature-rate momentum) })
            )
            true
          )
        )
      )
    )
  )
)