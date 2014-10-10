fs                = require 'fs'
path              = require 'path'
HOMEDIR           = path.join(__dirname,'..')
LIB_COV           = path.join(HOMEDIR,'lib-cov')
LIB_DIR           = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
sqlite3             = require( path.join(LIB_DIR,'sqlite3-client') )
should            = require('should')

CONNECT_OPTS = ':memory:'

describe 'SQLite3',->

  it 'can connect to the database', (done)->
    client = new sqlite3.SQLite3Client(CONNECT_OPTS)
    client.connect (err)->
      if err?
        report_no_database(err)
      should.not.exist err
      client.disconnect (err)->
        should.not.exist err
        done()

  it 'can connect to the database (mode-case)', (done)->
    client = new sqlite3.SQLite3Client(CONNECT_OPTS,6) # 6 == sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE
    client.connect (err)->
      if err?
        report_no_database(err)
      should.not.exist err
      client.disconnect (err)->
        should.not.exist err
        done()

  it 'can execute a query (straight sql)', (done)->
    client = new sqlite3.SQLite3Client(CONNECT_OPTS)
    client.connect (err)->
      should.not.exist err
      client.execute "SELECT 17 AS n", (err,rows)->
        should.not.exist err
        should.exist rows
        rows.length.should.equal 1
        rows[0].n.should.equal 17
        client.disconnect (err)->
          should.not.exist err
          done()

  it 'can execute a query (bind-variables)', (done)->
    client = new sqlite3.SQLite3Client(CONNECT_OPTS)
    client.connect (err)->
      should.not.exist err
      client.execute "SELECT ? AS x", [19], (err,rows)->
        should.not.exist err
        should.exist rows
        rows.length.should.equal 1
        rows[0].x.should.equal 19
        client.disconnect (err)->
          should.not.exist err
          done()


describe 'ClientPool',->

  it 'supports borrow, execute, return pattern (default config)', (done)->
    pool = new sqlite3.SQLite3ClientPool(CONNECT_OPTS)
    pool.open (err)->
      should.not.exist err
      pool.borrow (err,client)->
        should.not.exist err
        should.exist client
        client.execute "SELECT ? AS x, ? AS y", [32,18], (err,rows)->
          should.not.exist err
          should.exist rows
          rows.length.should.equal 1
          rows[0].x.should.equal 32
          rows[0].y.should.equal 18
          pool.return client, (err)->
            should.not.exist err
            pool.close (err)->
              should.not.exist err
              done()

  it 'supports borrow, execute, return pattern (max_idle=5,min_idle=3)', (done)->
    options = { min_idle:3, max_idle:5 }
    pool = new sqlite3.SQLite3ClientPool(CONNECT_OPTS)
    pool.open options, (err)->
      should.not.exist err
      pool.borrow (err,client)->
        should.not.exist err
        should.exist client
        client.execute "SELECT ? AS x, ? AS y", [32,18], (err,rows)->
          should.not.exist err
          should.exist rows
          rows.length.should.equal 1
          rows[0].x.should.equal 32
          rows[0].y.should.equal 18
          pool.return client, (err)->
            should.not.exist err
            pool.close (err)->
              should.not.exist err
              done()

  it 'supports borrow, execute, borrow, execute, return, return pattern (default config)', (done)->
    pool = new sqlite3.SQLite3ClientPool(CONNECT_OPTS)
    pool.open (err)->
      should.not.exist err
      pool.borrow (err,client1)->
        should.not.exist err
        should.exist client1
        client1.execute "SELECT ? AS x, ? AS y", [32,18], (err,rows)->
          should.not.exist err
          should.exist rows
          rows.length.should.equal 1
          rows[0].x.should.equal 32
          rows[0].y.should.equal 18
          pool.borrow (err,client2)->
            should.not.exist err
            should.exist client2
            client2.execute "SELECT ? AS x, ? AS y", [1,5], (err,rows)->
              should.not.exist err
              should.exist rows
              rows.length.should.equal 1
              rows[0].x.should.equal 1
              rows[0].y.should.equal 5
              pool.return client2, (err)->
                should.not.exist err
                pool.return client1, (err)->
                  should.not.exist err
                  pool.close (err)->
                    should.not.exist err
                    done()

  it 'supports borrow, execute, return, borrow,  execute, return pattern (max_idle=1,min_idle=0)', (done)->
    options = { max_idle:1,min_idle:0 }
    pool = new sqlite3.SQLite3ClientPool(CONNECT_OPTS)
    pool.open options,(err)->
      should.not.exist err
      pool.borrow (err,client1)->
        should.not.exist err
        should.exist client1
        client1.execute "SELECT ? AS x, ? AS y", [32,18], (err,rows)->
          should.not.exist err
          should.exist rows
          rows.length.should.equal 1
          rows[0].x.should.equal 32
          rows[0].y.should.equal 18
          pool.return client1, (err)->
            should.not.exist err
            pool.borrow (err,client2)->
              should.not.exist err
              should.exist client2
              client2.execute "SELECT ? AS x, ? AS y", [1,5], (err,rows)->
                should.not.exist err
                should.exist rows
                rows.length.should.equal 1
                rows[0].x.should.equal 1
                rows[0].y.should.equal 5
                pool.return client2, (err)->
                  should.not.exist err
                  pool.close (err)->
                    should.not.exist err
                    done()
