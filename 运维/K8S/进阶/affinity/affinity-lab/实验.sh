#!/usr/bin/env bash
# ============================================================
# 顶层一键入口:按顺序跑完所有实验
# 用法:
#   bash 实验.sh          只打印说明
#   bash 实验.sh 1        只跑实验1
#   bash 实验.sh all      依次跑 预备+1+2+3+4
# ============================================================
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-help}"

case "$TARGET" in
  prep|预备)
    bash "$ROOT/00-预备.sh"
    ;;
  1|nodeAffinity)
    bash "$ROOT/01-nodeAffinity/01-run.sh"
    ;;
  2|podAffinity)
    bash "$ROOT/02-podAffinity/02-run.sh"
    ;;
  3|podAntiAffinity)
    bash "$ROOT/03-podAntiAffinity/03-run.sh"
    ;;
  4|spread)
    bash "$ROOT/04-SPD/04-run.sh"
    ;;
  clean|清理)
    bash "$ROOT/99-清理.sh"
    ;;
  all|全部)
    bash "$ROOT/00-预备.sh"
    echo ""
    bash "$ROOT/01-nodeAffinity/01-run.sh"
    echo ""
    bash "$ROOT/02-podAffinity/02-run.sh"
    echo ""
    bash "$ROOT/03-podAntiAffinity/03-run.sh"
    echo ""
    bash "$ROOT/04-SPD/04-run.sh"
    ;;
  *)
    echo "用法: bash 实验.sh [all|1|2|3|4|clean]"
    echo "  1  nodeAffinity     节点亲和(硬/软)"
    echo "  2  podAffinity      同节点亲和(顺序关键)"
    echo "  3  podAntiAffinity  反亲和打散(硬/软)"
    echo "  4  spread           拓扑分布约束(进阶)"
    echo "  clean 清理全部资源"
    ;;
esac