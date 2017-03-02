import md5 from 'js-md5'

export default class NewPortButton
  @types: {
    left:  "left"   # try having these as descriptive strings rather than integers
    right: "right"  # a bit silly, but nice for debugging
  }

  # my_node is the node I'm attached to
  # x and y are in my_node's space
  constructor: (@my_node, @after_argnum, @type, @x, @y) ->
    @_is_split_cp = @my_node.children_are_visible
    @_draw()

  _draw: () ->
    if @_is_mouse_over_me()
      @stroke_color = Alonzo.graphics_constants.connection_port.stroke_color
      @fill_color   = Alonzo.graphics_constants.connection_port.fill_color
    else
      @stroke_color = "transparent"
      @fill_color   = "transparent"

    if @_is_split_cp
      @_draw_split()
    else
      @_draw_simple()

  _draw_split: () ->
    [tagspace_x, tagspace_y] = @my_node.convert_point_to_tag_space(@x, @y)
    r_parent_tagspace = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius)
    r_child_tagspace  =        @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius)
    parent_dash_array = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.new_cp_button_dash_array)
    child_dash_array  =        @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.new_cp_button_dash_array)

    if @type is NewPortButton.types.left
      path_string_parent =
        "M " + tagspace_x + ", " + (tagspace_y + r_parent_tagspace) + " " +
        "a " + r_parent_tagspace + ", " + r_parent_tagspace + " " + "0 1, 1" + " " + "0" + ", " + (0 - 2*r_parent_tagspace)
      path_string_child  =
        "M " + tagspace_x + ", " + (tagspace_y - r_child_tagspace)  + " " +
        "a " + r_child_tagspace  + ", " + r_child_tagspace  + " " + "0 1, 1" + " " + "0" + ", " + (0 + 2*r_child_tagspace)
    else if @type is NewPortButton.types.right
      path_string_parent =
        "M " + tagspace_x + ", " + (tagspace_y - r_parent_tagspace) + " " +
        "a " + r_parent_tagspace + ", " + r_parent_tagspace + " " + "0 1, 1" + " " + "0" + ", " + (0 + 2*r_parent_tagspace)
      path_string_child  =
        "M " + tagspace_x + ", " + (tagspace_y + r_child_tagspace)  + " " +
        "a " + r_child_tagspace  + ", " + r_child_tagspace  + " " + "0 1, 1" + " " + "0" + ", " + (0 - 2*r_child_tagspace)
    else
      console.error("don't know how to handle new port button type #{@type}")

    Alonzo.draw_path({
      key:         md5("new port button" + @my_node.ancestry + @type + @after_argnum + "parent half")
      d:           path_string_parent
      fill:        @fill_color
      stroke:      @stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.stroke_width)
      strokeDasharray: "#{parent_dash_array}, #{parent_dash_array}"
      onClick:     @_onClick
      onMouseOver: @_onMouseOver
      onMouseOut:  @_onMouseOut
    })

    Alonzo.draw_path({
      key:         md5("new port button" + @my_node.ancestry + @type + @after_argnum + "child half")
      d:           path_string_child
      fill:        @fill_color
      stroke:      @stroke_color
      strokeWidth: @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.stroke_width)
      strokeDasharray: "#{child_dash_array}, #{child_dash_array}"
      onClick:     @_onClick
      onMouseOver: @_onMouseOver
      onMouseOut:  @_onMouseOut
    })

  _draw_simple: () ->
    [tagspace_x, tagspace_y] = @my_node.convert_point_to_tag_space(@x, @y)
    r_tagspace = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius)
    dash_array = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.new_cp_button_dash_array)
    Alonzo.draw_circle({
      key:              md5("new port button" + @my_node.ancestry + @type + @after_argnum)
      cx:               tagspace_x
      cy:               tagspace_y
      stroke:           @stroke_color
      strokeWidth:      @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.stroke_width)
      strokeDasharray:  "#{dash_array}, #{dash_array}"
      fill:             @fill_color
      r:                r_tagspace
      onClick:          @_onClick
      onMouseOver:      @_onMouseOver
      onMouseOut:       @_onMouseOut
    })

  _is_mouse_over_me: () ->
    if Alonzo.volatile_state.mouse_state isnt Alonzo.volatile_state.mouse_states.over_new_cp_button
      false
    else
      ancestry_same = Alonzo.Utils.ancestry_same(Alonzo.volatile_state.mouse_over_new_cp_button.ancestry, @my_node.ancestry)
      side_same     = Alonzo.volatile_state.mouse_over_new_cp_button.type == @type
      argnum_same   = Alonzo.volatile_state.mouse_over_new_cp_button.after_argnum == @after_argnum
      ancestry_same and side_same and argnum_same

  _onClick: (e) =>
    # e.preventDefault()
    # e.stopPropagation()
    if @my_node.my_model.composite #TODO this would fail for singletons for example
      Alonzo.add_port_to_composite_model(@my_node.my_model.uuid, @after_argnum, @type)
    else
      Alonzo.add_port_to_submodel(@my_node.ancestry, @after_argnum, @type)
    Library.flush_to_database()
    Alonzo.render()

  _onMouseOver: () =>
    Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.over_new_cp_button
    Alonzo.volatile_state.mouse_over_new_cp_button = {
      ancestry:     @my_node.ancestry
      type:         @type
      after_argnum: @after_argnum
    }
    Alonzo.render()

  _onMouseOut: () =>
    Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.up
    Alonzo.volatile_state.mouse_over_new_cp_button = null
    Alonzo.render()
