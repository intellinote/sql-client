fs        = require 'fs'
path      = require 'path'
HOMEDIR   = path.join(__dirname,'..')
LIB_COV   = path.join(HOMEDIR,'lib-cov')
LIB_DIR   = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
SQLClient = require( path.join(LIB_DIR,'sql-client') ).SQLClient

class SQLClientPool

  MESSAGES: {
    POOL_NOT_OPEN:      "The pool is not open; please call 'open' before invoking this method."
    TOO_MANY_RETURNED:  "More clients have been returned to the pool than were active. A client may have been returned twice."
    EXHAUSTED:          "The maxiumum number of clients are already active; cannot obtain a new client."
    MAX_WAIT:           "The maxiumum number of clients are already active and the maximum wait time has been exceeded; cannot obtain a new client."
    INVALID:            "Unable to create a valid client."
    INTERNAL_ERROR:     "Internal error."
    INVALID_ARGUMENT:   "Invalid argument."
    NULL_RETURNED:      "A null object was returned."
    CLOSED_WITH_ACTIVE: "The pool was closed, but some clients remain active (were never returned)."
 }

  DEFAULT_WAIT_INTERVAL: 50

  create:(callback)=>
    client = new SQLClient(@sql_options...,@factory)
    client.connect (err)=>
      callback(err,client)

  activate:(client,callback)=>
    callback(null,client)

  validate:(client,callback)=>
    if client? and (not client.pooled_at? or (Date.now()-client.pooled_at) < @pool_options.max_age)
      callback(null,true,client)
    else
      callback(null,false,client)

  passivate:(client,callback)=>
    callback(null,client)

  destroy:(client,callback)=>
    if client?
      client.disconnect(callback)
    else
      callback()

  pool:[]
  pool_options:{}
  open:false
  borrowed:0
  returned:0
  active:0

  constructor:(@sql_options...,@factory)->

  open:(opts,callback)=>
    if not callback? and typeof opts is 'function'
      callback = opts
      opts = null
    if typeof callback isnt 'function'
      throw new Error(@MESSAGES.INVALID_ARGUMENT)
    else
      @_config opts, (err)=>
        @open = true
        callback?(err)

  close:(callback)=>
    if callback? and typeof callback isnt 'function'
      throw new Error(@MESSAGES.INVALID_ARGUMENT)
    else
      @open = false
      if @pool.length > 0
        @destroy @pool.shift(),()=>
          @close(callback)
      else
        if @active > 0
          callback?(new Error(@MESSAGES.CLOSED_WITH_ACTIVE))
        else
          callback?()

  borrow:(callback,blocked_since)=>
    if typeof callback isnt 'function'
      throw new Error(@MESSAGES.INVALID_ARGUMENT)
    else
      if not @open
        callback new Error(@MESSAGES.NOT_OPEN)
      else
        if @active >= @pool_options.max_active and @pool_options.when_exhausted is 'fail'
          callback new Error(@MESSAGES.EXHAUSTED)
        else if @active >= @pool_options.max_active and @pool_options.when_exhausted is 'block'
          if blocked_since? and (Date.now() - blocked_since) >= @pool_options.max_wait
            callback new Error(@MESSAGES.MAX_WAIT)
          else
            blocked_since ?= Date.now()
            setTimeout (()=>@borrow(callback,blocked_since)), @pool_options.wait_interval
        else if @pool.length > 0
          client = @pool.shift()
          @_activate_and_validate_or_destroy client, (err,valid,client)=>
            if err?
              callback(err)
            else if not valid
              @borrow(callback)
            else
              client.pooled_at = null
              client.borrowed_at = Date.now()
              @active++
              callback(null,client)
        else
          @create (err,client)=>
            if err?
              callback(err)
            else
              @_activate_and_validate_or_destroy client, (err,valid,client)=>
                if err?
                  callback(err)
                else if not valid
                  callback new Error(@MESSAGES.INVALID)
                else
                  client.pooled_at = null
                  client.borrowed_at = Date.now()
                  @active++
                  callback(null,client)

  return:(client,callback)=>
    if (not client? and not callback?) or (callback? and typeof callback isnt 'function')
      throw new Error(@MESSAGES.INVALID_ARGUMENT)
    else if not client?
      callback(new Error(@MESSAGES.NULL_RETURNED))
    else if @active <= 0
      callback(new Error(@MESSAGES.TOO_MANY_RETURNED))
    else
      @returned++
      @active--
      if client?
        @passivate client, (err,client)=>
          if err
            callback(err)
          else
            client.pooled_at = Date.now()
            client.borrowed_at = null
            if @pool.length >= @pool_options.max_idle
              @destroy client, callback
            else
              @pool.push client
              callback?()

  _config:(opts,callback)=>
    opts ?= {}
    new_opts = @_clone(@pool_options)
    keys = Object.keys(opts)
    for prop in [ 'min_idle','max_idle','max_active', 'when_exhausted', 'max_wait', 'wait_interval', 'max_age' ]
      if prop in keys
        new_opts[prop] = opts[prop]
    if typeof new_opts.max_idle is 'number' and new_opts.max_idle < 0
      new_opts.max_idle = Number.MAX_VALUE
    else if typeof new_opts.max_idle isnt 'number'
      new_opts.max_idle = 0
    new_opts.min_idle = 0 if typeof new_opts.min_idle isnt 'number' or new_opts.min_idle < 0
    new_opts.min_idle = new_opts.max_idle if new_opts.min_idle > new_opts.max_idle
    new_opts.max_active = Number.MAX_VALUE if typeof new_opts.max_active isnt 'number' or new_opts.max_active < 0
    new_opts.max_wait = Number.MAX_VALUE if typeof new_opts.max_wait isnt 'number' or new_opts.max_wait < 0
    new_opts.wait_interval = @DEFAULT_WAIT_INTERVAL if typeof new_opts.wait_interval isnt 'number' or new_opts.wait_interval < 0
    new_opts.when_exhausted = 'grow' unless new_opts.when_exhausted in [ 'grow','block','fail' ]
    new_opts.block_timeout = null unless typeof new_opts.block_timeout is 'number' and new_opts.block_timeout > 0
    new_opts.max_age = Number.MAX_VALUE if not new_opts.max_age? or new_opts.max_age < 0
    @pool_options = new_opts
    @_reconfig(callback)

  _reconfig:(callback)=>
    @_evict (err)=>
      if err?
        callback?(err)
      else
        @_prepopulate callback

  _evict:(callback)=>
    new_pool = []
    while @pool.length > 0
      client = @pool.shift()
      if new_pool.length < @pool_options.max_idle and @_is_valid(client)
        new_pool.push client
      else
        client.disconnect()
    @pool = new_pool
    callback?()

  _prepopulate:(callback)=>
    n = @pool_options.min_idle - @pool.length
    if n > 0
      @_borrow_n n, [], (err,borrowed)=>
        if err?
          callback(err)
        else
          @_return_n borrowed, callback
    else
      callback()

  _borrow_n:(n,borrowed,callback)=>
    if typeof n isnt 'number' or not Array.isArray(borrowed)
      callback(new Error(@MESSAGES.INTERNAL_ERROR))
    else
      if n > borrowed.length
        @borrow (err,client)=>
          if client?
            borrowed.push client
          if err?
            @_return_n borrowed, ()=>
              callback(err)
          else
            @_borrow_n(n,borrowed,callback)
      else
        callback(null,borrowed)

  _return_n:(borrowed,callback)=>
    if not Array.isArray(borrowed)
      callback(new Error(@MESSAGES.INTERNAL_ERROR))
    else if borrowed.length > 0
      client = borrowed.shift()
      @return client,()=>
        @_return_n(borrowed,callback)
    else
      callback(null)

  _activate_and_validate_or_destroy:(client,callback)=>
    @activate client, (err,client)=>
      if err?
        if client?
          @destroy client, ()=>
            callback(err,false,null)
        else
          callback(err,false,null)
      else
        @validate client, (err,valid,client)=>
          if err?
            if client?
              @destroy client, ()=>
                callback(err,false,null)
            else
              callback(err,false,null)
          else if not valid
            @destroy client,()=>
              callback(null,false,null)
          else
            callback(null,true,client)

  _clone:(map)->
    unless map?
      return null
    else
      cloned = {}
      for n,v of map
        cloned[n] = v
      return cloned

exports.SQLClientPool = SQLClientPool
