class ConnectionFactory

  open_connection:(options...,callback)=>
    callback?(new Error("open_connection not implemented; please override"))

  close_connection:(connection,callback)=>
    if typeof connection?.end is 'function'
      connection.end()
      callback?()
    else if typeof connection?.close is 'function'
      connection.close()
      callback?()
    else
      callback?(new Error("close_connection not implemented; please override"))

  execute:(connection,sql,bindvars,callback)=>
    if typeof connection.query is 'function'
      connection.query(sql,bindvars,callback)
    else
      callback(new Error("execute not implemented; please override"))

  pre_process_sql:(sql,bindvars,callback)=>
    callback(null,sql,bindvars)

exports.ConnectionFactory = ConnectionFactory
