SQLClient         = require( './sql-client' ).SQLClient
SQLClientPool     = require( './sql-client-pool' ).SQLClientPool
ConnectionFactory = require( './connection-factory' ).ConnectionFactory
pg                = require('pg')
Url               = require 'url'
querystring       = require 'querystring'

try
  unless pg.__lookupGetter__("native")?
    pg = pg.native
catch error
  console.log error

# PostgreSQLConnectionFactory does not use any of node-pg's built-in pooling.
class PostgreSQLConnectionFactory extends ConnectionFactory
  constructor:()->
    super()

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

# PostgreSQLConnectionFactory2 DOES usenode-pg's built-in pooling.
class PostgreSQLConnectionFactory2 extends PostgreSQLConnectionFactory
  constructor:()->
    super()
    @pg_pools_by_connect_string = {}

  _connect_string_regexp:/^([^:]+):\/\/([^:]+):([^@]+)@([^:\/]+)(:([0-9]+))?(.*)$/

  _parse_connect_string:(connect_string)=>
    if typeof connect_string is 'string' and @_connect_string_regexp.test(connect_string)
      matches = connect_string.match(@_connect_string_regexp)
      config = {}
      config.database = matches[1]
      config.user = matches[2]
      config.password = matches[3]
      config.host = matches[4]
      if matches[6]?
        config.port = parseInt(matches[6])
      path = matches[7]
      parsed_path = Url.parse(path)
      config.database = parsed_path.pathname.substring(1)
      if parsed_path.query?
        qs = querystring.parse(parsed_path.query)
        for name, value of qs
          if value is 'true'
            value = true
          else if value is 'false'
            value = false
          else if "#{value}" is "#{parseInt(value)}"
            value = parseInt(value)
          config[name] = value
      return config
    else
      return connect_string

  open_connection:(connect_string,callback)=>
    key = connect_string
    unless typeof key is 'string'
      key = JSON.stringify(key)
    pg_pool = @pg_pools_by_connect_string[key]
    unless pg_pool?
      pg_pool = new pg.Pool(@_parse_connect_string(connect_string))
      @pg_pools_by_connect_string[key] = pg_pool
    pg_pool.connect (err,client,done_fn)=>
      connection = client
      if connection?
        connection._sqlclient_done = done_fn
        connection._pg_pool_key = key
        connection._pg_pool = pg_pool
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

  disconnect:(options, callback)=>
    if typeof options is "function" and not callback?
      [callback, options] = [options, callback]
    if options?.end_pg_pool
      pg_pool_to_end = @connection?._pg_pool
    return super options, (err)=>
      if (typeof pg_pool_to_end?.end is "function") and not (pg_pool_to_end.ending or pg_pool_to_end.ended)
        pg_pool_to_end.end()
      callback(err)

  disconnect_and_end:(callback)=>
    return @disconnect {end_pg_pool:true}, callback

class PostgreSQLClientPool2 extends SQLClientPool
  constructor:(options...)->
    super(options...,new PostgreSQLConnectionFactory2())

  destroy:(client,callback)=>
    if client?
      client.disconnect callback
    else
      callback?()

  close:(callback)=>
    super (args...)=>
      pools_to_close = @factory?.pg_pools_by_connect_string
      for key, pg_pool of pools_to_close ? {}
        unless not pg_pool? or (pg_pool.ending or pg_pool.ended)
          pg_pool.end()
      callback?(args...)

exports.PostgreSQLConnectionFactory2 = PostgreSQLConnectionFactory2
exports.PostgreSQLClient2 = PostgreSQLClient2
exports.PostgreSQLClientPool2 = PostgreSQLClientPool2
