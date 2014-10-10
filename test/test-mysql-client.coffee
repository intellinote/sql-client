fs                = require 'fs'
path              = require 'path'
HOMEDIR           = path.join(__dirname,'..')
LIB_COV           = path.join(HOMEDIR,'lib-cov')
LIB_DIR           = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
mysql             = require( path.join(LIB_DIR,'mysql-client') )
should            = require('should')

describe 'MySQL',->

  CONNECT_OPTS = {
    host: 'localhost'
    user: 'sqlclient_test_u'
    password: 'password'
  }

  PAUSE = 2

  it 'check for database',(done)->
    database_available = (callback)->
      client = new mysql.MySQLClient(CONNECT_OPTS)
      client.connect (err)->
        if err?
          report_no_database(err)
          x = 0
          console.error "(Pausing for #{PAUSE} seconds to make sure you notice the message.)"
          console.error "============================================================"
          console.error ""
          setTimeout (callback), PAUSE*1000
        else
          client.disconnect (err)->
            callback(true)

    report_no_database = (err)->
      console.error ""
      console.error "============================================================"
      console.error "!WARNING! COULD NOT CONNECT TO POSTGRESQL DATABASE !WARNING!"
      console.error "------------------------------------------------------------"
      console.error ""
      console.error " The automated functional tests in:"
      console.error "     #{path.basename(__filename)}"
      console.error " require access to a test account in a PostgeSQL database. "
      console.error ""
      console.error " The following error was encountered while trying to"
      console.error " connect to the database using the connection params:"
      console.error "     #{JSON.stringify(CONNECT_OPTS)}"
      console.error ""
      console.error " The specific error encountered was:"
      console.error "     #{err}"
      console.error " Some unit tests will be skipped because of this error."
      console.error ""
      console.error " See the README file at:"
      console.error "     #{path.join(__dirname,'README.md')}"
      console.error " for instructions on how to set up and configure the test"
      console.error " database in order to enable these tests."
      console.error ""
      console.error "------------------------------------------------------------"

    database_available (available)->
      if available

        describe 'Client',->

          it 'can connect to the database', (done)->
            client = new mysql.MySQLClient(CONNECT_OPTS)
            client.connect (err)->
              if err?
                report_no_database(err)
              should.not.exist err
              client.disconnect (err)->
                should.not.exist err
                done()

          it 'can execute a query (straight sql)', (done)->
            client = new mysql.MySQLClient(CONNECT_OPTS)
            client.connect (err)->
              should.not.exist err
              client.execute "SELECT 17 AS n, NOW() as dt", (err,rows,fields)->
                should.not.exist err
                should.exist rows
                rows.length.should.equal 1
                rows[0].n.should.equal 17
                rows[0].dt.should.be.ok
                client.disconnect (err)->
                  should.not.exist err
                  done()

          it 'can execute a query (bind-variables)', (done)->
            client = new mysql.MySQLClient(CONNECT_OPTS)
            client.connect (err)->
              should.not.exist err
              client.execute "SELECT ? AS x", [19], (err,rows,fields)->
                should.not.exist err
                should.exist rows
                rows.length.should.equal 1
                rows[0].x.should.equal 19
                client.disconnect (err)->
                  should.not.exist err
                  done()


        describe 'ClientPool',->

          it 'supports borrow, execute, return pattern (default config)', (done)->
            pool = new mysql.MySQLClientPool(CONNECT_OPTS)
            pool.open (err)->
              should.not.exist err
              pool.borrow (err,client)->
                should.not.exist err
                should.exist client
                client.execute "SELECT ? AS x, ? AS y", [32,18], (err,rows,fields)->
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
            pool = new mysql.MySQLClientPool(CONNECT_OPTS)
            pool.open options, (err)->
              should.not.exist err
              pool.borrow (err,client)->
                should.not.exist err
                should.exist client
                client.execute "SELECT ? AS x, ? AS y", [32,18], (err,rows,fields)->
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
            pool = new mysql.MySQLClientPool(CONNECT_OPTS)
            pool.open (err)->
              should.not.exist err
              pool.borrow (err,client1)->
                should.not.exist err
                should.exist client1
                client1.execute "SELECT ? AS x, ? AS y", [32,18], (err,rows,fields)->
                  should.not.exist err
                  should.exist rows
                  rows.length.should.equal 1
                  rows[0].x.should.equal 32
                  rows[0].y.should.equal 18
                  pool.borrow (err,client2)->
                    should.not.exist err
                    should.exist client2
                    client2.execute "SELECT ? AS x, ? AS y", [1,5], (err,rows,fields)->
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
            pool = new mysql.MySQLClientPool(CONNECT_OPTS)
            pool.open options,(err)->
              should.not.exist err
              pool.borrow (err,client1)->
                should.not.exist err
                should.exist client1
                client1.execute "SELECT ? AS x, ? AS y", [32,18], (err,rows,fields)->
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
                      client2.execute "SELECT ? AS x, ? AS y", [1,5], (err,rows,fields)->
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
      done()
