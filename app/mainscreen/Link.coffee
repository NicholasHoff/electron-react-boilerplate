import md5 from 'js-md5'
import {ConnectionPort} from './ConnectionPort.coffee'
import Library from './Library.coffee'


class Link
  # my_node is the node inside which I am drawn, not necesarily a node I am connected to
  constructor: (@my_node, @from_cp, @to_cp) ->
    Alonzo.registry.register_link(this)
    @_draw()

  from_id_arg: () ->
    [@from_cp.id_if_source, @from_cp.argnum]

  to_id_arg: () ->
    [@to_cp.id_if_sink, @to_cp.argnum]

  _draw: () ->
    path_string = @_generate_path_string()
    stroke_color =
      if @is_selected()
        Alonzo.graphics_constants.link.stroke_color_selected
      else if this instanceof BubbleLink
        Alonzo.graphics_constants.bubble.border_stroke_color
      else
        Alonzo.graphics_constants.link.stroke_color

    Alonzo.draw_path({
      key:         md5(@to_cp.get_key() + "link")
      d:           path_string
      fill:        "transparent"
      stroke:      stroke_color
      strokeWidth: @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.link.stroke_width)
      onMouseDown: @_onMouseDown
    })

  _generate_path_string: () ->
    start_tagspace = @from_cp.right_connection_point_in_tagspace()
    end_tagspace   =   @to_cp.left_connection_point_in_tagspace()
    curve_strength_tagspace = @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.link.curve_strength)
    control_point_1_tagspace = Alonzo.Utils.shift_point_right_by(start_tagspace,  curve_strength_tagspace)
    control_point_2_tagspace = Alonzo.Utils.shift_point_right_by(end_tagspace,   -curve_strength_tagspace)

    "M "     + start_tagspace[0]           + "," + start_tagspace[1]           + " " +
      "C " + control_point_1_tagspace[0] + "," + control_point_1_tagspace[1] + " " +
             control_point_2_tagspace[0] + "," + control_point_2_tagspace[1] + " " +
             end_tagspace[0]             + "," + end_tagspace[1]

  _onMouseDown: (e) =>
    e.preventDefault()
    e.stopPropagation()
    Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.down_on_link
    Alonzo.volatile_state.drag_link.down_link_ancestry   = @my_node.ancestry
    Alonzo.volatile_state.drag_link.down_link_idargidarg = [@from_cp.id_if_source, @from_cp.argnum, @to_cp.id_if_sink, @to_cp.argnum]
    Alonzo.render() #need to render because the mouse overlay will probably have to be inserted

  delete_self: () ->
    @remove_from_selection()
    Library.remove_link_from_model(@my_node.my_model.uuid, @from_id_arg()[0], @from_id_arg()[1], @to_id_arg()[0], @to_id_arg()[1])

  is_selected: () ->
    for each in Alonzo.volatile_state.selected_links
      if @my_node.my_model.uuid is each.model_uuid and @to_id_arg()[0] is each.idargidarg[2] and @to_id_arg()[1] is each.idargidarg[3]
        return true
    return false

  # does not redraw, only alters the react state
  remove_from_selection: () ->
    sl = Alonzo.volatile_state.selected_links
    Alonzo.volatile_state.selected_links = (x for x in sl when not (@my_node.my_model.uuid is x.model_uuid and @to_id_arg()[0] is x.idargidarg[2] and @to_id_arg()[1] is x.idargidarg[3]))

  # does not redraw, only alters the react state
  add_to_selection: () ->
    x = [@from_id_arg()[0], @from_id_arg()[1], @to_id_arg()[0], @to_id_arg()[1]]
    Alonzo.volatile_state.selected_links.push({model_uuid: @my_node.my_model.uuid, idargidarg: x})

class BubbleLink extends Link
  constructor: (@from_cp, @to_cp) ->
    @my_node = @to_cp.enclosing_node_if_sink
    super(@my_node, @from_cp, @to_cp) #this is silly, but required for the => bindings in the superclass to work

  delete_self: () ->
    @remove_from_selection()
    Library.remove_source_from_bubble(@to_cp.my_node.ancestry)

  is_selected: () ->
    for each in Alonzo.volatile_state.selected_bubble_links
      if Alonzo.Utils.ancestry_same(each, @to_cp.my_node.ancestry)
        return true
    return false

  # does not redraw, only alters the react state
  remove_from_selection: () ->
    sl = Alonzo.volatile_state.selected_bubble_links
    Alonzo.volatile_state.selected_bubble_links = (x for x in sl when not Alonzo.Utils.ancestry_same(x, @to_cp.my_node.ancestry))

  # does not redraw, only alters the react state
  add_to_selection: () ->
    Alonzo.volatile_state.selected_bubble_links.push(@to_cp.my_node.ancestry)

class DanglingLink # too much dancing required for this to extend Link, better to keep things clear for now
  constructor: (@my_node, @fixed_cp, @dangling_position) -> #dangling_position is in parent's space
    @_draw()

  _draw: () ->
    path_string = @_generate_path_string()
    dash_array  = @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.link.dangling_dash_array)
    Alonzo.draw_path({
      key:             md5(@fixed_cp.get_key() + "dangling link")
      d:               path_string
      fill:            "transparent"
      stroke:          Alonzo.graphics_constants.link.dangling_color
      strokeWidth:     @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.link.stroke_width)
      strokeDasharray: "#{dash_array}, #{dash_array}"
    })

  _generate_path_string: () ->
    curve_strength_tagspace = @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.link.curve_strength)

    if Alonzo.Utils.ancestry_same(@fixed_cp.my_node.ancestry, @my_node.ancestry)
      # the fixed CP is one of the CPs of this node
      if @fixed_cp.type is ConnectionPort.types.input
        # the fixed CP is one of the input ports to this node
        start_tagspace           = @fixed_cp.right_connection_point_in_tagspace()
        control_point_1_tagspace = Alonzo.Utils.shift_point_right_by(start_tagspace, curve_strength_tagspace)
        end_tagspace             = @my_node.convert_point_to_tag_space(@dangling_position)
        control_point_2_tagspace = end_tagspace
      else
        # the fixed CP is one of the output ports of this node
        start_tagspace           = @my_node.convert_point_to_tag_space(@dangling_position)
        control_point_1_tagspace = start_tagspace
        end_tagspace             = @fixed_cp.left_connection_point_in_tagspace()
        control_point_2_tagspace = Alonzo.Utils.shift_point_right_by(end_tagspace, -curve_strength_tagspace)
    else
      # the fixed CP is on one of the child nodes of this node
      if Alonzo.volatile_state.drag_cp.down_cp.type is ConnectionPort.types.input
        # the fixed CP is one of the input ports to one of this node's children
        start_tagspace           = @my_node.convert_point_to_tag_space(@dangling_position)
        control_point_1_tagspace = start_tagspace
        end_tagspace             = @fixed_cp.left_connection_point_in_tagspace()
        control_point_2_tagspace = Alonzo.Utils.shift_point_right_by(end_tagspace, -curve_strength_tagspace)
      else
        # the fixed CP is one of the output ports of one of this node's children
        start_tagspace           = @fixed_cp.right_connection_point_in_tagspace()
        control_point_1_tagspace = Alonzo.Utils.shift_point_right_by(start_tagspace, curve_strength_tagspace)
        end_tagspace             = @my_node.convert_point_to_tag_space(@dangling_position)
        control_point_2_tagspace = end_tagspace

    "M "     + start_tagspace[0]           + "," + start_tagspace[1]           + " " +
      "C " + control_point_1_tagspace[0] + "," + control_point_1_tagspace[1] + " " +
             control_point_2_tagspace[0] + "," + control_point_2_tagspace[1] + " " +
             end_tagspace[0]             + "," + end_tagspace[1]

export {Link, BubbleLink, DanglingLink}
