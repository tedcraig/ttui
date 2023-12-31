#! /usr/bin/env bash

# =============================================================================
#
#   name:   ttui_lib.sh
#   auth:   ted craig
#
#   desc:   Terminal UI library for Bash.
#
#   dependancies:   awk  (developed using version 20200816)
#                   perl (developed using version 5.30.3)
#
#   acknowledgment: Special thanks to Dylan Araps who has generously shared
#                   with the world their extensive knowledge of 
#                   shell scripting, especially the esoteric world of console
#                   control escape sequences.
#                   https://github.com/dylanaraps
#
#   NOTE:   There are some potentially dangerous things in here.  In order to
#           allow for the flexibility of having functions write values to 
#           user specified variables, the eval command is used which could
#           result in chaos, or worse, if strings of a certain nature are passed
#           into it.
# =============================================================================

# -----------------------------------------------------------------------------
# Path Vars
# -----------------------------------------------------------------------------
# readonly FULL_PATH_TO_SCRIPT="$(which "$0")"  #/path/filename
# readonly PATH_TO_SCRIPT="$(dirname "$0")"     #/path
# readonly BASENAME="$(basename "$0")"          #filename
readonly TTUI_PATH=$(dirname "${BASH_SOURCE[0]}") # get full path to this file and strip the filename from it
# echo "TTUI_PATH: ${TTUI_PATH}"


# -----------------------------------------------------------------------------
# Imports
# -----------------------------------------------------------------------------
source "${TTUI_PATH}/Enum_builder.sh"
source "${TTUI_PATH}/Window.sh"

# -----------------------------------------------------------------------------
# Global Vars
# -----------------------------------------------------------------------------
TTUI_LOADED=false

readonly TIMESTAMP_AT_LAUNCH=`date +"%Y-%m-%d %T"`
TTUI_THIS_IS_FIRST_LOG=true

TTUI_LOGGING_ENABLED=false
readonly TTUI_LOG_FILENAME="ttui_lib_log.txt"
readonly TTUI_INVOKED_DEBUG_MSG="=========== invoked =========="
readonly TTUI_EXECUTION_COMPLETE_DEBUG_MSG="  --- execution complete ---"

TTUI_SHOULD_USE_WHOLE_TERM_WINDOW=false
TTUI_SCROLL_AREA_CHANGED=false
TTUI_OPERATING_SYSTEM=
TTUI_TERM_LINES=
TTUI_TERM_COLUMNS=
TTUI_CURRENT_LINE=
TTUI_CURRENT_COLUMN=
TTUI_CURSOR_VISIBLE=true
TTUI_LINE_WRAPPING_ENABLED=true
TTUI_COLOR_RGB=()
TTUI_COLOR_LCH_FROM_RGB=
TTUI_COLOR_RGB_FROM_LCH=


## Glyphs to use as 'graphics' in the terminal
## https://www.w3.org/TR/xml-entity-names/025.html

# wborder(local_win, ' ', ' ', ' ',' ',' ',' ',' ',' ');
# 	/* The parameters taken are 
# 	 * 1. win: the window on which to operate
# 	 * 2. ls: character to be used for the left side of the window 
# 	 * 3. rs: character to be used for the right side of the window 
# 	 * 4. ts: character to be used for the top side of the window 
# 	 * 5. bs: character to be used for the bottom side of the window 
# 	 * 6. tl: character to be used for the top left corner of the window 
# 	 * 7. tr: character to be used for the top right corner of the window 
# 	 * 8. bl: character to be used for the bottom left corner of the window 
# 	 * 9. br: character to be used for the bottom right corner of the window
# 	 */
readonly TTUI_WBORDER_SINGLE_SQUARED_LIGHT=('│' '│' '─' '─' '┌' '┐' '└' '┘')
readonly TTUI_WBORDER_SINGLE_SQUARED_HEAVY=('║' '║' '═' '═' '╔' '╗' '╚' '╝')
readonly TTUI_WBORDER_SINGLE_ROUNDED_LIGHT=('│' '│' '─' '─' '╭' '╮' '╰' '╯')
readonly TTUI_WBORDER_DOUBLE_SQUARED_LIGHT=()
readonly TTUI_WBORDER_DOUBLE_SQUARED_HEAVY=()

readonly TTUI_HORIZONTAL_RULER_TICK='│'

## horizontal bar
readonly TTUI_HBAR_8='█'
readonly TTUI_HBAR_7='▉'
readonly TTUI_HBAR_6='▊'
readonly TTUI_HBAR_5='▋'
readonly TTUI_HBAR_4='▌'
readonly TTUI_HBAR_3='▍'
readonly TTUI_HBAR_2='▎'
readonly TTUI_HBAR_1='▏'
readonly TTUI_HBAR_0='╳'


## escape codes that can be strung together in a printf statement 
## for speed and brevity as an alternative to function calls
readonly TTUI_SAVE_TERMINAL_SCREEN='\e[?1049h'
readonly TTUI_RESTORE_TERMINAL_SCREEN='\e[?1049l'
readonly TTUI_RESET_TERMINAL_TO_DEFAULTS='\ec'
readonly TTUI_CLEAR_SCREEN_ENTIRELY='\e[2J'
readonly TTUI_DISABLE_LINE_WRAPPING='\e[?7l'
readonly TTUI_ENABLE_LINE_WRAPPING='\e[?7h'
readonly TTUI_RESTORE_SCROLL_AREA='\e[;r'
readonly TTUI_SCROLL_UP='\eM'
readonly TTUI_SCROLL_DOWN='\eD'
readonly TTUI_HIDE_CURSOR='\e[?25l'
readonly TTUI_SHOW_CURSOR='\e[?25h'
readonly TTUI_SAVE_CURSOR_POSITION='\e7'
readonly TTUI_RESTORE_CURSOR_POSITION='\e8'
readonly TTUI_MOVE_CURSOR_UP_ONE_LINE='\e[1A'
readonly TTUI_MOVE_CURSOR_DOWN_ONE_LINE='\e[1B'
readonly TTUI_MOVE_CURSOR_LEFT_ONE_COL='\e[1D'
readonly TTUI_MOVE_CURSOR_RIGHT_ONE_COL='\e[1C'
readonly TTUI_MOVE_CURSOR_TO_HOME_POSITION='\e[2J'
readonly TTUI_MOVE_CURSOR_TO_BOTTOM_LINE='\e[9999H'


# -----------------------------------------------------------------------------
# Signal Captures
# -----------------------------------------------------------------------------

# React to window size changes via SIGWINCH
trap 'ttui::get_term_size' WINCH
# Clean up upon exit signal.  If this trap is overridden, overriding script
# should call this function within its own exit handling
trap 'ttui::handle_exit' EXIT


# -----------------------------------------------------------------------------
# Get the current operating system type
# Globals:
#   TTUI_OS
# Arguments:
#   None
# -----------------------------------------------------------------------------
# ┏━━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━┓
# ┃          OS	        │       $OSTYPE       ┃
# ┣━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━┫  
# ┃ Linux with glibc	  │ linux-gnu           ┃
# ┃ Linux with musl	    │ linux-musl          ┃
# ┃ Cygwin	            │ cygwin              ┃
# ┃ Bash on Windows 10  │	linux-gnu           ┃
# ┃ Msys	              │ msys                ┃
# ┃ Mingw64	            │ msys                ┃ 
# ┃ Mingw32	            │ msys                ┃
# ┃ OpenBSD	            │ openbsd*            ┃
# ┃ FreeBSD	            │ freebsd*            ┃
# ┃ NetBSD	            │ netbsd              ┃
# ┃ macOS	              │ darwin*             ┃
# ┃ iOS	                │ darwin9             ┃
# ┃ Solaris	            │ solaris*            ┃
# ┃ Android (Termux)    │ linux-android       ┃
# ┃ Android	            │ linux-gnu           ┃
# ┃ Haiku	              │ haiku               ┃
# ┗━━━━━━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━━━━━━┛
ttui::get_operating_system() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  # '$OSTYPE' typically stores the name of the OS kernel.
  case "$OSTYPE" in
    linux*)
      TTUI_OPERATING_SYSTEM="linux"
      # ...
    ;;

    # Mac OS X / macOS.
    darwin*)
      TTUI_OPERATING_SYSTEM="macos"
      # ...
    ;;

    openbsd*)
      TTUI_OPERATING_SYSTEM="openbsd"
      # ...
    ;;

    # Everything else.
    *)
      TTUI_OPERATING_SYSTEM="other"
      #...
    ;;
  esac
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# Saves the current state of the terminal which can later be restored via
# ttui::restore_terminal_screen()
# Globals:
#   TBD
# Arguments:
#   None
# -----------------------------------------------------------------------------
ttui::save_terminal_screen() {
  # Saving and Restoring the user's terminal screen.
  # This non-VT100 sequence allows you to save and restore the user's terminal 
  # screen when running your program. When the user exits the program, their 
  # command-line will be restored as it was before running the program.
  # While this sequence is XTerm specific, it is covered by almost all modern 
  # terminal emulators and simply ignored in older ones. 
  # Save the user's terminal screen.
  printf '\e[?1049h'
}


# -----------------------------------------------------------------------------
# Restores terminal to the state saved via ttui::save_terminal_screen()
# Globals:
#   TBD
# Arguments:
#   None
# -----------------------------------------------------------------------------
ttui::restore_terminal_screen() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  printf '\e[?1049l'
}


# -----------------------------------------------------------------------------
# Clears the screen.
# Globals:
#   TBD
# Arguments:
#   None
# -----------------------------------------------------------------------------
ttui::reset_terminal_to_defaults() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  printf '\ec'
}


# -----------------------------------------------------------------------------
# Clears the screen.
# Globals:
#   TBD
# Arguments:
#   None
# -----------------------------------------------------------------------------
ttui::clear_screen() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  # See: https://vt100.net/docs/vt510-rm/ED.html
  # Ps represents the amount of the display to erase.
  # Ps	Area Erased:
  # 0 (default)	From the cursor through the end of the display
  # 1	From the beginning of the display through the cursor
  # 2	The complete display
  printf '\e[2J'
}


# -----------------------------------------------------------------------------
# Get the current size of the terminal
# Globals:
#   lines
#   ORACLE_SID
# Arguments:
#   None
# -----------------------------------------------------------------------------
ttui::get_term_size() {
  local should_print=false
  
  [[ $# -gt 0 ]] && [[ "$1" == "print" ]] && {
    should_print=true
  }
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  # '\e7':           Save the current cursor position.
  # '\e[9999;9999H': Move the cursor to the bottom right corner.
  # '\e[6n':         Get the cursor position (window size).
  # '\e8':           Restore the cursor to its previous position.
  IFS='[;' read -p $'\e7\e[9999;9999H\e[6n\e8' -d R -rs _ TTUI_TERM_LINES TTUI_TERM_COLUMNS
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
  [[ "${should_print}" == "true" ]] && {
    echo "${TTUI_TERM_LINES} ${TTUI_TERM_COLUMNS}"
  }
}


# -----------------------------------------------------------------------------
# Get the current width (number of columns) of the terminal
# Globals:
#   TTUI_TERM_COLUMNS
# Function Calls:
#   ttui::get_term_size
# Arguments:
#   $1) force - if string "force" is received, get_term_size will be called
#               before echoing result
# -----------------------------------------------------------------------------
ttui::get_term_width() {
  [[ "$1" == "from_cache" ]] && {
    echo "${TTUI_TERM_COLUMNS}"
    return
  }
  ttui::get_term_size
  echo "${TTUI_TERM_COLUMNS}"
}


# -----------------------------------------------------------------------------
# Get the current height (number of lines) of the terminal
# Globals:
#   TTUI_TERM_LINES
# Function Calls:
#   ttui::get_term_size
# Arguments:
#   $1) force - if string "force" is received, get_term_size will be called
#               before echoing result
# -----------------------------------------------------------------------------
ttui::get_term_height() {
  [[ "$1" == "from_cache" ]] && {
    echo "${TTUI_TERM_LINES}"
    return
  }
  ttui::get_term_size
  echo "${TTUI_TERM_LINES}"
}


# -----------------------------------------------------------------------------
# Disables line wrapping
# Globals:
#   line_wrapping_enabled
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::disable_line_wrapping() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  printf '\e[?7l'
  TTUI_LINE_WRAPPING_ENABLED=false
}


# -----------------------------------------------------------------------------
#  line wrapping
# Globals:
#   line_wrapping_enabled
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::enable_line_wrapping() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  printf '\e[?7h'
  TTUI_LINE_WRAPPING_ENABLED=true
}


# -----------------------------------------------------------------------------
# Limits vertical scrolling area to be between the two specified points
# and then moves cursor to top-left of the new boundary.
# Globals:
#   TTUI_SCROLL_AREA_TOP
#   TTUI_SCROLL_AREA_BOTTOM
# Arguments:
#   position 1: top line number (positive int) inclusive
#   position 2: bottom line number (positive int) inclusive
# -----------------------------------------------------------------------------
ttui::set_scroll_area() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  local expanded_args=$(echo "$@")
  ttui::logger::log "args received: $expanded_args"

  ## TODO: arg validation
  if [[ $# -gt 1 ]]; then
    local top_line_of_scroll=$1
    local bottom_line_of_scroll=$2
    # See: https://vt100.net/docs/vt510-rm/DECSTBM.html
    # Limit scrolling from line 0 to line 10.
    # printf '\e[0;10r'
    # Limit scrolling from line top to line bottom.
    printf '\e[%s;%sr' "${top_line_of_scroll}" "${bottom_line_of_scroll}"
    TTUI_SCROLL_AREA_CHANGED=true
  fi
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# Restores scolling margins back to default.
# Globals:
#   TTUI_SCROLL_AREA_TOP
#   TTUI_SCROLL_AREA_BOTTOM
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::restore_scroll_area() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  # See: https://vt100.net/docs/vt510-rm/DECSTBM.html
  printf '\e[;r'
  TTUI_SCROLL_AREA_CHANGED=false
}


# -----------------------------------------------------------------------------
# Scroll display up one line.
# Globals:
#   TBD
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::scroll_up() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  printf '\eM'
}


# -----------------------------------------------------------------------------
# Scroll display down one line.
# Globals:
#   TBD
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::scroll_down() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  printf '\eD'
}


# -----------------------------------------------------------------------------
# Clear the current line 
# Globals:
#   TBD
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::clear_line() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"

  # cleareol EL0          Clear line from cursor right           [0K
  # clearbol EL1          Clear line from cursor left            [1K
  # clearline EL2         Clear entire line                      [2K

  # if not args, delete entire line
  [[ $# == 0 ]] && {
    printf '\e[2K'
    return
  }
  
  case $1 in
    "left"|"LEFT")
      printf '\e[1K'
      return
      ;;
    "right"|"RIGHT")
      printf '\e[0K'
      return
      ;;
    "whole"|"WHOLE")
      printf '\e[2K'
      return
      ;;
  esac
}


# -----------------------------------------------------------------------------
# Generates RGB color escape code string using the argument values supplied. 
# If optional variable name argument is provided, resulting escape code will be 
# assigned to variable matching the provided name.  
# If optional variable name argument is not used then resulting escape code will
# be assigned global variable TTUI_COLOR_RGB.
# Globals:
#   TTUI_COLOR_RGB
# Arguments:
#   position 1:  Red    value (0-255)
#   position 2:  Blue   value (0-255)
#   position 3:  Green  value (0-255)
#  [position 4:] name of existing variable to which result should be assigned
# -----------------------------------------------------------------------------
ttui::color::get_escape_code_for_rgb() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  local expanded_args=$(echo "$@")
  ttui::logger::log "args received: $expanded_args"

  ##########  TODO:
  ##########  check that args in position 1, 2, 3 are numbers 
  ##########  and that they are within the legal range for RGB
  ##########  values: 0-255
  
  local RED=$1
  local GREEN=$2
  local BLUE=$3
  
  # assign escape code string ---------------------------------------------------
  #   if option fourth arg exists, then try to assign values to variable of the same name
  #   else assign values to default global variable
  if [[ $# -gt 3 ]]; then
    ttui::logger::log "4th arg found: $4"
    # check if the string value of myVar is the name of a declared variable
    local varName="$4"
    # myVar='$'"$4"
    local bVarExists=false
    local test='if ${'"${varName}"'+"false"}; then ttui::logger::log "${varName} not defined"; else bVarExists=true; ttui::logger::log "${varName} is defined"; fi'
    ttui::logger::log "test: $test"
    eval $test
    ttui::logger::log  "bVarExists: ${bVarExists}"

    if [[ $bVarExists == true ]]; then
      local assignment="${varName}"'="\033[38;2;${RED};${GREEN};${BLUE}m"'
      ttui::logger::log  "assignment: ${assignment}"
      eval $assignment
    else
      echo "${FUNCNAME[0]} --> warning: cannot assign RGB color escape code to ${varName}: undelcared variable"
    fi
  else
    ttui::logger::log "no var name provided. Assigning RGB color escape code to TTUI_COLOR_RGB_FROM_LCH"
    TTUI_COLOR_RGB='\033[38;2;'"${RED};${GREEN};${BLUE}"'m'
  fi
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# *** SLOW-ish !!! ***
# Converts RGB (0-255) color values to CIE-L*Ch°(ab) (LCH) values. 
# If optional variable name argument is provided, resulting LCH values will be 
# assigned as an array (L,C,H) to variable matching the provided name.  If 
# optional variable name argument is not used then resulting LCH value will be
# assigned as an array (L,C,H) to global variable TTUI_COLOR_LCH_FROM_RGB.
# Globals:
#   TTUI_COLOR_LCH_FROM_RGB
# Arguments:
#   position 1:  Red    value (0-255)
#   position 2:  Green  value (0-255)
#   position 3:  Blue   value (0-255)
#  [position 4:] name of existing variable to which result should be assigned
# Dependancies:
#   awk
# -----------------------------------------------------------------------------
#     color conversion equations from:
#     avisek/colorConversions.js
#     https://gist.github.com/avisek/eadfbe7a7a169b1001a2d3affc21052e
# 
#     checked sanity of results using:
#     http://colormine.org/convert/rgb-to-lch - matches converted values
#     https://www.easyrgb.com/en/convert.php#inputFORM - C val is slightly different
# 
#     LCH color picker:
#     https://css.land/lch/
# -----------------------------------------------------------------------------
ttui::color::get_lch_from_rgb() {

##########  TODO:
##########  check that args in position 1, 2, 3 are numbers 
##########  and that they are within the legal range for their
##########  respective LCH value:
##########    position 1:  LCH lightness value (0-100)
##########    position 2:  LCH chroma    value (0-132)
##########    position 3:  LCH hue       value (0-360)
ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
ttui::logger::log "$# arguments received"
local expanded_args=$(echo "$@")
ttui::logger::log "args received: $expanded_args"

## TODO: validate that 3 numbers have been provided and that they are within legal range
## assign positional args 1,2,3 as prospective LCH values
local RGB_R=$1
local RGB_G=$2
local RGB_B=$3

ttui::logger::log "rgb --> R: $RGB_R | G: $RGB_G | B: $RGB_B"

  ttui::logger::log "converting RGB to LCH..."

  local LCH=`awk -v R=$RGB_R -v G=$RGB_G -v B=$RGB_B 'BEGIN {
    # convert rgb --> xyz
    R = R / 255
    G = G / 255
    B = B / 255
    
    if (R > 0.04045) {
      R = ((R + 0.055) / 1.055) ^ 2.4
    } else {
      R = R / 12.92
    }
    
    if (G > 0.04045) {
      G = ((G + 0.055) / 1.055) ^ 2.4
    } else {
      G = G / 12.92
    }

    if (B > 0.04045) {
      B = ((B + 0.055) / 1.055) ^ 2.4
    } else {
      B = B / 12.92
    }

    R *= 100
    G *= 100
    B *= 100

    #Observer = 2°, Illuminant = D65
    X = R * 0.4124 + G * 0.3576 + B * 0.1805
    Y = R * 0.2126 + G * 0.7152 + B * 0.0722
    Z = R * 0.0193 + G * 0.1192 + B * 0.9505
    # print X, Y, Z

    # convert xyz --> lab
    # Observer = 2°, Illuminant = D65
    X = X / 95.047
    Y = Y / 100.000
    Z = Z / 108.883

    if (X > 0.008856) {
      X = X ** 0.333333333
    } else {
      X = 7.787 * X + 0.137931034
    }

    if (Y > 0.008856) {
      Y = Y ** 0.333333333
    } else {
      Y = 7.787 * Y + 0.137931034
    }

    if (Z > 0.008856) {
      Z = Z ** 0.333333333
    } else {
      Z = 7.787 * Z + 0.137931034
    }

    L = (116 * Y) - 16
    A = 500 * (X - Y)
    B = 200 * (Y - Z)
    # print L, A, B

    # convert lab --> lch

    C = sqrt( (A * A) + (B * B) )
    
    H = atan2(B, A) #quadrant by signs

    # get value of PI
    PI = atan2(0, -1)

    if (H > 0) {
      H = (H / PI) * 180
    } else {
      H = sub("^-", "", H) # make absolute val by removing minus sign
      H = 360 - (H / PI) * 180
    }
    # result
    print L, C, H
  }'`

  # print result
  echo "${LCH}"

  export TTUI_COLOR_LCH_FROM_RGB=(${LCH})

  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# *** SLOW-ish !!! ***
# Converts LCH color values -- specifically CIE-L*Ch°(ab) -- to RGB values.
# Resulting RGB values are echoed as a string delimited by spaces and are also
# assigned as an array (R,G,B) to global variable TTUI_COLOR_RGB_FROM_LCH.
#
# Globals:
#   TTUI_COLOR_RGB_FROM_LCH
#
# Arguments:
#   position 1:  LCH lightness value (0-100)
#   position 2:  LCH chroma    value (0-132)
#   position 3:  LCH hue       value (0-360)
#  [position 4:] name of existing variable to which result should be assigned
#
# Dependancies:
#   awk
# -----------------------------------------------------------------------------
ttui::color::get_rgb_from_lch() {
  # color conversion equations from:
  # avisek/colorConversions.js
  # https://gist.github.com/avisek/eadfbe7a7a169b1001a2d3affc21052e
  #
  # checked sanity of results using:
  # https://www.easyrgb.com/en/convert.php#inputFORM
  #
  # LCH color picker:
  # https://css.land/lch/

  ##########  TODO:
  ##########  check that args in position 1, 2, 3 are numbers 
  ##########  and that they are within the legal range for their
  ##########  respective LCH value:
  ##########    position 1:  LCH lightness value (0-100)
  ##########    position 2:  LCH chroma    value (0-132)
  ##########    position 3:  LCH hue       value (0-360)

  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  local expanded_args=$(echo "$@")
  ttui::logger::log "args received: $expanded_args"
  
  # assign positional args 1,2,3 as prospective LCH values
  local LCH_L=$1
  local LCH_C=$2
  local LCH_H=$3

  # TODO: validate that 3 numbers have been provided and that they are within legal range

  # isNumber=`eval '[[ '$"${varName}"' =~ ^[+-]?[0-9]+$ ]]'`
  # if $isNumber; then echo "it's a number!"; else echo "it's not a number"; fi

  # if [[ eval $myVar =~ ^[+-]?[0-9]+$ ]]; then
  #   echo "Number!" 
  # elif [[ eval $myVar =~ ^[+-]?[0-9]*\.[0-9]+$ ]]; then
  #   echo "Float!"
  # elif [[ eval $myVar =~ [0-9] ]]; then
  #   echo "Mixed, some numbers"
  # else
  #   echo "No numbers!"
  # fi  


  ttui::logger::log "lch --> L: $LCH_L | C: $LCH_C | H: $LCH_H"

  ttui::logger::log "converting LCH to RGB..."

  local RGB=`awk -v L=$LCH_L -v C=$LCH_C -v H=$LCH_H 'BEGIN {
    # convert LCH -> LAB
    A = cos(H * 0.01745329251) * C;
    B = sin(H * 0.01745329251) * C;
    # print "LAB:", L, A, B;

    # convert LAB -> XYZ
    Y = ( L + 16 ) / 116;
    X = A / 500 + Y;
    Z = Y - B / 200;

    Y = (Y ^ 3) > 0.008856 ? Y ^ 3 : (Y - 0.137931034) / 7.787;
    X = (X ^ 3) > 0.008856 ? X ^ 3 : (X - 0.137931034) / 7.787;
    Z = (Z ^ 3) > 0.008856 ? Z ^ 3 : (Z - 0.137931034) / 7.787;

    X = 95.047 * X;
    Y = 100.000 * Y;
    Z = 108.883 * Z;

    X = X / 100;
    Y = Y / 100;
    Z = Z / 100;
    # print "XYZ:", X, Y, Z;

    # convert XYZ -> RGB
    R = X * 3.2406 + Y * -1.5372 + Z * -0.4986;
    G = X * -0.9689 + Y * 1.8758 + Z * 0.0415;
    B = X * 0.0557 + Y * -0.2040 + Z * 1.0570;

    R = R > 0.0031308 ? 1.055 * (R ^ 0.41666667) - 0.055 : 12.92 * R;
    G = G > 0.0031308 ? 1.055 * (G ^ 0.41666667) - 0.055 : 12.92 * G;
    B = B > 0.0031308 ? 1.055 * (B ^ 0.41666667) - 0.055 : 12.92 * B;

    R = 255 * R;
    G = 255 * G;
    B = 255 * B;
    # print "RGB (unclamped):", R, G, B;

    # clamp RGB values to inclusive range 0-255 and force to int value
    intVal = int(R) 
    if (R < 0) {
      R = 0
    } else if (R > 255) {
      R = 255
    } else if (R == intVal ){
      R = R
    } else if (R - intVal >= 0.5) {
      R = intVal + 1
    } else {
      R = intVal
    }; 
    
    intVal = int(G) 
    if (G < 0) {
      G = 0
    } else if (G > 255) {
      G = 255
    } else if (G == intVal ){
      G = G
    } else if (G - intVal >= 0.5) {
      G = intVal + 1
    } else {
      G = intVal
    }; 
  
    intVal = int(B) 
    if (B < 0) {
      B = 0
    } else if (B > 255) {
      B = 255
    } else if (B == intVal ){
      B = B
    } else if (B - intVal >= 0.5) {
      B = intVal + 1
    } else {
      B = intVal
    }; 
    # print "RGB:", R, G, B;

    # result
    print R, G, B
  }'`

  # print result
  echo "${RGB}"


  # convert to array in order to log individual values
  # RGB_arr=($RGB)
  # ttui::logger::log "rgb --> R: ${RGB_arr[0]} | G: ${RGB_arr[1]} | B: ${RGB_arr[2]}"
  
  # assign to global var
  TTUI_COLOR_RGB_FROM_LCH=${RGB}
  
  ttui::logger::log "TTUI_COLOR_RGB_FROM_LCH: ${TTUI_COLOR_RGB_FROM_LCH}"

  

  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# Sets active color to terminal default.
# Globals:
#   none
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::color::reset() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  printf "\033[0m"
}


# -----------------------------------------------------------------------------
# Sets color to specified RGB value.
# This color will remain active until the it is intentionally reset.
# Globals:
#   none
# Arguments:
#   position 1:  Red    value (0-255)
#   position 2:  Blue   value (0-255)
#   position 3:  Green  value (0-255)
# -----------------------------------------------------------------------------
ttui::color::set_color_to_rgb() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  local expanded_args=$(echo "$@")
  ttui::logger::log "args received: $expanded_args"

  ##########  TODO:
  ##########  check that args in position 1, 2, 3 are numbers 
  ##########  and that they are within the legal range for RGB
  ##########  values: 0-255
  
  local RED=$1
  local GREEN=$2
  local BLUE=$3

  printf "\033[38;2;%d;%d;%dm" ${RED} ${GREEN} ${BLUE};

  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# Hides the cursor
# Globals:
#   cursor_visible
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::cursor::hide() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  printf '\e[?25l'
  TTUI_CURSOR_VISIBLE=false
}


# -----------------------------------------------------------------------------
# Shows the cursor
# Globals:
#   cursor_visible
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::cursor::show() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  printf '\e[?25h'
  TTUI_CURSOR_VISIBLE=true
}


# -----------------------------------------------------------------------------
# Saves the current cursor position.  Cursor can later be restored to this
# position using ttui::restore_cursor_position()
# Globals:
#   TBD
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::cursor::save_position() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  # This is more widely supported than '\e[s'.
  printf '\e7'
}


# -----------------------------------------------------------------------------
# Restores the cursor to the position saved via ttui::save_cursor_position().
# Globals:
#   TBD
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::cursor::restore_position() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  # This is more widely supported than '\e[u'.
  printf '\e8'
}


# -----------------------------------------------------------------------------
# Restores the cursor to the position saved via ttui::save_cursor_position().
# Globals:
#   TTUI_CURRENT_LINE
#   TTUI_CURRENT_COLUMN
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::cursor::get_position() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"

  # save the current/default IFS delimeter(s) in order to restore later
  local old_ifs="$IFS"
  
  # assign line and column nums
  IFS='[;' read -p $'\e[6n' -d R -rs _ TTUI_CURRENT_LINE TTUI_CURRENT_COLUMN
  #\_____/ \__/ \_________/ \__/ \_/ \_____________________________________/
  #   |     |       |        |    |                    |
  #   |     |       |        |    |     Variables to receive output of read,
  #   |     |       |        |    |     as parsed by the IFS delimeters.
  #   |     |       |        |    |     pattern of response to parse: 
  #   |     |       |        |    |         ^[Ignore[Lines;ColumnsR
  #   |     |       |        |    |     var:  -
  #   |     |       |        |    |         receives superfluous value
  #   |     |       |        |    |         parsed between [ and [
  #   |     |       |        |    |     var:  LINE_NUM_VAR
  #   |     |       |        |    |         receives line number value
  #   |     |       |        |    |         parsed between [ and ;
  #   |     |       |        |    |     var:  COLUMN_NUM_VAR
  #   |     |       |        |    |         receives column number value
  #   |     |       |        |    |         parsed between ; and R
  #   |     |       |        |     ╲
  #   |     |       |        |  Do not treat a Backslash as an escape character.
  #   |     |       |        |  Silent mode: any characters input from the terminal
  #   |     |       |        |  are not echoed.
  #   |     |       |         ╲
  #   |     |       |     Terminates the input line at R rather than at newline 
  #   |     |        ╲
  #   |     |     Prints '\e[6n' as prompt to console.
  #   |     |     This term command escape code is immediately interpted, generating
  #   |     |     response code containing the line and column position
  #   |     |     in format: ^[[1;2R  (where num at position 1 is the line number
  #   |     |     and num at position 2 is the column number). This response string
  #   |     |     becomes the input of the read command.
  #   |      ╲
  #   |     Read input from console
  #    ╲
  #   Overrides default delimeters for output of the read.
  #   Will capture values between [ and/or ; chars

  # reset delimeters to original/default value
  IFS="${old_ifs}"

  ttui::logger::log "current position: Line ${TTUI_CURRENT_LINE} | Col ${TTUI_CURRENT_COLUMN}"
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# Get the column number on which the cursor currently resides
# Globals:
#   TTUI_CURRENT_COLUMN
# Function Calls:
#   ttui::cursor::get_position
# Arguments:
#   $1) from_cache - result will be echoed from global var TTUI_CURRENT_COLUMN 
#       without reinvoking cursor::get_position()
#       **NOTE** this feature will NOT work if function is being called within
#       a command substitution
#               
# -----------------------------------------------------------------------------
ttui::cursor::get_column() {
  [[ "$1" == "from_cache" ]] && {
    # return column number stored in global var without updating via ttui::cursor::get_position
    echo "${TTUI_CURRENT_COLUMN}"
    return
  }
  ttui::cursor::get_position # updates global var TTUI_CURRENT_COLUMN
  echo "${TTUI_CURRENT_COLUMN}"
}


# -----------------------------------------------------------------------------
# Get the line number on which the cursor currently resides
# Globals:
#   TTUI_CURRENT_LINE
# Function Calls:
#   ttui::cursor::get_position
# Arguments:
#   $1) from_cache - result will be echoed from global var TTUI_CURRENT_LINE 
#       without reinvoking cursor::get_position()
#       **NOTE** this feature will NOT work if function is being called within
#       a command substitution
# -----------------------------------------------------------------------------
ttui::cursor::get_line() {
  [[ "$1" == "from_cache" ]] && {
    # return column number stored in global var without updating via ttui::cursor::get_position
    echo "${TTUI_CURRENT_LINE}"
    return
  }
  ttui::cursor::get_position # updates global var TTUI_CURRENT_COLUMN
  echo "${TTUI_CURRENT_LINE}"
}


# -----------------------------------------------------------------------------
# Moves cursor to the specified line and column.
# Globals:
#   TBD
# Arguments:
#   position 1: line number (positive int) or '-' (any non-digit char)
#   position 2: column number (positive int) or '-' (any non-digit char)
# -----------------------------------------------------------------------------
ttui::cursor::move_to() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  ttui::logger::log "arg \$1: $1 | \$2: $2"
  
  local LINE_NUMBER=$1
  local COLUMN_NUMBER=$2
  
  # See: https://vt100.net/docs/vt510-rm/CUP.html
  
  [[ $# == 0 ]] && {
    # Move the cursor to 0,0.
    printf '\e[H'
    return 0
  }

  ## TODO: validate that LINE_NUMBER value is actually an integer
  [[ $# == 1 ]] && {
    # Move the cursor to specified line number.
    printf '\e[%sH' "${LINE_NUMBER}"  
  }

  ## TODO: validate that LINE_NUMBER & COLUMN_NUMBER value are actually integers
  [[ $# -gt 1 ]] && {
    # Move the cursor to specified line and column.
    printf '\e[%s;%sH' "${LINE_NUMBER}" "${COLUMN_NUMBER}"
  }
  
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# Moves cursor up 1 or more lines relative to current position.
# Globals:
#   TBD
# Arguments:
#   [position 1]: number of lines to move (positive int)
# -----------------------------------------------------------------------------
ttui::cursor::move_up() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  local expanded_args=$(echo "$@")
  ttui::logger::log "args received: $expanded_args"
  # See: https://vt100.net/docs/vt510-rm/CUU.html
  # if no value passed, move up 1 line
  local num_lines_to_move=1
  # else move up the specified number of lines
  # printf '\e[%sA' "${num_lines_to_move}"
  # Todo: validate arg is actually a valid number
  [[ $# -gt 0 ]] && num_lines_to_move=$1
  ttui::logger::log "moving up ${num_lines_to_move} lines"
  printf '\e[%sA' "${num_lines_to_move}"
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# Moves cursor down 1 or more lines relative to current position.
# Globals:
#   TBD
# Arguments:
#   [position 1]: number of lines to move (positive int)
# -----------------------------------------------------------------------------
ttui::cursor::move_down() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  local expanded_args=$(echo "$@")
  ttui::logger::log "args received: $expanded_args"
  # See: https://vt100.net/docs/vt510-rm/CUD.html
  # if no value passed, move up 1 line
  # printf '\e[B'
  local num_lines_to_move=1
  # else move up the specified number of lines
  # printf '\e[%sB' "${num_lines_to_move}"
  # Todo: validate arg is actually a valid number
  [[ $# -gt 0 ]] && num_lines_to_move=$1
  ttui::logger::log "moving down ${num_lines_to_move} lines"
  printf '\e[%sB' "${num_lines_to_move}"
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# Moves cursor left 1 or more lines relative to current position.
# Globals:
#   TBD
# Arguments:
#   [position 1]: number of lines to move (positive int)
# -----------------------------------------------------------------------------
ttui::cursor::move_left() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  local expanded_args=$(echo "$@")
  ttui::logger::log "args received: $expanded_args"
  # See: https://vt100.net/docs/vt510-rm/CUB.html
  # if no value passed, move up 1 line
  # printf '\e[D'
  local num_columns_to_move=1
  # else move left the specified number of columns
  # printf '\e[%sD' "${num_columns_to_move}"
  # Todo: validate arg is actually a valid number
  [[ $# -gt 0 ]] && num_columns_to_move=$1
  ttui::logger::log "moving left ${num_columns_to_move} columns"
  printf '\e[%sD' "${num_columns_to_move}"
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# Moves cursor right 1 or more lines relative to current position.
# Globals:
#   TBD
# Arguments:
#   [position 1]: number of lines to move (positive int)
# -----------------------------------------------------------------------------
ttui::cursor::move_right() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  local expanded_args=$(echo "$@")
  ttui::logger::log "args received: $expanded_args"
  # See: https://vt100.net/docs/vt510-rm/CUF.html
  # if no value passed, move up 1 line
  # printf '\e[C'
  local num_columns_to_move=1
  # else move up the specified number of columns
  # printf '\e[%sC' "${num_columns_to_move}"
  # Todo: validate arg is actually a valid number
  [[ $# -gt 0 ]] && num_columns_to_move=$1
  ttui::logger::log "moving right ${num_columns_to_move} columns"
  printf '\e[%sC' "${num_columns_to_move}"
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# Moves cursor to the last line.
# Globals:
#   TBD
# Arguments:
#   position 1: line number (positive int) or '-' (any non-digit char)
#   position 2: column number (positive int) or '-' (any non-digit char)
# -----------------------------------------------------------------------------
ttui::cursor::move_to_bottom() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  # Using terminal size, move cursor to bottom.
  # printf '\e[%sH' "$LINES"
  #  -- or --
  # Move to a huge number, will stop at bottom line available in the window
  printf '\e[9999H'
}


# -----------------------------------------------------------------------------
# Moves cursor to the home position: 0,0.
# Globals:
#   none
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::cursor::move_to_home() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  printf '\e[2J'
}


# -----------------------------------------------------------------------------
# Moves cursor to the left most position: 1 (or 0).
# Globals:
#   none
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::cursor::move_to_left() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  # use a huge number, the cursor will only move as far as the left edge
  printf '\e[%sD' 999
}


# -----------------------------------------------------------------------------
# Draws box of specified width and height at the current cursor location 
# or from specified anchor point.
# Globals:
#   ttui::cursor::get_column()
#   ttui::cursor::get_line()
#   ttui::cursor::move_right()
#   ttui::cursor::move_to()
#   ttui::cursor::move_up()
#   ttui::logger::log()
#   TTUI_WBORDER_SINGLE_SQUARED_LIGHT (array of border glyphs)
# Arguments:
#   $1  : width of box  (including border)
#   $2  : height of box (including border)
#  [$3] : anchor column (upper left corner location)
#  [$4] : anchor line   (upper left corner location)
# -----------------------------------------------------------------------------
ttui::draw::box() {
  # width, height, upperLeftX, upperLeftY
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  ttui::logger::log "args received: $*"

  local width="$1"
  ttui::logger::log "width:  ${width}"

  local height="$2"
  ttui::logger::log "height: ${height}"

  local anchor_column=
  anchor_column=$(ttui::cursor::get_column)
    [[ $# -gt 2 ]] && {
      anchor_column=$3
    }
  ttui::logger::log "anchor_column: ${anchor_column}"

  local anchor_line=
  anchor_line=$(ttui::cursor::get_line)
    [[ $# -gt 3 ]] && {
      anchor_line="$4"
    }
  ttui::logger::log "anchor_line: ${anchor_line}"

  local current_column=
  local current_line=

  ## wborder params
  ## 	0. ls: character to be used for the left side of the window 
  ## 	1. rs: character to be used for the right side of the window 
  ## 	2. ts: character to be used for the top side of the window 
  ## 	3. bs: character to be used for the bottom side of the window 
  ## 	4. tl: character to be used for the top left corner of the window 
  ## 	5. tr: character to be used for the top right corner of the window 
  ## 	6. bl: character to be used for the bottom left corner of the window 
  ## 	7. br: character to be used for the bottom right corner of the window

  local left_side=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[0]}
  local right_side=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[1]}
  local top_side=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[2]}
  local bottom_side=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[3]}
  local top_left_corner=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[4]}
  local top_right_corner=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[5]}
  local bottom_left_corner=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[6]}
  local bottom_right_corner=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[7]}
  
  ## dev debug stuff

  # ttui::logger::log "left_side:            ${left_side}"
  # ttui::logger::log "right_side:           ${right_side}"
  # ttui::logger::log "top_side:             ${top_side}"
  # ttui::logger::log "bottom_side:          ${bottom_side}"
  # ttui::logger::log "top_left_corner:      ${top_left_corner}"
  # ttui::logger::log "top_right_corner:     ${top_right_corner}"
  # ttui::logger::log "bottom_left_corner:   ${bottom_left_corner}"
  # ttui::logger::log "bottom_right_corner:  ${bottom_right_corner}"
  # ttui::logger::log "box sample:"
  # ttui::logger::log "${top_left_corner}${top_side}${top_side}${top_side}${top_side}${top_side}${top_side}${top_right_corner}"
  # ttui::logger::log "${left_side}      ${right_side}"
  # ttui::logger::log "${left_side}      ${right_side}"
  # ttui::logger::log "${bottom_left_corner}${bottom_side}${bottom_side}${bottom_side}${bottom_side}${bottom_side}${bottom_side}${bottom_right_corner}"

  # echo ${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[0]}
  # echo ${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[1]}
  # echo ${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[2]}
  # echo ${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[3]}
  # echo ${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[4]}
  # echo ${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[5]}
  # echo ${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[6]}
  
  ## insert mode:
  ## print empty lines to make room
  expand='{1..'"${height}"'}'
  rep="printf '%.0s\\n' ${expand}"
  ttui::logger::log "$rep"
  eval "${rep}"

  echo
  ttui::cursor::move_up $((height + 1))

  current_line=$(ttui::cursor::get_line force)
  ttui::cursor::move_to "${current_line}" "${anchor_column}"
  # top left corner
  printf '%s' "${top_left_corner}"

  # repeat top char width - 2 times (to account for corners)
  printf -vch  "%$((width - 2))s"
  printf '%s' "${ch// /$top_side}"
  
  # top right corner
  printf '%s' "${top_right_corner}"

  # local height_counter=1
  # printf " ${height_counter}"

  # left and right sides
  for (( r=1; r<=height - 2; r++ )); do 
    (( current_line++ ))
    ttui::cursor::move_to "${current_line}" "${anchor_column}"
    printf '%s' "${left_side}"
    ttui::cursor::move_right $((width - 2))
    printf '%s' "${right_side}"
  done

  ## move to bottom line of the box  
  (( current_line++ ))
  ttui::cursor::move_to "${current_line}" "${anchor_column}"

  ## draw bottom of box
  printf "${bottom_left_corner}"
  ## repeat bottom char width - 2 times (to account for corners)
  printf -vch  "%$((width - 2))s" ""
  printf "%s" "${ch// /$bottom_side}"
  printf '%s' "${bottom_right_corner}"
  echo

  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# >>>>> WIP -- DO ONT USE <<<<<<
#
# Draws box of specified width and height at the current cursor location 
# or from specified anchor point.
# Assumes space is available -- will overwrite pre-existings characters
# Globals:
#   ttui::cursor::get_column()
#   ttui::cursor::get_line()
#   ttui::cursor::move_right()
#   ttui::cursor::move_to()
#   ttui::cursor::move_up()
#   ttui::logger::log()
#   TTUI_WBORDER_SINGLE_SQUARED_LIGHT (array of border glyphs)
# Arguments:
#   $1  : width of box  (including border)
#   $2  : height of box (including border)
#  [$3] : left column (upper left corner location)
#  [$4] : top line   (upper left corner location)
# -----------------------------------------------------------------------------
ttui::draw::box_v2() {
  # width, height, upperLeftX, upperLeftY
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  ttui::logger::log "args received: $*"

  local left_column="none"
  local top_line="none"
  local right_column="none"
  local bottom_line="none"
  local width="none"
  local height="none"

  # left_column=$(ttui::cursor::get_column)
  # [[ $# -gt 2 ]] && {
  #   left_column=$3
  # }
  # ttui::logger::log "left_column: ${left_column}"

  # local top_line=$(ttui::cursor::get_line)
  # [[ $# -gt 3 ]] && {
  #   top_line="$4"
  # }
  # ttui::logger::log "top_line: ${top_line}"

  # process args
  for arg in "$@"; do

    [[ $# -lt 2 ]] && {
      ttui::utils::printerr "${FUNCNAME[0]}: unable to draw box: not enough property args provided to define box dimensions"
    }

    [[ $# == 2 && $1 != *"="* && $2 != *"="* ]] && {
      $(ttui::utils::is_uint $1) && $(ttui::utils::is_uint $2) && {
        # assume top left is current cursor position and that $1 and $2 are width and height
        width="$1"
        height="$2"
        # left_column=$(ttui::cursor::get_column)
        left_column=$(ttui::cursor::get_column)
        top_line=$(ttui::cursor::get_line)
        right_column=$((left_column + width - 1))
        bottom_line=$((top_line + height - 1))
        [[  $TTUI_LOGGING_ENABLED == true ]] && {
          ttui::logger::log "width:         ${width}"
          ttui::logger::log "height:        ${height}"
          ttui::logger::log "left_column:   ${left_column}"
          ttui::logger::log "top_line:      ${top_line}"
          ttui::logger::log "right_column:  ${right_column}"
          ttui::logger::log "bottom_line:   ${bottom_line}"
        }
        break # skip any further args processing
      }
      # if we get this far the arg must not be an unsigned integer and therefore invalid
      # TODO: log or print error
      break
    }
    
    # if we get to this point, we are expecting args to have the form PROPERTY=VALUE
    # process props
    local PROP=${arg%=*}
    local VAL=${arg#*=}
    
    # echo "$FUNCNAME --> PROP: $PROP | VAL:$VAL"
    # if $(ttui::utils::is_uint $_VAL); then
    #   echo "$_VAL is unsigned int"
    # else
    #   echo "$_VAL is NOT an unsigned int"
    # fi

    case ${PROP} in
      from)
        case $VAL in
          here)
            left_column=$(ttui::cursor::get_column)
            top_line=$(ttui::cursor::get_line)
            ;;
          *)
            local start_line=${VAL%","*}
            local start_col=${VAL#*","}
            $(ttui::utils::is_uint $top_line) && $(ttui::utils::is_uint $start_col) && {
              top_line=$start_line
              left_column=$start_col
            }
            # TODO: handle error -- value must be unsigned int
            ;;
        esac
        continue
        ;;
      to) 
        local end_line=${VAL%","*}
        local end_col=${VAL#*","}
        $(ttui::utils::is_uint $end_line) && $(ttui::utils::is_uint $end_col) && {
          bottom_line=$end_line
          right_column=$end_col
          continue
        }
        # TODO: handle error -- value must be unsigned int
        continue
        ;;
      width)
        $(ttui::utils::is_uint $VAL) && {
          width=$VAL
        }
        # TODO: handle error -- value must be unsigned int
        ;;
      height) 
        $(ttui::utils::is_uint $VAL) && {
            height=$VAL
          }
          # TODO: handle error -- value must be unsigned int
        ;;
      *) echo "Unknown parameter passed: ${PROP}"
          # exit 1
          ;;
    esac
  done

  local bottom_right_column=
  local bottom_right_line=

  local current_column=
  local current_line=

  #### debug info
  # echo "args:           $expanded_args"
  # echo "width:          $width"
  # echo "height:         $height"
  # echo "left_column:    $left_column"
  # echo "top_line:       $top_line"
  # echo "ttui::cursor::get_line from_cache --> $(ttui::cursor::get_line from_cache)"
  # echo -n "col=\$(ttui::cursor::get_column) --> col: "
  # local col=$(ttui::cursor::get_column)
  # echo "$col"
  # echo "TTUI_CURRENT_COLUMN: $TTUI_CURRENT_COLUMN"
  # echo "TTUI_CURRENT_LINE:   $TTUI_CURRENT_LINE"
  # echo -n "ttui::cursor::get_line from_cache --> "
  # ttui::cursor::get_line from_cache
  # echo "TTUI_CURRENT_LINE:   $TTUI_CURRENT_LINE"
  # compgen -A variable

  ## wborder params
  ## 	0. ls: character to be used for the left side of the window 
  ## 	1. rs: character to be used for the right side of the window 
  ## 	2. ts: character to be used for the top side of the window 
  ## 	3. bs: character to be used for the bottom side of the window 
  ## 	4. tl: character to be used for the top left corner of the window 
  ## 	5. tr: character to be used for the top right corner of the window 
  ## 	6. bl: character to be used for the bottom left corner of the window 
  ## 	7. br: character to be used for the bottom right corner of the window
  
  ## insert mode:
  ## print empty lines to make room
  # expand='{1..'"${height}"'}'
  # rep="printf '%.0s\\n' ${expand}"
  # ttui::logger::log "$rep"
  # eval "${rep}"

  # echo
  # ttui::cursor::move_up $((height + 1))

  ttui::cursor::move_to "${top_line}" "${left_column}"

  # current_line=$(ttui::cursor::get_line)
  # ttui::cursor::move_to "${current_line}" "${left_column}"
  
  # top left corner
  ttui::draw::corner topleft

  # top line
  ttui::cursor::move_right
  ttui::draw::horizontal_line from=here to=right length=$((width - 1))
  
  # top right corner
  ttui::draw::corner topright

  # draw right side
  ttui::cursor::move_down  
  ttui::draw::vertical_line from=here to=down length=$((height - 1))

  # bottom right corner
  ttui::draw::corner bottomright

  # bottom line
  ttui::cursor::move_left
  ttui::draw::horizontal_line from=here to=left length=$((width - 1))

  # bottom left corner
  ttui::draw::corner bottomleft

  # left side
  ttui::cursor::move_up
  ttui::draw::vertical_line from=here to=up length=$((height - 2))  
  
  # move cursor to anchor/origin cell as ending position
  ttui::cursor::move_up

  printf '*' # debug marker

  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


# -----------------------------------------------------------------------------
# Draws corner glyph
# Globals:
#   TBD
#   TTUI_WBORDER_SINGLE_SQUARED_LIGHT (array of border glyphs)
# Arguments:
#   tl | topleft | tr | topright | bl | bottomleft | br | bottomright
#   type=<tl | topleft | tr | topright | bl | bottomleft | br | bottomright>
#  [corner=<square|round>]
#  [style=<singleline>]
#  [weight=<light>]
# -----------------------------------------------------------------------------
#   TODO: add support for coordinates
#   TODO: add support for colors
# -----------------------------------------------------------------------------
ttui::draw::corner() {
  local TYPE="unspecified"  # "orientation" is prob more accurate term but too long for user to type
  local TYPE_IS_SET=false
  local STYLE="singleline"
  local CORNER="square"
  local WEIGHT="light"
  local GLYPH="none"

  local top_left_corner=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[4]}
  local top_right_corner=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[5]}
  local bottom_left_corner=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[6]}
  local bottom_right_corner=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[7]}

  # process prop arguments
  for arg in "$@"; do
    
    [[ "${arg}" != *"="* ]] && {
      # assume this must be the orientation / TYPE if no '=' is found
      TYPE="${arg}"
      continue
    }

    # if we get to this point, we are expecting args to have the form PROPERTY=VALUE
    local PROP=${arg%=*}
    local VAL=${arg#*=}
    
    # echo "$FUNCNAME --> PROP: $PROP | VAL:$VAL"
    # if $(ttui::utils::is_uint $_VAL); then
    #   echo "$_VAL is unsigned int"
    # else
    #   echo "$_VAL is NOT an unsigned int"
    # fi

    case ${PROP} in
        type)
            # case $VAL in
            #     topleft | tl | upperleft | ul)
            #         TYPE="topleft"
            #         ;;
            #     topright | tr | upperright | ur)
            #         TYPE="topright"
            #         ;;
            #     bottomleft | bl | lowerleft | ll)
            #         TYPE="bottomleft"
            #         ;;
            #     bottomright | br | lowerright | lr)
            #         TYPE="bottomright"
            #         ;;
            #     *) # unrecognized type
            # esac
            TYPE=$VAL
            ;;
        style) 
            STYLE=$VAL
            ;;
        weight)
            WEIGHT=$VAL
            ;;
        corner) 
            CORNER=$VAL
            ;;
        *) ttui::utils::printerr "${FUNCNAME}: Unknown parameter passed: ${PROP}"
            # exit 1
            ;;
    esac
  done


  # assign appropriate glyph based on TYPE property
  case $TYPE in
      topleft | tl | upperleft | ul)
          [[ $STYLE == "singleline" && $WEIGHT == "light" && $CORNER == "square" ]] && {
            GLYPH=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[4]}
          }
          TYPE_IS_SET=true
          ;;
      topright | tr | upperright | ur)
          [[ $STYLE == "singleline" && $WEIGHT == "light" && $CORNER == "square" ]] && {
            GLYPH=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[5]}
          }
          TYPE_IS_SET=true
          ;;
      bottomleft | bl | lowerleft | ll)
          [[ $STYLE == "singleline" && $WEIGHT == "light" && $CORNER == "square" ]] && {
            GLYPH=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[6]}
          }
          TYPE_IS_SET=true
          ;;
      bottomright | br | lowerright | lr)
          [[ $STYLE == "singleline" && $WEIGHT == "light" && $CORNER == "square" ]] && {
            GLYPH=${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[7]}
          }
          TYPE_IS_SET=true
          ;;
      # *)  # unrecognized type
      #     ;;
  esac

  # abort if type is not set
  [[ $TYPE_IS_SET == false ]] && {
    ttui::utils::printerr "${FUNCNAME}: unable to print corner.  valid TYPE must be specified in order for corner glyph to be determined"
    return 1
  }

  # print the corner glyph
  printf "${GLYPH}"
  
  # move cursor back over the printed glyph
  ttui::cursor::move_left

}


# -----------------------------------------------------------------------------
# Draws horizontal line
# Globals:
#   TBD
#   TTUI_WBORDER_SINGLE_SQUARED_LIGHT (array of border glyphs)
# Arguments:
#   TBD
# -----------------------------------------------------------------------------
#   col#                        draws from current position to specified col# on current line
#   from=here to=col#           draws from current position to specified col# on current line
#   at=line# from=col# to-col#  draws from specified col to specified col at specified line
#   from=col# to=right len=40   draws from specified col specified length to the right 
#   inclusive=false             does not draw at current coordinate (starts printing at the next line or column)
#
#   ttui::draw::horizontal_line from=here to=42
# -----------------------------------------------------------------------------
#   TODO: add support for line weights
#   TODO: refactor line drawing to always be to the right (for simplicity)
# -----------------------------------------------------------------------------
ttui::draw::horizontal_line() {
  local start_col=
  local end_col=
  local line=
  local LINE_NOT_SPECIFIED=true
  local use_direction=false
  local direction=
  local length=
  local is_inclusive=true
  local step=1

  # echo "args: $@"

  for arg in "$@"; do

    [[ $# == 1 ]] && {
      $(ttui::utils::is_uint $arg) && {
        # assume we are moving from current col to a specified col# since no '=' is found
        start_col=$(ttui::cursor::get_column)
        end_col="${arg}"
        break
      }
      # if we get this far the arg must not be a unit and therefore invalid
      # TODO: log or print error
      break
    }
    
    # if we get to this point, we are expecting args to have the form PROPERTY=VALUE
    # process props
    local PROP=${arg%=*}
    local VAL=${arg#*=}
    
    # echo "$FUNCNAME --> PROP: $PROP | VAL:$VAL"
    # if $(ttui::utils::is_uint $_VAL); then
    #   echo "$_VAL is unsigned int"
    # else
    #   echo "$_VAL is NOT an unsigned int"
    # fi

    case ${PROP} in
            from)
              case $VAL in
                here)
                  start_col=$(ttui::cursor::get_column)
                  ;;
                *)
                  $(ttui::utils::is_uint $VAL) && {
                    start_col=$VAL
                  }
                  # TODO: handle error -- value must be unsigned int
                  ;;
              esac
              continue
              ;;
            to) 
              case $VAL in
                left)
                  use_direction=true
                  direction="left"
                  ;;
                right)
                  use_direction=true
                  direction="right"
                  ;;
                *)
                  $(ttui::utils::is_uint $VAL) && {
                    end_col=$VAL
                  }
                  # TODO: handle error -- value must be unsigned int
                  ;;
              esac
              continue
              ;;
            at)
              $(ttui::utils::is_uint $VAL) && {
                LINE_NOT_SPECIFIED=false
                line=$VAL
              }
              # TODO: handle error -- value must be unsigned int
              ;;
            length) 
                $(ttui::utils::is_uint $VAL) && {
                    length=$VAL
                  }
                  # TODO: handle error -- value must be unsigned int
                ;;
            inclusive)
              case $VAL in
                true)
                  is_inclusive=true
                  ;;
                false)
                  is_inclusive=false
                  ;;
                  # TODO: handle unknown value error
                # *) # handle error
              esac
              continue
              ;;
            *) echo "Unknown parameter passed: ${PROP}"
                # exit 1
                ;;
    esac
  done

  [[ $LINE_NOT_SPECIFIED == true ]] && {
    line=$(ttui::cursor::get_line)
  }

  [[ $use_direction == true ]] && {
    if $(ttui::utils::is_uint $length); then
      if [[ $direction == "right" ]]; then
        (( end_col = start_col + length - 1 ))
        # echo "end_col = start_col + length - 1: $end_col"
        local TERM_WIDTH=$(ttui::get_term_width)
        [[ $end_col -gt $TERM_WIDTH ]] && end_col=$TERM_WIDTH
      else
        # left
        (( end_col = start_col - length + 1 ))
        [[ $end_col -lt 1 ]] && end_col=1
      fi
    else
      #error
      echo "length must be unsigned int" 2>/dev/null # throwing this away for now
    fi
  }

  # draw line
  if [[ end_col -lt start_col ]]; then
    # draw towards left
    for ((col = start_col; col >= end_col; col--)); do
      ttui::cursor::move_to $line $col
      printf "${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[2]}"
    done
    
  else
    # draw towards right
    for ((col = start_col; col <= end_col; col++)); do
      ttui::cursor::move_to $line $col
      printf "${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[2]}"
    done
  fi
  
  # place cursor back onto the logical ending position
  ttui::cursor::move_left 
  
  # echo
  # ttui::cursor::move_down
  # ttui::cursor::move_left 999
  # echo "start_col: ........  ${start_col}"
  # echo "end_col: ..........  ${end_col}"
  # echo "line: .............  ${line}"
  # echo "LINE_NOT_SPECIFIED:  ${LINE_NOT_SPECIFIED}"
  # echo "direction: ........  ${direction}"
  # echo "length: ...........  ${length}"
  # echo "is_inclusive: .....  ${is_inclusive}"
  # echo "step: .............  ${step}"

}


# -----------------------------------------------------------------------------
# Draws tick marks as ruler along the horizontal axis
# Globals:
#   TTUI_HORIZONTAL_RULER_TICK
# Arguments:
#   TBD
# -----------------------------------------------------------------------------
ttui::draw::horizontal_ruler() {
  local TERM_WIDTH=$(ttui::get_term_width force)
  local counter=1
  for ((i=0; i < TERM_WIDTH; i++)); do
    if [[ ${counter} == 10 ]]; then
      echo -n "${TTUI_HORIZONTAL_RULER_TICK}"
      counter=1
    else
      echo -n ' '
      (( counter++ ))
    fi
  done
  echo
}



# -----------------------------------------------------------------------------
# Draws vertical line
# Globals:
#   TBD
#   TTUI_WBORDER_SINGLE_SQUARED_LIGHT (array of border glyphs)
# Arguments:
#   TBD
# -----------------------------------------------------------------------------
#   col#                        draws from current position to specified col# on current line
#   from=here to=col#           draws from current position to specified col# on current line
#   at=line# from=col# to-col#  draws from specified col to specified col at specified line
#   from=col# to=right len=40   draws from specified col specified length to the right 
#   inclusive=false             does not draw at current coordinate (starts printing at the next line or column)
#
#   ttui::draw::horizontal_line from=here to=42
# -----------------------------------------------------------------------------
#   TODO: add support for line weights
#   TODO: refactor line drawing to always be to the right (for simplicity)
# -----------------------------------------------------------------------------
ttui::draw::vertical_line() {
  local start_line=
  local end_line=
  local column=
  local COL_NOT_SPECIFIED=true
  local use_direction=false
  local direction="auto"
  local length="auto"
  local is_inclusive=true
  local step=1
  local GLYPH="${TTUI_WBORDER_SINGLE_SQUARED_LIGHT[0]}"

  for arg in "$@"; do

    [[ $# == 1 ]] && {
      $(ttui::utils::is_uint $arg) && {
        # assume we are moving from current line to a specified line# since no '=' is found
        start_line=$(ttui::cursor::get_line)
        end_line="${arg}"
        break
      }
      # if we get this far the arg must not be a unsigned int and therefore invalid
      # TODO: log or print error
      break
    }
    
    # if we get to this point, we are expecting args to have the form PROPERTY=VALUE
    # process props
    local PROP=${arg%=*}
    local VAL=${arg#*=}
    
    # echo "$FUNCNAME --> PROP: $PROP | VAL:$VAL"
    # if $(ttui::utils::is_uint $_VAL); then
    #   echo "$_VAL is unsigned int"
    # else
    #   echo "$_VAL is NOT an unsigned int"
    # fi

    case ${PROP} in
            from)
              case $VAL in
                here)
                  start_line=$(ttui::cursor::get_line)
                  ;;
                *)
                  $(ttui::utils::is_uint $VAL) && {
                    start_line=$VAL
                  }
                  # TODO: handle error -- value must be unsigned int
                  ;;
              esac
              continue
              ;;
            to) 
              case $VAL in
                up)
                  use_direction=true
                  direction="up"
                  ;;
                down)
                  use_direction=true
                  direction="down"
                  ;;
                *)
                  $(ttui::utils::is_uint $VAL) && {
                    end_line=$VAL
                  }
                  # TODO: handle error -- value must be unsigned int
                  ;;
              esac
              continue
              ;;
            at)
              $(ttui::utils::is_uint $VAL) && {
                COL_NOT_SPECIFIED=false
                column=$VAL
              }
              # TODO: handle error -- value must be unsigned int
              ;;
            length) 
                $(ttui::utils::is_uint $VAL) && {
                    length=$VAL
                  }
                  # TODO: handle error -- value must be unsigned int
                ;;
            inclusive)
              case $VAL in
                true)
                  is_inclusive=true
                  ;;
                false)
                  is_inclusive=false
                  ;;
                  # TODO: handle unknown value error
                # *) # handle error
              esac
              continue
              ;;
            *) echo "Unknown parameter passed: ${PROP}"
                # exit 1
                ;;
    esac
  done

  [[ $COL_NOT_SPECIFIED == true ]] && {
    column=$(ttui::cursor::get_column)
  }

  [[ $use_direction == true ]] && {
    if $(ttui::utils::is_uint $length); then
      if [[ $direction == "down" ]]; then
        (( end_line = start_line + length - 1 ))
        local TERM_HEIGHT=$(ttui::get_term_height)
        [[ $end_line -gt $TERM_HEIGHT ]] && end_line=$TERM_HEIGHT
      else
        # up
        (( end_line = start_line - length + 1 ))
        [[ $end_line -lt 1 ]] && end_line=1
      fi
    else
      #error
      echo "length must be unsigned int" 2>/dev/null # throwing this away for now
    fi
  }

  #### a few debug values used during dev
  # ttui::cursor::move_to_bottom
  # DEBUG_START_LINE=$(( $(ttui::cursor::get_line) - 8))
  # DEBUG_START_COL=80
  # ttui::cursor::move_to $DEBUG_START_LINE $DEBUG_START_COL
  # echo -n "start_line: .........  ${start_line}"
  # ttui::cursor::move_to $((DEBUG_START_LINE + 1)) $DEBUG_START_COL
  # echo -n "end_line: ...........  ${end_line}"
  # ttui::cursor::move_to $((DEBUG_START_LINE + 2)) $DEBUG_START_COL
  # echo -n "column: .............  ${column}"
  # ttui::cursor::move_to $((DEBUG_START_LINE + 3)) $DEBUG_START_COL
  # echo -n "COL_NOT_SPECIFIED: ..  ${COL_NOT_SPECIFIED}"
  # ttui::cursor::move_to $((DEBUG_START_LINE + 4)) $DEBUG_START_COL
  # echo -n "use_direction: ......  ${use_direction}"
  # ttui::cursor::move_to $((DEBUG_START_LINE + 5)) $DEBUG_START_COL
  # echo -n "direction: ..........  ${direction}"
  # ttui::cursor::move_to $((DEBUG_START_LINE + 6)) $DEBUG_START_COL
  # echo -n "length: .............  ${length}"
  # ttui::cursor::move_to $((DEBUG_START_LINE + 7)) $DEBUG_START_COL
  # echo -n "is_inclusive: .......  ${is_inclusive}"
  # ttui::cursor::move_to $((DEBUG_START_LINE + 8)) $DEBUG_START_COL
  # echo -n "step: ...............  ${step}"
  # ttui::cursor::move_to_bottom
  # ttui::cursor::move_left 999
  ####

  # draw line
  if [[ end_line -lt start_line ]]; then
    # draw upward
    for ((line = start_line; line >= end_line; line--)); do
      ttui::cursor::move_to $line $column
      printf "${GLYPH}"
    done
    
  else
    # draw downward
    for ((line = $start_line; line <= $end_line; line++)); do
      ttui::cursor::move_to $line $column
      printf "${GLYPH}"
    done
  fi
  
  # place cursor back onto the logical ending position
  ttui::cursor::move_left



}



ttui::initialize() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  echo "${FUNCNAME[0]} --> initializing"
  echo "TTUI_SHOULD_USE_WHOLE_TERM_WINDOW: ${TTUI_SHOULD_USE_WHOLE_TERM_WINDOW}"
  [[ TTUI_SHOULD_USE_WHOLE_TERM_WINDOW == true ]] && ttui::save_terminal_screen
  ttui::get_term_size
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
}


ttui::handle_exit() {
  
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  
  ttui::logger::log  "cleaning up before exit"
  
  # ttui::color::reset
  ttui::logger::log  "TTUI_SCROLL_AREA_CHANGED: ${TTUI_SCROLL_AREA_CHANGED}"
  [[ $TTUI_SCROLL_AREA_CHANGED == true ]] && ttui::restore_scroll_area

  ttui::logger::log  "TTUI_SHOULD_USE_WHOLE_TERM_WINDOW: ${TTUI_SHOULD_USE_WHOLE_TERM_WINDOW}"
  [[ $TTUI_SHOULD_USE_WHOLE_TERM_WINDOW == true ]] && ttui::restore_terminal_screen
  
  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"

  local TIMESTAMP_AT_EXIT=`date +"%Y-%m-%d %T"`
  ttui::logger::log "Exiting at ${TIMESTAMP_AT_EXIT}"
}


# -----------------------------------------------------------------------------
# Enables debug logs.
# Globals:
#   ttui_debug_logs_enabled
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::logger::enable_logging() {
  TTUI_LOGGING_ENABLED=true
  ttui::logger::log "debug mode enabled"
}


# -----------------------------------------------------------------------------
# Disables debug logs.
# Globals:
#   ttui_debug_logs_enabled
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::logger::disable_logging() {
  TTUI_LOGGING_ENABLED=false
}


# -----------------------------------------------------------------------------
# Print debug messages if debug mode is enabled.
# Globals:
#   ttui_debug_logs_enabled
# Arguments:
#   message
# -----------------------------------------------------------------------------
ttui::logger::log() {
  [[ "${TTUI_LOGGING_ENABLED}" == false ]] && return
  [[ "${TTUI_THIS_IS_FIRST_LOG}" == true ]] && {
    echo " " >> "${TTUI_LOG_FILENAME}"
    echo "-------------------------------------------------------------------------------" >> "${TTUI_LOG_FILENAME}"
    echo "  LAUNCHED      ${TIMESTAMP_AT_LAUNCH}" >> "${TTUI_LOG_FILENAME}"
    echo "-------------------------------------------------------------------------------" >> "${TTUI_LOG_FILENAME}"
    echo " " >> "${TTUI_LOG_FILENAME}"
    TTUI_THIS_IS_FIRST_LOG=false
    }
  local caller="${FUNCNAME[1]}"
  local self="${FUNCNAME[0]}"
  local message="$1"
  [[ "$#" == 0 ]] && message="no message argument provided to ${self}"
  echo "[ ${caller} ]--> ${message}" >> "${TTUI_LOG_FILENAME}"
}



# -----------------------------------------------------------------------------
# prints current epoch time in milliseconds
# (milliseconds since Unix epoch January 1 1970)
# Globals:
#   none
# Arguments:
#   none
# Dependancies:
#   perl
# -----------------------------------------------------------------------------
ttui::utils::epoch_time_ms() {
  perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000)'
}


# -----------------------------------------------------------------------------
# returns code 0 if arg is a float
# Globals:
#   none
# Arguments:
#   $1) value to be tested
# -----------------------------------------------------------------------------
ttui::utils::is_float() { 
  case ${1#[-+]} in 
    '' | . | *[!0-9.]* | *.*.* ) 
      return 1
      ;; 
    *[0-9]*.*[0-9])
      return 0
      ;;
  esac
  return 1
}


# -----------------------------------------------------------------------------
# returns code 0 if arg is an integer
# Globals:
#   none
# Arguments:
#   $1) value to be tested
# -----------------------------------------------------------------------------
ttui::utils::is_int() { 
  case ${1#[-+]} in 
    ''|*[!0-9]*) 
      return 1
      ;;
  esac
}


# -----------------------------------------------------------------------------
# returns code 0 if arg is a number
# Globals:
#   none
# Arguments:
#   $1) value to be tested
# -----------------------------------------------------------------------------
ttui::utils::is_num()  { 
  case ${1#[-+]} in 
    '' | . | *[!0-9.]* | *.*.* ) 
    return 1
    ;; 
  esac
}


# -----------------------------------------------------------------------------
# returns code 0 if arg is an unsigned float
# Globals:
#   none
# Arguments:
#   $1) value to be tested
# -----------------------------------------------------------------------------
ttui::utils::is_ufloat() { 
  case $1 in 
    '' | . | *[!0-9.]* | *.*.* ) 
      return 1
      ;; 
    *[0-9]*.*[0-9])
      return 0
      ;;
  esac
  return 1
}


# -----------------------------------------------------------------------------
# returns code 0 if arg is an unsigned integer
# Globals:
#   none
# Arguments:
#   $1) value to be tested
# -----------------------------------------------------------------------------
#   Example usage:
#   
#   VAR=1000
#   $(ttui::util::is_uint $VAR) && echo "$VAR is an unsigned integer"
#   # OUTPUT --> 1000 is an unsigned integer
#
#   NUM_ARGS=2
#   VAR=1234
#   [[ $NUM_ARGS == 2 ]] && $(ttui::util::is_uint $VAR) && echo "$VAR is an unsigned integer"
#   # OUTPUT --> 1234 is an unsigned integer
#
#   BASH_IS_NIFTY=true
#   VAR=42
#   [[ $BASH_IS_NIFTY == true && $(ttui::util::is_uint $VAR) == 0 ]] && echo "$VAR is an unsigned integer"
#   # OUTPUT --> 42 is an unsigned integer
#
#   VAR="blahblah"
#   if $(is_uint $VAR); then
#     echo "$VAR is an unsigned integer"
#   else
#     echo "$VAR is NOT an unsigned integer"
#   fi
#   # OUTPUT --> blahblah is NOT an unsigned integer
# -----------------------------------------------------------------------------
ttui::utils::is_uint() { 
  case $1 in 
    ''|*[!0-9]*)
      return 1
      ;;
  esac
}


# -----------------------------------------------------------------------------
# returns code 0 if arg is an unsigned number
# Globals:
#   none
# Arguments:
#   $1) value to be tested
# -----------------------------------------------------------------------------
ttui::utils::is_unum() {
  case $1 in 
    ''|.|*[!0-9.]*|*.*.*) 
      return 1
      ;; 
  esac
}


# -----------------------------------------------------------------------------
#   prints to stderr
# Globals:
#   none
# Arguments:
#   *) string(s) to be printed to stderr
# -----------------------------------------------------------------------------
ttui::utils::printerr() {
	echo $@ >&2
}


# -----------------------------------------------------------------------------
#   TTUI LOADED
#   can be referenced in order to confirm that ttui is loaded
# -----------------------------------------------------------------------------
TTUI_LOADED=true