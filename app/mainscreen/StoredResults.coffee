export default class StoredResults
  @_stored_results: []

  @clear: () ->
    @_stored_results = []

  # the ancestry of the bubble
  # and the sugared map ancestry of that bubble (same length lists)
  @lookup_result: (ancestry, smap_ancestry) ->
    # this is for patched-in results for the video
    if Alonzo.Utils.ancestry_same(ancestry, [4619])
      return "CloudObject[\"https://s3.amazonaws.com/alonzo/result_3.png\"]"
    else if Alonzo.Utils.ancestry_same(ancestry, [9027])
      return "94"
    else if Alonzo.Utils.ancestry_same(ancestry, [8454])
      return "CloudObject[\"https://s3.amazonaws.com/alonzo/result_1.png\"]"
    else if Alonzo.Utils.ancestry_same(ancestry, [9836])
      return "CloudObject[\"https://s3.amazonaws.com/alonzo/result_2.png\"]"
    else if Alonzo.Utils.ancestry_same(ancestry, [2373])
      return "CloudObject[\"https://s3.amazonaws.com/alonzo/result_5.png\"]"
    else if Alonzo.Utils.ancestry_same(ancestry, [4878])
      return "CloudObject[\"https://s3.amazonaws.com/alonzo/result_4.png\"]"
    else if Alonzo.Utils.ancestry_same(ancestry, [794])
      return "CloudObject[\"https://s3.amazonaws.com/alonzo/icecream_map.png\"]"
    else if Alonzo.Utils.ancestry_same(ancestry, [5786])
      return "CloudObject[\"https://s3.amazonaws.com/alonzo/icecream_label.png\"]"
    else if Alonzo.Utils.ancestry_same(ancestry, [3634])
      return "€2.4 M"
    else if Alonzo.Utils.ancestry_same(ancestry, [8941])
      return "CloudObject[\"https://s3.amazonaws.com/alonzo/icecream_plot.png\"]"
    else if Alonzo.Utils.ancestry_same(ancestry, [7073])
      return "0.926"
    else if Alonzo.Utils.ancestry_same(ancestry, [6193])
      return "CloudObject[\"https://s3.amazonaws.com/alonzo/fibo_plot.png\"]"

    result = (stored_result for stored_result in @_stored_results when (
      Alonzo.Utils.ancestry_same(stored_result.ancestry,           ancestry)           and
      Alonzo.Utils.ancestry_same(stored_result.iteration_ancestry, smap_ancestry)
    ))

    if result.length == 0
      "(none)"
    else if result.length == 1
      result[0].content
    else
      console.error("more than one result found")

  # the format of this datastructure is described in the format documentation, for example format_04.txt
  @load_results_from_file: (filename) ->
    x = fs.readFileSync("/home/nhoff/visx_tmp_results/results.json")
    y = JSON.parse(x)
    @_stored_results = y.results
