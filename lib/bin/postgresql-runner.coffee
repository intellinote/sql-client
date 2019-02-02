fs               = require 'fs'
path             = require 'path'
HOMEDIR          = path.join(__dirname,'..','..')
LIB_COV          = path.join(HOMEDIR,'lib-cov')
LIB_DIR          = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
SQLRunner        = require( path.join(LIB_DIR,'sql-runner') ).SQLRunner
PostgreSQLClient = require( path.join(LIB_DIR,'postgresql-client') ).PostgreSQLClient
Util        = require( path.join(LIB_DIR,'util') ).Util

class PostgreSQLRunner extends SQLRunner
  constructor:(connect_string,options)->
    super()
    if connect_string? and typeof connect_string is 'object' and not options?
      options = connect_string
      connect_string = null
    client = null
    if connect_string?
      client = new PostgreSQLClient(connect_string)
    @_init(client,options)

  set_client:(client)=>
    unless client.execute?
      client = new PostgreSQLClient(client)
    super(client)

  _get_options:(additional={})=>
    pg_opts = {
      d: { alias: 'db',  describe: "Databse connect string." }
    }
    super(Util.merge(pg_opts,additional))

  _handle_argv:(argv)=>
    if argv.db?
      @set_client(argv.db)
    super(argv)

  _stringify_results:(results...)=>
    if results?[0]?.rows?
      return JSON.stringify(results[0].rows,null,2)
    else
      super(results...)

exports.PostgreSQLRunner = PostgreSQLRunner

if require.main is module
  (new PostgreSQLRunner()).main()


# EXAMPLE
#
#   echo "SELECT 3+5 as FOO" | coffee lib/bin/postgresql-runner.coffee --db postgres://sqlclient_test_user:password@localhost/sqlclient_test_db
#
# or
#
#   echo "SELECT 3+5 as FOO" | ./bin/postgresql-runner --db postgres://sqlclient_test_user:password@localhost/sqlclient_test_db
