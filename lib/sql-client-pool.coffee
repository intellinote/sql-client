SQLClient = require( './sql-client' ).SQLClient

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
  DEFAULT_RETRY_INTERVAL: 50

  create_transaction:()=>
    new Transaction(this)

  create:(callback)=>
    client = new SQLClient(@sql_options...,@factory)
    client.connect (err)=>
      callback(err,client)

  activate:(client,callback)=>
    callback(null,client)

  validate:(client,callback)=>
    if client? and ( (not client.pooled_at?) or (not @pool_options?.max_age?) or ((Date.now()-client.pooled_at) < @pool_options.max_age) )
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
  pool_is_open:false
  borrowed:0
  returned:0
  active:0
  eviction_runner:null

  constructor:(@sql_options...,@factory)->
    @open ()->undefined

  open:(opts,callback)=>
    if not callback? and typeof opts is 'function'
      callback = opts
      opts = null
    if typeof callback isnt 'function'
      throw new Error(@MESSAGES.INVALID_ARGUMENT)
    else
      @_config opts, (err)=>
        @pool_is_open = true
        callback?(err)

  close:(callback)=>
    if callback? and typeof callback isnt 'function'
      throw new Error(@MESSAGES.INVALID_ARGUMENT)
    else
      @pool_is_open = false
      if @eviction_runner?
        @eviction_runner.ref()
        clearTimeout @eviction_runner
        @eviction_runner = null
      if @pool.length > 0
        @destroy @pool.shift(),()=>
          @close(callback)
      else
        if @active > 0
          callback?(new Error(@MESSAGES.CLOSED_WITH_ACTIVE))
        else
          callback?()

  # borrow, execute, return, callback
  execute:(sql,bindvars,callback)=>
    if typeof bindvars is 'function' and not callback?
      callback = bindvars
      bindvars = []
    @borrow (err,client)=>
      if err?
        callback(err)
      else unless client?
        callback(new Error("non-null client expected"))
      else
        client.execute sql, bindvars, (response...)=>
          @return client, ()=>
            callback(response...)

  borrow:(callback,blocked_since=null,retry_count=0)=>
    if typeof callback isnt 'function'
      throw new Error(@MESSAGES.INVALID_ARGUMENT)
    else
      if not @pool_is_open
        callback new Error(@MESSAGES.POOL_NOT_OPEN)
      else
        if @active >= @pool_options.max_active and @pool_options.when_exhausted is 'fail'
          callback new Error(@MESSAGES.EXHAUSTED)
        else if @active >= @pool_options.max_active and @pool_options.when_exhausted is 'block'
          if blocked_since? and (Date.now() - blocked_since) >= @pool_options.max_wait
            callback new Error(@MESSAGES.MAX_WAIT)
          else
            blocked_since ?= Date.now()
            setTimeout (()=>@borrow(callback,blocked_since,retry_count)), @pool_options.wait_interval
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
                  if @pool_options.max_retries? and @pool_options.max_retries > retry_count
                    setTimeout (()=>@borrow(callback,blocked_since,retry_count+1)), (@pool_options.retry_interval ? 0)
                  else
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

  # CONFIGUATION OPTIONS:
  #  - `min_idle` - minimum number of idle connections in an "empty" pool
  #  - `max_idle` - maximum number of idle connections in a "full" pool
  #  - `max_active` - maximum number of connections active at one time
  #  - `when_exhausted` - what to do when max_active is reached (`grow`,`block`,`fail`),
  #  - `max_wait` - when `when_exhausted` is `block` max time (in millis) to wait before failure, use < 0 for no maximum
  #  - `wait_interval`  - when `when_exhausted` is `BLOCK`, amount of time (in millis) to wait before rechecking if connections are available
  #  - `max_retries` - number of times to attempt to create another new connection when a newly created connection is invalid; when `null` no retry attempts will be made; when < 0 an infinite number of retries will be attempted
  #  - `retry_interval`  - when `max_retries` is > 0, amount of time (in millis) to wait before retrying
  #  - `max_age` - when a positive integer, connections that have been idle for `max_age` milliseconds will be considered invalid and eligable for eviction
  #  - `eviction_run_interval` - when a positive integer, the number of milliseconds between eviction runs; during an eviction run idle connections will be tested for validity and if invalid, evicted from the pool
  #   - `eviction_run_length` - when a positive integer, the maxiumum number of connections to examine per eviction run (when not set, all idle connections will be evamined during each eviction run)
  #   - `unref_eviction_runner` - unless `false`, `unref` (https://nodejs.org/api/timers.html#timers_unref) will be called on the eviction run interval timer
  _config:(opts,callback)=>
    opts ?= {}
    new_opts = @_clone(@pool_options)
    keys = Object.keys(opts)
    for prop in [ 'min_idle','max_idle','max_active', 'when_exhausted', 'max_wait', 'wait_interval', 'max_age', 'eviction_run_interval', 'eviction_run_length', 'unref_eviction_runner', 'max_retries', 'retry_interval']
      if prop in keys
        new_opts[prop] = opts[prop]
    if new_opts.max_retries? and (typeof new_opts.max_retries isnt 'number' or new_opts.max_retries <= 0)
      new_opts.max_retries = null
    if new_opts.max_retries?
      if new_opts.retry_interval? and (typeof new_opts.retry_interval isnt 'number' or new_opts.retry_interval <= 0)
        new_opts.retry_interval = 0
      else unless new_opts.retry_interval?
        new_opts.retry_interval = @DEFAULT_RETRY_INTERVAL
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
    new_opts.max_age = Number.MAX_VALUE if not new_opts.max_age? or new_opts.max_age < 0
    @pool_options = new_opts
    @_reconfig(callback)

  _reconfig:(callback)=>
    if @eviction_runner?
      @eviction_runner.ref()
      clearTimeout @eviction_runner
      @eviction_runner = null
    @_evict (err)=>
      if err?
        callback?(err)
      else
        @_prepopulate (x...)=>
          if @pool_options?.eviction_run_interval? and @pool_options.eviction_run_interval > 0
            @eviction_runner = setInterval(@_eviction_run,@pool_options.eviction_run_interval)
            unless @pool_options?.unref_eviction_runner is false
              @eviction_runner.unref()
          callback(x...)

  _evict:(callback)=>
    @_eviction_run(0,callback)

  _eviction_run:(num_to_check,callback)=>
    if typeof num_to_check is 'function' and not callback?
      callback = num_to_check
      num_to_check = null
    new_pool = []
    num_checked = 0
    while @pool.length > 0
      client = @pool.shift()
      if (not num_to_check?) or num_to_check <= 0 or num_checked < num_to_check
        num_checked += 1
        if new_pool.length < @pool_options.max_idle and @_is_valid(client)
          new_pool.push client
        else
          client.disconnect()
      else
        new_pool.push client
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

class Transaction

  constructor:(pool_or_client)->
    if pool_or_client? and pool_or_client instanceof SQLClientPool
      @_pool = pool_or_client
    else if pool_or_client? and pool_or_client instanceof SQLClient
      @_client = pool_or_client
    else
      throw new Error("Expected SQLClientPool or SQLClient instance, found #{pool_or_client}")

  begin:(callback)=>
    @execute "BEGIN", [], (r...)=>
      @_began = true
      callback(r...)

  _end:(command,options,callback)=>
    if typeof options is "function" and not callback?
      [callback, options] = [options, callback]
    maybe_return = (cb)=>
      @_ended = true
      if @_pool? and @_client?
        @_pool.return @_client, ()=>
          @_pool = null
          @_client = null
          cb?()
      else if @_client? and @_client?._auto_disconnect_on_transaction_end
        @_client.disconnect(options,cb)
        @_client = null
      else
        cb?()
    if @_began
      @execute command, [], (err)=>
        maybe_return ()=>
          callback(err)
    else
      maybe_return ()=>
        callback()

  rollback:(options, callback)=>
    if typeof options is "function" and not callback?
      [callback, options] = [options, callback]
    if @_ended
      callback(new Error("This transaction has already been closed."))
    else
      @_end "ROLLBACK", options, callback

  commit:(options, callback)=>
    if typeof options is "function" and not callback?
      [callback, options] = [options, callback]
    if @_ended
      callback(new Error("This transaction has already been closed."))
    else
      @_end "COMMIT", options, callback

  rollback_and_end:(callback)=>
    return @rollback({end_pg_pool:true},callback)

  commit_and_end:(callback)=>
    return @commit({end_pg_pool:true},callback)

  _borrow:(callback)=>
    if @_client?
      unless @_client.connected_at?
        @_client.connect (err)=>
          @_client._auto_disconnect_on_transaction_end = true
          callback(err, @_client)
      else
        callback(null,@_client)
    else unless @_pool?
      callback(new Error("No SQLClient or SQLClientPool from which to obtain a connection. This transaction may have already been closed."))
    else
      @_pool.borrow (err,client)=>
        if err?
          callback(err)
        else
          @_client = client
          callback(null,client)

  execute:(sql,bindvars,callback)=>
    if typeof bindvars is 'function' and (not callback?)
      [callback,bindvars] = [bindvars,callback]
    if @_ended
      callback(new Error("This transaction has already been closed."))
    else
      @_borrow (err,client)=>
        if err?
          callback(err)
        else
          client.execute sql, bindvars, callback

exports.SQLClientPool = SQLClientPool
exports.Transaction   = Transaction
