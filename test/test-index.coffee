should    = require 'should'
index     = require('../lib/index')

describe "index",->

  expected = [
    'ConnectionFactory'
    'SQLClient'
    'SQLClientPool'
    'SQLRunner'
    'Transaction'
    # 'PostgreSQLClient'
    # 'MySQLClient'
    # 'SQLite3Client'
    # ['bin','PostgreSQLRunner']
    # ['bin','MySQLRunner']
    # ['bin','SQLite3Runner']
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
