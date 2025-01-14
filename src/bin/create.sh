#!/bin/bash
set -e

. NIXUNITS/bin/common.sh

usage() {
  echo "Usage : nixunits create <container id> [options]"
  echo "Available options:"
  echo "  -a  <json list> capabilities allowed"
  echo "  -cc <service config content>"
  echo "  -cf <service file>"
  echo "  -cn <service name>"
  echo "  -i  <interface>"
  echo "  -4  <IPv4>"
  echo "  -H4 <host IPv4>"
  echo "  -R4 <IPv4 route>"
  echo "  -6  [IPv6] "
  echo "  -H6 <host IPv6>"
  echo "  -R6 <IPv6 route>"
  echo "  -f  force ?"
  echo "  -h, --help"
  echo "  -r  restart ?"
  echo "  -s  start ?"
  echo
  echo "Examples:"
  echo " nixunits create my_wordpress -cn wordpress  -6 '2001:bc8:a:b:c:d:e:1/64' -i link1 -R6 'fe80::1'"
  echo " nixunits create my_pg        -cn postgresql -6 'fc00::a:2' -H6 'fc00::a:1'"
  echo " nixunits create my_mariadb   -cn mysql      -4 192.168.1.1 -R4 192.168.1.254"
  echo
  echo "Auto generated IPv6, from name (private network only):"
  echo " nixunits create my_nc -cn nextcloud -6"

  test -n "$1" && exit "$1"
  exit 0
}

id=$1
test -z "$id" && usage 1
shift

FORCE=false
START=false
RESTART=false

# shellcheck disable=SC2213
while getopts "4:6a:c:f:i:n:H:R:hsr" opt; do
  case $opt in
    4) ip4=$OPTARG;;
    6)
      # shellcheck disable=SC2124
      next_arg="${@:$OPTIND:1}"
      if [[ -n $next_arg && $next_arg != -* ]] ; then
        ip6=$next_arg
        OPTIND=$((OPTIND + 1))
      else
        ip6=$(ip6_crc32 "$id")
        hostIp6=$(ip6_crc32_host "$id")
      fi;;
    a) CAPS=$OPTARG;;
    c)
      case $OPTARG in
        c) serviceContent="${!OPTIND}"; OPTIND=$((OPTIND + 1));;
        f) serviceFile="${!OPTIND}"; OPTIND=$((OPTIND + 1));;
        n) serviceName="${!OPTIND}"; OPTIND=$((OPTIND + 1));;
        *) echo "Invalid option for -s. Use c, f or n."; usage 1;;
      esac
      ;;
    i) interface=$OPTARG;;
    r) RESTART=true;;
    s) START=true;;
    H)
      case $OPTARG in
        4) hostIp4="${!OPTIND}"; OPTIND=$((OPTIND + 1));;
        6) hostIp6="${!OPTIND}"; OPTIND=$((OPTIND + 1));;
        *) echo "Invalid option for -H. Use 4 or 6."; usage 1;;
      esac
      ;;
    R)
      case $OPTARG in
        4) ip4route="${!OPTIND}"; OPTIND=$((OPTIND + 1));;
        6) ip6route="${!OPTIND}"; OPTIND=$((OPTIND + 1));;
        *) echo "Invalid option for -R. Use 4 or 6."; usage 1;;
      esac
      ;;
    f) FORCE=true;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option : -$OPTARG" >&2
      usage 1
      ;;
  esac
done

test "$FORCE" != "true" && in_nixos_failed "$id"

OUT_VAR=$(out_var "$id")

test ! -d "$OUT_VAR" && install -m 2750 -d "$OUT_VAR"
test -d "$OUT_VAR/root" || install -g root -d "$OUT_VAR/root"
chmod g-s "$OUT_VAR/root"

_args="--argstr id $id"
if [ -n "$serviceFile" ] || [ -n "$serviceContent" ]
then
  if [ -n "$serviceFile" ]
  then
    install "$serviceFile" "$OUT_VAR/unit.nix"
  else
    echo "$serviceContent" > "$OUT_VAR/unit.nix"
  fi
else
  test -z "$serviceName" && usage 1
  _args+=" --argstr service $serviceName"
fi

[ -n "$CAPS" ]      && _args+=" --argstr caps $CAPS"
[ -n "$hostIp4" ]   && _args+=" --argstr hostIp4 $hostIp4"
[ -n "$hostIp6" ]   && _args+=" --argstr hostIp6 $hostIp6"
[ -n "$interface" ] && _args+=" --argstr interface $interface"
[ -n "$ip4" ]       && _args+=" --argstr ip4 $ip4"
[ -n "$ip6" ]       && _args+=" --argstr ip6 $ip6"
[ -n "$ip4route" ]  && _args+=" --argstr ip4route $ip4route"
[ -n "$ip6route" ]  && _args+=" --argstr ip6route $ip6route"

_args+=" --out-link $OUT_VAR/result"

echo "Container : $id"
test -n "$interface" && echo "  interface: $interface"
test -n "$ip4"       && echo "  ip4: $ip4"
test -n "$ip4route"  && echo "  ip4route: $ip4route"
test -n "$hostIp4"   && echo "  hostIp4: $hostIp4"
test -n "$ip6"       && echo "  ip6: $ip6"
test -n "$hostIp6"   && echo "  hostIp6: $hostIp6"
test -n "$ip6route"  && echo "  ip6route: $ip6route"
echo

echo "nix-build NIXUNITS/default.nix $_args"
# shellcheck disable=SC2086
nix-build NIXUNITS/default.nix $_args

_link="$OUT_VAR/unit.conf"
test -L "$_link" || ln -s "$OUT_VAR/result/etc/nixunits/$id.conf" "$_link"

_unit="nixunits@$id"
STARTED=$(systemctl -o json show "$_unit" --no-pager |grep ^SubState=running >/dev/null && echo true || echo false)
if $START && ! $STARTED || $RESTART
then
  echo "systemctl restart $_unit"
  systemctl restart "$_unit"
  systemctl status  "$_unit" --no-pager
fi