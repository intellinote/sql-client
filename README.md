# SQL-Client

**sql-client** is a [Node.js](http://nodejs.org/) library that defines
a simple and consistent abstraction for interacting with a relational
database.

Currently PostgeSQL, MySQL and SQLite3 are supported, and support for
additional database platforms isn't difficult to implement.

<!-- toc -->

* [SQL-Client](#sql-client)
	* [Installing](#installing)
	* [Using](#using)
		* [SQLClient](#sqlclient)
		* [SQLClientPool](#sqlclientpool)
		* [Transactions](#transactions)
	* [Contents](#contents)
		* [Generic Types](#generic-types)
		* [Database-Specific Types](#database-specific-types)
		* [Executables](#executables)
	* [Hacking](#hacking)
		* [Obtaining Make](#obtaining-make)
		* [Basics](#basics)
		* [Using the Makefile](#using-the-makefile)
	* [Licensing](#licensing)
	* [How to contribute](#how-to-contribute)
	* [About Intellinote](#about-intellinote)
		* [Work with Us](#work-with-us)

<!-- tocstop -->

## Installing

The source code and documentation for *sql-client* is available on
GitHub at
[intellinote/sql-client](https://github.com/intellinote/sql-client).
You can clone the repository via:

```bash
git clone git@github.com:intellinote/sql-client
```

*sql-client* is deployed as an [npm module](https://npmjs.org/) under
the name [`sql-client`](https://npmjs.org/package/sql-client). Hence you
can install a pre-packaged version with the command:

```bash
npm install sql-client
```

and you can add it to your project as a dependency by adding a line like:

```javascript
"sql-client": "latest"
```

to the `dependencies` or `devDependencies` part of your `package.json` file.

## Using

Let's use `MySQLClient` and `MySQLClientPool` as an
example. These classes extend `SQLClient` and `SQLClientPool`,
respectively. (Also see `PostgreSQLClient` and `SQLite3Client`.)

### SQLClient

Ignoring error handling (i.e., not checking for errors passed to the
callbacks), a basic end-to-end example of using `MySQLClient` to query the
database looks like this:


```javascript
var mysql = require('sql-client');
var params = { host: 'localhost', user: 'scott', password: 'tiger' };
var client = new mysql.MySQLClient(params);
client.connect( function(err) {
  client.execute( "SELECT ? + 3 AS x", [ 4 ], function (err,rows,fields) {
    console.log("The answer is",rows[0].x);
    client.disconnect();
  });
});
```

Actually, the `client.connect` call is optional, since it will be
automatically invoked by `client.execute` if it hasn't been called
yet. Hence the query above is equivalent to:


```javascript
var mysql = require('sql-client');
var params = { host: 'localhost', user: 'scott', password: 'tiger' };
var client = new mysql.MySQLClient(params);
client.execute( "SELECT ? + 3 AS x", [ 4 ], function (err,rows,fields) {
  console.log("The answer is",rows[0].x);
  client.disconnect();
});
```

### SQLClientPool

The `SQLClientPool` type adds basic connection pooling logic (for
database clients that don't provide native pooling).

When using a pool, we obtain a `SQLClient` instance by calling
`SQLClientPool.borrow` and must take care to return it by calling
`SQLClientPool.return` when we are done with it.

For your convenience, you can encapsulate the `borrow` and `return` sequence with a single call, `execute`.

For example:

```javascript
var mysql = require('sql-client');
var params = { host: 'localhost', user: 'scott', password: 'tiger' };

function setupPool(callback) {
  params.max_idle = 3;
  var pool = new mysql.MySQLClientPool(params);
  pool.open( function(err) { callback(pool); } );
}

function teardownPool(pool) {
  pool.close();
}

function runQuery(callback) {
  pool.execute( "SELECT ? + 3 AS x", [ 4 ], function (err,rows,fields) {
    console.log("The answer is",rows[0].x);
    callback();
  });
}

setupPool( function(pool) {
  runQuery( function() {
    teardownPool( pool );
  });
});
```

### Transactions

The `SQLClientPool` provides convenience methods that make it easy to work with transactions.

To create a transaction, call the `SQLClientPool` method `create_transaction`.  The returned object will look very much like the underlying pool, but it also includes `begin`, `commit` and `rollback` methods.


For example:

```javascript
var mysql = require('sql-client');
var params = { host: 'localhost', user: 'scott', password: 'tiger' };

function setupPool(callback) {
  params.max_idle = 3;
  var pool = new mysql.MySQLClientPool(params);
  pool.open( function(err) { callback(pool); } );
}

function teardownPool(pool) {
  pool.close();
}

function runQuery(callback) {
  transaction = pool.create_transaction();
  transaction.execute( "SELECT ? + 3 AS x", [ 4 ], function (err,rows,fields) {
    if (err) {
      transaction.rollback(function() { callback(err); });
    } else {
      console.log("The answer is",rows[0].x);
      transaction.commit(callback);
    }
  });
}

setupPool( function(pool) {
  runQuery( function() {
    teardownPool( pool );
  });
});
```

## Contents

*sql-client* provides the following.

### Generic Types

 * **SQLClient** - an "abstract" base class for SQL clients, offering
   a simple and consistent `connect`, `execute`, `disconnect` API.

 * **SQLClientPool** - an simple, configurable connection pool for
   `SQLClient` instances.

 * **ConnectionFactory** - an "abstract" base class that defines the
   methods you'll need to implement to support a specific database.

   Specifically, you'll need to implement:

     - `open_connection`
     - `close_connection`
     - `execute`

   Once defined, a `ConnectionFactory` can be dropped right in to the
   `SQLClient` and `SQLClientPool` types to acquire the interface and
   functionality they provide.

### Database-Specific Types

The *sql-client* module bundles support for several database
platforms.  Specifically:

 * **PostgreSQLClient** / **PostgreSQLClientPool** -
   a `ConnectionFactory` implementation that wraps
   [*node-postgres*](https://github.com/brianc/node-postgres).

 * **PostgreSQLClient2** / **PostgreSQLClientPool2** -
   a `ConnectionFactory` implementation that wraps
   [*node-postgres*](https://github.com/brianc/node-postgres)
   but using node-postgres's built in pooling. (This client should
   be used with sql-client pool with max_idle = 0 to allow
   node-postgres to handle the pooling directly.)

 * **MySQLClient** / **MySQLClientPool** -
   a `ConnectionFactory` implementation that wraps
   [*mysql*](https://github.com/felixge/node-mysql/).

 * **SQLite3Client** / **SQLite3ClientPool** -
   a `ConnectionFactory` implementation that wraps
   [*sqlite3*](https://github.com/mapbox/node-sqlite3).

These clients are generally implemented as thin wrappers around
existing database-specific client modules.

Those database-specific modules are declared as `devDependencies` in
this module's `package.json` file, and hence are not needed at
runtime.

When `sql-client` is `require`d, it will test to see if the requisite
client libraries are available.  The database-specific components of
*sql-client* will only be loaded (and exported) if the underlying
libraries they depend upon are available.

Hence, for example, the `PostgreSQLClient` and `PostgreSQLClientPool`
classes depend on
[*node-postgres*](https://github.com/brianc/node-postgres).

To use *sql-client* with PostgreSQL, you'll need to install both
*node-postgres* (`npm install pg`) and *sql-client* (`npm install
sql-client`).  In your `package.json` file, that would look something
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

 * `make docs` - generate HTML documentation from markdown files and
   annotated source code.

 * `make docco` - generate an HTML rendering of the annotated source
   code into the `docs/docco` directory.

 * `make coverage` - generate a test-coverage report (to the file
   `docs/coverage.html`).

 * `make module` - package the module for upload to npm.

 * `make test-module-install` - generates an npm module from this
   repository and validates that it can be installed using npm.


## Licensing

The amqp-util library and related documentation are made available
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

**Please Note:** We'd rather have a contribution that doesn't follow
these guidelines than no contribution at all.  If you are confused or
put-off by any of the above, your contribution is still welcome.  Feel
free to contribute or comment in whatever channel works for you.

---

[![Intellinote](https://www.intellinote.net/wp-content/themes/intellinote/images/logo@2x.png)](https://www.intellinote.net/)

## About Intellinote

Intellinote is a multi-platform (web, mobile, and tablet) software
application that helps businesses of all sizes capture, collaborate
and complete work, quickly and easily.

Users can start with capturing any type of data into a note, turn it
into a task, assign it to others, start a discussion around it, add a
file and share – with colleagues, managers, team members, customers,
suppliers, vendors and even classmates. Since all of this is done in
the context of Private and Public Workspaces, users retain end-to-end
control, visibility and security.

For more information about Intellinote, visit
<https://www.intellinote.net/>.

### Work with Us

Interested in working for Intellinote?  Visit
[the careers section of our website](https://www.intellinote.net/careers/)
to see our latest technical (and non-technical) openings.

---
