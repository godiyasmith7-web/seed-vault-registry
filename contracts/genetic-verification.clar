;; title: genetic-verification
;; version: 1.0.0
;; summary: Cryptographic verification system for agricultural genetic authenticity
;; description: Smart contract providing genetic marker validation, authenticity
;;              scoring, and tamper-proof verification logs for seed genetics
;;              registered in the seed vault registry system.

;; =================================
;; CONSTANTS & ERROR CODES
;; =================================

(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_NOT_FOUND u404)
(define-constant ERR_ALREADY_VERIFIED u409)
(define-constant ERR_INVALID_HASH u400)
(define-constant ERR_VERIFICATION_FAILED u422)
(define-constant ERR_INSUFFICIENT_MARKERS u406)
(define-constant MIN_VERIFICATION_MARKERS u3)
(define-constant MAX_VERIFICATION_MARKERS u20)
(define-constant VERIFICATION_EXPIRY_BLOCKS u52560)
(define-constant QUALITY_THRESHOLD u70)
(define-constant VERIFICATION_ADMIN tx-sender)

;; =================================
;; DATA STORAGE STRUCTURES
;; =================================

(define-data-var verification-counter uint u0)
(define-data-var total-verifications uint u0)

(define-map genetic-markers
  uint
  (list 20 (buff 32))
)

(define-map verification-log
  uint
  {
    seed-id: uint,
    verifier: principal,
    verification-height: uint,
    genetic-hash: (buff 32),
    verification-result: bool,
    confidence-score: uint,
    marker-matches: uint,
    total-markers: uint,
    verification-type: (string-ascii 20)
  }
)

(define-map verification-status
  uint
  {
    is-verified: bool,
    last-verification-id: uint,
    last-verification-height: uint,
    total-verification-attempts: uint,
    authenticity-score: uint,
    verification-expires: uint
  }
)

(define-map authorized-verifiers
  principal
  {
    registration-height: uint,
    verification-count: uint,
    success-rate: uint,
    specialization: (string-ascii 100),
    authorized: bool,
    certification-level: uint
  }
)

(define-map marker-quality
  { seed-id: uint, marker-index: uint }
  {
    quality-score: uint,
    stability-rating: uint,
    last-updated: uint,
    verified-by: principal
  }
)

;; =================================
;; PRIVATE HELPER FUNCTIONS
;; =================================

(define-private (get-next-verification-id)
  (let ((current-id (var-get verification-counter)))
    (var-set verification-counter (+ current-id u1))
    (+ current-id u1)
  )
)

(define-private (calculate-confidence (matches uint) (total uint))
  (if (> total u0)
    (/ (* matches u100) total)
    u0
  )
)

(define-private (is-valid-genetic-hash (hash (buff 32)))
  (is-eq (len hash) u32)
)

(define-private (is-authorized-verifier (verifier principal))
  (match (map-get? authorized-verifiers verifier)
    verifier-info (get authorized verifier-info)
    false
  )
)

(define-private (validate-marker (marker (buff 32)) (acc bool))
  (and acc (is-valid-genetic-hash marker))
)

(define-private (count-marker-matches (provided-markers (list 20 (buff 32))) (stored-markers (list 20 (buff 32))))
  (let ((provided-len (len provided-markers)) (stored-len (len stored-markers)))
    (if (and (> provided-len u0) (> stored-len u0))
      ;; Simplified matching - compare first few markers
      (if (is-eq (unwrap-panic (element-at provided-markers u0)) (unwrap-panic (element-at stored-markers u0)))
        u1
        u0
      )
      u0
    )
  )
)

;; =================================
;; PUBLIC FUNCTIONS
;; =================================

;; Register as an authorized genetic verifier
(define-public (register-verifier (specialization (string-ascii 100)) (certification-level uint))
  (let (
    (verifier tx-sender)
    (current-height block-height)
  )
    (asserts! (and (> certification-level u0) (<= certification-level u5)) (err ERR_INVALID_HASH))
    
    (if (is-some (map-get? authorized-verifiers verifier))
      (err ERR_ALREADY_VERIFIED)
      (begin
        (map-set authorized-verifiers verifier {
          registration-height: current-height,
          verification-count: u0,
          success-rate: u100,
          specialization: specialization,
          authorized: true,
          certification-level: certification-level
        })
        (ok verifier)
      )
    )
  )
)

;; Add genetic markers for a seed
(define-public (add-genetic-markers (seed-id uint) (markers (list 20 (buff 32))))
  (let (
    (marker-count (len markers))
    (current-height block-height)
  )
    (asserts! (and (>= marker-count MIN_VERIFICATION_MARKERS)
                   (<= marker-count MAX_VERIFICATION_MARKERS)) (err ERR_INSUFFICIENT_MARKERS))
    
    (asserts! (fold validate-marker markers true) (err ERR_INVALID_HASH))
    
    (map-set genetic-markers seed-id markers)
    
    ;; Initialize some marker quality entries
    (map-set marker-quality { seed-id: seed-id, marker-index: u0 } {
      quality-score: u50, stability-rating: u50, last-updated: current-height, verified-by: tx-sender
    })
    
    (ok true)
  )
)

;; Perform genetic verification
(define-public (verify-genetics 
    (seed-id uint) 
    (provided-hash (buff 32))
    (provided-markers (list 20 (buff 32)))
    (verification-type (string-ascii 20))
  )
  (let (
    (verification-id (get-next-verification-id))
    (verifier tx-sender)
    (current-height block-height)
    (stored-markers (default-to (list) (map-get? genetic-markers seed-id)))
    (marker-count (len provided-markers))
  )
    (asserts! (is-valid-genetic-hash provided-hash) (err ERR_INVALID_HASH))
    (asserts! (is-authorized-verifier verifier) (err ERR_UNAUTHORIZED))
    (asserts! (>= marker-count MIN_VERIFICATION_MARKERS) (err ERR_INSUFFICIENT_MARKERS))
    
    (if (> (len stored-markers) u0)
      (let (
        (matches (count-marker-matches provided-markers stored-markers))
        (total-stored (len stored-markers))
        (confidence (calculate-confidence matches total-stored))
        (verification-passed (>= confidence QUALITY_THRESHOLD))
      )
        ;; Log verification attempt
        (map-set verification-log verification-id {
          seed-id: seed-id,
          verifier: verifier,
          verification-height: current-height,
          genetic-hash: provided-hash,
          verification-result: verification-passed,
          confidence-score: confidence,
          marker-matches: matches,
          total-markers: total-stored,
          verification-type: verification-type
        })
        
        ;; Update verification status
        (let (
          (current-status (default-to 
                           { is-verified: false, last-verification-id: u0, 
                             last-verification-height: u0, total-verification-attempts: u0,
                             authenticity-score: u0, verification-expires: u0 }
                           (map-get? verification-status seed-id)))
        )
          (map-set verification-status seed-id {
            is-verified: verification-passed,
            last-verification-id: verification-id,
            last-verification-height: current-height,
            total-verification-attempts: (+ (get total-verification-attempts current-status) u1),
            authenticity-score: confidence,
            verification-expires: (+ current-height VERIFICATION_EXPIRY_BLOCKS)
          })
        )
        
        ;; Update verifier statistics
        (match (map-get? authorized-verifiers verifier)
          verifier-info (
            (let (
              (new-count (+ (get verification-count verifier-info) u1))
              (new-success-rate (if verification-passed u100 u50))
            )
              (map-set authorized-verifiers verifier
                (merge verifier-info {
                  verification-count: new-count,
                  success-rate: new-success-rate
                })
              )
            )
          )
          false
        )
        
        ;; Update global counter if successful
        (if verification-passed
          (var-set total-verifications (+ (var-get total-verifications) u1))
          false
        )
        
        (ok {
          verification-id: verification-id,
          verified: verification-passed,
          confidence: confidence,
          matches: matches,
          total: total-stored
        })
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; Update marker quality score
(define-public (update-marker-quality (seed-id uint) (marker-index uint) (quality-score uint) (stability-rating uint))
  (let (
    (caller tx-sender)
    (current-height block-height)
  )
    (asserts! (and (<= quality-score u100) (<= stability-rating u100)) (err ERR_INVALID_HASH))
    (asserts! (< marker-index MAX_VERIFICATION_MARKERS) (err ERR_INVALID_HASH))
    (asserts! (is-authorized-verifier caller) (err ERR_UNAUTHORIZED))
    
    (map-set marker-quality { seed-id: seed-id, marker-index: marker-index } {
      quality-score: quality-score,
      stability-rating: stability-rating,
      last-updated: current-height,
      verified-by: caller
    })
    
    (ok true)
  )
)

;; Revoke verifier authorization (admin only)
(define-public (revoke-verifier-authorization (verifier-address principal))
  (let ((is-admin (is-eq tx-sender VERIFICATION_ADMIN)))
    (if is-admin
      (match (map-get? authorized-verifiers verifier-address)
        verifier-info (
          (begin
            (map-set authorized-verifiers verifier-address
              (merge verifier-info { authorized: false })
            )
            (ok true)
          )
        )
        (err ERR_NOT_FOUND)
      )
      (err ERR_UNAUTHORIZED)
    )
  )
)

;; =================================
;; READ-ONLY FUNCTIONS
;; =================================

(define-read-only (get-verification-status (seed-id uint))
  (ok (map-get? verification-status seed-id))
)

(define-read-only (get-verification-details (verification-id uint))
  (ok (map-get? verification-log verification-id))
)

(define-read-only (get-genetic-markers (seed-id uint))
  (ok (map-get? genetic-markers seed-id))
)

(define-read-only (get-verifier-info (verifier-address principal))
  (ok (map-get? authorized-verifiers verifier-address))
)

(define-read-only (get-marker-quality (seed-id uint) (marker-index uint))
  (ok (map-get? marker-quality { seed-id: seed-id, marker-index: marker-index }))
)

(define-read-only (is-verification-valid (seed-id uint))
  (match (map-get? verification-status seed-id)
    status (
      (and (get is-verified status)
           (> (get verification-expires status) block-height))
    )
    false
  )
)

(define-read-only (get-verification-stats)
  (ok {
    total-verifications: (var-get total-verifications),
    total-verification-attempts: (var-get verification-counter),
    admin: VERIFICATION_ADMIN
  })
)
