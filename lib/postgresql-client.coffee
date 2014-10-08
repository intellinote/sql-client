fs                = require 'fs'
path              = require 'path'
HOMEDIR           = path.join(__dirname,'..')
LIB_COV           = path.join(HOMEDIR,'lib-cov')
LIB_DIR           = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
SQLClient         = require( path.join(LIB_DIR,'sql-client') ).SQLClient
SQLClientPool     = require( path.join(LIB_DIR,'sql-client-pool') ).SQLClientPool
ConnectionFactory = require( path.join(LIB_DIR,'connection-factory') ).ConnectionFactory
pg                = require('pg').native

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
