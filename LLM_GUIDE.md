# LLM Guide

This project (`PriceAdjustPro-iOS`) talks to the web stack that lives in `https://github.com/jerredrogero/PriceAdjustPro.git` (already cloned at `/Users/jerred/Desktop/Code/PriceAdjustPro`). Future LLMs should use this guide to stay oriented and avoid re-discovering the setup every session.

## Key Dependencies

- Backend API: Django app under `/Users/jerred/Desktop/Code/PriceAdjustPro/price_adjust_pro/`.
- Frontend reference: React client under `/Users/jerred/Desktop/Code/PriceAdjustPro/frontend/` (useful for matching UI flows and payloads).
- Shared models/contracts: `price_adjust_pro/receipt_parser/serializers.py`, `price_adjust_pro/receipt_parser/views.py`, and `frontend/src/api/axios.ts` describe the endpoints the iOS app replicates.

## Keeping the Backend Clone Fresh

1. `cd /Users/jerred/Desktop/Code/PriceAdjustPro`
2. `git pull`
3. Run `git status -sb` to make sure only intentional local edits show up.
4. If the iOS project relies on new backend migrations, run `python manage.py migrate` inside `price_adjust_pro/`.

> Tip: if you ever see `fatal: destination path … already exists`, it means this clone is already present—just `git pull` instead of recloning.

## Environment Expectations

- Activate the backend virtual environment before running scripts: `source /Users/jerred/Desktop/Code/PriceAdjustPro/venv/bin/activate`.
- Use `python3`/`pip3` (never the system Python) as noted in `README.md`.
- For Node tasks in the frontend, run them from `/Users/jerred/Desktop/Code/PriceAdjustPro/frontend` using `npm`.

## How the iOS App Interfaces With The Backend

- Authentication: mirrors Django auth endpoints (`/api/auth/login/`, `/api/auth/register/`). Check `AuthenticationService.swift` in iOS alongside backend views for request/response shapes.
- Receipts: `ReceiptStore` calls the same endpoints defined in `receipt_parser/views.py`. Use serializers to confirm field names (`total`, `tax`, `line_items`, etc.).
- Subscriptions & StoreKit: iOS leverages receipts plus premium status flags exposed via backend endpoints described in `SUBSCRIPTION_SETUP.md` (kept in the backend repo).

When debugging, open the backend file next to the Swift file that consumes it to keep context tight.

## Common Workflows

- **Sync both repos**: pull the backend first, then `git pull` inside `PriceAdjustPro-iOS`.
- **Add new API fields**: update Django serializer/view, run migrations if needed, then adjust the Swift models (`ReceiptModels.swift`, `LineItem+Extensions.swift`).
- **Validate JSON changes**: compare against the TypeScript types in `frontend/src/types`. The web client already uses the live contract and serves as a reference implementation.

## Gotchas

- Stale migrations cause 500s in local testing—run `python manage.py migrate` after every backend pull.
- The backend clone contains local documentation files (`EMAIL_*`, `SUBSCRIPTION_SETUP.md`). Don’t delete them unless you mean to; otherwise `git status` will show pending deletions and confuse future LLMs.
- Remember to restart the Django dev server after touching settings or environment variables; it does not hot-reload everything.

Keep this file updated whenever the integration surface changes so future LLMs can jump straight into productive work.

