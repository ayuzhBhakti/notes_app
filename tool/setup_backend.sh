#!/usr/bin/env bash
# Sets up the Evos Supabase project from the files in supabase/.
#
#   ./tool/setup_backend.sh deploy    # tables, policies and the four functions
#   ./tool/setup_backend.sh secrets   # optional: push supabase/functions/.env
#   ./tool/setup_backend.sh check     # what the project has, read-only
#
# Every step except `check` changes the live project. Run it yourself, after
# `supabase login`. Steps and the dashboard clicks in between are in
# docs/09-deep-link-onboarding.md.
set -euo pipefail

REF="sqvlgiqypqvjykczuhgz"
URL="https://$REF.supabase.co"
KEY="sb_publishable_fwrQXYrua2ld2NOijHgdsg_MYdJ4Ieb"
ENV_FILE="supabase/functions/.env"

cd "$(dirname "$0")/.."

SUPABASE="$(command -v supabase || true)"
[[ -z "$SUPABASE" && -x "$HOME/.local/bin/supabase" ]] && SUPABASE="$HOME/.local/bin/supabase"
if [[ -z "$SUPABASE" ]]; then
  echo "The Supabase CLI is not installed. See https://supabase.com/docs/guides/cli." >&2
  exit 1
fi

case "${1:-}" in
  deploy)
    # Asks for the database password the first time (Project Settings -> Database).
    "$SUPABASE" link --project-ref "$REF"
    "$SUPABASE" db push
    for fn in sms-hook create-cashfree-subscription verify-cashfree-subscription cashfree-webhook; do
      "$SUPABASE" functions deploy "$fn" --project-ref "$REF" --use-api
    done
    echo
    echo "Deployed. Next, in the dashboard:"
    echo "  1. Authentication -> Hooks -> Send SMS hook -> HTTPS:"
    echo "       $URL/functions/v1/sms-hook"
    echo "     Save, and copy the secret it shows."
    echo "  2. Authentication -> Sign In / Providers -> Phone -> enable."
    echo "  3. Table Editor -> app_config, fill these four rows:"
    echo "       fast2sms, fast2sms_dlt_sender_id, fast2sms_dlt_te_id  (same values as CashAlert)"
    echo "       send_sms_hook_secret                                  (the secret from step 1)"
    ;;

  secrets)
    if [[ ! -f "$ENV_FILE" ]]; then
      echo "$ENV_FILE is missing. Copy supabase/functions/.env.example to it." >&2
      exit 1
    fi
    # Not needed when the app_config rows are filled, which is the usual way.
    "$SUPABASE" secrets set --env-file "$ENV_FILE" --project-ref "$REF"
    ;;

  check)
    echo "Phone sign-in enabled: $(curl -s -m 20 "$URL/auth/v1/settings" -H "apikey: $KEY" \
      | python3 -c 'import sys,json; print(json.load(sys.stdin).get("external",{}).get("phone"))')"
    for table in app_config profiles; do
      echo "Table $table: HTTP $(curl -s -m 20 -o /dev/null -w '%{http_code}' \
        "$URL/rest/v1/$table?select=*&limit=1" -H "apikey: $KEY" -H "Authorization: Bearer $KEY")"
    done
    for fn in sms-hook create-cashfree-subscription verify-cashfree-subscription cashfree-webhook; do
      echo "Function $fn: HTTP $(curl -s -m 20 -o /dev/null -w '%{http_code}' -X OPTIONS \
        "$URL/functions/v1/$fn" -H "apikey: $KEY")"
    done
    echo "(Tables: 200 exists, 404 missing. Functions: 404 missing, anything else deployed.)"
    ;;

  *)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
