should    = require 'should'
fs        = require 'fs'
path      = require 'path'
HOMEDIR   = path.join __dirname, '..'
LIB_COV   = path.join HOMEDIR, 'lib-cov'
LIB       = path.join HOMEDIR, 'lib'
LIB_DIR   = if fs.existsSync(LIB_COV) then LIB_COV else LIB
index     = require(path.join(LIB_DIR,'index'))

describe "index",->

  expected = [
    'ConnectionFactory'
    'SQLClient'
    'SQLClientPool'
    'PostgreSQLClient'
    'MySQLClient'
    'SQLite3Client'
    'SQLRunner'
    ['bin','PostgreSQLRunner']
    ['bin','MySQLRunner']
    ['bin','SQLite3Runner']
  ]

  for expect in expected
    it "exports #{expect.toString()}", (done)->
      unless Array.isArray(expect)
        expect = [expect]
      map = index
      while expect.length > 0
        map = map[expect.shift()]
        map.should.exist
      done()
