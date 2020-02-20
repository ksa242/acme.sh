#!/usr/bin/env sh
# vim:tw=78:ts=2:sw=2:et:
#
# Author: ksa242@gmail.com
# November 10, 2020
# Report bugs at https://github.com/ksa242/acme.sh
#
# Values to export:
# export DNSMGR_URL="https://hosting.example:1500/dnsmgr"
# export DNSMGR_AUTHINFO="username:password"

# Adds a TXT record.
# Usage: dns_dnsmgr_add '_acme-challenge.www.domain.com' 'XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs'
dns_dnsmgr_add () {
  txtdomain="$1"
  txtvalue="$2"
  _debug "Calling: dns_dnsmgr_add '$txtdomain' '$txtvalue'"

  _dns_dnsmgr_url || return 1
  _dns_dnsmgr_authinfo || return 1

  _dns_dnsmgr_get_domain "$txtdomain" || return 1
  _debug "Found suitable domain: $dnsmgr_domain"

  url="$DNSMGR_URL"
  data="authinfo=${DNSMGR_AUTHINFO}&out=JSONdata&func=domain.record.edit&sok=ok&plid=${dnsmgr_domain}&name=${txtdomain}.&rtype=txt&ttl=360&value=${txtvalue}"
  res="$(_post "$data" "$url" | _normalizeJson)"
  _debug2 "Result: $res"

  printf '%s' "$res" | grep '"ok":""' >/dev/null || return 1
}

# Removes the TXT record.
# Usage: dns_dnsmgr_rm '_acme-challenge.www.domain.com' 'XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs'
dns_dnsmgr_rm () {
  txtdomain="$1"
  txtvalue="$2"
  _debug "Calling: dns_dnsmgr_rm '$txtdomain' '$txtvalue'"

  _dns_dnsmgr_url || return 1
  _dns_dnsmgr_authinfo || return 1

  _dns_dnsmgr_get_domain "$txtdomain" || return 1
  _debug "Found suitable domain: $dnsmgr_domain"

  url="$DNSMGR_URL"
  data="authinfo=${DNSMGR_AUTHINFO}&out=JSONdata&func=domain.record&elid=${dnsmgr_domain}"
  res="$(_get "${url}?${data}" | _normalizeJson)"
  _debug2 "Result: $res"

  rkey="$(printf '%s' "$res" | _egrep_o '"rkey":"'"$txtdomain"'[^"]+'"$txtvalue"'"' | cut -d: -f2 | sed -e 's/"//g')"
  _debug "Record to remove: '$rkey'"

  url="$DNSMGR_URL"
  data="authinfo=${DNSMGR_AUTHINFO}&out=JSONdata&func=domain.record.delete&plid=${dnsmgr_domain}&elid=$(printf '%s' "$rkey" | _url_encode)"
  res="$(_post "$data" "$url")"
  _debug2 "Result: $res"

  printf '%s' "$res" | grep '"ok":""' >/dev/null || return 1
}

_dns_dnsmgr_url () {
  DNSMGR_URL="${DNSMGR_URL:-$(_readaccountconf_mutable DNSMGR_URL)}"
  if [ -z "$DNSMGR_URL" ]; then
    DNSMGR_URL=""
    _err "You have to specify the DNSManager control panel URL:"
    _err "export DNSMGR_URL='https://hosting.example:1500/dnsmgr'"
    return 1
  fi
  _saveaccountconf_mutable DNSMGR_URL "$DNSMGR_URL"
}

_dns_dnsmgr_authinfo () {
  DNSMGR_AUTHINFO="${DNSMGR_AUTHINFO:-$(_readaccountconf_mutable DNSMGR_AUTHINFO)}"
  if [ -z "$DNSMGR_AUTHINFO" ]; then
    DNSMGR_AUTHINFO=""
    _err "You have to specify the DNSManager control panel username and password:"
    _err "export DNSMGR_AUTHINFO='username:password'"
    return 1
  fi
  _saveaccountconf_mutable DNSMGR_AUTHINFO "$DNSMGR_AUTHINFO"
}

_dns_dnsmgr_get_domain () {
  txtdomain="$1"

  url="$DNSMGR_URL"
  data="authinfo=${DNSMGR_AUTHINFO}&out=JSONdata&func=domain"
  res="$(_get "${url}?${data}" | _normalizeJson)"
  _debug2 "Result: $res"

  domains="$(printf '%s' "$res" | _egrep_o '"name":"[^"]+"' | cut -d: -f2 | sed -e 's/"//g')"
  _debug2 "Domains: $domains"

  dnsmgr_domain=''
  n=2
  while [ $n -lt 10 ]; do
    elid="$(printf '%s' "$txtdomain" | cut -d . -f $n-100)"
    _debug "Finding zone for domain $elid"
    for d in $domains; do
      if [ "$d" = "$elid" ]; then
        dnsmgr_domain="$elid"
        return 0
      fi
    done
    n=$(_math $n + 1)
  done

  _err 'No suitable domain found in your account'
  return 1
}
