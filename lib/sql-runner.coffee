fs   = require 'fs'
Util = require('./util').Util

class SQLRunner

  stop_on_error: false

  constructor:(client,options)->
    if client? or options?
      @_init(client,options)

  _init:(client,options)=>
    if client? and not options? and not client.execute?
      options = client
      client = null
    if not client? and options?.client?
      client = options.client
      options.client = null
    if options?
      for f in ['stop_on_error']
        @[f] = options[f] if options[f]
    if client?
      @set_client(client)

  set_client:(client)=>
    @client = client

  close:(callback)=>
    if @client?
      @client.disconnect(callback)
    else
      callback?()

  execute:(sql,callback)->
    responses  = []
    error = null
    if Array.isArray(sql)
      action = (stmt,index,list,next)=>
        @client.execute stmt, (err,tail...)=>
          responses.push [err].concat(tail)
          if err?
            error = err
            if stop_on_error
              callback(error,responses)
            else
              next()
          else
            next()
      when_done = ()=>
        callback(error,responses)
      Util.for_each_async(sql,action,when_done)
    else
      @client.execute(sql,callback)

  execute_file:(file,encoding,callback)=>
    if not callback? and typeof encoding is 'function'
      callback = encoding
      encoding = null
    options = {}
    options.encoding = encoding if encoding?
    fs.readFile file, options, (err,data)=>
      unless Util.handle_error(err,callback)
        execute(data.toString(),callback)

  _BASE_OPTIONS: {
    h: { alias: 'help',    boolean:true, describe: "Show help" }
    v: { alias: 'verbose', boolean:true, describe: "Be more chatty." }
    q: { alias: 'quiet',   boolean:true, describe: "Be less chatty." }
    'stop-on-error': { alias: 'stop_on_error',   boolean:true, describe: "Stop on error" }
  }

  _get_options:(additional={})=>
    Util.merge(@_BASE_OPTIONS,additional)

  _handle_argv:(argv)=>
    argv.v = argv.verbose = false if argv.quiet
    return argv

  _stringify_results:(results...)=>
    return JSON.stringify(results,null,2)

  main:(argv,logfn,errfn,callback)=>
    # set default arguments
    if errfn? and not callback?
      callback = errfn
      errfn = null
    if logfn? and not callback?
      callback = lognf
      logfn = null
    argv ?= process.argv
    logfn ?= console.log
    errfn ?= console.error
    callback ?= process.exit
    # swap out process.argv so that yargs reads the function argument
    original_argv = process.argv
    process.argv = argv
    # perform the rest of the operation in a try block so we can be
    # sure to restore process.argv when we're finished.
    try
      # read command line parameters using node-yargs
      yargs = require('yargs')
      argv = yargs.options(@_get_options()).usage('Usage: $0 [OPTIONS]').argv
      argv = @_handle_argv(argv)
      # handle help
      if argv.help
        yargs.showHelp(errfn)
        callback()
      else
        # make sure we've got a client to run with
        unless @client
          errfn("SQLClient not configured.") unless argv.quiet
          callback(3)
        else
          # read input files or stdin using node-argf
          ARGF = require('argf')
          argf = new ARGF(argv._)
          # after all data has been read, execute the input sql
          argf.on 'finished', ()=>
            sql = buffer.join("\n")
            if argv.verbose
              logfn "Read #{sql.length} character(s) in #{buffer.length} line(s)."
            if sql.length is 0
              unless argv.quiet
                errfn "No input found. Cannot continue. (Try --help for help.)"
              callback(2)
            else
              if argv.verbose
                logfn "Executing."
            @execute sql,(err,result...)=>
              if err?
                unless argv.quiet
                  errfn "ERROR" if argv.verbose
                  errfn "Encountered error:",err
                  errfn "while executing SQL:\n",sql
                callback(1)
              else
                logfn "SUCCESS" if argv.verbose
                unless argv.quiet
                  logfn(@_stringify_results(result...))
                callback()
          # create one big buffer containing all input data
          if argv.verbose
            if argv._?.length > 0
              logfn "Reading from #{argv._?.length} input files."
            else
              logfn "Reading from stdin."
          buffer = []
          argf.forEach (line)=>
            buffer.push line
    finally
      process.argv = original_argv

exports.SQLRunner = SQLRunner
