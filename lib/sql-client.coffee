class SQLClient

  constructor:(@options...,@factory)->
    @created_at = Date.now()
    @pooled_at = null
    @borrowed_at = null
    @connected_at = null

  connect:(callback)=>
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

  disconnect:(callback)=>
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
          @factory.execute(@connection,sql,bindvars,callback)

exports.SQLClient = SQLClient
