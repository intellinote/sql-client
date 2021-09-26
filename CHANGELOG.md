# SQL-Client Change Log

## v3.0.0 - 26 September 2021

Notable changes:

  * External dependencies upgraded to latest stable release, including:
    * Production Dependencies (`dependencies`):
      * `yargs` updated to v17
    * Peer Dependencies:
      * `pg` updated to v8 (although v7 still works also)
      * `sqlite3` updated to v5 (although v4 still works also)
    * `devDependencies`
      * `mocha` updated to v9
      * `nyc` updated to v15
      * `should` updated to v13
    * Other
      * Node version (`engines` section of `package.json`) bumped up to v12 although everything from Node v8 to Node v14 should still be compatiable. In particular SQL-Client v3 has been tested on Node 12, 13 and 14.

  * API Changes

    * *NOTE: There shouldn't really be any breaking changes here relative to the v2 API but it seemed worthy of a major version update regardless. See the root-level README.md file for more detail on the updated API.*

    * The `Transaction` class can now be used to wrap a stand-alone instance of `SQLClient` via  `new Transaction(sql_client_instance)`. (Previous versions were only available via `SQLClientPool.create_transaction`.)

    * The `SQLClient.connect` and `SQLClient.disconnect` methods now support an optional `options` parameter (i.e., both methods now support a `(callback)` and an `(options, callback)` signature).

      * The `options` parameter is currently ignored in all cases but one: The `PostgreSQLClient2` implementation accepts an option labelled `end_pg_pool` in the `disconnect` method. When truthy, the `end` method will be called on underlying (node-postgres-based) connection, closing the underlying pooled connection. This is primarily useful for allowing the node process to terminate right away (rather than waiting a few seconds for node-postgres to decided the pool is safe to close).

      * A similar optional `options` parameter has been added to the `Transaction.commit` and `Transaction.rollback` methods, for the same reason.

    * A `disconnect_and_end` method has been added to `PostgreSQLClient2` for which is `disconnect_and_end(callback)` is equivalent to `disconnect({end_pg_pool:true}, callback)`.

      * Similar `Transaction.commit_and_end` and `Transaction.rollback_and_end` methods have been added to `Transaction` for the same reason and with the same logic, however this will have no practical effect for transactions based on any `SQLClient` instance other than `PostgreSQLClient2`

  * Other Changes: Both the documentation and test suite have been updated and expanded.
