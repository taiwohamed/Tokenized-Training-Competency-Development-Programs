;; Development Planning Contract v1
;; Creates and manages competency development plans

;; Constants
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_PLAN_EXISTS (err u302))
(define-constant ERR_INVALID_INPUT (err u303))

;; Data Variables
(define-data-var plan-id-nonce uint u0)

;; Data Maps
(define-map development-plans
  uint
  {
    employee: principal,
    coordinator: principal,
    title: (string-ascii 100),
    target-skills: (list 10 (string-ascii 50)),
    current-level: uint,
    target-level: uint,
    duration-weeks: uint,
    status: (string-ascii 20),
    created-at: uint,
    updated-at: uint
  }
)

(define-map plan-milestones
  {plan-id: uint, milestone-id: uint}
  {
    description: (string-ascii 200),
    target-date: uint,
    completed: bool,
    completed-at: (optional uint)
  }
)

(define-map employee-active-plans
  principal
  (list 5 uint)
)

;; Public Functions

;; Create a development plan
(define-public (create-plan
  (employee principal)
  (title (string-ascii 100))
  (target-skills (list 10 (string-ascii 50)))
  (current-level uint)
  (target-level uint)
  (duration-weeks uint))

  (let ((coordinator tx-sender)
        (plan-id (+ (var-get plan-id-nonce) u1)))

    (asserts! (> target-level current-level) ERR_INVALID_INPUT)
    (asserts! (> duration-weeks u0) ERR_INVALID_INPUT)
    (asserts! (> (len target-skills) u0) ERR_INVALID_INPUT)

    (map-set development-plans plan-id {
      employee: employee,
      coordinator: coordinator,
      title: title,
      target-skills: target-skills,
      current-level: current-level,
      target-level: target-level,
      duration-weeks: duration-weeks,
      status: "active",
      created-at: block-height,
      updated-at: block-height
    })

    ;; Add to employee's active plans
    (let ((current-plans (default-to (list) (map-get? employee-active-plans employee))))
      (map-set employee-active-plans employee (unwrap! (as-max-len? (append current-plans plan-id) u5) ERR_INVALID_INPUT))
    )

    (var-set plan-id-nonce plan-id)
    (ok plan-id)
  )
)

;; Add milestone to plan
(define-public (add-milestone (plan-id uint) (milestone-id uint) (description (string-ascii 200)) (target-date uint))
  (let ((plan (unwrap! (map-get? development-plans plan-id) ERR_NOT_FOUND))
        (coordinator tx-sender))

    (asserts! (is-eq coordinator (get coordinator plan)) ERR_UNAUTHORIZED)

    (map-set plan-milestones {plan-id: plan-id, milestone-id: milestone-id} {
      description: description,
      target-date: target-date,
      completed: false,
      completed-at: none
    })

    (ok true)
  )
)

;; Complete milestone
(define-public (complete-milestone (plan-id uint) (milestone-id uint))
  (let ((milestone-key {plan-id: plan-id, milestone-id: milestone-id})
        (milestone (unwrap! (map-get? plan-milestones milestone-key) ERR_NOT_FOUND))
        (plan (unwrap! (map-get? development-plans plan-id) ERR_NOT_FOUND)))

    (asserts! (or
      (is-eq tx-sender (get coordinator plan))
      (is-eq tx-sender (get employee plan))
    ) ERR_UNAUTHORIZED)

    (map-set plan-milestones milestone-key (merge milestone {
      completed: true,
      completed-at: (some block-height)
    }))

    (ok true)
  )
)

;; Update plan status
(define-public (update-plan-status (plan-id uint) (new-status (string-ascii 20)))
  (let ((plan (unwrap! (map-get? development-plans plan-id) ERR_NOT_FOUND))
        (coordinator tx-sender))

    (asserts! (is-eq coordinator (get coordinator plan)) ERR_UNAUTHORIZED)

    (map-set development-plans plan-id (merge plan {
      status: new-status,
      updated-at: block-height
    }))

    (ok true)
  )
)

;; Read-only Functions

;; Get development plan
(define-read-only (get-plan (plan-id uint))
  (map-get? development-plans plan-id)
)

;; Get milestone
(define-read-only (get-milestone (plan-id uint) (milestone-id uint))
  (map-get? plan-milestones {plan-id: plan-id, milestone-id: milestone-id})
)

;; Get employee's active plans
(define-read-only (get-employee-plans (employee principal))
  (map-get? employee-active-plans employee)
)

;; Get current plan ID
(define-read-only (get-current-plan-id)
  (var-get plan-id-nonce)
)
