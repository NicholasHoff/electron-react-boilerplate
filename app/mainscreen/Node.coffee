# class hierarchy
# ---------------
# Node (NOT abstract)
#   UserDataNode
#   RawInputNode
#   SmartInputNode
#   Bubble
#   ResultNode
#   Diagram
#   CodeNode

import Library from './Library.coffee'
import {
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
} from './NodeGraphics.coffee'

class Node
  # @ will have:
  # @parent
  # @position      in parent space
  # @height        in parent space
  # @width         in parent space
  # @ancestry
  # @sugared_map_ancestry
  # @submodel_id
  # @arity
  # @coarity
  # @sugared_maps  (null if none set)
  # @variable_arity
  # @variable_coarity
  # @_node_graphics
  # @can_be_drop_target_for_nodes
  # @children_are_visible
  # @level
  # @display_name

  # @ will NOT necesarily have:
  # my_model - not all nodes have models (SingletonInput, Bubble)

  # these Nodes can be treated as model-backed nodes, other types of nodes
  # (like singleton inputs or notes) are implemented by sublcassing Node

  # position, width, and height are in the parent's space

  # need to supply arity and coarity because some models are have variable arity/coarity
  # same with sugared_maps

  # idea - I could give each node the submodel data structure that corresponds to it.  That would contain
  # any instance-specific information like arity, coarity, position, height, width, and maps, and anything
  # else I might add later.  That might be cleaner.
  constructor: (@parent, @ancestry, @my_model, @position, @width, @height, @arity, @coarity, @sugared_maps) ->
    Alonzo.registry.regsiter_node(this)

    @level = @parent.level + 1
    @submodel_id = Alonzo.Utils.list_last(@ancestry)
    @variable_arity   = @my_model.variable_arity
    @variable_coarity = @my_model.variable_coarity
    @display_name = @my_model.name
    @sugared_map_ancestry = Alonzo.Utils.list_append(@parent.sugared_map_ancestry, Alonzo.get_sugared_map_index(@ancestry))


    # @can_be_drop_target_for_nodes
    # this is currently decided simply with regard to how the node is drawn
    # could also be changed in the future when some composite nodes are locked
    # or if you want to be able to drop into composite models that are shown as noncomposite

    width_in_tag_space = @parent.convert_magnitude_to_tag_space(@width)

    @can_be_drop_target_for_nodes = false
    @children_are_visible         = false

    if width_in_tag_space > Alonzo.graphics_constants.detail_threshold.composite and @my_model.composite
      @can_be_drop_target_for_nodes = true
      @children_are_visible         = true
      @_node_graphics = new CompositeNodeGraphics(this)
    else if width_in_tag_space > Alonzo.graphics_constants.detail_threshold.name_and_port_lables
      if @labels_are_all_empty()
        @_node_graphics = new NameOnlyNodeGraphics(this)
      else
        @_node_graphics = new NameAndPortLabelsNodeGraphics(this)
    else if width_in_tag_space > Alonzo.graphics_constants.detail_threshold.name_only
      @_node_graphics = new NameOnlyNodeGraphics(this)
    else
      @_node_graphics = new NoDetailNodeGraphics(this)

    @_node_graphics.draw()

  # remove self from current parent, insert self into new parent at given location
  # this moves the whole submodel datastructure, so nodes that have things like input data or loop settings will be fine
  # does not touch links
  # overridden for Bubble
  # maintains selected status
  transplant_to_new_parent_at_location: (droptarget_node, new_upper_left) ->
    my_submodel_id = Alonzo.Utils.list_last(@ancestry)
    my_submodel_datastructure = Library.get_submodel_datastructure(@parent.my_model.uuid, my_submodel_id)
    my_submodel_datastructure = Alonzo.Utils.json_clone(my_submodel_datastructure)
    my_submodel_datastructure.position = new_upper_left
    Library.remove_submodel_from_model(@parent.my_model.uuid, my_submodel_id, write_to_database = false)
    Library.add_submodel_to_model(droptarget_node.my_model.uuid, my_submodel_datastructure, write_to_database = false)
    if @is_selected()
      @remove_from_selection()
      Alonzo.volatile_state.selected_nodes.push({
        parent_uuid: droptarget_node.my_model.uuid
        submodel_id: @submodel_id
      })

  # deletes all links going to/from self in parent model, including links that go to bubbles
  # writes to Library but not Database
  # does not render
  delete_all_links_going_to_self: () ->
    for each_link in Alonzo.registry.get_links_by_ancestry(@parent.ancestry)
      comes_from_me = each_link.from_cp.id_if_source is @submodel_id
      goes_to_me    = each_link.to_cp.id_if_sink is @submodel_id
      if comes_from_me or goes_to_me
        each_link.delete_self()
    for sibling_bubble in Alonzo.registry.sibling_nodes_of(this) when sibling_bubble instanceof Bubble
      if sibling_bubble.source_idargnum isnt null
        if sibling_bubble.source_idargnum[0] is @submodel_id
          sibling_bubble.delete_all_links_going_to_self()

  # deletes self from parent model, also deletes links going to/from self in parent model,
  # also deletes any bubbles that are descendants of me, whether or not they are currently drawn
  # writes to Library but not Database, overridden for Bubble
  delete_self: () ->
    #first the descentant bubbles
    Bubble.delete_bubble_when_not_shown(x) for x in Library.get_bubbles_by_ancestor_ancestry(@ancestry)

    @delete_all_links_going_to_self()
    @remove_from_selection()
    my_submodel_id = Alonzo.Utils.list_last(@ancestry)
    Library.remove_submodel_from_model(@parent.my_model.uuid, my_submodel_id, write_to_database = false)

  convert_point_to_tag_space: (x, y) -> #x and y are in my internal space
    if typeof(x) is "object"
      y = x[1]
      x = x[0]

    @parent.convert_point_to_tag_space(@convert_point_to_parent_space(x, y))

  convert_point_to_parent_space: (x, y) -> #x and y are in my internal space
    if typeof(x) is "object"
      y = x[1]
      x = x[0]

    rd = @_node_graphics.relative_density()
    [(x / rd) + @position[0], (y / rd) + @position[1]]

  convert_magnitude_to_tag_space: (magnitude) ->
    @parent.convert_magnitude_to_tag_space(@convert_magnitude_to_parent_space(magnitude))

  convert_magnitude_to_parent_space: (magnitude) ->
    (1 / @_node_graphics.relative_density()) * magnitude

  convert_point_from_tag_space: (x, y) -> #x and y are in tag space, result is in my space
    if typeof(x) is "object"
      y = x[1]
      x = x[0]

    [tagspace00x, tagspace00y] = @convert_point_to_tag_space(0, 0)
    tagspace_delta_x = x - tagspace00x
    tagspace_delta_y = y - tagspace00y
    factor = @convert_magnitude_from_tag_space(1.0)
    myspace_delta_x = tagspace_delta_x * factor
    myspace_delta_y = tagspace_delta_y * factor
    return [myspace_delta_x, myspace_delta_y]

  convert_magnitude_from_tag_space: (magnitude) ->
    1.0 / @convert_magnitude_to_tag_space(magnitude)

  tag_point_is_inside_node: (test_point_tag_space) ->
    @_node_graphics.tag_point_is_inside_node(test_point_tag_space)

  parent_point_is_inside_node: (test_point_parent_space) ->
    @_node_graphics.tag_point_is_inside_node(@parent.convert_point_to_tag_space(test_point_parent_space))

  top_left_parent_space: () ->
    @position

  bot_right_parent_space: () ->
    [@position[0] + @width, @position[1] + @height]

  # in internal space of this node
  get_position_of_input_port: (argnum) ->
    @_node_graphics.get_position_of_input_port(argnum)

  # in internal space of this node
  get_position_of_output_port: (argnum) ->
    @_node_graphics.get_position_of_output_port(argnum)

  aspect_ratio: () ->
    @width / @height

  is_child_of: (other_node) ->
    Alonzo.Utils.ancestry_same(@parent.ancestry, other_node.ancestry)

  is_parent_of: (other_node) ->
    other_node.is_child_of(this)

  is_sibling_of: (other_node) ->
    if other_node instanceof Diagram
      false
    else
      Alonzo.Utils.ancestry_same(@parent.ancestry, other_node.parent.ancestry)

  is_selected: () ->
    for each in Alonzo.volatile_state.selected_nodes
      if @parent.my_model.uuid is each.parent_uuid and @submodel_id is each.submodel_id
        return true
    return false

  # does not redraw, only alters the react state
  add_to_selection: () ->
    Alonzo.volatile_state.selected_nodes.push({
      parent_uuid: @parent.my_model.uuid
      submodel_id: @submodel_id
    })

  # does not redraw, only alters the react state
  remove_from_selection: () ->
    sn = Alonzo.volatile_state.selected_nodes
    Alonzo.volatile_state.selected_nodes = (x for x in sn when not (
      @parent.my_model.uuid is x.parent_uuid and
      @submodel_id          is x.submodel_id
    ))

  # if no label is specified, or if you've asked for an argnum above the default argnum,
  # null is returned
  get_input_label: (argnum) ->
    if @variable_arity
      if argnum > @my_model.default_arity
        # could put some logic here to how to label ports above the default arity
        null
      else
        Library.get_input_label_for_model(@my_model.uuid, argnum)
    else
      Library.get_input_label_for_model(@my_model.uuid, argnum)

  get_output_label: (argnum) ->
    if @variable_coarity
      if argnum > @my_model.default_coarity
        # could put some logic here to how to label ports above the default arity
        null
      else
        Library.get_output_label_for_model(@my_model.uuid, argnum)
    else
      Library.get_output_label_for_model(@my_model.uuid, argnum)

  labels_are_all_empty: () ->
    labels = @my_model.labels
    if labels?
      for x in labels[0]
        if x isnt null and x isnt "" then return false
      for x in labels[1]
        if x isnt null and x isnt "" then return false
    return true

class UserDataNode extends Node
  constructor: (@parent, @ancestry, @my_model, @position, @width, @height, @arity, @coarity) ->
    Alonzo.registry.regsiter_node(this)

    @level = @parent.level + 1
    @submodel_id = Alonzo.Utils.list_last(@ancestry)
    @variable_arity   = @my_model.variable_arity
    @variable_coarity = @my_model.variable_coarity
    @display_name = @my_model.name
    @sugared_maps = null
    @sugared_map_ancestry = Alonzo.Utils.list_append(@parent.sugared_map_ancestry, 0)

    width_in_tag_space = @parent.convert_magnitude_to_tag_space(@width)

    @can_be_drop_target_for_nodes = false
    @children_are_visible         = false

    if width_in_tag_space > Alonzo.graphics_constants.detail_threshold.name_only
      @_node_graphics = new NameOnlyNodeGraphics(this)
    else
      @_node_graphics = new NoDetailNodeGraphics(this)

    @_node_graphics.draw()

class RawInputNode extends Node
  @FIXED_HEIGHT_IN_PARENT: 10

  # position, width, and height are in the parent's space
  constructor: (@parent, @ancestry, @position, @width, @current_value) ->
    Alonzo.registry.regsiter_node(this)
    @can_be_drop_target_for_nodes = false
    @children_are_visible         = false
    @level = @parent.level + 1
    @display_name = "Input"
    @submodel_id = Alonzo.Utils.list_last(@ancestry)
    @sugared_map_ancestry = Alonzo.Utils.list_append(@parent.sugared_map_ancestry, 0)

    @arity   = 0
    @coarity = 1
    @variable_arity   = false
    @variable_coarity = false
    @height = RawInputNode.FIXED_HEIGHT_IN_PARENT
    if @parent.convert_magnitude_to_tag_space(@width) > 50
      @_node_graphics = new TextLineInputNodeGraphics(this)
    else
      @_node_graphics = new NameOnlyNodeGraphics(this)
    @_node_graphics.draw()

  get_input_label:  (argnum) -> null
  get_output_label: (argnum) -> if argnum is 1 then "value" else null

class CodeNode extends Node
  @FIXED_HEIGHT_IN_PARENT: 80

  # position, width, and height are in the parent's space
  constructor: (@parent, @ancestry, @position, @width, @contents) ->
    Alonzo.registry.regsiter_node(this)
    @can_be_drop_target_for_nodes = false
    @children_are_visible         = false
    @level = @parent.level + 1
    @display_name = "Wolfram Language Code"
    @submodel_id = Alonzo.Utils.list_last(@ancestry)
    @sugared_map_ancestry = Alonzo.Utils.list_append(@parent.sugared_map_ancestry, 0)

    @arity   = 2
    @coarity = 1
    @variable_arity   = false
    @variable_coarity = false
    @height = CodeNode.FIXED_HEIGHT_IN_PARENT
    if @parent.convert_magnitude_to_tag_space(@width) > 50
      @_node_graphics = new TextBoxNodeGraphics(this)
    else
      @_node_graphics = new NameOnlyNodeGraphics(this)
    @_node_graphics.draw()

  get_input_label:  (argnum) -> null
  get_output_label: (argnum) -> if argnum is 1 then "value" else null

class SmartInputNode extends Node
  @FIXED_HEIGHT_IN_PARENT: 10

  # position, width, and height are in the parent's space
  constructor: (@parent, @ancestry, @position, @width, @current_value) ->
    Alonzo.registry.regsiter_node(this)
    @can_be_drop_target_for_nodes = false
    @children_are_visible         = false
    @level = @parent.level + 1
    @display_name = "Smart Input"
    @submodel_id = Alonzo.Utils.list_last(@ancestry)
    @sugared_map_ancestry = Alonzo.Utils.list_append(@parent.sugared_map_ancestry, 0)

    @arity   = 0
    @coarity = 1
    @variable_arity   = false
    @variable_coarity = false
    @height = SmartInputNode.FIXED_HEIGHT_IN_PARENT
    if @parent.convert_magnitude_to_tag_space(@width) > 50
      @_node_graphics = new TextLineInputNodeGraphics(this)
    else
      @_node_graphics = new NameOnlyNodeGraphics(this)
    @_node_graphics.draw()

  get_input_label:  (argnum) -> null
  get_output_label: (argnum) -> if argnum is 1 then "value" else null

class SetVariableNode extends Node
  @FIXED_HEIGHT_IN_PARENT: 10

  # position, width, and height are in the parent's space
  constructor: (@parent, @ancestry, @position, @width, @current_variable_name) ->
    Alonzo.registry.regsiter_node(this)
    @can_be_drop_target_for_nodes = false
    @children_are_visible         = false
    @level = @parent.level + 1
    @display_name = "Set Storage"
    @submodel_id = Alonzo.Utils.list_last(@ancestry)
    @sugared_map_ancestry = Alonzo.Utils.list_append(@parent.sugared_map_ancestry, 0)

    @arity   = 1
    @coarity = 0
    @variable_arity   = false
    @variable_coarity = false
    @height = SetVariableNode.FIXED_HEIGHT_IN_PARENT
    if @parent.convert_magnitude_to_tag_space(@width) > 50
      @_node_graphics = new SetVariableNodeGraphics(this)
    else
      @_node_graphics = new NameOnlyNodeGraphics(this)
    @_node_graphics.draw()

class RefVariableNode extends Node
  @FIXED_HEIGHT_IN_PARENT: 10

  # position, width, and height are in the parent's space
  constructor: (@parent, @ancestry, @position, @width, @current_variable_name) ->
    Alonzo.registry.regsiter_node(this)
    @can_be_drop_target_for_nodes = false
    @children_are_visible         = false
    @level = @parent.level + 1
    @display_name = "Load Storage"
    @submodel_id = Alonzo.Utils.list_last(@ancestry)
    @sugared_map_ancestry = Alonzo.Utils.list_append(@parent.sugared_map_ancestry, 0)

    @arity   = 0
    @coarity = 1
    @variable_arity   = false
    @variable_coarity = false
    @height = RefVariableNode.FIXED_HEIGHT_IN_PARENT
    if @parent.convert_magnitude_to_tag_space(@width) > 50
      @_node_graphics = new RefVariableNodeGraphics(this)
    else
      @_node_graphics = new NameOnlyNodeGraphics(this)
    @_node_graphics.draw()

class Bubble extends Node
  constructor: (@parent, @ancestry, @source_idargnum, @position, @width, @height) ->
    Alonzo.registry.regsiter_node(this)
    @can_be_drop_target_for_nodes = false
    @children_are_visible         = false
    @level = @parent.level + 1
    @arity   = 1
    @coarity = 0
    @variable_arity   = false
    @variable_coarity = false
    @display_name = "Output"
    @submodel_id = Alonzo.Utils.list_last(@ancestry)
    @sugared_maps = null
    @sugared_map_ancestry = Alonzo.Utils.list_append(@parent.sugared_map_ancestry, 0)

    @_node_graphics = new BubbleGraphics(this)
    @_node_graphics.draw()

  transplant_to_new_parent_at_location: (droptarget_node, new_upper_left) ->
    my_bubble_id = Alonzo.Utils.list_last(@ancestry)
    my_bubble_datastructure = Library.get_bubble_by_ancestry(@ancestry)
    my_bubble_datastructure = Alonzo.Utils.json_clone(my_bubble_datastructure)
    new_ancestry = Alonzo.Utils.list_append(droptarget_node.ancestry, my_bubble_id)
    Library.remove_bubble(@ancestry)
    Library.add_bubble(new_ancestry, new_upper_left, my_bubble_datastructure.size, my_bubble_datastructure.source, my_bubble_datastructure.density)
    if @is_selected()
      @remove_from_selection()
      Alonzo.volatile_state.selected_bubbles.push(Alonzo.Utils.list_append(droptarget_node.ancestry, @submodel_id))

  # deletes self from parent model, also deletes link going to/from self
  # writes to Library but not Database
  delete_self: () ->
    @delete_all_links_going_to_self()
    @remove_from_selection()
    Library.remove_bubble(@ancestry)

  # if there's a bubble inside a node, but that bubble isn't shown (because it's too small or too deep, for example),
  # then that node is deleted, the bubble needs to be deleted but you can't use delete_self because the Bubble doesn't
  # exist, so you have to use this.  I've put it here so it's next to delete_self.
  @delete_bubble_when_not_shown: (bubble_data) ->
    sb = Alonzo.volatile_state.selected_bubbles
    Alonzo.volatile_state.selected_bubbles = (x for x in sb when not Alonzo.Utils.ancestry_same(bubble_data.ancestry, x))
    Library.remove_bubble(bubble_data.ancestry)

  is_selected: () ->
    for each in Alonzo.volatile_state.selected_bubbles
      if Alonzo.Utils.ancestry_same(@ancestry, each)
        return true
    return false

  add_to_selection: () ->
    Alonzo.volatile_state.selected_bubbles.push(@ancestry)

  # remember this code is mostly copied into @delete_bubble_when_not_shown
  remove_from_selection: () ->
    sb = Alonzo.volatile_state.selected_bubbles
    Alonzo.volatile_state.selected_bubbles = (x for x in sb when not Alonzo.Utils.ancestry_same(@ancestry, x))

  get_input_label:  (argnum) -> if argnum is 1 then "value" else null
  get_output_label: (argnum) -> null

class ResultNode extends Node
  constructor: (@parent, @ancestry, @position, @width, @height) ->
    Alonzo.registry.regsiter_node(this)
    @can_be_drop_target_for_nodes = false
    @children_are_visible         = false
    @level = @parent.level + 1
    @arity   = 1
    @coarity = 0
    @variable_arity   = false
    @variable_coarity = false
    @display_name = "Result"
    @submodel_id = Alonzo.Utils.list_last(@ancestry)
    @sugared_maps = null
    @sugared_map_ancestry = Alonzo.Utils.list_append(@parent.sugared_map_ancestry, 0)

    @_node_graphics = new ResultGraphics(this)
    @_node_graphics.draw()

  get_input_label:  (argnum) -> if argnum is 1 then "value" else null
  get_output_label: (argnum) -> null

class Diagram extends Node
  constructor: () ->
    Alonzo.registry.regsiter_node(this)
    @can_be_drop_target_for_nodes = true
    @children_are_visible         = true
    @sugared_maps                 = null

    @level    = 0
    @arity    = 0
    @coarity  = 0
    @variable_arity   = false
    @variable_coarity = false
    @my_model = Library.get_model_for_uuid(Library.get_uuid_of_current_top_level_model())
    @sugared_map_ancestry = []
    @ancestry             = []
    @_node_graphics = new DiagramGraphics(this)
    @_node_graphics.draw()

  convert_point_to_tag_space: (x, y) ->
    if typeof(x) is "object"
      y = x[1]
      x = x[0]

    [
      (x - Alonzo.volatile_state.viewport_00[0]) * Alonzo.volatile_state.zoom
      (y - Alonzo.volatile_state.viewport_00[1]) * Alonzo.volatile_state.zoom
    ]

  convert_magnitude_to_tag_space: (magnitude) ->
    magnitude * Alonzo.volatile_state.zoom

  is_child_of: (other_node) ->
    false

  is_sibling_of: (other_node) ->
    false

  is_selected: () ->
    return false


# also deletes any links going to/from the port
# handles singletons and other things
# not for deleting bubble ports
# returns without doing anything if the port is not deleteable
Alonzo.delete_port = (parent_model_uuid, submodel_id, type, argnum) ->
  parent_model_data   = Library.get_model_for_uuid(parent_model_uuid)
  submodel_data       = Library.get_submodel_datastructure(parent_model_uuid, submodel_id)
  if submodel_data.submodel_type isnt "model" then return
  submodel_model_data = Library.get_model_for_uuid(submodel_data.uuid)

  if submodel_model_data.composite
    Alonzo.delete_port_from_composite_model(submodel_model_data.uuid, type, argnum)
  else
    [current_arity, current_coarity] = Alonzo.get_submodel_arity_coarity(submodel_data)
    if type is ConnectionPort.types.input
      if not submodel_model_data.variable_arity then return
      if current_arity == submodel_model_data.default_arity then return

      for each_link in parent_model_data.links
        [from_id, from_argnum, to_id, to_argnum] = each_link
        if to_id == submodel_id
          if to_argnum == argnum
            Library.remove_link_from_model(parent_model_uuid, from_id, from_argnum, to_id, to_argnum)
          if to_argnum > argnum
            Library.remove_link_from_model(parent_model_uuid, from_id, from_argnum, to_id, to_argnum)
            Library.add_link_to_model(     parent_model_uuid, from_id, from_argnum, to_id, to_argnum - 1)

      Library.set_submodel_override_arity(parent_model_uuid, submodel_id, current_arity - 1)
    else if type is ConnectionPort.types.output
      if not submodel_model_data.variable_coarity then return
      if current_coarity == submodel_model_data.default_coarity then return

      for each_link in parent_model_data.links
        [from_id, from_argnum, to_id, to_argnum] = each_link
        if from_id == submodel_id
          if from_argnum == argnum
            Library.remove_link_from_model(parent_model_uuid, from_id, from_argnum, to_id, to_argnum)
          if from_argnum > argnum
            Library.remove_link_from_model(parent_model_uuid, from_id, from_argnum,     to_id, to_argnum)
            Library.add_link_to_model(     parent_model_uuid, from_id, from_argnum - 1, to_id, to_argnum)

      # for each bubble, see if it's in this parent model, if so, delete or move its link if necessary
      for each_bubble in Library.all_bubbles()
        parent_ancestry = Alonzo.Utils.list_most(each_bubble.ancestry)
        if parent_model_uuid is Library.get_model_uuid_for_ancestry(parent_ancestry)
          # the bubble is inside the parent model
          [from_id, from_argnum] = each_bubble.source
          if from_id == submodel_id
            if from_argnum == argnum
              #delete bubble source
              Library.remove_source_from_bubble(each_bubble.ancestry)
            else if from_argnum > argnum
              #chance source
              Library.set_source_for_bubble(each_bubble.ancestry, [from_id, from_argnum - 1])

      Library.set_submodel_override_coarity(parent_model_uuid, submodel_id, current_coarity - 1)
    else
      console.error("trying to delete port, found unknown type " + type)

Alonzo.delete_port_from_composite_model = (model_uuid, type, argnum) ->
  model_to_remove_from = Library.get_model_for_uuid(model_uuid)

  if type is ConnectionPort.types.input
    # reduce the defalut_arity of the model
    new_arity = model_to_remove_from.default_arity - 1
    Library.set_model_default_arity(model_uuid, new_arity)

    # rewrite any affected links inside the changed model
    for each_link in model_to_remove_from.links
      [from_id, from_argnum, to_id, to_argnum] = each_link
      if from_id == 0
        if from_argnum == argnum
          Library.remove_link_from_model(model_to_remove_from.uuid, from_id, from_argnum, to_id, to_argnum)
        if from_argnum >  argnum
          Library.remove_link_from_model(model_to_remove_from.uuid, from_id, from_argnum,     to_id, to_argnum)
          Library.add_link_to_model(     model_to_remove_from.uuid, from_id, from_argnum - 1, to_id, to_argnum)

    # rewrite any affected bubble sources inside the changed model
    for each_bubble in Library.all_bubbles() when each_bubble.source isnt null
      parent_ancestry = Alonzo.Utils.list_most(each_bubble.ancestry)
      if model_to_remove_from.uuid is Library.get_model_uuid_for_ancestry(parent_ancestry)
        # the bubble is inside the model_to_remove_from
        [from_id, from_argnum] = each_bubble.source
        if from_id == 0
          if from_argnum == argnum
            Library.remove_source_from_bubble(each_bubble.ancestry)
          if from_argnum >  argnum
            Library.set_source_for_bubble(each_bubble.ancestry, [from_id, from_argnum - 1])

    # rewrite any affected links in models using the changed model
    for each_model in Library.get_all_models() when each_model.composite
      for each_submodel in each_model.submodels
        if each_submodel.submodel_type is "model" and each_submodel.uuid == model_to_remove_from.uuid
          for each_link in each_model.links
            [from_id, from_argnum, to_id, to_argnum] = each_link
            if to_id == each_submodel.submodel_id
              if to_argnum == argnum
                Library.remove_link_from_model(each_model.uuid, from_id, from_argnum, to_id, to_argnum)
              if to_argnum >  argnum
                Library.remove_link_from_model(each_model.uuid, from_id, from_argnum, to_id, to_argnum    )
                Library.add_link_to_model(     each_model.uuid, from_id, from_argnum, to_id, to_argnum - 1)

    # rewrite any affected bubble sources in models using the changed model
    # impossible when deleting a left-side port

  else if type is ConnectionPort.types.output
    # change coarity of model
    new_coarity = model_to_remove_from.default_coarity - 1
    Library.set_model_default_coarity(model_uuid, new_coarity)

    # rewrite any affected links inside the changed model
    for each_link in model_to_remove_from.links
      [from_id, from_argnum, to_id, to_argnum] = each_link
      if to_id == 0
        if to_argnum == argnum
          Library.remove_link_from_model(model_to_remove_from.uuid, from_id, from_argnum, to_id, to_argnum)
        if to_argnum >  argnum
          Library.remove_link_from_model(model_to_remove_from.uuid, from_id, from_argnum, to_id, to_argnum    )
          Library.add_link_to_model(     model_to_remove_from.uuid, from_id, from_argnum, to_id, to_argnum - 1)

    # rewrite any affected bubble sources inside the changed model
    # impossible when deleting a right-side port

    # rewrite any affected links in models using the changed model
    for each_model in Library.get_all_models() when each_model.composite
      for each_submodel in each_model.submodels
        if each_submodel.submodel_type is "model" and each_submodel.uuid == model_to_remove_from.uuid
          for each_link in each_model.links
            [from_id, from_argnum, to_id, to_argnum] = each_link
            if from_id == each_submodel.submodel_id
              if from_argnum == argnum
                Library.remove_link_from_model(each_model.uuid, from_id, from_argnum, to_id, to_argnum)
              if from_argnum >  argnum
                Library.remove_link_from_model(each_model.uuid, from_id, from_argnum    , to_id, to_argnum)
                Library.add_link_to_model(     each_model.uuid, from_id, from_argnum - 1, to_id, to_argnum)

    # rewrite any affected bubble sources in models using the changed model
    for each_bubble in Library.all_bubbles() when each_bubble.source isnt null
      parent_ancestry        = Alonzo.Utils.list_most(each_bubble.ancestry)
      [from_id, from_argnum] = each_bubble.source
      parent_model_uuid      = Library.get_model_uuid_for_ancestry(parent_ancestry)
      parent_model           = Library.get_model_for_uuid(parent_model_uuid)

      if from_id != 0
        source_submodel_datastructure = Library.get_submodel_datastructure(parent_model_uuid, from_id)
        if source_submodel_datastructure.submodel_type is "model"
          if source_submodel_datastructure.uuid == model_to_remove_from.uuid
            if from_argnum == argnum
              Library.remove_source_from_bubble(each_bubble.ancestry)
            if from_argnum >  argnum
              Library.set_source_for_bubble(each_bubble.ancestry, [from_id, from_argnum - 1])

  else
    console.error("trying to delete port, found unknown type " + type)

export {Node, UserDataNode, RawInputNode, CodeNode, SmartInputNode, SetVariableNode, RefVariableNode, Bubble, ResultNode, Diagram}
