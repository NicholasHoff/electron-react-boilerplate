Alonzo.compileDiagram = () ->
  # compiledWLCode = (new BlockCompiler(Library.get_uuid_of_current_top_level_model())).compile()
  compiledWLCode = (new Compiler()).compileDiagram()
  fs.writeFileSync("./test_MM_compile.txt",compiledWLCode)

  spawn = child_process.spawn;
  console.log("about to spawn MM process")
  # mm = spawn('math', ['-noprompt', '-initfile', './test_MM_compile.txt']);
  mm = spawn('wolfram', ['-script', './test_MM_compile.txt']);

  mm.stdout.on('data', (data) =>
    console.log("MM stdout: #{data}")
  )

  mm.stderr.on('data', (data) =>
    console.log("MM stderr: #{data}");
  )

  mm.on('close', (code) =>
    console.log("child process exited with code #{code}");
    if code is 0
      StoredResults.load_results_from_file("/home/nhoff/visx_tmp_results/results.json")
      Alonzo.render()
    else
      console.log("not rendering because return code from Mathematica was not 0")
  )

class Compiler
  @implicitVariableMangle = "var"
  @resultsTmpMangle       = "resultsTmp"
  @saveResultMangle       = "saveResult"
  @ansMangle              = "ans"
  #FIXME put in the rest of these

  constructor: () ->
    @blocksToCompile        = []   # these are lists of model uuids
    @blocksToCompileWithMap = []
    @compiledWLCode         = ""

  compileDiagram: () ->
    header =
      "Remove[\"Global`*\"]\n" +
      "results=<||>;\n" +
      "stack={};\n" +
      "saveResult[submodelID_Integer,value_]:=Module[{},\n" +
      "  results[Prepend[stack, stackFrame[submodelID,0]]]=value;\n" +
      "];\n"
    footer = "block[\"#{Library.get_uuid_of_current_top_level_model()}\",0][]\n"
    postprocessor = fs.readFileSync("./MM_postprocessor.m")
    header + @compileBlocks() + footer + postprocessor + "\nExit[]\n"

  # compiles the current diagram
  compileBlocks: () ->
    @_calculateDependencies()
    for model_uuid in @blocksToCompile
      @compiledWLCode += (new BlockCompiler(model_uuid, false)).compile()
    for model_uuid in @blocksToCompileWithMap
      @compiledWLCode += (new BlockCompiler(model_uuid, true)).compile()
    @compiledWLCode

  # fills in blocksToCompile and blocksToCompileWithMap
  _calculateDependencies: () ->
      includeChildrenOf = (parent_model) =>
        for s in parent_model.submodels when s.submodel_type is "model"
          submodel_model = Library.get_model_for_uuid(s.uuid)
          if submodel_model.composite
            if Alonzo.submodel_has_sugared_map_Q(s)
              @blocksToCompileWithMap.push(s.uuid)
            else
              @blocksToCompile.push(s.uuid)
            includeChildrenOf(submodel_model)

      @blocksToCompile.push(Library.get_uuid_of_current_top_level_model())
      includeChildrenOf(Library.get_model_for_uuid(Library.get_uuid_of_current_top_level_model()))

class BlockCompiler
  constructor: (@model_uuid, @sugared_map = false) ->
    @splitLocations  = []   # [submodel_id, submodel_id, ...], only the ones where there are splits
    @evaluationOrder = []   # [submodel_id, submodel_id, ...]
    @compiledWLCode  = ""
    @model           = Library.get_model_for_uuid(@model_uuid)

  compile: () ->
    @splitLocations          = @findSplitLocations()
    @splitsAlreadyCalculated = []
    @evaluationOrder         = BlockCompiler.calculateEvaluationOrder(@model)
    @submodelDatastructures  = {}   # {submodel_id: (that submodel datastructure)}

    for submodel in @model.submodels
      @submodelDatastructures[submodel.submodel_id] = submodel

    # header
    @compiledWLCode += "block[\"#{@model_uuid}\",idInParent_Integer#{if @sugared_map then ",sugaredMap" else ""}]:=Module[{#{Compiler.implicitVariableMangle},#{Compiler.resultsTmpMangle},#{Compiler.ansMangle}},\n"
    if @sugared_map
      @compiledWLCode += "Function[{arg1,arg2},\n"
    else
      @compiledWLCode += "Function[{#{("ans"+x for x in Alonzo.Utils.range_1_to(@model.default_arity)).join(',')}},\n"

    # push stack
    if @sugared_map
      @compiledWLCode += "stack=Prepend[stack,stackFrame[idInParent,First@arg2]];\n"
    else
      @compiledWLCode += "stack=Prepend[stack,stackFrame[idInParent,0]];\n"

    # main body
    for desiredSubblock in @evaluationOrder
      submodelDatastructure = @submodelDatastructures[desiredSubblock]
      connectiveOrder = @calculateConnectiveOrder(desiredSubblock)
      connectiveOrderList = ([parseInt(k),v] for k,v of connectiveOrder) #need the parseInt because "k,v of" pulls out keys as strings
      subblocksInOrder = (x[0] for x in connectiveOrderList.sort((a,b)->(b[1]-a[1]))) # list of submodel ids in order of connective dependency
      # first calculate splits
      for submodel_id in subblocksInOrder
        if submodel_id in @splitLocations and submodel_id not in @splitsAlreadyCalculated
          @compiledWLCode += "#{Compiler.implicitVariableMangle}[#{submodel_id}]=#{@compileWLExpressionForSource(submodel_id, 1)};\n"
          @splitsAlreadyCalculated = [@splitsAlreadyCalculated..., submodel_id]
      # then the actual desired block
      if submodelDatastructure.submodel_type is "set_variable"
          @compiledWLCode += "#{submodelDatastructure.variable_name}=#{@compileWLExpressionForSink(desiredSubblock, 1)};\n"
      else if submodelDatastructure.submodel_type is "result"
          @compiledWLCode += "#{Compiler.resultsTmpMangle}[#{submodelDatastructure.submodel_id}]=#{@compileWLExpressionForSink(desiredSubblock, 1)};\n"
          @compiledWLCode += "#{Compiler.saveResultMangle}[#{submodelDatastructure.submodel_id},#{Compiler.resultsTmpMangle}[#{submodelDatastructure.submodel_id}]];\n"
    # now the final result
    if @thisBlockReturnsValueQ()
      @compiledWLCode += "#{Compiler.ansMangle}=#{@compileWLExpressionForSink(0, 1)};\n"

    # pop stack
    @compiledWLCode += "stack=Rest[stack];\n"

    # return value
    if @thisBlockReturnsValueQ()
      @compiledWLCode += "#{Compiler.ansMangle}\n"

    # footer
    @compiledWLCode += "]\n];\n"

    @compiledWLCode

  # stopping at block inputs, singletons, set_variables, splits
  compileWLExpressionForSource: (submodel_id, argnum) ->
    submodelDatastructure = @submodelDatastructures[submodel_id]

    if submodel_id is 0
      "arg#{argnum}"
    else
      # check if it's a split
      if submodel_id in @splitLocations and submodel_id in @splitsAlreadyCalculated #that second clause prevents var[3]=var[3]
        "#{Compiler.implicitVariableMangle}[#{submodel_id}]"
      else #it's not a split
        if submodelDatastructure.submodel_type is "singleton"
          if submodelDatastructure.singleton_input.type is "raw"
            submodelDatastructure.singleton_input.value
          else if submodelDatastructure.singleton_input.type is "semantic_interpretation"
            "SemanticInterpretation[" + submodelDatastructure.singleton_input.value + "]"
        else if submodelDatastructure.submodel_type is "ref_variable"
          submodelDatastructure.variable_name
        else
          # it's not a split and it's not a terminal
          if submodelDatastructure.submodel_type isnt "model" then console.error("compiling, but hit something other than a model")
          thisSubmodelsModel = Library.get_model_for_uuid(submodelDatastructure.uuid)
          if thisSubmodelsModel.MM_builtin
            if Alonzo.submodel_has_sugared_map_Q(submodelDatastructure)
              # it's a builtin model with a sugared map on it
              "Map[#{thisSubmodelsModel.MM_name},#{@compileArgumentSequence(submodel_id)}]"
            else
              # it's a builtin model without a sugared map on it
              "#{thisSubmodelsModel.MM_name}[#{@compileArgumentSequence(submodel_id)}]"
          else
            if Alonzo.submodel_has_sugared_map_Q(submodelDatastructure)
              # it's a non-builtin model with a sugared map on it
              "MapIndexed[block[\"#{thisSubmodelsModel.uuid}\",#{submodel_id},sugaredMap],#{@compileArgumentSequence(submodel_id)}]"
            else
              # it's a non-builtin model without a sugared map on it
              "block[\"#{thisSubmodelsModel.uuid}\",#{submodel_id}][#{@compileArgumentSequence(submodel_id)}]"

  compileWLExpressionForSink: (submodel_id, argnum) ->
    #find link that feeds it
    #compileWLExpressionForSource(that source)
    feeder = @findSourceThatFeedsSink(submodel_id, argnum)
    if feeder?
      @compileWLExpressionForSource(feeder...)
    else
      undefined

  # if the expression for a block were A[a,b,c], this would return the "a,b,c" part
  compileArgumentSequence: (submodel_id) ->
    [arity, coarity] = Alonzo.get_submodel_arity_coarity(@submodelDatastructures[submodel_id])
    allInputs = (@compileWLExpressionForSink(submodel_id, input_argnum) for input_argnum in Alonzo.Utils.range_1_to(arity))
    allFilledInputs = (x for x in allInputs when x?)
    allFilledInputs.join(',')

  # returns a list of submodel_ids out of which more than one link comes
  findSplitLocations: () ->
    numberOfOutputLinks = {}   # {submodel_id: int, ...}
    for [from_id, from_argnum, to_id, to_argnum] in @model.links when from_id isnt 0
      numberOfOutputLinks[from_id] = (numberOfOutputLinks[from_id]? or 0) + 1

    parseInt(k,10) for k,v of numberOfOutputLinks when numberOfOutputLinks[k] > 1 # the "k,v of" thing pulls out the keys as strings, hence the parseInt

  # finds results and variables, left-to-right, returns a list of submodel ids, not including the final output
  @calculateEvaluationOrder: (model) ->
    thing = ([submodel.submodel_id, submodel.position[0]] for submodel in model.submodels when submodel.submodel_type is "set_variable" or submodel.submodel_type is "result")
    x[0] for x in thing.sort((a,b)->(a[1]-b[1]))

  # {submodel_id: connective order, ...}
  calculateConnectiveOrder: (starting_submodel_id) ->
    connectiveOrder = {}
    doit = (submodel_id, current_order) =>
      connectiveOrder[submodel_id] = Math.max(connectiveOrder[submodel_id]? or 0, current_order)
      for feeder_submodel_id in @blocksThatDirectlyFeed(submodel_id) when feeder_submodel_id isnt 0
        doit(feeder_submodel_id, current_order+1)
    doit(starting_submodel_id, 0)
    connectiveOrder

  # returns the list of submodel ids of submodels that feed the given submodel
  blocksThatDirectlyFeed: (submodel_id) ->
    hits = []
    for [from_id, from_argnum, to_id, to_argnum] in @model.links
      if to_id == submodel_id
        hits = [hits..., from_id]
    hits

  # returns [from_id, from_argnum]
  findSourceThatFeedsSink: (to_id, to_argnum) ->
    for [from_id, from_argnum, x, y] in @model.links
      if x is to_id and y is to_argnum
        return [from_id, from_argnum]
    console.log("tried to find source that feeds #{to_id}, #{to_argnum}, but there is no such link")
    return undefined

  thisBlockReturnsValueQ: () ->
    @model.composite and not @model.diagram and @findSourceThatFeedsSink(0,1)?

export {Compiler, BlockCompiler}
