;; Certification Management Contract v1
;; Issues and manages skill certifications

;; Constants
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_NOT_FOUND (err u501))
(define-constant ERR_ALREADY_EXISTS (err u502))
(define-constant ERR_EXPIRED (err u503))
(define-constant ERR_INVALID_INPUT (err u504))

;; Data Variables
(define-data-var certificate-id-nonce uint u0)

;; Data Maps
(define-map certificates
  uint
  {
    employee: principal,
    issuer: principal,
    skill-name: (string-ascii 50),
    certification-level: uint,
    issue-date: uint,
    expiry-date: uint,
    status: (string-ascii 20),
    verification-hash: (buff 32)
  }
)

(define-map employee-certificates
  principal
  (list 20 uint)
)

(define-map certificate-templates
  (string-ascii 50)
  {
    skill-name: (string-ascii 50),
    validity-period: uint,
    min-score-required: uint,
    issuer-requirements: (string-ascii 100)
  }
)

;; Public Functions

;; Create certificate template
(define-public (create-template
  (skill-name (string-ascii 50))
  (validity-period uint)
  (min-score-required uint)
  (issuer-requirements (string-ascii 100)))

  (let ((coordinator tx-sender))
    (asserts! (> validity-period u0) ERR_INVALID_INPUT)
    (asserts! (<= min-score-required u100) ERR_INVALID_INPUT)

    (map-set certificate-templates skill-name {
      skill-name: skill-name,
      validity-period: validity-period,
      min-score-required: min-score-required,
      issuer-requirements: issuer-requirements
    })

    (ok true)
  )
)

;; Issue certificate
(define-public (issue-certificate
  (employee principal)
  (skill-name (string-ascii 50))
  (certification-level uint)
  (verification-hash (buff 32)))

  (let ((issuer tx-sender)
        (certificate-id (+ (var-get certificate-id-nonce) u1))
        (template (unwrap! (map-get? certificate-templates skill-name) ERR_NOT_FOUND)))

    (asserts! (> certification-level u0) ERR_INVALID_INPUT)
    (asserts! (<= certification-level u5) ERR_INVALID_INPUT)

    ;; Create certificate
    (map-set certificates certificate-id {
      employee: employee,
      issuer: issuer,
      skill-name: skill-name,
      certification-level: certification-level,
      issue-date: block-height,
      expiry-date: (+ block-height (get validity-period template)),
      status: "active",
      verification-hash: verification-hash
    })

    ;; Add to employee's certificate list
    (let ((current-certs (default-to (list) (map-get? employee-certificates employee))))
      (map-set employee-certificates employee
        (unwrap! (as-max-len? (append current-certs certificate-id) u20) ERR_INVALID_INPUT))
    )

    (var-set certificate-id-nonce certificate-id)
    (ok certificate-id)
  )
)

;; Renew certificate
(define-public (renew-certificate (certificate-id uint) (new-verification-hash (buff 32)))
  (let ((certificate (unwrap! (map-get? certificates certificate-id) ERR_NOT_FOUND))
        (issuer tx-sender)
        (template (unwrap! (map-get? certificate-templates (get skill-name certificate)) ERR_NOT_FOUND)))

    (asserts! (is-eq issuer (get issuer certificate)) ERR_UNAUTHORIZED)

    (map-set certificates certificate-id (merge certificate {
      issue-date: block-height,
      expiry-date: (+ block-height (get validity-period template)),
      status: "active",
      verification-hash: new-verification-hash
    }))

    (ok true)
  )
)

;; Revoke certificate
(define-public (revoke-certificate (certificate-id uint))
  (let ((certificate (unwrap! (map-get? certificates certificate-id) ERR_NOT_FOUND))
        (issuer tx-sender))

    (asserts! (is-eq issuer (get issuer certificate)) ERR_UNAUTHORIZED)

    (map-set certificates certificate-id (merge certificate {
      status: "revoked"
    }))

    (ok true)
  )
)

;; Read-only Functions

;; Get certificate details
(define-read-only (get-certificate (certificate-id uint))
  (map-get? certificates certificate-id)
)

;; Get employee certificates
(define-read-only (get-employee-certificates (employee principal))
  (map-get? employee-certificates employee)
)

;; Get certificate template
(define-read-only (get-template (skill-name (string-ascii 50)))
  (map-get? certificate-templates skill-name)
)

;; Verify certificate validity
(define-read-only (is-certificate-valid (certificate-id uint))
  (match (map-get? certificates certificate-id)
    certificate-data
      (and
        (is-eq (get status certificate-data) "active")
        (> (get expiry-date certificate-data) block-height)
      )
    false
  )
)

;; Check if certificate is expired
(define-read-only (is-certificate-expired (certificate-id uint))
  (match (map-get? certificates certificate-id)
    certificate-data (<= (get expiry-date certificate-data) block-height)
    true
  )
)

;; Get current certificate ID
(define-read-only (get-current-certificate-id)
  (var-get certificate-id-nonce)
)
