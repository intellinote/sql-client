fs                = require 'fs'
path              = require 'path'
should_continue = true
try
  require('pg')
catch err
  console.error ""
  console.error "WARNING: require('pg') failed with the following error:"
  console.error err
  console.error "The tests in #{path.basename(__filename)} will be skipped."
  console.error ""
  console.error "You must add the pg library to your devDependencies to enable"
  console.error "these tests. See `./test/README.md` for details."
  console.error ""
  should_continue = false

if should_continue
  should            = require('should')
  pg                = require( '../lib/postgresql-client' )
  Transaction       = require( '../lib/sql-client-pool' ).Transaction
  Util              = require( '../lib/util' ).Util

  describe 'PostgreSQL2',->

    CONNECT_STRING            = "postgres://sqlclient_test_user:password@localhost/sqlclient_test_db"
    CONNECT_STRING_WITH_PORT_AND_QS = "postgres://sqlclient_test_user:password@localhost:5432/sqlclient_test_db?application_name=sql-client-unit-test?foo=true&bar=false&connect_timeout=10"

    PAUSE = 2

    it 'check for database',(done)->
      database_available = (callback)->
        client = new pg.PostgreSQLClient(CONNECT_STRING)
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
        console.error " connect to the database using the connect string:"
        console.error "     #{CONNECT_STRING}"
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

          #--------------------------------------------------------------------#
          # BEGINNING OF TESTS TO EXECUTE WHEN PG INSTANCE IS AVAILABLE
          #--------------------------------------------------------------------#

          describe 'Transactions',->

            it 'can execute within transactions (via Pool.create_transaction case)', (done)->
              pool = new pg.PostgreSQLClientPool2(CONNECT_STRING)
              pool.open (err)->
                if err?
                  report_no_database(err)
                should.not.exist err
                pool.execute "DROP TABLE IF EXISTS bar CASCADE", (err,results)->
                  should.not.exist err
                  pool.execute "CREATE TABLE bar ( foo VARCHAR(32), bar INTEGER )", (err,results)->
                    should.not.exist err
                    pool.execute "INSERT INTO bar VALUES ( 'x', 1 )", (err,results)->
                      should.not.exist err
                      pool.close (err)->
                        should.not.exist err
                        pool = new pg.PostgreSQLClientPool2(CONNECT_STRING_WITH_PORT_AND_QS)
                        pool.open (err)->
                          should.not.exist err
                          pool.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                            should.not.exist err
                            results.rows[0].c.should.equal 1
                            transaction = pool.create_transaction()
                            transaction.begin (err)->
                              should.not.exist err
                              transaction.execute "INSERT INTO bar VALUES ( 'y', 2 )", (err,results)->
                                should.not.exist err
                                transaction.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                  should.not.exist err
                                  results.rows[0].c.should.equal 2
                                  pool.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                    should.not.exist err
                                    results.rows[0].c.should.equal 1
                                    transaction.commit (err)->
                                      should.not.exist err
                                      pool.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                        should.not.exist err
                                        results.rows[0].c.should.equal 2
                                        pool.execute "DROP TABLE IF EXISTS bar CASCADE", (err,results)->
                                          should.not.exist err
                                          pool.close (err)->
                                            should.not.exist err
                                            done()
              return null

            it 'can rollback transactions (via Pool.create_transaction case)', (done)->
              pool = new pg.PostgreSQLClientPool2(CONNECT_STRING)
              pool.open (err)->
                if err?
                  report_no_database(err)
                should.not.exist err
                pool.execute "DROP TABLE IF EXISTS bar CASCADE", (err,results)->
                  should.not.exist err
                  pool.execute "CREATE TABLE bar ( foo VARCHAR(32), bar INTEGER )", (err,results)->
                    should.not.exist err
                    pool.execute "INSERT INTO bar VALUES ( 'x', 1 )", (err,results)->
                      should.not.exist err
                      pool.close (err)->
                        should.not.exist err
                        pool = new pg.PostgreSQLClientPool2(CONNECT_STRING)
                        pool.open (err)->
                          should.not.exist err
                          pool.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                            should.not.exist err
                            results.rows[0].c.should.equal 1
                            transaction = pool.create_transaction()
                            transaction.begin (err)->
                              should.not.exist err
                              transaction.execute "INSERT INTO bar VALUES ( 'y', 2 )", (err,results)->
                                should.not.exist err
                                transaction.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                  should.not.exist err
                                  results.rows[0].c.should.equal 2
                                  pool.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                    should.not.exist err
                                    results.rows[0].c.should.equal 1
                                    transaction.rollback (err)->
                                      should.not.exist err
                                      pool.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                        should.not.exist err
                                        results.rows[0].c.should.equal 1
                                        pool.execute "DROP TABLE IF EXISTS bar CASCADE", (err,results)->
                                          should.not.exist err
                                          pool.close (err)->
                                            should.not.exist err
                                            done()
              return null

            it 'can execute within transactions (via new Transaction(SQLClient) case)', (done)->
              # create a SQLClient that exists outside of the transaction
              outside_client = new pg.PostgreSQLClient2(CONNECT_STRING)
              outside_client.connect (err)->
                if err?
                  report_no_database(err)
                should.not.exist err
                # set up the schema
                outside_client.execute "DROP TABLE IF EXISTS bar CASCADE", (err,results)->
                  should.not.exist err
                  outside_client.execute "CREATE TABLE bar ( foo VARCHAR(32), bar INTEGER )", (err,results)->
                    should.not.exist err
                    outside_client.execute "INSERT INTO bar VALUES ( 'x', 1 )", (err,results)->
                      should.not.exist err
                      outside_client.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                        should.not.exist err
                        results.rows[0].c.should.equal 1
                        # create a SQLClient that exists *inside* the transaction
                        transaction = new Transaction(new pg.PostgreSQLClient2(CONNECT_STRING))
                        transaction.begin (err)->
                          should.not.exist err
                          # insert a record inside the transaction and demonstrate that it's visible
                          transaction.execute "INSERT INTO bar VALUES ( 'y', 2 )", (err,results)->
                            should.not.exist err
                            transaction.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                              should.not.exist err
                              results.rows[0].c.should.equal 2
                              # since the transaction is not committed the outside client should not see the new record yet
                              outside_client.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                should.not.exist err
                                results.rows[0].c.should.equal 1
                                # now commit the transaction and confirm the change is visible outside
                                transaction.commit_and_end (err)->
                                  should.not.exist err
                                  outside_client.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                    should.not.exist err
                                    results.rows[0].c.should.equal 2
                                    # (validate that you can't use the transaction after commit or rollback)
                                    transaction.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                      should.exist err
                                      # tear down the schema and close out
                                      outside_client.execute "DROP TABLE IF EXISTS bar CASCADE", (err,results)->
                                        should.not.exist err
                                        outside_client.disconnect_and_end (err)->
                                          should.not.exist err
                                          # done
                                          done()
              return null


            it 'can rollback transactions (via new Transaction(SQLClient) case)', (done)->
              # create a SQLClient that exists outside of the transaction
              outside_client = new pg.PostgreSQLClient2(CONNECT_STRING)
              outside_client.connect (err)->
                if err?
                  report_no_database(err)
                should.not.exist err
                # set up the schema
                outside_client.execute "DROP TABLE IF EXISTS bar CASCADE", (err,results)->
                  should.not.exist err
                  outside_client.execute "CREATE TABLE bar ( foo VARCHAR(32), bar INTEGER )", (err,results)->
                    should.not.exist err
                    outside_client.execute "INSERT INTO bar VALUES ( 'x', 1 )", (err,results)->
                      should.not.exist err
                      outside_client.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                        should.not.exist err
                        results.rows[0].c.should.equal 1
                        # create a SQLClient that exists *inside* the transaction
                        transaction = new Transaction(new pg.PostgreSQLClient2(CONNECT_STRING))
                        transaction.begin (err)->
                          should.not.exist err
                          # insert a record inside the transaction and demonstrate that it's visible
                          transaction.execute "INSERT INTO bar VALUES ( 'y', 2 )", (err,results)->
                            should.not.exist err
                            transaction.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                              should.not.exist err
                              results.rows[0].c.should.equal 2
                              # since the transaction is not committed the outside client should not see the new record yet
                              outside_client.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                should.not.exist err
                                results.rows[0].c.should.equal 1
                                # now rollback the transaction and confirm the change is still NOT visible outside
                                transaction.rollback_and_end (err)->
                                  should.not.exist err
                                  outside_client.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                    should.not.exist err
                                    results.rows[0].c.should.equal 1
                                    # (validate that you can't use the transaction after commit or rollback)
                                    transaction.execute "SELECT COUNT(*)::INTEGER AS c FROM bar", (err,results)->
                                      should.exist err
                                      # tear down the schema and close out
                                      outside_client.execute "DROP TABLE IF EXISTS bar CASCADE", (err,results)->
                                        should.not.exist err
                                        outside_client.disconnect_and_end (err)->
                                          should.not.exist err
                                          # done
                                          done()
              return null

          describe 'PostgreSQLClient2',->

            it 'can connect to the database', (done)->
              client = new pg.PostgreSQLClient2(CONNECT_STRING)
              client.connect (err)->
                if err?
                  report_no_database(err)
                should.not.exist err
                client.disconnect_and_end (err)->
                  should.not.exist err
                  done()
              return null

            it 'can execute a query (straight sql)', (done)->
              client = new pg.PostgreSQLClient2(CONNECT_STRING)
              client.connect (err)->
                should.not.exist err
                client.execute "SELECT 17 AS n, NOW() as dt", (err,results)->
                  should.not.exist err
                  should.exist results
                  should.exist results.rows
                  results.rows.length.should.equal 1
                  results.rows[0].n.should.equal 17
                  results.rows[0].dt.should.be.ok
                  client.disconnect_and_end (err)->
                    should.not.exist err
                    done()
              return null

            it 'can execute a query (postgresql-style ($1) bind-variables)', (done)->
              client = new pg.PostgreSQLClient2(CONNECT_STRING)
              client.connect (err)->
                should.not.exist err
                client.execute "SELECT $1::INTEGER AS x", [19], (err,results)->
                  should.not.exist err
                  should.exist results
                  should.exist results.rows
                  results.rows.length.should.equal 1
                  results.rows[0].x.should.equal 19
                  client.disconnect_and_end (err)->
                    should.not.exist err
                    done()
              return null

            it 'can execute a query (?-style bind-variables)', (done)->
              client = new pg.PostgreSQLClient2(CONNECT_STRING)
              client.connect (err)->
                should.not.exist err
                client.execute "SELECT ?::INTEGER AS x", [19], (err,results)->
                  should.not.exist err
                  should.exist results
                  should.exist results.rows
                  results.rows.length.should.equal 1
                  results.rows[0].x.should.equal 19
                  client.disconnect_and_end (err)->
                    should.not.exist err
                    done()
              return null


          describe 'PostgreSQLClientPool2',->

            it 'supports borrow, execute, return pattern (default config)', (done)->
              pool = new pg.PostgreSQLClientPool2(CONNECT_STRING)
              pool.open (err)->
                should.not.exist err
                pool.borrow (err,client)->
                  should.not.exist err
                  should.exist client
                  client.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [32,18], (err,results)->
                    should.not.exist err
                    should.exist results
                    should.exist results.rows
                    results.rows.length.should.equal 1
                    results.rows[0].x.should.equal 32
                    results.rows[0].y.should.equal 18
                    pool.return client, (err)->
                      should.not.exist err
                      pool.close (err)->
                        should.not.exist err
                        done()
              return null

            it 'supports execute method to wrapping borrow/return logic (default config)', (done)->
              pool = new pg.PostgreSQLClientPool2(CONNECT_STRING)
              pool.open (err)->
                should.not.exist err
                pool.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [32,18], (err,results)->
                  should.not.exist err
                  should.exist results
                  should.exist results.rows
                  results.rows.length.should.equal 1
                  results.rows[0].x.should.equal 32
                  results.rows[0].y.should.equal 18
                  pool.close (err)->
                    should.not.exist err
                    done()
              return null

            it 'supports borrow, execute, return X 5 pattern (default config)', (done)->
              pool = new pg.PostgreSQLClientPool2(CONNECT_STRING)
              pool.open (err)->
                should.not.exist err
                action = (e,i,l,next)=>
                  pool.borrow (err,client)->
                    should.not.exist err
                    should.exist client
                    client.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [32,18], (err,results)->
                      should.not.exist err
                      should.exist results
                      should.exist results.rows
                      results.rows.length.should.equal 1
                      results.rows[0].x.should.equal 32
                      results.rows[0].y.should.equal 18
                      pool.return client, (err)->
                        should.not.exist err
                        next()
                Util.for_each_async [0...5], action, ()=>
                  pool.close (err)->
                    should.not.exist err
                    done()
              return null

            it 'supports borrow, execute, borrow, return, execute, return X 5 pattern (default config)', (done)->
              pool = new pg.PostgreSQLClientPool2(CONNECT_STRING)
              pool.open (err)->
                should.not.exist err
                action = (e,i,l,next)=>
                  pool.borrow (err,client)->
                    should.not.exist err
                    should.exist client
                    client.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [32,18], (err,results)->
                      should.not.exist err
                      should.exist results
                      should.exist results.rows
                      results.rows.length.should.equal 1
                      results.rows[0].x.should.equal 32
                      results.rows[0].y.should.equal 18
                      pool.borrow (err,client2)->
                        should.not.exist err
                        should.exist client2
                        pool.return client, (err)->
                          should.not.exist err
                          client2.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [3,18], (err,results)->
                            should.not.exist err
                            should.exist results
                            should.exist results.rows
                            results.rows.length.should.equal 1
                            results.rows[0].x.should.equal 3
                            results.rows[0].y.should.equal 18
                            pool.return client2, (err)->
                              should.not.exist err
                              next()
                Util.for_each_async [0...5], action, ()=>
                  pool.close (err)->
                    should.not.exist err
                    done()
              return null

            it 'supports borrow, execute, borrow, execute, return, return X 5 pattern (default config)', (done)->
              pool = new pg.PostgreSQLClientPool2(CONNECT_STRING)
              pool.open (err)->
                should.not.exist err
                action = (e,i,l,next)=>
                  pool.borrow (err,client)->
                    should.not.exist err
                    should.exist client
                    client.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [32,18], (err,results)->
                      should.not.exist err
                      should.exist results
                      should.exist results.rows
                      results.rows.length.should.equal 1
                      results.rows[0].x.should.equal 32
                      results.rows[0].y.should.equal 18
                      pool.borrow (err,client2)->
                        should.not.exist err
                        should.exist client2
                        client2.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [3,18], (err,results)->
                          should.not.exist err
                          should.exist results
                          should.exist results.rows
                          results.rows.length.should.equal 1
                          results.rows[0].x.should.equal 3
                          results.rows[0].y.should.equal 18
                          pool.return client2, (err)->
                            should.not.exist err
                            pool.return client, (err)->
                              should.not.exist err
                              next()
                Util.for_each_async [0...5], action, ()=>
                  pool.close (err)->
                    should.not.exist err
                    done()
              return null

            it 'supports borrow, execute, return pattern (max_idle=5,min_idle=3)', (done)->
              options = { min_idle:3, max_idle:5 }
              pool = new pg.PostgreSQLClientPool2(CONNECT_STRING)
              pool.open options, (err)->
                should.not.exist err
                pool.borrow (err,client)->
                  should.not.exist err
                  should.exist client
                  client.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [32,18], (err,results)->
                    should.not.exist err
                    should.exist results
                    should.exist results.rows
                    results.rows.length.should.equal 1
                    results.rows[0].x.should.equal 32
                    results.rows[0].y.should.equal 18
                    pool.return client, (err)->
                      should.not.exist err
                      pool.close (err)->
                        should.not.exist err
                        done()
              return null

            it 'supports borrow, execute, borrow, execute, return, return pattern (default config)', (done)->
              pool = new pg.PostgreSQLClientPool2(CONNECT_STRING)
              pool.open (err)->
                should.not.exist err
                pool.borrow (err,client1)->
                  should.not.exist err
                  should.exist client1
                  client1.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [32,18], (err,results)->
                    should.not.exist err
                    should.exist results
                    should.exist results.rows
                    results.rows.length.should.equal 1
                    results.rows[0].x.should.equal 32
                    results.rows[0].y.should.equal 18
                    pool.borrow (err,client2)->
                      should.not.exist err
                      should.exist client2
                      client2.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [1,5], (err,results)->
                        should.not.exist err
                        should.exist results
                        should.exist results.rows
                        results.rows.length.should.equal 1
                        results.rows[0].x.should.equal 1
                        results.rows[0].y.should.equal 5
                        pool.return client2, (err)->
                          should.not.exist err
                          pool.return client1, (err)->
                            should.not.exist err
                            pool.close (err)->
                              should.not.exist err
                              done()
              return null

            it 'supports borrow, execute, return, borrow,  execute, return pattern (max_idle=1,min_idle=0)', (done)->
              options = { max_idle:1,min_idle:0 }
              pool = new pg.PostgreSQLClientPool2(CONNECT_STRING)
              pool.open options,(err)->
                should.not.exist err
                pool.borrow (err,client1)->
                  should.not.exist err
                  should.exist client1
                  client1.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [32,18], (err,results)->
                    should.not.exist err
                    should.exist results
                    should.exist results.rows
                    results.rows.length.should.equal 1
                    results.rows[0].x.should.equal 32
                    results.rows[0].y.should.equal 18
                    pool.return client1, (err)->
                      should.not.exist err
                      pool.borrow (err,client2)->
                        should.not.exist err
                        should.exist client2
                        client2.execute "SELECT ?::INTEGER AS x, ?::INTEGER AS y", [1,5], (err,results)->
                          should.not.exist err
                          should.exist results
                          should.exist results.rows
                          results.rows.length.should.equal 1
                          results.rows[0].x.should.equal 1
                          results.rows[0].y.should.equal 5
                          pool.return client2, (err)->
                            should.not.exist err
                            pool.close (err)->
                              should.not.exist err
                              done()
              return null

          #--------------------------------------------------------------------#
          # END OF TESTS TO EXECUTE WHEN PG INSTANCE IS AVAILABLE
          #--------------------------------------------------------------------#

        done()
      return null
