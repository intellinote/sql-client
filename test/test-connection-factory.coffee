fs                = require 'fs'
path              = require 'path'
HOMEDIR           = path.join(__dirname,'..')
LIB_COV           = path.join(HOMEDIR,'lib-cov')
LIB_DIR           = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
ConnectionFactory = require( path.join(LIB_DIR,'connection-factory') ).ConnectionFactory
should            = require('should')


describe 'ConnectionFactory',->

  it 'demands that open_connect be overridden', (done)->
    factory = new ConnectionFactory()
    factory.open_connection {},(err,connection)->
      should.exist err
      should.not.exist connection
      done()

  it 'demands that close_connection be overridden if connection.end and connection.close don\'t exist', (done)->
    factory = new ConnectionFactory()
    factory.close_connection {},(err)->
      should.exist err
      done()

  it 'demands that execute be overridden if connection.query doesn\'t exist', (done)->
    factory = new ConnectionFactory()
    factory.execute {},"sql",["bindvars"],(err,result)->
      should.exist err
      should.not.exist result
      done()

  it 'uses connection.end or connection.close when available', (done)->
    factory = new ConnectionFactory()
    end_called = false
    conn = {
      end:()->end_called=true
    }
    factory.close_connection conn,(err)->
      should.not.exist err
      end_called.should.be.ok
      close_called = false
      conn = {
        close:()->close_called=true
      }
      factory.close_connection conn,(err)->
        should.not.exist err
        close_called.should.be.ok
        done()

  it 'uses connection.query when available', (done)->
    factory = new ConnectionFactory()
    query_called = false
    conn = {
      query:(s,b,c)->
        query_called=true
        c()
    }
    factory.execute conn,"s",["b"],(err,result)->
      should.not.exist err
      query_called.should.be.ok
      done()

  it 'pre_process_sql is a no-op by default', (done)->
    factory = new ConnectionFactory()
    factory.pre_process_sql "s","b",(err,s,b)->
      should.not.exist err
      s.should.equal "s"
      b.should.equal "b"
      done()
