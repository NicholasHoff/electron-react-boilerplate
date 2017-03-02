import {ConnectionPort} from './ConnectionPort.coffee'

Alonzo.reset_registry = () ->
  Alonzo.registry = {
    all_nodes:  []
    all_cps:    []
    all_links:  []

    # keeping track of and finding nodes (including bubbles)
    # ==================================
    regsiter_node: (new_node) ->
      Alonzo.registry.all_nodes = [Alonzo.registry.all_nodes..., new_node]

    get_node_by_ancestry: (ancestry) ->
      (x for x in Alonzo.registry.all_nodes when Alonzo.Utils.ancestry_same(x.ancestry, ancestry))[0]

    parent_node_of: (child_node) ->
      Alonzo.registry.get_node_by_ancestry(Alonzo.Utils.list_most(child_node.ancestry))

    descendants_of: (parent_node) ->
      (x for x in Alonzo.registry.all_nodes when (Alonzo.Utils.ancestry_starts_with(x.ancestry, parent_node.ancestry) and x isnt parent_node))

    child_nodes_of: (parent_node) ->
      (x for x in Alonzo.registry.descendants_of(parent_node) when x.ancestry.length == parent_node.ancestry.length + 1)

    sibling_nodes_of: (the_node) ->
      including_self = Alonzo.registry.child_nodes_of(Alonzo.registry.parent_node_of(the_node))
      (x for x in including_self when not Alonzo.Utils.ancestry_same(x.ancestry, the_node.ancestry))

    # keeping track of and finding CPs
    #========================================
    regsiter_cp: (new_cp) ->
      Alonzo.registry.all_cps = [Alonzo.registry.all_cps..., new_cp]

    get_input_cp: (ancestry, argnum) ->
      (cp for cp in Alonzo.registry.all_cps when (
        (cp.type is ConnectionPort.types.input) and
        (Alonzo.Utils.ancestry_same(cp.my_node.ancestry, ancestry)) and
        (cp.argnum is argnum)))[0]

    get_output_cp: (ancestry, argnum) ->
      (cp for cp in Alonzo.registry.all_cps when (
        (cp.type is ConnectionPort.types.output) and
        (Alonzo.Utils.ancestry_same(cp.my_node.ancestry, ancestry)) and
        (cp.argnum is argnum)))[0]

    get_cp: (ancestry, argnum, type) ->
      if      type is ConnectionPort.types.input
        Alonzo.registry.get_input_cp( ancestry, argnum)
      else if type is ConnectionPort.types.output
        Alonzo.registry.get_output_cp(ancestry, argnum)
      else
        console.error("unkown cp type #{type}")

    # keeping track of and finding links
    #========================================
    register_link: (new_link) ->
      Alonzo.registry.all_links.push(new_link)

    get_link: (ancestry, to_id, to_argnum) ->
      (x for x in Alonzo.registry.all_links when (
        x.to_id_arg()[0] is to_id     and
        x.to_id_arg()[1] is to_argnum and
        Alonzo.Utils.ancestry_same(ancestry, x.my_node.ancestry)
      ))[0]

    # ancestry of the enclosing node
    get_links_by_ancestry: (ancestry) ->
      (x for x in Alonzo.registry.all_links when Alonzo.Utils.ancestry_same(x.my_node.ancestry, ancestry))
  }
