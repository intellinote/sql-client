fs                = require 'fs'
path              = require 'path'
HOMEDIR           = path.join(__dirname,'..')
LIB_COV           = path.join(HOMEDIR,'lib-cov')
LIB_DIR           = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
SQLClient         = require( path.join(LIB_DIR,'sql-client') ).SQLClient
SQLClientPool     = require( path.join(LIB_DIR,'sql-client-pool') ).SQLClientPool
ConnectionFactory = require( path.join(LIB_DIR,'connection-factory') ).ConnectionFactory
should            = require('should')

class MockConnectionFactory extends ConnectionFactory
  constructor:(@mock_connection = {}, @mock_error = null, @mock_result = {})->
    @mock_connection.open_count ?= 0
    @mock_connection.close_count ?= 0
    @mock_connection.executed ?= []
    @mock_connection.pre_processed ?= []

  open_connection:(options...,callback)=>
    @mock_connection.open_count++
    @mock_connection.options = options
    callback(null,@mock_connection)

  close_connection:(connection,callback)=>
    if connection?.close_count?
      connection.close_count++
    callback(null,@mock_connection)

  execute:(connection,sql,bindvars,callback)=>
    if connection?.close_count?
      connection.close_count++
    @mock_connection.executed.push {sql:sql,bindvars:bindvars}
    callback @mock_error, @mock_result

  pre_process_sql:(sql,bindvars,callback)=>
    @mock_connection.pre_processed.push {sql:sql,bindvars:bindvars}
    callback sql, bindvars

describe 'SQLClientPool',->

  it 'does no pooling by default', (done)->
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.pool.length.should.equal 0
      pool.borrow (err,first_client)->
        should.not.exist err
        should.exist first_client
        first_id = first_client.id = "FIRST:#{Date.now()}"
        factory.mock_connection.open_count.should.equal 1
        factory.mock_connection.close_count.should.equal 0
        pool.return first_client, (err)->
          should.not.exist err
          pool.pool.length.should.equal 0
          factory.mock_connection.open_count.should.equal 1
          factory.mock_connection.close_count.should.equal 1
          pool.borrow (err,second_client)->
            should.not.exist err
            should.exist second_client
            should.not.exist second_client.id
            factory.mock_connection.open_count.should.equal 2
            factory.mock_connection.close_count.should.equal 1
            pool.return second_client, (err)->
              should.not.exist err
              pool.pool.length.should.equal 0
              factory.mock_connection.open_count.should.equal 2
              factory.mock_connection.close_count.should.equal 2
              pool.close (err)=>
                should.not.exist err
                pool.pool.length.should.equal 0
                factory.mock_connection.open_count.should.equal 2
                factory.mock_connection.close_count.should.equal 2
                done()

  it 'can lend and accept return of SQLClients', (done)->
    options = { max_idle: 1, min_idle:0 }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,client)->
        should.not.exist err
        factory.mock_connection.open_count.should.equal 1
        factory.mock_connection.close_count.should.equal 0
        should.exist client
        pool.return client, (err)->
          should.not.exist err
          factory.mock_connection.open_count.should.equal 1
          pool.close (err)=>
            should.not.exist err
            factory.mock_connection.close_count.should.equal 1
            done()

  it 'can be set up for no pooling', (done)->
    options = { max_idle: 0 }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,client)->
        should.not.exist err
        factory.mock_connection.open_count.should.equal 1
        factory.mock_connection.close_count.should.equal 0
        should.exist client
        pool.return client, (err)->
          should.not.exist err
          factory.mock_connection.open_count.should.equal 1
          factory.mock_connection.close_count.should.equal 1
          pool.close (err)=>
            should.not.exist err
            factory.mock_connection.close_count.should.equal 1
            done()

  it 'will return the same client if configuration allows', (done)->
    options = { max_idle: 1, min_idle:0 }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,client)->
        should.not.exist err
        should.exist client
        id = client.id = Date.now()
        factory.mock_connection.open_count.should.equal 1
        factory.mock_connection.close_count.should.equal 0
        pool.return client, (err)->
          should.not.exist err
          factory.mock_connection.open_count.should.equal 1
          pool.borrow (err,client)->
            should.not.exist err
            should.exist client
            client.id.should.equal id
            factory.mock_connection.open_count.should.equal 1
            factory.mock_connection.close_count.should.equal 0
            pool.return client, (err)->
              should.not.exist err
              factory.mock_connection.open_count.should.equal 1
              pool.close (err)=>
                should.not.exist err
                factory.mock_connection.close_count.should.equal 1
                done()

  it 'will fail when exhausted if configuration allows', (done)->
    options = { max_idle: 1, min_idle:0, max_active:1, when_exhausted:'fail' }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,first_client)->
        should.not.exist err
        should.exist first_client
        pool.borrow (err,second_client)->
          should.exist err
          should.not.exist second_client
          pool.return first_client, (err)->
            should.not.exist err
            pool.borrow (err,third_client)->
              should.not.exist err
              should.exist third_client
              pool.return third_client, (err)->
                pool.close (err)=>
                  should.not.exist err
                  done()

  it 'will grow when exhausted if configuration allows', (done)->
    options = { max_idle: 1, min_idle:0, max_active:1, when_exhausted:'grow' }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,first_client)->
        should.not.exist err
        should.exist first_client
        pool.borrow (err,second_client)->
          should.not.exist err
          should.exist second_client
          pool.return first_client, (err)->
            should.not.exist err
            pool.borrow (err,third_client)->
              should.not.exist err
              should.exist third_client
              pool.return second_client, (err)->
                pool.return third_client, (err)->
                  pool.close (err)=>
                    should.not.exist err
                    done()

  it 'will grow when exhausted by default', (done)->
    options = { max_idle: 1, min_idle:0, max_active:1 }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,first_client)->
        should.not.exist err
        should.exist first_client
        pool.borrow (err,second_client)->
          should.not.exist err
          should.exist second_client
          pool.return first_client, (err)->
            should.not.exist err
            pool.borrow (err,third_client)->
              should.not.exist err
              should.exist third_client
              pool.return second_client, (err)->
                pool.return third_client, (err)->
                  pool.close (err)=>
                    should.not.exist err
                    done()

  it 'will block when exhausted if configuration allows (max_wait case)', (done)->
    options = { max_idle: 1, min_idle:0, max_active:1, when_exhausted:'block', max_wait:500 }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,first_client)->
        should.not.exist err
        should.exist first_client
        before_block = Date.now()
        pool.borrow (err,second_client)->
          should.exist err
          should.not.exist second_client
          (Date.now() - before_block).should.not.be.below options.max_wait
          pool.return first_client, (err)->
            should.not.exist err
            before_block = Date.now()
            pool.borrow (err,third_client)->
              should.not.exist err
              should.exist third_client
              (Date.now() - before_block).should.be.below options.max_wait
              pool.return third_client, (err)->
                pool.close (err)=>
                  should.not.exist err
                  done()

  it 'will block when exhausted if configuration allows (returned before timeout)', (done)->
    options = { max_idle: 1, min_idle:0, max_active:1, when_exhausted:'block' }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,first_client)->
        should.not.exist err
        should.exist first_client
        before_block = Date.now()
        returned_at = null
        return_after = 500
        return_client = ()->
          pool.return first_client, (err)->
            should.not.exist err
            returned_at = Date.now()
        setTimeout return_client, return_after
        pool.borrow (err,second_client)->
          should.not.exist err
          should.exist second_client
          (Date.now() - before_block).should.not.be.below return_after
          (Date.now()).should.not.be.below returned_at
          pool.return second_client, (err)->
            should.not.exist err
            before_block = Date.now()
            pool.borrow (err,third_client)->
              should.not.exist err
              should.exist third_client
              (Date.now() - before_block).should.be.below return_after
              pool.return third_client, (err)->
                pool.close (err)=>
                  should.not.exist err
                  done()

  it 'will reject stale clients if configuration allows', (done)->
    options = { max_idle: 1, min_idle:0, max_active:1, max_age:250 }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,client)->
        should.not.exist err
        should.exist client
        client.id = Date.now()
        factory.mock_connection.open_count.should.equal 1
        factory.mock_connection.close_count.should.equal 0
        pool.return client, (err)->
          should.not.exist err
          factory.mock_connection.open_count.should.equal 1
          factory.mock_connection.close_count.should.equal 0
          pool.borrow (err,client)->
            should.not.exist err
            should.exist client
            should.exist client.id
            factory.mock_connection.open_count.should.equal 1
            factory.mock_connection.close_count.should.equal 0
            pool.return client, (err)->
              should.not.exist err
              factory.mock_connection.open_count.should.equal 1
              factory.mock_connection.close_count.should.equal 0
              after_wait = ()->
                pool.borrow (err,client)->
                  should.not.exist err
                  should.exist client
                  should.not.exist client.id
                  factory.mock_connection.open_count.should.equal 2
                  factory.mock_connection.close_count.should.equal 1
                  pool.return client, (err)->
                    should.not.exist err
                    factory.mock_connection.open_count.should.equal 2
                    factory.mock_connection.close_count.should.equal 1
                    pool.close (err)->
                      should.not.exist err
                      factory.mock_connection.open_count.should.equal 2
                      factory.mock_connection.close_count.should.equal 2
                      done()
              setTimeout after_wait, options.max_age+50

  it 'will pre-populate min_idle clients', (done)->
    options = { max_idle: 3, min_idle:2 }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    factory.mock_connection.open_count.should.equal 0
    factory.mock_connection.close_count.should.equal 0
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 2
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,client)->
        should.not.exist err
        should.exist client
        factory.mock_connection.open_count.should.equal 2
        factory.mock_connection.close_count.should.equal 0
        pool.return client, (err)->
          should.not.exist err
          factory.mock_connection.open_count.should.equal 2
          factory.mock_connection.close_count.should.equal 0
          pool.close (err)=>
            should.not.exist err
            factory.mock_connection.open_count.should.equal 2
            factory.mock_connection.close_count.should.equal 2
            done()

  it 'returning null yields error', (done)->
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,client)->
        should.not.exist err
        should.exist client
        factory.mock_connection.open_count.should.equal 1
        factory.mock_connection.close_count.should.equal 0
        pool.return null, (err)->
          should.exist err
          factory.mock_connection.open_count.should.equal 1
          factory.mock_connection.close_count.should.equal 0
          pool.close (err)=>
            should.exist err
            factory.mock_connection.open_count.should.equal 1
            factory.mock_connection.close_count.should.equal 0
            done()

  it 'throws exceptions if stupid mistakes are made', (done)->
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    # open without config or callback
    try
      pool.open()
      "Expected exception".should.not.exist
    catch err
      (typeof err).should.not.equal 'string'
    # open without callback
    try
      pool.open({})
      "Expected exception".should.not.exist
    catch err
      (typeof err).should.not.equal 'string'
    # borrow without callback
    try
      pool.borrow()
      "Expected exception".should.not.exist
    catch err
      (typeof err).should.not.equal 'string'
    # borrow with non-function callback
    try
      pool.borrow({})
      "Expected exception".should.not.exist
    catch err
      (typeof err).should.not.equal 'string'
    # return without client
    try
      pool.return()
      "Expected exception".should.not.exist
    catch err
      (typeof err).should.not.equal 'string'
    # return with non-function callback
    try
      pool.return({},{})
      "Expected exception".should.not.exist
    catch err
      (typeof err).should.not.equal 'string'
    # close with non-function callback
    try
      pool.close({})
      "Expected exception".should.not.exist
    catch err
      (typeof err).should.not.equal 'string'
    done()

  it 'calls-back with error when too many clients are returned', (done)->
    options = { max_idle: 1, min_idle:0 }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,client)->
        should.not.exist err
        factory.mock_connection.open_count.should.equal 1
        factory.mock_connection.close_count.should.equal 0
        should.exist client
        pool.return client, (err)->
          should.not.exist err
          factory.mock_connection.open_count.should.equal 1
          factory.mock_connection.close_count.should.equal 0
          pool.return client, (err)->
            should.exist err
            factory.mock_connection.open_count.should.equal 1
            factory.mock_connection.close_count.should.equal 0
            pool.close (err)=>
              should.not.exist err
              factory.mock_connection.close_count.should.equal 1
              done()

  it 'calls-back with error when trying to use a closed pool', (done)->
    options = { max_idle: 1, min_idle:0 }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,client)->
        should.not.exist err
        factory.mock_connection.open_count.should.equal 1
        factory.mock_connection.close_count.should.equal 0
        should.exist client
        pool.return client, (err)->
          should.not.exist err
          factory.mock_connection.open_count.should.equal 1
          factory.mock_connection.close_count.should.equal 0
          pool.close (err)=>
            should.not.exist err
            factory.mock_connection.close_count.should.equal 1
            pool.borrow (err,client)->
              should.exist err
              done()

  it 'calls-back with error if a valid client cannot be created', (done)->
    options = { max_idle: 1, min_idle:0 }
    factory = new MockConnectionFactory()
    factory.open_connection = (options...,callback)->
      callback(new Error("Mock Error"))
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,client)->
        should.exist err
        factory.mock_connection.open_count.should.equal 0
        factory.mock_connection.close_count.should.equal 0
        pool.close (err)=>
          should.not.exist err
          done()

  it 'calls-back with error if a valid client cannot be created (min_idle case)', (done)->
    options = { max_idle: 5, min_idle:3 }
    factory = new MockConnectionFactory()
    factory.open_connection = (options...,callback)->
      callback(new Error("Mock Error"))
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.exist err
      done()

  it 'will evict existing clients if reconfigured for max_idle=0', (done)->
    options = { max_idle: -1, min_idle:0 }
    factory = new MockConnectionFactory()
    pool = new SQLClientPool "my sql configuration", factory
    pool.open options, (err)=>
      should.not.exist err
      factory.mock_connection.open_count.should.equal 0
      factory.mock_connection.close_count.should.equal 0
      pool.borrow (err,client)->
        should.not.exist err
        should.exist client
        id = client.id = Date.now()
        factory.mock_connection.open_count.should.equal 1
        factory.mock_connection.close_count.should.equal 0
        pool.return client, (err)->
          should.not.exist err
          factory.mock_connection.open_count.should.equal 1
          pool.borrow (err,client)->
            should.not.exist err
            should.exist client
            client.id.should.equal id
            factory.mock_connection.open_count.should.equal 1
            factory.mock_connection.close_count.should.equal 0
            pool.return client, (err)->
              should.not.exist err
              factory.mock_connection.open_count.should.equal 1
              factory.mock_connection.close_count.should.equal 0
              pool._config {max_idle:0}, (err)->
                should.not.exist err
                factory.mock_connection.open_count.should.equal 1
                factory.mock_connection.close_count.should.equal 1
                pool.borrow (err,client)->
                  should.not.exist err
                  should.exist client
                  should.not.exist client.id
                  factory.mock_connection.open_count.should.equal 2
                  factory.mock_connection.close_count.should.equal 1
                  pool.return client, (err)->
                    should.not.exist err
                    factory.mock_connection.open_count.should.equal 2
                    factory.mock_connection.close_count.should.equal 2
                    pool.close (err)=>
                      should.not.exist err
                      factory.mock_connection.open_count.should.equal 2
                      factory.mock_connection.close_count.should.equal 2
                      done()
