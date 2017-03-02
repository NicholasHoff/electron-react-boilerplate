fs = require('fs')
import DiskIO from './DiskIO.coffee'

class Library
  @clearLibrary: () ->
    # these are only referenced in class Library
    Alonzo._all_models   = []
    Alonzo._all_diagrams = []

  @loadModelsFromFile: (filePath, callback) ->
    fs.readFile(filePath, (err, data) ->
      if err
        console.log(err)
        return
      Alonzo._all_models = Alonzo._all_models.concat(JSON.parse(data))
      callback()
    )

  @loadDiagramsFromFile: (filePath, callback) ->
    fs.readFile(filePath, (err, data) ->
      if err
        console.log(err)
        return
      Alonzo._all_diagrams = Alonzo._all_diagrams.concat(JSON.parse(data))
      callback()
    )

  @set_all_models_to: (new_models) ->
    Alonzo._all_models = new_models

  @set_all_diagrams_to: (new_diagrams) ->
    Alonzo._all_diagrams = new_diagrams

  # this is only needed for when you want to delete a bubble
  @_set_bubbles_to: (new_bubbles) ->
    Library.get_current_diagram().bubbles = new_bubbles

  # sending accumulated changes to database
  # ---------------------------------
  # Whenever a change is written to a model or diagram using functions
  # in the Library (which is the only way such changes should be made),
  # that function will add the uuid of the changed node to the list.
  # At an appropriate time (like the mouseup of a drag operation), the
  # flush function will be called, which will write all accumulated changes
  # out to the database.  It needs to be done this way, instead of writing
  # changes to the database each time, because sometimes lots of changes
  # get made before they are final.
  @_changed_model_uuids: []
  @_diagram_has_changed: false
  @flush_to_database: () ->
    console.log("writing all changes to files")
    if Library._changed_model_uuids.length > 0
      DiskIO.write_models(x for x in Alonzo._all_models when x.MM_builtin is false)
    if Library._diagram_has_changed
      DiskIO.write_diagrams(Alonzo._all_diagrams)
    Library._changed_model_uuids = []
    Library._diagram_has_changed = false

  @model_has_changed: (uuid) ->
    if uuid not in Library._changed_model_uuids
      Library._changed_model_uuids.push(uuid)

  # models
  # ------------------
  @get_all_models: () ->
    Alonzo._all_models

  @get_model_for_uuid: (uuid) ->
    (m for m in Alonzo._all_models when m.uuid is uuid)[0]

  @create_new_model: (model_datastructure) ->
    Alonzo._all_models.push(model_datastructure)
    Library.model_has_changed(model_datastructure.uuid)

  @get_model_uuid_for_ancestry: (ancestry) ->
    doit = (relative_ancestry, model_uuid_relative_to) ->
      if relative_ancestry.length is 0
        model_uuid_relative_to
      else
        next_submodel_id = relative_ancestry[0]
        next_model_uuid  = Library.get_submodel_datastructure(model_uuid_relative_to, next_submodel_id).uuid
        doit(Alonzo.Utils.list_rest(relative_ancestry), next_model_uuid)

    doit(ancestry, @get_uuid_of_current_top_level_model())

  @set_model_default_arity: (uuid, new_arity) ->
    Library.get_model_for_uuid(uuid).default_arity = new_arity
    Library.model_has_changed(uuid)

  @set_model_default_coarity: (uuid, new_coarity) ->
    Library.get_model_for_uuid(uuid).default_coarity = new_coarity
    Library.model_has_changed(uuid)

  @set_model_name: (uuid, new_name) ->
    model_datastructure = Library.get_model_for_uuid(uuid)
    if not model_datastructure.name?
      console.warn("trying to set name #{new_name} for model #{uuid}, but there was no name previously set")
      return
    model_datastructure.name = new_name
    Library.model_has_changed(uuid)

  # if labels are not specified in the model, null is returned
  # not valid for argnums above the default arity
  @get_input_label_for_model: (uuid, argnum) ->
    labels = Library.get_model_for_uuid(uuid).labels
    if labels?
      labels[0][argnum-1]
    else
      null

  @get_output_label_for_model: (uuid, argnum) ->
    labels = Library.get_model_for_uuid(uuid).labels
    if labels?
      labels[1][argnum-1]
    else
      null

  @set_model_internal_space: (uuid, new_width, new_height) ->
    model = Library.get_model_for_uuid(uuid)
    if not model.composite
      console.warn("tried to set_model_internal_space for a non-composite model")
      return
    if model.diagram
      console.warn("tried to set_model_internal_space for a diagram")
      return
    model.size = [new_width, new_height]
    Library.model_has_changed(uuid)

  # submodels
  # -------------------
  # performance could be improved by passing in model directly instead of uuid
  #here, position is [x, y]
  @add_submodel_to_model: (model_uuid_to_add_to, new_submodel_datastructure, write_to_database = true) ->
    Library.get_model_for_uuid(model_uuid_to_add_to).submodels.push(new_submodel_datastructure)
    Library.model_has_changed(model_uuid_to_add_to)

  # does not touch links
  @remove_submodel_from_model: (model_uuid_to_remove_from, submodel_id_to_remove, write_to_database = true) ->
    model = Library.get_model_for_uuid(model_uuid_to_remove_from)
    model.submodels = (x for x in model.submodels when x.submodel_id isnt submodel_id_to_remove)
    Library.model_has_changed(model_uuid_to_remove_from)

  # returns the whole thing, possibly including variable arity stuff, singleton input stuff, loop stuff, etc
  # used when moving a node from on parent to another
  @get_submodel_datastructure: (model_uuid, submodel_id) ->
    model = Library.get_model_for_uuid(model_uuid)
    (x for x in model.submodels when x.submodel_id is submodel_id)[0]

  # model_uuid is the uuid of the model containing the singleton you want to change
  @set_singleton_input_value: (model_uuid, submodel_id, new_value) ->
    sub = Library.get_submodel_datastructure(model_uuid, submodel_id)
    sub.singleton_input.value = new_value
    Library.model_has_changed(model_uuid)

  # model_uuid is the uuid of the model containing the codenode you want to change
  @set_codenode_contents: (model_uuid, submodel_id, new_value) ->
    sub = Library.get_submodel_datastructure(model_uuid, submodel_id)
    sub.contents = new_value
    #Library.model_has_changed(model_uuid)

  # model_uuid is the uuid of the model containing the variable you want to change
  @set_variable_value: (model_uuid, submodel_id, new_value) ->
    sub = Library.get_submodel_datastructure(model_uuid, submodel_id)
    submodel_type = sub.submodel_type
    if submodel_type isnt "set_variable" and submodel_type isnt "ref_variable"
      console.error("trying to set submodel_id " + submodel_id + " in model " + model_uuid + " to variable name " + new_value + ", but it isn't a variable submodel")
      return
    sub.variable_name = new_value
    Library.model_has_changed(model_uuid)

  @set_result_density: (model_uuid, submodel_id, new_value) ->
    sub = Library.get_submodel_datastructure(model_uuid, submodel_id)
    sub.density = new_value
    Library.model_has_changed(model_uuid)

  @set_result_size: (model_uuid, submodel_id, new_size) ->
    new_width  = new_size[0]
    new_height = new_size[1]
    sub = Library.get_submodel_datastructure(model_uuid, submodel_id)
    sub.width  = new_width
    sub.height = new_height
    Library.model_has_changed(model_uuid)

  @set_submodel_position: (model_uuid, submodel_id, new_position) ->
    submodel = Library.get_submodel_datastructure(model_uuid, submodel_id)
    submodel.position = new_position
    Library.model_has_changed(model_uuid)

  @set_submodel_width: (model_uuid, submodel_id, new_width) ->
    submodel = Library.get_submodel_datastructure(model_uuid, submodel_id)
    submodel.width = new_width
    Library.model_has_changed(model_uuid)

  # model_uuid of the model containing the submodel whose override_arity is being changed
  # if new_value is equal to the default arity of the submodels's model, it will remove override_arity
  # new_value can be null, in which case it removes the override_arity
  @set_submodel_override_arity: (model_uuid, submodel_id, new_value) ->
    parent_model    = Library.get_model_for_uuid(model_uuid)
    submodel_data   = Library.get_submodel_datastructure(model_uuid, submodel_id)
    submodels_model = Library.get_model_for_uuid(submodel_data.uuid)
    if not submodels_model.variable_arity
      console.error("tried to set override_arity on a submodel whose model is not variable_arity")
    else
      if new_value?
        if new_value == submodels_model.default_arity
          delete submodel_data.override_arity
        else
          submodel_data.override_arity = new_value
      else
        delete submodel_data.override_arity
      Library.model_has_changed(model_uuid)

  @set_submodel_override_coarity: (model_uuid, submodel_id, new_value) ->
    parent_model    = Library.get_model_for_uuid(model_uuid)
    submodel_data   = Library.get_submodel_datastructure(model_uuid, submodel_id)
    submodels_model = Library.get_model_for_uuid(submodel_data.uuid)
    if not submodels_model.variable_coarity
      console.error("tried to set override_coarity on a submodel whose model is not variable_coarity")
    else
      if new_value?
        if new_value == submodels_model.default_coarity
          delete submodel_data.override_coarity
        else
          submodel_data.override_coarity = new_value
      else
        delete submodel_data.override_coarity
      Library.model_has_changed(model_uuid)

  # null if none set
  @get_submodel_sugared_maps: (model_uuid, submodel_id) ->
    submodel_data   = Library.get_submodel_datastructure(model_uuid, submodel_id)
    raw_maps = submodel_data.sugared_map
    if raw_maps? then raw_maps else null

  # set to null to indicate none set
  @set_submodel_sugared_maps: (model_uuid, submodel_id, maps) ->
    submodel_data   = Library.get_submodel_datastructure(model_uuid, submodel_id)
    submodel_data.sugared_map = maps
    if submodel_data.sugared_map is null then delete submodel_data.sugared_map
    Library.model_has_changed(model_uuid)

  # diagram
  # -------------------
  @get_all_diagrams: () ->
    Alonzo._all_diagrams

  @get_current_diagram: () ->
    diagram_uuid = Alonzo.volatile_state.current_diagram_uuid
    theone = (x for x in Alonzo._all_diagrams when x.uuid is diagram_uuid)
    if theone.length is 0
      console.error("did not find diagram uuid #{diagram_uuid}")
    else if theone.length isnt 1
      console.error("more than one diagram with uuid #{diagram_uuid}")
    else
      theone[0]

  @set_name_of_current_diagram: (new_name) ->
    Library.get_current_diagram().name = new_name
    Library._diagram_has_changed = true

  @get_uuid_of_current_top_level_model: () ->
    Library.get_current_diagram().tlm_uuid

  # links
  # -------------------
  @add_link_to_model: (model_uuid_to_add_to, from_id, from_argnum, to_id, to_argnum, write_to_database = true) ->
    model_to_add_to = Library.get_model_for_uuid(model_uuid_to_add_to)
    submodel_ids = (x.submodel_id for x in model_to_add_to.submodels)
    if (from_id in submodel_ids or from_id is 0) and (to_id in submodel_ids or to_id is 0)
      model_to_add_to.links.push([
        from_id
        from_argnum
        to_id
        to_argnum
      ])
      Library.model_has_changed(model_uuid_to_add_to)
    else
      console.log("error, tried to add bad link")

  @remove_link_from_model: (model_uuid_to_remove_from, from_id, from_argnum, to_id, to_argnum, write_to_database = true) ->
    model = Library.get_model_for_uuid(model_uuid_to_remove_from)
    model.links = (x for x in model.links when not Alonzo.Utils.lists_same(
      x
      [from_id, from_argnum, to_id, to_argnum]
    ))
    Library.model_has_changed(model_uuid_to_remove_from)

  # bubble data
  # -------------------
  @all_bubbles: () -> Library.get_current_diagram().bubbles

  # ancestry is the ancestry of the bubble, position is inside its parent's space
  # from_idarg is [from_id, from_argnum] and is alowed to be null
  @add_bubble: (ancestry, position, size, from_idarg, density=0.5) ->
    Library.get_current_diagram().bubbles.push({
      ancestry:  ancestry
      source:    from_idarg
      position:  position
      size:       size
      density:    density
    })
    Library._diagram_has_changed = true

  @remove_bubble: (ancestry) ->
    @_set_bubbles_to(each for each in Library.get_current_diagram().bubbles when not Alonzo.Utils.ancestry_same(each.ancestry, ancestry))
    Library._diagram_has_changed = true

  # given the ancestry of a parent, return all child bubbles of that node
  @get_bubbles_by_parent_ancestry: (parent_ancestry) ->
    each_data for each_data in Library.get_current_diagram().bubbles when (
      Alonzo.Utils.ancestry_same(Alonzo.Utils.list_most(each_data.ancestry), parent_ancestry))

  # given the ancestry of a node, return all descendant bubbles of that node
  @get_bubbles_by_ancestor_ancestry: (parent_ancestry) ->
    each_data for each_data in Library.get_current_diagram().bubbles when (
      Alonzo.Utils.ancestry_starts_with(each_data.ancestry, parent_ancestry))

  # given the ancestry of a bubble, return the bubble
  @get_bubble_by_ancestry: (ancestry) ->
    (each_data for each_data in Library.get_current_diagram().bubbles when (
      Alonzo.Utils.ancestry_same(                       each_data.ancestry,  ancestry)      ))[0]

  @set_bubble_position: (ancestry, new_position) ->
    Library.get_bubble_by_ancestry(ancestry).position = new_position
    Library._diagram_has_changed = true

  @set_bubble_size: (ancestry, new_size) ->
    Library.get_bubble_by_ancestry(ancestry).size = new_size
    Library._diagram_has_changed = true

  @set_bubble_density: (ancestry, new_density) ->
    Library.get_bubble_by_ancestry(ancestry).density = new_density
    Library._diagram_has_changed = true

  @set_source_for_bubble: (ancestry, new_source) ->
    if new_source is null
      console.warn("to delete a bubble link, please use remove_source_from_bubble(.)")
    Library.get_bubble_by_ancestry(ancestry).source = new_source
    Library._diagram_has_changed = true

  @remove_source_from_bubble: (ancestry) ->
    bubble = Library.get_bubble_by_ancestry(ancestry)
    if bubble?
      bubble.source = null
      Library._diagram_has_changed = true

Alonzo.Library = Library

export default Library
