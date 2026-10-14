# Rider app ↔ backend contract

Endpoints the rider app calls. **Existing** ones were already used before this
change; **New / extended** ones need backend work before the matching screen
works end to end. Everything is under `/api/v1`, JWT bearer auth.

## Offers and orders (existing)

| Call | Used for |
|---|---|
| `POST /riders/orders/:id/accept` · `POST /riders/orders/:id/decline` | Offer sheet |
| `POST /riders/orders/:id/pickup` | Confirm pickup (dispatched → ready) |
| `PATCH /riders/orders/:id/deliver` | Complete delivery (see below) |
| Socket `newOrder`, `orderCancelled`, `orderUpdated` | Live offers |

### Optional order fields the app now reads
Absent fields degrade gracefully (the matching UI is simply hidden).

| Field(s) | Effect |
|---|---|
| `offer_expires_at` (ISO time) | Offer countdown (clamped to 8–45 s; default 20 s) |
| `rider_earning` / `rider_fee` | Shown as **You earn**. Without it the sheet says **Order total** |
| `payment_method` (`cod`/`cash`/`mpesa`…) + `payment_status` | Unpaid cash ⇒ COD: cash field on delivery |
| `amount_due` / `cod_amount` | Cash to collect (defaults to `grand_total`) |
| `delivery_otp_required` (bool) | Customer code becomes mandatory |
| `pickup_latitude`, `pickup_longitude`, `pickup_address`, `vendor_name` — or nested `outlet {name, latitude, longitude, address}` | Pickup leg of navigation |

## Proof of delivery — **extended** `PATCH /riders/orders/:id/deliver`

Sent as `multipart/form-data` when a photo is attached, JSON otherwise.

| Field | Type | Notes |
|---|---|---|
| `otp` | string, 4–6 digits | **Verify server-side** against the code issued to the customer; reject with 4xx if wrong |
| `proof_photo` | file (JPEG, ≤1280 px) | Needs an upload middleware (e.g. multer) on this route |
| `empty_cylinders_collected` | int | Cylinder swap count |
| `cash_collected` | number | COD only. Record it as a cash collection (see below) |
| `note` | string | |
| `latitude`, `longitude`, `distance_from_dropoff_m` | number | Rider position when confirming |

The client enforces "code or photo", "code required if `delivery_otp_required`"
and "cash must match amount due or carry a note". **The server must enforce
the same rules** — the app is not a security boundary.
The customer-side code (generation + display in the customer app) is not part
of this repo.

## Location — `POST /riders/location` (used, backend support unconfirmed)
`{latitude, longitude, lat, lng, heading, speed, accuracy, order_id?, recorded_at}`
about every 30 s while online, in addition to the `locationUpdate` socket event.
After 3 consecutive failures the app pauses these posts for 10 minutes.

## Cash on delivery and payouts — **new**

| Call | Request | Response |
|---|---|---|
| `GET /riders/cash` | — | `{cash_in_hand, cash_limit, collected_today, remitted_today, instructions?, collections: [{order_id, order_number, amount, collected_at, status: "unremitted"\|"remitted"}]}` |
| `POST /riders/cash/remit` | `{amount, mpesa_code}` | 2xx. Finance matches the M-Pesa code to the paybill/till payment |
| `GET /riders/payouts` | — | `{payouts: [{id, amount, status: "pending"\|"processing"\|"paid"\|"failed", reference?, created_at}]}` |
| `POST /riders/payouts/request` | `{amount}` | 2xx. Pays out to the rider's M-Pesa (B2C) |

`GET /riders/cash` returning 404/501 shows "Cash tracking is not available".
`instructions` is free text ("Paybill 123456, account = your rider ID").
`GET /riders/earnings/summary` must provide `pendingPayout` — it is the
"available to withdraw" figure.
