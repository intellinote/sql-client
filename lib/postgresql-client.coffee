fs                = require 'fs'
path              = require 'path'
HOMEDIR           = path.join(__dirname,'..')
LIB_COV           = path.join(HOMEDIR,'lib-cov')
LIB_DIR           = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
SQLClient         = require( path.join(LIB_DIR,'sql-client') ).SQLClient
SQLClientPool     = require( path.join(LIB_DIR,'sql-client-pool') ).SQLClientPool
ConnectionFactory = require( path.join(LIB_DIR,'connection-factory') ).ConnectionFactory
pg                = require('pg')
try
  if pg?.native?
    pg = pg.native
catch error
  console.log error

class PostgreSQLConnectionFactory extends ConnectionFactory
  open_connection:(connect_string,callback)=>
    connection = new pg.Client(connect_string)
    connection.connect (err)=>
      callback(err,connection)

  pre_process_sql:(sql,bindvars,callback)=>
    if sql? and bindvars?
      index = 1
      sql = sql.replace(/\?/g,(()->'$'+index++))
    callback(null,sql,bindvars)

class PostgreSQLClient extends SQLClient
  constructor:(options...)->
    super(options...,new PostgreSQLConnectionFactory())


class PostgreSQLClientPool extends SQLClientPool
  constructor:(options...)->
    super(options...,new PostgreSQLConnectionFactory())

exports.PostgreSQLConnectionFactory = PostgreSQLConnectionFactory
exports.PostgreSQLClient = PostgreSQLClient
exports.PostgreSQLClientPool = PostgreSQLClientPool

class PostgreSQLConnectionFactory2 extends PostgreSQLConnectionFactory
  open_connection:(connect_string,callback)=>
    pg.connect connect_string, (err,client,done_fn)=>
      connection = client
      if connection?
        connection._sqlclient_done = done_fn
      callback(err,connection)
      
  close_connection:(connection,callback)=>
    if connection?._sqlclient_done?
      connection._sqlclient_done()
      callback?(null)
    else
      super.close_connection(connection,callback)

class PostgreSQLClient2 extends SQLClient
  constructor:(options...)->
    super(options...,new PostgreSQLConnectionFactory2())


class PostgreSQLClientPool2 extends SQLClientPool
  constructor:(options...)->
    super(options...,new PostgreSQLConnectionFactory2())

exports.PostgreSQLConnectionFactory2 = PostgreSQLConnectionFactory2
exports.PostgreSQLClient2 = PostgreSQLClient2
exports.PostgreSQLClientPool2 = PostgreSQLClientPool2
