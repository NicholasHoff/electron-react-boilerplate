import md5 from 'js-md5'
import {Bubble} from './Node.coffee'
import StoredErrors from './StoredErrors.coffee'

class ConnectionPort
  @types: {
    input:  "input"   # try having these as descriptive strings rather than integers
    output: "output"  # a bit silly, but nice for debugging
  }

  # my_node is the node I'm attached to
  # x and y are in my_node's space
  constructor: (@my_node, @argnum, @type, @x, @y) ->
    Alonzo.registry.regsiter_cp(this)
    @id_if_source             = if @type is ConnectionPort.types.input  then 0 else Alonzo.Utils.list_last(@my_node.ancestry)
    @id_if_sink               = if @type is ConnectionPort.types.output then 0 else Alonzo.Utils.list_last(@my_node.ancestry)
    @enclosing_node_if_source = if @type is ConnectionPort.types.input  then @my_node else @my_node.parent
    @enclosing_node_if_sink   = if @type is ConnectionPort.types.output then @my_node else @my_node.parent
    @is_bubble_cp             = @my_node instanceof Bubble
    @_my_error                = StoredErrors.lookup_cp_error(@my_node.ancestry, @type, @argnum)
    @_is_split_cp             = @my_node.children_are_visible

  draw: () ->
    @stroke_color =
      if @_is_mouse_over_me()
        Alonzo.graphics_constants.connection_port.stroke_color_mouseover
      else
        if @is_selected()
          Alonzo.graphics_constants.connection_port.stroke_color_selected
        else if @_my_error isnt null
          Alonzo.graphics_constants.connection_port.stroke_color_error
        else
          if @is_bubble_cp
            Alonzo.graphics_constants.bubble.border_stroke_color
          else
            Alonzo.graphics_constants.connection_port.stroke_color

    if @_is_split_cp
      @_draw_split()
    else
      @_draw_simple()

  _draw_split: () ->
    [@tagspace_x, @tagspace_y] = @my_node.convert_point_to_tag_space(@x, @y)
    @r_parent_tagspace = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius)
    @r_child_tagspace  =        @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius)

    if @type is ConnectionPort.types.input
      path_string_parent =
        "M " + @tagspace_x + ", " + (@tagspace_y + @r_parent_tagspace) + " " +
        "a " + @r_parent_tagspace + ", " + @r_parent_tagspace + " " + "0 1, 1" + " " + "0" + ", " + (0 - 2*@r_parent_tagspace)
      path_string_child  =
        "M " + @tagspace_x + ", " + (@tagspace_y - @r_child_tagspace)  + " " +
        "a " + @r_child_tagspace  + ", " + @r_child_tagspace  + " " + "0 1, 1" + " " + "0" + ", " + (0 + 2*@r_child_tagspace)
    else if @type is ConnectionPort.types.output
      path_string_parent =
        "M " + @tagspace_x + ", " + (@tagspace_y - @r_parent_tagspace) + " " +
        "a " + @r_parent_tagspace + ", " + @r_parent_tagspace + " " + "0 1, 1" + " " + "0" + ", " + (0 + 2*@r_parent_tagspace)
      path_string_child  =
        "M " + @tagspace_x + ", " + (@tagspace_y + @r_child_tagspace)  + " " +
        "a " + @r_child_tagspace  + ", " + @r_child_tagspace  + " " + "0 1, 1" + " " + "0" + ", " + (0 - 2*@r_child_tagspace)
    else
      console.error("don't know how to handle connection port type #{@type}")

    Alonzo.draw_path({
      key:         md5(@get_key() + "parent cp half")
      d:           path_string_parent
      fill:        Alonzo.graphics_constants.connection_port.fill_color
      stroke:      @stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.stroke_width)
      onMouseDown: @_onMouseDown
      onMouseOver: @_onMouseOver
      onMouseOut:  @_onMouseOut
    })

    Alonzo.draw_path({
      key:         md5(@get_key() + "child cp half")
      d:           path_string_child
      fill:        Alonzo.graphics_constants.connection_port.fill_color
      stroke:      @stroke_color
      strokeWidth: @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.stroke_width)
      onMouseDown: @_onMouseDown
      onMouseOver: @_onMouseOver
      onMouseOut:  @_onMouseOut
    })

  _draw_simple: () ->
    [@tagspace_x, @tagspace_y] = @my_node.convert_point_to_tag_space(@x, @y)
    @r_tagspace = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius)
    Alonzo.draw_circle({
      key:         md5(@get_key() + "cp")
      cx:          @tagspace_x
      cy:          @tagspace_y
      stroke:      @stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.stroke_width)
      fill:        Alonzo.graphics_constants.connection_port.fill_color
      r:           @r_tagspace
      onMouseDown: @_onMouseDown
      onMouseOver: @_onMouseOver
      onMouseOut:  @_onMouseOut
    })

  right_connection_point_in_tagspace: () ->
    [tagspace_x, tagspace_y] = @my_node.convert_point_to_tag_space(@x, @y)

    # Set stroke width here to make links touch the actual ends of the CPs
    # the problem is that they don't look connected because of the CP curvature
    # better would be to leave stroke_width offset at 0 and draw the links
    # under the CPs.  The CPs have to be drawn first though, so it would
    # require actually setting the layer at the SVG level.  That would require
    # specifying the order that the SVG elements are placed into the tag,
    # separate from the order in which I draw them.
    radius       = Alonzo.graphics_constants.connection_port.radius
    stroke_width = 0#Alonzo.graphics_constants.connection_port.stroke_width / 2

    offset =
      if @_is_split_cp
        if @type is ConnectionPort.types.input
          @my_node.convert_magnitude_to_tag_space(radius + stroke_width)
        else if @type is ConnectionPort.types.output
          @my_node.parent.convert_magnitude_to_tag_space(radius + stroke_width)
      else
        @my_node.parent.convert_magnitude_to_tag_space(radius + stroke_width)

    [tagspace_x + offset, tagspace_y]

  left_connection_point_in_tagspace: () ->
    [tagspace_x, tagspace_y] = @my_node.convert_point_to_tag_space(@x, @y)

    # Set stroke width here to make links touch the actual ends of the CPs
    # the problem is that they don't look connected because of the CP curvature
    # better would be to leave stroke_width offset at 0 and draw the links
    # under the CPs.  The CPs have to be drawn first though, so it would
    # require actually setting the layer at the SVG level.  That would require
    # specifying the order that the SVG elements are placed into the tag,
    # separate from the order in which I draw them.
    radius       = Alonzo.graphics_constants.connection_port.radius
    stroke_width = 0#Alonzo.graphics_constants.connection_port.stroke_width / 2

    offset =
      if @_is_split_cp
        if @type is ConnectionPort.types.input
          @my_node.parent.convert_magnitude_to_tag_space(radius + stroke_width)
        else if @type is ConnectionPort.types.output
          @my_node.convert_magnitude_to_tag_space(radius + stroke_width)
      else
        @my_node.parent.convert_magnitude_to_tag_space(radius + stroke_width)

    [tagspace_x - offset, tagspace_y]

  get_key: () ->
    if @key?
      @key
    else
      @key = " " + @my_node.ancestry + @type + @argnum
      @key

  tag_point_is_inside_cp: (test_point_tag_space) ->
    max_allowable_distance =
      if @_is_split_cp
        if @type is ConnectionPort.types.input
          if test_point_tag_space[0] < @tagspace_x
            @r_parent_tagspace
          else
            @r_child_tagspace
        else if @type is ConnectionPort.types.output
          if test_point_tag_space[0] < @tagspace_x
            @r_child_tagspace
          else
            @r_parent_tagspace
      else
        @r_tagspace

    Alonzo.Utils.abs_distance_between_points([@tagspace_x, @tagspace_y], test_point_tag_space) < max_allowable_distance

  _is_mouse_over_me: () ->
    if Alonzo.volatile_state.mouse_over_cp is null
      false
    else
      ancestry_same = Alonzo.Utils.ancestry_same(Alonzo.volatile_state.mouse_over_cp.ancestry, @my_node.ancestry)
      side_same     = Alonzo.volatile_state.mouse_over_cp.zero_in_one_out == (if @type is ConnectionPort.types.input then 0 else 1)
      argnum_same   = Alonzo.volatile_state.mouse_over_cp.argnum == @argnum
      ancestry_same and side_same and argnum_same

  # _should_show_error_message: () ->
  #   @_my_error isnt null and
  #     Alonzo.volatile_state.mouse_over_cp? and
  #     Alonzo.Utils.ancestry_same(Alonzo.volatile_state.mouse_over_cp.ancestry, @my_node.ancestry) and
  #     Alonzo.volatile_state.mouse_over_cp.zero_in_one_out is (if @type is ConnectionPort.types.input then 0 else 1) and
  #     Alonzo.volatile_state.mouse_over_cp.argnum is @argnum

  _onMouseDown: (e) =>
    e.preventDefault()
    e.stopPropagation()
    Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.down_on_cp
    Alonzo.volatile_state.drag_cp.down_cp.ancestry = @my_node.ancestry
    Alonzo.volatile_state.drag_cp.down_cp.type     = @type
    Alonzo.volatile_state.drag_cp.down_cp.argnum   = @argnum
    Alonzo.render()

  _onMouseOver: () =>
    Alonzo.volatile_state.mouse_over_cp = {
      ancestry:        @my_node.ancestry
      zero_in_one_out: (if @type is ConnectionPort.types.input then 0 else 1)
      argnum:          @argnum
    }
    Alonzo.render()

  _onMouseOut: () =>
    Alonzo.volatile_state.mouse_over_cp = null
    Alonzo.render()

  add_to_selection: () ->
    if @is_bubble_cp
      Alonzo.volatile_state.selected_bubble_cps.push(@my_node.ancestry)
    else
      Alonzo.volatile_state.selected_cps.push({
        parent_model_uuid: @my_node.parent.my_model.uuid
        submodel_id:       @my_node.submodel_id
        type:              @type
        argnum:            @argnum
      })

  remove_from_selection: () ->
    if @is_bubble_cp
      Alonzo.volatile_state.selected_bubble_cps =
        (x for x in Alonzo.volatile_state.selected_bubble_cps when not Alonzo.Utils.ancestry_same(x, @my_node.ancestry))
    else
      Alonzo.volatile_state.selected_cps = (x for x in Alonzo.volatile_state.selected_cps when not (
        x.parent_model_uuid is @my_node.parent.my_model.uuid and
        x.submodel_id       is @my_node.submodel_id          and
        x.type              is @type                         and
        x.argnum            is @argnum
      ))

  is_selected: () ->
    if @is_bubble_cp
      for each in Alonzo.volatile_state.selected_bubble_cps
        if Alonzo.Utils.ancestry_same(each, @my_node.ancestry)
          return true
      return false
    else
      for each in Alonzo.volatile_state.selected_cps
        cond1 = each.parent_model_uuid is @my_node.parent.my_model.uuid
        cond2 = each.submodel_id       is @my_node.submodel_id
        cond3 = each.type              is @type
        cond4 = each.argnum            is @argnum
        if cond1 and cond2 and cond3 and cond4
          return true
      return false

export {ConnectionPort}
