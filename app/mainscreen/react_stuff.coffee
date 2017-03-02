import $ from 'jquery'
import md5 from 'js-md5'
import React, { Component } from 'react'
import {Diagram} from './Node.coffee'

#FIXME name-mangle these before release
# Alonzo.volatile_state is the one used for rendering
# this one is never changed, it is copied into volatile_state
# whenever a new diagram is chosen and a reset is required
# the selection needs to be reset etc.
Alonzo.volatile_state_initialize = {
  zoom_per_wheel:     1.3   # on mousewheel, multiply or divide zoom by this number
  viewport_size:      [600, 400]
  viewport_00:        [0, 0]# in the space of the diagram model
  zoom:               3.0   # zoom is the ratio of the density of pixel space to diagram space

  current_diagram_uuid: null # a string when populated

  more_space_button:  1.1 #1.1 means 10% more space is created when you click the more space button

  mouse_states: {
    up:                                   1
    over_new_cp_button:                  14
    down_on_background:                   2
    dragging_background:                  3  # TODO rename to panning_background
    dragging_box_select:                 12
    dragging_box_new_node:               13
    down_on_cp:                           4
    dragging_cp:                          5
    down_on_node:                         6  # including bubbles
    down_on_node_name:                   18
    dragging_node:                        7
    down_on_link:                        10
    dragging_link:                       11
    over_node_resizer:                   15
    down_on_node_resizer:                16
    dragging_node_resizer:               17
  }
  mouse_state:                1
  ctrl_key_on_mouse_down:     false
  shift_key_on_mouse_down:    false
  drag_background: { # TODO could rename to data_when_down_on_background or something
    mousedown_position:     [0, 0]  # in tagspace
    mousedown_viewport00:   [0, 0]
  }
  mouse_over_cp: { #null if not over a CP, unrelated to mouse_state
    ancestry:               []
    zero_in_one_out:        0
    argnum:                 0
  }
  mouse_over_new_cp_button: {
    ancestry:               []
    type:                   "" #this will follow the types enum in NewPortButton.types
    after_argnum:           0
  }
  drag_cp: {
    down_cp: {
      ancestry:           []
      type:               0
      argnum:             0
    }
    dangling_link: {
      draw_it:            false   # would be false if, for example, you're dragging out a new link, but not currently over a valid drop target
      parent_ancestry:    []      # this is only required because some CPs are both internal and external, otherwise, down_cp would fully specify it
      dangling_position:  [0, 0]  # in the parent's space
    }
  }
  drag_node: { #or bubble
    down_offset_parent:     [0, 0]  # down position to drag_node upper left, in parent space
    down_node_ancestry:     []
  }
  drag_link: { #or bubble link
    down_link_ancestry:     []
    down_link_idargidarg:   [0, 0, 0, 0] # [from_id, from_argnum, to_id, to_argnum]
  }

  node_rename_text_box: {
    draw_it:                false
    ancestry:               [] # of the node whose name should be changed
  }
  drag_select_box: {
    draw_it:                false
    ancestry:               [] # of the node containing the box TODO - remove because redundant with drag_background.mousedown_position
    top_left_parent_space:  [0, 0]
    bot_right_parent_space: [0, 0]
  }
  drag_new_node_box: {
    draw_it:                false
    ancestry:               [] # of the node containing the box TODO - remove because redundant with drag_background.mousedown_position
    top_left_parent_space:  [0, 0]
    bot_right_parent_space: [0, 0]
  }
  node_resizer_data: {
    ancestry:               [] # of the node to which the resizer is attached
    offset_parent:          [0, 0] # mouse position to bottom right in parent space
  }

  # selected_nodes is a list of things like:
  # {
  #   parent_uuid: uuid
  #   submodel_id: submodel_id
  # }
  selected_nodes:   []

  # selected_bubbles is just a list of ancestries
  selected_bubbles: []

  # selected_links is a list of things like:
  # {
  #  model_uuid: "someuuid"
  #  idargidarg: [from_id, from_argnum, to_id, to_argnum]
  # }
  selected_links: []

  # this is a list of the ancestries of the associated bubbles
  selected_bubble_links: []

  # selected_cps is a list of things like:
  # {
  #  parent_model_uuid: "someuuid"
  #  submodel_id:       0
  #  type:              "" #this will follow the types enum in ConnectionPort.types
  #  argnum:            0
  # }
  selected_cps: []

  # this is a list of the ancestries of the associated bubbles
  selected_bubble_cps: []

  clipboard: {
    submodels:  []   # in same format as in the model spec
    links:      []   # in same format as in the model spec
  }
  paste_mode:     false

  # dictionary of the form [ancestry] -> sugared_map_index
  sugared_map_indicies: {}
}

Alonzo.chrome_state = {
  header_height:                    50         # px
  library_pane_width:               250        # px
  footer_height:                    0          # px
  footer_height_if_message:         50         # px

  library_panels_expanded:          {}         # {category: boolean}
  library_search_box_text:          ""

  mouse_down_lib_entry:             false
  mouse_drag_lib_entry:             false
  drag_from_library:  {
    display_name:                 ""
    specifier:                    ""
  }

  editing_diagram_name:             false

  current_message:                  null       # string
  message_removal_delay:            2000
}

Alonzo.ct_fg = "#444"
Alonzo.ct_bg = "white"

Alonzo.graphics_constants = {
  background_color:                 Alonzo.ct_bg
  new_node_default_width:           50
  minimum_node_width:               10
  detail_threshold: {
    name_only:            100
    name_and_port_lables: 150
    composite:            250
  }
  node: {
    corner_radius:                3          # in parents space
    border_stroke_width:          1          # in parents space
    border_stroke_color:          Alonzo.ct_fg
    border_stroke_color_selected: "red"
    lighter_than_parent:          0.95       # 0.1 means parent plus 10% grey
    oliver_height:                5          # in parents space
    oliver_min_aspect_ratio:      15         # if drawing the oliver at its specified height would cause an ar lower than this, the height is reduced to meet this ar
    name_text_color:              Alonzo.ct_fg
    name_text_color_composite:    Alonzo.ct_bg
    name_font_size:               0.15
    name_font_size_composite:     0.8        # fraction of the oliver height
    label_text_color:             Alonzo.ct_fg
    label_font_size:              0.12
    label_horizontal_offset:      0.12
    label_vertical_offset:        0.00
    type_dropdown_width_native:   50
    type_dropdown_width_my_node:  0.3
    type_text_color:              "#888"
    grid_line_spacing:            10
    grid_line_thickness:          0.5
    grid_line_color:              "#EEE"
    resizer_width_muliplier:      1.5        # 1.0 would fit right in the corner radius
    resizer_line_color:           "#888"
    space_buttons_stroke_color:   Alonzo.ct_bg
    space_buttons_stroke_width:   0.05       # these are all fractions of the oliver height
    space_buttons_width:          0.8
    space_buttons_inset:          0.6
    space_buttons_separation:     0.4
    space_buttons_corner_radius:  0.06
    variable_corner_extent:       0.7        # fraction of height
  }
  connection_port: {
    radius:                       2          # in parents space
    stroke_width:                 1          # in parents space
    fill_color:                   Alonzo.ct_bg
    stroke_color:                 Alonzo.ct_fg
    stroke_color_mouseover:       "green"
    stroke_color_error:           "#B44"
    stroke_color_selected:        "red"
    error_message_font_size:      5
    error_message_color:          "red"
    new_cp_button_dash_array:     1.7
    sugared_map_size:             3
  }
  link: {
    curve_strength:               15         # in parents space
    stroke_width:                 1          # in parents space
    stroke_color:                 Alonzo.ct_fg
    stroke_color_selected:        "red"
    dangling_color:               Alonzo.ct_fg
    dangling_dash_array:          4          # points on, points off
  }
  bubble: {
    border_stroke_width:          2
    border_stroke_color:          "darkblue"
    oliver_height:                5          # in parents space
    corner_radius:                5          # in parents space
    border_stroke_color_selected: "red"
    fill_color:                   "blue"
    fill_opacity:                 0.1
    text_value_color:             Alonzo.ct_fg
    text_value_size:              0.3
    image_value_width:            1.2
  }
  drag_select_box: {
    border_stroke_width:          0.5
    border_stroke_color:          "purple"
    fill_color:                   "purple"
    fill_opacity:                 0.4
  }
}

Alonzo.render = () ->
  Alonzo.render_all()

Alonzo.render_diagram = () ->
  Alonzo.svg_elements_to_draw     = []
  Alonzo.svg_elements_to_draw_top = []
  Alonzo.native_elements_to_draw  = []
  Alonzo.reset_registry()
  new Diagram()
  mouse_overlay = Alonzo.get_mouse_overlay()

  onKeyDown = (event) ->
    KEYCODE_C       = 67
    KEYCODE_V       = 86
    KEYCODE_CONTROL = 17
    if      event.keyCode is KEYCODE_C and event.ctrlKey
      console.log("register ctrl-c")
      Alonzo.copy_command()
    else if event.keyCode is KEYCODE_V and event.ctrlKey
      console.log("register ctrl-v")
      Alonzo.paste_command()

  <div id="diagram-container" key="div0" onKeyDown={onKeyDown} tabIndex="1">
    <Alonzo.ReactSVGBase
      width  = "100%"
      height = "100%"
      key    = "svgbase"
      style  = {position:"absolute", top:"0px", left:"0px"}
    >
      {Alonzo.svg_elements_to_draw}
      {Alonzo.svg_elements_to_draw_top}
    </Alonzo.ReactSVGBase>
    <div key="nativebase">
      {Alonzo.native_elements_to_draw}
    </div>
    {if mouse_overlay? then mouse_overlay}
  </div>

# Takes a point in the coordinates of the window (as obtained, for example in a mouse event
# handler) and converts it to pixels in the coordinates of the svg tag.
Alonzo.abs_to_rel = (x, y) ->
  # offset() returns the position of the element within the whole window (see also .position())
  cco = $("#diagram-container").offset()
  [x - cco.left, y - cco.top]

Alonzo.ReactSVGBase = React.createClass({
  displayName: "SVGBase"
  # onClick: (e) ->
  #   #e.preventDefault();
  #   #console.log("svg click handler")
  # onMouseMove: (e) ->
  #   #e.preventDefault()
  #   #console.log("svg mouse move")
  # onMouseDown: (e) ->
  #   #e.preventDefault()
  #   #console.log("svg mousedown")
  # onMouseUp: (e) ->
  #   #e.preventDefault()
  #   #console.log("svg mouseup")

  _onWheel: (e) =>
    Alonzo.on_wheel_zoom(e)

  render: () ->
    <svg onWheel={this._onWheel} {... this.props}>
      {this.props.children}
    </svg>
  }
)

Alonzo.on_wheel_zoom = (e) ->
  e.preventDefault()

  if(e.deltaX    is not 0)
    console.warn("onWheel deltaX was not 0")
  if(e.deltaZ    is not 0)
    console.warn("onWheel deltaZ was not 0")
  if(e.deltaMode is not 0)
    console.warn("onWheel deltaMode was not 0")

  zoom_before       = Alonzo.volatile_state.zoom
  viewport00_before = Alonzo.volatile_state.viewport_00
  mouse_position_px = Alonzo.abs_to_rel(e.clientX, e.clientY)
  mouse_position_diagram = [ # in diagram space
    Alonzo.volatile_state.viewport_00[0] + (mouse_position_px[0] / Alonzo.volatile_state.zoom),
    Alonzo.volatile_state.viewport_00[1] + (mouse_position_px[1] / Alonzo.volatile_state.zoom)
  ]

  # when mouse wheel zoom in, e.deltaY is -53, out is 53
  if      e.deltaY > 0 # zoom out
    zoom_after = Alonzo.volatile_state.zoom / Alonzo.volatile_state.zoom_per_wheel
  else if e.deltaY < 0 # zoom in
    zoom_after = Alonzo.volatile_state.zoom * Alonzo.volatile_state.zoom_per_wheel

  zoom_ratio = zoom_after / zoom_before
  viewport00_after = [
    mouse_position_diagram[0] + ( (viewport00_before[0] - mouse_position_diagram[0]) / zoom_ratio )
    mouse_position_diagram[1] + ( (viewport00_before[1] - mouse_position_diagram[1]) / zoom_ratio )
  ]

  Alonzo.volatile_state.viewport_00 = viewport00_after
  Alonzo.volatile_state.zoom = zoom_after
  Alonzo.render()


# some things you can put in props:
# height
# width
# x
# y
# fill
# fillOpacity
# stroke
# strokeWidth
# opacity
# onMouseDown
# onMouseUp
# onMouseOver
# onMouseOut
# onMouseMove
# onWheel
# rx
# ry
Alonzo.draw_rect = (props, ontop = false) ->
  if not props.key?
    console.warn("tried to draw a rect without a key attribute")

  # If I wanted, I could treat the input props as Alonzo-specific, with my own
  # elements and higher-level things, then transform it into something with correct
  # names and stuff for react.  For now, it's all the same though.

  element = <rect {... props}></rect>

  if ontop
    Alonzo.svg_elements_to_draw_top.push(element)
  else
    Alonzo.svg_elements_to_draw.push(element)


# some things you can put in props:
# cx
# cy
# r
# fill
# fillOpacity
# stroke
# strokeWidth
# opacity
# (all the mouse stuff)
Alonzo.draw_circle = (props) ->
  if not props.key?
    console.warn("tried to draw a circle without a key attribute")

  Alonzo.svg_elements_to_draw.push(
    <circle {... props}></circle>
  )

# some things you can put in props:
# d (this is the path string)
# fill
# fillOpacity
# stroke
# strokeWidth
# opacity
# (all the mouse stuff)
Alonzo.draw_path = (props) ->
  if not props.key?
    console.warn("tried to draw a path without a key attribute")

  Alonzo.svg_elements_to_draw.push(
    <path {... props}></path>
  )

# some things to put in props:
# x
# y
# fontFamily
# fontSize
# stroke
# fill
# textAnchor   can be "start" "middle" or "end"
Alonzo.draw_text = (actual_text, props, ontop = false) ->
  if not props.key?
    console.warn("tried to draw text without a key attribute")

  element = <text {... props}>{actual_text}</text>

  if ontop
    Alonzo.svg_elements_to_draw_top.push(element)
  else
    Alonzo.svg_elements_to_draw.push(element)

Alonzo.make_text_field = (props) ->
  # all measurements are in tagspace
  # props should have x, y, width, height, current_value, onNewValue(new_value)

  if not props.key?
    console.warn("tried to draw a text field without a key attribute")

  native_width = props.width / props.height * 26

  style = {}
  style.position = "absolute"
  style.left     = props.x      + "px" # formerly added 15 as a hack here to compensate for the bootstrap padding of mainapp-panel
  style.top      = props.y      + "px"
  style.width    = native_width + "px"

  scale_factor = props.width / native_width * 1
  translate    = -(1 - scale_factor) / 2
  transform_string = "translate(#{translate*100}%, #{translate*100}%) scale(#{scale_factor}, #{scale_factor})"
  style.transform       = transform_string  # take this out if it bugs some browsers
  style.MozTransform    = transform_string
  style.msTransform     = transform_string
  style.WebkitTransform = transform_string
  style.OTransform      = transform_string

  Alonzo.native_elements_to_draw.push(
    <Alonzo.ReactInputElement
      style         = {style}
      key           = {props.key}
      key_duplicate = {props.key}
      startingValue = {props.current_value}
      onNewValue    = {props.onNewValue}
    ></Alonzo.ReactInputElement>
  )

Alonzo.ReactInputElement = React.createClass({
  displayName: "ReactInputElement"

  getInitialState: () ->
    {value: this.props.startingValue}

  componentWillReceiveProps: (nextprops) ->
    # x = this.refs.thisref.getDOMNode()
    x = $("#" + this.props.key_duplicate)[0]
    a = $(document.activeElement)[0]
    xid = $(x).attr("id")
    aid = $(a).attr("id")
    if xid isnt aid
      this.setState({value: nextprops.startingValue})

  handleChange: (event) ->
    this.setState({value: event.target.value})

  onKeyPress: (event) ->
    if event.key is "Enter"
      this.props.onNewValue(this.state.value)

  onBlur: (event) ->
    this.props.onNewValue(this.state.value)

  render: () ->
    rest = Object.assign({},this.props)
    delete rest.key_duplicate
    delete rest.startingValue
    delete rest.onNewValue

    <input
      type       = "text"
      id         = {this.props.key_duplicate}
      value      = {this.state.value}
      onChange   = {this.handleChange}
      onKeyPress = {this.onKeyPress}
      onBlur     = {this.onBlur}
      {... rest}
    ></input>
})

Alonzo.make_text_box = (props) ->
  # all measurements are in tagspace
  # props should have x, y, width, height, current_value, onNewValue(new_value)

  if not props.key?
    console.warn("tried to draw a text box without a key attribute")

  # native_width = props.width / props.height * 60
  native_width = 200

  style = {}
  style.position = "absolute"
  style.left     = props.x      + "px" # formerly added 15 as a hack here to compensate for the bootstrap padding of mainapp-panel
  style.top      = props.y      + "px"
  style.width    = native_width + "px"
  style.height   = "167"        + "px"

  scale_factor = props.width / native_width * 1
  translate    = -(1 - scale_factor) / 2
  transform_string = "translate(#{translate*100}%, #{translate*100}%) scale(#{scale_factor}, #{scale_factor})"
  style.transform       = transform_string  # take this out if it bugs some browsers
  style.MozTransform    = transform_string
  style.msTransform     = transform_string
  style.WebkitTransform = transform_string
  style.OTransform      = transform_string

  Alonzo.native_elements_to_draw.push(
    <Alonzo.ReactTextBoxElement
      style         = {style}
      key           = {props.key}
      key_duplicate = {props.key}
      startingValue = {props.current_value}
      onNewValue    = {props.onNewValue}
    ></Alonzo.ReactTextBoxElement>
  )

Alonzo.ReactTextBoxElement = React.createClass({
  displayName: "ReactInputElement"

  getInitialState: () ->
    {value: this.props.startingValue}

  componentWillReceiveProps: (nextprops) ->
    # x = this.refs.thisref.getDOMNode()
    x = $("#" + this.props.key_duplicate)[0]
    a = $(document.activeElement)[0]
    xid = $(x).attr("id")
    aid = $(a).attr("id")
    if xid isnt aid
      this.setState({value: nextprops.startingValue})

  handleChange: (event) ->
    this.setState({value: event.target.value})

  onKeyPress: (event) ->
    if event.key is "Enter"
      this.props.onNewValue(this.state.value)

  onBlur: (event) ->
    this.props.onNewValue(this.state.value)

  render: () ->
    <textarea
      type       = "text"
      id         = {this.props.key_duplicate}
      value      = {this.state.value}
      onChange   = {this.handleChange}
      onKeyPress = {this.onKeyPress}
      onBlur     = {this.onBlur}
      {... this.props}
    ></textarea>
})

Alonzo.make_img_tag = (props) ->
  # props should have src, x, y, width, height

  if not props.key?
    console.warn("tried to draw an image tag without a key attribute")

  style = {}
  style.position = "absolute"
  style.left     = props.x      + "px"
  style.top      = props.y      + "px"
  style.width    = props.width  + "px"
  style.height   = props.height + "px"

  Alonzo.native_elements_to_draw.push(
    <img
      src         = {props.src}
      style       = {style}
      key         = {props.key}
      onMouseDown = {(e) -> e.preventDefault()}
    ></img>
  )

Alonzo.make_select_dropdown = (props) ->
  # props should have x, y, native_width, final_width, values, current_value, onNewValue(new_value)

  if not props.key?
    console.warn("tried to make a select dropdown without a key attribute")

  style = {}
  style.position = "absolute"
  style.left     = props.x              + "px"
  style.top      = props.y              + "px"
  style.width    = props.native_width   + "px"

  scale_factor = props.final_width / props.native_width
  translate    = -(1 - scale_factor) / 2
  transform_string = "translate(#{translate*100}%, #{translate*100}%) scale(#{scale_factor}, #{scale_factor})"
  style.transform       = transform_string  # take this out if it bugs some browsers
  style.MozTransform    = transform_string
  style.msTransform     = transform_string
  style.WebkitTransform = transform_string
  style.OTransform      = transform_string

  Alonzo.native_elements_to_draw.push(
    <Alonzo.ReactSelectDropdown
      style         = {style}
      key           = {props.key}
      values        = {props.values}
      startingValue = {props.current_value}
      onNewValue    = {props.onNewValue}
    ></Alonzo.ReactSelectDropdown>
  )

Alonzo.ReactSelectDropdown = React.createClass({
  displayName: "ReactSelectDropdown"

  getInitialState: () ->
    {value: this.props.startingValue}

  componentWillReceiveProps: (nextprops) ->
    this.setState({value: nextprops.startingValue})

  handleChange: (event) ->
    this.setState({value: event.target.value})
    this.props.onNewValue(event.target.value)

  render: () ->
    <select
      value     = {this.state.value}
      onChange  = {this.handleChange}
      {... this.props}
    >
      {for x in this.props.values
        <option value={x} key={md5("" + this.props.key + x)}>{x}</option>
      }
    </select>
})
