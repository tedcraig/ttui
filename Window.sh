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
# =============================================================================
# Base class. (1)
function Window()
{
    # A pointer to this Class. (2)
    base=$FUNCNAME
    this=$1

    # Declare Properties. (4)
    export ${this}_x=$2
    export ${this}_y=$3
    export ${this}_z=$4

    # Declare methods. (5)
    for method in $(compgen -A function)
    do
        export ${method/#$base\_/$this\_}="${method} ${this}"
    done
}