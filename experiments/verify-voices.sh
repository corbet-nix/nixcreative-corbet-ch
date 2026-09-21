#!/usr/bin/env bash
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# Re-verify the voice catalogue against the sources it claims to have been read from.
#
# WHAT THIS IS FOR. `lib/voices.nix` is a table of facts about somebody else's artifacts, and the
# failure mode it is exposed to is not a typo -- `checks/voices-eval.nix` catches those -- but the
# world moving underneath it. A repository is renamed and the old id redirects; a licence tag is
# corrected; a gate is added or lifted. None of that changes this repository, so none of it fails a
# check, and the entry quietly stops being true. This script is how you find out.
#
# WHAT IT DOES NOT DO: download weights. Every request is a metadata request -- the model API and
# the repository API -- and the whole point of the catalogue is that this repository says WHICH
# model a workload serves and never where a weight file lives.
#
# IT READS THE CATALOGUE THROUGH NIX rather than parsing it, so it cannot drift from what the flake
# actually exports.
#
#   ./experiments/verify-voices.sh              # every catalogued model
#   ./experiments/verify-voices.sh kokoro-82m   # one of them
#
# EXIT STATUS is the finding: 0 when every catalogued fact still matches its source, 1 when
# anything disagrees. A disagreement is not automatically an error in this repository -- upstream
# may simply have changed -- so it prints what it saw rather than what it expected you to do.
#
# UNAUTHENTICATED, on purpose: everything it reads is public, and a script that needed a credential
# would be one nobody could run. The GitHub API allows 60 unauthenticated requests an hour, which is
# more than this needs and less than you get by running it in a loop.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
only=${1:-}

command -v jq >/dev/null || { echo "needs jq" >&2; exit 2; }
command -v nix >/dev/null || { echo "needs nix" >&2; exit 2; }

catalogue=$(nix eval --json "$root#lib.voices") || exit 2

fail=0
throttled=0
note() { printf '  %-12s %s\n' "$1" "$2"; }

for key in $(jq -r 'keys[]' <<<"$catalogue"); do
  [ -n "$only" ] && [ "$only" != "$key" ] && continue
  entry=$(jq -r --arg k "$key" '.[$k]' <<<"$catalogue")
  repo=$(jq -r '.hfRepo' <<<"$entry")
  spdx=$(jq -r '.licence.spdx // ""' <<<"$entry")
  gated=$(jq -r '.gated' <<<"$entry")
  upstream=$(jq -r '.upstream' <<<"$entry")

  echo "== $key ($repo)"

  body=$(curl -sS -m 30 -w '\n%{http_code}' "https://huggingface.co/api/models/$repo")
  code=$(tail -n1 <<<"$body")
  body=$(sed '$d' <<<"$body")

  case "$code" in
    200)
      # THE CANONICAL ID, which is the fact a rename breaks. The API answers a redirected lookup
      # with the id it redirected TO, so an entry can keep resolving long after its id stopped
      # being the one anybody should write down.
      id=$(jq -r '.id // ""' <<<"$body")
      [ "$id" = "$repo" ] || { note "ID MOVED" "catalogued $repo, API answers $id"; fail=1; }
      lic=$(jq -r '.cardData.license // ""' <<<"$body")
      note "licence tag" "${lic:-<none>}"
      if [ -n "$spdx" ] && [ -n "$lic" ]; then
        # Only compared where the catalogue claims a single standard licence. A two-instrument
        # stack has no `spdx`, precisely because no tag can carry it.
        [ "${lic,,}" = "${spdx,,}" ] || { note "LICENCE MOVED" "catalogued $spdx, API tag $lic"; fail=1; }
      fi

      # THE GATE IS TWO DIFFERENT FACTS AND THEY DISAGREE IN PRACTICE, which is why this reads the
      # card rather than the flag. What the catalogue records is whether the WEIGHTS ARE PUBLISHED
      # BEHIND TERMS YOU MUST ACCEPT -- an agreement the publisher wrote, visible as the card's
      # declared gate fields. Whether the hub is currently ENFORCING that agreement is a separate,
      # movable thing: the API's own `gated` flag can read false while the card declares the
      # agreement, and an anonymous file request can then be answered rather than refused. Both are
      # reported, and only the first one is compared.
      declared=$(jq -r 'if ((.cardData.extra_gated_fields // .cardData.extra_gated_prompt) != null) then "true" else "false" end' <<<"$body")
      enforced=$(jq -r 'if (.gated == false or .gated == null) then "false" else "true" end' <<<"$body")
      note "gate" "declared on the card=$declared, enforced by the hub=$enforced"
      [ "$declared" = "$gated" ] || { note "GATE MOVED" "catalogued gated=$gated, card declares $declared"; fail=1; }

      # And what an unattended fetcher would actually get: 401 is a wall, a redirect to the CDN is
      # not. The file is taken from the repository's own listing rather than guessed -- probing a
      # name like `config.json` answers 404 on any repository that does not happen to have one,
      # which reads as a refusal and is nothing of the kind.
      file=$(jq -r '[.siblings[]?.rfilename] | map(select(. != ".gitattributes")) | first // ""' <<<"$body")
      if [ -n "$file" ]; then
        anon=$(curl -sS -m 20 -o /dev/null -w '%{http_code}' -I "https://huggingface.co/$repo/resolve/main/$file")
        note "anonymous fetch" "HTTP $anon for $file"
      else
        note "anonymous fetch" "no file listed to probe"
      fi
      ;;
    401|403)
      # A gated repository answers 401 to an anonymous request, which is a FINDING and not an
      # error: it is the same thing an unattended fetcher would hit.
      if [ "$gated" = "true" ]; then
        note "gated" "HTTP $code anonymously, as catalogued"
      else
        note "GATE APPEARED" "HTTP $code anonymously, catalogued as ungated"; fail=1
      fi
      ;;
    *)
      note "UNREACHABLE" "HTTP $code"; fail=1
      ;;
  esac

  # The code, separately from the weights: an upstream that stopped moving is the other way a
  # catalogued model quietly stops being a candidate.
  slug=${upstream#https://github.com/}
  if [ "$slug" != "$upstream" ]; then
    gh=$(curl -sS -m 30 "https://api.github.com/repos/$slug")
    if jq -e 'has("pushed_at")' >/dev/null 2>&1 <<<"$gh"; then
      note "upstream" "pushed $(jq -r '.pushed_at' <<<"$gh"), archived=$(jq -r '.archived' <<<"$gh")"
    else
      msg=$(jq -r '.message // "unknown"' <<<"$gh")
      case "$msg" in
        *"rate limit"*|*"Rate limit"*)
          # THROTTLED IS NOT AN OBSERVATION, and printing it like one is how this script would come
          # to report nothing while looking like it reported something. The unauthenticated GitHub
          # quota is 60/hour and this loop spends one request per model, so a second run inside the
          # hour silently degrades EVERY upstream line to a shrug. Counted as a failure of the run,
          # not of the catalogue -- the distinction is in the wording and in the summary below.
          note "upstream" "NOT CHECKED (GitHub rate limit) -- this run establishes nothing about upstreams"
          throttled=1
          ;;
        *)
          note "UPSTREAM UNREADABLE" "$msg"; fail=1
          ;;
      esac
    fi
  fi
done

if [ "$fail" -ne 0 ]; then
  echo
  echo "at least one catalogued fact no longer matches its source -- read the lines in capitals" >&2
  exit 1
fi

# A CLEAN RUN THAT CHECKED NOTHING IS NOT A CLEAN RUN. Exit 3 rather than 0, so a caller -- a human
# reading the last line, or anything that ever wires this into CI -- cannot mistake "nothing
# disagreed" for "everything was compared". Distinct from 1 (a fact moved) and 2 (the tool could not
# start), because the remedy is different: wait an hour, or set GH_TOKEN.
if [ "$throttled" -ne 0 ]; then
  echo
  echo "the weights all matched, but GitHub throttled this run: NO upstream was checked." >&2
  echo "re-run in an hour, or with a token, before treating the upstream half as verified." >&2
  exit 3
fi
echo
echo "every catalogued model still matches the source it was read from"
