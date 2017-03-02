fs = require('fs')

export default class DiskIO
  # overwrites the whole file with whatever is passed in
  @write_models: (models) ->
      fs.writeFileSync(Alonzo.file_paths.user_blocks, JSON.stringify(models, null, 2))

  # overwrites the whole file with whatever is passed in
  @write_diagrams: (diagrams) ->
      fs.writeFileSync(Alonzo.file_paths.diagrams, JSON.stringify(diagrams, null, 2))
