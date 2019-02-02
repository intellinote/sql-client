fs          = require 'fs'
path        = require 'path'
HOMEDIR     = path.join(__dirname,'..','..')
LIB_COV     = path.join(HOMEDIR,'lib-cov')
LIB_DIR     = if fs.existsSync(LIB_COV) then LIB_COV else path.join(HOMEDIR,'lib')
SQLRunner   = require( path.join(LIB_DIR,'sql-runner') ).SQLRunner
MySQLClient = require( path.join(LIB_DIR,'mysql-client') ).MySQLClient
Util        = require( path.join(LIB_DIR,'util') ).Util

class MySQLRunner extends SQLRunner
  constructor:(connect_string,options)->
    super()
    if connect_string? and typeof connect_string is 'object' and not options?
      options = connect_string
      connect_string = null
    client = null
    if connect_string?
      client = new MySQLCLient(connect_string)
    @_init(client,options)

  set_client:(client)=>
    unless client.execute?
      client = new MySQLClient(client)
    super(client)

  _get_options:(additional={})=>
    my_opts = {
      d: { alias: 'db',  describe: "Databse connect string." }
    }
    super(Util.merge(my_opts,additional))

  _handle_argv:(argv)=>
    if argv.db?
      @set_client(argv.db)
    super(argv)

  _stringify_results:(rows,fields,other...)=>
    if rows?
      return JSON.stringify(rows,null,2)
    else
      super(rows,fields,other...)

exports.MySQLRunner = MySQLRunner

if require.main is module
  (new MySQLRunner()).main()

# EXAMPLE
#
#   echo "SELECT 3+5 as FOO" | coffee lib/bin/mysql-runner.coffee --db "mysql://sqlclient_test_u:password@localhost/sqlclient_test_db"
#
# or
#
#   echo "SELECT 3+5 as FOO" | ./bin/mysql-runner --db "mysql://sqlclient_test_u:password@localhost/sqlclient_test_db"
