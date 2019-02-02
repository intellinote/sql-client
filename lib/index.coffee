path      = require 'path'

export_source_file = (file)->
  target = exports
  exported = require(file)
  for k,v of exported
    target[k] = v

sources = [
  './connection-factory'
  './sql-client'
  './sql-client-pool'
  './sql-runner'
 ]

for file in sources
  export_source_file(file)

conditional_sources = [
  ['pg', './postgresql-client' ]
  ['pg', './bin/postgresql-runner' ]
  ['mysql', './mysql-client' ]
  ['mysql', './bin/mysql-runner' ]
  ['sqlite3', './sqlite3-client' ]
  ['sqlite3', './bin/sqlite3-runner' ]
 ]

for [required_module, file] in conditional_sources
  try
    require(required_module)
    export_source_file(file)
  catch err
    # ignored; required module not available so do not load source file
