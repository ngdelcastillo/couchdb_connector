defmodule Couchdb.Connector.SecureReaderTest do
  use ExUnit.Case

  alias Couchdb.Connector.Reader
  alias Couchdb.Connector.TestConfig
  alias Couchdb.Connector.TestPrep
  alias Couchdb.Connector.TestSupport

  setup context do
    TestPrep.ensure_database
    TestPrep.ensure_document "{\"test_key\": \"test_value\"}", "foo"
    on_exit context, fn ->
      TestPrep.delete_test_user
      TestPrep.delete_test_admin
      TestPrep.delete_database
    end
  end

  # Tests for secured database, using basic authentication

  test "get/3: ensure that document exists using basic authentication" do
    TestPrep.secure_database
    { :ok, json } = Reader.get(TestConfig.database_properties, TestSupport.test_user, "foo")
    { :ok, json_map } = Poison.decode json
    assert json_map["test_key"] == "test_value"
  end

  test "fetch_uuid/1: get a single uuid from a secured database server" do
    TestPrep.secure_database
    { :ok, json } = Reader.fetch_uuid(TestConfig.database_properties)
    uuid = hd(Poison.decode!(json)["uuids"])
    assert String.length(uuid) == 32
  end
end
