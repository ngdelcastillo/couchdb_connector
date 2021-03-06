# CouchdbConnector

[![Build Status](https://travis-ci.org/locolupo/couchdb_connector.svg)](https://travis-ci.org/locolupo/couchdb_connector)
[![Coverage Status](https://coveralls.io/repos/locolupo/couchdb_connector/badge.svg?branch=master&service=github)](https://coveralls.io/github/locolupo/couchdb_connector?branch=master)
[![Hex.pm](https://img.shields.io/hexpm/v/couchdb_connector.svg?style=flat-square)](https://hex.pm/packages/couchdb_connector)
[![Stories in Ready](https://badge.waffle.io/locolupo/couchdb_connector.png?label=ready&title=Ready)](https://waffle.io/locolupo/couchdb_connector)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/couchdb_connector/)

## Description

A connector for CouchDB, the Erlang-based, JSON document database.

The connector does not implement the protocols defined in Ecto.
Reasons: CouchDB does not support transactions as known in the world of
ACID compliant, relational databases.
The concept of migrations also does not apply to CouchDB.
And since CouchDB does not implement an SQL dialect, the decision was taken
to not follow the standards established by Ecto.

The connector offers create, update and read operations through its
Writer and Reader modules.
Basic support for view operations is provided by the View module.

All create and update operations expect valid JSON documents. All read
operations return JSON strings exactly as they come from CouchDB.

The connector also offers functions to manage users and admins. These functions
have been implemented to support testing of authentication and most users will
probably manage users through different tools.

Basic access authentication (basic auth) is currently the only supported
authentication scheme.

## Supported platforms

This library has been tested successfully with Elixir release versions 1.0.5,
1.1.1 and 1.2.5, using CouchDB version 1.6.1.

## Installation

The module is [available in Hex](https://hex.pm/packages/couchdb_connector), the package can be installed as follows:

  1. Add couchdb_connector to your list of dependencies in `mix.exs`:

```Elixir
def deps do
  [{:couchdb_connector, "~> 0.3.0"}]
end
```

  2. Ensure couchdb_connector is started before your application:

```Elixir
def application do
  [applications: [:couchdb_connector]]
end
```

## Usage

For the subsequent steps, let's assume that we work in iex and that we define these database properties:

```Elixir
db_props = %{protocol: "http", hostname: "localhost",database: "couchdb_connector_dev", port: 5984}
```

### Create a database

```Elixir
Couchdb.Connector.Storage.storage_up(db_props)
```

You should see

```Elixir
{:ok, "{\"ok\":true}\n"}
```

In case the database already exists of course, you would see

```Elixir
{:error,
  "{\"error\":\"file_exists\",\"reason\":\"The database could not be created, the file already exists.\"}\n"}
```

### Write to a database

Now that the database exits, we can create documents in it.

```Elixir
Couchdb.Connector.Writer.create(db_props, "{\"key\": \"value\"}")
```

You should see something similar to this

```Elixir
{:ok,
  "{\"ok\":true,\"id\":\"6b66e9bd59c1c35f3ab51165b10889a7\",\"rev\":\"1-59414e77c768bc202142ac82c2f129de\"}\n",
    [{"Server", "CouchDB/1.6.1 (Erlang OTP/18)"},
    {"Location",
    "http://localhost:5984/couchdb_connector_dev/6b66e9bd59c1c35f3ab51165b10889a7"},
    {"ETag", "\"1-59414e77c768bc202142ac82c2f129de\""},
    {"Date", "Sun, 27 Dec 2015 22:28:15 GMT"},
    {"Content-Type", "text/plain; charset=utf-8"}, {"Content-Length", "95"},
    {"Cache-Control", "must-revalidate"}]}
```

In the previous example, we had CouchDB assign a generated id to the document. This will do for most cases. In case you want to provide an id and you are sure that it does not yet exist in the database, you can do this:

```Elixir
Couchdb.Connector.Writer.create(db_props, "{\"key\": \"value\"}", "unique_id")
```

You should then see something like

```Elixir
{:ok,
  "{\"ok\":true,\"id\":\"unique_id\",\"rev\":\"1-59414e77c768bc202142ac82c2f129de\"}\n",
    [{"Server", "CouchDB/1.6.1 (Erlang OTP/18)"},
    {"Location", "http://localhost:5984/couchdb_connector_dev/unique_id"},
    {"ETag", "\"1-59414e77c768bc202142ac82c2f129de\""},
    {"Date", "Sun, 27 Dec 2015 22:32:45 GMT"},
    {"Content-Type", "text/plain; charset=utf-8"}, {"Content-Length", "72"},
    {"Cache-Control", "must-revalidate"}]}
```

### Read from a database

Given we have a document under the id "unique_id" in the database that we created in one of the steps above, the following "GET" should return the desired document.

So let's try

```Elixir
Couchdb.Connector.Reader.get(db_props, "unique_id")
```

You should see something akin to this:

```Elixir
{:ok,
  "{\"_id\":\"unique_id\",\"_rev\":\"1-59414e77c768bc202142ac82c2f129de\",\"key\":\"value\"}\n"}
```

In case you ask for a non existing document, like in this example

```Elixir
Couchdb.Connector.Reader.get(db_props, "wrong_id")
```

You should see something this:

```Elixir
{:error,  "{\"error\":\"not_found\",\"reason\":\"missing\"}\n"}
```

### Create a View

CouchDB [Views](http://guide.couchdb.org/editions/1/en/views.html) are defined in JavaScript and consist of mappers and (optional) reducers. Views are grouped together in CouchDB in what is known as Design Documents.

Let's assume that you want to create one or more Views as part of a seeding process. In order to do so, you can encode your Views in JSON files as follows:

```JSON
{
  "_id" : "_design/example",
  "views" : {
    "by_name" : {
      "map" : "function(doc){ emit(doc.name, doc)}"
    }
  }
}
```

Creating this View can then be done through the connector like this:

```Elixir
{:ok, code} = File.read("path/to/view.json")
{:ok, _} = Couchdb.Connector.View.create_view(db_props, "example", code)
```

where "example" is the name of the design document and code now contains the JavaScript as read from file.

You should see something like

```Elixir
{:ok,
 "{\"ok\":true,\"id\":\"_design/example\",\"rev\":\"1-175ebbcc6e519413aeb640e8fc63424d\"}\n"}
```

### Query a View

Querying a View can be done like this:

```Elixir
{:ok, result} = Couchdb.Connector.View.document_by_key(db_props, "design_name", "view_name", "key")
```

In case the document given by "key" exists, you should see something like
```Elixir
{:ok,
 "{\"total_rows\":3,\"offset\":1,\"rows\":[\r\n{\"id\":\"5c09dbf93fd6226c...\",\"key\":\"key\",..."}
```

otherwise, the response should contain an empty list of rows:
```Elixir
{:ok, "{\"total_rows\":0,\"offset\":0,\"rows\":[\r\n\r\n]}\n"}
```

### Destroy a database

```Elixir
Couchdb.Connector.Storage.storage_down(db_props)
```

You should see

```Elixir
{:ok, "{\"ok\":true}\n"}
```

In case that database never existed, you should see

```Elixir
{:error, "{\"error\":\"not_found\",\"reason\":\"missing\"}\n"}
```

## Next

Love to hear from you. Meanwhile, here are some things we'd like to tackle next:

- enhance view handling and query capabilities
- implement wrappers to take / return Maps instead of JSON strings only
- cookie auth, oauth auth
- attachment support
