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

## Order status seen by the rider app
Rider endpoints return a rider-facing `status` / `order_status`:
`pending` (an unanswered offer) → `accepted` → `in_transit` (cylinder collected) → `delivered`, or `cancelled`.
The raw database value is in `db_status`. `POST /riders/orders/:id/pickup` moves the order to `in_transit`;
`deliver` requires `in_transit`. Accepting does not change the vendor-side status.
Build-time option: `--dart-define=SUPPORT_PHONE=+254...` enables "Call AquaGas support" in the safety sheet.

## Growth endpoints
- `GET /riders/incentives` → `{ data: { deliveries_today, tiers:[{target,bonus,reached}], next:{target,bonus,remaining}|null, bonus_earned_today } }`
- `GET /riders/demand-zones?hours=3` → `{ data: { window_hours, zones:[{latitude,longitude,count,intensity,radius_m}] } }`

## Cashless (M-Pesa) completion of cash orders
For a COD order the rider asks the customer to pay by M-Pesa instead of handing over cash.
The **server** sends the STK push; only a verified SasaPay callback marks the order paid.

| Call | Body | Response |
|---|---|---|
| `POST /riders/orders/:id/mpesa/request` | `{phone?}` (only when the customer authorises another number) | `{reused, mpesa}` |
| `GET /riders/orders/:id/mpesa/status` | — | `{mpesa, order_status, payment_status}` |

`mpesa` = `{state: "none"\|"pending"\|"paid"\|"failed"\|"expired", amount, seconds_left?, receipt?, reason?, phone? (masked), attempts}`.
Errors carry `{error, code}`: `NOT_DISPATCHED`, `ALREADY_PAID`, `NOT_COD`, `BAD_PHONE`, `TOO_MANY`, `DISABLED`, `UNAVAILABLE`, `GATEWAY`.

- Order payloads add `can_request_mpesa`.
- While a request is `pending`, `deliver` returns **409** `code: MPESA_PENDING` (never take cash while a prompt is live).
- A declined/cancelled prompt does not fail the order — retry, or take cash.
- Once `paid`, `deliver` needs no `cash_collected`, and no cash is added to the rider's remit balance.
- Socket: `paymentUpdated {order_id, payment_status:"paid", receipt, amount}` is emitted to `rider_<id>` and `order_<id>`.
- Server flags: `COD_MPESA_ENABLED` (default true), `RIDER_MPESA_TTL_SECONDS` (default 180), `RIDER_MPESA_MAX_ATTEMPTS` (default 5).
