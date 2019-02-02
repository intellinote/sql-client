ConnectionFactory = require( '../lib/connection-factory' ).ConnectionFactory
SQLClient         = require( '../lib/sql-client' ).SQLClient
should            = require('should')

describe 'SQLClient',->

  it 'pre-processes SQL on execute', (done)->
    factory = new ConnectionFactory()
    factory.open_connection = (o,cb)->
      cb(null,{})
    factory.pre_processed = false
    factory.pre_process_sql = (s,b,cb)->
      factory.pre_processed = true
      cb(null,s,b)
    factory.execute = (c,s,b,cb)->
      factory.pre_processed.should.be.ok
      cb()
    client = new SQLClient({},factory)
    client.execute("s",done)

  it 'opens connection on execute if not already open', (done)->
    factory = new ConnectionFactory()
    factory.opened = false
    factory.open_connection = (o,cb)->
      factory.opened = true
      cb(null,{})
    factory.execute = (c,s,b,cb)->
      factory.opened.should.be.ok
      cb()
    client = new SQLClient({},factory)
    client.execute("s",done)
