fs                = require 'fs'
path              = require 'path'
HOMEDIR           = path.join(__dirname,'..')
LIB_COV           = path.join(HOMEDIR,'lib-cov')
LIB_DIR           = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
SQLClient         = require( path.join(LIB_DIR,'sql-client') ).SQLClient
SQLClientPool     = require( path.join(LIB_DIR,'sql-client-pool') ).SQLClientPool
ConnectionFactory = require( path.join(LIB_DIR,'connection-factory') ).ConnectionFactory
sqlite3           = require('sqlite3').verbose();

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
