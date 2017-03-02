import React, { Component } from 'react'
import {Bubble} from './Node.coffee'
import Library from './Library.coffee'


# this first checks to see if a mouse overlay is needed (by looking at the mouse state in the volatile state)
# if so, it returns the react element to use, if not, it returns null
Alonzo.get_mouse_overlay = () ->
  _node_and_bubble_drag = (clientX, clientY) ->
    # find the drag set
    #   if dragged node is selected, include it with all selected siblings
    #   else, just the dragged node
    # calculate their new drop positions in the drop target node
    # record any links that go between dragged nodes [id,arg,id,arg], same for bubble links [id,arg,bubbleid]
    # if new parent is same as old parent
    #   do NOT delete links, just transplant nodes
    #   # this is so that links going to/from the drag set will remain
    # else
    #   delete all links going to all nodes in drag set
    #   transplant nodes
    #   add back links to new parent

    drag_set             = [] # list of actual Node objects
    links_to_keep        = [] # list of [from_id, from_argnum, to_id, to_argnum]
    bubble_links_to_keep = [] # list of [from_id, from_argnum, bubble_id]

    # find the drag set
    dragged_node = Alonzo.registry.get_node_by_ancestry(Alonzo.volatile_state.drag_node.down_node_ancestry)
    if dragged_node.is_selected()
      drag_set.push(dragged_node)
      for sibling in Alonzo.registry.sibling_nodes_of(dragged_node) when sibling.is_selected()
        drag_set.push(sibling)
    else
      drag_set.push(dragged_node)

    # calculate new upper left positions of dragged nodes
    mouse_position_tag      = Alonzo.abs_to_rel(clientX, clientY)
    droptarget_node         = Alonzo.deepest_droptarget_node_at_this_point(mouse_position_tag, dragged_node)
    mouse_position_target   = droptarget_node.convert_point_from_tag_space(mouse_position_tag)
    down_offset_parent      = Alonzo.volatile_state.drag_node.down_offset_parent
    dragged_node_target_new = Alonzo.Utils.add_vectors(mouse_position_target, down_offset_parent)
    for each_node in drag_set
      offset_from_dragged_node = Alonzo.Utils.subtract_vectors(each_node.position, dragged_node.position)
      position_target_new      = Alonzo.Utils.add_vectors(offset_from_dragged_node, dragged_node_target_new)
      each_node.tmp = position_target_new

    # record links that go between dragged nodes
    for each_link in dragged_node.parent.my_model.links
      [from_id, from_argnum, to_id, to_argnum] = each_link
      from_side_in_drag_set = from_id in (x.submodel_id for x in drag_set)
      to_side_in_drag_set   = to_id   in (x.submodel_id for x in drag_set)
      if from_side_in_drag_set and to_side_in_drag_set
        links_to_keep.push(each_link)

    for each_node in drag_set when each_node instanceof Bubble
      if each_node.source_idargnum isnt null
        [source_id, source_argnum] = each_node.source_idargnum
        if source_id in (x.submodel_id for x in drag_set)
          bubble_links_to_keep.push([source_id, source_argnum, each_node.submodel_id])

    # actually move and transplant the dragged nodes
    new_parent_same_as_old = Alonzo.Utils.ancestry_same(dragged_node.parent.ancestry, droptarget_node.ancestry)
    if new_parent_same_as_old
      for each_node in drag_set
        each_node.transplant_to_new_parent_at_location(droptarget_node, each_node.tmp)
    else
      for each_node in drag_set
        each_node.delete_all_links_going_to_self()
        each_node.transplant_to_new_parent_at_location(droptarget_node, each_node.tmp)
      for each_link in links_to_keep
        Library.add_link_to_model(droptarget_node.my_model.uuid, each_link[0], each_link[1], each_link[2], each_link[3], write_to_database = false)
      for each_bubble_link in bubble_links_to_keep
        Library.set_source_for_bubble(Alonzo.Utils.list_append(droptarget_node.ancestry, each_bubble_link[2]), [each_bubble_link[0], each_bubble_link[1]])

    for each_node in drag_set
      delete each_node.tmp

    # set volatile_state.drag_node to new, possibly different, ancestry
    Alonzo.volatile_state.drag_node.down_node_ancestry = Alonzo.Utils.list_append(droptarget_node.ancestry, dragged_node.submodel_id)

  _drag_box_new_node = (e) ->
    # find the chunked set
    # calculate their new drop positions in the newly-created node
    # record any links that go between chunked nodes [id,arg,id,arg], same for bubble links [id,arg,bubbleid]
    # record any links that are 'cut' by the new node (they will need to go to inputs/outputs of the new node)
    # calculate the arity and coarity of the new node
    # make the new model
    # put an instance of the new model into the parent
    # transplant chunked nodes
    # add back links between chunked nodes, in their new parent
    # add internal links in the new model  going to/from id 0
    # add internal links in the old parent going to/from the new node

    chunked_nodes        = [] # list of actual Node objects
    links_to_keep        = [] # list of [from_id, from_argnum, to_id, to_argnum]
    bubble_links_to_keep = [] # list of [from_id, from_argnum, bubble_id]
    cut_inbound_links    = [] # list of [from_id, from_argnum, to_id, to_argnum]
    cut_outbound_links   = [] # list of [from_id, from_argnum, to_id, to_argnum]

    q = Alonzo.volatile_state.drag_new_node_box

    mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)
    down_node    = Alonzo.deepest_droptarget_node_at_this_point(Alonzo.volatile_state.drag_background.mousedown_position)
    current_node = Alonzo.deepest_droptarget_node_at_this_point(mouse_position_tag)

    if Alonzo.Utils.ancestry_same(current_node.ancestry, down_node.ancestry) #TODO what if the upper right or lower left is inside a child?
      # find the chunked set
      for each_child in Alonzo.registry.child_nodes_of(down_node)
        [top_left_x,      top_left_y]      = each_child.top_left_parent_space()
        [bot_right_x,     bot_right_y]     = each_child.bot_right_parent_space()
        [box_top_left_x,  box_top_left_y]  = q.top_left_parent_space
        [box_bot_right_x, box_bot_right_y] = q.bot_right_parent_space
        cond1 = top_left_x  >= box_top_left_x
        cond2 = top_left_y  >= box_top_left_y
        cond3 = bot_right_x <= box_bot_right_x
        cond4 = bot_right_y <= box_bot_right_y
        if cond1 and cond2 and cond3 and cond4
          chunked_nodes.push(each_child)

      # calculate new upper left positions of chunked nodes
      # can assume that the density of the space inside the new node is the same as the parent space
      for each_node in chunked_nodes
        each_node.tmp = Alonzo.Utils.subtract_vectors(each_node.position, q.top_left_parent_space)

      # record links that go between chunked nodes and links that are cut by the new node
      for each_link in down_node.my_model.links
        [from_id, from_argnum, to_id, to_argnum] = each_link
        from_side_in_chunked_nodes = from_id in (x.submodel_id for x in chunked_nodes)
        to_side_in_chunked_nodes   = to_id   in (x.submodel_id for x in chunked_nodes)
        if          from_side_in_chunked_nodes and     to_side_in_chunked_nodes
          links_to_keep.push(each_link)
        else if not from_side_in_chunked_nodes and     to_side_in_chunked_nodes
          cut_inbound_links.push(each_link)
        else if     from_side_in_chunked_nodes and not to_side_in_chunked_nodes
          cut_outbound_links.push(each_link)

      # links to bubbles
      # if a chunked bubble gets is source from a chunked node, keep the bubble link
      for each_node in chunked_nodes when each_node instanceof Bubble
        if each_node.source_idargnum isnt null
          [source_id, source_argnum] = each_node.source_idargnum
          if source_id in (x.submodel_id for x in chunked_nodes)
            bubble_links_to_keep.push([source_id, source_argnum, each_node.submodel_id])
      # (chunked bubbles that get their source from a non-chunked node will have their sources deleted
      #  when transplant_to_new_parent_at_location is called, then not explicitly put back, so in effect deleted)

      # for non-chunked bubbles that get their source from a chunked node, delete the bubble source
      for each_child in Alonzo.registry.child_nodes_of(down_node)
        if each_child instanceof Bubble and not (each_child in chunked_nodes)
          if each_child.source_idargnum isnt null
            [source_id, source_argnum] = each_child.source_idargnum
            if source_id in (x.submodel_id for x in chunked_nodes)
              each_child.delete_all_links_going_to_self()

      # calculate the arity, coarity, uuid, types of the new node
      new_arity       = cut_inbound_links.length
      new_coarity     = cut_outbound_links.length
      new_uuid        = Alonzo.Utils.generate_uid()
      new_submodel_id = Alonzo.Utils.random_new_submodel_id()

      # make the new model
      Library.create_new_model(
        {
          doctype:          "model-4"
          name:             "my model"
          uuid:             new_uuid
          default_arity:    new_arity
          default_coarity:  new_coarity
          category:         "userdef"

          diagram:          false
          data:             false
          composite:        true
          variable_arity:   false
          variable_coarity: false
          MM_builtin:       false

          size:             Alonzo.Utils.subtract_vectors(q.bot_right_parent_space, q.top_left_parent_space)

          submodels:        []
          links:            []
        }
      )

      # put an instance of the new model into the parent
      submodel_datastructure = {
        submodel_id:   new_submodel_id
        submodel_type: "model"
        position:      q.top_left_parent_space
        uuid:          new_uuid
        width:         q.bot_right_parent_space[0] - q.top_left_parent_space[0]
      }
      Library.add_submodel_to_model(down_node.my_model.uuid, submodel_datastructure, write_to_database = false)

      # make a real Node object for the new node, so the transplant functions will work
      new_node_ancestry = Alonzo.Utils.list_append(down_node.ancestry, new_submodel_id)
      new_node = new Node(
        down_node,
        new_node_ancestry,
        Library.get_model_for_uuid(new_uuid),
        q.top_left_parent_space,
        q.bot_right_parent_space[0] - q.top_left_parent_space[0],
        q.bot_right_parent_space[1] - q.top_left_parent_space[1], #TODO suspect
        new_arity,
        new_coarity
      )

      # transplant chunked nodes
      for each_node in chunked_nodes
        each_node.delete_all_links_going_to_self()
        each_node.transplant_to_new_parent_at_location(new_node, each_node.tmp)

      # add back links between chunked nodes, in their new parent
      for each_link in links_to_keep
        Library.add_link_to_model(new_node.my_model.uuid, each_link[0], each_link[1], each_link[2], each_link[3], write_to_database = false)
      for each_bubble_link in bubble_links_to_keep
        Library.set_source_for_bubble(Alonzo.Utils.list_append(new_node.ancestry, each_bubble_link[2]), [each_bubble_link[0], each_bubble_link[1]])

      # add internal links in the new model going to/from id 0
      # add internal links in the old parent going to/from the new node
      for each_link, i in cut_inbound_links
        new_argnum = i + 1
        [from_id, from_argnum, to_id, to_argnum] = each_link
        Library.add_link_to_model(new_node.my_model.uuid, 0, new_argnum, to_id, to_argnum)
        Library.add_link_to_model(down_node.my_model.uuid, from_id, from_argnum, new_submodel_id, new_argnum)
      for each_link, i in cut_outbound_links
        new_argnum = i + 1
        [from_id, from_argnum, to_id, to_argnum] = each_link
        Library.add_link_to_model(new_node.my_model.uuid, from_id, from_argnum, 0, new_argnum)
        Library.add_link_to_model(down_node.my_model.uuid, new_submodel_id, new_argnum, to_id, to_argnum)

      # clean up
      for each_node in chunked_nodes
        delete each_node.tmp

      Library.flush_to_database()

    Alonzo.volatile_state.drag_new_node_box.draw_it = false

  onMouseMove = (e) ->
    e.preventDefault()
    e.stopPropagation()

    if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.up
      console.warn("debug - got mouse move when the state was up, how did that happen?")
      return
    if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_background
      if Alonzo.volatile_state.ctrl_key_on_mouse_down
        Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.dragging_box_select
      else if Alonzo.volatile_state.shift_key_on_mouse_down
        Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.dragging_box_new_node
      else
        Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.dragging_background
    if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_cp
      Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.dragging_cp
    if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_node
      Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.dragging_node
    if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_node_name #if dragging the node name, you mean to drag the node
      Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.dragging_node
    if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_link
      Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.dragging_link
    if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_node_resizer
      Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.dragging_node_resizer

    if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_background
      mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)

      mouse_delta = [ #how much has the mouse moved (in pixels)?
        mouse_position_tag[0] - Alonzo.volatile_state.drag_background.mousedown_position[0],
        mouse_position_tag[1] - Alonzo.volatile_state.drag_background.mousedown_position[1]
      ]
      viewport_00_delta = [ #how much should the viewport move (in top level diagram space)?
        mouse_delta[0] / Alonzo.volatile_state.zoom,
        mouse_delta[1] / Alonzo.volatile_state.zoom
      ]
      new_viewport_00 = [ #new viewport00 in top level diagram space
        Alonzo.volatile_state.drag_background.mousedown_viewport00[0] - viewport_00_delta[0],
        Alonzo.volatile_state.drag_background.mousedown_viewport00[1] - viewport_00_delta[1]
      ]
      Alonzo.volatile_state.viewport_00 = new_viewport_00

      Alonzo.render()
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_cp
      mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)
      # maybe this should be different logic from droptarget?
      droptarget_node = Alonzo.deepest_droptarget_node_at_this_point(mouse_position_tag)
      internal = Alonzo.Utils.ancestry_same(droptarget_node.ancestry,                        Alonzo.volatile_state.drag_cp.down_cp.ancestry)
      external = Alonzo.Utils.ancestry_same(droptarget_node.ancestry, Alonzo.Utils.list_most(Alonzo.volatile_state.drag_cp.down_cp.ancestry))
      if internal or external
        Alonzo.volatile_state.drag_cp.dangling_link.draw_it           = true
        Alonzo.volatile_state.drag_cp.dangling_link.parent_ancestry   = droptarget_node.ancestry
        Alonzo.volatile_state.drag_cp.dangling_link.dangling_position = droptarget_node.convert_point_from_tag_space(mouse_position_tag)
      else
        Alonzo.volatile_state.drag_cp.dangling_link.draw_it           = false
      Alonzo.render()
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_node
      _node_and_bubble_drag(e.clientX, e.clientY)
      Alonzo.render()
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_box_select
      mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)
      mouse_down_tag     = Alonzo.volatile_state.drag_background.mousedown_position
      down_node          = Alonzo.deepest_droptarget_node_at_this_point(Alonzo.volatile_state.drag_background.mousedown_position)
      current_node       = Alonzo.deepest_droptarget_node_at_this_point(mouse_position_tag)

      if      mouse_position_tag[0] >  mouse_down_tag[0] and mouse_position_tag[1] >  mouse_down_tag[1] # dragging southeast
        box_top_left_tag  = mouse_down_tag
        box_bot_right_tag = mouse_position_tag
      else if mouse_position_tag[0] <= mouse_down_tag[0] and mouse_position_tag[1] <= mouse_down_tag[1] # dragging northwest
        box_top_left_tag  = mouse_position_tag
        box_bot_right_tag = mouse_down_tag
      else if mouse_position_tag[0] >  mouse_down_tag[0] and mouse_position_tag[1] <= mouse_down_tag[1] # dragging northeast
        box_top_left_tag  = [mouse_down_tag[0],     mouse_position_tag[1]]
        box_bot_right_tag = [mouse_position_tag[0], mouse_down_tag[1]    ]
      else if mouse_position_tag[0] <= mouse_down_tag[0] and mouse_position_tag[1] >  mouse_down_tag[1] # dragging southwest
        box_top_left_tag  = [mouse_position_tag[0], mouse_down_tag[1]    ]
        box_bot_right_tag = [mouse_down_tag[0],     mouse_position_tag[1]]

      if Alonzo.Utils.ancestry_starts_with(current_node.ancestry, down_node.ancestry)
        Alonzo.volatile_state.drag_select_box = {
          draw_it:                true
          ancestry:               down_node.ancestry
          top_left_parent_space:  down_node.convert_point_from_tag_space(box_top_left_tag )
          bot_right_parent_space: down_node.convert_point_from_tag_space(box_bot_right_tag)
        }
      else
        Alonzo.volatile_state.drag_select_box.draw_it = false
      Alonzo.render()
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_box_new_node
      mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)
      mouse_down_tag     = Alonzo.volatile_state.drag_background.mousedown_position
      down_node          = Alonzo.deepest_droptarget_node_at_this_point(Alonzo.volatile_state.drag_background.mousedown_position)
      current_node       = Alonzo.deepest_droptarget_node_at_this_point(mouse_position_tag)

      if      mouse_position_tag[0] >  mouse_down_tag[0] and mouse_position_tag[1] >  mouse_down_tag[1] # dragging southeast
        box_top_left_tag  = mouse_down_tag
        box_bot_right_tag = mouse_position_tag
      else if mouse_position_tag[0] <= mouse_down_tag[0] and mouse_position_tag[1] <= mouse_down_tag[1] # dragging northwest
        box_top_left_tag  = mouse_position_tag
        box_bot_right_tag = mouse_down_tag
      else if mouse_position_tag[0] >  mouse_down_tag[0] and mouse_position_tag[1] <= mouse_down_tag[1] # dragging northeast
        box_top_left_tag  = [mouse_down_tag[0],     mouse_position_tag[1]]
        box_bot_right_tag = [mouse_position_tag[0], mouse_down_tag[1]    ]
      else if mouse_position_tag[0] <= mouse_down_tag[0] and mouse_position_tag[1] >  mouse_down_tag[1] # dragging southwest
        box_top_left_tag  = [mouse_position_tag[0], mouse_down_tag[1]    ]
        box_bot_right_tag = [mouse_down_tag[0],     mouse_position_tag[1]]

      if Alonzo.Utils.ancestry_same(current_node.ancestry, down_node.ancestry)
        Alonzo.volatile_state.drag_new_node_box = {
          draw_it:                true
          ancestry:               down_node.ancestry
          top_left_parent_space:  down_node.convert_point_from_tag_space(box_top_left_tag )
          bot_right_parent_space: down_node.convert_point_from_tag_space(box_bot_right_tag)
        }
      else
        Alonzo.volatile_state.drag_new_node_box.draw_it = false
      Alonzo.render()
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_node_resizer
      # if the mouse is outside the parent of the resizing node, do nothing (not even render)
      # if the mouse is upper left from the location+minsize, do nothing (not even render)

      mouse_position_tag    = Alonzo.abs_to_rel(e.clientX, e.clientY)
      parent_ancestry       = Alonzo.Utils.list_most(Alonzo.volatile_state.node_resizer_data.ancestry)
      parent_node           = Alonzo.registry.get_node_by_ancestry(parent_ancestry)
      mouse_over_node       = Alonzo.deepest_droptarget_node_at_this_point(mouse_position_tag)
      resizing_node         = Alonzo.registry.get_node_by_ancestry(Alonzo.volatile_state.node_resizer_data.ancestry)
      aspect_ratio          = resizing_node.aspect_ratio()
      mouse_position_parent = parent_node.convert_point_from_tag_space(mouse_position_tag)
      resize_node_position  = resizing_node.position

      if mouse_over_node.is_parent_of(parent_node)
        return

      too_far_left = mouse_position_parent[0] < resize_node_position[0] + Alonzo.graphics_constants.minimum_node_width
      too_far_up   = mouse_position_parent[1] < resize_node_position[1] + Alonzo.graphics_constants.minimum_node_width / aspect_ratio
      if too_far_left or too_far_up
        return

      # this could get more general by putting a piece of data in each Node, and then even in the model data format
      resizing_scheme =
        if      resizing_node instanceof Bubble             then "free"
        else if resizing_node instanceof ResultNode         then "free"
        else if resizing_node instanceof RawInputNode       then "fixed height"
        else if resizing_node instanceof SmartInputNode     then "fixed height"
        else if resizing_node instanceof SetVariableNode    then "fixed height"
        else if resizing_node instanceof RefVariableNode    then "fixed height"
        else                                                     "fixed asrat"

      if resizing_scheme is "free"
        proposed_bottom_right = [mouse_position_parent[0], mouse_position_parent[1]]
        proposed_top_right    = [mouse_position_parent[0], resize_node_position[1] ]
        proposed_bottom_left  = [resize_node_position[0],  mouse_position_parent[1]]
      else if resizing_scheme is "fixed asrat"
        asrat_line         = (x) -> resize_node_position[1] + (x - resize_node_position[0]) / aspect_ratio
        asrat_line_inverse = (y) -> resize_node_position[0] + (y - resize_node_position[1]) * aspect_ratio

        if mouse_position_parent[1] > asrat_line(mouse_position_parent[0])
          # mouse is above aspect ratio line
          proposed_bottom_right = [mouse_position_parent[0],                     asrat_line(mouse_position_parent[0])]
          proposed_top_right    = [proposed_bottom_right[0],                     resize_node_position[1]             ]
          proposed_bottom_left  = [resize_node_position[0],                      proposed_bottom_right[1]            ]
        else
          # mouse is below aspect ratio line
          proposed_bottom_right = [asrat_line_inverse(mouse_position_parent[1]), mouse_position_parent[1]            ]
          proposed_top_right    = [proposed_bottom_right[0],                     resize_node_position[1]             ]
          proposed_bottom_left  = [resize_node_position[0],                      proposed_bottom_right[1]            ]
      else if resizing_scheme is "fixed height"
        proposed_bottom_right = [mouse_position_parent[0], resize_node_position[1] + resizing_node.height]
        proposed_top_right    = [mouse_position_parent[0], resize_node_position[1]                       ]
        proposed_bottom_left  = [resize_node_position[0],  resize_node_position[1] + resizing_node.height]
      else
        logger.error("unknown resizing_scheme #{resising_scheme}")

      for each_sibling in Alonzo.registry.sibling_nodes_of(resizing_node) when not (each_sibling instanceof Bubble)
        test1 = each_sibling.parent_point_is_inside_node(proposed_bottom_right)
        test2 = each_sibling.parent_point_is_inside_node(proposed_bottom_left)
        test3 = each_sibling.parent_point_is_inside_node(proposed_top_right)
        if test1 or test2 or test3
          return

      # at this point, the proposed new size is OK
      if resizing_node instanceof Bubble
        new_size = Alonzo.Utils.subtract_vectors(proposed_bottom_right, resize_node_position)
        Library.set_bubble_size(resizing_node.ancestry, new_size)
      else if resizing_node instanceof ResultNode
        new_size = Alonzo.Utils.subtract_vectors(proposed_bottom_right, resize_node_position)
        Library.set_result_size(parent_node.my_model.uuid, resizing_node.submodel_id, new_size)
      else
        new_width = proposed_bottom_right[0] - resize_node_position[0]
        Library.set_submodel_width(parent_node.my_model.uuid, resizing_node.submodel_id, new_width)

      Alonzo.render()

  onMouseUp = (e) ->
    e.preventDefault()
    e.stopPropagation()

    if Alonzo.volatile_state.paste_mode and (Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_background or Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_node)
      # paste
      mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)
      Alonzo.paste_click(mouse_position_tag)
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_node # click node
      clicked_node = Alonzo.registry.get_node_by_ancestry(Alonzo.volatile_state.drag_node.down_node_ancestry)
      Alonzo.clear_selection() unless e.ctrlKey
      if clicked_node.is_selected()
        clicked_node.remove_from_selection()
      else
        clicked_node.add_to_selection()
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_node_name # click node name
      console.log("click node name, ancestry " + Alonzo.volatile_state.drag_node.down_node_ancestry)
      clicked_node = Alonzo.registry.get_node_by_ancestry(Alonzo.volatile_state.drag_node.down_node_ancestry)
      if clicked_node.children_are_visible
        Alonzo.volatile_state.node_rename_text_box.draw_it  = true
        Alonzo.volatile_state.node_rename_text_box.ancestry = Alonzo.volatile_state.drag_node.down_node_ancestry
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_cp # click cp
      click_cp = Alonzo.registry.get_cp(
        Alonzo.volatile_state.drag_cp.down_cp.ancestry
        Alonzo.volatile_state.drag_cp.down_cp.argnum
        Alonzo.volatile_state.drag_cp.down_cp.type
      )
      Alonzo.clear_selection() unless e.ctrlKey
      if click_cp.is_selected()
        click_cp.remove_from_selection()
      else
        click_cp.add_to_selection()
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_link # click link
      [from_id, from_argnum, to_id, to_argnum] = Alonzo.volatile_state.drag_link.down_link_idargidarg
      clicked_link = Alonzo.registry.get_link(Alonzo.volatile_state.drag_link.down_link_ancestry, to_id, to_argnum)

      Alonzo.clear_selection() unless e.ctrlKey
      if clicked_link.is_selected()
        clicked_link.remove_from_selection()
      else
        clicked_link.add_to_selection()
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_node #done dragging node
      Library.flush_to_database()
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_background # click in background
      Alonzo.clear_selection()
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_cp #make new link
      mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)
      drop_cp = Alonzo.which_cp_is_at_this_point(mouse_position_tag)
      down_cp = Alonzo.registry.get_cp(
        Alonzo.volatile_state.drag_cp.down_cp.ancestry
        Alonzo.volatile_state.drag_cp.down_cp.argnum
        Alonzo.volatile_state.drag_cp.down_cp.type
      )
      if drop_cp #would be null if drop did not occur over a cp
        # make new link if legal
        sourcesink = Alonzo.can_link_between_these_cps(drop_cp, down_cp)
        if sourcesink
          # make new link
          [source_cp, sink_cp] = sourcesink
          # first delete existing link going to this sink, if one exists
          existing_link = Alonzo.registry.get_link(sink_cp.enclosing_node_if_sink.ancestry, sink_cp.id_if_sink, sink_cp.argnum)
          if existing_link? then existing_link.delete_self()
          # now add the new link
          Alonzo.make_new_link(source_cp, sink_cp)
          Library.flush_to_database()
        else
          console.log("can't make a link between those cps")
      else
        console.log("cancel creation of new link")
      Alonzo.volatile_state.drag_cp.dangling_link.draw_it = false
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_background # done dragging background
      console.log("done dragging background")
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_link # done dragging link
      null # do nothing
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_box_select
      mouse_position_tag = Alonzo.abs_to_rel(e.clientX, e.clientY)
      down_node    = Alonzo.deepest_droptarget_node_at_this_point(Alonzo.volatile_state.drag_background.mousedown_position)
      current_node = Alonzo.deepest_droptarget_node_at_this_point(mouse_position_tag)
      if Alonzo.Utils.ancestry_starts_with(current_node.ancestry, down_node.ancestry)
        for each_child in Alonzo.registry.child_nodes_of(down_node)
          [top_left_x,      top_left_y]      = each_child.top_left_parent_space()
          [bot_right_x,     bot_right_y]     = each_child.bot_right_parent_space()
          [box_top_left_x,  box_top_left_y]  = Alonzo.volatile_state.drag_select_box.top_left_parent_space
          [box_bot_right_x, box_bot_right_y] = Alonzo.volatile_state.drag_select_box.bot_right_parent_space
          cond1 = top_left_x  >= box_top_left_x
          cond2 = top_left_y  >= box_top_left_y
          cond3 = bot_right_x <= box_bot_right_x
          cond4 = bot_right_y <= box_bot_right_y
          if cond1 and cond2 and cond3 and cond4
            each_child.add_to_selection()
      Alonzo.volatile_state.drag_select_box.draw_it = false
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_box_new_node
      _drag_box_new_node(e)
      # Alonzo.render()
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.down_on_node_resizer
      # clicked node resizer
      console.log("clicked node resizer")
    else if Alonzo.volatile_state.mouse_state is Alonzo.volatile_state.mouse_states.dragging_node_resizer
      # done resizing node
      console.log("done resizing node")
      Library.flush_to_database()

    Alonzo.volatile_state.mouse_state = Alonzo.volatile_state.mouse_states.up
    Alonzo.render() #always have to rerender to get rid of the mouse overlay

  mouse_state = Alonzo.volatile_state.mouse_state
  should_exist =
    mouse_state is Alonzo.volatile_state.mouse_states.down_on_node           or
    mouse_state is Alonzo.volatile_state.mouse_states.down_on_node_name      or
    mouse_state is Alonzo.volatile_state.mouse_states.dragging_node          or
    mouse_state is Alonzo.volatile_state.mouse_states.down_on_background     or
    mouse_state is Alonzo.volatile_state.mouse_states.dragging_background    or
    mouse_state is Alonzo.volatile_state.mouse_states.dragging_box_select    or
    mouse_state is Alonzo.volatile_state.mouse_states.dragging_box_new_node  or
    mouse_state is Alonzo.volatile_state.mouse_states.down_on_cp             or
    mouse_state is Alonzo.volatile_state.mouse_states.dragging_cp            or
    mouse_state is Alonzo.volatile_state.mouse_states.down_on_link           or
    mouse_state is Alonzo.volatile_state.mouse_states.dragging_link          or
    mouse_state is Alonzo.volatile_state.mouse_states.down_on_node_resizer   or
    mouse_state is Alonzo.volatile_state.mouse_states.dragging_node_resizer

  if should_exist
    #this is a ReactSVGBase so that it gets the mouse wheel functionality
    <Alonzo.ReactSVGBase
      width       = "100%"
      height      = "100%"
      onMouseMove = {onMouseMove}
      onMouseUp   = {onMouseUp}
      key         = "mouseoverlay"
      style       = {position:"absolute", top:"0px", left:"0px"}
    >
      {#this is for debugging, for release, it (and the entire rect) could be removed}
      <rect
        key         = "mouseoverlayindicator"
        x           = 0
        y           = 0
        width       = "100%"
        height      = "100%"
        fill        = "red"
        fillOpacity = 0.0
      ></rect>
    </Alonzo.ReactSVGBase>
  else
    null
