SQLClient         = require( './sql-client' ).SQLClient
SQLClientPool     = require( './sql-client-pool' ).SQLClientPool
ConnectionFactory = require( './connection-factory' ).ConnectionFactory
sqlite3           = require('sqlite3').verbose()

class SQLite3ConnectionFactory extends ConnectionFactory
  open_connection:(filename,mode,callback)=>
    if typeof mode is 'function' and not callback?
      callback = mode
      mode = null
    db = null
    cb = (err)=>
      if err?
        callback(err)
      else
        callback(null,db)
    if mode?
      db = new sqlite3.Database(filename,mode,cb)
    else
      db = new sqlite3.Database(filename,cb)

  execute:(db,sql,bindvars,callback)=>
    bindvars ?= []
    db.all(sql,bindvars,callback)

class SQLite3Client extends SQLClient
  constructor:(options...)->
    super(options...,new SQLite3ConnectionFactory())


class SQLite3ClientPool extends SQLClientPool
  constructor:(options...)->
    super(options...,new SQLite3ConnectionFactory())

exports.SQLite3ConnectionFactory = SQLite3ConnectionFactory
exports.SQLite3Client = SQLite3Client
exports.SQLite3ClientPool = SQLite3ClientPool
