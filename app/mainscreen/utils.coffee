import Library from './Library.coffee'
import {ConnectionPort} from './ConnectionPort.coffee'
import {Bubble} from './Node.coffee'



Alonzo.Utils = {
  generate_uid: () ->
    #change both instances of 10 to 36 to also include letters
    #the purpose of the leading 1 is so that, for example, 0123 never gets shortened to 123
    '1xxxx'.replace(/[xy]/g, (() -> (Math.random()*10|0).toString(10)))
  random_4digit_number: () ->
    Math.random()*10000|0
  random_new_submodel_id: () ->
    Alonzo.Utils.random_4digit_number() * Alonzo.Utils.random_4digit_number()

  # if input is 0, output will be [], if input is 1, output will be [1], if input is 4, output will be [1,2,3,4]
  range_1_to: (number) ->
    if      number <  0
      []
    else if number is 0
      []
    else if number is 1
      [1]
    else
      [1..number]

  # list_most gives all except the last element
  list_most: (the_list) ->
    if the_list.length is 0
      console.error("tried to take list_most([])")
    else
      the_list[..-2]
  list_rest: (the_list) ->
    the_list[1..]
  list_last: (the_list) ->
    the_list[the_list.length - 1]
  list_append: (the_list, new_last) ->
    [the_list..., new_last]
  list_prepend: (new_first, the_list) ->
    [new_first, the_list...]
  list_insert_at: (the_list, new_item, new_index) ->   # new_index is zero-based
    if new_index == 0
      Alonzo.Utils.list_prepend(new_item, the_list)
    else if new_index == the_list.length
      Alonzo.Utils.list_append(the_list, new_item)
    else if new_index < 0 or new_index > the_list.length
      console.error("list_insert_at called with new_index=" + new_index + " but the_list was " + the_list)
    else
      [the_list[...new_index]..., new_item, the_list[new_index..]...]
  drop_element_by_index: (the_list, index) ->
    if index < 0 or index > the_list.length
      console.error("drop_element_by_index called with index " + index + " and list " + the_list)
    else
      [the_list[...index]..., the_list[(index+1)..]...]
  ancestry_same: (anc1, anc2) ->
    if anc1.length != anc2.length
      return false
    if anc1.length is 0 and anc2.length is 0
      return true
    for x in [0..anc1.length-1]
      if anc1[x] != anc2[x]
        return false
    return true
  # this is only doubled so that I can change ancestry logic in the future if I need to
  lists_same: (list1, list2) ->
    Alonzo.Utils.ancestry_same(list1, list2)
  ancestry_starts_with: (anc, starts) ->
    if starts.length > anc.length
      false
    if starts.length is 0
      true
    else
      Alonzo.Utils.ancestry_same(starts, anc[..(starts.length - 1)])

  shift_point_right_by: (point, amount) ->
    [point[0] + amount, point[1]]

  scale_vector_by: (vector, amount) ->
    [vector[0] * amount, vector[1] * amount]

  abs_distance_between_points: (p1, p2) ->
    Math.sqrt(Math.pow(p1[0] - p2[0], 2) + Math.pow(p1[1] - p2[1], 2))

  add_vectors: (v1, v2) ->
    [v1[0] + v2[0], v1[1] + v2[1]]

  subtract_vectors: (v1, v2) ->
    [v1[0] - v2[0], v1[1] - v2[1]]

  json_clone: (obj) ->
    JSON.parse(JSON.stringify(obj))

  straight_line_path_string: (x1, y1, x2, y2) ->
    "M " + x1 + ' ' + y1 + ' ' + "L " + x2 + ' ' + y2

  #all inputs in tagspace
  oliver_path_string: (node_upper_left, oliver_width, oliver_height, corner_radius) ->
    control_point_offset = corner_radius/2
    difference = corner_radius - control_point_offset

    "M " + (node_upper_left[0] + corner_radius) + "," + node_upper_left[1]      + " " +
    "c " + (-control_point_offset)              + "," + 0                       + " " +
           (-corner_radius)                     + "," + difference              + " " +
           (-corner_radius)                     + "," + (corner_radius)         + " " + #lower left point
    "l " + 0                                    + "," + (-oliver_height)        + " " + #above that point
    "c " + 0                                    + "," + (-control_point_offset) + " " +
           difference                           + "," + (-corner_radius)        + " " +
           corner_radius                        + "," + (-corner_radius)        + " " + #finish upper left curve
    "l " + (oliver_width - 2*corner_radius)     + "," + 0                       + " " + #right of that
    "c " + control_point_offset                 + "," + 0                       + " " +
           corner_radius                        + "," + difference              + " " +
           corner_radius                        + "," + corner_radius           + " " + #finish upper right curve
    "l " + 0                                    + "," + oliver_height           + " " + #lower right point
    "c " + 0                                    + "," + (-control_point_offset) + " " +
           (-difference)                        + "," + (-corner_radius)        + " " +
           (-corner_radius)                     + "," + (-corner_radius)        + " " + #finish lower right curve
    "l " + (-oliver_width + 2*corner_radius)    + "," + 0                       + " "   #back to start
}

Alonzo.evaluate_command = () ->
  console.log("evaluate command")

  Alonzo.compileDiagram()
  # mathematica -noprompt -initfile thecode.m

# specifier is either the model uuid, or "AAAbubble", or "AAAsingleton"
Alonzo.make_new_node = (specifier, position_tag) ->
  droptarget_node = Alonzo.deepest_droptarget_node_at_this_point(position_tag)
  if specifier is "AAAbubble"
    position_parent = droptarget_node.convert_point_from_tag_space(position_tag)
    width           = Alonzo.graphics_constants.new_node_default_width
    height          = width
    new_submodel_id = Alonzo.Utils.random_new_submodel_id()
    new_ancestry    = Alonzo.Utils.list_append(droptarget_node.ancestry, new_submodel_id)
    Library.add_bubble(new_ancestry, position_parent, [width, height], null)
  else if specifier is "AAAresult"
    new_submodel_datastructure = {
      submodel_id:   Alonzo.Utils.random_new_submodel_id()
      submodel_type: "result"
      position:      droptarget_node.convert_point_from_tag_space(position_tag)
      width:         Alonzo.graphics_constants.new_node_default_width
      height:        Alonzo.graphics_constants.new_node_default_width
      density:       0.5
    }
    Library.add_submodel_to_model(droptarget_node.my_model.uuid, new_submodel_datastructure, write_to_database = true)
  else if specifier is "AAAraw"
    new_submodel_datastructure = {
      submodel_id:   Alonzo.Utils.random_new_submodel_id()
      submodel_type: "singleton"
      position:      droptarget_node.convert_point_from_tag_space(position_tag)
      width:         Alonzo.graphics_constants.new_node_default_width
      singleton_input: {
        type:  "raw"
        value: ""
      }
    }
    Library.add_submodel_to_model(droptarget_node.my_model.uuid, new_submodel_datastructure, write_to_database = true)
  else if specifier is "AAAcodenode"
    new_submodel_datastructure = {
      submodel_id:   Alonzo.Utils.random_new_submodel_id()
      submodel_type: "codenode"
      position:      droptarget_node.convert_point_from_tag_space(position_tag)
      width:         Alonzo.graphics_constants.new_node_default_width * 2
      contents:      ""
    }
    Library.add_submodel_to_model(droptarget_node.my_model.uuid, new_submodel_datastructure, write_to_database = true)
  else if specifier is "AAAsemantic"
    new_submodel_datastructure = {
      submodel_id:   Alonzo.Utils.random_new_submodel_id()
      submodel_type: "singleton"
      position:      droptarget_node.convert_point_from_tag_space(position_tag)
      width:         Alonzo.graphics_constants.new_node_default_width
      singleton_input: {
        type:  "semantic_interpretation"
        value: ""
      }
    }
    Library.add_submodel_to_model(droptarget_node.my_model.uuid, new_submodel_datastructure, write_to_database = true)
  else if specifier is "AAAsetvariable"
    new_submodel_datastructure = {
      submodel_id:   Alonzo.Utils.random_new_submodel_id()
      submodel_type: "set_variable"
      position:      droptarget_node.convert_point_from_tag_space(position_tag)
      width:         Alonzo.graphics_constants.new_node_default_width
      variable_name: ""
    }
    Library.add_submodel_to_model(droptarget_node.my_model.uuid, new_submodel_datastructure, write_to_database = true)
  else if specifier is "AAArefvariable"
    new_submodel_datastructure = {
      submodel_id:   Alonzo.Utils.random_new_submodel_id()
      submodel_type: "ref_variable"
      position:      droptarget_node.convert_point_from_tag_space(position_tag)
      width:         Alonzo.graphics_constants.new_node_default_width
      variable_name: ""
    }
    Library.add_submodel_to_model(droptarget_node.my_model.uuid, new_submodel_datastructure, write_to_database = true)
  else
    new_submodel_datastructure = {
      submodel_id:   Alonzo.Utils.random_new_submodel_id()
      submodel_type: "model"
      position:      droptarget_node.convert_point_from_tag_space(position_tag)
      uuid:          specifier # uuid of the submodel's model
      width:         Alonzo.graphics_constants.new_node_default_width
    }
    Library.add_submodel_to_model(droptarget_node.my_model.uuid, new_submodel_datastructure, write_to_database = true)
  Library.flush_to_database()
  Alonzo.render()

Alonzo.add_port_to_composite_model = (uuid, after_argnum, type) ->
  model_to_add_to = Library.get_model_for_uuid(uuid)

  if type is NewPortButton.types.left
    # change arity of model
    new_arity = model_to_add_to.default_arity + 1
    Library.set_model_default_arity(uuid, new_arity)

    # rewrite any affected links inside the changed model
    for each_link in model_to_add_to.links
      [from_id, from_argnum, to_id, to_argnum] = each_link
      if from_id == 0 and from_argnum > after_argnum
        Library.remove_link_from_model(model_to_add_to.uuid, from_id, from_argnum,     to_id, to_argnum)
        Library.add_link_to_model(     model_to_add_to.uuid, from_id, from_argnum + 1, to_id, to_argnum)

    # rewrite any affected bubble sources inside the changed model
    for each_bubble in Library.all_bubbles() when each_bubble.source isnt null
      parent_ancestry = Alonzo.Utils.list_most(each_bubble.ancestry)
      if model_to_add_to.uuid is Library.get_model_uuid_for_ancestry(parent_ancestry)
        # the bubble is inside the model_to_add_to
        [from_id, from_argnum] = each_bubble.source
        if from_id == 0 and from_argnum > after_argnum
          #chance source
          Library.set_source_for_bubble(each_bubble.ancestry, [from_id, from_argnum + 1])

    # rewrite any affected links in models using the changed model
    for each_model in Library.get_all_models() when each_model.composite
      for each_submodel in each_model.submodels
        if each_submodel.submodel_type is "model" and each_submodel.uuid == model_to_add_to.uuid
          for each_link in each_model.links
            [from_id, from_argnum, to_id, to_argnum] = each_link
            if to_id == each_submodel.submodel_id and to_argnum > after_argnum
              Library.remove_link_from_model(each_model.uuid, from_id, from_argnum, to_id, to_argnum    )
              Library.add_link_to_model(     each_model.uuid, from_id, from_argnum, to_id, to_argnum + 1)

    # rewrite any affected bubble sources in models using the changed model
    # impossible when adding a left-side port

  else if type is NewPortButton.types.right
    # change coarity of model
    new_coarity = model_to_add_to.default_coarity + 1
    Library.set_model_default_coarity(uuid, new_coarity)

    # rewrite any affected links inside the changed model
    for each_link in model_to_add_to.links
      [from_id, from_argnum, to_id, to_argnum] = each_link
      if to_id == 0 and to_argnum > after_argnum
        Library.remove_link_from_model(model_to_add_to.uuid, from_id, from_argnum, to_id, to_argnum    )
        Library.add_link_to_model(     model_to_add_to.uuid, from_id, from_argnum, to_id, to_argnum + 1)

    # rewrite any affected bubble sources inside the changed model
    # impossible when adding a right-side port

    # rewrite any affected links in models using the changed model
    for each_model in Library.get_all_models() when each_model.composite
      for each_submodel in each_model.submodels
        if each_submodel.submodel_type is "model" and each_submodel.uuid == model_to_add_to.uuid
          for each_link in each_model.links
            [from_id, from_argnum, to_id, to_argnum] = each_link
            if from_id == each_submodel.submodel_id and from_argnum > after_argnum
              Library.remove_link_from_model(each_model.uuid, from_id, from_argnum    , to_id, to_argnum)
              Library.add_link_to_model(     each_model.uuid, from_id, from_argnum + 1, to_id, to_argnum)

    # rewrite any affected bubble sources in models using the changed model
    for each_bubble in Library.all_bubbles() when each_bubble.source isnt null
      parent_ancestry        = Alonzo.Utils.list_most(each_bubble.ancestry)
      [from_id, from_argnum] = each_bubble.source
      parent_model_uuid      = Library.get_model_uuid_for_ancestry(parent_ancestry)
      parent_model           = Library.get_model_for_uuid(parent_model_uuid)

      if from_id != 0
        source_submodel_datastructure = Library.get_submodel_datastructure(parent_model_uuid, from_id)
        if source_submodel_datastructure.submodel_type is "model"
          if source_submodel_datastructure.uuid == model_to_add_to.uuid and from_argnum > after_argnum
            #chance source
            Library.set_source_for_bubble(each_bubble.ancestry, [from_id, from_argnum + 1])

  else
    console.error("unknown type " + type + "while adding port to composite model")

# ancestry of the node to which the port is being added
# the reason you need ancestry of the node and not just uuid of the enclosing model and submodel_id
# is that you might have to update bubble links as well if you're adding an output port
# This function is a bit ugly.  I should look up the actual links being changed using the registry
# then use their delete methods, then call Alonzo.add_new_link(.).  It would be a little slower,
# but would make code maintenance easier.
Alonzo.add_port_to_submodel = (ancestry, after_argnum, type) ->
  node_having_port_added = Alonzo.registry.get_node_by_ancestry(ancestry)
  parent_model_uuid      = node_having_port_added.parent.my_model.uuid
  submodel_id            = node_having_port_added.submodel_id
  model_to_change        = Library.get_model_for_uuid(parent_model_uuid)
  submodel_to_change     = Library.get_submodel_datastructure(parent_model_uuid, submodel_id)
  submodels_model        = Library.get_model_for_uuid(submodel_to_change.uuid)
  [current_arity, current_coarity] = Alonzo.get_submodel_arity_coarity(submodel_to_change)
  if type is NewPortButton.types.left
    # set or change override_arity
    Library.set_submodel_override_arity(parent_model_uuid, submodel_id, current_arity + 1)

    # change all links in the model going to/from any port of the submodel above after_argnum
    for each_link in model_to_change.links
      [from_id, from_argnum, to_id, to_argnum] = each_link
      if to_id == submodel_id and to_argnum >= (after_argnum + 1)
        Library.remove_link_from_model(model_to_change.uuid, from_id, from_argnum, to_id, to_argnum    )
        Library.add_link_to_model(     model_to_change.uuid, from_id, from_argnum, to_id, to_argnum + 1)
  else if type is NewPortButton.types.right
    Library.set_submodel_override_coarity(parent_model_uuid, submodel_id, current_coarity + 1)

    for each_link in model_to_change.links
      [from_id, from_argnum, to_id, to_argnum] = each_link
      if from_id == submodel_id and from_argnum >= (after_argnum + 1)
        Library.remove_link_from_model(model_to_change.uuid, from_id, from_argnum,     to_id, to_argnum)
        Library.add_link_to_model(     model_to_change.uuid, from_id, from_argnum + 1, to_id, to_argnum)

    # in the case of adding an output port, I might have to update bubbles too
    for each_bubble in Alonzo.registry.sibling_nodes_of(node_having_port_added) when each_bubble instanceof Bubble
      bubble_data = Library.get_bubble_by_ancestry(each_bubble.ancestry)
      if bubble_data.source? and bubble_data.source.length isnt 0
        [from_id, from_argnum] = bubble_data.source
        if from_id == submodel_id and from_argnum >= (after_argnum + 1)
          each_bubble.delete_all_links_going_to_self()
          Library.set_source_for_bubble(each_bubble.ancestry, [from_id, from_argnum + 1])
  else
    console.error("unknown type " + type + "while adding port to submodel")

  # since I'm not using the Link.delete_self(.) function, the selection might get messed up
  Alonzo.clear_selection()

# sets the currently displayed diagram
# removes selection stuff etc
# renders
Alonzo.reinitialize_and_render_diagram = (diagram_uuid) ->
  Alonzo.volatile_state = Alonzo.Utils.json_clone(Alonzo.volatile_state_initialize)
  Alonzo.volatile_state.current_diagram_uuid = diagram_uuid
  Alonzo.render()

Alonzo.delete_command = () ->
  for each in Alonzo.registry.all_nodes when each.is_selected()
    each.delete_self()
  for each in Alonzo.registry.all_links when each.is_selected()
    each.delete_self()
  for each in Alonzo.volatile_state.selected_cps.sort((a,b) -> (b.argnum - a.argnum))
    Alonzo.delete_port(each.parent_model_uuid, each.submodel_id, each.type, each.argnum)

  Alonzo.clear_selection()
  Library.flush_to_database()
  Alonzo.render()

# takes a submodel specification
# only for model submodels
# if default_aspect_ratio is set to "auto", this function calculates what it should be
Alonzo.get_node_aspect_ratio = (submodel, arity_as_used, coarity_as_used) ->
  if submodel.singleton_input?
    console.error("get_node_aspect_ratio for singleton_input, I don't know what to do with this")

  if !submodel.uuid?
    console.error("get_node_aspect_ratio for non-model-backed node, don't know what to do")

  model = Library.get_model_for_uuid(submodel.uuid)
  if model.composite
    model.size[0] / model.size[1]
  else
    if submodel.override_aspect_ratio?
      submodel.override_aspect_ratio
    else if model.default_aspect_ratio is "auto"
      threshold          = 9
      name_length        = model.name.length
      name_length_factor = if name_length > threshold then Math.pow(1.1, name_length - threshold) else 1.0
      max_ports          = Math.max(arity_as_used, coarity_as_used) + 1
      max_ports_factor   = 1/max_ports
      if_nothing_else    = 4
      if_nothing_else * name_length_factor * max_ports_factor
    else
      model.default_aspect_ratio

# takes a submodel specification
Alonzo.get_submodel_arity_coarity = (submodel) ->
  if submodel.submodel_type is "singleton"
    console.warn("get_arity_coarity for singleton_input, did you mean to do that?")
    return [0, 1]
  else if submodel.submodel_type is "model"
    model = Library.get_model_for_uuid(submodel.uuid)
    [
      if model.variable_arity   and submodel.override_arity?   then submodel.override_arity   else model.default_arity,
      if model.variable_coarity and submodel.override_coarity? then submodel.override_coarity else model.default_coarity
    ]
  else
    console.error("don't know how to get arity/coarity for submodel type " + submodel.submodel_type)

# takes a submodel datastructure and tells if that submodel has a valid sugared map set
# only returns true for single input models for which the first input is set to sugared map
Alonzo.submodel_has_sugared_map_Q = (submodelDatastructure) ->
  sm = submodelDatastructure.sugared_map
  sm? and sm.length is 1 and sm[0] is 1 and Alonzo.get_submodel_arity_coarity(submodelDatastructure)[0] is 1

# TODO - this won't work beyond some depth because it'll just reach white and keep going
Alonzo.get_background_color_by_level = (level) ->
  lightness = 100 * level * Alonzo.graphics_constants.node.lighter_than_parent
  "rgb(#{lightness}%, #{lightness}%, #{lightness}%)"

Alonzo.set_footer_message = (message) ->
  Alonzo.chrome_state.current_message = message
  remove = () =>
    # if some other message has been set during my timeout, don't remove the new one
    if message is Alonzo.chrome_state.current_message
      Alonzo.chrome_state.current_message = null
      Alonzo.render_all()
  window.setTimeout(remove, Alonzo.chrome_state.message_removal_delay)
  Alonzo.render_all()

# selection stuff
# ===============================

# clears selected nodes, bubbles, and links
Alonzo.clear_selection = () ->
  Alonzo.volatile_state.selected_nodes        = []
  Alonzo.volatile_state.selected_bubbles      = []
  Alonzo.volatile_state.selected_links        = []
  Alonzo.volatile_state.selected_bubble_links = []
  Alonzo.volatile_state.selected_cps          = []
  Alonzo.volatile_state.selected_bubble_cps   = []

# the deepest node at this point which is capable of having other nodes dropped into it, not counting 'except' and its children
Alonzo.deepest_droptarget_node_at_this_point = (test_point_tag_space, except = null) ->
  candidates = (x for x in Alonzo.registry.all_nodes when (
    x.can_be_drop_target_for_nodes and
    x.tag_point_is_inside_node(test_point_tag_space) and
    (if except? then (not Alonzo.Utils.ancestry_starts_with(x.ancestry, except.ancestry)) else true)
    ))

  current_deepest_node = candidates[0]
  for x in candidates
    if x.level > current_deepest_node.level
      current_deepest_node = x
  return current_deepest_node

# if there is no cp at the point, null is returned
Alonzo.which_cp_is_at_this_point = (mouse_position_tag) ->
  for each_cp in Alonzo.registry.all_cps
    if each_cp.tag_point_is_inside_cp(mouse_position_tag)
      return each_cp
  return null

# If a link can be drawn between these cps, then the two input cps are returned in a list
# as [source_cp, sink_cp] ordered according to which of them would be the source and sink
# for the proposed link.  If a link can not be drawn between them, null is returned.
Alonzo.can_link_between_these_cps = (drop_cp, down_cp) ->
  if down_cp.type is ConnectionPort.types.input
    # down_cp is a left-side cp
    if Alonzo.Utils.ancestry_same(drop_cp.my_node.ancestry, down_cp.my_node.ancestry) and drop_cp.type is ConnectionPort.types.output
      # drop_cp is a right-side cp on the same node as down_cp
      if down_cp.my_node.children_are_visible
        [down_cp, drop_cp]
      else
        # this would be making a loop
        # [drop_cp, down_cp]
        null
    else if drop_cp.my_node.is_child_of(down_cp.my_node) and drop_cp.type is ConnectionPort.types.input
      # drop_cp is a left-side cp on a child node of down_cp's node
      [down_cp, drop_cp]
    else if drop_cp.my_node.is_sibling_of(down_cp.my_node) and drop_cp.type is ConnectionPort.types.output
      # drop_cp is a right-side cp on a node which a sibling of down_cp's node
      [drop_cp, down_cp]
    else if drop_cp.my_node.is_parent_of(down_cp.my_node) and drop_cp.type is ConnectionPort.types.input
      # drop_cp is a left-side cp on a node which a parent of down_cp's node
      [drop_cp, down_cp]
    else
      null
  else if down_cp.type is ConnectionPort.types.output
    # down_cp is a right-side cp
    # if I want different logic depending on which cp was the start and end point of the drag, then
    # remove this little trick and write the logic, otherwise...
    if drop_cp.type is ConnectionPort.types.output
      if drop_cp.my_node.is_parent_of(down_cp.my_node)
        [down_cp, drop_cp]
      else if down_cp.my_node.is_parent_of(drop_cp.my_node)
        [drop_cp, down_cp]
      else
        null
    else
      Alonzo.can_link_between_these_cps(down_cp, drop_cp)

# This assumes that a link FROM source TO sink would be valid.
# This is called from mouse_overlay.onMouseUp(.).
# bubble-specific logic is in here, not done with inheritence
Alonzo.make_new_link = (source_cp, sink_cp) ->
  if sink_cp.my_node instanceof Bubble
    Library.set_source_for_bubble(sink_cp.my_node.ancestry, [source_cp.id_if_source, source_cp.argnum])
    Library.flush_to_database()
  else
    if sink_cp.type is ConnectionPort.types.output
      Library.add_link_to_model(
        sink_cp.my_node.my_model.uuid,
        source_cp.id_if_source,
        source_cp.argnum,
        0
        sink_cp.argnum,
      )
      Library.flush_to_database()
    else if sink_cp.type is ConnectionPort.types.input #sink cp is a left-side port
      Library.add_link_to_model(
        sink_cp.my_node.parent.my_model.uuid,
        source_cp.id_if_source,
        source_cp.argnum,
        sink_cp.id_if_sink,
        sink_cp.argnum
      )
      Library.flush_to_database()
    else
      console.error("unknown cp type")

# any selected input connection ports will have sugared map set
Alonzo.set_sugared_map = () ->
  for cp in Alonzo.volatile_state.selected_cps when cp.type is ConnectionPort.types.input
    model_uuid  = cp.parent_model_uuid
    submodel_id = cp.submodel_id
    argnum      = cp.argnum
    maps_before = Library.get_submodel_sugared_maps(model_uuid, submodel_id)

    if maps_before?
      maps_after = Alonzo.Utils.list_append(maps_before, argnum)
    else
      maps_after = [argnum]
    Library.set_submodel_sugared_maps(model_uuid, submodel_id, maps_after)

    Library.flush_to_database()
    Alonzo.render()

# any selected input connection ports will have sugared map set
Alonzo.unset_sugared_map = () ->
  for cp in Alonzo.volatile_state.selected_cps when cp.type is ConnectionPort.types.input
    model_uuid  = cp.parent_model_uuid
    submodel_id = cp.submodel_id
    argnum      = cp.argnum
    maps_before = Library.get_submodel_sugared_maps(model_uuid, submodel_id)

    if maps_before?
      maps_after = []
      for each in maps_before when each isnt argnum
        maps_after = Alonzo.Utils.list_append(maps_after, each)
      if maps_after.length is 0 then maps_after = null
      Library.set_submodel_sugared_maps(model_uuid, submodel_id, maps_after)

      Library.flush_to_database()
      Alonzo.render()

Alonzo.get_sugared_map_index = (ancestry) ->
  proposed = Alonzo.volatile_state.sugared_map_indicies[ancestry]
  if proposed? then proposed else 0
