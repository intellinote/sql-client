fs                = require 'fs'
path              = require 'path'
HOMEDIR           = path.join(__dirname,'..')
LIB_COV           = path.join(HOMEDIR,'lib-cov')
LIB_DIR           = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
SQLClient         = require( path.join(LIB_DIR,'sql-client') ).SQLClient
SQLClientPool     = require( path.join(LIB_DIR,'sql-client-pool') ).SQLClientPool
ConnectionFactory = require( path.join(LIB_DIR,'connection-factory') ).ConnectionFactory
mysql             = require('mysql')

class MySQLConnectionFactory extends ConnectionFactory
  open_connection:(options,callback)=>
    connection = mysql.createConnection(options)
    connection.connect()
    callback(null,connection)

class MySQLClient extends SQLClient
  constructor:(options...)->
    super(options...,new MySQLConnectionFactory())


class MySQLClientPool extends SQLClientPool
  constructor:(options...)->
    super(options...,new MySQLConnectionFactory())

exports.MySQLConnectionFactory = MySQLConnectionFactory
exports.MySQLClient = MySQLClient
exports.MySQLClientPool = MySQLClientPool
