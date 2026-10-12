#!/usr/bin/env bash
# Abre várias instâncias REAIS do Godot (host + clientes) e roda o teste de
# rede em cada uma. Uso:
#   GODOT=/caminho/godot tools/tests/run_net_test.sh <lan|relay> <main|kill|hostleave|full>
# Para "relay", defina PNS_RELAY (ex.: 127.0.0.1:8080) e PNS_APP_ID.
set -u
GODOT="${GODOT:-godot}"
TRANSPORT="${1:-lan}"
SCENARIO="${2:-main}"
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${OUT_DIR:-/tmp/pns_net}"
mkdir -p "$OUT"
CODE="$OUT/code_${TRANSPORT}_${SCENARIO}.txt"
rm -f "$CODE" "$CODE.kill" "$OUT"/${TRANSPORT}_${SCENARIO}_*.log

run() { # papel nome log [jogadores]
  exec "$GODOT" --headless --path "$DIR" --script res://tools/tests/net_test.gd -- \
    --role="$1" --name="$2" --transport="$TRANSPORT" --scenario="$SCENARIO" \
    --codefile="$CODE" --players="${4:-2}" > "$3" 2>&1
}

PIDS=()
case "$SCENARIO" in
  main|kill|ui)
    run host Anfitriao "$OUT/${TRANSPORT}_${SCENARIO}_host.log" & HOST=$!
    sleep 2
    run client Convidado "$OUT/${TRANSPORT}_${SCENARIO}_client.log" & PIDS+=($!)
    if [ "$SCENARIO" = kill ]; then
      for i in $(seq 1 120); do
        [ -f "$CODE.kill" ] && break; sleep 0.5
      done
      sleep 1
      echo "Encerrando o host à força (kill -9)..."
      kill -9 $HOST
    fi
    ;;
  killclient)
    run host Anfitriao "$OUT/${TRANSPORT}_${SCENARIO}_host.log" & HOST=$!
    sleep 2
    run client Convidado "$OUT/${TRANSPORT}_${SCENARIO}_client.log" & CLIENT=$!
    for i in $(seq 1 120); do [ -f "$CODE.kill" ] && break; sleep 0.5; done
    sleep 0.5
    echo "Encerrando o cliente à força (kill -9)..."
    kill -9 $CLIENT
    ;;
  errors)
    run host Sozinho "$OUT/${TRANSPORT}_${SCENARIO}_host.log" & HOST=$!
    ;;
  hostleave)
    N=3
    run host Anfitriao "$OUT/${TRANSPORT}_${SCENARIO}_host.log" $N & HOST=$!
    sleep 2
    for n in Bia Caio; do
      run client $n "$OUT/${TRANSPORT}_${SCENARIO}_$n.log" $N & PIDS+=($!); sleep 0.5
    done
    ;;
  full)
    N=6
    run host Anfitriao "$OUT/${TRANSPORT}_${SCENARIO}_host.log" $N & HOST=$!
    sleep 2
    for n in Bia Caio Duda Enzo Fabi; do
      run client $n "$OUT/${TRANSPORT}_${SCENARIO}_$n.log" $N & PIDS+=($!); sleep 0.5
    done
    run client Extra "$OUT/${TRANSPORT}_${SCENARIO}_Extra.log" $N & PIDS+=($!)
    ;;
esac
wait "${PIDS[@]}" 2>/dev/null
[ "$SCENARIO" != kill ] && wait $HOST 2>/dev/null
[ "$SCENARIO" = kill ] && sleep 1
echo "----- $TRANSPORT / $SCENARIO -----"
grep -h "RESULTADO REDE\|\[FALHA\]" "$OUT"/${TRANSPORT}_${SCENARIO}_*.log
