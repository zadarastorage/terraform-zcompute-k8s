#!/bin/bash
set -e
V="${module_version}";R="${cluster_role}"
U="https://raw.githubusercontent.com/${github_org}/${github_repo}/$V/scripts"
D=/opt/bootstrap;L=/var/log/bootstrap;mkdir -p $D $L
log(){ echo "[$(date +%s)] $*">>$L/boot.log; }
fail(){ echo "$*">>/var/log/bootstrap-failed;log "FAIL: $*";exit 1; }
dl(){ local u=$1 o=$2 n=0
  while [ $n -lt 3 ];do curl -sfL --connect-timeout 10 -m 60 "$u" -o "$o"&&return 0
    n=$((n+1));log "retry $n: $u";sleep $((2**n));done;fail "DL: $u"; }
log "start v=$V r=$R"
dl "$U/MANIFEST.sha256" $D/MANIFEST.sha256
for d in common $R;do grep "^[a-f0-9].*  $d/" $D/MANIFEST.sha256|while read sum p;do
  f=$D/$${d}-$(basename "$p");dl "$U/$p" "$f"
  echo "$sum  $f"|sha256sum -c ->>$L/verify.log 2>&1||fail "CHK: $p";done||exit 1;done
log "exec scripts"
for s in $(ls $D/*.sh 2>/dev/null|sort);do log "run $(basename $s)"
  chmod +x "$s";"$s">>$L/$(basename $s).log 2>&1||fail "EXEC: $s";done
log "done"
