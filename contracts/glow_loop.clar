;; GlowLoop Contract
;; Manages circular economy marketplace for recycling and upcycling

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u404))
(define-constant err-unauthorized (err u401))
(define-constant err-already-claimed (err u409))

;; Data Variables
(define-data-var next-item-id uint u0)

;; Data Maps
(define-map Items
    uint 
    {
        owner: principal,
        title: (string-ascii 50),
        description: (string-ascii 500),
        category: (string-ascii 20),
        status: (string-ascii 10),
        claimed-by: (optional principal)
    }
)

(define-map UserStats
    principal
    {
        recycling-credits: uint,
        reputation-score: uint,
        items-listed: uint,
        items-claimed: uint
    }
)

;; Private Functions
(define-private (get-or-create-user-stats (user principal))
    (default-to
        {
            recycling-credits: u0,
            reputation-score: u100,
            items-listed: u0,
            items-claimed: u0
        }
        (map-get? UserStats user)
    )
)

;; Public Functions
(define-public (list-item (title (string-ascii 50)) (description (string-ascii 500)) (category (string-ascii 20)))
    (let
        (
            (item-id (var-get next-item-id))
            (user-stats (get-or-create-user-stats tx-sender))
        )
        (try! (map-set Items item-id {
            owner: tx-sender,
            title: title,
            description: description,
            category: category,
            status: "available",
            claimed-by: none
        }))
        (map-set UserStats tx-sender (merge user-stats {
            items-listed: (+ (get items-listed user-stats) u1)
        }))
        (var-set next-item-id (+ item-id u1))
        (ok item-id)
    )
)

(define-public (claim-item (item-id uint))
    (let
        (
            (item (unwrap! (map-get? Items item-id) err-not-found))
            (user-stats (get-or-create-user-stats tx-sender))
        )
        (asserts! (is-eq (get status item) "available") err-already-claimed)
        (try! (map-set Items item-id (merge item {
            status: "claimed",
            claimed-by: (some tx-sender)
        })))
        (map-set UserStats tx-sender (merge user-stats {
            items-claimed: (+ (get items-claimed user-stats) u1)
        }))
        (ok true)
    )
)

(define-public (complete-transaction (item-id uint))
    (let
        (
            (item (unwrap! (map-get? Items item-id) err-not-found))
            (claimer (unwrap! (get claimed-by item) err-not-found))
            (owner-stats (get-or-create-user-stats (get owner item)))
            (claimer-stats (get-or-create-user-stats claimer))
        )
        (asserts! (or (is-eq tx-sender (get owner item)) (is-eq tx-sender claimer)) err-unauthorized)
        (try! (map-set Items item-id (merge item {status: "completed"})))
        ;; Award recycling credits and update reputation
        (map-set UserStats (get owner item) (merge owner-stats {
            recycling-credits: (+ (get recycling-credits owner-stats) u10),
            reputation-score: (+ (get reputation-score owner-stats) u5)
        }))
        (map-set UserStats claimer (merge claimer-stats {
            recycling-credits: (+ (get recycling-credits claimer-stats) u5),
            reputation-score: (+ (get reputation-score claimer-stats) u5)
        }))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-item-details (item-id uint))
    (ok (map-get? Items item-id))
)

(define-read-only (get-user-stats (user principal))
    (ok (get-or-create-user-stats user))
)