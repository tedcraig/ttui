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


# ttui::log() {
  
# }

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
  [[ "$1" == "force" ]] && {
    ttui::get_term_size
  }
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
  [[ "$1" == "force" ]] && {
    ttui::get_term_size
  }
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
  ttui::logger::log "$# arguments received"
  local expanded_args=$(echo "$@")
  ttui::logger::log "args received: $expanded_args"
  
  # save the current/default IFS delimeter(s) in order to restore later
  local old_ifs="$IFS"
  
  # assign line and column nums -------------------------------------------------
  #   if more than one arg exists, then try to assign values to variables
  #   of the same name.
  #   else assign values to default global variable.
  if [[ $# -gt 1 ]]; then
    ttui::logger::log "1st arg found: $1"
    ttui::logger::log "2nd arg found: $2"
    # check if the string value of myVar is the name of a declared variable
    local lineVarName="$1"
    local bLineVarExists=false
    local test='if ${'"${lineVarName}"'+"false"}; then ttui::logger::log "${lineVarName} not defined"; else bLineVarExists=true; ttui::logger::log "${lineVarName} is defined"; fi'
    ttui::logger::log "test: $test"
    eval $test
    ttui::logger::log  "bLineVarExists: ${bLineVarExists}"

    local columnVarName="$2"
    local bColumnVarExists=false
    local test='if ${'"${columnVarName}"'+"false"}; then ttui::logger::log "${columnVarName} not defined"; else bColumnVarExists=true; ttui::logger::log "${columnVarName} is defined"; fi'
    ttui::logger::log "test: $test"
    eval $test
    ttui::logger::log  "bColumnVarExists: ${bColumnVarExists}"

    if [[ $bLineVarExists == true ]] && [[ $bColumnVarExists == true ]]; then
      local assignment="IFS='[;' read -p $'\e[6n' -d R -rs _ ${lineVarName} ${columnVarName}"
      #                 \______/ \__/ \_________/ \__/ \_/ \___________________________/
      #                    |      |       |        |    |                |
      #                    |      |       |        |    |  Variables to receive output of read,
      #                    |      |       |        |    |  as parsed by the IFS delimeters.
      #                    |      |       |        |    |  ^[ThrowAway[Lines;ColumnsR
      #                    |      |       |        |    |  var:  -
      #                    |      |       |        |    |     receives superfluous value
      #                    |      |       |        |    |     parsed between [ and [
      #                    |      |       |        |    |  var:  LINE_NUM_VAR
      #                    |      |       |        |    |     receives line number value
      #                    |      |       |        |    |     parsed between [ and ;
      #                    |      |       |        |    |  var:  COLUMN_NUM_VAR
      #                    |      |       |        |    |     receives column number value
      #                    |      |       |        |    |     parsed between ; and R
      #                    |      |       |        |     \
      #                    |      |       |        |  Do not treat a Backslash as an escape character.
      #                    |      |       |        |  Silent mode: any characters input from the terminal
      #                    |      |       |        |  are not echoed.
      #                    |      |       |        |
      #                    |      |       |  Terminates the input line at R rather than at newline 
      #                    |      |       |
      #                    |      |  Prints '\e[6n' as prompt to console.
      #                    |      |  This term command escape code is immediately interpted, generating
      #                    |      |  response code containing the line and column position
      #                    |      |  in format: ^[[1;2R  (where num at position 1 is the line number
      #                    |      |  and num at position 2 is the column number). This response string
      #                    |      |  becomes the input of the read command.
      #                    |      |
      #                    |  Read input from console
      #                    |
      #                  Overrides default delimeters for output of the read.
      #                  Will capture values between [ and/or ; chars
      ttui::logger::log  "assignment: ${assignment}"
      eval $assignment
    else
      echo "${FUNCNAME[0]} --> warning: cannot assign cursor position values to provided var names: ${lineVarName} and/or ${columnVarName}: undelcared or invalid variable"
    fi
  else
    ttui::logger::log "no var name provided. Assigning cursor position values to global vars TTUI_CURRENT_LINE TTUI_CURRENT_COLUMN"
    IFS='[;' read -p $'\e[6n' -d R -rs _ TTUI_CURRENT_LINE TTUI_CURRENT_COLUMN
  fi
  
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
#   $1) force - if string "force" is received, cursor::get_position will be called
#               before echoing result
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
#   $1) force - if string "force" is received, cursor::get_position will be called
#               before echoing result
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
# Draws horizontal line
# or from specified anchor point.
# Globals:
#   TBD
#   ttui::cursor::get_column()
#   ttui::cursor::get_line()
#   ttui::cursor::move_right()
#   ttui::cursor::move_to()
#   ttui::logger::log()
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
ttui::draw::horizontal_line() {
  local _dhl_start_col=
  local _dhl_end_col=
  local _dhl_line=
  local _dhl_LINE_NOT_SPECIFIED=true
  local _dhl_direction=
  local _dhl_length=
  local _dhl_is_inclusive=true

  for arg in "$@"; do

    [[ $# == 1 ]] && {
      $(ttui::utils::is_unit $arg) && {
        # assume we are moving from current col to a specified col# since no '=' is found
        _dhl_start_col=$(ttui::cursor::get_column)
        _dhl_end_col="${arg}"
        break
      }
      # if we get this far the arg must not be a unit and therefore invalid
      # TODO: log or print error
      break
    }
    
    # if we get to this point, we are expecting args to have the form PROPERTY=VALUE
    # process props
    local _PROP=${arg%=*}
    local _VAL=${arg#*=}
    echo "$FUNCNAME --> PROP: $_PROP | VAL:$_VAL"
    echo "is_uint($_VAL): $(ttui::utils::is_uint $_VAL)"
    case ${_PROP} in
            from)
              echo "prop 'from' found"
              case $_VAL in
                here)
                  _dhl_start_col=$(ttui::cursor::get_column)
                  ;;
                *)
                  echo "  should be number"
                  $(ttui::utils::is_uint $arg) && {
                    echo "  is a number: $arg"
                    _dhl_start_col=$arg
                  }
                  # TODO: handle error -- value must be unsigned int
                  ;;
              esac
              continue
              ;;
            to) 
              echo "prop 'to' found"
              case $_VAL in
                left)
                  _dhl_direction="left"
                  ;;
                right)
                  _dhl_direction="right"
                  ;;
                *)
                  $(ttui::utils::is_uint $arg) && {
                    _dhl_end_col=$arg
                  }
                  # TODO: handle error -- value must be unsigned int
                  ;;
              esac
              continue
              ;;
            length) 
                $(ttui::utils::is_uint $arg) && {
                    _dhl_length=$arg
                  }
                  # TODO: handle error -- value must be unsigned int
                ;;
            inclusive)
              case $_VAL in
                true)
                  _dhl_is_inclusive=true
                  ;;
                false)
                  _dhl_is_inclusive=false
                  ;;
                  # TODO: handle unknown value error
                # *) # handle error
              esac
              continue
              ;;
            *) echo "Unknown parameter passed: ${_PROP}"
                # exit 1
                ;;
    esac
  done

  [[ $_dhl_LINE_NOT_SPECIFIED == true ]] && {
    _dhl_line=$(ttui::cursor::get_line)
  }
  
  echo "_dhl_start_col: ........  ${_dhl_start_col}"
  echo "_dhl_end_col: ..........  ${_dhl_end_col}"
  echo "_dhl_line: .............  ${_dhl_line}"
  echo "_dhl_LINE_NOT_SPECIFIED:  ${_dhl_LINE_NOT_SPECIFIED}"
  echo "_dhl_direction: ........  ${_dhl_direction}"
  echo "_dhl_length: ...........  ${_dhl_length}"
  echo "_dhl_is_inclusive: .....  ${_dhl_is_inclusive}"

}


# -----------------------------------------------------------------------------
# 
# Globals:
#   TBD
# Arguments:
#   TBD
# -----------------------------------------------------------------------------





ttui::draw::vertical_line() {
  # here to line#
  # line# to line#
  echo bash doesnt allow functions with no statements
}


ttui::draw::box() {
  ttui::draw_box $@
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
ttui::draw_box() {
  # width, height, upperLeftX, upperLeftY
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  ttui::logger::log "$# arguments received"
  local expanded_args=$(echo "$@")
  ttui::logger::log "args received: $expanded_args"

  local width="$1"
  ttui::logger::log "width:  ${width}"

  local height="$2"
  ttui::logger::log "height: ${height}"

  local anchor_column=$(ttui::cursor::get_column force)
    [[ $# -gt 2 ]] && {
      anchor_column=$3
    }
  ttui::logger::log "anchor_column: ${anchor_column}"

  local anchor_line=$(ttui::cursor::get_line) # no need for 'force' here since we already forced get_column
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
  printf "${top_left_corner}"

  # repeat top char width - 2 times (to account for corners)
  printf -vch  "%$((width - 2))s" ""
  printf "%s" "${ch// /$top_side}"
  
  # top right corner
  printf "${top_right_corner}"

  # local height_counter=1
  # printf " ${height_counter}"

  # left and right sides
  for (( r=1; r<=height - 2; r++ )); do 
    (( current_line++ ))
    ttui::cursor::move_to "${current_line}" "${anchor_column}"
    printf "${left_side}"
    ttui::cursor::move_right $((width - 2))
    printf "${right_side}"
  done

  ## move to bottom line of the box  
  (( current_line++ ))
  ttui::cursor::move_to "${current_line}" "${anchor_column}"

  ## draw bottom of box
  printf "${bottom_left_corner}"
  ## repeat bottom char width - 2 times (to account for corners)
  printf -vch  "%$((width - 2))s" ""
  printf "%s" "${ch// /$bottom_side}"
  printf "${bottom_right_corner}"
  echo

  ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
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


# # -----------------------------------------------------------------------------
# # ** Removed -- do NOT use! *********************
# # ** code retained for reference purposes only **
# # ***********************************************
# # Converts LCH color values to RGB values. *** SLOW !!! ***
# # If optional variable name argument is provided, resulting RGB values will be 
# # assigned as an array (R,G,B) to variable matching the provided name.  If 
# # optional variable name argument is not used then resulting RGB value will be
# # assigned as an array (R,G,B) to global variable TTUI_COLOR_RGB_FROM_LCH.
# # Globals:
# #   TTUI_COLOR_RGB_FROM_LCH
# # Arguments:
# #   position 1:  LCH lightness value (0-100)
# #   position 2:  LCH chroma    value (0-132)
# #   position 3:  LCH hue       value (0-360)
# #  [position 4:] name of existing variable to which result should be assigned
# # Dependancies:
# #   awk
# # -----------------------------------------------------------------------------
# ttui::color::get_rgb_from_lch_old() {
#   # color conversion equations from:
#   # avisek/colorConversions.js
#   # https://gist.github.com/avisek/eadfbe7a7a169b1001a2d3affc21052e
#   #
#   # checked sanity of results using:
#   # https://www.easyrgb.com/en/convert.php#inputFORM
#   #
#   # LCH color picker:
#   # https://css.land/lch/

#   ##########  TODO:
#   ##########  check that args in position 1, 2, 3 are numbers 
#   ##########  and that they are within the legal range for their
#   ##########  respective LCH value:
#   ##########    position 1:  LCH lightness value (0-100)
#   ##########    position 2:  LCH chroma    value (0-132)
#   ##########    position 3:  LCH hue       value (0-360)
  
#   ##########  TODO:
#   ##########  refactor to reduce awk invocations.
#   ##########  maybe introduce function calls within awk to reduce code repetition
#   ##########  (unless that is less performant)
#   ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
#   ttui::logger::log "$# arguments received"
#   local expanded_args=$(echo "$@")
#   ttui::logger::log "args received: $expanded_args"
  
#   # assign positional args 1,2,3 as prospective LCH values
#   local LCH_L=$1
#   local LCH_C=$2
#   local LCH_H=$3

#   local LAB_L=
#   local LAB_A=
#   local LAB_B=

#   local XYZ_X=
#   local XYZ_Y=
#   local XYZ_Z=

#   local RGB_R=
#   local RGB_G=
#   local RGB_B=

#   # TODO: validate that 3 numbers have been provided and that they are within legal range

#   # isNumber=`eval '[[ '$"${varName}"' =~ ^[+-]?[0-9]+$ ]]'`
#   # if $isNumber; then echo "it's a number!"; else echo "it's not a number"; fi

#   # if [[ eval $myVar =~ ^[+-]?[0-9]+$ ]]; then
#   #   echo "Number!" 
#   # elif [[ eval $myVar =~ ^[+-]?[0-9]*\.[0-9]+$ ]]; then
#   #   echo "Float!"
#   # elif [[ eval $myVar =~ [0-9] ]]; then
#   #   echo "Mixed, some numbers"
#   # else
#   #   echo "No numbers!"
#   # fi  

#   ttui::logger::log "lch --> L: $LCH_L | C: $LCH_C | H: $LCH_H"

#   # lchToLab ------------------------------------------------------------------
#   ttui::logger::log "converting LCH to LAB..."
#   #   l = l
#   #   a = cos(h * 0.01745329251) * c
#   #   b = sin(h * 0.01745329251) * c
#   LAB_L=$LCH_L
#   LAB_A=`awk -v H=$LCH_H -v C=$LCH_C 'BEGIN{ A=cos(H * 0.01745329251) * C; print A }'`
#   LAB_B=`awk -v H=$LCH_H -v C=$LCH_C 'BEGIN{ B=sin(H * 0.01745329251) * C; print B }'`
#   ttui::logger::log "lab --> L: $LAB_L | A: $LAB_A | B: $LAB_B"

#   # labToXyz --------------------------------------------------------------------
#   ttui::logger::log "converting LAB to XYZ..."
#   #   y = (l + 16) / 116
#   #   x = a / 500 + y
#   #   z = y - b / 200
#   XYZ_Y=`awk -v L=$LAB_L 'BEGIN{ Y=( L + 16 ) / 116; print Y }'`
#   XYZ_X=`awk -v A=$LAB_A -v Y=$XYZ_Y 'BEGIN{ X= A / 500 + Y; print X }'`
#   XYZ_Z=`awk -v Y=$XYZ_Y -v B=$LAB_B 'BEGIN{ Z=Y - B / 200; print Z }'`
#   ttui::logger::log "intermediate X: ${XYZ_X} | Y: ${XYZ_Y} | Z: ${XYZ_Z}"
#   #   if (Math.pow(y, 3) > 0.008856) {
#   #     y = Math.pow(y, 3)
#   #   } else {
#   #     y = (y - 0.137931034) / 7.787
#   #   }
#   XYZ_Y=`awk -v Y=$XYZ_Y 'BEGIN{ Y=(Y ^ 3) > 0.008856 ? Y ^ 3 : (Y - 0.137931034) / 7.787; print Y}'`
#   #   if (Math.pow(x, 3) > 0.008856) {
#   #     x = Math.pow(x, 3)
#   #   } else {
#   #     x = (x - 0.137931034) / 7.787
#   #   }
#   XYZ_X=`awk -v X=$XYZ_X 'BEGIN{ X=(X ^ 3) > 0.008856 ? X ^ 3 : (X - 0.137931034) / 7.787; print X}'`
#   #   if (Math.pow(z, 3) > 0.008856) {
#   #     z = Math.pow(z, 3)
#   #   } else {
#   #     z = (z - 0.137931034) / 7.787
#   #   }
#   XYZ_Z=`awk -v Z=$XYZ_Z 'BEGIN{ Z=(Z ^ 3) > 0.008856 ? Z ^ 3 : (Z - 0.137931034) / 7.787; print Z}'`
#   ttui::logger::log "intermediate2 X: ${XYZ_X} | Y: ${XYZ_Y} | Z: ${XYZ_Z}"
#   #   // Observer = 2°, Illuminant = D65
#   #   x = 95.047 * x
#   #   y = 100.000 * y
#   #   z = 108.883 * z
#   XYZ_X=`awk -v X=$XYZ_X 'BEGIN{ X=95.047 * X; print X}'`
#   XYZ_Y=`awk -v Y=$XYZ_Y 'BEGIN{ Y=100.000 * Y; print Y}'`
#   XYZ_Z=`awk -v Z=$XYZ_Z 'BEGIN{ Z=108.883 * Z; print Z}'`
#   ttui::logger::log "xyz --> X: $XYZ_X | Y: $XYZ_Y | Z: $XYZ_Z"

#   # xyzToRgb --------------------------------------------------------------------
#   ttui::logger::log "converting XYZ to RGB..."
#   #   // Observer = 2°, Illuminant = D65
#   #   x = xyz.x / 100 // X from 0 to 95.047
#   #   y = xyz.y / 100 // Y from 0 to 100.000
#   #   z = xyz.z / 100 // Z from 0 to 108.883
#   XYZ_X=`awk -v X=$XYZ_X 'BEGIN{ X=X / 100; print X}'`
#   XYZ_Y=`awk -v Y=$XYZ_Y 'BEGIN{ Y=Y / 100; print Y}'`
#   XYZ_Z=`awk -v Z=$XYZ_Z 'BEGIN{ Z=Z / 100; print Z}'`
#   ttui::logger::log "intermediate3 X: ${XYZ_X} | Y: ${XYZ_Y} | Z: ${XYZ_Z}"
#   #   r = x * 3.2406 + y * -1.5372 + z * -0.4986
#   #   g = x * -0.9689 + y * 1.8758 + z * 0.0415
#   #   b = x * 0.0557 + y * -0.2040 + z * 1.0570
#   RGB_R=`awk -v X=$XYZ_X -v Y=$XYZ_Y -v Z=$XYZ=Z 'BEGIN{ R=X * 3.2406 + Y * -1.5372 + Z * -0.4986; print R}'`
#   RGB_G=`awk -v X=$XYZ_X -v Y=$XYZ_Y -v Z=$XYZ=Z 'BEGIN{ G=X * -0.9689 + Y * 1.8758 + Z * 0.0415; print G}'`
#   RGB_B=`awk -v X=$XYZ_X -v Y=$XYZ_Y -v Z=$XYZ=Z 'BEGIN{ B=X * 0.0557 + Y * -0.2040 + Z * 1.0570; print B}'`
#   ttui::logger::log "intermediate4 R: ${RGB_R} | G: ${RGB_G} | B: ${RGB_B}"
#   #   if (r > 0.0031308) {
#   #     r = 1.055 * (Math.pow(r, 0.41666667)) - 0.055
#   #   } else {
#   #     r = 12.92 * r
#   #   }
#   RGB_R=`awk -v R=$RGB_R 'BEGIN{ R=R > 0.0031308 ? 1.055 * (R ^ 0.41666667) - 0.055 : 12.92 * R; print R}'`
#   #   if (g > 0.0031308) {
#   #     g = 1.055 * (Math.pow(g, 0.41666667)) - 0.055
#   #   } else {
#   #     g = 12.92 * g
#   #   }
#   RGB_G=`awk -v G=$RGB_G 'BEGIN{ G=G > 0.0031308 ? 1.055 * (G ^ 0.41666667) - 0.055 : 12.92 * G; print G}'`
#   #   if (b > 0.0031308) {
#   #     b = 1.055 * (Math.pow(b, 0.41666667)) - 0.055
#   #   } else {
#   #     b = 12.92 * b
#   #   }
#   RGB_B=`awk -v B=$RGB_B 'BEGIN{ B=B > 0.0031308 ? 1.055 * (B ^ 0.41666667) - 0.055 : 12.92 * B; print B}'`
#   ttui::logger::log "intermediate4 R: ${RGB_R} | G: ${RGB_G} | B: ${RGB_B}"
#   #   r *= 255
#   #   g *= 255
#   #   b *= 255
#   RGB_R=`awk -v R=$RGB_R 'BEGIN{ R=255 * R; print R}'`
#   RGB_G=`awk -v G=$RGB_G 'BEGIN{ G=255 * G; print G}'`
#   RGB_B=`awk -v B=$RGB_B 'BEGIN{ B=255 * B; print B}'`
#   ttui::logger::log "intermediate5 R: ${RGB_R} | G: ${RGB_G} | B: ${RGB_B}"
#   #   round float values to int vals and clamp to range 0-255
#   RGB_R=`awk -v R=$RGB_R 'BEGIN{
#     intVal = int(R) 
#     if (R < 0) {
#       R = 0
#     } else if (R > 255) {
#       R = 255
#     } else if (R == intVal ){
#       R = R
#     } else if (R - intVal >= 0.5) {
#       R = intVal + 1
#     } else {
#       R = intVal
#     }; 
#     print R}'`
#   RGB_G=`awk -v G=$RGB_G 'BEGIN{
#     intVal = int(G) 
#     if (G < 0) {
#       G = 0
#     } else if (G > 255) {
#       G = 255
#     } else if (G == intVal ){
#       G = G
#     } else if (G - intVal >= 0.5) {
#       G = intVal + 1
#     } else {
#       G = intVal
#     }; 
#     print G}'`
#   RGB_B=`awk -v B=$RGB_B 'BEGIN{
#     intVal = int(B) 
#     if (B < 0) {
#       B = 0
#     } else if (B > 255) {
#       B = 255
#     } else if (B == intVal ){
#       B = B
#     } else if (B - intVal >= 0.5) {
#       B = intVal + 1
#     } else {
#       B = intVal
#     }; 
#     print B}'`
#   ttui::logger::log "rgb --> R: $RGB_R | G: $RGB_G | B: $RGB_B"

#   # test
#   # printf "\033[38;2;%d;%d;%dm$LEVEL_BARS_TOP\n" $RGB_R $RGB_G $RGB_B;
#   # printf "\033[38;2;%d;%d;%dm$LEVEL_BARS_MID\n" $RGB_R $RGB_G $RGB_B;
#   # printf "\033[38;2;%d;%d;%dm$LEVEL_BARS_BOT\n" $RGB_R $RGB_G $RGB_B;
#   # reset color
#   # printf "\033[0m"

#   # assign RGB values -----------------------------------------------------------
#   #   if option fourth arg exists, then try to assign values to variable of the same name
#   #   else assign values to default global variable
#   if [[ $# -gt 3 ]]; then
#     ttui::logger::log "4th arg found: $4"
#     # check if the string value of myVar is the name of a declared variable
#     local varName="$4"
#     # myVar='$'"$4"
#     local bVarExists=false
#     local test='if ${'"${varName}"'+"false"}; then ttui::logger::log "${varName} not defined"; else bVarExists=true; ttui::logger::log "${varName} is defined"; fi'
#     ttui::logger::log "test: $test"
#     eval $test
#     ttui::logger::log  "bVarExists: ${bVarExists}"

#     if [[ $bVarExists == true ]]; then
#       local assignment="${varName}"'=($RGB_R $RGB_G $RGB_B)'
#       ttui::logger::log  "assignment: ${assignment}"
#       eval $assignment
#       local toEcho='echo "${varName}: ${'"${varName}"'[@]}"'
#       ttui::logger::log  "toEcho: $toEcho"
#       # eval $toEcho
#       local toLog=`eval $toEcho`
#       ttui::logger::log $toLog
#     else
#       echo "${FUNCNAME[0]} --> warning: cannot assign RGB values to ${varName}: undelcared variable"
#     fi
#   else
#     ttui::logger::log "no var name provided. Assigning to TTUI_COLOR_RGB_FROM_LCH"
#     TTUI_COLOR_RGB_FROM_LCH=($RGB_R $RGB_G $RGB_B)
#   fi

#   ttui::logger::log "${TTUI_EXECUTION_COMPLETE_DEBUG_MSG}"
# }


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
# Confirms that this script has been loaded and functions are available
# Globals:
#   none
# Arguments:
#   none
# -----------------------------------------------------------------------------
ttui::lib_is_loaded() {
  ttui::logger::log "${TTUI_INVOKED_DEBUG_MSG}"
  echo "ttui_lib is loaded"
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
# returns code 1 if arg is an unsigned integer
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
#   [[ $BASH_IS_NIFTY == true && $(ttui::util::is_uint $VAR) == 1 ]] && echo "$VAR is an unsigned integer"
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

TTUI_LOADED=true