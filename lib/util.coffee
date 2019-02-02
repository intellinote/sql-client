class Util

  merge:(objs...)=>
    result = {}
    for obj in objs
      result = Object.assign( result, obj )
    return result

  #----------------------------------------------------------------------------#

  handle_error:(err,callback,throw_when_no_callback=true)=>
    throw_when_no_callback ?= true
    if err?
      if callback?
        callback(err)
        return true
      else if throw_when_no_callback
        throw err
      else
        console.error "ERROR",err
    else
      return false

  #----------------------------------------------------------------------------#

  for_async:(initialize,condition,action,increment,options,whendone)=>
    if typeof options is "function" and not whendone?
      whendone = options
      options = undefined
    timeout = options?.timeout
    results = []
    looper = ()->
      if condition()
        action (response...)->
          results.push response
          increment()
          looper()
      else
        whendone(undefined,results) if whendone?
    initialize()
    looper()

  for_each_async:(list,action,options,whendone)=>
    if typeof options is "function" and not whendone?
      whendone = options
      options = undefined
    i = null
    init = ()-> i = 0
    cond = ()-> (i < list.length)
    incr = ()-> i += 1
    act  = (next)->action(list[i],i,list,next)
    @for_async(init, cond, act, incr, whendone)
  #----------------------------------------------------------------------------#

module.exports.Util = new Util()
