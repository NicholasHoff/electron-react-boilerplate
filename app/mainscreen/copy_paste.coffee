Alonzo.copy_command = () ->
  console.log("copy_command")
  selected_nodes = Alonzo.volatile_state.selected_nodes
  if selected_nodes.length == 0
    console.log("tried to invoke copy command, but there were no nodes selected")
    return

  for each in selected_nodes
    if each.parent_uuid isnt selected_nodes[0].parent_uuid
      Alonzo.set_footer_message("you can only copy nodes which are siblings")
      return

  Alonzo.volatile_state.clipboard.submodels = []
  Alonzo.volatile_state.clipboard.links     = []

  for each in selected_nodes
    this_submodel_datastructure = Library.get_submodel_datastructure(each.parent_uuid, each.submodel_id)
    clone = Alonzo.Utils.json_clone(this_submodel_datastructure)
    Alonzo.volatile_state.clipboard.submodels = Alonzo.Utils.list_append(Alonzo.volatile_state.clipboard.submodels, clone)

  all_links = Library.get_model_for_uuid(selected_nodes[0].parent_uuid).links
  all_selected_submodel_ids = (x.submodel_id for x in Alonzo.volatile_state.clipboard.submodels)
  for each_link in all_links
    from_id     = each_link[0]
    from_argnum = each_link[1]
    to_id       = each_link[2]
    to_argnum   = each_link[3]

    # only select links which come from a selected submodel and go to a selected submodel
    if from_id in all_selected_submodel_ids and to_id in all_selected_submodel_ids
      clone = Alonzo.Utils.json_clone(each_link)
      Alonzo.volatile_state.clipboard.links = Alonzo.Utils.list_append(Alonzo.volatile_state.clipboard.links, clone)

Alonzo.paste_command = () ->
  console.log("paste_command")
  if Alonzo.volatile_state.clipboard.submodels.length is 0
    Alonzo.set_footer_message("you tried to paste, but nothing was copied")
    return

  Alonzo.set_footer_message("now click where you want to paste")
  Alonzo.volatile_state.paste_mode = true
  Alonzo.render()

Alonzo.paste_click = (tagspace_click) ->
  console.log("paste_click")
  if Alonzo.volatile_state.clipboard.submodels.length is 0
    console.error("tried to paste, but nothing was on the clipboard")
    return

  [tagspace_x, tagspace_y] = tagspace_click

  # find which node I'm pasting into
  pastetarget_node = Alonzo.deepest_droptarget_node_at_this_point(tagspace_click)
  internal_paste_point = pastetarget_node.convert_point_from_tag_space(tagspace_click)

  old_submodel_ids = (x.submodel_id for x in Alonzo.volatile_state.clipboard.submodels)

  # calculate bounding box of all copied nodes
  bbox_ulx =  Number.MAX_VALUE
  bbox_uly =  Number.MAX_VALUE
  bbox_lrx = -Number.MAX_VALUE
  bbox_lry = -Number.MAX_VALUE
  for each_submodel in Alonzo.volatile_state.clipboard.submodels
    position = each_submodel.position
    ulx = position[0]
    uly = position[1]
    lrx = ulx + each_submodel.width
    lry = position[1] #should add height

    bbox_ulx = Math.min(bbox_ulx, ulx)
    bbox_uly = Math.min(bbox_uly, uly)
    bbox_lrx = Math.max(bbox_lrx, lrx)
    bbox_lry = Math.max(bbox_lry, lry)
  bbox_center = [(bbox_lrx + bbox_ulx)/2, (bbox_lry + bbox_uly)/2]

  # add bounding box offset to each copied node
  for each_submodel in Alonzo.volatile_state.clipboard.submodels
    each_submodel.tmp_offset_for_copy_paste = Alonzo.Utils.subtract_vectors(each_submodel.position, bbox_center)

  # create the new links and submodels - cloned, renumbered, and repositioned
  new_links = Alonzo.Utils.json_clone(Alonzo.volatile_state.clipboard.links)
  new_submodels =
    for submodel in Alonzo.volatile_state.clipboard.submodels
      new_submodel_id = Alonzo.Utils.random_new_submodel_id()
      old_submodel_id = submodel.submodel_id

      new_submodel = Alonzo.Utils.json_clone(submodel)
      new_submodel.submodel_id = new_submodel_id
      new_submodel.position = Alonzo.Utils.add_vectors(internal_paste_point, new_submodel.tmp_offset_for_copy_paste)
      delete new_submodel.tmp_offset_for_copy_paste

      new_links =
        for each_link in new_links
          from_id     = each_link[0]
          from_argnum = each_link[1]
          to_id       = each_link[2]
          to_argnum   = each_link[3]

          new_from_id = if from_id is old_submodel_id then new_submodel_id else from_id
          new_to_id   = if to_id   is old_submodel_id then new_submodel_id else to_id

          [new_from_id, from_argnum, new_to_id, to_argnum]

      new_submodel

  # and now actually insert the new submodels and links into the target model
  pastetarget_node_uuid = pastetarget_node.my_model.uuid
  Library.add_submodel_to_model(pastetarget_node_uuid, x, false) for x in new_submodels
  Library.add_link_to_model(pastetarget_node_uuid, x[0], x[1], x[2], x[3], false) for x in new_links

  # finish
  Alonzo.volatile_state.paste_mode = false
  Library.flush_to_database()
  #don'r render because the mouse overlay onMouseUp(.) will do that
