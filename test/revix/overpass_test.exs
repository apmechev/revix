defmodule Revix.OverpassTest do
  use ExUnit.Case, async: true

  alias Revix.Overpass

  describe "parse_elements/3" do
    test "parses node elements" do
      elements = %{
        "elements" => [
          %{
            "type" => "node",
            "id" => 123,
            "lat" => 40.001,
            "lon" => -105.001,
            "tags" => %{"name" => "Coffee Shop", "amenity" => "cafe"}
          }
        ]
      }

      assert [result] = Overpass.parse_elements(elements, 40.0, -105.0)
      assert result.name == "Coffee Shop"
      assert result.lat == 40.001
      assert result.lon == -105.001
      assert result.osm_type == :node
      assert result.osm_id == 123
      assert result.source == :osm
      assert result.id == nil
      assert is_float(result.distance)
      assert result.distance > 0
    end

    test "parses way elements using center coordinates" do
      elements = %{
        "elements" => [
          %{
            "type" => "way",
            "id" => 456,
            "center" => %{"lat" => 40.002, "lon" => -105.002},
            "tags" => %{"name" => "Big Building", "tourism" => "museum"}
          }
        ]
      }

      assert [result] = Overpass.parse_elements(elements, 40.0, -105.0)
      assert result.name == "Big Building"
      assert result.osm_type == :way
      assert result.osm_id == 456
      assert result.lat == 40.002
      assert result.lon == -105.002
    end

    test "parses relation elements using center coordinates" do
      elements = %{
        "elements" => [
          %{
            "type" => "relation",
            "id" => 789,
            "center" => %{"lat" => 40.003, "lon" => -105.003},
            "tags" => %{"name" => "Park Complex", "leisure" => "park"}
          }
        ]
      }

      assert [result] = Overpass.parse_elements(elements, 40.0, -105.0)
      assert result.osm_type == :relation
      assert result.osm_id == 789
    end

    test "skips elements without a name" do
      elements = %{
        "elements" => [
          %{
            "type" => "node",
            "id" => 111,
            "lat" => 40.001,
            "lon" => -105.001,
            "tags" => %{"amenity" => "bench"}
          }
        ]
      }

      assert [] = Overpass.parse_elements(elements, 40.0, -105.0)
    end

    test "sorts results by distance" do
      elements = %{
        "elements" => [
          %{
            "type" => "node",
            "id" => 1,
            "lat" => 40.01,
            "lon" => -105.01,
            "tags" => %{"name" => "Far"}
          },
          %{
            "type" => "node",
            "id" => 2,
            "lat" => 40.001,
            "lon" => -105.001,
            "tags" => %{"name" => "Near"}
          }
        ]
      }

      results = Overpass.parse_elements(elements, 40.0, -105.0)
      assert length(results) == 2
      assert Enum.at(results, 0).name == "Near"
      assert Enum.at(results, 1).name == "Far"
    end

    test "handles empty elements" do
      assert [] = Overpass.parse_elements(%{"elements" => []}, 40.0, -105.0)
    end

    test "handles missing elements key" do
      assert [] = Overpass.parse_elements(%{}, 40.0, -105.0)
    end
  end
end

defmodule Revix.OverpassSearchTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Revix.Overpass

  describe "search_nearby/3" do
    test "includes admin_level relations enclosing the point" do
      Req.Test.stub(:overpass, fn conn ->
        Req.Test.json(conn, %{
          "elements" => [
            %{
              "type" => "relation",
              "id" => 12345,
              "center" => %{"lat" => 40.0, "lon" => -105.0},
              "tags" => %{"name" => "Boulder County", "admin_level" => "6"}
            }
          ]
        })
      end)

      assert {:ok, [result]} = Overpass.search_nearby(40.0, -105.0, 500)
      assert result.name == "Boulder County"
      assert result.osm_type == :relation
      assert result.osm_id == 12345
    end

    test "uses the configured Overpass URL when set" do
      original = Application.get_env(:revix, :overpass)

      Application.put_env(
        :revix,
        :overpass,
        Keyword.put(original || [], :url, "http://overpass.example/api/interpreter")
      )

      on_exit(fn -> Application.put_env(:revix, :overpass, original) end)

      Req.Test.stub(:overpass, fn conn ->
        send(self(), {:overpass_request_host, conn.host})
        Req.Test.json(conn, %{"elements" => []})
      end)

      assert {:ok, []} = Overpass.search_nearby(40.0, -105.0, 500)
      assert_received {:overpass_request_host, "overpass.example"}
    end

    test "logs HTTP errors with the queried instance at warning level" do
      Req.Test.stub(:overpass, fn conn ->
        Plug.Conn.send_resp(conn, 429, "Too Many Requests")
      end)

      log = capture_log(fn -> Overpass.search_nearby(40.0, -105.0, 500) end)

      assert log =~ "Overpass search failed"
      assert log =~ "POST https://overpass-api.de/api/interpreter"
      assert log =~ "429"
    end

    test "logs transport errors with the queried instance at warning level" do
      Req.Test.stub(:overpass, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      log = capture_log(fn -> Overpass.search_nearby(40.0, -105.0, 500) end)

      assert log =~ "Overpass search failed"
      assert log =~ "POST https://overpass-api.de/api/interpreter"
      assert log =~ "timeout"
    end
  end

  describe "log_request_result/4" do
    test "logs slow successful requests at warning level" do
      log =
        capture_log(fn ->
          Overpass.log_request_result(
            :search,
            "http://overpass.example/api/interpreter",
            {:ok, %{status: 200}},
            15_000
          )
        end)

      assert log =~ "Overpass search was slow"
      assert log =~ "POST http://overpass.example/api/interpreter"
      assert log =~ "15000ms"
    end

    test "logs fast successful requests at debug level" do
      original_level = Logger.level()
      on_exit(fn -> Logger.configure(level: original_level) end)
      Logger.configure(level: :debug)

      log =
        capture_log(fn ->
          Overpass.log_request_result(
            :fetch,
            "http://overpass.example/api/interpreter",
            {:ok, %{status: 200}},
            100
          )
        end)

      Logger.configure(level: original_level)

      assert log =~ "Overpass fetch succeeded"
    end
  end
end

defmodule Revix.OverpassFetchTest do
  use ExUnit.Case, async: false

  alias Revix.Overpass

  describe "fetch_element/2" do
    test "returns name and coordinates for a node" do
      Req.Test.stub(:overpass, fn conn ->
        Req.Test.json(conn, %{
          "elements" => [
            %{
              "type" => "node",
              "id" => 123,
              "lat" => 51.5,
              "lon" => -0.1,
              "tags" => %{"name" => "Some Cafe"}
            }
          ]
        })
      end)

      assert {:ok, %{name: "Some Cafe", lat: 51.5, lon: -0.1}} =
               Overpass.fetch_element(:node, 123)
    end

    test "returns center coordinates for a way" do
      Req.Test.stub(:overpass, fn conn ->
        Req.Test.json(conn, %{
          "elements" => [
            %{
              "type" => "way",
              "id" => 456,
              "center" => %{"lat" => 48.8, "lon" => 2.3},
              "tags" => %{"name" => "Big Museum"}
            }
          ]
        })
      end)

      assert {:ok, %{name: "Big Museum", lat: 48.8, lon: 2.3}} =
               Overpass.fetch_element(:way, 456)
    end

    test "returns center coordinates for a relation" do
      Req.Test.stub(:overpass, fn conn ->
        Req.Test.json(conn, %{
          "elements" => [
            %{
              "type" => "relation",
              "id" => 789,
              "center" => %{"lat" => 40.7, "lon" => -74.0},
              "tags" => %{"name" => "City Park"}
            }
          ]
        })
      end)

      assert {:ok, %{name: "City Park", lat: 40.7, lon: -74.0}} =
               Overpass.fetch_element(:relation, 789)
    end

    test "returns {:error, :not_found} on empty elements list" do
      Req.Test.stub(:overpass, fn conn ->
        Req.Test.json(conn, %{"elements" => []})
      end)

      assert {:error, :not_found} = Overpass.fetch_element(:node, 999)
    end

    test "returns {:error, :not_found} when element has no name" do
      Req.Test.stub(:overpass, fn conn ->
        Req.Test.json(conn, %{
          "elements" => [
            %{
              "type" => "node",
              "id" => 111,
              "lat" => 51.5,
              "lon" => -0.1,
              "tags" => %{"amenity" => "bench"}
            }
          ]
        })
      end)

      assert {:error, :not_found} = Overpass.fetch_element(:node, 111)
    end

    test "returns http error tuple on non-200 response" do
      Req.Test.stub(:overpass, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Plug.Conn.send_resp(429, "Too Many Requests")
      end)

      assert {:error, {:http_error, 429}} = Overpass.fetch_element(:node, 123)
    end

    test "returns error tuple on transport error" do
      Req.Test.stub(:overpass, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, _} = Overpass.fetch_element(:node, 123)
    end
  end
end
