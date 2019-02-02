fs               = require 'fs'
path             = require 'path'
HOMEDIR          = path.join(__dirname,'..','..')
LIB_COV          = path.join(HOMEDIR,'lib-cov')
LIB_DIR          = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
SQLRunner        = require( path.join(LIB_DIR,'sql-runner') ).SQLRunner
SQLite3Client    = require( path.join(LIB_DIR,'sqlite3-client') ).SQLite3Client
Util             = require( path.join(LIB_DIR,'util') ).Util

class SQLite3Runner extends SQLRunner
  constructor:(opts,options)->
    super()
    if opts? and typeof opts is 'object' and not options?
      options = opts
      opts = null
    client = null
    if opts?
      client = new SQLite3Client(opts)
    @_init(client,options)

  set_client:(client)=>
    unless client.execute?
      client = new  SQLite3Client(client)
    super(client)

  _get_options:(additional={})=>
    sqlite_opts = {
      d: { alias: 'db',  describe: "Databse connect string." }
    }
    super(Util.merge(sqlite_opts,additional))

  _handle_argv:(argv)=>
    if argv.db?
      @set_client(argv.db)
    super(argv)

  _stringify_results:(rows,tail...)=>
    if rows?
      return JSON.stringify(rows,null,2)
    else
      super(rows,tail...)

exports.SQLite3Runner = SQLite3Runner

if require.main is module
  (new SQLite3Runner()).main()

# EXAMPLE
#
#   echo "SELECT 3+5 as FOO" | coffee lib/bin/sqlite3-runner.coffee --db ":memory:"
#
# or
#
#   echo "SELECT 3+5 as FOO" | ./bin/sqlite3-runner --db ":memory:"
