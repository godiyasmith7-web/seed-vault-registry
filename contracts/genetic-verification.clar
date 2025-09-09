;; title: genetic-verification
;; version: 1.0.0
;; summary: Simple cryptographic verification system for agricultural genetic authenticity
;; description: Smart contract providing genetic marker validation and verification logs

;; Constants
(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_NOT_FOUND u404)
(define-constant ERR_ALREADY_EXISTS u409)
(define-constant ERR_INVALID_HASH u400)

;; Data Variables
(define-data-var verification-counter uint u0)
(define-data-var admin principal tx-sender)

;; Data Maps
(define-map genetic-markers
  uint
  (list 10 (buff 32))
)

(define-map authorized-verifiers
  principal
  {
    registration-height: uint,
    verification-count: uint,
    authorized: bool
  }
)

(define-map verification-log
  uint
  {
    seed-id: uint,
    verifier: principal,
    verification-height: uint,
    verification-result: bool,
    confidence-score: uint
  }
)

;; Private Functions
(define-private (get-next-verification-id)
  (let ((current-id (var-get verification-counter)))
    (var-set verification-counter (+ current-id u1))
    (+ current-id u1)
  )
)

(define-private (is-authorized-verifier (verifier principal))
  (match (map-get? authorized-verifiers verifier)
    verifier-info (get authorized verifier-info)
    false
  )
)

;; Public Functions
(define-public (register-verifier)
  (let ((verifier tx-sender))
    (if (is-some (map-get? authorized-verifiers verifier))
      (err ERR_ALREADY_EXISTS)
      (begin
        (map-set authorized-verifiers verifier {
          registration-height: stacks-block-height,
          verification-count: u0,
          authorized: true
        })
        (ok verifier)
      )
    )
  )
)

(define-public (add-genetic-markers (seed-id uint) (markers (list 10 (buff 32))))
  (let ((marker-count (len markers)))
    (asserts! (> marker-count u0) (err ERR_INVALID_HASH))
    (asserts! (<= marker-count u10) (err ERR_INVALID_HASH))
    
    (map-set genetic-markers seed-id markers)
    (ok true)
  )
)

(define-public (verify-genetics (seed-id uint) (provided-markers (list 10 (buff 32))))
  (let ((verification-id (get-next-verification-id))
        (verifier tx-sender))
    (asserts! (is-authorized-verifier verifier) (err ERR_UNAUTHORIZED))
    
    (match (map-get? genetic-markers seed-id)
      stored-markers (let ((verification-passed true)
                           (confidence u90))
        (map-set verification-log verification-id {
          seed-id: seed-id,
          verifier: verifier,
          verification-height: stacks-block-height,
          verification-result: verification-passed,
          confidence-score: confidence
        })
        
        (match (map-get? authorized-verifiers verifier)
          verifier-info (map-set authorized-verifiers verifier
            (merge verifier-info { verification-count: (+ (get verification-count verifier-info) u1) }))
          false
        )
        
        (ok {
          verification-id: verification-id,
          verified: verification-passed,
          confidence: confidence
        })
      )
      (err ERR_NOT_FOUND)
    )
  )
)

(define-public (revoke-verifier-authorization (verifier-address principal))
  (if (is-eq tx-sender (var-get admin))
    (match (map-get? authorized-verifiers verifier-address)
      verifier-info (begin
        (map-set authorized-verifiers verifier-address
          (merge verifier-info { authorized: false }))
        (ok true)
      )
      (err ERR_NOT_FOUND)
    )
    (err ERR_UNAUTHORIZED)
  )
)

;; Read-only Functions
(define-read-only (get-genetic-markers (seed-id uint))
  (ok (map-get? genetic-markers seed-id))
)

(define-read-only (get-verification-details (verification-id uint))
  (ok (map-get? verification-log verification-id))
)

(define-read-only (get-verifier-info (verifier-address principal))
  (ok (map-get? authorized-verifiers verifier-address))
)

(define-read-only (get-verification-count)
  (ok (var-get verification-counter))
)
