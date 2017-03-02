export default class StoredErrors
  @_stored_errors: []

  @clear: () ->
    @_stored_errors = []

  # the ancestry of the node to which the CP of interest is attached
  # and the type (input or output) of that CP
  # and the argnum of that CP
  # returns either null or an error message
  @lookup_cp_error: (ancestry, type, argnum) ->
    result = (stored_error for stored_error in @_stored_errors when (
      Alonzo.Utils.ancestry_same(stored_error.ancestry, ancestry) and
      (
        ((stored_error.input_or_output is "input" ) and (type is ConnectionPort.types.input )) or
        ((stored_error.input_or_output is "output") and (type is ConnectionPort.types.output))
      ) and
      (stored_error.argnum is argnum)
    ))

    if result.length == 0
      null
    else
      result[0].message

  # the format of this datastructure is described in the format documentation, for example format_04.txt
  @store_error: (datastructure) ->
    @_stored_errors.push(datastructure)
