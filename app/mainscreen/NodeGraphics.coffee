# class hierarchy
# ---------------
# NodeGraphics (abstract)
#   CompositeNodeGraphics
#     DiagramGraphics
#   NonCompositeNodeGraphics (abstract)
#     NoDetailNodeGraphics
#     NameOnlyNodeGraphics
#     NameAndPortLabelsNodeGraphics
#     SpecialContentsNodeGraphics (abstract)
#       BubbleGraphics
#       ResultGraphics
#       TextLineInputNodeGraphics
#       SetVariableNodeGraphics
#       TextBoxNodeGraphics

import React from 'react';
import md5 from 'js-md5'
import {ConnectionPort} from './ConnectionPort.coffee'
import Library from './Library.coffee'
import NewPortButton from './NewPortButton.coffee'
import {Link, DanglingLink} from './Link.coffee'
import StoredResults from './StoredResults.coffee'
import {
  Node,
  UserDataNode,
  RawInputNode,
  CodeNode,
  SmartInputNode,
  SetVariableNode,
  RefVariableNode,
  Bubble,
  ResultNode,
  Diagram
} from './Node.coffee'

class NodeGraphics #abstract
  # @ will have:
  # @my_node
  # @_internal_width    # these are the width and height of the internal space AS DRAWN, so for example
  # @_internal_height   # a composite model drawn as a noncomposite node will have internal width 1.0

  # this is only here so that functions directly under NodeGraphics can have access to @my_node
  constructor: (@my_node) ->

  _draw_connection_ports: () ->
    if @my_node.arity > 0
      for argnum in [1..@my_node.arity]
        [x, y] = @my_node.get_position_of_input_port(argnum)
        (new ConnectionPort(@my_node, argnum, ConnectionPort.types.input, x, y)).draw()

    if @my_node.coarity > 0
      for argnum in [1..@my_node.coarity]
        [x, y] = @my_node.get_position_of_output_port(argnum)
        (new ConnectionPort(@my_node, argnum, ConnectionPort.types.output, x, y)).draw()

    @_draw_sugared_map_brackets()

  # left_side and right_side are booleans indicating where buttons should be drawn
  _draw_new_port_buttons: (left_side, right_side) ->
    if left_side
      spacing = @_internal_height / (@my_node.arity + 1)
      for i in [0..@my_node.arity]
        x = 0
        y = (i * spacing) + (spacing / 2)
        new NewPortButton(@my_node, i, NewPortButton.types.left, x, y)
    if right_side
      spacing = @_internal_height / (@my_node.coarity + 1)
      for i in [0..@my_node.coarity]
        x = @_internal_width
        y = (i * spacing) + (spacing / 2)
        new NewPortButton(@my_node, i, NewPortButton.types.right, x, y)

  # these are overridden for Set/RefVariableNodeGraphics
  get_position_of_input_port: (argnum) ->
    if @my_node.arity > 0
      spacing = @_internal_height / (@my_node.arity + 1)
      [0, argnum * spacing]
    else
      console.error("someone asked for position of input port on a node with arity 0")

  get_position_of_output_port: (argnum) ->
    if @my_node.coarity > 0
      spacing = @_internal_height / (@my_node.coarity + 1)
      [@_internal_width, argnum * spacing]
    else
      console.error("someone asked for position of output port on a node with coarity 0")

  _draw_sugared_map_brackets: () ->
    # on inputs
    if @my_node.arity > 0 and @my_node.sugared_maps?
      for argnum in @my_node.sugared_maps
        [x, y]    = @my_node.convert_point_to_tag_space(@my_node.get_position_of_input_port(argnum))
        font_size = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius * Alonzo.graphics_constants.connection_port.sugared_map_size)
        offset    = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius * 2.0)
        Alonzo.draw_text("{", {
          x:          x - offset
          y:          y + font_size*0.25
          textAnchor: "middle"
          fontSize:   font_size
          fill:       Alonzo.graphics_constants.connection_port.stroke_color
          key:        md5(@my_node.ancestry + "input sugared map {" + argnum)
        })

    # on outputs
    if @my_node.coarity > 0 and @my_node.sugared_maps?
      for argnum in [1..@my_node.coarity]
        [x, y]    = @my_node.convert_point_to_tag_space(@my_node.get_position_of_output_port(argnum))
        font_size = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius * Alonzo.graphics_constants.connection_port.sugared_map_size)
        offset    = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius * 2.0)
        Alonzo.draw_text("}", {
          x:          x + offset
          y:          y + font_size*0.25
          textAnchor: "middle"
          fontSize:   font_size
          fill:       Alonzo.graphics_constants.connection_port.stroke_color
          key:        md5(@my_node.ancestry + "output sugared map }" + argnum)
        })

  # how much more dense is my internal space than my parents?
  # NonCompositeNodes still need this
  # NonCompositeNodes still need to have stuff draw in them, and that stuff needs to be scaled
  # the size of the internal space of the model, in the case of composite models, does not matter
  # NonCompositeNodes are considered to have an internal space with a width of 1.0 and a height determined by aspect ratio
  # they sill need to be able to convert points and magnitudes inside them into their parent space
  relative_density: () ->
    #it's OK to refer to my_model.size because this function will only be called
    #if this node is backed by a composite model
    #the width of my internal space / the width of me in my parent's space
    @_internal_width/@my_node.width

  tag_point_is_inside_node: (test_point_tag_space) ->
    [x, y] = @my_node.convert_point_from_tag_space(test_point_tag_space)
    return (x > 0) and (y > 0) and (x < @_internal_width) and (y < @_internal_height)

  _borderOnMouseDown: (e) =>
    #console.log("composite node oliver onmouseDown #{@my_node.ancestry}")
    Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.down_on_node
    mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)
    down_position_parent = @my_node.parent.convert_point_from_tag_space(mouse_position_tag)
    Alonzo.volatile_state.drag_node.down_offset_parent = Alonzo.Utils.subtract_vectors(@my_node.position, down_position_parent)
    Alonzo.volatile_state.drag_node.down_node_ancestry = @my_node.ancestry
    Alonzo.render() #need to render because the mouse overlay will probably have to be inserted

  _nodeNameOnMouseDown: (e) =>
    # e.preventDefault() # this needs to have the default because clicking out of a input box needs to cause it to loose focus
    e.stopPropagation()
    console.log("node name onmouseDown #{@my_node.ancestry}")
    Alonzo.volatile_state.ctrl_key_on_mouse_down  = e.ctrlKey
    Alonzo.volatile_state.shift_key_on_mouse_down = e.shiftKey
    Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.down_on_node_name

    # prepare to be dragging the node - so populate volatile_state.drag_node
    mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)
    down_position_parent = @my_node.parent.convert_point_from_tag_space(mouse_position_tag)
    Alonzo.volatile_state.drag_node.down_offset_parent = Alonzo.Utils.subtract_vectors(@my_node.position, down_position_parent)
    Alonzo.volatile_state.drag_node.down_node_ancestry = @my_node.ancestry
    Alonzo.render() #need to render because the mouse overlay will probably have to be inserted

class CompositeNodeGraphics extends NodeGraphics
  constructor: (my_node) ->
    super(my_node)
    @_internal_width  = @my_node.my_model.size?[0] #the ? is because this has to work for the diagram background, too
    @_internal_height = @my_node.my_model.size?[1]
    if not Alonzo.volatile_state.sugared_map_indicies[@my_node.ancestry]
      Alonzo.volatile_state.sugared_map_indicies[@my_node.ancestry] = 0

  draw: () ->
    @_draw_border_and_oliver()
    @_draw_content_background_rect()
    @_draw_grid_lines()
    @_draw_connection_ports()
    @_draw_new_port_buttons(true, true)
    @_draw_name() unless Alonzo.volatile_state.node_rename_text_box.draw_it and Alonzo.Utils.ancestry_same(@my_node.ancestry, Alonzo.volatile_state.node_rename_text_box.ancestry)
    @_draw_rename_text_box()
    @_draw_space_buttons()
    @_draw_child_nodes()
    @_draw_child_node_resizers()
    @_draw_links()
    @_draw_sugared_map_buttons()
    @_draw_drag_select_box()   # TODO - could move these, including the drag link, into render
    @_draw_drag_new_node_box() # the code would stay here but be called from render

  _draw_border_and_oliver: () ->
    [node_tagspace_x, node_tagspace_y] = @my_node.parent.convert_point_to_tag_space(@my_node.position)
    additional_height_from_oliver = @_get_oliver_height_tagspace() - @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)
    this_rect_tagspace_y = node_tagspace_y - additional_height_from_oliver
    this_rect_tagspace_x = node_tagspace_x
    this_rect_height     = @my_node.parent.convert_magnitude_to_tag_space(@my_node.height) + additional_height_from_oliver
    this_rect_width      = @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
    corner_radius        = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.corner_radius)

    color = if @my_node.is_selected() then Alonzo.graphics_constants.node.border_stroke_color_selected else Alonzo.graphics_constants.node.border_stroke_color
    Alonzo.draw_rect({
      key:         md5(@my_node.ancestry + "main box")
      x:           this_rect_tagspace_x
      y:           this_rect_tagspace_y
      width:       this_rect_width
      height:      this_rect_height
      stroke:      color
      strokeWidth: 2*@my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)
      fill:        color
      rx:          corner_radius
      ry:          corner_radius
      onMouseDown: @_borderOnMouseDown
    })

  _draw_content_background_rect: () ->
    [tagspace_x, tagspace_y] = @my_node.parent.convert_point_to_tag_space(@my_node.position)
    height_tagspace          = @my_node.parent.convert_magnitude_to_tag_space(@my_node.height)
    width_tagspace           = @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
    corner_radius            = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.corner_radius)

    color = Alonzo.get_background_color_by_level(@my_node.level)
    Alonzo.draw_rect({
      key:         md5(@my_node.ancestry + "content background")
      x:           tagspace_x
      y:           tagspace_y
      width:       width_tagspace
      height:      height_tagspace
      fill:        color
      rx:          corner_radius
      ry:          corner_radius
      onMouseDown: @_nodeBackgroundOnMouseDown
    })

  _get_oliver_height_tagspace: () ->
    #will not allow an oliver smaller than the border width
    min_ar = Alonzo.graphics_constants.node.oliver_min_aspect_ratio
    width  = @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
    height = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.oliver_height)
    border = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)

    if width / height < min_ar then height = width / min_ar
    if height < border then height = border

    height

  _draw_name: () ->
    name = @my_node.display_name

    # all in tagspace
    oliver_height    = @_get_oliver_height_tagspace()
    node_position    = @my_node.convert_point_to_tag_space(0, 0)
    half_width       = @my_node.convert_magnitude_to_tag_space(@_internal_width / 2)
    [x, y]           = Alonzo.Utils.add_vectors(node_position, [half_width, -oliver_height/2])
    font_size        = Alonzo.graphics_constants.node.name_font_size_composite * oliver_height
    font_size_offset = font_size * 0.3
    Alonzo.draw_text(name, {
      x:           x
      y:           y + font_size_offset
      textAnchor:  "middle"
      fontSize:    font_size
      fill:        Alonzo.graphics_constants.node.name_text_color_composite
      key:         md5(@my_node.ancestry + "node name" + name)
      onMouseDown: @_nodeNameOnMouseDown
    })

  _draw_rename_text_box: () ->
    vs = Alonzo.volatile_state
    unless vs.node_rename_text_box.draw_it and Alonzo.Utils.ancestry_same(@my_node.ancestry, vs.node_rename_text_box.ancestry)
      return

    # when the user presses enter while in the box, or clicks outside the box and it looses focus
    onUserEnteredNewName = (new_value) =>
      console.log("onUserEnteredNewName " + @my_node.ancestry + " " + new_value)
      Library.set_model_name(@my_node.my_model.uuid, new_value)
      Alonzo.volatile_state.node_rename_text_box.draw_it = false
      Library.flush_to_database()
      Alonzo.render()

    oliver_height    = @_get_oliver_height_tagspace()
    node_position    = @my_node.convert_point_to_tag_space(0, 0)
    node_width       = @my_node.convert_magnitude_to_tag_space(@_internal_width)
    text_field_x     = node_position[0] + 0.25*node_width
    text_field_y     = node_position[1] - oliver_height
    text_field_width = node_width*0.5

    Alonzo.make_text_field({
      key:            md5(@my_node.ancestry + "rename text field")
      x:              text_field_x
      y:              text_field_y
      width:          text_field_width
      height:         oliver_height
      current_value:  @my_node.my_model.name
      onNewValue:     onUserEnteredNewName
    })

  _draw_space_buttons: () ->
    agcn = Alonzo.graphics_constants.node

    inner_offset  = 0.1  # space between the arrow tails
    outter_offset = 0.15 # space between the arrow heads and the edge of the buton
    head_length   = 0.25 # the length of the head parts of the arrow head

    # the harpoon point should be the one that's at the same x as the tip point, this function will figure out the other one
    __draw_arrow = (tail_point, tip_point, harpoon_point, arrow_uniqueness) =>
      path_string = Alonzo.Utils.straight_line_path_string(tail_point[0], tail_point[1], tip_point[0], tip_point[1])
      Alonzo.draw_path({
        key:         md5("arrow line 1" + @my_node.ancestry + arrow_uniqueness)
        d:           path_string
        stroke:      agcn.space_buttons_stroke_color
        strokeWidth: agcn.space_buttons_stroke_width * oliver_height
      })

      path_string = Alonzo.Utils.straight_line_path_string(harpoon_point[0], harpoon_point[1], tip_point[0], tip_point[1])
      Alonzo.draw_path({
        key:         md5("arrow line 2" + @my_node.ancestry + arrow_uniqueness)
        d:           path_string
        stroke:      agcn.space_buttons_stroke_color
        strokeWidth: agcn.space_buttons_stroke_width * oliver_height
        strokeLinecap: "square"
      })

      diff = tip_point[1] - harpoon_point[1]
      path_string = Alonzo.Utils.straight_line_path_string(tip_point[0] + diff, tip_point[1], tip_point[0], tip_point[1])
      Alonzo.draw_path({
        key:         md5("arrow line 3" + @my_node.ancestry + arrow_uniqueness)
        d:           path_string
        stroke:      agcn.space_buttons_stroke_color
        strokeWidth: agcn.space_buttons_stroke_width * oliver_height
      })

    # all in tagspace
    oliver_height = @_get_oliver_height_tagspace()
    node_position = @my_node.convert_point_to_tag_space(0, 0)
    button_width  = agcn.space_buttons_width * oliver_height

    # remove space button
    tagspace_upper_left_x = node_position[0] + agcn.space_buttons_inset*oliver_height
    tagspace_upper_left_y = node_position[1] - oliver_height/2 - button_width/2
    tagspace_bot_right_x  = tagspace_upper_left_x + button_width
    tagspace_bot_right_y  = tagspace_upper_left_y + button_width

    tip_point     = [tagspace_upper_left_x + button_width*outter_offset,       tagspace_bot_right_y  - button_width*outter_offset                             ]
    tail_point    = [tagspace_upper_left_x + button_width*(0.5-inner_offset),  tagspace_bot_right_y  - button_width*(0.5-inner_offset)                        ]
    harpoon_point = [tagspace_upper_left_x + button_width*outter_offset,       tagspace_bot_right_y  - button_width*outter_offset - button_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "remove space button arrow 1")

    tip_point     = [tagspace_bot_right_x  - button_width*outter_offset,       tagspace_upper_left_y + button_width*outter_offset                             ]
    tail_point    = [tagspace_upper_left_x + button_width*(0.5+inner_offset),  tagspace_bot_right_y  - button_width*(0.5+inner_offset)                        ]
    harpoon_point = [tagspace_bot_right_x  - button_width*outter_offset,       tagspace_upper_left_y + button_width*outter_offset + button_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "remove space button arrow 2")

    Alonzo.draw_rect({
      key:         md5("remove space button" + @my_node.ancestry)
      x:           tagspace_upper_left_x
      y:           tagspace_upper_left_y
      width:       button_width
      height:      button_width
      stroke:      agcn.space_buttons_stroke_color
      strokeWidth: agcn.space_buttons_stroke_width*oliver_height
      fill:        "white"
      fillOpacity: 0
      ry:          agcn.space_buttons_corner_radius*oliver_height
      rx:          agcn.space_buttons_corner_radius*oliver_height
      onClick:     @_remove_space
    })

    # add space button
    tagspace_upper_left_x = node_position[0] + agcn.space_buttons_inset*oliver_height + button_width + agcn.space_buttons_separation*oliver_height
    tagspace_upper_left_y = node_position[1] - oliver_height/2 - button_width/2
    tagspace_bot_right_x  = tagspace_upper_left_x + button_width
    tagspace_bot_right_y  = tagspace_upper_left_y + button_width

    tail_point    = [tagspace_upper_left_x + button_width*outter_offset,       tagspace_bot_right_y  - button_width*outter_offset                                  ]
    tip_point     = [tagspace_upper_left_x + button_width*(0.5-inner_offset),  tagspace_bot_right_y  - button_width*(0.5-inner_offset)                             ]
    harpoon_point = [tagspace_upper_left_x + button_width*(0.5-inner_offset),  tagspace_bot_right_y  - button_width*(0.5-inner_offset) + button_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "add space button arrow 1")

    tail_point    = [tagspace_bot_right_x  - button_width*outter_offset,       tagspace_upper_left_y + button_width*outter_offset                                  ]
    tip_point     = [tagspace_upper_left_x + button_width*(0.5+inner_offset),  tagspace_bot_right_y  - button_width*(0.5+inner_offset)                             ]
    harpoon_point = [tagspace_bot_right_x  - button_width*(0.5-inner_offset),  tagspace_upper_left_y + button_width*(0.5-inner_offset) - button_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "add space button arrow 2")

    Alonzo.draw_rect({
      key:         md5("add space button" + @my_node.ancestry)
      x:           tagspace_upper_left_x
      y:           tagspace_upper_left_y
      width:       button_width
      height:      button_width
      stroke:      agcn.space_buttons_stroke_color
      strokeWidth: agcn.space_buttons_stroke_width*oliver_height
      fill:        "white"
      fillOpacity: 0
      rx:          agcn.space_buttons_corner_radius*oliver_height
      ry:          agcn.space_buttons_corner_radius*oliver_height
      onClick:     @_add_space
    })

  _draw_child_nodes: () ->
    # draw child submodels
    for each_submodel in @my_node.my_model.submodels
      each_ancestry = Alonzo.Utils.list_append(@my_node.ancestry, each_submodel.submodel_id)
      if each_submodel.submodel_type is "singleton"
        x = each_submodel
        if x.singleton_input.type is "raw" or x.singleton_input.type is "auto"
          new RawInputNode(@my_node, each_ancestry, x.position, x.width, x.singleton_input.value)
        else if x.singleton_input.type is "semantic_interpretation"
          new SmartInputNode(@my_node, each_ancestry, x.position, x.width, x.singleton_input.value)
      else if each_submodel.submodel_type is "set_variable"
        x = each_submodel
        new SetVariableNode(@my_node, each_ancestry, x.position, x.width, x.variable_name)
      else if each_submodel.submodel_type is "ref_variable"
        x = each_submodel
        new RefVariableNode(@my_node, each_ancestry, x.position, x.width, x.variable_name)
      else if each_submodel.submodel_type is "codenode"
        x = each_submodel
        new CodeNode(@my_node, each_ancestry, x.position, x.width, x.contents)
      else if each_submodel.submodel_type is "model"
        [arity, coarity] = Alonzo.get_submodel_arity_coarity(each_submodel)
        width = each_submodel.width
        aspect_ratio = Alonzo.get_node_aspect_ratio(each_submodel, arity, coarity)
        height = width/aspect_ratio
        child_model = Library.get_model_for_uuid(each_submodel.uuid)
        sugared_maps = Library.get_submodel_sugared_maps(@my_node.my_model.uuid, each_submodel.submodel_id)
        if child_model.data
          new UserDataNode(@my_node, each_ancestry, child_model, each_submodel.position, width, height, arity, coarity)
        else
          new         Node(@my_node, each_ancestry, child_model, each_submodel.position, width, height, arity, coarity, sugared_maps)
      else if each_submodel.submodel_type is "result"
        new ResultNode(@my_node, each_ancestry, each_submodel.position, each_submodel.width, each_submodel.height)
      else
        console.error("don't know what to do with submodel_type " + each_submodel.submodel_type)

    # draw child bubbles
    for each_bubble in Library.get_bubbles_by_parent_ancestry(@my_node.ancestry)
      new Bubble(@my_node, each_bubble.ancestry, each_bubble.source, each_bubble.position, each_bubble.size[0], each_bubble.size[1])

  _draw_child_node_resizers: () ->
    for each_child in Alonzo.registry.child_nodes_of(@my_node)
      parent_bot_right = each_child.bot_right_parent_space()
      resizer_width_parent = Alonzo.graphics_constants.node.resizer_width_muliplier * (Alonzo.graphics_constants.node.corner_radius + Alonzo.graphics_constants.node.border_stroke_width)
      upper_left_x = parent_bot_right[0] + Alonzo.graphics_constants.node.border_stroke_width/2 - resizer_width_parent
      upper_left_y = parent_bot_right[1] + Alonzo.graphics_constants.node.border_stroke_width/2 - resizer_width_parent
      bot_right_x  = upper_left_x + resizer_width_parent
      bot_right_y  = upper_left_y + resizer_width_parent
      [tagspace_upper_left_x, tagspace_upper_left_y] = @my_node.convert_point_to_tag_space(upper_left_x, upper_left_y)
      [tagspace_bot_right_x,  tagspace_bot_right_y ] = @my_node.convert_point_to_tag_space(bot_right_x,  bot_right_y )
      tagspace_width = @my_node.convert_magnitude_to_tag_space(resizer_width_parent)
      opacity =
        if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.over_node_resizer and Alonzo.Utils.ancestry_same(each_child.ancestry, Alonzo.volatile_state.node_resizer_data.ancestry)
          0.7
        else if (Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_node_resizer or Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_node_resizer) and Alonzo.Utils.ancestry_same(each_child.ancestry, Alonzo.volatile_state.node_resizer_data.ancestry)
          1.0
        else
          0.0

      this_on_mouse_over = ( (each_child) ->
        () =>
          Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.over_node_resizer
          Alonzo.volatile_state.node_resizer_data.ancestry = each_child.ancestry
          Alonzo.render()
        )(each_child)

      this_on_mouse_out = () =>
        if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_node_resizer
          # this shouldn't fire, you're actually dragging
          # don't change anything
        else
          Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.up
          Alonzo.volatile_state.node_resizer_data.ancestry = null
          Alonzo.render()

      this_on_mouse_down = ( (each_child) =>
        (e) =>
          e.stopPropagation()
          e.preventDefault()
          Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.down_on_node_resizer
          Alonzo.volatile_state.node_resizer_data.ancestry = each_child.ancestry
          mouse_position_tag      = Alonzo.abs_to_rel(e.clientX, e.clientY)
          mouse_position_my_space = @my_node.convert_point_from_tag_space(mouse_position_tag)
          offset                  = Alonzo.Utils.subtract_vectors(each_child.bot_right_parent_space(), mouse_position_my_space)
          Alonzo.volatile_state.node_resizer_data.offset_parent = offset
          Alonzo.render()
        )(each_child)

      path_string = Alonzo.Utils.straight_line_path_string(
        tagspace_upper_left_x,
        tagspace_bot_right_y,
        tagspace_bot_right_x,
        tagspace_upper_left_y
      )
      Alonzo.draw_path({
        key:         md5("resizer line 1" + each_child.ancestry)
        d:           path_string
        stroke:      Alonzo.graphics_constants.node.resizer_line_color
        strokeWidth: tagspace_width*0.1
        strokeOpacity: opacity
      })

      path_string = Alonzo.Utils.straight_line_path_string(
        tagspace_upper_left_x + tagspace_width*0.5,
        tagspace_bot_right_y,
        tagspace_bot_right_x,
        tagspace_upper_left_y + tagspace_width*0.5
      )
      Alonzo.draw_path({
        key:         md5("resizer line 2" + each_child.ancestry)
        d:           path_string
        stroke:      Alonzo.graphics_constants.node.resizer_line_color
        strokeWidth: tagspace_width*0.1
        strokeOpacity: opacity
      })

      Alonzo.draw_rect({
        key:         md5("child node resizer" + each_child.ancestry)
        x:           tagspace_upper_left_x
        y:           tagspace_upper_left_y
        width:       tagspace_width
        height:      tagspace_width
        # stroke:      border_stroke_color
        # strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)
        fill:        "blue"
        fillOpacity: 0
        onMouseOver: this_on_mouse_over
        onMouseOut:  this_on_mouse_out
        onMouseDown: this_on_mouse_down
      })

  _draw_links: () ->
    # draw main links
    for each_link in @my_node.my_model.links
      [from_id, from_argnum, to_id, to_argnum] = each_link
      if from_id is 0
        from_cp = Alonzo.registry.get_input_cp(                          @my_node.ancestry,           from_argnum)
      else
        from_cp = Alonzo.registry.get_output_cp(Alonzo.Utils.list_append(@my_node.ancestry, from_id), from_argnum)

      if to_id   is 0
        to_cp   = Alonzo.registry.get_output_cp(                         @my_node.ancestry,           to_argnum)
      else
        to_cp   = Alonzo.registry.get_input_cp( Alonzo.Utils.list_append(@my_node.ancestry, to_id  ), to_argnum)

      new Link(@my_node, from_cp, to_cp)

    # draw bubble links
    for each_bubble in Library.get_bubbles_by_parent_ancestry(@my_node.ancestry) when each_bubble.source? and each_bubble.source.length isnt 0
      [from_id, from_argnum] = each_bubble.source

      if from_id is 0
        from_cp = Alonzo.registry.get_input_cp(                          @my_node.ancestry,           from_argnum)
      else
        from_cp = Alonzo.registry.get_output_cp(Alonzo.Utils.list_append(@my_node.ancestry, from_id), from_argnum)

      to_cp = Alonzo.registry.get_input_cp(each_bubble.ancestry, 1)

      new BubbleLink(from_cp, to_cp)

    # draw dangling link from dragging, if necessary
    if Alonzo.volatile_state.drag_cp.dangling_link.draw_it
      if Alonzo.Utils.ancestry_same(Alonzo.volatile_state.drag_cp.dangling_link.parent_ancestry, @my_node.ancestry)
        fixed_cp = Alonzo.registry.get_cp(
          Alonzo.volatile_state.drag_cp.down_cp.ancestry,
          Alonzo.volatile_state.drag_cp.down_cp.argnum,
          Alonzo.volatile_state.drag_cp.down_cp.type
        )
        new DanglingLink(@my_node, fixed_cp, Alonzo.volatile_state.drag_cp.dangling_link.dangling_position)

  _draw_grid_lines: () ->
    spacing = Alonzo.graphics_constants.node.grid_line_spacing

    if spacing == 0 then return

    num_horizontal_lines = Math.floor(@_internal_height / spacing)
    num_vertical_lines   = Math.floor(@_internal_width  / spacing)

    for i in [1..num_horizontal_lines]
      x1 = 0
      y1 = i * spacing
      x2 = @_internal_width
      y2 = i * spacing
      [x1_tag, y1_tag] = @my_node.convert_point_to_tag_space(x1, y1)
      [x2_tag, y2_tag] = @my_node.convert_point_to_tag_space(x2, y2)
      path_string = Alonzo.Utils.straight_line_path_string(x1_tag, y1_tag, x2_tag, y2_tag)

      Alonzo.draw_path({
        key:         md5("horizontal grid line" + i + @my_node.ancestry)
        d:           path_string
        stroke:      Alonzo.graphics_constants.node.grid_line_color
        strokeWidth: @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.grid_line_thickness)
      })
    for i in [1..num_vertical_lines]
      x1 = i * spacing
      y1 = 0
      x2 = i * spacing
      y2 = @_internal_height
      [x1_tag, y1_tag] = @my_node.convert_point_to_tag_space(x1, y1)
      [x2_tag, y2_tag] = @my_node.convert_point_to_tag_space(x2, y2)
      path_string = Alonzo.Utils.straight_line_path_string(x1_tag, y1_tag, x2_tag, y2_tag)

      Alonzo.draw_path({
        key:         md5("vertical grid line" + i + @my_node.ancestry)
        d:           path_string
        stroke:      Alonzo.graphics_constants.node.grid_line_color
        strokeWidth: @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.grid_line_thickness)
      })

  _draw_drag_select_box: () ->
    q = Alonzo.volatile_state.drag_select_box
    if q.draw_it and Alonzo.Utils.ancestry_same(@my_node.ancestry, q.ancestry)
      [tagspace_x,     tagspace_y]     = @my_node.convert_point_to_tag_space(q.top_left_parent_space)
      [bot_right_ts_x, bot_right_ts_y] = @my_node.convert_point_to_tag_space(q.bot_right_parent_space)

      Alonzo.draw_rect({
        key:         md5("drag select box")
        x:           tagspace_x
        y:           tagspace_y
        width:       bot_right_ts_x - tagspace_x
        height:      bot_right_ts_y - tagspace_y
        stroke:      Alonzo.graphics_constants.drag_select_box.border_stroke_color
        strokeWidth: @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.drag_select_box.border_stroke_width)
        fill:        Alonzo.graphics_constants.drag_select_box.fill_color
        fillOpacity: Alonzo.graphics_constants.drag_select_box.fill_opacity
        rx:          0
        ry:          0
      })

  _draw_drag_new_node_box: () ->
    q = Alonzo.volatile_state.drag_new_node_box
    if q.draw_it and Alonzo.Utils.ancestry_same(@my_node.ancestry, q.ancestry)
      [tagspace_x,     tagspace_y]     = @my_node.convert_point_to_tag_space(q.top_left_parent_space)
      [bot_right_ts_x, bot_right_ts_y] = @my_node.convert_point_to_tag_space(q.bot_right_parent_space)
      dash_array                       = @my_node.convert_magnitude_to_tag_space(4)

      Alonzo.draw_rect({
        key:         md5("drag new node box")
        x:           tagspace_x
        y:           tagspace_y
        width:       bot_right_ts_x - tagspace_x
        height:      bot_right_ts_y - tagspace_y
        stroke:      Alonzo.graphics_constants.node.border_stroke_color
        strokeWidth: @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)
        fill:        "transparent"
        fillOpacity: 0
        rx:          @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.corner_radius)
        ry:          @my_node.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.corner_radius)
        strokeDasharray: "#{dash_array}, #{dash_array}"
      })

  _draw_sugared_map_buttons: () ->
    return unless @my_node.sugared_maps

    exists_descendent_bubble = false
    for each_node in Alonzo.registry.descendants_of(@my_node)
      if each_node instanceof ResultNode
        exists_descendent_bubble = true
        break
    return unless exists_descendent_bubble

    agcn                     = Alonzo.graphics_constants.node

    # all in tagspace
    oliver_height     = @_get_oliver_height_tagspace()
    node_position     = @my_node.convert_point_to_tag_space(0, 0)
    button_width      = agcn.space_buttons_width * oliver_height
    node_width        = @my_node.convert_magnitude_to_tag_space(@_internal_width)
    font_size         = button_width * 1.0
    font_size_offset  = font_size * 0.25
    buttons_inset     = agcn.space_buttons_inset*oliver_height
    button_separation = agcn.space_buttons_separation * oliver_height

    map_index_x       = node_position[0] + node_width - buttons_inset - font_size
    right_arrow_box_x = map_index_x       - button_separation - button_width
    left_arrow_box_x  = right_arrow_box_x - button_separation - button_width
    right_arrow_x     = right_arrow_box_x + button_width/2
    left_arrow_x      = left_arrow_box_x  + button_width/2
    braces_x          = left_arrow_box_x - 1.5*font_size

    text_y            = node_position[1] - oliver_height/2
    box_y             = node_position[1] - oliver_height/2 - button_width/2

    # the "{}"
    Alonzo.draw_text("{ }", {
      x:          braces_x
      y:          text_y + font_size_offset
      textAnchor: "start"
      fontSize:   font_size
      fill:       Alonzo.graphics_constants.node.space_buttons_stroke_color
      key:        md5(@my_node.ancestry + "{} on sugared map index controls")
    })

    # the left pointing arrow
    Alonzo.draw_text("<", {
      x:          left_arrow_x
      y:          text_y + font_size_offset
      textAnchor: "middle"
      fontSize:   font_size * 0.8
      fill:       Alonzo.graphics_constants.node.space_buttons_stroke_color
      key:        md5(@my_node.ancestry + "< on sugared map index controls")
    })

    Alonzo.draw_rect({
      key:         md5("sugared map decrease index rect" + @my_node.ancestry)
      x:           left_arrow_box_x
      y:           box_y
      width:       button_width
      height:      button_width
      stroke:      Alonzo.graphics_constants.node.space_buttons_stroke_color
      strokeWidth: agcn.space_buttons_stroke_width*oliver_height
      fill:        "white"
      fillOpacity: 0
      rx:          agcn.space_buttons_corner_radius*oliver_height
      ry:          agcn.space_buttons_corner_radius*oliver_height
      onClick:     @_decrement_sugared_map_index
    })

    # the right pointing arrow
    Alonzo.draw_text(">", {
      x:          right_arrow_x
      y:          text_y + font_size_offset
      textAnchor: "middle"
      fontSize:   font_size * 0.8
      fill:       Alonzo.graphics_constants.node.space_buttons_stroke_color
      key:        md5(@my_node.ancestry + "> on sugared map index controls")
    })

    Alonzo.draw_rect({
      key:         md5("sugared map increase index rect" + @my_node.ancestry)
      x:           right_arrow_box_x
      y:           box_y
      width:       button_width
      height:      button_width
      stroke:      Alonzo.graphics_constants.node.space_buttons_stroke_color
      strokeWidth: agcn.space_buttons_stroke_width*oliver_height
      fill:        "white"
      fillOpacity: 0
      rx:          agcn.space_buttons_corner_radius*oliver_height
      ry:          agcn.space_buttons_corner_radius*oliver_height
      onClick:     @_increment_sugared_map_index
    })

    # the map index
    Alonzo.draw_text(Alonzo.volatile_state.sugared_map_indicies[@my_node.ancestry], {
      x:          map_index_x
      y:          text_y + font_size_offset
      textAnchor: "start"
      fontSize:   font_size
      fill:       Alonzo.graphics_constants.node.space_buttons_stroke_color
      key:        md5(@my_node.ancestry + "sugared map index")
    })

  _decrement_sugared_map_index: () =>
    console.log("decrement sugared map index")
    Alonzo.volatile_state.sugared_map_indicies[@my_node.ancestry] = Alonzo.volatile_state.sugared_map_indicies[@my_node.ancestry] - 1
    if Alonzo.volatile_state.sugared_map_indicies[@my_node.ancestry] < 0
      Alonzo.volatile_state.sugared_map_indicies[@my_node.ancestry] = 0
    Alonzo.render()

  _increment_sugared_map_index: () =>
    console.log("increment sugared map index")
    Alonzo.volatile_state.sugared_map_indicies[@my_node.ancestry] = Alonzo.volatile_state.sugared_map_indicies[@my_node.ancestry] + 1
    Alonzo.render()

  _nodeBackgroundOnMouseDown: (e) =>
    # e.preventDefault() # this needs to have the default because clicking out of a input box needs to cause it to loose focus
    e.stopPropagation()
    #console.log("composite node background onmouseDown #{@my_node.ancestry}")
    Alonzo.volatile_state.ctrl_key_on_mouse_down  = e.ctrlKey
    Alonzo.volatile_state.shift_key_on_mouse_down = e.shiftKey
    Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.down_on_background
    Alonzo.volatile_state.drag_background.mousedown_position   = Alonzo.abs_to_rel(e.clientX, e.clientY)
    Alonzo.volatile_state.drag_background.mousedown_viewport00 = Alonzo.volatile_state.viewport_00 #need clone?
    Alonzo.render() #need to render because the mouse overlay will probably have to be inserted

  _add_space: () =>
    new_width    = @_internal_width  * Alonzo.volatile_state.more_space_button
    new_height   = @_internal_height * Alonzo.volatile_state.more_space_button
    Library.set_model_internal_space(@my_node.my_model.uuid, new_width, new_height)

    width_added  = new_width  - @_internal_width
    height_added = new_height - @_internal_height
    for each_child in Alonzo.registry.child_nodes_of(@my_node)
      [current_x, current_y] = each_child.top_left_parent_space()
      new_x = current_x + width_added/2
      new_y = current_y + height_added/2
      each_child.transplant_to_new_parent_at_location(@my_node, [new_x, new_y])
    Library.flush_to_database()
    Alonzo.render()

  _remove_space: () =>
    new_width    = @_internal_width  / Alonzo.volatile_state.more_space_button
    new_height   = @_internal_height / Alonzo.volatile_state.more_space_button
    Library.set_model_internal_space(@my_node.my_model.uuid, new_width, new_height)

    width_added  = new_width  - @_internal_width
    height_added = new_height - @_internal_height
    for each_child in Alonzo.registry.child_nodes_of(@my_node)
      [current_x, current_y] = each_child.top_left_parent_space()
      new_x = current_x + width_added/2
      new_y = current_y + height_added/2
      each_child.transplant_to_new_parent_at_location(@my_node, [new_x, new_y])
    Library.flush_to_database()
    Alonzo.render()

class NonCompositeNodeGraphics extends NodeGraphics #abstract
  constructor: (my_node) ->
    super(my_node)
    if @my_node.width > @my_node.height and false
      #wide
      @_internal_width  = @my_node.width / @my_node.height
      @_internal_height = 1.0
    else
      #tall
      @_internal_width  = 1.0
      @_internal_height = @my_node.height / @my_node.width

  draw: () ->
    @_draw_main_box()
    @_draw_connection_ports()

  _draw_main_box: () ->
    [x, y] = @my_node.position

    [tagspace_x, tagspace_y] = @my_node.parent.convert_point_to_tag_space(x, y)
    border_stroke_color = if @my_node.is_selected() then Alonzo.graphics_constants.node.border_stroke_color_selected else Alonzo.graphics_constants.node.border_stroke_color
    Alonzo.draw_rect({
      key:         md5(@my_node.ancestry + "main box")
      x:           tagspace_x
      y:           tagspace_y
      width:       @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
      height:      @my_node.parent.convert_magnitude_to_tag_space(@my_node.height)
      stroke:      border_stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)
      fill:        "white"
      fillOpacity: 0
      rx:          @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.corner_radius)
      ry:          @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.corner_radius)
      onMouseDown: @_nodeBackgroundOnMouseDown #there's no move and up, those are handled by the mouse overlay
    })

  _nodeBackgroundOnMouseDown: (e) =>
    #console.log("noncomposite node background onmouseDown #{@my_node.ancestry}")
    Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.down_on_node
    mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)
    down_position_parent = @my_node.parent.convert_point_from_tag_space(mouse_position_tag)
    Alonzo.volatile_state.drag_node.down_offset_parent = Alonzo.Utils.subtract_vectors(@my_node.position, down_position_parent)
    Alonzo.volatile_state.drag_node.down_node_ancestry = @my_node.ancestry
    Alonzo.render() #need to render because the mouse overlay will probably have to be inserted

class NoDetailNodeGraphics extends NonCompositeNodeGraphics
  constructor: (my_node) ->
    super(my_node)

  draw: () ->
    super()

class NameOnlyNodeGraphics extends NonCompositeNodeGraphics
  constructor: (my_node) ->
    super(my_node)

  draw: () ->
    super()
    @_draw_name()
    @_draw_new_port_buttons(@my_node.variable_arity, @my_node.variable_coarity)

  _draw_name: () ->
    name = @my_node.display_name

    ar = @_internal_width/@_internal_height
    ar_adjustment = if ar > 1 then 1/ar else 1
    ar_adjustment = 1

    threshold = 10
    letters_adjustment = if name.length > threshold then 1/Math.pow(name.length - threshold, 0.3) else 1

    font_size = Alonzo.graphics_constants.node.name_font_size * ar_adjustment * letters_adjustment
    push_down_for_text_height = 0.5 * font_size
    [x, y]    = @my_node.convert_point_to_tag_space(@_internal_width/2, (@_internal_height/2) + push_down_for_text_height)
    Alonzo.draw_text(name, {
      x:          x
      y:          y
      textAnchor: "middle"
      fontSize:   @my_node.convert_magnitude_to_tag_space(font_size)
      fill:       Alonzo.graphics_constants.node.name_text_color
      key:        md5(@my_node.ancestry + "node name" + name)
      onMouseDown: @_nodeNameOnMouseDown
    })

class NameAndPortLabelsNodeGraphics extends NonCompositeNodeGraphics
  constructor: (my_node) ->
    super(my_node)

  draw: () ->
    super()
    @_draw_name()
    @_draw_port_labels()
    @_draw_new_port_buttons(@my_node.variable_arity, @my_node.variable_coarity)

  _draw_name: () ->
    name = @my_node.display_name

    threshold = 10
    letters_adjustment = if name.length > threshold then 1/Math.pow(name.length - threshold, 0.4) else 1

    font_size = Alonzo.graphics_constants.node.name_font_size * letters_adjustment
    push_down_for_text_height = 0.5 * font_size
    push_up_for_inputs = if @my_node.arity > 4 then -2.3 * font_size else 0
    [x, y]    = @my_node.convert_point_to_tag_space(@_internal_width/2, (@_internal_height*0.15) + push_down_for_text_height + push_up_for_inputs)
    Alonzo.draw_text(name, {
      x:          x
      y:          y
      textAnchor: "middle"
      fontSize:   @my_node.convert_magnitude_to_tag_space(font_size)
      fill:       Alonzo.graphics_constants.node.name_text_color
      key:        md5(@my_node.ancestry + "node name" + name)
      onMouseDown: @_nodeNameOnMouseDown
    })

  _draw_port_labels: () ->
    really_exists = (x) -> x? and x isnt ""

    # if there's actually something on the output AND something on the input, then offset, else not
    collision_offset = 0.05
    [input_collision_offset, output_collision_offset] =
      if @my_node.coarity > 0 and really_exists(@my_node.get_output_label(1))
        if @my_node.arity > 0 and really_exists(@my_node.get_input_label(1))
          [-collision_offset, collision_offset]
          [0, 0]
        else
          [0, 0]
      else
        [0, 0]

    if @my_node.arity > 0
      for argnum in [1..@my_node.arity]
        label = @my_node.get_input_label(argnum)
        if label?
          ar = @_internal_width/@_internal_height
          ar_adjustment = if ar > 1 then 1/Math.pow(ar, 0.5) else 1

          threshold = 10
          letters_adjustment = if label.length > threshold then 1/Math.pow(label.length - threshold, 0.35) else 1
          font_size = Alonzo.graphics_constants.node.label_font_size * letters_adjustment * ar_adjustment
          push_down_for_text_height = 0.5 * font_size

          [x, y] = @my_node.get_position_of_input_port(argnum)
          [x_tag, y_tag] = @my_node.convert_point_to_tag_space(
            x + Alonzo.graphics_constants.node.label_horizontal_offset * ar_adjustment,
            y - Alonzo.graphics_constants.node.label_vertical_offset + push_down_for_text_height + input_collision_offset
          )
          Alonzo.draw_text(label, {
            x:          x_tag
            y:          y_tag
            textAnchor: "start"
            fontSize:   @my_node.convert_magnitude_to_tag_space(font_size)
            fill:       Alonzo.graphics_constants.node.name_text_color
            key:        md5("port label" + "input" + @my_node.ancestry + argnum)
          })
    if @my_node.coarity > 0
      for argnum in [1..@my_node.coarity]
        label = @my_node.get_output_label(argnum)
        if label?
          ar = @_internal_width/@_internal_height
          ar_adjustment = if ar > 1 then 1/Math.pow(ar, 0.5) else 1

          threshold = 10
          letters_adjustment = if label.length > threshold then 1/Math.pow(label.length - threshold, 0.35) else 1
          font_size = Alonzo.graphics_constants.node.label_font_size * letters_adjustment * ar_adjustment
          push_down_for_text_height = 0.5 * font_size

          [x, y] = @my_node.get_position_of_output_port(argnum)
          [x_tag, y_tag] = @my_node.convert_point_to_tag_space(
            x - Alonzo.graphics_constants.node.label_horizontal_offset * ar_adjustment,
            y - Alonzo.graphics_constants.node.label_vertical_offset + push_down_for_text_height + output_collision_offset
          )
          Alonzo.draw_text(label, {
            x:          x_tag
            y:          y_tag
            textAnchor: "end"
            fontSize:   @my_node.convert_magnitude_to_tag_space(font_size)
            fill:       Alonzo.graphics_constants.node.name_text_color
            key:        md5("port label" + "output" + @my_node.ancestry + argnum)
          })

class SpecialContentsNodeGraphics extends NonCompositeNodeGraphics #abstract
  constructor: (my_node) ->
    super(my_node)

class TextLineInputNodeGraphics extends SpecialContentsNodeGraphics
  constructor: (my_node) ->
    super(my_node)

  draw: () ->
    @_draw_border_and_oliver()
    @_draw_name()
    @_draw_connection_ports()
    @_draw_text_field()

  _draw_border_and_oliver: () ->
    [node_tagspace_x, node_tagspace_y] = @my_node.parent.convert_point_to_tag_space(@my_node.position)
    additional_height_from_oliver = @_get_oliver_height_tagspace() - @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)
    this_rect_tagspace_y = node_tagspace_y - additional_height_from_oliver
    this_rect_tagspace_x = node_tagspace_x
    this_rect_height     = @my_node.parent.convert_magnitude_to_tag_space(@my_node.height) + additional_height_from_oliver
    this_rect_width      = @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
    corner_radius        = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.corner_radius)

    color = if @my_node.is_selected() then Alonzo.graphics_constants.node.border_stroke_color_selected else Alonzo.graphics_constants.node.border_stroke_color
    Alonzo.draw_rect({
      key:         md5(@my_node.ancestry + "main box")
      x:           this_rect_tagspace_x
      y:           this_rect_tagspace_y
      width:       this_rect_width
      height:      this_rect_height
      stroke:      color
      strokeWidth: 2*@my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)
      fill:        color
      rx:          corner_radius
      ry:          corner_radius
      onMouseDown: @_borderOnMouseDown
    })

  _get_oliver_height_tagspace: () ->
    #will not allow an oliver smaller than the border width
    min_ar = Alonzo.graphics_constants.node.oliver_min_aspect_ratio
    width  = @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
    height = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.oliver_height)
    border = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)

    if width / height < min_ar then height = width / min_ar
    if height < border then height = border

    height

  _draw_name: () ->
    name = @my_node.display_name

    # all in tagspace
    oliver_height    = @_get_oliver_height_tagspace()
    node_position    = @my_node.convert_point_to_tag_space(0, 0)
    half_width       = @my_node.convert_magnitude_to_tag_space(@_internal_width / 2)
    [x, y]           = Alonzo.Utils.add_vectors(node_position, [half_width, -oliver_height/2])
    font_size        = Alonzo.graphics_constants.node.name_font_size_composite * oliver_height
    font_size_offset = font_size * 0.3
    Alonzo.draw_text(name, {
      x:           x
      y:           y + font_size_offset
      textAnchor:  "middle"
      fontSize:    font_size
      fill:        Alonzo.graphics_constants.node.name_text_color_composite
      key:         md5(@my_node.ancestry + "node name" + name)
      onMouseDown: @_borderOnMouseDown
    })

  _draw_text_field: () ->
    # @width                   is node width  in parent space
    # @height                  is node height in parent space (fixed)
    # internal_width           is text field width in internal space

    text_field_x    = 0.0    # in internal space
    text_field_y    = 0.0    # in internal space
    internal_width  = 1.0
    tagspace_width  = @my_node.convert_magnitude_to_tag_space(@_internal_width) - (@my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius))/2 - 3
    tagspace_height = @my_node.convert_magnitude_to_tag_space(@_internal_height)

    [tagspace_x, tagspace_y] = @my_node.convert_point_to_tag_space(text_field_x, text_field_y)
    Alonzo.make_text_field({
      key:            md5(@my_node.ancestry + "text field")
      x:              tagspace_x
      y:              tagspace_y
      width:          tagspace_width
      height:         tagspace_height
      current_value:  @my_node.current_value
      onNewValue:     @_onUserEnteredNewValue
    })

  # when the user presses enter while in the box, or clicks outside the box and it looses focus
  _onUserEnteredNewValue: (new_value) =>
    console.log("_onUserEnteredNewValue " + @my_node.ancestry + " " + new_value)
    Library.set_singleton_input_value(@my_node.parent.my_model.uuid, Alonzo.Utils.list_last(@my_node.ancestry), new_value)
    Library.flush_to_database()
    Alonzo.render()

class TextBoxNodeGraphics extends SpecialContentsNodeGraphics
  constructor: (my_node) ->
    super(my_node)

  draw: () ->
    @_draw_border_and_oliver()
    @_draw_name()
    @_draw_connection_ports()
    @_draw_text_box()

  _draw_border_and_oliver: () ->
    [node_tagspace_x, node_tagspace_y] = @my_node.parent.convert_point_to_tag_space(@my_node.position)
    additional_height_from_oliver = @_get_oliver_height_tagspace() - @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)
    this_rect_tagspace_y = node_tagspace_y - additional_height_from_oliver
    this_rect_tagspace_x = node_tagspace_x
    this_rect_height     = @my_node.parent.convert_magnitude_to_tag_space(@my_node.height) + additional_height_from_oliver
    this_rect_width      = @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
    corner_radius        = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.corner_radius)

    color = if @my_node.is_selected() then Alonzo.graphics_constants.node.border_stroke_color_selected else Alonzo.graphics_constants.node.border_stroke_color
    Alonzo.draw_rect({
      key:         md5(@my_node.ancestry + "main box")
      x:           this_rect_tagspace_x
      y:           this_rect_tagspace_y
      width:       this_rect_width
      height:      this_rect_height
      stroke:      color
      strokeWidth: 2*@my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)
      fill:        color
      rx:          corner_radius
      ry:          corner_radius
      onMouseDown: @_borderOnMouseDown
    })

  _get_oliver_height_tagspace: () ->
    #will not allow an oliver smaller than the border width
    min_ar = Alonzo.graphics_constants.node.oliver_min_aspect_ratio
    width  = @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
    height = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.oliver_height)
    border = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)

    if width / height < min_ar then height = width / min_ar
    if height < border then height = border

    height

  _draw_name: () ->
    name = @my_node.display_name

    # all in tagspace
    oliver_height    = @_get_oliver_height_tagspace()
    node_position    = @my_node.convert_point_to_tag_space(0, 0)
    half_width       = @my_node.convert_magnitude_to_tag_space(@_internal_width / 2)
    [x, y]           = Alonzo.Utils.add_vectors(node_position, [half_width, -oliver_height/2])
    font_size        = Alonzo.graphics_constants.node.name_font_size_composite * oliver_height
    font_size_offset = font_size * 0.3
    Alonzo.draw_text(name, {
      x:           x
      y:           y + font_size_offset
      textAnchor:  "middle"
      fontSize:    font_size
      fill:        Alonzo.graphics_constants.node.name_text_color_composite
      key:         md5(@my_node.ancestry + "node name" + name)
      onMouseDown: @_borderOnMouseDown
    })

  _draw_text_box: () ->
    # @width                   is node width  in parent space
    # @height                  is node height in parent space (fixed)
    # internal_width           is text field width in internal space

    text_field_x    = 0.0    # in internal space
    text_field_y    = 0.0    # in internal space
    internal_width  = 1.0
    tagspace_width  = @my_node.convert_magnitude_to_tag_space(@_internal_width) - (@my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius))/2 - 3
    tagspace_height = @my_node.convert_magnitude_to_tag_space(@_internal_height)*0.9

    text_field_x    = 0.028    # in internal space
    text_field_y    = 0.0    # in internal space
    tagspace_width  = 285
    tagspace_height = 155

    [tagspace_x, tagspace_y] = @my_node.convert_point_to_tag_space(text_field_x, text_field_y)
    Alonzo.make_text_box({
      key:            md5(@my_node.ancestry + "text box")
      x:              tagspace_x
      y:              tagspace_y
      width:          tagspace_width
      height:         tagspace_height
      current_value:  @my_node.current_value
      onNewValue:     @_onUserEnteredNewValue
    })

  # when the user presses enter while in the box, or clicks outside the box and it looses focus
  _onUserEnteredNewValue: (new_value) =>
    console.log("_onUserEnteredNewValue " + @my_node.ancestry + " " + new_value)
    Library.set_singleton_input_value(@my_node.parent.my_model.uuid, Alonzo.Utils.list_last(@my_node.ancestry), new_value)
    Library.flush_to_database()
    Alonzo.render()

class SetVariableNodeGraphics extends SpecialContentsNodeGraphics
  constructor: (my_node) ->
    super(my_node)

  draw: () ->
    @_draw_main_box()
    @_draw_connection_ports()
    @_draw_text_field()

  _draw_main_box: () ->
    [tagspace_x, tagspace_y] = @my_node.convert_point_to_tag_space(0, 0)
    tagspace_width           = @my_node.convert_magnitude_to_tag_space(@_internal_width)
    tagspace_height          = @my_node.convert_magnitude_to_tag_space(@_internal_height)
    tagspace_corner_extent   = tagspace_height * Alonzo.graphics_constants.node.variable_corner_extent

    path_string =
      "M " +   tagspace_x              + ", " +   tagspace_y         + " " +
      "l " +   tagspace_width          + ", " +   "0"                + " " +
      "l " +   "0"                     + ", " +   tagspace_height    + " " +
      "l " + -(tagspace_width)         + ", " +   "0"                + " " +
      "l " + -(tagspace_corner_extent) + ", " + -(tagspace_height/2) + " " +
      "l " +   tagspace_corner_extent  + ", " + -(tagspace_height/2)

    border_stroke_color = if @my_node.is_selected() then Alonzo.graphics_constants.node.border_stroke_color_selected else Alonzo.graphics_constants.node.border_stroke_color
    Alonzo.draw_path({
      key:         md5(@my_node.ancestry + "main box")
      d:           path_string
      fill:        "white"
      fillOpacity: 0
      stroke:      border_stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)
      onMouseDown: @_nodeBackgroundOnMouseDown #there's no move and up, those are handled by the mouse overlay
    })

  get_position_of_input_port: (argnum) ->
    if argnum == 1
      [-@_internal_height*Alonzo.graphics_constants.node.variable_corner_extent, @_internal_height / 2]
    else
      console.error("someone asked for position of input port #{argnum} on a SetVariableNode")

  _draw_text_field: () ->
    text_field_x    = 0.0    # in internal space
    text_field_y    = 0.0    # in internal space
    internal_width  = 1.0
    tagspace_width  = @my_node.convert_magnitude_to_tag_space(@_internal_width)
    tagspace_height = @my_node.convert_magnitude_to_tag_space(@_internal_height)

    [tagspace_x, tagspace_y] = @my_node.convert_point_to_tag_space(text_field_x, text_field_y)
    Alonzo.make_text_field({
      key:            md5(@my_node.ancestry + "text field")
      x:              tagspace_x
      y:              tagspace_y
      width:          tagspace_width
      height:         tagspace_height
      current_value:  @my_node.current_variable_name
      onNewValue:     @_onUserEnteredNewValue
    })

  # when the user presses enter while in the box, or clicks outside the box and it looses focus
  _onUserEnteredNewValue: (new_value) =>
    console.log("SetVariable _onUserEnteredNewValue " + @my_node.ancestry + " " + new_value)
    Library.set_variable_value(@my_node.parent.my_model.uuid, Alonzo.Utils.list_last(@my_node.ancestry), new_value)
    Library.flush_to_database()
    Alonzo.render()

class RefVariableNodeGraphics extends SpecialContentsNodeGraphics
  constructor: (my_node) ->
    super(my_node)

  draw: () ->
    @_draw_main_box()
    @_draw_connection_ports()
    @_draw_text_field()

  _draw_main_box: () ->
    [tagspace_x, tagspace_y] = @my_node.convert_point_to_tag_space(0, 0)
    tagspace_width           = @my_node.convert_magnitude_to_tag_space(@_internal_width)
    tagspace_height          = @my_node.convert_magnitude_to_tag_space(@_internal_height)
    tagspace_corner_extent   = tagspace_height * Alonzo.graphics_constants.node.variable_corner_extent

    path_string =
      "M " +   tagspace_x              + ", " +   tagspace_y         + " " +
      "l " +   tagspace_width          + ", " +   "0"                + " " +
      "l " +   tagspace_corner_extent  + ", " +   tagspace_height/2  + " " +
      "l " + -(tagspace_corner_extent) + ", " +   tagspace_height/2  + " " +
      "l " + -(tagspace_width)         + ", " +   "0"                + " " +
      "l " +   "0"                     + ", " +   -(tagspace_height)

    border_stroke_color = if @my_node.is_selected() then Alonzo.graphics_constants.node.border_stroke_color_selected else Alonzo.graphics_constants.node.border_stroke_color
    Alonzo.draw_path({
      key:         md5(@my_node.ancestry + "main box")
      d:           path_string
      fill:        "white"
      fillOpacity: 0
      stroke:      border_stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.node.border_stroke_width)
      onMouseDown: @_nodeBackgroundOnMouseDown #there's no move and up, those are handled by the mouse overlay
    })

  get_position_of_output_port: (argnum) ->
    if argnum == 1
      [@_internal_width + @_internal_height*Alonzo.graphics_constants.node.variable_corner_extent, @_internal_height / 2]
    else
      console.error("someone asked for position of output port #{argnum} on a RefVariableNode")

  _draw_text_field: () ->
    text_field_x    = 0.0    # in internal space
    text_field_y    = 0.0    # in internal space
    internal_width  = 1.0
    tagspace_width  = @my_node.convert_magnitude_to_tag_space(@_internal_width)
    tagspace_height = @my_node.convert_magnitude_to_tag_space(@_internal_height)

    [tagspace_x, tagspace_y] = @my_node.convert_point_to_tag_space(text_field_x, text_field_y)
    Alonzo.make_text_field({
      key:            md5(@my_node.ancestry + "text field")
      x:              tagspace_x
      y:              tagspace_y
      width:          tagspace_width
      height:         tagspace_height
      current_value:  @my_node.current_variable_name
      onNewValue:     @_onUserEnteredNewValue
    })

  # when the user presses enter while in the box, or clicks outside the box and it looses focus
  _onUserEnteredNewValue: (new_value) =>
    console.log("RefVariable _onUserEnteredNewValue " + @my_node.ancestry + " " + new_value)
    Library.set_variable_value(@my_node.parent.my_model.uuid, Alonzo.Utils.list_last(@my_node.ancestry), new_value)
    Library.flush_to_database()
    Alonzo.render()

class BubbleGraphics extends SpecialContentsNodeGraphics
  constructor: (my_node) ->
    super(my_node)
    @_density = Library.get_bubble_by_ancestry(@my_node.ancestry).density
    @_internal_width  = @my_node.width  * @_density
    @_internal_height = @my_node.height * @_density

  draw: () ->
    @_draw_main_box() #could replace this with super()?
    @_draw_oliver()
    @_draw_space_buttons()
    @_draw_connection_ports()
    @_draw_value()

  _draw_space_buttons: () ->
    agcn = Alonzo.graphics_constants.node
    oliver_height = Alonzo.graphics_constants.bubble.oliver_height

    inner_offset  = 0.1  # space between the arrow tails
    outter_offset = 0.15 # space between the arrow heads and the edge of the buton
    head_length   = 0.25 # the length of the head parts of the arrow head

    # the harpoon point should be the one that's at the same x as the tip point, this function will figure out the other one
    __draw_arrow = (tail_point, tip_point, harpoon_point, arrow_uniqueness) =>
      path_string = Alonzo.Utils.straight_line_path_string(tail_point[0], tail_point[1], tip_point[0], tip_point[1])
      Alonzo.draw_path({
        key:         md5("arrow line 1" + @my_node.ancestry + arrow_uniqueness)
        d:           path_string
        stroke:      agcn.space_buttons_stroke_color
        strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_stroke_width * oliver_height)
      })

      path_string = Alonzo.Utils.straight_line_path_string(harpoon_point[0], harpoon_point[1], tip_point[0], tip_point[1])
      Alonzo.draw_path({
        key:         md5("arrow line 2" + @my_node.ancestry + arrow_uniqueness)
        d:           path_string
        stroke:      agcn.space_buttons_stroke_color
        strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_stroke_width * oliver_height)
        strokeLinecap: "square"
      })

      diff = tip_point[1] - harpoon_point[1]
      path_string = Alonzo.Utils.straight_line_path_string(tip_point[0] + diff, tip_point[1], tip_point[0], tip_point[1])
      Alonzo.draw_path({
        key:         md5("arrow line 3" + @my_node.ancestry + arrow_uniqueness)
        d:           path_string
        stroke:      agcn.space_buttons_stroke_color
        strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_stroke_width * oliver_height)
      })

    # remove space button
    parent_upper_left_x  = @my_node.position[0] + agcn.space_buttons_inset*oliver_height
    parent_upper_left_y  = @my_node.position[1] - agcn.oliver_height/2 - agcn.space_buttons_width*oliver_height/2
    [tagspace_upper_left_x, tagspace_upper_left_y] = @my_node.parent.convert_point_to_tag_space(parent_upper_left_x, parent_upper_left_y)
    tagspace_width       = @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_width*oliver_height)
    tagspace_bot_right_x = tagspace_upper_left_x + tagspace_width
    tagspace_bot_right_y = tagspace_upper_left_y + tagspace_width

    tip_point     = [tagspace_upper_left_x + tagspace_width*outter_offset,       tagspace_bot_right_y  - tagspace_width*outter_offset                             ]
    tail_point    = [tagspace_upper_left_x + tagspace_width*(0.5-inner_offset),  tagspace_bot_right_y  - tagspace_width*(0.5-inner_offset)                        ]
    harpoon_point = [tagspace_upper_left_x + tagspace_width*outter_offset,       tagspace_bot_right_y  - tagspace_width*outter_offset - tagspace_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "remove space button arrow 1")

    tip_point     = [tagspace_bot_right_x  - tagspace_width*outter_offset,       tagspace_upper_left_y + tagspace_width*outter_offset                             ]
    tail_point    = [tagspace_upper_left_x + tagspace_width*(0.5+inner_offset),  tagspace_bot_right_y  - tagspace_width*(0.5+inner_offset)                        ]
    harpoon_point = [tagspace_bot_right_x  - tagspace_width*outter_offset,       tagspace_upper_left_y + tagspace_width*outter_offset + tagspace_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "remove space button arrow 2")

    Alonzo.draw_rect({
      key:         md5("remove space button" + @my_node.ancestry)
      x:           tagspace_upper_left_x
      y:           tagspace_upper_left_y
      width:       tagspace_width
      height:      tagspace_width
      stroke:      agcn.space_buttons_stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_stroke_width*oliver_height)
      fill:        "white"
      fillOpacity: 0
      ry:          @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_corner_radius*oliver_height)
      rx:          @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_corner_radius*oliver_height)
      onClick:     @_increase_density
    })

    # add space button
    parent_upper_left_x  = @my_node.position[0] + agcn.space_buttons_inset*oliver_height + agcn.space_buttons_width*oliver_height + agcn.space_buttons_separation*oliver_height
    parent_upper_left_y  = @my_node.position[1] - agcn.oliver_height/2 - agcn.space_buttons_width*oliver_height/2
    [tagspace_upper_left_x, tagspace_upper_left_y] = @my_node.parent.convert_point_to_tag_space(parent_upper_left_x, parent_upper_left_y)
    tagspace_width       = @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_width*oliver_height)
    tagspace_bot_right_x = tagspace_upper_left_x + tagspace_width
    tagspace_bot_right_y = tagspace_upper_left_y + tagspace_width

    tail_point    = [tagspace_upper_left_x + tagspace_width*outter_offset,       tagspace_bot_right_y  - tagspace_width*outter_offset                                  ]
    tip_point     = [tagspace_upper_left_x + tagspace_width*(0.5-inner_offset),  tagspace_bot_right_y  - tagspace_width*(0.5-inner_offset)                             ]
    harpoon_point = [tagspace_upper_left_x + tagspace_width*(0.5-inner_offset),  tagspace_bot_right_y  - tagspace_width*(0.5-inner_offset) + tagspace_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "add space button arrow 1")

    tail_point    = [tagspace_bot_right_x  - tagspace_width*outter_offset,       tagspace_upper_left_y + tagspace_width*outter_offset                                  ]
    tip_point     = [tagspace_upper_left_x + tagspace_width*(0.5+inner_offset),  tagspace_bot_right_y  - tagspace_width*(0.5+inner_offset)                             ]
    harpoon_point = [tagspace_bot_right_x  - tagspace_width*(0.5-inner_offset),  tagspace_upper_left_y + tagspace_width*(0.5-inner_offset) - tagspace_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "add space button arrow 2")

    Alonzo.draw_rect({
      key:         md5("add space button" + @my_node.ancestry)
      x:           tagspace_upper_left_x
      y:           tagspace_upper_left_y
      width:       tagspace_width
      height:      tagspace_width
      stroke:      agcn.space_buttons_stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_stroke_width*oliver_height)
      fill:        "white"
      fillOpacity: 0
      rx:          @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_corner_radius*oliver_height)
      ry:          @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_corner_radius*oliver_height)
      onClick:     @_decrease_density
    })

  _increase_density: () =>
    current_density = Library.get_bubble_by_ancestry(@my_node.ancestry).density
    new_density = current_density * Alonzo.volatile_state.more_space_button
    Library.set_bubble_density(@my_node.ancestry, new_density)
    Library.flush_to_database()
    Alonzo.render()

  _decrease_density: () =>
    current_density = Library.get_bubble_by_ancestry(@my_node.ancestry).density
    new_density = current_density / Alonzo.volatile_state.more_space_button
    Library.set_bubble_density(@my_node.ancestry, new_density)
    Library.flush_to_database()
    Alonzo.render()

  _draw_main_box: () ->
    [x, y] = @my_node.position

    [tagspace_x, tagspace_y] = @my_node.parent.convert_point_to_tag_space(x, y)
    border_stroke_color = if @my_node.is_selected() then Alonzo.graphics_constants.bubble.border_stroke_color_selected else Alonzo.graphics_constants.bubble.border_stroke_color
    Alonzo.draw_rect({
      key:         md5(@my_node.ancestry + "main box")
      x:           tagspace_x
      y:           tagspace_y
      width:       @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
      height:      @my_node.parent.convert_magnitude_to_tag_space(@my_node.height)
      stroke:      border_stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.border_stroke_width)
      fill:        Alonzo.graphics_constants.bubble.fill_color
      fillOpacity: Alonzo.graphics_constants.bubble.fill_opacity
      rx:          @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.corner_radius)
      ry:          @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.corner_radius)
      onMouseDown: @_nodeBackgroundOnMouseDown #there's no move and up, those are handled by the mouse overlay
    })

  _draw_oliver: () ->
    # all in tagspace
    upper_left    = @my_node.parent.convert_point_to_tag_space(@my_node.position)
    oliver_width  = @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
    oliver_height = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.oliver_height)
    radius        = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.corner_radius)
    color         = if @my_node.is_selected() then Alonzo.graphics_constants.bubble.border_stroke_color_selected else Alonzo.graphics_constants.bubble.border_stroke_color

    Alonzo.draw_path({
      key:         md5(@my_node.ancestry + "oliver")
      d:           Alonzo.Utils.oliver_path_string(upper_left, oliver_width, oliver_height, radius)
      fill:        color
      stroke:      color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.border_stroke_width)
      onMouseDown: @_oliverOnMouseDown
    })

  _oliverOnMouseDown: (e) =>
    #console.log("composite node oliver onmouseDown #{@my_node.ancestry}")
    Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.down_on_node
    mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)
    down_position_parent = @my_node.parent.convert_point_from_tag_space(mouse_position_tag)
    Alonzo.volatile_state.drag_node.down_offset_parent = Alonzo.Utils.subtract_vectors(@my_node.position, down_position_parent)
    Alonzo.volatile_state.drag_node.down_node_ancestry = @my_node.ancestry
    Alonzo.render() #need to render because the mouse overlay will probably have to be inserted

  _draw_value: () ->
    # console.log("bubble internal width #{@_internal_width}, width in parent #{@my_node.width}")
    margin = 0.02

    # this is a proportional margin
    # [x, y] = @my_node.convert_point_to_tag_space(@_internal_width * margin, @_internal_height * margin)
    # width  = @my_node.convert_magnitude_to_tag_space(@_internal_width *(1 - 2*margin))
    # height = @my_node.convert_magnitude_to_tag_space(@_internal_height*(1 - 2*margin))

    # this is a fixed margin
    # [x, y] = @my_node.convert_point_to_tag_space(margin, margin)
    # width  = @my_node.convert_magnitude_to_tag_space(@_internal_width  - 2*margin)
    # height = @my_node.convert_magnitude_to_tag_space(@_internal_height - 2*margin)

    # this is just enough margin to leave the port uncovered
    [x_0, y_0]  = @my_node.convert_point_to_tag_space(0, 0)
    port_radius = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius)
    x           = x_0 + port_radius
    y           = y_0
    width       = @my_node.convert_magnitude_to_tag_space(@_internal_width) - port_radius
    height      = @my_node.convert_magnitude_to_tag_space(@_internal_height)

    style = {}
    style.position  = "absolute"
    style.left      = x      + "px"
    style.top       = y      + "px"
    style.width     = width  + "px"
    style.height    = height + "px"
    style.overflow  = "auto"
    style.textAlign = "center"

    content = StoredResults.lookup_result(@my_node.ancestry, @my_node.sugared_map_ancestry, @my_node.source_idargnum)
    tagspace_density = @my_node.parent.convert_magnitude_to_tag_space(1) * @_density
    tagspace_size = 50 * tagspace_density

    Alonzo.native_elements_to_draw.push(
      <div
        style   = {style}
        key     = {md5(@my_node.ancestry + "result container div")}
        onWheel = {Alonzo.on_wheel_zoom}
      >
        {Alonzo.replace_cloud_object_images(content, md5(@my_node.ancestry + "result container div"), tagspace_size)}
      </div>
    )

# this takes a result value, finds any instances of "onDisk["url"]" in it, and replaces it with
# an image tag with the url
Alonzo.replace_cloud_object_images = (content, key_material, tagspace_size) ->
  # content is like "{3, onDisk[http://blah.blah.blah], 4, onDisk[http://blee.blee.blee]}"
  # thesplit is then
  # [ '{3, '                                            ,
  #   'onDisk["http://blah.blah.blah"]'            ,
  #   ', 4, '                                           ,
  #   'onDisk["http://blee.blee.blee"]'            ,
  #   '}'                                               ]
  # and display_elements is
  # [ react tag for ('{3, ')                            ,
  #   react tag for ('<img http://blah.blah.blah >')    ,
  #   react tag for (', 4, ')                           ,
  #   react tag for ('<img http://blee.blee.blee >')    ,
  #   react tag for ('}')                               ]


  transform_to_react = (x, key_material) ->
    r = x.match(new RegExp("onDisk\\[\"(.*?)\"\\]"))
    if r is null
      make_react_text(x, key_material)
    else
      make_react_img(r[1], key_material)

  make_react_text = (display_text, key_material) ->
    style = {}
    style.color    = Alonzo.graphics_constants.bubble.text_value_color
    style.fontSize = Alonzo.graphics_constants.bubble.text_value_size * tagspace_size

    <span style={style} key={md5(key_material + "drawn result span")}>
      {display_text}
    </span>

  make_react_img = (display_url, key_material) ->
    style = {}
    style.width  = Alonzo.graphics_constants.bubble.image_value_width * tagspace_size

    <span key={md5(key_material + "drawn result span")}>
      <img
        key         = {md5(key_material + "drawn result img")}
        style       = {style}
        src         = {"file://" + display_url}
        onMouseDown = {(e) -> e.preventDefault()}
      ></img>
    </span>

  thesplit = content.split(new RegExp("(onDisk\\[.*?\\])", "g"))
  display_elements = (transform_to_react(x, key_material + i) for x,i in thesplit)
  display_elements

class ResultGraphics extends SpecialContentsNodeGraphics
  constructor: (my_node) ->
    super(my_node)
    @_density = Library.get_submodel_datastructure(@my_node.parent.my_model.uuid, @my_node.submodel_id).density
    @_internal_width  = @my_node.width  * @_density
    @_internal_height = @my_node.height * @_density

  draw: () ->
    @_draw_main_box() #could replace this with super()?
    @_draw_oliver()
    @_draw_space_buttons()
    @_draw_connection_ports()
    @_draw_value()

  _draw_space_buttons: () ->
    agcn = Alonzo.graphics_constants.node
    oliver_height = Alonzo.graphics_constants.bubble.oliver_height

    inner_offset  = 0.1  # space between the arrow tails
    outter_offset = 0.15 # space between the arrow heads and the edge of the buton
    head_length   = 0.25 # the length of the head parts of the arrow head

    # the harpoon point should be the one that's at the same x as the tip point, this function will figure out the other one
    __draw_arrow = (tail_point, tip_point, harpoon_point, arrow_uniqueness) =>
      path_string = Alonzo.Utils.straight_line_path_string(tail_point[0], tail_point[1], tip_point[0], tip_point[1])
      Alonzo.draw_path({
        key:         md5("arrow line 1" + @my_node.ancestry + arrow_uniqueness)
        d:           path_string
        stroke:      agcn.space_buttons_stroke_color
        strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_stroke_width * oliver_height)
      })

      path_string = Alonzo.Utils.straight_line_path_string(harpoon_point[0], harpoon_point[1], tip_point[0], tip_point[1])
      Alonzo.draw_path({
        key:         md5("arrow line 2" + @my_node.ancestry + arrow_uniqueness)
        d:           path_string
        stroke:      agcn.space_buttons_stroke_color
        strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_stroke_width * oliver_height)
        strokeLinecap: "square"
      })

      diff = tip_point[1] - harpoon_point[1]
      path_string = Alonzo.Utils.straight_line_path_string(tip_point[0] + diff, tip_point[1], tip_point[0], tip_point[1])
      Alonzo.draw_path({
        key:         md5("arrow line 3" + @my_node.ancestry + arrow_uniqueness)
        d:           path_string
        stroke:      agcn.space_buttons_stroke_color
        strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_stroke_width * oliver_height)
      })

    # remove space button
    parent_upper_left_x  = @my_node.position[0] + agcn.space_buttons_inset*oliver_height
    parent_upper_left_y  = @my_node.position[1] - agcn.oliver_height/2 - agcn.space_buttons_width*oliver_height/2
    [tagspace_upper_left_x, tagspace_upper_left_y] = @my_node.parent.convert_point_to_tag_space(parent_upper_left_x, parent_upper_left_y)
    tagspace_width       = @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_width*oliver_height)
    tagspace_bot_right_x = tagspace_upper_left_x + tagspace_width
    tagspace_bot_right_y = tagspace_upper_left_y + tagspace_width

    tip_point     = [tagspace_upper_left_x + tagspace_width*outter_offset,       tagspace_bot_right_y  - tagspace_width*outter_offset                             ]
    tail_point    = [tagspace_upper_left_x + tagspace_width*(0.5-inner_offset),  tagspace_bot_right_y  - tagspace_width*(0.5-inner_offset)                        ]
    harpoon_point = [tagspace_upper_left_x + tagspace_width*outter_offset,       tagspace_bot_right_y  - tagspace_width*outter_offset - tagspace_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "remove space button arrow 1")

    tip_point     = [tagspace_bot_right_x  - tagspace_width*outter_offset,       tagspace_upper_left_y + tagspace_width*outter_offset                             ]
    tail_point    = [tagspace_upper_left_x + tagspace_width*(0.5+inner_offset),  tagspace_bot_right_y  - tagspace_width*(0.5+inner_offset)                        ]
    harpoon_point = [tagspace_bot_right_x  - tagspace_width*outter_offset,       tagspace_upper_left_y + tagspace_width*outter_offset + tagspace_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "remove space button arrow 2")

    Alonzo.draw_rect({
      key:         md5("remove space button" + @my_node.ancestry)
      x:           tagspace_upper_left_x
      y:           tagspace_upper_left_y
      width:       tagspace_width
      height:      tagspace_width
      stroke:      agcn.space_buttons_stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_stroke_width*oliver_height)
      fill:        "white"
      fillOpacity: 0
      ry:          @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_corner_radius*oliver_height)
      rx:          @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_corner_radius*oliver_height)
      onClick:     @_increase_density
    })

    # add space button
    parent_upper_left_x  = @my_node.position[0] + agcn.space_buttons_inset*oliver_height + agcn.space_buttons_width*oliver_height + agcn.space_buttons_separation*oliver_height
    parent_upper_left_y  = @my_node.position[1] - agcn.oliver_height/2 - agcn.space_buttons_width*oliver_height/2
    [tagspace_upper_left_x, tagspace_upper_left_y] = @my_node.parent.convert_point_to_tag_space(parent_upper_left_x, parent_upper_left_y)
    tagspace_width       = @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_width*oliver_height)
    tagspace_bot_right_x = tagspace_upper_left_x + tagspace_width
    tagspace_bot_right_y = tagspace_upper_left_y + tagspace_width

    tail_point    = [tagspace_upper_left_x + tagspace_width*outter_offset,       tagspace_bot_right_y  - tagspace_width*outter_offset                                  ]
    tip_point     = [tagspace_upper_left_x + tagspace_width*(0.5-inner_offset),  tagspace_bot_right_y  - tagspace_width*(0.5-inner_offset)                             ]
    harpoon_point = [tagspace_upper_left_x + tagspace_width*(0.5-inner_offset),  tagspace_bot_right_y  - tagspace_width*(0.5-inner_offset) + tagspace_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "add space button arrow 1")

    tail_point    = [tagspace_bot_right_x  - tagspace_width*outter_offset,       tagspace_upper_left_y + tagspace_width*outter_offset                                  ]
    tip_point     = [tagspace_upper_left_x + tagspace_width*(0.5+inner_offset),  tagspace_bot_right_y  - tagspace_width*(0.5+inner_offset)                             ]
    harpoon_point = [tagspace_bot_right_x  - tagspace_width*(0.5-inner_offset),  tagspace_upper_left_y + tagspace_width*(0.5-inner_offset) - tagspace_width*head_length]
    __draw_arrow(tail_point, tip_point, harpoon_point, "add space button arrow 2")

    Alonzo.draw_rect({
      key:         md5("add space button" + @my_node.ancestry)
      x:           tagspace_upper_left_x
      y:           tagspace_upper_left_y
      width:       tagspace_width
      height:      tagspace_width
      stroke:      agcn.space_buttons_stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_stroke_width*oliver_height)
      fill:        "white"
      fillOpacity: 0
      rx:          @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_corner_radius*oliver_height)
      ry:          @my_node.parent.convert_magnitude_to_tag_space(agcn.space_buttons_corner_radius*oliver_height)
      onClick:     @_decrease_density
    })

  _increase_density: () =>
    new_density = @_density * Alonzo.volatile_state.more_space_button
    Library.set_result_density(@my_node.parent.my_model.uuid, @my_node.submodel_id, new_density)
    Library.flush_to_database()
    Alonzo.render()

  _decrease_density: () =>
    new_density = @_density / Alonzo.volatile_state.more_space_button
    Library.set_result_density(@my_node.parent.my_model.uuid, @my_node.submodel_id, new_density)
    Library.flush_to_database()
    Alonzo.render()

  _draw_main_box: () ->
    [x, y] = @my_node.position

    [tagspace_x, tagspace_y] = @my_node.parent.convert_point_to_tag_space(x, y)
    border_stroke_color = if @my_node.is_selected() then Alonzo.graphics_constants.bubble.border_stroke_color_selected else Alonzo.graphics_constants.bubble.border_stroke_color
    border_stroke_color = "purple"
    Alonzo.draw_rect({
      key:         md5(@my_node.ancestry + "main box")
      x:           tagspace_x
      y:           tagspace_y
      width:       @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
      height:      @my_node.parent.convert_magnitude_to_tag_space(@my_node.height)
      stroke:      border_stroke_color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.border_stroke_width)
      fill:        Alonzo.graphics_constants.bubble.fill_color
      fillOpacity: Alonzo.graphics_constants.bubble.fill_opacity
      rx:          @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.corner_radius)
      ry:          @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.corner_radius)
      onMouseDown: @_nodeBackgroundOnMouseDown #there's no move and up, those are handled by the mouse overlay
    })

  _draw_oliver: () ->
    # all in tagspace
    upper_left    = @my_node.parent.convert_point_to_tag_space(@my_node.position)
    oliver_width  = @my_node.parent.convert_magnitude_to_tag_space(@my_node.width)
    oliver_height = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.oliver_height)
    radius        = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.corner_radius)
    color         = if @my_node.is_selected() then Alonzo.graphics_constants.bubble.border_stroke_color_selected else Alonzo.graphics_constants.bubble.border_stroke_color

    Alonzo.draw_path({
      key:         md5(@my_node.ancestry + "oliver")
      d:           Alonzo.Utils.oliver_path_string(upper_left, oliver_width, oliver_height, radius)
      fill:        color
      stroke:      color
      strokeWidth: @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.bubble.border_stroke_width)
      onMouseDown: @_borderOnMouseDown
    })

  _draw_value: () ->
    margin = 0.02

    # this is a proportional margin
    # [x, y] = @my_node.convert_point_to_tag_space(@_internal_width * margin, @_internal_height * margin)
    # width  = @my_node.convert_magnitude_to_tag_space(@_internal_width *(1 - 2*margin))
    # height = @my_node.convert_magnitude_to_tag_space(@_internal_height*(1 - 2*margin))

    # this is a fixed margin
    # [x, y] = @my_node.convert_point_to_tag_space(margin, margin)
    # width  = @my_node.convert_magnitude_to_tag_space(@_internal_width  - 2*margin)
    # height = @my_node.convert_magnitude_to_tag_space(@_internal_height - 2*margin)

    # this is just enough margin to leave the port uncovered
    [x_0, y_0]  = @my_node.convert_point_to_tag_space(0, 0)
    port_radius = @my_node.parent.convert_magnitude_to_tag_space(Alonzo.graphics_constants.connection_port.radius)
    x           = x_0 + port_radius
    y           = y_0
    width       = @my_node.convert_magnitude_to_tag_space(@_internal_width) - port_radius
    height      = @my_node.convert_magnitude_to_tag_space(@_internal_height)

    style = {}
    style.position  = "absolute"
    style.left      = x      + "px"
    style.top       = y      + "px"
    style.width     = width  + "px"
    style.height    = height + "px"
    style.overflow  = "auto"
    style.textAlign = "center"

    content = StoredResults.lookup_result(@my_node.ancestry, @my_node.sugared_map_ancestry)
    tagspace_density = @my_node.parent.convert_magnitude_to_tag_space(1) * @_density
    tagspace_size = 50 * tagspace_density

    Alonzo.native_elements_to_draw.push(
      <div
        style   = {style}
        key     = {md5(@my_node.ancestry + "result container div")}
        onWheel = {Alonzo.on_wheel_zoom}
      >
        {Alonzo.replace_cloud_object_images(content, md5(@my_node.ancestry + "result container div"), tagspace_size)}
      </div>
    )

class DiagramGraphics extends CompositeNodeGraphics
  constructor: (my_node) ->
    super(my_node)

  draw: () ->
    # NOT super() because that would try to draw an outer box and connection ports
    @_draw_background_rect()
    @_draw_child_nodes()
    @_draw_child_node_resizers()
    @_draw_links()
    @_draw_drag_select_box()
    @_draw_drag_new_node_box()

  _draw_background_rect: () ->
    Alonzo.draw_rect({
      key:         md5("background rect")
      x:           0
      y:           0
      width:       "100%"#Alonzo.volatile_state.viewport_size[0]
      height:      "100%"#Alonzo.volatile_state.viewport_size[1]
      stroke:      "none"
      fill:        Alonzo.graphics_constants.background_color
      onMouseDown: @_nodeBackgroundOnMouseDown
    })

  # the diagram model does not really have a defined size, as in, there isn't anything outside it
  # it's fine for submodels to have negative positions
  tag_point_is_inside_node: (test_point_tag_space) ->
    true

export {
  NodeGraphics,
  CompositeNodeGraphics,
  NonCompositeNodeGraphics,
  NoDetailNodeGraphics,
  NameOnlyNodeGraphics,
  NameAndPortLabelsNodeGraphics,
  SpecialContentsNodeGraphics,
  TextLineInputNodeGraphics,
  TextBoxNodeGraphics,
  SetVariableNodeGraphics,
  RefVariableNodeGraphics,
  BubbleGraphics,
  ResultGraphics,
  DiagramGraphics
}
