;; title: seed-vault-registry
;; version: 1.0.0
;; summary: Decentralized registry for crop genetics and seed vault management
;; description: Smart contract enabling farmers and institutions to register,
;;              verify, and track genetic material with cryptographic proof
;;              and immutable lineage records for agricultural preservation.

;; =================================
;; CONSTANTS & ERROR CODES
;; =================================

(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_NOT_FOUND u404)
(define-constant ERR_ALREADY_EXISTS u409)
(define-constant ERR_VAULT_LOCKED u423)
(define-constant ERR_INVALID_PARAMS u400)
(define-constant MAX_LINEAGE_DEPTH u10)
(define-constant VAULT_ADMIN tx-sender)

;; =================================
;; DATA STORAGE STRUCTURES
;; =================================

(define-data-var seed-counter uint u0)
(define-data-var total-farmers uint u0)

(define-map seed-registry 
  uint  ;; seed-id
  {
    genetic-fingerprint: (buff 32),
    owner: principal,
    batch-id: uint,
    registration-height: uint,
    locked: bool,
    quality-score: uint,
    seed-type: (string-ascii 50),
    origin-location: (string-ascii 100)
  }
)

(define-map lineage-records
  uint
  (list 10 uint)
)

(define-map farmer-registry
  principal
  {
    registration-height: uint,
    total-seeds: uint,
    verified-status: bool,
    location: (string-ascii 100)
  }
)

(define-map batch-registry
  uint
  {
    creator: principal,
    creation-height: uint,
    seed-count: uint,
    harvest-season: (string-ascii 20),
    notes: (string-ascii 200)
  }
)

;; =================================
;; PRIVATE HELPER FUNCTIONS
;; =================================

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

(define-private (is-valid-fingerprint (fingerprint (buff 32)))
  (is-eq (len fingerprint) u32)
)

(define-private (verify-parent-exists (parent-id uint) (acc bool))
  (and acc (is-some (map-get? seed-registry parent-id)))
)

;; =================================
;; PUBLIC FUNCTIONS
;; =================================

;; Register a new farmer in the system
(define-public (register-farmer (location (string-ascii 100)))
  (let (
    (farmer tx-sender)
    (current-height block-height)
  )
    (if (is-some (map-get? farmer-registry farmer))
      (err ERR_ALREADY_EXISTS)
      (begin
        (map-set farmer-registry farmer {
          registration-height: current-height,
          total-seeds: u0,
          verified-status: false,
          location: location
        })
        (var-set total-farmers (+ (var-get total-farmers) u1))
        (ok farmer)
      )
    )
  )
)

;; Register new seed genetics with comprehensive metadata
(define-public (register-seed 
    (genetic-fingerprint (buff 32))
    (batch-id uint)
    (seed-type (string-ascii 50))
    (origin-location (string-ascii 100))
  )
  (let (
    (seed-id (get-next-seed-id))
    (farmer tx-sender)
    (current-height block-height)
  )
    (asserts! (is-valid-fingerprint genetic-fingerprint) (err ERR_INVALID_PARAMS))
    (asserts! (> batch-id u0) (err ERR_INVALID_PARAMS))
    (asserts! (> (len seed-type) u0) (err ERR_INVALID_PARAMS))
    
    (match (map-get? farmer-registry farmer)
      farmer-info (
        (begin
          (map-set seed-registry seed-id {
            genetic-fingerprint: genetic-fingerprint,
            owner: farmer,
            batch-id: batch-id,
            registration-height: current-height,
            locked: false,
            quality-score: u50,
            seed-type: seed-type,
            origin-location: origin-location
          })
          
          (map-set farmer-registry farmer
            (merge farmer-info { total-seeds: (+ (get total-seeds farmer-info) u1) })
          )
          
          (match (map-get? batch-registry batch-id)
            batch-info (
              (map-set batch-registry batch-id
                (merge batch-info { seed-count: (+ (get seed-count batch-info) u1) })
              )
            )
            (map-set batch-registry batch-id {
              creator: farmer,
              creation-height: current-height,
              seed-count: u1,
              harvest-season: "Unknown",
              notes: "Auto-created batch"
            })
          )
          
          (ok seed-id)
        )
      )
      (err ERR_UNAUTHORIZED)
    )
  )
)

;; Lock a seed vault to prevent unauthorized modifications
(define-public (lock-vault (seed-id uint))
  (let ((seed-info (map-get? seed-registry seed-id)))
    (match seed-info
      seed-data (
        (if (is-seed-owner seed-id tx-sender)
          (begin
            (map-set seed-registry seed-id
              (merge seed-data { locked: true })
            )
            (ok true)
          )
          (err ERR_UNAUTHORIZED)
        )
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; Unlock a seed vault
(define-public (unlock-vault (seed-id uint))
  (let ((seed-info (map-get? seed-registry seed-id)))
    (match seed-info
      seed-data (
        (if (is-eq tx-sender (get owner seed-data))
          (begin
            (map-set seed-registry seed-id
              (merge seed-data { locked: false })
            )
            (ok true)
          )
          (err ERR_UNAUTHORIZED)
        )
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; Record lineage information for breeding programs
(define-public (record-lineage (child-seed-id uint) (parent-seed-ids (list 10 uint)))
  (let (
    (child-info (map-get? seed-registry child-seed-id))
    (parent-count (len parent-seed-ids))
  )
    (match child-info
      child-data (
        (if (and (is-seed-owner child-seed-id tx-sender)
                 (> parent-count u0)
                 (<= parent-count MAX_LINEAGE_DEPTH))
          (begin
            (asserts! (fold verify-parent-exists parent-seed-ids true) (err ERR_NOT_FOUND))
            (map-set lineage-records child-seed-id parent-seed-ids)
            (ok true)
          )
          (err ERR_UNAUTHORIZED)
        )
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; Update quality score for a seed
(define-public (update-quality-score (seed-id uint) (new-score uint))
  (let ((seed-info (map-get? seed-registry seed-id)))
    (match seed-info
      seed-data (
        (if (and (is-seed-owner seed-id tx-sender)
                 (<= new-score u100))
          (begin
            (map-set seed-registry seed-id
              (merge seed-data { quality-score: new-score })
            )
            (ok true)
          )
          (err ERR_UNAUTHORIZED)
        )
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; =================================
;; READ-ONLY FUNCTIONS
;; =================================

(define-read-only (get-seed-info (seed-id uint))
  (ok (map-get? seed-registry seed-id))
)

(define-read-only (get-seed-lineage (seed-id uint))
  (ok (map-get? lineage-records seed-id))
)

(define-read-only (get-farmer-info (farmer-address principal))
  (ok (map-get? farmer-registry farmer-address))
)

(define-read-only (get-batch-info (batch-id uint))
  (ok (map-get? batch-registry batch-id))
)

(define-read-only (get-system-stats)
  (ok {
    total-seeds: (var-get seed-counter),
    total-farmers: (var-get total-farmers),
    contract-admin: VAULT_ADMIN
  })
)

(define-read-only (is-vault-locked (seed-id uint))
  (match (map-get? seed-registry seed-id)
    seed-data (ok (get locked seed-data))
    (err ERR_NOT_FOUND)
  )
)
