#!/usr/bin/env bash

set -u

BASE_URL="${BASE_URL:-http://127.0.0.1:3000}"
RUN_ID="$(date +%s)-$$"
MONTH="$(date +%Y-%m)"
RESPONSE_BODY=""
RESPONSE_STATUS=""
PASS_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS %02d - %s\n' "$PASS_COUNT" "$1"
}

fail() {
  printf 'FAIL - %s\n' "$1" >&2
  printf 'HTTP status: %s\n' "${RESPONSE_STATUS:-not available}" >&2
  printf 'Response: %s\n' "${RESPONSE_BODY:-not available}" >&2
  exit 1
}

request_api() {
  local method="$1"
  local path="$2"
  local token="${3:-}"
  local body="${4:-}"
  local response_file
  response_file="$(mktemp)"

  local args=(-sS -o "$response_file" -w '%{http_code}' -X "$method" "${BASE_URL}${path}")
  if [[ -n "$token" ]]; then
    args+=(-H "Authorization: Bearer ${token}")
  fi
  if [[ -n "$body" ]]; then
    args+=(-H 'Content-Type: application/json' -d "$body")
  fi

  if ! RESPONSE_STATUS="$(curl "${args[@]}")"; then
    RESPONSE_BODY="$(cat "$response_file" 2>/dev/null || true)"
    rm -f "$response_file"
    fail "${method} ${path} could not connect to ${BASE_URL}"
  fi

  RESPONSE_BODY="$(cat "$response_file")"
  rm -f "$response_file"
}

expect_status() {
  local expected="$1"
  local label="$2"
  if [[ "$RESPONSE_STATUS" != "$expected" ]]; then
    fail "${label}: expected HTTP ${expected}, got ${RESPONSE_STATUS}"
  fi
}

json_value() {
  local expression="$1"
  printf '%s' "$RESPONSE_BODY" | node -e '
    const fs = require("fs");
    const input = fs.readFileSync(0, "utf8");
    let data;
    try { data = JSON.parse(input); } catch { process.exit(2); }
    const value = Function("data", `return (${process.argv[1]})`)(data);
    if (value === undefined || value === null || value === false) process.exit(3);
    process.stdout.write(typeof value === "string" ? value : JSON.stringify(value));
  ' "$expression"
}

expect_json() {
  local expression="$1"
  local label="$2"
  if ! json_value "$expression" >/dev/null; then
    fail "${label}: JSON assertion failed (${expression})"
  fi
}

printf 'MVP smoke test\nBase URL: %s\nRun ID: %s\n\n' "$BASE_URL" "$RUN_ID"

request_api POST /auth/mock-login "" "{\"phoneNumber\":\"smoke-a-${RUN_ID}\"}"
expect_status 201 "User A login"
TOKEN_A="$(json_value 'data.accessToken')" || fail "User A login: accessToken missing"
pass "User A development phone login"

request_api POST /families "$TOKEN_A" "{\"name\":\"Smoke Family ${RUN_ID}\",\"requirePhotoProof\":false,\"identityLabel\":\"男主人\",\"avatarKey\":\"avatar_01\"}"
expect_status 201 "Create family"
FAMILY_ID="$(json_value 'data.id')" || fail "Create family: id missing"
INVITE_CODE="$(json_value 'data.inviteCode')" || fail "Create family: inviteCode missing"
expect_json 'data.myMembership.memberRole === "OWNER" && data.myMembership.status === "ACTIVE"' "Create family owner state"
pass "User A creates family and receives inviteCode ${INVITE_CODE}"

request_api POST /auth/mock-login "" "{\"phoneNumber\":\"smoke-b-${RUN_ID}\"}"
expect_status 201 "User B login"
TOKEN_B="$(json_value 'data.accessToken')" || fail "User B login: accessToken missing"
USER_B_ID="$(json_value 'data.user.id')" || fail "User B login: user id missing"
pass "User B development phone login"

request_api POST /families/join-requests "$TOKEN_B" "{\"inviteCode\":\"${INVITE_CODE}\",\"identityLabel\":\"室友\",\"avatarKey\":\"avatar_02\"}"
expect_status 201 "User B join request"
MEMBER_ID="$(json_value 'data.id')" || fail "User B join request: member id missing"
expect_json 'data.status === "PENDING" && data.memberRole === "MEMBER"' "User B pending membership"
pass "User B applies with inviteCode"

request_api PATCH "/families/${FAMILY_ID}/join-requests/${MEMBER_ID}" "$TOKEN_A" '{"action":"approve"}'
expect_status 200 "Approve User B"
expect_json 'data.status === "ACTIVE"' "Approve User B"
pass "User A approves User B"

request_api GET /families/me "$TOKEN_B"
expect_status 200 "User B families"
expect_json "Array.isArray(data) && data.some(family => family.id === \"${FAMILY_ID}\" && family.status === \"ACTIVE\")" "User B active family"
pass "User B fetches active family list"

request_api GET /chores
expect_status 200 "Fetch chores"
CHORE_ID="$(json_value 'data.find(chore => !chore.isLocked)?.id')" || fail "Fetch chores: no unlocked chore"
pass "User B fetches chores"

request_api POST /chore-records "$TOKEN_B" "{\"familyId\":\"${FAMILY_ID}\",\"choreId\":\"${CHORE_ID}\",\"actualMinutes\":20,\"note\":\"MVP smoke ${RUN_ID}\"}"
expect_status 201 "Create chore record"
RECORD_ID="$(json_value 'data.recordId || data.id')" || fail "Create chore record: record id missing"
expect_json 'data.actualMinutes === 20 && Number.isInteger(data.points)' "Create chore record actualMinutes"
pass "User B creates record with actualMinutes"

request_api GET "/families/${FAMILY_ID}/activity?range=day" "$TOKEN_B"
expect_status 200 "Day activity"
expect_json "Array.isArray(data) && data.some(record => record.recordId === \"${RECORD_ID}\")" "Day activity record"
pass "Day activity contains the new record"

request_api GET "/families/${FAMILY_ID}/activity?range=recent" "$TOKEN_B"
expect_status 200 "Recent activity"
expect_json "Array.isArray(data) && data.some(record => record.recordId === \"${RECORD_ID}\")" "Recent activity record"
pass "Recent activity contains the new record"

request_api POST "/chore-records/${RECORD_ID}/like" "$TOKEN_A"
expect_status 201 "Like record"
expect_json 'data.likeCount === 1 && data.likedByMe === true' "Like state"
pass "User A likes User B record"

request_api POST "/chore-records/${RECORD_ID}/like" "$TOKEN_A"
expect_status 201 "Repeat like"
expect_json 'data.likeCount === 1 && data.likedByMe === true' "Repeat like state"
pass "Repeated like is idempotent"

request_api DELETE "/chore-records/${RECORD_ID}/like" "$TOKEN_A"
expect_status 200 "Unlike record"
expect_json 'data.likeCount === 0 && data.likedByMe === false' "Unlike state"
pass "User A unlikes record"

request_api DELETE "/chore-records/${RECORD_ID}/like" "$TOKEN_A"
expect_status 200 "Repeat unlike"
expect_json 'data.likeCount === 0 && data.likedByMe === false' "Repeat unlike state"
pass "Repeated unlike is idempotent"

request_api DELETE "/chore-records/${RECORD_ID}" "$TOKEN_B"
expect_status 200 "Delete record"
expect_json "data.recordId === \"${RECORD_ID}\" && Boolean(data.deletedAt)" "Soft-delete response"
pass "User B soft-deletes own record"

request_api GET "/families/${FAMILY_ID}/activity?range=day" "$TOKEN_A"
expect_status 200 "Day activity after delete"
expect_json "Array.isArray(data) && !data.some(record => record.recordId === \"${RECORD_ID}\")" "Deleted day activity"
pass "Deleted record is absent from day activity"

request_api GET "/families/${FAMILY_ID}/activity?range=recent" "$TOKEN_A"
expect_status 200 "Recent activity after delete"
expect_json "Array.isArray(data) && !data.some(record => record.recordId === \"${RECORD_ID}\")" "Deleted recent activity"
pass "Deleted record is absent from recent activity"

request_api GET "/families/${FAMILY_ID}/leaderboard?range=month" "$TOKEN_A"
expect_status 200 "Leaderboard after delete"
expect_json "Array.isArray(data) && !data.some(item => item.userId === \"${USER_B_ID}\" && item.recordCount > 0)" "Deleted leaderboard record"
pass "Deleted record is absent from leaderboard"

request_api GET "/families/${FAMILY_ID}/monthly-report?month=${MONTH}" "$TOKEN_A"
expect_status 200 "Monthly report after delete"
expect_json 'data.totalRecords === 0 && data.totalPoints === 0' "Deleted monthly report record"
pass "Deleted record is absent from monthly report"

printf '\nPASS - MVP smoke test completed (%d checks).\n' "$PASS_COUNT"
