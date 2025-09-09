;; title: seed-vault-registry
;; version: 1.0.0
;; summary: Simple decentralized registry for crop genetics and seed vault management
;; description: Smart contract enabling farmers to register and track genetic material

;; Constants
(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_NOT_FOUND u404)
(define-constant ERR_ALREADY_EXISTS u409)
(define-constant ERR_INVALID_PARAMS u400)

;; Data Variables  
(define-data-var seed-counter uint u0)

;; Data Maps
(define-map seed-registry 
  uint
  {
    genetic-fingerprint: (buff 32),
    owner: principal,
    locked: bool,
    quality-score: uint
  }
)

(define-map farmer-registry
  principal
  {
    registration-height: uint,
    total-seeds: uint
  }
)

;; Private Functions
(define-private (get-next-seed-id)
  (let ((current-id (var-get seed-counter)))
    (var-set seed-counter (+ current-id u1))
    (+ current-id u1)
  )
)

(define-private (is-seed-owner (seed-id uint) (caller principal))
  (match (map-get? seed-registry seed-id)
    seed-data (is-eq caller (get owner seed-data))
    false
  )
)

;; Public Functions
(define-public (register-farmer)
  (let ((farmer tx-sender))
    (if (is-some (map-get? farmer-registry farmer))
      (err ERR_ALREADY_EXISTS)
      (begin
        (map-set farmer-registry farmer {
          registration-height: stacks-block-height,
          total-seeds: u0
        })
        (ok farmer)
      )
    )
  )
)

(define-public (register-seed (genetic-fingerprint (buff 32)))
  (let ((seed-id (get-next-seed-id))
        (farmer tx-sender))
    (asserts! (is-eq (len genetic-fingerprint) u32) (err ERR_INVALID_PARAMS))
    (asserts! (is-some (map-get? farmer-registry farmer)) (err ERR_UNAUTHORIZED))
    
    (map-set seed-registry seed-id {
      genetic-fingerprint: genetic-fingerprint,
      owner: farmer,
      locked: false,
      quality-score: u50
    })
    
    (match (map-get? farmer-registry farmer)
      farmer-info (map-set farmer-registry farmer
        (merge farmer-info { total-seeds: (+ (get total-seeds farmer-info) u1) }))
      false
    )
    
    (ok seed-id)
  )
)

(define-public (lock-vault (seed-id uint))
  (if (is-seed-owner seed-id tx-sender)
    (match (map-get? seed-registry seed-id)
      seed-data (begin
        (map-set seed-registry seed-id (merge seed-data { locked: true }))
        (ok true)
      )
      (err ERR_NOT_FOUND)
    )
    (err ERR_UNAUTHORIZED)
  )
)

(define-public (unlock-vault (seed-id uint))
  (if (is-seed-owner seed-id tx-sender)
    (match (map-get? seed-registry seed-id)
      seed-data (begin
        (map-set seed-registry seed-id (merge seed-data { locked: false }))
        (ok true)
      )
      (err ERR_NOT_FOUND)
    )
    (err ERR_UNAUTHORIZED)
  )
)

(define-public (update-quality-score (seed-id uint) (new-score uint))
  (if (and (is-seed-owner seed-id tx-sender) (<= new-score u100))
    (match (map-get? seed-registry seed-id)
      seed-data (begin
        (map-set seed-registry seed-id (merge seed-data { quality-score: new-score }))
        (ok true)
      )
      (err ERR_NOT_FOUND)
    )
    (err ERR_UNAUTHORIZED)
  )
)

;; Read-only Functions
(define-read-only (get-seed-info (seed-id uint))
  (ok (map-get? seed-registry seed-id))
)

(define-read-only (get-farmer-info (farmer principal))
  (ok (map-get? farmer-registry farmer))
)

(define-read-only (get-total-seeds)
  (ok (var-get seed-counter))
)
