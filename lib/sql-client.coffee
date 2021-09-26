DEBUG         = (/(^|,)SQLClient($|,)/i.test process?.env?.NODE_DEBUG)
DEBUG_DDL     = (/(^|,)SQLClient\.DDL($|,)/i.test process?.env?.NODE_DEBUG)
DEBUG_CONNECT = (/(^|,)SQLClient\.connect($|,)/i.test process?.env?.NODE_DEBUG)

class SQLClient

  constructor:(@options...,@factory)->
    @created_at = Date.now()
    @pooled_at = null
    @borrowed_at = null
    @connected_at = null

  connect:(options, callback)=>
    if typeof options is "function" and not callback?
      [callback, options] = [options, callback]
    #
    if DEBUG_CONNECT
      console.log "SQLClient.connect. @connection? #{@connection?}"
    unless @connection?
      @factory.open_connection @options...,(err,connection)=>
        if err?
          callback?(err)
        else
          @connection = connection
          @connected_at = Date.now()
          callback?()
    else
      callback?()

  disconnect:(options, callback)=>
    if typeof options is "function" and not callback?
      [callback, options] = [options, callback]
    #
    if DEBUG_CONNECT
      console.log "SQLClient.disconnect. @connection? #{@connection?}; options:", options
    if @connection?
      @factory.close_connection @connection, (err)=>
        if err?
          callback?(err,@connection)
        else
          @connection = null
          @connected_at = null
          callback?()
    else
      callback?()

  execute:(sql,bindvars,callback)=>
    if (not callback?) and typeof bindvars is 'function'
      callback = bindvars
      bindvars = null
    if (not @connection?)
      @connect (err)=>
        if err?
          callback(err)
        else
          @execute(sql,bindvars,callback)
    else
      @factory.pre_process_sql sql, bindvars, (err,sql,bindvars)=>
        if err?
          callback?(err)
        else
          if DEBUG and (DEBUG_DDL or not (/^\s((create)|(drop))\s/i.test sql))
            console.log "SQLClient executing:",sql,bindvars
          @factory.execute(@connection,sql,bindvars,callback)

exports.SQLClient = SQLClient
