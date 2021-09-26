# SQL-Client

**sql-client** is a [Node.js](http://nodejs.org/) library that defines
a simple and consistent abstraction for interacting with a relational
database.

## Features

 * Simple and consistent API for multiple databases. (Currently PostgeSQL, MySQL and SQLite3 are supported, and support for additional database platforms shouldn't be difficult to implement.)

 * Prepared-statement-aware, with consistent `?`-based bind-variable syntax. (Eliminating need for `$n`-style bindvar matching in PostgreSQL, although either style *may* be used.)

 * Easy-to-use [transaction API](#transactions) with near seamless substitution between transactional and non-transactional database interactions.

 * Built-in (but optional) connection pooling, with:
   * pass-thru support to database-native pooling mechanism where available
	 * configurable active and idle connection caps
	 * configurable wait/block/grow/fail behavior when all connections are in use
	 * optional keep-alive-while-idle, validation, automatic-retrieval and eviction policies

 * Batch (multi-statement) "SQL runner" available, with API and stand-alone command-line interfaces.

 * Small library with limited external dependencies.

## Examples

### Executing a Query

```javascript
var sql_client = require('sql-client')
var client = new sql_client.PostgreSQLClient("postgres://uname:passwd@localhost/dbname")
client.execute( "SELECT 1 + ? AS x", [ 2 ], function (err, resultset) {
  console.log("The result is", resultset.rows[0].x) // yields `3`
  client.disconnect()
});
```

### DDL, DML, or DQL

```javascript
var sql_client = require('sql-client')
var client = new sql_client.PostgreSQLClient("postgres://uname:passwd@localhost/dbname")

function create_table(client, callback) {
  sql = "CREATE TABLE employee ( name VARCHAR(64), salary INTEGER )"
  client.execute( sql, callback );
}

function insert_record(client, name, salary, callback) {
  sql = "INSERT INTO employee ( name, salary ) VALUES ( ?, ? )"
  client.execute( sql, [ name, salary ], callback )
}

function list_records(client, callback) {
  sql = "SELECT * FROM employee ORDER BY salary DESC"
  client.execute( sql, function(err, resultset) {
    if (err) {
      callback(err)
    } else {
      console.log("NAME\tSALARY")
      for (i=0;i<resultset.rows.length;i++) {
        console.log(resultset.rows[i].name, resultset.rows[i].salary)
      }
      callback()
    }
  }
}
create_table( client, function() {
  insert_record( client, "Smith", 64000, function() {
    insert_record( client, "Hsu", 80000, function() {
      list_records( client, function() {
        client.disconnect()
      })
    })
  })
})
```

### Connection Pooling

```javascript
var sql_client = require('sql-client')

// configure and open the pool
var pool = new sql_client.PostgreSQLClientPool("postgres://uname:passwd@localhost/dbname")
var pool_options = {
  max_idle  : 3 // max number of idle connections to keep waiting in pool
  max_active: 5 // max number of active connections to allow at one time
}
pool.open( pool_options, function() {

  // automatically borrow and return across a single statement
  pool.execute( "SELECT 1 + ? AS x", [ 2 ], function (err, resultset) {
    console.log("The result is", resultset.rows[0].x) // yields `3`

    // or manually borrow and return for multiple statements
    pool.borrow( function(err, connection) {
      connection.execute("SELECT ...", function() {
        connection.execute("SELECT ...", function() {
          // ...and return when done
          pool.return(connection, function(){

            // close the pool to close all underlying connections
            pool.close()

          }) // (end pool.return callback)
        })
      })
    }) // (end pool.borrow callback)

  }) // (end outer pool.execute callback)

}) // (end pool.open callback)
```

### Transactions

#### Via SQLClient Wrapper

```javascript
var sql_client = require('sql-client')
var transaction = new Transaction(
  new sql_client.PostgreSQLClientPool("postgres://uname:passwd@localhost/dbname")
)
transaction.execute( "INSERT INTO employee ( name, salary )", [ "Jones", 40000 ], function (err) {
  if (err) {
    transaction.rollback(function() { callback(err); });
  } else {
    transaction.commit(callback);
  }
})
```

#### Via SQLClientPool

```javascript
var sql_client = require('sql-client')
var pool = new sql_client.PostgreSQLClientPool("postgres://uname:passwd@localhost/dbname")
pool.open( function() {

  // works just like a regular client, but with commit and rollback methods
  var transaction = pool.create_transaction();
  transaction.execute( "INSERT INTO employee ( name, salary )", [ "Jones", 40000 ], function (err) {
    if (err) {
      transaction.rollback(function() { callback(err); });
    } else {
      transaction.commit(callback);
    }
  })

})
```

## Installing

### Via NPM

sql-client is deployed as an [npm module](https://npmjs.org/) under
the name [`sql-client`](https://npmjs.org/package/sql-client). Hence you
can install a pre-packaged version with the command:

```bash
npm install sql-client
```

and you can add it to your project as a dependency by adding a line like:

```json
"sql-client": "latest"
```

to the `dependencies` or `devDependencies` section of your `package.json` file.

> NOTE: You will also need to install the "native" client library for the
database you are using. [See below for details.](#database-specific-dependencies)

### From Source

The source code and documentation for *sql-client* is available on
GitHub at [intellinote/sql-client](https://github.com/intellinote/sql-client).

You can clone the repository via:

```bash
git clone git@github.com:intellinote/sql-client
```

See the ["Hacking"](#hacking) section below for tips on working with
the source code.

### Database-Specific Dependencies

In order to minimize external dependencies, although this library supports
multiple database implementations it does not specify any of the "native"
database-specific clients as a direct dependency. Instead, the specific
database-client implementations that are exposed are determined at runtime,
based on the third-party libraries that are available.

That means that in order to use sql-client with given database type you'll
need to install one of the database-specific client libraries as a peer
dependency. I.e., in addition to `sql-client` you'll want to add one (or more)
of the following to the `dependencies` or `devDependencies` section of your
`package.json` file:

 * For PostgreSQL, use `npm install pg` (or add `"pg":"latest"` in your `package.json`) to install [node-postgres](https://www.npmjs.com/package/pg). Versions 7 and 8 of node-postgres are known to be supported. (Others are likely to be supported as well, but haven't necessarily been tested.)

 * For MySQL, use `npm install mysql` (or add `"mysql":"latest"` in your `package.json`) to install [mysql](https://www.npmjs.com/package/mysql). Version 2 of mySQL is known to be supported. (Other versions may also work, but haven't necessarily been tested.)

 * For SQLite, use `npm install sqlite3` (or add `"sqlite3":"latest"` in your `package.json`) to install [sqlite3](https://www.npmjs.com/package/sqlite3). Versions 3 and 4 of sqlite3 are known to be supported. (Others may be supported as well, but haven't necessarily been tested.)

NOTE: sql-client works equally well with node-postgres v7 and v8, and with Node.js versions going back well before v14, but according to [this issue](https://github.com/brianc/node-postgres/issues/2317) you should use node-postgres v8 with Node.js version 14 or later. Specifically it seems that node-postgres v7 may hang indefinitely when attempting to connect to the database when running on Node v14. This issue is wholly independent of sql-client, we're just making a note of it because it can be hard to identify the source of the problem if you happen to encounter it.


## API

### SQLClient

`SQLClient` provides the core database-interaction functionality. It is roughly
equivalent to a database "connection".

The abstract interface supports three methods:

#### `SQLClient.connect(options, callback)`

Open a connection to the database (based on the configuration provided to the
database-specific constructor), or in some cases, borrow a connection from the
underlying connection pool.

Parameters:

 * `options` - an optional map of database-specific options
 * `callback` - callback method with the signature `(err)`

The `callback` parameter is technically optional, but the client is not ready
for use (i.e., the `execute` method cannot be called) until the callback (if
provided) is invoked.

The `callback` method should accept a single parameter: an error (exception)
object which will be populated if there was a problem connecting to the
database. If the `err` parameter is undefined or `null`, the client is connected
and ready to be used.

#### `SQLClient.execute(sql, bindvars, callback)`

Executes the given SQL statement, which may be a common CRUD (DQL/DML) statement
like `SELECT` or `INSERT`, a DDL command such as `CREATE TABLE` or `DROP FUNCTION`
or any arbitrary command accepted by the specific database instance (`TRUNCATE`,
`EXPLAIN`, `LOCK`, etc.)

Parameters:

 * `sql` - the SQL statement to execute, as a string

 * `bindvars` - an optional array of bind-variable values; the nth element in the array will be bound to the nth bind variable slot (typically marked by `?`) found in the SQL statement. Note that bind-variable substitution is NOT handled directly within sql-client but passed to the underlying database client library (which in turn submits the bind variables to the database engine itself using the native database network protocol).

 * `callback` - a callback method with a slightly database-dependent signature:
   * in PostgreSQL the signature is `(err, result_set)` where `result_set` is [described here](https://node-postgres.com/api/result). Notably `result_set.rows` is an array of objects representing database records.
   * in SQLite3 the signature is `(err, rows)` where `rows` is an array of objects representing database records.
   * in MySQL the signature is `(err, rows, fields)` where `rows` is an array of objects representing database records and `fields` is a map of meta-data describing the columns in the result set.

#### `SQLClient.disconnect(options, callback)`

Close the connection to the database (or in some cases, return the connection
to the pool). After `disconnect` is called the client can no longer be used.

Parameters:

 * `options` - an optional map of database-specific options
 * `callback` - callback method with the signature `(err)`

### SQLClientPool

A pool of `SQLClient` instances that can be borrowed and returned.

#### `SQLClientPool.open(options, callback)`

Initialize the pool.

Parameters:

 * `options` - an optional map of configuration options, including:
   * `min_idle` - minimum number of idle connections in an "empty" pool (default: 0)
   * `max_idle` - maximum number of idle connections in a "full" pool (default: unset, no limit)
   * `max_active` - maximum number of connections active at one time (default: unset, no limit)
   * `when_exhausted` - what to do when max_active is reached (`grow`,`block`,`fail`) (default: `grow` - i.e., create a new connection anyway)
   * `max_wait` - when `when_exhausted` is `block` max time (in millis) to wait before failure, use < 0 for no maximum (default: unset, no limit)
   * `wait_interval`  - when `when_exhausted` is `BLOCK`, amount of time (in millis) to wait before rechecking if connections are available (default: 50)
   * `max_retries` - number of times to attempt to create another new connection when a newly created connection is invalid; when `null` no retry attempts will be made; when < 0 an infinite number of retries will be attempted (default: unset, no limit)
   * `retry_interval`  - when `max_retries` is > 0, amount of time (in millis) to wait before retrying  (default: 50)
   * `max_age` - when a positive integer, connections that have been idle for `max_age` milliseconds will be considered invalid and eligable for eviction (default: unset, no limit)
   * `eviction_run_interval` - when a positive integer, the number of milliseconds between eviction runs; during an eviction run idle connections will be tested for validity and if invalid, evicted from the pool  (default: unset, no eviction runs)
   * `eviction_run_length` - when a positive integer, the max number of connections to examine per eviction run (when not set, all idle connections will be examined during each eviction run) (default: unset, no limit)
   * `unref_eviction_runner` - unless `false`, [`unref`](https://nodejs.org/api/timers.html#timers_timeout_unref) will be called on the eviction run interval timer, which prevents the eviction-interval timer from keeping the node process alive when no other loops are active (default: true)
 * `callback` - callback method with the signature `(err)`

#### `SQLClientPool.close(callback)`

Terminate the pool, closing any idle connections.

Parameters:
 * `callback` - callback method with the signature `(err)`

#### `SQLClientPool.borrow(callback)`

Borrow a connection from the pool

Parameters:
 * `callback` - callback method with the signature `(err, client)`

#### `SQLClientPool.return(client, callback)`

Return a connection to the pool

Parameters:
* `client` - the previously borrowed client
* `callback` - callback method with the signature `(err)`

#### `SQLClientPool.execute(sql, bindvars, callback)`

Convenience method that is equivalent to borrowing a SQLClient instance,
invoking `execute` on that client then returning the client to the pool.

#### `SQLClientPool.create_transaction()`

Create a database transaction based on a connection borrowed from the pool.

A `Transaction` instance is essentially an extension of `SQLClient` with
additional `commit` and `rollback` methods. Calling one of those methods will
commit or rollback the database transaction and return the underlying
connection to the database.

Note that you can also create a `Transaction` instance that wraps an
instance of `SQLClient` directly (see [below](#transaction)).

### Transaction

A `Transaction` wraps a `SQLClient` instance in a database transaction, adding
`commit` and `rollback` methods that can be used to end the transaction.

A `Transaction` instance is obtained in one of two ways:

1. By passing a `SQLClient` instance to the `Transaction` constructor, as in `new Transaction(new SQLClient(...))`.

2. Via the `create_transaction` method of `SQLClientPool` (which see).

Once your work with the transaction is complete be sure to call
`Transaction.commit` or `Transaction.rollback` to end the transaction. Both
methods accept a callback method with the `(err)` signature.

Once a transaction has been closed via `commit` or `rollback` it can no longer
be used.

Note that you may also `BEGIN` and subsequently `COMMIT` or `ROLLBACK`
directly on the `SQLClient` instance to handle transactions "manually"
(without using `create_transaction` or `new Transaction(sql_client)`).

### Database-Specific Types

The *sql-client* module bundles support for several database
platforms.  Specifically:

 * **PostgreSQLClient** / **PostgreSQLClientPool** - a `ConnectionFactory` implementation that wraps [node-postgres](https://www.npmjs.com/package/pg) (known as `pg` on npm).

 * **PostgreSQLClient2** / **PostgreSQLClientPool2** - a `ConnectionFactory` implementation that wraps [node-postgres](https://www.npmjs.com/package/pg)  but using node-postgres's built in pooling. (This client should be used with sql-client pool with max_idle = 0 to allow node-postgres to handle the pooling directly.)

 * **MySQLClient** / **MySQLClientPool** - a `ConnectionFactory` implementation that wraps
   [mysql](https://www.npmjs.com/package/mysql).

 * **SQLite3Client** / **SQLite3ClientPool** - a `ConnectionFactory` implementation that wraps [sqlite3](https://www.npmjs.com/package/sqlite3)

These clients are generally implemented as thin wrappers around
existing database-specific client modules.

Those database-specific modules are not declared as dependencies in
this module's `package.json` file, and hence are not needed at
runtime.

When `sql-client` is `require`d, it will test to see if the requisite
client libraries are available.  The database-specific components of
*sql-client* will only be loaded (and exported) if the underlying
libraries they depend upon are available.

Hence, for example, the `PostgreSQLClient` and `PostgreSQLClientPool`
classes depend on [*node-postgres*](https://github.com/brianc/node-postgres).

To use *sql-client* with PostgreSQL, you'll need to install both
*node-postgres* (`npm install pg`) and *sql-client* (`npm install
sql-client`). In your `package.json` file, that would look something
like this:

    {
      "dependencies": {
        "pg": "latest",
        "sql-client": "latest"
      },
      "...":"...and so on..."
    }

### Executables

When installed via `npm`, the *sql-client* module exposes a basic
command line tool for executing arbitrary SQL (read from STDIN or
files enumerated on the command line).

For example:

    echo "SELECT 3+5 as FOO" | mysql-runner --db "mysql://sqlclient_test_u:password@localhost/sqlclient_test_db"

    echo "SELECT 3+5 as FOO" | postgresql-runner --db "postgres://sqlclient_test_user:password@localhost/sqlclient_test_db"

    echo "SELECT 3+5 as FOO" | sqlite3-runner --db ":memory:"

These files are available in the `./lib/bin`, or (after `make bin` is
run) in the `./bin` directory, or (after `npm install` is run) in the
`./node_modules/.bin` directory.

Pass the command line parameter `--help` for more help.

## Testing

The [source-code distribution](#from-source) of this module contains a fairly
extensive automated test suite, with ~75% coverage by line count.

These tests can be executed by running `make test` or `npm test`. A test-coverage
report can be generated by running `make coverage`.

You should be able to simply clone the repository and successfully run the
basic test suite (via just `make test` if you're using [the Makefile](#hacking),
or `npm install && npm test` if you are not). There are however a few
additional steps required to run the *full* test suite.

Automated *functional* tests are provided for each of the database-specific
implementations of the core interface (PostgreSQL, MySQL, SQLite). However to
execute these tests the following additional steps are required:

1. You must install the corresponding "native" database client libraries as they are not listed as package dependencies by default. See [the note above](#database-specific-dependencies) for details.

2. In the case of MySQL and PostgreSQL you must set up a local "test" instance of the database for use during the tests. See the [./test/README.md](https://github.com/intellinote/sql-client/blob/master/test/README.md) file for instructions. (Since SQLite is an in-memory database this step is not required to test the sqlite3 implementation.)

If any database-specific library is missing when the test suite is run the corresponding tests will be skipped (but a prominent message will be printed to the console to warn you about this).

If the library is included but the external database instance cannot be reached the corresponding tests will fail (and a warning will be printed directing you to the `test/README.md` file).

For your convenience several targets have been added to the `package.json` file that allow you to run specify test collections:

 * `npm test` (or `npm run-script test-all`) will attempt to run all of the tests (including all database-specific "integration" tests)
 * `npm run-script test-nodb` will run the generic interface tests (those that do not depend on any specific database client library)
 * `npm run-script test-pg` will run the generic interface tests and the PostgreSQL-specific tests (but not SQLite or MySQL)
 * `npm run-script test-sqlite` will run the generic interface tests and the SQLite-specific tests (but not PostgeSQL or MySQL)
 * `npm run-script test-mysql` will run the generic interface tests and the MySQL-specific tests (but not PostgeSQL or SQLite)

### Test Coverage

Run the Makefile target `make coverage` to generate a test coverage report. This will run the full automated test suite and generate a test coverage report (within `./docs/coverage`) that contains an HTMLized view of the source code annotated with information about the functions, branches and lines that were exercised by the test run. As of this writing roughly 75% of the source code lines were touched by the complete automated test suite.

## Hacking

While not strictly required, you are *strongly* encouraged to take
advantage of the [`Makefile`](./Makefile) when working on this module.

[`make`](http://www.gnu.org/software/make/) is a *very* widely
supported tool for dependency management and conditional compilation.

### Obtaining Make

`make` is probably pre-installed on your Linux or Unix distribution (if
not, you can use `rpm`, `yum`, `apt-get`, etc. to install it).

On Mac OSX, one simple way to add `make` to your system is to install
the Apple Developer Tools from <https://developer.apple.com/>.

On Windows, you can install [MinGW](http://www.mingw.org/),
[GNUWin](http://gnuwin32.sourceforge.net/packages/make.htm) or
[Cygwin](https://www.cygwin.com/), among other sources.

### Basics

With `make` installed, run:

    make clean test

to download any missing dependencies, compile anything that needs to
be compiled and run the unit test suite.

Run:

    make docs

to generate various documentation artifacts, largely but not
exclusively in the `docs` directory.

### Using the Makefile

From this project's root directory (the directory containing this
file), type `make help` to see a list of common targets, including:

 * `make install` - download and install all external dependencies.

 * `make clean` - remove all generated files.

 * `make test` - run the unit-test suite.

 * `make bin` - generate the executable scripts in `./bin`.

 * `make coverage` - generate a test-coverage report (to the file
   `docs/coverage.html`).

 * `make module` - package the module for upload to npm.

 * `make test-module-install` - generates an npm module from this
   repository and validates that it can be installed using npm.

## Licensing

The sql-client library and related documentation are made available
under an [MIT License](http://opensource.org/licenses/MIT).  For
details, please see the file [LICENSE.txt](LICENSE.txt) in the root
directory of the repository.

## How to contribute

Your contributions,
[bug reports](https://github.com/intellinote/sql-client/issues) and
[pull-requests](https://github.com/intellinote/sql-client/pulls) are
greatly appreciated.

We're happy to accept any help you can offer, but the following
guidelines can help streamline the process for everyone.

 * You can report any bugs at
   [github.com/intellinote/sql-client/issues](https://github.com/intellinote/sql-client/issues).

    - We'll be able to address the issue more easily if you can
      provide an demonstration of the problem you are
      encountering. The best format for this demonstration is a
      failing unit test (like those found in
      [./test/](https://github.com/intellinote/sql-client/tree/master/test)),
      but your report is welcome with or without that.

 * Our preferred channel for contributions or changes to the source
   code and documentation is as a Git "patch" or "pull-request".

    - If you've never submitted a pull-request, here's one way to go
      about it:

        1. Fork or clone the repository.
        2. Create a local branch to contain your changes (`git
           checkout -b my-new-branch`).
        3. Make your changes and commit them to your local repository.
        4. Create a pull request
           [as described here](https://help.github.com/articles/creating-a-pull-request).

    - If you'd rather use a private (or just non-GitHub) repository,
      you might find
      [these generic instructions on creating a "patch" with Git](https://ariejan.net/2009/10/26/how-to-create-and-apply-a-patch-with-git/)
      helpful.

 * If you are making changes to the code please ensure that the
   [unit test suite](./test) still passes.

 * If you are making changes to the code to address a bug or introduce
   new features, we'd *greatly* appreciate it if you can provide one
   or more [unit tests](./test) that demonstrate the bug or exercise
   the new feature.

 * This module follows the [git-flow](https://nvie.com/posts/a-successful-git-branching-model/) branching model. The `master` branch contains the latest production (released) code. The `develop` branch contains the work-in-progress. It would be best to submit any pull-requests against the `develop` branch.

**Please Note:** We'd rather have a contribution that doesn't follow
these guidelines than no contribution at all.  If you are confused or
put-off by any of the above, your contribution is still welcome.  Feel
free to contribute or comment in whatever channel works for you.
