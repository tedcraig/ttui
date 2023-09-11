# TTUI

## Description
Terminal UI library for Bash, written in Bash

## Why?

Let's be real: a purely Bash terminal UI library/framework is a bit silly.  The language is not suited for it.  In order to acheive desired results I am building clunky data structures that would be fast running native code in a more appropriate language.

So ... why?  I wanted to a TUI framework that didn't rely on tput and didn't require installing any new apps or libraries; BUT, mostly this project was built as a fun thought experiment and to provide me with a framework for gaining a deeper understanding of Bash.  So far, I have been entertained trying to make it do things that it was never intented to do.

## API



### ttui::color::get_escape_code_for_rgb
Generates RGB color escape code string using the argument values supplied. 
If optional variable name argument is provided, resulting escape code will be 
assigned to variable matching the provided name.  
If optional variable name argument is not used then resulting escape code will
be assigned global variable TTUI_COLOR_RGB.
#### Globals:
TTUI_COLOR_RGB
#### Arguments:
position|desc|type
--------|----|----
  $1:|  Red  |  unsigned integer (0-255)
  $2:|  Blue |  unsigned integer (0-255)
  $3:|  Green | unsigned integer (0-255)
 \[$4:\] |name of existing variable to which result should be assigned | string


### ttui::color::get_lch_from_rgb
Converts RGB (0-255) color values to CIE-L*Ch°(ab) (LCH) values. 
If optional variable name argument is provided, resulting LCH values will be 
assigned as an array (L,C,H) to variable matching the provided name.  If 
optional variable name argument is not used then resulting LCH value will be
assigned as an array (L,C,H) to global variable TTUI_COLOR_LCH_FROM_RGB.
*** SLOW-ish !!! ***
#### Globals:
TTUI_COLOR_LCH_FROM_RGB
#### Arguments:
position|desc|type
--------|----|----
  $1:|  Red  |  unsigned integer (0-255)
  $2:|  Blue |  unsigned integer (0-255)
  $3:|  Green | unsigned integer (0-255)
 \[$4:\] |name of existing variable to which result should be assigned | string
#### Dependancies:
awk  (developed using version 20200816)
#### Notes:
color conversion equations from:
avisek/colorConversions.js
https://gist.github.com/avisek/eadfbe7a7a169b1001a2d3affc21052e

checked sanity of results using:
http://colormine.org/convert/rgb-to-lch - matches converted values
https://www.easyrgb.com/en/convert.php#inputFORM - C val is slightly different

LCH color picker:
https://css.land/lch/


### ttui::color::get_rgb_from_lch
Converts LCH color values -- specifically CIE-L*Ch°(ab) -- to RGB values.
Resulting RGB values are echoed as a string delimited by spaces and are also
assigned as an array (R,G,B) to global variable TTUI_COLOR_RGB_FROM_LCH.
*** SLOW-ish !!! ***
#### Globals:
TTUI_COLOR_RGB_FROM_LCH
#### Arguments:
position|desc|type
--------|----|----
  position 1:|  LCH lightness| unsigned integer (0-100)
  position 2:|  LCH chroma|    unsigned integer (0-132)
  position 3:|  LCH hue|       unsigned integer (0-360)
 [position 4:]| name of existing variable to which result should be assigned| string
#### Dependancies:awk  (developed using version 20200816)
#### Notes:
color conversion equations from:
avisek/colorConversions.js
https://gist.github.com/avisek/eadfbe7a7a169b1001a2d3affc21052e

checked sanity of results using:
http://colormine.org/convert/rgb-to-lch - matches converted values
https://www.easyrgb.com/en/convert.php#inputFORM - C val is slightly different

LCH color picker:
https://css.land/lch/

### ttui::color::reset
Sets active color to terminal default.

#### Globals:
none
#### Arguments:
none


### ttui::color::set_color_to_rgb
Sets color to specified RGB value.
This color will remain active until the it is intentionally reset.
#### Globals:
none
#### Arguments:
position|desc|type
--------|----|----
  $1:|  Red  |  unsigned integer (0-255)
  $2:|  Blue |  unsigned integer (0-255)
  $3:|  Green | unsigned integer (0-255)



### ttui::cursor::get_column
Get the column number on which the cursor currently resides
#### Globals:
TTUI_CURRENT_COLUMN
#### Arguments:
position|desc|type
--------|----|----
 $1| from cache flag| string "from_cache" - result will be echoed from global var TTUI_CURRENT_COLUMN without reinvoking [ttui::cursor::get_position()](#ttui::cursor::get_position). **NOTE** this feature may not work if function is being called within a command substitution|

### ttui::cursor::get_line
Get the line number on which the cursor currently resides
#### Globals:
TTUI_CURRENT_LINE
#### Arguments:
position|desc|type
--------|----|----
 $1| from cache flag| string "from_cache" - result will be echoed from global var TTUI_CURRENT_LINE without reinvoking [ttui::cursor::get_position()](#ttui::cursor::get_position). **NOTE** this feature may not work if function is being called within a command substitution|

### ttui::cursor::get_position
Gets the current position of the cursor and assigns line and column values to globals vars.
### Globals:
TTUI_CURRENT_LINE
TTUI_CURRENT_COLUMN
#### Arguments:
none

### ttui::cursor::hide
Hides the cursor.
#### Globals:
cursor_visible
#### Arguments:
none

### ttui::cursor::show
Shows the cursor.
#### Globals:
cursor_visible
#### Arguments:
none



### ttui::cursor::move_to
Moves cursor to the specified line and column.
#### Globals:
none
#### Arguments:
position|desc|type
--------|----|----
$1| line number| unsigned integer or '-' or '_'
$2| column number| unsigned integer or '-' or '_'



### ttui::term::clear_screen
Clears the screen.
Globals:
  None
Arguments:
  None

### ttui::term::reset_to_defaults
Reset terminal to initial state.
#### Globals:
None
#### Arguments:
None

### ttui::term::restore_screen
Restores terminal to the state saved via ttui::save_terminal_screen()
#### Globals:
None
#### Arguments:
None

### ttui::term::save_screen
Saves the current state of the terminal which can later be restored via
[ttui::restore_terminal_screen()](#ttui::term::restore_screen)

#### Globals:
None
#### Arguments:
None
