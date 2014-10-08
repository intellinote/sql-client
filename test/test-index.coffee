should    = require 'should'
fs        = require 'fs'
path      = require 'path'
HOMEDIR   = path.join __dirname, '..'
LIB_COV   = path.join HOMEDIR, 'lib-cov'
LIB       = path.join HOMEDIR, 'lib'
LIB_DIR   = if fs.existsSync(LIB_COV) then LIB_COV else LIB
index     = require(path.join(LIB_DIR,'index'))

describe "index",->

  it "exports SQLClient", (done)->
    index.SQLClient.should.exist
    done()

  it "exports SQLClientPool", (done)->
    index.SQLClientPool.should.exist
    done()

  it "exports PostgreSQLClient", (done)->
    index.PostgreSQLClient.should.exist
    done()
