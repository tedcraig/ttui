#! /usr/bin/env bash

# =============================================================================
#
#   name:   enum_builder.sh
#
#   desc:   implements hacky enum-ish style declaration of constants
#
#   dependancies:   awk (developed using version 20200816)
#
#   acknowledgment: code more or less lifted from Zhro
#                   https://stackoverflow.com/questions/21849328/enum-data-type-seems-not-available-in-bash
#
#   NOTE:   This implementation uses 'eval'
#
# -----------------------------------------------------------------------------
#
#   Example:
#   
#   ENUM=(
#      OK_INDEX
#      CANCEL_INDEX
#      ERROR_INDEX
#      CONFIRM_INDEX
#      SAVE_INDEX
#      EXIT_INDEX
#   ) && _enum "${ENUM[@]}"
#   
#   echo "OK_INDEX = "$OK_INDEX
#   echo "CANCEL_INDEX = "$CANCEL_INDEX
#   echo "ERROR_INDEX = "$ERROR_INDEX
#   echo "CONFIRM_INDEX = "$CONFIRM_INDEX
#   echo "SAVE_INDEX = "$SAVE_INDEX
#   echo "EXIT_INDEX = "$EXIT_INDEX
#
#   Output:
#   
#   OK_INDEX = 0
#   CANCEL_INDEX = 1
#   ERROR_INDEX = 2
#   CONFIRM_INDEX = 3
#   SAVE_INDEX = 4
#   EXIT_INDEX = 5
#
# =============================================================================
function build_enum()
{
  ## void
  ## (
  ##    _IN $@ : [ array<string> ] list
  ## )
  local list=("$@")
  local len=${#list[@]}
  for (( i=0; i < $len; i++ )); do
    eval "${list[i]}=$i"
  done
}