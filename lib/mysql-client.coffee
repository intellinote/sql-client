SQLClient         = require( './sql-client' ).SQLClient
SQLClientPool     = require( './sql-client-pool' ).SQLClientPool
ConnectionFactory = require( './connection-factory' ).ConnectionFactory
mysql             = require('mysql')

class MySQLConnectionFactory extends ConnectionFactory
  open_connection:(options,callback)=>
    connection = mysql.createConnection(options)
    connection.connect (err)=>
      callback(err,connection)

class MySQLClient extends SQLClient
  constructor:(options...)->
    super(options...,new MySQLConnectionFactory())


class MySQLClientPool extends SQLClientPool
  constructor:(options...)->
    super(options...,new MySQLConnectionFactory())

exports.MySQLConnectionFactory = MySQLConnectionFactory
exports.MySQLClient = MySQLClient
exports.MySQLClientPool = MySQLClientPool
