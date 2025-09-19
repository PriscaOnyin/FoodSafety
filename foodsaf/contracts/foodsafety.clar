;; Food Safety Monitoring Network
;; Comprehensive blockchain system for tracking food safety through the entire supply chain

;; Regulatory Constants
(define-constant FOOD_SAFETY_AUTHORITY tx-sender)
(define-constant ERR_UNAUTHORIZED_OPERATION (err u400))
(define-constant ERR_BATCH_NOT_FOUND (err u401))
(define-constant ERR_INVALID_INSPECTOR (err u402))
(define-constant ERR_DATA_INTEGRITY_ERROR (err u403))
(define-constant ERR_SAFETY_VIOLATION (err u404))
(define-constant ERR_CONTAMINATION_RISK (err u405))
(define-constant ERR_EXPIRED_CERTIFICATION (err u406))

;; System Configuration Variables
(define-data-var next-batch-id uint u1)
(define-data-var monitoring-active bool true)
(define-data-var minimum-safety-score uint u90)
(define-data-var inspection-validity-blocks uint u4380) ;; ~30 days in blocks

;; Core Food Safety Data Maps
(define-map food-batches
  { batch-id: uint }
  {
    product-identifier: (buff 32),
    product-category: (string-ascii 90),
    processing-facility: principal,
    current-status: (string-ascii 80),
    production-date: uint,
    last-inspection: uint,
    inspection-count: uint,
    safety-rating: uint
  }
)

(define-map safety-checkpoints
  { batch-id: uint, checkpoint-id: uint }
  {
    checkpoint-type: (string-ascii 80),
    safety-inspector: principal,
    facility-location: (string-ascii 140),
    inspection-timestamp: uint,
    safety-score: uint,
    is-compliant: bool,
    contamination-hash: (buff 32)
  }
)

(define-map certified-inspectors
  { inspector: principal }
  {
    inspector-organization: (string-ascii 140),
    specialization-area: (string-ascii 80),
    certification-grade: uint,
    is-authorized: bool,
    inspections-completed: uint,
    last-certification: uint
  }
)

(define-map batch-traceability
  { batch-id: uint }
  {
    origin-farm: (string-ascii 140),
    processing-date: uint,
    distribution-network: (string-ascii 140),
    expiration-date: uint,
    recall-status: bool
  }
)

;; Enhanced Input Validation
(define-private (validate-text-140 (input (string-ascii 140)))
  (and (> (len input) u0) (<= (len input) u140))
)

(define-private (validate-text-90 (input (string-ascii 90)))
  (and (> (len input) u0) (<= (len input) u90))
)

(define-private (validate-text-80 (input (string-ascii 80)))
  (and (> (len input) u0) (<= (len input) u80))
)

(define-private (validate-safety-score (score uint))
  (and (>= score u0) (<= score u100))
)

(define-private (validate-inspector-principal (inspector principal))
  (not (is-eq inspector 'SP000000000000000000002Q6VF78))
)

(define-private (validate-batch-exists (batch-id uint))
  (is-some (map-get? food-batches { batch-id: batch-id }))
)

(define-private (validate-monitoring-active)
  (var-get monitoring-active)
)

(define-private (validate-certification-grade (grade uint))
  (and (>= grade u1) (<= grade u5))
)

(define-private (validate-product-hash (hash (buff 32)))
  (> (len hash) u0)
)

(define-private (validate-expiration-date (exp-date uint))
  (> exp-date stacks-block-height)
)

;; Added batch-id validation function
(define-private (validate-batch-id (batch-id uint))
  (and (> batch-id u0) (< batch-id (var-get next-batch-id)))
)

;; Inspector Certification System
(define-public (certify-safety-inspector 
  (inspector principal) 
  (inspector-organization (string-ascii 140)) 
  (specialization-area (string-ascii 80))
  (certification-grade uint))
  (begin
    (asserts! (is-eq tx-sender FOOD_SAFETY_AUTHORITY) ERR_UNAUTHORIZED_OPERATION)
    (asserts! (validate-monitoring-active) ERR_UNAUTHORIZED_OPERATION)
    (asserts! (validate-inspector-principal inspector) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (validate-text-140 inspector-organization) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (validate-text-80 specialization-area) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (validate-certification-grade certification-grade) ERR_DATA_INTEGRITY_ERROR)
    
    (ok (map-set certified-inspectors
      { inspector: inspector }
      { 
        inspector-organization: inspector-organization, 
        specialization-area: specialization-area,
        certification-grade: certification-grade,
        is-authorized: true,
        inspections-completed: u0,
        last-certification: stacks-block-height
      }
    ))
  )
)

(define-public (suspend-monitoring)
  (begin
    (asserts! (is-eq tx-sender FOOD_SAFETY_AUTHORITY) ERR_UNAUTHORIZED_OPERATION)
    (var-set monitoring-active false)
    (ok true)
  )
)

(define-public (resume-monitoring)
  (begin
    (asserts! (is-eq tx-sender FOOD_SAFETY_AUTHORITY) ERR_UNAUTHORIZED_OPERATION)
    (var-set monitoring-active true)
    (ok true)
  )
)

;; Batch Traceability Management
(define-public (register-batch-traceability 
  (batch-id uint)
  (origin-farm (string-ascii 140))
  (distribution-network (string-ascii 140))
  (expiration-date uint))
  (begin
    (asserts! (validate-monitoring-active) ERR_UNAUTHORIZED_OPERATION)
    (asserts! (validate-batch-exists batch-id) ERR_BATCH_NOT_FOUND)
    (asserts! (is-certified-inspector tx-sender) ERR_INVALID_INSPECTOR)
    (asserts! (validate-text-140 origin-farm) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (validate-text-140 distribution-network) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (validate-expiration-date expiration-date) ERR_DATA_INTEGRITY_ERROR)
    
    (ok (map-set batch-traceability
      { batch-id: batch-id }
      {
        origin-farm: origin-farm,
        processing-date: stacks-block-height,
        distribution-network: distribution-network,
        expiration-date: expiration-date,
        recall-status: false
      }
    ))
  )
)

;; Core Food Safety Functions
(define-public (create-food-batch 
  (product-identifier (buff 32))
  (product-category (string-ascii 90))
  (safety-rating uint))
  (let ((batch-id (var-get next-batch-id)))
    (asserts! (validate-monitoring-active) ERR_UNAUTHORIZED_OPERATION)
    (asserts! (is-certified-inspector tx-sender) ERR_UNAUTHORIZED_OPERATION)
    (asserts! (validate-product-hash product-identifier) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (validate-text-90 product-category) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (validate-safety-score safety-rating) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (>= safety-rating (var-get minimum-safety-score)) ERR_SAFETY_VIOLATION)
    
    (map-set food-batches
      { batch-id: batch-id }
      {
        product-identifier: product-identifier,
        product-category: product-category,
        processing-facility: tx-sender,
        current-status: "created",
        production-date: stacks-block-height,
        last-inspection: stacks-block-height,
        inspection-count: u0,
        safety-rating: safety-rating
      }
    )
    
    (map-set safety-checkpoints
      { batch-id: batch-id, checkpoint-id: u0 }
      {
        checkpoint-type: "initial-production",
        safety-inspector: tx-sender,
        facility-location: "Production Facility",
        inspection-timestamp: stacks-block-height,
        safety-score: safety-rating,
        is-compliant: true,
        contamination-hash: product-identifier
      }
    )
    
    (var-set next-batch-id (+ batch-id u1))
    (ok batch-id)
  )
)

(define-public (add-safety-checkpoint 
  (batch-id uint) 
  (checkpoint-type (string-ascii 80)) 
  (facility-location (string-ascii 140)) 
  (safety-score uint)
  (contamination-hash (buff 32)))
  (let ((checkpoint-id (+ (get-checkpoint-count batch-id) u1))
        (batch-data (unwrap! (map-get? food-batches { batch-id: batch-id }) ERR_BATCH_NOT_FOUND)))
    (asserts! (validate-monitoring-active) ERR_UNAUTHORIZED_OPERATION)
    (asserts! (is-certified-inspector tx-sender) ERR_UNAUTHORIZED_OPERATION)
    ;; Added batch-id validation before using in map operations
    (asserts! (validate-batch-id batch-id) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (validate-text-80 checkpoint-type) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (validate-text-140 facility-location) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (validate-safety-score safety-score) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (>= safety-score (var-get minimum-safety-score)) ERR_SAFETY_VIOLATION)
    (asserts! (validate-product-hash contamination-hash) ERR_DATA_INTEGRITY_ERROR)
    
    (map-set safety-checkpoints
      { batch-id: batch-id, checkpoint-id: checkpoint-id }
      {
        checkpoint-type: checkpoint-type,
        safety-inspector: tx-sender,
        facility-location: facility-location,
        inspection-timestamp: stacks-block-height,
        safety-score: safety-score,
        is-compliant: (>= safety-score (var-get minimum-safety-score)),
        contamination-hash: contamination-hash
      }
    )
    
    (map-set food-batches
      { batch-id: batch-id }
      (merge batch-data
             { 
               current-status: checkpoint-type,
               last-inspection: stacks-block-height,
               inspection-count: (+ (get inspection-count batch-data) u1),
               safety-rating: safety-score
             })
    )
    
    ;; Update inspector statistics
    (map-set certified-inspectors
      { inspector: tx-sender }
      (merge (unwrap-panic (map-get? certified-inspectors { inspector: tx-sender }))
             { inspections-completed: (+ (get inspections-completed (unwrap-panic (map-get? certified-inspectors { inspector: tx-sender }))) u1) })
    )
    
    (ok checkpoint-id)
  )
)

(define-public (initiate-batch-recall (batch-id uint) (recall-reason (string-ascii 140)))
  (let ((batch-data (unwrap! (map-get? food-batches { batch-id: batch-id }) ERR_BATCH_NOT_FOUND)))
    (asserts! (validate-monitoring-active) ERR_UNAUTHORIZED_OPERATION)
    (asserts! (or (is-eq tx-sender FOOD_SAFETY_AUTHORITY) 
                  (is-eq tx-sender (get processing-facility batch-data))) ERR_UNAUTHORIZED_OPERATION)
    ;; Added batch-id validation before using in map operations
    (asserts! (validate-batch-id batch-id) ERR_DATA_INTEGRITY_ERROR)
    (asserts! (validate-text-140 recall-reason) ERR_DATA_INTEGRITY_ERROR)
    
    (map-set batch-traceability
      { batch-id: batch-id }
      (merge (default-to 
               { origin-farm: "Unknown", processing-date: u0, distribution-network: "Unknown", expiration-date: u0, recall-status: false }
               (map-get? batch-traceability { batch-id: batch-id }))
             { recall-status: true })
    )
    
    (map-set food-batches
      { batch-id: batch-id }
      (merge batch-data { current-status: "recalled" })
    )
    
    (ok true)
  )
)

;; Query and Safety Verification Functions
(define-read-only (get-food-batch (batch-id uint))
  (map-get? food-batches { batch-id: batch-id })
)

(define-read-only (get-safety-checkpoint (batch-id uint) (checkpoint-id uint))
  (map-get? safety-checkpoints { batch-id: batch-id, checkpoint-id: checkpoint-id })
)

(define-read-only (get-batch-traceability (batch-id uint))
  (map-get? batch-traceability { batch-id: batch-id })
)

(define-read-only (is-certified-inspector (inspector principal))
  (match (map-get? certified-inspectors { inspector: inspector })
    inspector-data (and (get is-authorized inspector-data) 
                       (< (- stacks-block-height (get last-certification inspector-data)) (var-get inspection-validity-blocks)))
    false
  )
)

(define-read-only (get-inspector-credentials (inspector principal))
  (map-get? certified-inspectors { inspector: inspector })
)

(define-read-only (get-checkpoint-count (batch-id uint))
  (match (map-get? food-batches { batch-id: batch-id })
    batch-data (get inspection-count batch-data)
    u0
  )
)

(define-read-only (get-monitoring-status)
  {
    is-active: (var-get monitoring-active),
    next-batch-id: (var-get next-batch-id),
    minimum-safety-score: (var-get minimum-safety-score),
    inspection-validity-period: (var-get inspection-validity-blocks)
  }
)

(define-read-only (verify-batch-safety (batch-id uint))
  (let ((batch-data (map-get? food-batches { batch-id: batch-id }))
        (traceability-data (map-get? batch-traceability { batch-id: batch-id })))
    (match batch-data
      batch (and (>= (get safety-rating batch) (var-get minimum-safety-score))
                (> (get inspection-count batch) u0)
                (< (- stacks-block-height (get last-inspection batch)) (var-get inspection-validity-blocks))
                (match traceability-data
                  trace (not (get recall-status trace))
                  true))
      false
    )
  )
)

(define-read-only (check-contamination-risk (batch-id uint))
  (let ((batch-data (map-get? food-batches { batch-id: batch-id })))
    (match batch-data
      batch (< (get safety-rating batch) (var-get minimum-safety-score))
      true
    )
  )
)

(define-read-only (get-batch-recall-status (batch-id uint))
  (match (map-get? batch-traceability { batch-id: batch-id })
    trace-data (get recall-status trace-data)
    false
  )
)
